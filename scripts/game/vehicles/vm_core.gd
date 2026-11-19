class_name VmCore
extends RefCounted
## Procedural models: the core roster - the vehicles every match fields (the
## M1A2 SEP, the T-55A, the Hilux technicals, the M1151, the M2A3 Bradley, the
## BTR-80, the AH-64D and the UH-60) and the fallback convoy truck.
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys unique, "core_" prefixed).
##
## These models stand in for the originals in vehicle_models.gd, so they keep
## those builders' contracts: the same k.turret / k.gun_tip / k.mg_tip per
## key, every road wheel and tyre in k.wheels, the helicopters' rotor, blades,
## blur disc and tail rotor. Footprints stay close to the keys' Defs sizes: the
## Abrams and the Bradley are built a touch under full scale (0.9), the two
## helicopters at 0.65 (as the originals were), the rest at full scale.

## Every model key this file builds.
## ("m35" is the fallback truck on its own, whoever's convoy it is.)
const KEYS: Array[String] = ["tank", "old_tank", "technical", "aa_tech", "humvee", "ifv", "btr", "apc", "gunship", "heli", "truck", "m35"]

const X90 := Vector3(PI / 2, 0, 0)  # a cylinder lying along Z (barrels)
const Z90 := Vector3(0, 0, PI / 2)  # a cylinder lying along X (axles, wheels)
const GUN := Color(0.3, 0.32, 0.24)  # painted gun barrels, thermal sleeves
const OD := Color(0.3, 0.32, 0.22)  # olive drab: ammo cans, jerrycans
const BAG := Color(0.38, 0.37, 0.27)  # canvas bags and covers
const TAN_BAG := Color(0.45, 0.42, 0.35)  # coyote kit: a greyish tan, which the warm sun would turn orange were it any yellower
const TAN_BAG_WRECK := Color(0.47, 0.42, 0.31)  # (the old sand a wreck keeps: its roll's straps take the tint)


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"tank":
			_abrams(k, team, seed)
		"old_tank":
			_t55(k, team, seed)
		"technical":
			_hilux(k, team, seed, false)
		"aa_tech":
			_hilux(k, team, seed, true)
		"humvee":
			_humvee(k, team, seed)
		"ifv":
			_bradley(k, team, seed)
		"btr", "apc":
			_btr80(k, team, seed)
		"gunship":
			_apache(k, team)
		"heli":
			_blackhawk(k, team)
		"truck":
			# the convoy proper is the HEMTT or the Zamak (as the original did)
			if not ((team == 0 and VmNato.build(k, "hemtt_cargo", team, seed)) or (team == 1 and VmIndep.build(k, "zamak_cargo", team, seed))):
				_truck(k, team)
		"m35":
			_truck(k, team)
		_:
			return false
	return true


# --- shared helpers ------------------------------------------------------------------

static func _cam(team: int) -> String:
	return "camo_tank" if team != 1 else "camo_tank_rebel"


static var _plain := {}


## k._box, but a small part (under 4 cm thick somewhere) gets a plain box:
## its chamfers wouldn't show, and a bevelled box costs four times the
## vertices - these models stand on the battlefield by the dozen.
static func _bx(k: VehicleModels, p: Node3D, s: Vector3, pos: Vector3, mat: String, col = null, rot := Vector3.ZERO, shadow := true) -> Variant:
	if minf(s.x, minf(s.y, s.z)) >= 0.04:
		return k._box(p, s, pos, mat, col, rot, shadow)
	var key := "%.3f,%.3f,%.3f" % [s.x, s.y, s.z]
	if not _plain.has(key):
		var bm := BoxMesh.new()
		bm.size = s
		_plain[key] = bm
	return k._add(p, _plain[key], mat, col, pos, rot, Vector3.ONE, shadow)


## The Euler rotation that turns +Y onto direction d.
static func _aim(d: Vector3) -> Vector3:
	var u := d.normalized()
	if u.dot(Vector3.UP) < -0.9999:
		return Vector3(PI, 0, 0)
	if u.dot(Vector3.UP) > 0.9999:
		return Vector3.ZERO
	return Basis(Quaternion(Vector3.UP, u)).get_euler()


## A round bar from a to b (radius r, or r at a and rb at b).
static func _tube(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 8, shadow := true, rb := -1.0) -> Variant:
	return VehicleFrames.tube(k, p, a, b, r, mat, col, segs, shadow, rb)


## A tube along a polyline, the joints rounded.
static func _path(k: VehicleModels, p: Node3D, pts: Array, r: float, mat: String, col = null, segs := 8) -> void:
	VehicleFrames.path(k, p, pts, r, mat, col, segs)


## A square-section bar from a to b, w across (kept level where it can be), t thick.
static func _bar(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, w: float, t: float, mat: String, col = null, shadow := true) -> Variant:
	return VehicleFrames.beam(k, p, a, b, w, t, mat, col, shadow, true)


## A plate lying on a face seen side-on: its length from a to b ((z, y)
## points), centred on x, w wide, t thick, pushed `push` out along the face's
## normal (outward is up/forward when a -> b climbs a front face toward the back).
static func _zy(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, t: float, push: float, mat: String, col = null, shadow := true) -> Variant:
	var d := b - a
	var dn := d.normalized()
	var n := Vector2(-dn.y, dn.x)
	var c := (a + b) * 0.5 + n * (push + t * 0.5)
	return _bx(k, p, Vector3(w, d.length(), t), Vector3(x, c.y, c.x), mat, col, Vector3(atan2(d.x, d.y), 0, 0), shadow)


## A box lying flat on a face: local x along ex, y along ey (squared up), its
## thickness standing out of the face toward `out`; surf the point under its centre.
static func _on_face(k: VehicleModels, p: Node3D, surf: Vector3, ex: Vector3, ey: Vector3, out: Vector3, size: Vector3, mat: String, col = null, shadow := true) -> Variant:
	var x := ex.normalized()
	var z := x.cross(ey).normalized()
	if z.dot(out) < 0.0:
		z = -z
		x = -x
	var y := z.cross(x)
	return _bx(k, p, size, surf + z * size.z * 0.5, mat, col, Basis(x, y, z).get_euler(), shadow)


## Rings for VehicleModels.solid from plan outlines (x, z pairs) at heights.
static func _rings(outlines: Array, ys: Array) -> Array:
	var r := []
	for i in outlines.size():
		r.append(VehicleModels.ring_y(VehicleModels._v2(outlines[i]), ys[i]))
	return r


## A ring across x at z from (x, y) pairs.
static func _rz(pairs: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, pairs.size(), 2):
		r.append(Vector3(pairs[i], pairs[i + 1], z))
	return r


## A weld run along `points` (Vector3s; a closed loop repeats its first point
## last). Armour plate is welded at its joints, and the bead's round section
## riding a lofted hull's sharp edge catches the light along it as a real
## welded, ground edge does, where a dead-sharp corner reads as CG.
static func _weld(k: VehicleModels, p: Node3D, points: Array, mat: String, col = null, r := 0.016) -> void:
	VehicleBody.bead(k, p, points, r, mat, col, 6, false)


## The points of a plan outline ((x, z) pairs) at height y, closed: a weld
## round a roof's edge or a cover plate's foot.
static func _loop_y(pairs: Array, y: float) -> Array:
	var pts := []
	for i in range(0, pairs.size(), 2):
		pts.append(Vector3(pairs[i], y, pairs[i + 1]))
	pts.append(pts[0])
	return pts


## A weld round a roof's edge, seated in the joint: the plan outline ((x, z)
## pairs, convex) at height y moved in by `inset` and down by `drop`, closed.
## A fillet weld fills the corner where the roof plate meets the side or the
## glacis, its bead standing a few millimetres proud of both; centred on the
## corner (as _loop_y lays it) the default bead stood out of the edge like a
## pipe laid along it, an elbow at every corner. `open` keeps only the
## outline's points from `first` on, that many of them, unclosed: a run
## along part of the edge.
static func _seated(pairs: Array, y: float, inset := 0.008, drop := 0.01, first := 0, open := 0) -> Array:
	var d := []
	for i in pairs.size() >> 1:
		d.append(inset)
	var q := VehicleWheelArches._inset(VehicleModels._v2(pairs), d)
	var pts := []
	var count := open if open > 0 else q.size()
	for i in count:
		var v := q[(first + i) % q.size()]
		pts.append(Vector3(v.x, y - drop, v.y))
	if open <= 0:
		pts.append(pts[0])
	return pts


## A cover plate welded flat on a roof: the plan outline ((x, z) pairs,
## convex), t thick standing on y, with the weld round its foot. The roof
## plates over a tank's armour cavities and its blow-off panels are such
## plates; their raised edge and weld are what a turret roof's breakup reads
## as from above.
static func _cover(k: VehicleModels, p: Node3D, key: String, outline: Array, y: float, t: float, mat: String, col = null) -> void:
	k._add(p, VehicleModels.loft(key, outline, outline, y - 0.004, y + t, 0.01), mat, col, Vector3.ZERO)
	_weld(k, p, _loop_y(outline, y), mat, col, minf(0.012, t * 0.6))


## Armoured glass: inches of laminate, green-blue through its depth where a
## windscreen's thin pane is near black.
const ARMOR_GLASS := Color(0.08, 0.13, 0.13)


## A tactical number stencilled on a flat face: `text` h tall, centred on
## `center` (a point on the face), reading along `along` as seen from outside,
## `out` the face's outward normal (VehicleMarkings.face_text: heavy stencil
## bars, gone with the paint on a wreck). Crews paint these big on turret and
## hull sides so a commander can tell his vehicles apart; from the RTS camera
## they're the detail that reads. The US Army's are CARC sand (`col`), as its
## chevrons are.
static func _stencil(k: VehicleModels, p: Node3D, text: String, h: float, center: Vector3, along: Vector3, out: Vector3, col := VehicleMarkings.STENCIL_SAND) -> void:
	VehicleMarkings.face_text(k, p, text, h, center, along, out, col)


## Exhaust soot, streaked back along a face from an outlet by the slipstream:
## a smear tapering away from it (VehicleMarkings, gone with the paint on a
## wreck), laid on the plane through `origin` (the outlet's trailing edge)
## spanned by `along` (the way the exhaust trails) and `up`, `out` the
## face's outward normal; `length` long, `height` tall at the outlet.
static func _soot(k: VehicleModels, p: Node3D, origin: Vector3, along: Vector3, up: Vector3, out: Vector3, length: float, height: float) -> void:
	# Soot thins into the paint toward its edges: VehicleBody.soot's graded
	# films, which carry the hull's camouflage through the faint outer ones
	# (two flat grey and black films ended in a hard line on the paint). Its
	# outermost film runs 1.18 x as long and 1.3 x as tall as the size it's
	# given, so it is given less, to cover the plate it was fitted to.
	VehicleBody.soot(k, p, origin, along, up, out, length / 1.18, height / 1.3)


## A chamfered rectangle (x0..x1, z0..z1) as plan outline pairs.
static func _oct(x0: float, x1: float, z0: float, z1: float, c: float) -> Array:
	return [x0 + c, z0, x1 - c, z0, x1, z0 + c, x1, z1 - c, x1 - c, z1, x0 + c, z1, x0, z1 - c, x0, z0 + c]


const DISHED_PRESSING := -1
static var _wheel_discs := {}


## The outer pressing dips behind its lip and rises again at the hub. The
## radial ribs are part of the surface, so they turn through light and shade.
static func _wheel_disc(spokes: int) -> ArrayMesh:
	if _wheel_discs.has(spokes):
		return _wheel_discs[spokes]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Radius, offset along the axle, and additional height on the crest of a rib.
	var rings := [Vector3(0.17, 0.18, 0), Vector3(0.29, 0.14, 0.015),
		Vector3(0.46, 0.016, 0.12), Vector3(0.66, 0.012, 0.10),
		Vector3(0.75, 0.065, 0.025), Vector3(0.79, 0.10, 0), Vector3(0.83, 0.025, 0)]
	if spokes == DISHED_PRESSING:
		rings = [Vector3(0.16,0.23,0), Vector3(0.32,0.19,0), Vector3(0.39,-0.015,0),
			Vector3(0.55,-0.12,0), Vector3(0.68,-0.09,0), Vector3(0.75,0.015,0),
			Vector3(0.81,0.13,0), Vector3(0.86,0.14,0), Vector3(0.88,0.04,0)]
	var segments := 48
	for ring: Vector3 in rings:
		for j in segments:
			var a := TAU * j / segments
			var ridge := pow(0.5 + 0.5 * cos(a * spokes), 3.0) if spokes > 0 else 0.0
			surface.add_vertex(Vector3(ring.y + ridge * ring.z, ring.x * sin(a), ring.x * cos(a)))
	for i in rings.size() - 1:
		for j in segments:
			var a := i * segments + j
			var b := i * segments + (j + 1) % segments
			for idx: int in [a, a + segments, b, b, a + segments, b + segments]:
				surface.add_index(idx)
	surface.generate_normals()
	var mesh := surface.commit()
	_wheel_discs[spokes] = mesh
	return mesh


static var _tyre_mesh: ArrayMesh


## The rubber band leaves room behind the lip for the recessed wheel pressing.
static func _hollow_tyre() -> ArrayMesh:
	if _tyre_mesh != null:
		return _tyre_mesh
	var tyre := SurfaceTool.new()
	tyre.begin(Mesh.PRIMITIVE_TRIANGLES)
	var section := [Vector2(-0.5,0.80),Vector2(-0.5,0.94),Vector2(-0.44,0.989),
		Vector2(-0.34,1.0),Vector2(0.34,1.0),Vector2(0.44,0.989),Vector2(0.5,0.94),Vector2(0.5,0.80)]
	var sides := 40
	for p: Vector2 in section:
		for j in sides:
			var a := TAU * j / sides
			tyre.add_vertex(Vector3(p.x, p.y * sin(a), p.y * cos(a)))
	for i in section.size():
		for j in sides:
			var a := i * sides + j
			var b := i * sides + (j + 1) % sides
			var c := ((i + 1) % section.size()) * sides + j
			var d := ((i + 1) % section.size()) * sides + (j + 1) % sides
			for index: int in [a, b, c, b, d, c]:
				tyre.add_index(index)
	tyre.generate_normals()
	_tyre_mesh = tyre.commit()
	return _tyre_mesh


## Twin tyres leave a passage for the guide horns between the wheels.
static func _road_wheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null, spokes := 0) -> Node3D:
	var pv := k._pivot(p, pos)
	pv.set_meta(&"radius", r)
	for sx: float in [-1.0, 1.0]:
		if spokes == DISHED_PRESSING:
			k._add(pv, _hollow_tyre(), "rubber", null, Vector3(sx * w * 0.3, 0, 0), Vector3.ZERO, Vector3(w * 0.4, r, r))
		else:
			k._cyl(pv, r, r, w * 0.4, Vector3(sx * w * 0.3, 0, 0), Z90, "rubber", null, 32)
	var ox := signf(pos.x)
	var face := ox * (w * 0.5 + 0.002)
	var rot := Vector3.UP * (PI if ox < 0 else 0.0)
	k._add(pv, _wheel_disc(spokes), mat, col, Vector3(face, 0, 0), rot, Vector3.ONE * r)
	k._cyl(pv, r * 0.20, r * 0.20, w + r * 0.40, Vector3.ZERO, Z90, mat, col, 16)
	for i in 8:
		var a := TAU * i / 8.0
		k._cyl(pv, r * 0.032, r * 0.032, r * 0.044, Vector3(face + ox * r * 0.16, sin(a) * r * 0.27, cos(a) * r * 0.27), Z90, "gunmetal_w", null, 6, false)
		if spokes == DISHED_PRESSING:
			# Outer fasteners catch the light along the rim of the dished pressing.
			k._cyl(pv, r * 0.040, r * 0.043, r * 0.070, Vector3(face - ox * r * 0.07, sin(a) * r * 0.675, cos(a) * r * 0.675), Z90, "gunmetal_w", Color("68604e"), 6, false)
	if spokes == DISHED_PRESSING:
		k._add(pv, Res.sphere(1, 16), "gunmetal_w", Color("49483e"), Vector3(face + ox * r * 0.18, 0, 0), Vector3.ZERO, Vector3(0.075, 0.16, 0.16) * r)
	k.wheels.append(pv)
	return pv


## A toothed drive sprocket spinning about x.
static func _sprocket(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null, teeth := 11) -> Node3D:
	var pv := VehicleWheels.sprocket(k, p, pos, r, w, mat, col, teeth)
	pv.set_meta(&"radius", r)
	pv.set_meta(&"teeth", teeth)
	return pv


