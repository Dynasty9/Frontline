"""Identify and compress the browser runtime shipped beside the website."""
import gzip
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
protocol = re.search(r"const NET_VERSION := (\d+)", (root / "scripts/autoload/net.gd").read_text())
assert protocol, "NET_VERSION missing"
destination = pathlib.Path(sys.argv[1])
assert (destination / "index.wasm").is_file() and (destination / "index.pck").is_file(), "Export the game first"
# Compress once during the build, rather than on every first visit to a model or battle.
download = 0
for filename in ("index.wasm", "index.pck", "index.js"):
    source = destination / filename
    packed = gzip.compress(source.read_bytes(), mtime=0)
    source.with_suffix(source.suffix + ".gz").write_bytes(packed)
    download += len(packed)
# bytes: what a first visit downloads (compressed), which the site says before it starts one
manifest = {"format": 1, "protocol": int(protocol[1]), "manual": 3, "bytes": download}
(destination / "viewer.json").write_text(json.dumps(manifest) + "\n")
