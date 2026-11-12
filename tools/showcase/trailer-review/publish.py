"""Publish compact screening copies of an existing archive to the website."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / "web/public/media/edits"


def encode(args):
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", *map(str, args)], check=True)


def frame_count(path):
    return int(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0",
                                        "-show_entries", "stream=nb_frames", "-of", "csv=p=0", path], text=True))


# Earlier archive entries predate the change-frame field. These screening cues
# lead to the moment described in each original edit note.
EARLY_CUES = {"00": 0.4, "01": 2.0, "02": 0.7, "03": 21.8, "04": 5.4, "05": 13.5,
              "06": 15.1, "07": 20.73, "08": 19.0, "09": 11.8, "10": 5.17, "11": 15.1,
              "12": 12.7, "13": 9.97, "14": 7.07, "15": 1.7, "16": 18.6}


def publish(archive, version, homepage_digest):
    source = archive / version["file"]
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if version.get("sha256", digest) != digest:
        raise ValueError(f"Archived movie has changed: {source}")
    stem = source.stem
    item = dict(id=stem.split("-")[0], label=version["label"], note=version["note"], frames=version.get("frames") or frame_count(source))
    if item["id"] in EARLY_CUES:
        item["change_frame"] = round(EARLY_CUES[item["id"]] * 30)
    if "change_frame" in version:
        item["change_frame"] = version["change_frame"]
    target = DEST / source.name
    if digest == homepage_digest:
        # Keep the archival address stable when a future homepage reel replaces this one.
        shutil.copyfile(source, target)
    elif not target.exists():
        pending = target.with_suffix(".tmp.mp4")
        encode(["-i", source, "-vf", "scale=640:-2", "-c:v", "libx264", "-threads", 2,
                "-preset", "fast", "-crf", 30, "-c:a", "aac", "-b:a", "80k", "-movflags", "+faststart", pending])
        pending.replace(target)
    item["file"] = "/media/edits/" + target.name
    poster = DEST / (stem + ".jpg")
    at = item.get("change_frame", 30) / 30
    if item["id"] == "30":
        at = 19.4  # The jet against the ridge, just before the underwing cut.
    encode(["-ss", at, "-i", source, "-frames:v", 1, "-vf", "scale=960:-2", "-q:v", 4, poster])
    item["poster"] = "/media/edits/" + poster.name
    for key, suffix in [("captions", ".vtt"), ("recipe", ".json")]:
        companion = source.with_suffix(suffix)
        if key == "captions" and stem == "published-homepage" and not companion.exists():
            # Captions shipped with the historical homepage film.
            (DEST / companion.name).write_bytes(subprocess.check_output([
                "git", "cat-file", "blob", "565d45261d9772146f2e934084f1eb65b9543a5c"], cwd=ROOT))
            item[key] = "/media/edits/" + companion.name
        elif companion.is_file():
            shutil.copyfile(companion, DEST / companion.name)
            item[key] = "/media/edits/" + companion.name
    if "recipe" in item:
        edit = json.loads(source.with_suffix(".json").read_text())["outputs"]["reel"]
        item["cuts"] = len(edit["cuts"])
    return item


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    versions = json.loads((args.archive / "versions.json").read_text())
    # Publish the milestones used by the website. The offline viewer serves every edit.
    milestones = {"00", "07", "13", "21", "26", "30"}
    versions = [v for v in versions if v["file"].split("-", 1)[0] in milestones]
    found = {v["file"].split("-", 1)[0] for v in versions}
    if found != milestones:
        parser.error("Archive lacks requested editions: " + ", ".join(sorted(milestones - found)))
    original = args.archive / "published-homepage.mp4"
    if original.exists():
        frames = frame_count(original)
        versions.insert(0, dict(file=original.name, label="Published homepage", frames=int(frames),
                                note="The public homepage trailer before this editing series began."))
    DEST.mkdir(parents=True, exist_ok=True)
    homepage_digest = hashlib.sha256((DEST.parent / "reel.mp4").read_bytes()).hexdigest()
    with ThreadPoolExecutor(3) as pool:
        items = list(pool.map(lambda v: publish(args.archive, v, homepage_digest), versions))
    (ROOT / "web/src/lib/trailer-editions.json").write_text(json.dumps(items, indent=2, ensure_ascii=False) + "\n")
    print(f"Published {len(items)} playable cuts to {DEST}")


if __name__ == "__main__":
    main()
