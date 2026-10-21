#!/usr/bin/env python3
"""Offline setup regression tests; never runs real agent CLIs."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch

SPEC=importlib.util.spec_from_file_location('observatory',Path(__file__).parents[1]/'observatory.py')
OBS=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(OBS)


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.env=patch.dict(os.environ,{'HOME':str(self.root/'home with spaces'),'CODEX_HOME':str(self.root/'custom codex'),'CLAUDE_CONFIG_DIR':str(self.root/'custom claude'),'XDG_CONFIG_HOME':str(self.root/'config')})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.output=io.StringIO()
        self.redirect=contextlib.redirect_stdout(self.output)
        self.redirect.__enter__()
        self.addCleanup(self.redirect.__exit__,None,None,None)

    def write(self,client,value):
        path=OBS.paths(client)
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(value)
        return path

    @patch.object(OBS.shutil,'which',return_value='/mock/node')
    def test_codex_stdio_preserves_config_and_rerun(self,_which):
        original='model="existing"\n[mcp_servers.other]\nurl="https://example.invalid"\n'
        path=self.write('codex',original)
        OBS.setup('codex')
        first=path.read_bytes()
        OBS.setup('codex')
        self.assertEqual(first,path.read_bytes())
        self.assertTrue(first.startswith(original.encode()))
        server=tomllib.loads(first.decode())['mcp_servers']['observatory']
        self.assertEqual(server,{'command':'/mock/node','args':[str(OBS.BRIDGE),'serve']})
        self.assertEqual(stat.S_IMODE(path.stat().st_mode),0o600)
        self.assertTrue(OBS.marker().exists())

    @patch.object(OBS.shutil,'which',return_value='/mock/node')
    def test_claude_stdio_uses_user_scope(self,_which):
        path=self.write('claude','{"other":"preserve"}')
        def fake_run(argv,**_kwargs):
            self.assertEqual(argv,['claude','mcp','add','--transport','stdio','--scope','user','observatory','--','/mock/node',str(OBS.BRIDGE),'serve'])
            config=json.loads(path.read_text())
            config['mcpServers']={'observatory':{'type':'stdio','command':'/mock/node','args':[str(OBS.BRIDGE),'serve']}}
            path.write_text(json.dumps(config))
            return subprocess.CompletedProcess(argv,0)
        with patch.object(OBS.subprocess,'run',side_effect=fake_run) as run:
            OBS.setup('claude')
            OBS.setup('claude')
            self.assertEqual(run.call_count,1)
        self.assertEqual(json.loads(path.read_text())['other'],'preserve')

    @patch.object(OBS.shutil,'which',return_value='/mock/node')
    def test_old_http_and_conflicting_definitions_unchanged(self,_which):
        for value in [{'type':'http','url':OBS.URL},{'type':'http','url':'https://different.invalid'},{'type':'stdio','command':'/tmp/untrusted','args':[]}]:
            path=self.write('claude',json.dumps({'mcpServers':{'observatory':value}}))
            original=path.read_bytes()
            with self.assertRaises(RuntimeError):
                OBS.setup('all')
            self.assertEqual(path.read_bytes(),original)
            self.assertFalse(OBS.paths('codex').exists())
            self.assertFalse(OBS.marker().exists())

    def test_invalid_configs_hide_contents(self):
        for client,content in [('codex','secret="SECRET'),('claude','{"token":"SECRET"'),('claude','[]')]:
            self.write(client,content)
            with self.assertRaises(RuntimeError) as error:
                OBS.validate(client)
            self.assertNotIn('SECRET',str(error.exception))

    def test_symlink_and_inline_tables_not_replaced(self):
        path=OBS.paths('codex')
        path.parent.mkdir(parents=True)
        source=self.root/'managed.toml'
        source.write_text('model="keep"\n')
        path.symlink_to(source)
        with self.assertRaises(RuntimeError):
            OBS.install_codex('/mock/node')
        self.assertEqual(source.read_text(),'model="keep"\n')
        path.unlink()
        original='mcp_servers = {other = {url = "https://example.invalid"}}\n'
        path.write_text(original)
        with self.assertRaises(RuntimeError):
            OBS.install_codex('/mock/node')
        self.assertEqual(path.read_text(),original)

    @patch.object(OBS.shutil,'which',return_value=None)
    def test_missing_cli_no_changes(self,_which):
        with self.assertRaises(RuntimeError):
            OBS.setup('all')
        self.assertFalse(OBS.marker().exists())

    @patch.object(OBS.shutil,'which',return_value='/mock/node')
    def test_login_alias_uses_pairing_not_dcr(self,_which):
        with patch.object(OBS.sys,'argv',['observatory','login','claude']),patch.object(OBS.subprocess,'call',return_value=0) as call:
            self.assertEqual(OBS.main(),0)
            call.assert_called_once_with(['/mock/node',str(OBS.BRIDGE),'connect'])

    @patch.object(OBS.shutil,'which',return_value='/mock/node')
    def test_cli_failure_does_not_enable_reporting(self,_which):
        with patch.object(OBS.subprocess,'run',return_value=subprocess.CompletedProcess([],1,stderr='SECRET')):
            with self.assertRaises(RuntimeError):
                OBS.setup('claude')
        self.assertFalse(OBS.marker().exists())
        self.assertNotIn('SECRET',self.output.getvalue())

    def test_disable_preserves_other_configuration(self):
        path=self.write('codex','model="keep"\n')
        OBS.marker().parent.mkdir(parents=True)
        OBS.marker().touch()
        with patch.object(OBS.sys,'argv',['observatory','disable']):
            self.assertEqual(OBS.main(),0)
        self.assertFalse(OBS.marker().exists())
        self.assertEqual(path.read_text(),'model="keep"\n')


if __name__=='__main__':
    unittest.main()
