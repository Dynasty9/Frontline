"""Read the Blender smoke cache into the fixed grid used by the film."""

import argparse
from pathlib import Path
import sys

import numpy as np
import openvdb

parser = argparse.ArgumentParser()
parser.add_argument(
    "source", type=Path, help="Mantaflow directory containing the fine .vdb files"
)
parser.add_argument("out", type=Path)
parser.add_argument(
    "--render-grids", type=Path, help="Also write trimmed VDBs for offline rendering"
)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
args.out.mkdir(exist_ok=True, parents=True)
if args.render_grids:
    args.render_grids.mkdir(exist_ok=True, parents=True)

extent = np.array((14.0, 6.0, 12.0))


def smooth(value):
    value = np.clip(value, 0, 1)
    return value * value * (3 - 2 * value)


def sample(field, shape):
    """Separable trilinear interpolation at the output voxel centers."""
    for axis, size in enumerate(shape):
        length = field.shape[axis]
        x = np.clip((np.arange(size) + 0.5) * length / size - 0.5, 0, length - 1)
        left = x.astype(int)
        shape_1d = [1, 1, 1]
        shape_1d[axis] = size
        fraction = (x - left).astype("f").reshape(shape_1d)
        field = (
            np.take(field, left, axis) * (1 - fraction)
            + np.take(field, np.minimum(left + 1, length - 1), axis) * fraction
        )
    return field


for path in sorted(args.source.glob("*.vdb")):
    frame = int(path.stem.rsplit("_", 1)[1])
    packed = args.out / f"{frame:04d}.npz"
    grid_path = (
        args.render_grids / f"fluid_data_{frame:04d}.vdb" if args.render_grids else None
    )
    if (frame % 2 == 0 or packed.exists()) and (
        grid_path is None or grid_path.exists()
    ):
        continue
    arrays = {}
    grids = []
    for name in ("density", "flame"):
        channel = name + "_noise" if path.stem.startswith("fluid_noise_") else name
        grid = openvdb.read(str(path), channel)
        spacing = np.array(grid.transform.voxelSize())
        shape = np.rint(extent / spacing).astype(int)
        field = np.empty(tuple(shape), dtype="f")
        grid.copyToArray(field)
        # Soften the open boundaries, where the simulation stops tracking gas.
        x, y, z = np.ogrid[tuple(slice(0, size) for size in shape)]
        edge = smooth(x * spacing[0] / 1.35) * smooth(
            (shape[0] - 1 - x) * spacing[0] / 1.45
        )
        edge = (
            edge
            * smooth(y * spacing[1] / 0.74)
            * smooth((shape[1] - 1 - y) * spacing[1] / 0.74)
        )
        field *= edge * smooth((shape[2] - 1 - z) * spacing[2] / 1.4)
        if frame % 2:
            reduced = sample(field, (80, 34, 68))
            arrays[name] = (
                (np.clip(reduced.transpose(2, 1, 0), 0, 1) * 255).round().astype("u1")
            )
        if grid_path:
            reduced = sample(field, (160, 69, 137))
            reduced[reduced < 0.0025] = 0
            clean = openvdb.FloatGrid()
            clean.name = name
            clean.gridClass = openvdb.GridClass.FOG_VOLUME
            clean.transform = openvdb.createLinearTransform(voxelSize=14 / 160)
            clean.saveFloatAsHalf = True
            clean.copyFromArray(reduced)
            grids.append(clean)
    if arrays:
        np.savez_compressed(packed, **arrays)
    if grid_path:
        openvdb.write(str(grid_path), grids=grids)
