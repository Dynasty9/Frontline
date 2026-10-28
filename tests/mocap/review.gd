extends "res://tests/mocap/viewer.gd"
## Review source clips separately from the poses selected by the gameplay renderer.

var cases: Array[Dictionary] = []
var case_picker: OptionButton
var review_state: Label
var notes: TextEdit
var reviews := ConfigFile.new()
var review_path := "user://animation-reviews.cfg"
var proxy: SoldierModel
var current_case := -1
var case_time := 0.0
var barrier: Node3D
var revision := ""
var save_ok := true
var fingerprints := {}

func _ready() -> void:
	super._ready()
	if not ready_to_run: return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reviews="): review_path = arg.trim_prefix("--reviews=")
	var result := reviews.load(review_path)
	if result not in [OK, ERR_FILE_NOT_FOUND]:
		save_ok = false
		push_error("Cannot read animation reviews: " + error_string(result))
	for path in ["res://scripts/game/soldier_model.gd", "res://scripts/game/skinned_rifleman.gd", "res://scripts/game/rifle_animation_controller.gd", "res://scripts/game/mixamo_clips.gd", soldier.model_asset]:
		revision += FileAccess.get_sha256(path)
	proxy = SoldierModel.new()
	add_child(proxy)
	proxy.build("rifleman", 0, 4)
	soldier.bind_procedural(proxy)
	proxy.root.hide()
	proxy.skinned = soldier
	proxy.rifle_driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	proxy.rifle_driver.setup(soldier)
	_surface(Vector3(0, 0.5, -0.7), Vector3(2.5, 1.0, 0.15), Color("7c8790"))
	barrier = get_child(get_child_count() - 1)
	barrier.hide()
	barrier.collision_layer = 0
	for action in Soldier.Act:
		cases.append({"name": "Action / " + action, "act": Soldier.Act[action]})
	for posture in Soldier.Post:
		for action in ["IDLE", "WALK", "SHOOT", "RELOAD"]:
			cases.append({"name": posture + " / " + action, "post": Soldier.Post[posture], "act": Soldier.Act[action]})
	for life in Soldier.Life:
		if life != "ALIVE": cases.append({"name": "Life / " + life, "life": Soldier.Life[life]})
	for height in [0.7, 1.0, 1.2, 1.5]:
		cases.append({"name": "Fire over %.1f m wall" % height, "wall": height, "act": Soldier.Act.SHOOT, "post": Soldier.Post.CROUCH if height < Cover.KNEEL_MAX else Soldier.Post.STAND})
	cases.append({"name": "Blind fire over cover", "wall": 1.2, "blind": true, "act": Soldier.Act.SHOOT, "post": Soldier.Post.CROUCH})
	cases.append({"name": "Mounted gun / pose only", "crew": true, "act": Soldier.Act.SHOOT})
	cases.append({"name": "Stance transitions / stand - crouch - prone", "transition": true})
	for direction in [-PI / 2, PI / 2, PI]:
		cases.append({"name": "Movement / heading %.0f degrees" % rad_to_deg(direction), "yaw": direction, "act": Soldier.Act.WALK})
	for response in [0, 1, 2]:
		cases.append({"name": ["Hit reaction", "Fatal hit / ragdoll", "Heavy impact / ragdoll"][response], "impact": response})
	_build_review_ui()
	_refresh_review()
	if "--review-test" in OS.get_cmdline_user_args(): call_deferred("_review_test")
	if "--review-preview" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()

