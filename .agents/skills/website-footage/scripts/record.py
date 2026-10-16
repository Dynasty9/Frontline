"""Record takes of the game, off-screen, with Godot's movie writer.

    record.py --list                      what takes shots.json defines
    record.py TAKE [TAKE ...]             record those takes
    record.py --all                       record every take
      [--jobs 3] [--godot PATH] [--work DIR] [--no-sync] [--port 8700]

Each take is a run of the game with its own flags (shots.json), written frame
by frame at a fixed 30 fps to WORK/takes/TAKE.avi (MJPEG + the game's sound),
so a slow render never drops a frame: a take of N frames is N/30 seconds of
game time however long it takes to draw (about 5 frames a second, slower with
several running).

The game runs from a private copy of the project (WORK/project) with an
override.cfg that starts its window minimized, borderless and unfocused, and
--offscreen moves it out of sight, so nothing opens over the desktop. The copy
is refreshed from the repo (and re-imported) before recording unless
--no-sync, so it records the game as this checkout has it. Every run gets its
own free port: a game that can't open its port carries on as an observer
without saying so (its log shows "Couldn't create an ENet host"), and other
games on this machine may hold the usual ones.

Godot: --godot, else $GODOT, else `godot` on the PATH. It must be able to open
a window (any build but --headless; on Windows the plain or the _console exe):
it has to draw to record.
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent
REPO = SKILL.parents[2]
sys.path.insert(0, str(HERE))
from avi import Avi  # noqa: E402

# what the game needs to run; everything else in the repo stays behind
SKIP = {".git", ".github", ".claude", ".godot", "web", "matchmaker", "docs", "design", "changelog", "node_modules", "export", "build"}

OVERRIDE = """[display]

window/size/mode=1
window/size/borderless=true
window/size/no_focus=true

[editor]

