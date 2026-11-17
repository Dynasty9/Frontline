class_name Headlights
extends Node3D
## (view) After dark the vehicles driving about near the camera have their
## headlights on: a pair of cones down the road ahead, lighting the ground and
## showing in the night's low mist and haze (AirLayers), the way a car's beams
## do on a damp night. A few lights (SLOTS) are shared out among the nearest
## vehicles on the move (a pair each) a few times a second, so however big the column the
## cost stays the same. None by day, and none in the browser (its renderer
## compiles shaders again for every new light, a hitch mid-battle). Looks only.

const SLOTS := 6
## Only vehicles this close to the camera (m) get a light.
const REACH := 240.0
## A vehicle keeps its lights on this long (s) after it last moved: a halt in a
## column doesn't switch the beams off and on.
const LINGER := 5.0

var world
## How dark it is (Atmosphere's LAMPLIGHT for the mood): the lights burn above 0.4.
var level := 0.0
var _lights: Array[SpotLight3D] = []
var _on: Array = []  # the vehicle each light is on, or null
var _pick_t := 0.0
var _t := 0.0
## (a peer isn't sent the vehicles' speeds, so whether each is on the move
## comes from where it was at the last look)
var _last := {}  # eid -> where it was at the last pick
var _moved := {}  # eid -> _t it last moved


func setup(w) -> void:
	world = w
	name = "Headlights"
	# (a pair a vehicle: two narrow cones, bright at the lamp and gone in 20-odd m)
	for i in SLOTS * 2:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.96, 0.86)  # (the cool white-yellow of a halogen lamp)
		l.spot_range = 24.0
		l.spot_angle = 16.0
		l.spot_angle_attenuation = 1.4
		l.spot_attenuation = 1.6
		l.light_specular = 0.4
		l.shadow_enabled = false
		# (the beam shows in the air: the night's low haze, the mist in the
		# hollows, the dust a column raises)
		l.light_volumetric_fog_energy = 60.0
		l.visible = false
		add_child(l)
		_lights.append(l)
	for i in SLOTS:
		_on.append(null)


func _process(dt: float) -> void:
	_t += dt
	var on := level > 0.4
	_pick_t -= dt
	if _pick_t <= 0.0:
		_pick_t = 0.25
		_pick(on)
	var energy := 4.0 * clampf((level - 0.4) / 0.4, 0.0, 1.0)
	for i in SLOTS:
		var v = _on[i]
		if v == null or not is_instance_valid(v):
			_on[i] = null
			_lights[i * 2].visible = false
			_lights[i * 2 + 1].visible = false
			continue
		var size: Vector3 = v.vdef.get("size", Vector3(2.3, 2.6, 6.0))
		var xf: Transform3D = (v as Node3D).global_transform
		for side in 2:
			var l := _lights[i * 2 + side]
			# (low on the front of the hull either side, dipped a little toward the road)
			var at: Transform3D = xf * Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(size.x * (0.32 if side == 0 else -0.32), size.y * 0.36, -size.z * 0.5 - 0.15))
			l.global_transform = Transform3D(at.basis.orthonormalized(), at.origin)
			l.light_energy = energy
			l.visible = true


## The nearest vehicles on the move get the lights.
func _pick(on: bool) -> void:
	var near: Array = []
	var cam := Vector3.INF
	if on and world.cam and world.cam.cam:
		cam = world.cam.cam.global_position
	var seen := {}
	for v in world.vehicles:
		if not is_instance_valid(v) or v.is_air() or v.is_boat():
			continue
		var p: Vector3 = v.position
		seen[v.eid] = true
		var was: Vector3 = _last.get(v.eid, p)
		_last[v.eid] = p
		if Defs.flat(p - was).length() > 0.3:  # (over a quarter of a second: over 1 m/s)
			_moved[v.eid] = _t
		if cam == Vector3.INF or v.health_frac() <= 0.0 or _t - float(_moved.get(v.eid, -99.0)) > LINGER:
			continue
		var d := cam.distance_to(p)
		if d < REACH:
			near.append([d, v])
	for eid in _last.keys():
		if not seen.has(eid):
			_last.erase(eid)
			_moved.erase(eid)
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in SLOTS:
		_on[i] = near[i][1] if i < near.size() else null
