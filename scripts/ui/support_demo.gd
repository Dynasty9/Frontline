extends World
## A stationary training range using the game's real support and projectile simulation.
## It has no commanders, orders, network session, economy or battle recording.

signal finished
var support_kind := ""
var _duration := 18.0
var _active := false
var _aircraft: Projectile


func _build_environment() -> void:
	# The manual supplies the survey floor and lights; a sortie needs no full map renderer.
	pass


func prepare(kind: String) -> void:
	support_kind = kind
	nav = Nav.new()
	nav.terrain = terrain
	combat = Combat.new(self)
	rules = Rules.new(self)
	battle = BattleStats.new(self)
	fires = Fires.new(self)
	if has_view:
		cam = RtsCamera.new()
		cam.world = self
		add_child(cam)
		cam.process_mode = Node.PROCESS_MODE_DISABLED
		cam.cam.current = true
		cam.cam.far = 1500.0
		# Keep the range quiet until the explicitly requested sortie begins.
		Music.play_cue("")
	await get_tree().process_frame
	_start_sortie()


func replay() -> void:
	_active = false
	process_mode = Node.PROCESS_MODE_DISABLED
	for e in entities.values():
		despawn(e)
	# Despawn defers detaching entities; let that finish before releasing them.
	await get_tree().process_frame
	for entry in _graveyard:
		entry[0].free()
	_graveyard.clear()
	fires = Fires.new(self)
	combat = Combat.new(self)
	# Keep warmed effect pools and terrain collision; old smoke and debris fade naturally.
	_start_sortie()


func _start_sortie() -> void:
	var kind := support_kind
	rng.seed = int(settings.get("seed", 7))
	for i in 3:
		spawn("vehicle", {"vkind": "technical", "team": 1, "owner": -2, "pos": Vector3(-14 + i * 14, 0, (i % 2) * 7 - 3), "yaw": 0.2})
	rules.demo_support(kind, Vector3.ZERO, Vector3.RIGHT)
	for p in projectiles:
		if p.ptype in ["a10", "jet", "ac130"]:
			_aircraft = p
	_duration = 34.0 if String(Defs.SUPPORT[kind].shape) == "orbit" else 18.0
	time = 0.0
	_active = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	_update_camera()


func _physics_process(dt: float) -> void:
	if not _active:
		return
	time += dt
	_rebuild_uhash()
	for p in projectiles.duplicate():
		if not p.gone:
			p.sim(dt)
	fires.tick(dt)
	terrain.tick(2500)
	if time >= _duration:
		_active = false
		finished.emit()
		process_mode = Node.PROCESS_MODE_DISABLED


func _process(_dt: float) -> void:
	if _active:
		_update_camera()


func _update_camera() -> void:
	if not cam:
		return
	var look := Vector3(0, 20, 0)
	var offset := Vector3(-55, 90, 135)
	if is_instance_valid(_aircraft) and not _aircraft.gone:
		if _aircraft.ptype == "ac130":
			look = _aircraft.position * 0.5
			offset = Vector3(85, 120, 160)
		elif _aircraft.position.x < 160.0:
			var approach := smoothstep(-240.0, -90.0, _aircraft.position.x)
			look = _aircraft.position.lerp(_aircraft.position * 0.5, approach)
			offset = Vector3(-30, 18, 65).lerp(offset, approach)
	cam.focus_pos = look
	cam.dist = offset.length()
	cam.cam.position = look + offset
	cam.cam.look_at(look)