## A steel idler wheel spinning about x: the road wheels' twin pressed discs
## with their hub and bolt circle (VehicleWheels.road), but steel-rimmed where
## a road wheel is tyred, since the idler only tensions the track and runs on
## the links' inner faces. Built the road wheels' way, it reads as one of the
## set from the battle camera instead of a smooth drum of another make.
static func _idler(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	var pv := VehicleWheels.road(k, p, pos, r, w, mat, col, 0, false)
	pv.set_meta(&"radius", r)
	return pv


## A track: a belt of link plates round the convex hull of its wheels (each
## circle (z, y, r)) at x, w wide, th thick. A return run without rollers
## sits on the road wheels, with its guide horns visible in the gaps.
static func _belt(k: VehicleModels, p: Node3D, x: float, w: float, circles: Array, th := 0.08, rests_on_wheels := false) -> void:
	var pts := PackedVector2Array()
	for c in circles:
		var cv: Vector3 = c
		var rr := cv.z + th * 0.5
		# Include the bottom tangent. An inscribed polygon between samples
		# leaves daylight under every pad, even on a perfectly flat road.
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(Vector2(cv.x + cos(a) * rr, cv.y + sin(a) * rr))
	var hull := Geometry2D.convex_hull(pts)
	if not k.burnt:
		var belt := preload("res://scripts/game/vehicles/track_belt.gd").new()
		belt.position.x = x
		p.add_child(belt)
		belt.build(VehicleTracks.on_rollers(k, hull, circles, th * 0.5), w, th, k.wheels, rests_on_wheels)
		k.belts.append(belt)
		return
	# The wreck keeps its kind of track: the T-55's (the one whose return run
	# rests on its wheels) is cast single-pin steel, the Abrams' and Bradley's
	# double-pin with rubber pads and centre guides.
	VehicleTracks.shoes(k, p, x, w, hull, th, 0.20, not rests_on_wheels, true)


## A headlight facing f (-1 forward, 1 back): housing, lens, wire guard.
static func _lamp(k: VehicleModels, p: Node3D, pos: Vector3, r := 0.08, f := -1.0, guard := true) -> void:
	VehicleFittings.lamp_unit(k, p, pos, Vector3(r * 2.6, r * 2.3, 0.12), f, [r], Rect2(), "cage" if guard else "")


## A tail light cluster (red and amber) facing back.
static func _taillight(k: VehicleModels, p: Node3D, pos: Vector3) -> void:
	VehicleFittings.tail_cluster(k, p, pos)



## A whip antenna on a base.
static func _antenna(k: VehicleModels, p: Node3D, pos: Vector3, h := 2.0) -> void:
	VehicleFittings.antenna(k, p, pos, h)


## A bank of smoke-grenade dischargers: `rows` x `cols` tubes on a bracket,
## the bank turned by yaw (0 faces forward, positive turns it to the left),
## the tubes pitched up.
static func _smoke(k: VehicleModels, p: Node3D, pos: Vector3, yaw: float, cols := 3, rows := 2, pitch := 0.5, r := 0.042) -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
	var tubes := []
	for j in rows:
		for i in cols:
			var fx := (i - (cols - 1) * 0.5) * r * 2.3
			var lp := Vector3(fx, 0.05 + j * r * 2.1, -0.02 + j * 0.03)
			tubes.append(Transform3D(t.basis * Basis.from_euler(Vector3(-PI / 2 + pitch + j * 0.15, fx * 1.2, 0)), t * lp))
	VehicleFittings.smoke_bank(k, p, t * Vector3(0, -0.03, 0.02), Vector3(cols * r * 2.3 + 0.04, 0.06, 0.16), Vector3(0, yaw, 0), tubes, r, 0.22)


## A tow shackle (a U on its pin) at pos, facing f (-1 forward, 1 back).
static func _shackle(k: VehicleModels, p: Node3D, pos: Vector3, f := -1.0) -> void:
	VehicleFittings.tow_shackle(k, p, pos, f)



## A periscope head facing along yaw (0: forward), with its glass.
static func _periscope(k: VehicleModels, p: Node3D, pos: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	VehicleFittings.periscope(k, p, pos, Vector3(0.18, 0.1, 0.12), Vector3(pitch, yaw, 0))



## A round hatch: the ring, the lid, its hinge and handle.
static func _hatch(k: VehicleModels, p: Node3D, pos: Vector3, r: float, mat: String, col = null, hinge_z := 1.0) -> void:
	VehicleFittings.hatch(k, p, pos + Vector3(0, 0.085, 0), r, mat, col, hinge_z)



## A jerrycan standing upright, its broad face toward x (yaw turns it).
static func _jerry(k: VehicleModels, p: Node3D, pos: Vector3, col := OD, yaw := 0.0) -> void:
	VehicleFittings.jerrycan(k, p, pos, col, Vector3(0, yaw, 0))



## An ammo can, its long side along z (yaw turns it).
static func _ammo_can(k: VehicleModels, p: Node3D, pos: Vector3, yaw := 0.0, col := OD) -> void:
	VehicleFittings.ammo_can(k, p, pos, col, Vector3(0, yaw, 0))



## A lifting eye (a small loop) standing on a surface at pos.
static func _eye(k: VehicleModels, p: Node3D, pos: Vector3, yaw := 0.0) -> void:
	VehicleFittings.lifting_eye(k, p, pos, yaw)


## The crew's kit on a stretch of bare roof or deck. No tank or carrier in
## the field runs with an empty top: what its crew keeps where they can reach
## it from the hatches is what the battle camera sees of it, a canvas kit bag
## or a tarpaulin bundled in its straps, a pair of ammunition cans, or the
## tow cable coiled flat. `at` is the middle of the free patch on the plate's
## top, `room` its size (x across it, y along `yaw`, the patch's direction
## about the parent's Y), which the caller keeps clear of hatches, sights and
## the guns' sweep; `col` the canvas. One crew in five keeps the patch clear.
## Only on a vehicle with a load of its own (VehicleCargo.kit, salted by
## `salt`): wrecks, burnt hulks and scenery stay as the builders made them.
## On a turret's roof, half the crews who'd carry a bundle carry the tarpaulin
## rolled instead (VehicleCloth.tarp_roll: VehicleCloth.roll's shape without
## its buckles, cheap enough for a roof's worth of kit), lying along the patch
## where the turret's bulk keeps it out of the hatches' way; a hull roof the
## troops climb out over keeps its flat bundles.
static func roof_kit(k: VehicleModels, p: Node3D, at: Vector3, yaw: float, room: Vector2, salt: int, col := BAG) -> void:
	if k.wreck:
		return
	var rng := VehicleCargo.kit(k, p, at, 40 + salt)
	if rng == null:
		return
	var across := Vector3(cos(yaw), 0, -sin(yaw))
	var r := rng.randf()
	if r < 0.2:
		return
	# (on a patch too narrow for two cans side by side their share goes to
	# the bundle, not to a coil a hand across, which read as nothing from
	# above)
	if r >= 0.5 and r < 0.75 and room.x < 0.36 and room.y >= 0.5:
		r = 0.45
	if r < 0.5 and room.y >= 0.5 and _on_turret(k, p) and rng.randf() < 0.5:
		# (a tarp rolled a hand and a half across, its length on a 5 cm
		# step so a few cached rolls serve every turret, in a tarpaulin's
		# shade of the crew's canvas)
		var radius := 0.085
		var length := snappedf(minf(room.y * 0.9, 0.85), 0.05)
		var tint := VehicleCargo.kit_colour(rng, col, VehicleCargo.KIT_TARP, 0.4)
		VehicleCloth.tarp_roll(k, p, at + Vector3.UP * radius, radius, length, Vector3(PI / 2, yaw + rng.randf_range(-0.06, 0.06), 0), tint)
	elif r < 0.5 and room.y >= 0.5:
		# (sizes on a 5 cm step, so a few cached shapes serve every roof; the
		# bundle's length lies along the patch) A crew's bundle is a long
		# roll of bedding and a kit bag lashed together, most of a metre: a
		# 70 cm brick in a shade under the crew's canvas read from the battle
		# camera as a briefcase on a bare roof. It goes in the canvas a little
		# sun-faded, as kit that lives on a roof does.
		var size := Vector3(snappedf(minf(room.y * 0.9, 0.9), 0.05), 0.24, snappedf(minf(room.x * 0.9, 0.45), 0.05))
		k._bag(p, size, at + Vector3.UP * size.y * 0.5, "canvas", col.lightened(0.1), Vector3(0, yaw - PI / 2 + rng.randf_range(-0.08, 0.08), 0))
	elif r < 0.75 and room.x >= 0.36:
		# side by side, lids up, each set down a little askew
		for i in 2:
			VehicleFittings.ammo_can(k, p, at + across * (i - 0.5) * 0.18 + Vector3.UP * 0.1, OD, Vector3(0, yaw + rng.randf_range(-0.07, 0.07), 0))
	else:
		_cable_coil(k, p, at, minf(minf(room.x, room.y) * 0.45, 0.3), rng)


## Whether `p` rides the turret (roof_kit's tarp goes only there).
static func _on_turret(k: VehicleModels, p: Node3D) -> bool:
	var n := p
	while n != null and n != k.root:
		if n == k.turret:
			return true
		n = n.get_parent() as Node3D
	return false


## A steel tow cable coiled flat on a deck as a crew lays it down to keep it
## from kinking: a turn and three quarters of 28 mm wire rope spiralling in
## from `radius`, each turn inside the last, the swaged ferrule of its eye at
## the outer end. `rng` turns the coil.
static func _cable_coil(k: VehicleModels, p: Node3D, at: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	var wire := 0.014
	var start := rng.randf_range(0.0, TAU)
	var route: Array = []
	for i in 23:
		var f := float(i) / 22.0
		var a := start + f * 1.75 * TAU
		var rr := radius * (1.0 - 0.2 * f)
		route.append(at + Vector3(cos(a) * rr, wire, sin(a) * rr))
	VehicleFrames.path(k, p, route, wire, "steel", Color(0.2, 0.21, 0.19), 5, false)
	var a0 := start
	var tangent := Vector3(-sin(a0), 0, cos(a0))
	var end: Vector3 = route[0]
	VehicleFrames.tube(k, p, end - tangent * 0.07, end, wire * 1.5, "steel", Color(0.4, 0.41, 0.38), 6, false)


## The lower side plates of a wheeled carrier, with an arch cut over every
## wheel. On a BTR, an AMV or a Rooikat the hull's sides come down between
## the wheels nearly to the axles and each wheel turns in its own well, the
## plate's edge following the tyre round a hand's breadth clear of it; left
## out, the tyres hang below a flat-bottomed side like a toy's. One plate a
## side from `z0` to `z1`, `y0` to `y1` high (its top tucked into the hull
## over it), `x_in` to `x_out` from the centre line, arches of radius `r` about
## each of `axles` at `axle_y`, each well lined dark from the plate in to
## `liner_in` (inside the tyre's inner wall). Each arch is cut in six
## chords, as an armoured hull's arch is flame-cut and folded from flat plate:
## four read as a polygon round a round tyre from the battle camera, the
## plate's edge standing 5 cm in from the tyre's path mid-chord. (The plate
## is one outline now, VehicleWheelArches._plate, so each chord costs two
## edges, not a strip: six cost less than four did.) `chords` cuts it in
## fewer on a hull whose thin plate shows little of its arch. `liner_in` zero
## leaves the lining out, where the hull already has its own dark well over
## the tyres. A wreck stays as it was.
static func wheel_wells(k: VehicleModels, p: Node3D, key: String, x_in: float, x_out: float, y0: float, y1: float, z0: float, z1: float, axles: Array, axle_y: float, r: float, liner_in: float, mat: String, col = null, chords := 6) -> void:
	if k.wreck:
		return
	var arches := []
	for z: float in axles:
		arches.append([z, axle_y, r])
	var low := asin(clampf((y0 - axle_y) / r, -1.0, 1.0))
	for s: float in [-1.0, 1.0]:
		var xa := s * x_in
		var xb := s * x_out
		VehicleWheelArches._xbody(k, p, "%s_%d" % [key, int(s)], [z0, y0, z1, y0, z1, y1, z0, y1], minf(xa, xb), maxf(xa, xb), 0.015, arches, mat, col, chords, [], 0.0, 0.0)
		if liner_in <= 0.0:
			continue
		# (the lining stops just inside the plate's face, and only where the
		# plate is: an end wheel's arch runs off the plate's end, where its
		# lining would hang in the air like a mudguard)
		var xl := s * (x_out - 0.004)
		var xi := s * liner_in
		for z: float in axles:
			var a0 := maxf(low, acos(clampf((z1 - z) / r, -1.0, 1.0)))
			var a1 := minf(PI - low, acos(clampf((z0 - z) / r, -1.0, 1.0)))
			if a1 > a0 + 0.1:
				# (in as many segments as the plate's arch has chords, so it
				# shows round behind it, not as a polygon of its own)
				VehicleWheelArches.liner(k, p, z, axle_y, r, minf(xi, xl), maxf(xi, xl), a0, a1, chords)



# --- weapons -------------------------------------------------------------------------

## An M2 .50 cal along -Z, its receiver's centre 10 cm behind pos: the shared
## heavy gun with the spade grips of a pintle mount and, with `can`, the ammo
## can on the left. Returns the muzzle.
static func _m2(k: VehicleModels, p: Node3D, pos: Vector3, can := true) -> Vector3:
	return VehicleWeapons.hmg(k, p, pos + Vector3(0, 0, 0.1), pos + Vector3(0, 0, -1.47), 1.0, -1.0 if can else 0.0, true, "gunmetal_w", OD)


## An M240 / PKT-sized machine gun along -Z, receiver at pos: the shared
## general-purpose gun with its butt and, with `can`, the ammo can on the
## left. Returns the muzzle.
static func _mmg(k: VehicleModels, p: Node3D, pos: Vector3, can := true) -> Vector3:
	return VehicleWeapons.mmg(k, p, pos, pos + Vector3(0, 0, -0.93), 1.0, -1.0 if can else 0.0, true, "gunmetal_w", OD)


# --- tank: M1A2 SEP Abrams ---------------------------------------------------------

## M1A2 SEP Abrams (built at 0.9 scale to the Battle Tank's footprint): the
## long hull with its very shallow upper glacis and the driver in the middle
## under the gun, seven road wheels a side under the big bolted skirts (the
## front two heavy armoured panels, the first raked over the idler), the rear
## sprocket, the engine deck grilles and the turbine's exhaust grille across
## the back plate. The welded turret: wide flat slab with the cheek armour
## swept back either side of the recessed gun shield and undercut beneath,
## the gunner's sight doghouse and the CITV on the roof, the commander's .50
## and the loader's M240 behind its shield, M250 smoke dischargers, stowage
## boxes along the sides and the bustle rack round the back; the 120 mm in
## its thermal sleeve with the bore evacuator and the muzzle reference sensor.
static func _abrams(k: VehicleModels, team: int, seed: int) -> void:
	var cam := "abrams_sand" if team == 1 else "abrams_olive"
	var m := k.root
	var roof := 1.42
	# --- running gear: front idler, seven road wheels, rear sprocket
	var tx := 1.3
	var tw := 0.56
	var rw := []
	for i in 7:
		rw.append(-2.2 + i * 0.72)
	for s: float in [-1.0, 1.0]:
		var circles := []
		for z in rw:
			_road_wheel(k, m, Vector3(s * tx, 0.39, z), 0.32, tw * 0.86, cam, null, DISHED_PRESSING)
			circles.append(Vector3(z, 0.39, 0.32))
		_idler(k, m, Vector3(s * tx, 0.6, -2.96), 0.27, tw * 0.8, cam)
		_sprocket(k, m, Vector3(s * tx, 0.64, 2.98), 0.3, tw * 0.8, cam)
		circles.append(Vector3(-2.96, 0.6, 0.27))
		circles.append(Vector3(2.98, 0.64, 0.3))
		for z: float in [-0.95, 0.85]:
			VehicleWheels.roller(k, m, Vector3(s * tx, 0.86, z), 0.075, tw * 0.5)
			circles.append(Vector3(z, 0.86, 0.075))
		_belt(k, m, s * tx, tw, circles, 0.08)
	# --- the hull: the belly between the tracks with the lower glacis at its
	# front, the upper hull out over the tracks with the long upper glacis
	k._add(m, VehicleModels.loft("core_m1_low", _oct(-0.98, 0.98, -2.95, 3.22, 0.08), _oct(-1.0, 1.0, -3.5, 3.48, 0.08), 0.42, 1.0), cam, null, Vector3.ZERO)
	var u0 := _oct(-1.62, 1.62, -3.52, 3.5, 0.06)
	var u1 := _oct(-1.62, 1.62, -3.46, 3.5, 0.06)
	var u2 := _oct(-1.6, 1.6, -1.78, 3.48, 0.05)
	# (the roof's edge ground off 22 mm all round: no more, so the welds
	# across its ends still sit in the cut)
	k._add(m, VehicleModels.solid(_rings([u0, u1, u2], [0.98, 1.08, roof]), "core_m1_up", false, 0.022), cam, null, Vector3.ZERO)
	# the welds where the glacis and the back plate meet the deck, each down
	# in its joint: on the ground-off edge's face, a bead's depth in (centred
	# on the old sharp corner they lay on the chamfer like rods)
	# (the glacis meets the deck at 11 degrees, so its cut is nearly flat)
	for e: Vector2 in [Vector2(-1.78, roof - 0.012), Vector2(3.462, roof - 0.018)]:
		_weld(k, m, [Vector3(-1.55, e.y, e.x), Vector3(1.55, e.y, e.x)], cam)
	var ga := Vector2(-3.46, 1.08)
	var gb := Vector2(-1.78, roof)
	# the glacis: the driver's hatch in the middle at its top, his three
	# periscopes; a seam across the nose, lifting eyes
	_zy(k, m, 0.0, 3.1, ga.lerp(gb, 0.02), ga.lerp(gb, 0.05), 0.02, 0.0, "gunmetal_w", null, false)
	var dh := ga.lerp(gb, 0.82)
	# (the lid turned to lie on the glacis, hinged toward its top, its centre
	# half its thickness out of the plate; the pivot boss on its back edge)
	var up := (gb - ga).normalized()
	VehicleFittings.panel_hatch(k, m, Vector3(0, dh.y + up.x * 0.025, dh.x - up.y * 0.025), Vector3(0.72, 0.05, 0.6), cam, null, 1.0, true, Vector3(-atan2(gb.y - ga.y, gb.x - ga.x), 0, 0))
	_zy(k, m, 0.0, 0.1, dh + (gb - ga).normalized() * 0.18, dh + (gb - ga).normalized() * 0.3, 0.05, 0.05, "gunmetal_w", null, false)
	for i in 3:
		var pz := ga.lerp(gb, 0.62)
		_periscope(k, m, Vector3(-0.22 + i * 0.22, pz.y + 0.06, pz.x), (1 - i) * 0.3, -0.2)
	for s: float in [-1.0, 1.0]:
		var e := ga.lerp(gb, 0.3)
		_eye(k, m, Vector3(s * 1.05, e.y + 0.01, e.x))
	# the front: headlight clusters in their guards on the fender tops, tow
	# shackles on the lower glacis, the front fenders' rubber flaps
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.42, 0.24, 0.3), Vector3(s * 1.36, 1.22, -3.38), cam)
		_lamp(k, m, Vector3(s * 1.36, 1.24, -3.56), 0.065)
		_bx(k, m, Vector3(0.12, 0.05, 0.05), Vector3(s * 1.2, 1.24, -3.58), "paint", Color(0.55, 0.38, 0.1), Vector3.ZERO, false)
		_shackle(k, m, Vector3(s * 0.62, 0.72, -3.28))
		# Rolled fenders wrap the top of the front idlers and hold the rubber flaps.
		var cover := [-3.34,1.37, -3.54,1.36, -3.68,1.31, -3.76,1.22, -3.79,1.04, -3.75,1.04, -3.72,1.20, -3.65,1.28, -3.53,1.32, -3.34,1.33]
		k._add(m, VehicleModels.extrude_x("core_m1_fender_curve", cover, -0.28, 0.28), cam, null, Vector3(s * 1.34, 0, 0))
		# (turned about Y so its clamp bar and bolts face forward)
		VehicleFittings.mudflap(k, m, Vector3(s * 1.34, 0.90, -3.77), Vector2(0.53, 0.34), Vector3(0.09, PI, 0))
	# skirts: seven bolted panels a side, the first two heavy armoured ones,
	# the front panel raked over the idler; a bolt line along their tops
	var panel := _breakaway_skirt()
	for s: float in [-1.0, 1.0]:
		var sx: float = s * 1.68
		var skirt := k._pivot(m, Vector3(sx, 1.38, -2.25))
		k.front_skirts.append(skirt)
		k._add(skirt, panel[0], cam, null, Vector3.ZERO)
		var plug := k._pivot(skirt, Vector3.ZERO)
		k.skirt_plugs.append(plug)
		k._add(plug, panel[1], cam, null, Vector3.ZERO)
		if k.burnt and s > 0:
			skirt.rotation = Vector3(0.29, 0.04, 0.43)
			plug.visible = false
		for i in 6:
			var z0 := -2.22 + i * 0.84
			var z1 := z0 + 0.82
			var heavy := i == 0
			VehicleEquipment.skirt(k, m, Vector3(sx + (0.0 if heavy else -0.02 * s), 0.94, (z0 + z1) * 0.5), Vector3(0.11 if heavy else 0.06, 0.88, z1 - z0), s, cam)
			for j in 3:
				var bolt := Vector3(sx + s * (0.06 if heavy else 0.035), 1.3, z0 + 0.12 + j * 0.29)
				_skirt_bolt(k, m, bolt, s, cam)
		for j in 4:
			var bolt := Vector3(s * 0.06, -0.08, -1.15 + j * 0.34)
			_skirt_bolt(k, skirt, bolt, s, cam)
		for hinge_z: float in [-1.06, -0.32]:
			k._cyl(skirt, 0.023, 0.023, 0.11, Vector3(s * 0.043, -0.024, hinge_z), X90, cam, null, 12, false)
		# the handrail-like lip of the fender over the skirts, a rear mudguard
		# over the sprocket with its rubber flap
		VehicleBody.track_guard(k, m, Vector3(s * 1.64, roof - 0.02, 0.0), Vector3(0.12, 0.05, 7.0), s, cam, null, 0, 0.0, Vector2.ZERO, Vector2.ZERO, false)
		VehicleBody.fender(k, m, Vector3(s * 1.33, 1.08, 3.25), Vector3(0.62, 0.05, 0.5), s, cam)
		VehicleFittings.mudflap(k, m, Vector3(s * 1.33, 0.84, 3.48), Vector2(0.5, 0.42))
		# fuel filler caps on the deck over the sponsons
		VehicleFittings.filler(k, m, Vector3(s * 1.28, roof + 0.02, 1.1), 0.09)
		if not k.wreck and team >= 0:
			# The recognition chevron lies flush on the skirt.
			for end: float in [-1.0, 1.0]:
				_bar(k, m, Vector3(s * 1.694, 0.84, 0.69), Vector3(s * 1.694, 1.1, 0.69 + end * 0.21), 0.007, 0.045, "paint", Color(0.67, 0.64, 0.5), false)
	k.engine_deck = Vector3(-0.74, roof + 0.06, 3.02)
	k.engine_vent = Vector3(0.24, 1.52, 3.48)
	# --- the engine deck: the big grille doors over the turbine and the
	# transmission, the centre access plate, lifting eyes
	for s: float in [-1.0, 1.0]:
		VehicleFittings.grille(k, m, Vector3(s * 0.74, roof + 0.03, 2.55), Vector2(1.22, 1.5), Vector3(-PI / 2, 0, 0), cam, null, 7)
		_bx(k, m, Vector3(1.0, 0.03, 0.62), Vector3(s * 0.74, roof + 0.012, 1.25), cam)
		VehicleDoors.pull(k, m, Vector3(s * 0.74, roof + 0.027, 1.1), Vector3.UP, Vector3.RIGHT, 0.12, 0.006, "gunmetal_w")
		_eye(k, m, Vector3(s * 1.35, roof, 3.3))
	_bx(k, m, Vector3(0.22, 0.04, 2.2), Vector3(0, roof + 0.015, 2.3), cam)
	# --- the rear plate: the turbine exhaust grille across the middle, the
	# tail light clusters, tow pintle and shackles, the infantry phone box
	VehicleFittings.grille(k, m, Vector3(0, 1.08, 3.56), Vector2(2.0, 0.58), Vector3.ZERO, cam, null, 6)
	for s: float in [-1.0, 1.0]:
		# (each cluster sits in a deep armoured housing)
		VehicleFittings.tail_cluster(k, m, Vector3(s * 1.3, 1.3, 3.5), Vector3(0.3, 0.2, 0.1))
		_shackle(k, m, Vector3(s * 0.7, 0.62, 3.42), 1.0)
	VehicleMounts.hitch(k, m, Vector3(0, 0.6, 3.5), Vector3(0.18, 0.16, 0.2))
	_bx(k, m, Vector3(0.24, 0.28, 0.14), Vector3(1.0, 1.24, 3.56), cam)
	if team >= 0:
		# the bumper code on the band across the nose under the glacis and on
		# the back plate under the tail lights: the battalion on the left,
		# the company and vehicle on the right, its number the turret boxes' own
		var code := VehicleMarkings.bumper_code(seed, VehicleMarkings.US_ARMOR, "31" if posmod(seed, 2) == 0 else "24")
		VehicleMarkings.bumper(k, m, code, 0.065, 0.5, 1.03, -3.49, Vector3(0, 0.51, -0.86), 0.42)
		VehicleMarkings.bumper(k, m, code, 0.06, 1.32, 1.155, 3.496, Vector3(0, 0.06, 1), 0.46)
	# --- the turret
	var t := k._pivot(m, Vector3(0, roof, -0.3))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.03, 0.1), 1.1, 1.14, 0.06, "gunmetal_w", null, 22)
	var tr := 0.7  # the turret roof
	# the main body: the crew compartment and the long bustle over the deck
	var b0 := [-1.36, -1.3, 1.36, -1.3, 1.46, -1.05, 1.46, 2.32, 1.26, 2.58, -1.26, 2.58, -1.46, 2.32, -1.46, -1.05]
	var b1 := [-1.3, -1.2, 1.3, -1.2, 1.4, -0.98, 1.4, 2.28, 1.2, 2.52, -1.2, 2.52, -1.4, 2.28, -1.4, -0.98]
	k._add(t, VehicleModels.loft("core_m1_tur", b0, b1, 0.04, tr), cam, null, Vector3.ZERO)
	# the cheeks: armour blocks either side of the gun shield, swept back in
	# plan, their faces near vertical over a deep undercut
	for s: float in [-1.0, 1.0]:
		var c0 := [0.42, -1.72, 1.46, -1.45, 1.46, -0.7, 0.42, -0.7]
		var c1 := [0.42, -2.36, 1.52, -1.98, 1.52, -0.7, 0.42, -0.7]
		var c2 := [0.42, -2.26, 1.44, -1.9, 1.44, -0.7, 0.42, -0.7]
		var key := "core_m1_cheek_r" if s > 0.0 else "core_m1_cheek_l"
		if s < 0.0:
			c0 = _mirror(c0)
			c1 = _mirror(c1)
			c2 = _mirror(c2)
		k._add(t, VehicleModels.solid(_rings([c0, c1, c2], [0.06, 0.3, tr + 0.012]), key), cam, null, Vector3.ZERO)
		# the seam where the cheek block meets the turret side
		_bx(k, t, Vector3(0.03, 0.5, 0.03), Vector3(s * 1.5, 0.52, -1.0), "gunmetal_w", null, Vector3.ZERO, false)
		# the roof plate welded over the armour cavity in the cheek (the sight
		# doghouse and the CITV stand on it), and the welds along the cheek's
		# top edges, its face and its flank
		var cover := [0.5, -2.17, 1.36, -1.87, 1.36, -0.78, 0.5, -0.78]
		_cover(k, t, "core_m1_cav_r" if s > 0.0 else "core_m1_cav_l", cover if s > 0.0 else _mirror(cover), tr + 0.012, 0.02, cam)
		var cheek_weld := _seated([0.42, -2.26, 1.44, -1.9, 1.44, -0.7, 0.42, -0.7], tr + 0.012, 0.008, 0.01, 0, 3)
		for i in cheek_weld.size():
			cheek_weld[i] = (cheek_weld[i] as Vector3) * Vector3(s, 1, 1)
		_weld(k, t, cheek_weld, cam)
	# the weld round the roof's edge from the cheeks back round the bustle,
	# seated in the joint
	var roof_weld := _seated(b1, tr, 0.008, 0.01, 3, 4)
	roof_weld.push_front(Vector3((roof_weld[0] as Vector3).x, tr - 0.01, -0.7))
	roof_weld.append(Vector3((roof_weld[roof_weld.size() - 1] as Vector3).x, tr - 0.01, -0.7))
	_weld(k, t, roof_weld, cam)
	# the gun shield, recessed between the cheeks; the gunner's auxiliary sight
	# port on it, the coax M240 to its right
	var gy := 0.4
	_bx(k, t, Vector3(0.82, 0.54, 0.5), Vector3(0, gy, -1.82), cam)
	_bx(k, t, Vector3(0.6, 0.42, 0.06), Vector3(0, gy, -2.08), cam)
	VehicleMounts.sight(k, t, Vector3(0.28, gy + 0.12, -2.12), Vector3(0.12, 0.1, 0.06), [Rect2(Vector2.ZERO, Vector2(0.08, 0.06))], "gunmetal_w")
	VehicleWeapons.coax(k, t, Vector3(0.3, gy - 0.1, -2.18), 0.2, 0.024)
	k.mg_tip = k._tip(t, Vector3(0.3, gy - 0.1, -2.29))
	# the 120 mm: the sleeve in sections with their clamp bands, the bore
	# evacuator, the muzzle and its reference sensor
	var trunnion := Vector3(0, gy, -2.08)
	k.gun_mount = k._pivot(t, trunnion)
	var slide := k._pivot(k.gun_mount, -trunnion)
	# the gun's pleated canvas mantlet cover, from the shield's face to its
	# tie round the sleeve: with the gun, so it lays as the gun elevates
	var boot := k._pivot(slide, Vector3(0, gy, 0))
	VehicleMounts.gun_boot(k, boot, -2.11, 0.2, 0.095, 0.26)
	k._fold(boot)
	VehicleFittings.barrel(k, slide, Vector3(0, gy, -2.3), Vector3(0, gy, -5.32), 0.095, cam, null)
	VehicleFittings.evacuator(k, slide, Vector3(0, gy, -3.82), 0.135, 0.56, cam)
	VehicleWeapons.muzzle_sensor(k, slide, Vector3(0, gy + 0.13, -5.14), Vector3(0.09, 0.07, 0.14), Vector3(0, gy, -5.14), 0.095)
	k.gun_tip = k._tip(slide, Vector3(0, gy, -5.34))
	# --- the roof: the gunner's primary sight doghouse front right with its
	# armoured doors, the commander's independent thermal viewer front left
	k.periscope = Vector3(0.81, tr + 0.22, -1.65)
	k._add(t, VehicleModels.loft("core_m1_gps", _oct(0.5, 1.12, -1.62, -0.8, 0.05), _oct(0.54, 1.08, -1.48, -0.84, 0.05), tr, tr + 0.42, 0.025), cam, null, Vector3.ZERO)
	for sx: float in [0.63, 0.99]:
		# (turned about Y so the leaf's finished face looks forward)
		VehicleDoors.leaf(k, t, Vector3(0.24, 0.26, 0.04), Vector3(sx, tr + 0.24, -1.56), cam, null, Vector3(-0.3, PI, 0), 2)
	if not k.burnt:
		_bx(k, t, Vector3(0.4, 0.14, 0.02), Vector3(0.81, tr + 0.22, -1.6), "glass" if k.wreck else "armor_glass", null if k.wreck else VehicleMounts.OPTIC, Vector3(0.3, 0, 0), false)
	k._cyl(t, 0.2, 0.22, 0.24, Vector3(-0.78, tr + 0.12, -0.95), Vector3.ZERO, "gunmetal_w", null, 14)
	k._add(t, VehicleModels.loft("core_m1_citv", _oct(-0.98, -0.58, -1.18, -0.74, 0.06), _oct(-0.95, -0.61, -1.12, -0.77, 0.05), tr + 0.24, tr + 0.58, 0.02), cam, null, Vector3.ZERO)
	if not k.burnt:
		_bx(k, t, Vector3(0.26, 0.16, 0.02), Vector3(-0.78, tr + 0.42, -1.16), "glass" if k.wreck else "armor_glass", null if k.wreck else VehicleMounts.OPTIC, Vector3.ZERO, false)
	# the commander's station on the right: the cupola ring with its vision
	# blocks, the hatch, the .50 on its mount ahead of it
	var cp := Vector3(0.62, tr, 0.3)
	VehicleMounts.cupola(k, t, cp + Vector3(0, 0.08, 0), 0.44, 0.47, 0.16, 6, -1.2, 0.48, cam, null, Vector3(0.13, 0.07, 0.05))
	_hatch(k, t, cp + Vector3(0, 0.12, 0.04), 0.33, cam)
	k.roof_gun = cp + Vector3(0.0, 0.48, -0.5)
	# (the pintle's cradle goes under the .50's receiver, 10 cm behind roof_gun)
	VehicleMounts.pintle(k, t, cp + Vector3(0, 0.17, -0.44), k.roof_gun + Vector3(0, 0, 0.1), "gunmetal_w", null, Vector2(0.04, 0.05))
	_m2(k, t, k.roof_gun)
	# the loader's hatch on the left and his M240 on its pintle behind the gun
	# shield kit, the pintle's socket on the roof just ahead of the hatch ring
	var lp := Vector3(-0.66, tr, 0.35)
	_hatch(k, t, lp, 0.34, cam, null, 1.0)
	k._cyl(t, 0.42, 0.42, 0.04, lp + Vector3(0, 0.02, 0), Vector3.ZERO, "gunmetal_w", null, 18, false)
	VehicleMounts.pintle(k, t, lp + Vector3(0, 0.0, -0.5), lp + Vector3(0, 0.42, -0.62), "gunmetal_w", null, Vector2(0.03, 0.04), Vector2(0.08, 0.13))
	_mmg(k, t, lp + Vector3(0, 0.42, -0.62))
	_bx(k, t, Vector3(0.74, 0.46, 0.04), lp + Vector3(0, 0.44, -0.78), cam, null, Vector3(0.12, 0, 0))
	if not k.burnt:
		_bx(k, t, Vector3(0.26, 0.16, 0.02), lp + Vector3(0.17, 0.52, -0.81), "glass" if k.wreck else "armor_glass", null if k.wreck else ARMOR_GLASS, Vector3(0.12, 0, 0), false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.04, 0.42, 0.42), lp + Vector3(s * 0.39, 0.42, -0.6), cam, null, Vector3(0, s * 0.35, 0))
	# the crosswind sensor mast at the back of the roof, the blow-off panels
	# over the ammunition in the bustle, lifting eyes, antennas
	VehicleMounts.mast_segment(k, t, Vector3(0, tr + 0.25, 1.85), 0.5, 0.025, "gunmetal_w", null)
	_bx(k, t, Vector3(0.18, 0.04, 0.04), Vector3(0, tr + 0.5, 1.85), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.9, 0.025, 0.9), Vector3(s * 0.55, tr + 0.012, 1.6), cam)
		_bx(k, t, Vector3(0.92, 0.012, 0.03), Vector3(s * 0.55, tr + 0.028, 1.15), "gunmetal_w", null, Vector3.ZERO, false)
		_eye(k, t, Vector3(s * 1.2, tr, -0.75))
		_eye(k, t, Vector3(s * 1.15, tr, 2.2))
		_antenna(k, t, Vector3(s * 1.08, tr, 2.22), 2.1 if s < 0.0 else 1.6)
		# M250 smoke dischargers on the flanks behind the cheeks
		_smoke(k, t, Vector3(s * 1.54, 0.6, -1.12), -s * 1.05, 3, 2, 0.5, 0.043)
		# stowage boxes along the turret sides, their lids and latches
		VehicleEquipment.storage(k, t, Vector3(s * 1.58, 0.42, 1.3), Vector3(0.24, 0.46, 1.5), cam, null, Vector3.ZERO)
		for height: float in [0.26, 0.48]:
			_bx(k, t, Vector3(0.026, 0.030, 1.47), Vector3(s * 1.702, height, 1.3), cam, null, Vector3.ZERO, false)
		for z: float in [0.57, 1.30, 2.03]:
			_bx(k, t, Vector3(0.028, 0.37, 0.031), Vector3(s * 1.701, 0.44, z), cam, null, Vector3.ZERO, false)
		for z: float in [0.9, 1.7]:
			_bx(k, t, Vector3(0.02, 0.08, 0.05), Vector3(s * 1.71, 0.57, z), "gunmetal_w", null, Vector3.ZERO, false)
		if not k.wreck and team >= 0:
			var stencil := QuadMesh.new()
			stencil.size = Vector2(0.44, 0.18)
			var ink := StandardMaterial3D.new()
			ink.albedo_texture = preload("res://assets/vehicles/abrams-numbers.png")
			ink.uv1_scale.x = 0.5
			ink.uv1_offset.x = 0.5 * posmod(seed, 2)
			ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			ink.alpha_scissor_threshold = 0.45
			ink.roughness = 0.96
			Res.mi(t, stencil, ink, Vector3(s * 1.704, 0.37, 1.66), Vector3(0, s * PI / 2, 0), false)
	# the bustle rack: a basket round the back of the bustle, packed with kit
	VehicleMounts.basket(k, t, Vector3(0, 0.26, 2.85), Vector3(2.9, 0.42, 0.62))
	# A packed roll flattens where it rests and pinches under each webbing strap.
	_bedroll(k, t, Vector3(-0.57, 0.57, 2.83), 1.17, 0.29, BAG)
	_bedroll(k, t, Vector3(0.65, 0.51, 2.87), 0.97, 0.22, TAN_BAG)
	if seed % 2 == 0:
		_bedroll(k, t, Vector3(-0.50, 0.91, 2.82), 0.90, 0.18, TAN_BAG)
	_jerry(k, t, Vector3(-1.29, 0.53, 2.84), OD, PI / 2)


