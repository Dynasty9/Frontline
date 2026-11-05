class_name SimulationRandom
extends RefCounted
## The same seeded gameplay stream in the Rust core and engine-only checkouts.

var _backend: RefCounted
var seed: int:
	get:
		return _backend.get_seed()
	set(value):
		_backend.set_seed(value)
var state: int:
	get:
		return _backend.get_state()
	set(value):
		_backend.set_state(value)


func _init() -> void:
	_backend = ClassDB.instantiate("SimulationRandomCore") if ClassDB.class_exists("SimulationRandomCore") else RandomNumberGenerator.new()
	seed = 1


func randi() -> int:
	return _backend.randi()


func randf() -> float:
	return _backend.randf()


func randf_range(from: float, to: float) -> float:
	return _backend.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _backend.randi_range(from, to)
