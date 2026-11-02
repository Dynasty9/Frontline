"""Offline alpine material packing and reusable terrain forms (Pillow + NumPy).

Run from the repository root. Source downloads are checksum-verified and cached
under build/terrain; only the packed assets are needed by the game.
"""
from pathlib import Path
import hashlib
import json
import subprocess

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/terrain"
CACHE = ROOT / "build/terrain"
SOURCES = {s["file"]: s for s in json.loads((ASSETS / "sources.json").read_text())}


def source(name):
    path = ASSETS / name
    if not path.exists():
        path = CACHE / name
        if not path.exists():
            subprocess.run(["curl", "-sS", "-L", "--fail", "--max-time", "90",
                            "-o", str(path), SOURCES[name]["source"]], check=True)
    assert hashlib.sha256(path.read_bytes()).hexdigest() == SOURCES[name]["sha256"], name
    return Image.open(path).resize((1024, 1024), Image.Resampling.LANCZOS)


def fractured_rock(color, height, normal, ao, rough):
    """Bake metre-scale joints over the photograph; all channels share the relief."""
    size = color.width
    columns, rows = 7, 3
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    u = x * columns + .22 * np.sin(y * np.pi * 4) + .09 * np.sin(x * np.pi * 6)
    v = y * rows + .18 * np.sin(x * np.pi * 4)
    cells = np.random.default_rng(431).uniform(.15, .85, (rows, columns, 2))
    ix, iy = np.floor(u).astype(int), np.floor(v).astype(int)
    first = np.full(x.shape, 100.0)
    second = first.copy()
    for dz in [-1, 0, 1]:
        for dx in [-1, 0, 1]:
            offset = cells[(iy + dz) % rows, (ix + dx) % columns]
            distance = (u - ix - dx - offset[..., 0]) ** 2 + (v - iy - dz - offset[..., 1]) ** 2
            second = np.minimum(second, np.maximum(first, distance))
            first = np.minimum(first, distance)
    edge = np.sqrt(second) - np.sqrt(first)
    joint = np.exp(-(edge * 13) ** 2)
    # Broad irregular slabs meet at recessed joints, not painted dark lines alone.
    relief = .20 * (1 - joint) + .10 * np.cos(np.sqrt(first) * 3.5)
    texel_metres = 48.0 / size
    dx = (np.roll(relief, -1, 1) - np.roll(relief, 1, 1)) / (2 * texel_metres)
    dy = (np.roll(relief, -1, 0) - np.roll(relief, 1, 0)) / (2 * texel_metres)
    n = np.asarray(normal, dtype=np.float32) / 127.5 - 1
    xy = n[..., :2] / np.maximum(n[..., 2:3], .35) - np.stack([dx, dy], axis=-1)
    nz = 1 / np.sqrt(1 + np.sum(xy * xy, axis=-1))
    mapped = np.dstack([xy * nz[..., None], nz])
    assert np.isfinite(mapped).all() and np.max(np.abs(np.linalg.norm(mapped, axis=-1) - 1)) < .0001
    def gray(values):
        return Image.fromarray(np.clip(values, 0, 255).astype(np.uint8), 'L')
    color = Image.fromarray(np.clip(np.asarray(color) * (1 - joint[..., None] * .06), 0, 255).astype(np.uint8), 'RGB')
    height = gray(np.asarray(height) * .72 + np.clip(relief / .30, 0, 1) * 255 * .28)
    normal = Image.fromarray(np.clip((mapped + 1) * 127.5, 0, 255).astype(np.uint8), 'RGB')
    ao = gray(np.asarray(ao) * (1 - joint * .25))
    rough = gray(np.asarray(rough) * (1 - joint * .15) + joint * 255 * .15)
    assert np.ptp(relief) > .20 and np.max(np.abs(dx)) > .2
    return color, height, normal, ao, rough


def materials():
    for name in ["rock_face_03", "aerial_rocks_02", "aerial_grass_rock"]:
        color = source(name + "_diff_2k.jpg").convert("RGB")
        height = source(name + "_disp_2k.jpg").convert("L")
        normal = source(name + "_nor_gl_2k.jpg").convert("RGB")
        ao = source(name + "_ao_2k.jpg").convert("L")
        rough = source(name + "_rough_2k.jpg").convert("L")
        if name == "rock_face_03":
            color, height, normal, ao, rough = fractured_rock(color, height, normal, ao, rough)
        # Colour RGB is sRGB; alpha and every channel of surface remain linear data.
        Image.merge("RGBA", (*color.split(), height)).save(ASSETS / (name + "_color_height.png"))
        Image.merge("RGBA", (*normal.split()[:2], ao, rough)).save(ASSETS / (name + "_surface.png"))
        assert np.ptp(np.asarray(height)) > 30 and np.ptp(np.asarray(ao)) > 30


def forms():
    # Broad rock masses, with asymmetric escarpments and sloping backs. Heights
    # are baked once; the game rotates/scales these forms before erosion.
    z, x = np.mgrid[-1:1:33j, -1:1:33j]
    ridge = np.clip(1 - np.abs(x + .12 * np.sin(z * 4)), 0, 1)
    escarpment = np.clip((x + .62) / .16, 0, 1) * np.clip((1 - x) / 1.05, 0, 1)
    buttress = escarpment * (.74 + .26 * np.cos(z * 8 + x * 1.8) ** 4)
    cirque = np.clip(1 - np.abs(np.sqrt((x * .9) ** 2 + (z + .18) ** 2) - .60) / .34, 0, 1)
    cirque *= np.clip((z + .85) / .5, 0, 1)
    saddle = ridge * (.64 + .28 * np.cos(z * 3.8) ** 2)
    kit = {"buttress": buttress, "cirque": cirque, "saddle": saddle}
    lines = ['[gd_resource type="Resource" format=3]', '', '[resource]',
             'resource_name = "Baked alpine forms"', 'metadata/width = 33']
    for name, field in kit.items():
        # Cut narrow drainage seams into the faces without making isolated cones.
        field *= .94 + .06 * np.sin(x * 23 + z * 7) ** 2
        assert np.isfinite(field).all() and field.min() >= 0 and field.max() <= 1
        values = ", ".join(f"{v:.5f}" for v in field.flat)
        lines.append(f'metadata/{name} = PackedFloat32Array({values})')
    (ASSETS / "alpine_forms.tres").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    CACHE.mkdir(parents=True, exist_ok=True)
    materials()
    forms()
    print("Packed three height/normal/AO/roughness materials and three alpine forms.")
