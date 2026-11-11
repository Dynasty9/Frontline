extends Node
## Export actual model aliases instead of guessing them from source text.
func _ready() -> void:
	var output := "/tmp/vehicle-roster.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicle-index-out="):
			output = arg.trim_prefix("--vehicle-index-out=")
	var rows := {}
	for key: String in Defs.VEHICLES:
		var spec: Dictionary = Defs.VEHICLES[key]
		rows[key] = {"model": String(spec.get("model", key)), "name": String(spec.get("name", key)), "team": spec.get("team", -1)}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "\t", true))
	print("VEHICLE_ROSTER_INDEX ", rows.size())
	get_tree().quit()
