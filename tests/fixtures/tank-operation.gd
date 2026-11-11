extends Node

class TestTank extends Vehicle:
	var shots := 0
	func _fire_cannon() -> void:
		shots += 1

class FlatGroundTank extends Vehicle:
	func _ground_h(_p: Vector3) -> float:
		return 0.0

class SlopingField extends World:
	func ground_y(p: Vector3) -> float:
		return 6.0 + p.x * 0.12 - p.z * 0.24

class TurningTank extends Vehicle:
	func _drive(_dt: float) -> void:
		rotation.y += 0.02


func _ready() -> void:
	_check_running_gear()
	_check_impact_and_pivot()
	_check_wreck_on_slope()
	var tank := TestTank.new()
	var enemy := Vehicle.new()
	tank.vdef = {"base": "tank", "cannon": true, "mg": ""}
	enemy.vdef = {"base": "tank"}
	enemy.eid = 10
	enemy.position = Vector3(50, 0, 0)
	tank.target = enemy
	tank.cannon_t = 0.0
	var dt := 1.0 / 30.0
	tank._turret_tick(dt)
	assert(absf(tank.turret_yaw) <= dt * dt + 0.00001, "traverse starts with acceleration")
	for i in 240:
		var previous := tank.turret_yaw
		tank._turret_tick(dt)
		assert(absf(wrapf(tank.turret_yaw - previous, -PI, PI)) <= 0.7 * dt + 0.00001)
	assert(tank._aim_err() < 0.001 and tank._aim_time > 0.3, "gun settles on target")
	tank._fire_tick()
	assert(tank.shots == 1)
	enemy.eid = 11
	tank.cannon_t = 0.0
	tank._turret_tick(dt)
	tank._fire_tick()
	assert(tank.shots == 1, "a new target needs its own firing solution")
	for i in 12:
		tank._turret_tick(dt)
	tank._fire_tick()
	assert(tank.shots == 2)
	tank.target = null
	tank.turret_yaw = TAU - 0.1
	tank._traverse = 0.0
	tank._turret_tick(dt)
	assert(tank.turret_yaw > -0.1, "return to forward takes the shortest arc")
	assert(tank._aim_time == 0.0)
	var moving := TurningTank.new()
	var world := World.new()
	world.terrain = TerrainMap.new(world)
	moving.world = world
	moving.vdef = tank.vdef
	moving.scan_t = 100.0
	moving.smash_t = 100.0
	moving.cannon_t = 100.0
	moving.target = enemy
	moving.turret_yaw = Defs.yaw_of(enemy.position)
	var bearing := moving.turret_yaw
	for i in 30:
		moving.sim(dt)
	assert(absf(wrapf(moving.rotation.y + moving.turret_yaw - bearing, -PI, PI)) < 0.001,
		"gun stays on its world bearing while the hull turns")
	moving.free()
	world.free()
	tank.target = enemy
	enemy.free()
	tank._turret_tick(dt)
	assert(tank._aim_time == 0.0, "a despawned target is safely released")
	tank.free()
	print("TANK_OPERATION passed")
	get_tree().quit()


func _check_wreck_on_slope() -> void:
	var field := SlopingField.new()
	var wreck := Structure.new()
	wreck.world = field
	wreck.skind = "wreck"
	wreck.wreck_turret_yaw = 0.42
	wreck.bent_skirts = 2
	wreck.size = Vector3(3.6, 2.4, 7.5)
	wreck.yaw = 0.74
	wreck.rotation.y = wreck.yaw
	wreck.position = Vector3(8.0, 3.0, -4.0)
	wreck.model = Node3D.new()
	add_child(wreck)
	wreck.add_child(wreck.model)
	wreck._apply_tilt()
	for x in [-1.4, 1.4]:
		for z in [-2.8, 2.8]:
			var shoe := wreck.model.to_global(Vector3(x, 0, z))
			assert(absf(shoe.y - field.ground_y(shoe)) < 0.002, "both ends of the wreck's tracks rest on the slope")
	var joining := Structure.new()
	joining.world = field
	joining.model = Node3D.new()
	add_child(joining)
	joining.add_child(joining.model)
	joining.apply_props(wreck.get_props())
	assert(joining.bent_skirts == 2 and joining.wreck_turret_yaw == wreck.wreck_turret_yaw)
	assert(joining.model.global_transform.is_equal_approx(wreck.model.global_transform), "a late join sees the same wreck on the ridge")
	joining.free()
	wreck.free()
	field.free()


