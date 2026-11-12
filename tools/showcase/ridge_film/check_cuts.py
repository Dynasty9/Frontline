"""Check actual picture changes at the camera cuts recorded by the ridge stage."""

import argparse
import json
import subprocess
from pathlib import Path

import numpy as np

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("take", type=Path, help="Directory recorded by ridge-film-export")
parser.add_argument("movie", type=Path)
args = parser.parse_args()

take = json.loads((args.take / "scene.json").read_text())
camera = np.fromfile(args.take / "camera.f32", dtype="<f4").reshape(-1, 21)
if len(camera) != take["frames"]:
    parser.error("The camera take is incomplete")

# Within a shot the camera moves smoothly. Cuts jump in position or field of view.
distance = np.linalg.norm(np.diff(camera[:, 9:12], axis=0), axis=1)
fov_step = np.abs(np.diff(camera[:, 12]))
cuts = np.flatnonzero((distance > 1) | (fov_step > 1.5)) + 1
if not len(cuts):
    parser.error("The take contains no camera cuts")

pixels = subprocess.check_output(
    [
        "ffmpeg",
        "-v",
        "error",
        "-xerror",
        "-i",
        str(args.movie),
        "-vf",
        f"fps={take['fps']},scale=64:36,format=gray",
        "-an",
        "-f",
        "rawvideo",
        "-",
    ]
)
frames = np.frombuffer(pixels, dtype=np.uint8).reshape(-1, 36, 64)
if len(frames) != len(camera):
    parser.error(f"Expected {len(camera)} pictures, decoded {len(frames)}")

change = np.abs(np.diff(frames.astype(np.int16), axis=0)).mean(axis=(1, 2))
for cut in cuts:
    # Supersampled captures can put the transition one frame either side.
    if change[max(0, cut - 2) : cut + 1].max() < 4:
        parser.error(f"Missing visible cut at {cut / take['fps']:.2f}s (frame {cut})")
print(
    f"Verified {len(cuts)} visible cuts across {len(frames)} frames of {args.movie.name}"
)
