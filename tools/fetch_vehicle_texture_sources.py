#!/usr/bin/env python3
"""Verify or restore the pinned CC0 vehicle authoring sources (standard library)."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1] / "assets/vehicles/sources"


def matches(data, entry):
    return len(data) == entry["bytes"] and hashlib.sha256(data).hexdigest() == entry["sha256"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Check local files without downloading")
    args = parser.parse_args()
    count = 0
    for asset in json.loads((ROOT / "sources.json").read_text())["assets"]:
        pending = []
        for entry in asset["files"]:
            target = (ROOT / entry["file"]).resolve()
            if not target.is_relative_to(ROOT.resolve()):
                raise ValueError("Manifest path escapes source directory")
            if not target.exists() or not matches(target.read_bytes(), entry):
                pending.append((entry, target))
            count += 1
        if not pending:
            continue
        if args.verify:
            raise SystemExit(f"Missing or changed files in {asset['id']}")
        request = urllib.request.Request(asset["download"], headers={
            "User-Agent": "Frontline texture sources (https://github.com/Dynasty9/Frontline)"
        })
        with urllib.request.urlopen(request, timeout=120) as response:
            archive = response.read()
        if hashlib.sha256(archive).hexdigest() != asset["archive_sha256"]:
            raise SystemExit(f"Archive checksum mismatch for {asset['id']}")
        with zipfile.ZipFile(io.BytesIO(archive)) as pack:
            verified = []
            for entry, target in pending:
                members = [name for name in pack.namelist() if Path(name).name == target.name]
                if len(members) != 1:
                    raise ValueError(f"Missing or ambiguous archive member: {target.name}")
                data = pack.read(members[0])
                if not matches(data, entry):
                    raise ValueError(f"File checksum mismatch: {target.name}")
                verified.append((target, data))
            for target, data in verified:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
    print(f"Verified {count} texture maps and preview images.")


if __name__ == "__main__":
    main()