movie_writer/mjpeg_quality=0.92
movie_writer/fps=30
"""


def work_dir(arg: str | None) -> Path:
    d = Path(arg or os.environ.get("FRONTLINE_FOOTAGE_DIR") or Path(tempfile.gettempdir()) / "frontline-footage")
    d.mkdir(parents=True, exist_ok=True)
    return d


def find_godot(arg: str | None) -> str:
    g = arg or os.environ.get("GODOT") or shutil.which("godot") or shutil.which("godot4")
    if not g or not Path(g).exists() and not shutil.which(g):
        sys.exit("No Godot: pass --godot PATH or set GODOT to a Godot 4.7 binary that can open a window.")
    return g


def sync(godot: str, proj: Path) -> None:
    """Copy the game into proj and import it (a fresh copy every time: old scripts must not linger)."""
    if proj.exists():
        shutil.rmtree(proj / "scripts", ignore_errors=True)
        shutil.rmtree(proj / "assets", ignore_errors=True)
    proj.mkdir(parents=True, exist_ok=True)
    for p in REPO.iterdir():
        if p.name in SKIP or p.name.startswith("."):
            continue
        if p.is_dir():
            shutil.copytree(p, proj / p.name, dirs_exist_ok=True)
        else:
            shutil.copy2(p, proj / p.name)
    (proj / "override.cfg").write_text(OVERRIDE, newline="\n")
    print(f"importing the project copy in {proj} ...", flush=True)
    r = subprocess.run([godot, "--headless", "--path", str(proj), "--import"], capture_output=True, text=True, timeout=900)
    bad = [line for line in (r.stdout + r.stderr).splitlines() if "SCRIPT ERROR" in line or "Parse Error" in line]
    if bad:
        sys.exit("The game doesn't compile:\n" + "\n".join(bad[:10]))


def free_ports(first: int, n: int) -> list[int]:
    """n ports from `first` up that nothing is holding (the game's ENet host is UDP)."""
    ports: list[int] = []
    p = first
    while len(ports) < n and p < first + 500:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.bind(("", p))
            ports.append(p)
        except OSError:
            pass
        p += 1
    return ports


def commit() -> str:
    """The checkout's commit, marked "+changes" if the game's files have uncommitted edits."""
    try:
        head = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(["git", "status", "--porcelain", "--", "scripts", "assets", "project.godot"], cwd=REPO,
                               capture_output=True, text=True).stdout.strip()
        return head + (" +changes" if dirty else "")
    except OSError:
        return "unknown"


def used_by(shots: dict, take: str) -> list[str]:
    """The outputs and stills cut from a take: what has to be re-cut and rebuilt when it's re-recorded."""
    outs = [o for o, spec in shots["outputs"].items() if any(c["take"] == take for c in spec["cuts"])]
    return outs + [f"still {s}" for s, spec in shots.get("stills", {}).items() if spec["take"] == take]


def record(godot: str, proj: Path, out: Path, name: str, take: dict, common: list[str], port: int) -> str:
    avi = out / f"{name}.avi"
    log = out / f"{name}.log"
    frames = int(take["frames"])
    cmd = [godot, "--path", str(proj), "--write-movie", str(avi), "--fixed-fps", "30", "--quit-after", str(frames), "--"]
    # the user's own settings.cfg is loaded: make sure the sound is up (it can be saved at 0)
    cmd += ["--offscreen", "--set=volume:0.8", f"--port={port}", *common, *take["args"]]
    t0 = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        f.write(" ".join(cmd) + "\n\n")
        f.flush()
        try:
            subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=300 + frames * 0.8)
        except subprocess.TimeoutExpired:
            return f"{name}: TIMED OUT after {time.time() - t0:.0f} s (see {log})"
    text = log.read_text(encoding="utf-8", errors="replace")
    if "Couldn't create an ENet host" in text:
        return f"{name}: FAILED: port {port} was taken, so the game ran as an observer. Record it again."
    errors = [line for line in text.splitlines() if "SCRIPT ERROR" in line]
    if "Done recording movie" not in text or not avi.exists():
        return f"{name}: FAILED (see {log})"
    n = len(Avi(avi))
    # what game this was: later, `git log COMMIT..HEAD -- scripts assets` says what's changed since
    stamp = {"take": name, "frames": n, "recorded": time.strftime("%Y-%m-%d %H:%M"), "commit": commit(),
             "args": take["args"], "common_args": common}
    (out / f"{name}.json").write_text(json.dumps(stamp, indent=2) + "\n", encoding="utf-8")
    note = f", {len(errors)} script errors in the log" if errors else ""
    return f"{name}: {n} frames ({n / 30:.1f} s) in {time.time() - t0:.0f} s -> {avi}{note}"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("takes", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--jobs", type=int, default=3, help="takes recorded at once (they share the GPU)")
    ap.add_argument("--godot")
    ap.add_argument("--work")
    ap.add_argument("--no-sync", action="store_true", help="reuse the project copy as it is")
    ap.add_argument("--port", type=int, default=8700, help="first port to try; each take gets the next free one")
    a = ap.parse_args()

    shots = json.loads((SKILL / "shots.json").read_text(encoding="utf-8"))
    takes: dict = shots["takes"]
    if a.list:
        work = work_dir(a.work)
        for name, t in takes.items():
            have = ""
            stamp = work / "takes" / f"{name}.json"
            if (work / "takes" / f"{name}.avi").exists():
                s = json.loads(stamp.read_text(encoding="utf-8")) if stamp.exists() else {}
                have = f", recorded {s.get('recorded', '?')} at {s.get('commit', '?')}"
            print(f"{name}  ({t['frames']} frames{have})  {' '.join(t['args'])}")
            print(f"    shows: {', '.join(t.get('shows', []))}")
            print(f"    feeds: {', '.join(used_by(shots, name)) or 'nothing yet'}")
            print(f"    {t.get('about', '')}")
        print(f"(takes folder: {work / 'takes'})")
        return
    names = list(takes) if a.all else a.takes
    unknown = [n for n in names if n not in takes]
    if unknown or not names:
        sys.exit(f"Unknown takes: {unknown}" if unknown else "Name some takes, or --all (--list shows them).")

    godot = find_godot(a.godot)
    work = work_dir(a.work)
    proj = work / "project"
    out = work / "takes"
    out.mkdir(exist_ok=True)
    if not a.no_sync or not (proj / "project.godot").exists():
        sync(godot, proj)

    ports = free_ports(a.port, len(names))
    print(f"recording {len(names)} take(s), {a.jobs} at a time, on ports {ports} ...", flush=True)
    with cf.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
        jobs = [
            ex.submit(record, godot, proj, out, n, takes[n], shots.get("common_args", []), ports[i])
            for i, n in enumerate(names)
        ]
        for j in cf.as_completed(jobs):
            print(j.result(), flush=True)


if __name__ == "__main__":
    main()