func _check_running_gear() -> void:
	var built := VehicleModels.build("old_tank", 1, 2)
	add_child(built.root)
	assert(built.belts.size() == 2)
	var faces := PackedVector3Array()
	for part in built.root.get_children():
		if part is MeshInstance3D and part.visibility_range_begin == 0 and part.mesh:
			faces.append_array(part.transform * part.mesh.get_faces())
	var body := TriangleMesh.new()
	assert(body.create_from_faces(faces), "Expected the drawn T-55A hull and fenders")
	# Look straight down at the stowed links and the bare glacis beside them.
	var bare := body.intersect_ray(Vector3(-0.53, 2, -2.32), Vector3.DOWN)
	assert(not bare.is_empty())
	for x: float in [0.245, 0.435, 0.625, 0.815]:
		var link := body.intersect_ray(Vector3(x, 2, -2.32), Vector3.DOWN)
		assert(not link.is_empty() and link.position.y > bare.position.y + 0.05, "Spare links must stand proud of the sloping plate")
	for belt in built.belts:
		# Headless rendering has no readback of instance transforms. Sample
		# the same contact run from the curve that positions those instances.
		var offset := 0.0
		while offset < belt.loop.get_baked_length():
			var point: Vector2 = belt._point(offset)
			if point.y < 0.1 and absf(point.x + 0.03) < 0.05:
				break
			offset += 0.05
		assert(offset < belt.loop.get_baked_length(), "lower run crosses the road wheels")
		var before: Vector2 = belt._point(offset)
		var level := func(_p: Vector3) -> float: return 0.0
		var sprocket: Node3D = belt.wheel_nodes[-1]
		var tooth := TAU / float(sprocket.get_meta(&"teeth"))
		belt.advance(belt.pitch, level)
		assert(is_equal_approx(sprocket.rotation.x, -tooth), "one shoe advances one sprocket tooth")
		belt.advance(-belt.pitch, level)
		var resting: Vector2 = belt._point(offset)
		assert(absf(resting.y - belt.half_thickness) < 0.004, "the belt rests on its lower tangent")
		belt.advance(0.04, level)
		var after: Vector2 = belt._point(offset + belt.phase)
		assert(absf(after.x - before.x - 0.04) < 0.005, "forward travel plants the lower links")
		belt.advance(-0.04, level)
		assert(is_zero_approx(belt.wheel_nodes[0].rotation.x), "reverse unwinds the wheel")
		belt.dust = CPUParticles3D.new()
		belt.dust.emitting = false
		belt.add_child(belt.dust)
		belt.stir_dust(2.0)
		var rear: float = belt.dust.position.z
		belt.stir_dust(-2.0)
		assert(belt.dust.position.z < rear and Vfx.is_emitting(belt.dust))
		belt.stir_dust(0.0)
		assert(not Vfx.is_emitting(belt.dust), "a stopped belt no longer throws dust")
		# A marked shoe should keep its identity past the next shoe's place.
		var two_links: float = 2.4 * belt.pitch
		belt.advance(two_links, level)
		assert(is_equal_approx(belt.phase, two_links), "a link travels its full circuit")
		belt.advance(-two_links, level)
		var bump := func(p: Vector3) -> float: return 0.16 if absf(p.z) < 0.4 else 0.0
		belt.advance(0, bump)
		assert(belt.travel[2] > 0.12 and absf(belt.travel[0]) < 0.03, "one wheel takes the bump")
		assert(belt._point(offset).y - before.y > 0.12, "lower run follows the displaced wheel")
		var gap: float = (belt.centers[0].z + belt.centers[1].z) * 0.5
		var upper: float = belt.loop.get_closest_offset(Vector2(gap, 1.0))
		var top: Vector2 = belt.loop.sample_baked(upper)
		assert(belt._point(upper).y < top.y - 0.015, "the return run sags between supports")
	built.root.rotation.x = 0.19
	var ramp := func(p: Vector3) -> float: return -tan(0.19) * p.z
	for belt in built.belts:
		belt.advance(0.05, ramp)
		for i in belt.centers.size() - 2:
			var sole: Vector3 = belt.to_global(belt.wheel_nodes[i].position - Vector3.UP * (belt.radii[i] + 2 * belt.half_thickness))
			assert(absf(sole.y - ramp.call(sole)) < 0.005, "road wheel contact follows the grade")
		var contact: float = belt.loop.get_closest_offset(Vector2(0.30, 0.02))
		var shoe: Vector2 = belt._point(contact)
		var planted: Vector3 = belt.to_global(Vector3(0, shoe.y, shoe.x))
		built.root.position -= built.root.basis.z * 0.08
		belt.advance(0.08, ramp)
		shoe = belt._point(contact + belt.turn_sign * 0.08)
		assert(planted.distance_to(belt.to_global(Vector3(0, shoe.y, shoe.x))) < 0.005,
			"the same contacting shoe stays planted as the hull climbs")
		# Drive every wheel to its upper stop, then sweep each shoe under
		# the actual hull and fender triangles throughout one pitch.
		var compressed := func(_p: Vector3) -> float: return 10.0
		var least := INF
		for phase in 4:
			belt.advance(belt.pitch * 0.25, compressed)
			for link in belt.multimesh.instance_count:
				var pose: Transform3D = belt.shoe_pose(link)
				if pose.origin.y < 0.70:
					continue
				for x: float in [-0.297, -0.15, 0.0, 0.15, 0.297]:
					for z: float in [-0.45, 0.0, 0.45]:
						var pad: Vector3 = belt.position + pose * Vector3(x, -belt.half_thickness * 1.2, belt.pitch * z)
						var hit := body.intersect_ray(Vector3(pad.x, 0.60, pad.z), Vector3.UP)
						if absf(pad.z) < 1.8:
							assert(not hit.is_empty(), "Expected a wheel well over the road wheels")
						if not hit.is_empty():
							least = minf(least, hit.position.y - pad.y)
		assert(least > 0.004, "Return shoes need clearance under the T-55A fenders at full bump: %s" % least)
	built.root.free()


