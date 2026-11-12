"""Bake the drifting wreck fire for the ridge film with Blender 4.5 LTS."""

import argparse
import os
from pathlib import Path
import sys

import bpy

parser = argparse.ArgumentParser()
parser.add_argument("cache", type=Path)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
directory = args.cache.resolve()
directory.mkdir(parents=True, exist_ok=True)
# Mantaflow places its wavelet lookup table in the working directory.
os.chdir(directory)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 425
scene.render.fps = 24


def inflow(name, center, radii, fuel, velocity):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Fuel source", "FLUID")
    modifier.fluid_type = "FLOW"
    bpy.context.view_layer.update()
    flow = modifier.flow_settings
    flow.flow_type = "BOTH"
    flow.flow_behavior = "INFLOW"
    flow.fuel_amount = fuel
    flow.temperature = 1.5
    flow.density = 0.85
    flow.surface_distance = 1.6
    flow.use_initial_velocity = True
    flow.velocity_coord = velocity


inflow("Open seam", (-3.2, 0, 0.5), (0.43, 0.26, 0.30), 0.72, (0.72, 0.03, 1.25))
inflow(
    "Second flame", (-2.7, 0.22, 0.42), (0.25, 0.16, 0.24), 0.50, (0.94, -0.04, 0.87)
)
bpy.ops.mesh.primitive_cube_add(size=1, location=(1.8, 0, 6))
box = bpy.context.object
box.name = "Rising plume"
box.dimensions = (14, 6, 12)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
modifier = box.modifiers.new("Smoke and flame", "FLUID")
modifier.fluid_type = "DOMAIN"
bpy.context.view_layer.update()
domain = modifier.domain_settings
domain.domain_type = "GAS"
domain.resolution_max = 128
domain.cache_frame_start = scene.frame_start
domain.cache_frame_end = scene.frame_end
domain.cache_type = "ALL"
domain.cache_directory = str(directory / "cache")
domain.cache_data_format = "OPENVDB"
domain.use_adaptive_domain = False
domain.use_noise = True
domain.noise_scale = 2
domain.noise_strength = 1.05
domain.noise_pos_scale = 2.1
domain.noise_time_anim = 0.12
domain.time_scale = 1.05
domain.alpha = 0.28
domain.beta = 2.2
domain.flame_smoke = 1.25
domain.vorticity = 0.42
for side in ("front", "back", "left", "right", "top", "bottom"):
    setattr(domain, "use_collision_border_" + side, False)
bpy.ops.wm.save_as_mainfile(filepath=str(directory / "plume.blend"))
# The fine solver needs the live inflow and velocity while the coarse
# simulation advances. A separate non-resumable bake can yield empty grids.
if "FINISHED" not in bpy.ops.fluid.bake_all():
    raise RuntimeError("Fluid bake did not finish")
