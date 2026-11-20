extends Node
## The smoke's shadow map without a battle: a smoke screen's blobs land on the
## sunward side's opposite, stretched along the sun the lower it is, keeping
## the smoke's total depth; blobs out of the map's reach are left out; the
## shadow goes with the sun below the horizon and with the flip; and the
## shaders that light with the clouds' shade carry the smoke's as well, the
## air's fog taking it only from smoke above it.


class FakeWorld:
	extends RefCounted
	var fx = null
	var cam = null
	var smoke_projectiles: Array = []
	var water = null
	var vehicles: Array = []
	var terrain = null
	var atmo = null
	var town_rect := Rect2()

	func ground_y(_p: Vector3) -> float:
		return 0.0


class FakeCam:
	extends RefCounted
	var dist := 50.0
	var focus_pos := Vector3.ZERO


class FakeAtmo:
	extends RefCounted
	var sun: DirectionalLight3D


class FakeAir:
	extends RefCounted
	var atmo: FakeAtmo
	var plumes = null
	var trails = null
	var mat = null
	var _flip_frame := -1


class FakeCanister:
	extends Node3D
	var smoke_r := 6.5
	var eid := 3


var world: FakeWorld
var air: FakeAir
var sh: SmokeShadow


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	world = FakeWorld.new()
	world.cam = FakeCam.new()
	air = FakeAir.new()
	air.atmo = FakeAtmo.new()
	air.atmo.sun = DirectionalLight3D.new()
	add_child(air.atmo.sun)
	sh = SmokeShadow.new()
	add_child(sh)
	sh.setup(world, air)
	_check_overhead()
	_check_low_sun()
	_check_reach()
	_check_screen()
	_check_night()
	_check_shaders()
	print("SMOKE SHADOW passed")
	get_tree().quit()


