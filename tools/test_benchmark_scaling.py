"""Exercise the runner with a deterministic stand-in, never performance evidence."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).with_name('benchmark_scaling.py')


class BenchmarkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.engine = self.root / 'fake-engine'
        self.engine.write_text('#!' + sys.executable + '\n' + '''
import json, pathlib, sys
path = pathlib.Path(next(a.split('=', 1)[1] for a in sys.argv if a.startswith('--perf-json=')))
path.write_text(json.dumps({'ticks': {'count': 1, 'max_ms': 1, 'p95_ms': 1}}))
(path.parent / 'argv.json').write_text(json.dumps(sys.argv))
''')
        self.engine.chmod(0o755)
        self.out = self.root / 'attempt'

    def run_case(self, *args):
        return subprocess.run([sys.executable, str(RUNNER), '--godot', str(self.engine),
                               '--output', str(self.out), *args], capture_output=True, text=True,
                              env={**os.environ, 'XDG_DATA_HOME': str(self.root / 'data')})

    def test_default_capture_is_after_report(self):
        result = self.run_case('--rendered', '--battlefield=alder-valley', '--no-baked-map')
        self.assertEqual(result.returncode, 0, result.stderr)
        argv = json.loads((self.out / 'argv.json').read_text())
        self.assertIn('--battlefield=alder-valley', argv)
        self.assertIn('--no-baked-map', argv)
        self.assertTrue(any(a.startswith('--perf-shot=') for a in argv))
        self.assertFalse(any(a.startswith(('--screenshot=', '--shot-at=')) for a in argv))

    def test_png_can_be_disabled(self):
        result = self.run_case('--rendered', '--no-screenshot')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--no-perf-shot', json.loads((self.out / 'argv.json').read_text()))

    def test_existing_empty_directory_rejected(self):
        self.out.mkdir()
        result = self.run_case()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('new output directory', result.stderr)

    def test_stale_server_without_client_rejected(self):
        self.out.mkdir()
        stale = self.out / 'server.json'
        stale.write_text('{"ticks": {"count": 10}}')
        result = self.run_case('--local-server')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.out / 'argv.json').exists())
        self.assertEqual(stale.read_text(), '{"ticks": {"count": 10}}')

    def test_missing_current_host_report_fails_closed(self):
        result = self.run_case('--local-server')
        self.assertNotEqual(result.returncode, 0)
        report = json.loads((self.out / 'result.json').read_text())
        self.assertIsNone(report['server'])
        self.assertIn('Private host produced no fresh report in this invocation', report['errors'])

    @unittest.skipUnless(sys.platform.startswith('linux'), 'Linux XDG fixture')
    def test_current_host_report_is_collected(self):
        with self.engine.open('a') as f:
            f.write('''
import os, time
sessions = pathlib.Path(os.environ['XDG_DATA_HOME']) / 'godot/app_userdata/Frontline/local_servers'
sessions.mkdir(parents=True)
(sessions / 'fixture.json').write_text(json.dumps({'benchmark_output': str(path), 'parent_pid': os.getpid()}))
(sessions / 'fixture.perf.json').write_text(json.dumps({'ticks': {'count': 2, 'max_ms': 1, 'p95_ms': 1}}))
time.sleep(1.1)
''')
        result = self.run_case('--local-server')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = json.loads((self.out / 'result.json').read_text())
        self.assertEqual(report['server']['ticks']['count'], 2)


if __name__ == '__main__':
    unittest.main()