func _build_review_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -370
	panel.offset_right = -20
	panel.offset_top = -470
	panel.offset_bottom = -20
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_label(column, "ANIMATION APPROVAL", 21)
	case_picker = OptionButton.new()
	case_picker.clip_text = true
	case_picker.add_item("Source clip (select on left)")
	for item in cases: case_picker.add_item(item.name)
	case_picker.item_selected.connect(func(index: int): _select_case(index - 1))
	column.add_child(case_picker)
	review_state = _label(column, "", 14)
	review_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes = TextEdit.new()
	notes.placeholder_text = "Leave a comment about this animation..."
	notes.custom_minimum_size.y = 75
	column.add_child(notes)
	var save_comment := Button.new()
	save_comment.text = "Save comment (keep current decision)"
	save_comment.pressed.connect(func(): _decide(_decision(_identity())))
	column.add_child(save_comment)
	var row := HBoxContainer.new()
	column.add_child(row)
	for decision in ["Approved", "Rejected", "Unreviewed"]:
		var button := Button.new()
		button.text = decision
		button.pressed.connect(_decide.bind(decision))
		row.add_child(button)
	var next := Button.new()
	next.text = "Next unreviewed (clips + gameplay)"
	next.pressed.connect(_next_unreviewed)
	column.add_child(next)
	_label(column, "Left list: every imported clip. Dropdown: gameplay poses.\nClick character to test projectiles; Reset replays.\nMounted pose has no vehicle or mounted-weapon rig.\nApproval records feedback; it does not disable game content.", 12)
	var folder := Button.new()
	folder.text = "Open saved review folder"
	folder.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path(review_path).get_base_dir()))
	column.add_child(folder)

func _select_clip(index: int) -> void:
	current_case = -1
	super._select_clip(index)
	if case_picker != null:
		case_picker.select(0)
		barrier.hide()
		barrier.collision_layer = 0
		_refresh_review()

func _select_case(index: int) -> void:
	current_case = index
	case_picker.select(index + 1)
	_reset_actor()
	playing = true
	_refresh_review()

func _reset_actor() -> void:
	super._reset_actor()
	case_time = 0.0
	if proxy != null:
		proxy.act_time = 0.0
		proxy.last_act = -1

func _pose_preview(step: float) -> void:
	if current_case < 0 or proxy == null:
		super._pose_preview(step)
		return
	case_time += step
	var item := cases[current_case]
	var posture: int = item.get("post", Soldier.Post.STAND)
	var action: int = item.get("act", Soldier.Act.IDLE)
	if item.get("transition", false): posture = [Soldier.Post.STAND, Soldier.Post.CROUCH, Soldier.Post.PRONE, Soldier.Post.CROUCH][int(case_time / 3.0) % 4]
	var speed := 3.5 if action == Soldier.Act.RUN else (1.2 if action in [Soldier.Act.WALK, Soldier.Act.CRAWL, Soldier.Act.LIMP, Soldier.Act.DRAG, Soldier.Act.CARRY] else 0.0)
	proxy.move_yaw = item.get("yaw", 0.0)
	proxy.cover_h = item.get("wall", 0.0)
	proxy.over_wall = proxy.cover_h > 0.0
	proxy.blind = item.get("blind", false)
	proxy.crew = item.get("crew", false)
	proxy.crew_l = Vector3(-0.2, 1.1, -0.5)
	proxy.crew_r = Vector3(0.2, 1.1, -0.5)
	barrier.visible = proxy.over_wall
	barrier.collision_layer = 1 if proxy.over_wall else 0
	soldier.visual.visible = item.get("life", Soldier.Life.ALIVE) != Soldier.Life.HIDDEN
	if proxy.over_wall:
		barrier.scale.y = proxy.cover_h
		barrier.position.y = proxy.cover_h * 0.5
	if not soldier.dead:
		proxy.pose(step, item.get("life", Soldier.Life.ALIVE), posture, action, speed, false, true)
	if item.has("impact") and case_time >= 1.0 and case_time - step < 1.0:
		soldier.hit(Vector3.BACK, 1.2)
		if item.impact > 0: soldier.kill(Vector3.BACK * (5.0 if item.impact == 2 else 0.8) + Vector3.UP, 1 if item.impact == 2 else 0)

func _identity() -> String:
	return "gameplay/" + str(cases[current_case].name) if current_case >= 0 else "clip/" + selected

func _fingerprint(key: String) -> String:
	if fingerprints.has(key): return fingerprints[key]
	var path: String = clip_paths.get(key.trim_prefix("clip/"), "")
	fingerprints[key] = (revision + (FileAccess.get_sha256(path) if not path.is_empty() else "")).sha256_text()
	return fingerprints[key]

func _decision(key: String) -> String:
	if reviews.get_value(key, "revision", "") != _fingerprint(key): return "Unreviewed"
	return reviews.get_value(key, "decision", "Unreviewed")

