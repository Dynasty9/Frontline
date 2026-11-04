extends Node

var theme_changes := 0

func _ready() -> void:
	var world := World.new()
	world.local_team = 0
	world.team_info = [{"sup": {}}, {}]
	var hud := Hud.new()
	hud.world = world
	hud.support_box = VBoxContainer.new()
	add_child(hud.support_box)
	hud._update_support()
	for b: Button in hud._support_btns.values():
		for key in ["name", "state"]:
			(b.get_meta(key) as Label).theme_changed.connect(func(): theme_changes += 1)
	await get_tree().process_frame
	theme_changes = 0
	for i in 60:
		hud._update_support()
	await get_tree().process_frame
	assert(theme_changes == 0, "Unchanged support status must not invalidate label themes")
	var kind: String = Defs.supports_for(0)[0]
	var button: Button = hud._support_btns[kind]
	var state: Label = button.get_meta("state")
	world.time = Defs.support_from(kind) + 1.0
	hud._update_support()
	assert(not button.disabled and button.visible and "RDY" in state.text)
	assert(state.get_theme_color("font_color") == UiKit.GOOD)
	world.team_info[0].sup[kind] = world.time + 42.0
	hud._update_support()
	assert(button.disabled and state.text == "42S")
	assert(state.get_theme_color("font_color") == UiKit.FAINT)
	assert((button.get_meta("name") as Label).get_theme_color("font_color") == UiKit.DIM)
	hud._fires_open = true
	hud._update_support()
	assert(button.visible, "Opening the list must reveal cooling support")
	world._rpc_team([{"sq": {"7": ["move", Vector3(10, 0, 20), Vector3.ZERO, 1]}}, {}])
	hud._track_orders()
	var order: Array = hud.orders[7]
	for i in 60:
		hud._track_orders()
	assert(is_same(hud.orders[7], order), "Frames between summaries must retain the current orders")
	world._rpc_team([{"sq": {"7": ["defend", Vector3(30, 0, 40), Vector3.ZERO, 2]}}, {}])
	hud._track_orders()
	assert(hud.orders[7][0] == "defend" and hud.orders[7][1] == Vector3(30, 0, 40) and hud.orders[7][5] >= 0)
	world.team_info = [{}, {}]  # Replay seeking replaces summaries directly.
	hud._track_orders()
	assert(hud.orders.is_empty(), "Removed squads must disappear on the next summary")
	hud.free()
	world.free()
	print("SUPPORT_PANEL passed")
	get_tree().quit()