static var _skirt_meshes: Array[ArrayMesh] = []


## The two flush faces fill the opening in an intact skirt. When the panel
## tears, removing them reveals the steel edge and running gear behind it.
static func _breakaway_skirt() -> Array[ArrayMesh]:
	if not _skirt_meshes.is_empty():
		return _skirt_meshes
	var profile := PackedVector2Array([Vector2(0,-0.88), Vector2.ZERO, Vector2(-1.35,0),
		Vector2(-1.35,-0.16), Vector2(-0.85,-0.88)])
	var center := Vector2(-0.40,-0.395)
	var shell := SurfaceTool.new()
	var fill := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector3Array()
	var outline := PackedVector3Array()
	for edge in profile.size():
		for step in 8:
			var point := profile[edge].lerp(profile[(edge + 1) % profile.size()], step / 8.0)
			var ray := (point - center).normalized()
			var rough := 1.0 + 0.12 * sin(ray.angle() * 7.0) + 0.06 * cos(ray.angle() * 11.0)
			var cut := center + ray * rough / (ray / Vector2(0.125,0.078)).length()
			rim.append(Vector3(0,cut.y,cut.x))
			outline.append(Vector3(0,point.y,point.x))
	var middle := Vector3(0,center.y,center.x)
	var half_width := Vector3.RIGHT * 0.055
	for i in rim.size():
		var j := (i + 1) % rim.size()
		for side: float in [-1.0,1.0]:
			var dx := side * half_width
			VehicleModels._tri(shell,outline[i]+dx,outline[j]+dx,rim[j]+dx,middle)
			VehicleModels._tri(shell,outline[i]+dx,rim[j]+dx,rim[i]+dx,middle)
			VehicleModels._tri(fill,middle+dx,rim[i]+dx,rim[j]+dx,middle)
		# The outer edge faces away from the center. The fracture faces into it.
		VehicleModels._tri(shell,outline[i]-half_width,outline[j]-half_width,outline[j]+half_width,middle)
		VehicleModels._tri(shell,outline[i]-half_width,outline[j]+half_width,outline[i]+half_width,middle)
		var steel := (outline[i] + outline[j]) * 0.5
		VehicleModels._tri(shell,rim[i]-half_width,rim[j]-half_width,rim[j]+half_width,steel)
		VehicleModels._tri(shell,rim[i]-half_width,rim[j]+half_width,rim[i]+half_width,steel)
	_skirt_meshes.assign([shell.commit(),fill.commit()])
	return _skirt_meshes


static func _skirt_bolt(k: VehicleModels, parent: Node3D, at: Vector3, side: float, paint: String) -> void:
	k._cyl(parent, 0.025, 0.023, 0.014, at, Z90, paint, null, 10, false)
	k._cyl(parent, 0.014, 0.016, 0.019, at + Vector3.RIGHT * side * 0.009, Z90, "gunmetal_w", null, 6, false)


static var _roll_mesh: ArrayMesh


static func _bedroll(k: VehicleModels, parent: Node3D, center: Vector3, length: float, radius: float, cloth: Color) -> void:
	# Whose bedroll it is: each crew's are their own issue and colour.
	var rng := VehicleCargo.kit(k, parent, center, 2)
	if rng != null:
		cloth = VehicleCargo.kit_colour(rng, cloth, VehicleCargo.KIT_CLOTH, 0.4)
	# Coyote and sand shells are dull, greyish tans: at the kit palette's
	# brown the game's sun turned a roll terracotta, the warmest thing on the
	# hull, so a live roll's colour keeps a dull tan's saturation at most.
	if not k.wreck:
		cloth = Color.from_hsv(cloth.h, minf(cloth.s, 0.26), cloth.v)
	if _roll_mesh == null:
		var fabric := SurfaceTool.new()
		fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
		var slices := 36
		var sides := 24
		for i in range(slices + 1):
			var x := -1.0 + 2.0 * i / slices
			var pinch := 0.19 * exp(-pow((absf(x) - 0.55) / 0.095, 2.0))
			for j in sides:
				var a := TAU * j / sides
				var folds := 0.047 * sin(6.0 * a + x * 3.1) + 0.027 * sin(11.0 * a + 2.6 * x)
				var r := 1.0 + folds - pinch - 0.11 * pow(absf(x), 7.0)
				if i == 0 or i == slices:
					r *= 0.88
				fabric.add_vertex(Vector3(x, clampf(r * sin(a), -0.85, 1.0), r * cos(a)))
		for i in slices:
			for j in sides:
				var a := i * sides + j
				var b := i * sides + (j + 1) % sides
				for index: int in [a, b, a + sides, b, b + sides, a + sides]:
					fabric.add_index(index)
		for j in range(1, sides - 1):
			for index: int in [0, j + 1, j, slices * sides, slices * sides + j, slices * sides + j + 1]:
				fabric.add_index(index)
		fabric.generate_normals()
		_roll_mesh = fabric.commit()
	# A crew's bedroll is a sleeping bag in a nylon shell, not cotton duck:
	# in the canvas finish's warm tone the game's sun turned a tan roll the
	# orange of a terracotta pot, the warmest thing on a tank. (A wreck's
	# stays canvas, which a burnt hulk burns away.)
	var shell := "canvas" if k.wreck else "nylon"
	k._add(parent, _roll_mesh, shell, cloth, center, Vector3.ZERO, Vector3(length * 0.5, radius, radius * 1.12))
	# The wound layers show on its ends as a darker spiral, the rolled
	# cloth's edge winding in to the core.
	k._add(parent, _bedroll_spiral(), shell, cloth.darkened(0.25), center, Vector3.ZERO, Vector3(length * 0.5, radius, radius * 1.12), false)
	for s: float in [-1.0, 1.0]:
		var strap := center + Vector3.RIGHT * s * length * 0.275
		# (webbing, a strap's own weave; a wreck's burnt away with the roll)
		k._add(parent, Res.cyl(1, 1, 0.045, 24), "canvas" if k.wreck else "webbing", cloth.darkened(0.42), strap, Z90, Vector3(radius * 0.85, 1, radius * 0.96))
		_bx(k, parent, Vector3(0.061, 0.036, 0.025), strap + Vector3(0, radius * 0.35, radius * 0.87), "gunmetal_w")


static var _spiral_mesh: ArrayMesh

## Two and a half turns of a rolled cloth's edge on each end of _bedroll's
## mesh (its ends at x = ±1, a little proud of them), within its flattened
## underside.
static func _bedroll_spiral() -> ArrayMesh:
	if _spiral_mesh != null:
		return _spiral_mesh
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for side: float in [-1.0, 1.0]:
		for t in 25:
			var f := float(t) / 24.0
			var a := f * TAU * 2.5 * side
			var r := lerpf(0.1, 0.62, f)
			for w: float in [-0.035, 0.035]:
				verts.append(Vector3(side * 1.006, sin(a) * (r + w), cos(a) * (r + w)))
				norms.append(Vector3(side, 0, 0))
			if t > 0:
				var b := verts.size() - 4
				VehicleWheels._tri(idx, verts, Vector3(side, 0, 0), b, b + 1, b + 2)
				VehicleWheels._tri(idx, verts, Vector3(side, 0, 0), b + 1, b + 3, b + 2)
	_spiral_mesh = VehicleWheels._mesh(verts, norms, idx)
	return _spiral_mesh



# --- old_tank: T-55A --------------------------------------------------------------

const RUST := Color(0.33, 0.19, 0.11)
const RUST_D := Color(0.24, 0.14, 0.09)


## A rounded plan outline at height y: n points round (0, 0), hw half wide,
## reaching ef forward and er back (each half an ellipse, p > 2 squarer).
static func _round_ring(hw: float, ef: float, er: float, y: float, n := 24, p := 2.0) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in n:
		var a := TAU * (i + 0.5) / n
		var c := cos(a)
		var s := sin(a)
		var x := signf(c) * pow(absf(c), 2.0 / p) * hw
		var zz := signf(s) * pow(absf(s), 2.0 / p)
		r.append(Vector3(x, y, zz * (er if zz > 0.0 else ef)))
	return r


## The T-55's cast dome: its rings (half width, reach forward, reach back,
## height), lofted bottom to top.
const T55_DOME := [[1.06, 1.08, 1.02, 0.02], [1.16, 1.2, 1.14, 0.13], [1.14, 1.15, 1.13, 0.32], [1.03, 0.99, 1.04, 0.5],
	[0.84, 0.76, 0.88, 0.65], [0.58, 0.5, 0.64, 0.75], [0.28, 0.22, 0.34, 0.8]]


## How far out the dome's flank is at height y and z (+x side): each ring's
## polygon where it crosses z, between the two rings either side of y.
static func _dome_x(y: float, z: float) -> float:
	for i in T55_DOME.size() - 1:
		var a: Array = T55_DOME[i]
		var b: Array = T55_DOME[i + 1]
		if y <= float(b[3]) or i == T55_DOME.size() - 2:
			var t := clampf((y - float(a[3])) / (float(b[3]) - float(a[3])), 0.0, 1.0)
			return lerpf(_ring_x(_round_ring(a[0], a[1], a[2], a[3]), z), _ring_x(_round_ring(b[0], b[1], b[2], b[3]), z), t)
	return 0.0


## Where a plan ring's polygon crosses z on its +x side.
static func _ring_x(r: PackedVector3Array, z: float) -> float:
	var x := 0.0
	for i in r.size():
		var p := r[i]
		var q := r[(i + 1) % r.size()]
		if p.x > 0.0 and q.x > 0.0 and (p.z - z) * (q.z - z) <= 0.0 and absf(q.z - p.z) > 0.00001:
			x = maxf(x, lerpf(p.x, q.x, (z - p.z) / (q.z - p.z)))
	return x


## A DShK 12.7 mm along -Z, its receiver's centre at pos: the receiver and
## feed cover, the spade grips, the finned barrel, the gas cylinder under it,
## the big flat muzzle brake, the 50-round box on the left. Returns the muzzle.
static func _dshk(k: VehicleModels, p: Node3D, pos: Vector3) -> Vector3:
	# (on a pivot of its own at the receiver: the gun a mount can lay)
	var g := k._pivot(p, pos)
	VehicleMounts.receiver(k, g, Vector3(0.13, 0.15, 0.56), Vector3(0, 0, 0.1), VehicleWeapons.STEEL)
	_bx(k, g, Vector3(0.14, 0.05, 0.26), Vector3(0, 0.09, 0.0), VehicleWeapons.STEEL)
	_bx(k, g, Vector3(0.14, 0.15, 0.03), Vector3(0, 0.0, 0.39), VehicleWeapons.STEEL)
	# the wooden spade grips, swelling to the palm and rounded off on top
	for sx: float in [-0.08, 0.08]:
		k._cyl(g, 0.019, 0.023, 0.13, Vector3(sx, 0.055, 0.47), Vector3.ZERO, "wood_dark", null, 8, false)
		k._add(g, Res.sphere(0.019, 8), "wood_dark", null, Vector3(sx, 0.12, 0.47), Vector3.ZERO, Vector3(1.0, 0.7, 1.0), false)
	k._cyl(g, 0.028, 0.028, 1.06, Vector3(0, 0, -0.71), X90, VehicleWeapons.STEEL, null, 8)
	for i in 8:
		k._cyl(g, 0.052, 0.052, 0.016, Vector3(0, 0, -0.24 - i * 0.05), X90, VehicleWeapons.STEEL, null, 10, false)
	k._cyl(g, 0.016, 0.016, 0.6, Vector3(0, -0.06, -0.48), X90, VehicleWeapons.STEEL, null, 6, false)
	_bx(k, g, Vector3(0.025, 0.07, 0.1), Vector3(0, 0.06, -0.62), VehicleWeapons.STEEL, null, Vector3.ZERO, false)
	_bx(k, g, Vector3(0.02, 0.06, 0.02), Vector3(0, 0.06, -1.12), VehicleWeapons.STEEL, null, Vector3.ZERO, false)
	k._cyl(g, 0.042, 0.042, 0.13, Vector3(0, 0, -1.29), X90, VehicleWeapons.STEEL, null, 10)
	_bx(k, g, Vector3(0.12, 0.016, 0.1), Vector3(0, 0, -1.29), VehicleWeapons.STEEL, null, Vector3.ZERO, false)
	# the 50-round box on its bracket on the left, the belt rising out of it
	# into the feed; the rear sight's leaf on the cover, the charging handle
	# on the right, the butterfly trigger between the grips
	VehicleFittings.ammo_can(k, g, Vector3(-0.15, -0.07, 0.04), OD, Vector3.ZERO, Vector3(0.1, 0.17, 0.24), true)
	VehicleWeapons._belt(k, g, Vector3(-0.15, -0.07, 0.04), Vector3(0.1, 0.17, 0.24), Vector3(-0.068, 0.06, 0.01), 0.011, 0.147)
	_bx(k, g, Vector3(0.05, 0.05, 0.012), Vector3(0, 0.14, 0.11), VehicleWeapons.STEEL, null, Vector3(-0.2, 0, 0), false)
	_tube(k, g, Vector3(0.065, -0.02, 0.16), Vector3(0.11, -0.02, 0.16), 0.008, "steel", null, 6, false)
	k._cyl(g, 0.015, 0.015, 0.03, Vector3(0.115, -0.02, 0.16), Z90, "metal_dark", null, 6, false)
	_bx(k, g, Vector3(0.07, 0.025, 0.02), Vector3(0, 0.06, 0.43), VehicleWeapons.STEEL, null, Vector3.ZERO, false)
	k.gun_assembly(g, Vector3(0, 0, -1.36), [Vector3(0.08, 0.06, 0.47), Vector3(-0.08, 0.06, 0.47)])
	return pos + Vector3(0, 0, -1.36)


## A sawn log's end grain, pale against its bark.
const END_GRAIN := Color(0.6, 0.48, 0.33)


## An unditching beam's fittings, the log lying along x at `center`, `half`
## its half length, `r0` / `r1` its radius at the -x / +x end: the steel
## bands that clamp it to its brackets at `bands` (x), and its sawn ends in
## pale end grain (a smooth brown cylinder alone read as a pipe). A wreck's
## log stays bare.
static func _beam_fittings(k: VehicleModels, p: Node3D, center: Vector3, half: float, r0: float, r1: float, bands: Array) -> void:
	if k.wreck:
		return
	for x: float in bands:
		var r := lerpf(r0, r1, (x + half) / (half * 2.0)) + 0.008
		k._cyl(p, r, r, 0.045, center + Vector3(x, 0, 0), Z90, "gunmetal_w", null, 10, false)
	for e: float in [-1.0, 1.0]:
		var r := (r0 if e < 0.0 else r1) * 0.86
		k._cyl(p, r, r, 0.01, center + Vector3(e * (half + 0.002), 0, 0), Z90, "wood", END_GRAIN, 10, false)


## An infrared searchlight's filter glass: the deep violet-black a Soviet
## IR lamp's face shows by day.
const IR_FILTER := Color(0.07, 0.055, 0.09)


