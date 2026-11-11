extends Node3D
## Seeded ridge-objective encounter using the game's tank models, suspension, sounds and effects.
## Record with --write-movie. Scene time is independent of the capture sample rate.
signal shot_fired(beat: int, muzzle: Vector3, contact: Vector3, ground: bool, flight: float)

const FPS := 30
const SIM_HZ := 60
const Contest := preload("res://tests/fixtures/ridge-contest.gd")
const ImpactPlate := VehicleModels.ImpactPlate

class Field extends "res://tests/fixtures/effects-field.gd":
	var noise := FastNoiseLite.new()
	func ground_y(p: Vector3) -> float:
		var local_x := signf(p.x) * maxf(0.0, absf(p.x) - Contest.GAP)
		var axis := local_x + sin(p.z * 0.045) * 1.4
		var west := 4.7 * exp(-pow((axis + 39.0) / 15.0, 2.0))
		var east := 5.5 * exp(-pow((axis - 40.0) / 19.0, 2.0))
		var back := smoothstep(65.0, 145.0, Vector2(local_x, p.z).length())
		var ridge_length := exp(-pow((p.z + 2.0) / 29.0, 2.0))
		return (west + east) * ridge_length + noise.get_noise_2d(p.x * 6.0, p.z * 6.0) * 0.48 + back * (-7.0 + 4.0 * noise.get_noise_2d(p.x * 0.62, p.z * 0.62))

class StageTank extends Vehicle:
	var plate: ImpactPlate
	var soot: ShaderMaterial
	var fire_sound: AudioStreamPlayer3D
	var disabled := false
	var burn_age := 0.0
	var skirt: Node3D
	var fire_level := -1
	var settling_pitch := 0.0
	var picture_pitch := 0.0
	var last_discharge := -10000
	var gun_delay := AudioEffectDelay.new()
	var hit_delay := AudioEffectDelay.new()
	var report_bus: StringName
	var impact_bus: StringName
	var opening_beat := false
	var claim_waiting := false

	func _track_audio(dt: float, audible: bool, belt_speed: float, grade: float) -> void:
		super._track_audio(dt, audible and (not disabled or burn_age < 1.4), belt_speed, grade)
		if disabled and _engine_sound.playing:
			var coast := smoothstep(0.0,1.4,burn_age)
			_engine_sound.volume_db -= coast * 27.0
			_engine_sound.pitch_scale *= 1.0 - coast * 0.28

	func show_damage(dt: float) -> void:
		if not disabled:
			return
		var previous_age := burn_age
		burn_age += dt
		if previous_age < 0.85 and burn_age >= 0.85:
			world.fx.play(Fx.tank_knockout(plate.global_position + Vector3.UP * 0.25), impact_bus)
		VehicleModels.spread_soot(soot, plate.global_position, burn_age)
		if skirt:
			var side := signf(skirt.position.x)
			skirt.rotation.z = side * (0.41 + 0.20 * sin(burn_age * 8.0) * exp(-burn_age * 1.8)) * smoothstep(0.0, 0.24, burn_age)
			skirt.rotation.x = -0.23 * smoothstep(0.0, 0.8, burn_age)
		var ignition := 2.2
		var level := floori(clampf((burn_age - ignition) * 3.0, 0.0, 8.0))
		if level != fire_level:
			fire_level = level
			world.fx.vfx.set_burning(burner, level * 0.060, 0.55 + level * 0.05)
		if burn_age > 0.45:
			settling_pitch = lerpf(settling_pitch, -0.095, 1.0 - exp(-dt * 0.8))
			_vm.gun_mount.rotation.x = settling_pitch

	func disable() -> void:
		disabled = true
		if skirt:
			_vm.skirt_plugs[_vm.front_skirts.find(skirt)].visible = false
		target = null
		hp = 0
		settling_pitch = _vm.gun_mount.rotation.x
		soot = _vm.scorch_finish()

	func _ground_h(p: Vector3) -> float:
		return world.ground_y(p) - position.y

var field := Field.new()
var camera := Camera3D.new()
var listener := AudioListener3D.new()
var tanks: Array[StageTank] = []
const MARKS_PER_METRE := 48.0
const MARK_SPAN := Vector2(152, 32)
var marks := Image.create(int(MARK_SPAN.x * MARKS_PER_METRE), int(MARK_SPAN.y * MARKS_PER_METRE), false, Image.FORMAT_L8)
var mark_texture: ImageTexture
var shoe_contacts := {}
var marks_dirty := false
var verify := false
var recording := false
var capture_fps := 0
var sample_count := 0
var elapsed := 0.0
var contest: Contest
var battle_seed := 712
var sim_tick := 0
var accumulated := 0.0
var end_time := 120.0
var pending: Array[Dictionary] = []
var glances := 0
var dirt_hits := 0
var last_claim_dirt := false
var camera_kick := 0.0
var kick_time := -1.0
var last_hit_time := -100.0
var eyepiece := ColorRect.new()
var shots_seen: Array[String] = []
var camera_mode := ""
var camera_side := 0
var camera_age := 0.0
var camera_anchor := Vector3.ZERO
var camera_cuts := 0
var min_separation := INF
var driven := [0.0, 0.0]
var outcome_logged := false
var wind: AudioStreamPlayer
var ground_material := ShaderMaterial.new()
var contact_lines := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])


