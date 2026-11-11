"""Light and render the game take in Cycles. Blender 4.5 LTS, see ../README.md."""

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "take", type=Path, help="Directory recorded by ridge-film-export.tscn"
)
parser.add_argument(
    "volumes", type=Path, help="Trimmed OpenVDBs from read_ridge_fire.py"
)
parser.add_argument("output", type=Path, help="Destination for numbered PNG frames")
parser.add_argument(
    "--frames", help="Optional comma-separated zero-based frames to proof"
)
parser.add_argument("--width", type=int, default=1920)
parser.add_argument(
    "--device",
    choices=["CPU", "METAL", "OPTIX", "CUDA", "HIP", "ONEAPI"],
    default="CPU",
)
parser.add_argument(
    "--resume", action="store_true", help="Skip finished frames from this take"
)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
rig_cache = args.take.resolve()
output_dir = args.output.resolve()
output_dir.mkdir(parents=True, exist_ok=True)
repo = Path(__file__).resolve().parents[3]
assets = repo / "assets"
field_assets = repo / "tests/fixtures/ridge-light"
take = json.loads((rig_cache / "scene.json").read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=str(rig_cache / "stage.glb"))
scene.render.engine = "CYCLES"
if args.device != "CPU":
    preferences = bpy.context.preferences.addons["cycles"].preferences
    preferences.compute_device_type = args.device
    preferences.get_devices()
    devices = [dev for dev in preferences.devices if dev.type == args.device]
    if not devices:
        raise RuntimeError(f"No {args.device} Cycles device found")
    for dev in preferences.devices:
        dev.use = dev.type == args.device
    scene.cycles.device = "GPU"
scene.cycles.use_denoising = True
scene.cycles.use_adaptive_sampling = True
scene.cycles.max_bounces = 5
scene.cycles.transparent_max_bounces = 18
scene.cycles.volume_bounces = 1
scene.cycles.diffuse_bounces = 2
scene.cycles.glossy_bounces = 2
scene.render.resolution_x = args.width
scene.render.resolution_y = round(scene.render.resolution_x * 9 / 16)
scene.render.resolution_percentage = 100
scene.render.fps = take["fps"]
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.render.image_settings.compression = 18
scene.render.use_persistent_data = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = 0.29


