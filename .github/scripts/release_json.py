"""The release.json a release bakes into the website and the matchmaker.

    python3 release_json.py VERSION BUILD_DIR [PUBLISHED]  > release.json

BUILD_DIR holds Frontline-windows.zip, Frontline-macos.zip and Frontline-linux.zip
as published, and the installers: Frontline-windows-setup.exe and
Frontline-macos.dmg. The download URLs are GitHub's fixed ones for the release's
tag. `assets` are the zips, which is what the game's updater downloads and
checks against these checksums; `installers` are what the website offers first,
and releases from before the installers have none.
"""

import hashlib
import json
import os
import sys
from datetime import datetime, timezone

PLATFORMS = ("windows", "macos", "linux")
INSTALLERS = {"windows": "Frontline-windows-setup.exe", "macos": "Frontline-macos.dmg"}


def main() -> None:
    version, build_dir = sys.argv[1], sys.argv[2]
    published = sys.argv[3] if len(sys.argv) > 3 else datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    repo = os.environ.get("GITHUB_REPOSITORY", "Dynasty9/Frontline")
    tag = f"v{version}"

    def download(name: str) -> dict:
        path = os.path.join(build_dir, name)
        with open(path, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        return {
            "name": name,
            "url": f"https://github.com/{repo}/releases/download/{tag}/{name}",
            "size": os.path.getsize(path),
            "sha256": digest,
        }

    assets = {p: download(f"Frontline-{p}.zip") for p in PLATFORMS}
    installers = {p: download(name) for p, name in INSTALLERS.items() if os.path.exists(os.path.join(build_dir, name))}
    json.dump(
        {
            "version": version,
            "tag": tag,
            "name": f"Frontline {tag}",
            "published": published,
            "url": f"https://github.com/{repo}/releases/tag/{tag}",
            "assets": assets,
            "installers": installers,
        },
        sys.stdout,
        indent=2,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
