class_name VehicleFittings
extends RefCounted
## Repeating service fittings, folded into the parent's existing material bake.
static var _pipes := {}

## Round unlit optical insert; center is the old lens face, direction points out.
## Families retain their mounting boxes and protective cages. The shallow cup
## sits ahead of the old housing face so the solid housing cannot fill it in.
static func headlamp(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, direction := Vector3.FORWARD) -> void:
	if radius <= 0.0 or direction.length_squared() < 0.000001:
		return
	var mount := k._pivot(parent, center)
	mount.basis = VehicleFrames.aim(direction)
	k._cyl(mount, radius * 1.08, radius * 1.08, radius * 0.16, Vector3.ZERO, Vector3.ZERO, "rubber", null, 20, false)
	k._add(mount, _ring(radius * 0.96, radius * 1.09), "gunmetal_w", null, Vector3(0, radius * 0.19, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
	if not k.burnt:
		k._add(mount, _headlamp_reflector(), "headlamp", Color(0.76, 0.78, 0.73), Vector3.ZERO, Vector3.ZERO, Vector3.ONE * radius, false)
		# Sparse moulded ribs approximate a sealed-beam lens without transparent
		# sorting or another light/shadow pass. All detail joins the hull bake.
		for i in range(-3, 4):
			var x := i * 0.23
			var half_span := sqrt(0.88 * 0.88 - x * x)
			for j in 4:
				var z0 := lerpf(-half_span, half_span, j / 4.0)
				var z1 := lerpf(-half_span, half_span, (j + 1) / 4.0)
				var a := Vector3(x, 0.22 + 0.08 * (1.0 - x * x - z0 * z0), z0) * radius
				var b := Vector3(x, 0.22 + 0.08 * (1.0 - x * x - z1 * z1), z1) * radius
				VehicleFrames.tube(k, mount, a, b, radius * 0.018, "headlamp", Color(0.52, 0.58, 0.56), 5, false)
		k._cyl(mount, radius * 0.14, radius * 0.18, radius * 0.08, Vector3(0, radius * 0.17, 0), Vector3.ZERO, "gunmetal", Color(0.28, 0.29, 0.27), 12, false)
	k._fold(mount)


static var _lamp_reflector: ArrayMesh

## Unit dish shared by every lamp size, facing local +Y.
static func _headlamp_reflector() -> ArrayMesh:
	if _lamp_reflector:
		return _lamp_reflector
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 4:
		for segment in 24:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var r := 0.12 + (ring + corner.x) * 0.21
				var angle := TAU * (segment + corner.y) / 24.0
				surface.add_vertex(Vector3(cos(angle) * r, 0.09 + 0.13 * r * r, sin(angle) * r))
	surface.generate_normals()
	_lamp_reflector = surface.commit()
	return _lamp_reflector


## Local XY grille, +Z outward. Fins stand in front of a recessed radiator core.
static func grille(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, material: String, col = null, count := 8, vertical := false) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var rim := minf(0.035, minf(size.x, size.y) * 0.08)
	k._box(mount, Vector3(size.x, size.y, 0.018), Vector3(0, 0, -0.035), "plain_dark", Color(0.025, 0.028, 0.026), Vector3.ZERO, false)
	# Fine radiator channels behind the broad protective slats.
	var channels := clampi(ceili(size.x / 0.055), 6, 40)
	for i in channels:
		k._box(mount, Vector3(0.008, size.y - rim * 2, 0.012), Vector3(lerpf(-size.x / 2 + rim, size.x / 2 - rim, float(i) / (channels - 1)), 0, -0.018), "gunmetal", Color(0.14, 0.15, 0.14), Vector3.ZERO, false)
	for side in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x, rim, 0.06), Vector3(0, side * (size.y - rim) / 2, 0), material, col)
		k._box(mount, Vector3(rim, size.y - rim * 2, 0.06), Vector3(side * (size.x - rim) / 2, 0, 0), material, col)
		for y in [-1.0, 1.0]:
			VehicleBody.fastener(k, mount, Vector3(side * (size.x / 2 - rim / 2), y * (size.y / 2 - rim / 2), 0.035), Vector3.BACK, rim * 0.24)
	var span := (size.x if vertical else size.y) - rim * 2
	var pitch := span / maxf(count, 1)
	for i in count:
		var offset := -span / 2 + pitch * (i + 0.5)
		var fin_size := Vector3(pitch * 0.36, size.y - rim * 2, 0.035) if vertical else Vector3(size.x - rim * 2, pitch * 0.36, 0.035)
		k._box(mount, fin_size, Vector3(offset, 0, 0.008) if vertical else Vector3(0, offset, 0.008), material, col, Vector3(0, 0.22, 0) if vertical else Vector3(-0.28, 0, 0))
	k._fold(mount)


