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
                            "-A", "FrontlineAssetBaker/1.0",
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


# Meadow turf, 90 m drone survey of grassland and eroded soil follow the gravel layer in the array.
MATERIALS = ["rock_face_03", "aerial_rocks_02", "aerial_grass_rock", "snow_02", "forest_leaves_02",
             "grass_ground", "rocky_terrain_02", "dirt_aerial_02", "brown_mud"]


def materials(names=MATERIALS):
    for name in names:
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
    rng = np.random.default_rng(1907)

    def noise(u, v, scale):
        grid = rng.uniform(-1, 1, (64, 64))
        u, v = (u + 3) * scale, (v + 3) * scale
        ix, iz = np.floor(u).astype(int), np.floor(v).astype(int)
        fx, fz = u - ix, v - iz
        fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
        a = grid[iz % 64, ix % 64] * (1 - fx) + grid[iz % 64, (ix + 1) % 64] * fx
        b = grid[(iz + 1) % 64, ix % 64] * (1 - fx) + grid[(iz + 1) % 64, (ix + 1) % 64] * fx
        return a * (1 - fz) + b * fz

    # Broad shoulders carry branching gullies; avoid parallel sinusoidal flutes.
    warp = noise(x, z, 2.2)
    u, v = x + warp * .14, z + noise(x, z, 1.8) * .16
    ridge = np.clip(1 - np.abs(u + .16 * np.sin(v * 3)), 0, 1)
    escarpment = np.clip((u + .62) / .28, 0, 1) * np.clip((1 - u) / 1.05, 0, 1)
    crest = .38 + .62 * np.sqrt(np.clip(1 - (v + .15) ** 2, 0, 1))
    buttress = escarpment * crest
    cirque = np.clip(1 - np.abs(np.sqrt((u * .9) ** 2 + (v + .18) ** 2) - .60) / .34, 0, 1)
    cirque *= np.clip((v + .85) / .5, 0, 1) * (.76 + .24 * crest)
    saddle = ridge * (.50 + .38 * np.abs(v - .12))
    drainage = np.abs(noise(u + warp * .2, v * .38, 6.0))
    tributaries = np.abs(noise(u + warp * .35, v * .65, 12.0))
    incision = .13 * np.exp(-drainage * 12) + .045 * np.exp(-tributaries * 15)
    kit = {"buttress": buttress, "cirque": cirque, "saddle": saddle}
    lines = ['[gd_resource type="Resource" format=3]', '', '[resource]',
             'resource_name = "Baked alpine forms"', 'metadata/width = 33']
    for name, field in kit.items():
        # Cut narrow drainage seams into the faces without making isolated cones.
        field = np.clip(field * (1 - incision) + noise(x, z, 9.0) * .012 * field, 0, 1)
        assert np.isfinite(field).all() and field.min() >= 0 and field.max() <= 1
        values = ", ".join(f"{v:.5f}" for v in field.flat)
        lines.append(f'metadata/{name} = PackedFloat32Array({values})')
    (ASSETS / "alpine_forms.tres").write_text("\n".join(lines) + "\n")


def _periodic_fbm(n, rng, octaves=6, base=3):
    """Exactly periodic fBm from integer-frequency Fourier components."""
    out = np.zeros((n, n))
    y, x = np.mgrid[0:n, 0:n] / n
    amp = 1.0
    for octave in range(octaves):
        f = base * 2 ** octave
        for _ in range(8):
            kx, ky = rng.integers(-f, f + 1, 2)
            if kx == 0 and ky == 0:
                continue
            out += amp * np.sin(2 * np.pi * (kx * x + ky * y) + rng.uniform(0, 2 * np.pi)) / np.hypot(kx, ky) * f
        amp *= 0.5
    return out / np.abs(out).max()


