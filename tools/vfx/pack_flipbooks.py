#!/usr/bin/env python3
"""Pack Blender's linear RGBA coefficients and bidirectional optical flow.

Requires numpy, opencv-python-headless and OpenEXR. Source volumes and intermediate
renders stay outside the repository; only the compact atlases ship.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import cv2
import OpenEXR
import numpy as np

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--kind', choices=['dust', 'fuel'], required=True)
p.add_argument('--preview', action='store_true', help='Reuse the low view while the high view renders')
p.add_argument('--oidn', type=Path, help='Path to Intel Open Image Denoise 2.5 oidnDenoise (offline only)')
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
cv2.setNumThreads(2)
temporary = tempfile.TemporaryDirectory(prefix='frontline-vfx-')

def denoise(rgb):
    if a.oidn is None or rgb.max() < 0.0001:
        return rgb
    source = Path(temporary.name) / 'input.pfm'
    target = Path(temporary.name) / 'output.pfm'
    cv2.imwrite(str(source), rgb[..., ::-1])
    subprocess.run([str(a.oidn), '--hdr', str(source), '-o', str(target),
                    '--threads', '2', '--affinity', '0', '--is', '1'],
                   check=True, stdout=subprocess.DEVNULL)
    return cv2.imread(str(target), cv2.IMREAD_UNCHANGED)[..., ::-1]

def read(path):
    if path.suffix == '.exr':
        with OpenEXR.File(str(path)) as source:
            rgba = source.channels()['RGBA'].pixels.astype(np.float32)
        # OpenEXR stores associated alpha; PNG stores straight alpha.
        rgba[..., :3] /= np.maximum(rgba[..., 3:4], 0.001)
        return rgba
    im = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if im is None:
        raise FileNotFoundError(path)
    divisor = 1.0 if im.dtype == np.float32 else (65535.0 if im.dtype == np.uint16 else 255.0)
    return im[..., [2, 1, 0, 3]].astype(np.float32) / divisor

atlases = {}
bounds = np.zeros((1, 128, 4), dtype=np.uint8)
for view, pitch in enumerate([35, 65]):
    if a.preview:
        pitch = 35
    positives, negatives, features = [], [], []
    for frame in range(64):
        pos = read(a.source / f'{a.kind}_{pitch}_positive_{frame:03d}.png')
        neg = read(a.source / f'{a.kind}_{pitch}_negative_{frame:03d}.png')
        alpha = (pos[..., 3] + neg[..., 3]) * 0.5
        ys, xs = np.where(alpha > 1.0 / 255.0)
        if len(xs):
            # Outward rounding keeps fine wisps. Runtime unions adjacent
            # frames/views and pads for the optical-flow reconstruction.
            lo = np.floor(np.array([xs.min(), ys.min()]) / alpha.shape[0] * 255)
            hi = np.ceil(np.array([xs.max() + 1, ys.max() + 1]) / alpha.shape[0] * 255)
            bounds[0, frame + view * 64] = np.concatenate([lo, hi]).astype(np.uint8)
        else:
            bounds[0, frame + view * 64] = 128
        pos[..., :3] *= alpha[..., None]
        neg[..., :3] *= alpha[..., None]
        pos[..., :3] = denoise(pos[..., :3])
        neg[..., :3] = denoise(neg[..., :3])
        pos[..., 3] = alpha
        if a.kind == 'fuel':
            emission = read(a.source / f'{a.kind}_{pitch}_emission_{frame:03d}.exr')
            neg[..., 3] = (1.0 - np.exp(-np.mean(emission[..., :3], axis=2) * 0.15)) * alpha
        else:
            neg[..., 3] = 0
        # A small spatial reconstruction filter removes isolated Monte Carlo
        # specks; it doesn't smear the animation in time or soften its silhouette.
        pos = cv2.GaussianBlur(pos, (3, 3), 0.45)
        neg = cv2.GaussianBlur(neg, (3, 3), 0.45)
        # Transparent guard pixels prevent adjacent atlas tiles from leaking
        # into faint border wisps through filtering and compressed mip levels.
        edge = np.minimum(np.arange(len(alpha)), np.arange(len(alpha))[::-1])
        guard = np.clip(np.minimum(edge[:, None], edge[None, :]) / 2.0, 0, 1)
        pos *= guard[..., None]
        neg *= guard[..., None]
        positives.append(pos)
        negatives.append(neg)
        features.append(np.uint8(np.clip(alpha * 0.5 + (pos[..., :3].sum(2) + neg[..., :3].sum(2)) * 0.12, 0, 1) * 255))
    tile = positives[0].shape[0]
    if not atlases:
        atlases = {key: np.zeros((tile * 8, tile * 16, 4), dtype=np.uint8) for key in ['positive', 'negative', 'motion']}
    flow = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    for frame in range(64):
        following = min(frame + 1, 63)
        forward = flow.calc(features[frame], features[following], None)
        backward = flow.calc(features[following], features[frame], None)
        motion = np.concatenate([forward, backward], axis=2) / (tile * 0.125) * 0.5 + 0.5
        x, y = (frame % 8 + view * 8) * tile, (frame // 8) * tile
        for key, im in [('positive', positives[frame]), ('negative', negatives[frame]), ('motion', motion)]:
            atlases[key][y:y+tile, x:x+tile] = np.uint8(np.clip(im * 255 + 0.5, 0, 255))
for key, atlas in atlases.items():
    path = a.output / f'{a.kind}_{key}.png'
    channels = [2, 1, 0] if a.kind == 'dust' and key == 'negative' else [2, 1, 0, 3]
    cv2.imwrite(str(path), atlas[..., channels], [cv2.IMWRITE_PNG_COMPRESSION, 9])
    print(path, path.stat().st_size, flush=True)
path = a.output / f'{a.kind}_bounds.png'
cv2.imwrite(str(path), bounds[..., [2, 1, 0, 3]])
print(path, path.stat().st_size, flush=True)
print(json.dumps({'kind': a.kind, 'tile': tile, 'frames': 64, 'elevations': [35, 65],
                  'preview': a.preview, 'denoised': a.oidn is not None}))
temporary.cleanup()
