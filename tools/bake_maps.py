"""Precompute exact desktop starting deployments, optionally benchmark and verify reuse.

The config uses LocalServer options, e.g. {"fixed_seed":3,"map_size":1024,
"ai_fill":true,"team":-1,"name":"Commander"}. No map or player settings are
rewritten to make a cache hit. Output packages can be exported under maps/precomputed/.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

from map_cache_version import stamp

ROOT = Path(__file__).resolve().parents[1]


def execute(argv, log):
    started = time.perf_counter()
    with log.open("w", encoding="utf-8") as output:
        subprocess.run(argv, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                       check=True, timeout=900)
    text = log.read_text(encoding="utf-8")
    if re.search(r"SCRIPT ERROR|Parse Error|^ERROR:|panicked", text, re.MULTILINE):
        raise RuntimeError(f"Errors in {log}")
    return time.perf_counter() - started, text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="Package directory")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--server", type=Path, default=ROOT / "bin/native" / ("frontline-server.exe" if os.name == "nt" else "macos/frontline-server" if sys.platform == "darwin" else "frontline-server"))
    parser.add_argument("--benchmark", action="store_true", help="Compare uncached, population and two cached runs")
    parser.add_argument("--ticks", type=int, default=600, help="Run and independently verify this many deterministic ticks")
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8-sig"))
    if not isinstance(config, dict) or ("fixed_seed" not in config and not config.get("mission")):
        parser.error("Config must be an object with a fixed_seed or a fixed-seed mission")
    if args.ticks < 1:
        parser.error("--ticks must be positive")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    stamp(ROOT)
    version = int(re.search(r"const NET_VERSION := (\d+)", (ROOT / "scripts/autoload/net.gd").read_text()).group(1))
    config = {**config, "team": config.get("team", -1), "name": config.get("name", "Commander"),
              "version": version, "parent_pid": os.getpid(), "map_cache_dir": str(output)}
    runs = []
    with tempfile.TemporaryDirectory(prefix="map-bake-", dir=output) as scratch:
        scratch = Path(scratch)
        labels = ["uncached", "populate", "cached-1", "cached-2"] if args.benchmark else ["bake"]
        for label in labels:
            stem = scratch / label
            options = {**config, "map_cache": label != "uncached"}
            stem.with_suffix(".json").write_text(json.dumps(options), encoding="utf-8")
            seconds, text = execute([args.godot, "--headless", "--path", str(ROOT), "--",
                                     f"--managed-server={stem}"], output / f"{label}.log")
            data = stem.with_suffix(".initial").read_bytes()
            initial_hash = hashlib.sha256(data).hexdigest()
            hit = "BATTLEFIELD_CACHE hit" in text
            if label.startswith("cached") and not hit:
                raise RuntimeError(f"Expected a cache hit; see {label}.log")
            if runs and initial_hash != runs[0]["initial_sha256"]:
                raise RuntimeError("Cached and generated initial states differ")
            replay = stem.with_suffix(".flrp")
            simulation_seconds, _ = execute([str(args.server.resolve()), "run", str(stem.with_suffix('.initial')),
                                              str(replay), str(args.ticks)], output / f"{label}-simulation.log")
            _, verification = execute([str(args.server.resolve()), "verify", str(replay)], output / f"{label}-verify.log")
            verified = next(line for line in verification.splitlines() if line.startswith("REPLAY_VERIFIED"))
            if runs and verified != runs[0]["verification"]:
                raise RuntimeError("Generated and cached replay verification differs")
            record = {"mode": label, "generation_seconds": round(seconds, 3), "cache_hit": hit,
                      "initial_bytes": len(data), "initial_sha256": initial_hash,
                      "simulation_seconds": round(simulation_seconds, 3), "verification": verified}
            runs.append(record)
            print(json.dumps(record), flush=True)
    report = {"config": {k: v for k, v in config.items() if k not in ("parent_pid", "map_cache_dir")},
              "ticks": args.ticks, "runs": runs,
              "scope": "Generator process wall time; excludes Rust initialization and client visual loading. Other apps remain running."}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
