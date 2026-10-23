extends Node

class Observer extends Soldier:
	var candidates := []
	var eyes := 0
	var excludes := 0
	func scan_candidates() -> Array: return candidates
	func scan_eye() -> Vector3:
		eyes += 1
		return Vector3(2, 1, 3)
	func get_exclude() -> Array:
		excludes += 1
		return []

class Sight extends Combat:
	var checks := 0
	func can_see_from(eye: Vector3, e: Entity, ex: Array) -> bool:
		assert(eye == Vector3(2, 1, 3) and ex.is_empty())
		checks += 1
		return e.eid % 2 == 0

func reference(w: World, a: Vector3, b: Vector3) -> bool:
	for p: Projectile in w.projectiles:
		if p.ptype == "smoke" and p.smoke_r > 0.8 and Defs.seg_sphere(a, b, p.position + Vector3(0, 1.4, 0), p.smoke_r):
			return true
	for sm in w.fires.smokes:
		if Defs.seg_sphere(a, b, sm[0], sm[1]):
			return true
	return false

func _ready() -> void:
	var w := World.new()
	w.has_view = false
	w.combat = Combat.new(w)
	w.fires = Fires.new(w)
	for i in 200:
		var p: Projectile = w.spawn("projectile", {"ptype": "smoke" if i % 20 == 0 else "frag", "pos": Vector3(i - 100, 0, i % 7)})
		p.smoke_r = 3.0 if i % 40 == 0 else 0.5
	assert(w.smoke_projectiles.size() == 10)
	w.rng.seed = 736
	for i in 1000:
		var a := Vector3(w.rng.randf_range(-110, 110), 1.4, w.rng.randf_range(-10, 20))
		var b := Vector3(w.rng.randf_range(-110, 110), 1.4, w.rng.randf_range(-10, 20))
		assert(w.combat.smoke_blocks(a, b) == reference(w, a, b))
	var changed: Projectile = w.projectiles[1]
	changed.apply_props({"ptype": "smoke"})
	changed.ptype = "smoke"
	assert(w.smoke_projectiles.size() == 11, "Property refreshes must not duplicate smoke")
	changed.smoke_r = 4.0
	changed.position = Vector3(0, 0, 100)
	var a := Vector3(-10, 1.4, 100)
	var b := Vector3(10, 1.4, 100)
	assert(w.combat.smoke_blocks(a, b), "Live radius and position changes must be visible immediately")
	changed.ptype = "frag"
	assert(w.smoke_projectiles.size() == 10 and not w.combat.smoke_blocks(a, b))
	changed.ptype = "smoke"
	w.despawn(changed)
	assert(w.smoke_projectiles.size() == 10 and not w.combat.smoke_blocks(a, b))
	w.fires.smokes.append([Vector3(0, 1.4, 100), 4.0])
	assert(w.combat.smoke_blocks(a, b), "Burning terrain must still screen sight")
	await get_tree().process_frame
	changed.free()
	w._graveyard.clear()
	var observer := Observer.new()
	observer.world = w
	w.add_child(observer)
	var sight := Sight.new(w)
	w.combat = sight
	for i in range(1, 11):
		var target := Soldier.new()
		target.eid = i
		w.add_child(target)
		observer.candidates.append([float(i * i), target])
	observer._scan_work()
	assert(sight.checks == 7 and observer.eyes == 1 and observer.excludes == 1)
	assert(observer.vis_targets.map(func(e): return e.eid) == [2, 4, 6])
	assert(observer.target.eid == 2, "Nearest visible candidate keeps the same priority")
	observer.target = observer.candidates[5][1]
	observer._scan_work()
	assert(observer.target.eid == 6, "The current target keeps its existing preference")
	w.free()
	print("VISIBILITY_WORKING_SET passed")
	get_tree().quit()
