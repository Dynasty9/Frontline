"""Exercise benchmark acceptance with synthetic reports, without launching Godot."""
import contextlib
import io
import json
from pathlib import Path
import runpy
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

RUNNER = Path(__file__).with_name("benchmark_scaling.py")
FAST_FRAMES = {"count": 120, "max_ms": 10, "p99_ms": 9}
FAST_TICKS = {"count": 60, "max_ms": 20, "p95_ms": 18}


class BenchmarkTargetTest(unittest.TestCase):
    def run_benchmark(self, client, *, server=None, rendered=True, require_target=True, exit_code=0):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            args = [str(RUNNER), "--godot", "not-a-real-godot", "--output", folder]
            if rendered:
                args.append("--rendered")
            if require_target:
                args.append("--require-target")
            if server is not None:
                args.append("--local-server")

            def complete_process(*_args, **_kwargs):
                if client is not None:
                    (out / "client.json").write_text(json.dumps(client), encoding="utf-8")
                if server is not None:
                    (out / "server.json").write_text(json.dumps(server), encoding="utf-8")
                return Mock(pid=12345, returncode=exit_code, poll=Mock(return_value=exit_code))

            stdout = io.StringIO()
            # No executable, network socket, process inspection or sleep is used.
            with patch.object(sys, "argv", args), patch("subprocess.Popen", side_effect=complete_process) as launch, \
                    patch("socket.socket") as socket, patch("os.kill") as kill, patch("time.sleep") as sleep, \
                    contextlib.redirect_stdout(stdout), self.assertRaises(SystemExit) as stopped:
                socket.return_value.__enter__.return_value.getsockname.return_value = ("127.0.0.1", 12345)
                runpy.run_path(str(RUNNER), run_name="__main__")
            launch.assert_called_once()
            kill.assert_not_called()
            sleep.assert_not_called()
            result = json.loads((out / "result.json").read_text(encoding="utf-8"))
            self.assertEqual(json.loads(stdout.getvalue()), result)
            return stopped.exception.code, result

    def test_headless_cannot_pass_rendered_target(self):
        for frames in (None, FAST_FRAMES):
            with self.subTest(frames=frames):
                client = {"ticks": FAST_TICKS}
                if frames is not None:
                    client["frames"] = frames
                code, result = self.run_benchmark(client, rendered=False)
                self.assertEqual(code, 1)
                self.assertIsNone(result["budgets"]["render_60_fps_every_sample"])
                self.assertIsNone(result["budgets"]["render_60_fps_p99"])
                self.assertTrue(result["budgets"]["simulation_30hz_every_sample"])

    def test_headless_diagnostics_remain_successful(self):
        for ticks in (FAST_TICKS, {"count": 60, "max_ms": 40, "p95_ms": 35}):
            with self.subTest(ticks=ticks):
                code, result = self.run_benchmark({"ticks": ticks}, rendered=False, require_target=False)
                self.assertEqual(code, 0)
                self.assertIsNone(result["budgets"]["render_60_fps_every_sample"])
                self.assertEqual(result["budgets"]["simulation_30hz_every_sample"], ticks["max_ms"] <= 1000 / 30)

    def test_rendered_target_requires_frame_samples_and_maximum(self):
        for frames in (None, {}, {"count": 0, "max_ms": 0}, {"max_ms": 10}, {"count": 120}):
            with self.subTest(frames=frames):
                client = {"ticks": FAST_TICKS}
                if frames is not None:
                    client["frames"] = frames
                code, result = self.run_benchmark(client)
                self.assertEqual(code, 1)
                self.assertFalse(result["budgets"]["render_60_fps_every_sample"])

    def test_rendered_target_requires_tick_samples_and_maximum(self):
        for ticks in (None, {}, {"count": 0, "max_ms": 0}, {"max_ms": 20}, {"count": 60}):
            with self.subTest(ticks=ticks):
                client = {"frames": FAST_FRAMES}
                if ticks is not None:
                    client["ticks"] = ticks
                code, result = self.run_benchmark(client)
                self.assertEqual(code, 1)
                self.assertFalse(result["budgets"]["simulation_30hz_every_sample"])

    def test_measured_target_passes_at_both_budget_boundaries(self):
        client = {"frames": {**FAST_FRAMES, "max_ms": 1000 / 60}, "ticks": {**FAST_TICKS, "max_ms": 1000 / 30}}
        code, result = self.run_benchmark(client)
        self.assertEqual(code, 0)
        self.assertTrue(result["budgets"]["render_60_fps_every_sample"])
        self.assertTrue(result["budgets"]["simulation_30hz_every_sample"])

    def test_every_sample_budget_not_just_percentiles_is_required(self):
        for frames, ticks in (
            ({**FAST_FRAMES, "max_ms": 17}, FAST_TICKS),
            (FAST_FRAMES, {**FAST_TICKS, "max_ms": 34}),
        ):
            with self.subTest(frames=frames, ticks=ticks):
                code, result = self.run_benchmark({"frames": frames, "ticks": ticks})
                self.assertEqual(code, 1)
                self.assertTrue(result["budgets"]["render_60_fps_p99"])
                self.assertTrue(result["budgets"]["simulation_30hz_p95"])

    def test_local_server_ticks_determine_simulation_budget(self):
        client = {"frames": FAST_FRAMES, "ticks": FAST_TICKS}
        for ticks, expected in ((FAST_TICKS, 0), ({"count": 0}, 1), ({**FAST_TICKS, "max_ms": 34}, 1)):
            with self.subTest(ticks=ticks):
                code, _ = self.run_benchmark(client, server={"ticks": ticks})
                self.assertEqual(code, expected)

    def test_rendered_diagnostics_keep_failed_budgets_without_acceptance_gate(self):
        code, result = self.run_benchmark({"frames": {"count": 0}, "ticks": FAST_TICKS}, require_target=False)
        self.assertEqual(code, 0)
        self.assertFalse(result["budgets"]["render_60_fps_every_sample"])

    def test_process_failure_or_missing_report_still_fails_without_target(self):
        for client, exit_code in ((None, 0), ({"frames": FAST_FRAMES, "ticks": FAST_TICKS}, 2)):
            with self.subTest(client=client, exit_code=exit_code):
                code, _ = self.run_benchmark(client, require_target=False, exit_code=exit_code)
                self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
