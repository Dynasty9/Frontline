extends Node
## Drives real menu controls and the normal private-host launch for visual QA.
## This is a capture fixture, never a loading benchmark.

var game: Node
var started := Time.get_ticks_msec()

func mark(stage: String) -> void:
	print("CAPTURE %s wall_ms=%d drawn=%d" % [stage, Time.get_ticks_msec() - started, Engine.get_frames_drawn()])

func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	# The private host uses /root/Main/World for RPCs. Preserve that path.
	get_tree().root.add_child.call_deferred(game)
	await get_tree().create_timer(3).timeout
	game.menu._open_op(0)
	await get_tree().create_timer(2).timeout
	var picker: OptionButton
	for control in game.menu.op_panel.find_children("*", "OptionButton", true, false):
		if control.get_script() == load("res://scripts/ui/battlefield_picker.gd"):
			picker = control
	assert(picker != null)
	for choice in [1, 2]:
		picker.show_popup()
		await get_tree().create_timer(1.5).timeout
		picker.get_popup().hide()
		picker.select(choice)
		picker.item_selected.emit(choice)
		mark("selected_" + String(picker.get_item_metadata(choice)))
		await get_tree().create_timer(2).timeout
	assert(game.menu._battlefield == "highland-junction")
	mark("deploy_highland-junction")
	game.menu._deploy()
	# Leave the real game running. End the external recorder only after inspecting
	# the revealed battlefield; this driver does not certify loading or performance.
