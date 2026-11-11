#!/usr/bin/env python3
"""Bake CC0 EmberGen volumes into relightable flipbooks with Blender 4.3+.

Run with blender -b --factory-startup -t 8 --python tools/vfx/bake_volumes.py --
    --source /path/to/DustImpactVDB --kind dust --output /path/to/frames
No Blender or source volumes are needed to play the game.
"""
import argparse
import math
from pathlib import Path
import sys
import time
import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--kind', choices=['dust', 'fuel'], required=True)
p.add_argument('--samples', type=int, default=512)
p.add_argument('--fixed-samples', action='store_true', help='Disable adaptive convergence for reference renders')
p.add_argument('--threads', type=int, default=4)
p.add_argument('--resolution', type=int, default=256)
p.add_argument('--frames', type=int, default=64)
p.add_argument('--only', type=int)
p.add_argument('--pitch', type=int, choices=[35, 65])
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
s = bpy.context.scene
s.render.engine = 'CYCLES'
s.cycles.samples = a.samples
s.cycles.use_denoising = False  # Works with distro builds without OIDN.
s.cycles.use_adaptive_sampling = not a.fixed_samples
s.cycles.adaptive_threshold = 0.025
s.cycles.adaptive_min_samples = 64
s.cycles.volume_bounces = 1
s.cycles.volume_step_rate = 0.75
s.render.threads_mode = 'FIXED'
s.render.threads = a.threads
s.render.resolution_x = s.render.resolution_y = a.resolution
s.render.resolution_percentage = 100
s.render.film_transparent = True
s.world.use_nodes = True
s.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0
# These are linear lighting coefficients, not display colors.
s.view_settings.view_transform = 'Raw'
s.view_settings.look = 'None'
s.render.image_settings.file_format = 'PNG'
s.render.image_settings.color_mode = 'RGBA'
s.render.image_settings.color_depth = '16'
s.render.image_settings.compression = 15

files = sorted(a.source.glob('*.vdb'))
bpy.ops.object.volume_import(filepath=str(files[0]))
v = bpy.context.object
if a.kind == 'dust':
    v.scale = (0.015,) * 3
    v.location = (0, 384 * 0.015, 183 * 0.015)
    span, height, density = 18.0, 2.7, 1.8
else:
    v.scale = (0.05,) * 3
    v.location = (0, 0, 159.5 * 0.05)
    span, height, density = 21.0, 7.0, 2.0
m = bpy.data.materials.new('White isotropic scattering')
m.use_nodes = True
n = m.node_tree.nodes
n.clear()
out = n.new('ShaderNodeOutputMaterial')
volume = n.new('ShaderNodeVolumePrincipled')
volume.inputs['Density'].default_value = density
volume.inputs['Color'].default_value = (1, 1, 1, 1)
volume.inputs['Anisotropy'].default_value = 0
m.node_tree.links.new(volume.outputs['Volume'], out.inputs['Volume'])
v.data.materials.append(m)
if a.kind == 'fuel':
    flame = n.new('ShaderNodeAttribute')
    flame.attribute_name = 'flames'
    strength = n.new('ShaderNodeMath')
    strength.operation = 'MULTIPLY'
    strength.inputs[1].default_value = 0.0
    m.node_tree.links.new(flame.outputs['Fac'], strength.inputs[0])
    m.node_tree.links.new(strength.outputs[0], volume.inputs['Emission Strength'])
    volume.inputs['Emission Color'].default_value = (1, 1, 1, 1)

bpy.ops.object.camera_add()
c = bpy.context.object
c.data.type = 'ORTHO'
c.data.ortho_scale = span
s.camera = c
lights = []
for i in range(3):
    data = bpy.data.lights.new('Axis %d' % i, 'SUN')
    data.energy = math.pi * 4
    data.angle = 0
    data.color = tuple(float(j == i) for j in range(3))
    obj = bpy.data.objects.new(data.name, data)
    s.collection.objects.link(obj)
    lights.append(obj)

for pitch in ([a.pitch] if a.pitch else [35, 65]):
    angle = math.radians(pitch)
    target = Vector((0, 0, height))
    c.location = target + Vector((0, -math.cos(angle), math.sin(angle))) * 40
    c.rotation_euler = (target - c.location).to_track_quat('-Z', 'Y').to_euler()
    rot = c.rotation_euler.to_matrix()
    for frame in ([a.only] if a.only is not None else range(a.frames)):
        # More samples during the violent opening, fewer during slow dissipation.
        index = round((frame / (a.frames - 1)) ** 1.5 * (len(files) - 1))
        v.data.filepath = str(files[index])
        v.data.grids.load()
        s.cycles.seed = 712  # Correlated noise avoids temporal boiling.
        passes = [('positive', 1), ('negative', -1)]
        if a.kind == 'fuel':
            passes.append(('emission', 0))
        for side, sign in passes:
            extension = 'exr' if side == 'emission' else 'png'
            dst = a.output / f'{a.kind}_{pitch}_{side}_{frame:03d}.{extension}'
            if dst.exists():
                continue
            if a.kind == 'fuel':
                strength.inputs[1].default_value = 0.10 if sign == 0 else 0.0
            for i, obj in enumerate(lights):
                obj.data.energy = 0.0 if sign == 0 else math.pi * 4
                direction = Vector(tuple((sign or 1) if j == i else 0 for j in range(3)))
                obj.rotation_euler = (-(rot @ direction)).to_track_quat('-Z', 'Y').to_euler()
            s.render.image_settings.file_format = 'OPEN_EXR' if side == 'emission' else 'PNG'
            s.render.filepath = str(dst)
            start = time.monotonic()
            bpy.ops.render.render(write_still=True)
            print(f'BAKED {dst.name} source={files[index].name} seconds={time.monotonic()-start:.1f}', flush=True)
