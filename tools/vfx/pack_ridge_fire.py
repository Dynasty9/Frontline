"""Pack density, flame and incident sunlight into the ridge stage’s slice sheets."""

import argparse
import io
from pathlib import Path
import struct

import numpy as np
from PIL import Image
from scipy.ndimage import shift

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
files = sorted(args.source.glob("*.npz"))
if not files:
    parser.error("The input directory contains no smoke samples")

levels = np.array([63, 63, 31], dtype="f")
sun = np.array([0.14, 0.807, 0.574])
metres_per_voxel = np.array([12 / 68, 6 / 34, 14 / 80])
with args.output.open("wb") as output:
    output.write(struct.pack("<I", len(files)))
    for path in files:
        with np.load(path) as sample:
            density = sample["density"].astype("f") / 255
            flame = sample["flame"].astype("f") / 255
        depth = np.zeros_like(density)
        for distance in np.arange(0.25, 6, 0.35):
            offset = -sun * distance / metres_per_voxel
            depth += 0.35 * shift(
                density, offset, order=1, mode="constant", prefilter=False
            )
        light = np.exp(-3.2 * depth)
        light[density + flame < 0.001] = 1
        values = np.stack((np.sqrt(density), np.sqrt(flame), light), axis=-1)
        values = np.round(values * levels) / levels
        # Eight columns of horizontal slices. The final four tiles are empty.
        slices = np.zeros((72, 34, 80, 3), dtype="u1")
        slices[:68] = np.round(values * 255).astype("u1")
        sheet = (
            slices.reshape(9, 8, 34, 80, 3)
            .transpose(0, 2, 1, 3, 4)
            .reshape(306, 640, 3)
        )
        record = io.BytesIO()
        Image.fromarray(sheet).save(record, format="WEBP", lossless=True, method=4)
        output.write(struct.pack("<I", len(record.getbuffer())))
        output.write(record.getbuffer())