def lin(v):
    return ((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92


def rgba(rgb):
    return tuple(lin(v) for v in rgb) + (1,)


def add(tree, kind):
    return tree.nodes.new(kind)


def wire(tree, src, dst):
    if isinstance(src, bpy.types.NodeSocket):
        tree.links.new(src, dst)
    else:
        dst.default_value = src


def image_file(f, data=False):
    im = bpy.data.images.load(str(f), check_existing=True)
    if data:
        im.colorspace_settings.name = "Non-Color"
    return im


def tex(tree, im, coord=None, box=False):
    n = add(tree, "ShaderNodeTexImage")
    n.image = im
    if box:
        n.projection = "BOX"
        n.projection_blend = 0.18
    if coord is not None:
        wire(tree, coord, n.inputs["Vector"])
    return n


def vec(tree, op, a, b):
    n = add(tree, "ShaderNodeVectorMath")
    n.operation = op
    wire(tree, a, n.inputs[0])
    wire(tree, b, n.inputs["Scale" if op == "SCALE" else 1])
    return n.outputs[0]


def mix(tree, typ, f, a, b):
    n = add(tree, "ShaderNodeMixRGB")
    n.blend_type = typ
    wire(tree, f, n.inputs[0])
    wire(tree, a, n.inputs[1])
    wire(tree, b, n.inputs[2])
    return n.outputs[0]


def noise(tree, coord, scale, detail=2.0):
    n = add(tree, "ShaderNodeTexNoise")
    wire(tree, coord, n.inputs[0])
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    return n


def bump(tree, height, scale, strength, normal=None):
    n = add(tree, "ShaderNodeBump")
    wire(tree, height, n.inputs["Height"])
    n.inputs["Distance"].default_value = scale
    n.inputs["Strength"].default_value = strength
    if normal is not None:
        wire(tree, normal, n.inputs["Normal"])
    return n.outputs["Normal"]


def ramp(tree, fac, points):
    n = add(tree, "ShaderNodeValToRGB")
    wire(tree, fac, n.inputs[0])
    for i, (p, c) in enumerate(points):
        e = n.color_ramp.elements[i] if i < 2 else n.color_ramp.elements.new(p)
        e.position = p
        e.color = c
    return n.outputs[0]


def new_bsdf(m):
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    surface = add(tree, "ShaderNodeBsdfPrincipled")
    out = add(tree, "ShaderNodeOutputMaterial")
    wire(tree, surface.outputs[0], out.inputs["Surface"])
    return tree, surface


wear_img = image_file(assets / "vehicles/steel-wear.jpg", True)
for name, params in take["palette"].items():
    if not params:
        continue
    m = bpy.data.materials[name]
    tree, surface = new_bsdf(m)
    coord = add(tree, "ShaderNodeTexCoord").outputs["Object"]
    paint = rgba(params["col_a"])
    base = paint
    weather = params.get("worn_armour", False)
    if weather:
        pattern = noise(tree, coord, 0.75, 3.0).outputs["Fac"]
        base = ramp(
            tree,
            pattern,
            [
                (0.22, rgba(params["col_b"])),
                (0.43, paint),
                (0.52, rgba(params["col_d"])),
                (0.62, rgba(params["col_c"])),
                (0.79, paint),
            ],
        )
        wear = tex(tree, wear_img, vec(tree, "SCALE", coord, 0.31), True).outputs[
            "Color"
        ]
        variation = ramp(
            tree, wear, [(0.19, (0.63, 0.59, 0.52, 1)), (0.39, (1.03, 1.02, 0.99, 1))]
        )
        base = mix(tree, "MULTIPLY", 0.43, base, variation)
        occ = add(tree, "ShaderNodeAmbientOcclusion")
        occ.samples = 8
        occ.inputs["Distance"].default_value = 0.36
        base = mix(tree, "MULTIPLY", 0.36, base, occ.outputs["Color"])
    else:
        wear = noise(tree, coord, 24, 2.0).outputs["Fac"]
    tint = add(tree, "ShaderNodeVertexColor")
    tint.layer_name = "Color"
    final = vec(
        tree,
        "SCALE",
        mix(tree, "MULTIPLY", 1.0, base, tint.outputs["Color"]),
        params.get("vcolor_k", 4),
    )
    wire(tree, final, surface.inputs["Base Color"])
    surface.inputs["Roughness"].default_value = params["rough"]
    surface.inputs["Metallic"].default_value = params.get("metal", 0)
    micro = noise(tree, coord, 160 if weather else 85, 1.0).outputs["Fac"]
    normal = bump(tree, micro, 0.0018, 0.14)
    if weather:
        bevel = add(tree, "ShaderNodeBevel")
        bevel.samples = 3
        bevel.inputs["Radius"].default_value = 0.0055
        wire(tree, normal, bevel.inputs["Normal"])
        normal = bevel.outputs["Normal"]
    wire(tree, bump(tree, wear, 0.006, 0.28, normal), surface.inputs["Normal"])
# A photographed terrain material stays fixed to the ground as the camera moves.
m = bpy.data.materials["TerrainSoil"]
tree, surface = new_bsdf(m)
pos = add(tree, "ShaderNodeNewGeometry").outputs["Position"]
mapping = vec(tree, "SCALE", pos, 0.21)
rotation = add(tree, "ShaderNodeVectorRotate")
rotation.rotation_type = "Z_AXIS"
wire(tree, pos, rotation.inputs[0])
rotation.inputs["Angle"].default_value = 0.96
rot = vec(tree, "SCALE", rotation.outputs[0], 0.144)
turf = image_file(assets / "terrain/aerial_grass_rock_diff_2k.jpg")
stones = image_file(assets / "terrain/aerial_rocks_02_diff_2k.jpg")
macro = noise(tree, pos, 0.11, 3.0).outputs["Fac"]
soil = mix(
    tree,
    "MIX",
    macro,
    tex(tree, turf, mapping, True).outputs[0],
    tex(tree, turf, rot, True).outputs[0],
)
soil = mix(
    tree,
    "MIX",
    ramp(tree, macro, [(0.4, (0, 0, 0, 1)), (0.74, (0.54, 0.54, 0.54, 1))]),
    soil,
    tex(tree, stones, rot, True).outputs[0],
)
wire(tree, soil, surface.inputs["Base Color"])
surface.inputs["Roughness"].default_value = 0.92
micro = noise(tree, pos, 115, 2.0).outputs["Fac"]
wire(
    tree,
    bump(tree, soil, 0.075, 0.38, bump(tree, micro, 0.006, 0.32)),
    surface.inputs["Normal"],
)
m = bpy.data.materials["TuftCards"]
tree, surface = new_bsdf(m)
atlas = tex(tree, image_file(field_assets / "grass.png"))
wire(tree, atlas.outputs[0], surface.inputs["Base Color"])
wire(tree, atlas.outputs["Alpha"], surface.inputs["Alpha"])
surface.inputs["Roughness"].default_value = 0.95
# Match the game's two-sided straw. The upright normal lights the clump
# consistently on either side of a crossed card. A little back-scattered
# light keeps its dry paper-thin blades from turning black in the sun.
straw_normal = add(tree, "ShaderNodeVectorMath")
straw_normal.operation = "ADD"
straw_normal.inputs[0].default_value = (0, 0, 1)
wire(tree, straw_normal.outputs["Vector"], surface.inputs["Normal"])
surface.inputs["Specular IOR Level"].default_value = 0.17
leaf = add(tree, "ShaderNodeBsdfTranslucent")
wire(tree, atlas.outputs[0], leaf.inputs["Color"])
out = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
# Keep the card's alpha on both the diffuse and translucent parts.
clear = add(tree, "ShaderNodeBsdfTransparent")
glass = add(tree, "ShaderNodeMixShader")
wire(tree, atlas.outputs["Alpha"], glass.inputs[0])
wire(tree, clear.outputs[0], glass.inputs[1])
wire(tree, leaf.outputs[0], glass.inputs[2])
blend = add(tree, "ShaderNodeMixShader")
blend.inputs[0].default_value = 0.29
wire(tree, surface.outputs[0], blend.inputs[1])
wire(tree, glass.outputs[0], blend.inputs[2])
wire(tree, blend.outputs[0], out.inputs["Surface"])
# Scatter the same scanned plants, stones and grass as the game.
axis = np.array(((1, 0, 0), (0, 0, -1), (0, 1, 0)), float)


def xform(pack):
    m = np.eye(4)
    m[:3, :3] = axis @ pack[:3].T @ axis.T
    m[:3, 3] = axis @ pack[3]
    return Matrix(m)


for name in take["vegetation"]:
    proto = bpy.data.objects[name]
    proto.parent = None
    proto.matrix_world = Matrix.Identity(4)
    # Prototype is located out of frame; relative transforms in the node graph stay local.
    proto.location = (0, 0, -1000)
    packs = np.fromfile(rig_cache / (name + ".f32"), "<f4").reshape(-1, 4, 3)
    points = [xform(p).decompose() for p in packs]
    mesh = bpy.data.meshes.new(name + " scatter")
    mesh.from_pydata([tuple(it[0]) for it in points], [], [])
    mesh.update()
    for attr, values in [
        ("scale", [tuple(it[2]) for it in points]),
        ("rotation", [tuple(it[1].to_euler()) for it in points]),
    ]:
        a = mesh.attributes.new(attr, "FLOAT_VECTOR", "POINT")
        a.data.foreach_set("vector", np.asarray(values, dtype="f").ravel())
    obj = bpy.data.objects.new(name + " Instances", mesh)
    scene.collection.objects.link(obj)
    mod = obj.modifiers.new("Field scatter", "NODES")
    tree = bpy.data.node_groups.new("Place " + name, "GeometryNodeTree")
    mod.node_group = tree
    tree.interface.new_socket(
        name="Geometry", in_out="INPUT", socket_type="NodeSocketGeometry"
    )
    tree.interface.new_socket(
        name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry"
    )
    inp = add(tree, "NodeGroupInput")
    out = add(tree, "NodeGroupOutput")
    ins = add(tree, "GeometryNodeInstanceOnPoints")
    info = add(tree, "GeometryNodeObjectInfo")
    info.transform_space = "ORIGINAL"
    info.inputs["Object"].default_value = proto
    info.inputs["As Instance"].default_value = False
    wire(tree, info.outputs["Geometry"], ins.inputs["Instance"])
    wire(tree, inp.outputs[0], ins.inputs["Points"])
    for key in ("Scale", "Rotation"):
        n = add(tree, "GeometryNodeInputNamedAttribute")
        n.data_type = "FLOAT_VECTOR"
        n.inputs["Name"].default_value = key.lower()
        wire(tree, n.outputs["Attribute"], ins.inputs[key])
    wire(tree, ins.outputs[0], out.inputs[0])
# The HDR sky supplies reflections. The matching sun gives soft contact shadows.
world = bpy.data.worlds.new("Qwantani sunset")
scene.world = world
world.use_nodes = True
tree = world.node_tree
tree.nodes.clear()
wc = add(tree, "ShaderNodeTexCoord")
rot = add(tree, "ShaderNodeVectorRotate")
rot.rotation_type = "Z_AXIS"
rot.inputs["Angle"].default_value = -math.pi * 0.5
wire(tree, wc.outputs["Generated"], rot.inputs[0])
env = add(tree, "ShaderNodeTexEnvironment")
env.image = image_file(field_assets / "qwantani.exr")
wire(tree, rot.outputs[0], env.inputs[0])
ray = add(tree, "ShaderNodeLightPath")
lit = mix(
    tree,
    "MIX",
    ray.outputs["Is Camera Ray"],
    vec(tree, "MINIMUM", env.outputs[0], (4, 4, 4)),
    env.outputs[0],
)
bg = add(tree, "ShaderNodeBackground")
wire(tree, lit, bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.85
wo = add(tree, "ShaderNodeOutputWorld")
wire(tree, bg.outputs[0], wo.inputs["Surface"])
sun = bpy.data.lights.new("Warm sun", "SUN")
sun.energy = 2.05
sun.angle = math.radians(0.55)
sun.color = (1, 0.82, 0.57)
o = bpy.data.objects.new("Warm sun", sun)
scene.collection.objects.link(o)
o.rotation_euler = Vector((-0.574, -0.807, -0.14)).to_track_quat("-Z", "Y").to_euler()
camera = bpy.data.objects.new("Film camera", bpy.data.cameras.new("Film camera"))
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.sensor_fit = "VERTICAL"
camera.data.sensor_height = 24
camera.data.clip_end = 600
rig = [bpy.data.objects[n] for n in take["objects"]]
for obj in rig:
    obj.parent = None
motion = np.fromfile(rig_cache / "motion.f32", "<f4").reshape(-1, len(rig), 4, 3)
camera_data = np.fromfile(rig_cache / "camera.f32", "<f4").reshape(-1, 21)
if len(motion) != take["frames"] or len(camera_data) != len(motion):
    raise ValueError("Incomplete take: expected one camera and rig pose per film frame")


# Material finishing shared by every camera cut.
def number(tree, operation, a, b):
    n = add(tree, "ShaderNodeMath")
    n.operation = operation
    wire(tree, a, n.inputs[0])
    wire(tree, b, n.inputs[1])
    return n.outputs[0]


def smoothmap(tree, x, low, high):
    n = add(tree, "ShaderNodeMapRange")
    n.interpolation_type = "SMOOTHERSTEP"
    wire(tree, x, n.inputs[0])
    n.inputs[1].default_value = low
    n.inputs[2].default_value = high
    return n.outputs[0]


for name, params in take["palette"].items():
    if not params.get("worn_armour"):
        continue
    m = bpy.data.materials[name]
    tree = m.node_tree
    surface = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    shade = surface.inputs["Base Color"].links[0].from_socket
    coord = add(tree, "ShaderNodeTexCoord").outputs["Object"]
    flecks = tex(
        tree, wear_img, vec(tree, "MULTIPLY", coord, (0.97, 0.92, 0.15)), True
    ).outputs["Color"]
    mottling = smoothmap(tree, flecks, 0.23, 0.36)
    patina = ramp(
        tree, mottling, [(0, (0.56, 0.53, 0.47, 1)), (1, (1.15, 1.12, 1.07, 1))]
    )
    shade = mix(tree, "MULTIPLY", 0.75, shade, patina)
    geo = add(tree, "ShaderNodeNewGeometry")
    edge = smoothmap(tree, geo.outputs["Pointiness"], 0.50, 0.57)
    chip = number(tree, "MULTIPLY", edge, smoothmap(tree, flecks, 0.30, 0.40))
    shade = mix(
        tree, "MIX", number(tree, "MULTIPLY", 0.5, chip), shade, (0.12, 0.115, 0.092, 1)
    )
    # Grazing plates collect pale dust. Vertical cheeks retain the darker paint,
    # so their joint remains visible when the sky is the main light source.
    normal = add(tree, "ShaderNodeSeparateXYZ")
    wire(tree, geo.outputs["Normal"], normal.inputs[0])
    shelf = number(
        tree, "MULTIPLY", smoothmap(tree, normal.outputs["Z"], 0.22, 0.85), mottling
    )
    shade = mix(
        tree, "MIX", number(tree, "MULTIPLY", shelf, 0.24), shade, (0.34, 0.26, 0.15, 1)
    )
    wire(tree, shade, surface.inputs["Base Color"])
    wire(
        tree,
        ramp(tree, mottling, [(0, (0.54, 0.54, 0.54, 1)), (1, (0.95, 0.95, 0.95, 1))]),
        surface.inputs["Roughness"],
    )
# The native shoe stamps are revealed only after the vehicle reaches the ground there.
ground = bpy.data.materials["TerrainSoil"]
tree = ground.node_tree
surface = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
mark_uv = add(tree, "ShaderNodeUVMap")
mark_uv.uv_map = "UVMap.001"
mark = tex(tree, image_file(rig_cache / "ruts.png", True), mark_uv.outputs["UV"])
mark.extension = "CLIP"
channels = add(tree, "ShaderNodeSeparateColor")
wire(tree, mark.outputs[0], channels.inputs[0])
clock = add(tree, "ShaderNodeValue")
ground_time = clock.outputs[0]
age = number(tree, "SUBTRACT", ground_time, channels.outputs[1])
reveal = smoothmap(tree, age, -0.002, 0.004)
strength = number(tree, "MULTIPLY", reveal, channels.outputs[0])
shade = surface.inputs["Base Color"].links[0].from_socket
wire(
    tree,
    mix(tree, "MULTIPLY", strength, shade, (0.46, 0.39, 0.30, 1)),
    surface.inputs["Base Color"],
)
normal = surface.inputs["Normal"].links[0].from_socket
wire(
    tree,
    bump(tree, number(tree, "MULTIPLY", strength, -1), 0.034, 0.5, normal),
    surface.inputs["Normal"],
)

# Godot marks these film prop vertex colors as sRGB. glTF assumes vertex
# colors are linear, so bring the scraped metal back to its original value.
finished = set()
for obj in rig:
    if not obj.name.startswith("scar"):
        continue
    for m in obj.data.materials:
        if m in finished:
            continue
        finished.add(m)
        tree, surface = new_bsdf(m)
        tint = add(tree, "ShaderNodeVertexColor")
        tint.layer_name = "Color"
        gamma = add(tree, "ShaderNodeGamma")
        gamma.inputs["Gamma"].default_value = 2.2
        wire(tree, tint.outputs["Color"], gamma.inputs[0])
        wire(tree, gamma.outputs[0], surface.inputs["Base Color"])
        wire(tree, tint.outputs["Alpha"], surface.inputs["Alpha"])
        surface.inputs["Roughness"].default_value = 0.82
        surface.inputs["Metallic"].default_value = 0.22


# Cache real rig transforms as animation channels. Cycles samples each moving
# shoe over an exposure while the geometry on the ground stays fixed.
def curves(obj, field, array, action):
    time = np.arange(len(array), dtype="f") + 1
    for j in range(array.shape[1]):
        values = array[:, j]
        if np.ptp(values) < 0.00001:
            getattr(obj, field)[j] = values[0]
            continue
        fc = action.fcurves.new(data_path=field, index=j, action_group=field)
        fc.keyframe_points.add(len(values))
        fc.keyframe_points.foreach_set(
            "co", np.stack((time, values), axis=1).astype("f").ravel()
        )
        fc.update()
        for pt in fc.keyframe_points:
            pt.interpolation = "LINEAR"


def animate_rig():
    scene.render.use_motion_blur = True
    scene.render.motion_blur_shutter = 0.48
    for j, obj in enumerate(rig):
        # The stage holds its final wreck pose for several seconds.
        samples = motion[:, j]
        delta = np.flatnonzero(
            np.max(np.abs(np.diff(samples, axis=0)), axis=(1, 2)) > 1e-6
        )
        end = min(len(samples), int(delta[-1]) + 3) if delta.size else 1
        samples = samples[:end]
        poses = [xform(q).decompose() for q in samples]
        loc = np.array([tuple(x[0]) for x in poses])
        rot = np.array([tuple(x[1]) for x in poses])
        size = np.array([tuple(x[2]) for x in poses])
        for i in range(1, len(rot)):
            if np.dot(rot[i - 1], rot[i]) < 0:
                rot[i] *= -1
        obj.rotation_mode = "QUATERNION"
        obj.animation_data_create()
        action = bpy.data.actions.new(obj.name + " recorded motion")
        obj.animation_data.action = action
        curves(obj, "location", loc, action)
        curves(obj, "rotation_quaternion", rot, action)
        curves(obj, "scale", size, action)
        if action.slots:
            obj.animation_data.action_slot = action.slots[0]


animate_rig()

rng = np.random.default_rng(712)
events = take["shots"]


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def direction(p):
    return Vector(tuple(axis @ np.asarray(p)))


def material_volume(label):
    m = bpy.data.materials.new(label)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    vol = add(tree, "ShaderNodeVolumePrincipled")
    sink = add(tree, "ShaderNodeOutputMaterial")
    wire(tree, vol.outputs[0], sink.inputs["Volume"])
    vol.inputs["Density Attribute"].default_value = ""
    vol.inputs["Temperature Attribute"].default_value = ""
    return m, tree, vol


def lamp(label, color):
    light = bpy.data.lights.new(label, "POINT")
    light.color = color
    light.shadow_soft_size = 0.38
    o = bpy.data.objects.new(label, light)
    scene.collection.objects.link(o)
    return o


def fire_grid(i):
    m, tree, v = material_volume("Combustion " + str(i))
    v.inputs["Color"].default_value = (0.29, 0.27, 0.25, 1)
    v.inputs["Anisotropy"].default_value = 0.12
    attr = add(tree, "ShaderNodeAttribute")
    attr.attribute_name = "density"
    fl = add(tree, "ShaderNodeAttribute")
    fl.attribute_name = "flame"
    local = add(tree, "ShaderNodeTexCoord").outputs["Object"]
    sep = add(tree, "ShaderNodeSeparateXYZ")
    wire(tree, local, sep.inputs[0])
    edge = 1.0
    for j, mx in enumerate([14.0, 6.0, 12.0]):
        lo = smoothmap(tree, sep.outputs[j], 0.05, 1.05 if j < 2 else 0.35)
        hi = number(
            tree,
            "SUBTRACT",
            1,
            smoothmap(tree, sep.outputs[j], mx - (1.3 if j == 2 else 0.85), mx),
        )
        edge = number(tree, "MULTIPLY", edge, number(tree, "MULTIPLY", lo, hi))
    wire(
        tree,
        number(
            tree, "MULTIPLY", number(tree, "MULTIPLY", attr.outputs["Fac"], edge), 3.2
        ),
        v.inputs["Density"],
    )
    heat = add(tree, "ShaderNodeValue").outputs[0]
    radiance = number(
        tree, "MULTIPLY", heat, number(tree, "POWER", fl.outputs["Fac"], 1.65)
    )
    wire(tree, number(tree, "MULTIPLY", radiance, 5.4), v.inputs["Emission Strength"])
    hue = ramp(
        tree,
        fl.outputs["Fac"],
        [
            (0, (0.96, 0.038, 0.002, 1)),
            (0.45, (1, 0.14, 0.006, 1)),
            (0.85, (1, 0.40, 0.036, 1)),
            (1, (1, 0.65, 0.19, 1)),
        ],
    )
    wire(tree, hue, v.inputs["Emission Color"])
    data = bpy.data.volumes.new("Wreck atmosphere " + str(i))
    o = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(o)
    o.data.materials.append(m)
    o.hide_render = True
    o.scale = (0.81 if i == 0 else 1.08,) * 3
    return o, heat, lamp("Reflected fire " + str(i), (1, 0.26, 0.036))


wrecks = [fire_grid(i) for i in range(2)]
volume_dir = args.volumes.resolve()
soot = []
for name, params in take["palette"].items():
    if not params:
        continue
    m = bpy.data.materials[name]
    tree = m.node_tree
    surface = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    base = surface.inputs["Base Color"].links[0].from_socket
    pos = add(tree, "ShaderNodeNewGeometry").outputs["Position"]
    # A fine fringe follows the edge of the blackening. Its origin follows the bent panel.
    irregular = number(tree, "MULTIPLY", noise(tree, pos, 4, 3).outputs["Fac"], 0.55)
    amount = 0.0
    for i in range(2):
        center = add(tree, "ShaderNodeCombineXYZ")
        rad = add(tree, "ShaderNodeValue").outputs[0]
        dist = add(tree, "ShaderNodeVectorMath")
        dist.operation = "DISTANCE"
        wire(tree, pos, dist.inputs[0])
        wire(tree, center.outputs[0], dist.inputs[1])
        inside = number(
            tree, "ADD", number(tree, "SUBTRACT", rad, dist.outputs["Value"]), irregular
        )
        mask = smoothmap(tree, inside, 0, 0.5)
        amount = number(tree, "MAXIMUM", amount, mask)
        soot.append((i, center, rad))
    wire(
        tree,
        mix(
            tree,
            "MIX",
            number(tree, "MULTIPLY", amount, 0.91),
            base,
            (0.023, 0.021, 0.018, 1),
        ),
        surface.inputs["Base Color"],
    )


def cloud(label, color, emission=0):
    bpy.ops.mesh.primitive_cube_add(size=2)
    o = bpy.context.object
    o.name = label
    o.hide_render = True
    m, tree, v = material_volume(label)
    o.data.materials.append(m)
    co = add(tree, "ShaderNodeTexCoord").outputs["Generated"]
    local = vec(tree, "SUBTRACT", vec(tree, "SCALE", co, 2), (1, 1, 1))
    r = add(tree, "ShaderNodeVectorMath")
    r.operation = "LENGTH"
    wire(tree, local, r.inputs[0])
    freq = noise(tree, co, 5.2, 3.0)
    fine = noise(tree, co, 16.5, 2.0)
    rag = number(
        tree,
        "ADD",
        number(tree, "MULTIPLY", freq.outputs["Fac"], 0.63),
        number(tree, "MULTIPLY", fine.outputs["Fac"], 0.18),
    )
    rim = number(tree, "ADD", number(tree, "SUBTRACT", 0.53, r.outputs["Value"]), rag)
    density = add(tree, "ShaderNodeValue").outputs[0]
    body = number(
        tree,
        "MULTIPLY",
        smoothmap(tree, rim, 0, 0.51),
        smoothmap(tree, freq.outputs["Fac"], 0.25, 0.67),
    )
    amount = number(tree, "MULTIPLY", density, body)
    wire(tree, amount, v.inputs["Density"])
    v.inputs["Color"].default_value = color
    v.inputs["Anisotropy"].default_value = 0.22
    if emission:
        wire(
            tree,
            number(tree, "MULTIPLY", amount, emission),
            v.inputs["Emission Strength"],
        )
        v.inputs["Emission Color"].default_value = (1, 0.34, 0.034, 1)
    return o, density


def display_cloud(item, at, size, density, axis=None):
    o, level = item
    o.hide_render = density < 0.008
    if o.hide_render:
        return
    o.location = at
    o.scale = size
    if axis:
        o.rotation_euler = axis.to_track_quat("X", "Z").to_euler()
    level.default_value = density


def chip_geometry():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1)
    p = bpy.context.object
    p.name = "Dirt clod template"
    p.hide_render = True
    mat = bpy.data.materials.new("Turned soil")
    _, surface = new_bsdf(mat)
    surface.inputs["Base Color"].default_value = (0.075, 0.048, 0.021, 1)
    surface.inputs["Roughness"].default_value = 0.98
    p.data.materials.append(mat)
    return p.data


def spark_geometry():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1)
    p = bpy.context.object
    p.hide_render = True
    m = bpy.data.materials.new("Fleeting hot metal")
    _, surface = new_bsdf(m)
    surface.inputs["Emission Color"].default_value = (1, 0.27, 0.035, 1)
    surface.inputs["Emission Strength"].default_value = 7
    p.data.materials.append(m)
    return p.data


bits = [chip_geometry(), spark_geometry()]
effects = []
for i, e in enumerate(events):
    origin = direction(e["from"])
    contact = direction(e["to"])
    course = (contact - origin).normalized()
    clouds = [
        cloud("Muzzle flare", (0.64, 0.25, 0.045, 1), 5),
        cloud("Propellant haze", (0.54, 0.52, 0.48, 1)),
        cloud("Lifted ground dust", (0.42, 0.32, 0.21, 1)),
        cloud("Contact debris", (0.32, 0.245, 0.19, 1)),
    ]
    particles = []
    for q in range(24 if e["ground"] else 18):
        mesh = bits[0 if e["ground"] else 1]
        o = bpy.data.objects.new("Airborne debris", mesh)
        scene.collection.objects.link(o)
        o.hide_render = True
        spray = Vector((rng.normal(0, 1.9), rng.normal(0, 1.55), rng.uniform(1, 5.5)))
        radius = rng.uniform(0.012, 0.08) if e["ground"] else rng.uniform(0.007, 0.018)
        particles.append(
            (o, spray, radius, rng.uniform(0.02, 0.12), rng.uniform(0.15, 0.52))
        )
    effects.append(
        (
            e,
            origin,
            contact,
            course,
            clouds,
            lamp("Flash bounce", (1, 0.66, 0.29)),
            particles,
        )
    )


def battle_effects(frame):
    t = frame / take["fps"]
    r = camera_data[frame]
    for i, (o, heat, glow) in enumerate(wrecks):
        act = r[13 + 4 * i : 17 + 4 * i]
        at = direction(act[:3])
        age = float(act[3])
        k = o.scale[0]
        ignition = 1.8 if i == 0 else 4.2
        o.hide_render = age <= 0.38
        glow.data.energy = 0.0
        if age <= 0.38:
            continue
        nf = min(425, max(1, 1 + round((age - 0.38) * 24)))
        grid_path = volume_dir / f"fluid_data_{nf:04}.vdb"
        if not grid_path.is_file():
            raise FileNotFoundError(f"Missing smoke for frame {frame}: {grid_path}")
        o.data.filepath = str(grid_path)
        o.location = at - Vector((2, 3, 0.5)) * k
        heat.default_value = smooth((age - ignition) / 1.25)
        glow.location = at + Vector((0, 0, 0.36))
        glow.data.energy = heat.default_value * (
            165 + 35 * math.sin(t * 9.8) + 17 * math.sin(t * 17.2)
        )
    for i, center, rad in soot:
        act = r[13 + 4 * i : 17 + 4 * i]
        at = direction(act[:3])
        age = float(act[3])
        for j in range(3):
            center.inputs[j].default_value = at[j]
        rad.default_value = -2 if age <= 0 else 0.09 + 2.75 * smooth(age / 8)
    for e, origin, contact, course, groups, burst, particles in effects:
        age = t - e["time"]
        hit = age - 2 / take["fps"]
        muzzle, smoke, wash, cloudlet = groups
        for obj, level in groups:
            obj.hide_render = True
        burst.data.energy = 0
        if -0.003 <= age < 0.11:
            life = max(0.0, 1 - age / 0.11)
            length = 1.4 + life * 0.8
            display_cloud(
                muzzle,
                origin + course * length * 0.72,
                (length, 0.37, 0.33),
                life * 2.3,
                course,
            )
            burst.location = origin + course * 0.8
            burst.data.energy = 5300 * life**2
        if 0 <= age < 2.85:
            f = age
            display_cloud(
                smoke,
                origin
                + course * (0.7 + 1.5 * f)
                + Vector((0.4 * f, 0.12 * f, 0.35 * f)),
                (1.1 + 1.32 * f, 0.42 + 0.9 * f, 0.42 + 0.75 * f),
                1.2 * math.exp(-1.95 * f),
                course,
            )
            floor = origin + course * (0.85 + 1.2 * f) + Vector((0, 0, -1.0 + 0.12 * f))
            display_cloud(
                wash,
                floor,
                (1.0 + f * 2.1, 1.1 + f * 1.7, 0.28 + f * 0.36),
                0.75 * math.exp(-f * 1.45),
            )
        if 0 <= hit < (3.0 if e["ground"] else 1.5):
            f = hit
            lift = 1.45 if e["ground"] else 0.65
            center = contact + Vector((0.65 * f, 0.12 * f, lift * math.sqrt(f + 0.01)))
            factor = 1.0 if e["ground"] else 0.53
            display_cloud(
                cloudlet,
                center,
                tuple(
                    factor * x
                    for x in (0.65 + 1.35 * f, 0.59 + 0.95 * f, 0.52 + 1.1 * f)
                ),
                (4 if e["ground"] else 1.6) * math.exp(-f * 1.65),
            )
        for o, v, radius, delay, life in particles:
            a = hit - delay * 0.4
            o.hide_render = a < 0 or a > (1.35 if e["ground"] else life)
            if o.hide_render:
                continue
            o.location = contact + v * a + Vector((0, 0, -4.5 * a * a))
            if e["ground"]:
                o.scale = (radius, radius * 0.76, radius * 0.64)
                o.rotation_euler = (a * 8, a * 5, 0)
            else:
                o.scale = (
                    radius * (1 - a / life),
                    radius * 0.60,
                    max(radius, 0.072 * (1 - a / life)),
                )
                o.rotation_euler = (
                    (v + Vector((0, 0, -9 * a))).to_track_quat("Z", "Y").to_euler()
                )


# Age first becomes positive one sample after the initial impact.
burning_frames = np.flatnonzero(np.any(camera_data[:, [16, 20]] > 0, axis=1))
first_fire = (
    max(0, int(burning_frames[0]) - 1) if len(burning_frames) else len(camera_data)
)


def pose(frame):
    ground_time.default_value = frame / take["frames"]
    scene.cycles.samples = 18 if frame >= first_fire else 24
    scene.cycles.adaptive_threshold = 0.047 if frame >= first_fire else 0.041
    scene.cycles.volume_step_rate = 2.1
    scene.cycles.volume_max_steps = 140
    scene.frame_set(frame + 1)
    for j in (0, len(rig) // 2):
        expected = xform(motion[frame, j]).translation
        if (rig[j].matrix_world.translation - expected).length > 0.002:
            raise RuntimeError(f"Unbound game pose at frame {frame}, {rig[j].name}")
    battle_effects(frame)
    for obj, p in zip(rig, motion[frame]):
        if obj.name.startswith("scar"):
            obj.hide_render = bool(abs(p[0]).max() < 0.001)
    record = camera_data[frame]
    cp = record[:12].reshape(4, 3)
    view = np.eye(4)
    view[:3, :3] = axis @ cp[:3].T
    view[:3, 3] = axis @ cp[3]
    camera.matrix_world = Matrix(view)
    camera.data.lens = (camera.data.sensor_height * 0.5) / math.tan(
        math.radians(record[12]) * 0.5
    )


frames = (
    [int(value) for value in args.frames.split(",")]
    if args.frames
    else range(len(motion))
)
for frame in frames:
    if not 0 <= frame < len(motion):
        raise ValueError(f"Frame {frame} outside the recorded take")
    image_path = output_dir / f"{frame:04d}.png"
    if args.resume and image_path.exists():
        continue
    pose(frame)
    # Write each complete frame before replacing its destination; an interrupted
    # background render then resumes at the first unfinished image.
    pending = output_dir / f"{frame:04d}.partial.png"
    scene.render.filepath = str(pending)
    bpy.ops.render.render(write_still=True)
    pending.replace(image_path)
    print(f"Rendered {frame+1}/{len(motion)}", flush=True)