def eroded_face(n=256, seed=7, slope=0.5, relief=6.0):
    """Rain-cut gullies on a steep rock face, as a tileable layer (eroded_face_*).

    Droplets run down a tilted, wrapping slope and carve branching channels. The
    pack is flipped so the channels run down the texture's v axis: the ground
    shader's side projections map v to world up, so they run downhill on any face.
    """
    rng = np.random.default_rng(seed)
    h = _periodic_fbm(n, rng) * relief  # (cells; the tilt adds -slope per row)
    radius = 2
    offsets = [(dx, dy) for dy in range(-radius, radius + 1) for dx in range(-radius, radius + 1)
               if dx * dx + dy * dy <= radius * radius + 0.5]
    weights = np.array([max(0.0, radius + 0.5 - np.hypot(dx, dy)) for dx, dy in offsets])
    weights /= weights.sum()
    inertia, capacity_k, deposit_k, erode_k, evaporation, gravity = 0.1, 3.0, 0.3, 0.25, 0.03, 4.0

    def sample(px, py):
        ix, iy = int(px) % n, int(py) % n
        fx, fy = px - int(px), py - int(py)
        x1, y1 = (ix + 1) % n, (iy + 1) % n
        a, b, c, e = h[iy, ix], h[iy, x1], h[y1, ix], h[y1, x1]
        return ix, iy, x1, y1, fx, fy, (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + e * fx) * fy - slope * py,             (b - a) * (1 - fy) + (e - c) * fy, (c - a) * (1 - fx) + (e - b) * fx - slope

    for _ in range(int(n * n * 0.8)):
        px, py = rng.uniform(0, n), rng.uniform(0, n)
        dirx = diry = 0.0
        speed, water, sediment = 1.0, 1.0, 0.0
        for _ in range(64):
            ix, iy, x1, y1, fx, fy, here, gx, gy = sample(px, py)
            dirx = dirx * inertia - gx * (1 - inertia)
            diry = diry * inertia - gy * (1 - inertia)
            length = (dirx * dirx + diry * diry) ** 0.5
            if length < 1e-9:
                break
            dirx /= length
            diry /= length
            nx, ny = px + dirx, py + diry
            fall = sample(nx, ny)[6] - here
            capacity = max(-fall * speed * water * capacity_k, 0.01)
            if sediment > capacity or fall > 0:
                amount = min(fall, sediment) if fall > 0 else (sediment - capacity) * deposit_k
                sediment -= amount
                h[iy, ix] += amount * (1 - fx) * (1 - fy)
                h[iy, x1] += amount * fx * (1 - fy)
                h[y1, ix] += amount * (1 - fx) * fy
                h[y1, x1] += amount * fx * fy
            else:
                amount = min((capacity - sediment) * erode_k, -fall, 0.06)
                for (ox, oy), weight in zip(offsets, weights):
                    h[(iy + oy) % n, (ix + ox) % n] -= amount * weight
                sediment += amount
            speed = max(0.0, speed * speed - fall * gravity) ** 0.5
            water *= 1 - evaporation
            px, py = nx % n, ny % n
            if water < 0.05:
                break
    h = np.flipud(h)  # channels down the v axis (see above)
    size = 1024
    height = np.asarray(Image.fromarray(((h - h.min()) / np.ptp(h)).astype(np.float32), "F")
                        .resize((size, size), Image.Resampling.BICUBIC), dtype=np.float64)
    height = np.clip(height, 0.0, 1.0)
    # Normals in the scans' OpenGL convention (green toward the top of the image).
    ddx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    ddy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    strength = 1.0 / max(np.percentile(np.abs(ddx), 98), 1e-6) * 0.45
    normal = np.dstack([-ddx * strength, ddy * strength, np.ones_like(height)])
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    # Channels sit in shade and hold damp grit; ribs between them catch the light.
    freq = np.fft.fftfreq(size)
    kernel = np.exp(-2.0 * (np.pi * 6.0) ** 2 * (freq[:, None] ** 2 + freq[None, :] ** 2))
    blur = np.real(np.fft.ifft2(np.fft.fft2(height) * kernel))  # (wraps, so the tile stays seamless)
    cavity = np.clip(0.5 + (height - blur) * 6.0, 0.0, 1.0)
    ao = np.clip(0.55 + cavity * 0.45, 0.0, 1.0)
    shade = np.clip(0.35 + cavity * 0.45, 0.0, 1.0)

    def byte(values):
        return Image.fromarray(np.clip(values * 255.0 + 0.5, 0, 255).astype(np.uint8), "L")
    colour = byte(shade)
    Image.merge("RGBA", (colour, colour, colour, byte(height))).save(ASSETS / "eroded_face_color_height.png")
    Image.merge("RGBA", (byte(normal[..., 0] * 0.5 + 0.5), byte(normal[..., 1] * 0.5 + 0.5), byte(ao),
                         byte(np.full_like(height, 0.9)))).save(ASSETS / "eroded_face_surface.png")
    assert np.ptp(height) > 0.9 and np.ptp(cavity) > 0.3


if __name__ == "__main__":
    import sys
    CACHE.mkdir(parents=True, exist_ok=True)
    # Named materials re-pack only those layers; with no names everything is rebuilt.
    chosen = [name for name in sys.argv[1:] if name in MATERIALS]
    if chosen or "eroded_face" not in sys.argv[1:]:
        materials(chosen or MATERIALS)
    if "eroded_face" in sys.argv[1:] or len(sys.argv) == 1:
        eroded_face()
    if len(sys.argv) == 1:
        forms()
    print("Packed the requested terrain layers.")