func _ready() -> void:
	TestRun.watch()
	recording = not Engine.get_write_movie_path().is_empty()
	if recording:
		# A covered window can retain its last picture while the simulation and
		# movie clock keep advancing. Draw the recording viewport on every tick.
		RenderingServer.render_loop_enabled = false
		RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	verify = "--verify-ridge-duel" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ridge-fps="):
			capture_fps = maxi(0, arg.trim_prefix("--ridge-fps=").to_int())
		if arg.begins_with("--ridge-seed="):
			battle_seed = arg.trim_prefix("--ridge-seed=").to_int()
	contest = Contest.new(battle_seed)
	seed(battle_seed)
	Sfx._ensure()
	field.view_team = -1
	add_child(field)
	_terrain()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://tests/fixtures/ridge-sky.gdshader")
	var panorama := Image.load_from_file("res://tests/fixtures/ridge-light/qwantani.exr")
	panorama.generate_mipmaps()
	sky_mat.set_shader_parameter("panorama", ImageTexture.create_from_image(panorama))
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.04
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.15
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 2.0
	env.fog_light_color = Color(0.63, 0.71, 0.77)
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = env
	add_child(atmosphere)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(-Vector3(0.574, 0.14, -0.807).normalized(), Vector3.UP)
	sun.light_color = Color(1.0, 0.85, 0.68)
	sun.light_energy = 1.82
	sun.light_angular_distance = 0.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	add_child(sun)
	for i in 2:
		var tank := StageTank.new()
		tank.vkind = "tank" if i == 0 else "old_tank"
		tank.vdef = Defs.VEHICLES[tank.vkind]
		tank.team = 1 - i
		tank.world = field
		tank.eid = i + 1
		tank.srv = true
		tank.hp = 100
		tank.max_hp = 100
		tank.position = Contest.position_of(i, Vector2(-42.0 - contest.drivers[i].rng.randf_range(0.0, 2.0), 0))
		tank.position.y = field.ground_y(tank.position)
		tank.rotation.y = Defs.yaw_of(Defs.flat(contest.destination(i) - tank.position))
		tank.speed = 1.35
		field.add_child(tank)
		tank._build_model()
		tank.always_animate_tracks = true
		# A narrow lens still resolves the paint from the opposite ridge.
		for part: MeshInstance3D in tank.model.find_children("*", "MeshInstance3D", true, false):
			if part.visibility_range_begin > 0.0:
				part.hide()
			else:
				part.visibility_range_end = 0.0
		for belt in tank._vm.belts:
			var contacts: Array[bool] = []
			contacts.resize(belt.multimesh.instance_count)
			shoe_contacts[belt] = contacts
		tank.set_process(false)
		# Keep the fire audible beside the wreck. Its falloff still leaves
		# the wind alone at the far end of the valley.
		tank.fire_sound = tank.burner.get_node("Snd") as AudioStreamPlayer3D
		tank.fire_sound.unit_size *= 1.9
		var side := 1.0 if i == 0 else -1.0
		tank.plate = tank._vm.make_impact_plate(side)
		if not tank._vm.front_skirts.is_empty():
			tank.skirt = tank.plate.get_parent()
		field.vehicles.append(tank)
		tanks.append(tank)
	tanks[0].target = tanks[1]
	tanks[1].target = tanks[0]
	for tank in tanks:
		tank.turret_yaw = Defs.yaw_of(Defs.flat(tank.target.position - tank.position)) - tank.rotation.y
	wind = Sfx.make_ambience("wind", -15.0)
	add_child(wind)
	add_child(camera)
	camera.current = true
	var optic_glass := ShaderMaterial.new()
	optic_glass.shader = preload("res://scripts/shaders/vehicle_eyepiece.gdshader")
	eyepiece.material = optic_glass
	eyepiece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eyepiece)
	eyepiece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera.near = 0.45
	get_viewport().msaa_3d = Viewport.MSAA_4X
	add_child(listener)
	listener.make_current()
	for tank in tanks:
		# Each side keeps its own echo when a reply arrives from across a cut.
		tank.report_bus = StringName("Ridge report %d" % tank.eid)
		tank.impact_bus = StringName("Ridge impact %d" % tank.eid)
		_mic_bus(tank.report_bus, tank.gun_delay)
		_mic_bus(tank.impact_bus, tank.hit_delay)
		for step in 40:
			tank._view_process(1.0 / FPS)
	_shot(0.0)
	listener.global_transform = camera.global_transform

