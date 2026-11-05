"""Bake CC0 branch cards and a four-view distant-tree atlas (Pillow + Godot)."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import urllib.request
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/foliage"
CACHE = ROOT / "build/terrain/foliage-source"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    args = parser.parse_args()
    for source in json.loads((ASSETS / "sources.json").read_text()):
        path = CACHE / source["file"]
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            urllib.request.urlretrieve(source["url"], path)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source["sha256"], path
    for name, channel, box in [("fir", "twig", (300, 410, 665, 805)), ("broadleaf", "leaves", (550, 35, 875, 645))]:
        color = Image.open(CACHE / f"{name}-{channel}_diff.jpg").convert("RGBA")
        color.putalpha(Image.open(CACHE / f"{name}-{channel}_alpha.jpg").convert("L"))
        color = color.crop(box)
        color.thumbnail((512, 512), Image.Resampling.LANCZOS)
        color.save(ASSETS / f"{name}.png")
    model = CACHE / "models/fir_tree_01_1k.gltf"
    scene = json.loads(model.read_text())
    scene["scenes"][0]["nodes"] = [2]
    model.with_name("fir-c.gltf").write_text(json.dumps(scene))
    subprocess.run([args.godot, "--path", str(ROOT), "--script", "tools/bake_forest_atlas.gd"], cwd=ROOT, check=True)
    with Image.open(ASSETS / "fir_impostor.png") as atlas:
        assert atlas.size == (1024, 1024)
        for x, y in [(0, 0), (512, 0), (0, 512), (512, 512)]:
            assert atlas.crop((x, y, x + 512, y + 512)).getchannel("A").getbbox(), "Every view must contain a tree"


if __name__ == "__main__":
    main()
