"""Append a fixed-length trailer revision and rebuild its offline comparison viewer."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RECIPE = ROOT / ".agents/skills/website-footage/shots.json"
# The published homepage reel from v1.0.5. Its Git blob stays the same as main moves.
PUBLISHED_REEL = "9659c85134cd271b589f6a0f29a37564a1b72e71"


def write_viewer(folder, versions):
    original = folder / "published-homepage.mp4"
    if not original.exists() and (git := shutil.which("git")):
        source = subprocess.run([git, "cat-file", "blob", PUBLISHED_REEL], cwd=ROOT, capture_output=True)
        if source.returncode == 0:
            original.with_suffix(".tmp").write_bytes(source.stdout)
            original.with_suffix(".tmp").replace(original)
    # The historical reference is selectable but does not consume an edition number.
    cuts = versions
    if original.exists():
        cuts = [dict(label="Published homepage · 32.9 s", file=original.name, frames=987,
                     note="The homepage reel before this series. Choose edition 00 to see the start of the 24-hour run."), *versions]
    data = json.dumps(cuts, ensure_ascii=False).replace("<", "\\u003c")
    output = folder / "index.html"
    output.with_suffix(".tmp").write_text((HERE / "viewer.html").read_text().replace("__VERSIONS__", data))
    output.with_suffix(".tmp").replace(output)
    print(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clip", type=Path)
    parser.add_argument("--label", required=True)
    parser.add_argument("--note", required=True)
    parser.add_argument("--at", type=float, help="Seconds into the finished cut where the change starts")
    parser.add_argument("--folder", type=Path, default=ROOT / "build/trailer-review")
    parser.add_argument("--takes", type=Path, help="Capture folder containing the record.py take manifests")
    args = parser.parse_args()
    recipe = json.loads(RECIPE.read_text())
    captures = {}
    if args.takes:
        edit = recipe["outputs"]["reel"]
        sources = edit["cuts"] + [edit[key] for key in ("score", "end_title") if key in edit]
        for source in sources:
            name = source["take"]
            if name not in captures:
                captures[name] = json.loads((args.takes / (name + ".json")).read_text())
    streams = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-of", "json", str(args.clip)
    ]))["streams"]
    video = next(s for s in streams if s["codec_type"] == "video")
    if (video["nb_frames"], video["avg_frame_rate"]) != ("720", "30/1"):
        parser.error("Comparison cuts must contain 720 frames at 30 fps (24 seconds).")
    frames = int(video["nb_frames"])
    if args.at is not None and not 0 <= args.at < frames / 30:
        parser.error("--at must identify a frame in the finished cut.")
    if not any(s["codec_type"] == "audio" for s in streams):
        parser.error("The trailer must have an audio track.")
    args.folder.mkdir(exist_ok=True, parents=True)
    manifest = args.folder / "versions.json"
    versions = json.loads(manifest.read_text()) if manifest.exists() else []
    with args.clip.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if any(v["sha256"] == digest for v in versions):
        parser.error("These exact frames and audio have already been archived.")
    stem = f"{len(versions):02d}-{digest[:8]}"
    target = args.folder / (stem + ".mp4")
    shutil.copyfile(args.clip, target)
    shutil.copyfile(RECIPE, target.with_suffix(".json"))
    if captures:
        target.with_suffix(".takes.json").write_text(json.dumps(captures, indent=2) + "\n")
    if args.clip.with_suffix(".vtt").exists():
        shutil.copyfile(args.clip.with_suffix(".vtt"), target.with_suffix(".vtt"))
    versions.append(dict(label=args.label, note=args.note, file=target.name, sha256=digest, frames=frames,
                         date=datetime.now(timezone.utc).isoformat(timespec="seconds")))
    if args.at is not None:
        versions[-1]["change_frame"] = min(frames - 1, round(args.at * 30))
    data = json.dumps(versions, ensure_ascii=False, indent=2)
    manifest.with_suffix(".tmp").write_text(data + "\n")
    manifest.with_suffix(".tmp").replace(manifest)
    write_viewer(args.folder, versions)


if __name__ == "__main__":
    main()
