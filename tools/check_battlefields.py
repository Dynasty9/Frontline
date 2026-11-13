"""Reject missing, damaged or stale prepared maps before packaging the game."""

import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT, engine_version=None):
    catalogue = (root / "scripts/battlefields.gd").read_text(encoding="utf-8")
    keys = re.findall(r'"key":\s*"([a-z0-9-]+)"', catalogue)
    implementation = (root / "scripts/game/battlefield_map.gd").read_text(encoding="utf-8")
    source_block = re.search(r"const SOURCES := \[(.*?)\]", implementation, re.S)
    expected_sources = set(re.findall(r'"([^"]+)"', source_block[1]))
    expected_format = int(re.search(r"const FORMAT := (\d+)", implementation)[1])
    errors = []
    for key in keys:
        package = root / "assets/battlefields" / f"{key}.flmap"
        try:
            manifest = json.loads(package.with_suffix(".flmap.json").read_text())
            if manifest["key"] != key:
                errors.append(f"{key}: manifest names another map")
            if engine_version and manifest.get("engine") != f"{engine_version}-stable (official)":
                errors.append(f"{key}: rebake with Godot {engine_version}")
            if manifest["format"] != expected_format or set(manifest["sources"]) != expected_sources:
                errors.append(f"{key}: package format or source list changed; rebake")
            if hashlib.sha256(package.read_bytes()).hexdigest() != manifest["sha256"]:
                errors.append(f"{key}: package checksum differs")
            if not manifest["sources"]:
                errors.append(f"{key}: no source identities")
            for source, expected in manifest["sources"].items():
                contents = (root / source).read_bytes().replace(b"\r\n", b"\n")
                if hashlib.sha256(contents).hexdigest() != expected:
                    errors.append(f"{key}: rebake after changing {source}")
        except (OSError, ValueError, KeyError, TypeError) as exc:
            errors.append(f"{key}: {exc}")
    if not keys:
        errors.append("The battlefield catalogue is empty")
    return errors


if __name__ == "__main__":
    failures = check(engine_version=os.environ.get("GODOT_VERSION"))
    print("\n".join(failures) if failures else "BATTLEFIELDS: packages and source identities verified")
    sys.exit(bool(failures))
