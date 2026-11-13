class_name Lightning
extends Node3D
## Lightning over a rain battle: a bolt you can see, the light it throws, and
## its thunder arriving as late as the bolt is far. All of it is looks (it
## draws on the global `randf`, never the world's generator), and only a peer
## with a view makes any.
##
## A strike is a stepped leader feeling its way down from the cloud base in
## jagged steps of ten or twenty metres, forking as it goes, then two to four
## return strokes lighting the whole channel in a flicker a few tenths of a
## second long. The bolt is drawn as ribbons along the channel that turn to
## face the camera and stay a few pixels wide at any range, emissive and
## brighter than anything else in the frame, so the glow pass blooms them. Its
## light: the clouds round it light from within (the sky shader's flash), the
## battlefield takes a flash from the bolt's side (Atmosphere turns the rim
## light towards it), and on Forward+ a light low on the channel lights the
## ground beneath it. Some flashes stay in the cloud: a dimmer crawler along
## the cloud base. Sound covers a kilometre in about three seconds (343 m/s),
## so the thunder comes as late as the nearest part of the channel is far, and
## the further it has come the lower and quieter it is.

const SOUND_SPEED := 343.0
const TINT := Color(0.78, 0.84, 1.0)

var world: World
## This frame's strike, for the light it throws (Atmosphere): how bright
## (0..1), where it is from the camera (towards the top of the channel), and
## how near (1 inside 500 m, a quarter at 2 km, as the light falls off).
var flash := 0.0
var flash_dir := Vector3.UP
var flash_near := 0.0
## How much light the rain-filled air takes out of the bolt over each metre
## (Atmosphere sets it from the fog).
var haze := 0.0006

var _bolt: MeshInstance3D
var _mat: ShaderMaterial
var _light: OmniLight3D  # (Forward+ only: the browser lights every object in reach again for it)
var _lit := false  # whether this strike lights the ground beneath it
var _age := -1.0  # seconds since the strike began (-1: none)
var _strokes := PackedFloat32Array()  # when each return stroke flashes, from the strike's start
var _glow := 1.0  # how brightly this one shows (a flash in the cloud is muffled)
var _top := Vector3.ZERO
var _thunder: Array = []  # [seconds to go, direction from the camera, metres, seconds since the strike]
## The last thunder to arrive: how long after its strike, and from how far (m).
var last_thunder := Vector2(-1.0, -1.0)


func _init(w: World) -> void:
	world = w
	name = "Lightning"
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BOLT_SHADER
	_mat.shader = sh
	_bolt = MeshInstance3D.new()
	_bolt.material_override = _mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.extra_cull_margin = 24.0  # (the ribbons widen in the vertex shader)
	_bolt.visible = false
	add_child(_bolt)
	if not Vfx.gl:
		_light = OmniLight3D.new()
		_light.light_color = TINT
		_light.omni_range = 520.0
		_light.omni_attenuation = 0.4
		_light.shadow_enabled = false
		_light.light_volumetric_fog_energy = 0.0
		_light.visible = false
		add_child(_light)


## Strikes somewhere the camera can see: ahead of it, a few hundred metres to a
## couple of kilometres out, mostly far; now and then the flash stays in the cloud.
func strike_somewhere() -> void:
	if world.cam == null or world.cam.cam == null:
		return
	var c := world.cam.cam
	var ahead := -c.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var d := 320.0 + 2100.0 * pow(randf(), 1.3)
	var at := c.global_position + ahead.rotated(Vector3.UP, randf_range(-0.85, 0.85)) * d
	strike(at, randf() < 0.3)


## A strike down to `at` (its height is found here), or a flash in the cloud
## above it.
func strike(at: Vector3, in_cloud := false) -> void:
	if world.cam == null or world.cam.cam == null:
		return
	var inside := absf(at.x) < MapDims.HALF and absf(at.z) < MapDims.HALF
	# (beyond the map the scenery's hills stand in the way: run the channel into
	# the ground and let the depth buffer cut it where it meets them)
	at.y = world.ground_y(at) - 1.0 if inside else -40.0
	strike_seen_from(world.cam.cam.global_position, at, in_cloud)


