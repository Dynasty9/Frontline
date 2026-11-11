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
	k._cyl(rp, hub, hub * 1.05, 0.2, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, maxi(nb * 2, 10))
	k._cyl(rp, hub * 0.55, hub * 0.7, 0.16, Vector3(0, 0.17, 0), Vector3.ZERO, "gunmetal_w", null, 10)
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
		k._cyl(rp, c * 0.14, c * 0.14, 0.07, pin, Vector3.ZERO, "steel", Color(0.4, 0.41, 0.38), 12, false)
		VehicleFrames.tube(k, rp, bs * Vector3(c * 0.43, -0.23, hub * 0.65), bs * Vector3(c * 0.43, 0.03, hub + grip * 0.30), c * 0.035, "steel", Color(0.4, 0.41, 0.38), 8)
	# Stepped swashplate, mast collar and evenly spaced hub fasteners.
	k._cyl(rp, hub * 1.28, hub * 1.28, 0.055, Vector3(0, -0.22, 0), Vector3.ZERO, "steel", Color(0.32, 0.33, 0.30), 24)
	k._cyl(rp, hub * 0.86, hub * 0.86, 0.07, Vector3(0, -0.15, 0), Vector3.ZERO, "gunmetal_w", null, 24)
	for i in nb * 2:
		var angle := TAU * i / float(nb * 2)
		k._cyl(rp, hub * 0.075, hub * 0.075, 0.035, Vector3(sin(angle) * hub * 0.82, 0.115, cos(angle) * hub * 0.82), Vector3.ZERO, "steel", Color(0.39, 0.4, 0.37), 6, false)
	if not k.burnt:
		var blur := MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(r, r) * 2.0
		blur.mesh = disc
		blur.material_override = VehicleModels._blur_mat()
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
	k._cyl(tr, 0.05, 0.08, 0.2, Vector3(side * 0.04, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	k._cyl(tr, 0.035, 0.035, 0.12, Vector3(side * 0.17, 0, 0), Vector3(0, 0, PI / 2), "steel", null, 8, false)
	for i in nb:
		var mount := k._pivot(tr, Vector3(side * 0.07, 0, 0))
		mount.basis = Basis.from_euler(Vector3(phase + TAU * float(i) / float(nb), 0, 0)) * Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
		blade(k, mount, 0.07, r, c, 0, Color(0.15, 0.155, 0.16))
		k._fold(mount)
	k.tail_rotor = tr
	return tr
