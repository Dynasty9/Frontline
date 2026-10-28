extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var manual := FieldManual.new()
	manual.embedded = true
	add_child(manual)
	check(manual._view.find_world_3d() == get_viewport().find_world_3d() and manual._view.audio_listener_enable_3d, "Embedded support must hear the game's spatial sound pool")
	for entry in [["hunter", "veh_light"], ["slammer", "veh_armour"], ["rhib", "boats"], ["hatchback", "civilian"], ["wipeout", "aircraft"], ["ac130", "support"]]:
		manual.open("entry", entry[0])
		check(manual._cat == entry[1], "Wrong manual category for " + entry[0])
		check(manual._sel == entry[0], "Wrong selected entry for " + entry[0])
		check(is_instance_valid(manual._model) and manual._model.get_child_count() > 0, "Missing model for " + entry[0])
		check(manual._title == null and manual._list == null, "Embedded models must leave the UI to the website")
		await get_tree().process_frame
	manual.open("entry", "not-a-vehicle")
	check(manual._cat == "veh_armour" and is_instance_valid(manual._model), "Unknown links need a usable fallback")
	manual.open("vehicles", "hunter")
	check(manual._cat == "veh_light" and manual._sel == "hunter", "Existing vehicle links must still work")
	var original := manual._dist
	manual.control_model("zoom-in")
	check(manual._dist < original, "CSS zoom controls must move the manual camera")
	manual.control_model("left")
	check(manual._yaw != manual._home_view.x, "CSS rotate controls must move the manual camera")
	manual.control_model("reset")
	check(is_equal_approx(manual._dist, original) and manual._yaw == manual._home_view.x, "Reset must restore the initial camera")
	manual._process(10.0)
	check(manual._yaw == manual._home_view.x, "Embedded previews must not spin without input")
	manual.control_model("reduce-motion")
	manual._process(3.0)
	check(manual._studio_clock == 0.0, "Reduced motion must stop the survey interference")
	manual.control_model("allow-motion")
	var full_manual := FieldManual.new()
	add_child(full_manual)
	full_manual.open("vehicles", "hunter")
	check(full_manual._cat == "veh_light" and full_manual._title.text == "Hunter", "The game's full manual must keep its UI")
	print("FIELD_MANUAL_ENTRY_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
