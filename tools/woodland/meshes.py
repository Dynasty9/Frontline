"""Blender stage: retain scanned silhouettes and UVs within a scenery triangle budget."""
import bpy
import math
import json
import random
import sys
import mmap
import numpy as np
from pathlib import Path
from mathutils import Vector

root = Path.cwd()
source = root / 'build/woodland/source'
output = root / 'build/woodland/meshes'
output.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.edit.use_global_undo = False
written = []

def canopy_cards(obj, samples=None):
    """Sample the scan's branch envelope without carrying millions of tiny leaf faces."""
    rng = random.Random(7319)
    vertices, faces = [], []
    source_mesh = obj.data
    for i in range(700 if samples is None else len(samples)):
        if samples is None:
            polygon = source_mesh.polygons[rng.randrange(len(source_mesh.polygons))]
            center = polygon.center.copy()
            normal = polygon.normal.normalized()
            along = Vector((0, 0, 1)) - normal * normal.z
            if along.length < 0.1:
                along = Vector((1, 0, 0)) - normal * normal.x
            along.normalize()
            side = normal.cross(along).normalized()
        else:
            center = samples[i]
            along = Vector((center.x, center.y, -0.6)).normalized()
            side = Vector((-center.y, center.x, 0)).normalized()
        angle = rng.uniform(-1.1, 1.1)
        along, side = along * math.cos(angle) + side * math.sin(angle), side * math.cos(angle) - along * math.sin(angle)
        along *= rng.uniform(0.2, 0.34) if samples is None else rng.uniform(0.28, 0.5)
        side *= rng.uniform(0.1, 0.18) if samples is None else rng.uniform(0.1, 0.22)
        start = len(vertices)
        vertices.extend([center-side-along, center+side-along, center+side+along, center-side+along])
        faces.extend([(start, start+1, start+2), (start, start+2, start+3)])
    mesh = bpy.data.meshes.new('Scanned canopy cards')
    mesh.from_pydata(vertices, [], faces)
    uv = mesh.uv_layers.new(name='UVMap')
    coords = [(0, 0), (1, 0), (1, 1), (0, 1)]
    for polygon in mesh.polygons:
        for loop in polygon.loop_indices:
            uv.data[loop].uv = coords[mesh.loops[loop].vertex_index % 4]
    obj.data = mesh
    bpy.data.meshes.remove(source_mesh)

for name, budget, scale, variants in [('dead_tree_trunk_02', 3500, 1, [0]), ('tree_stump_01', 2200, 1, [0]), ('fern_02', 1600, 1, [0, 1]), ('nettle_plant', 1600, 4, [0, 4]), ('rock_moss_set_01', 1500, 1, [0, 2]), ('grass_medium_01', 700, 3, [3, 4]), ('shrub_02', 1800, 1, [0, 1])]:
    if '--trees-only' in sys.argv or '--fir-only' in sys.argv:
        continue
    if '--shrubs-only' in sys.argv and name != 'shrub_02':
        continue
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source / name / (name + '.gltf')))
    objects = sorted([o for o in bpy.context.scene.objects if o.type == 'MESH'], key=lambda o: o.name)
    for i, obj in enumerate(objects):
        if i not in variants:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        obj.location = (0, 0, 0)
        obj.scale *= scale
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bounds = [Vector(c) for c in obj.bound_box]
        center = Vector(((min(v.x for v in bounds) + max(v.x for v in bounds)) / 2,
                         (min(v.y for v in bounds) + max(v.y for v in bounds)) / 2,
                         min(v.z for v in bounds)))
        for vertex in obj.data.vertices:
            vertex.co -= center
        if len(obj.data.polygons) > budget:
            modifier = obj.modifiers.new('Scenery budget', 'DECIMATE')
            modifier.ratio = budget / len(obj.data.polygons)
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.materials.clear()
        filename = f'{name}-{i}'
        bpy.ops.export_scene.gltf(filepath=str(output / (filename + '.glb')), export_format='GLB',
                                  use_selection=True, export_materials='NONE', export_animations=False)
        print(f'WOODLAND_MESH {filename} faces={len(obj.data.polygons)}', flush=True)
        assert len(obj.data.polygons) <= budget * 1.1, filename
        written.append(filename + '.glb')