## A strike down to `at` (or a flash in the cloud above it), seen and heard
## from `eye`.
func strike_seen_from(eye: Vector3, at: Vector3, in_cloud := false) -> void:
	_top = Vector3(at.x + randf_range(-80.0, 80.0), maxf(at.y, 0.0) + randf_range(420.0, 650.0), at.z + randf_range(-80.0, 80.0))
	var b := Builder.new()
	var channel: PackedVector3Array
	if in_cloud:
		# a crawler along the cloud base, forking sideways
		var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(380.0, 800.0)
		channel = _walk(_top, _top + away + Vector3(0, randf_range(-60.0, 20.0), 0), 22.0, 0.9, 70, 0.25)
		b.strip(channel, 1.0, 1.3, 0.0, 1.0)
		_branches(b, channel, 0.35, 0.0, Vector3(0, -0.15, 0))
		_glow = 0.35
	else:
		channel = _walk(_top, at, 15.0, 0.75, 90, 1.0)
		b.strip(channel, 1.0, 1.0, 0.0, 1.0)
		_branches(b, channel, 0.5, 0.0, Vector3(0, -1.0, 0))
		_glow = 1.0
	_bolt.mesh = b.mesh()
	_bolt.visible = true
	# Two to four return strokes down the one channel, tens of milliseconds
	# apart: the flicker. A flash in the cloud has fewer, softer ones.
	_strokes.clear()
	var t := 0.04  # the leader takes this long to reach the ground
	for i in (randi_range(1, 2) if in_cloud else randi_range(2, 4)):
		_strokes.append(t)
		t += randf_range(0.05, 0.13)
	_age = 0.0
	flash_dir = (_top - eye).normalized()
	var nearest := INF
	for p in channel:
		nearest = minf(nearest, p.distance_to(eye))
	flash_near = clampf(500.0 / nearest, 0.15, 1.0)
	_mat.set_shader_parameter("haze", haze)
	_lit = _light != null and int(Settings.get_v("effects")) >= 1 and not in_cloud
	if _lit:
		_light.global_position = channel[int(channel.size() * 0.8)]
	if OS.has_environment("FL_DEBUG_LIGHTNING"):
		print("LIGHTNING %s at %s: nearest %.0f m, thunder due in %.2f s" % ["in the cloud" if in_cloud else "strike", at.round(), nearest, nearest / SOUND_SPEED])
	var heading := channel[_closest(channel, eye)] - eye
	_thunder.append([nearest / SOUND_SPEED, heading.normalized(), nearest, 0.0])


## How bright the channel is `t` seconds into the strike: each return stroke
## flares and dies in about a tenth of a second, with a dimmer glow between
## them while current still runs.
func _brightness(t: float) -> float:
	var b := 0.0
	for s in _strokes:
		var u := t - s
		if u >= 0.0:
			b = maxf(b, exp(-u * 22.0) * 0.85 + exp(-u * 6.0) * 0.15)
	return b


func tick(dt: float) -> void:
	if _age >= 0.0:
		_age += dt
		var b := _brightness(_age)
		flash = b * _glow
		_mat.set_shader_parameter("flash", b * _glow)
		_mat.set_shader_parameter("reach", clampf(_age / 0.04, 0.0, 1.0))
		if _lit:
			_light.visible = b > 0.02
			_light.light_energy = 7.0 * b
		if _age > _strokes[_strokes.size() - 1] + 0.5:
			_age = -1.0
			flash = 0.0
			_bolt.visible = false
			_bolt.mesh = null
			if _lit:
				_light.visible = false
				_lit = false
	for i in range(_thunder.size() - 1, -1, -1):
		var th: Array = _thunder[i]
		th[0] = float(th[0]) - dt
		th[3] = float(th[3]) + dt
		if float(th[0]) <= 0.0:
			_thunder.remove_at(i)
			last_thunder = Vector2(float(th[3]), float(th[2]))
			_rumble(th[1], float(th[2]))


## The thunder reaching the camera from `metres` away along `heading`: a sharp
## crack close by; from kilometres off only the low rumble is left, quieter.
func _rumble(heading: Vector3, metres: float) -> void:
	var far := smoothstep(350.0, 3000.0, metres)
	if OS.has_environment("FL_DEBUG_LIGHTNING"):
		print("THUNDER from %.0f m, %.2f s after its strike: %.1f dB, pitch %.2f" % [metres, last_thunder.x, lerpf(8.0, -9.0, far), lerpf(1.05, 0.68, far)])
	if world == null or world.cam == null or world.cam.cam == null:
		return
	var at := world.cam.cam.global_position + heading * 45.0 + Vector3(0, 20, 0)
	Sfx.play("thunder", at, lerpf(8.0, -9.0, far), lerpf(1.05, 0.68, far), &"Ambience")


static func _closest(pts: PackedVector3Array, to: Vector3) -> int:
	var best := 0
	for i in pts.size():
		if pts[i].distance_squared_to(to) < pts[best].distance_squared_to(to):
			best = i
	return best


