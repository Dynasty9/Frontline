"""Small copies of the released changelog's pictures, for the website's lists.

    changelog_thumbs.py DEST

The Updates page shows a release's changes as a list, each with a little
picture, and a change's gallery as a strip of them: 96 pixels wide on the
page. The pictures themselves are full-size screenshots (some PNGs of several
MB), so the site's build makes a copy of each, WIDTH pixels wide, at
DEST/<version>/<change>/<file>.jpg (the original's name and extension, then
.jpg, so a.png and a.jpg never meet). The site asks for that copy and falls
back to the picture itself where there isn't one (web/src/lib/changelog.ts).
Only released versions: the site's changelog is what's been released.
"""

import pathlib
import sys

from PIL import Image

WIDTH = 384  # twice the largest the lists show, for sharp screens
PICTURES = {".jpg", ".jpeg", ".png", ".webp"}

root = pathlib.Path(__file__).resolve().parents[2] / "changelog"
destination = pathlib.Path(sys.argv[1])
made = 0
for path in sorted(root.glob("v*/*/*")):
    if path.suffix.lower() not in PICTURES:
        continue
    out = destination / path.relative_to(root).parent / (path.name + ".jpg")
    out.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(path) as picture:
        small = picture.convert("RGB")
        small.thumbnail((WIDTH, WIDTH * 4), Image.LANCZOS)
        small.save(out, "JPEG", quality=74, optimize=True, progressive=True)
    made += 1
print(f"{made} changelog thumbnails in {destination}")
