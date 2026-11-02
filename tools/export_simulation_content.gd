extends Node
## Bake the same definitions used by the client into the standalone server.

func _ready() -> void:
	call_deferred("_export")

func _plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[String(key)] = _plain(value[key])
		return result
	if value is Array:
		var result := []
		for item: Variant in value:
			result.append(_plain(item))
		return result
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Vector3 or value is Vector3i:
		return [value.x, value.y, value.z]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	assert(value == null or value is bool or value is int or value is float or value is String, "Unsupported simulation content value")
	return value

func _export() -> void:
	var defs: Node = get_tree().root.get_node("Defs")
	var motion := {}
	for kind: String in defs.VEHICLES:
		motion[kind] = VehicleMotion.profile(kind, defs.VEHICLES[kind])
	var content := {
		"version": 1,
		"weapons": defs.WEAPONS, "units": defs.UNITS, "squads": defs.SQUADS,
		"vehicles": defs.VEHICLES, "buildings": defs.BUILDINGS,
		"support": defs.SUPPORT, "upgrades": defs.UPGRADES,
		"sockets": VehicleSockets.DATA.LAYOUTS,
		"motion": motion, "boat_hulls": Vehicle.BOAT_HULLS, "mounted_guns": WeaponModels.GUNS,
		"names": Defs.NAMES, "team_names": Defs.TEAM_NAMES, "fob_names": Defs.FOB_NAMES,
		"base_cap": Defs.BASE_CAP, "cap_per_fob": Defs.CAP_PER_FOB,
		"fob_radius": Defs.FOB_RADIUS, "build_radius": Defs.BUILD_RADIUS,
		"fob_expand_radius": Defs.FOB_EXPAND_RADIUS, "fob_min_spacing": Defs.FOB_MIN_SPACING,
		"supply_per_truck": Defs.SUPPLY_PER_TRUCK, "start_supply": Defs.START_SUPPLY,
		"town_yield": Defs.TOWN_YIELD, "town_stock": Defs.TOWN_STOCK,
		"town_load": Defs.TOWN_LOAD, "town_radius": Defs.TOWN_RADIUS, "town_pace": Defs.TOWN_PACE,
	}
	var output := "res://native/content.json"
	var check := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--check":
			check = true
	var data: Dictionary = _plain(content)
	for table: String in ["weapons", "units", "squads", "vehicles", "buildings", "support", "upgrades"]:
		for key: String in data[table]:
			data[table][key]["key"] = key
	for key: String in defs.SUPPORT:
		var d: Dictionary = defs.SUPPORT[key]
		var muzzles := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
		if d.get("fly", key) == "orbit":
			var model := String(d.get("model", "ac130"))
			var i := 0
			for gun: String in Projectile.GUNSETS.get(d.get("guns", "ac130"), Projectile.AC_GUNS):
				var socket := VehicleSockets.point(model, gun)
				if socket == Vector3.INF:
					socket = VehicleSockets.point(model, "mg" if gun == "ac25" else "gun")
				muzzles[i] = socket if socket != Vector3.INF else Vector3.ZERO
				i += 1
		data.support[key]["muzzles"] = _plain(muzzles)
	var text := JSON.stringify(data, "\t", true, true) + "\n"
	if check:
		if FileAccess.get_file_as_string(output) != text:
			printerr("Simulation content is stale; run tools/export_simulation_content.gd")
			get_tree().quit(1)
			return
	else:
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write simulation content: ", FileAccess.get_open_error())
			get_tree().quit(1)
			return
		file.store_string(text)
	print("SIMULATION_CONTENT passed vehicles=%d units=%d weapons=%d" % [defs.VEHICLES.size(), defs.UNITS.size(), defs.WEAPONS.size()])
	get_tree().quit()