## A channel feeling its way from `from` towards `to` in jagged steps about
## `step` metres long, each turned aside at random (`wander`) with some memory
## of the last turn, so it zig-zags rather than jitters. `drop` keeps a channel
## that should stay level (in the cloud) from wandering up and down. Each step
## is then kinked twice over at finer scales: a channel is as crooked at a
## metre as at a hundred.
static func _walk(from: Vector3, to: Vector3, step: float, wander: float, steps: int, drop: float) -> PackedVector3Array:
	var pts := PackedVector3Array([from])
	var p := from
	var aside := Vector3.ZERO
	for i in steps:
		var left := to - p
		if left.length() < step:
			pts.append(to)
			break
		var kick := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3) * drop, randf_range(-1.0, 1.0)) * wander
		aside = aside * 0.45 + kick
		p += (left.normalized() + aside).normalized() * step * randf_range(0.55, 1.45)
		pts.append(p)
	for level in 2:
		var fine := PackedVector3Array([pts[0]])
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var off := Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5) * drop, randf_range(-1.0, 1.0))
			fine.append((a + b) * 0.5 + off * a.distance_to(b) * 0.22)
			fine.append(b)
		pts = fine
	return pts


## Forks off a channel: here and there a branch strays away and down, dimmer
## and thinner, and now and then forks again; they die out before the ground.
func _branches(b: Builder, channel: PackedVector3Array, bright: float, depth: float, lean: Vector3) -> void:
	var n := channel.size()
	for i in range(1, n - 3):
		var share := float(i) / n
		if randf() > (0.075 if depth == 0.0 else 0.04) * (1.0 - share * 0.6):
			continue
		var from := channel[i]
		var out := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		var reach := randf_range(60.0, 190.0) * (1.0 if depth == 0.0 else 0.55)
		var goal := from + out * reach + lean * reach * randf_range(0.6, 1.4)
		var fork := _walk(from, goal, 11.0, 0.95, randi_range(4, 14) if depth == 0.0 else randi_range(2, 7), 1.0)
		var k := bright * randf_range(0.55, 1.0)
		b.strip(fork, k, 0.55 if depth == 0.0 else 0.35, share, share + 0.25)
		if depth == 0.0 and fork.size() > 12:
			_branches(b, fork, k * 0.55, 1.0, lean)


## The bolt's mesh: each channel a strip of quads whose two edges the shader
## pushes apart, across the line of sight. Per vertex: its place on the
## channel; the channel's direction there (NORMAL); which edge and how bright
## (UV); how far down the bolt it is, for the leader, and how wide (UV2).
class Builder:
	var verts := PackedVector3Array()
	var dirs := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()

	func strip(pts: PackedVector3Array, bright: float, width: float, along0: float, along1: float) -> void:
		var n := pts.size()
		if n < 2:
			return
		var first := verts.size()
		for i in n:
			var dir := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var along := lerpf(along0, along1, float(i) / (n - 1))
			# (a branch thins and dims towards its tip)
			var k := bright * (1.0 - 0.5 * float(i) / (n - 1) if bright < 1.0 else 1.0)
			for side in [-1.0, 1.0]:
				verts.append(pts[i])
				dirs.append(dir)
				uvs.append(Vector2(side, k))
				uv2s.append(Vector2(along, width))
			if i > 0:
				var a := first + (i - 1) * 2
				idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 2, a + 1, a + 3]))

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = dirs
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


const BOLT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;
uniform float flash = 0.0;  // the strokes' flicker, 0..1
uniform float reach = 1.0;  // how far down the bolt the leader has got
uniform float haze = 0.0006;  // the rain-filled air's extinction (per metre)
uniform vec3 tint : source_color = vec3(0.78, 0.84, 1.0);
varying float side;
varying float bright;
void vertex() {
	vec3 to_cam = CAMERA_POSITION_WORLD - VERTEX;
	float d = length(to_cam);
	vec3 across = cross(NORMAL, to_cam / max(d, 0.001));
	float l = length(across);
	across = l > 0.001 ? across / l : vec3(1.0, 0.0, 0.0);
	// a channel is centimetres across but glares far wider: a few pixels at any range
	VERTEX += across * UV.x * max(0.8, d * 0.008) * UV2.y;
	side = UV.x;
	bright = UV.y * (1.0 - smoothstep(reach - 0.02, reach, UV2.x)) * exp(-d * haze);
}
void fragment() {
	float core = exp(-side * side * 160.0);
	// (the browser draws in low dynamic range: a wide glow there is only a thick line)
	float glow = exp(-side * side * 9.0) * (OUTPUT_IS_SRGB ? 0.15 : 1.0) + exp(-side * side * 2.5) * (OUTPUT_IS_SRGB ? 0.0 : 0.25);
	ALBEDO = (vec3(1.0) * core * 22.0 + tint * glow * 2.2) * bright * flash;
}
"""
