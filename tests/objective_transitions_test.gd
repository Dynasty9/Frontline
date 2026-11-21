extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func objective(text: String, state: int) -> Array:
	return ["", text, state, "do", null, 0, "", false]

func _ready() -> void:
	TestRun.watch()
	var panel := HudObjectives.new()
	# Training can progress faster than a banner's display time. The newest
	# instruction must be shown now, even when several earlier notices exist.
	panel._spot_changes({"key": "bootcamp", "objs": [objective("Look around", MissionDirector.ACTIVE)]})
	panel._spot_changes({"key": "bootcamp", "objs": [objective("Look around", MissionDirector.DONE), objective("Select a squad", MissionDirector.ACTIVE)]})
	check(panel._banners.size() == 1, "Training must not queue stale instructions")
	check(panel._banners[0][1] == "Select a squad", "Training must show the current step")
	panel._spot_changes({"key": "bootcamp", "objs": [objective("Select a squad", MissionDirector.DONE)]})
	check(panel._banners[0][0] == "OBJECTIVE COMPLETE", "Completion still needs visible acknowledgement")
	panel.free()

	var mission := HudObjectives.new()
	mission._spot_changes({"key": "bridgehead", "objs": [objective("Secure the bridge", MissionDirector.ACTIVE), objective("Protect the convoy", MissionDirector.ACTIVE)]})
	check(mission._banners.size() == 2, "Ordinary missions retain simultaneous objective notices")
	mission.free()
	print("OBJECTIVE TRANSITIONS failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
