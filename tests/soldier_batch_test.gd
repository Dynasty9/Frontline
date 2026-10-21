extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var world := World.new()
	world.has_view = false
	var batch := SoldierViewBatch.new()
	batch.world = world
	add_child(batch)
	batch._make_pose("rifleman:0:0:0", "rifleman", 0, 0, 0)
	var mesh: ArrayMesh = batch.poses["rifleman:0:0:0"]
	check(mesh.get_surface_count() == 1, "A distant pose must require only one material draw per pass")
	var importer := ImporterMesh.from_mesh(mesh)
	var levels := 0
	for surface in importer.get_surface_count():
		levels += importer.get_surface_lod_count(surface)
	check(levels > 0, "Shared poses must contain generated mesh detail levels")
	for i in 40:
		var s := Soldier.new()
		s.world = world
		s.eid = i + 1
		s.utype = "rifleman"
		s.team = 0
		s.view_lod = true
		s.position = Vector3(i % 20, 0, 0 if i < 20 else 640)
		world.add_child(s)
		world.soldiers.append(s)
	batch._process(0.016)
	check(batch.groups.size() == 2, "Widely separated men must use separate spatial batches")
	for group: Dictionary in batch.groups.values():
		var mm: MultiMesh = group.mm
		check(group.count == 20 and mm.visible_instance_count == 20, "Every soldier must survive a batch capacity increase")
		if DisplayServer.get_name() != "headless":
			for i in 20:
				check(mm.get_instance_transform(i).origin == Vector3(i, 0, 0), "Resizing and cell offsets must preserve every transform")
	for s: Soldier in world.soldiers:
		s.gone = true
	world.time = 6.0
	batch._process(0.016)
	check(batch.groups.is_empty(), "Unused spatial batches must release their render resources")
	batch.free()
	world.free()
	print("SOLDIER_BATCH_TEST failures=%d lod_levels=%d" % [failures, levels])
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
