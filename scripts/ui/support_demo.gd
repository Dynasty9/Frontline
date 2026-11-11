extends World
## A stationary training range using the game's real support and projectile simulation.
## It has no commanders, orders, network session, economy or battle recording.

signal finished
var support_kind := ""
var _duration := 18.0
var _active := false
var _aircraft: Projectile
var _following_drop := false


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
	_following_drop = false
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
	# Frame the real subject in world space. The RTS rig has its own pitch,
	# so assigning a world-space offset to the camera's local position tilts
	# the shot a second time and can put an approaching aircraft off screen.
	var look := Vector3(0, 2, 0)
	var offset := Vector3(12, 22, 44)
	var recon := bool(Defs.SUPPORT[support_kind].get("recon", false))
	if is_instance_valid(_aircraft) and not _aircraft.gone:
		var plane := _aircraft.global_position
		var chase := Vector3(-17, 9, 31)
		var follow := true
		if _aircraft.ptype == "ac130":
			chase = Vector3(plane.x, 0, plane.z).normalized() * 36.0 + Vector3.UP * 12.0
			# Give wide, banked wings and tiltrotor discs room at the frame edge.
			if _aircraft.guns in ["ac130", "blackfish", "xian"]:
				chase = chase.rotated(Vector3.UP, 0.45) * 1.65
			follow = recon or time < (6.0 if _aircraft.guns == "greyhawk" else 3.2)
		elif _aircraft.ptype == "a10":
			follow = _aircraft._fire_el < 0.0
		elif not recon:
			# Follow the first falling silhouette until it reaches the target.
			# A pan between aircraft and target spends much of the pass on empty sky.
			for drop in projectiles:
				if drop.ptype == "bomb" and not drop.gone:
					var blend := smoothstep(5.0, 50.0, drop.position.y)
					look = look.lerp(drop.position, blend)
					offset = offset.lerp(chase, blend)
					_following_drop = true
					break
			follow = not _following_drop
		if follow:
			look = plane
			# Recon never cuts to a ground impact. Keep the small airframes
			# readable, including the wings of an orbiting drone.
			offset = chase.rotated(Vector3.UP, 0.42) * 0.7 if recon else chase
	elif recon:
		return
	cam.focus_pos = look
	cam.dist = offset.length()
	cam.cam.global_position = look + offset
	cam.cam.look_at(look)
