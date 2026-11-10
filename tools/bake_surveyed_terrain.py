"""Bake surveyed Alpine ridge stamps from pinned Mapzen Terrarium tiles.

Requires Pillow, NumPy and GODOT pointing to Godot 4.7. Downloads are cached;
the game only needs assets/terrain/surveyed_alps.res. See its LICENSE.md.
"""
from pathlib import Path
import hashlib
import json
import math
import os
import subprocess

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "build/terrain/alpine-dem-source"
SOURCES = ROOT / "assets/terrain/surveyed_sources.json"


def bake():
    CACHE.mkdir(parents=True, exist_ok=True)
    sources = json.loads(SOURCES.read_text(encoding="utf-8"))
    for site in dict.fromkeys(s["site"] for s in sources):
        tiles = [s for s in sources if s["site"] == site]
        assert len(tiles) == 9 and len({(s["x"], s["y"]) for s in tiles}) == 9
        mosaic = np.zeros((768, 768), dtype=np.float32)
        min_x, min_y = min(s["x"] for s in tiles), min(s["y"] for s in tiles)
        for tile in tiles:
            path = CACHE / tile["file"]
            if not path.exists():
                subprocess.run(["curl", "-sS", "-L", "--fail", "--max-time", "90",
                                "-o", str(path), tile["url"]], check=True)
            assert hashlib.sha256(path.read_bytes()).hexdigest() == tile["sha256"], path
            rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
            assert rgb.shape == (256, 256, 3)
            height = rgb[..., 0] * 256 + rgb[..., 1] + rgb[..., 2] / 256 - 32768
            x, y = (tile["x"] - min_x) * 256, (tile["y"] - min_y) * 256
            mosaic[y:y + 256, x:x + 256] = height
        origin = tiles[0]
        scale = 2 ** origin["z"]
        latitude = math.radians(origin["latitude"])
        px = (origin["longitude"] + 180) / 360 * scale
        py = (1 - math.asinh(math.tan(latitude)) / math.pi) / 2 * scale
        x, y = round((px - min_x) * 256) - 256, round((py - min_y) * 256) - 256
        field = mosaic[y:y + 512, x:x + 512].copy()
        assert field.shape == (512, 512) and np.isfinite(field).all()
        assert field.max() - field.min() > 1500, "Each stamp must retain a full mountain relief"
        base = np.quantile(field, .12)
        field = np.maximum(field - base, 0) / (field.max() - base)
        z, x = np.mgrid[-1:1:512j, -1:1:512j]
        fade = np.clip((np.sqrt(x * x + z * z) - .65) / .35, 0, 1)
        field *= 1 - fade * fade * (3 - 2 * fade)
        assert np.isfinite(field).all() and 0 <= field.min() <= field.max() <= 1
        assert not np.any(field[[0, -1], :]) and not np.any(field[:, [0, -1]])
        field.astype("<f4").tofile(CACHE / (site + ".r32"))
    subprocess.run([os.environ.get("GODOT", "godot"), "--headless", "--path", str(ROOT),
                    "--script", "tools/pack_surveyed_terrain.gd"], check=True)


if __name__ == "__main__":
    bake()
