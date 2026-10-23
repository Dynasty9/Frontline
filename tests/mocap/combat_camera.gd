extends Node3D
## Optional inspection camera. All actors still run the normal battle simulation.
var squad
var tank
var subject
var camera: Camera3D
var caption: Label
var elapsed := 0.0
var tank_focus := Vector3.ZERO
var view_angle := 0.0
var corpse_time := 0.0
var foliage: Array[AABB] = []

func setup(friendly, armour) -> void:
	squad = friendly
	tank = armour
	tank_focus = armour.global_position + Vector3.UP
	for man in squad.alive_members():
		if man.utype == "rifleman":
			subject = man
			break
	camera = Camera3D.new()
	camera.fov = 45
	# The RTS camera focus distances are unsuitable for a close inspection lens.
	camera.attributes = CameraAttributesPractical.new()
	add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(32, 26)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)

func _process(dt: float) -> void:
	if not camera.current: camera.make_current()
	elapsed += dt
	if is_instance_valid(subject) and subject.life != Soldier.Life.ALIVE:
		corpse_time += dt
	else:
		corpse_time = 0.0
	# Briefly show an unscripted death, then return to the living squad.
	# The staged blast keeps its victim in view for the full ragdoll segment.
	if ((elapsed < 15.0 and corpse_time > 1.2) or (elapsed > 15.0 and elapsed < 16.9)) and is_instance_valid(squad):
		for man in squad.alive_members():
			if man.utype == "rifleman":
				subject = man
				break
	var show_tank := (elapsed >= 9.0 and elapsed < 13.0) or elapsed >= 22.0
	var focus := Vector3.ZERO
	var offset := Vector3(3.0, 2.2, -4.8)
	caption.text = "FRONTLINE / LIVE BATTLE - skinned infantry"
	if show_tank:
		if is_instance_valid(tank) and tank.is_inside_tree():
			tank_focus = tank.global_position + Vector3.UP
		focus = tank_focus
		offset = Vector3(7, 3, -9)
		caption.text = "FRONTLINE / LIVE BATTLE - tank impact and wreck"
	elif is_instance_valid(subject) and subject.is_inside_tree():
		focus = subject.global_position + Vector3(0, 0.8, 0)
		if subject.model and subject.model.skinned:
			focus = subject.model.skinned.joint("Hips").origin + Vector3.UP * 0.2
	if elapsed > 15 and elapsed < 22:
		caption.text = "FRONTLINE / LIVE BATTLE - staged blast, skeletal ragdoll"
	if not show_tank:
		var world := get_parent() as World
		foliage.clear()
		if world != null and world.atmo != null and world.atmo.grass != null:
			_gather_foliage(world.atmo.grass, focus)
		var smokes: Array = world.fires.smokes.duplicate() if world != null else []
		if world != null:
			for projectile in world.projectiles:
				if projectile.ptype == "smoke" and projectile.smoke_r > 0.8:
					smokes.append([projectile.position + Vector3(0, 1.4, 0), projectile.smoke_r])
		offset = _camera_offset(focus, offset, smokes)
	camera.global_position = focus + offset
	camera.look_at(focus)

func _visible(focus: Vector3, eye: Vector3) -> bool:
	return _clear_rays(focus, eye) == 3

func _clear_rays(focus: Vector3, eye: Vector3, include_foliage: bool = true) -> int:
	var space := get_world_3d().direct_space_state
	var clear := 0
	var side := (eye - focus).cross(Vector3.UP).normalized() * 0.35
	# Check body width too: a pelvis ray can clear a wall that hides the rifle and shoulders.
	for height in [-0.5, 0.0, 0.6]:
		var blocked := false
		for lateral in [-1.0, 0.0, 1.0]:
			var target: Vector3 = focus + Vector3.UP * height + side * lateral
			for bounds in foliage:
				if not include_foliage: break
				if bounds.has_point(eye) or bounds.intersects_segment(eye, target) != null:
					blocked = true
					break
			if blocked: break
			var ray := PhysicsRayQueryParameters3D.create(eye, target, Defs.L_COVER)
			ray.hit_from_inside = true
			if not space.intersect_ray(ray).is_empty():
				blocked = true
				break
		if not blocked: clear += 1
	return clear

func _gather_foliage(grass: Grass, focus: Vector3) -> void:
	for x in range(floori((focus.x - 10.0) / Grass.CHUNK), floori((focus.x + 10.0) / Grass.CHUNK) + 1):
		for z in range(floori((focus.z - 10.0) / Grass.CHUNK), floori((focus.z + 10.0) / Grass.CHUNK) + 1):
			for node in grass._built.get(Vector2i(x, z), []):
				if not node.is_visible_in_tree() or node.multimesh.mesh != grass.bush: continue
				var mesh_bounds: AABB = grass.bush.get_aabb()
				for i in node.multimesh.instance_count:
					var pose: Transform3D = node.global_transform * node.multimesh.get_instance_transform(i)
					if pose.origin.distance_to(focus) > 12.0: continue
					var ground := grass.atmo.world.terrain.deform_at(pose.origin) if grass.atmo != null else 0.0
					if ground < -0.12: continue
					pose.origin.y += ground
					# Allow for the shader's leaf displacement and wind sway.
					foliage.append((pose * mesh_bounds).grow(0.2))

func _camera_offset(focus: Vector3, offset: Vector3, smokes: Array = []) -> Vector3:
	var best := offset.rotated(Vector3.UP, view_angle)
	var best_clear := -1
	var best_depth := INF
	var best_solid_clear := -1
	var best_angle := view_angle
	for distance in [1.0, 0.7, 0.4]:
		for angle in [view_angle, 0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI]:
			var candidate: Vector3 = offset.rotated(Vector3.UP, angle) * distance
			var clear := _clear_rays(focus, focus + candidate)
			if clear >= best_clear:
				var depth := _smoke_depth(focus, focus + candidate, smokes)
				var solid_clear := _clear_rays(focus, focus + candidate, false)
				# Foliage around the feet must not make an obstructing wall an equal choice.
				if clear > best_clear or (clear == best_clear and (solid_clear > best_solid_clear or (solid_clear == best_solid_clear and depth < best_depth))):
					best = candidate
					best_clear = clear
					best_solid_clear = solid_clear
					best_depth = depth
					best_angle = angle
				if clear == 3 and depth == 0.0:
					view_angle = angle
					return candidate
	# Keep a readable distance when foliage hides part of an enclosed subject.
	view_angle = best_angle
	return best

func _smoke_depth(focus: Vector3, eye: Vector3, smokes: Array) -> float:
	var length := focus.distance_to(eye)
	if length < 0.001: return 0.0
	var direction := (eye - focus) / length
	var depth := 0.0
	for region in smokes:
		var to_center: Vector3 = region[0] - focus
		var along := to_center.dot(direction)
		var radius: float = region[1]
		var half_squared := radius * radius - (to_center.length_squared() - along * along)
		if half_squared <= 0.0: continue
		var half := sqrt(half_squared)
		depth += maxf(0.0, minf(length, along + half) - maxf(0.0, along - half))
	return depth

