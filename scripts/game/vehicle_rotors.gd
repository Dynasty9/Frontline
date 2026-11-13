class_name VehicleRotors
extends RefCounted
## Airfoil blades and articulated hub fittings shared by helicopter families.
## The assembly preserves each aircraft's rotor pivots and blur contract.

static func _rbox(k: VehicleModels, p: Node3D, base: Basis, size: Vector3, pos: Vector3, mat: String, col = null, rot := Vector3.ZERO, shadow := true, origin := Vector3.ZERO) -> Variant:
	return k._box(p, size, origin + base * pos, mat, col, (base * Basis.from_euler(rot)).get_euler(), shadow)

## Local +Z is span, X chord, Y thickness. The root is thick and pitched;
## the outer blade twists flatter and bends gently down to its tip.
static func blade(k: VehicleModels, parent: Node3D, root: float, radius: float, chord: float, tip: int, col: Color) -> void:
	var sections: Array = []
	var edges: Array[Vector3] = []
	var profile := [Vector2(-0.5, 0), Vector2(-0.42, 0.055), Vector2(-0.15, 0.075), Vector2(0.2, 0.045), Vector2(0.5, 0.005), Vector2(0.2, -0.025), Vector2(-0.15, -0.04), Vector2(-0.42, -0.03)]
	for t: float in [0.0, 0.08, 0.55, 0.82, 0.94, 1.0]:
		var taper := lerpf(0.92, 0.72, t)
		if tip == 2 and t >= 0.82 and t < 1.0:
			taper = 1.28
		var sweep := chord * (maxf(0.0, t - 0.82) / 0.18) * (0.7 if tip > 0 else 0.08)
		var twist := Basis(Vector3.BACK, lerpf(0.13, 0.025, t))
		var center := Vector3(sweep, -radius * 0.009 * t * t, lerpf(root, radius, t))
		var ring := PackedVector3Array()
		for point: Vector2 in profile:
			ring.append(center + twist * Vector3(point.x * chord * taper, point.y * chord, 0))
		sections.append(ring)
		edges.append(ring[1])
	var key := "rotor_airfoil_%s_%s_%s_%d" % [root, radius, chord, tip]
	k._add(parent, VehicleModels.solid(sections, key), "rotor", col, Vector3.ZERO)
	# Narrow erosion protection follows the shaped leading edge, not a straight
	# floating box. A muted tip panel makes the swept end readable when stopped.
	for i in range(1, edges.size() - 1):
		VehicleFrames.beam(k, parent, edges[i], edges[i + 1], chord * 0.035, chord * 0.018, "steel", Color(0.3, 0.31, 0.29), false)
	var tip_ring: PackedVector3Array = sections[-2]
	var end_ring: PackedVector3Array = sections[-1]
	var stripe: Array = []
	for fraction: float in [0.40, 0.72]:
		var ring := PackedVector3Array()
		for i in tip_ring.size():
			ring.append(tip_ring[i].lerp(end_ring[i], fraction) + Vector3(0, chord * 0.003, 0))
		stripe.append(ring)
	k._add(parent, VehicleModels.solid(stripe, key + "_tip"), "rotor", Color(0.48, 0.47, 0.39), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	k._box(parent, Vector3(chord * 0.95, chord * 0.18, chord * 0.5), Vector3(0, 0, root + chord * 0.15), "gunmetal_w")

static func main(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float, main := true, phase := 0.0, droop := 0.02, hub := 0.28, tip := 0, bcol = null) -> Node3D:
	var rp := k._pivot(p, pos)
	var bl := k._pivot(rp, Vector3.ZERO)
	# The hub's drums keep their facets (a rotor head's round edge is what the
	# camera sees), on one band of sides each.
	VehicleBody.cylinder(k, rp, hub, hub * 1.05, 0.2, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, maxi(nb * 2, 10))
	VehicleBody.cylinder(k, rp, hub * 0.55, hub * 0.7, 0.16, Vector3(0, 0.17, 0), Vector3.ZERO, "gunmetal_w", null, 10)
	var bc: Color = bcol if bcol is Color else Color(0.15, 0.155, 0.16)
	var grip := minf(0.2 + r * 0.06, 0.75)
	for i in nb:
		var bs := Basis.from_euler(Vector3(droop, phase + TAU * float(i) / float(nb), 0))
		# the grip and pitch horn on the hub (they stay with the blur)
		_rbox(k, rp, bs, Vector3(c * 0.75, 0.1 + c * 0.12, grip), Vector3(0, 0, hub + grip * 0.5 - 0.02), "gunmetal_w")
		_rbox(k, rp, bs, Vector3(0.05, 0.05, 0.16), Vector3(c * 0.42, -0.06, hub + 0.06), "steel", null, Vector3.ZERO, false)
		var r0 := hub + grip - 0.04
		var mount := k._pivot(bl, Vector3.ZERO)
		mount.basis = bs
		blade(k, mount, r0, r, c, tip, bc)
		k._fold(mount)
		# Forked grips, vertical hinge pins and pitch links remain with the hub
		# when the explicit blades switch to the existing blur disc.
		for side in [-1.0, 1.0]:
			_rbox(k, rp, bs, Vector3(c * 0.12, 0.08, grip * 0.82), Vector3(side * c * 0.34, 0.10, hub + grip * 0.48), "steel", Color(0.29, 0.30, 0.28))
		var pin := bs * Vector3(0, 0.17, hub + grip * 0.65)
		VehicleBody.cylinder(k, rp, c * 0.14, c * 0.14, 0.07, pin, Vector3.ZERO, "steel", Color(0.4, 0.41, 0.38), 12, false)
		# (the pitch link's foot is in the swashplate)
		VehicleBody.rod(k, rp, bs * Vector3(c * 0.43, -0.23, hub * 0.65), bs * Vector3(c * 0.43, 0.03, hub + grip * 0.30), c * 0.035, "steel", Color(0.4, 0.41, 0.38), 8, true, -1.0, false)
	# Stepped swashplate, mast collar and evenly spaced hub fasteners.
	VehicleBody.cylinder(k, rp, hub * 1.28, hub * 1.28, 0.055, Vector3(0, -0.22, 0), Vector3.ZERO, "steel", Color(0.32, 0.33, 0.30), 24)
	VehicleBody.cylinder(k, rp, hub * 0.86, hub * 0.86, 0.07, Vector3(0, -0.15, 0), Vector3.ZERO, "gunmetal_w", null, 24)
	# (each bolt's foot is in the hub's top)
	for i in nb * 2:
		var angle := TAU * i / float(nb * 2)
		VehicleBody.cylinder(k, rp, hub * 0.075, hub * 0.075, 0.035, Vector3(sin(angle) * hub * 0.82, 0.115, cos(angle) * hub * 0.82), Vector3.ZERO, "steel", Color(0.39, 0.4, 0.37), 6, false, true, false)
	if not k.burnt:
		var blur := MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(r, r) * 2.0
		blur.mesh = disc
		blur.material_override = VehicleModels._blur_mat()
		Mats.set_inst(blur, &"blade_count", float(nb))
		# (the disc in the blades' own paint)
		Mats.set_inst(blur, &"blade_tint", bc)
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blur.position = Vector3(0, 0.06, 0)
		blur.visible = false
		rp.add_child(blur)
		if main:
			k.blur = blur
		else:
			blur.name = "Blur"
	if main:
		k.rotor = rp
		k.blades = bl
	else:
		bl.name = "Blades"
		k.rotors.append(rp)
	return rp


## A tail rotor spinning about X at pos: n blades of radius r, chord c.
static func tail(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float, side := 1.0, phase := 0.4) -> Node3D:
	var tr := k._pivot(p, pos)
	VehicleBody.cylinder(k, tr, 0.05, 0.08, 0.2, Vector3(side * 0.04, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	VehicleBody.cylinder(k, tr, 0.035, 0.035, 0.12, Vector3(side * 0.17, 0, 0), Vector3(0, 0, PI / 2), "steel", null, 8, false)
	for i in nb:
		var mount := k._pivot(tr, Vector3(side * 0.07, 0, 0))
		mount.basis = Basis.from_euler(Vector3(phase + TAU * float(i) / float(nb), 0, 0)) * Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
		blade(k, mount, 0.07, r, c, 0, Color(0.15, 0.155, 0.16))
		k._fold(mount)
	k.tail_rotor = tr
	return tr

## Rotor mast between the gearbox and the hub: the old shaft cylinder's centre,
## radii and height, with a bearing housing at its foot and drive splines up
## the shaft. `collars` are Vector2(y, radius) in the parent's space: bolted
## flanges such as the swashplate guide and the coaxial rotors' separator.
static func mast(k: VehicleModels, parent: Node3D, center: Vector3, top_radius: float, bottom_radius: float, height: float, collars: Array = []) -> void:
	# (the shaft's foot is inside its bearing housing)
	VehicleBody.cylinder(k, parent, top_radius, bottom_radius, height, center, Vector3.ZERO, "gunmetal_w", null, 12, true, true, false)
	var foot := minf(0.07, height * 0.16)
	VehicleBody.cylinder(k, parent, bottom_radius * 1.22, bottom_radius * 1.32, foot, center + Vector3(0, -height * 0.5 + foot * 0.5, 0), Vector3.ZERO, "metal_dark", null, 12)
	for i in 4:
		var a := TAU * (i + 0.25) / 4.0
		var n := Vector3(cos(a), 0, sin(a))
		var low := center + Vector3(0, -height * 0.5 + foot, 0) + n * bottom_radius * 0.98
		var high := center + Vector3(0, height * 0.42, 0) + n * lerpf(bottom_radius, top_radius, 0.92) * 0.98
		VehicleFrames.beam(k, parent, low, high, minf(0.02, top_radius * 0.16), minf(0.012, top_radius * 0.1), "steel", null, false)
	for collar: Vector2 in collars:
		var thickness := clampf(collar.y * 0.18, 0.04, 0.06)
		var at := Vector3(center.x, collar.x, center.z)
		VehicleBody.cylinder(k, parent, collar.y, collar.y * 1.03, thickness, at, Vector3.ZERO, "steel", null, 14)
		for i in 6:
			var a := TAU * i / 6.0
			VehicleBody.fastener(k, parent, at + Vector3(cos(a) * collar.y * 0.74, thickness * 0.5 + 0.002, sin(a) * collar.y * 0.74), Vector3.UP, clampf(collar.y * 0.06, 0.006, 0.014))

## A rotor hub's cap, the fairing over the head that turns with it: the old
## cap cylinder's centre, top and bottom radii, height and facet count, in
## the rotor pivot's own space (Y up). Built on the caller's rotor pivot, it
## spins with the hub main() drew and registers nothing. A bolted flange
## round its foot, the shell above, a domed crown inside the old height or,
## without `dome`, a flat chamfered top (keep a faceted fairing of eight
## sides or fewer flat-topped, as it was). `upper` = (top radius, bottom
## radius, height) stacks a second tier on the first's top (a two-step
## faceted fairing); the crown then crowns that. `arms` > 0 adds a bifilar
## vibration absorber on the crown: that many arms reaching `reach` from the
## axis, the first `phase` radians from +Z toward +X (as main() counts its
## blades), each swinging a pendulum weight on its two pins.
static func hub_cap(k: VehicleModels, rotor: Node3D, center: Vector3, top_radius: float, bottom_radius: float, height: float, segments := 10, mat := "gunmetal_w", col = null, dome := true, upper := Vector3.ZERO, arms := 0, reach := 0.0, phase := 0.0) -> void:
	var m := k._pivot(rotor, center)
	var y0 := -height * 0.5
	var y1 := height * 0.5
	var flange := minf(height * 0.14, 0.04)
	var ledge := lerpf(bottom_radius, top_radius, flange / height) * 0.96
	# (each flat step rises 2 mm toward the axis, so the loft can tell which
	# way it faces)
	var prof := [Vector2(bottom_radius, y0), Vector2(bottom_radius, y0 + flange), Vector2(ledge, y0 + flange + 0.002)]
	var lower := Vector2(ledge, y0 + flange + 0.002)
	var crown := Vector2(top_radius, y1)
	if not upper.is_zero_approx():
		prof.append(Vector2(top_radius, y1))
		if absf(upper.y - top_radius) > 0.002:
			prof.append(Vector2(upper.y, y1 + 0.002))
		lower = Vector2(upper.y, y1 + 0.002)
		crown = Vector2(upper.x, y1 + upper.z)
	if dome:
		var rise := minf((crown.y - lower.y) * 0.35, crown.x * 0.6)
		var yd := crown.y - rise
		var rd := lerpf(lower.x, crown.x, (yd - lower.y) / maxf(crown.y - lower.y, 0.001))
		prof.append_array([Vector2(rd, yd), Vector2(rd * 0.77, yd + rise * 0.64), Vector2(rd * 0.34, yd + rise * 0.94), Vector2(0, crown.y)])
	else:
		var chamfer := minf(crown.x * 0.08, 0.015)
		prof.append_array([Vector2(crown.x, crown.y - chamfer), Vector2(crown.x - chamfer, crown.y - 0.002), Vector2(0, crown.y)])
	# lofted through polygons laid out as a CylinderMesh lays its sides (the
	# first corner toward +Z): eight sides or fewer stay crisp facets, ten or
	# more read round
	var rings := []
	for q: Vector2 in prof:
		var ring := PackedVector3Array()
		for j in segments:
			var a := TAU * float(j) / float(segments)
			ring.append(Vector3(sin(a) * q.x, q.y, cos(a) * q.x))
		rings.append(ring)
	k._add(m, VehicleProfiles.loft(rings, 40.0), mat, col, Vector3.ZERO)
	# the flange's bolts, one to a facet (every other on a rounder cap)
	var bolts := segments if segments <= 8 else segments >> 1
	var circle := (bottom_radius + ledge) * 0.5 * cos(PI / float(segments))
	for i in bolts:
		var a := (float(i) * float(segments) / float(bolts) + 0.5) * TAU / float(segments)
		VehicleBody.fastener(k, m, Vector3(sin(a) * circle, y0 + flange + 0.004, cos(a) * circle), Vector3.UP, clampf(bottom_radius * 0.035, 0.005, 0.014))
	if arms > 0 and reach > 0.0:
		var depth := clampf(reach * 0.12, 0.03, 0.07)
		var arm_y := crown.y - depth * 0.5
		var weight := reach * 0.17
		for i in arms:
			var a := phase + TAU * float(i) / float(arms)
			var d := Vector3(sin(a), 0, cos(a))
			var across := Vector3(cos(a), 0, -sin(a))
			VehicleFrames.beam(k, m, Vector3(0, arm_y, 0) + d * crown.x * 0.3, Vector3(0, arm_y, 0) + d * reach, depth * 1.3, depth, "gunmetal_w", null, false, true)
			var at := Vector3(0, arm_y - weight * 0.4, 0) + d * reach
			VehicleBody.cylinder(k, m, weight, weight, weight * 1.6, at, Vector3.ZERO, "gunmetal_w", null, 10)
			for side: float in [-1.0, 1.0]:
				VehicleBody.fastener(k, m, at + across * side * weight * 0.45 + Vector3(0, weight * 0.8 + 0.003, 0), Vector3.UP, weight * 0.16)
	k._fold(m)