## A clamped rubber flap with a gently kicked lower edge and reinforcing ribs.
static func mudflap(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var rings: Array = []
	for i in 5:
		var t := float(i) / 4
		var y := size.y * (0.5 - t)
		var bend := t * t * 0.045
		rings.append(PackedVector3Array([Vector3(-size.x / 2, y, bend - 0.012), Vector3(size.x / 2, y, bend - 0.012), Vector3(size.x / 2, y, bend + 0.012), Vector3(-size.x / 2, y, bend + 0.012)]))
	k._add(mount, VehicleModels.solid(rings, "shared_mudflap_%s" % str(size)), "rubber", null, Vector3.ZERO)
	k._box(mount, Vector3(size.x, 0.04, 0.018), Vector3(0, size.y / 2 - 0.025, 0.026), "gunmetal", Color(0.22, 0.23, 0.21))
	for side in [-1.0, 0.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * size.x * 0.36, size.y / 2 - 0.025, 0.038), Vector3.BACK, 0.009)
	for side in [-1.0, 1.0]:
		for i in 4:
			var t0 := float(i) / 4
			var t1 := float(i + 1) / 4
			VehicleFrames.tube(k, mount, Vector3(side * size.x * 0.36, size.y * (0.5 - t0), t0 * t0 * 0.045 + 0.016), Vector3(side * size.x * 0.36, size.y * (0.5 - t1), t1 * t1 * 0.045 + 0.016), 0.006, "rubber", Color(0.10, 0.11, 0.10), 5, false)
	k._fold(mount)