## T-55A (the Rebels' old tank, full scale): the low hull with its 60-degree
## glacis and the V of the splash board across it, five big "starfish" road
## wheels a side with the gap after the first and the track sagging straight
## onto them (no return rollers), thin sheet-steel fenders running the full
## length with the external fuel tanks on the right and the stowage boxes and
## the exhaust on the left, two 200-litre drums on the back; the cast dome
## turret, its 100 mm D-10T with the fume extractor near the muzzle and the
## canvas boot over the mantlet, the IR searchlight beside the gun, the
## commander's cupola and the loader's hatch with its DShK, grab rails, the
## snorkel stowed on the back. Worn: faded, rust-streaked, a replacement road
## wheel in another army's green, a bent mudguard, mismatched fuel drums.
static func _t55(k: VehicleModels, team: int, seed: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var roof := 1.5
	var green := Color(0.29, 0.31, 0.22)
	# --- running gear: front idler, five road wheels (the gap after the
	# first), rear sprocket; the track sagging onto the wheels
	var tx := 1.32
	var tw := 0.58
	var rw := [-1.98, -0.88, -0.03, 0.82, 1.67]
	var wr := 0.405
	var wy := 0.48
	for s: float in [-1.0, 1.0]:
		var circles := []
		for i in rw.size():
			var z: float = rw[i]
			# one road wheel a replacement, still in its old green
			var odd := (s < 0.0 and i == 2) or (s > 0.0 and i == (seed % 3) + 1 and seed % 2 == 0)
			_road_wheel(k, m, Vector3(s * tx, wy, z), wr, tw * 0.82, "paint" if odd else cam, green if odd else null, 6)
			circles.append(Vector3(z, wy, wr))
		_idler(k, m, Vector3(s * tx, 0.56, -2.72), 0.28, tw * 0.8, cam)
		_sprocket(k, m, Vector3(s * tx, 0.6, 2.58), 0.33, tw * 0.8, cam, null, 13)
		circles.append(Vector3(-2.72, 0.56, 0.28))
		circles.append(Vector3(2.58, 0.6, 0.33))
		_belt(k, m, s * tx, tw, circles, 0.075, true)
	# --- the hull: the belly between the tracks with the lower glacis, the
	# upper hull over the tracks, the glacis rising at 60 degrees
	k._add(m, VehicleModels.loft("core_t55_low", _oct(-1.0, 1.0, -2.78, 2.86, 0.08), _oct(-1.0, 1.0, -3.08, 3.06, 0.08), 0.42, 0.97), cam, null, Vector3.ZERO)
	var u0 := _oct(-1.0, 1.0, -3.1, 3.06, 0.05)
	var u1 := _oct(-1.0, 1.0, -3.08, 3.04, 0.05)
	# The belly fits between the tracks. The upper hull widens above
	# the return run, including when a road wheel is at full bump.
	var inner := _oct(-1.0, 1.0, -2.60, 3.01, 0.05)
	var shelf := _oct(-1.38, 1.38, -2.60, 3.01, 0.05)
	var u2 := _oct(-1.37, 1.37, -2.12, 2.98, 0.05)
	k._add(m, VehicleModels.solid(_rings([u0, u1, inner, shelf, u2], [0.96, 1.0, 1.25, 1.25, roof]), "core_t55_up"), cam, null, Vector3.ZERO)
	# the welds round the hull roof's edge, the glacis's top with it, down
	# in the joints
	_weld(k, m, _seated(u2, roof), cam)
	var ga := Vector2(-3.08, 1.0)
	var gb := Vector2(-2.12, roof)
	var gu := Vector3(0, gb.y - ga.y, gb.x - ga.x).normalized()
	# The glacis normal points up and forward, out of the plate.
	var gn := Vector3(0, gu.z, -gu.y)
	# the splash board: a V across the glacis, its point forward
	for s: float in [-1.0, 1.0]:
		var a := Vector3(0, ga.lerp(gb, 0.18).y, ga.lerp(gb, 0.18).x)
		var b := Vector3(s * 1.04, ga.lerp(gb, 0.62).y, ga.lerp(gb, 0.62).x)
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		_on_face(k, m, mid, along, gn.cross(along), gn, Vector3(a.distance_to(b), 0.034, 0.075), cam)
	# spare track links bolted across the glacis below it, tow hooks under the nose
	var c := ga.lerp(gb, 0.79)
	VehicleTracks.spare_links(k, m, Vector3(0.53, c.y, c.x), Vector3.RIGHT, gn, 4, Vector3(0.175, 0.51, 0.046), 0.19)
	for s: float in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.7, 0.78, -2.95))
	# the driver's hatch front left and his two periscopes, the lights on the
	# glacis corners: the headlight and the IR driving light on the left (its
	# lens long gone), one headlight on the right
	VehicleFittings.panel_hatch(k, m, Vector3(-0.72, roof + 0.025, -1.75), Vector3(0.62, 0.05, 0.56), cam, null, -1.0)
	for i in 2:
		_periscope(k, m, Vector3(-0.86 + i * 0.28, roof + 0.05, -2.08), (i - 0.5) * 0.4)
	for e in [[-0.9, 0.34, true], [-0.63, 0.34, false], [0.9, 0.34, true]]:
		var c2 := ga.lerp(gb, float(e[1]))
		var lp := Vector3(float(e[0]), c2.y + 0.16, c2.x + 0.06)
		k._cyl(k.root, 0.012, 0.012, 0.18, lp + Vector3(0, -0.1, 0.02), Vector3.ZERO, "gunmetal_w", null, 4, false)
		VehicleFittings.lamp_unit(k, m, lp, Vector3(0.22, 0.19, 0.16), -1.0, [0.08] if bool(e[2]) else [], Rect2(), "", Vector3.ZERO, "round")
		if not bool(e[2]) and not k.burnt:
			k._cyl(m, 0.08, 0.08, 0.02, lp + Vector3(0, 0, -0.08), X90, "plain_dark", null, 12, false)
		# The guard arches over the lamp. Keep its steel clear of the lens.
		for x: float in [-0.113, 0.113]:
			_bar(k, m, lp + Vector3(x, -0.082, -0.044), lp + Vector3(x, 0.115, -0.1), 0.018, 0.018, "gunmetal_w", null, false)
		_bx(k, m, Vector3(0.244, 0.018, 0.018), lp + Vector3(0, 0.124, -0.1), "gunmetal_w", null, Vector3.ZERO, false)
	# --- fenders: thin shelves the full length over the tracks with a lip
	# down their outer edge, on gussets, the front mudguards angled down (the
	# left one bent up), the rear ones
	for s: float in [-1.0, 1.0]:
		var front := Vector2(0.53, 0.21) if s > 0.0 else Vector2(0.56, -0.02)
		VehicleBody.track_guard(k, m, Vector3(s * 1.52, 1.28, -0.05), Vector3(0.3, 0.035, 5.6), s, cam, null, 6, 0.075, front, Vector2(0.525, 0.194))
	# the right fender: three external fuel tanks (dented, one streaked with
	# rust), a stowage box forward; their straps and pipes
	for i in 3:
		var z := 0.35 + i * 0.82
		# (each box tank, with its straps and filler cap, set a little askew
		# where the tank is dented). The tanks are painted with the hull, as
		# every army paints them; the middle one is a replacement in another
		# army's green, like the odd road wheel. (Bare steel, they glared
		# white from above.)
		var tank_mat := "paint" if i == 1 else cam
		VehicleRunningGear.fuel_tank(k, m, Vector3(1.52, 1.515, z), Vector3(0.27, 0.42, 0.74), 1.0, tank_mat, green if i == 1 else null, false, Vector3(0, [0.0, 0.03, -0.02][i], [0.0, 0.02, 0.04][i]))
	_bx(k, m, Vector3(0.02, 0.3, 0.06), Vector3(1.665, 1.495, 0.97), "paint", RUST, Vector3.ZERO, false)
	_bx(k, m, Vector3(0.02, 0.22, 0.05), Vector3(1.665, 1.445, 1.85), "paint", RUST, Vector3.ZERO, false)
	_tube(k, m, Vector3(1.42, 1.675, 0.0), Vector3(1.42, 1.675, 2.6), 0.022, "gunmetal_w", null, 6)
	VehicleEquipment.storage(k, m, Vector3(1.52, 1.4975, -1.15), Vector3(0.27, 0.385, 0.95), cam)
	k.engine_deck = Vector3(-0.74, roof + 0.12, 1.85)
	k.engine_vent = Vector3(-1.45, 1.49, 1.35)
	# the left fender: stowage boxes, the spare parts box, the oil tank; the
	# exhaust louvre on the hull side above it, sooted round
	for e in [[-1.6, 0.85], [-0.55, 0.95], [0.55, 0.6]]:
		VehicleEquipment.storage(k, m, Vector3(-1.52, 1.475, float(e[0])), Vector3(0.26, 0.34, float(e[1])), cam, null, Vector3(0, 0.02, 0))
		_bx(k, m, Vector3(0.02, 0.06, 0.08), Vector3(-1.665, 1.555, float(e[0])), "gunmetal_w", null, Vector3.ZERO, false)
	VehicleRunningGear.fuel_tank(k, m, Vector3(-1.5, 1.475, 2.4), Vector3(0.34, 0.34, 0.8), -1.0, cam)
	# (turned about Y so the louvre faces out to the left)
	VehicleFittings.grille(k, m, Vector3(-1.415, 1.385, 1.35), Vector2(0.62, 0.18), Vector3(0, -PI / 2, 0), "gunmetal_w", null, 4)
	# the dark outlet behind the louvres, and the diesel's soot streaked back
	# along the side plate from their trailing edge to the fuel tank, graded
	# into the paint (it was one flat black slab running on past the louvres,
	# its edges hard as a sticker's)
	_bx(k, m, Vector3(0.02, 0.17, 0.6), Vector3(-1.385, 1.385, 1.35), "plain", Color(0.07, 0.07, 0.065), Vector3.ZERO, false)
	VehicleBody.soot(k, m, Vector3(-1.375, 1.385, 1.62), Vector3.BACK, Vector3(0.04, 1.0, 0), Vector3(-1.0, 0.04, 0), 0.9, 0.18)
	# rust streaks down the hull sides and the glacis corners
	for e in [[1.385, 1.22, -0.4, 0.32], [-1.385, 1.25, -0.9, 0.36], [1.385, 1.2, 2.2, 0.26], [-1.385, 1.18, 2.7, 0.3]]:
		_bx(k, m, Vector3(0.012, float(e[3]), 0.04), Vector3(float(e[0]), float(e[1]), float(e[2])), "paint", RUST, Vector3.ZERO, false)
	# --- the engine deck: the louvred grilles, the access plates, the
	# radiator grille across the back
	VehicleFittings.grille(k, m, Vector3(0, roof + 0.03, 2.25), Vector2(2.2, 1.15), Vector3(-PI / 2, 0, 0), cam, null, 7)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.9, 0.035, 0.75), Vector3(s * 0.55, roof + 0.012, 0.95), cam, null, Vector3(0, s * 0.01, 0))
		VehicleDoors.pull(k, m, Vector3(s * 0.55, roof + 0.0295, 0.75), Vector3.UP, Vector3.RIGHT, 0.1, 0.0055, "gunmetal_w")
	k._cyl(m, 0.13, 0.13, 0.06, Vector3(0.6, roof + 0.03, 0.35), Vector3.ZERO, "gunmetal_w", null, 10, false)
	# --- the rear: the sloped plate, the two 200-litre drums on their
	# brackets (one rust-brown, one green), the unditching log under them,
	# tail lights, tow hooks
	_bx(k, m, Vector3(2.6, 0.4, 0.06), Vector3(0, 1.22, 3.06), "gunmetal_w", null, Vector3(-0.35, 0, 0))
	# (the drums are run dry first and dropped: about a crew in four has
	# dumped one, its brackets left bare; from the kit seed, so neighbours
	# differ, and scenery and wrecks carry both)
	var drums := VehicleCargo.kit(k, m, Vector3(0, 1.5, 3.3), 0x55d)
	var dropped := 0.0
	if drums != null and drums.randf() < 0.25:
		dropped = -1.0 if drums.randf() < 0.5 else 1.0
	for s: float in [-1.0, 1.0]:
		var dc: Color = Color(0.3, 0.2, 0.14) if s < 0.0 else Color(0.28, 0.31, 0.22)
		# Each drum lies fore and aft with its bung head to the rear, strapped
		# down to the two brackets off the plate.
		if s != dropped:
			VehicleEquipment.drum(k, m, Vector3(s * 0.66, 1.5, 3.3), 0.29, 0.86, Vector3.BACK, "paint", dc, Vector3(s, 1, 0), 0.2, [-0.15, 0.25], 16)
		for dz: float in [-0.15, 0.25]:
			_bar(k, m, Vector3(s * 0.66, 1.18, 3.06), Vector3(s * 0.66, 1.2, 3.3 + dz), 0.05, 0.04, "gunmetal_w", null, false)
		_taillight(k, m, Vector3(s * 1.2, 1.25, 3.1))
		_shackle(k, m, Vector3(s * 0.75, 0.7, 2.95), 1.0)
	k._cyl(m, 0.13, 0.14, 2.7, Vector3(0, 1.0, 3.12), Z90, "bark", null, 10)
	_beam_fittings(k, m, Vector3(0, 1.0, 3.12), 1.35, 0.13, 0.14, [-0.78, 0.78])
	for x: float in [-0.95, 0.95]:
		_bx(k, m, Vector3(0.05, 0.3, 0.3), Vector3(x, 1.02, 3.12), "gunmetal_w", null, Vector3.ZERO, false)
	_antenna(k, m, Vector3(-1.1, roof, 2.85), 1.8)
	k._team_mark(m, team, Vector3(0, roof + 0.012, 1.5), Vector3(0.7, 0.02, 0.4))
	# --- the turret: the cast dome
	var t := k._pivot(m, Vector3(0, roof, -0.95))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.03, 0.0), 1.02, 1.06, 0.06, "gunmetal_w", null, 22)
	var dome := []
	for r: Array in T55_DOME:
		dome.append(_round_ring(r[0], r[1], r[2], r[3]))
	k._add(t, VehicleModels.solid(dome, "core_t55_dome", true), "cast_" + cam, null, Vector3.ZERO)
	# the cast mantlet in the dome's front and the canvas boot over the gun
	var gy := 0.4
	k._add(t, VehicleModels.solid([_rz([-0.36, gy - 0.26, 0.36, gy - 0.26, 0.42, gy - 0.1, 0.42, gy + 0.14, 0.3, gy + 0.28, -0.3, gy + 0.28, -0.42, gy + 0.14, -0.42, gy - 0.1], -0.85),
		_rz([-0.3, gy - 0.22, 0.3, gy - 0.22, 0.36, gy - 0.08, 0.36, gy + 0.1, 0.26, gy + 0.22, -0.26, gy + 0.22, -0.36, gy + 0.1, -0.36, gy - 0.08], -1.24)], "core_t55_mant"), cam, null, Vector3.ZERO)
	# the 100 mm: the long tapering barrel, the fume extractor near the muzzle
	var trunnion := Vector3(0, gy, -1.38)
	k.gun_mount = k._pivot(t, trunnion)
	var slide := k._pivot(k.gun_mount, -trunnion)
	# the boot: pleated canvas from the mantlet's face, tied round the barrel,
	# with the gun so it lays as the gun elevates (on the turret, the barrel
	# swung out through its side)
	var boot := k._pivot(slide, Vector3(0, gy, 0))
	VehicleMounts.gun_boot(k, boot, -1.24, 0.2, 0.07, 0.3)
	k._fold(boot)
	VehicleFittings.barrel(k, slide, Vector3(0, gy, -1.5), Vector3(0, gy, -5.065), 0.07, cam, null, false)
	VehicleFittings.evacuator(k, slide, Vector3(0, gy, -4.42), 0.118, 0.64, cam)
	k.gun_tip = k._tip(slide, Vector3(0, gy, -5.1))
	# the coaxial PKT's port right of the gun
	VehicleWeapons.coax(k, t, Vector3(0.27, gy - 0.02, -1.26), 0.16, 0.022)
	k.mg_tip = k._tip(t, Vector3(0.27, gy - 0.02, -1.34))
	# the L-2 IR searchlight on its bracket to the right of the gun, braced
	# to the mantlet
	VehicleFittings.searchlight(k, t, Vector3(0.5, 0.82, -1.02), Vector3.FORWARD, 0.17, 0.34, "bracket", Vector3(0.5, 0.52, -0.98), cam)
	# its IR filter over the face, the near-black violet glass a Luna lamp
	# shows by day (a clear white-light reflector glared off the turret as a
	# second headlight); a wreck keeps its old face
	if not k.wreck:
		k._cyl(t, 0.153, 0.153, 0.008, Vector3(0.5, 0.82, -1.178), Vector3(PI / 2, 0, 0), "glass", IR_FILTER, 16, false)
	_bar(k, t, Vector3(0.38, 0.5, -1.1), Vector3(0.42, 0.74, -1.04), 0.03, 0.03, "gunmetal_w", null, false)
	# the gunner's sight port front left, the ventilator dome front right
	k.periscope = Vector3(-0.45, 0.73, -0.89)
	VehicleMounts.sight(k, t, Vector3(-0.45, 0.72, -0.72), Vector3(0.18, 0.12, 0.24), [Rect2(Vector2(0, -0.016), Vector2(0.12, 0.06))], "gunmetal_w", null, Vector3.ZERO, Vector3(0.2, 0, 0))
	k._cyl(t, 0.12, 0.15, 0.08, Vector3(0.12, 0.8, -0.5), Vector3.ZERO, cam, null, 12)
	# (its cap painted with the turret: in bare steel it was a second pale
	# disc on the roof from above)
	k._cyl(t, 0.16, 0.13, 0.06, Vector3(0.12, 0.86, -0.5), Vector3.ZERO, cam, null, 12)
	# the commander's cupola on the left with its vision blocks and the small
	# IR spotlight, the loader's hatch on the right with the DShK on its ring
	var cp := Vector3(-0.44, 0.73, 0.18)
	VehicleMounts.cupola(k, t, cp + Vector3(0, 0.08, 0), 0.34, 0.37, 0.16, 5, -1.0, 0.5, cam, null, Vector3(0.11, 0.06, 0.05))
	_hatch(k, t, cp + Vector3(0, 0.14, 0.02), 0.27, cam)
	VehicleFittings.searchlight(k, t, cp + Vector3(0, 0.3, -0.34), Vector3.FORWARD, 0.08, 0.14, "bracket", cp + Vector3(0, 0.17, -0.3))
	if not k.wreck:
		k._cyl(t, 0.072, 0.072, 0.006, cp + Vector3(0, 0.3, -0.404), Vector3(PI / 2, 0, 0), "glass", IR_FILTER, 16, false)
	var lp := Vector3(0.46, 0.7, 0.28)
	k._cyl(t, 0.36, 0.38, 0.08, lp + Vector3(0, 0.04, 0), Vector3.ZERO, cam, null, 16)
	# the ring's race round the open hatch, painted with the turret, the
	# hatch dark inside it: a solid steel disc here read from above as a
	# closed grey plate under the gun, though its lid stands open behind
	k._add(t, _annulus(0.27, 0.39, 0.04, 18), cam, null, lp + Vector3(0, 0.08, 0))
	k._cyl(t, 0.275, 0.275, 0.004, lp + Vector3(0, 0.082, 0), Vector3.ZERO, "plain_dark", null, 18, false)
	k._cyl(t, 0.3, 0.32, 0.05, lp + Vector3(0.0, 0.2, 0.52), Vector3(-0.35, 0, 0), cam, null, 16)
	_bx(k, t, Vector3(0.24, 0.06, 0.1), lp + Vector3(0, 0.12, 0.36), "gunmetal_w", null, Vector3.ZERO, false)
	k.roof_gun = lp + Vector3(0, 0.56, -0.35)
	# the DShK's pintle on the ring's race, its cradle under the receiver
	VehicleMounts.pintle(k, t, lp + Vector3(0, 0.12, -0.3), k.roof_gun + Vector3(0, 0, 0.1), "gunmetal_w", null, Vector2(0.03, 0.04), Vector2(0.13, 0.15))
	_dshk(k, t, k.roof_gun)
	# grab rails round the dome, the snorkel stowed across the back, a rolled
	# tarpaulin, lifting eyes
	for s: float in [-1.0, 1.0]:
		var rp := []
		for i in 5:
			var a := -1.0 + i * 0.52
			rp.append(Vector3(s * sin(PI / 2 + a) * 1.18 * 0.98, 0.36, -cos(PI / 2 + a) * 1.16 * 0.98 - 0.0))
		_path(k, t, rp, 0.016, "gunmetal_w", null, 6)
		for q in [rp[0], rp[4]]:
			_tube(k, t, q, (q as Vector3) * Vector3(0.93, 1.0, 0.93), 0.016, "gunmetal_w", null, 6, false)
		_eye(k, t, Vector3(s * 0.6, 0.7, -0.62), s * 0.5)
		k._team_mark(t, team, Vector3(s * 1.155, 0.26, 0.15), Vector3(0.02, 0.18, 0.5))
		# the turret number, painted big on both flanks of the dome as on
		# every T-55 that ever served, a little ahead of the identification
		# panel; laid on the cast curve, 12 mm out from its facets
		var number := VehicleMarkings.tactical_number(seed)
		var side: float = s
		var on_dome := func(q: Vector2) -> Vector3:
			var y := 0.47 + q.y
			var z := -0.3 - side * q.x
			return Vector3(side * (_dome_x(y, z) + 0.012), y, z)
		VehicleMarkings.digits(k, t, number, 0.17, on_dome, Vector3(s, 0.35, 0), VehicleMarkings.STENCIL_WHITE, Vector2.ZERO, "tactical")
	# (the snorkel's tube painted, as the tanks are)
	k._cyl(t, 0.16, 0.16, 1.7, Vector3(-0.15, 0.36, 1.2), Z90, "paint", Color(0.32, 0.33, 0.26), 12)
	for x: float in [-0.75, 0.45]:
		k._cyl(t, 0.175, 0.175, 0.04, Vector3(x, 0.36, 1.2), Z90, "gunmetal_w", null, 12, false)
		_bar(k, t, Vector3(x, 0.36, 1.04), Vector3(x, 0.42, 0.96), 0.04, 0.03, "gunmetal_w", null, false)
	VehicleCloth.roll(k, t, Vector3(0.82, 0.48, 0.55), 0.14, 1.1, Vector3(PI / 2, 0.55, 0), Color(0.35, 0.33, 0.24))
	_antenna(k, t, Vector3(-0.62, 0.72, 0.62), 2.1)
	# rust round the cupola and a streak down the dome's flank
	_bx(k, t, Vector3(0.012, 0.22, 0.05), Vector3(1.1, 0.25, -0.6), "paint", RUST, Vector3(0, 0.5, 0.1), false)


# --- technical / aa_tech: Toyota Hilux double cab ----------------------------------

## What the technicals were before the war: sun-faded white (most of them),
## beige, a tired light blue, maroon, dark green, silver.
const HILUX := [Color(0.72, 0.71, 0.66), Color(0.6, 0.54, 0.42), Color(0.45, 0.5, 0.53), Color(0.34, 0.15, 0.12),
	Color(0.27, 0.31, 0.25), Color(0.55, 0.56, 0.55)]
const TRIM := Color(0.12, 0.12, 0.12)  # black plastic
const PRIMER := Color(0.46, 0.46, 0.43)  # a replacement panel in grey primer
const MUD := Color(0.27, 0.22, 0.16)


