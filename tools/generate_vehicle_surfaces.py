"""Bake seamless linear material-data maps; no photographs or runtime generation.

Requires numpy, scipy and Pillow. Run from any directory. R = height,
G = roughness variation around 0.5, B = sparse wear mask. All filters wrap.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = Path(__file__).resolve().parents[1] / "assets/vehicles/surfaces"
SIZE = 512
rng = np.random.default_rng(7319)
y, x = np.mgrid[:SIZE, :SIZE] / SIZE


def noise(sigma):
    field = gaussian_filter(rng.random((SIZE, SIZE)), sigma, mode="wrap")
    return np.clip((field - field.mean()) / max(field.std(), 1e-6) * 0.16 + 0.5, 0, 1)


def save(name, height, roughness, wear):
    data = np.stack([height, roughness, wear], axis=-1)
    Image.fromarray(np.round(np.clip(data, 0, 1) * 255).astype("uint8")).save(OUT / f"{name}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    fine, broad = noise(0.8), noise(12)
    chips = np.clip((noise(2.5) - 0.76) * 5, 0, 1)
    save("coating", fine * 0.65 + noise(2) * 0.35, broad * 0.65 + fine * 0.35, chips)
    save("rubber", noise(1.5) * 0.8 + broad * 0.2, noise(5), np.zeros_like(x))
    warp = np.cos(x * np.pi * 2 * 64)
    weft = np.cos(y * np.pi * 2 * 64)
    weave = 0.5 + 0.22 * warp * weft + 0.12 * (warp + weft)
    save("canvas", weave * 0.85 + fine * 0.15, 0.4 + weave * 0.2, np.zeros_like(x))
    brushed = noise((0.6, 30))
    save("metal", brushed * 0.75 + fine * 0.25, brushed * 0.45 + broad * 0.55, chips)
    aggregate = np.clip((noise(1.4) - 0.35) * 1.8, 0, 1)
    save("nonslip", aggregate, 0.3 + aggregate * 0.4, chips)
    soot = noise(4)
    save("char", noise(1) * 0.4 + soot * 0.6, soot, np.clip((broad - 0.55) * 2, 0, 1))
    print(f"Baked six {SIZE}x{SIZE} packed surface maps to {OUT}")


if __name__ == "__main__":
    main()
