"""Run one reproducible scaling case. Report measured frames, never inferred FPS."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def rss(pid):
    if os.name != "nt":
        try:
            return int(Path(f"/proc/{pid}/statm").read_text().split()[1]) * os.sysconf("SC_PAGE_SIZE")
        except (OSError, ValueError):
            return None
    class Counters(ctypes.Structure):
        _fields_ = [("cb", ctypes.c_ulong), ("faults", ctypes.c_ulong)] + [
            (name, ctypes.c_size_t) for name in ("peak", "working", "pool_peak", "pool", "nonpaged_peak", "nonpaged", "pagefile", "pagefile_peak")]
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    psapi.GetProcessMemoryInfo.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ulong]
    handle = kernel.OpenProcess(0x410, False, pid)
    if not handle:
        return None
    counters = Counters()
    counters.cb = ctypes.sizeof(counters)
    try:
        return counters.working if psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb) else None
    finally:
        kernel.CloseHandle(handle)


def above_normal(pid):
    """Normalize only this benchmark's owned Windows processes under contention."""
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.SetPriorityClass.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    handle = kernel.OpenProcess(0x200, False, pid)
    if not handle:
        return False
    try:
        return bool(kernel.SetPriorityClass(handle, 0x8000))
    finally:
        kernel.CloseHandle(handle)


p = argparse.ArgumentParser()
p.add_argument("--godot", required=True)
p.add_argument("--output", required=True)
p.add_argument("--exported", action="store_true")
p.add_argument("--above-normal", action="store_true", help="Windows diagnostic: give both owned game processes Above Normal priority")
p.add_argument("--details", action="store_true", help="Time individual soldier methods; adds profiling overhead")
p.add_argument("--rendered", action="store_true")
p.add_argument("--nohud", action="store_true", help="Hide the HUD to isolate its rendering cost")
p.add_argument("--require-target", action="store_true", help="Fail if any measured rendered frame exceeds 16.67 ms or simulation tick exceeds 33.33 ms")
p.add_argument("--local-server", action="store_true")
p.add_argument("--generated", action="store_true")
p.add_argument("--battlefield", help="Measure a catalogue map instead of the stress scenario")
p.add_argument("--no-baked-map", action="store_true", help="Generate the same catalogue seed as the control")
p.add_argument("--commanders", action="store_true")
p.add_argument("--map-size", type=int, choices=[1024, 2048, 3072], default=1024)
p.add_argument("--units", type=int, default=500)
p.add_argument("--vehicles", type=int, default=0)
p.add_argument("--mode", choices=["idle", "march", "combat"], default="combat")
p.add_argument("--seed", type=int, default=3)
p.add_argument("--warmup", type=float, default=15)
p.add_argument("--duration", type=float, default=10)
p.add_argument("--zoom", type=float, default=130)
p.add_argument("--focus", default="0,0", help="Initial camera position X,Z")
p.add_argument("--pitch", type=float, help="Camera pitch in degrees")
p.add_argument("--pan", help="Exercise scenery streaming with the game's X,Z camera pan")
p.add_argument("--width", type=int, default=1280)
p.add_argument("--height", type=int, default=720)
p.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], default="forward_plus")
p.add_argument("--mood", default="day", help="Lock lighting instead of inheriting saved settings")
p.add_argument("--team", type=int, choices=[-1, 0, 1], default=-1)
p.add_argument("--preset", choices=["low", "medium", "high", "ultra"], default="high")
p.add_argument("--timeout", type=float, default=300)
a = p.parse_args()
if a.above_normal and os.name != "nt":
    p.error("--above-normal requires Windows")
out = Path(a.output).resolve()
out.mkdir(parents=True, exist_ok=True)
report_path = out / "client.json"
if report_path.exists():
    raise SystemExit("Use a fresh output directory to avoid stale benchmark results")
cmd = [str(Path(a.godot).resolve()), "--log-file", str(out / "engine.log")]
if not a.exported:
    cmd += ["--path", str(ROOT)]
if a.rendered:
    cmd += ["--resolution", f"{a.width}x{a.height}", "--position", "-12000,-12000", "--rendering-method", a.renderer]
else:
    cmd += ["--headless"]
cmd += ["--", "--novsync", "--set=fps_cap:0", f"--units={a.units}", f"--map-size={a.map_size}",
        f"--preset={a.preset}",
        f"--vehicles={a.vehicles}",
        f"--stress-mode={a.mode}", f"--seed={a.seed}", f"--team={a.team}", f"--mood={a.mood}", f"--perf-at={a.warmup}",
        f"--perf-json={report_path}", f"--perf-duration={a.duration}", f"--quit-after={a.warmup+a.duration+15}", f"--focus={a.focus}", f"--zoom={a.zoom}"]
if a.pitch is not None:
    cmd += [f"--pitch={a.pitch}"]
if a.pan:
    cmd += [f"--pan={a.pan}"]