## Toyota Hilux double cab (full scale): the long bonnet over the front
## axle with its grille and square headlights, the raked windscreen, the
## four-door cab, the short bed behind it with the roll bar; a pipe bull bar
## welded on the front. Rough: faded paint, a door in grey primer, rust round
## the arches, mud up the sills, a brushed-on sand camouflage on some, a
## dented tailgate hanging open. aa: a ZU-23-2 on a raised turntable in the
## bed; otherwise a DShK on a pintle with a welded gun shield.
static func _hilux(k: VehicleModels, team: int, seed: int, aa: bool) -> void:
	var m := k.root
	# A burning pickup keeps its original finish away from the bonnet.
	k.engine_deck = Vector3(0, 1.12, -1.55)
	var h := absi(hash(seed * 7919 + (31 if aa else 17)))
	var col: Color = HILUX[h % HILUX.size()]
	col = col.lerp(Color(0.55, 0.5, 0.42), 0.08 * float((h >> 3) % 3))
	var hw := 0.87
	var zf := -1.65
	var zr := 1.4
	var wr := 0.385
	var ar := 0.47
	# ladder frame, the front diff and the rear axle, the exhaust, fuel tank
	VehicleRunningGear.frame(k, m, Vector3(0, 0.44, 0), 0.36, 4.6, Vector2(0.12, 0.18), [zf, 0.0, zr])
	for z: float in [zf, zr]:
		VehicleWheelArches.tub(k, m, Vector3(0, 0.66, z), Vector3(1.22, 0.46, 0.92))
	VehicleRunningGear.axle(k, m, Vector3(0, wr, zr), 1.35, 0.055, 0.36, 0.8)
	_bx(k, m, Vector3(0.62, 0.12, 0.45), Vector3(0, 0.3, zf), "gunmetal_w")
	# (the exhaust hangs from the right frame rail, 5 cm over its centre line)
	VehicleFittings.exhaust_run(k, m, [Vector3(0.36, 0.3, 0.05), Vector3(0.36, 0.3, 2.35)], 0.032, Vector3.ZERO, Vector3.ZERO, Vector2.ZERO, 0.05)
	VehicleRunningGear.fuel_tank(k, m, Vector3(-0.45, 0.42, 0.55), Vector3(0.5, 0.26, 0.7), -1.0, "gunmetal_w", null, false)
	# the body: bonnet, front wings and the cab's lower half in one panel, the
	# bed's sides in another, their arches cut round the wheels. A technical
	# is a pickup years past its last polish, baked in the sun: its paint is
	# chalky and matte, worn through at the edges (in a showroom clear coat
	# the cab roof glinted like a toy's from the battle camera). A wreck
	# keeps the finish it was built in.
	var fin := "car_paint" if k.wreck else "paint"
	# (pressed panels: the bends of the bonnet and the nose shaded round, the
	# bonnet crowned, as the civilian pickups' are; cut as flat blocks they
	# read as a painted box beside them. A wreck keeps the cut look.)
	var roll := 0.0 if k.wreck else VmCiv.ROLL_BOXY
	VmCiv._xbody(k, m, "core_hlx_body", [-2.42, 0.5, 0.96, 0.5, 0.96, 1.13, -0.85, 1.12, -2.3, 1.02, -2.45, 0.86],
		-hw, hw, 0.04, [[zf, wr, ar]], fin, col, 8, [0.22, 0.08, 0.0, 0.0], roll)
	VmCiv._xbody(k, m, "core_hlx_bed", [1.0, 0.52, 2.44, 0.52, 2.44, 0.86, 1.0, 0.86], -hw, hw, 0.03, [[zr, wr, ar]], fin, col, 8, [], roll)
	_bx(k, m, Vector3(1.6, 0.6, 0.06), Vector3(0, 0.84, 0.98), "plain_dark")
	# the bed: its walls, the top rails rolled over their edges, the wheel
	# tubs, a ribbed floor in the body's paint, scuffed matt by years of
	# loads (bare bright steel here glared like a mirror from above)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.07, 0.3, 1.44), Vector3(s * (hw - 0.035), 1.01, 1.72), fin, col)
		VmCiv._rolled(k, m, "core_hlx_rail", Vector3(s * (hw - 0.05), 1.165, 1.72), Vector3(0.1, 0.035, 1.44), fin, col.darkened(0.1))
		VehicleWheelArches.tub(k, m, Vector3(s * 0.66, 0.96, zr), Vector3(0.2, 0.2, 0.9), s, fin, col.darkened(0.2))
	_bx(k, m, Vector3(hw * 2.0, 0.34, 0.07), Vector3(0, 1.0, 1.0), fin, col)
	# (in the body's worn paint, so the ribs' tops scuff through to bare steel)
	var bed := "plain_dark" if k.wreck else fin
	_bx(k, m, Vector3(1.6, 0.02, 1.42), Vector3(0, 0.87, 1.72), bed, col.darkened(0.35))
	for i in 6:
		_bx(k, m, Vector3(0.05, 0.02, 1.4), Vector3(-0.62 + i * 0.25, 0.885, 1.72), bed, col.darkened(0.45), Vector3.ZERO, false)
	# the tailgate hanging open on its chains, dented
	VehicleDoors.leaf(k, m, Vector3(hw * 2.0 - 0.04, 0.06, 0.34), Vector3(0, 0.82, 2.62), fin, col, Vector3(0.12, 0, 0.03), 1)
	for s: float in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.8, 1.1, 2.42), Vector3(s * 0.8, 0.86, 2.76), 0.008, "gunmetal_w", null, 4, false)
	# the glasshouse: the windscreen raked well back, the four-door cab, its
	# back window; the panes laid on its faces
	var lo := [-0.86, -0.85, 0.86, -0.85, 0.86, 0.93, -0.86, 0.93]
	var hi := [-0.71, -0.22, 0.71, -0.22, 0.73, 0.86, -0.73, 0.86]
	# (the roof crowned twice as hard as a car's: a pickup's cab roof is
	# pressed to a tighter curve across its narrow width, so the sun glints
	# off it in a small spot rather than a hard white blob across its front)
	VmCiv._yloft(k, m, "core_hlx_gh", [lo, hi], [1.12, 1.79], 0.05, fin, col, Vector3.ZERO, 0.6)
	var r0 := VehicleModels.ring_y(VehicleModels._v2(lo), 1.12)
	var r1 := VehicleModels.ring_y(VehicleModels._v2(hi), 1.79)
	var inside := Vector3(0, 1.45, 0.1)
	if not k.burnt:
		VmCiv._pane(k, m, "core_hlx_ws", VmCiv._face(r0, r1, 0), inside, 0.03, 0.97, 0.05, 0.94, 0.0, 0.012, "glass")
		VmCiv._pane(k, m, "core_hlx_bw", VmCiv._face(r0, r1, 2), inside, 0.14, 0.86, 0.2, 0.85, 0.0, 0.012, "glass")
		for f in [1, 3]:
			var a := 0.0 if f == 1 else 0.48
			VmCiv._pane(k, m, "core_hlx_sw%d" % f, VmCiv._face(r0, r1, f), inside, a + 0.03, a + 0.49, 0.07, 0.9, 0.0, 0.012, "glass")
			VmCiv._pane(k, m, "core_hlx_sv%d" % f, VmCiv._face(r0, r1, f), inside, 0.52 - a, 0.97 - a, 0.07, 0.9, 0.0, 0.012, "glass")
	# the doors: shut lines, handles; one rear door a replacement in primer
	var primer := (h >> 5) % 2 == 0
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.83, 0.08, 0.93]:
			VehicleBody.seam(k, m, [Vector3(s * (hw + 0.003), 1.17, z), Vector3(s * (hw + 0.003), 0.51, z)])
		for z: float in [-0.12, 0.74]:
			VehicleDoors.pull(k, m, Vector3(s * (hw + 0.002), 1.04, z), Vector3(s, 0, 0), Vector3.BACK, 0.13, 0.006, "plain_dark", TRIM)
		_bx(k, m, Vector3(0.012, 0.022, 3.3), Vector3(s * (hw + 0.002), 1.0, -0.75), fin, col.darkened(0.25), Vector3.ZERO, false)
		# (the mud up the sills is the surface's own, splashed up from the
		# wheels: a brown slab along each sill here read as a plank nailed on)
		# wing mirrors at the windscreen's foot
		VehicleFittings.mirror(k, m, Vector3(s * 1.02, 1.22, -0.74), Vector2(0.20, 0.14), -s * 0.3, [Vector3(s * 0.84, 1.16, -0.78)])
		# arches flared in black, rust round the rear ones, the side step
		VmCiv._flare(k, m, "core_hlx_ff%d" % int(s), zf, wr, ar - 0.01, ar + 0.06, s * hw - 0.03, s * hw + 0.035, 0.25, PI - 0.25, "plain_dark", TRIM, 7)
		VmCiv._flare(k, m, "core_hlx_fr%d" % int(s), zr, wr, ar - 0.01, ar + 0.06, s * hw - 0.03, s * hw + 0.035, 0.25, PI - 0.25, "plain_dark", TRIM, 7)
		# rust bubbling through the paint behind the rear arch: a film on the
		# panel clear of the arch's flare, not a board standing off it and
		# over the wheel opening
		# (a wreck keeps the old film; on a running truck the rust is a
		# bubbled patch, dark and flaking at its heart where the water sits
		# and fading upward into a stained halo through the paint: a hard
		# rotated strip of one brown read as a sticker)
		if k.wreck:
			_bx(k, m, Vector3(0.004, 0.1, 0.36), Vector3(s * (hw + 0.002), 0.74, zr + 0.57), "paint", RUST, Vector3(0.5, 0, 0), false)
		else:
			# Rust starts where mud and water sit, in the lip round the back
			# of the arch, and creeps up and back from it: a ragged crescent of
			# blisters round the arch's rear quarter, flaking dark in the lip
			# and fading through stained paint to a faint halo above (one
			# tilted blob read as a rhombus glued on). Each blister's own
			# outline and size, darkest low down, all on the bed's flank
			# between its foot (0.52 m) and its rail: (angle round the arch
			# from the back, out from its edge, length, height, how far gone).
			# (each film a little prouder than the one under it, so where two
			# overlap neither flickers through the other)
			var rust: Array = [[0.8, 0.21, 0.34, 0.2, 0.22], [0.5, 0.07, 0.24, 0.14, 0.8], [0.8, 0.07, 0.22, 0.13, 0.62], [1.1, 0.07, 0.18, 0.1, 0.45]]
			for i in rust.size():
				var b: Array = rust[i]
				var a: float = b[0]
				var at := Vector2(zr, wr) + Vector2(cos(a), sin(a)) * (ar + float(b[1]))
				var size := Vector2(float(b[2]), float(b[3]))
				var gone: float = b[4]
				_daub(k, m, s * (hw + 0.0015 + 0.0008 * i), at.x, at.y, size, -a, int(a * 10.0) % 3, col.lerp(RUST, gone * 0.75), "paint")
				if gone > 0.3:
					# (the flaking heart of each blister, nearer the lip)
					var heart := at - Vector2(cos(a), sin(a)) * 0.02
					_daub(k, m, s * (hw + 0.0048), heart.x, heart.y, size * 0.55, -a + 0.5, int(a * 10.0 + 1.0) % 3, col.lerp(RUST, gone).lerp(RUST_D, gone * 0.7), "paint")
			# (and a run of it along the quarter panel's foot to the bed's end)
			_daub(k, m, s * (hw + 0.0045), zr + ar + 0.28, 0.6, Vector2(0.3, 0.07), 0.0, 2, col.lerp(RUST_D, 0.6), "paint")
		# the side step: a black moulded running board, its ribs along it (in
		# bright steel with eight ribs across it, it read as piano keys
		# along the sill from the battle camera)
		VehicleFrames.step(k, m, Vector3(s * 0.84, 0.45, -0.38), Vector2(0.12, 1.66), Vector3.ZERO, "steel" if k.wreck else "plain_dark", Color(0.4, 0.4, 0.4) if k.wreck else TRIM)
		# (on its two brackets up to the sill: on its own it hung in the air)
		for z: float in [-0.95, 0.2]:
			_bx(k, m, Vector3(0.04, 0.08, 0.06), Vector3(s * 0.8, 0.49, z), "gunmetal_w", null, Vector3.ZERO, false)
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.76, wr, z), wr, 0.27, "steel", Color(0.58, 0.58, 0.55))
		# tail lights up the bed's corners, set in its back face
		VehicleFittings.signal_lens(k, m, Vector3(s * (hw - 0.05), 1.0, 2.44), Vector2(0.1, 0.3), Color(0.5, 0.06, 0.05))
		VehicleFittings.signal_lens(k, m, Vector3(s * (hw - 0.05), 0.8, 2.44), Vector2(0.1, 0.08), Color(0.75, 0.45, 0.12))
	if primer and not k.burnt:
		if k.wreck:
			_bx(k, m, Vector3(0.014, 0.6, 0.8), Vector3(hw + 0.006, 0.82, 0.5), fin, PRIMER, Vector3(0, 0, -0.01), false)
		else:
			# The replacement rear door is the whole pressing in primer, so
			# it ends at the door's own shut lines, its corners rounded as the
			# door's are, laid on the panel (a box 1.4 cm proud stood off the
			# flank as a grey board). Primer is a dead-flat, even grey with no
			# clear coat to wear through, so it takes the plain moulded finish,
			# not the service paint's chipped and speckled one (which read as
			# a texture swatch glued on).
			var door := PackedVector2Array()
			var corners: Array[Vector2] = [Vector2(0.14, 0.58), Vector2(0.87, 0.58), Vector2(0.87, 1.06), Vector2(0.14, 1.06)]
			for i in 4:
				for j in 3:
					var a := PI + i * PI * 0.5 + j * PI * 0.25
					door.append(corners[i] + Vector2(cos(a), sin(a)) * 0.04)
			VehicleMarkings.polygons(k, m, [door], func(q: Vector2) -> Vector3: return Vector3(hw + 0.002, q.y, q.x), Vector3.RIGHT, PRIMER, "plain_dark", false)
	# brushed-on sand camouflage on some: blotches down the flanks
	if (h >> 7) % 3 == 0 and not k.burnt:
		var bc := Color(0.55, 0.47, 0.33) if col.v < 0.6 else Color(0.42, 0.36, 0.26)
		for e in [[1, -0.4, 0.8, 0.5], [1, 0.5, 0.92, 0.42], [-1, -0.1, 0.75, 0.6], [-1, 1.7, 0.98, 0.5], [1, 1.9, 0.98, 0.36]]:
			if k.wreck:
				var sx := float(e[0]) * (hw + 0.007)
				for j in 2:
					_bx(k, m, Vector3(0.012, 0.2 - j * 0.07, float(e[3]) * (1.0 - j * 0.35)), Vector3(sx + float(e[0]) * j * 0.002, float(e[2]) + j * 0.08, float(e[1]) + (j * 0.14 if j == 1 else 0.0)), fin, bc, Vector3(0.22 - j * 0.6, 0, 0), false)
				continue
			# Each blotch is brushed on by hand: a ragged daub of sand with a
			# thinner, dry-brushed margin round it where the brush ran out and
			# the paint under it shows through, painted on the panel (boxes
			# with straight edges in one flat tan read as cut cardboard).
			var x := float(e[0]) * (hw + 0.002)
			var v := absi(int(float(e[1]) * 10.0)) % 3
			var at := Vector2(float(e[1]), float(e[2]))
			var size := Vector2(float(e[3]), 0.2)
			_daub(k, m, x, at.x, at.y, size * 1.18, 0.12, v, col.lerp(bc, 0.55), fin)
			_daub(k, m, x + float(e[0]) * 0.001, at.x + 0.02, at.y + 0.005, size, 0.16, v + 1, bc, fin)
	# the face: grille, square headlights, indicators, a dented bumper and the
	# pipe bull bar welded across it, the number plate long gone
	var nz := -2.45
	VehicleFittings.grille(k, m, Vector3(0, 0.88, nz - 0.03), Vector2(0.94, 0.3), Vector3(0, PI, 0), "steel", Color(0.55, 0.55, 0.53), 4)
	_bx(k, m, Vector3(0.24, 0.07, 0.03), Vector3(0, 0.88, nz - 0.045), "steel", Color(0.6, 0.6, 0.58), Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		VehicleFittings.lamp_unit(k, m, Vector3(s * 0.66, 0.9, nz + 0.01), Vector3(0.3, 0.17, 0.05), -1.0, [Rect2(Vector2(-s * 0.06, 0), Vector2(0.18, 0.12))], Rect2(Vector2(s * 0.1, 0), Vector2(0.07, 0.12)))
	VehicleMounts.bumper(k, m, Vector3(1.8, 0.2, 0.16), Vector3(0, 0.6, nz - 0.04), "steel", Color(0.45, 0.45, 0.44), Vector3(0, 0, 0.02))
	VehicleFrames.bull_bar(k, m, [[Vector3(-0.7, 0.62, nz - 0.2), Vector3(-0.7, 1.08, nz - 0.18), Vector3(0.7, 1.08, nz - 0.18), Vector3(0.7, 0.62, nz - 0.2)],
		[Vector3(-0.7, 0.86, nz - 0.19), Vector3(0.7, 0.86, nz - 0.19), 0.03],
		[Vector3(-0.7, 0.62, nz - 0.2), Vector3(-0.7, 0.55, nz + 0.05), 0.03], [Vector3(0.7, 0.62, nz - 0.2), Vector3(0.7, 0.55, nz + 0.05), 0.03]], 0.035, "gunmetal_w", null, 2)
	# the rear: a step bumper, the tow ball on it. (The ball's mount runs
	# along the bumper's top from its plate, hidden in the bed's back panel;
	# the box is 1/6 m tall for a ball 4 cm in radius, its crown 0.76 m up.)
	VehicleMounts.bumper(k, m, Vector3(1.7, 0.14, 0.14), Vector3(0, 0.55, 2.52), "steel", Color(0.42, 0.42, 0.41))
	var ball := Vector3(0.14, 1.0 / 6.0, 0.3)
	VehicleMounts.hitch(k, m, Vector3(0, 0.76 - ball.y * 0.5, 2.476), ball, Vector3.ZERO, "ball")
	# wipers, a whip antenna on the wing
	for x: float in [-0.32, 0.22]:
		VehicleFittings.parked_wiper(k, m, Vector3(x, 1.15, -0.81), 0.48, Vector3(-0.8, 0, 0.1))
	VehicleFittings.antenna(k, m, Vector3(0.82, 1.1, -0.95), 1.38)
	# the roll bar behind the cab: the hoop and its stays back to the bed rails
	VehicleFrames.roll_bar(k, m, [[Vector3(-0.8, 1.17, 1.12), Vector3(-0.74, 1.86, 1.08), Vector3(0.74, 1.86, 1.08), Vector3(0.8, 1.17, 1.12)],
		[Vector3(-0.76, 1.8, 1.1), Vector3(-0.8, 1.17, 1.62), 0.03], [Vector3(0.76, 1.8, 1.1), Vector3(0.8, 1.17, 1.62), 0.03]], 0.036)
	k._team_mark(m, team, Vector3(hw + 0.008, 0.85, -0.4), Vector3(0.02, 0.18, 0.42))
	k._team_mark(m, team, Vector3(-hw - 0.008, 0.85, -0.4), Vector3(0.02, 0.18, 0.42))
	if aa:
		_zu23(k, team)
	else:
		_hilux_dshk(k)


## A daub of paint (or rust) laid on a flank at `x`, facing out along its
## sign: a ragged ten-sided blob `size` long (z) and tall (y), centred at
## (z, y) and turned by `tilt`. `v` picks one of three outlines, so blotches
## down one truck aren't one stamp.
static func _daub(k: VehicleModels, m: Node3D, x: float, z: float, y: float, size: Vector2, tilt: float, v: int, col: Color, mat: String) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		var r := 1.0 + 0.17 * sin(i * 2.3 + v * 1.9) + 0.09 * sin(i * 4.7 + v * 0.8)
		pts.append(Vector2(cos(a) * size.x * 0.5, sin(a) * size.y * 0.5).rotated(tilt) * r + Vector2(z, y))
	VehicleMarkings.polygons(k, m, [pts], func(q: Vector2) -> Vector3: return Vector3(x, q.y, q.x), Vector3(signf(x), 0, 0), col, mat, false)


## The DShK on a tall pedestal welded to the bed floor, its bore 40 cm clear
## of the cab roof so it fires forward over the cab, behind a small welded
## shield; the gunner stands on the bed floor behind it, the grips at his
## chest. The spare stands against the cab's back, ammunition and a jerrycan
## in the front corner, so the floor behind the gun is his.
static func _hilux_dshk(k: VehicleModels) -> void:
	var m := k.root
	var px := Vector3(0, 0.89, 1.5)
	var pivot := px + Vector3(0, 1.02, 0)
	# kit in the bed's front: the spare upright against the cab with a strap
	# over it to the wall, two ammo boxes and a jerrycan in the right corner
	VehicleWheels.spare(k, m, Vector3(-0.42, 1.25, 1.17), 0.36, 0.25, Vector3(PI / 2, 0, 0), "steel", Color(0.5, 0.5, 0.48), "road")
	var lash := VehicleCargo.kit(k, m, Vector3(-0.42, 1.25, 1.17), 44)
	if lash == null or k.wreck or lash.randf() < 0.3:
		_bx(k, m, Vector3(0.04, 0.006, 0.32), Vector3(-0.42, 1.615, 1.14), "webbing", Color(0.3, 0.28, 0.2), Vector3.ZERO, false)
		_bx(k, m, Vector3(0.04, 0.46, 0.006), Vector3(-0.42, 1.38, 1.04), "webbing", Color(0.3, 0.28, 0.2), Vector3.ZERO, false)
	else:
		# (or, as most crews do, roped to the roll bar's leg: a hitch round
		# the tube, across the tyre's face and through its wheel's centre,
		# behind it along the cab and back round the leg, tied off)
		var line := Color(0.5, 0.45, 0.33) if lash.randf() < 0.5 else Color(0.2, 0.3, 0.4)
		VehicleCloth.rope(k, m, [Vector3(-0.77, 1.45, 1.15), Vector3(-0.672, 1.505, 1.305), Vector3(-0.42, 1.25, 1.315), Vector3(-0.42, 1.25, 1.026), Vector3(-0.8, 1.25, 1.026), Vector3(-0.79, 1.25, 1.16)], 0.006, line, [0, 5])
	for i in 2:
		_ammo_can(k, m, Vector3(0.36, 0.99 + i * 0.205, 1.22), 0.0, Color(0.27, 0.3, 0.21))
	_jerry(k, m, Vector3(0.62, 1.125, 1.22), Color(0.32, 0.34, 0.24), 0.0)
	if lash != null and not k.wreck:
		# the jerrycan roped round its waist to the rail, so it can't walk
		VehicleCloth.rope(k, m, [Vector3(0.8, 1.185, 1.05), Vector3(0.712, 1.2, 1.045), Vector3(0.528, 1.2, 1.045), Vector3(0.528, 1.2, 1.395), Vector3(0.712, 1.2, 1.395), Vector3(0.8, 1.185, 1.42)], 0.006, Color(0.5, 0.45, 0.33), [0, 5])
	# Sandbags along both bed rails behind the roll bar's stays, two courses
	# on most, where the gunner crouches out of the side's small-arms fire
	# (a crew that has filled its sacks: VehicleCloth.sack_lot)
	var lot := VehicleCloth.sack_lot(k)
	for s: float in [-1.0, 1.0]:
		var bags := VehicleCargo.kit(k, m, Vector3(s * 0.82, 1.18, 2.0), 43)
		if bags != null and bags.randf() < 0.6:
			VehicleCloth.sandbags(k, m, Vector3(s * 0.82, 1.183, 1.72), Vector3(s * 0.82, 1.183, 2.42), bags, lot, 2 if bags.randf() < 0.7 else 1, true)
	# a steel plate bolted over each rear door on some, cut from whatever the
	# crew found, its cut edges rusting (the front doors keep the side's mark)
	var plate := VehicleCargo.kit(k, m, Vector3(0, 0.8, 0.5), 45)
	if plate != null and not k.wreck and plate.randf() < 0.4:
		# (Mild steel plate comes off the stack in its blue-black mill scale,
		# or a crew slaps the truck's own primer over it; it rusts first
		# along its cut edges and where water runs off its bolts, a stain
		# streaking down the door under it. Rusted across its whole face in
		# one even speckle, the plate read as a texture swatch glued on.)
		var steel: Color = [Color(0.3, 0.29, 0.26), Color(0.4, 0.4, 0.38), Color(0.24, 0.22, 0.2)][plate.randi_range(0, 2)]
		for s: float in [-1.0, 1.0]:
			VehicleMounts.applique(k, m, Vector3(s * 0.893, 0.8, 0.5), Vector3(0.78, 0.4, 0.012), Vector3(0, s * PI / 2, 0), "gunmetal_w", steel, Vector2i(3, 2))
			for z: float in [0.2, 0.62]:
				# (on the door's skin, from under the plate's foot to the sill)
				_daub(k, m, s * 0.873, z, 0.57, Vector2(0.06, 0.09), 0.0, int(z * 10.0) % 3, Color(0.36, 0.22, 0.13), "paint")
	# the pedestal: the post on its plate welded to the bed floor, braced to
	# its corners; the traversing head on it with the yoke, the gun, the
	# shield, a rust streak down its face
	var t := k._pivot(m, pivot)
	k.turret = t
	VehicleMounts.pedestal(k, m, px, pivot, t, "gunmetal_w", null, 0.44, Vector2(0.045, 0.052), 4, Vector3(0.085, 0.26, 0.13))
	var tip := _dshk(k, t, Vector3(0, 0.3, 0.02))
	k.mg_tip = k._tip(t, tip)
	VehicleMounts.gun_shield(k, t, Vector3(0, 0.322, -0.4), Vector2(0.66, 0.4), "paint", Color(0.27, 0.28, 0.23), 0.12, Vector2(0.16, -0.5), Vector2(0.11, 0.17), 0.02)
	_bx(k, t, Vector3(0.1, 0.14, 0.003), Vector3(0.18, 0.403, -0.402), "paint", RUST, Vector3(0.12, 0, 0), false)
	k.gunner_floor = {"on": m, "y": px.y, "area": Rect2(Vector2(-0.62, 1.45), Vector2(1.24, 0.85))}


## A ZU-23-2 (its wheeled carriage dropped) on a turntable raised on a
## welded box in the bed: the two 23 mm guns side by side in their cradle,
## the long barrels with their flash hiders, the ammunition boxes outboard,
## the gunner's seat and the ZAP-23 sight on the left, the second seat right.
static func _zu23(k: VehicleModels, team: int) -> void:
	var m := k.root
	var g := Color(0.33, 0.35, 0.27)
	var px := Vector3(0, 0.88, 1.62)
	_bx(k, m, Vector3(1.0, 0.3, 0.9), px + Vector3(0, 0.15, 0), "steel", Color(0.32, 0.31, 0.27))
	_bx(k, m, Vector3(1.06, 0.04, 0.96), px + Vector3(0, 0.31, 0), "gunmetal_w")
	# loose kit in the corners: ammunition boxes, a jerrycan
	for i in 2:
		VehicleCargo.crate_stack(k, m, Vector3(-0.72, 0.88, 1.95), Vector3(0.22, 0.2, 0.5), Vector3i.ONE, "wood_dark", null, 0.0, [], 0.12, Color(0.28, 0.26, 0.2), 0.1 * i)
	_jerry(k, m, Vector3(0.7, 1.12, 2.2), Color(0.32, 0.34, 0.24), 0.2)
	# Sandbags round the mount on some: a wall across the bed behind the
	# turntable's box, under the platform's swing, and along the left rail
	# over the ammunition (the jerrycan has the right corner)
	var lot := VehicleCloth.sack_lot(k)
	var bags := VehicleCargo.kit(k, m, Vector3(0, 0.88, 2.26), 43)
	if bags != null and bags.randf() < 0.6:
		VehicleCloth.sandbags(k, m, Vector3(-0.56, 0.88, 2.26), Vector3(0.52, 0.88, 2.26), bags, lot, 2)
		VehicleCloth.sandbags(k, m, Vector3(-0.82, 1.183, 1.72), Vector3(-0.82, 1.183, 2.42), bags, lot, 1 if bags.randf() < 0.5 else 2, true)
	var t := k._pivot(m, px + Vector3(0, 0.33, 0))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.04, 0), 0.46, 0.5, 0.08, "paint", g, 18)
	_bx(k, t, Vector3(0.95, 0.06, 1.0), Vector3(0, 0.1, 0.1), "paint", g)
	# the side frames carrying the trunnions
	for s: float in [-1.0, 1.0]:
		k._add(t, VehicleModels.extrude_x("core_zu_frame", [-0.3, 0.12, 0.42, 0.12, 0.3, 0.42, -0.12, 0.62, -0.3, 0.5], -0.025, 0.025), "paint", g, Vector3(s * 0.4, 0, 0))
	# the cradle, raised a little, with both guns
	var el := k._pivot(t, Vector3(0, 0.58, -0.02))
	el.rotation.x = 0.2
	for s: float in [-1.0, 1.0]:
		var gx: float = s * 0.17
		_bx(k, el, Vector3(0.15, 0.22, 0.82), Vector3(gx, 0.0, 0.05), "paint", g)
		_bx(k, el, Vector3(0.12, 0.06, 0.5), Vector3(gx, 0.13, 0.0), "gunmetal_w")
		VehicleWeapons.autocannon(k, el, Vector3(gx, 0.02, -0.325), Vector3(gx, 0.02, -2.62), Vector2(0.048, 0.55), Vector2(0.03, 0.026), Vector2(0.05, 0.24), "gunmetal_w", null, 1)
		# the ammunition box outboard of each gun, the spent-case chute under it
		_bx(k, el, Vector3(0.17, 0.3, 0.56), Vector3(s * 0.38, 0.02, 0.1), "paint", g.darkened(0.08))
		_bx(k, el, Vector3(0.18, 0.03, 0.58), Vector3(s * 0.38, 0.18, 0.1), "paint", g.darkened(0.2))
		_bx(k, el, Vector3(0.1, 0.16, 0.2), Vector3(gx, -0.18, 0.15), "gunmetal_w")
	_bx(k, el, Vector3(0.22, 0.1, 0.4), Vector3(0, -0.05, -0.2), "paint", g)
	k.mg_tip = k._tip(el, Vector3(0, 0.02, -2.63))
	# the gunner's seat and his sight on the left, the hand wheels, the second
	# seat on the right
	_bx(k, t, Vector3(0.05, 0.4, 0.06), Vector3(-0.3, 0.75, -0.3), "gunmetal_w")
	VehicleMounts.sight(k, t, Vector3(-0.3, 0.98, -0.32), Vector3(0.14, 0.16, 0.22), [Rect2(Vector2(0, 0.02), Vector2(0.1, 0.08))], "paint", g)
	for s: float in [-1.0, 1.0]:
		VehicleCab.seat(k, t, Vector3(s * 0.38, 0.42, 0.55), Vector3(0.32, 0.2, 0.3), Vector3.ZERO, Color(0.2, 0.2, 0.17))
		_tube(k, t, Vector3(s * 0.38, 0.12, 0.55), Vector3(s * 0.38, 0.4, 0.55), 0.025, "gunmetal_w", null, 6)
		k._cyl(t, 0.11, 0.11, 0.02, Vector3(s * 0.48, 0.5, 0.22), Z90, "gunmetal_w", null, 12, false)


# --- humvee: M1151 HMMWV --------------------------------------------------------------

## M1151 up-armoured HMMWV (full scale): wide and low on its big tyres, the
## one-piece bonnet over the wheels with its rubber latches sloping down to
## the slotted grille, the headlights in the wing corners, the bumper with
## the winch and the lifting shackles; the boxy armoured cab with the split
## near-vertical windscreen and four heavy doors with their thick little
## windows; the rear deck behind it; the O-GPK gunner's turret on the roof -
## faceted shields with ballistic windows round an M2.
static func _humvee(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	var hw := 1.09
	var zf := -1.66
	var zr := 1.66
	var wr := 0.47
	var ar := 0.6
	# the chassis under the body: frame, the wheel wells over each axle, the
	# portal hub housings and the double wishbones out to them (each housing
	# is its wheel's knuckle)
	_bx(k, m, Vector3(1.0, 0.3, 4.4), Vector3(0, 0.58, 0.0), "gunmetal_w")
	for z: float in [zf, zr]:
		VehicleWheelArches.tub(k, m, Vector3(0, 0.82, z), Vector3(1.5, 0.5, 1.15))
		for s: float in [-1.0, 1.0]:
			_bx(k, m, Vector3(0.16, 0.3, 0.24), Vector3(s * 0.72, wr, z), "gunmetal_w")
			VehicleRunningGear.wishbone(k, m, Vector3(s * 0.3, 0.45, z), Vector3(s * 0.66, wr - 0.06, z), Vector3(s * 0.3, 0.72, z - 0.05), Vector3(s * 0.66, wr + 0.12, z - 0.05), Vector2(0.08, 0.06), Vector2(0.07, 0.05), Vector3.ZERO, Vector3.ZERO, 0.06, false)
	# the body: bonnet over the wings, the cab's lower half and the rear deck
	# in one panel, the arches cut round the wheels
	# (the bonnet's bend down into the grille shaded round and its top
	# crowned, its chamfers crisp; a wreck keeps the cut look)
	VmCiv._xbody(k, m, "core_hmv_body", [-2.42, 0.62, 2.46, 0.62, 2.47, 1.3, 0.92, 1.33, -0.8, 1.33, -2.32, 1.14, -2.46, 1.02],
		-hw, hw, 0.04, [[zf, wr, ar], [zr, wr, ar]], cam, null, 8, [], 0.0 if k.wreck else VmCiv.ROLL_BOXY)
	_bx(k, m, Vector3(1.9, 0.5, 4.0), Vector3(0, 0.92, 0.0), "plain_dark")
	# the wheels, their mud flaps
	for s: float in [-1.0, 1.0]:
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.9, wr, z), wr, 0.36, cam)
		VehicleFittings.mudflap(k, m, Vector3(s * 0.9, 0.42, zf + 0.68), Vector2(0.36, 0.42))
		VehicleFittings.mudflap(k, m, Vector3(s * 0.9, 0.42, zr + 0.66), Vector2(0.36, 0.42))
	# the bonnet: its seam and the raised middle, the rubber T-latches either
	# side, the intake grille on the right
	_bx(k, m, Vector3(1.3, 0.04, 1.3), Vector3(0, 1.26, -1.5), cam, null, Vector3(-0.115, 0, 0))
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.012, 0.03, 1.55), Vector3(s * 0.66, 1.25, -1.55), "plain_dark", null, Vector3(-0.115, 0, 0), false)
		for z: float in [-2.2, -1.0]:
			_bx(k, m, Vector3(0.04, 0.12, 0.06), Vector3(s * (hw + 0.012), 1.08 + (z + 2.2) * 0.12, z), "rubber", null, Vector3.ZERO, false)
	# (laid on the bonnet's slope, its face 3 cm proud so the recessed core
	# clears the panel, as the deck grilles stand; its slats across the car)
	VehicleFittings.grille(k, m, Vector3(0.84, 1.316, -1.153), Vector2(0.36, 0.42), Vector3(-PI / 2 - 0.115, 0, 0), "gunmetal_w", null, 5)
	# an air-recognition panel, folded, tied across the bonnet's raised middle
	VehicleEquipment.recognition_panel(k, m, Vector3(0, 1.2512, -1.7506), Vector3(-0.115, 0, 0), true)
	# the face: the slotted grille, headlights in the wing corners, the
	# indicators, the bumper with its winch and lifting shackles
	var nz := -2.46
	VehicleFittings.grille(k, m, Vector3(0, 0.88, nz - 0.025), Vector2(1.16, 0.4), Vector3(0, PI, 0), cam, null, 9, true)
	for s: float in [-1.0, 1.0]:
		VehicleFittings.lamp_unit(k, m, Vector3(s * 0.84, 0.98, nz - 0.01), Vector3(0.28, 0.2, 0.06), -1.0, [Vector3(s * 0.04, 0, 0.075)], Rect2(Vector2(-s * 0.1, 0), Vector2(0.06, 0.06)), "bar", Vector3(0.28, 0.24, 0.07))
		_shackle(k, m, Vector3(s * 0.62, 0.66, nz - 0.18))
	VehicleMounts.bumper(k, m, Vector3(2.08, 0.22, 0.2), Vector3(0, 0.66, nz - 0.06), "gunmetal_w")
	VehicleEquipment.winch(k, m, Vector3(0, 0.66, nz - 0.18), Vector3(0.5, 0.2, 0.2))
	# the cab: armoured walls lofted from the belt to the roof
	var lo := [-1.06, -0.8, 1.06, -0.8, 1.06, 0.92, -1.06, 0.92]
	var hi := [-1.0, -0.68, 1.0, -0.68, 1.0, 0.88, -1.0, 0.88]
	var roof := 1.92
	# (its armoured roof is a welded plate, barely crowned)
	VmCiv._yloft(k, m, "core_hmv_cab", [lo, hi], [1.32, roof], 0.03, cam, null, Vector3.ZERO, 0.1)
	var r0 := VehicleModels.ring_y(VehicleModels._v2(lo), 1.32)
	var r1 := VehicleModels.ring_y(VehicleModels._v2(hi), roof)
	var inside := Vector3(0, 1.6, 0.1)
	if not k.burnt:
		# the split windscreen, thick armoured glass in heavy frames
		for e in [[0.05, 0.47], [0.53, 0.95]]:
			VehicleMaterials.glaze(k, VmCiv._pane(k, m, "core_hmv_ws%d" % int(float(e[0]) * 100), VmCiv._face(r0, r1, 0), inside, float(e[0]), float(e[1]), 0.12, 0.88, 0.0, 0.02, "glass", ARMOR_GLASS), "armor_glass", ARMOR_GLASS)
		# the door windows, small and square; the cab's back window
		for f in [1, 3]:
			for e in [[0.12, 0.36], [0.6, 0.84]]:
				var u0 := float(e[0]) if f == 1 else 1.0 - float(e[1])
				VehicleMaterials.glaze(k, VmCiv._pane(k, m, "core_hmv_sw%d_%d" % [f, int(u0 * 100)], VmCiv._face(r0, r1, f), inside, u0, u0 + 0.24, 0.2, 0.78, 0.0, 0.02, "glass", ARMOR_GLASS), "armor_glass", ARMOR_GLASS)
		VehicleMaterials.glaze(k, VmCiv._pane(k, m, "core_hmv_bw", VmCiv._face(r0, r1, 2), inside, 0.32, 0.68, 0.35, 0.8, 0.0, 0.02, "glass", ARMOR_GLASS), "armor_glass", ARMOR_GLASS)
	# the doors: heavy armoured slabs proud of the body, their seams, hinges
	# and the big latch handles
	for s: float in [-1.0, 1.0]:
		for e in [[-0.78, 0.04], [0.06, 0.88]]:
			var z0 := float(e[0])
			var z1 := float(e[1])
			var surface := VehicleSurface.quad([Vector3(s * (hw + 0.005), 0.69, z0 + 0.02), Vector3(s * (hw + 0.005), 0.69, z1 - 0.02), Vector3(s * (hw + 0.005), 1.31, z1 - 0.02), Vector3(s * (hw + 0.005), 1.31, z0 + 0.02)], Vector3(0, 1.0, (z0 + z1) * 0.5))
			VehicleDoors.closed(k, m, surface, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), [Vector2(0.07, 0.18), Vector2(0.07, 0.82)], Vector2(0.82, 0.78), cam, null, "armored")
		# the wing mirrors on their arms
		VehicleFittings.mirror(k, m, Vector3(s * 1.32, 1.56, -0.74), Vector2(0.20, 0.26), -s * 0.3, [Vector3(s * 1.08, 1.42, -0.72)])
		# armour over the rear deck's sides
		_bx(k, m, Vector3(0.05, 0.12, 1.5), Vector3(s * (hw - 0.02), 1.39, 1.68), cam)
		k._team_mark(m, team, Vector3(s * (hw + 0.052), 1.0, -0.38), Vector3(0.02, 0.18, 0.5))
	# the rear: the deck lid, tail lights in the corners, the pintle, jerrycans
	_bx(k, m, Vector3(2.1, 0.04, 1.5), Vector3(0, 1.33, 1.68), cam)
	_bx(k, m, Vector3(2.12, 0.62, 0.05), Vector3(0, 1.0, 2.47), cam)
	for s: float in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 0.88, 1.1, 2.49))
		_jerry(k, m, Vector3(s * 0.62, 1.58, 2.25), OD, PI / 2)
		_antenna(k, m, Vector3(s * 0.95, 1.35, 2.3), 2.6 if s < 0.0 else 2.0)
	VehicleMounts.bumper(k, m, Vector3(1.9, 0.16, 0.16), Vector3(0, 0.68, 2.5), "gunmetal_w")
	VehicleMounts.hitch(k, m, Vector3(0, 0.66, 2.6), Vector3(0.16, 0.14, 0.2))
	if team >= 0:
		# the bumper code on the front bumper either side of the winch, and
		# on the back wall over the rear bumper
		var code := VehicleMarkings.bumper_code(seed, VehicleMarkings.US_INFANTRY + VehicleMarkings.US_ARMOR + VehicleMarkings.US_CAVALRY)
		VehicleMarkings.bumper(k, m, code, 0.075, 0.41, 0.66, nz - 0.16, Vector3.FORWARD, 0.27)
		VehicleMarkings.bumper(k, m, code, 0.08, 0.42, 0.93, 2.495, Vector3.BACK, 0.5)
	k._bag(m, Vector3(0.6, 0.32, 0.5), Vector3(0.0, 1.51, 1.85), "canvas", BAG, Vector3(0, 0.15, 0))
	# --- the gunner's turret: an O-GPK on the roof ring, turning whole with
	# its gun. The ring on its race over the open hatch, the steel shields
	# round it in faces, each with a thick ballistic window at the gunner's
	# eye level (open at the back, where he climbs in); the M2 on its cradle
	# at the ring's front, its barrel out through the front shield's slot.
	# He stands in the hatch on his platform, chest and head inside the
	# shields.
	var t := k._pivot(m, Vector3(0, roof, 0.15))
	k.turret = t
	_hatch_ring(k, t, 0.56, 0.68, 0.1, 0.78, cam)
	var ap := 0.72
	var face_w := ap * 2.0 * tan(PI / 8.0)
	var top := 1.05
	for i in range(-3, 4):
		if i == 0:
			# the gun's slot, a small window over it for laying
			_shield_face(k, t, 0.0, ap, face_w, 0.13, top, [Rect2(-0.065, 0.3, 0.13, 0.38), Rect2(-0.17, 0.74, 0.34, 0.24)], [false, true], cam)
		else:
			_shield_face(k, t, float(i) * PI / 4.0, ap, face_w, 0.13, top, [Rect2(-face_w * 0.34, 0.64, face_w * 0.68, 0.34)], [true], cam)
	# the posts where the faces meet, bolted to the deck at their feet
	var corner := ap / cos(PI / 8.0) - 0.015
	for i in range(-3, 3):
		var a := (float(i) + 0.5) * PI / 4.0
		var c := Basis(Vector3.UP, a) * Vector3(0, 0, -corner)
		k._add(t, BevelMesh.make(Vector3(0.055, top - 0.13, 0.055), 0.01), cam, null, c + Vector3(0, (top + 0.13) * 0.5, 0), Vector3(0, a, 0))
		k._add(t, BevelMesh.make(Vector3(0.09, 0.02, 0.09), 0.004), "gunmetal_w", null, c + Vector3(0, 0.14, 0), Vector3(0, a, 0))
	# the open back's edge posts, a grab handle on each
	for s: float in [-1.0, 1.0]:
		var a := s * 3.5 * PI / 4.0
		var c := Basis(Vector3.UP, a) * Vector3(0, 0, -corner)
		k._add(t, BevelMesh.make(Vector3(0.055, top - 0.13, 0.055), 0.01), cam, null, c + Vector3(0, (top + 0.13) * 0.5, 0), Vector3(0, a, 0))
		VehicleDoors.pull(k, t, c * 0.93 + Vector3(0, 0.75, 0), Vector3(c.x, 0, c.z).normalized() * -1.0, Vector3.UP, 0.16, 0.012, "gunmetal_w")
	# the M2 on its cradle at the ring's front: the bracket off the ring, the
	# post, the cradle elevating on its trunnions with the gun, the ammo can
	# on its tray on the gun's left, the belt rising into the feed
	var cradle := Vector3(0, 0.39, -0.46)
	_bx(k, t, Vector3(0.14, 0.03, 0.3), Vector3(0, 0.12, -0.6), "gunmetal_w")
	for s: float in [-1.0, 1.0]:
		VehicleFrames.beam(k, t, Vector3(s * 0.05, 0.13, -0.66), Vector3(s * 0.04, 0.3, -0.5), 0.02, 0.05, "gunmetal_w")
	VehicleEquipment._cyl(k, t, 0.032, 0.036, 0.2, Vector3(0, 0.23, -0.46), Vector3.ZERO, "gunmetal_w", null, 12, true, 2)
	k._cyl(t, 0.05, 0.05, 0.04, Vector3(0, 0.33, -0.46), Vector3.ZERO, "metal_dark", null, 12)
	var cr := k._pivot(t, cradle)
	var rx := Vector3(0, 0.115, 0.22)
	k._add(cr, BevelMesh.make(Vector3(0.2, 0.025, 0.36), 0.006), VehicleWeapons.STEEL, null, Vector3(0, -0.035, 0.1))
	for s: float in [-1.0, 1.0]:
		k._add(cr, BevelMesh.make(Vector3(0.018, 0.13, 0.15), 0.004), VehicleWeapons.STEEL, null, Vector3(s * 0.1, 0.03, 0.0))
		k._cyl(cr, 0.026, 0.026, 0.012, Vector3(s * 0.112, 0.0, 0.0), Z90, "metal_dark", null, 10, false)
	_tube(k, cr, Vector3(-0.115, 0, 0), Vector3(0.115, 0, 0), 0.012, "steel", null, 8, false)
	_tube(k, cr, Vector3(0, -0.05, 0.24), Vector3(0, -0.09, 0.25), 0.007, "steel", null, 6, false)
	_tube(k, cr, Vector3(-0.03, -0.09, 0.25), Vector3(0.03, -0.09, 0.25), 0.007, "steel", null, 6, false)
	# the can's tray, bolted out from the cradle's left cheek
	k._add(cr, BevelMesh.make(Vector3(0.16, 0.012, 0.32), 0.003), VehicleWeapons.STEEL, null, rx + Vector3(-0.19, -0.172, 0.08))
	VehicleFrames.beam(k, cr, Vector3(-0.1, -0.03, 0.05), rx + Vector3(-0.15, -0.168, 0.06), 0.03, 0.012, VehicleWeapons.STEEL)
	var tip_local := VehicleWeapons.hmg(k, cr, rx, rx + Vector3(0, 0, -1.5), 1.0, -1.0, true, "gunmetal_w", OD)
	k.gun_assembly(cr, tip_local, [rx + Vector3(0.075, 0.03, 0.4), rx + Vector3(-0.075, 0.03, 0.4)])
	k.mg_tip = k._tip(t, cradle + tip_local)
	# the gunner in the hatch, on his platform behind the gun
	k.gunner_floor = {"on": t, "y": rx.y + cradle.y + 0.03 - 1.3, "area": Rect2(Vector2(0, 0.5), Vector2.ZERO)}