# Keep wood and foliage separate so the game's existing fire material can shed leaves.
for name in ['tree_small_02', 'pine_sapling_small']:
    if '--fir-only' in sys.argv or '--shrubs-only' in sys.argv:
        continue
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source / name / (name + '.gltf')))
    originals = sorted([o for o in bpy.context.scene.objects if o.type == 'MESH'], key=lambda o: o.name)
    for variant, obj in enumerate(originals[:2]):
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        obj.location = (0, 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bounds = [Vector(c) for c in obj.bound_box]
        low = min(v.z for v in bounds)
        base = [v.co for v in obj.data.vertices if v.co.z < low + 0.15]
        center = sum(base, Vector()) / len(base)
        center.z = low
        for vertex in obj.data.vertices:
            vertex.co -= center
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.separate(type='MATERIAL')
        bpy.ops.object.mode_set(mode='OBJECT')
        parts = list(bpy.context.selected_objects)
        for part in parts:
            material_name = part.data.materials[0].name
            leafy = 'leaves' in material_name or 'twig' in material_name
            suffix = 'leaves' if leafy else ('branches' if 'branches' in material_name else 'trunk')
            budget = (12000 if leafy else 1800) if name == 'tree_small_02' else (3000 if leafy else 350)
            bpy.ops.object.select_all(action='DESELECT')
            part.select_set(True)
            bpy.context.view_layer.objects.active = part
            if leafy and name == 'tree_small_02':
                canopy_cards(part)
            if len(part.data.polygons) > budget:
                modifier = part.modifiers.new('Tree scenery budget', 'DECIMATE')
                modifier.ratio = budget / len(part.data.polygons)
                modifier.use_collapse_triangulate = True
                bpy.ops.object.modifier_apply(modifier=modifier.name)
            part.data.materials.clear()
            filename = f'{name}-{variant}-{suffix}'
            bpy.ops.export_scene.gltf(filepath=str(output / (filename + '.glb')), export_format='GLB',
                                      use_selection=True, export_materials='NONE', export_animations=False)
            print(f'WOODLAND_MESH {filename} faces={len(part.data.polygons)}', flush=True)
            assert len(part.data.polygons) <= budget * 1.1, filename
            written.append(filename + '.glb')

# Sample the fir's needle geometry directly; importing millions of tiny needle
# faces only to replace them needlessly multiplies the offline memory footprint.
if '--shrubs-only' in sys.argv:
    (output / 'manifest.json').write_text(json.dumps(written, indent=2))
    sys.exit(0)

fir_source = source / 'fir_tree_01'
fir_document = json.loads((fir_source / 'fir_tree_01.gltf').read_text())
with (fir_source / 'fir_tree_01.bin').open('rb') as binary_file:
    binary = mmap.mmap(binary_file.fileno(), 0, access=mmap.ACCESS_READ)
    def accessor(index):
        description = fir_document['accessors'][index]
        view = fir_document['bufferViews'][description['bufferView']]
        dtype = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[description['componentType']]
        width = 3 if description['type'] == 'VEC3' else 1
        stride = view.get('byteStride', np.dtype(dtype).itemsize * width)
        return np.ndarray((description['count'], width), dtype=dtype, buffer=binary,
                          offset=view.get('byteOffset', 0) + description.get('byteOffset', 0),
                          strides=(stride, np.dtype(dtype).itemsize))

    for variant, node_index in enumerate([1, 2]):
        twig = next(p for p in fir_document['meshes'][node_index]['primitives'] if p['material'] == 2)
        positions = accessor(twig['attributes']['POSITION'])
        indices = accessor(twig['indices']).reshape(-1)
        rng = random.Random(8831 + variant)
        samples = []
        for i in range(1600):
            triangle = rng.randrange(len(indices) // 3) * 3
            point = positions[indices[triangle:triangle+3]].mean(axis=0)
            samples.append(Vector((float(point[0]), -float(point[2]), float(point[1]))))
        document = json.loads(json.dumps(fir_document))
        node = document['nodes'][node_index]
        mesh = document['meshes'][node['mesh']]
        mesh['primitives'] = [p for p in mesh['primitives'] if p['material'] != 2]
        node['mesh'] = 0
        document['nodes'] = [node]
        document['meshes'] = [mesh]
        document['scenes'] = [{'nodes': [0]}]
        document['scene'] = 0
        selected = fir_source / 'fir-wood.gltf'
        selected.write_text(json.dumps(document))
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        bpy.ops.outliner.orphans_purge(do_recursive=True)
        bpy.ops.import_scene.gltf(filepath=str(selected))
        trunk = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
        bpy.context.view_layer.objects.active = trunk
        trunk.location = (0, 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        low = min(v.co.z for v in trunk.data.vertices)
        for vertex in trunk.data.vertices:
            vertex.co.z -= low
        modifier = trunk.modifiers.new('Fir wood budget', 'DECIMATE')
        modifier.ratio = 3500 / len(trunk.data.polygons)
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        trunk.data.materials.clear()
        leaves = bpy.data.objects.new('Fir canopy', bpy.data.meshes.new('Fir sample placeholder'))
        bpy.context.collection.objects.link(leaves)
        canopy_cards(leaves, [p - Vector((0, 0, low)) for p in samples])
        for suffix, part in [('trunk', trunk), ('leaves', leaves)]:
            bpy.ops.object.select_all(action='DESELECT')
            part.select_set(True)
            bpy.context.view_layer.objects.active = part
            filename = f'fir_tree_01-{variant}-{suffix}'
            bpy.ops.export_scene.gltf(filepath=str(output / (filename + '.glb')), export_format='GLB',
                                      use_selection=True, export_materials='NONE', export_animations=False)
            print(f'WOODLAND_MESH {filename} faces={len(part.data.polygons)}', flush=True)
            assert len(part.data.polygons) <= (5000 if suffix == 'trunk' else 3200), filename
            written.append(filename + '.glb')
    del positions, indices
    binary.close()

(output / 'manifest.json').write_text(json.dumps(written, indent=2))
