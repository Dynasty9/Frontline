class_name VehicleCab
extends RefCounted
## Open truck cabs share glazing and furniture, with family-specific proportions.

static var glass_near: StandardMaterial3D
static var glass_far: StandardMaterial3D

## Separate transparent panes are intentionally outside the opaque material bake.
## A cheap opaque pane takes over at the same distance as the chassis LOD.
static func glass(k: VehicleModels, size: Vector2, pos: Vector3, rot: Vector3) -> void:
	if k.burnt:
		return
	_materials()
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh_glass(k, k.root, mesh, pos, rot)


static func mesh_glass(k: VehicleModels, parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	if k.burnt:
		return
	_materials()
	var pane := Res.mi(parent, mesh, glass_near, pos, rot, false)
	pane.name = "CabGlass"
	pane.visibility_range_end = 100.0
	var distant := Res.mi(parent, mesh, glass_far, pos, rot, false)
	distant.name = "CabGlassDistant"
	distant.visibility_range_begin = 100.0

static func interior(k: VehicleModels, origin := Vector3.ZERO, scale := Vector3.ONE) -> void:
	var m := k._pivot(k.root, origin)
	m.scale = scale
	k._box(m, Vector3(2.10, 0.17, 0.34), Vector3(0, 2.03, -4.17), "plain_dark", Color(0.10, 0.12, 0.10))
	for side: float in [-1.0, 1.0]:
		seat(k, m, Vector3(side * 0.60, 1.99, -3.49), Vector3(0.57, 0.58, 0.54), Vector3.ZERO, Color(0.18, 0.20, 0.13), "canvas", true)
	# Steering wheel, spokes, column and an instrument binnacle. The rim is the
	# shared steering wheel's torus: a 2 cm grip seen through a cab window needs
	# no more than its 24 sections of six sides.
	k._add(m, Res.torus(0.16, 0.18), "rubber", null, Vector3(-0.60, 2.26, -3.97), Vector3(0.65, 0, 0))
	VehicleBody.rod(k, m, Vector3(-0.60, 1.97, -4.14), Vector3(-0.60, 2.26, -3.97), 0.035, "gunmetal_w", null, 8, true, -1.0, false, true)
	k._box(m, Vector3(0.45, 0.13, 0.10), Vector3(-0.60, 2.17, -4.15), "rubber")
	for x in [-0.73, -0.59, -0.47]:
		VehicleBody.cylinder(k, m, 0.04, 0.04, 0.012, Vector3(x, 2.18, -4.09), Vector3(PI / 2, 0, 0), "glass", Color(0.30, 0.32, 0.24), 12, false, true, false)
	k._fold(m)


## A hollow glasshouse on a separately modelled lower cab. Frame members follow
## the windshield rake and inward lean; no solid panel sits behind a window.
static func upper(k: VehicleModels, widths: Vector2, heights: Vector2, front: Vector2, rear: float, mat: String, col = null) -> void:
	var m := k.root
	var h := heights.y - heights.x
	var y := (heights.x + heights.y) * 0.5
	var z := (front.x + front.y) * 0.5
	var width := (widths.x + widths.y) * 0.5
	k._box(m, Vector3(widths.y * 2.0, 0.09, rear - front.y), Vector3(0, heights.y, (rear + front.y) * 0.5), mat, col)
	k._box(m, Vector3(width * 2.0, h, 0.10), Vector3(0, y, rear), mat, col)
	# The same surface defines the shell and its glass: the raked panes cannot
	# drift away from a separately positioned frame as cab proportions change.
	var front_corners := [Vector3(-widths.x, heights.x, front.x), Vector3(widths.x, heights.x, front.x), Vector3(widths.y, heights.y, front.y), Vector3(-widths.y, heights.y, front.y)]
	framed_face(k, m, front_corners, Vector3(0, y, rear), [Rect2(0.055, 0.10, 0.415, 0.79), Rect2(0.53, 0.10, 0.415, 0.79)], mat, col)
	for side: float in [-1.0, 1.0]:
		var corners := [Vector3(side * widths.x, heights.x, front.x), Vector3(side * widths.x, heights.x, rear), Vector3(side * widths.y, heights.y, rear), Vector3(side * widths.y, heights.y, front.y)]
		framed_face(k, m, corners, Vector3(0, y, z), [Rect2(0.055, 0.12, 0.53, 0.75), Rect2(0.65, 0.12, 0.29, 0.75)], mat, col)
	# Furniture is fitted into each cab's available space, then baked with it.
	var sc := Vector3(width / 1.17, h / 0.91, (rear - z) / 1.51)
	interior(k, Vector3(0, heights.x - 1.95 * sc.y, rear + 2.91 * sc.z), sc)


static func window(k: VehicleModels, size: Vector2, pos: Vector3, rot: Vector3) -> void:
	VehicleGlazing.rectangle(k, k.root, size, pos, rot, true)



static func _materials() -> void:
	if glass_near == null:
		glass_near = StandardMaterial3D.new()
		glass_near.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_near.albedo_color = Color(0.16, 0.20, 0.21, 0.27)
		glass_near.roughness = 0.045
		glass_near.metallic_specular = 0.5
		glass_near.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass_far = StandardMaterial3D.new()
		glass_far.albedo_color = Color(0.10, 0.14, 0.16)
		glass_far.roughness = 0.09
		glass_far.cull_mode = BaseMaterial3D.CULL_DISABLED


## Reusable hollow cabin face; openings are normalized rectangles on the quad.
static func framed_face(k: VehicleModels, parent: Node3D, corners: Array, inside: Vector3, openings: Array[Rect2], mat: String, col = null, depth := 0.065) -> void:
	var surface := VehicleSurface.quad(corners, inside)
	k._add(parent, surface.shell(Rect2(0, 0, 1, 1), openings, depth), mat, col, Vector3.ZERO)
	for hole in openings:
		var outline := PackedVector2Array([hole.position, Vector2(hole.end.x, hole.position.y), hole.end, Vector2(hole.position.x, hole.end.y)])
		VehicleGlazing.polygon(k, parent, surface, outline, true, null, 0.012)


## Seat origin is the cushion centre; dimensions are width, back height, depth.
## The local front is -Z. Padding, seams and support share construction, while
## low marine jockey backs and full-height crew seats retain their proportions.
static func seat(k: VehicleModels, parent: Node3D, center: Vector3, size := Vector3(0.46, 0.5, 0.46), rotation := Vector3.ZERO, col := Color(0.20, 0.21, 0.17), material := "canvas", headrest := false) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var pad := minf(0.12, size.z * 0.24)
	k._add(mount, BevelMesh.make(Vector3(size.x, pad, size.z), minf(0.035, pad * 0.3)), material, col, Vector3.ZERO)
	var back := Vector3(0, size.y * 0.5, size.z * 0.46)
	# The back leans away from the sitter, as a seat back does.
	k._add(mount, BevelMesh.make(Vector3(size.x * 0.94, size.y, pad * 0.8), pad * 0.22), material, col.darkened(0.06), back, Vector3(0.12, 0, 0))
	# Rolled cushion piping and the two stitched back panels catch side light.
	var seam_col := col.darkened(0.26)
	for side: float in [-1.0, 1.0]:
		# (piping and seams 7 mm thick: their ends are a few pixels, left open)
		VehicleBody.rod(k, mount, Vector3(side * size.x * 0.43, pad * 0.48, -size.z * 0.4), Vector3(side * size.x * 0.43, pad * 0.48, size.z * 0.34), 0.004, material, seam_col, 5, false, -1.0, false, false)
		VehicleBody.rod(k, mount, Vector3(side * size.x * 0.30, size.y * 0.13, size.z * 0.46 - pad * 0.42 - size.y * 0.04), Vector3(side * size.x * 0.30, size.y * 0.85, size.z * 0.46 - pad * 0.42 + size.y * 0.046), 0.0035, material, seam_col, 5, false, -1.0, false, false)
		VehicleFrames.beam(k, mount, Vector3(side * size.x * 0.32, -pad * 0.7, -size.z * 0.3), Vector3(side * size.x * 0.32, -pad * 0.7, size.z * 0.38), 0.025, 0.035, "metal_dark")
	if headrest:
		for side: float in [-1.0, 1.0]:
			# The posts follow the back's lean up out of its top edge.
			VehicleBody.rod(k, mount, back + Vector3(side * size.x * 0.2, size.y * 0.46, size.y * 0.055), back + Vector3(side * size.x * 0.2, size.y * 0.63, size.y * 0.076), 0.012, "steel", null, 6, false, -1.0, false, false)
		k._box(mount, Vector3(size.x * 0.58, size.y * 0.25, pad), back + Vector3(0, size.y * 0.66, size.y * 0.08), material, col, Vector3(0.12, 0, 0))
	for side: float in [-1.0, 1.0]:
		k._add(mount, BevelMesh.make(Vector3(size.x * 0.11, pad * 0.62, size.z * 0.75), pad * 0.15), material, col, Vector3(side * size.x * 0.43, pad * 0.35, 0))
	k._add(mount, BevelMesh.make(Vector3(size.x * 0.78, size.y * 0.82, pad * 0.22), pad * 0.07), "plain_dark", Color(0.12, 0.13, 0.12), back + Vector3(0, 0, pad * 0.5), Vector3(0.12, 0, 0))
	k._fold(mount)


## A bench for a row of sitters: a truck's troop bench, a car's rear bench, a
## light vehicle's or a boat's padded bench. `center` and `size` are the old
## seat box (plank or cushion) in the parent's axes; `facing` is the level way
## the sitters face, and the bench runs along the level axis across it, so a
## side bench in a truck bed faces inboard and a car's rear bench forward.
## `back` = (rise, height, thickness) stands a backrest on the seat's rear
## edge: its lower edge `rise` above the seat's top (negative tucks it down
## behind a cushion), its front face `inset` into the seat from that edge, its
## top leaning `recline` radians away from the sitters (about its own middle);
## zero height for none. Outward-facing passengers sitting back to back are
## two calls whose backs meet. `legs` > 0 stands the seat on folding legs that
## long under its front edge, down to the floor; zero leaves it on a deck, a
## box or brackets. `wall` hangs the bench on a body wall behind it, as troop
## seats that fold up against a dropside or a bulwark: hinges along the seat's
## rear edge, the backrest bolted through to the wall's brackets; otherwise the
## backrest stands on flat stays from the seat's frame. Wood (by `mat`'s
## finish) is laid as slats on steel bearers with a slatted back; anything
## else is a cushion in `seat`'s padding style, piped along its front edge
## with a stitched seam between places, on a steel frame, with a padded back
## on a dark backing shell. Stays within the seat box and the backrest but for
## 2.5 cm of frame under a cushion, the legs down to the floor, 1.2 cm of stays
## behind a free-standing back, and 0.8 cm of hinge straps under the seat.
static func bench(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, facing: Vector3, back := Vector3.ZERO, mat := "canvas", col = null, legs := 0.0, wall := false, recline := 0.0, inset := 0.0) -> void:
	var front := Vector3(facing.x, 0, facing.z).normalized()
	if front.is_zero_approx():
		front = Vector3.FORWARD
	var along := front.cross(Vector3.UP)
	# Local frame: X along the bench, -Z toward the sitters (as `seat`).
	var mount := k._pivot(parent, center)
	mount.basis = Basis(along, Vector3.UP, -front)
	var length := absf(along.x) * size.x + absf(along.z) * size.z
	var depth := absf(front.x) * size.x + absf(front.z) * size.z
	var t := size.y
	var hl := length * 0.5
	var hd := depth * 0.5
	var wood := VehicleMaterials.profile(mat, k.surface_family) == "wood"
	var tint: Variant = col
	var seam: Variant = (col as Color).darkened(0.26) if col is Color else null
	if wood:
		# Slats laid the length of the bench on steel bearers and edge angles.
		var slats := maxi(2, roundi(depth / 0.12))
		var gap := minf(0.014, depth * 0.04)
		var width := (depth - gap * (slats - 1)) / slats
		var st := maxf(0.02, t * 0.6)
		for i in slats:
			k._box(mount, Vector3(length - 0.01, st, width), Vector3(0, t * 0.5 - st * 0.5, -hd + width * 0.5 + i * (width + gap)), mat, tint)
		var under := maxf(0.008, t - st)
		for e: float in [-1.0, 1.0]:
			k._box(mount, Vector3(length - 0.04, under, 0.025), Vector3(0, -t * 0.5 + under * 0.5, e * (hd - 0.0125)), "gunmetal_w")
		var bearers := maxi(2, ceili(length / 0.8) + 1)
		for i in bearers:
			var x := lerpf(-hl + 0.04, hl - 0.04, float(i) / (bearers - 1))
			k._box(mount, Vector3(0.03, under, depth - 0.05), Vector3(x, -t * 0.5 + under * 0.5, 0), "gunmetal_w", null, Vector3.ZERO, false)
	else:
		k._add(mount, BevelMesh.make(Vector3(length, t, depth), minf(0.035, t * 0.3)), mat, tint, Vector3.ZERO)
		# Piping rolled along the front edge, a stitched seam between places.
		VehicleBody.rod(k, mount, Vector3(-hl * 0.97, t * 0.42, -hd * 0.94), Vector3(hl * 0.97, t * 0.42, -hd * 0.94), 0.004, mat, seam, 5, false, -1.0, false, false)
		var places := maxi(1, roundi(length / 0.55))
		for i in range(1, places):
			var x := lerpf(-hl, hl, float(i) / places)
			VehicleBody.rod(k, mount, Vector3(x, t * 0.5, -hd * 0.86), Vector3(x, t * 0.5, hd * 0.8), 0.0035, mat, seam, 5, false, -1.0, false, false)
		for e: float in [-1.0, 1.0]:
			VehicleFrames.beam(k, mount, Vector3(-hl * 0.92, -t * 0.5 - 0.0125, e * depth * 0.32), Vector3(hl * 0.92, -t * 0.5 - 0.0125, e * depth * 0.32), 0.025, 0.035, "metal_dark")
	# Brackets and stays repeat about every metre, never fewer than two.
	var stations := maxi(2, roundi(length / 1.0) + 1)
	var bx: Array[float] = []
	for i in stations:
		bx.append(lerpf(-hl + minf(0.12, hl * 0.3), hl - minf(0.12, hl * 0.3), float(i) / (stations - 1)))
	var wall_z := hd
	if back.y > 0.0:
		var th := back.z
		var bc := Vector3(0, t * 0.5 + back.x + back.y * 0.5, hd - inset + th * 0.5)
		wall_z = hd - inset + th
		var bp := k._pivot(mount, bc)
		bp.rotation = Vector3(recline, 0, 0)
		if wood:
			var boards := 2 if back.y >= 0.22 else 1
			var bh := (back.y - 0.02 * (boards - 1)) / boards
			for i in boards:
				var y := -back.y * 0.5 + bh * 0.5 + i * (bh + 0.02)
				k._box(bp, Vector3(length - 0.01, bh, th), Vector3(0, y, 0), mat, tint)
				if wall:
					for x: float in bx:
						VehicleBody.fastener(k, bp, Vector3(x, y, -th * 0.5 - 0.002), Vector3.FORWARD, minf(0.01, bh * 0.15))
		else:
			k._add(bp, BevelMesh.make(Vector3(length, back.y, th * 0.8), minf(0.03, th * 0.22)), mat, (col as Color).darkened(0.06) if col is Color else null, Vector3(0, 0, -th * 0.1))
			k._add(bp, BevelMesh.make(Vector3(length * 0.96, back.y * 0.9, th * 0.2), th * 0.06), "plain_dark", Color(0.12, 0.13, 0.12), Vector3(0, 0, th * 0.4))
			VehicleBody.rod(k, bp, Vector3(-length * 0.48, back.y * 0.44, -th * 0.48), Vector3(length * 0.48, back.y * 0.44, -th * 0.48), 0.0035, mat, seam, 5, false, -1.0, false, false)
			var places := maxi(1, roundi(length / 0.55))
			for i in range(1, places):
				var x := lerpf(-hl, hl, float(i) / places)
				VehicleBody.rod(k, bp, Vector3(x, -back.y * 0.4, -th * 0.5), Vector3(x, back.y * 0.4, -th * 0.5), 0.0035, mat, seam, 5, false, -1.0, false, false)
			if wall:
				for x: float in bx:
					VehicleBody.fastener(k, bp, Vector3(x, back.y * 0.3, -th * 0.5 - 0.001), Vector3.FORWARD, 0.008)
		if not wall:
			# Flat stays from the seat frame's rear rail up the back's rear face.
			for x: float in bx:
				var up := bp.transform * Vector3(x, back.y * 0.25, th * 0.5 + 0.006)
				var foot := Vector3(x, -t * 0.5 - 0.006, minf(hd - 0.02, up.z))
				VehicleFrames.beam(k, mount, foot, up, 0.03, 0.012, "metal_dark")
		k._fold(bp)
	if wall:
		# The seat folds up on hinges at its rear edge, their straps to the wall.
		for x: float in bx:
			VehicleBody.cylinder(k, mount, 0.012, 0.012, 0.07, Vector3(x, -t * 0.5 + 0.004, hd - 0.012), Vector3(0, 0, PI / 2), "steel", null, 8, false)
			var reach := maxf(0.02, wall_z - (hd - 0.03))
			k._box(mount, Vector3(0.05, 0.008, reach), Vector3(x, -t * 0.5 - 0.004, hd - 0.03 + reach * 0.5), "gunmetal_w", null, Vector3.ZERO, false)
	if legs > 0.0:
		# Folding legs under the front edge, hinged under the seat, on foot pads.
		var count := maxi(2, roundi(length / 1.5) + 1)
		for i in count:
			var x := lerpf(-hl + 0.1, hl - 0.1, float(i) / (count - 1)) if length > 0.3 else 0.0
			var top := Vector3(x, -t * 0.5, -hd + minf(0.05, hd * 0.4))
			# (the leg's top is in its hinge knuckle, its foot on the pad)
			VehicleBody.rod(k, mount, top, top + Vector3.DOWN * legs, 0.016, "gunmetal_w", null, 6, true, -1.0, false, false)
			VehicleBody.cylinder(k, mount, 0.019, 0.019, 0.05, top + Vector3(0, -0.012, 0), Vector3(0, 0, PI / 2), "steel", null, 8, false)
			k._box(mount, Vector3(0.05, 0.008, 0.06), top + Vector3(0, -legs + 0.004, 0), "gunmetal_w", null, Vector3.ZERO, false)
	k._fold(mount)


## Dash with a driver-side gauge cluster on the rear face (+Z). Caller supplies
## the shell dimensions; no extra glass transparency or lighting is introduced.
static func dashboard(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat := "plastic", col = null, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._add(mount, BevelMesh.make(size, minf(size.y, size.z) * 0.12), mat, col, Vector3.ZERO)
	for i in 3:
		var r := minf(size.y * 0.26, size.x * 0.045)
		var p := Vector3(-size.x * 0.25 + (i - 1) * r * 2.5, 0, size.z * 0.505)
		VehicleBody.cylinder(k, mount, r * 1.12, r * 1.12, 0.008, p, Vector3(PI / 2, 0, 0), "metal_dark", null, 12, false, true, false)
		if not k.burnt:
			VehicleBody.cylinder(k, mount, r, r, 0.003, p + Vector3(0, 0, 0.005), Vector3(PI / 2, 0, 0), "plain_dark", null, 12, false, true, false)
			VehicleBody.rod(k, mount, p + Vector3(0, 0, 0.008), p + Vector3(-r * 0.4, r * 0.5, 0.008), r * 0.05, "paint", Color(0.7, 0.72, 0.65), 4, false, -1.0, false, false)
	k._fold(mount)

## Torus rim, three spokes and hub; torus convention has local Y as the axis.
static func steering_wheel(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, rotation: Vector3, mat := "rubber", col = null) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._add(mount, Res.torus(radius * 0.84, radius), mat, col, Vector3.ZERO)
	for i in 3:
		var a := TAU * i / 3.0
		VehicleFrames.beam(k, mount, Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * radius * 0.87, radius * 0.1, radius * 0.12, "metal_dark", null, false)
	VehicleBody.cylinder(k, mount, radius * 0.24, radius * 0.24, radius * 0.18, Vector3.ZERO, Vector3.ZERO, mat, col, 12, false)
	k._fold(mount)