if a.battlefield:
    cmd += [f"--battlefield={a.battlefield}", "--aivai", "--curtain", "--no-stun"]
else:
    cmd += ["--scenario=stress"]
if a.no_baked_map:
    cmd += ["--no-baked-map"]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as port_socket:
    port_socket.bind(("127.0.0.1", 0))
    cmd.append(f"--port={port_socket.getsockname()[1]}")
if a.rendered:
    cmd += ["--offscreen", f"--screenshot={out / 'battle.png'}", f"--shot-at={a.warmup+min(0.5, a.duration*0.5)}"]
if a.details:
    cmd += ["--perf-details"]
if a.nohud:
    cmd += ["--nohud"]
if a.local_server:
    cmd += ["--local-server"]
if a.generated:
    cmd += ["--stress-generated", "--scenery=0"]
if a.commanders:
    cmd += ["--stress-commanders"]
sessions = Path(os.environ.get("APPDATA", str(Path.home() / ".local/share"))) / "Godot/app_userdata/Frontline/local_servers"
server_report = None
server_log = None
server_pid = None
client_pid = None
memory = []
priority_applied = {}
started = time.monotonic()
with (out / "stdout.log").open("w", encoding="utf-8") as log:
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                            creationflags=(subprocess.CREATE_NO_WINDOW | (subprocess.ABOVE_NORMAL_PRIORITY_CLASS if a.above_normal else 0)) if os.name == "nt" else 0)
    client_pid = proc.pid
    if a.above_normal:
        priority_applied["client"] = above_normal(client_pid)
    while proc.poll() is None and time.monotonic() - started < a.timeout:
        if a.local_server and server_report is None:
            for config in sessions.glob("*.json"):
                try:
                    data = json.loads(config.read_text())
                    if data.get("parent_pid") == proc.pid or data.get("benchmark_output") == str(report_path):
                        server_report = config.with_suffix(".perf.json")
                        server_log = config.with_suffix(".log")
                        server_pid = data.get("child_pid")
                        client_pid = data.get("parent_pid", proc.pid)
                        if a.above_normal:
                            priority_applied["client"] = above_normal(client_pid)
                            priority_applied["server"] = above_normal(server_pid) if server_pid else False
                        break
                except (OSError, ValueError):
                    pass
        memory.append({"wall_seconds": time.monotonic()-started, "client_rss": rss(client_pid), "server_rss": rss(server_pid) if server_pid else None})
        time.sleep(0.5)
    timed_out = proc.poll() is None
    if timed_out:
        proc.terminate()
        proc.wait(timeout=20)
    # A broken development build may exit before its normal child cleanup.
    # Only the PIDs recorded by this benchmark's private launch are ours.
    for owned_pid in ({client_pid, server_pid} if timed_out else {server_pid}) - {None, proc.pid}:
        try:
            os.kill(owned_pid, 15)
        except OSError:
            pass
if server_report and server_report.exists():
    shutil.copy2(server_report, out / "server.json")
if server_log and server_log.exists():
    shutil.copy2(server_log, out / "server.log")
result = {"arguments": vars(a), "wall_seconds": time.monotonic()-started,
          "memory": memory, "priority_applied": priority_applied,
          "exit_code": proc.returncode, "timed_out": timed_out,
          "client": json.loads(report_path.read_text()) if report_path.exists() else None,
          "server": json.loads((out / "server.json").read_text()) if (out / "server.json").exists() else None}
result["errors"] = [f"{path.name}: {line}" for path in [out / "stdout.log", out / "server.log"] if path.exists()
                    for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
                    if "ERROR:" in line and "resources still in use at exit" not in line]
if a.above_normal and (not priority_applied.get("client") or (a.local_server and not priority_applied.get("server"))):
    result["errors"].append("Could not normalize both owned process priorities")
frames = (result["client"] or {}).get("frames", {})
ticks = (result["server"] or result["client"] or {}).get("ticks", {})
result["budgets"] = {
    "render_60_fps_every_sample": frames.get("count", 0) > 0 and frames.get("max_ms", float("inf")) <= 1000/60 if a.rendered else None,
    "render_60_fps_p99": frames.get("count", 0) > 0 and frames.get("p99_ms", float("inf")) <= 1000/60 if a.rendered else None,
    "simulation_30hz_every_sample": ticks.get("count", 0) > 0 and ticks.get("max_ms", float("inf")) <= 1000/30,
    "simulation_30hz_p95": ticks.get("count", 0) > 0 and ticks.get("p95_ms", float("inf")) <= 1000/30,
}
target_failed = result["budgets"]["render_60_fps_every_sample"] is False or not result["budgets"]["simulation_30hz_every_sample"]
(out / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
raise SystemExit(1 if timed_out or proc.returncode != 0 or not result["client"] or (a.local_server and not result["server"]) or result["errors"] or (a.require_target and target_failed) else 0)
