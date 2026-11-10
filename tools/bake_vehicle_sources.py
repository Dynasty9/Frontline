#!/usr/bin/env python3
"""Bake CC0 source maps into shared linear RGBA vehicle data (numpy/Pillow).

R height, G centered roughness, B corrosion coverage, A centered luminance.
Color is converted from sRGB before extracting luminance; faction colors remain
in the shader. Source normals are not copied: height drives triplanar relief.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/vehicles/sources'
OUT = ROOT / 'assets/vehicles/surfaces'
SETS = {'coating': 'Metal027', 'rubber': 'Rubber004', 'canvas': 'Fabric036',
        'metal': 'Metal009', 'tread': 'DiamondPlate009', 'oxidized': 'Metal053B'}


def read(asset, channel):
    path = SOURCE / asset / f'{asset}_1K-JPG_{channel}.jpg'
    with Image.open(path) as image:
        mode = 'RGB' if channel == 'Color' else 'L'
        return np.asarray(image.convert(mode).resize((512, 512), Image.Resampling.LANCZOS), dtype=float) / 255


def main():
    manifest = json.loads((SOURCE / 'sources.json').read_text())
    for asset in manifest['assets']:
        for entry in asset['files']:
            data = (SOURCE / entry['file']).read_bytes()
            if hashlib.sha256(data).hexdigest() != entry['sha256']:
                raise ValueError(f"Changed source: {entry['file']}")
    results = []
    for name, asset in SETS.items():
        height = read(asset, 'Displacement')
        rough = read(asset, 'Roughness')
        color = read(asset, 'Color')
        linear = np.where(color <= 0.04045, color / 12.92, ((color + 0.055) / 1.055) ** 2.4)
        luma = linear @ np.array([0.2126, 0.7152, 0.0722])
        # Retain source contrast without turning JPEG noise into exaggerated relief.
        height = height - height.mean() + 0.5
        rough = rough - rough.mean() + 0.5
        tone = np.clip(luma / max(float(luma.mean()), 0.01), 0.5, 1.5) - 0.5
        corrosion = 1 - read(asset, 'Metalness') if name == 'oxidized' else np.zeros_like(height)
        packed = np.stack([height, rough, corrosion, tone], axis=-1)
        path = OUT / f'{name}.png'
        Image.fromarray(np.round(np.clip(packed, 0, 1) * 255).astype('uint8')).save(path)
        results.append({'file': path.name, 'source': asset,
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT / 'baked-sources.json').write_text(json.dumps({'size': 512, 'maps': results}, indent=2) + '\n')
    print('Baked six CC0-derived vehicle maps.')


if __name__ == '__main__':
    main()