## Delay the direct report by its distance from the mic. Give the impact a
## separate line so the far gun can still be in flight when the plate rings.
func _mic_bus(bus_name: StringName, delay: AudioEffectDelay) -> void:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Effects")
	delay.dry = 0.0
	delay.tap1_level_db = 0.0
	delay.tap2_level_db = -17.0
	delay.tap2_pan = 0.24
	AudioServer.add_bus_effect(index, delay)

func _place_sound(delay: AudioEffectDelay, source: Vector3) -> void:
	var travel_ms := clampf(listener.global_position.distance_to(source) * 1000.0 / 343.0, 1.0, 1250.0)
	delay.tap1_delay_ms = travel_ms
	delay.tap2_delay_ms = travel_ms + 208.0

func _drive(tank: StageTank, i: int, dt: float) -> void:
	var delta := Defs.flat(contest.destination(i) - tank.position)
	var distance := delta.length()
	var old_yaw := tank.rotation.y
	var forward := Defs.dir_of(old_yaw)
	var direction := delta / maxf(distance, 0.001)
	var reverse := forward.dot(direction) < -0.50
	var heading := Defs.yaw_of(-direction if reverse else direction)
	var driven_speed := 0.0
	if distance > 0.85 and not tank.disabled and contest.winner == -1:
		var steer := VehicleMotion.slew(old_yaw, tank.yaw_rate, heading, 0.72, 0.85, dt)
		tank.rotation.y = steer.x
		tank.yaw_rate = steer.y
		var alignment := maxf(0.0, cos(wrapf(heading - steer.x, -PI, PI)))
		var limit := 2.1 if reverse else 3.2
		driven_speed = minf(limit, sqrt(2.0 * 2.5 * maxf(0.0, distance - 0.8))) * alignment * (-1.0 if reverse else 1.0)
	else:
		tank.yaw_rate = move_toward(tank.yaw_rate, 0.0, dt)
	forward = Defs.dir_of(tank.rotation.y)
	var grade := (field.ground_y(tank.position + forward) - field.ground_y(tank.position - forward)) * 0.5
	var accel := 2.0 / (1.0 + 2.5 * maxf(0.0, grade * signf(driven_speed)))
	tank.speed = move_toward(tank.speed, driven_speed, dt * (accel if absf(driven_speed) > absf(tank.speed) else 2.5))
	var step := tank.speed * dt / sqrt(1.0 + grade * grade)
	tank.position += forward * step
	tank.position.y = field.ground_y(tank.position)
	driven[i] += absf(step)
	if not tank.disabled:
		tank.turret_yaw -= wrapf(tank.rotation.y - old_yaw, -PI, PI)
		# Between relay visits the display follows the driver's direction.
		# The game's traverse drive blends back towards the opposite ridge.
		var across := Defs.flat(tanks[1 - i].position - tank.position).normalized()
		var blend := 0.30 * smoothstep(2.0, 11.0, distance)
		var sight := across.lerp(direction, blend)
		tank._slew_turret(Defs.yaw_of(sight) - tank.rotation.y, dt)


## The middle of the valley never receives a print. Give those texels to
## the two driving areas so the gap between successive pads survives filtering.
func _mark_uv(at: Vector3) -> Vector2:
	var x := signf(at.x) * maxf(0.0, absf(at.x) - Contest.GAP - 16.0)
	return Vector2(x, at.z) / MARK_SPAN + Vector2(0.5, 0.5)


func _stamp(tank: Vehicle, i: int) -> void:
	for b in tank._vm.belts.size():
		var belt = tank._vm.belts[b]
		# The loaded stretch ends at the last road wheel, before the belt
		# rises to the sprocket. The ground loses skylight along that stretch.
		var front: Vector3 = belt.wheel_nodes[0].global_position
		var rear: Vector3 = belt.wheel_nodes[-3].global_position
		contact_lines[i * 2 + b] = Vector4(front.x, front.z, rear.x, rear.z)
		var contacts: Array[bool] = shoe_contacts[belt]
		var side3: Vector3 = belt.global_basis.x
		var side := Vector2(side3.x, side3.z).normalized()
		var forward := Vector2(side.y, -side.x)
		for link in contacts.size():
			var shoe: Transform3D = belt.shoe_pose(link)
			var sole: Vector3 = belt.to_global(shoe * (Vector3.DOWN * belt.half_thickness))
			var clearance := sole.y - field.ground_y(sole)
			var loaded: bool = shoe.origin.y < 0.34 and absf(clearance) < 0.075
			if verify and camera_mode == "tracks" and camera_side == i and shoe.origin.y < 0.30:
				if shoe.origin.z > belt.centers[0].z + belt.pitch and shoe.origin.z < belt.centers[-3].z - belt.pitch:
					assert(absf(clearance) < 0.04, "Loaded shoes must follow the hillside")
			var landed := loaded and not contacts[link]
			contacts[link] = loaded
			if not landed:
				continue
			# A resting shoe makes one impression, even as the chassis travels over it.
			var center := _mark_uv(sole) * Vector2(marks.get_size())
			var radius := ceili(0.30 * MARKS_PER_METRE)
			var low := Vector2i(center) - Vector2i(radius, radius)
			var high := Vector2i(center) + Vector2i(radius, radius)
			for y in range(maxi(0, low.y), mini(marks.get_height(), high.y + 1)):
				for x in range(maxi(0, low.x), mini(marks.get_width(), high.x + 1)):
					var delta := (Vector2(x + 0.5, y + 0.5) - center) / MARKS_PER_METRE
					var across := absf(delta.dot(side))
					var along := absf(delta.dot(forward) + (across - 0.126) * 0.09)
					var pad := smoothstep(0.013, 0.033, across) * (1.0 - smoothstep(0.224, 0.252, across))
					var pressure := pad * (1.0 - smoothstep(belt.pitch * 0.26, belt.pitch * 0.42, along))
					if pressure > marks.get_pixel(x, y).r:
						marks.set_pixel(x, y, Color(pressure, pressure, pressure))
			marks_dirty = true