## A gunner's hatch ring on a roof, in the turret's space (its origin on the
## roof at the ring's centre): the race `height` tall from `inner` to `outer`
## radius, the deck plate on it out to `deck` that the shields stand on, its
## bolt circle, and the hatch open and dark inside it.
static func _hatch_ring(k: VehicleModels, t: Node3D, inner: float, outer: float, height: float, deck: float, cam: String) -> void:
	k._add(t, _annulus(inner, outer, height), "gunmetal_w", null, Vector3.ZERO)
	k._add(t, _annulus(inner, deck, 0.03), cam, null, Vector3(0, height, 0))
	k._cyl(t, inner + 0.005, inner + 0.005, 0.004, Vector3(0, 0.003, 0), Vector3.ZERO, "plain_dark", null, 24, false)
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		VehicleBody.fastener(k, t, Vector3(cos(a), 0, sin(a)) * (inner + 0.04) + Vector3(0, height + 0.03, 0), Vector3.UP, 0.01)


static var _annuli := {}


## A flat ring round Y (a washer), `inner` to `outer` in radius and `height`
## up from the origin: open in the middle, its faces flat and edges sharp.
static func _annulus(inner: float, outer: float, height: float, sides := 32) -> ArrayMesh:
	var key := Vector4(inner, outer, height, sides)
	if _annuli.has(key):
		return _annuli[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# each face a strip of its own (underside, outer wall, top, inner wall),
	# its section points (height, radius) round in order
	var faces := [[Vector2(0, inner), Vector2(0, outer)], [Vector2(0, outer), Vector2(height, outer)], [Vector2(height, outer), Vector2(height, inner)], [Vector2(height, inner), Vector2(0, inner)]]
	var base := 0
	for f: Array in faces:
		for q: Vector2 in f:
			for j in sides:
				var a := TAU * j / sides
				st.set_uv(Vector2(a * q.y, q.x))
				st.add_vertex(Vector3(q.y * cos(a), q.x, q.y * sin(a)))
		for j in sides:
			var a := base + j
			var b := base + (j + 1) % sides
			var c := base + sides + j
			var d := base + sides + (j + 1) % sides
			for index: int in [a, b, c, b, d, c]:
				st.add_index(index)
		base += sides * 2
	st.generate_normals()
	var mesh := st.commit()
	_annuli[key] = mesh
	return mesh


## One face of a gunner's turret shield, in the turret's space: the steel
## plate `width` wide from `y0` up to `y1`, standing `apothem` out from the
## turret's axis at `yaw` (its outside away from the axis), with `holes` cut
## through it (Rect2s in its x and y). A hole whose `glass` is true holds a
## thick block of ballistic glass in a bolted frame; the others stay open (a
## gun's slot). The top edge rolled; wrecks lose the glass.
static func _shield_face(k: VehicleModels, t: Node3D, yaw: float, apothem: float, width: float, y0: float, y1: float, holes: Array, glass: Array, mat: String, thick := 0.035) -> void:
	var p := k._pivot(t, Basis(Vector3.UP, yaw) * Vector3(0, 0, -apothem))
	p.rotation.y = yaw
	# the plate in columns between the holes' edges, each column's solid runs
	# one piece of steel
	var xs: Array[float] = [-width * 0.5, width * 0.5]
	var ys: Array[float] = [y0, y1]
	for h: Rect2 in holes:
		xs.append_array([h.position.x, h.end.x])
		ys.append_array([h.position.y, h.end.y])
	xs.sort()
	ys.sort()
	for i in xs.size() - 1:
		var xa := xs[i]
		var xb := xs[i + 1]
		if xb - xa < 0.002:
			continue
		var start := INF
		for j in ys.size() - 1:
			var ya := ys[j]
			var yb := ys[j + 1]
			if yb - ya < 0.002:
				continue
			var mid := Vector2((xa + xb) * 0.5, (ya + yb) * 0.5)
			var open := false
			for h: Rect2 in holes:
				open = open or h.has_point(mid)
			if not open and start == INF:
				start = ya
			elif open and start != INF:
				k._box(p, Vector3(xb - xa, ya - start, thick), Vector3((xa + xb) * 0.5, (start + ya) * 0.5, 0), mat)
				start = INF
		if start != INF:
			k._box(p, Vector3(xb - xa, y1 - start, thick), Vector3((xa + xb) * 0.5, (start + y1) * 0.5, 0), mat)
	var out := -thick * 0.5 - 0.006
	for n in holes.size():
		var h: Rect2 = holes[n]
		var c := h.get_center()
		if not bool(glass[n]):
			continue
		if not k.burnt:
			k._box(p, Vector3(h.size.x, h.size.y, thick + 0.03), Vector3(c.x, c.y, 0.012), "glass" if k.wreck else "armor_glass", ARMOR_GLASS, Vector3.ZERO, false)
			# the steel clamp lip over the block's top on the inside, where it
			# stands proud of the plate: the gunner looks through the glass,
			# not down onto its edge (bare, that edge caught the sky from the
			# battle camera as a white bar along every window)
			if not k.wreck:
				k._box(p, Vector3(h.size.x + 0.02, 0.02, 0.034), Vector3(c.x, h.end.y + 0.008, thick * 0.5 + 0.015), mat, null, Vector3.ZERO, false)
		# the frame round it on the outside, a bolt at each corner
		var f := 0.024
		for y: float in [h.position.y - f * 0.5, h.end.y + f * 0.5]:
			k._box(p, Vector3(h.size.x + f * 2.0, f, 0.012), Vector3(c.x, y, out), mat, null, Vector3.ZERO, false)
		for x: float in [h.position.x - f * 0.5, h.end.x + f * 0.5]:
			k._box(p, Vector3(f, h.size.y, 0.012), Vector3(x, c.y, out), mat, null, Vector3.ZERO, false)
			for y: float in [h.position.y - f * 0.5, h.end.y + f * 0.5]:
				VehicleBody.fastener(k, p, Vector3(x, y, out - 0.006), Vector3.FORWARD, 0.007)
	VehicleFrames.tube(k, p, Vector3(-width * 0.5 + 0.01, y1, 0), Vector3(width * 0.5 - 0.01, y1, 0), thick * 0.55, mat, null, 6, false)
	# the bolts along its foot, through the angle it stands on
	for i in 5:
		VehicleBody.fastener(k, p, Vector3(lerpf(-width * 0.4, width * 0.4, i / 4.0), y0 + 0.04, -thick * 0.5 - 0.001), Vector3.FORWARD, 0.008)
	k._fold(p)

# --- btr / apc: BTR-80 ----------------------------------------------------------------

## BTR-80 (full scale): the long boat-shaped hull that swims - the lower bow
## raked forward to a sharp stem, the trim vane folded flat against it, the
## upper glacis climbing to the steep plate with the driver's and the
## commander's windows under their raised armoured shutters; the upper sides
## leaning in over the wheel wells, the lower hull a narrow V between eight
## big tyres, the side doors between the second and third axles; the engine
## deck aft with its louvres, the water-jet's flap in the stern; the small
## conical BPU-1 turret over the second axle with the KPVT and its coaxial
## PKT, six smoke dischargers across its back.
static func _btr80(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.53
	var axles := [-2.36, -1.01, 0.54, 1.89]
	var roof := 2.05
	# the hull: belly, the wheel wells' roof, the crease, the upper sides
	var r0 := [-0.6, -2.95, 0.6, -2.95, 0.78, -2.6, 0.78, 3.3, 0.6, 3.48, -0.6, 3.48, -0.78, 3.3, -0.78, -2.6]
	var r1 := [-0.82, -3.7, 0.82, -3.7, 1.0, -3.3, 1.0, 3.52, 0.85, 3.68, -0.85, 3.68, -1.0, 3.52, -1.0, -3.3]
	var r2 := [-0.92, -3.8, 0.92, -3.8, 1.42, -3.1, 1.44, 3.55, 1.15, 3.74, -1.15, 3.74, -1.44, 3.55, -1.42, -3.1]
	var r3 := [-0.92, -3.68, 0.92, -3.68, 1.46, -2.98, 1.46, 3.58, 1.18, 3.78, -1.18, 3.78, -1.46, 3.58, -1.46, -2.98]
	var r4 := [-0.8, -3.05, 0.8, -3.05, 1.25, -2.6, 1.25, 3.56, 1.02, 3.72, -1.02, 3.72, -1.25, 3.56, -1.25, -2.6]
	var r5 := [-0.66, -2.74, 0.66, -2.74, 1.08, -2.32, 1.08, 3.52, 0.9, 3.64, -0.9, 3.64, -1.08, 3.52, -1.08, -2.32]
	k._add(m, VehicleModels.solid(_rings([r0, r1, r2, r3, r4, r5], [0.42, 1.05, 1.11, 1.38, 1.75, roof]), "core_btr_hull"), cam, null, Vector3.ZERO)
	# the welds round the roof's edge and along the belt line, where the
	# upper sides start leaning in
	# (each seated in its joint; the belt line's crease is a shallow one, so
	# its bead goes straight in)
	_weld(k, m, _seated(r5, roof), cam)
	_weld(k, m, _seated(r3, 1.38, 0.01, 0.0), cam)
	# the wheels on their axles, the wells' dark liners, mud flaps
	for s: float in [-1.0, 1.0]:
		for z in axles:
			k._wheel(m, Vector3(s * 1.2, wr, z), wr, 0.38, cam)
			_bx(k, m, Vector3(0.5, 0.03, 1.14), Vector3(s * 1.2, 1.09, z), "plain_dark", null, Vector3.ZERO, false)
			_bx(k, m, Vector3(0.24, 0.22, 0.2), Vector3(s * 0.9, wr, z), "gunmetal_w")
		VehicleFittings.mudflap(k, m, Vector3(s * 1.2, 0.62, 2.48), Vector2(0.36, 0.36))
	# the hull's lower sides down between the wheels, each wheel in its own
	# arch (the BTR's tyres stand almost flush with the side, so the plate is
	# a thin one under the belt's overhang, its arches in three chords, and
	# the wells' liners above already dark the tyres' tops)
	wheel_wells(k, m, "core_btr_wells", 1.395, 1.43, 0.72, 1.12, -3.0, 3.4, axles, wr, wr + 0.1, 0.0, cam, null)
	# the bow: the trim vane folded against the lower bow plate, tow hooks,
	# a splash rail across the stem
	var ba := Vector2(-2.95, 0.42)
	var bb := Vector2(-3.8, 1.11)
	var bd := (bb - ba).normalized()
	var vane0 := ba.lerp(bb, 0.25)
	var vane1 := ba.lerp(bb, 0.92)
	VehicleMounts.trim_vane(k, m, Vector3(0, vane0.y, vane0.x), Vector3(0, vane1.y, vane1.x), 1.5, 0.05, Vector3(0, bd.x, -bd.y), cam)
	for s: float in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.55, 0.72, -3.2))
	_bx(k, m, Vector3(1.7, 0.05, 0.06), Vector3(0, 1.12, -3.78), "gunmetal_w")
	# the upper glacis and the window plate: the driver's and commander's
	# windows with their shutters propped open, the lights in guards on the
	# corners, the IR light on the left
	var ga := Vector2(-3.68, 1.38)
	var gb := Vector2(-3.05, 1.75)
	var gc := Vector2(-2.74, roof)
	var wu := Vector3(0, gc.y - gb.y, gc.x - gb.x).normalized()
	var wn := Vector3(0, wu.z, -wu.y)
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * 0.36, (gb.y + gc.y) * 0.5, (gb.x + gc.x) * 0.5)
		_on_face(k, m, c, Vector3.RIGHT, wu, wn, Vector3(0.52, 0.32, 0.02), "gunmetal_w")
		if not k.burnt:
			_on_face(k, m, c + wn * 0.02, Vector3.RIGHT, wu, wn, Vector3(0.44, 0.24, 0.015), "glass" if k.wreck else "armor_glass", null, false)
		# the shutter hinged along the roof's front edge over its window and
		# raised forward as a visor, held up by a stay from the window plate
		# beside it, as BTR crews drive with them open. (It lay back against
		# the window plate from a hinge line floating 19 cm over the roof.)
		# Each crew's own: now and then the driver's (left) or the
		# commander's is shut down over its glass, closed up for a fight.
		var hinge := Vector3(s * 0.36, gc.y + 0.006, gc.x - 0.012)
		var shut := (absi(hash(seed * 53 + 17)) >> (2 if s > 0.0 else 0)) % 4 == 0
		for dx: float in [-0.19, 0.19]:
			VehicleDoors.hinge(k, m, hinge + Vector3(dx, 0, 0), Vector3.UP, Vector3.RIGHT, 0.016, cam, null, dx < 0.0)
		if shut:
			# (down the window plate, resting on the glass's frame)
			var lie := -atan2(wu.y, wu.z)
			VehicleDoors.leaf(k, m, Vector3(0.56, 0.04, 0.36), Vector3(s * 0.36, gc.y, gc.x) + wn * 0.036 + Basis(Vector3.RIGHT, lie) * Vector3(0, 0.02, -0.18), cam, null, Vector3(lie, 0, 0), 1)
		else:
			var raise := Basis(Vector3.RIGHT, 0.32)
			VehicleDoors.leaf(k, m, Vector3(0.56, 0.04, 0.36), hinge + raise * Vector3(0, 0.02, -0.18), cam, null, Vector3(0.32, 0, 0), 1)
			var stay_top := hinge + Vector3(s * 0.25, 0, 0) + raise * Vector3(0, -0.004, -0.3)
			var stay_foot := c + Vector3(s * 0.31, 0, 0) - wu * 0.06 + wn * 0.01
			_tube(k, m, stay_foot, stay_top, 0.011, "gunmetal_w", null, 6, false)
			k._cyl(m, 0.02, 0.02, 0.02, stay_foot, _aim(wn), "gunmetal_w", null, 8, false)
		var lp := Vector3(s * 1.0, ga.lerp(gb, 0.6).y + 0.12, ga.lerp(gb, 0.6).x + 0.05)
		_lamp(k, m, lp, 0.065)
	VehicleFittings.searchlight(k, m, Vector3(-0.68, 1.72, -3.12), Vector3.FORWARD, 0.1, 0.16, "", Vector3.ZERO, "gunmetal_w", null, 0.09)
	# the roof: driver's and commander's hatches at the front, the troop
	# hatches behind the turret, periscopes along the edges
	for s: float in [-1.0, 1.0]:
		_hatch(k, m, Vector3(s * 0.38, roof, -2.25), 0.25, cam)
		_hatch(k, m, Vector3(s * 0.45, roof, 0.3), 0.27, cam)
		for z: float in [-1.75, -0.6, 0.85]:
			_periscope(k, m, Vector3(s * 0.95, roof + 0.03, z), s * -PI / 2)
	# the side doors between the second and third axles: the upper half in
	# the sloped side, the lower half below the crease; firing ports, the
	# stowage boxes and the exhausts aft, tow cable
	var su := Vector3(-0.38, 0.67, 0).normalized()
	for s: float in [-1.0, 1.0]:
		var sn := Vector3(s * 0.67, 0.38, 0).normalized()
		var sup := Vector3(s * su.x, su.y, 0)
		var dc := Vector3(s * 1.36, 1.58, -0.24)
		# the upper half hinged on its front edge, its firing port
		VehicleDoors.rectangle(k, m, dc, Vector2(0.6, 0.42), Basis(sup.cross(sn), sup, sn).get_euler(), cam, null, "armored")
		k._cyl(m, 0.05, 0.065, 0.06, dc + sn * 0.04 + Vector3(0, 0, 0.12), Vector3(0, 0, s * (PI / 2 - 0.5)), "gunmetal_w", null, 8, false)
		# the lower half, below the crease, folding down into a step on its
		# long bottom hinge (its sealed face outboard on either side)
		VehicleDoors.leaf(k, m, Vector3(0.04, 0.32, 0.56), Vector3(s * 1.23, 0.88, -0.24), cam, null, Vector3(0, 0, s * 0.12), 0, s)
		VehicleDoors.piano_hinge(k, m, Vector3(s * 1.27, 0.72, -0.49), Vector3(s * 1.27, 0.72, 0.01), 0.02, Vector3(s, 0, 0))
		for z: float in [-1.85, -0.95, 0.65, 1.5]:
			k._cyl(m, 0.055, 0.075, 0.06, Vector3(s * 1.33, 1.6, z), Vector3(0, 0, s * (PI / 2 - 0.5)), "gunmetal_w", null, 8, false)
		# the stowage box on the sloped side, its lid hinged along the top
		VehicleEquipment.storage(k, m, Vector3(s * 1.33, 1.58, 2.6) + sn * 0.08, Vector3(1.0, 0.16, 0.36), cam, null, Basis(sn.cross(sup), sn, sup).get_euler())
		# the engine's exhaust outlet low on each side of the stern: a guard
		# in the hull's paint over the silencer, louvred to throw the gas
		# down and clear (a bare steel slab there read as a black hole in the
		# side); a wreck keeps the old slab
		if k.wreck:
			_bx(k, m, Vector3(0.05, 0.2, 0.42), Vector3(s * 1.44, 1.26, 3.3), "gunmetal_w")
		else:
			_bx(k, m, Vector3(0.05, 0.24, 0.46), Vector3(s * 1.44, 1.26, 3.3), cam)
			VehicleFittings.grille(k, m, Vector3(s * 1.495, 1.26, 3.3), Vector2(0.4, 0.18), VmCsat._face_rot(Vector3(s, 0, 0), Vector3.UP), cam, null, 3)
		VehicleFittings.tow_cable(k, m, [Vector3(s * 1.47, 1.3, -2.7), Vector3(s * 1.47, 1.3, 1.7)], 0.022, 0.0, -1, sn, "gunmetal_w", null)
		k._team_mark(m, team, Vector3(s * 1.462, 1.25, -1.7), Vector3(0.02, 0.2, 0.6))
		# the big white hull number on the sloped side between the first two
		# firing ports: battalion, company and vehicle, Soviet style
		_stencil(k, m, VehicleMarkings.tactical_number(seed), 0.2, Vector3(s * 1.335, 1.6, -1.4), Vector3(0, 0, -s), sn, VehicleMarkings.STENCIL_WHITE)
	# the engine deck: the radiators' louvred intakes either side of the
	# engine's access hatch down the middle, hinged on its front edge, and
	# the access panels ahead of them (one grille 1.7 m across read from
	# above as a striped slab over the whole deck)
	# (wrecks keep their old deck)
	if k.wreck:
		VehicleFittings.grille(k, m, Vector3(0, roof + 0.03, 2.55), Vector2(1.7, 1.6), Vector3(-PI / 2, 0, 0), cam, null, 8)
	else:
		for s: float in [-1.0, 1.0]:
			VehicleFittings.grille(k, m, Vector3(s * 0.56, roof + 0.03, 2.55), Vector2(0.6, 1.6), Vector3(-PI / 2, 0, 0), cam, null, 8)
		k._add(m, VehicleMounts._bevel(Vector3(0.46, 0.04, 1.52), 0.012), cam, null, Vector3(0, roof + 0.02, 2.56))
		VehicleDoors.piano_hinge(k, m, Vector3(-0.19, roof + 0.045, 1.82), Vector3(0.19, roof + 0.045, 1.82), 0.016, Vector3.UP)
	_bx(k, m, Vector3(1.6, 0.03, 0.55), Vector3(0, roof + 0.012, 1.3), cam)
	# the crew's kit across the roof between the troop hatches and the engine
	# deck, behind the turret's sweep
	roof_kit(k, m, Vector3(0, roof, 0.8), PI / 2, Vector2(0.4, 1.1), 0)
	# the stern: the water-jet's flap, tail lights, tow hooks, the antenna
	VehicleDoors.leaf(k, m, Vector3(0.5, 0.42, 0.04), Vector3(0, 0.95, 3.6), cam, null, Vector3(-0.38, 0, 0))
	for s: float in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 0.85, 1.5, 3.74))
		_shackle(k, m, Vector3(s * 0.45, 0.7, 3.44), 1.0)
	_antenna(k, m, Vector3(0.85, roof, 3.25), 2.4)
	_antenna(k, m, Vector3(-0.85, roof, 3.25), 1.6)
	# --- the BPU-1 turret: a low cone, the mantlet, the KPVT and the PKT
	var t := k._pivot(m, Vector3(0, roof, -1.15))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.04, 0), 0.7, 0.72, 0.08, "gunmetal_w", null, 20)
	k._cyl(t, 0.46, 0.66, 0.44, Vector3(0, 0.3, 0), Vector3.ZERO, cam, null, 20)
	k._cyl(t, 0.42, 0.46, 0.04, Vector3(0, 0.54, 0), Vector3.ZERO, cam, null, 20)
	var gy := 0.32
	VehicleMounts.mantlet(k, t, Vector3(0.42, 0.32, 0.36), Vector3(0, gy, -0.56), cam)
	k._cyl(t, 0.13, 0.15, 0.2, Vector3(0, gy, -0.82), X90, cam, null, 12)
	# the KPVT: the heavy jacket over its rear third, the bare barrel, the
	# muzzle brake; the coaxial PKT's port to its right
	VehicleWeapons.autocannon(k, t, Vector3(0, gy, -0.89), Vector3(0, gy, -2.9), Vector2(0.065, 0.62), Vector2(0.034, 0.032), Vector2(0.045, 0.12))
	k.mg_tip = k._tip(t, Vector3(0, gy, -2.92))
	VehicleWeapons.coax(k, t, Vector3(0.2, gy - 0.04, -0.85), 0.4, 0.02)
	# the gunner's sight on the left of the roof, a vision block right, the hatch
	VehicleMounts.sight(k, t, Vector3(-0.2, 0.62, -0.25), Vector3(0.16, 0.2, 0.2), [Rect2(Vector2(0, 0.02), Vector2(0.1, 0.08))], "gunmetal_w")
	_periscope(k, t, Vector3(0.22, 0.58, -0.25))
	VehicleFittings.hatch(k, t, Vector3(0.08, 0.58, 0.18), 0.2, cam, null, 1.0, 0.04)
	# six smoke dischargers in a row across the back, firing over the turret
	var tubes := []
	for i in 6:
		var a := (i - 2.5) * 0.3
		tubes.append(Transform3D(Basis.from_euler(Vector3(-0.6, a, 0)), Vector3(sin(a) * 0.56, 0.42, cos(a) * 0.56)))
	VehicleFittings.smoke_bank(k, t, Vector3(0, 0.3, 0.58), Vector3(0.9, 0.06, 0.14), Vector3.ZERO, tubes, 0.045, 0.24)


