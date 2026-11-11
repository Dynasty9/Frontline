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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clip", type=Path)
    parser.add_argument("--label", required=True)
    parser.add_argument("--note", required=True)
    parser.add_argument("--folder", type=Path, default=ROOT / "build/trailer-review")
    parser.add_argument("--takes", type=Path, help="Capture folder containing the record.py take manifests")
    args = parser.parse_args()
    recipe = json.loads(RECIPE.read_text())
    captures = {}
    if args.takes:
        edit = recipe["outputs"]["reel"]
        sources = edit["cuts"] + ([edit["score"]] if "score" in edit else [])
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
    versions.append(dict(label=args.label, note=args.note, file=target.name, sha256=digest, frames=int(video["nb_frames"]),
                         date=datetime.now(timezone.utc).isoformat(timespec="seconds")))
    data = json.dumps(versions, ensure_ascii=False, indent=2)
    manifest.with_suffix(".tmp").write_text(data + "\n")
    manifest.with_suffix(".tmp").replace(manifest)
    # Embed the ledger so the viewer also works when opened directly from disk.
    page = (HERE / "viewer.html").read_text().replace("__VERSIONS__", data.replace("<", "\\u003c"))
    output = args.folder / "index.html"
    output.with_suffix(".tmp").write_text(page)
    output.with_suffix(".tmp").replace(output)
    print(output)


if __name__ == "__main__":
    main()