func _simulate(dt: float) -> void:
	for i in 2:
		var tank := tanks[i]
		tank._vm.gun_mount.rotation.x -= tank.picture_pitch
		_drive(tank, i, dt)
		tank._view_process(dt)
		tank.picture_pitch = 0.0
		if not tank.disabled:
			var left := Defs.flat(contest.destination(i) - tank.position).length()
			tank.picture_pitch = deg_to_rad(3.4) * smoothstep(1.5, 12.0, left)
			tank._vm.gun_mount.rotation.x += tank.picture_pitch
		else:
			tank._vm.gun_mount.rotation.x = tank.settling_pitch
		tank.show_damage(dt)
		_stamp(tank, i)
		var post := contest.step(i, tank.position, tank.speed, dt)
		if post >= Contest.Post.RELAY_LEFT:
			tank.claim_waiting = true
		var loaded := sim_tick - tank.last_discharge >= ceili(tank.cannon_interval() * SIM_HZ)
		if loaded and not tank.disabled and (contest.winner < 0 or contest.winner == i):
			if tank.claim_waiting:
				_volley(i, contest.winner == i, false)
				tank.claim_waiting = false
				tank.opening_beat = true
			elif tank.opening_beat and contest.winner < 0 and contest.drivers[i].hold == 0.0:
				_volley(i, false, true)
	if verify and sim_tick == 1:
		# A collapsed belt stamps every shoe at the same spot.
		assert(marks.get_data().count(255) > 1000, "Expected four full contact patches")
	min_separation = minf(min_separation, tanks[0].position.distance_to(tanks[1].position))
	for n in range(pending.size() - 1, -1, -1):
		if sim_tick >= int(pending[n].due):
			_impact(pending.pop_at(n))

func _volley(i: int, decisive: bool, incidental: bool) -> void:
	var other := tanks[1 - i]
	var ground := incidental or (not decisive and contest.drivers[i].rng.randf() < 0.48)
	var at := other.plate.global_position
	if ground:
		if incidental:
			# Extra dirt beats leave the two drivers’ seeded routes untouched.
			at += Vector3(4.0 * cos(sim_tick), 0, 8.0 + 3.0 * sin(sim_tick))
		else:
			at += Vector3(contest.drivers[i].rng.randf_range(-4, 4), 0, contest.drivers[i].rng.randf_range(3, 7))
		at.y = field.ground_y(at)
	# Alternate consecutive dirt claims with a plate strike. Cosmetic shots
	# between claims never consume the drivers’ random draws.
	if ground and not incidental and last_claim_dirt:
		ground = false
		at = other.plate.global_position
	if not incidental:
		last_claim_dirt = ground
	var muzzle := tanks[i].muzzle_world(true)
	if camera_mode == "optic" and camera_side == i:
		_cut("firing", i)
		_shot(float(sim_tick) / SIM_HZ)
		listener.global_transform = camera.global_transform
		if verify:
			assert(_in_picture(muzzle), "The exterior camera must see the firing muzzle on the shot tick")
	elif ground and not incidental and "overhead" in shots_seen and camera_age >= 3.0 and camera_mode not in ["knockout", "push", "ground"]:
		_cut("ground", 1 - i)
		camera_anchor = at
		_shot(float(sim_tick) / SIM_HZ)
		listener.global_transform = camera.global_transform
	_kick_camera(muzzle, 1.0)
	var shooter := tanks[i]
	_place_sound(shooter.gun_delay, muzzle)
	field.fx._cannon(muzzle, at, shooter, shooter.report_bus)
	var flight_ticks := maxi(1, ceili(Fx.cannon_flight(muzzle, at) * SIM_HZ))
	tanks[i].last_discharge = sim_tick
	if verify:
		print("RIDGE_SHOT ", i, " ", sim_tick, " ", flight_ticks, " ", ceili(tanks[i].cannon_interval() * SIM_HZ))
	shot_fired.emit(roundi(float(sim_tick) * FPS / SIM_HZ), muzzle, at, ground, float(flight_ticks) / SIM_HZ)
	pending.append({"due": sim_tick + flight_ticks, "side": 1 - i, "at": at, "ground": ground, "decisive": decisive})