## Hollow exhaust on an authored axis. The dark sleeve sits behind the rolled
## lip; it is not a black disc pasted onto the end of a closed cylinder.
static func exhaust(k: VehicleModels, parent: Node3D, base: Vector3, direction: Vector3, length: float, radius: float) -> void:
	var mount := k._pivot(parent, base)
	mount.basis = VehicleFrames.aim(direction)
	var key := Vector2(radius, length)
	if not _pipes.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = radius
		outer.bottom_radius = radius
		outer.height = length
		outer.radial_segments = 16
		outer.cap_top = false
		var inner := CylinderMesh.new()
		inner.top_radius = radius * 0.80
		inner.bottom_radius = radius * 0.80
		inner.height = minf(length, radius * 4)
		inner.radial_segments = 16
		inner.cap_top = false
		inner.cap_bottom = false
		inner.flip_faces = true
		_pipes[key] = [outer, inner]
	var pipes: Array = _pipes[key]
	k._add(mount, pipes[0], "gunmetal", Color(0.24, 0.23, 0.21), Vector3(0, length / 2, 0))
	var depth := minf(length, radius * 4)
	k._add(mount, pipes[1], "burnt", Color(0.025, 0.025, 0.023), Vector3(0, length - depth / 2, 0))
	k._cyl(mount, radius * 0.8, radius * 0.8, 0.004, Vector3(0, length - depth, 0), Vector3.ZERO, "burnt", null, 16, false)
	k._add(mount, VehicleWheels.ring(radius * 0.8, radius * 1.03), "gunmetal", Color(0.28, 0.24, 0.19), Vector3(0, length, 0))
	# Stand-off shield and clamps sit below the hot, uncovered outlet.
	k._cyl(mount, radius * 1.4, radius * 1.4, length * 0.30, Vector3(0, length * 0.43, 0), Vector3.ZERO, "steel", Color(0.28, 0.29, 0.26), 16)
	for t in [0.28, 0.58]:
		k._add(mount, VehicleWheels.ring(radius * 1.35, radius * 1.55), "gunmetal", Color(0.18, 0.19, 0.17), Vector3(0, length * t, 0), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	k._fold(mount)


## A fixed whip with a rubber boot, spring base and tapered flexible rod.
## The fixed boot stays baked into the hull; the spring and rod share one pivot.
static func antenna(k: VehicleModels, parent: Node3D, base: Vector3, height: float) -> void:
	var mount := k._pivot(parent, base)
	k._box(mount, Vector3(0.13, 0.025, 0.13), Vector3(0, 0.0125, 0), "gunmetal_w")
	for side in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * 0.045, 0.03, 0), Vector3.UP, 0.012)
	k._cyl(mount, 0.034, 0.05, 0.09, Vector3(0, 0.065, 0), Vector3.ZERO, "rubber", null, 10, false)
	var whip := k._pivot(mount, Vector3(0, 0.10, 0))
	if not k.burnt:
		k.antennas.append(whip)
	k._cyl(whip, 0.019, 0.019, 0.16, Vector3(0, 0.08, 0), Vector3.ZERO, "gunmetal_w", null, 8, false)
	k._add(whip, _antenna_spring(), "gunmetal_w", Color(0.24, 0.25, 0.23), Vector3(0, 0.008, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 5:
		var t0 := float(i) / 5
		var t1 := float(i + 1) / 5
		var a := Vector3(0, 0.16 + (height - 0.14) * t0, height * 0.035 * t0 * t0)
		var b := Vector3(0, 0.16 + (height - 0.14) * t1, height * 0.035 * t1 * t1)
		VehicleFrames.tube(k, whip, a, b, lerpf(0.013, 0.005, t0), "gunmetal_w", null, 6, false, lerpf(0.013, 0.005, t1))
	if k.burnt:
		k._fold(whip)
	k._fold(mount)


## Rear-facing mirror glass (+Z), in a moulded housing on jointed arms.
## Anchors are parent-local; the family owns the door attachment positions.
static func mirror(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, yaw: float, anchors: Array) -> void:
	var facing := Basis(Vector3.UP, yaw)
	for i in anchors.size():
		var y := (0.28 if i == 0 else -0.28) * size.y
		var end := center + facing * Vector3(0, y, -0.06)
		var local_anchor: Vector3 = facing.inverse() * (anchors[i] - center)
		var side := 1.0 if local_anchor.x >= 0 else -1.0
		# Route around the housing edge before turning onto its back. A straight
		# diagonal from the door can otherwise pass through the reflective face.
		var elbow := center + facing * Vector3(side * (size.x / 2 + 0.045), y, -0.06)
		VehicleFrames.path(k, parent, [anchors[i], elbow, end], 0.018, "gunmetal_w", null, 8)
		k._add(parent, Res.sphere(0.027, 8), "gunmetal_w", null, end)
	var mount := k._pivot(parent, center)
	mount.rotation.y = yaw
	k._box(mount, Vector3(size.x, size.y, 0.06), Vector3.ZERO, "plain_dark", Color(0.11, 0.12, 0.11))
	k._box(mount, Vector3(size.x - 0.018, size.y - 0.018, 0.009), Vector3(0, 0, 0.033), "rubber", Color(0.06, 0.065, 0.06), Vector3.ZERO, false)
	k._add(mount, _mirror_glass(size - Vector2(0.033, 0.033)), "mirror", Color(0.78, 0.82, 0.84), Vector3(0, 0, 0.042), Vector3.ZERO, Vector3.ONE, false)
	# A rib on the back stiffens the shell around the arm mounting points.
	k._box(mount, Vector3(0.025, size.y * 0.7, 0.014), Vector3(0, 0, -0.035), "plain_dark", Color(0.13, 0.14, 0.13), Vector3.ZERO, false)
	k._fold(mount)


## Open gun tube aimed from breech to muzzle. The family keeps its recoil,
## extractor, reference sensor and gun_tip; this helper owns the tube's finish.
static func barrel(k: VehicleModels, parent: Node3D, breech: Vector3, muzzle: Vector3, radius: float, material: String, col = null, sleeved := true) -> void:
	var length := breech.distance_to(muzzle)
	if length < 0.001:
		return
	var mount := k._pivot(parent, breech)
	mount.basis = VehicleFrames.aim(muzzle - breech)
	var key := Vector2(radius, length)
	if not _barrels.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = radius
		outer.bottom_radius = radius * 1.12
		outer.height = length
		outer.radial_segments = 20
		outer.cap_top = false
		var inner := CylinderMesh.new()
		inner.top_radius = radius * 0.62
		inner.bottom_radius = radius * 0.62
		inner.height = minf(length, radius * 6)
		inner.radial_segments = 20
		inner.cap_top = false
		inner.cap_bottom = false
		inner.flip_faces = true
		_barrels[key] = [outer, inner]
	var meshes: Array = _barrels[key]
	k._add(mount, meshes[0], material, col, Vector3(0, length / 2, 0))
	var depth := minf(length, radius * 6)
	k._add(mount, meshes[1], "burnt", Color(0.018, 0.019, 0.018), Vector3(0, length - depth / 2, 0))
	k._cyl(mount, radius * 0.62, radius * 0.62, 0.004, Vector3(0, length - depth, 0), Vector3.ZERO, "burnt", null, 16, false)
	k._add(mount, _ring(radius * 0.62, radius * 1.02), "gunmetal", Color(0.29, 0.30, 0.28), Vector3(0, length, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	if sleeved:
		var span := length * 0.83
		for i in 3:
			var y := span * (i + 0.5) / 3
			k._cyl(mount, radius * 1.13, radius * 1.13, span / 3 - 0.025, Vector3(0, y, 0), Vector3.ZERO, material, col, 16)
			k._cyl(mount, radius * 1.19, radius * 1.19, 0.035, Vector3(0, span * (i + 1) / 3 - 0.035, 0), Vector3.ZERO, "gunmetal_w", null, 16, false)
			# Longitudinal closure strip and clamp latch on the sleeve.
			k._box(mount, Vector3(radius * 0.23, span / 3 - 0.035, 0.012), Vector3(0, y, radius * 1.13), material, col, Vector3.ZERO, false)
			k._box(mount, Vector3(radius * 0.48, 0.045, 0.024), Vector3(0, span * (i + 1) / 3 - 0.035, radius * 1.18), "gunmetal_w", null, Vector3.ZERO, false)
	k._fold(mount)


static var _barrels := {}
static var _fitting_rings := {}

## Small fittings need fewer segments than road-wheel beads.
static func _ring(inner: float, outer: float) -> TorusMesh:
	var key := Vector2(inner, outer)
	if not _fitting_rings.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 20
		mesh.ring_segments = 6
		_fitting_rings[key] = mesh
	return _fitting_rings[key]


static var _spring_mesh: ArrayMesh

static func _antenna_spring() -> ArrayMesh:
	if _spring_mesh:
		return _spring_mesh
	var rings: Array = []
	for i in 73:
		var angle := TAU * 6 * i / 72.0
		var center := Vector3(cos(angle) * 0.023, 0.144 * i / 72.0, sin(angle) * 0.023)
		var basis := VehicleFrames.aim(Vector3(-sin(angle) * 0.023, 0.144 / (TAU * 6), cos(angle) * 0.023))
		var ring := PackedVector3Array()
		for j in 6:
			var around := TAU * j / 6.0
			ring.append(center + basis * Vector3(cos(around) * 0.004, 0, sin(around) * 0.004))
		rings.append(ring)
	_spring_mesh = VehicleModels.solid(rings, "vehicle_antenna_spring")
	return _spring_mesh


static var _mirror_faces := {}

## Slight convexity catches a range of environment reflections across the face.
static func _mirror_glass(size: Vector2) -> ArrayMesh:
	if _mirror_faces.has(size):
		return _mirror_faces[size]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for y in 8:
		for x in 6:
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var uv := Vector2(float(x + offset.x) / 6, float(y + offset.y) / 8)
				var xy := uv * 2 - Vector2.ONE
				surface.set_uv(uv)
				surface.add_vertex(Vector3(xy.x * size.x / 2, xy.y * size.y / 2, minf(size.x, size.y) * 0.035 * (1 - xy.x * xy.x) * (1 - xy.y * xy.y)))
	surface.generate_normals()
	var mesh := surface.commit()
	_mirror_faces[size] = mesh
	return mesh


## Pressed 20-litre fuel can. Center is the body center, broad faces along X.
## Rotate the complete assembly so the cap, handle and ribs stay attached.
static func jerrycan(k: VehicleModels, parent: Node3D, center: Vector3, col: Color, rotation := Vector3.ZERO, width := 0.17) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._box(mount, Vector3(width, 0.46, 0.34), Vector3.ZERO, "paint", col)
	# The pressed seam and X ribs stiffen the broad walls of the can.
	for side in [-1.0, 1.0]:
		var x: float = side * (width / 2 + 0.003)
		for z in [-1.0, 1.0]:
			VehicleFrames.tube(k, mount, Vector3(x, -0.16, z * 0.11), Vector3(x, 0.16, -z * 0.11), 0.008, "paint", col, 6, false)
		VehicleFrames.path(k, mount, [Vector3(x, -0.20, -0.14), Vector3(x, 0.20, -0.14), Vector3(x, 0.20, 0.14), Vector3(x, -0.20, 0.14), Vector3(x, -0.20, -0.14)], 0.005, "paint", col.darkened(0.12), 6)
	# Three parallel carrying bars leave real finger openings above the shoulder.
	for x in [-width * 0.27, 0.0, width * 0.27]:
		VehicleFrames.path(k, mount, [Vector3(x, 0.225, -0.025), Vector3(x, 0.27, 0.005), Vector3(x, 0.27, 0.105), Vector3(x, 0.225, 0.135)], 0.010, "paint", col, 6)
	k._cyl(mount, 0.035, 0.039, 0.018, Vector3(0, 0.24, -0.10), Vector3.ZERO, "gunmetal_w", null, 12, false)
	k._box(mount, Vector3(0.018, 0.012, 0.07), Vector3(0, 0.255, -0.10), "gunmetal_w", null, Vector3.ZERO, false)
	k._fold(mount)


## Sealed ammunition can; feed boxes and wooden ammunition crates are separate.
static func ammo_can(k: VehicleModels, parent: Node3D, center: Vector3, col: Color, rotation := Vector3.ZERO, size := Vector3(0.16, 0.2, 0.3)) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	mount.scale = size / Vector3(0.16, 0.2, 0.3)
	k._box(mount, Vector3(0.16, 0.18, 0.3), Vector3(0, -0.01, 0), "paint", col)
	k._box(mount, Vector3(0.162, 0.008, 0.302), Vector3(0, 0.078, 0), "rubber", null, Vector3.ZERO, false)
	k._box(mount, Vector3(0.17, 0.025, 0.31), Vector3(0, 0.095, 0), "paint", col)
	VehicleFrames.path(k, mount, [Vector3(0, 0.108, -0.065), Vector3(0, 0.133, -0.065), Vector3(0, 0.133, 0.065), Vector3(0, 0.108, 0.065)], 0.008, "gunmetal_w", null, 6)
	for z in [-0.157, 0.157]:
		k._box(mount, Vector3(0.04, 0.055, 0.012), Vector3(0, 0.065, z), "gunmetal_w", null, Vector3.ZERO, false)
		VehicleFrames.tube(k, mount, Vector3(-0.028, 0.089, z), Vector3(0.028, 0.089, z), 0.007, "gunmetal_w", null, 6, false)
	for side: float in [-1.0, 1.0]:
		for z in [-0.09, 0.09]:
			k._box(mount, Vector3(0.006, 0.115, 0.012), Vector3(side * 0.081, -0.015, z), "paint", col, Vector3.ZERO, false)
	k._fold(mount)


## Forged recovery shackle, with an open bow and a transverse removable pin.
static func tow_shackle(k: VehicleModels, parent: Node3D, center: Vector3, facing := -1.0, size := Vector3(0.14, 0.14, 0.12), radius := 0.065) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation.y = PI if facing < 0 else 0.0
	k._box(mount, size, Vector3.ZERO, "gunmetal_w")
	var z := size.z / 2 + radius * 0.85
	k._box(mount, Vector3(radius * 0.8, radius * 0.7, radius * 1.15), Vector3(0, -0.02, size.z / 2 + radius * 0.42), "gunmetal_w")
	var points: Array = []
	for i in 13:
		var a := PI + PI * i / 12.0
		points.append(Vector3(cos(a) * radius, sin(a) * radius - 0.02, z))
	VehicleFrames.path(k, mount, points, radius * 0.23, "gunmetal_w", null, 8)
	VehicleFrames.tube(k, mount, Vector3(-radius * 1.35, -0.02, z), Vector3(radius * 1.35, -0.02, z), radius * 0.24, "steel", null, 10)
	k._box(mount, Vector3(0.012, radius * 0.65, radius * 0.42), Vector3(radius * 1.4, -0.02, z), "gunmetal_w", null, Vector3.ZERO, false)
	k._fold(mount)
