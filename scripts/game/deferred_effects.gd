class_name DeferredEffects extends RefCounted
## Damage and rubble belong to the simulation, independently of rendering callbacks.

var _native: RefCounted
var _pending := []
var _rubble := []
var _sequence := 0
var _time := 0.0

func _init(use_native := true) -> void:
	if use_native and ClassDB.class_exists("DeferredEffectsCore"):
		_native = ClassDB.instantiate("DeferredEffectsCore")

func cook_off(now: float, position: Vector3, supply: float, rng: SimulationRandom) -> void:
	if _native:
		var count: int = _native.cook_off(now, position, supply, rng._backend)
		assert(count >= 0, "Invalid cache cook-off")
		return
	# Engine-only checkouts use the same simulation clock until the standalone server replaces them.
	assert(now >= _time and now >= 0.0 and now <= 1e12 and position.is_finite() and is_finite(supply))
	var left := clampf(supply / Structure.CACHE_STOCK, 0.2, 1.0)
	var at := position + Vector3(0, 0.6, 0)
	for i in int(4 + 5 * left):
		var big := i == 0
		var p := at if big else at + Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.5, 1.5))
		var d := {"dmg": 90.0 * left + 40.0, "radius": 4.0 + 2.0 * left, "fling": 8.0, "at": 60.0, "src": null, "size": 1.2 + left} if big \
			else {"dmg": 35.0, "radius": 2.5, "fling": 4.0, "src": null, "size": 0.5}
		var deadline := now + (0.05 if big else 0.5 + i * rng.randf_range(0.35, 0.9))
		_pending.append([deadline, _sequence, p, d])
		_sequence += 1
	_pending.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))

func advance_to(now: float) -> Array:
	var due := []
	if _native:
		var result: Array = _native.advance_to(now)
		assert(result.size() == 1, "Invalid delayed-explosion clock")
		for event: Array in result[0]:
			var v: PackedFloat64Array = event[2]
			due.append([event[1], {"dmg": v[0], "radius": v[1], "fling": v[2], "at": v[3], "track": v[4], "size": v[5], "struct_mult": v[6], "src": null}])
		return due
	assert(now >= _time and now <= 1e12)
	_time = now
	while not _pending.is_empty() and float(_pending[0][0]) <= now:
		var event: Array = _pending.pop_front()
		due.append([event[2], event[3]])
	return due

func defer_rubble(position: Vector3, yaw: float, size: Vector3) -> void:
	if _native:
		var valid: bool = _native.defer_rubble(position, yaw, size)
		assert(valid, "Invalid deferred rubble")
		return
	_rubble.append([position, yaw, size])

func take_rubble() -> Array:
	if _native:
		return _native.take_rubble()
	var pending := _rubble
	_rubble = []
	return pending
