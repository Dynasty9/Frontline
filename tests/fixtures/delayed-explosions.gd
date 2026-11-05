extends "res://tests/fixtures/actors.gd"

class DeferredWorld extends ActorWorld:
	var spawned := []
	func spawn(kind: String, data: Dictionary) -> Entity:
		spawned.append([kind, data])
		return null

class RubbleCombat extends ActorCombat:
	func explode(pos: Vector3, data: Dictionary) -> void:
		super.explode(pos, data)
		world.defer_rubble(pos, 0.37, Vector3(8, 0, 2.4))


func canonical(events: Array) -> Array:
	var result := []
	for event: Array in events:
		var d: Dictionary = event[1]
		result.append([event[0], PackedFloat64Array([d.dmg, d.radius, d.fling, d.get("at", 0.0), d.get("track", 0.3), d.size, d.get("struct_mult", 1.0)])])
	return result

func _ready() -> void:
	var cases := 0
	var delivered := 0
	for trial in 128:
		var reference := DeferredEffects.new(false)
		var native := DeferredEffects.new()
		var old_rng := SimulationRandom.new()
		var new_rng := SimulationRandom.new()
		old_rng.seed = trial + 137
		new_rng.seed = trial + 137
		var initial := Vector3(3.1, 0.7, -7.9)
		var supply: float = [-10.0, 0.0, 31.0, 77.3, 160.0, 200.0][trial % 6]
		for p in [initial, -initial]:
			reference.cook_off(0.0, p, supply, old_rng)
			native.cook_off(0.0, p, supply, new_rng)
		assert(old_rng.state == new_rng.state)
		var pending: Array = native._native.pending()
		assert(pending.size() == reference._pending.size())
		for i in pending.size():
			assert(pending[i][0] == reference._pending[i][0] and pending[i][1] == reference._pending[i][1])
		for tick in 300:
			var now := tick / 30.0
			if tick % 17 == 0:
				for effects in [reference, native]:
					effects.defer_rubble(Vector3(1.3, 0, tick * 0.13), tick * 0.37, Vector3(8, 0, 2.4))
			if tick == 71:
				reference.cook_off(now, Vector3.ONE, 97.3, old_rng)
				native.cook_off(now, Vector3.ONE, 97.3, new_rng)
			var expected := canonical(reference.advance_to(now))
			var actual := canonical(native.advance_to(now))
			assert(expected == actual, "delayed blast %d/%d" % [trial, tick])
			delivered += actual.size()
			assert(old_rng.state == new_rng.state)
			if tick % 17 == 0:
				var saved: PackedByteArray = native._native.checkpoint()
				assert(native._native.restore(saved) and native._native.checkpoint() == saved)
				var bad := saved.duplicate()
				bad[4] = 2
				assert(not native._native.restore(bad) and native._native.checkpoint() == saved)
			assert(reference.take_rubble() == native.take_rubble())
			cases += 1
		assert(reference._pending.is_empty() and native._native.pending().is_empty())
	# The live World drains the same queue. A cache is gone before any of its damage is applied.
	var w := DeferredWorld.new()
	w.srv = true
	w.has_view = false
	w.combat = RubbleCombat.new(w)
	add_child(w)
	var cache := Mount.new()
	cache.world = w
	cache.skind = "ammo_cache"
	cache.supply = 160.0
	cache.position = Vector3(3, 0, -7)
	w.time = 10.0
	cache._cook_off()
	cache.free()
	var building := Mount.new()
	building.world = w
	building.skind = "barracks"
	building.position = Vector3(-3, 0, 7)
	building.size = Vector3(10, 3, 4)
	building.yaw = 0.731
	building._destroyed()
	building.free()
	assert(w.spawned.is_empty())
	assert(w.combat.explosions.is_empty())
	w._run_deferred_effects()
	assert(w.combat.explosions.is_empty())
	# Rendering or polling without advancing battle time must not fire pending damage.
	for i in 60:
		w._run_deferred_effects()
	assert(w.combat.explosions.is_empty())
	w.time = 10.05
	w._run_deferred_effects()
	assert(w.combat.explosions.size() == 1 and w.spawned.size() == 2)
	assert(w.spawned[0] == ["structure", {"skind": "rubble", "pos": Vector3(-3, 0, 7), "yaw": 0.731, "size": Vector3(8, 0, 2.4)}])
	w.time = 30.0
	w._run_deferred_effects()
	assert(w.combat.explosions.size() == 9 and w.spawned.size() == 10)
	w._run_deferred_effects()
	assert(w.combat.explosions.size() == 9 and w.spawned.size() == 10)
	var fresh := DeferredEffects.new()
	assert(fresh.advance_to(30.0).is_empty())
	print("DELAYED_EXPLOSIONS passed steps=%d blasts=%d" % [cases, delivered])
	get_tree().quit()
