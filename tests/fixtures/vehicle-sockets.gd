extends Node
## -- --write-sockets regenerates the authority's geometry-only socket table.
## Otherwise validate every definition against the actual procedural model.
func _ready() -> void:
	TestRun.watch()
	var layouts := {}
	var keys: Array = Defs.VEHICLES.keys()
	for key in ["ac130", "blackfish_armed", "xian", "greyhawk", "a10", "wipeout"]:
		if key not in keys:
			keys.append(key)
	for kind: String in keys:
		var k := VehicleModels.build(kind, 0, 0)
		add_child(k.root)
		var sockets := {"mg": k.mg_tip, "gun": k.gun_tip}
		sockets.merge(k.weapon_tips)
		var entries := {}
		for weapon: String in sockets:
			var tip: Node3D = sockets[weapon]
			if tip == null:
				continue
			var pt := tip.global_position
			var item := {"point": [pt.x, pt.y, pt.z]}
			if k.turret and k.turret.is_ancestor_of(tip):
				var pivot := k.turret.global_position
				item["pivot"] = [pivot.x, pivot.y, pivot.z]
			entries[weapon] = item
		layouts[kind] = entries
		# Nonzero hull and turret headings expose parent-space and scale errors.
		var holder := Node3D.new()
		add_child(holder)
		k.root.reparent(holder, false)
		holder.transform = Transform3D(Basis.from_euler(Vector3(0.17, 1.2, -0.22)), Vector3(20, 12, -8))
		if k.turret:
			k.turret.rotation.y = 1.1
		if "--write-sockets" not in OS.get_cmdline_user_args():
			for weapon: String in sockets:
				var tip: Node3D = sockets[weapon]
				if tip:
					var point := holder.to_global(VehicleSockets.point(kind, weapon, 1.1))
					assert(point.distance_to(tip.global_position) < 0.001, kind + " " + weapon + " rotated socket drifted")
		holder.free()
	if "--write-sockets" in OS.get_cmdline_user_args():
		var file := FileAccess.open("res://scripts/game/vehicle_socket_data.gd", FileAccess.WRITE)
		file.store_string("class_name VehicleSocketData\nextends RefCounted\n## Generated from procedural model markers; regenerate with vehicle-sockets.tscn.\nconst LAYOUTS := " + JSON.stringify(layouts, "\t", true, true) + "\n")
	else:
		for kind: String in layouts:
			for weapon: String in layouts[kind]:
				var p: Array = layouts[kind][weapon].point
				assert(VehicleSockets.point(kind, weapon).distance_to(Vector3(p[0], p[1], p[2])) < 0.0001, kind + " " + weapon + " socket drifted")
	print("VEHICLE_SOCKETS passed models=%d" % layouts.size())
	get_tree().quit()
