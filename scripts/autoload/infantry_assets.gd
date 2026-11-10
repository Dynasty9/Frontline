extends Node

func _init() -> void:
	if "tests/mocap/pack_infantry.gd" in OS.get_cmdline_args(): return
	if not ProjectSettings.load_resource_pack("res://assets/infantry/infantry.zip", false):
		push_error("Could not mount Frontline infantry assets")
