#!/usr/bin/env python3
"""Opt-in user-level Observatory MCP setup. Python 3.11+, no dependencies."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib

URL = "https://agent-observatory-hub.peachy-pony-3346.chatgpt.site/mcp"
NAME = "observatory"


def paths(client):
    if client == "codex":
        return Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "config.toml"
    directory = os.environ.get("CLAUDE_CONFIG_DIR")
    return Path(directory) / ".claude.json" if directory else Path.home() / ".claude.json"


def marker():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "observatory" / "enabled"


def read_config(client):
    path = paths(client)
    if not path.exists():
        return {}
    try:
        text = path.read_text()
        config = tomllib.loads(text) if client == "codex" else json.loads(text)
        if not isinstance(config, dict):
            raise ValueError("Expected a configuration object")
        return config
    except (ValueError, OSError) as exc:
        # Parser messages may contain source lines, including credentials.
        raise RuntimeError(f"Cannot parse {client} config; repair it locally (contents hidden).") from exc


def entry(client):
    config = read_config(client)
    servers = config.get("mcp_servers" if client == "codex" else "mcpServers", {})
    if not isinstance(servers, dict):
        raise RuntimeError(f"Invalid {client} server configuration (contents hidden).")
    value = servers.get(NAME)
    if value is not None and not isinstance(value, dict):
        raise RuntimeError(f"Invalid {client} Observatory entry (contents hidden).")
    return value


def validate(client):
    value = entry(client)
    if value is not None:
        if value.get("url") != URL or value.get("command"):
            raise RuntimeError(f"{client}: existing '{NAME}' conflicts; left untouched. Resolve locally first.")
        if client == "claude" and value.get("type") != "http":
            raise RuntimeError("claude: existing Observatory transport conflicts; left untouched.")
        if client == "codex" and value.get("oauth_resource", URL) != URL:
            raise RuntimeError("codex: OAuth resource conflicts; left untouched.")
    return value


def install_codex():
    path = paths("codex")
    if path.is_symlink():
        raise RuntimeError("Codex config is a symlink; add the documented MCP block to its source manually.")
    original = path.read_bytes() if path.exists() else b""
    block = ('\n[mcp_servers.observatory]\n'
             f'url = "{URL}"\n'
             f'oauth_resource = "{URL}"\n'
             'enabled_tools = ["register_task", "update_task", "list_tasks"]\n')
    combined = original + block.encode()
    # Reject conflicting inline tables without touching the user's file.
    try:
        tomllib.loads(combined.decode())
    except ValueError as exc:
        raise RuntimeError("Cannot append MCP table safely; use the documented block manually.") from exc
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temp = Path(stream.name)
            stream.write(combined)
        temp.chmod(0o600)
        if (path.read_bytes() if path.exists() else b"") != original:
            raise RuntimeError("Codex config changed during setup; retry.")
        temp.replace(path)
    finally:
        if temp and temp.exists():
            temp.unlink()


def setup(target):
    clients = ["codex", "claude"] if target == "all" else [target]
    available = [c for c in clients if shutil.which(c)]
    if not available:
        raise RuntimeError("Requested CLI is not installed. Run dotfiles setup/update first.")
    # Inspect both before the first write; never replace a conflicting definition.
    existing = {c: validate(c) for c in available}
    for client in available:
        if existing[client] is None:
            if client == "codex":
                install_codex()
            else:
                # CLI owns the JSON merge. Suppress output that might contain local data.
                result = subprocess.run(["claude", "mcp", "add", "--transport", "http", "--scope", "user", NAME, URL], capture_output=True, timeout=30, check=False)
                if result.returncode:
                    raise RuntimeError("Claude MCP registration failed; inspect `claude mcp get observatory` locally.")
            if validate(client) is None:
                raise RuntimeError(f"{client}: registration could not be verified.")
        print(f"{client}: configured (OAuth login still needs verification).")
    marker().parent.mkdir(parents=True, exist_ok=True)
    marker().touch(mode=0o600)
    print("Reporting enabled. Restart your agent sessions after authentication.")
    print("Codex: observatory login codex; Claude Code: /mcp → observatory → authenticate.")
    for client in set(clients) - set(available):
        print(f"{client}: CLI not installed; skipped.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    command = sub.add_parser("setup", help="Register user-level MCP entries and enable reporting")
    command.add_argument("client", nargs="?", choices=["all", "codex", "claude"], default="all")
    sub.add_parser("status", help="Show local configuration only; does not verify login")
    sub.add_parser("disable", help="Disable reporting instructions; keep MCP settings and login")
    command = sub.add_parser("login", help="Run the official Codex OAuth browser login")
    command.add_argument("client", choices=["codex"])
    args = parser.parse_args()
    try:
        if args.action == "setup":
            setup(args.client)
        elif args.action == "disable":
            marker().unlink(missing_ok=True)
            print("Reporting disabled. MCP configuration and credentials were retained.")
        elif args.action == "status":
            print(f"Reporting: {'enabled' if marker().exists() else 'disabled'}")
            for client in ("codex", "claude"):
                value = validate(client)
                state = "configured" if value is not None else "not configured"
                print(f"{client}: {state}; CLI {'installed' if shutil.which(client) else 'not installed'}")
            print("Local configuration only. Verify authenticated list_tasks in each client.")
        else:
            if validate("codex") is None or not shutil.which("codex"):
                raise RuntimeError("Run `observatory setup codex` first.")
            # The resource value is public metadata returned by Sites, not a credential.
            return subprocess.call(["codex", "-c", f'mcp_servers.observatory.oauth_resource="{URL}"', "mcp", "login", NAME])
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        if isinstance(exc, RuntimeError):
            print(f"observatory: {exc}", file=sys.stderr)
        else:
            print("observatory: local operation failed (details hidden); inspect configuration locally.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