func _impact(event: Dictionary) -> void:
	var i: int = event.side
	var struck := tanks[i]
	var contact: Vector3 = event.at if event.ground else struck.plate.global_position
	if verify:
		print("RIDGE_CONTACT ", 1 - i, " ", sim_tick)
	_kick_camera(contact, 1.35 if event.decisive else 0.8)
	last_hit_time = float(sim_tick) / SIM_HZ
	_place_sound(struck.hit_delay, contact)
	if event.ground:
		dirt_hits += 1
		var distance := contact.distance_to(struck.position)
		if distance < 10.0:
			struck.impact_react(Defs.flat(struck.position - contact).normalized(), 0.32 * (1.0 - distance / 10.0))
		field.fx._explode(contact, 1.05, "he", struck.impact_bus)
		# Press down the standing grass around the crater decal.
		var centre := Vector2i(_mark_uv(contact) * Vector2(marks.get_size()))
		var r := roundi(MARKS_PER_METRE * 1.35)
		for y in range(maxi(0, centre.y - r), mini(marks.get_height(), centre.y + r + 1)):
			for x in range(maxi(0, centre.x - r), mini(marks.get_width(), centre.x + r + 1)):
				var coverage := 1.0 - smoothstep(0.58, 1.0, Vector2(x - centre.x, y - centre.y).length() / r)
				if coverage > marks.get_pixel(x, y).r:
					marks.set_pixel(x, y, Color(coverage, coverage, coverage))
		marks_dirty = true
		return
	struck.plate.take_hit()
	var normal := struck.plate.global_basis.z
	field.fx.hull_strike(contact, normal, struck.impact_bus)
	struck.impact_react(-normal, 1.05)
	if event.decisive:
		if verify:
			assert(camera_mode == "knockout" and camera_side == i and _in_picture(contact), "The camera must see the last hit land")
		if not struck.plate.exposed:
			struck.plate.take_hit()
		struck.disable()
		end_time = ceilf(last_hit_time + 13.0)
	else:
		glances += 1
		var skip := (normal * 0.45 + struck.model.global_basis.z + Vector3.UP * 0.28).normalized()
		field.fx.gunfx.ricochet(contact, skip, true)
		Sfx.play("ricochet", contact, -9.0, 0.90, struck.impact_bus)

func _process(dt: float) -> void:
	if capture_fps > 0:
		dt = 1.0 / capture_fps
	accumulated += minf(dt, 0.25)
	while accumulated >= 1.0 / SIM_HZ - 0.0000001:
		accumulated -= 1.0 / SIM_HZ
		sim_tick += 1
		_simulate(1.0 / SIM_HZ)
	ground_material.set_shader_parameter("contact_lines", contact_lines)
	if marks_dirty:
		mark_texture.update(marks)
		marks_dirty = false
	camera_age += dt
	_shot(elapsed)
	# Cut the microphone with the picture. Sweeping it across the valley
	# briefly pans and amplifies sources outside either shot.
	listener.global_transform = camera.global_transform
	var fade := smoothstep(end_time - 0.8, end_time - 0.25, elapsed)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), -42.0 * fade)
	if elapsed >= end_time - 0.25 and Sfx.enabled:
		Sfx.enabled = false
		wind.stop()
		for tank in tanks:
			tank.fire_sound.stop()
	sample_count += 1
	elapsed = sample_count / float(capture_fps) if capture_fps > 0 else elapsed + dt
	if elapsed >= end_time - 0.00001 and not outcome_logged:
		outcome_logged = true
		if Music._task >= 0:
			WorkerThreadPool.wait_for_task_completion(Music._task)
			Music._task = -1
		var claims := [contest.drivers[0].claims, contest.drivers[1].claims]
		var visits := [Array(contest.drivers[0].visits), Array(contest.drivers[1].visits)]
		print("RIDGE_RESULT ", JSON.stringify({"seed": battle_seed, "winner": contest.winner, "actions": contest.actions, "claims": claims, "visits": visits, "distance": driven, "separation": min_separation, "ticks": sim_tick, "cuts": camera_cuts, "glances": glances, "dirt_hits": dirt_hits, "shots": shots_seen, "vehicles": [tanks[0].vkind, tanks[1].vkind]}))
		if verify:
			assert(contest.winner >= 0 and tanks[1 - contest.winner].disabled)
			assert(tanks[1 - contest.winner].plate.exposed and not tanks[contest.winner].disabled)
			assert(min_separation > 300 and minf(driven[0], driven[1]) > 20)
			assert(contest.drivers[contest.winner].supplies >= 1)
			print("RIDGE_DUEL verified")
		print("RIDGE_DUEL captured ", sample_count, " frames")
		TestRun.quit(get_tree())
	if recording:
		RenderingServer.force_draw(false, dt)