# --- ifv: M2A3 Bradley -----------------------------------------------------------------

## M2A3 Bradley (0.9 scale): the tall slab-sided hull with its steep lower
## nose and long upper glacis (the driver front left, the engine's grilles
## and exhaust front right), the big bolted appliqué armour tiles over the
## sides and the heavy skirts below them, six road wheels a side with the
## sprocket forward, the big ramp at the back with its door; the two-man
## turret with the 25 mm Bushmaster and its coax, the TOW launcher box on the
## left, the IBAS sight and the commander's independent viewer, smoke
## dischargers, the stowage basket round the back.
static func _bradley(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	var roof := 1.8
	# running gear: front sprocket, six road wheels, rear idler
	var tx := 1.18
	var tw := 0.48
	var rw := []
	for i in 6:
		rw.append(-1.9 + i * 0.76)
	for s: float in [-1.0, 1.0]:
		var circles := []
		for z in rw:
			_road_wheel(k, m, Vector3(s * tx, 0.34, z), 0.27, tw * 0.86, cam)
			circles.append(Vector3(z, 0.34, 0.27))
		_sprocket(k, m, Vector3(s * tx, 0.64, -2.62), 0.27, tw * 0.8, cam)
		_idler(k, m, Vector3(s * tx, 0.56, 2.6), 0.25, tw * 0.8, cam)
		circles.append(Vector3(-2.62, 0.64, 0.27))
		circles.append(Vector3(2.6, 0.56, 0.25))
		for z: float in [-1.15, 0.4, 1.95]:
			VehicleWheels.roller(k, m, Vector3(s * tx, 0.84, z), 0.07, tw * 0.5)
			circles.append(Vector3(z, 0.84, 0.07))
		_belt(k, m, s * tx, tw, circles, 0.07)
	# the hull: the belly with the steep lower nose, the upper hull out over
	# the tracks with the long upper glacis
	k._add(m, VehicleModels.loft("core_m2_low", _oct(-0.9, 0.9, -2.55, 2.75, 0.06), _oct(-0.92, 0.92, -2.95, 2.95, 0.06), 0.4, 0.98), cam, null, Vector3.ZERO)
	var u0 := _oct(-1.42, 1.42, -2.97, 2.95, 0.05)
	var u1 := _oct(-1.42, 1.42, -2.95, 2.95, 0.05)
	var u2 := _oct(-1.38, 1.38, -1.78, 2.92, 0.05)
	k._add(m, VehicleModels.solid(_rings([u0, u1, u2], [0.96, 1.12, roof]), "core_m2_up"), cam, null, Vector3.ZERO)
	# the weld round the roof's edge, the glacis's top with it, down in the
	# joint
	_weld(k, m, _seated(u2, roof), cam)
	var ga := Vector2(-2.95, 1.12)
	var gb := Vector2(-1.78, roof)
	var gu := Vector3(0, gb.y - ga.y, gb.x - ga.x).normalized()
	# The glacis normal points up and forward, out of the plate.
	var gn := Vector3(0, gu.z, -gu.y)
	# the glacis: its armour plate with the bolt rows, the driver's hatch and
	# periscopes front left, the engine access and grilles front right
	_zy(k, m, 0.0, 2.7, ga.lerp(gb, 0.04), ga.lerp(gb, 0.7), 0.05, 0.0, cam)
	for f: float in [0.08, 0.66]:
		for i in 7:
			var c := ga.lerp(gb, f)
			VehicleBody.fastener(k, m, Vector3(-1.2 + i * 0.4, c.y + 0.06, c.x), gn, 0.022)
	VehicleFittings.panel_hatch(k, m, Vector3(-0.78, roof + 0.025, -1.45), Vector3(0.62, 0.05, 0.6), cam)
	for i in 4:
		_periscope(k, m, Vector3(-1.05 + i * 0.19, roof + 0.05, -1.72), (1.5 - i) * 0.22)
	var gr := ga.lerp(gb, 0.82)
	VehicleFittings.grille(k, m, Vector3(0.5, gr.y, gr.x) + gn * 0.03, Vector2(1.0, 0.5), Basis(Vector3.RIGHT, -gu, gn).get_euler(), cam, null, 5)
	# the exhaust on the right of the nose: its louvred outlet let into the
	# first armour tile, the louvres raked down and back to throw the gas
	# clear of the hull. (It was a steel box buried in the tile, only its
	# flat black face showing on it like a patch.) Lights in guards, tow hooks.
	VehicleFittings.grille(k, m, Vector3(1.54, 1.42, -2.3), Vector2(0.4, 0.28), Vector3(0, PI / 2, 0), "gunmetal_w", null, 4)
	# its soot streaked back along the first armour tile
	_soot(k, m, Vector3(1.51, 1.42, -2.1), Vector3.BACK, Vector3.UP, Vector3.RIGHT, 0.75, 0.24)
	for s: float in [-1.0, 1.0]:
		_lamp(k, m, Vector3(s * 1.15, 1.28, -2.9), 0.07)
		_shackle(k, m, Vector3(s * 0.62, 0.72, -2.78))
	# the sides: the appliqué armour tiles with their bolts, the skirts under
	# them, the grab rail
	for s: float in [-1.0, 1.0]:
		var sx: float = s * 1.47
		for i in 4:
			var z0 := -2.55 + i * 1.32
			# (now and then a replacement tile in its plain factory paint)
			var tile := Vector3(sx, 1.46, z0 + 0.64)
			var pm := VmNato._module_paint(k, m, tile, cam)
			VehicleMounts.applique(k, m, tile, Vector3(1.28, 0.6, 0.08), Vector3(0, s * PI / 2, 0), pm[0], pm[1], Vector2i(3, 2))
		for i in 5:
			var z0 := -2.55 + i * 1.06
			VehicleEquipment.skirt(k, m, Vector3(s * 1.46, 0.88, z0 + 0.52), Vector3(0.07, 0.5, 1.03), s, cam)
			if i == 2 and not k.wreck and team >= 0:
				# the same recognition chevron as the Abrams', flush on the skirt
				for end: float in [-1.0, 1.0]:
					_bar(k, m, Vector3(s * 1.499, 0.74, z0 + 0.52), Vector3(s * 1.499, 1.0, z0 + 0.52 + end * 0.21), 0.007, 0.045, "paint", Color(0.67, 0.64, 0.5), false)
			_bx(k, m, Vector3(0.02, 0.03, 0.9), Vector3(s * 1.5, 1.08, z0 + 0.52), "gunmetal_w", null, Vector3.ZERO, false)
		VehicleEquipment.skirt_bow(k, m, Vector3(s * 1.44, 0.95, -2.85), Vector3(0.07, 0.42, 0.5), s, cam, null, Vector3(-0.45, 0, 0))
		k._team_mark(m, team, Vector3(s * 1.515, 1.46, 1.42), Vector3(0.02, 0.24, 0.7))
		# cut branches tucked along the skirts' top under the armour tiles,
		# ahead of the recognition panel
		VehicleBody.cut_branches(k, m, Vector3(s * 1.48, 1.143, -2.3), Vector3(s * 1.48, 1.143, 0.4), Vector3(s, 0, 0), 31)
	# the roof: the troop compartment's long cargo hatch hinged at its back
	# edge, vision blocks
	VehicleFittings.panel_hatch(k, m, Vector3(0, roof + 0.03, 2.05), Vector3(1.3, 0.06, 1.2), cam)
	# an air-recognition panel, folded, tied down on the cargo hatch
	VehicleEquipment.recognition_panel(k, m, Vector3(0, roof + 0.06, 2.1), Vector3.ZERO, true)
	for s: float in [-1.0, 1.0]:
		for z: float in [0.9, 1.5]:
			_periscope(k, m, Vector3(s * 1.22, roof + 0.05, z), s * -PI / 2)
	# the rear: the big ramp with its door, hinges, stowage boxes either side,
	# tail lights, a water can and kit
	VehicleDoors.leaf(k, m, Vector3(2.0, 1.2, 0.08), Vector3(0, 1.18, 2.96), cam, null, Vector3.ZERO, 2)
	VehicleDoors.leaf(k, m, Vector3(0.62, 0.95, 0.04), Vector3(-0.42, 1.3, 3.01), cam, null, Vector3.ZERO, 2)
	if not k.burnt:
		_bx(k, m, Vector3(0.18, 0.12, 0.02), Vector3(-0.42, 1.62, 3.035), "glass" if k.wreck else "armor_glass", null, Vector3.ZERO, false)
	VehicleDoors.pull(k, m, Vector3(-0.18, 1.28, 3.03), Vector3.BACK, Vector3.UP, 0.16, 0.012, "gunmetal_w")
	for x: float in [-0.7, 0.7]:
		k._cyl(m, 0.06, 0.06, 0.3, Vector3(x, 0.62, 2.96), Z90, "gunmetal_w", null, 8)
	for s: float in [-1.0, 1.0]:
		# (turned about Y so the lid's latches face out the back)
		VehicleEquipment.storage(k, m, Vector3(s * 1.2, 1.315, 3.02), Vector3(0.4, 0.89, 0.3), cam, null, Vector3(0, PI, 0))
		_taillight(k, m, Vector3(s * 1.2, 0.82, 3.0))
		_antenna(k, m, Vector3(s * 1.15, roof, 2.7), 2.0 if s < 0.0 else 1.5)
	_jerry(k, m, Vector3(0.45, 1.25, 3.1), OD, PI / 2)
	# --- the turret
	var t := k._pivot(m, Vector3(0.12, roof, -0.55))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.03, 0.1), 0.92, 0.95, 0.06, "gunmetal_w", null, 20)
	var tr := 0.84
	var tb := [-0.5, -1.1, 0.5, -1.1, 1.0, -0.62, 1.02, 0.95, 0.82, 1.22, -0.82, 1.22, -1.02, 0.95, -1.0, -0.62]
	var tt := [-0.38, -0.8, 0.38, -0.8, 0.86, -0.42, 0.9, 0.9, 0.72, 1.12, -0.72, 1.12, -0.9, 0.9, -0.86, -0.42]
	k._add(t, VehicleModels.loft("core_m2_tur", tb, tt, 0.04, tr), cam, null, Vector3.ZERO)
	_weld(k, t, _seated(tt, tr), cam)
	# its bumper code: the battalion and the company and vehicle, as US Army
	# vehicles carry them across the front and back
	var code := VehicleMarkings.bumper_code(seed, VehicleMarkings.US_INFANTRY + VehicleMarkings.US_CAVALRY)
	if team >= 0:
		# the vehicle half repeated big on the turret's right side, and on the
		# TOW launcher's flank (it covers the turret's left), between its bands
		VehicleMarkings.side_number(k, t, code[1], 0.2, Vector3(1.02, 0.04, 0.95), Vector3(1.0, 0.04, -0.62), Vector3(0.86, 0.84, -0.42), Vector3(0.9, 0.84, 0.9), Vector2(0.48, 0.5), VehicleMarkings.STENCIL_SAND, "tactical", false)
		_stencil(k, t, code[1], 0.22, Vector3(-1.54, 0.42, -0.06), Vector3.BACK, Vector3.LEFT)
	# the spaced armour on the turret's front faces
	for s: float in [-1.0, 1.0]:
		var a := Vector3(s * 0.52, 0.1, -1.16)
		var b := Vector3(s * 1.05, 0.1, -0.66)
		_on_face(k, t, (a + b) * 0.5 + Vector3(0, 0.26, 0), b - a, Vector3.UP, Vector3(s * 0.65, 0, -0.76), Vector3(a.distance_to(b) + 0.04, 0.48, 0.06), cam)
		for f: float in [0.2, 0.8]:
			VehicleBody.fastener(k, t, a.lerp(b, f) + Vector3(0, 0.42, 0) + Vector3(s * 0.65, 0, -0.76) * 0.063, Vector3(s * 0.65, 0, -0.76), 0.025)
	# the 25 mm in its mantlet, the coax to its right
	var gy := 0.4
	VehicleMounts.mantlet(k, t, Vector3(0.44, 0.4, 0.4), Vector3(-0.05, gy, -1.1), cam)
	VehicleWeapons.autocannon(k, t, Vector3(-0.05, gy, -1.23), Vector3(-0.05, gy, -3.54), Vector2(0.11, 0.3), Vector2(0.045, 0.04), Vector2(0.065, 0.24))
	k.mg_tip = k._tip(t, Vector3(-0.05, gy, -3.56))
	VehicleWeapons.coax(k, t, Vector3(0.28, gy - 0.05, -1.25), 0.32, 0.022)
	# the TOW launcher box on its arm on the left
	_bx(k, t, Vector3(0.18, 0.24, 0.34), Vector3(-1.02, 0.36, 0.0), "gunmetal_w")
	VehicleWeapons.missile_box(k, t, Vector3(-1.32, 0.42, -0.1), Vector3(0.44, 0.5, 1.38), 2, 1, 0.1, cam, null, Vector3.ZERO, false, Vector3.RIGHT)
	# the IBAS sight head front left under its raised armoured door, the CIV
	# on its column on the right, the hatches
	VehicleMounts.sight(k, t, Vector3(-0.45, tr + 0.18, -0.42), Vector3(0.5, 0.36, 0.5), [Rect2(Vector2.ZERO, Vector2(0.34, 0.16))], cam)
	VehicleDoors.leaf(k, t, Vector3(0.44, 0.06, 0.2), Vector3(-0.45, tr + 0.38, -0.59), cam, null, Vector3(0.6, 0, 0), 1)
	VehicleMounts.sight(k, t, Vector3(0.55, tr + 0.36, 0.55), Vector3(0.34, 0.28, 0.34), [Rect2(Vector2(0, 0.02), Vector2(0.22, 0.12))], cam, null, Vector3(0.14, 0.16, 0.36))
	_hatch(k, t, Vector3(0.42, tr, 0.0), 0.3, cam)
	_hatch(k, t, Vector3(-0.4, tr, 0.42), 0.28, cam)
	for s: float in [-1.0, 1.0]:
		_smoke(k, t, Vector3(s * 0.92, 0.66, -0.64), -s * 0.85, 2, 2, 0.5, 0.045)
		_eye(k, t, Vector3(s * 0.7, tr, 0.85))
	# the stowage basket round the back, bags and a bedroll in it
	VehicleMounts.basket(k, t, Vector3(0, 0.3, 1.42), Vector3(1.8, 0.4, 0.44))
	k._bag(t, Vector3(0.6, 0.34, 0.36), Vector3(-0.45, 0.5, 1.42), "canvas", BAG)
	VehicleCloth.roll(k, t, Vector3(0.38, 0.47, 1.42), 0.15, 0.7, Z90, TAN_BAG_WRECK if k.wreck else TAN_BAG)
	_antenna(k, t, Vector3(0.75, tr, 1.0), 1.6)
	if team >= 0:
		# the bumper code on the band across the nose and low on the ramp
		VehicleMarkings.bumper(k, m, code, 0.08, 0.55, 1.04, -2.96, Vector3(0, 0.124, -0.992), 0.7)
		VehicleMarkings.bumper(k, m, code, 0.075, 0.3, 0.72, 3.0, Vector3.BACK, 0.36)


# --- helicopters: AH-64D and UH-60 ----------------------------------------------------

## The helicopters are built at full scale inside a node scaled down to the
## size the originals had (the rotors and the gun turret are inside it too).
const HELI_SCALE := 0.65
## US Army helicopter drab, and the sand they wear for the other side.
const HELO_DRAB := Color(0.25, 0.27, 0.22)
const HELO_SAND := Color(0.47, 0.44, 0.38)


## The scaled airframe node the helicopter is built in.
static func _airframe(k: VehicleModels) -> Node3D:
	var b := k._pivot(k.root, Vector3.ZERO)
	b.scale = Vector3.ONE * HELI_SCALE
	return b


## AH-64D Apache Longbow: the narrow fuselage with the stepped tandem
## cockpit of flat panes (the gunner low in front, the pilot high behind),
## the avionics bays bulging along its lower flanks, the TADS/PNVS sensor
## turrets on the nose and the M230 chain gun in its turret under the chin;
## the two engines slung either side of the gearbox fairing with their
## exhaust suppressors, stub wings with a Hellfire rack outboard and a
## 19-tube rocket pod inboard each side, the four-blade rotor under the
## Longbow radar dome, the tail rotor on the left of the swept fin, the
## stabilator low at the back, fixed main gear and the tailwheel.
static func _apache(k: VehicleModels, team: int) -> void:
	var b := _airframe(k)
	var mat := "aircraft"
	var col: Color = HELO_DRAB if team != 1 else HELO_SAND
	var h := VmHeli.Hull.new([
		[-6.05, 1.28, 0.16, 0.16, 0.16],
		[-5.8, 1.32, 0.4, 0.38, 0.4],
		[-5.25, 1.4, 0.48, 0.55, 0.5, 0.9, 1.0],
		[-4.2, 1.5, 0.5, 0.52, 0.58, 0.9, 1.0],
		[-3.0, 1.56, 0.52, 0.62, 0.62, 0.88, 1.0],
		[-1.6, 1.66, 0.58, 0.82, 0.68, 0.8, 1.0],
		[0.4, 1.78, 0.56, 0.86, 0.64, 0.75, 1.0],
		[1.7, 1.98, 0.42, 0.6, 0.44],
		[3.2, 2.12, 0.3, 0.4, 0.3],
		[6.9, 2.3, 0.2, 0.27, 0.2],
		[8.05, 2.36, 0.15, 0.22, 0.15],
	], 12, 2.4)
	VmHeli._hull(k, b, h, "core_ah_body", mat, col)
	# the stepped canopy: the gunner's low in front, the pilot's high behind,
	# the blast shield between them; the fairing over the gearbox behind
	VmHeli._canopy(k, b, "core_ah_can1", [-0.42, -5.32, 0.42, -5.32, 0.5, -3.92, -0.5, -3.92], [-0.25, -4.92, 0.25, -4.92, 0.33, -3.96, -0.33, -3.96], 1.97, 2.5, mat, col, 0.03)
	VmHeli._canopy(k, b, "core_ah_can2", [-0.5, -3.96, 0.5, -3.96, 0.56, -2.56, -0.56, -2.56], [-0.29, -3.66, 0.29, -3.66, 0.35, -2.62, -0.35, -2.62], 2.08, 2.92, mat, col, 0.03)
	k._add(b, VehicleModels.loft("core_ah_spine", [-0.56, -2.62, 0.56, -2.62, 0.62, 1.3, -0.62, 1.3], [-0.36, -2.6, 0.36, -2.6, 0.4, 0.85, -0.4, 0.85], 2.2, 2.94), mat, col, Vector3.ZERO)
	# the avionics bays along the lower flanks, their access panel seams
	for s: float in [-1.0, 1.0]:
		k._add(b, VehicleModels.loft("core_ah_bay%d" % int(s), VmHeli._mx([0.38, -3.85, 0.78, -3.55, 0.9, -0.7, 0.38, -0.7], s),
			VmHeli._mx([0.38, -4.45, 0.74, -4.15, 0.8, -0.9, 0.38, -0.9], s), 1.0, 1.92), mat, col, Vector3.ZERO)
		for z: float in [-3.0, -2.0]:
			_bx(k, b, Vector3(0.015, 0.8, 0.025), Vector3(s * 0.86, 1.45, z), "gunmetal_w", null, Vector3(0, 0, -s * 0.07), false)
		# the radar warning receivers on the nose
		_bx(k, b, Vector3(0.08, 0.12, 0.16), Vector3(s * 0.42, 1.55, -5.55), "gunmetal_w", null, Vector3(0, s * 0.5, 0))
	# --- the nose: the TADS drum with its two sensor heads, the PNVS above
	k._cyl(b, 0.3, 0.3, 0.44, Vector3(0, 1.1, -6.3), Vector3.ZERO, mat, col, 16)
	k._add(b, Res.sphere(0.3, 14), mat, col, Vector3(0, 1.32, -6.3), Vector3.ZERO, Vector3(1.0, 0.35, 1.0))
	for s: float in [-1.0, 1.0]:
		_bx(k, b, Vector3(0.18, 0.34, 0.46), Vector3(s * 0.38, 1.1, -6.28), mat, col)
		if not k.burnt:
			_bx(k, b, Vector3(0.12, 0.22, 0.02), Vector3(s * 0.38, 1.1, -6.52), "glass", null, Vector3.ZERO, false)
	if not k.burnt:
		_bx(k, b, Vector3(0.22, 0.14, 0.02), Vector3(0, 1.08, -6.6), "glass", null, Vector3.ZERO, false)
	k._cyl(b, 0.15, 0.17, 0.26, Vector3(0, 1.7, -6.0), Vector3.ZERO, mat, col, 12)
	if not k.burnt:
		_bx(k, b, Vector3(0.14, 0.12, 0.02), Vector3(0, 1.7, -6.16), "glass", null, Vector3.ZERO, false)
	# wire cutters over the canopy and under the chin
	VehicleAircraft.wire_cutter(k, b, Vector3(0.025 * 1.6, (Vector3(0, 2.75, -5.25) - Vector3(0, 2.48, -4.95)).length(), 0.025 * 3), (Vector3(0, 2.48, -4.95) + Vector3(0, 2.75, -5.25)) * 0.5, VehicleFrames.aim(Vector3(0, 2.75, -5.25) - Vector3(0, 2.48, -4.95)).get_euler())
	VehicleAircraft.wire_cutter(k, b, Vector3(0.025 * 1.6, (Vector3(0, 0.66, -5.62) - Vector3(0, 0.84, -5.3)).length(), 0.025 * 3), (Vector3(0, 0.84, -5.3) + Vector3(0, 0.66, -5.62)) * 0.5, VehicleFrames.aim(Vector3(0, 0.66, -5.62) - Vector3(0, 0.84, -5.3)).get_euler())
	# --- the engines either side of the gearbox fairing: the nacelles on
	# their pylons, the dark intakes, the exhaust suppressors turned out
	var eng := VmHeli.Hull.new([[-1.45, 2.58, 0.24, 0.24, 0.24], [-1.25, 2.58, 0.36, 0.36, 0.36], [0.9, 2.58, 0.38, 0.38, 0.36], [1.5, 2.58, 0.3, 0.3, 0.28]], 12, 2.2)
	for s: float in [-1.0, 1.0]:
		var cowling_rings := []
		for station: Array in eng.st:
			cowling_rings.append(eng.ring(float(station[0])))
		VehicleAircraft.cowling(k, b, cowling_rings, Vector3(s * 0.98, 0, 0), mat, col)
		VehicleAircraft.intake_face(k, b, Vector3(s * 0.98, 2.58, -1.47), 0.25, Vector3.FORWARD, 0.08)
		_bx(k, b, Vector3(0.5, 0.26, 2.0), Vector3(s * 0.68, 2.42, -0.15), mat, col)
		VehicleAircraft.turbine_exhaust(k, b, Vector3(s * 0.98, 2.56, 1.4), Vector3(s * 1.3, 2.38, 2.05), 0.28, 0.22, mat, col)
	# --- stub wings: Hellfires outboard, rocket pods inboard, rails at the tips
	for s: float in [-1.0, 1.0]:
		k._add(b, VehicleModels.loft("core_ah_wing%d" % int(s), VmHeli._mx([0.0, -0.95, 2.05, -0.72, 2.05, 0.2, 0.0, 0.36], s),
			VmHeli._mx([0.0, -0.93, 2.05, -0.7, 2.05, 0.18, 0.0, 0.34], s), -0.08, 0.08), mat, col, Vector3(s * 0.55, 1.88, 0), Vector3(0, 0, -s * 0.05))
		for px: float in [1.48, 2.28]:
			VehicleAircraft.hardpoint(k, b, Vector3(s * px, 1.83 - (px - 0.55) * 0.05, -0.3), 0.74, 0.26, null, 0.0, 0.1, "gunmetal_w", 0.04)
		VmHeli._rocket_pod(k, b, Vector3(s * 1.48, 1.32, -0.42), 0.21, 1.62, "paint", Color(0.3, 0.32, 0.27), 19)
		VmHeli._hellfires(k, b, Vector3(s * 2.28, 1.62, -0.3), 4)
		_bx(k, b, Vector3(0.14, 0.14, 0.86), Vector3(s * 2.66, 1.76, -0.3), "gunmetal_w")
		VehicleFittings.nav_light(k, b, Vector3(s * 2.66, 1.85, -0.75), Vector3(0.05, 0.05, 0.06), s)
		k._team_mark(b, team, Vector3(s * 0.31, 2.2, 4.6), Vector3(0.02, 0.22, 0.9))
	# --- the tail: the swept fin, the tail rotor on its left, the stabilator
	# low at the back, the tailwheel under the fin
	k._add(b, VehicleModels.extrude_x("core_ah_fin", [6.7, 2.36, 7.95, 2.3, 8.55, 4.25, 7.95, 4.3], -0.09, 0.09), mat, col, Vector3.ZERO)
	_bx(k, b, Vector3(0.24, 0.3, 0.42), Vector3(-0.12, 3.96, 8.12), mat, col)
	VmHeli._tail_rotor(k, b, Vector3(-0.3, 3.96, 8.12), 4, 1.4, 0.24, -1.0, 0.3)
	_bx(k, b, Vector3(3.3, 0.07, 0.78), Vector3(0, 2.42, 8.02), mat, col)
	VehicleFittings.dome_light(k, b, Vector3(0, 4.32, 8.0), 0.06, Color(0.55, 0.08, 0.06))
	VehicleAircraft.tailwheel(k, b, Vector3(0, 2.12, 7.45), Vector3(0, 0.25, 7.98), Vector2(0.25, 0.15), 0.06)
	k._wheel(b, Vector3(0, 0.25, 7.98), 0.25, 0.15)
	# --- main gear: trailing arms off the bays, the shock struts
	for s: float in [-1.0, 1.0]:
		VehicleAircraft.trailing_gear(k, b, Vector3(s * 0.8, 1.02, -3.55), Vector3(s * 0.84, 1.5, -3.2), Vector3(s * 1.12, 0.34, -3.05), Vector2(0.34, 0.22), 0.07, 0.055, "gunmetal_w", null, Vector3.ZERO, "paint", null, null, 0.0, 8, Vector2(0.26, 0.21))
		k._wheel(b, Vector3(s * 1.12, 0.34, -3.05), 0.34, 0.22)
	# --- the M230 chain gun in its turret under the chin, its feeder and
	# ammunition chute on the right
	var t := k._pivot(b, Vector3(0, 0.92, -3.85))
	k.turret = t
	VehicleAircraft.chin_turret(k, t, Vector3(0, 0.02, 0), Vector2(0.24, 0.28), 0.16, Vector3(0, -0.2, -0.05), Vector3(0.24, 0.26, 0.56), mat, col, 1.0)
	VehicleWeapons.autocannon(k, t, Vector3(0, -0.22, -0.31), Vector3(0, -0.22, -1.99), Vector2(0.062, 0.42), Vector2(0.036, 0.036), Vector2(0.058, 0.18))
	k.mg_tip = k._tip(t, Vector3(0, -0.22, -2.01))
	# --- the mast, the rotor and the Longbow radar dome over it
	VehicleRotors.mast(k, b, Vector3(0, 3.33, -1.2), 0.16, 0.22, 0.9)
	VmHeli._rotor(k, b, Vector3(0, 3.82, -1.2), 4, 7.3, 0.53, true, PI / 4, 0.02, 0.36, 1)
	k._cyl(b, 0.09, 0.11, 0.42, Vector3(0, 4.17, -1.2), Vector3.ZERO, "gunmetal_w", null, 8)
	k._cyl(b, 0.56, 0.56, 0.16, Vector3(0, 4.45, -1.2), Vector3.ZERO, mat, col, 18)
	k._add(b, Res.sphere(0.56, 16), mat, col, Vector3(0, 4.52, -1.2), Vector3.ZERO, Vector3(1.0, 0.32, 1.0))
	k._add(b, Res.sphere(0.56, 16), mat, col, Vector3(0, 4.38, -1.2), Vector3.ZERO, Vector3(1.0, 0.18, 1.0))
	# antennas along the boom
	VehicleFittings.antenna(k, b, Vector3(0, 2.5, 3.4), 0.0, Vector3(0, 0.28, 0.3), 0.014, "gunmetal_w", null, "whip")
	_bx(k, b, Vector3(0.03, 0.18, 0.26), Vector3(0, 1.0, 1.2), "gunmetal_w")


