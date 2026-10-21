#!/usr/bin/env python3
"""Opt-in local stdio MCP setup for Codex and Claude Code. Python 3.11+."""
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
BRIDGE = Path(__file__).resolve().with_name("observatory-mcp.mjs")


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
            raise ValueError()
        return config
    except (ValueError, OSError) as exc:
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
    if value is None:
        return None
    if value.get("url") == URL and not value.get("command"):
        command = "codex mcp remove observatory" if client == "codex" else "claude mcp remove --scope user observatory"
        raise RuntimeError(f"{client}: legacy HTTP connection found. Run `{command}`, then rerun setup. Nothing was changed.")
    if Path(value.get("command", "")).name not in ("node", "nodejs") or value.get("args") != [str(BRIDGE), "serve"] or value.get("url"):
        raise RuntimeError(f"{client}: existing '{NAME}' conflicts; left untouched. Resolve locally first.")
    if client == "claude" and value.get("type") != "stdio":
        raise RuntimeError("Claude transport conflicts; left untouched.")
    return value


def install_codex(node):
    path = paths("codex")
    if path.is_symlink():
        raise RuntimeError("Codex config is a symlink; add the README stdio block manually.")
    original = path.read_bytes() if path.exists() else b""
    block = '\n[mcp_servers.observatory]\ncommand = ' + json.dumps(node) + '\nargs = ' + json.dumps([str(BRIDGE), "serve"]) + '\n'
    combined = original + block.encode()
    try:
        tomllib.loads(combined.decode())
    except ValueError as exc:
        raise RuntimeError("Cannot append MCP table safely; add the README stdio block manually.") from exc
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
    node = shutil.which("node")
    if not node or not BRIDGE.is_file():
        raise RuntimeError("Node.js and observatory-mcp.mjs are required. Update dotfiles first.")
    clients = ["codex", "claude"] if target == "all" else [target]
    available = [c for c in clients if shutil.which(c)]
    if not available:
        raise RuntimeError("Requested CLI is not installed. Run dotfiles setup/update first.")
    existing = {c: validate(c) for c in available}
    for client in available:
        if existing[client] is None:
            if client == "codex":
                install_codex(node)
            else:
                result = subprocess.run(["claude", "mcp", "add", "--transport", "stdio", "--scope", "user", NAME, "--", node, str(BRIDGE), "serve"], capture_output=True, timeout=30, check=False)
                if result.returncode:
                    raise RuntimeError("Claude stdio registration failed; inspect `claude mcp get observatory` locally.")
            if validate(client) is None:
                raise RuntimeError(f"{client}: registration could not be verified.")
        print(f"{client}: local stdio bridge configured.")
    marker().parent.mkdir(parents=True, exist_ok=True)
    marker().touch(mode=0o600)
    print("Reporting enabled. Run `observatory connect` if not paired, then restart your agents.")
    for client in set(clients) - set(available):
        print(f"{client}: CLI not installed; skipped.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    command = sub.add_parser("setup", help="Register the local stdio bridge and enable reporting")
    command.add_argument("client", nargs="?", choices=["all", "codex", "claude"], default="all")
    sub.add_parser("status", help="Show local configuration only")
    sub.add_parser("disable", help="Disable reporting instructions; retain credentials")
    command = sub.add_parser("connect", help="Approve this computer in your signed-in browser")
    command.add_argument("label", nargs="?", default="Local agents")
    sub.add_parser("disconnect", help="Revoke this connection and delete local credentials")
    command = sub.add_parser("login", help="Compatibility alias for browser pairing")
    command.add_argument("client", choices=["codex", "claude"])
    command = sub.add_parser("worker", help="Manage the resident worker")
    command.add_argument("worker_args", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if args.action == "worker":
            node = shutil.which("node")
            if not node:
                raise RuntimeError("Node.js is required.")
            return subprocess.call([node, str(BRIDGE.with_name("observatory-worker.mjs")), *args.worker_args])
        elif args.action == "setup":
            setup(args.client)
        elif args.action == "disable":
            marker().unlink(missing_ok=True)
            print("Reporting disabled. Connection and credentials were retained.")
        elif args.action == "status":
            print(f"Reporting: {'enabled' if marker().exists() else 'disabled'}")
            for client in ("codex", "claude"):
                print(f"{client}: {'configured' if validate(client) is not None else 'not configured'}")
            print("Local configuration only. Verify list_tasks in each client.")
        else:
            node = shutil.which("node")
            if not node:
                raise RuntimeError("Node.js is required.")
            command = "disconnect" if args.action == "disconnect" else "connect"
            return subprocess.call([node, str(BRIDGE), command] + ([args.label] if args.action == "connect" else []))
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"observatory: {exc}" if isinstance(exc, RuntimeError) else "observatory: operation failed (details hidden).", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