## Points the sun along `to_sun` and ticks the map once.
func _sun(to_sun: Vector3) -> void:
	var s := air.atmo.sun
	s.global_transform = Transform3D(Basis.looking_at(-to_sun.normalized(), Vector3.UP if absf(to_sun.normalized().y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	sh.tick(0.1)


## The blob drawn last: its spread in texels (the transform's columns are
## three deviations either side), where it lands, and its peak depth.
func _last() -> Array:
	return _blob(sh._n - 1)


func _blob(i: int) -> Array:
	var b: PackedFloat32Array = sh.buf.slice(i * 12, i * 12 + 12)
	var texel: float = sh._span / SmokeShadow.MAP
	var at := Vector2(b[3], b[7]) * texel + sh._origin
	# the spread's covariance (m^2) back from its factor [[b0, b1], [b4, b5]] / 6
	var a := Transform2D(Vector2(b[0], b[4]) / 6.0 * texel, Vector2(b[1], b[5]) / 6.0 * texel, Vector2.ZERO)
	var cov_xx := a.x.x * a.x.x + a.y.x * a.y.x
	var cov_zz := a.x.y * a.x.y + a.y.y * a.y.y
	var cov_xz := a.x.x * a.x.y + a.y.x * a.y.y
	return [at, cov_xx, cov_zz, cov_xz, b[8], b[9] * SmokeShadow.H_SCALE, b[10] * SmokeShadow.S_SCALE]


## Sun straight overhead: the blob lies right under the smoke, its own shape,
## at its own depth.
func _check_overhead() -> void:
	_sun(Vector3.UP)
	sh._n = 0
	sh.puff(Vector3(10.0, 12.0, -5.0), 6.0, 3.0, 2.0, 0.0, 1.0, 0.0)
	var b := _last()
	assert((b[0] as Vector2).distance_to(Vector2(10.0, -5.0)) < 0.01, "overhead, the shadow is under the smoke")
	var texel: float = sh._span / SmokeShadow.MAP
	var widen := 0.64 * texel * texel
	assert(absf(float(b[1]) - (36.0 + widen)) < 0.05 and absf(float(b[2]) - (9.0 + widen)) < 0.05, "its own shape: %s" % [b])
	# (widened by the map's texel, its depth thinned to keep the total)
	var kept := float(b[4]) * sqrt(float(b[1]) * float(b[2])) / (6.0 * 3.0)
	assert(absf(kept - 1.0) < 0.01, "the smoke's total depth kept: %.3f" % kept)
	assert(absf(float(b[5]) - 12.0) < 0.1 and absf(float(b[6]) - 2.0) < 0.05, "its height kept")


## A low sun in the west: the shadow is thrown east, as far as the smoke is
## high over the cotangent, stretched east-west by its depth, and the slanting
## rays go through more of it.
func _check_low_sun() -> void:
	var elev := deg_to_rad(15.0)
	_sun(Vector3(-cos(elev), sin(elev), 0.0))
	sh._n = 0
	sh.puff(Vector3(0.0, 10.0, 0.0), 3.0, 3.0, 2.0, 0.0, 1.0, 0.0)
	var b := _last()
	var off := 10.0 / tan(elev)
	assert((b[0] as Vector2).distance_to(Vector2(off, 0.0)) < 0.05, "thrown downsun: %s, not %.1f" % [b[0], off])
	assert(float(b[1]) > float(b[2]) * 3.0, "long along the sun")
	# total depth over the ground: tau * area / sin(elevation)
	var total := float(b[4]) * sqrt(float(b[1]) * float(b[2]) - float(b[3]) * float(b[3]))
	assert(absf(total - 9.0 / sin(elev)) < 0.1, "the slanting rays cross more smoke: %.2f" % total)


## Smoke beyond the map's reach isn't drawn.
func _check_reach() -> void:
	_sun(Vector3.UP)
	sh._n = 0
	sh.puff(Vector3(5000.0, 5.0, 0.0), 3.0, 3.0, 2.0, 0.0, 1.0, 0.0)
	assert(sh._n == 0, "far smoke left out")
	sh.puff(Vector3(0.0, 5.0, 0.0), 3.0, 3.0, 2.0, 0.0, 0.001, 0.0)
	assert(sh._n == 0, "smoke too thin to see left out")


## A smoke round's screen: blobs downwind of the canister, dense in the core.
func _check_screen() -> void:
	var can := FakeCanister.new()
	can.position = Vector3(20.0, 0.0, 10.0)
	world.smoke_projectiles = [can]
	_sun(Vector3(0.2, 1.0, 0.1))
	assert(sh._n >= 2, "the screen throws a shadow (%d blobs)" % sh._n)
	assert(float(_blob(0)[4]) > 1.0, "its core is dense: %.2f" % float(_blob(0)[4]))
	var at: Vector2 = _blob(1)[0]
	var downwind := (at - Vector2(20.0, 10.0)).dot(Vector2(Fires.WIND.x, Fires.WIND.z).normalized())
	assert(downwind > 0.0, "its tail lies downwind")
	assert(sh.shown > 0.99, "shown")
	# the flip turns it off
	sh.enabled_k = 0.0
	sh.tick(0.1)
	assert(sh.shown == 0.0 and sh._n == 0, "flipped off")
	sh.enabled_k = 1.0
	can.free()
	world.smoke_projectiles = []


## No sun up, no shadow.
func _check_night() -> void:
	_sun(Vector3(0.3, -0.4, 0.2))
	assert(sh.shown == 0.0, "no shadow with the sun down")


## Every surface lighting with the clouds' shade takes the smoke's; the air's
## fog takes the clouds' at the ground and the smoke's at its own height.
func _check_shaders() -> void:
	assert(CloudShadow.PATTERN.contains("float smoke_sun(vec3 p)") and CloudShadow.PATTERN.contains("return cloud_only(p) * smoke_sun(p);"))
	var ground := CloudShadow.shader(Atmosphere.GROUND_SHADER, CloudShadow.OWN_LIGHT, false)
	assert(ground.contains("smoke_sun(") and ground.contains("global uniform sampler2D smoke_shadow"))
	assert(AirLayers.AIR_SHADER.contains("cloud_only(p - to_sun * (h / max(to_sun.y, 0.2))) * smoke_sun(p)"))
	for name in ["smoke_shadow", "smoke_shadow_map", "smoke_shadow_sun"]:
		assert(ProjectSettings.has_setting("shader_globals/" + name), "%s declared" % name)