func _refresh_review() -> void:
	if review_state == null: return
	var key := _identity()
	var done := 0
	for clip in clip_keys:
		if _decision("clip/" + clip) != "Unreviewed": done += 1
	for item in cases:
		if _decision("gameplay/" + str(item.name)) != "Unreviewed": done += 1
	review_state.text = "%s\n%s | %d / %d reviewed\n%s" % [key, _decision(key), done, clip_keys.size() + cases.size(), "Gameplay renderer; review in context." if current_case >= 0 else "Source playback only; gameplay routing may differ."]
	if not save_ok: review_state.text += "\nSAVE ERROR: existing file could not be read."
	notes.text = reviews.get_value(key, "notes", "")
	for i in clip_keys.size(): picker.set_item_text(i, "[%s] %s" % [_decision("clip/" + clip_keys[i]), clip_keys[i].replace("_", " ")])
	timeline.editable = current_case < 0
	source_toggle.disabled = current_case >= 0 or _is_native()

func _decide(decision: String) -> void:
	if not save_ok: return
	var key := _identity()
	var old := reviews.encode_to_text()
	reviews.set_value(key, "decision", decision)
	reviews.set_value(key, "notes", notes.text)
	reviews.set_value(key, "revision", _fingerprint(key))
	reviews.set_value(key, "updated", Time.get_datetime_string_from_system(true))
	# Write a complete replacement before touching the user's previous decisions.
	var result := reviews.save(review_path + ".tmp")
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(review_path + ".tmp"), ProjectSettings.globalize_path(review_path))
	if result != OK:
		reviews.clear()
		reviews.parse(old)
		review_state.text = "Could not save review: " + error_string(result)
		return
	_refresh_review()

func _next_unreviewed() -> void:
	var start := clip_keys.size() + current_case if current_case >= 0 else clip_keys.find(selected)
	var count := clip_keys.size() + cases.size()
	for offset in range(1, count + 1):
		var index := (start + offset) % count
		var key := "clip/" + clip_keys[index] if index < clip_keys.size() else "gameplay/" + str(cases[index - clip_keys.size()].name)
		if _decision(key) != "Unreviewed": continue
		if index < clip_keys.size(): _select_clip(index)
		else: _select_case(index - clip_keys.size())
		return
	review_state.text = "Everything reviewed. Select any item to revise a decision."

func _review_test() -> void:
	# Use a disposable review file; never write test decisions into the user's queue.
	if not review_path.ends_with("review-test.cfg"):
		push_error("Review test requires --reviews=user://review-test.cfg")
		get_tree().quit(1)
		return
	for i in clip_keys.size():
		_select_clip(i)
		_pose_preview(0.05)
	for i in cases.size():
		_select_case(i)
		for frame in 130: _pose_preview(1.0 / 60.0)
	_select_clip(0)
	notes.text = "Persistence check"
	_decide("Rejected")
	var saved := ConfigFile.new()
	if saved.load(review_path) != OK or saved.get_value(_identity(), "decision", "") != "Rejected" or saved.get_value(_identity(), "notes", "") != notes.text:
		push_error("Review persistence failed")
		get_tree().quit(1)
		return
	_next_unreviewed()
	if _identity() == "clip/" + clip_keys[0]:
		push_error("Review queue did not advance")
		get_tree().quit(1)
		return
	_decide("Unreviewed")
	notes.text = "Comment without approval"
	_decide(_decision(_identity()))
	saved.load(review_path)
	if saved.get_value(_identity(), "notes", "") != notes.text or _decision(_identity()) != "Unreviewed":
		push_error("Comment-only save changed decision or lost text")
		get_tree().quit(1)
		return
	_decide("Approved")
	var key := _identity()
	if _decision(key) != "Approved":
		get_tree().quit(1)
		return
	fingerprints[key] += "changed"
	if _decision(key) != "Unreviewed":
		push_error("Changed animation kept stale approval")
		get_tree().quit(1)
		return
	print("ANIMATION REVIEW PASS clips=", clip_keys.size(), " gameplay=", cases.size())
	get_tree().quit()
