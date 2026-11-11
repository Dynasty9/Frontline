"""Pack the film's ground marks and the time each tread first pressed the soil."""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("take", type=Path)
take = parser.parse_args().take
frames = json.loads((take / "scene.json").read_text())["frames"]


def tread_sample(frame):
    return take / "ruts" / f"{frame:04d}.png"


with Image.open(tread_sample(0)) as image:
    size = (image.height, image.width)
mask = np.zeros(size, dtype="uint8")
first_contact = np.full(size, 255, dtype="uint8")
for frame in range(0, frames, 6):
    path = tread_sample(frame)
    with Image.open(path) as image:
        marks = np.array(image.convert("L"))
    first_contact[(marks > 13) & (first_contact == 255)] = round(frame * 255 / frames)
    np.maximum(marks, mask, out=mask)
Image.fromarray(np.stack((mask, first_contact, np.zeros_like(mask)), axis=-1)).save(
    take / "ruts.png"
)
