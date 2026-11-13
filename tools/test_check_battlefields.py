import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from check_battlefields import check


class BattlefieldPackages(unittest.TestCase):
    def test_valid_damaged_and_stale_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts/game").mkdir(parents=True)
            (root / "scripts/game/battlefield_map.gd").write_text(
                'const FORMAT := 1\nconst SOURCES := ["scripts/generator.gd"]\n'
            )
            (root / "scripts/battlefields.gd").write_text('{"key": "sample"}')
            source = root / "scripts/generator.gd"
            source.write_bytes(b"one\r\ntwo\r\n")
            package = root / "assets/battlefields/sample.flmap"
            package.parent.mkdir(parents=True)
            package.write_bytes(b"sample map")
            manifest = {
                "format": 1,
                "engine": "4.7.2-stable (official)",
                "key": "sample",
                "sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
                "sources": {"scripts/generator.gd": hashlib.sha256(b"one\ntwo\n").hexdigest()},
            }
            package.with_suffix(".flmap.json").write_text(json.dumps(manifest))
            self.assertEqual(check(root), [])
            self.assertEqual(check(root, "4.7.2"), [])
            self.assertIn("rebake with Godot", check(root, "4.8")[0])
            source.write_bytes(b"changed")
            self.assertIn("rebake", check(root)[0])
            source.write_bytes(b"one\ntwo\n")
            package.write_bytes(b"damaged")
            self.assertIn("checksum", check(root)[0])
            package.unlink()
            self.assertTrue(check(root))


if __name__ == "__main__":
    unittest.main()
