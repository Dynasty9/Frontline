"""Pack CC0 town scans into mipmapped colour and normal/roughness pairs (Pillow)."""
from pathlib import Path
import hashlib
import json
import urllib.request

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/town"
CACHE = ROOT / "build/terrain/town-source"


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    sources = json.loads((ASSETS / "sources.json").read_text())
    for source in sources:
        path = CACHE / source["file"]
        if not path.exists():
            urllib.request.urlretrieve(source["url"], path)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source["sha256"], path
    for name in ["aerial_asphalt_01", "concrete_pavement", "leafy_grass"]:
        size = (2048, 2048) if name == "aerial_asphalt_01" else (1024, 1024)
        def read(channel):
            return Image.open(CACHE / f"{name}_{channel}_2k.jpg").resize(size, Image.Resampling.LANCZOS)
        read("diff").convert("RGB").save(ASSETS / f"{name}_color.jpg", quality=95)
        surface = read("nor_gl").convert("RGBA")
        surface.putalpha(read("rough").convert("L"))
        surface.save(ASSETS / f"{name}_surface.png")


if __name__ == "__main__":
    main()