func _crosses_sheet(sheet: ArrayMesh, at: Vector3) -> bool:
	var faces := sheet.get_faces()
	for i in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(at - Vector3.RIGHT, at + Vector3.RIGHT,
				faces[i], faces[i + 1], faces[i + 2]) != null:
			return true
	return false


func _check_impact_and_pivot() -> void:
	var pieces := VmCore._breakaway_skirt()
	var center := Vector3(0, -0.39, -0.39)
	assert(_crosses_sheet(pieces[1], center) and not _crosses_sheet(pieces[0], center))
	assert(_crosses_sheet(pieces[0], center + Vector3.BACK * 0.2))
	var field := World.new()
	field.has_view = true
	field.view_team = -1
	var tank := FlatGroundTank.new()
	tank.world = field
	tank.vkind = "tank"
	tank.vdef = Defs.VEHICLES.tank
	add_child(tank)
	tank._build_model()
	var left: Node3D = tank._vm.belts[0].wheel_nodes[0]
	var right: Node3D = tank._vm.belts[1].wheel_nodes[0]
	tank.rotation.y = 0.05
	tank._view_process(1.0 / 30.0)
	assert(left.rotation.x * right.rotation.x < 0, "opposing belts turn the hull in place")
	var cradle := tank._vm.gun_mount
	cradle.rotation.x = -0.13
	tank._view_process(1.0 / 60.0)
	var first_step := cradle.rotation.x + 0.13
	tank._view_process(1.0 / 60.0)
	assert(first_step > 0 and cradle.rotation.x + 0.13 > first_step * 2.2, "the displayed barrel gains speed from rest")
	for frame in 90:
		tank._view_process(1.0 / 60.0)
	assert(absf(cradle.rotation.x) < 0.005 and absf(tank._barrel_pitch_rate) < 0.01, "the cradle settles on level ground")
	# Headless games mute the mixer. Exercise the same player controls with
	# real imported loops in the dummy audio driver.
	var sound_enabled := Sfx.enabled
	Sfx.enabled = true
	tank._engine_sound = AudioStreamPlayer3D.new()
	tank._engine_sound.stream = load("res://assets/audio/tracked/turbine.wav")
	tank._track_sound = AudioStreamPlayer3D.new()
	tank._track_sound.stream = load("res://assets/audio/tracked/running-gear.wav")
	tank.add_child(tank._engine_sound)
	tank.add_child(tank._track_sound)
	assert((tank._track_sound.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	tank._track_audio(0.1, true, 2.0, 0.1)
	assert(tank._engine_sound.playing and tank._track_sound.playing)
	tank._track_audio(0.1, true, 0.0, 0.0)
	assert(tank._engine_sound.playing and not tank._track_sound.playing, "idle stops the tracks alone")
	tank._track_audio(0.1, false, 0.0, 0.0)
	assert(not tank._engine_sound.playing, "hidden tanks release their audio")
	Sfx.enabled = sound_enabled
	tank.srv = true
	tank.hp = 100.0
	tank.max_hp = 100.0
	tank.explosion_hit(tank.to_global(Vector3(-1.4, 0.8, -1.9)), {"dmg": 670.0, "size": 1.0})
	assert(tank.bent_skirts == 1 and tank._vm.front_skirts[0].rotation.z < -0.3)
	assert(tank._vm.front_skirts[1].rotation == Vector3.ZERO)
	assert(not tank._vm.skirt_plugs[0].visible and tank._vm.skirt_plugs[1].visible)
	var joining := FlatGroundTank.new()
	joining.world = field
	joining.apply_props(tank.get_props())
	joining.vdef = tank.vdef
	add_child(joining)
	joining._build_model()
	assert(joining._vm.front_skirts[0].rotation == tank._vm.front_skirts[0].rotation)
	tank.repair(40.0)
	assert(tank.bent_skirts == 0 and tank._vm.front_skirts[0].rotation == Vector3.ZERO)
	assert(tank._vm.skirt_plugs[0].visible)
	joining.free()
	var ring_rest := tank.turret.position
	var slide := tank._vm.gun_tip.get_parent() as Node3D
	var gun_rest := slide.position.z
	tank.gun_kick(0.26)
	tank.blast_jolt(tank.position + Vector3.RIGHT, 1.25)
	tank._view_process(1.0 / 30.0)
	assert(tank.turret.position == ring_rest and slide.position.z > gun_rest + 0.1)
	assert(absf(tank.model.rotation.z) > 0.008, "a side impact rolls the hull")
	for i in 100:
		tank._view_process(1.0 / 30.0)
	assert(absf(tank.model.rotation.z) < 0.001 and is_equal_approx(slide.position.z, gun_rest))
	tank.free()
	field.free()
