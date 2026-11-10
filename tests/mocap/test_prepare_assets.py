"""Asset preparation retains import identity while enabling 3D texture mipmaps."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


class TexturePreparationTest(unittest.TestCase):
    def test_fresh_and_repeat_import(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / 'tests/mocap/prepare_assets.py'
            script.parent.mkdir(parents=True)
            shutil.copyfile(Path(__file__).with_name('prepare_assets.py'), script)
            archive = root / 'sample.zip'
            asset = 'FBX/MotusMan/test.png'
            with zipfile.ZipFile(archive, 'w') as pack:
                pack.writestr(asset, b'asset bytes')
            command = [sys.executable, str(script), str(archive)]
            subprocess.run(command, check=True, capture_output=True)
            texture = root / 'assets/local_mocap' / asset
            sidecar = texture.with_suffix('.png.import')
            self.assertIn('mipmaps/generate=true', sidecar.read_text())
            sidecar.write_text('[remap]\nimporter="texture"\nuid="uid://preserved"\n[params]\nmipmaps/generate=false\ncompress/mode=2\n')
            for _ in range(2):
                subprocess.run(command, check=True, capture_output=True)
                settings = sidecar.read_text()
                self.assertEqual(settings.count('mipmaps/generate=true'), 1)
                self.assertIn('uid="uid://preserved"', settings)
                self.assertIn('compress/mode=2', settings)
                self.assertEqual(texture.read_bytes(), b'asset bytes')


if __name__ == '__main__':
    unittest.main()
