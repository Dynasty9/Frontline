"""Bake CC0 woodland scans. Requires Pillow, NumPy, Blender and Godot 4.7."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import shutil
import urllib.request
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/foliage/woodland'
CACHE = ROOT / 'build/woodland/source'

def write_image(image, path):
    if path.exists():
        with Image.open(path) as previous:
            if image.mode == previous.mode and image.size == previous.size and image.tobytes() == previous.tobytes():
                return
    image.save(path, optimize=True)

def textures():
    shutil.copyfile(CACHE / 'butterfly/aglais_cc0.jpg', ASSETS / 'small-tortoiseshell.jpg')
    for name in ['dead_tree_trunk_02', 'tree_stump_01', 'fern_02', 'nettle_plant', 'rock_moss_set_01', 'grass_medium_01', 'shrub_02']:
        print('WOODLAND_TEXTURE', name, flush=True)
        source = CACHE / name
        color = Image.open(next((source / 'textures').glob('*_diff_2k.jpg'))).convert('RGBA')
        if (source / 'alpha.png').exists():
            alpha = Image.open(source / 'alpha.png')
            if alpha.mode in ('I', 'I;16'):
                alpha = alpha.point(lambda value: value / 257)
            color.putalpha(alpha.convert('L'))
        color.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
        write_image(color, ASSETS / (name + '-color.png'))
        normal = Image.open(next((source / 'textures').glob('*_nor_gl_2k.jpg'))).convert('RGBA')
        arm_file = next((source / 'textures').glob('*_arm_2k.jpg'), None)
        arm = Image.open(arm_file).convert('RGB') if arm_file else None
        roughness = arm.getchannel('G') if arm else Image.open(next((source / 'textures').glob('*_rough_2k.jpg'))).convert('L')
        occlusion = arm.getchannel('R') if arm else Image.new('L', normal.size, 255)
        normal = Image.merge('RGBA', (normal.getchannel('R'), normal.getchannel('G'), occlusion, roughness))
        normal.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        write_image(normal, ASSETS / (name + '-surface.png'))
    for name, part in [('pine_sapling_small', 'twig'), ('pine_sapling_small', 'bark')]:
        print('WOODLAND_TEXTURE', name, part, flush=True)
        source = CACHE / name
        color = Image.open(source / 'textures' / f'{name}_{part}_diff_2k.jpg').convert('RGBA')
        if part == 'twig':
            alpha = Image.open(source / 'alpha.png')
            if alpha.mode in ('I', 'I;16'):
                alpha = alpha.point(lambda value: value / 257)
            color.putalpha(alpha.convert('L'))
        write_image(color, ASSETS / f'{name}-{part}-color.png')
        normal = Image.open(source / 'textures' / f'{name}_{part}_nor_gl_2k.jpg').convert('RGBA')
        arm = Image.open(source / 'textures' / f'{name}_{part}_arm_2k.jpg').convert('RGB')
        normal = Image.merge('RGBA', (normal.getchannel('R'), normal.getchannel('G'), arm.getchannel('R'), arm.getchannel('G')))
        normal.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        write_image(normal, ASSETS / f'{name}-{part}-surface.png')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--blender', default='blender')
    parser.add_argument('--textures-only', action='store_true')
    args = parser.parse_args()
    ASSETS.mkdir(parents=True, exist_ok=True)
    opener = urllib.request.build_opener()
    opener.addheaders = [('User-Agent', 'Frontline asset baker')]
    urllib.request.install_opener(opener)
    for source in json.loads((ASSETS / 'sources.json').read_text()):
        print('WOODLAND_VERIFY', source['file'], flush=True)
        file = CACHE / source['file']
        file.parent.mkdir(parents=True, exist_ok=True)
        if not file.exists():
            urllib.request.urlretrieve(source['url'], file)
        with file.open('rb') as stream:
            assert hashlib.file_digest(stream, 'sha256').hexdigest() == source['sha256'], file
    print('WOODLAND_SOURCES verified', flush=True)
    textures()
    if not args.textures_only:
        subprocess.run([args.blender, '-b', '--python-exit-code', '1', '--python', str(ROOT / 'tools/woodland/meshes.py')], cwd=ROOT, check=True)
        subprocess.run([args.godot, '--headless', '--path', str(ROOT / 'tools/woodland'), '--script', 'meshes.gd'], cwd=ROOT, check=True)

if __name__ == '__main__':
    main()
