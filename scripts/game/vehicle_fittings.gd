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
	# The seat's back lies inside the housing; sixteen sides keep the sliver of
	# it that shows round the bezel round.
	VehicleFrames.cyl(k, mount, radius * 1.08, radius * 1.08, radius * 0.16, Vector3.ZERO, Vector3.ZERO, "rubber", null, 16, false, 1)
	k._add(mount, _ring(radius * 0.96, radius * 1.09), "gunmetal_w", null, Vector3(0, radius * 0.19, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
	if not k.burnt:
		k._add(mount, _headlamp_reflector(), "headlamp", Color(0.76, 0.78, 0.73), Vector3.ZERO, Vector3.ZERO, Vector3.ONE * radius, false)
		# Sparse moulded ribs approximate a sealed-beam lens without transparent
		# sorting or another light/shadow pass. All detail joins the hull bake.
		# Two segments per rib follow the dome closely enough at lamp size, and
		# keep the insert cheap: it repeats on hundreds of lamps across the roster.
		# A rib is a millimetre or two thick: four sides and open ends are plenty.
		for i in range(-3, 4):
			var x := i * 0.23
			var half_span := sqrt(0.88 * 0.88 - x * x)
			for j in 2:
				var z0 := lerpf(-half_span, half_span, j / 2.0)
				var z1 := lerpf(-half_span, half_span, (j + 1) / 2.0)
				var a := Vector3(x, 0.22 + 0.08 * (1.0 - x * x - z0 * z0), z0) * radius
				var b := Vector3(x, 0.22 + 0.08 * (1.0 - x * x - z1 * z1), z1) * radius
				VehicleFrames.tube(k, mount, a, b, radius * 0.018, "headlamp", Color(0.52, 0.58, 0.56), 4, false, -1.0, 0)
		# The bulb shield's underside faces into the reflector, out of sight.
		VehicleFrames.cyl(k, mount, radius * 0.14, radius * 0.18, radius * 0.08, Vector3(0, radius * 0.17, 0), Vector3.ZERO, "gunmetal", Color(0.28, 0.29, 0.27), 10, false, 1)
	k._fold(mount)


static var _lamp_reflector: ArrayMesh

## Unit dish shared by every lamp size, facing local +Y. Its rim lies under
## the bezel, so sixteen segments round it.
static func _headlamp_reflector() -> ArrayMesh:
	if _lamp_reflector:
		return _lamp_reflector
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 4:
		for segment in 16:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var r := 0.12 + (ring + corner.x) * 0.21
				var angle := TAU * (segment + corner.y) / 16.0
				surface.add_vertex(Vector3(cos(angle) * r, 0.09 + 0.13 * r * r, sin(angle) * r))
	surface.generate_normals()
	_lamp_reflector = surface.commit()
	return _lamp_reflector


## Local XY grille, +Z outward. Fins stand in front of a recessed radiator core.
## `center` is the grille's face: the dark core lies 2.5 cm behind it and the
## frame and slats stand a centimetre or two in front. Set into an opening, the
## centre goes on the opening's plane; on a solid face with no opening, stand
## the centre about 3 cm proud of the face so the core isn't buried in it.
static func grille(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, material: String, col = null, count := 8, vertical := false) -> void:
	var basis := Basis.from_euler(rotation)
	var surface := VehicleSurface.plane(center, basis.x, basis.y)
	var x := size.x * 0.5
	var y := size.y * 0.5
	var cut := minf(0.035, minf(x, y) * 0.12)
	var outline := PackedVector2Array([Vector2(-x + cut, -y), Vector2(x - cut, -y), Vector2(x, -y + cut), Vector2(x, y - cut), Vector2(x - cut, y), Vector2(-x + cut, y), Vector2(-x, y - cut), Vector2(-x, -y + cut)])
	vent(k, parent, surface, outline, material, col, count, vertical)


## Outline-aware grille in a metre-scaled surface domain. Fins and radiator
## channels are clipped to the inset; tapered vents need no bespoke slat loops.
## Placed as grille is: the surface is the vent's face, its core 2.5 cm below
## it, so on a solid face with no opening lift the surface about 3 cm proud.
static func vent(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, material: String, col = null, count := 8, vertical := false) -> void:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for q in outline:
		bounds = bounds.expand(q)
	var rim := minf(0.025, minf(bounds.size.x, bounds.size.y) * 0.065)
	var inset := Geometry2D.offset_polygon(outline, -rim * 1.5)
	assert(not inset.is_empty())
	k._add(parent, surface.patch(outline, -0.025, 0.012), "plain_dark", Color(0.025, 0.028, 0.026), Vector3.ZERO)
	VehicleBody.boundary(k, parent, surface, outline, 0.0, rim * 0.7, true, 0, material, col)
	var axis := 0 if vertical else 1
	var pitch := bounds.size[axis] / maxf(count, 1)
	# Fine channels remain behind the protective slats, at a separate depth:
	# strips of sheet seen only face on through the slats, so no edges or backs.
	_slats(k, parent, surface, inset[0], bounds, 0, clampi(ceili(bounds.size.x / 0.055), 6, 40), 0.14, -0.012, 0.0, "gunmetal", Color(0.14, 0.15, 0.14))
	_slats(k, parent, surface, inset[0], bounds, axis, count, 0.42, 0.012, minf(0.012, pitch * 0.15), material, col)

static func _slats(k: VehicleModels, parent: Node3D, surface: VehicleSurface, inset: PackedVector2Array, bounds: Rect2, axis: int, count: int, coverage: float, lift: float, depth: float, material: String, col) -> void:
	var pitch := bounds.size[axis] / maxf(count, 1)
	for i in count:
		var lo := bounds.position[axis] + pitch * (i + (1.0 - coverage) * 0.5)
		var hi := lo + pitch * coverage
		var strip := PackedVector2Array([Vector2(lo, bounds.position.y), Vector2(hi, bounds.position.y), Vector2(hi, bounds.end.y), Vector2(lo, bounds.end.y)]) if axis == 0 else PackedVector2Array([Vector2(bounds.position.x, lo), Vector2(bounds.end.x, lo), Vector2(bounds.end.x, hi), Vector2(bounds.position.x, hi)])
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(inset, strip):
			var angled := VehicleSurface.new(func(q: Vector2) -> Vector3: return surface.point(q, lift + (q[axis] - lo) * 0.25), surface.outward)
			k._add(parent, angled.patch(clipped, 0.0, depth), material, col, Vector3.ZERO)


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
	# Each rib is one moulded bead following the kick.
	for side in [-1.0, 1.0]:
		var rib := []
		for i in 5:
			var t := float(i) / 4
			rib.append(Vector3(side * size.x * 0.36, size.y * (0.5 - t), t * t * 0.045 + 0.016))
		VehicleFrames.path(k, mount, rib, 0.006, "rubber", Color(0.10, 0.11, 0.10), 5, false)
	k._fold(mount)


## Hollow exhaust on an authored axis. The dark sleeve sits behind the rolled
## lip; it is not a black disc pasted onto the end of a closed cylinder.
## Unlike the other fittings it registers its mouth with `k.exhaust_at`, so
## the running engine's heat haze and smoke leave it: a pipe that shouldn't
## breathe (a dead stub, a ship's outlet that never had any) stays authored.
static func exhaust(k: VehicleModels, parent: Node3D, base: Vector3, direction: Vector3, length: float, radius: float, shielded := true) -> void:
	k.exhaust_at(parent, base + direction.normalized() * length, direction)
	var mount := k._pivot(parent, base)
	mount.basis = VehicleFrames.aim(direction)
	var key := Vector2(radius, length)
	# Sixteen sides keep a stack's silhouette round; a thinner pipe needs twelve.
	# Straight walls need no rings between their ends, and the sooted bore's
	# floor is the liner's own end, turned to face up the pipe.
	var sides := 16 if radius >= 0.04 else 12
	if not _pipes.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = radius
		outer.bottom_radius = radius
		outer.height = length
		outer.radial_segments = sides
		outer.rings = 0
		outer.cap_top = false
		var inner := CylinderMesh.new()
		inner.top_radius = radius * 0.80
		inner.bottom_radius = radius * 0.80
		inner.height = minf(length, radius * 4)
		inner.radial_segments = sides
		inner.rings = 0
		inner.cap_top = false
		inner.flip_faces = true
		_pipes[key] = [outer, inner]
	var pipes: Array = _pipes[key]
	k._add(mount, pipes[0], "gunmetal", Color(0.24, 0.23, 0.21), Vector3(0, length / 2, 0))
	var depth := minf(length, radius * 4)
	k._add(mount, pipes[1], "burnt", Color(0.025, 0.025, 0.023), Vector3(0, length - depth / 2, 0))
	k._add(mount, _ring(radius * 0.8, radius * 1.03), "gunmetal", Color(0.28, 0.24, 0.19), Vector3(0, length, 0))
	if shielded:
		# Stand-off shield and clamps sit below the hot, uncovered outlet.
		var shield := [Vector2(radius * 1.34, length * 0.28), Vector2(radius * 1.4, length * 0.28), Vector2(radius * 1.4, length * 0.58), Vector2(radius * 1.34, length * 0.58)]
		k._add(mount, VehicleProfiles.revolve(shield, sides), "steel", Color(0.28, 0.29, 0.26), Vector3.ZERO, Vector3(-PI / 2, 0, 0))
		for t in [0.28, 0.58]:
			k._box(mount, Vector3(radius * 0.5, radius * 0.35, radius * 0.5), Vector3(0, length * t, radius * 1.40), "metal_dark")
			VehicleBody.fastener(k, mount, Vector3(0, length * t, radius * 1.67), Vector3.BACK, radius * 0.15)
			k._add(mount, _ring(radius * 1.35, radius * 1.55), "gunmetal", Color(0.18, 0.19, 0.17), Vector3(0, length * t, 0), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	k._fold(mount)


## A fixed whip with a rubber boot, spring base and tapered flexible rod.
## The fixed boot stays baked into the hull; the spring and rod share one pivot,
## registered in k.antennas so it sways (VehicleModels.update_antennas sets
## that pivot's rotation every frame, so the rod's lean lives in its geometry).
## `base` is the surface point; with the defaults the rod rises `height` (its
## top 0.12 m higher, over the boot and spring) with a slight trailing bow.
## `tip` (relative to base) leans the rod to end there instead, and `radius`,
## `mat` and `col` dress the rod (its foot radius; it tapers to 0.385 of it).
## style "whip" is the static whip of aircraft and boats: no boot, spring or
## sway, a mounting boss (or `foot`, the old insulator cylinder: top radius,
## bottom radius, height, white glass fibre) standing on the surface, or hanging
## under it when the tip is below the base, then a tapered rod from base to
## base + tip (straight up `height` without a tip) with a ferrule at its root
## and a ball at its end. Nothing is registered for a static whip.
static func antenna(k: VehicleModels, parent: Node3D, base: Vector3, height: float, tip := Vector3.ZERO, radius := 0.013, mat := "gunmetal_w", col = null, style := "sprung", foot := Vector3.ZERO) -> void:
	if style == "whip":
		_static_whip(k, parent, base, tip if tip != Vector3.ZERO else Vector3(0, height, 0), radius, mat, col, foot)
		return
	var mount := k._pivot(parent, base)
	k._box(mount, Vector3(0.13, 0.025, 0.13), Vector3(0, 0.0125, 0), "gunmetal_w")
	for side in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * 0.045, 0.03, 0), Vector3.UP, 0.012)
	# The boot stands on its plate and the sleeve's foot inside the boot.
	VehicleFrames.cyl(k, mount, 0.034, 0.05, 0.09, Vector3(0, 0.065, 0), Vector3.ZERO, "rubber", null, 10, false, 1)
	var whip := k._pivot(mount, Vector3(0, 0.10, 0))
	if not k.burnt:
		k.antennas.append(whip)
	VehicleFrames.cyl(k, whip, 0.019, 0.019, 0.16, Vector3(0, 0.08, 0), Vector3.ZERO, "gunmetal_w", null, 8, false, 1)
	k._add(whip, _antenna_spring(), "gunmetal_w", Color(0.24, 0.25, 0.23), Vector3(0, 0.008, 0), Vector3.ZERO, Vector3.ONE, false)
	# A leaning rod keeps the same bow, across its own line toward the rear.
	# Its pieces meet end to end at one radius, so only the tip is capped (the
	# foot stands on the sleeve's top).
	var start := Vector3(0, 0.16, 0)
	var run := tip - Vector3(0, 0.10, 0) - start
	var bow := (Vector3.BACK - run.normalized() * run.normalized().dot(Vector3.BACK)).normalized() * run.length() * 0.035
	var scale := radius / 0.013
	for i in 5:
		var t0 := float(i) / 5
		var t1 := float(i + 1) / 5
		var a := Vector3(0, 0.16 + (height - 0.14) * t0, height * 0.035 * t0 * t0)
		var b := Vector3(0, 0.16 + (height - 0.14) * t1, height * 0.035 * t1 * t1)
		if tip != Vector3.ZERO:
			a = start + run * t0 + bow * t0 * t0
			b = start + run * t1 + bow * t1 * t1
		VehicleFrames.tube(k, whip, a, b, lerpf(0.013, 0.005, t0) * scale, mat, col, 6, false, lerpf(0.013, 0.005, t1) * scale, 1 if i == 4 else 0)
	if k.burnt:
		k._fold(whip)
	k._fold(mount)


## The static whip of an aircraft or boat (see antenna). `tip` is relative to
## `base`; the fitting stands on the surface toward the side the tip is on.
static func _static_whip(k: VehicleModels, parent: Node3D, base: Vector3, tip: Vector3, radius: float, mat: String, col, foot: Vector3) -> void:
	var up := Vector3.UP if tip.y >= 0.0 else Vector3.DOWN
	var mount := k._pivot(parent, base)
	var root := Vector3.ZERO
	# The fitting's foot (the cylinder's bottom, either way up) is on the
	# surface; the rod's foot is in the ferrule and its end in the ball.
	if foot.z > 0.0:
		# The insulator's top radius goes to the end away from the surface.
		VehicleFrames.cyl(k, mount, foot.x, foot.y, foot.z, up * foot.z * 0.5, Vector3.ZERO if up.y > 0.0 else Vector3(PI, 0, 0), "plain", Color(0.84, 0.84, 0.81), 8, false, 1)
		root = up * foot.z * 0.94
	else:
		VehicleFrames.cyl(k, mount, radius * 1.6, radius * 2.3, radius * 3.0, up * radius * 1.5, Vector3.ZERO if up.y > 0.0 else Vector3(PI, 0, 0), mat, col, 8, false, 1)
		root = up * radius * 2.6
	var axis := (tip - root).normalized()
	VehicleFrames.tube(k, mount, root - axis * radius * 0.5, root + axis * radius * 4.0, radius * 1.45, "metal_dark", null, 6, false, -1.0, 1)
	VehicleFrames.tube(k, mount, root, tip, radius, mat, col, 6, false, radius * 0.45, 0)
	k._add(mount, Res.sphere(radius * 0.8, 6), mat, col, tip, Vector3.ZERO, Vector3.ONE, false)
	k._fold(mount)


## Rear-facing mirror glass (+Z), in a moulded housing on jointed arms.
## Anchors are parent-local; the family owns the door attachment positions.
static func mirror(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, yaw: float, anchors: Array, shell_mat := "plain_dark", shell_col: Variant = Color(0.11, 0.12, 0.11)) -> void:
	var facing := Basis(Vector3.UP, yaw)
	for i in anchors.size():
		var y := (0.28 if i == 0 else -0.28) * size.y
		var end := center + facing * Vector3(0, y, -0.06)
		var local_anchor: Vector3 = facing.inverse() * (anchors[i] - center)
		var side := 1.0 if local_anchor.x >= 0 else -1.0
		# Route around the housing edge before turning onto its back. A straight
		# diagonal from the door can otherwise pass through the reflective face.
		var elbow := center + facing * Vector3(side * (size.x / 2 + 0.045), y, -0.06)
		var anchor: Vector3 = anchors[i]
		var axis: Vector3 = (elbow - anchor).normalized()
		# The arm starts inside its boss (when the boss is the thicker) and
		# ends in the ball joint on the housing's back.
		var boss := minf(size.x * 0.16, 0.038)
		VehicleFrames.tube(k, parent, anchor - axis * 0.008, anchor + axis * 0.018, boss, "gunmetal_w", null, 8, false)
		VehicleFrames.path(k, parent, [anchors[i], elbow, end], 0.018, "gunmetal_w", null, 8, true, 0 if boss > 0.019 else 2)
		k._add(parent, Res.sphere(0.027, 8), "gunmetal_w", null, end)
	var mount := k._pivot(parent, center)
	mount.rotation.y = yaw
	# The housing defaults to black moulding; cars pass their body paint.
	k._add(mount, BevelMesh.make(Vector3(size.x, size.y, 0.06), minf(0.018, size.x * 0.06)), shell_mat, shell_col, Vector3.ZERO)
	k._box(mount, Vector3(size.x - 0.018, size.y - 0.018, 0.009), Vector3(0, 0, 0.033), "rubber", Color(0.06, 0.065, 0.06), Vector3.ZERO, false)
	k._add(mount, _mirror_glass(size - Vector2(0.033, 0.033)), "mirror", Color(0.78, 0.82, 0.84), Vector3(0, 0, 0.042), Vector3.ZERO, Vector3.ONE, false)
	# A rib on the back stiffens the shell around the arm mounting points.
	k._box(mount, Vector3(0.025, size.y * 0.7, 0.014), Vector3(0, 0, -0.035), shell_mat, (shell_col as Color).lightened(0.04) if shell_col is Color else null, Vector3.ZERO, false)
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
	# The tube keeps twenty sides: its silhouette is what the camera follows.
	# Its taper is straight, so no rings between its ends; the sooted bore's
	# floor is the liner's own end, turned to face the muzzle.
	if not _barrels.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = radius
		outer.bottom_radius = radius * 1.12
		outer.height = length
		outer.radial_segments = 20
		outer.rings = 0
		outer.cap_top = false
		var inner := CylinderMesh.new()
		inner.top_radius = radius * 0.62
		inner.bottom_radius = radius * 0.62
		inner.height = minf(length, radius * 6)
		inner.radial_segments = 20
		inner.rings = 0
		inner.cap_top = false
		inner.flip_faces = true
		_barrels[key] = [outer, inner]
	var meshes: Array = _barrels[key]
	k._add(mount, meshes[0], material, col, Vector3(0, length / 2, 0))
	var depth := minf(length, radius * 6)
	k._add(mount, meshes[1], "burnt", Color(0.018, 0.019, 0.018), Vector3(0, length - depth / 2, 0))
	k._add(mount, _ring(radius * 0.62, radius * 1.02, 20), "gunmetal", Color(0.29, 0.30, 0.28), Vector3(0, length, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	if sleeved:
		var span := length * 0.83
		for i in 3:
			var y := span * (i + 0.5) / 3
			VehicleFrames.cyl(k, mount, radius * 1.13, radius * 1.13, span / 3 - 0.025, Vector3(0, y, 0), Vector3.ZERO, material, col, 16)
			VehicleFrames.cyl(k, mount, radius * 1.19, radius * 1.19, 0.035, Vector3(0, span * (i + 1) / 3 - 0.035, 0), Vector3.ZERO, "gunmetal_w", null, 16, false)
			# Longitudinal closure strip and clamp latch on the sleeve.
			k._box(mount, Vector3(radius * 0.23, span / 3 - 0.035, 0.012), Vector3(0, y, radius * 1.13), material, col, Vector3.ZERO, false)
			k._box(mount, Vector3(radius * 0.48, 0.045, 0.024), Vector3(0, span * (i + 1) / 3 - 0.035, radius * 1.18), "gunmetal_w", null, Vector3.ZERO, false)
	k._fold(mount)


static var _barrels := {}
static var _fitting_rings := {}

## Small fittings need fewer segments than road-wheel beads, and a small ring
## fewer than a large one: twelve round a ring whose outer radius is under 3
## cm, sixteen under 12 cm, twenty beyond (as every ring once had); `rings`
## sets the count instead (a gun's muzzle matches its tube). A band under 2 cm
## thick is four-sided: mostly scaled flat, it reads as a rolled edge.
static func _ring(inner: float, outer: float, rings := 0) -> TorusMesh:
	var count := rings if rings > 0 else (12 if outer < 0.03 else (16 if outer < 0.12 else 20))
	var key := Vector3(inner, outer, count)
	if not _fitting_rings.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = count
		mesh.ring_segments = 4 if outer - inner < 0.02 else 6
		_fitting_rings[key] = mesh
	return _fitting_rings[key]


static var _spring_mesh: ArrayMesh

## Six turns of 4 mm wire round a 23 mm coil. Eight stations a turn keep the
## coil round at its 5 cm width, and four sides are plenty for a wire that
## thin; its inner side lies against the sleeve.
static func _antenna_spring() -> ArrayMesh:
	if _spring_mesh:
		return _spring_mesh
	var rings: Array = []
	for i in 49:
		var angle := TAU * 6 * i / 48.0
		var center := Vector3(cos(angle) * 0.023, 0.144 * i / 48.0, sin(angle) * 0.023)
		var basis := VehicleFrames.aim(Vector3(-sin(angle) * 0.023, 0.144 / (TAU * 6), cos(angle) * 0.023))
		var ring := PackedVector3Array()
		for j in 4:
			var around := TAU * j / 4.0
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
static func jerrycan(k: VehicleModels, parent: Node3D, center: Vector3, col: Color, rotation := Vector3.ZERO, width := 0.17, size := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	if size != Vector3.ZERO:
		assert(size.x > 0 and size.y > 0 and size.z > 0)
		mount.scale = size / Vector3(width, 0.46, 0.34)
	var half_width := width * 0.5
	var cut := minf(width * 0.08, 0.012)
	var outline := PackedVector2Array([Vector2(-half_width + cut, -0.17), Vector2(half_width - cut, -0.17), Vector2(half_width, -0.17 + cut), Vector2(half_width, 0.17 - cut), Vector2(half_width - cut, 0.17), Vector2(-half_width + cut, 0.17), Vector2(-half_width, 0.17 - cut), Vector2(-half_width, -0.17 + cut)])
	var shoulder: Array = []
	for station: Vector3 in [Vector3(-0.23, 0.94, 0.97), Vector3(-0.215, 1, 1), Vector3(0.16, 1, 1), Vector3(0.23, 0.76, 0.85)]:
		var ring := PackedVector2Array()
		for q in outline:
			ring.append(q * Vector2(station.y, station.z))
		shoulder.append(VehicleModels.ring_y(ring, station.x))
	k._add(mount, VehicleProfiles.loft(shoulder, 25), "paint", col, Vector3.ZERO)
	# The spout's neck rises out of the shoulder, the cap sits on the neck.
	VehicleFrames.cyl(k, mount, 0.034, 0.042, 0.028, Vector3(0, 0.231, -0.10), Vector3.ZERO, "paint", col, 12, false, 1)
	# The pressed seam and X ribs stiffen the broad walls of the can. The seam
	# is one closed bead (its corners need no balls at this size).
	for side in [-1.0, 1.0]:
		var x: float = side * (width / 2 + 0.003)
		for z in [-1.0, 1.0]:
			VehicleFrames.tube(k, mount, Vector3(x, -0.16, z * 0.11), Vector3(x, 0.14, -z * 0.11), 0.008, "paint", col, 6, false)
		VehicleFrames.path(k, mount, [Vector3(x, -0.20, -0.14), Vector3(x, 0.15, -0.14), Vector3(x, 0.15, 0.14), Vector3(x, -0.20, 0.14), Vector3(x, -0.20, -0.14)], 0.005, "paint", col.darkened(0.12), 6)
	# Three parallel carrying bars leave real finger openings above the shoulder;
	# their feet are welded into it.
	for x in [-width * 0.27, 0.0, width * 0.27]:
		VehicleFrames.path(k, mount, [Vector3(x, 0.225, -0.025), Vector3(x, 0.27, 0.005), Vector3(x, 0.27, 0.105), Vector3(x, 0.225, 0.135)], 0.010, "paint", col, 6, true, 0)
	VehicleFrames.cyl(k, mount, 0.035, 0.039, 0.018, Vector3(0, 0.24, -0.10), Vector3.ZERO, "gunmetal_w", null, 12, false, 1)
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
	# The carrying handle's feet are pinned into the lid.
	VehicleFrames.path(k, mount, [Vector3(0, 0.108, -0.065), Vector3(0, 0.133, -0.065), Vector3(0, 0.133, 0.065), Vector3(0, 0.108, 0.065)], 0.008, "gunmetal_w", null, 6, true, 0)
	for z in [-0.157, 0.157]:
		k._box(mount, Vector3(0.04, 0.055, 0.012), Vector3(0, 0.065, z), "gunmetal_w", null, Vector3.ZERO, false)
		VehicleFrames.tube(k, mount, Vector3(-0.028, 0.089, z), Vector3(0.028, 0.089, z), 0.007, "gunmetal_w", null, 6, false)
	for side: float in [-1.0, 1.0]:
		for z in [-0.09, 0.09]:
			k._box(mount, Vector3(0.006, 0.115, 0.012), Vector3(side * 0.081, -0.015, z), "paint", col, Vector3.ZERO, false)
	var seam := VehicleSurface.plane(Vector3(0, -0.085, 0), Vector3.RIGHT, Vector3.FORWARD)
	VehicleBody.boundary(k, mount, seam, PackedVector2Array([Vector2(-0.065, -0.15), Vector2(0.065, -0.15), Vector2(0.08, -0.135), Vector2(0.08, 0.135), Vector2(0.065, 0.15), Vector2(-0.065, 0.15), Vector2(-0.08, 0.135), Vector2(-0.08, -0.135)]), 0, 0.003, false, 0, "paint", col)
	VehicleDoors.hinge(k, mount, Vector3(0, 0.09, 0.15), Vector3.BACK, Vector3.RIGHT, 0.008, "paint", col)
	VehicleDoors.pull(k, mount, Vector3(0, 0.06, -0.164), Vector3.FORWARD, Vector3.UP, 0.035, 0.004)
	k._fold(mount)


## Forged recovery shackle, with an open bow and a transverse removable pin.
## `mat` and `col` dress the block, bow and keeper (a civilian truck's hooks
## are painted red); the pin stays bright steel.
static func tow_shackle(k: VehicleModels, parent: Node3D, center: Vector3, facing := -1.0, size := Vector3(0.14, 0.14, 0.12), radius := 0.065, mat := "gunmetal_w", col = null) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation.y = PI if facing < 0 else 0.0
	k._box(mount, size, Vector3.ZERO, mat, col)
	var z := size.z / 2 + radius * 0.85
	k._box(mount, Vector3(radius * 0.8, radius * 0.7, radius * 1.15), Vector3(0, -0.02, size.z / 2 + radius * 0.42), mat, col)
	# The bow is one bent bar: its pieces run on into each other round the
	# curve (no joint balls), and both its ends lie inside the pin.
	var points: Array = []
	for i in 13:
		var a := PI + PI * i / 12.0
		points.append(Vector3(cos(a) * radius, sin(a) * radius - 0.02, z))
	VehicleFrames.path(k, mount, points, radius * 0.23, mat, col, 8, true, 0)
	VehicleFrames.tube(k, mount, Vector3(-radius * 1.35, -0.02, z), Vector3(radius * 1.35, -0.02, z), radius * 0.24, "steel", null, 10)
	k._box(mount, Vector3(0.012, radius * 0.65, radius * 0.42), Vector3(radius * 1.4, -0.02, z), mat, col, Vector3.ZERO, false)
	k._fold(mount)


## One smoke discharger. Families own the bank's layout, pitch and count.
## Built as an unsleeved barrel is (a tapered tube, its sooted bore and rolled
## muzzle lip), but with twelve sides: a discharger is a hand's width across
## and comes in banks of four to eight.
static func smoke_tube(k: VehicleModels, parent: Node3D, center: Vector3, rotation: Vector3, radius: float, length: float) -> void:
	var axis := Basis.from_euler(rotation).y
	var mount := k._pivot(parent, center - axis * length / 2)
	mount.basis = VehicleFrames.aim(axis)
	var key := Vector2(radius, length)
	var depth := minf(length, radius * 6)
	if not _smoke_tubes.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = radius
		outer.bottom_radius = radius * 1.12
		outer.height = length
		outer.radial_segments = 12
		outer.rings = 0
		outer.cap_top = false
		var inner := CylinderMesh.new()
		inner.top_radius = radius * 0.62
		inner.bottom_radius = radius * 0.62
		inner.height = depth
		inner.radial_segments = 12
		inner.rings = 0
		inner.cap_top = false
		inner.flip_faces = true
		_smoke_tubes[key] = [outer, inner]
	var meshes: Array = _smoke_tubes[key]
	k._add(mount, meshes[0], "gunmetal_w", null, Vector3(0, length / 2, 0))
	k._add(mount, meshes[1], "burnt", Color(0.018, 0.019, 0.018), Vector3(0, length - depth / 2, 0))
	k._add(mount, _ring(radius * 0.62, radius * 1.02), "gunmetal", Color(0.29, 0.30, 0.28), Vector3(0, length, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	k._fold(mount)
	VehicleFrames.cyl(k, parent, radius * 1.15, radius * 1.15, length * 0.16, center - axis * length * 0.30, rotation, "gunmetal_w", null, 12, false)


static var _smoke_tubes := {}


## A bank of smoke-grenade dischargers on its bracket. `center`, `size` and
## `rotation` are the old bracket box in the parent's axes. `tubes` holds one
## Transform3D per discharger, also in the parent's axes: origin the tube's
## centre and basis the one its old rotation made (Basis.from_euler of what was
## passed to smoke_tube: the tube along local Y, muzzle toward +Y), so every
## family keeps its own layout, pitch and count; `radius` and `length` are the
## tubes'. The bracket is a cast block on a bolted base flange. A junction box
## on the bracket's back (the face the tubes fire away from) sends a firing lead
## to each tube's breech, and its cable runs down to the deck.
static func smoke_bank(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation: Vector3, tubes: Array, radius: float, length: float) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var flange := minf(0.02, size.y * 0.25)
	k._box(mount, Vector3(size.x, flange, size.z), Vector3(0, -hy + flange * 0.5, 0), "gunmetal_w")
	k._add(mount, BevelMesh.make(Vector3(size.x * 0.9, size.y - flange, size.z * 0.86), minf(0.012, minf(size.y, size.z) * 0.12)), "gunmetal_w", null, Vector3(0, flange * 0.5, 0))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		VehicleBody.fastener(k, mount, Vector3(corner.x * hx * 0.96, -hy + flange + 0.002, corner.y * hz * 0.93), Vector3.UP, minf(0.008, minf(hx, hz) * 0.09))
	# The back face: the bracket side facing away from the tubes' muzzles.
	var fire := Vector3.ZERO
	var inverse := mount.transform.affine_inverse()
	for tube: Transform3D in tubes:
		fire += inverse.basis * tube.basis.y
	var back := Vector3.BACK
	if absf(fire.x) > absf(fire.z) and absf(fire.x) > 0.001:
		back = Vector3(-signf(fire.x), 0, 0)
	elif absf(fire.z) > 0.001:
		back = Vector3(0, 0, -signf(fire.z))
	var depth := minf(0.045, maxf(hx, hz) * 0.5)
	var face := absf(back.dot(Vector3(hx, 0, hz)))
	var across := Vector3(-back.z, 0, back.x)
	var jb := Vector3(minf(0.09, absf(across.dot(size)) * 0.5), minf(0.07, size.y * 0.8), depth)
	var at := back * (face + depth * 0.5) + Vector3(0, hy - jb.y * 0.5, 0)
	k._add(mount, BevelMesh.make(Vector3(jb.x, jb.y, jb.z) if back.x == 0.0 else Vector3(jb.z, jb.y, jb.x), minf(0.006, jb.z * 0.15)), "gunmetal_w", null, at)
	VehicleBody.fastener(k, mount, at + back * (depth * 0.5 + 0.002), back, minf(0.008, jb.y * 0.12))
	# Firing leads from the box's top to each breech, and the feed to the deck.
	# A lead's ends lie on the box's top and inside its tube; the feed's foot
	# is on the flange.
	var port := at + Vector3(0, jb.y * 0.5, 0)
	for tube: Transform3D in tubes:
		var breech: Vector3 = inverse * (tube.origin - tube.basis.y * length * 0.38)
		VehicleFrames.tube(k, mount, port, breech, minf(0.005, radius * 0.12), "rubber", null, 4, false, -1.0, 0)
	var low := at + back * depth * 0.5 + Vector3(0, -jb.y * 0.5, 0)
	VehicleFrames.tube(k, mount, low + Vector3(0, jb.y * 0.3, 0), Vector3(low.x, -hy + 0.008, low.z), 0.008, "rubber", null, 6, false, -1.0, 2)
	k._fold(mount)
	for tube: Transform3D in tubes:
		smoke_tube(k, parent, tube.origin, tube.basis.get_euler(), radius, length)


## Armoured periscope head, local -Z outward. Size describes its housing.
static func periscope(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._box(mount, size, Vector3.ZERO, "gunmetal_w")
	var face := -size.z / 2
	k._box(mount, Vector3(size.x * 0.86, size.y * 0.72, 0.008), Vector3(0, 0, face - 0.003), "rubber", null, Vector3.ZERO, false)
	if not k.burnt:
		k._box(mount, Vector3(size.x * 0.73, size.y * 0.52, 0.006), Vector3(0, 0, face - 0.008), "glass", Color(0.18, 0.30, 0.27), Vector3.ZERO, false)
	# The overhanging lip shields the glass without becoming another window.
	k._box(mount, Vector3(size.x * 1.04, size.y * 0.12, size.z * 0.65), Vector3(0, size.y * 0.48, face * 0.6), "gunmetal_w", null, Vector3.ZERO, false)
	for side: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * size.x * 0.44, 0, face - 0.009), Vector3.FORWARD, minf(size.x, size.y) * 0.055)
	k._fold(mount)


## Closed round hatch; center is the lid center, not the deck surface.
## Cupola pedestals, sights and open/rectangular lids stay with the family.
static func hatch(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, material: String, col = null, hinge_side := 1.0, thickness := 0.05) -> void:
	var mount := k._pivot(parent, center)
	# Coaming, seal and lid stack on the deck: only their tops can show.
	VehicleFrames.cyl(k, mount, radius + 0.03, radius + 0.04, 0.035, Vector3(0, -thickness / 2 - 0.025, 0), Vector3.ZERO, material, col, 24, true, 1)
	VehicleFrames.cyl(k, mount, radius + 0.008, radius + 0.008, 0.012, Vector3(0, -thickness / 2 - 0.006, 0), Vector3.ZERO, "rubber", null, 24, false, 1)
	VehicleFrames.cyl(k, mount, radius - 0.02, radius, thickness, Vector3.ZERO, Vector3.ZERO, material, col, 24, true, 1)
	# Two hinge knuckles and their common pin, all attached to the lid's edge.
	var hz := hinge_side * radius * 0.94
	for x in [-0.07, 0.07]:
		k._box(mount, Vector3(0.06, 0.045, 0.09), Vector3(x, 0, hz), material, col)
	VehicleFrames.tube(k, mount, Vector3(-0.12, 0.018, hz), Vector3(0.12, 0.018, hz), 0.018, "gunmetal_w", null, 10, false)
	var y := thickness / 2
	# The grab handle's feet stand on the lid.
	VehicleFrames.path(k, mount, [Vector3(-0.065, y, -hinge_side * radius * 0.4), Vector3(-0.065, y + 0.035, -hinge_side * radius * 0.4), Vector3(0.065, y + 0.035, -hinge_side * radius * 0.4), Vector3(0.065, y, -hinge_side * radius * 0.4)], 0.009, "gunmetal_w", null, 6, true, 0)
	for side: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * radius * 0.7, y + 0.003, 0), Vector3.UP, 0.012)
	var ring := VehicleFittings._ring(radius * 0.70, radius * 0.74)
	k._add(mount, ring, material, col, Vector3(0, y + 0.003, 0), Vector3.ZERO, Vector3(1, 0.3, 1), false)
	var latch := Vector3(0, y + 0.01, -hinge_side * radius * 0.86)
	k._box(mount, Vector3(radius * 0.22, thickness * 0.45, radius * 0.24), latch, "metal_dark")
	VehicleBody.fastener(k, mount, latch + Vector3(0, thickness * 0.3, 0), Vector3.UP, minf(0.016, radius * 0.055))
	k._fold(mount)


## A ribbed coloured signal lens, local +Z outward, on a rubber seat.
static func signal_lens(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, col: Color, facing := 1.0) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation.y = PI if facing < 0 else 0.0
	k._box(mount, Vector3(size.x + 0.008, size.y + 0.008, 0.008), Vector3(0, 0, -0.004), "rubber", null, Vector3.ZERO, false)
	if not k.burnt:
		k._box(mount, Vector3(size.x, size.y, 0.012), Vector3(0, 0, 0.004), "signal_lens", col, Vector3.ZERO, false)
		for i in 5:
			k._box(mount, Vector3(size.x * 0.9, size.y * 0.045, 0.003), Vector3(0, size.y * (i - 2) * 0.17, 0.011), "signal_lens", col.lightened(0.05), Vector3.ZERO, false)
	k._fold(mount)


## Two-colour convoy tail cluster. The family supplies its original dimensions.
static func tail_cluster(k: VehicleModels, parent: Node3D, center: Vector3, size := Vector3(0.22, 0.12, 0.06), lens := Vector2(0.08, 0.07), spacing := 0.05, facing := 1.0) -> void:
	k._box(parent, size, center, "gunmetal_w")
	for side: float in [-1.0, 1.0]:
		var col := Color(0.45, 0.035, 0.025) if side < 0 else Color(0.62, 0.27, 0.025)
		signal_lens(k, parent, center + Vector3(side * spacing, 0, facing * (size.z / 2 + 0.005)), lens, col, facing)


## Welded lifting eye. Upright eyes have a clear transverse hole; deck rings
## may lie flat. Base is the contact surface, and yaw turns the whole fitting.
static func lifting_eye(k: VehicleModels, parent: Node3D, base: Vector3, yaw := 0.0, radius := 0.045, upright := true) -> void:
	var mount := k._pivot(parent, base)
	mount.rotation.y = yaw
	k._box(mount, Vector3(radius * 2.65, 0.025, radius * 1.8), Vector3(0, 0.0125, 0), "gunmetal_w", null, Vector3.ZERO, false)
	var height := radius + 0.015 if upright else 0.035
	k._add(mount, _ring(radius * 0.52, radius), "gunmetal_w", null, Vector3(0, height, 0), Vector3(0, 0, PI / 2) if upright else Vector3.ZERO, Vector3.ONE, false)
	for side: float in [-1.0, 1.0]:
		VehicleFrames.tube(k, mount, Vector3(side * radius * 0.4, 0.027, -radius * 0.65), Vector3(side * radius * 0.4, 0.027, radius * 0.65), 0.005, "steel", null, 6, false)
	k._fold(mount)


## Rectangular unlit headlight insert, local -Z outward. The original housing
## and guard remain authored by the vehicle; optics fit inside the old lens size.
static func rectangular_headlamp(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._box(mount, Vector3(size.x, size.y, 0.014), Vector3.ZERO, "rubber", null, Vector3.ZERO, false)
	if not k.burnt:
		k._box(mount, Vector3(size.x * 0.88, size.y * 0.82, 0.009), Vector3(0, 0, -0.009), "headlamp", Color(0.76, 0.78, 0.73), Vector3.ZERO, false)
		for i in 7:
			var x := (i - 3) * size.x * 0.115
			k._box(mount, Vector3(size.x * 0.025, size.y * 0.74, 0.004), Vector3(x, 0, -0.015), "headlamp", Color(0.52, 0.58, 0.56), Vector3.ZERO, false)
		k._box(mount, Vector3(size.x * 0.12, size.y * 0.14, 0.004), Vector3(0, 0, -0.017), "gunmetal", null, Vector3.ZERO, false)
	k._fold(mount)


## A vehicle lamp assembly: the housing, its lamp inserts, an optional amber
## indicator and an optional guard. `center` and `size` are the old housing:
## a box (x across, y up, z deep) or, with style "round", a drum along Z whose
## diameter is size.x at the lens face and size.y at the back (the old
## cylinder's radii doubled). `face` -1 shines along -Z, +1 along +Z;
## `rotation` turns the whole lamp about its centre (a raked nose, a lamp
## toed out), and `mat`/`col` dress the housing. The face is the housing's
## front plane. Each entry of `lamps` is a round sealed beam: a float radius at
## the face's centre, or a Vector3 (x, y, radius) offset across the face; or a
## Rect2 rectangular insert whose position is its centre on the face (as
## VehicleMounts.sight's windows) and size its lens; later inserts sit a few
## millimetres proud of earlier ones, so a projector can sit in a cluster lens.
## `indicator` is an amber lens the same way (zero size: none). `guard`:
## "cage" (VehicleMounts.light_guard, three bars), "rails" (its two side bows
## and top rail only), "bar" (one strap bent round the lens, bolted to the
## housing's top and bottom) or "cross" (a vertical and a horizontal strap).
## `guard_size` = (width, height, reach of its front from the housing centre);
## zero sizes it from the housing. Wrecks keep the housing and guard and lose
## the lenses, as headlamp and signal_lens do.
static func lamp_unit(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, face := -1.0, lamps: Array = [], indicator := Rect2(), guard := "", guard_size := Vector3.ZERO, style := "box", rotation := Vector3.ZERO, mat := "gunmetal_w", col = null) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var f := 1.0 if face > 0.0 else -1.0
	var drum_style := style == "round"
	var front := Vector3(0, 0, f * size.z * 0.5)
	var width := maxf(size.x, size.y) if drum_style else size.x
	var height := maxf(size.x, size.y) if drum_style else size.y
	# Half the housing's height at mid-depth, where a strap guard is bolted.
	var shoulder := (size.x + size.y) * 0.25 if drum_style else size.y * 0.5
	var drum := Vector3(PI / 2, 0, 0)
	if drum_style:
		var face_r := size.x * 0.5
		var back_r := size.y * 0.5
		# CylinderMesh's top end lies along +Z once turned onto the lamp's axis.
		VehicleFrames.cyl(k, mount, face_r if f > 0.0 else back_r, back_r if f > 0.0 else face_r, size.z, Vector3.ZERO, drum, mat, col, 16)
		k._add(mount, _ring(face_r * 0.9, face_r * 1.04), mat, col, front, drum, Vector3(1, 0.5, 1), false)
	else:
		k._box(mount, size, Vector3.ZERO, mat, col)
		# A thin bezel frames the face; the inserts sit inside it.
		var rim := minf(0.012, minf(size.x, size.y) * 0.08)
		var lip := front + Vector3(0, 0, f * 0.003)
		for side: float in [-1.0, 1.0]:
			k._box(mount, Vector3(size.x, rim, 0.006), lip + Vector3(0, side * (size.y - rim) * 0.5, 0), mat, col, Vector3.ZERO, false)
			k._box(mount, Vector3(rim, size.y - rim * 2, 0.006), lip + Vector3(side * (size.x - rim) * 0.5, 0, 0), mat, col, Vector3.ZERO, false)
	# The cable gland at the back takes the lamp's lead into the hull; its
	# near end is in the housing (the drum turn points its top to +Z).
	VehicleFrames.cyl(k, mount, minf(0.016, height * 0.1), minf(0.02, height * 0.12), 0.016, Vector3(0, -height * 0.15, -f * (size.z * 0.5 + 0.008)), drum, "rubber", null, 8, false, 1 if f < 0.0 else 2)
	var turn := Vector3(0, PI if f > 0.0 else 0.0, 0)
	for i in lamps.size():
		var lamp: Variant = lamps[i]
		if lamp is Rect2:
			var r: Rect2 = lamp
			rectangular_headlamp(k, mount, front + Vector3(r.position.x, r.position.y, f * (0.004 + i * 0.006)), r.size, turn)
		elif lamp is Vector3:
			var v: Vector3 = lamp
			headlamp(k, mount, front + Vector3(v.x, v.y, f * i * 0.006), v.z, Vector3(0, 0, f))
		else:
			headlamp(k, mount, front + Vector3(0, 0, f * i * 0.006), float(lamp), Vector3(0, 0, f))
	if indicator.size != Vector2.ZERO:
		signal_lens(k, mount, front + Vector3(indicator.position.x, indicator.position.y, 0), indicator.size, Color(0.62, 0.27, 0.025), f)
	var reach := guard_size
	match guard:
		"cage", "rails":
			if reach == Vector3.ZERO:
				reach = Vector3(width * 1.0385, height * 1.087, size.z)
			VehicleMounts.light_guard(k, mount, Vector3.ZERO, Vector2(reach.x, reach.y), reach.z, f, 3 if guard == "cage" else 0, 0.007 if guard == "cage" else 0.012)
		"bar", "cross":
			if reach == Vector3.ZERO:
				reach = Vector3(width * 1.15, height * 1.2, size.z * 0.5 + 0.04)
			var strap := clampf(reach.y * 0.05, 0.006, 0.0125)
			var top := maxf(shoulder, reach.y * 0.5 - strap)
			VehicleFrames.path(k, mount, [Vector3(0, shoulder, 0), Vector3(0, top, f * reach.z), Vector3(0, -top, f * reach.z), Vector3(0, -shoulder, 0)], strap, "gunmetal_w", null, 6)
			for end: float in [-1.0, 1.0]:
				VehicleBody.fastener(k, mount, Vector3(0, end * (shoulder + 0.003), 0), Vector3.UP * end, strap * 1.3)
			if guard == "cross":
				var flank := size.x * 0.5 if not drum_style else shoulder
				var side := maxf(flank, reach.x * 0.5 - strap)
				VehicleFrames.path(k, mount, [Vector3(flank, 0, 0), Vector3(side, 0, f * reach.z), Vector3(-side, 0, f * reach.z), Vector3(-flank, 0, 0)], strap, "gunmetal_w", null, 6)
				for end: float in [-1.0, 1.0]:
					VehicleBody.fastener(k, mount, Vector3(end * (flank + 0.003), 0, 0), Vector3.RIGHT * end, strap * 1.3)
	k._fold(mount)


## Static wiper, with a raised arm and a rubber blade seated on the pane.
## Explicit plane directions keep both ends fitted to raked windscreens.
static func wiper(k: VehicleModels, parent: Node3D, pivot: Vector3, blade_center: Vector3, along: Vector3, normal: Vector3, length := 0.48) -> void:
	var n := normal.normalized()
	var axis := along.normalized()
	var blade_a := blade_center - axis * length * 0.5
	var blade_b := blade_center + axis * length * 0.5
	VehicleFrames.tube(k, parent, pivot, pivot + n * 0.018, 0.018, "metal_dark", null, 8, false)
	VehicleFrames.beam(k, parent, pivot + n * 0.018, blade_center + n * 0.018, 0.014, 0.009, "metal_dark")
	VehicleFrames.tube(k, parent, blade_a, blade_b, 0.007, "rubber", null, 6, false)
	VehicleFrames.beam(k, parent, blade_a.lerp(blade_b, 0.15) + n * 0.012, blade_a.lerp(blade_b, 0.85) + n * 0.012, 0.012, 0.008, "metal_dark")

static func parked_wiper(k: VehicleModels, parent: Node3D, center: Vector3, length: float, rotation: Vector3) -> void:
	var basis := Basis.from_euler(rotation)
	wiper(k, parent, center + basis * Vector3(-length * 0.35, -0.065, 0), center, basis.x, -basis.z, length)


## Side marker housing, gasket and optical insert. No live light or new
## animation is needed for the coloured navigation cue. `facing` turns the
## lens about Y in quarter turns from +Z: 1 faces +X, -1 faces -X, 2 faces
## forward (-Z), 0 back (+Z), as for roof-top cab markers.
static func marker(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, facing: float, col: Color) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation.y = facing * PI / 2
	k._add(mount, BevelMesh.make(Vector3(size.z, size.y, size.x), minf(size.y, size.x) * 0.2), "metal_dark", null, Vector3.ZERO)
	signal_lens(k, mount, Vector3(0, 0, size.x * 0.5 + 0.002), Vector2(size.z * 0.8, size.y * 0.78), col)
	k._fold(mount)


## Filler cap seated in a recessed neck. The caller supplies the outward normal.
static func filler(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, normal := Vector3.UP, mat := "gunmetal_w", col = null) -> void:
	var basis := VehicleFrames.aim(normal)
	# The seal's foot is in the panel and the cap's in the seal.
	VehicleFrames.cyl(k, parent, radius * 1.12, radius * 1.12, radius * 0.18, center, basis.get_euler(), "rubber", null, 16, false, 1)
	VehicleFrames.cyl(k, parent, radius * 0.88, radius, radius * 0.24, center + normal * radius * 0.08, basis.get_euler(), mat, col, 12, false, 1)
	VehicleFrames.beam(k, parent, center - basis.x * radius * 0.6 + normal * radius * 0.23, center + basis.x * radius * 0.6 + normal * radius * 0.23, radius * 0.18, radius * 0.18, mat, col, false)


## Rectangular hatch lid: the old lid box's centre and size, sitting on the
## roof. A seat coaming round it, a bevelled lid with pressed stiffeners, two
## hinges on the edge toward `hinge_side` along Z and a grab handle near the
## opposite edge. Opening lids and their pivots stay with the family.
## `rotation` turns the whole hatch about its centre, to lie on a sloped plate
## (a glacis, a raked engine deck): its local Y is the plate's outward normal.
static func panel_hatch(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, material: String, col = null, hinge_side := 1.0, handle := true, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var t := size.y
	var rim := minf(0.03, minf(size.x, size.z) * 0.06)
	for side: float in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x + rim * 2, t * 0.55, rim), Vector3(0, -t * 0.225, side * (size.z + rim) * 0.5), material, col)
		k._box(mount, Vector3(rim, t * 0.55, size.z), Vector3(side * (size.x + rim) * 0.5, -t * 0.225, 0), material, col)
	k._add(mount, BevelMesh.make(Vector3(size.x - 0.01, t, size.z - 0.01), minf(t * 0.3, 0.012)), material, col, Vector3.ZERO)
	k._box(mount, Vector3(size.x - 0.004, 0.006, size.z - 0.004), Vector3(0, -t * 0.5 + 0.004, 0), "rubber", null, Vector3.ZERO, false)
	var rib := minf(0.04, minf(size.x, size.z) * 0.08)
	k._add(mount, BevelMesh.make(Vector3(size.x * 0.7, t * 0.3, rib), t * 0.1), material, col, Vector3(0, t * 0.6, 0))
	k._add(mount, BevelMesh.make(Vector3(rib, t * 0.3, size.z * 0.7), t * 0.1), material, col, Vector3(0, t * 0.6, 0))
	var hinge_z := signf(hinge_side) * (size.z * 0.5 - 0.02)
	for side: float in [-1.0, 1.0]:
		VehicleDoors.hinge(k, mount, Vector3(side * size.x * 0.3, t * 0.5, hinge_z), Vector3.UP, Vector3.RIGHT, minf(0.016, t * 0.3), material, col)
	if handle:
		VehicleDoors.pull(k, mount, Vector3(0, t * 0.5, -signf(hinge_side) * (size.z * 0.5 - 0.07)), Vector3.UP, Vector3.RIGHT, minf(0.16, size.x * 0.35), minf(0.01, t * 0.2))
	k._fold(mount)


## Bore evacuator on a gun tube along Z: the old cylinder's centre, radius and
## length. The chamber tapers down onto the barrel at both ends; a joint band
## and the filler plug show where its two shells meet.
static func evacuator(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, material := "paint", col = null) -> void:
	var mount := k._pivot(parent, center)
	var x90 := Vector3(PI / 2, 0, 0)
	var cap := minf(length * 0.14, radius * 0.9)
	var half := length * 0.5
	# The chamber's ends are closed by the tapers, which close round the barrel.
	VehicleFrames.cyl(k, mount, radius, radius, length - cap * 2, Vector3.ZERO, x90, material, col, 16, true, 0)
	VehicleFrames.cyl(k, mount, radius * 0.72, radius, cap, Vector3(0, 0, half - cap * 0.5), x90, material, col, 16, true, 1)
	VehicleFrames.cyl(k, mount, radius, radius * 0.72, cap, Vector3(0, 0, -half + cap * 0.5), x90, material, col, 16, true, 2)
	VehicleFrames.cyl(k, mount, radius * 1.03, radius * 1.03, minf(0.04, length * 0.06), Vector3(0, 0, length * 0.08), x90, "metal_dark", null, 16, false)
	VehicleBody.fastener(k, mount, Vector3(0, radius + 0.002, -length * 0.2), Vector3.UP, radius * 0.12)
	k._fold(mount)


## Round dome light (anti-collision beacon, masthead or stern light): the old
## lens sphere's centre and radius. A metal base and rubber seat under a
## glossy lens (left off wrecks); `scale` flattens or stretches it as the old
## sphere was, and `up` points from the base to the lens.
static func dome_light(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, col: Color, scale := Vector3.ONE, up := Vector3.UP) -> void:
	var mount := k._pivot(parent, center)
	mount.basis = VehicleFrames.aim(up) * Basis.from_scale(scale)
	# The base reaches the old sphere's lowest point, so a lamp on a pole or a
	# surface still sits on it.
	VehicleFrames.cyl(k, mount, radius * 0.9, radius * 1.04, radius * 0.6, Vector3(0, -radius * 0.7, 0), Vector3.ZERO, "metal_dark", null, 12, true, 1)
	VehicleFrames.cyl(k, mount, radius * 1.0, radius * 1.0, radius * 0.12, Vector3(0, -radius * 0.38, 0), Vector3.ZERO, "rubber", null, 12, false)
	# Like every other lamp, a wreck keeps the base and loses the lens.
	if not k.burnt:
		k._add(mount, Res.sphere(radius * 0.97, 12), "signal_lens", col, Vector3(0, radius * 0.02, 0), Vector3.ZERO, Vector3(1, 0.9, 1), false)
	k._fold(mount)


## Red (port, side < 0) or green (starboard, side > 0) sidelight. `size` is the
## old box in the parent's axes (X outward), so housings keep their place;
## the lens faces outward and a short visor shades it from above.
static func nav_light(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side: float) -> void:
	var facing := 1.0 if side >= 0.0 else -1.0
	var col := Color(0.1, 0.5, 0.2) if facing > 0.0 else Color(0.6, 0.1, 0.08)
	marker(k, parent, center, size, facing, col)
	var visor := maxf(0.004, size.y * 0.12)
	k._box(parent, Vector3(size.x * 1.3, visor, size.z * 1.06), center + Vector3(facing * size.x * 0.15, size.y * 0.5 + visor * 0.5, 0), "metal_dark", null, Vector3.ZERO, false)


## Steel-wire tow cable stowed along a hull side or across the back, on the
## old cable's `supports` (the points VehicleFrames.cable ran it through, in
## the parent's axes), `radius` the wire's and `slack` its old sag. Each end is
## a thimble eye, the wire looped round a grooved steel liner and swaged into a
## pressed ferrule; the loop's far side lies on the old end point, so the run
## keeps its length, and it hangs on a stowage peg. Spring clips hold the wire
## to the hull at every inner support and at `clips` more points spread along
## the run (-1: about one every 1.5 m); it sags only between them, the old
## slack shared out. `outward` is the normal of the face the eyes lie flat
## against; zero takes the run's horizontal normal pointing away from the
## parent's centre line. Pegs reach 4 cm into the face; clips stand 1.1 wire
## radii behind the wire.
static func tow_cable(k: VehicleModels, parent: Node3D, supports: Array, radius: float, slack := 0.0, clips := -1, outward := Vector3.ZERO, mat := "steel", col = Color(0.20, 0.21, 0.19)) -> void:
	if supports.size() < 2 or radius <= 0.0:
		return
	var points: Array[Vector3] = []
	for p: Vector3 in supports:
		points.append(p)
	var first := points[0]
	var last := points[points.size() - 1]
	var n := outward.normalized()
	if n.is_zero_approx():
		var run := last - first
		n = Vector3(-run.z, 0, run.x).normalized()
		if n.is_zero_approx():
			n = Vector3.RIGHT
		var mid := (first + last) * 0.5
		if n.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
			n = -n
	# The eyes take up the ends of the run: loop, then ferrule, then the wire.
	var eye := radius * 3.0
	var ferrule := radius * 5.0
	var ends: Array[Vector3] = []
	for e in 2:
		var tip: Vector3 = first if e == 0 else last
		var inner: Vector3 = points[1] if e == 0 else points[points.size() - 2]
		var d := (tip - inner).normalized()
		# The loop lies flat on the face, drawn out along the run into a teardrop.
		var along := (d - n * d.dot(n)).normalized()
		var flat := Basis(n.cross(along), n, along).get_euler()
		var stretch := Vector3(1, 1, 1.3)
		var loop := tip - d * (eye + radius) * 1.3
		var neck := loop - d * eye * 1.3
		k._add(parent, _ring(eye - radius, eye + radius), mat, col, loop, flat, stretch, false)
		k._add(parent, _ring(eye - radius * 1.55, eye - radius * 0.75), "steel", Color(0.46, 0.47, 0.44), loop, flat, stretch, false)
		VehicleFrames.tube(k, parent, neck - d * ferrule, neck + d * radius * 0.5, radius * 1.55, "steel", Color(0.40, 0.41, 0.38), 8, false)
		# The peg's foot is in the hull face.
		VehicleFrames.tube(k, parent, loop - n * 0.04, loop + n * radius * 1.6, radius * 0.6, "gunmetal_w", null, 6, false, -1.0, 1)
		ends.append(neck - d * ferrule * 0.9)
	points[0] = ends[0]
	points[points.size() - 1] = ends[1]
	# The wire, clipped at each inner support and at spread clips between,
	# sagging between clips as VehicleFrames.cable sags it. It is one bent
	# wire, its ends swaged inside the ferrules.
	var spans := 0.0
	for i in points.size() - 1:
		spans += points[i].distance_to(points[i + 1])
	var wire: Array = [points[0]]
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var extra := floori(length / 1.5) if clips < 0 else roundi(clips * length / maxf(spans, 0.001))
		var line: Array = [a]
		for j in extra:
			line.append(a.lerp(b, (j + 1.0) / (extra + 1.0)))
		line.append(b)
		var sag := slack / (extra + 1.0)
		for j in line.size() - 1:
			var from: Vector3 = line[j]
			var to: Vector3 = line[j + 1]
			for s in range(1, 5 if sag > 0.0 else 2):
				var t := float(s) / (4 if sag > 0.0 else 1)
				wire.append(from.lerp(to, t) + Vector3.DOWN * sin(PI * t) * sag)
		for j in range(1, line.size() - 1):
			_cable_clip(k, parent, line[j], (b - a).normalized(), n, radius)
		if i > 0:
			_cable_clip(k, parent, a, (b - a).normalized(), n, radius)
	VehicleFrames.path(k, parent, wire, radius, mat, col, 6, false, 0)


## A sprung stowage clip holding a wire at `at` (running along `along`) to
## the face behind it, whose normal is `n`: a bolted base plate and a strap
## bent over the wire.
static func _cable_clip(k: VehicleModels, parent: Node3D, at: Vector3, along: Vector3, n: Vector3, radius: float) -> void:
	var z := (along - n * along.dot(n)).normalized()
	if z.is_zero_approx():
		return
	var mount := k._pivot(parent, at)
	mount.basis = Basis(n.cross(z), n, z)
	k._box(mount, Vector3(radius * 5.0, 0.006, radius * 2.6), Vector3(0, -radius * 1.1, 0), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(mount, Vector3(radius * 2.8, 0.005, radius * 2.0), Vector3(0, radius * 1.15, 0), "gunmetal_w", null, Vector3.ZERO, false)
	for x: float in [-1.0, 1.0]:
		k._box(mount, Vector3(0.005, radius * 2.3, radius * 2.0), Vector3(x * radius * 1.38, 0, 0), "gunmetal_w", null, Vector3.ZERO, false)
	VehicleBody.fastener(k, mount, Vector3(radius * 2.0, -radius * 1.1 + 0.004, 0), Vector3.UP, minf(0.008, radius * 0.3))
	k._fold(mount)


static var _open_ends := {}

## Exhaust run under a vehicle: the pipe from the engine's manifold to the
## tail. `route` is its centre line in the parent's coordinates, two or more
## points from the engine end to the outlet, mandrel-bent at the inner points
## (each bend under a band clamp); `radius` is the pipe's. An old straight pipe
## along Z (a cylinder at c, length L) converts as [c - (0, 0, L/2), c + (0, 0,
## L/2)], the engine end first. A two-bolt flange joins it to the manifold.
## `silencer_center` / `silencer_size` put a silencer where the old can or box
## was (VehicleFittings.silencer; zero size: none), the pipe running on through
## it. `hang` > 0 hangs the run from the floor that far above the pipe's centre
## line on rubber-isolated rods, about one every 0.9 m, and the silencer from
## its two straps. `tip` = (length, radius) ends it in an outlet tip
## (VehicleFittings.exhaust, unshielded, which notes the exhaust mouth for the
## heat haze); zero leaves the route's end an open, sooted pipe end that notes
## nothing. Everything stays within the pipe's radius of the route but for the
## clamps and flange (1.3 and 2.2 radii), the hangers and the tip.
static func exhaust_run(k: VehicleModels, parent: Node3D, route: Array, radius: float, silencer_center := Vector3.ZERO, silencer_size := Vector3.ZERO, tip := Vector2.ZERO, hang := 0.0, mat := "gunmetal_w", col = null, round := true) -> void:
	var points: Array[Vector3] = []
	for p: Vector3 in route:
		if points.is_empty() or points[points.size() - 1].distance_to(p) > 0.001:
			points.append(p)
	if points.size() < 2 or radius <= 0.0:
		return
	var end := points[points.size() - 1]
	var out := (end - points[points.size() - 2]).normalized()
	var sleeve := radius * 2.0
	var open := tip.x <= 0.0 and end.distance_to(points[points.size() - 2]) > sleeve * 1.5
	if open:
		points[points.size() - 1] = end - out * sleeve
	VehicleFrames.path(k, parent, points, radius, mat, col, 8)
	# The manifold flange, square to the first run.
	var d0 := (points[1] - points[0]).normalized()
	var flange := k._pivot(parent, points[0])
	flange.basis = VehicleFrames.aim(d0)
	k._box(flange, Vector3(radius * 4.4, 0.008, radius * 2.2), Vector3.ZERO, "gunmetal_w", null, Vector3.ZERO, false)
	for x: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, flange, Vector3(x * radius * 1.55, 0.005, 0), Vector3.UP, radius * 0.3)
	k._fold(flange)
	for i in range(1, points.size() - 1):
		var d := (points[i + 1] - points[i - 1]).normalized()
		k._add(parent, _ring(radius * 0.96, radius * 1.3), "steel", Color(0.30, 0.31, 0.29), points[i], VehicleFrames.aim(d).get_euler(), Vector3(1, 0.6, 1), false)
	if open:
		_open_end(k, parent, end - out * sleeve, out, sleeve, radius, mat, col)
	elif tip.x > 0.0:
		exhaust(k, parent, end, out, tip.x, tip.y, false)
	if silencer_size != Vector3.ZERO:
		silencer(k, parent, silencer_center, silencer_size, mat, col, round)
	if hang > radius:
		var total := 0.0
		for i in points.size() - 1:
			total += points[i].distance_to(points[i + 1])
		var count := clampi(floori(total / 0.9), 1, 4)
		for j in count:
			var at := (j + 0.5) / count * total
			for i in points.size() - 1:
				var length := points[i].distance_to(points[i + 1])
				if at <= length or i == points.size() - 2:
					var p := points[i].lerp(points[i + 1], clampf(at / maxf(length, 0.001), 0.0, 1.0))
					if silencer_size == Vector3.ZERO or not AABB(silencer_center - silencer_size * 0.5, silencer_size).grow(0.05).has_point(p):
						_hanger(k, parent, p + Vector3.UP * radius, p.y + hang, radius)
					break
				at -= length
		if silencer_size != Vector3.ZERO and silencer_center.y + hang > silencer_center.y + silencer_size.y * 0.5 + 0.01:
			var axis := Vector3.ZERO
			axis[silencer_size.max_axis_index()] = 1.0
			var long := silencer_size[silencer_size.max_axis_index()]
			for f: float in [-0.28, 0.28]:
				var p := silencer_center + axis * long * f
				_hanger(k, parent, p + Vector3.UP * silencer_size.y * 0.5, silencer_center.y + hang, radius)


## A hanger rod from `from` straight up to the floor at height `floor_y`, a
## rubber isolator block on it and a bracket welded to the floor.
static func _hanger(k: VehicleModels, parent: Node3D, from: Vector3, floor_y: float, radius: float) -> void:
	var top := Vector3(from.x, floor_y, from.z)
	if top.y - from.y < 0.01:
		return
	var r := maxf(0.005, radius * 0.18)
	VehicleFrames.tube(k, parent, from, top, r, "steel", Color(0.30, 0.31, 0.29), 6, false)
	var block := minf(0.03, (top.y - from.y) * 0.4)
	VehicleFrames.cyl(k, parent, r * 3.2, r * 3.2, block, from.lerp(top, 0.55), Vector3(PI / 2, 0, 0), "rubber", null, 8, false)
	k._box(parent, Vector3(r * 6.0, 0.006, r * 6.0), top - Vector3(0, 0.003, 0), "gunmetal_w", null, Vector3.ZERO, false)


## The open end of a pipe: an uncapped sleeve `length` long from `base` along
## `direction`, its bore sooted dark inside a rolled lip (cached by size).
static func _open_end(k: VehicleModels, parent: Node3D, base: Vector3, direction: Vector3, length: float, radius: float, mat: String, col) -> void:
	var key := Vector2(radius, length)
	if not _open_ends.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = radius
		outer.bottom_radius = radius
		outer.height = length
		outer.radial_segments = 8
		outer.rings = 1
		outer.cap_top = false
		var inner := CylinderMesh.new()
		inner.top_radius = radius * 0.8
		inner.bottom_radius = radius * 0.8
		inner.height = length
		inner.radial_segments = 8
		inner.rings = 1
		inner.cap_top = false
		inner.flip_faces = true
		_open_ends[key] = [outer, inner]
	var meshes: Array = _open_ends[key]
	var mount := k._pivot(parent, base)
	mount.basis = VehicleFrames.aim(direction)
	k._add(mount, meshes[0], mat, col, Vector3(0, length * 0.5, 0))
	k._add(mount, meshes[1], "burnt", Color(0.03, 0.03, 0.028), Vector3(0, length * 0.5, 0), Vector3.ZERO, Vector3.ONE, false)
	k._add(mount, _ring(radius * 0.8, radius * 1.02), mat, col, Vector3(0, length, 0), Vector3.ZERO, Vector3(1, 0.4, 1), false)
	k._fold(mount)


## Exhaust silencer (muffler): the old can's or box's centre and size in the
## parent's axes, its length along whichever axis is longest. `round` makes it
## a rolled can as wide as the narrower cross size, else a pressed box the old
## box's size. Dished ends rolled onto the shell, the lock seam down its side
## and two clamped straps where it hangs; it stays inside the old size but for
## the seams and straps (4% of its width proud).
static func silencer(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat := "gunmetal_w", col = null, round := true) -> void:
	var a := size.max_axis_index()
	var axis := Vector3.ZERO
	axis[a] = 1.0
	var length := size[a]
	var mount := k._pivot(parent, center)
	mount.basis = VehicleFrames.aim(axis)
	# The old box's cross sizes in the can's own axes (local Y is its length).
	var across := Vector2(absf(mount.basis.x.dot(size)), absf(mount.basis.z.dot(size)))
	var r := minf(across.x, across.y) * 0.5
	var end := minf(length * 0.06, r * 0.35)
	if round:
		# The shell's ends are closed by the dished ends rolled onto it.
		VehicleFrames.cyl(k, mount, r, r, length - end * 2.0, Vector3.ZERO, Vector3.ZERO, mat, col, 14, true, 0)
		for e: float in [-1.0, 1.0]:
			var y := e * (length * 0.5 - end * 0.5)
			VehicleFrames.cyl(k, mount, r * (0.84 if e > 0.0 else 1.0), r * (1.0 if e > 0.0 else 0.84), end, Vector3(0, y, 0), Vector3.ZERO, mat, col, 14, true, 1 if e > 0.0 else 2)
			VehicleFrames.cyl(k, mount, r * 1.04, r * 1.04, minf(0.012, end), Vector3(0, e * (length * 0.5 - end), 0), Vector3.ZERO, mat, col, 14, false)
		k._box(mount, Vector3(0.008, length - end * 2.0, r * 0.22), Vector3(r * 0.99, 0, 0), mat, col, Vector3.ZERO, false)
		for f: float in [-0.28, 0.28]:
			VehicleFrames.cyl(k, mount, r * 1.04, r * 1.04, minf(0.03, length * 0.08), Vector3(0, length * f, 0), Vector3.ZERO, "metal_dark", null, 14, false)
	else:
		k._add(mount, BevelMesh.make(Vector3(across.x, length - end * 2.0, across.y), minf(0.01, r * 0.12)), mat, col, Vector3.ZERO)
		for e: float in [-1.0, 1.0]:
			k._add(mount, BevelMesh.make(Vector3(across.x * 0.94, end, across.y * 0.94), minf(0.008, end * 0.3)), mat, col, Vector3(0, e * (length * 0.5 - end * 0.5), 0))
			k._box(mount, Vector3(across.x * 1.04, minf(0.012, end), across.y * 1.04), Vector3(0, e * (length * 0.5 - end), 0), mat, col, Vector3.ZERO, false)
		for f: float in [-0.28, 0.28]:
			k._box(mount, Vector3(across.x * 1.04, minf(0.03, length * 0.08), across.y * 1.04), Vector3(0, length * f, 0), "metal_dark", null, Vector3.ZERO, false)
	k._fold(mount)


## Engine air cleaner or intake stack standing beside a cab: the old body
## cylinder's centre, radius and height (a Y-axis cylinder). `cap` = (radius,
## height) of the old cap cylinder on its top: here the pre-cleaner, a dark
## screen the air is drawn in through under a rain hood (zero: one 1.05 radii
## round and 0.4 radii tall). A canister (radius 10 cm or more) has its dust
## cup clamped on with three over-centre latches; any stack wears two band
## straps, and `mount` (the direction toward the cab or bracket it is fixed
## to, parent axes) runs a bolted arm from each strap that way (zero: none).
## `hose` (parent coordinates) leads the rubber intake hose from the body's
## lower side to that point (zero: none). Everything stays inside the old body
## and cap but for the straps and latches (5% proud), the arms and the hose.
static func air_cleaner(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, height: float, mat: String, col = null, cap := Vector2.ZERO, mount := Vector3.ZERO, hose := Vector3.ZERO) -> void:
	var m := k._pivot(parent, center)
	var hh := height * 0.5
	var canister := radius >= 0.1
	var segs := 16 if canister else 10
	VehicleFrames.cyl(k, m, radius, radius, height, Vector3.ZERO, Vector3.ZERO, mat, col, segs)
	if canister:
		var joint := -hh + height * 0.22
		VehicleFrames.cyl(k, m, radius * 1.03, radius * 1.03, 0.022, Vector3(0, joint, 0), Vector3.ZERO, "metal_dark", null, segs, false)
		for i in 3:
			var a := TAU * (i + 0.25) / 3.0
			var at := Vector3(cos(a), 0, sin(a)) * radius * 1.02 + Vector3(0, joint, 0)
			k._box(m, Vector3(0.012, 0.06, 0.03), at, "gunmetal_w", null, Vector3(0, -a, 0), false)
	var arm := Vector3(mount.x, 0, mount.z).normalized()
	for f: float in [-0.28, 0.28]:
		var y := f * height
		var band := minf(0.035, height * 0.07)
		VehicleFrames.cyl(k, m, radius * 1.04, radius * 1.04, band, Vector3(0, y, 0), Vector3.ZERO, "metal_dark", null, segs, false)
		if not arm.is_zero_approx():
			var root := arm * radius * 1.02 + Vector3(0, y, 0)
			VehicleFrames.beam(k, m, root, root + arm * (radius * 0.5 + 0.04), band, 0.012, "metal_dark", null, false)
			VehicleBody.fastener(k, m, root + arm * (radius * 0.5 + 0.02) + Vector3(0, band * 0.5 + 0.001, 0), Vector3.UP, minf(0.008, band * 0.25))
	var cr := cap.x if cap.x > 0.0 else radius * 1.05
	var ch := cap.y if cap.y > 0.0 else radius * 0.4
	# The screen the air is drawn through, then the hood with its rolled rim.
	VehicleFrames.cyl(k, m, cr * 0.8, cr * 0.8, ch * 0.45, Vector3(0, hh + ch * 0.225, 0), Vector3.ZERO, "plain_dark", Color(0.06, 0.065, 0.06), 12, false)
	for i in 6:
		var a := TAU * i / 6.0
		k._box(m, Vector3(0.006, ch * 0.45, 0.006), Vector3(cos(a) * cr * 0.8, hh + ch * 0.225, sin(a) * cr * 0.8), "metal_dark", null, Vector3.ZERO, false)
	VehicleFrames.cyl(k, m, cr * 0.9, cr, ch * 0.55, Vector3(0, hh + ch * 0.725, 0), Vector3.ZERO, mat, col, 16)
	VehicleFrames.cyl(k, m, cr, cr, minf(0.012, ch * 0.12), Vector3(0, hh + ch * 0.45 + minf(0.006, ch * 0.06), 0), Vector3.ZERO, "metal_dark", null, 16, false)
	if hose != Vector3.ZERO:
		var to := hose - center
		var out := Vector3(to.x, 0, to.z).normalized()
		if out.is_zero_approx():
			out = Vector3.FORWARD
		var hr := minf(radius * 0.45, 0.08)
		var foot := Vector3(0, -hh + hr * 1.6, 0)
		var elbow := foot + out * (radius + hr * 1.5)
		VehicleFrames.path(k, m, [foot, elbow, to], hr, "rubber", null, 10)
		for at: Vector3 in [foot.lerp(elbow, 0.75), to]:
			var d := (elbow - foot).normalized() if at != to else (to - elbow).normalized()
			VehicleFrames.cyl(k, m, hr * 1.12, hr * 1.12, minf(0.02, hr * 0.5), at - d * minf(0.02, hr * 0.5), VehicleFrames.aim(d).get_euler(), "steel", Color(0.30, 0.31, 0.29), 10, false)
	k._fold(m)


## A searchlight or landing light: the lamp drum (the old drum cylinder's
## centre, its `radius` at the lens and `back_radius` behind, -1 the same, and
## `length` along the beam), aimed along `direction`. A bezel collar and
## rolled lip hold the reflector insert (VehicleFittings.headlamp, so wrecks
## lose the lens) a little inside the face; a cover plate and cable gland
## close the back, and `handle` adds the training handle behind it.
## `mount`: "yoke" hangs the drum on trunnion pins in a U yoke over a
## pedestal standing on `foot` (zero: 2.15 drum radii below the centre);
## "bracket" clamps a band round it on a post down to `foot`; "" leaves it
## fixed by its back, as lamps set in a hull or a gear leg are. A mounted lamp
## runs its power lead from the gland down to the foot. The drum keeps the old
## size (the collar 3% wider, the gland 2 cm behind); yokes stand 1.2 radii
## out at the sides.
static func searchlight(k: VehicleModels, parent: Node3D, center: Vector3, direction: Vector3, radius: float, length: float, mount := "", foot := Vector3.ZERO, mat := "gunmetal_w", col = null, back_radius := -1.0, handle := false) -> void:
	if radius <= 0.0 or length <= 0.0 or direction.length_squared() < 0.000001:
		return
	var d := direction.normalized()
	var x := d.cross(Vector3.UP).normalized() if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis(x, d, x.cross(d))
	var m := k._pivot(parent, center)
	m.basis = basis
	var rb := back_radius if back_radius > 0.0 else radius
	var big := maxf(radius, rb)
	var hl := length * 0.5
	var cover := length * 0.06
	var collar := length * 0.1
	# The drum (CylinderMesh's top radius lies toward the lens, local +Y). Its
	# front end is the dark back of the lamp round the insert; the cover closes
	# its back end. The collar is a band, open in the middle (a solid one hid
	# the insert set inside it): its outer wall, its face under the rolled lip
	# and its inner wall round the insert.
	VehicleFrames.cyl(k, m, radius, rb, length - cover - collar, Vector3(0, (cover - collar) * 0.5, 0), Vector3.ZERO, mat, col, 16, true, 1)
	VehicleFrames.cyl(k, m, rb, rb * 0.78, cover, Vector3(0, -hl + cover * 0.5, 0), Vector3.ZERO, mat, col, 16, true, 2)
	var band := [Vector2(radius * 1.03, hl - collar), Vector2(radius * 1.03, hl), Vector2(radius * 0.93, hl), Vector2(radius * 0.93, hl - collar)]
	k._add(m, VehicleProfiles.revolve(band, 16), mat, col, Vector3.ZERO, Vector3(-PI / 2, 0, 0))
	k._add(m, _ring(radius * 0.86, radius * 1.03), mat, col, Vector3(0, hl, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	headlamp(k, m, Vector3(0, hl - radius * 0.22, 0), radius * 0.84, Vector3.UP)
	var gland := Vector3(0, -hl - 0.01, -rb * 0.3)
	# The gland and the handle's legs stand on the back cover.
	VehicleFrames.cyl(k, m, minf(0.016, rb * 0.15), minf(0.02, rb * 0.18), 0.02, gland, Vector3.ZERO, "rubber", null, 8, false, 2)
	if handle:
		var w := rb * 0.45
		var back := -hl - length * 0.4
		VehicleFrames.path(k, m, [Vector3(-w, -hl, rb * 0.2), Vector3(-w, back, rb * 0.2), Vector3(w, back, rb * 0.2), Vector3(w, -hl, rb * 0.2)], maxf(0.008, rb * 0.07), "gunmetal_w", null, 6, true, 0)
	var base := foot if foot != Vector3.ZERO else center - Vector3.UP * big * 2.15
	match mount:
		"yoke":
			# The yoke turns with the lamp about the pedestal: build it in a
			# frame yawed so its X is the trunnion axis.
			var yoke := k._pivot(parent, center)
			yoke.rotation.y = atan2(-x.z, x.x)
			var t := big * 0.21
			var low := -big * 1.07
			for side: float in [-1.0, 1.0]:
				# A trunnion pin's outer end is in its arm.
				VehicleFrames.tube(k, yoke, Vector3(side * big * 0.95, 0, 0), Vector3(side * big * 1.24, 0, 0), big * 0.12, "steel", Color(0.30, 0.31, 0.29), 10, false, -1.0, 2)
				VehicleFrames.beam(k, yoke, Vector3(side * big * 1.21, low - t * 0.5, 0), Vector3(side * big * 1.21, big * 0.2, 0), t, big * 0.43, mat, col, true, true)
				VehicleFrames.cyl(k, yoke, big * 0.2, big * 0.2, t * 1.2, Vector3(side * big * 1.21, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10, false)
			VehicleFrames.beam(k, yoke, Vector3(-big * 1.31, low, 0), Vector3(big * 1.31, low, 0), big * 0.43, t, mat, col, true, true)
			var floor_at := yoke.transform.affine_inverse() * base
			# The pedestal stands in its foot plate, its top against the crossbar.
			VehicleFrames.tube(k, yoke, floor_at, Vector3(0, low - t * 0.5, 0), big * 0.5, mat, col, 12, true, big * 0.36, 0)
			VehicleFrames.cyl(k, yoke, big * 0.42, big * 0.42, t * 0.8, Vector3(0, low - t, 0), Vector3.ZERO, "metal_dark", null, 12, false)
			_foot_flange(k, yoke, floor_at, big * 0.7)
			k._fold(yoke)
		"bracket":
			VehicleFrames.cyl(k, m, big * 1.05, big * 1.05, length * 0.14, Vector3(0, -length * 0.05, 0), Vector3.ZERO, "metal_dark", null, 16, false)
			# The post stands upright on its foot, under the band.
			var post := Vector3(base.x, center.y - big * 0.95, base.z)
			VehicleFrames.beam(k, parent, post, base, big * 0.45, big * 0.6, mat, col, true, true)
			_foot_flange(k, parent, base, big * 0.55)
	if mount in ["yoke", "bracket"]:
		var lead := center + basis * gland
		# The lead enters the pedestal or post partway down, on its side.
		var into := base.lerp(center - Vector3.UP * big, 0.45) - x * big * (0.42 if mount == "yoke" else 0.22)
		VehicleFrames.cable(k, parent, [lead, into], maxf(0.006, big * 0.05), minf(big * 0.12, absf(lead.y - into.y) * 0.3), "rubber", null, false)
	k._fold(m)


## A bolted square foot plate under a post, `half` its half width.
static func _foot_flange(k: VehicleModels, parent: Node3D, at: Vector3, half: float) -> void:
	k._box(parent, Vector3(half * 2.0, 0.012, half * 2.0), at + Vector3(0, 0.006, 0), "gunmetal_w", null, Vector3.ZERO, false)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
		VehicleBody.fastener(k, parent, at + Vector3(corner.x * half * 0.7, 0.013, corner.y * half * 0.7), Vector3.UP, minf(0.009, half * 0.15))


## Roof lights side by side on one bar: `center` / `size` the old bar's (or
## base's) box, `lenses` one Color per lamp, laid along X at size.x / count
## apart (a zero size has no bar and centres the lamps on `center`).
## style "emergency": coloured lens modules standing on the bar's top (sunk
## 1.5 cm into it, the old lens boxes' way), each over a dark reflector housing
## and moulded with fresnel ribs, `lens_size` the old lens box (zero: the pitch
## less 4 cm, 0.9 of the bar's height, its depth less 4 cm). "work": lamps set
## in the bar's face toward `face` (-1: -Z, 1: +Z), VehicleFittings'
## rectangular inserts (lens_size x, y: the lens; zero: 0.64 of the pitch,
## 0.67 of the height; their colours are their own), cooling fins on its back
## and bolted end brackets. "beacon": a rotating beacon dome on the bar's top
## per lens, lens_size = (bottom radius, height, top radius) of the old dome
## (zero: a third of the bar's depth round). Wrecks keep the bar, housings and
## collars and lose every lens. `mat` / `col` dress the bar. Lamps stay inside
## the old boxes but for the beacon collars (10% wider), the work bar's fins
## (1.2 cm behind) and brackets (6 mm out at the ends).
static func light_bar(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, lenses: Array, style := "emergency", lens_size := Vector3.ZERO, face := -1.0, mat := "plain", col = Color(0.12, 0.12, 0.12)) -> void:
	var count := lenses.size()
	if count == 0:
		return
	var m := k._pivot(parent, center)
	var bar := size.x > 0.0 and size.y > 0.0 and size.z > 0.0
	var f := 1.0 if face > 0.0 else -1.0
	var top := size.y * 0.5 if bar else 0.0
	var pitch := size.x / count if bar else 0.0
	if bar:
		k._add(m, BevelMesh.make(size, minf(0.012, minf(size.y, size.z) * 0.2)), mat, col, Vector3.ZERO)
	match style:
		"emergency":
			var ls := lens_size if lens_size != Vector3.ZERO else Vector3(maxf(pitch - 0.04, pitch * 0.8), size.y * 0.9, size.z - 0.04)
			var y := top + ls.y * 0.5 - minf(0.015, ls.y * 0.17)
			for i in count:
				var x := (i - (count - 1) * 0.5) * pitch
				k._box(m, Vector3(ls.x * 0.9, ls.y * 0.4, ls.z * 0.9), Vector3(x, y - ls.y * 0.28, 0), "plain_dark", Color(0.05, 0.05, 0.05), Vector3.ZERO, false)
				if not k.burnt:
					var c: Color = lenses[i]
					k._add(m, BevelMesh.make(ls, minf(0.02, minf(ls.y, ls.z) * 0.3)), "signal_lens", c, Vector3(x, y, 0), Vector3.ZERO, Vector3.ONE, false)
					for j in 3:
						k._box(m, Vector3(0.004, ls.y * 0.66, ls.z * 1.004), Vector3(x + (j - 1) * ls.x * 0.28, y - ls.y * 0.05, 0), "signal_lens", c.lightened(0.1), Vector3.ZERO, false)
			if bar:
				# Clamp brackets bolt the bar to the roof rails at both ends.
				for e: float in [-1.0, 1.0]:
					for side: float in [-1.0, 1.0]:
						var at := Vector3(e * (size.x * 0.5 - minf(0.08, size.x * 0.1)), 0, side * (size.z * 0.5 + 0.002))
						k._box(m, Vector3(0.05, size.y * 0.8, 0.004), at, "metal_dark", null, Vector3.ZERO, false)
						VehicleBody.fastener(k, m, at + Vector3(0, 0, side * 0.003), Vector3(0, 0, side), 0.007)
		"work":
			var ls := Vector2(lens_size.x, lens_size.y) if lens_size != Vector3.ZERO else Vector2(pitch * 0.64, size.y * 0.67)
			for i in count:
				var x := (i - (count - 1) * 0.5) * pitch
				rectangular_headlamp(k, m, Vector3(x, 0, f * (size.z * 0.5 + 0.005)), ls, Vector3(0, PI if f > 0.0 else 0.0, 0))
			if bar:
				var fins := clampi(roundi(size.x / 0.05), 3, 24)
				for i in fins:
					var x := lerpf(-size.x * 0.45, size.x * 0.45, (i + 0.5) / fins)
					k._box(m, Vector3(0.004, size.y * 0.7, 0.012), Vector3(x, 0, -f * (size.z * 0.5 + 0.006)), mat, col, Vector3.ZERO, false)
				for e: float in [-1.0, 1.0]:
					k._box(m, Vector3(0.006, size.y * 1.24, size.z * 0.6), Vector3(e * (size.x * 0.5 + 0.003), -size.y * 0.12, 0), "metal_dark", null, Vector3.ZERO, false)
					VehicleBody.fastener(k, m, Vector3(e * (size.x * 0.5 + 0.007), 0, 0), Vector3(e, 0, 0), minf(0.01, size.y * 0.15))
		"beacon":
			var r0 := minf(size.z * 0.33, pitch * 0.4) if bar else 0.06
			var ls := lens_size if lens_size != Vector3.ZERO else Vector3(r0, r0 * 1.4, r0 * 0.9)
			var spacing := pitch if bar else ls.x * 2.6
			for i in count:
				var x := (i - (count - 1) * 0.5) * spacing
				var y0 := top
				VehicleFrames.cyl(k, m, ls.x * 1.06, ls.x * 1.1, ls.y * 0.2, Vector3(x, y0 + ls.y * 0.1, 0), Vector3.ZERO, mat, col, 14, true, 1)
				if k.burnt:
					k._box(m, Vector3(ls.x * 0.8, ls.y * 0.5, 0.012), Vector3(x, y0 + ls.y * 0.45, 0), "metal_dark")
					continue
				var c: Color = lenses[i]
				VehicleFrames.cyl(k, m, lerpf(ls.x, ls.z, 0.97), ls.x, ls.y * 0.66, Vector3(x, y0 + ls.y * 0.53, 0), Vector3.ZERO, "signal_lens", c, 14, false, 1)
				k._add(m, Res.dome(ls.z * 0.97, 12), "signal_lens", c, Vector3(x, y0 + ls.y * 0.86, 0), Vector3.ZERO, Vector3(1, minf(1.0, ls.y * 0.14 / maxf(ls.z * 0.97, 0.001)), 1), false)
				for t: float in [0.36, 0.62]:
					VehicleFrames.cyl(k, m, lerpf(ls.x, ls.z, t) + 0.003, lerpf(ls.x, ls.z, t) + 0.003, 0.006, Vector3(x, y0 + ls.y * (0.2 + 0.66 * t), 0), Vector3.ZERO, "signal_lens", c.lightened(0.12), 14, false)
			if bar:
				for e: float in [-1.0, 1.0]:
					VehicleBody.fastener(k, m, Vector3(e * (size.x * 0.5 - minf(0.04, size.x * 0.1)), top + 0.002, 0), Vector3.UP, minf(0.009, size.z * 0.08))
	k._fold(m)