func _kick_camera(source: Vector3, strength: float) -> void:
	if not Settings.get_v("shake"):
		return
	var t := float(sim_tick) / SIM_HZ
	var local_kick := strength * exp(-camera.global_position.distance_to(source) / 32.0)
	if local_kick > camera_kick * exp(-9.0 * (t - kick_time)):
		camera_kick = local_kick
		kick_time = t


func _cut(mode: String, i: int) -> void:
	camera_kick = 0.0
	camera_mode = mode
	eyepiece.visible = mode == "optic"
	Sfx.cabin_listening(eyepiece.visible)
	if mode not in shots_seen:
		shots_seen.append(mode)
	camera_side = i
	camera_anchor = tanks[i].position
	if mode == "knockout":
		var tank := tanks[i]
		var side := signf(tank.model.to_local(tank.plate.global_position).x)
		camera_anchor = tank.to_global(Vector3(side * 12.4, 2.55, -7.5))
	camera_age = 0.0
	camera_cuts += 1
	if verify:
		print("RIDGE_CUT ", sim_tick, " ", mode, " ", i)

func _shot(t: float) -> void:
	if camera_mode.is_empty():
		_cut("overview", 0)
	elif contest.winner >= 0:
		var struck := 1 - contest.winner
		var mode := "knockout"
		if t > end_time - 4.0:
			mode = "wide"
		elif tanks[struck].disabled and t - last_hit_time > 4.0:
			mode = "engine"
		if camera_mode != mode:
			_cut(mode, contest.winner if mode == "wide" else struck)
	elif camera_mode == "overview" and camera_age >= 4.0:
		_cut("wide", 0)
	elif camera_mode == "wide" and camera_age >= 4.0:
		_cut("distant", 1)
	elif camera_mode == "distant" and "optic" not in shots_seen and camera_age >= 4.0:
		_cut("optic", 0)
	elif camera_mode == "firing" and camera_age >= 3.5:
		_cut("overhead", camera_side)
	elif camera_mode == "overhead" and camera_age >= 3.5:
		_cut("tracks", camera_side)
	elif camera_mode == "barrel" and camera_age >= 3.2:
		_cut("knockout", camera_side)
	elif camera_mode == "push":
		for i in 2:
			if contest.drivers[i].advance and contest.drivers[i].hold > 0.0 and camera_age >= 3.0:
				_cut("knockout", 1 - i)
				break
	elif camera_mode in ["tracks", "ground", "roof", "distant"] and "overhead" in shots_seen and camera_age >= 4.0:
		if contest.drivers[0].advance or contest.drivers[1].advance:
			var leader := 0 if contest.drivers[0].advance else 1
			if Defs.flat(tanks[leader].position - contest.destination(leader)).length() < 9.0:
				_cut("barrel" if contest.drivers[leader].hold < 0.4 else "knockout", 1 - leader)
			else:
				_cut("push", leader)
		elif camera_age >= 6.0:
			_cut("roof" if camera_mode != "roof" else "distant", 1 - camera_side)
	var own := tanks[camera_side].position
	var facing := 1.0 if camera_side == 0 else -1.0
	var aim := own + Vector3.UP * 1.25
	var mount_label: StringName
	match camera_mode:
		"overview":
			# Look along the valley so the foreground tank reads at this distance.
			camera.position = Vector3(-263, 32, 46)
			var near_ray := camera.position.direction_to(tanks[0].position + Vector3.UP)
			var far_ray := camera.position.direction_to(tanks[1].position + Vector3.UP)
			aim = camera.position + (near_ray + far_ray).normalized()
			camera.fov = 36
		"optic":
			camera.position = tanks[0].camera_mounts()[&"Periscope"].global_position
			aim = tanks[1].turret.global_position + Vector3.UP * 0.4
			# Hold the landscape first. Changing focal length keeps the lens
			# on the same part of the ridge as the vehicle crosses the frame.
			var zoom := smoothstep(0.40, 1.65, camera_age)
			camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(8.0) * 0.5) / lerpf(1.0, 4.8, zoom)))
		"wide":
			if contest.winner < 0:
				mount_label = &"Behind"
				camera.fov = 37
			else:
				# Stage the last shot from the sunlit flank of the turret. The
				# barrel stays in profile even when the hull turns independently.
				var tank := tanks[camera_side]
				var barrel := Defs.flat(tank.muzzle_world(true) - tank._vm.gun_mount.global_position).normalized()
				var flank := barrel.cross(Vector3.UP)
				if flank.z < 0:
					flank = -flank
				camera.position = own + flank * 12.8 + barrel * 7.0 + Vector3.UP * 1.85
				aim = own + Vector3.UP * 1.25 + barrel * 0.95
				camera.fov = 31
		"firing":
			var tank := tanks[camera_side]
			var axis := Defs.flat(tank.muzzle_world(true) - tank.position).normalized()
			var flank := axis.cross(Vector3.UP)
			if flank.z < 0.0:
				flank = -flank
			camera.position = own + flank * 14.5 + axis * 3.0 + Vector3.UP * 2.8
			aim += axis * 1.65
			camera.fov = 37
		"overhead":
			mount_label = &"Aerial"
			camera.fov = 48
		"barrel":
			mount_label = &"Barrel"
			camera.fov = 54
		"roof":
			mount_label = &"Roof gun"
			camera.fov = 61
		"ground":
			aim = camera_anchor.lerp(own, 0.5) + Vector3.UP * 1.3
			camera.position = aim + Vector3(8 * facing, 3.3, 18)
			camera.fov = 40
		"tracks":
			mount_label = &"Tracks"
			camera.fov = 40
		"distant":
			# Keep the opposite skyline visible while the rounded turret clears it.
			camera.position = own + Vector3(19 * facing, 5.2, 33)
			camera.fov = 18.0
			aim.y += 0.4
		"engine":
			mount_label = &"Engine deck"
			camera.fov = 38
		"knockout":
			var tank := tanks[camera_side]
			camera.position = camera_anchor
			var barrel := Defs.flat(tank._vm.gun_mount.global_position.direction_to(tank.muzzle_world(true)))
			aim = own + Vector3.UP * 1.25 + barrel * 0.85
			camera.fov = 34.0
		"push":
			camera.position = camera_anchor + Vector3(9 * facing, 3.5, 18)
			camera.fov = 35
			aim.x += facing * 1.25
		_:
			camera.position = own + Vector3(-5.6 * facing, 2.8, 9.9)
			camera.fov = 43
			aim.x += facing * 0.85
	if mount_label != &"":
		var mount: Marker3D = tanks[camera_side].camera_mounts()[mount_label]
		camera.global_transform = mount.global_transform.orthonormalized()
		aim = camera.position - camera.global_basis.z * 12
	camera.position.y = maxf(camera.position.y, field.ground_y(camera.position) + 0.7)
	camera.look_at(aim)
	var age := maxf(0.0, float(sim_tick) / SIM_HZ - kick_time)
	var recoil := camera_kick * exp(-9.0 * age) * deg_to_rad(camera.fov) * 0.022
	camera.rotate_object_local(Vector3.RIGHT, recoil * cos(37.0 * age))
	camera.rotate_object_local(Vector3.UP, recoil * 0.45 * sin(51.0 * age))
	if verify and camera_mode == "optic":
		if camera_age < 0.3:
			assert(camera.fov > 7.0, "The eyepiece must open wide enough to show the ridge")
		elif camera_age > 1.8:
			assert(camera.fov < 2.0, "The zoom must settle before the shot ends")
	if verify and camera_mode == "overview":
		for tank in tanks:
			assert(_in_picture(tank.position + Vector3.UP), "Both ridges should be in the opening frame")
	if verify and camera_mode == "wide" and contest.winner >= 0:
		var tank := tanks[camera_side]
		var tip := tank.muzzle_world(true)
		assert(_in_picture(tip), "Keep the muzzle in frame")
		var gun := (tip - tank._vm.gun_mount.global_position).normalized()
		assert(absf(gun.dot(camera.global_basis.z)) < 0.65, "The closing shot needs a readable barrel silhouette")
		for x: float in [-1.8, 1.8]:
			for z: float in [-3.8, 3.8]:
				assert(_in_picture(tanks[camera_side].model.to_global(Vector3(x, 1.0, z))), "Keep the full hull in the closing frame")

