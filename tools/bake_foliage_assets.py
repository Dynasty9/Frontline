"""Bake CC0 branch cards and a four-variant distant-tree atlas (Pillow + NumPy + Godot)."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import urllib.request
import numpy as np
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
    scene["scenes"][0]["nodes"] = [0, 1, 2]
    model.with_name("fir-variants.gltf").write_text(json.dumps(scene))
    subprocess.run([args.godot, "--path", str(ROOT), "--script", "tools/bake_forest_atlas.gd"], cwd=ROOT, check=True)
    with Image.open(ASSETS / "fir_impostor.png") as atlas:
        assert atlas.size == (1024, 1024)
        for x, y in [(0, 0), (512, 0), (0, 512), (512, 512)]:
            assert atlas.crop((x, y, x + 512, y + 512)).getchannel("A").getbbox(), "Every view must contain a tree"
        pixels = np.asarray(atlas.convert("RGBA")).copy()
    # MSAA resolves colour against transparent black; cutouts need straight-alpha colour.
    alpha = pixels[..., 3:4].astype(np.float32) / 255.0
    rgb = pixels[..., :3].astype(np.float32) / 255.0
    linear = np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)
    linear = np.clip(linear / np.maximum(alpha, 1 / 255.0), 0, 1)
    straight = np.where(linear <= .0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - .055)
    partial = (alpha[..., 0] > 0) & (alpha[..., 0] < 1)
    before = pixels[..., :3][partial].copy()
    pixels[..., :3][partial] = np.rint(straight[partial] * 255).astype(np.uint8)
    assert partial.any() and np.mean(pixels[..., :3][partial]) > np.mean(before), "Resolved canopy edges must lose their black fringe"
    Image.fromarray(pixels, "RGBA").save(ASSETS / "fir_impostor.png")


if __name__ == "__main__":
    main()
