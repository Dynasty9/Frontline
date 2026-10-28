"""Identify the observer protocol shipped beside the website."""
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
protocol = re.search(r"const NET_VERSION := (\d+)", (root / "scripts/autoload/net.gd").read_text())
assert protocol, "NET_VERSION missing"
destination = pathlib.Path(sys.argv[1])
assert (destination / "index.wasm").is_file() and (destination / "index.pck").is_file(), "Export the game first"
(destination / "viewer.json").write_text(json.dumps({"format": 1, "protocol": int(protocol[1]), "manual": 1}) + "\n")
