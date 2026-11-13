"""Pack CC0 town scans into mipmapped colour and normal/roughness pairs (Pillow)."""
from pathlib import Path
import hashlib
import json
import sys
import urllib.request

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/town"
CACHE = ROOT / "build/terrain/town-source"


def mean_colour(image):
    """Measure linear albedo, then store its sRGB value for source_color uniforms."""
    result = []
    for band in image.convert("RGB").split():
        total = 0.0
        for value, count in enumerate(band.histogram()):
            srgb = value / 255
            linear = srgb / 12.92 if srgb <= .04045 else ((srgb + .055) / 1.055) ** 2.4
            total += linear * count
        linear = total / (image.width * image.height)
        result.append(12.92 * linear if linear <= .0031308 else 1.055 * linear ** (1 / 2.4) - .055)
    return result


NAMES = ["aerial_asphalt_01", "concrete_pavement", "leafy_grass", "roof_tiles", "weathered_planks", "concrete_floor_01", "asphalt_02", "brick_wall_001", "plastered_wall", "tree_bark_03", "gravelly_sand", "road_damaged_clean", "rocky_trail_02", "dirt_aerial_03"]
COLOUR_ONLY = {"asphalt_02", "dirt_aerial_03"}  # repair patches share the road relief; the aerial dirt only shades the trail


def main(only=None):
    """Bake every scan, or only those named (python tools/bake_town_assets.py rocky_trail_02 ...)."""
    names = only or NAMES
    CACHE.mkdir(parents=True, exist_ok=True)
    sources = json.loads((ASSETS / "sources.json").read_text())
    for source in sources:
        if not any(source["file"].startswith(name + "_") for name in names):
            continue
        path = CACHE / source["file"]
        if not path.exists():
            urllib.request.urlretrieve(source["url"], path)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source["sha256"], path
    means = {}
    means_path = ASSETS / "material_means.tres"
    for line in means_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("metadata/"):
            means[line.split(" = ")[0][len("metadata/"):]] = line
    for name in names:
        size = (2048, 2048) if name == "aerial_asphalt_01" else (1024, 1024)
        def read(channel):
            return Image.open(CACHE / f"{name}_{channel}_2k.jpg").resize(size, Image.Resampling.LANCZOS)
        read("diff").convert("RGB").save(ASSETS / f"{name}_color.jpg", quality=95)
        rgb = mean_colour(Image.open(ASSETS / f"{name}_color.jpg"))
        means[name] = f'metadata/{name} = Color({rgb[0]:.7f}, {rgb[1]:.7f}, {rgb[2]:.7f}, 1)'
        if name in COLOUR_ONLY:
            continue
        surface = read("nor_gl").convert("RGBA")
        surface.putalpha(read("rough").convert("L"))
        surface.save(ASSETS / f"{name}_surface.png")
    lines = ['[gd_resource type="Resource" format=3]', '', '[resource]'] + [means[name] for name in NAMES if name in means]
    means_path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main(sys.argv[1:])
