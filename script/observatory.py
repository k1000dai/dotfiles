#!/usr/bin/env python3
"""Opt-in user-level Observatory MCP setup. Python 3.11+, no dependencies."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
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
                print("Codex: install/connect Agent Observatory from /plugins → Personal.")
                continue
            else:
                # CLI owns the JSON merge. Suppress output that might contain local data.
                result = subprocess.run(["claude", "mcp", "add", "--transport", "http", "--scope", "user", NAME, URL], capture_output=True, timeout=30, check=False)
                if result.returncode:
                    raise RuntimeError("Claude MCP registration failed; inspect `claude mcp get observatory` locally.")
            if validate(client) is None:
                raise RuntimeError(f"{client}: registration could not be verified.")
        if client == "codex":
            print("Codex: legacy direct MCP entry found. Run `codex mcp remove observatory`, then use /plugins → Personal → Agent Observatory.")
        else:
            print(f"{client}: configured (OAuth login still needs verification).")
    marker().parent.mkdir(parents=True, exist_ok=True)
    marker().touch(mode=0o600)
    print("Reporting enabled. Restart your agent sessions after authentication.")
    print("Codex: /plugins → Personal → Agent Observatory; Claude Code: /mcp → observatory → authenticate (external OAuth compatibility unverified).")
    for client in set(clients) - set(available):
        print(f"{client}: CLI not installed; skipped.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    command = sub.add_parser("setup", help="Register user-level MCP entries and enable reporting")
    command.add_argument("client", nargs="?", choices=["all", "codex", "claude"], default="all")
    sub.add_parser("status", help="Show local configuration only; does not verify login")
    sub.add_parser("disable", help="Disable reporting instructions; keep MCP settings and login")
    command = sub.add_parser("login", help="Show the supported Sites plugin connection flow")
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
            print("Sites uses its generated Agent Observatory plugin; direct DCR login is not supported by this helper.")
            if entry("codex") is not None:
                validate("codex")
                print("Remove the legacy direct entry: codex mcp remove observatory")
            print("Run codex, open /plugins, then install/connect Personal → Agent Observatory.")
            print("Restart the session and ask it to call list_tasks to verify the connection.")
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        if isinstance(exc, RuntimeError):
            print(f"observatory: {exc}", file=sys.stderr)
        else:
            print("observatory: local operation failed (details hidden); inspect configuration locally.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
