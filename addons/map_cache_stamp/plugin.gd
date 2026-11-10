@tool
extends EditorPlugin

class Stamp extends EditorExportPlugin:
	func _get_name() -> String:
		return "MapCacheStamp"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		var cache: Script = load("res://scripts/game/battlefield_cache.gd")
		add_file("res://bin/map-cache-code.sha256", cache.source_identity().to_utf8_buffer(), false)

var stamp := Stamp.new()

func _enter_tree() -> void:
	add_export_plugin(stamp)

func _exit_tree() -> void:
	remove_export_plugin(stamp)
