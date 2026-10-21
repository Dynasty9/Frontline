extends CanvasLayer
## One observer for local archives and the delayed public broadcast.
var main: Node
var source := ""
var manifest := {}
var chunk := {}
var map := {}
var frame := 0
var sequence := -1
var position := 0.0
var speed := 1.0
var busy := false
var refreshing := false
var follow_live := true
var poll_at := 0
var label: Label
var slider: HSlider
var playing: Button
var seeking := false
var failed := false
var record_kinds := {}
var record_lengths := {}
var prop_types := {}
var downloaded := {}
var download_progress: ProgressBar
var playback_buttons: Array[BaseButton] = []
var loading_backdrop: TopoBackdrop

func _ready() -> void:
	layer = 30
	loading_backdrop = TopoBackdrop.new()
	add_child(loading_backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -92
	panel.theme = UiKit.theme()
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	label = Label.new()
	label.text = "Loading recording…"
	box.add_child(label)
	download_progress = ProgressBar.new()
	download_progress.visible = false
	box.add_child(download_progress)
	slider = HSlider.new()
	slider.min_value = 0
	slider.step = 0.1
	slider.custom_minimum_size.y = 24
	slider.tooltip_text = "Battle timeline"
	box.add_child(slider)
	slider.drag_started.connect(func(): seeking = true)
	slider.drag_ended.connect(func(changed: bool):
		seeking = false
		if changed: seek(slider.value))
	slider.value_changed.connect(func(value: float):
		if not seeking and not busy: seek(value))
	var row := HFlowContainer.new()
	box.add_child(row)
	playing = Button.new()
	playing.text = "Pause"
	playing.pressed.connect(func():
		speed = 1.0 if speed == 0 else 0.0
		if speed == 0:
			follow_live = false
		playing.text = "Play" if speed == 0 else "Pause")
	row.add_child(playing)
	var rate := OptionButton.new()
	for value in [0.25, 0.5, 1.0, 2.0, 4.0]:
		rate.add_item("%s×" % value)
	rate.select(2)
	rate.item_selected.connect(func(i: int):
		speed = [0.25, 0.5, 1.0, 2.0, 4.0][i]
		follow_live = false
		playing.text = "Pause")
	row.add_child(rate)
	var live := Button.new()
	live.text = "Latest"
	live.pressed.connect(func(): seek(maxf(0.0, float(manifest.get("duration", 0)) - 1.0)))
	live.pressed.connect(func(): follow_live = true)
	row.add_child(live)
	var follow := Button.new()
	follow.text = "Follow action"
	follow.pressed.connect(func():
		if is_instance_valid(main.world) and main.world.director:
			main.world.cam.user_moved = false
			main.world.director.active = true
			main.world.director._pick_shot())
	row.add_child(follow)
	var viewpoint := Button.new()
	viewpoint.text = "View: both sides"
	viewpoint.pressed.connect(func():
		if is_instance_valid(main.world) and main.world.director:
			main.world.director.cycle_view()
			viewpoint.text = "View: " + (["Coalition", "Rebels"][main.world.view_team] if main.world.view_team >= 0 else "both sides"))
	row.add_child(viewpoint)
	var exit_button := Button.new()
	exit_button.text = "Close replay"
	exit_button.pressed.connect(func():
		main.return_to_menu("")
		queue_free())
	row.add_child(exit_button)
	for button in row.get_children():
		if button is BaseButton and button != exit_button:
			playback_buttons.append(button)
	_refresh()

func fetch_json(path: String) -> Dictionary:
	if downloaded.has(path):
		return downloaded[path]
	if not source.begins_with("http://") and not source.begins_with("https://"):
		var file := source.path_join("index.json" if path.is_empty() else path.trim_prefix("/chunks/") + ".json")
		if not FileAccess.file_exists(file) or FileAccess.get_file_as_bytes(file).size() > 12 * 1024 * 1024:
			return {}
		var value = JSON.parse_string(FileAccess.get_file_as_string(file))
		return value if value is Dictionary else {}
	var request := HTTPRequest.new()
	request.timeout = 20
	request.body_size_limit = 12 * 1024 * 1024
	add_child(request)
	if request.request(source + path) != OK:
		request.queue_free()
		return {}
	var result: Array = await request.request_completed
	request.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		return {}
	var value = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return value if value is Dictionary else {}

func decode(body: Dictionary) -> Dictionary:
	var size := int(body.get("size", 0))
	if size < 1 or size > 64 * 1024 * 1024 or not body.get("data") is String:
		return {}
	var compressed := Marshalls.base64_to_raw(body.data)
	var raw := compressed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != size:
		return {}
	# Objects are never deserialized: recordings contain only data, not scripts.
	var value = bytes_to_var(raw)
	if not value is Dictionary or value.get("format") != 1 or value.get("protocol") != Net.NET_VERSION:
		return {}
	if not value.get("checkpoint") is Dictionary or not value.get("frames") is Array or value.frames.size() > 200:
		return {}
	record_kinds.clear()
	record_lengths.clear()
	if not _valid_state(value.checkpoint, true):
		return {}
	var previous: float = value.checkpoint.time
	for state in value.frames:
		if not state is Dictionary or not _valid_state(state, false) or state.time < previous:
			return {}
		previous = state.time
	return value

func _valid_state(state: Dictionary, full: bool) -> bool:
	if not (state.get("time") is float or state.get("time") is int) or not is_finite(float(state.time)):
		return false
	if not state.get("snapshots") is Array or not state.get("team") is Array or state.team.size() != 2 or not state.get("mission") is Dictionary:
		return false
	if not state.team[0] is Dictionary or not state.team[1] is Dictionary or not state.get("report") is Dictionary or not state.get("winner") is int:
		return false
	if full and not _valid_roads(state.get("roads")):
		return false
	var records = state.get("entities" if full else "spawn")
	if not records is Array or records.size() > 100000:
		return false
	for rec in records:
		if not rec is Array or rec.size() != 3 or not rec[0] is int or not rec[1] in World.ENT_KINDS or not rec[2] is Dictionary:
			return false
		if rec[0] <= 0 or not _valid_props(rec[1], rec[2], true):
			return false
		record_kinds[rec[0]] = rec[1]
		record_lengths[rec[0]] = {"soldier": 31, "vehicle": 24, "structure": 15 if rec[2].get("skind") == "town" else 14, "projectile": 14, "drone": 16}[rec[1]]
	for packet in state.snapshots:
		if not packet is PackedByteArray or packet.size() < 4 or packet.size() > 2048:
			return false
		var buffer := StreamPeerBuffer.new()
		buffer.data_array = packet
		if not is_finite(buffer.get_float()):
			return false
		while buffer.get_position() < packet.size():
			if buffer.get_available_bytes() < 5:
				return false
			var id := buffer.get_u32()
			var length := buffer.get_u8()
			var kind: String = record_kinds.get(id, "")
			var expected: int = record_lengths.get(id, 0)
			if expected == 0 or length != expected or length > buffer.get_available_bytes():
				if OS.has_environment("FL_DEBUG_REPLAY"):
					print("REPLAY packet kind=%s id=%d length=%d expected=%d available=%d" % [kind, id, length, expected, buffer.get_available_bytes()])
				return false
			var end := buffer.get_position() + length
			if kind != "structure":
				var pos := Entity.get_v3(buffer)
				if not pos.is_finite() or pos.length() > 100000:
					return false
			buffer.seek(end)
	if full:
		return true
	if not state.get("despawn") is Array or not state.get("props") is Dictionary or not state.get("fx") is Array:
		return false
	for id in state.despawn:
		if not id is int:
			return false
	for id in state.props:
		if not id is int or not state.props[id] is Dictionary:
			return false
		if record_kinds.has(id) and not _valid_props(record_kinds[id], state.props[id], false):
			return false
	for event in state.fx:
		if not _valid_fx(event):
			return false
	return true

func _refresh() -> void:
	refreshing = true
	var next := await fetch_json("")
	refreshing = false
	poll_at = Time.get_ticks_msec() + 500
	if next.is_empty():
		label.text = "Recording unavailable. Retrying…"
		return
	if next.get("format") != 1 or next.get("protocol") != Net.NET_VERSION or not next.get("chunks") is Array:
		failed = true
		label.text = "This recording needs a different version of Frontline."
		return
	manifest = next
	if follow_live and sequence >= 0 and manifest.get("status") == "live":
		position = maxf(position, float(manifest.duration) - 1.0)
	slider.max_value = maxf(0.1, float(manifest.get("duration", 0)))
	if sequence < 0 and not manifest.chunks.is_empty():
		if manifest.get("status") != "live" and not await _download_recording():
			return
		await seek(maxf(0, float(manifest.duration) - 1) if manifest.get("status") == "live" else 0)


func _download_recording() -> bool:
	busy = true
	slider.editable = false
	slider.hide()
	download_progress.show()
	for button in playback_buttons:
		button.disabled = true
	var total: int = manifest.chunks.size()
	var bytes := 0
	for i in total:
		label.text = "Loading replay · %d / %d parts" % [i, total]
		var path := "/chunks/%d" % i
		var body := await fetch_json(path)
		bytes += JSON.stringify(body).length()
		if bytes > BattleRecording.MAX_BYTES or body.get("sequence") != i or decode(body).is_empty():
			downloaded.clear()
			failed = true
			busy = false
			label.text = "Could not load the complete replay. Close it and try again."
			download_progress.hide()
			return false
		# Keep compressed data; only the current part is expanded during playback.
		downloaded[path] = body
		download_progress.value = 100.0 * (i + 1) / total
		await get_tree().process_frame
	busy = false
	slider.editable = true
	slider.show()
	download_progress.hide()
	for button in playback_buttons:
		button.disabled = false
	return true

func seek(target: float) -> void:
	if busy or failed or manifest.get("chunks", []).is_empty():
		return
	if sequence >= 0:
		follow_live = false
	busy = true
	label.text = "Loading battlefield…"
	target = clampf(target, 0, float(manifest.duration))
	var wanted := 0
	for entry in manifest.chunks:
		if float(entry.start) <= target:
			wanted = int(entry.sequence)
	var next := decode(await fetch_json("/chunks/%d" % wanted))
	if map.is_empty():
		var first := next if wanted == 0 else decode(await fetch_json("/chunks/0"))
		map = first.get("map", {})
	if next.is_empty() or not _valid_map(map):
		busy = false
		failed = true
		label.text = "This recording is damaged or incompatible."
		return
	chunk = next
	sequence = wanted
	# A fresh observer resets transient effects, fog, and entities when rewinding.
	await main._on_game_start({"replay": true, "players": {1: {"team": -1, "name": "Observer"}}})
	var world: World = main.world
	world._rpc_join_map(World._pack(map))
	world._rpc_spawn(chunk.checkpoint.entities)
	world._rpc_join_end()
	while is_instance_valid(world) and not world.loaded:
		await get_tree().process_frame
	if not is_instance_valid(world):
		busy = false
		return
	_apply(chunk.checkpoint, true, false)
	frame = 0
	position = target
	while frame < chunk.frames.size() and float(chunk.frames[frame].time) <= target:
		_apply(chunk.frames[frame], false, false)
		frame += 1
	world.time = position
	loading_backdrop.hide()
	for e in world.entities.values():
		if e.net_init:
			e.position = e.net_pos
			e.rotation.y = e.net_yaw
	if world.cam and not world.soldiers.is_empty():
		world.cam.focus(world.soldiers[0].position)
		world.cam.user_moved = false
		world.director.active = true
		world.director._pick_shot()
	busy = false
	_update_label()

func _apply(state: Dictionary, full: bool, effects: bool) -> void:
	var world: World = main.world
	world.time = float(state.time)
	if not full:
		world._rpc_spawn(state.spawn)
		world._rpc_props(state.props)
		world._rpc_despawn(state.despawn)
	for packet in state.snapshots:
		world._rpc_snap(packet)
	world.team_info = state.team
	world.mission_info = state.mission
	world.winner = int(state.get("winner", -1))
	world.report = state.get("report", world.report)
	if full:
		world.report = state.get("report", {})
		world._rpc_roads(state.get("roads", map.roads))
	elif effects:
		world._rpc_fx(state.fx)

func _process(dt: float) -> void:
	Engine.time_scale = 0.0 if busy or failed else speed
	if failed or busy:
		return
	if not refreshing and Time.get_ticks_msec() >= poll_at and manifest.get("status", "live") != "complete":
		_refresh()
	if sequence < 0 or not is_instance_valid(main.world):
		return
	position = minf(position + dt, float(manifest.duration))
	while frame < chunk.frames.size() and float(chunk.frames[frame].time) <= position:
		_apply(chunk.frames[frame], false, true)
		frame += 1
	main.world.time = position
	if frame == chunk.frames.size() and sequence + 1 < manifest.chunks.size():
		_next_chunk()
	if not seeking:
		slider.set_value_no_signal(position)
	_update_label()

func _next_chunk() -> void:
	busy = true
	var next := decode(await fetch_json("/chunks/%d" % (sequence + 1)))
	if next.is_empty():
		failed = true
		label.text = "Could not read the next part. Reopen the recording to retry."
	else:
		chunk = next
		sequence += 1
		frame = 0
	busy = false

func _update_label() -> void:
	var state := String(manifest.get("status", "complete"))
	label.text = "%02d:%02d / %02d:%02d · %s%s" % [int(position) / 60, int(position) % 60,
		int(manifest.duration) / 60, int(manifest.duration) % 60, state.to_upper(),
		" · Live · a few seconds behind" if state == "live" else " · Recorded by host"]


func _valid_props(kind: String, values: Dictionary, full: bool) -> bool:
	if prop_types.is_empty():
		for prototype in [Soldier.new(), Vehicle.new(), Structure.new(), Projectile.new(), Drone.new()]:
			prop_types[prototype.ekind()] = prototype.get_props()
			prototype.free()
		prop_types.structure["zc"] = Vector3.ZERO
		prop_types.structure["zr"] = 0.0
	var schema: Dictionary = prop_types.get(kind, {})
	for key in values:
		if key == "toss":
			var toss = values[key]
			if toss != null and (not toss is Array or toss.size() != 4 or not toss[0] is Vector3 or not toss[1] is float or not toss[2] is Vector3 or not toss[3] is Vector3):
				return false
			continue
		if not schema.has(key) or typeof(values[key]) != typeof(schema[key]):
			return false
		if values[key] is Vector3 and (not values[key].is_finite() or values[key].length() > 100000):
			return false
		if values[key] is float and not is_finite(values[key]):
			return false
		if values[key] is String and values[key].length() > 1000:
			return false
	if values.has("queue"):
		for item in values.queue:
			if not item is String or item.length() > 100:
				return false
	if full and not values.get("pos") is Vector3:
		return false
	if values.has("utype") and not Defs.UNITS.has(values.utype):
		return false
	if values.has("vkind") and not Defs.VEHICLES.has(values.vkind):
		return false
	if values.has("team") and not int(values.team) in [-1, 0, 1]:
		return false
	return true


func _valid_fx(event: Variant) -> bool:
	# Required fields for the existing effect protocol; trailing optional IDs
	# are numeric. Never feed arbitrary arrays into the renderer.
	const FIELDS := {
		0: [TYPE_VECTOR3, TYPE_VECTOR3, TYPE_INT, TYPE_STRING], 1: [TYPE_VECTOR3, TYPE_FLOAT],
		2: [TYPE_INT, TYPE_STRING], 3: [TYPE_VECTOR3, TYPE_VECTOR3],
		4: [TYPE_VECTOR3, TYPE_COLOR, TYPE_INT], 5: [TYPE_VECTOR3, TYPE_VECTOR3],
		6: [TYPE_VECTOR3, TYPE_VECTOR3], 7: [TYPE_STRING, TYPE_VECTOR3],
		8: [TYPE_VECTOR3, TYPE_VECTOR3], 9: [TYPE_VECTOR3], 10: [TYPE_VECTOR3, TYPE_FLOAT],
		11: [TYPE_VECTOR3, TYPE_INT, TYPE_INT], 12: [TYPE_VECTOR3], 13: [TYPE_VECTOR3, TYPE_FLOAT],
		14: [TYPE_STRING, TYPE_FLOAT], 15: [TYPE_INT, TYPE_VECTOR3, TYPE_INT],
		16: [TYPE_VECTOR3, TYPE_FLOAT, TYPE_FLOAT], 17: [TYPE_VECTOR3, TYPE_VECTOR3], 18: [TYPE_INT, TYPE_VECTOR3]}
	if not event is Array or event.is_empty() or not event[0] is int or not FIELDS.has(event[0]):
		return false
	var fields: Array = FIELDS[event[0]]
	if event.size() < fields.size() + 1 or event.size() > 8:
		return false
	for i in fields.size():
		var value = event[i + 1]
		if typeof(value) != fields[i] and not (fields[i] == TYPE_FLOAT and value is int):
			return false
		if value is Vector3 and (not value.is_finite() or value.length() > 100000):
			return false
	return true


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _valid_roads(roads: Variant) -> bool:
	if not roads is Array or roads.size() != 3:
		return false
	for group in roads:
		if not group is Array or group.size() > 10000:
			return false
		for line in group:
			if not _valid_points(line):
				return false
	return true


func _valid_points(points: Variant) -> bool:
	if not points is PackedVector3Array or points.size() > 100000:
		return false
	for point in points:
		if not point.is_finite() or point.length() > 100000:
			return false
	return true


func _valid_map(value: Dictionary) -> bool:
	if not value.get("kinds") is PackedByteArray or value.kinds.size() != MapDims.N * MapDims.N or not _valid_roads(value.get("roads")):
		return false
	if not value.get("town") is Rect2 or not value.get("decor") is Array or value.decor.size() > 100000 or not value.get("water") is Dictionary:
		return false
	for item in value.decor:
		if not item is Array or item.size() != 4 or not item[0] is String or not item[1] is Vector3 or not item[2] is float:
			return false
		if not item[1].is_finite() or item[1].length() > 100000 or not is_finite(item[2]):
			return false
		if item[0] in ["walk", "curb", "junction", "drop", "awning", "fence", "garden", "soft", "drive", "path", "pave", "lot_pave"] and not item[3] is Vector3:
			return false
		if item[0] in ["zebra", "stall", "hay"] and item[3] != null and not (item[3] is int or item[3] is float):
			return false
		if item[0] == "wire" and (not item[3] is Array or item[3].size() != 2 or not item[3][0] is Vector3 or not item[3][1] is float):
			return false
	var water: Dictionary = value.water
	if not water.get("coast") is Dictionary:
		return false
	if not water.coast.is_empty() and (not water.coast.get("x") is float or not water.coast.get("s") is float):
		return false
	for key in ["rivers", "ponds", "fords", "bridges"]:
		if not water.get(key) is Array or water[key].size() > 10000:
			return false
	for river in water.rivers:
		if not river is Dictionary or not _valid_points(river.get("pts")) or not river.get("w") is float:
			return false
	for pond in water.ponds:
		if not pond is Dictionary or not pond.get("c") is Vector3 or not pond.get("r") is float or not pond.get("s") is float:
			return false
	for ford in water.fords:
		if not ford is Vector3:
			return false
	for bridge in water.bridges:
		if not bridge is Array or bridge.size() != 4 or not bridge[0] is Vector3 or not bridge[1] is Vector3 or not bridge[2] is float or not bridge[3] is String:
			return false
	return true
