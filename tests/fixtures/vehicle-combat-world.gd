extends "res://tests/fixtures/world-combat.gd"

func _ready() -> void:
	var mode := 10
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = int(arg.trim_prefix("--case="))
	run(mode)
