"""Run scaling regressions and gameplay smoke cases, preserving every log."""
import argparse
from pathlib import Path
import socket
import subprocess

p = argparse.ArgumentParser()
p.add_argument("--godot", required=True)
p.add_argument("--output", default="build/scaling-checks")
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = (root / a.output).resolve()
out.mkdir(parents=True, exist_ok=True)
exe = str(Path(a.godot).resolve())
cases = [("import", ["--import"], None)]
for name in ("structure_index", "perception_index", "navigation_budget", "client_loading", "local_server", "update_sidecars", "terrain_updates", "squad_assessment", "map_placement", "snapshot_index", "terrain_cover", "soldier_batch", "structure_view"):
    cases.append((name, [f"res://tests/{name}_test.tscn"], "failures=0"))
for name in ("attack", "breach", "tank", "gdrill", "fire", "naval", "sling"):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    cases.append((name, ["--fixed-fps", "30", "--", f"--scenario={name}", "--seed=3", "--quit-after=45", "--stats=45", f"--port={port}"], "FINAL "))
failures = []
for name, args, marker in cases:
    path = out / f"{name}.log"
    print(f"RUN {name}", flush=True)
    try:
        with path.open("w", encoding="utf-8") as log:
            run = subprocess.run([exe, "--headless", "--path", str(root), *args], cwd=root,
                                 stdout=log, stderr=subprocess.STDOUT, timeout=240)
        text = path.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in text.splitlines() if "ERROR:" in line and "resources still in use at exit" not in line]
        failed = run.returncode != 0 or errors or "Parse Error" in text or (marker and marker not in text)
    except subprocess.TimeoutExpired:
        failed = True
    if failed:
        failures.append(name)
    print(f"{'FAIL' if failed else 'PASS'} {name}", flush=True)
    if failed and name == "import":
        break
print(f"SCALING_CHECKS failures={failures}", flush=True)
raise SystemExit(bool(failures))
