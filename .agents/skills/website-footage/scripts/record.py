"""Record takes of the game, off-screen, with Godot's movie writer.

    record.py --list                      what takes shots.json defines
    record.py --render reel [hero ...]    record and assemble finished clips and posters
    record.py TAKE [TAKE ...]             record those takes
    record.py --all                       record every take
      [--jobs 3] [--godot PATH] [--work DIR] [--no-sync] [--port 8700]

Each take is a run of the game with its own flags (shots.json), written frame
by frame at a fixed 30 fps to WORK/takes/TAKE.avi (MJPEG + the game's sound),
so a slow render never drops a frame: a take of N frames is N/30 seconds of
game time however long it takes to draw (about 5 frames a second, slower with
several running).

The game runs from a private copy of the project (WORK/project) with a
private render surface on macOS or an off-screen window on other desktops. The copy
is refreshed from the repo (and re-imported) before recording unless
--no-sync, so it records the game as this checkout has it. Every run gets its
own free port: a game that can't open its port carries on as an observer
without saying so (its log shows "Couldn't create an ENet host"), and other
games on this machine may hold the usual ones.

Godot: --godot, else $GODOT, else `godot` on the PATH. Use the editor binary so the movie writer can draw frames.
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
        sys.exit("No Godot: pass --godot PATH or set GODOT to the Godot 4.7 editor binary.")
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
    if r.returncode or bad:
        sys.exit("Godot import failed:\n" + ("\n".join(bad[:10]) or r.stderr[-1000:]))
    (proj / ".capture-revision").write_text(commit(), encoding="utf-8")


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
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(["git", "status", "--porcelain", "--", "scripts", "assets", "tests", "project.godot", "main.tscn"], cwd=REPO,
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
    embedded = sys.platform == "darwin"
    display = ["--embedded", "--debug", "--ignore-error-breaks"] if embedded else []
    cmd = [godot, *display, "--path", str(proj), "--write-movie", str(avi), "--fixed-fps", "30", "--quit-after", str(frames), "--"]
    # the user's own settings.cfg is loaded: make sure the sound is up (it can be saved at 0)
    if not embedded:
        cmd.append("--offscreen")
    cmd += ["--set=volume:0.8", f"--port={port}", *common, *take["args"]]
    t0 = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        f.write(" ".join(cmd) + "\n\n")
        f.flush()
        try:
            result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=300 + frames * 0.8,
                           env={**os.environ, **take.get("env", {})})
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"{name} timed out (see {log})") from None
    text = log.read_text(encoding="utf-8", errors="replace")
    if "Couldn't create an ENet host" in text:
        raise RuntimeError(f"{name}: port {port} was taken (see {log})")
    errors = [line for line in text.splitlines() if "SCRIPT ERROR" in line]
    if result.returncode or errors or "Done recording movie" not in text or not avi.exists():
        raise RuntimeError(f"{name}: capture failed (see {log})")
    n = len(Avi(avi))
    if n != frames:
        raise RuntimeError(f"{name}: expected {frames} frames, got {n} (see {log})")
    # what game this was: later, `git log COMMIT..HEAD -- scripts assets` says what's changed since
    revision = proj / ".capture-revision"
    stamp = {"take": name, "frames": n, "recorded": time.strftime("%Y-%m-%d %H:%M"),
             "commit": revision.read_text().strip() if revision.exists() else "unknown",
             "args": take["args"], "common_args": common, "env": take.get("env", {})}
    (out / f"{name}.json").write_text(json.dumps(stamp, indent=2) + "\n", encoding="utf-8")
    return f"{name}: {n} frames ({n / 30:.1f} s) in {time.time() - t0:.0f} s -> {avi}"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("takes", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--render", nargs="+", metavar="OUTPUT", help="record the takes and build the named clips or stills")
    ap.add_argument("--install", action="store_true", help="also copy the rendered outputs into the website")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--jobs", type=int, default=3, help="takes recorded at once (they share the GPU)")
    ap.add_argument("--godot")
    ap.add_argument("--work")
    ap.add_argument("--no-sync", action="store_true", help="reuse the project copy as it is")
    ap.add_argument("--port", type=int, default=8700, help="first port to try; each take gets the next free one")
    a = ap.parse_args()

    shots = json.loads((SKILL / "shots.json").read_text(encoding="utf-8"))
    takes: dict = shots["takes"]
    if a.render and (a.all or a.takes or a.list):
        ap.error("Use --render with output names, or give take names separately.")
    if a.install and not a.render:
        ap.error("--install requires --render OUTPUT.")
    if a.list:
        print("Clips: " + ", ".join(shots["outputs"]))
        print("Stills: " + ", ".join(shots.get("stills", {})))
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
    if a.render:
        names = []
        for name in a.render:
            clip = shots["outputs"].get(name)
            still = shots.get("stills", {}).get(name)
            if not clip and not still:
                ap.error(f"Unknown output {name!r} (--list shows available names).")
            if clip:
                names.extend(cut["take"] for cut in clip["cuts"])
            if still:
                names.append(still["take"])
        names = list(dict.fromkeys(names))
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
    if len(ports) != len(names):
        sys.exit("Not enough free recording ports. Try a different --port.")
    print(f"recording {len(names)} take(s), {a.jobs} at a time, on ports {ports} ...", flush=True)
    with cf.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
        jobs = [
            ex.submit(record, godot, proj, out, n, takes[n], shots.get("common_args", []), ports[i])
            for i, n in enumerate(names)
        ]
        for j in cf.as_completed(jobs):
            try:
                print(j.result(), flush=True)
            except RuntimeError as error:
                sys.exit(str(error))
    if a.render:
        cmd = [sys.executable, str(HERE / "build.py"), *a.render, "--work", str(work)]
        if a.install:
            cmd.append("--install")
        subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()
