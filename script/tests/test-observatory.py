#!/usr/bin/env python3
"""Offline setup tests; never starts real agents or makes network requests."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("observatory", Path(__file__).parents[1] / "observatory.py")
OBS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(OBS)


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = patch.dict(os.environ, {"HOME": str(self.root / "home with spaces"), "CODEX_HOME": str(self.root / "custom codex"), "CLAUDE_CONFIG_DIR": str(self.root / "custom claude"), "XDG_CONFIG_HOME": str(self.root / "config")})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.output = io.StringIO()
        self.redirect = contextlib.redirect_stdout(self.output)
        self.redirect.__enter__()
        self.addCleanup(self.redirect.__exit__, None, None, None)

    def write(self, client, value):
        path = OBS.paths(client)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
        return path

    @patch.object(OBS.shutil, "which", return_value="/mock/cli")
    def test_codex_setup_does_not_create_direct_mcp(self, _which):
        path = self.write("codex", 'model = "existing-model"\n')
        original = path.read_bytes()
        with patch.object(OBS.subprocess, "run") as run:
            OBS.setup("codex")
            OBS.setup("codex")
            run.assert_not_called()
        self.assertEqual(original, path.read_bytes())
        self.assertTrue(OBS.marker().exists())
        self.assertIn("/plugins", self.output.getvalue())

    def test_login_never_attempts_dcr(self):
        self.write("codex", f'[mcp_servers.observatory]\nurl = "{OBS.URL}"\n')
        with patch.object(OBS.sys, "argv", ["observatory", "login", "codex"]), patch.object(OBS.subprocess, "call") as call:
            self.assertEqual(OBS.main(), 0)
            call.assert_not_called()
        self.assertIn("codex mcp remove observatory", self.output.getvalue())
        self.assertIn("/plugins", self.output.getvalue())

    @patch.object(OBS.shutil, "which", return_value="/mock/cli")
    def test_conflict_preflight_does_not_write_other_client(self, _which):
        path = self.write("claude", json.dumps({"mcpServers": {"observatory": {"type": "http", "url": "https://different.invalid"}}}))
        original = path.read_bytes()
        with self.assertRaises(RuntimeError):
            OBS.setup("all")
        self.assertEqual(original, path.read_bytes())
        self.assertFalse(OBS.paths("codex").exists())
        self.assertFalse(OBS.marker().exists())

    @patch.object(OBS.shutil, "which", return_value="/mock/cli")
    def test_claude_cli_user_scope_and_no_duplicate(self, _which):
        self.write("claude", '{"other":"preserve"}')

        def fake_run(argv, **kwargs):
            self.assertEqual(argv, ["claude", "mcp", "add", "--transport", "http", "--scope", "user", "observatory", OBS.URL])
            value = json.loads(OBS.paths("claude").read_text())
            value["mcpServers"] = {"observatory": {"type": "http", "url": OBS.URL}}
            OBS.paths("claude").write_text(json.dumps(value))
            return subprocess.CompletedProcess(argv, 0)

        with patch.object(OBS.subprocess, "run", side_effect=fake_run) as run:
            OBS.setup("claude")
            OBS.setup("claude")
            self.assertEqual(run.call_count, 1)
        self.assertEqual(json.loads(OBS.paths("claude").read_text())["other"], "preserve")

    @patch.object(OBS.shutil, "which", return_value="/mock/cli")
    def test_claude_failure_does_not_enable(self, _which):
        with patch.object(OBS.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, stderr="SECRET")):
            with self.assertRaisesRegex(RuntimeError, "registration failed"):
                OBS.setup("claude")
        self.assertFalse(OBS.marker().exists())
        self.assertNotIn("SECRET", self.output.getvalue())

    def test_invalid_configs_redact_contents(self):
        for client, content in [("codex", 'secret = "SECRET'), ("claude", '{"token":"SECRET"'), ("claude", '[]')]:
            with self.subTest(client=client, content=content):
                self.write(client, content)
                with self.assertRaises(RuntimeError) as error:
                    OBS.validate(client)
                self.assertNotIn("SECRET", str(error.exception))

    @patch.object(OBS.shutil, "which", return_value="/mock/cli")
    def test_codex_symlink_is_not_replaced(self, _which):
        source = self.root / "managed.toml"
        original = 'model="existing"\n'
        source.write_text(original)
        path = OBS.paths("codex")
        path.parent.mkdir(parents=True)
        path.symlink_to(source)
        OBS.setup("codex")
        self.assertTrue(path.is_symlink())
        self.assertEqual(source.read_text(), original)

    @patch.object(OBS.shutil, "which", return_value=None)
    def test_missing_cli_no_writes(self, _which):
        with self.assertRaises(RuntimeError):
            OBS.setup("all")
        self.assertFalse(OBS.marker().exists())
        self.assertFalse(OBS.paths("codex").exists())

    def test_disable_keeps_config(self):
        config = self.write("codex", 'model="keep"\n')
        OBS.marker().parent.mkdir(parents=True)
        OBS.marker().touch()
        with patch.object(OBS.sys, "argv", ["observatory", "disable"]):
            self.assertEqual(OBS.main(), 0)
        self.assertFalse(OBS.marker().exists())
        self.assertEqual(config.read_text(), 'model="keep"\n')


if __name__ == "__main__":
    unittest.main()
