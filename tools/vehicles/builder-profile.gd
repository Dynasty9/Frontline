extends Node
## Where the roster's geometry goes: builds every model (team 0, seed 3, as
## construction-metrics does) with VehicleModels.profiling on and writes one
## line per builder, its triangle-list vertices across the roster, heaviest
## first. Shared builders are named file.function; parts a family adds itself
## are charged to its own function.
func _ready() -> void:
	TestRun.watch()
	var output := "/tmp/vehicle-builder-profile.tsv"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--builder-profile-out="):
			output = arg.trim_prefix("--builder-profile-out=")
	var keys: Array[String] = []
	for list in [Defs.VEHICLES.keys(), VehicleModels.family_keys(), VmCore.KEYS, VmGunship.KEYS, VmAttack.KEYS, VmFighter.KEYS]:
		for key: String in list:
			if key not in keys:
				keys.append(key)
	keys.sort()
	VehicleModels.profiling = true
	VehicleModels.profile.clear()
	for key in keys:
		var model := VehicleModels.build(key, 0, 3)
		model.root.free()
	VehicleModels.profiling = false
	var rows: Array = []
	var total := 0
	for owner: String in VehicleModels.profile:
		rows.append([int(VehicleModels.profile[owner]), owner])
		total += int(VehicleModels.profile[owner])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var file := FileAccess.open(output, FileAccess.WRITE)
	for row: Array in rows:
		file.store_line("%d\t%s" % [row[0], row[1]])
	print("VEHICLE_BUILDER_PROFILE %d builders, %d vertices" % [rows.size(), total])
	get_tree().quit()
