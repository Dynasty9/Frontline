extends Node

class DebrisFx extends Fx:
	func _visible_at(_p: Vector3) -> bool:
		return true

	func _puff(_kind: String, _pos: Vector3, _dir := Vector3.UP) -> void:
		pass


func _ready() -> void:
	var world := World.new()
	world.has_view = false
	world.rng.seed = 3187
	var reference := RandomNumberGenerator.new()
	reference.seed = 3187
	var effects := DebrisFx.new()
	effects.world = world
	add_child(effects)
	var initial := world.rng.state
	# The fallback runs only for visible debris without cosmetic physics.
	for count in [1, 7, 20]:
		effects._debris(Vector3.ZERO, Color.GRAY, count)
	assert(effects._movers.size() == 28)
	assert(world.rng.state == initial, "Drawing debris must not change gameplay randomness")
	for i in 100:
		assert(world.rng.randi() == reference.randi())
	effects.free()
	world.free()
	print("COSMETIC_RANDOM passed")
	get_tree().quit()
