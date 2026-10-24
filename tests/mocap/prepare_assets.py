"""Extract only the supplied FBX demo assets into an ignored local directory.
Usage: python tests/mocap/prepare_assets.py /path/to/MCO_Demo_Pack_v2.zip
"""
from pathlib import Path
import re
import shutil
import sys
import zipfile

root = Path(__file__).resolve().parents[2]
destination = root / 'assets' / 'local_mocap'
prefixes = ('FBX/MotusMan/', 'FBX/Animation/Rifle/', 'FBX/Animation/Mobility/')
count = 0
with zipfile.ZipFile(sys.argv[1]) as archive:
    for info in archive.infolist():
        if info.is_dir() or not info.filename.startswith(prefixes):
            continue
        if Path(info.filename).suffix.lower() not in ('.fbx', '.jpg', '.png', '.txt'):
            continue
        output = (destination / info.filename).resolve()
        if not output.is_relative_to(destination.resolve()):
            raise ValueError(f'Unsafe archive path: {info.filename}')
        output.parent.mkdir(parents=True, exist_ok=True)
        with archive.open(info) as source, output.open('wb') as target:
            shutil.copyfileobj(source, target)
        if output.suffix.lower() in ('.jpg', '.png'):
            # Runtime-bound materials do not trigger Godot's editor 3D detection.
            sidecar = output.with_suffix(output.suffix + '.import')
            settings = sidecar.read_text(encoding='utf-8') if sidecar.exists() else (
                '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
            )
            settings = re.sub(r'(?m)^mipmaps/generate=.*\n?', '', settings)
            settings = settings.replace('[params]', '[params]\nmipmaps/generate=true', 1)
            sidecar.write_text(settings, encoding='utf-8')
        count += 1
print(f'Extracted {count} evaluation files into {destination}')
print('Import this project in Godot before running tests/mocap/demo.tscn.')
print('The vendor assets remain git-ignored; no license to redistribute them is assumed.')