## A 230-gallon external fuel tank along z, centred at pos: the barrel with
## its rounded ends, the filler cap, the adapter it hangs from.
static func _fuel_tank(k: VehicleModels, p: Node3D, pos: Vector3, r: float, ln: float, mat: String, col) -> void:
	VehicleAircraft.pod(k, p, pos, VehicleAircraft.tank_stations(-ln * 0.35, ln * 0.35, r, r * 1.68, r * 1.47), mat, col, [-ln * 0.35, ln * 0.35], VehicleAircraft.POD_TANK, 0, [], Vector3(0.06, 0.13, ln * 0.4))


## UH-60 Black Hawk: the rounded nose and the big two-pane windscreen with
## the eyebrow windows over it, the cockpit doors, the gunners' windows, the
## wide cabin with its big sliding doors; the engines either side of the
## gearbox on the roof with their exhaust suppressors, the four-blade rotor
## with swept tips and the bifilar absorber on its hub, the long tapering
## boom with the swept pylon, the canted tail rotor high on its right and
## the big stabilator low across it; fixed main gear on drag beams, the
## tailwheel; the stores wings with a fuel tank each side.
static func _blackhawk(k: VehicleModels, team: int) -> void:
	var b := _airframe(k)
	var mat := "aircraft"
	var col: Color = HELO_DRAB if team != 1 else HELO_SAND
	var dark := Color(0.06, 0.06, 0.06)
	var h := VmHeli.Hull.new([
		[-7.0, 1.28, 0.12, 0.12, 0.14],
		[-6.8, 1.3, 0.55, 0.42, 0.5],
		[-6.35, 1.38, 0.88, 0.7, 0.72],
		[-5.7, 1.48, 1.06, 0.92, 0.84],
		[-4.8, 1.55, 1.14, 1.0, 0.9],
		[-2.2, 1.58, 1.18, 1.02, 0.92],
		[0.3, 1.62, 1.15, 0.98, 0.92],
		[1.3, 1.78, 0.92, 0.8, 0.68],
		[2.7, 2.0, 0.5, 0.48, 0.38],
		[6.3, 2.14, 0.32, 0.34, 0.27],
		[7.6, 2.22, 0.22, 0.28, 0.2],
	], 16, 2.8)
	VmHeli._hull(k, b, h, "core_uh_body", mat, col)
	# glazing: the two-pane windscreen, the eyebrow windows over it, the
	# cockpit doors' windows, the gunners' windows, the cabin doors' windows
	VmHeli._patch(k, b, h, "core_uh_ws", -6.72, -5.62, 1.15, 3.85, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_eye", -5.55, -4.95, 3.1, 3.88, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_cw", -5.3, -4.25, -0.2, 1.75, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_gw", -4.05, -3.55, 0.05, 1.4, "glass", null, 0.012, 0.05)
	for z0: float in [-3.12, -2.3]:
		VmHeli._patch(k, b, h, "core_uh_dw%d" % int(-z0 * 10), z0, z0 + 0.62, 0.3, 1.35, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_rw", -1.2, -0.75, 0.4, 1.2, "glass", null, 0.012, 0.05)
	# the frame between the windscreen panes, the door seams and the cabin
	# door's rail, the steps
	VmHeli._patch(k, b, h, "core_uh_post", -6.72, -5.62, 3.92, 4.08, mat, col, 0.024, 0.02, 1.0)
	for z: float in [-5.35, -4.15, -3.4, -1.5]:
		VmHeli._patch(k, b, h, "core_uh_seam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.6, 1.9, "gunmetal_w", null, 0.008)
	# (the rail laid on the hull's skin either side, as VmHeli._patch lays a pane)
	var rail_mid := h.pt(-1.5, 1.98)
	var rail_out := h.pt(-1.5, 1.98, 0.01) - rail_mid
	for s: float in [1.0, -1.0]:
		var rail := VehicleSurface.new(func(q: Vector2) -> Vector3:
			var v := h.pt(lerpf(-3.4, 0.4, q.x), lerpf(1.92, 2.04, q.y))
			return Vector3(v.x * s, v.y, v.z), Vector3(rail_out.x * s, rail_out.y, rail_out.z))
		VehicleDoors.slide_rail(k, b, rail, 3.8, 0.02, 0.03)
	VmHeli._patch(k, b, h, "core_uh_sill", -3.4, -1.5, -2.65, -2.5, "gunmetal_w", null, 0.02)
	# the nose: the radome's seam, pitots on the roof, the wire cutters
	VmHeli._patch(k, b, h, "core_uh_nose", -6.6, -6.56, -4.0, 0.9, "gunmetal_w", null, 0.008)
	for s: float in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, b, Vector3(s * 0.35, 2.32, -5.4), Vector3(s * 0.35, 2.3, -6.0), 0.02, "steel", null)
		VehicleFrames.step(k, b, Vector3(s * 1.2, 0.68, -4.7), Vector2(0.12, 0.3))
		VehicleFittings.nav_light(k, b, Vector3(s * 1.14, 2.36, -4.3), Vector3(0.05, 0.05, 0.06), s)
	VehicleAircraft.wire_cutter(k, b, Vector3(0.03 * 1.6, (Vector3(0, 2.78, -5.35) - Vector3(0, 2.45, -5.0)).length(), 0.03 * 3), (Vector3(0, 2.45, -5.0) + Vector3(0, 2.78, -5.35)) * 0.5, VehicleFrames.aim(Vector3(0, 2.78, -5.35) - Vector3(0, 2.45, -5.0)).get_euler())
	VehicleAircraft.wire_cutter(k, b, Vector3(0.03 * 1.6, (Vector3(0, 0.5, -6.25) - Vector3(0, 0.66, -5.9)).length(), 0.03 * 3), (Vector3(0, 0.66, -5.9) + Vector3(0, 0.5, -6.25)) * 0.5, VehicleFrames.aim(Vector3(0, 0.5, -6.25) - Vector3(0, 0.66, -5.9)).get_euler())
	# --- the roof: the gearbox fairing, the engines either side with their
	# dark intakes and the exhaust suppressors turned out, the IR jammer
	k._add(b, VehicleModels.loft("core_uh_top", [-0.8, -3.7, 0.8, -3.7, 1.0, -3.0, 1.0, 0.8, 0.62, 1.7, -0.62, 1.7, -1.0, 0.8, -1.0, -3.0],
		[-0.42, -3.2, 0.42, -3.2, 0.58, -2.7, 0.58, 0.5, 0.34, 1.3, -0.34, 1.3, -0.58, 0.5, -0.58, -2.7], 2.45, 3.1), mat, col, Vector3.ZERO)
	var eng := VmHeli.Hull.new([[-2.85, 2.82, 0.22, 0.22, 0.22], [-2.65, 2.82, 0.36, 0.34, 0.32], [0.2, 2.82, 0.38, 0.36, 0.32], [0.7, 2.82, 0.3, 0.28, 0.26]], 12, 2.4)
	for s: float in [-1.0, 1.0]:
		var cowling_rings := []
		for station: Array in eng.st:
			cowling_rings.append(eng.ring(float(station[0])))
		VehicleAircraft.cowling(k, b, cowling_rings, Vector3(s * 0.9, 0, 0), mat, col)
		VehicleAircraft.intake_face(k, b, Vector3(s * 0.9, 2.82, -2.87), 0.25, Vector3.FORWARD, 0.08)
		k._add(b, VehicleModels.loft("core_uh_hirss", [-0.22, 0.0, 0.22, 0.0, 0.2, 1.1, -0.2, 1.1], [-0.16, 0.06, 0.16, 0.06, 0.13, 1.0, -0.13, 1.0], 0.0, 0.42), mat, col, Vector3(s * 0.95, 2.6, 0.62), Vector3(0, s * 0.42, 0))
		_bx(k, b, Vector3(0.28, 0.03, 0.7), Vector3(s * 1.2, 3.03, 1.25), "plain", dark, Vector3(0, s * 0.42, 0), false)
	k._cyl(b, 0.16, 0.18, 0.32, Vector3(0, 3.22, 1.1), Vector3.ZERO, "gunmetal_w", null, 10)
	k._add(b, Res.sphere(0.16, 10), "glass", null, Vector3(0, 3.42, 1.1))
	# --- the mast and the rotor: swept tips, the bifilar absorber on the hub
	VehicleRotors.mast(k, b, Vector3(0, 3.3, -2.0), 0.18, 0.22, 0.55, [Vector2(3.28, 0.36)])
	VmHeli._rotor(k, b, Vector3(0, 3.62, -2.0), 4, 8.18, 0.53, true, PI / 4, 0.02, 0.42, 1)
	VehicleRotors.hub_cap(k, k.rotor, Vector3(0, 0.3, 0), 0.16, 0.2, 0.3, 10, "gunmetal_w", null, false, Vector3.ZERO, 4, 0.5, PI / 4)
	# --- the stores wings over the cabin's rear, braced to the floor, a fuel
	# tank on each
	for s: float in [-1.0, 1.0]:
		_bx(k, b, Vector3(1.9, 0.12, 0.8), Vector3(s * 1.95, 2.18, -0.5), mat, col, Vector3(0, 0, -s * 0.12))
		VmHeli._tube(k, b, Vector3(s * 2.3, 2.1, -0.5), Vector3(s * 1.1, 0.95, -0.5), 0.045, "gunmetal_w", null, 6)
		VehicleAircraft.hardpoint(k, b, Vector3(s * 2.15, 2.1, -0.5), 0.8, 0.3, null, 0.34, 0.1, "gunmetal_w", 0.04)
		_fuel_tank(k, b, Vector3(s * 2.15, 1.42, -0.6), 0.34, 3.0, mat, col)
	# --- the tail: the swept pylon, the canted tail rotor on its right, the
	# stabilator, the antenna along the boom, the tailwheel
	k._add(b, VehicleModels.extrude_x("core_uh_pylon", [6.25, 2.25, 7.8, 2.2, 8.3, 4.28, 7.6, 4.4], -0.13, 0.13), mat, col, Vector3.ZERO)
	_bx(k, b, Vector3(0.28, 0.36, 0.5), Vector3(0.16, 3.5, 7.93), mat, col)
	var cant := k._pivot(b, Vector3(0.38, 3.5, 7.93))
	cant.rotation.z = 0.35
	VmHeli._tail_rotor(k, cant, Vector3.ZERO, 4, 1.68, 0.25, 1.0, 0.3)
	k._add(b, VehicleModels.loft("core_uh_stab", [-0.3, 7.32, 0.3, 7.32, 2.2, 7.6, 2.2, 8.3, -2.2, 8.3, -2.2, 7.6],
		[-0.3, 7.36, 0.3, 7.36, 2.2, 7.63, 2.2, 8.26, -2.2, 8.26, -2.2, 7.63], 2.12, 2.22), mat, col, Vector3.ZERO)
	VehicleFittings.dome_light(k, b, Vector3(0, 4.42, 7.65), 0.06, Color(0.55, 0.08, 0.06))
	VmHeli._tube(k, b, Vector3(0, 2.52, 3.0), Vector3(0, 2.6, 5.6), 0.02, "gunmetal_w", null, 4)
	for z: float in [3.0, 5.6]:
		VmHeli._tube(k, b, Vector3(0, 2.42, z), Vector3(0, 2.6, z), 0.015, "gunmetal_w", null, 4)
	VehicleAircraft.tailwheel(k, b, Vector3(0, 1.92, 6.05), Vector3(0, 0.24, 6.48), Vector2(0.24, 0.16), 0.06, Vector3(0, 1.86, 5.55), 0.04)
	k._wheel(b, Vector3(0, 0.24, 6.48), 0.24, 0.16)
	for s: float in [-1.0, 1.0]:
		k._team_mark(b, team, Vector3(s * 0.37, 2.12, 4.6), Vector3(0.02, 0.24, 0.9))
	# --- main gear: the drag beam and the shock strut to each wheel
	for s: float in [-1.0, 1.0]:
		VehicleAircraft.trailing_gear(k, b, Vector3(s * 0.8, 0.66, -4.35), Vector3(s * 1.12, 1.35, -3.8), Vector3(s * 1.5, 0.38, -3.95), Vector2(0.38, 0.26), 0.07, 0.1, "gunmetal_w", null, Vector3.ZERO, "paint", null, null, 0.0, 8, Vector2(0.376, 0.506))
		k._wheel(b, Vector3(s * 1.5, 0.38, -3.95), 0.38, 0.26)


# --- truck: the fallback convoy truck ---------------------------------------------

## A generic 6x6 cargo truck, an M35A2 "deuce and a half" (full scale): the
## narrow bonnet between flat-topped wings with the headlights on them and the
## brush guard across its nose, the boxy cab with its flat two-pane
## windscreen, the spare wheel behind it, the cargo bed on the tandem axles
## under its canvas tilt and bows. (The convoy is the HEMTT or the Zamak; this
## stands in only if those can't be built.)
static func _truck(k: VehicleModels, team: int) -> void:
	var m := k.root
	var col := Color(0.32, 0.35, 0.25) if team != 1 else Color(0.45, 0.39, 0.29)
	var wr := 0.5
	var axles := [-2.15, 1.05, 2.4]
	# the chassis: the ladder frame's two channel rails and their cross
	# members (one slab here read as a grey beam under the bed from a
	# quarter), the axles and their diffs, the wheels. The deuce's pressed
	# steel wheels are painted with the truck, a shade darker for the road's
	# dirt on them (bare gunmetal read as alloy rims on a 1960s lorry); a
	# wreck's stay as they were.
	var rim := "gunmetal_w" if k.wreck else "paint"
	var rim_col: Variant = null if k.wreck else col.darkened(0.15)
	VehicleRunningGear.frame(k, m, Vector3(0, 0.84, 0.15), 0.43, 6.2, Vector2(0.1, 0.24), [-2.85, -0.9, 0.35, 1.72, 3.15])
	for z: float in axles:
		VehicleRunningGear.axle(k, m, Vector3(0, wr, z), 1.7, 0.07)
		for s: float in [-1.0, 1.0]:
			k._wheel(m, Vector3(s * 0.95, wr, z), wr, 0.38, rim, rim_col)
	# the bonnet with the radiator grille in its nose, the flat wings over the
	# front wheels with the headlights on them, the brush guard, the bumper
	# and its tow hooks (the grilles lean with the bonnet's faces)
	k._add(m, VehicleModels.loft("core_trk_hood", [-0.56, -3.22, 0.56, -3.22, 0.56, -1.85, -0.56, -1.85], [-0.5, -3.16, 0.5, -3.16, 0.52, -1.85, -0.52, -1.85], 0.95, 1.66, 0.025), "paint", col, Vector3.ZERO)
	VehicleFittings.grille(k, m, Vector3(0, 1.35, -3.215), Vector2(0.4, 0.6), Vector3(-0.084, PI, 0), "paint", col, 4, true)
	# The deuce's bonnet opens in two halves, each folding up from its side on
	# the piano hinge down the top's centre: the hinge's knuckle and the two
	# halves' shut lines either side of it break the bonnet's long flat top,
	# the face the battle camera sees most of on the truck's nose.
	_tube(k, m, Vector3(0, 1.665, -3.14), Vector3(0, 1.665, -1.87), 0.011, "paint", col.darkened(0.12), 6, false)
	for s: float in [-1.0, 1.0]:
		VehicleBody.seam(k, m, [Vector3(s * 0.025, 1.662, -3.14), Vector3(s * 0.025, 1.662, -1.87)])
	for s: float in [-1.0, 1.0]:
		VehicleBody.fender(k, m, Vector3(s * 0.86, 1.24, -2.42), Vector3(0.6, 0.04, 1.6), s, "paint", col)
		_bx(k, m, Vector3(0.04, 0.3, 1.6), Vector3(s * 0.58, 1.1, -2.42), "paint", col)
		VehicleBody.fender(k, m, Vector3(s * 0.86, 1.12, -3.3), Vector3(0.58, 0.04, 0.4), s, "paint", col, Vector3(-0.6, 0, 0))
		_lamp(k, m, Vector3(s * 0.86, 1.38, -3.05), 0.08)
		_shackle(k, m, Vector3(s * 0.6, 0.86, -3.45))
		# the louvres down the bonnet's sides
		VehicleFittings.grille(k, m, Vector3(s * 0.555, 1.425, -2.5), Vector2(0.4, 0.28), Vector3(-0.07, s * PI / 2, 0), "paint", col, 4)
	# the brush guard: its hoop and three uprights standing on the bumper
	var guard := [[Vector3(-0.62, 0.95, -3.4), Vector3(-0.62, 1.62, -3.36), Vector3(0.62, 1.62, -3.36), Vector3(0.62, 0.95, -3.4)]]
	for x: float in [-0.3, 0.0, 0.3]:
		guard.append([Vector3(x, 0.95, -3.39), Vector3(x, 1.62, -3.36), 0.02])
	VehicleFrames.bull_bar(k, m, guard, 0.025, "gunmetal_w", null, 0, 6)
	VehicleMounts.bumper(k, m, Vector3(2.3, 0.22, 0.2), Vector3(0, 0.84, -3.38), "paint", col.darkened(0.25))
	# the cab: its lower walls up to the waist, then the hard-top glasshouse
	# (VehicleCab.upper): the flat windscreen in two panes, the door windows
	# and the rear quarter lights, the rolled roof, and the seats, dash and
	# wheel seen through the glass, as the battle camera sees into a truck's
	# cab; a painted box behind dark panes read as a crate. Then the doors'
	# seams and handles, mirrors on their arms.
	var lo := [-1.08, -1.88, 1.08, -1.88, 1.08, -0.62, -1.08, -0.62]
	var waist := [-1.06, -1.85, 1.06, -1.85, 1.06, -0.64, -1.06, -0.64]
	k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(lo), 1.1), VehicleModels.ring_y(VehicleModels._v2(waist), 1.85)], "core_trk_open_cab"), "paint", col, Vector3.ZERO)
	VehicleCab.upper(k, Vector2(1.06, 1.04), Vector2(1.85, 2.55), Vector2(-1.85, -1.82), -0.67, "paint", col)
	for s: float in [-1.0, 1.0]:
		# (lying on the wall as it leans in toward the waist)
		VehicleBody.seam(k, m, [Vector3(s * 1.065, 1.83, -0.7), Vector3(s * 1.082, 1.15, -0.7)])
		VehicleDoors.pull(k, m, Vector3(s * 1.068, 1.72, -0.95), Vector3(s, 0, 0), Vector3.BACK, 0.14, 0.008, "gunmetal_w")
		VehicleFittings.mirror(k, m, Vector3(s * 1.34, 2.08, -1.82), Vector2(0.20, 0.38), -s * 0.3, [Vector3(s * 1.06, 2.2, -1.8)])
		VehicleFrames.step(k, m, Vector3(s * 0.98, 0.72, -1.25), Vector2(0.3, 0.22), Vector3.ZERO, "gunmetal_w", null)
		# (hung from the cab's floor on two flat straps at its inboard end: a
		# tread on its own floated under the door)
		for z: float in [-1.33, -1.17]:
			_bar(k, m, Vector3(s * 0.86, 0.71, z), Vector3(s * 0.86, 1.12, z), 0.04, 0.012, "gunmetal_w", null, false)
		k._team_mark(m, team, Vector3(s * 1.09, 1.55, -1.35), Vector3(0.02, 0.24, 0.5))
	# behind the cab: the spare wheel standing up, the fuel tank, a tool box
	# bolted through its hub to a carrier on the cab's back (its face against
	# the cab plain, as nobody sees it)
	VehicleWheels.spare(k, m, Vector3(0.45, 1.75, -0.45), 0.48, 0.3, Vector3(PI / 2, 0, 0), rim, rim_col, "offroad", Vector3(0.45, 1.75, -0.638))
	VehicleWheels.carrier(k, m, Vector3(0.45, 1.75, -0.45), 0.48, 0.3, Vector3(PI / 2, 0, 0), "hub", Vector3(0.45, 1.75, -0.638))
	VehicleRunningGear.fuel_tank(k, m, Vector3(-1.0, 0.92, 0.1), Vector3(0.44, 0.44, 0.9), -1.0, "paint", col.darkened(0.1))
	VehicleEquipment.storage(k, m, Vector3(1.0, 0.95, 0.1), Vector3(0.36, 0.34, 0.6), "paint", col.darkened(0.1))
	# the M35A2's exhaust: out from under the cab and straight up the right
	# back corner of the cab, open above the roof line, the stack that marks
	# the deuce-and-a-half's silhouette (a run, so no smoke point moves)
	VehicleFittings.exhaust_run(k, m, [Vector3(0.5, 0.86, -0.95), Vector3(1.14, 0.9, -0.56), Vector3(1.14, 2.72, -0.56)], 0.045)
	# the cargo bed: the floor, the dropsides and the tailgate, the canvas
	# tilt on its bows, the rope lashing, tail lights, mudflaps and the
	# pintle. The M35's cargo body is all steel, its floor plate welded in
	# sections and painted with the rest, scuffed darker by boots and loads
	# (only the troop seats are wooden slats); in planks of dark wood under
	# the tilt it read as a tiled floor. Under the tilt it is in the cover's
	# shade, the sky's light shut out as well as the sun's, which the renderer
	# doesn't know: lit like an open deck it read bright past the rolled
	# flap, so it's taken down as the tilt's liner is, toward the brown of the
	# dirt boots carry in (darkened alone, the paint went the slate of the sky
	# it reflects). (A wreck's floor stays as it was.)
	VehicleCargo.flatbed(k, m, -0.35, 3.05, 2.3, 1.37, "paint", col, 0.48, 0, 0.0, 0.0, 0.14, "wood_dark" if k.wreck else "paint", null if k.wreck else col.darkened(0.4).lerp(Color(0.2, 0.18, 0.1), 0.3), Vector3.ZERO, 0.06)
	for s: float in [-1.0, 1.0]:
		VehicleFittings.mudflap(k, m, Vector3(s * 0.95, 0.5, 3.15), Vector2(0.36, 0.4))
		_taillight(k, m, Vector3(s * 0.9, 1.1, 3.08))
	var tarp := VehicleCargo.tilt_colour(k, m, col.lightened(0.08))
	# The tilt's section: straight walls 0.9 m high, then a half-ellipse roof
	# 1.16 m to each side and 0.49 m high; the cloth hangs between the bows.
	var section := [Vector2(-1.16, 1.8)]
	for i in 7:
		var a := PI * (1.0 - i / 6.0)
		section.append(Vector2(1.16 * cos(a), 2.7 + 0.487 * sin(a)))
	section.append(Vector2(1.16, 1.8))
	# (the back flap laced shut across the tail, inside the last bow, or on
	# some trucks rolled up to the roof and tied there over the dark inside)
	# (its bows show only as the ridges the cover sags from, as on the real
	# truck: no plates standing proud of the walls)
	var flap := VehicleCargo.kit(k, m, Vector3(0, 2.7, 3.03), 18)
	var open := flap != null and not k.wreck and flap.randf() < 0.3
	VehicleCloth.canopy(k, m, section, [-0.33, -0.28, 0.82, 1.92, 3.03], tarp, not open)
	if k.wreck:
		# (a wreck's tilt keeps its old fitted panels, and so its bow plates)
		for i in 4:
			_bx(k, m, Vector3(2.36, 0.9, 0.05), Vector3(0, 2.25, -0.28 + i * 1.1), "canvas_white", tarp.darkened(0.15))
	for x: float in [-0.7, 0.0, 0.7]:
		if not open:
			_bx(k, m, Vector3(0.025, 1.0, 0.02), Vector3(x, 2.25, 3.04), "canvas_white", tarp.darkened(0.25), Vector3.ZERO, false)
	if open:
		# (under the rolled flap the tilt's own dim inside shows, and the bed
		# under it: no board across the opening)
		VehicleCloth.roll(k, m, Vector3(0, 2.86, 3.1), 0.1, 2.2, Vector3(0, 0, PI / 2), tarp.darkened(0.06), "canvas_white")
	VehicleMounts.hitch(k, m, Vector3(0, 0.84, 3.15), Vector3(0.18, 0.16, 0.2))
	_antenna(k, m, Vector3(-1.0, 2.55, -0.8), 1.8)


## Mirrors plan outline pairs (x, z) to the other side, keeping the winding.
static func _mirror(pairs: Array) -> Array:
	var o := []
	for i in range(pairs.size() - 2, -1, -2):
		o.append(-float(pairs[i]))
		o.append(pairs[i + 1])
	return o
