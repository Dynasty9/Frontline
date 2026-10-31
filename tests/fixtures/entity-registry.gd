extends Node3D

class Unit extends Entity:
	var kind := ""
	func ekind() -> String:
		return kind
	func on_spawned() -> void:
		assert(world.entities[eid] == self)
		if world._entity_core:
			assert(world._entity_core.ids() == PackedInt64Array(world.entities.keys()))
	func on_despawn() -> void:
		assert(not world.entities.has(eid))
		if world._entity_core:
			assert(world._entity_core.ids() == PackedInt64Array(world.entities.keys()))

class Scene extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _make(kind: String) -> Entity:
		var e := Unit.new()
		e.kind = kind
		return e


func _ready() -> void:
	assert(ClassDB.class_exists("EntityRegistryCore"))
	var core: RefCounted = ClassDB.instantiate("EntityRegistryCore")
	assert(core.initialize(100, PackedInt64Array([15, 2, 12]), PackedStringArray(["soldier", "vehicle", "structure"])))
	assert(core.ids() == PackedInt64Array([15, 2, 12]))
	var before: PackedByteArray = core.checkpoint()
	for ids in [PackedInt64Array([0]), PackedInt64Array([-1]), PackedInt64Array([4294967296]), PackedInt64Array([1, 1])]:
		var kinds := PackedStringArray()
		for id in ids:
			kinds.append("soldier")
		assert(not core.initialize(100, ids, kinds))
		assert(core.checkpoint() == before)
	assert(not core.initialize(-1, PackedInt64Array(), PackedStringArray()))
	assert(not core.initialize(100, PackedInt64Array([1]), PackedStringArray(["unknown"])))
	assert(not core.initialize(100, PackedInt64Array([1]), PackedStringArray()))
	assert(core.spawn("unknown") == 0 and core.checkpoint() == before)
	for i in before.size():
		assert(not core.restore(before.slice(0, i)))
		assert(core.checkpoint() == before)
	assert(core.restore(before) and core.checkpoint() == before)
	assert(core.remove(2) and not core.remove(2) and not core.remove(-1))
	assert(core.spawn("drone") == 100 and core.next_id() == 101)
	assert(core.ids() == PackedInt64Array([15, 12, 100]))
	assert(core.initialize(4294967295, PackedInt64Array([2147483648]), PackedStringArray(["projectile"])))
	assert(core.spawn("projectile") == 4294967295)
	assert(core.spawn("projectile") == 0 and core.next_id() == 4294967296)
	assert(core.ids() == PackedInt64Array([2147483648, 4294967295]))
	var worlds: Array[Scene] = []
	for native in [false, true]:
		var w := Scene.new()
		w.srv = true
		w.has_view = false
		w.settings = {"gdscript_entity_registry": not native}
		add_child(w)
		worlds.append(w)
	var kinds := ["soldier", "structure", "vehicle", "projectile", "drone"]
	for i in range(1, 4097):
		for w in worlds:
			var e := w.spawn(kinds[i % kinds.size()], {})
			assert(e.eid == i and e.world == w and e.srv)
			if i > 2 and i % 3 != 0:
				var old: Entity = w.entities[i - 2]
				w.despawn(old)
				w.despawn(old)
		var native := worlds[1]
		assert(native._entity_core.ids() == PackedInt64Array(worlds[0].entities.keys()))
		assert(native.next_eid == worlds[0].next_eid and native._entity_core.next_id() == native.next_eid)
		if i % 127 == 0:
			var checkpoint: PackedByteArray = native._entity_core.checkpoint()
			assert(native._entity_core.restore(checkpoint) and native._entity_core.checkpoint() == checkpoint)
	assert(worlds[0]._entity_core == null and worlds[1]._entity_core != null)
	# Replication builds presentation objects with server IDs; it allocates none.
	var client := Scene.new()
	client.has_view = false
	add_child(client)
	client._build_ent(123, "soldier", {})
	assert(client._entity_core == null and client.next_eid == 1)
	assert(client.entities[123].eid == 123 and not client.entities[123].srv)
	client.despawn(client.entities[123])
	await get_tree().process_frame
	for w in worlds:
		for retired: Array in w._graveyard:
			retired[0].free()
		w._graveyard.clear()
		w.free()
	for retired: Array in client._graveyard:
		retired[0].free()
	client._graveyard.clear()
	client.free()
	print("ENTITY_REGISTRY passed spawns=4096")
	get_tree().quit()
