#!/usr/bin/env python3
"""Bake shared linear tangent normals from the bundled, checksum-pinned CC0 sources.

Photographic normals are retained rather than reconstructed from the compressed
height channel. Original nonslip/char maps use periodic central differences.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from bake_vehicle_sources import SOURCE, OUT, SETS


def main():
    for asset in json.loads((SOURCE / 'sources.json').read_text())['assets']:
        for entry in asset['files']:
            path = SOURCE / entry['file']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
    records = []
    for name in [*SETS, 'nonslip', 'char']:
        if name in SETS:
            asset = SETS[name]
            path = SOURCE / asset / f'{asset}_1K-JPG_NormalGL.jpg'
            rgb = np.asarray(Image.open(path).convert('RGB').resize((512, 512), Image.Resampling.LANCZOS), dtype=float) / 255
            normal = rgb * 2 - 1
        else:
            height = np.asarray(Image.open(OUT / f'{name}.png').convert('RGB'), dtype=float)[:, :, 0] / 255
            dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 2
            dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 2
            normal = np.stack([-dx, dy, np.ones_like(dx)], axis=-1)
        normal /= np.maximum(np.linalg.norm(normal, axis=-1, keepdims=True), 1e-6)
        path = OUT / f'{name}_normal.png'
        Image.fromarray(np.round(np.clip(normal * 0.5 + 0.5, 0, 1) * 255).astype('uint8')).save(path)
        records.append({'file': path.name, 'source': SETS.get(name, 'Original MIT material height'), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT / 'baked-normals.json').write_text(json.dumps({'size':512, 'encoding':'linear OpenGL tangent normals', 'maps':records},indent=2)+'\n')


if __name__ == '__main__':
    main()
