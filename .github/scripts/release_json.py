"""The release.json a release bakes into the website and the matchmaker.

    python3 release_json.py VERSION ZIP_DIR [PUBLISHED]  > release.json

ZIP_DIR holds Frontline-windows.zip and Frontline-linux.zip as published.
The download URLs are GitHub's fixed ones for the release's tag, and the
checksums are what the game's updater checks a download against.
"""

import hashlib
import json
import os
import sys
from datetime import datetime, timezone

PLATFORMS = ("windows", "linux")


def main() -> None:
    version, zip_dir = sys.argv[1], sys.argv[2]
    published = sys.argv[3] if len(sys.argv) > 3 else datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    repo = os.environ.get("GITHUB_REPOSITORY", "Dynasty9/Frontline")
    tag = f"v{version}"
    assets = {}
    for p in PLATFORMS:
        name = f"Frontline-{p}.zip"
        path = os.path.join(zip_dir, name)
        with open(path, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        assets[p] = {
            "name": name,
            "url": f"https://github.com/{repo}/releases/download/{tag}/{name}",
            "size": os.path.getsize(path),
            "sha256": digest,
        }
    json.dump(
        {
            "version": version,
            "tag": tag,
            "name": f"Frontline {tag}",
            "published": published,
            "url": f"https://github.com/{repo}/releases/tag/{tag}",
            "assets": assets,
        },
        sys.stdout,
        indent=2,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
