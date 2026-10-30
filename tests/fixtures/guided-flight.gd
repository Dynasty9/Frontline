extends Node

var max_position_error := 0.0
var max_velocity_error := 0.0
var max_direction_error := 0.0

class MissileWorld extends World:
	func despawn(e: Entity) -> void:
		e.gone = true

class MissileCombat extends Combat:
	var explosions: Array = []
	var smoke := false
	func ray(_a: Vector3, _b: Vector3, _ex: Array = []) -> Dictionary:
		return {}
	func smoke_blocks(_a: Vector3, _b: Vector3) -> bool:
		return smoke
	func explode(pos: Vector3, data: Dictionary) -> void:
		explosions.append([pos, data])


func _ready() -> void:
	assert(ClassDB.class_exists("GuidedFlightCore"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 87392
	for trial in 96:
		var target := Soldier.new()
		target.eid = 2
		target.position = Vector3(rng.randf_range(20, 200), rng.randf_range(0, 60), rng.randf_range(-100, 100))
		var operator := Soldier.new()
		operator.eid = 1
		var pair: Array[Projectile] = [Projectile.new(), Projectile.new()]
		var worlds: Array[MissileWorld] = [MissileWorld.new(), MissileWorld.new()]
		var start := Vector3(0, rng.randf_range(2, 15), 0)
		var velocity := Vector3(rng.randf_range(-20, 20), rng.randf_range(-2, 20), rng.randf_range(-20, 20))
		var kind := "atgm" if trial < 48 else "sam"
		for i in 2:
			worlds[i].has_view = false
			worlds[i].entities = {1: operator, 2: target}
			worlds[i].combat = MissileCombat.new(worlds[i])
			worlds[i].combat.enable_native_collision()
			pair[i].world = worlds[i]
			pair[i].apply_props({"ptype": kind, "pos": start, "vel": velocity, "tgt": 2, "thrower": 1, "target": target.position})
		pair[1]._guided = ClassDB.instantiate("GuidedFlightCore")
		assert(pair[1]._guided.reset(kind == "atgm", start, velocity, target.position, 0.0, true))
		var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
		for tick in 500:
			if trial % 4 == 0 and tick == 12:
				target.gone = true
			if trial % 4 == 1:
				for w in worlds:
					(w.combat as MissileCombat).smoke = tick >= 8
			if trial % 4 == 2 and tick == 5:
				operator.gone = true
			target.position.z += 2.0 * dt
			if tick % 13 == 0:
				var checkpoint: PackedByteArray = pair[1]._guided.checkpoint()
				assert(pair[1]._guided.restore(checkpoint))
				var bad := checkpoint.duplicate()
				bad[4] = 2
				assert(not pair[1]._guided.restore(bad))
				assert(pair[1]._guided.checkpoint() == checkpoint)
			for p in pair:
				p.sim(dt)
			max_position_error = maxf(max_position_error, pair[0].position.distance_to(pair[1].position))
			max_velocity_error = maxf(max_velocity_error, pair[0].vel.distance_to(pair[1].vel))
			# Godot and pinned libm round differently; impact frames and decisions remain exact.
			assert(pair[0].position.distance_to(pair[1].position) < 0.005, "Missile position trial=%d tick=%d expected=%s actual=%s" % [trial, tick, pair[0].position, pair[1].position])
			assert(pair[0].vel.distance_to(pair[1].vel) < 0.01, "Missile velocity trial=%d tick=%d expected=%s actual=%s delta=%s" % [trial, tick, pair[0].vel, pair[1].vel, pair[0].vel.distance_to(pair[1].vel)])
			for key in ["target", "tgt_id", "life_t", "gone"]:
				assert(pair[0].get(key) == pair[1].get(key), "Missile %s trial=%d tick=%d" % [key, trial, tick])
			if pair[0].gone:
				break
		assert(pair[0].gone and pair[1].gone)
		assert(worlds[0].stats == worlds[1].stats)
		var a: Array = (worlds[0].combat as MissileCombat).explosions
		var b: Array = (worlds[1].combat as MissileCombat).explosions
		assert(a.size() == 1 and b.size() == 1)
		assert((a[0][0] as Vector3).distance_to(b[0][0]) < 0.005)
		if kind == "atgm":
			max_direction_error = maxf(max_direction_error, (a[0][1].dir as Vector3).distance_to(b[0][1].dir))
			assert((a[0][1].dir as Vector3).distance_to(b[0][1].dir) < 0.0001)
			a[0][1].erase("dir")
			b[0][1].erase("dir")
		assert(a[0][1] == b[0][1])
		for p in pair:
			p.free()
		for w in worlds:
			w.free()
		target.free()
		operator.free()
	print("GUIDED_ERROR position=", max_position_error, " velocity=", max_velocity_error, " direction=", max_direction_error)
	print("GUIDED_FLIGHT passed cases=96")
	get_tree().quit()