# Check the 16:9 export lens even when the headless renderer has no window.
func _in_picture(point: Vector3) -> bool:
	var local := camera.to_local(point)
	var half_height := -local.z * tan(deg_to_rad(camera.fov) * 0.5)
	return absf(local.y) < half_height and absf(local.x) < half_height * 16.0 / 9.0

func _terrain() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(380 + Contest.GAP * 2.0, 380)
	mesh.subdivide_width = roundi(mesh.size.x)
	mesh.subdivide_depth = 380
	var data := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var mark_uv := PackedVector2Array()
	mark_uv.resize(verts.size())
	for i in verts.size():
		var p := verts[i]
		mark_uv[i] = _mark_uv(p)
		p.y = field.ground_y(p)
		verts[i] = p
		normals[i] = Vector3(field.ground_y(p - Vector3.RIGHT * 0.5) - field.ground_y(p + Vector3.RIGHT * 0.5), 1.0, field.ground_y(p - Vector3.BACK * 0.5) - field.ground_y(p + Vector3.BACK * 0.5)).normalized()
	data[Mesh.ARRAY_TEX_UV2] = mark_uv
	data[Mesh.ARRAY_VERTEX] = verts
	data[Mesh.ARRAY_NORMAL] = normals
	var ground := ArrayMesh.new()
	ground.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	mark_texture = ImageTexture.create_from_image(marks)
	ground_material.shader = preload("res://tests/fixtures/ridge-ground.gdshader")
	ground_material.set_shader_parameter("marks", mark_texture)
	ground_material.set_shader_parameter("turf", preload("res://assets/terrain/aerial_grass_rock_diff_2k.jpg"))
	ground_material.set_shader_parameter("scree", preload("res://assets/terrain/aerial_rocks_02_diff_2k.jpg"))
	ground_material.set_shader_parameter("relief", preload("res://assets/terrain/aerial_grass_rock_nor_gl_2k.jpg"))
	var hillside := Res.mi(self, ground, ground_material, Vector3.ZERO)
	hillside.layers |= Res.GROUND_DECAL_LAYER
	var plants := Grass.new()
	add_child(plants)
	plants.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 712
	var blades := []
	var colors := []
	for i in 25000:
		var p := Vector3(rng.randf_range(-72,72), 0, rng.randf_range(-60,24))
		p.x += signf(p.x) * Contest.GAP
		if i % 5 == 0:
			p.x = rng.randf_range(-Contest.GAP, Contest.GAP)
		var patch := field.noise.get_noise_2d(p.x * 10, p.z * 10)
		if patch < -0.15:
			continue
		p.y = field.ground_y(p) - 0.035
		var size := rng.randf_range(0.14, 0.47) * (1.0 + patch * 0.5)
		blades.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), p))
		colors.append(Color(0.25 + 0.25 * patch, rng.randf(), 0, 0))
	# Two photographed bunches alternate around three intersecting cards.
	# Alpha coverage keeps the fine stems visible against distant ground.
	var turf := SurfaceTool.new()
	turf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 3:
		var axis := Vector3(cos(PI * j / 3.0), 0, sin(PI * j / 3.0)) * 0.6
		for corner: Vector2 in [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(0,1)]:
			turf.set_normal(Vector3.UP)
			turf.set_uv(Vector2((corner.x + (j & 1)) * 0.5, 1.0 - corner.y))
			turf.add_vertex(axis * (corner.x * 2.0 - 1.0) + Vector3.UP * corner.y * 0.6)
	var sprite := Image.load_from_file("res://tests/fixtures/ridge-light/grass.png")
	sprite.fix_alpha_edges()
	sprite.generate_mipmaps()
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = preload("res://tests/fixtures/ridge-grass.gdshader")
	grass_mat.set_shader_parameter("atlas", ImageTexture.create_from_image(sprite))
	grass_mat.set_shader_parameter("marks", mark_texture)
	grass_mat.set_shader_parameter("mark_span", MARK_SPAN)
	grass_mat.set_shader_parameter("mark_gap", Contest.GAP + 16.0)
	# These batches span both ridges. A distance cut on their shared
	# center made nearby plants vanish whenever the lens moved to a tank.
	plants._mm(turf.commit(), grass_mat, blades, colors, 0).name = "DriedGrass"
	for file in ["sand-rock", "rooibos"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file("res://tests/fixtures/ridge-light/%s.glb" % file, state) != OK:
			push_error("Cannot load ridge scenery " + file)
			continue
		var source := document.generate_scene(state)
		var original := source.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var patches := []
		var shades := []
		var shrub: bool = file == "rooibos"
		for i in (1900 if shrub else 310):
			var p := Vector3(rng.randf_range(-100,100), 0, rng.randf_range(-94,33))
			p.x += signf(p.x) * Contest.GAP
			if i % 5 == 0:
				p.x = rng.randf_range(-Contest.GAP, Contest.GAP)
			if absf(absf(p.x) - Contest.GAP - Contest.RIDGE) < 22.0 and absf(p.z) < 10.0:
				continue
			if field.noise.get_noise_2d(p.x * 4.0, p.z * 4.0) < -0.14:
				continue
			var size := rng.randf_range(0.32, 1.15) if shrub else rng.randf_range(0.30, 0.82)
			p.y = field.ground_y(p) - (0.025 if shrub else 0.075) * size
			var nx := field.ground_y(p - Vector3.RIGHT * 0.5) - field.ground_y(p + Vector3.RIGHT * 0.5)
			var nz := field.ground_y(p - Vector3.BACK * 0.5) - field.ground_y(p + Vector3.BACK * 0.5)
			var tilt := Basis(Quaternion(Vector3.UP, Vector3(nx,1,nz).normalized()))
			patches.append(Transform3D(tilt * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), p))
			shades.append(Color.WHITE)
		var group := plants._mm(original.mesh, null, patches, shades, 0)
		group.name = "Rooibos" if shrub else "Rocks"
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		source.free()
