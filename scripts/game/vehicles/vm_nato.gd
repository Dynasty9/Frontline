class_name VmNato
extends RefCounted
## Procedural models: NATO ground vehicles (Hunter, Prowler, Marshall, Rhino, Slammer, Panther, Bobcat, Cheetah, Scorcher, Sandstorm, HEMTT, Stomper).
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["hunter", "hunter_hmg", "hunter_gmg", "prowler", "prowler_hmg", "prowler_at",
		"marshall", "rhino", "rhino_up", "slammer", "slammer_up", "scorcher", "sandstorm", "panther", "bobcat", "cheetah",
		"hemtt", "hemtt_cargo", "hemtt_ammo", "hemtt_repair", "hemtt_medical", "hemtt_fuel", "stomper"]

const GUN := Color(0.3, 0.32, 0.24)  # painted gun barrels
const STOW := Color(0.33, 0.35, 0.25)  # olive stowage, ammo cans
const BAG := Color(0.38, 0.37, 0.27)  # canvas bags and covers


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"hunter":
			_hunter(k, team, "", seed)
		"hunter_hmg":
			_hunter(k, team, "hmg", seed)
		"hunter_gmg":
			_hunter(k, team, "gmg", seed)
		"prowler":
			_prowler(k, team, "")
		"prowler_hmg":
			_prowler(k, team, "hmg")
		"prowler_at":
			_prowler(k, team, "at")
		"marshall":
			_marshall(k, team, seed)
		"rhino":
			_rhino(k, team, false, seed)
		"rhino_up":
			_rhino(k, team, true, seed)
		"slammer":
			_slammer(k, team, false, seed)
		"slammer_up":
			_slammer(k, team, true, seed)
		"scorcher":
			_scorcher(k, team, seed)
		"sandstorm":
			_sandstorm(k, team)
		"panther":
			_panther(k, team, seed)
		"bobcat":
			_bobcat(k, team, seed)
		"cheetah":
			_cheetah(k, team, seed)
		"hemtt":
			_hemtt(k, team, "troop", seed)
		"hemtt_cargo":
			_hemtt(k, team, "cargo", seed)
		"hemtt_ammo":
			_hemtt(k, team, "ammo", seed)
		"hemtt_repair":
			_hemtt(k, team, "repair", seed)
		"hemtt_medical":
			_hemtt(k, team, "medical", seed)
		"hemtt_fuel":
			_hemtt(k, team, "fuel", seed)
		"stomper":
			_stomper(k, team)
		_:
			return false
	return true


# --- shared helpers ------------------------------------------------------------------

static func _cam(team: int) -> String:
	return "camo_tank" if team != 1 else "camo_tank_rebel"


## A plate lying on a sloped face seen side-on: its length runs from a to b
## ((z, y) points), centred on x, pushed `push` out along the face's normal
## (outward is forward/up when a -> b climbs a front face). Glass is a pane in
## its rubber seal (VehicleGlazing.rectangle) on the same box.
static func _zy(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, t: float, push: float, mat: String, col = null, shadow := true) -> Variant:
	var d := b - a
	var dn := d.normalized()
	var n := Vector2(-dn.y, dn.x)
	var c := (a + b) * 0.5 + n * push
	if mat == "glass":
		return VehicleGlazing.rectangle(k, p, Vector2(w, d.length()), Vector3(x, c.y, c.x), Vector3(atan2(d.x, d.y), 0, 0), false, col, t)
	return k._box(p, Vector3(w, d.length(), t), Vector3(x, c.y, c.x), mat, col, Vector3(atan2(d.x, d.y), 0, 0), shadow)


## A grille (VehicleFittings.grille) lying on a sloped face as _zy lays a
## plate: its length runs from a to b ((z, y) points), centred on x, w wide,
## its centre pushed `push` out along the face's normal and its slats across
## the slope. Turned over from _zy's plate, so the grille faces out of the face.
static func _zy_grille(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, push: float, mat: String, count: int) -> void:
	var d := b - a
	var dn := d.normalized()
	var c := (a + b) * 0.5 + Vector2(-dn.y, dn.x) * push
	# (the Merkava and Namer hulls' perforated armour cover, not louvres)
	VehicleFittings.grille(k, p, Vector3(x, c.y, c.x), Vector2(w, d.length()), Vector3(atan2(d.x, d.y) + PI, 0, 0), mat, null, count, false, 3)


## An access hatch (VehicleFittings.panel_hatch) lying on a sloped face as _zy
## lays a plate: its length runs from a to b ((z, y) points, a -> b climbing
## a front face), centred on x, w wide and t thick, its centre pushed `push`
## out along the face's normal. Tilted back with the face, so its lid looks
## out of the plate; hinged along its upper edge, the handle by the lower one.
static func _zy_hatch(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, t: float, push: float, mat: String, col = null) -> void:
	var d := b - a
	var dn := d.normalized()
	var c := (a + b) * 0.5 + Vector2(-dn.y, dn.x) * push
	VehicleFittings.panel_hatch(k, p, Vector3(x, c.y, c.x), Vector3(w, t, d.length()), mat, col, 1.0, true, Vector3(-atan2(d.y, d.x), 0, 0))


## A plate on a side face sloping in (seen from the front): a, b are (x, y)
## points on the right-hand side, bottom to top; s = -1 mirrors it to the left.
## Glass is a pane in its rubber seal (VehicleGlazing.rectangle), its width
## turned to run along z.
static func _xy(k: VehicleModels, p: Node3D, s: float, z: float, l: float, a: Vector2, b: Vector2, t: float, push: float, mat: String, col = null, shadow := true) -> Variant:
	var d := b - a
	var dn := d.normalized()
	var n := Vector2(dn.y, -dn.x)
	var c := (a + b) * 0.5 + n * push
	var lean := Vector3(0, 0, s * atan2(-d.x, d.y))
	if mat == "glass":
		return VehicleGlazing.rectangle(k, p, Vector2(l, d.length()), Vector3(s * c.x, c.y, z), (Basis.from_euler(lean) * Basis(Vector3.UP, PI / 2)).get_euler(), false, col, t)
	return k._box(p, Vector3(t, d.length(), l), Vector3(s * c.x, c.y, z), mat, col, lean, shadow)


## A stowage bin (VehicleEquipment.storage) standing on a side face sloping
## in, laid as _xy lays a plate: a, b the face's (x, y) points on the
## right-hand side, bottom to top, s = -1 mirrors it; the bin t deep off the
## face and l long at z, its lid on the top edge.
static func _xy_bin(k: VehicleModels, p: Node3D, s: float, z: float, l: float, a: Vector2, b: Vector2, t: float, cam: String) -> void:
	var d := b - a
	var dn := d.normalized()
	var c := (a + b) * 0.5 + Vector2(dn.y, -dn.x) * t * 0.5
	VehicleEquipment.storage(k, p, Vector3(s * c.x, c.y, z), Vector3(t, d.length(), l), cam, null, Vector3(0, 0, s * atan2(-d.x, d.y)))


## A bolt-on armour module (VehicleMounts.applique) on a side face sloping in,
## laid as _xy lays a plate: a, b the face's (x, y) points on the right-hand
## side, bottom to top, s = -1 mirrors it; the module t thick off the face,
## l long at z and as tall as the face (less `trim` top and bottom); `bolts`
## (along, up) heavy bolt heads. Returns where its outer face's middle is.
static func _xy_module(k: VehicleModels, p: Node3D, s: float, z: float, l: float, a: Vector2, b: Vector2, t: float, cam: String, bolts := Vector2i(3, 2), trim := 0.03) -> Vector3:
	var d := b - a
	var dn := d.normalized()
	var n := Vector2(dn.y, -dn.x)
	var c := (a + b) * 0.5 + n * t * 0.5
	var up := Vector3(s * dn.x, dn.y, 0)
	var out := Vector3(s * n.x, n.y, 0)
	var pm := _module_paint(k, p, Vector3(s * c.x, c.y, z), cam)
	VehicleMounts.applique(k, p, Vector3(s * c.x, c.y, z), Vector3(l, d.length() - trim * 2.0, t), Basis(up.cross(out), up, out).get_euler(), pm[0], pm[1], bolts)
	return Vector3(s * c.x, c.y, z) + out * t * 0.5


## A bolt-on armour module's paint at `at` on p, [material, colour]: the
## vehicle's own camouflage, or for about one module in eight a replacement
## bolted on after a hit, from depot stock in its plain factory paint and not
## yet camouflaged, so no two of a crew's vehicles wear their repairs alike
## (from the kit seed; scenery and wrecks keep the builders' one look).
static func _module_paint(k: VehicleModels, p: Node3D, at: Vector3, cam: String) -> Array:
	var rng := VehicleCargo.kit(k, p, at, 13)
	if rng == null or rng.randf() >= 0.125:
		return [cam, null]
	return ["paint", VehicleCargo.kit_colour(rng, MODULE_SPARE[rng.randi_range(0, MODULE_SPARE.size() - 1)], VehicleCargo.KIT_PAINT, 1.0)]


## Replacement armour modules' factory paints: NATO green, a darker green
## and desert tan.
const MODULE_SPARE: Array[Color] = [Color(0.27, 0.3, 0.2), Color(0.22, 0.25, 0.17), Color(0.5, 0.44, 0.32)]


## Armoured glass: inches of laminate, green-blue through its depth where a
## windscreen's thin pane is near black.
const ARMOR_GLASS := Color(0.08, 0.13, 0.13)


## A tactical number stencilled on a flat face: `text` h tall, centred on
## `center` (a point on the face), reading along `along` as seen from outside,
## `out` the face's outward normal (VehicleMarkings.face_text: gone with the
## paint on a wreck). Crews paint these big on turret and hull sides so a
## commander can tell his vehicles apart; from the RTS camera they're the
## detail that reads. NATO's are CARC sand in heavy stencil bars.
static func _stencil(k: VehicleModels, p: Node3D, text: String, h: float, center: Vector3, along: Vector3, out: Vector3) -> void:
	VehicleMarkings.face_text(k, p, text, h, center, along, out, VehicleMarkings.STENCIL_SAND)


## The vehicle's tactical number from its seed (VehicleMarkings.tactical_number):
## NATO numbers a vehicle by its company letter (when `company`), its platoon
## and its place in the platoon, as "B12".
static func _tac(seed: int, company := true) -> String:
	return VehicleMarkings.tactical_number(seed, ["ABCD", "123", "1234"] if company else ["123", "1234"], 3)


## Exhaust soot, streaked back along a face from an outlet by the slipstream:
## a smear tapering away from it (VehicleMarkings, gone with the paint on a
## wreck), laid on the plane through `origin` (the outlet's trailing edge)
## spanned by `along` (the way the exhaust trails) and `up`, `out` the
## face's outward normal; `length` long, `height` tall at the outlet.
static func _soot(k: VehicleModels, p: Node3D, origin: Vector3, along: Vector3, up: Vector3, out: Vector3, length: float, height: float) -> void:
	# Soot thins into the paint toward its edges: VehicleBody.soot's graded
	# films, which carry the hull's camouflage through the faint outer ones
	# (two flat grey and black films ended in a hard line on the green). Its
	# outermost film runs 1.18 x as long and 1.3 x as tall as the size it's
	# given, so it is given less, to cover the plate it was fitted to.
	VehicleBody.soot(k, p, origin, along, up, out, length / 1.18, height / 1.3)


## A weld run along `points` (Vector3s; a closed loop repeats its first point
## last). Armour plate is welded at its joints, and the bead's round section
## riding a lofted hull's sharp edge catches the light along it as a real
## welded, ground edge does, where a dead-sharp corner reads as CG.
static func _weld(k: VehicleModels, p: Node3D, points: Array, mat: String, r := 0.016) -> void:
	VehicleBody.bead(k, p, points, r, mat, null, 6, false)


## The points of a plan outline ((x, z) pairs) at height y, closed: a weld
## round a roof's edge.
static func _loop(pairs: Array, y: float) -> Array:
	var pts := []
	for i in range(0, pairs.size(), 2):
		pts.append(Vector3(pairs[i], y, pairs[i + 1]))
	pts.append(pts[0])
	return pts


## The level outlines ((x, z) pairs) of a loft or solid as its rings, bottom
## to top: `levels` alternates outline and height.
static func _rings(levels: Array) -> Array:
	var rings := []
	for i in range(0, levels.size(), 2):
		rings.append(VehicleModels.ring_y(VehicleModels._v2(levels[i]), levels[i + 1]))
	return rings


## Where a weld runs round the top of a solid whose top edge
## VehicleModels.solid chamfers by `b` (the same rings, so the same cut): the
## middle of each corner's chamfer facet, visited in the order of `corners`
## (top ring indices; empty: the whole ring, closed). Plate cut and welded at
## a corner is ground back to a narrow facet with the bead filling it, so the
## bead lies along the facet catching the light, never standing proud of a
## corner the chamfer has cut away. `foot` instead returns the facet's lower
## edge at those corners, where a weld up a side meets it.
static func _seated(rings: Array, b: float, corners: Array = [], foot := false) -> Array:
	var c: Array = VehicleModels._chamfered(rings, b, true)
	var mid: PackedVector3Array = c[c.size() - 2]
	var cut: PackedVector3Array = c[c.size() - 1]
	if cut.size() != mid.size() or c.size() == rings.size():
		mid = rings[rings.size() - 1]
		cut = mid
	var order := corners
	if order.is_empty():
		order = range(cut.size())
		order.append(0)
	var pts := []
	for i: int in order:
		pts.append(mid[i] if foot else (mid[i] + cut[i]) * 0.5)
	return pts


## A point on a lofted solid's side face as VehicleModels.solid triangulates
## it: a, b the lower ring's corners, c, d the upper ring's above them (c
## over a), (u, v) across from a to b and up. The face is two triangles,
## a-b-d and a-d-c, folded along a-d where the rings aren't parallel (the
## Merkava's wedge), so seams and bolts laid on it follow the plate they're on.
static func _on_loft(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Vector2) -> Vector3:
	if uv.y <= uv.x:
		return a + (b - a) * uv.x + (d - b) * uv.y
	return a + (d - c) * uv.x + (c - a) * uv.y


## That face's normal at (u, v), turned toward `out`.
static func _loft_normal(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Vector2, out: Vector3) -> Vector3:
	var n := ((b - a).cross(d - b) if uv.y <= uv.x else (d - c).cross(c - a)).normalized()
	return n if n.dot(out) >= 0.0 else -n


## A joint between armour modules across that face, from uv0 to uv1, bent
## where it crosses the fold.
static func _loft_seam(k: VehicleModels, p: Node3D, q: Array, uv0: Vector2, uv1: Vector2) -> void:
	var pts := [_on_loft(q[0], q[1], q[2], q[3], uv0)]
	var e0 := uv0.y - uv0.x
	var e1 := uv1.y - uv1.x
	if e0 * e1 < 0.0:
		pts.append(_on_loft(q[0], q[1], q[2], q[3], uv0.lerp(uv1, e0 / (e0 - e1))))
	pts.append(_on_loft(q[0], q[1], q[2], q[3], uv1))
	VehicleBody.seam(k, p, pts, 0.008)


## The frame of a part lying flat on a face: x along ex, y along ey (squared
## up to ex), z standing out of the face toward `out`.
static func _face_basis(ex: Vector3, ey: Vector3, out: Vector3) -> Basis:
	var x := ex.normalized()
	var z := x.cross(ey).normalized()
	if z.dot(out) < 0.0:
		z = -z
		x = -x
	return Basis(x, z.cross(x), z)


## Reactive armour bricks in a grid on the quad face a-b (bottom edge) /
## c-d (top edge): nu across, nv up, each brick filling its cell less a gap
## and standing th proud of the face.
static func _era(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nu: int, nv: int, out: Vector3, cam: String, th := 0.1, u0 := 0.0, u1 := 1.0) -> void:
	var ex := b - a
	var ey := (c + d) * 0.5 - (a + b) * 0.5
	var cu := ex.length() * (u1 - u0) / nu
	var cv := ey.length() / nv
	var face := _face_basis(ex, ey, out)
	var rot := face.get_euler()
	var size := Vector3(cu - 0.05, cv - 0.05, th)
	for i in nu:
		for j in nv:
			var u := u0 + (u1 - u0) * (i + 0.5) / nu
			var v := (j + 0.5) / nv
			var pt := a.lerp(b, u).lerp(c.lerp(d, u), v)
			VehicleMounts.era_brick(k, p, pt + face.z * th * 0.5, size, rot, cam)


## The Euler rotation that turns +Y onto direction d.
static func _aim(d: Vector3) -> Vector3:
	var u := d.normalized()
	if u.dot(Vector3.UP) < -0.9999:
		return Vector3(PI, 0, 0)
	if u.dot(Vector3.UP) > 0.9999:
		return Vector3.ZERO
	return Basis(Quaternion(Vector3.UP, u)).get_euler()


## A round tube from a to b (roll cages, rails, booms, hoses).
static func _tube(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 8, shadow := true) -> Variant:
	return VehicleFrames.tube(k, p, a, b, r, mat, col, segs, shadow)


## A square-section beam from a to b.
static func _beam(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, w: float, h: float, mat: String, col = null) -> Variant:
	return VehicleFrames.beam(k, p, a, b, w, h, mat, col)


## A headlight facing f (-1 forward, 1 back): housing, lens, wire guard.
static func _lamp(k: VehicleModels, p: Node3D, pos: Vector3, r := 0.08, f := -1.0, guard := true) -> void:
	VehicleFittings.lamp_unit(k, p, pos, Vector3(r * 2.6, r * 2.3, 0.12), f, [r], Rect2(), "cage" if guard else "")


## A tail light cluster (red and amber) facing back.
static func _taillight(k: VehicleModels, p: Node3D, pos: Vector3) -> void:
	VehicleFittings.tail_cluster(k, p, pos)



## A jerrycan standing upright, its face toward x (s = side it faces).
static func _jerry(k: VehicleModels, p: Node3D, pos: Vector3, col := Color(0.3, 0.33, 0.22), rot := Vector3.ZERO) -> void:
	VehicleFittings.jerrycan(k, p, pos, col, rot)



## An ammo can (olive), its long side along z.
static func _ammo_can(k: VehicleModels, p: Node3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	VehicleFittings.ammo_can(k, p, pos, STOW, rot)



## A whip antenna on a base.
static func _antenna(k: VehicleModels, p: Node3D, pos: Vector3, h := 2.2) -> void:
	VehicleFittings.antenna(k, p, pos, h)


## A cluster of smoke-grenade dischargers: n tubes fanned on a bracket on the
## side s, pointing out and up; yaw turns the bank (radians about Y).
static func _smoke(k: VehicleModels, p: Node3D, pos: Vector3, s: float, n := 4, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var aim := Basis.from_euler(Vector3(0, yaw, s * -0.9))
	var tubes := []
	for i in n:
		var o := b * Vector3(0, 0.07 + (i % 2) * 0.05, (i - (n - 1) * 0.5) * 0.12)
		tubes.append(Transform3D(aim, pos + o + Vector3(s * 0.06, 0.04, 0)))
	VehicleFittings.smoke_bank(k, p, pos, Vector3(0.14, 0.1, 0.12 * n + 0.04), Vector3(0, yaw, 0), tubes, 0.042, 0.22)


## A tow shackle (a U on its pin) at pos.
static func _shackle(k: VehicleModels, p: Node3D, pos: Vector3, f := -1.0) -> void:
	VehicleFittings.tow_shackle(k, p, pos, f, Vector3(0.14, 0.12, 0.1), 0.06)



## A static spare wheel (not spinning) lying with its axle along `axis`.
static func _spare(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, rot: Vector3, against := Vector3.INF) -> void:
	VehicleWheels.spare(k, p, pos, r, w, rot, "gunmetal_w", null, "offroad", against)


## A stowage basket hung on a turret's back (or standing on a deck): the
## open wire basket (VehicleMounts.basket) on its floor at `floor_center`,
## `size` across, high and deep, and when `back` is ahead of its front edge
## (the turret's back face at the floor's height, in z) a bracket each side
## bolted to that face and running back under the floor, the basket painted
## olive. Crews stow their bags, cans and rolls in these, and seen from above
## it's the open mesh and the kit in it that read.
static func _bustle_basket(k: VehicleModels, p: Node3D, floor_center: Vector3, size: Vector3, back: float, cam: String) -> void:
	VehicleMounts.basket(k, p, floor_center, size, "paint", STOW)
	var front := floor_center.z - size.z * 0.5
	if back >= front:
		return
	for s in [-1.0, 1.0]:
		var x: float = floor_center.x + s * size.x * 0.36
		_beam(k, p, Vector3(x, floor_center.y - 0.03, back - 0.04), Vector3(x, floor_center.y - 0.03, front + size.z * 0.6), 0.05, 0.04, cam)


## Cut branches a camouflaging crew (VehicleCloth.camouflage) has laid along
## its vehicle where they stay put on the move: tucked along a skirt's or
## fender's top against the hull, or along a roof's edge. Each run [cut end,
## tip] in p's space takes one about half the time, more often on a heavily
## camouflaged vehicle; `spread` sizes the leaf sprays (smaller where they'd
## press into a leaning side). Scenery and wrecks never get them.
static func _branches(k: VehicleModels, p: Node3D, runs: Array, spread := 0.2) -> void:
	var rng := VehicleCargo.kit(k, p, Vector3.ZERO, 23)
	var camo := VehicleCloth.camouflage(k)
	if rng == null or camo <= 0.0:
		return
	for run: Array in runs:
		if rng.randf() < 0.25 + camo * 0.4:
			VehicleCloth.branch(k, p, run[0], run[1], rng, spread)


## Non-skid coating: grit laid in the vehicle's own drab paint, so it reads a
## shade darker and duller than the plate round it, never black (a near-black
## patch read from the RTS camera as a hole in the roof).
const NONSKID := Color(0.25, 0.27, 0.21)


## A non-skid walkway: the gritty coating laid where the crew climb and stand
## on a deck or roof, flat on the face at `center` (its top), `size` across
## and along, turned by `yaw`. Darker and rougher than the paint round it, so
## a big flat roof shows where it's walked on from the RTS camera, as real
## armour's do.
static func _walkway(k: VehicleModels, p: Node3D, center: Vector3, size: Vector2, yaw := 0.0) -> void:
	k._box(p, Vector3(size.x, 0.006, size.y), center + Vector3(0, 0.003, 0), "nonslip", NONSKID, Vector3(0, yaw, 0), false)


## The subdued identification panel (VehicleModels._team_mark).
static func _team_mark(k: VehicleModels, p: Node3D, team: int, pos: Vector3, s: Vector3) -> void:
	k._team_mark(p, team, pos, s)


## A seat: pan and back, facing f (-1 forward). A light vehicle's crew seats
## are covered in Cordura nylon, finer and with more sheen than the canvas of
## its benches (a wreck's stay the canvas that burns away), each with its
## four-point harness lying in it (VehicleCloth.harness).
static func _seat(k: VehicleModels, p: Node3D, pos: Vector3, f := -1.0, yaw := 0.0) -> void:
	var rot := Vector3(0, yaw + (PI if f > 0.0 else 0.0), 0)
	VehicleCab.seat(k, p, pos, Vector3(0.46, 0.5, 0.46), rot, Color(0.20, 0.21, 0.17), "canvas" if k.wreck else "nylon")
	VehicleCloth.harness(k, p, pos, Vector3(0.46, 0.5, 0.46), rot)


# --- weapons -----------------------------------------------------------------------

## An M2 .50 cal on its own, receiver at pos, firing along -Z (spade grips
## for a crew-served mount). The mounts carry its ammunition boxes. Returns
## the muzzle position (in p's space).
static func _m2(k: VehicleModels, p: Node3D, pos: Vector3, grips := false) -> Vector3:
	return VehicleWeapons.hmg(k, p, pos, pos + Vector3(0, 0, -1.69), 1.0, 0.0, grips)


## A 40 mm grenade machine gun: a squat receiver, short fat perforated barrel
## and a drum of linked grenades on its right. Returns the muzzle position.
static func _gmg(k: VehicleModels, p: Node3D, pos: Vector3) -> Vector3:
	return VehicleWeapons.gmg(k, p, pos, pos + Vector3(0, 0, -0.9), 1.0, 1.0, true, "gunmetal_w", STOW)


## A remote weapon station (CROWS / Samson pattern) on a roof at pos: the
## turntable, the yoke, the gun cradle and the sight. gun: "hmg", "gmg" or
## "both" (HMG left, GMG right); sc scales the whole station. Becomes
## k.turret, k.mg_tip at the (HMG's) muzzle - on a tank's turret roof, put
## k.turret back to the main turret afterwards (the station turns with it).
static func _rcws(k: VehicleModels, p: Node3D, pos: Vector3, gun: String, cam: String, sc := 1.0) -> Node3D:
	var t := k._pivot(p, pos)
	t.scale = Vector3.ONE * sc
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.05, 0), 0.34, 0.38, 0.1, cam, null, 16)
	# (the turntable is the station's own armoured casting, painted with the
	# vehicle: bare metal there read from above as a pale disc under the gun)
	k._cyl(t, 0.24, 0.28, 0.14, Vector3(0, 0.17, 0), Vector3.ZERO, cam, null, 12)
	var gy := 0.52
	if gun == "both":
		# Samson-style: a wide box between two cradles, the sight head on top
		VehicleMounts.mantlet(k, t, Vector3(0.62, 0.34, 0.6), Vector3(0, 0.36, 0.05), cam)
		VehicleMounts.sight(k, t, Vector3(0, 0.62, -0.05), Vector3(0.3, 0.2, 0.3), [Rect2(Vector2.ZERO, Vector2(0.22, 0.14))], cam)
		k._box(t, Vector3(0.08, 0.16, 0.08), Vector3(0, 0.75, 0.08), cam)
		var a := _m2(k, t, Vector3(-0.42, 0.42, -0.05))
		k._box(t, Vector3(0.24, 0.26, 0.38), Vector3(-0.42, 0.32, 0.35), "paint", STOW)
		_gmg(k, t, Vector3(0.44, 0.42, -0.05))
		k.mg_tip = k._tip(t, a)
		_smoke(k, t, Vector3(0, 0.3, 0.38), 1.0, 3, PI / 2)
		return t
	# yoke arms either side of the cradle
	for s in [-1.0, 1.0]:
		VehicleMounts.mantlet(k, t, Vector3(0.06, 0.42, 0.34), Vector3(s * 0.2, 0.42, 0.02), cam)
	# the cradle's cross-shaft between the arms, painted with them
	k._cyl(t, 0.045, 0.045, 0.5, Vector3(0, gy, 0.02), Vector3(0, 0, PI / 2), cam, null, 8)
	var tip: Vector3
	if gun == "gmg":
		tip = _gmg(k, t, Vector3(0, gy, -0.05))
	else:
		tip = _m2(k, t, Vector3(0, gy, 0.0))
		k._box(t, Vector3(0.22, 0.3, 0.42), Vector3(0.33, gy - 0.05, 0.08), "paint", STOW)
	# the sight unit on the left of the cradle: day camera and thermal windows
	# side by side, under a sun lid
	VehicleMounts.sight(k, t, Vector3(-0.36, gy + 0.06, -0.06), Vector3(0.24, 0.26, 0.36), [Rect2(Vector2(-0.05, 0.02), Vector2(0.08, 0.08)), Rect2(Vector2(0.05, 0.02), Vector2(0.08, 0.08))], cam)
	k._box(t, Vector3(0.28, 0.03, 0.42), Vector3(-0.36, gy + 0.2, -0.08), cam)
	k.mg_tip = k._tip(t, tip)
	return t


# --- Hunter: Oshkosh M-ATV ---------------------------------------------------------

## M-ATV: the V-shaped hull under a tall slab-sided crew capsule with four
## heavy doors and small thick windows, a short bonnet with a big grille, the
## open cargo bed behind and the spare wheel on the back. arm: "", "hmg",
## "gmg" (a CROWS remote weapon station on the roof).
static func _hunter(k: VehicleModels, team: int, arm: String, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	var fz := -1.9
	var rz := 1.9
	var wr := 0.59
	var roof := 2.6
	# Its armoured glass is green-black through the laminate's depth (the
	# blue-green tint read as opaque navy panes from the battle camera); a
	# wreck's stays as it was.
	var glass: Color = ARMOR_GLASS if k.wreck else VmCsat.ARMOR_GLASS
	# --- V-hull, engine block, suspension and the wheels
	k._add(m, VehicleModels.loft("nato_matv_v", [-0.22, -1.0, 0.22, -1.0, 0.22, 2.3, -0.22, 2.3], [-0.74, -1.2, 0.74, -1.2, 0.74, 2.55, -0.74, 2.55], 0.41, 1.13), cam, null, Vector3.ZERO)
	k._box(m, Vector3(1.2, 0.5, 1.95), Vector3(0, 0.95, -2.0), "gunmetal_w")
	k._box(m, Vector3(1.3, 0.2, 5.6), Vector3(0, 1.0, -0.1), "gunmetal_w")
	for s in [-1.0, 1.0]:
		for z in [fz, rz]:
			k._wheel(m, Vector3(s * 0.98, wr, z), wr, 0.44)
			# the double wishbones, the coil-over leaning in behind them
			VehicleRunningGear.wishbone(k, m, Vector3(s * 0.302, 0.485, z), Vector3(s * 0.798, 0.555, z), Vector3(s * 0.322, 0.868, z - 0.04), Vector3(s * 0.778, 0.813, z - 0.04), Vector2(0.16, 0.07), Vector2(0.14, 0.07), Vector3(s * 0.453, 1.133, z + 0.24), Vector3(s * 0.667, 0.627, z + 0.24), 0.075)
	# --- bonnet over the engine, fenders over the front wheels, the grille
	var bon := [-2.95, 1.24, -0.94, 1.24, -0.94, 1.8, -2.45, 1.71, -2.97, 1.5]
	k._add(m, VehicleModels.extrude_x("nato_matv_bonnet", bon, -0.84, 0.84, 0.035), cam, null, Vector3.ZERO)
	var fen := [-2.94, 1.22, -0.94, 1.22, -0.94, 1.66, -2.4, 1.6, -2.95, 1.44]
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("nato_matv_fender", fen, -0.2, 0.2, 0.03), cam, null, Vector3(s * 1.04, 0, 0))
		# the wheel arch lip and mud flap behind the front wheel
		VehicleBody.fender(k, m, Vector3(s * 1.04, 1.22, fz), Vector3(0.42, 0.05, 1.36), s, "gunmetal_w")
		VehicleFittings.mudflap(k, m, Vector3(s * 1.0, 0.98, -1.22), Vector2(0.36, 0.5))
		_lamp(k, m, Vector3(s * 1.02, 1.4, -2.95), 0.078)
		VehicleFittings.signal_lens(k, m, Vector3(s * 1.15, 1.54, -2.93), Vector2(0.1, 0.05), Color(0.55, 0.36, 0.08), -1.0)
	VehicleFittings.grille(k, m, Vector3(0, 1.4, -3.04), Vector2(1.3, 0.38), Vector3(0, PI, 0), cam, null, 9, true)
	k._box(m, Vector3(1.36, 0.05, 0.06), Vector3(0, 1.6, -2.97), cam)
	# the hood's centre bulge and its latches
	k._add(m, VehicleModels.loft("nato_matv_bulge", [-0.44, -2.4, 0.44, -2.4, 0.44, -1.0, -0.44, -1.0], [-0.34, -2.3, 0.34, -2.3, 0.34, -1.0, -0.34, -1.0], 0.0, 0.07, 0.015), cam, null, Vector3(0, 1.73,0), Vector3(-0.062, 0, 0))
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.1, 0.06), Vector3(s * 0.74, 1.56, -2.62), "gunmetal_w", null, Vector3.ZERO, false)
	# bumper with tow shackles and a recovery winch
	VehicleMounts.bumper(k, m, Vector3(2.3, 0.3, 0.26), Vector3(0, 1.0, -3.02), "paint", Color(0.28, 0.3, 0.22))
	VehicleEquipment.winch(k, m, Vector3(0, 1.0, -3.15), Vector3(0.6, 0.2, 0.14))
	for s in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.62, 0.94, -3.08))
	if team >= 0:
		# the bumper code on the bumper's ends, outboard of the shackles (the
		# spare wheel hides the back of the bed)
		VehicleMarkings.bumper(k, m, VehicleMarkings.bumper_code(seed, VehicleMarkings.US_INFANTRY + VehicleMarkings.US_CAVALRY), 0.08, 0.89, 1.0, -3.15, Vector3.FORWARD, 0.29)
	# --- the crew capsule: vertical lower sides, the upper sides leaning in,
	# a lightly raked windscreen
	var lo := [-1.2, -0.98, 1.2, -0.98, 1.2, 1.62, -1.2, 1.62]
	var mid := [-1.24, -0.98, 1.24, -0.98, 1.24, 1.62, -1.24, 1.62]
	var top := [-1.04, -0.68, 1.04, -0.68, 1.04, 1.5, -1.04, 1.5]
	# the capsule is welded armour plate: its roof's edge ground back to a
	# narrow chamfer (kept inside the flush rails), the weld along it
	var capsule := _rings([lo, 1.12, mid, 1.68, top, roof])
	k._add(m, VehicleModels.solid(capsule, "nato_matv_cab", false, 0.03), cam, null, Vector3.ZERO)
	_weld(k, m, _seated(capsule, 0.03), cam)
	# windscreen: two small thick panes in a heavy frame
	for s in [-1.0, 1.0]:
		VehicleMaterials.glaze(k, _zy(k, m, s * 0.47, 0.72, Vector2(-0.905, 1.92), Vector2(-0.745, 2.4), 0.05, 0.0, "glass", glass, false), "armor_glass", glass)
		_zy(k, m, s * 0.47, 0.84, Vector2(-0.92, 1.87), Vector2(-0.73, 2.45), 0.03, -0.01, "gunmetal_w", null, false)
	# doors: seams, small thick windows on the upper sides, handles, hinges
	for s in [-1.0, 1.0]:
		for dz in [-0.88, 0.32, 1.48]:
			VehicleBody.seam(k, m, [Vector3(s * 1.245, 1.681, dz), Vector3(s * 1.085, 2.451, dz)])
		for wz in [-0.28, 0.9]:
			_xy(k, m, s, wz, 0.5, Vector2(1.2, 1.88), Vector2(1.11, 2.32), 0.07, 0.0, cam)
			VehicleMaterials.glaze(k, _xy(k, m, s, wz, 0.4, Vector2(1.2, 1.93), Vector2(1.12, 2.28), 0.03, 0.045, "glass", glass, false), "armor_glass", glass)
		for ends in [Vector2(-0.88, 0.32), Vector2(0.32, 1.48)]:
			var z0: float = ends.x + 0.018
			var z1: float = ends.y - 0.018
			var surface := VehicleSurface.quad([Vector3(s * 1.205, 1.12, z0), Vector3(s * 1.205, 1.12, z1), Vector3(s * 1.245, 1.68, z1), Vector3(s * 1.245, 1.68, z0)], Vector3(0, 1.4, 0))
			VehicleDoors.closed(k, m, surface, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), [Vector2(0.07, 0.2), Vector2(0.07, 0.8)], Vector2(0.82, 0.75), cam, null, "armored")
		# the steps under the doors, the mirror on its arm
		VehicleFrames.step(k, m, Vector3(s * 1.2, 0.98, -0.3), Vector2(0.24, 0.5))
		VehicleFrames.step(k, m, Vector3(s * 1.2, 0.98, 0.9), Vector2(0.24, 0.4))
		# (each hung from the capsule's floor on two flat brackets: alone the
		# treads floated a hand's width under the doors)
		for e: Vector2 in [Vector2(-0.3, 0.235), Vector2(0.9, 0.185)]:
			for dz: float in [-e.y, e.y]:
				_beam(k, m, Vector3(s * 1.17, 0.97, e.x + dz), Vector3(s * 1.17, 1.15, e.x + dz), 0.05, 0.012, "gunmetal_w")
		VehicleFittings.mirror(k, m, Vector3(s * 1.46, 2.16, -0.94), Vector2(0.2, 0.32), -s * 0.3, [Vector3(s * 1.17, 2.2, -0.74)])
		# stowage box low on the capsule side by the rear door
		VehicleEquipment.storage(k, m, Vector3(s * 1.3, 1.26, 1.15), Vector3(0.14, 0.26, 0.5), cam)
	# the engine air intake up the right A-pillar
	_zy(k, m, 1.27, 0.18, Vector2(-0.95, 1.8), Vector2(-0.72, 2.5), 0.2, 0.06, cam)
	k._box(m, Vector3(0.22, 0.12, 0.28), Vector3(1.27, 2.52, -0.72), "gunmetal_w")
	# roof: the flush rails, antennas, the lights over the windscreen
	VehicleCargo.roof_rack(k, m, Vector3(0, roof, 0.42), Vector3(1.92, 0.045, 2.1))
	for s in [-1.0, 1.0]:
		_antenna(k, m, Vector3(s * 0.86, roof, 1.36), 1.3)
		VehicleFittings.lamp_unit(k, m, Vector3(s * 0.35, roof + 0.05, -0.62), Vector3(0.16, 0.1, 0.1), -1.0, [Rect2(Vector2.ZERO, Vector2(0.13, 0.07))])
	# an air-recognition panel, folded, on the roof behind the weapon station
	VehicleEquipment.recognition_panel(k, m, Vector3(0, roof, 1.19), Vector3.ZERO, true)
	# --- the cargo bed behind the capsule, fenders over the rear wheels
	k._add(m, VehicleModels.loft("nato_matv_bed", [-1.2, 1.5, 1.2, 1.5, 1.2, 2.75, -1.2, 2.75], [-1.2, 1.5, 1.2, 1.5, 1.2, 2.78, -1.2, 2.78], 1.22, 1.46), cam, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.5, 1.24), Vector3(s * 1.18, 1.7, 2.15), cam)
		VehicleBody.fender(k, m, Vector3(s * 1.02, 1.22, rz), Vector3(0.44, 0.05, 1.36), s, "gunmetal_w")
		VehicleFittings.mudflap(k, m, Vector3(s * 1.0, 1.0, 2.76), Vector2(0.36, 0.42))
		_jerry(k, m, Vector3(s * 0.88, 1.7, 2.0))
		_taillight(k, m, Vector3(s * 0.95, 1.32, 2.8))
		_shackle(k, m, Vector3(s * 0.55, 1.12, 2.82), 1.0)
	k._box(m, Vector3(2.3, 0.1, 0.08), Vector3(0, 1.92, 2.74), cam)
	_zy(k, m, -0.45, 0.5, Vector2(1.537, 2.32), Vector2(1.581, 1.98), 0.06, 0.0, cam)
	VehicleMaterials.glaze(k, _zy(k, m, -0.45, 0.4, Vector2(1.54, 2.29), Vector2(1.578, 2.01), 0.03, 0.035, "glass", glass, false), "armor_glass", glass)
	# the step up into the bed, on two brackets up to the bed's floor
	VehicleFrames.step(k, m, Vector3(-0.6, 1.05, 2.86), Vector2(0.5, 0.2))
	for x: float in [-0.8, -0.4]:
		_beam(k, m, Vector3(x, 1.04, 2.8), Vector3(x, 1.16, 2.8), 0.04, 0.012, "gunmetal_w")
	k._bag(m, Vector3(1.1, 0.36, 0.5), Vector3(-0.15, 1.64, 2.1), "canvas", BAG, Vector3(0, 0.1, 0))
	# the spare wheel on its swing-out carrier
	_spare(k, m, Vector3(0.22, 1.66, 3.0), 0.56, 0.38, Vector3(PI / 2, 0, 0), Vector3(-0.5, 1.36, 2.77))
	VehicleWheels.carrier(k, m, Vector3(0.22, 1.66, 3.0), 0.56, 0.38, Vector3(PI / 2, 0, 0), "swing", Vector3(-0.5, 1.36, 2.77))
	_team_mark(k, m, team, Vector3(1.228, 1.36, -0.3), Vector3(0.02, 0.2, 0.5))
	_team_mark(k, m, team, Vector3(-1.228, 1.36, -0.3), Vector3(0.02, 0.2, 0.5))
	# --- the roof: a remote weapon station, or the gunner's hatch closed
	if arm == "":
		VehicleMounts.turret_ring(k, m, Vector3(0, roof + 0.04, 0.4), 0.42, 0.44, 0.08, cam, null, 16)
		VehicleFittings.hatch(k, m, Vector3(0, roof + 0.1, 0.4), 0.36, cam, null, 1.0, 0.05)
		k._box(m, Vector3(0.1, 0.06, 0.2), Vector3(0.3, roof + 0.13, 0.4), "gunmetal_w")
		return
	_rcws(k, m, Vector3(0, roof, 0.35), arm, cam, 1.15)


# --- Prowler: Polaris DAGOR ---------------------------------------------------------

## DAGOR: a low open chassis on big off-road tyres, a flat bonnet, the tube
## roll cage over two rows of seats and the rear cargo deck with outward
## benches. arm: "" (none), "hmg" (an M2 on a ring mount on the cage, a
## pintle MG for the passenger), "at" (a Titan launcher on the cage mount).
static func _prowler(k: VehicleModels, team: int, arm: String) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.46
	var fz := -1.6
	var rz := 1.5
	# --- the chassis tub, belly plate and suspension
	k._add(m, VehicleModels.loft("nato_dagor_tub", [-0.5, -1.95, 0.5, -1.95, 0.5, 2.1, -0.5, 2.1], [-0.6, -2.05, 0.6, -2.05, 0.6, 2.2, -0.6, 2.2], 0.42, 0.78), cam, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		for z in [fz, rz]:
			k._wheel(m, Vector3(s * 0.79, wr, z), wr, 0.32)
			# the long-travel wishbones, each coil-over on the axle's outer side
			var dz: float = 0.18 if z > 0 else -0.18
			VehicleRunningGear.wishbone(k, m, Vector3(s * 0.321, 0.402, z), Vector3(s * 0.679, 0.438, z), Vector3(s * 0.321, 0.678, z), Vector3(s * 0.679, 0.642, z), Vector2(0.12, 0.06), Vector2(0.12, 0.06), Vector3(s * 0.391, 1.025, z + dz), Vector3(s * 0.609, 0.575, z + dz), 0.05)
	# --- the flat bonnet, its fenders and the nose
	var bon := [-2.24, 0.62, -0.92, 0.62, -0.92, 1.1, -2.1, 1.06, -2.26, 0.94]
	k._add(m, VehicleModels.extrude_x("nato_dagor_bonnet", bon, -0.66, 0.66, 0.035), cam, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		# each fender sloping down outboard, the front one with a raked lip
		VehicleBody.fender(k, m, Vector3(s * 0.8, 0.98, fz), Vector3(0.36, 0.035, 1.1), s, cam, null, Vector3(0, 0, -s * 0.06))
		VehicleBody.fender(k, m, Vector3(s * 0.8, 0.91, fz - 0.66), Vector3(0.36, 0.035, 0.3), s, cam, null, Vector3(-0.45, 0, -s * 0.06))
		VehicleBody.fender(k, m, Vector3(s * 0.8, 0.98, rz), Vector3(0.36, 0.035, 0.9), s, cam, null, Vector3(0, 0, -s * 0.06))
	VehicleFittings.grille(k, m, Vector3(0, 0.82, -2.3), Vector2(1.0, 0.28), Vector3(0, PI, 0), cam, null, 6, true)
	# tube bumper with the winch, lights each side and on the cage
	VehicleFrames.bull_bar(k, m, [[Vector3(-0.72, 0.6, -2.08), Vector3(-0.85, 0.66, -2.32), Vector3(0.85, 0.66, -2.32), Vector3(0.72, 0.6, -2.08)]], 0.045)
	VehicleEquipment.winch(k, m, Vector3(0, 0.6, -2.3), Vector3(0.42, 0.18, 0.14))
	for s in [-1.0, 1.0]:
		_lamp(k, m, Vector3(s * 0.52, 0.9, -2.3), 0.065, -1.0, false)
		_shackle(k, m, Vector3(s * 0.35, 0.56, -2.24))
	# --- the cockpit: dash, the cowl, seats, steering wheel
	VehicleCab.dashboard(k, m, Vector3(1.3, 0.24, 0.2), Vector3(0, 1.06, -0.86), cam)
	# the floor the crew stand and climb on, its non-skid coat dark against
	# the paint as an open vehicle's is, the first thing seen from above
	k._box(m, Vector3(1.4, 0.1, 3.0), Vector3(0, 0.82, 0.62), "nonslip", NONSKID)
	for x in [-0.36, 0.36]:
		_seat(k, m, Vector3(x, 0.94, -0.3))
		_seat(k, m, Vector3(x, 0.98, 0.62))
	_tube(k, m, Vector3(-0.36, 1.05, -0.8), Vector3(-0.36, 1.2, -0.62), 0.025, "gunmetal_w")
	VehicleCab.steering_wheel(k, m, Vector3(-0.36, 1.22, -0.6), 0.17, Vector3(-0.9, 0, 0), "rubber")
	# rear deck: outward-facing benches either side, kit stowed between
	for s in [-1.0, 1.0]:
		VehicleCab.bench(k, m, Vector3(s * 0.45, 1.0, 1.62), Vector3(0.4, 0.1, 0.9), Vector3(s, 0, 0), Vector3(-0.03, 0.36, 0.08), "canvas", Color(0.2, 0.21, 0.17))
		k._box(m, Vector3(0.34, 0.32, 0.28), Vector3(s * 0.62, 0.62, 1.95), "gunmetal_w")
	k._bag(m, Vector3(0.36, 0.3, 0.6), Vector3(0, 1.05, 1.4), "canvas", BAG)
	_ammo_can(k, m, Vector3(-0.08, 1.01, 2.0))
	_ammo_can(k, m, Vector3(0.1, 1.01, 2.0))
	_jerry(k, m, Vector3(0.82, 0.95, 0.4), Color(0.3, 0.33, 0.22))
	_jerry(k, m, Vector3(-0.82, 0.95, 0.4), Color(0.3, 0.33, 0.22))
	# the spare wheel upright on the tailgate
	_spare(k, m, Vector3(0, 1.16, 2.25), 0.44, 0.28, Vector3(PI / 2, 0, 0))
	VehicleWheels.carrier(k, m, Vector3(0, 1.16, 2.25), 0.44, 0.28, Vector3(PI / 2, 0, 0), "cradle", Vector3(0, 0.78, 2.25))
	for s in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 0.62, 0.72, 2.24))
	# --- the roll cage: each side's A-pillar bent into the roof rail and on
	# down over the deck to the tail, the B and C posts, side bar and diagonal,
	# then the roof hoops across
	var cr := 0.035
	var ry := 1.8
	var cage := []
	for s in [-1.0, 1.0]:
		var x0: float = s * 0.7
		var x1: float = s * 0.68
		cage.append([Vector3(x0, 1.08, -0.92), Vector3(x1, ry, -0.28), Vector3(x1, ry, 1.05), Vector3(x1 * 0.98, 1.32, 2.15), Vector3(x1 * 0.98, 0.8, 2.15)])
		cage.append([Vector3(x1, 0.8, 0.12), Vector3(x1, ry, 0.12)])
		cage.append([Vector3(x1, 0.8, 1.05), Vector3(x1, ry, 1.05)])
		cage.append([Vector3(x1, 1.3, 0.12), Vector3(x1, 1.3, 1.05), cr * 0.8])
		cage.append([Vector3(x1, 0.8, 0.12), Vector3(x1, 1.6, 1.05), cr * 0.7])
	for z in [-0.28, 0.12, 1.05]:
		cage.append([Vector3(-0.68, ry, z), Vector3(0.68, ry, z)])
	cage.append([Vector3(-0.67, 1.32, 2.15), Vector3(0.67, 1.32, 2.15)])
	cage.append([Vector3(-0.68, ry, 0.12), Vector3(0.68, ry, 1.05), cr * 0.8])
	VehicleFrames.roll_bar(k, m, cage, cr, cam)
	# the work light bar on the front roof bar, antennas at the back
	var lamp := Color(0.72, 0.72, 0.66)
	VehicleFittings.light_bar(k, m, Vector3(0, ry + 0.05, -0.3), Vector3(0.9, 0.09, 0.08), [lamp, lamp, lamp, lamp], "work", Vector3(0.14, 0.06, 0), -1.0, "gunmetal_w", null)
	_antenna(k, m, Vector3(-0.66, 1.3, 2.12), 1.8)
	_team_mark(k, m, team, Vector3(0.67, 0.98, -1.4), Vector3(0.02, 0.06, 0.6))
	_team_mark(k, m, team, Vector3(-0.67, 0.98, -1.4), Vector3(0.02, 0.06, 0.6))
	if arm == "":
		return
	# the passenger's pintle MG (an M240-class .338) on a swing arm
	var pz := -0.78
	VehicleMounts.pintle(k, m, Vector3(0.6, 1.08, pz), Vector3(0.6, 1.45, pz - 0.1), "gunmetal_w", null, Vector2(0.025, 0.03), Vector2(0.08, 0.13))
	var ptip := VehicleWeapons.mmg(k, m, Vector3(0.6, 1.45, pz - 0.1), Vector3(0.6, 1.46, pz - 1.12), 1.0, 1.0, true, "gunmetal_w", STOW)
	# the ring mount on the cage roof, turning whole with the gun: the ring,
	# the carriage bar across its front under the post, the post clamped to
	# the bar; the gunner stands in the ring behind the gun, on the rear seats'
	# floor, turning with it
	var t := k._pivot(m, Vector3(0, ry + 0.02, 0.58))
	k.turret = t
	var bar := -0.34
	VehicleMounts.ring_mount(k, t, Vector3.ZERO, 0.48, 0.03, "gunmetal_w", null, [], t, bar)
	VehicleMounts.pedestal(k, t, Vector3(0, 0, bar), Vector3(0, 0.365, bar), null, "gunmetal_w", null, 0.0, Vector2(0.05, 0.06), 0, Vector3(0.1, 0.3, 0.16), 0.0255)
	if arm == "hmg":
		var tip := _m2(k, t, Vector3(0, 0.42, bar), true)
		k._box(t, Vector3(0.22, 0.26, 0.36), Vector3(0.2, 0.36, bar + 0.02), "paint", STOW)
		k.mg_tip = k._tip(t, tip)
		k.gunner_floor = {"on": t, "y": 0.45 - 1.3, "area": Rect2(Vector2(0, bar + 0.4 + 0.3), Vector2.ZERO)}
		# the pintle gun is the second gun, decoration here
	else:
		# Titan launcher: the tube, the sight/command unit, the grip
		var ly := 0.48
		VehicleWeapons.launch_tube(k, t, Vector3(0, ly, -0.25), 0.085, 1.25, "paint", Color(0.33, 0.35, 0.27))
		VehicleMounts.sight(k, t, Vector3(-0.2, ly - 0.02, -0.1), Vector3(0.22, 0.24, 0.42), [Rect2(Vector2(0, 0.02), Vector2(0.14, 0.12))], "gunmetal_w")
		k._box(t, Vector3(0.12, 0.2, 0.12), Vector3(0, ly - 0.2, -0.1), "gunmetal_w")
		k.gun_tip = k._tip(t, Vector3(0, ly, -0.92))
		# two reloads, each in its own launch tube, in a rack on the deck
		for x in [-0.12, 0.12]:
			VehicleWeapons.launch_tube(k, m, Vector3(x, 1.12, 1.85), 0.08, 1.2, "paint", Color(0.33, 0.35, 0.27))
	if k.mg_tip == null:
		k.mg_tip = k._tip(m, ptip)
		# the front passenger works it from his seat
		k.gunner_seated = true


# --- 8x8s: Marshall (Patria AMV), Rhino (Rooikat MTTD) ---------------------------------

## Road wheels on independent suspension either side at +-x: the tyres, the
## lower and upper wishbones going in to the hull, a mud flap behind the last.
static func _axles(k: VehicleModels, m: Node3D, x: float, zs: Array, r: float, w: float) -> void:
	for s in [-1.0, 1.0]:
		for z in zs:
			k._wheel(m, Vector3(s * x, r, z), r, w)
			VehicleRunningGear.wishbone(k, m, Vector3(s * (x - 0.608), r - 0.109, z), Vector3(s * (x - 0.192), r - 0.051, z), Vector3(s * (x - 0.589), r + 0.263, z - 0.05), Vector3(s * (x - 0.211), r + 0.217, z - 0.05), Vector2(0.16, 0.08), Vector2(0.14, 0.07))
		var zl: float = zs[zs.size() - 1]
		VehicleFittings.mudflap(k, m, Vector3(s * x, r * 0.85, zl + r + 0.12), Vector2(w + 0.04, 0.42))


## Patria AMV with the Denel 40 mm turret: the long flat-sided hull over eight
## big wheels, the long raked glacis with the trim vane folded on it, the
## driver forward left beside the engine, the troop compartment and its ramp
## at the back, the two-man turret mid-hull.
static func _marshall(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.6
	var roof := 2.14
	_axles(k, m, 1.08, [-2.55, -1.05, 0.8, 2.3], wr, 0.44)
	# lower hull between the wheels; the nose and tail blocks full width
	k._add(m, VehicleModels.loft("nato_amv_low", [-0.6, -3.1, 0.6, -3.1, 0.6, 3.5, -0.6, 3.5], [-0.86, -3.6, 0.86, -3.6, 0.86, 3.85, -0.86, 3.85], 0.46, 1.27), cam, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("nato_amv_nose", [-1.1, -3.45, 1.1, -3.45, 1.25, -3.25, -1.25, -3.25], [-1.15, -3.85, 1.15, -3.85, 1.38, -3.25, -1.38, -3.25], 0.78, 1.27), cam, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("nato_amv_tail", [-1.3, 2.98, 1.3, 2.98, 1.3, 3.8, -1.3, 3.8], [-1.38, 2.98, 1.38, 2.98, 1.38, 3.85, -1.38, 3.85], 0.74, 1.27), cam, null, Vector3.ZERO)
	# the upper hull: a vertical band over the wheels, then the sides leaning in
	var r0 := [-1.15, -3.85, 1.15, -3.85, 1.4, -3.45, 1.4, 3.85, -1.4, 3.85, -1.4, -3.45]
	var r1 := [-1.1, -3.72, 1.1, -3.72, 1.4, -3.3, 1.4, 3.85, -1.4, 3.85, -1.4, -3.3]
	var r2 := [-0.92, -2.42, 0.92, -2.42, 1.16, -2.18, 1.16, 3.78, -1.16, 3.78, -1.16, -2.18]
	var hull := _rings([r0, 1.26, r1, 1.56, r2, roof])
	k._add(m, VehicleModels.solid(hull, "nato_amv_hull", false, 0.05), cam, null, Vector3.ZERO)
	# the welds along the roof's chamfered edge and along the crease where
	# the sides start leaning in
	_weld(k, m, _seated(hull, 0.05), cam)
	_weld(k, m, [Vector3(-1.4, 1.56, 3.85), Vector3(-1.4, 1.56, -3.3), Vector3(-1.1, 1.56, -3.72), Vector3(1.1, 1.56, -3.72), Vector3(1.4, 1.56, -3.3), Vector3(1.4, 1.56, 3.85)], cam)
	# wheel wells: dark liners under the overhang over each wheel
	for s in [-1.0, 1.0]:
		for z in [-2.55, -1.05, 0.8, 2.3]:
			k._box(m, Vector3(0.5, 0.03, 1.3), Vector3(s * 1.12, 1.245, z), "gunmetal_w", null, Vector3.ZERO, false)
	# the lower side plates down between the wheels, an arch over each (the
	# AMV's paired wheels leave only a narrow web between their arches)
	VmCore.wheel_wells(k, m, "nato_amv_wells", 1.315, 1.395, 0.8, 1.27, -3.3, 2.99, [-2.55, -1.05, 0.8, 2.3], wr, wr + 0.12, 0.84, cam)
	# glacis: the trim vane folded flat, the driver's hatch and periscopes,
	# the engine deck grilles on the right, lights and tow eyes on the nose
	var ga := Vector2(-3.72, 1.56)
	var gb := Vector2(-2.42, roof)
	var vane_foot := ga.lerp(gb, 0.12)
	var vane_top := ga.lerp(gb, 0.62)
	var glacis := (gb - ga).normalized()
	VehicleMounts.trim_vane(k, m, Vector3(0, vane_foot.y, vane_foot.x), Vector3(0, vane_top.y, vane_top.x), 2.3, 0.06, Vector3(0, glacis.x, -glacis.y), cam, null, 2, 3)
	VehicleFittings.hatch(k, m, Vector3(-0.6, roof + 0.03, -2.0), 0.3, cam, null, 1.0, 0.06)
	for i in 3:
		VehicleFittings.periscope(k, m, Vector3(-0.78 + i * 0.18, roof + 0.05, -2.36), Vector3(0.16, 0.1, 0.07), Vector3(0, (i - 1) * 0.3, 0))
	VehicleFittings.grille(k, m, Vector3(0.42, roof + 0.035, -1.55), Vector2(1.0, 1.1), Vector3(-PI / 2, 0, 0), cam, null, 6)
	# non-skid walkways: the driver's way back along the deck beside the
	# engine grille, and the roof behind the troop hatches
	_walkway(k, m, Vector3(-0.62, roof, -1.26), Vector2(0.62, 0.72))
	_walkway(k, m, Vector3(0, roof, 3.38), Vector2(1.36, 0.5))
	for s in [-1.0, 1.0]:
		_lamp(k, m, Vector3(s * 1.0, 1.14, -3.6), 0.07)
		_lamp(k, m, Vector3(s * 0.72, 1.14, -3.68), 0.06, -1.0, false)
		_shackle(k, m, Vector3(s * 0.5, 0.9, -3.62))
	# exhaust grille on the right side, forward, and the diesel's soot
	# streaked back from it along the band over the wheels
	VehicleFittings.grille(k, m, Vector3(1.43, 1.42, -2.2), Vector2(0.6, 0.32), Vector3(0, PI / 2, 0), cam, null, 4)
	VehicleBody.soot(k, m, Vector3(1.4, 1.42, -1.94), Vector3.BACK, Vector3.UP, Vector3.RIGHT, 0.8, 0.2)
	# side details: stowage bins on the sloping sides, vision blocks, a tow
	# cable clipped along the hull
	for s in [-1.0, 1.0]:
		_xy_bin(k, m, s, 0.2, 1.3, Vector2(1.4, 1.56), Vector2(1.16, roof), 0.14, cam)
		# a bolted appliqué module over the driver's and engine bay's flank
		_xy_module(k, m, s, -1.48, 0.95, Vector2(1.4, 1.56), Vector2(1.16, roof), 0.06, cam, Vector2i(3, 2), 0.05)
		_xy_bin(k, m, s, 2.6, 1.1, Vector2(1.4, 1.56), Vector2(1.16, roof), 0.14, cam)
		# the butt weld where the flank's two side plates meet, up the side
		# and over the crease between the forward vision block and the bin,
		# so the 7 m side reads as welded plate, not one moulded slab (a
		# wreck stays as it was)
		if not k.wreck:
			_weld(k, m, [Vector3(s * 1.4, 1.27, -0.62), Vector3(s * 1.4, 1.56, -0.62), Vector3(s * 1.177, 2.1, -0.62)], cam, 0.014)
		for z in [-0.9, 1.5]:
			VehicleMaterials.glaze(k, _xy(k, m, s, z, 0.22, Vector2(1.36, 1.64), Vector2(1.26, 1.86), 0.05, 0.02, "glass", null, false), "armor_glass", VehicleMounts.BLOCK)
			# the armoured brow welded over the block, so it sits in the side
			# under its own shadow rather than as a dark tile on the paint
			if not k.wreck:
				_xy(k, m, s, z, 0.25, Vector2(1.268, 1.88), Vector2(1.251, 1.92), 0.07, 0.035, cam)
		VehicleFittings.tow_cable(k, m, [Vector3(s * 1.42, 1.38, -2.9), Vector3(s * 1.42, 1.38, 3.3)], 0.025, 0.04)
		k._box(m, Vector3(0.05, 0.12, 0.3), Vector3(s * 1.42, 1.4, 3.5), "gunmetal_w")
		_antenna(k, m, Vector3(s * 0.95, roof, 3.45), 1.6)
	# roof over the troop compartment: two hatches, periscopes
	for s in [-1.0, 1.0]:
		VehicleFittings.panel_hatch(k, m, Vector3(s * 0.48, roof + 0.03, 2.55), Vector3(0.72, 0.06, 0.95), cam)
		for z in [1.75, 3.4]:
			VehicleFittings.periscope(k, m, Vector3(s * 0.95, roof + 0.05, z), Vector3(0.14, 0.1, 0.12), Vector3(0, -s * PI / 2, 0))
	# the section's kit on the roof's left edge outboard of the troop hatch,
	# between its periscopes, where it doesn't foul the hatch's swing (a
	# 6 m roof with kit only on the turret read as bare plate from above)
	VmCore.roof_kit(k, m, Vector3(-0.99, roof, 2.55), 0.0, Vector2(0.26, 0.9), 2, BAG)
	# an air-recognition panel, folded, on the rear walkway
	VehicleEquipment.recognition_panel(k, m, Vector3(0, roof + 0.006, 3.38), Vector3.ZERO, true)
	# the rear: ramp with its door and the door's lever handle, hinges, lights
	VehicleDoors.leaf(k, m, Vector3(1.75, 1.15, 0.08), Vector3(0, 1.4, 3.86), cam)
	VehicleDoors.leaf(k, m, Vector3(0.6, 0.95, 0.04), Vector3(0.42, 1.48, 3.91), cam)
	VehicleDoors.lever(k, m, Vector3(0.18, 1.45, 3.93), Vector3.BACK, Vector3.DOWN, 0.12, 0.1)
	for s in [-1.0, 1.0]:
		# the ramp's heavy hinges along its foot
		VehicleDoors.hinge(k, m, Vector3(s * 0.62, 0.86, 3.82), Vector3.BACK, Vector3.RIGHT, 0.06, "gunmetal_w")
		_taillight(k, m, Vector3(s * 1.15, 1.72, 3.82))
		_shackle(k, m, Vector3(s * 1.05, 0.92, 3.86), 1.0)
		_jerry(k, m, Vector3(s * 1.15, 1.25, 3.95), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	_team_mark(k, m, team, Vector3(1.405, 1.42, 1.5), Vector3(0.02, 0.2, 0.7))
	_team_mark(k, m, team, Vector3(-1.405, 1.42, 1.5), Vector3(0.02, 0.2, 0.7))
	# cut branches tucked along the crease over the wheels, at the foot of the
	# armour module and the back bin
	var runs := []
	for s in [-1.0, 1.0]:
		runs.append([Vector3(s * 1.43, 1.585, -0.95), Vector3(s * 1.44, 1.59, -2.55)])
		runs.append([Vector3(s * 1.43, 1.585, 3.45), Vector3(s * 1.44, 1.59, 2.2)])
	_branches(k, m, runs, 0.16)
	# --- the turret: low and faceted, the 40 mm, smoke dischargers, the
	# commander's panoramic sight on its mast
	var t := k._pivot(m, Vector3(0, roof, 0.2))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.04, 0.1), 0.9, 0.95, 0.08, cam, null, 20)
	var tb := [-0.42, -1.05, 0.42, -1.05, 0.94, -0.55, 0.97, 1.12, 0.74, 1.4, -0.74, 1.4, -0.97, 1.12, -0.94, -0.55]
	var tt := [-0.34, -0.76, 0.34, -0.76, 0.76, -0.4, 0.79, 1.02, 0.6, 1.24, -0.6, 1.24, -0.79, 1.02, -0.76, -0.4]
	k._add(t, VehicleModels.loft("nato_amv_tur", tb, tt, 0.06, 0.74, 0.04), cam, null, Vector3.ZERO)
	_weld(k, t, _seated(_rings([tb, 0.06, tt, 0.74]), 0.04), cam)
	# gun: the mantlet with its canvas boot round the recoil sleeve, the
	# barrel, the muzzle brake
	VehicleMounts.mantlet(k, t, Vector3(0.44, 0.36, 0.4), Vector3(0, 0.34, -1.18), cam, null, Vector3.ZERO, Vector2(0.1, 0.16))
	VehicleWeapons.autocannon(k, t, Vector3(0, 0.34, -1.32), Vector3(0, 0.34, -4.59), Vector2(0.1, 0.6), Vector2(0.052, 0.058), Vector2(0.08, 0.36), "paint", GUN)
	k.mg_tip = k._tip(t, Vector3(0, 0.34, -4.6))
	# coaxial MG port beside the mantlet
	VehicleWeapons.coax(k, t, Vector3(0.32, 0.3, -1.3), 0.3, 0.025)
	# sights: gunner's forward left, the commander's panoramic sight on a mast
	VehicleMounts.sight(k, t, Vector3(-0.42, 0.78, -0.5), Vector3(0.3, 0.26, 0.34), [Rect2(Vector2(0, 0.02), Vector2(0.22, 0.16))], cam)
	VehicleMounts.sight(k, t, Vector3(0.45, 1.05, 0.55), Vector3(0.36, 0.3, 0.36), [Rect2(Vector2(0, 0.02), Vector2(0.24, 0.16))], cam, null, Vector3(0.08, 0.1, 0.33))
	# hatches, smoke dischargers, bustle stowage, antenna
	VehicleFittings.hatch(k, t, Vector3(-0.42, 0.69, 0.6), 0.3, cam, null, 1.0, 0.06)
	k._box(t, Vector3(0.12, 0.08, 0.2), Vector3(-0.2, 0.74, 0.6), "gunmetal_w")
	# the crew's kit on the roof's bare front right, ahead of the commander's
	# sight mast (the hull's roof is all hatches and the turret's sweep)
	VmCore.roof_kit(k, t, Vector3(0.4, 0.74, -0.2), 0.0, Vector2(0.45, 0.5), 0, BAG)
	for s in [-1.0, 1.0]:
		_smoke(k, t, Vector3(s * 0.92, 0.5, -0.55), s, 4, s * -0.55)
		k._box(t, Vector3(0.06, 0.3, 0.9), Vector3(s * 1.0, 0.36, 0.55), cam, null, Vector3(0, 0, s * 0.18))
		if team >= 0:
			# the tactical code on the turret's side plates
			_stencil(k, t, _tac(seed), 0.18, Vector3(s * 1.0295, 0.3654, 0.55), Vector3(0, 0, -s), Vector3(s * 0.984, 0.179, 0))
	# the bustle basket: an open wire basket on brackets off the turret's
	# back, the crew's kit stowed in it
	_bustle_basket(k, t, Vector3(0, 0.2, 1.68), Vector3(1.5, 0.3, 0.5), 1.36, cam)
	k._bag(t, Vector3(0.7, 0.32, 0.36), Vector3(-0.35, 0.37, 1.7), "canvas", BAG, Vector3(0, 0.08, 0))
	_ammo_can(k, t, Vector3(0.3, 0.33, 1.7), Vector3(0, PI / 2, 0))
	_antenna(k, t, Vector3(-0.6, 0.66, 1.25), 1.5)


## Rooikat with the 120 mm MTTD turret: a long low hull with a pointed nose
## and a ridge up the glacis, the sides leaning in over eight big wheels, the
## big turret set mid-rear with its long bustle and the long 120 mm with a
## fume extractor. up: reactive armour on the nose and turret, slat cages
## along the sides and over the back, and a remote .50 on the turret roof.
static func _rhino(k: VehicleModels, team: int, up: bool, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.6
	var roof := 1.96
	_axles(k, m, 1.1, [-2.45, -0.95, 1.05, 2.5], wr, 0.44)
	# the lower hull: a pointed nose under the glacis, sides inboard of the wheels
	var lb := [-0.1, -3.0, 0.1, -3.0, 0.62, -2.7, 0.62, 3.3, -0.62, 3.3, -0.62, -2.7]
	var lt := [-0.16, -3.58, 0.16, -3.58, 0.88, -3.05, 0.88, 3.55, -0.88, 3.55, -0.88, -3.05]
	k._add(m, VehicleModels.loft("nato_rk_low", lb, lt, 0.5, 1.22), cam, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("nato_rk_tail", [-1.3, 3.08, 1.3, 3.08, 1.3, 3.5, -1.3, 3.5], [-1.4, 3.08, 1.4, 3.08, 1.4, 3.55, -1.4, 3.55], 0.75, 1.22), cam, null, Vector3.ZERO)
	# the upper hull: the arrowhead nose climbing to a narrow front of the roof
	var u0 := [-0.16, -3.58, 0.16, -3.58, 1.42, -2.78, 1.42, 3.55, -1.42, 3.55, -1.42, -2.78]
	var u1 := [-0.15, -3.42, 0.15, -3.42, 1.42, -2.62, 1.42, 3.55, -1.42, 3.55, -1.42, -2.62]
	var u2 := [-0.36, -2.3, 0.36, -2.3, 1.12, -1.82, 1.12, 3.48, -1.12, 3.48, -1.12, -1.82]
	# (the roof's chamfer kept narrow: the driver's periscopes stand at its
	# front edge)
	var hull := _rings([u0, 1.21, u1, 1.45, u2, roof])
	k._add(m, VehicleModels.solid(hull, "nato_rk_hull", false, 0.04), cam, null, Vector3.ZERO)
	_weld(k, m, _seated(hull, 0.04), cam)
	for s in [-1.0, 1.0]:
		for z in [-2.45, -0.95, 1.05, 2.5]:
			k._box(m, Vector3(0.52, 0.03, 1.3), Vector3(s * 1.12, 1.195, z), "gunmetal_w", null, Vector3.ZERO, false)
	# the lower side plates between the wheels, an arch over each, from the
	# foot of the arrowhead nose back to the tail block
	VmCore.wheel_wells(k, m, "nato_rk_wells", 1.335, 1.415, 0.8, 1.22, -2.78, 3.09, [-2.45, -0.95, 1.05, 2.5], wr, wr + 0.12, 0.86, cam)
	# the driver's hatch centred at the top of the glacis, his periscopes,
	# lights in guards on the nose, tow eyes
	VehicleFittings.hatch(k, m, Vector3(0, roof + 0.03, -1.9), 0.28, cam, null, 1.0, 0.06)
	for i in 3:
		VehicleFittings.periscope(k, m, Vector3(-0.18 + i * 0.18, roof + 0.05, -2.24), Vector3(0.16, 0.1, 0.07), Vector3(0, (i - 1) * 0.35, 0))
	_tube(k, m, Vector3(0, 1.22, -3.56), Vector3(0, roof + 0.01, -2.3), 0.04, cam)
	for s in [-1.0, 1.0]:
		# non-skid walkways either side of the driver's hatch, up to the turret
		_walkway(k, m, Vector3(s * 0.64, roof, -1.38), Vector2(0.44, 0.7))
		_lamp(k, m, Vector3(s * 0.95, 1.36, -2.88), 0.07)
		_shackle(k, m, Vector3(s * 0.32, 0.98, -3.32))
		# big stowage bins along the leaning sides, the engine deck louvres
		_xy_bin(k, m, s, -0.6, 1.5, Vector2(1.42, 1.45), Vector2(1.12, roof), 0.16, cam)
		_xy_bin(k, m, s, 1.25, 1.2, Vector2(1.42, 1.45), Vector2(1.12, roof), 0.16, cam)
		# the butt weld between the side's two plates, up the gap between
		# the bins (one plate nose to tail read as a moulded slab; a wreck
		# stays as it was)
		if not k.wreck:
			_weld(k, m, [Vector3(s * 1.42, 1.22, 0.4), Vector3(s * 1.42, 1.45, 0.4), Vector3(s * 1.144, 1.92, 0.4)], cam, 0.014)
		# (the grab rail along the side, painted with the hull it's welded to)
		k._box(m, Vector3(0.06, 0.06, 2.8), Vector3(s * 1.44, 1.32, 0.3), cam)
		# the engine's exhaust outlets on the hull's rear flanks, a louvred
		# guard in the hull's paint over each (bare steel slabs there read
		# from above as black holes in the sides); a wreck keeps the slabs
		if k.wreck:
			k._box(m, Vector3(0.05, 0.3, 0.55), Vector3(s * 1.43, 1.0, 3.1), "gunmetal_w")
		else:
			k._box(m, Vector3(0.05, 0.3, 0.55), Vector3(s * 1.43, 1.0, 3.1), cam)
			VehicleFittings.grille(k, m, Vector3(s * 1.485, 1.0, 3.1), Vector2(0.48, 0.24), VmCsat._face_rot(Vector3(s, 0, 0), Vector3.UP), cam, null, 3)
		_taillight(k, m, Vector3(s * 1.15, 1.5, 3.57))
		_shackle(k, m, Vector3(s * 0.7, 0.95, 3.58), 1.0)
		_antenna(k, m, Vector3(s * 0.95, roof, 3.3), 1.5)
	VehicleFittings.grille(k, m, Vector3(0, roof + 0.035, 2.85), Vector2(1.6, 0.9), Vector3(-PI / 2, 0, 0), cam, null, 5)
	k._box(m, Vector3(1.9, 0.6, 0.06), Vector3(0, 1.5, 3.57), "gunmetal_w")
	_team_mark(k, m, team, Vector3(1.425, 1.33, -1.6), Vector3(0.02, 0.18, 0.6))
	_team_mark(k, m, team, Vector3(-1.425, 1.33, -1.6), Vector3(0.02, 0.18, 0.6))
	# cut branches tucked along the crease over the wheels, under the bins
	# (and between the slat cage's brackets on the urban package)
	var runs := []
	for s in [-1.0, 1.0]:
		runs.append([Vector3(s * 1.45, 1.475, -0.55), Vector3(s * 1.46, 1.48, -1.85)])
		runs.append([Vector3(s * 1.45, 1.475, 2.65), Vector3(s * 1.46, 1.48, 1.35)])
	_branches(k, m, runs, 0.16)
	# --- the turret: wedged front faces round the gun, a long bustle
	var t := k._pivot(m, Vector3(0, roof, 0.5))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.04, 0), 1.05, 1.1, 0.08, cam, null, 20)
	var tb := [-0.48, -1.5, 0.48, -1.5, 1.16, -0.85, 1.2, 1.95, 0.98, 2.3, -0.98, 2.3, -1.2, 1.95, -1.16, -0.85]
	var tt := [-0.4, -1.22, 0.4, -1.22, 0.98, -0.68, 1.02, 1.9, 0.84, 2.16, -0.84, 2.16, -1.02, 1.9, -0.98, -0.68]
	k._add(t, VehicleModels.loft("nato_rk_tur", tb, tt, 0.06, 0.8, 0.05), cam, null, Vector3.ZERO)
	_weld(k, t, _seated(_rings([tb, 0.06, tt, 0.8]), 0.05), cam)
	# the gun: mantlet and its canvas boot, barrel with its thermal sleeve and
	# fume extractor, the muzzle reference sensor
	var gy := 0.42
	VehicleMounts.mantlet(k, t, Vector3(0.62, 0.5, 0.42), Vector3(0, gy, -1.55), cam, null, Vector3.ZERO, Vector2(0.13, 0.24))
	k._cyl(t, 0.13, 0.13, 0.7, Vector3(0, gy, -2.05), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	VehicleFittings.barrel(k, t, Vector3(0, gy, -2.1), Vector3(0, gy, -6.5), 0.10, "paint", GUN)
	VehicleFittings.evacuator(k, t, Vector3(0, gy, -3.25), 0.165, 0.7, "paint", GUN)
	VehicleWeapons.muzzle_sensor(k, t, Vector3(0, gy + 0.15, -6.4), Vector3(0.08, 0.06, 0.12), Vector3(0, gy, -6.4), 0.1)
	k.gun_tip = k._tip(t, Vector3(0, gy, -6.52))
	VehicleWeapons.coax(k, t, Vector3(0.42, gy - 0.08, -1.7), 0.3, 0.025)
	k.mg_tip = k._tip(t, Vector3(0.42, gy - 0.08, -1.86))
	# sights: the gunner's ahead on the left, the commander's cupola and his
	# panoramic sight on the right; the loader's hatch
	VehicleMounts.sight(k, t, Vector3(-0.62, 0.95, -0.5), Vector3(0.36, 0.3, 0.42), [Rect2(Vector2(0, 0.03), Vector2(0.26, 0.18))], cam)
	VehicleMounts.cupola(k, t, Vector3(0.52, 0.9, 0.6), 0.34, 0.36, 0.2, 5, -0.9, 0.45, cam, null, Vector3(0.1, 0.08, 0.05))
	VehicleFittings.hatch(k, t, Vector3(0.52, 1.03, 0.6), 0.3, cam, null, 1.0, 0.06)
	VehicleMounts.sight(k, t, Vector3(0.62, 1.2, -0.4), Vector3(0.32, 0.28, 0.32), [Rect2(Vector2(0, 0.02), Vector2(0.22, 0.14))], cam, null, Vector3(0.07, 0.08, 0.4))
	VehicleFittings.hatch(k, t, Vector3(-0.5, 0.83, 0.75), 0.28, cam, null, 1.0, 0.06)
	for s in [-1.0, 1.0]:
		_smoke(k, t, Vector3(s * 1.06, 0.6, -0.72), s, 4, s * -0.5)
		# bins on the bustle sides
		VehicleEquipment.storage(k, t, Vector3(s * 1.18, 0.42, 1.35), Vector3(0.24, 0.42, 1.0), cam, null, Vector3(0, 0, s * 0.1))
		if not up:
			# The MTTD's crew sit behind bolt-on armour modules on the turret's
			# flanks, between the smoke dischargers and the bins: thick
			# chamfered slabs with heavy bolts, so the side reads as armour
			# hung on a hull rather than one blank wall (the urban package
			# hangs reactive bricks there instead), the turret number on it.
			var face := _xy_module(k, t, s, 0.15, 1.2, Vector2(1.168, 0.06), Vector2(0.986, 0.8), 0.1, cam, Vector2i(4, 2), 0.06)
			if team >= 0:
				_stencil(k, t, _tac(seed, false), 0.24, face, Vector3(0, 0, -s), Vector3(s * 0.971, 0.239, 0))
	_bustle_basket(k, t, Vector3(0, 0.28, 2.5), Vector3(2.0, 0.36, 0.46), 2.26, cam)
	k._bag(t, Vector3(0.8, 0.36, 0.38), Vector3(0.45, 0.47, 2.5), "canvas", BAG, Vector3(0, -0.1, 0))
	# the crosswind sensor on its mast
	VehicleMounts.mast_segment(k, t, Vector3(0.1, 1.0, 1.9), 0.45, 0.018)
	# the crew's kit on the bustle's roof behind the cupola, and behind the
	# loader's hatch where the urban package doesn't put its remote .50
	VmCore.roof_kit(k, t, Vector3(0.55, 0.8, 1.55), PI / 2, Vector2(0.45, 0.6), 0, BAG)
	if not up:
		VmCore.roof_kit(k, t, Vector3(-0.5, 0.8, 1.5), PI / 2, Vector2(0.45, 0.6), 1, BAG)
	k._box(t, Vector3(0.14, 0.05, 0.05), Vector3(0.1, 1.24, 1.9), "gunmetal_w", null, Vector3.ZERO, false)
	# a small sensor head on each front corner of the roof, its window forward
	for s in [-1.0, 1.0]:
		VehicleMounts.sight(k, t, Vector3(s * 0.85, 0.85, -0.55), Vector3(0.14, 0.1, 0.14), [Rect2(Vector2(0, 0.01), Vector2(0.1, 0.06))], "gunmetal_w")
	_jerry(k, t, Vector3(-0.45, 0.525, 2.5), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	_jerry(k, t, Vector3(-0.85, 0.525, 2.5), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	if not up:
		_antenna(k, t, Vector3(-0.8, 0.8, 2.2), 1.6)
		return
	# --- urban package: ERA bricks on the turret front and cheeks and along
	# the glacis, slat cages round the hull sides and back, a remote .50
	for s in [-1.0, 1.0]:
		# the turret's front cheeks and the forward half of its sides
		_era(k, t, Vector3(s * 0.48, 0.06, -1.5), Vector3(s * 1.16, 0.06, -0.85), Vector3(s * 0.4, 0.8, -1.22), Vector3(s * 0.98, 0.8, -0.68), 3, 2, Vector3(s, 0.2, -1.0), cam, 0.12)
		_era(k, t, Vector3(s * 1.16, 0.06, -0.85), Vector3(s * 1.2, 0.06, 1.95), Vector3(s * 0.98, 0.8, -0.68), Vector3(s * 1.02, 0.8, 1.9), 3, 2, Vector3(s, 0.0, 0.0), cam, 0.12, 0.02, 0.56)
		# both plates of the arrowhead glacis
		_era(k, m, Vector3(s * 0.15, 1.45, -3.42), Vector3(s * 1.42, 1.45, -2.62), Vector3(s * 0.36, 1.96, -2.3), Vector3(s * 1.12, 1.96, -1.82), 4, 2, Vector3(s * 0.4, 0.6, -0.8), cam)
	# slat cages: a frame standing off each side and across the back
	for s in [-1.0, 1.0]:
		VehicleMounts.slats(k, m, Vector3(s * 1.62, 1.255, -2.0), Vector3(s * 1.62, 1.255, 2.8), 0.85, 0.19, false, cam, null, cam)
		for z in [-2.0, -0.4, 1.2, 2.8]:
			VehicleFrames.beam(k, m, Vector3(s * 1.38, 1.6, z), Vector3(s * 1.62, 1.6, z), 0.04, 0.04, "gunmetal_w" if k.wreck else cam)
	VehicleMounts.slats(k, m, Vector3(-1.62, 1.255, 3.85), Vector3(1.62, 1.255, 3.85), 0.85, 0.19, false, cam, null, cam)
	for s in [-1.0, 1.0]:
		VehicleFrames.beam(k, m, Vector3(s * 1.6, 1.9, 3.25), Vector3(s * 1.6, 1.9, 3.85), 0.05, 0.05, "gunmetal_w" if k.wreck else cam)
	# the remote weapon station on the turret roof (it turns with the gun)
	_rcws(k, t, Vector3(-0.35, 0.8, 1.35), "hmg", cam, 0.9)
	k.turret = t


# --- tracked: the Merkava IV family ----------------------------------------------------

## A track belt seen side-on, as a loop of link plates round the drive
## sprocket (front: z, y, r), the road wheels' bottoms (z0..z1 at ground) and
## the idler (rear: z, y, r), back along the top run. x is the belt's centre,
## w its width.
static func _track_loop(k: VehicleModels, m: Node3D, x: float, w: float, front: Vector3, rear: Vector3, z0: float, z1: float, th := 0.08) -> void:
	var pts: Array[Vector2] = []
	for i in 5:
		var a := deg_to_rad(90.0 + i * 30.0)
		pts.append(Vector2(front.x + cos(a) * front.z, front.y + sin(a) * front.z))
	pts.append(Vector2(z0, th))
	pts.append(Vector2(z1, th))
	for i in 5:
		var a := deg_to_rad(-60.0 + i * 37.5)
		pts.append(Vector2(rear.x + cos(a) * rear.z, rear.y + sin(a) * rear.z))
	VehicleTracks.shoes(k, m, x, w, PackedVector2Array(pts), th, 0.20, true, true)


## A tracked vehicle's road wheel: rubber tyre, the dished disc standing
## proud of it, the hub with its bolt ring. Lighter than k._wheel (a tank has
## sixteen of these) but registered the same way, so it spins.
static func _road_wheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float) -> Node3D:
	return VehicleWheels.road(k, p, pos, r, w)


## The Merkava IV's running gear either side: the track belt, six road wheels,
## the drive sprocket forward (front engine), the idler aft.
static func _mk_running(k: VehicleModels, m: Node3D) -> void:
	var tx := 1.42
	for s in [-1.0, 1.0]:
		_track_loop(k, m, s * tx, 0.64, Vector3(-3.28, 0.86, 0.36), Vector3(3.3, 0.66, 0.34), -2.55, 2.55)
		for i in 6:
			_road_wheel(k, m, Vector3(s * tx, 0.45, -2.45 + i * 0.98), 0.38, 0.56)
		VehicleWheels.sprocket(k, m, Vector3(s * tx, 0.86, -3.28), 0.36, 0.5, "gunmetal_w", null, 14)
		_road_wheel(k, m, Vector3(s * tx, 0.66, 3.3), 0.3, 0.5)


## The Merkava IV hull: the long shallow glacis over the front engine with its
## sharp nose, the flat hull roof aft, the sponsons over the tracks with the
## big side skirts, the rear door into the troop compartment. era: reactive
## armour on the glacis and skirts. Returns nothing; the roof is at y 1.9.
static func _mk_hull(k: VehicleModels, team: int, cam: String, era: bool) -> void:
	var m := k.root
	_mk_running(k, m)
	# lower hull between the tracks: the lower nose plate, the belly, the tail
	k._add(m, VehicleModels.loft("nato_mk_low", [-1.08, -3.2, 1.08, -3.2, 1.08, 3.5, -1.08, 3.5], [-1.1, -3.82, 1.1, -3.82, 1.1, 3.78, -1.1, 3.78], 0.45, 1.21), cam, null, Vector3.ZERO)
	# the upper hull: the sponsons over the tracks, the glacis rising from the
	# nose to the front of the roof, the roof flat back to the rear
	var u0 := [-1.5, -3.82, 1.5, -3.82, 1.78, -3.42, 1.78, 3.78, -1.78, 3.78, -1.78, -3.42]
	var u1 := [-1.24, -0.92, 1.24, -0.92, 1.72, -0.52, 1.72, 3.72, -1.72, 3.72, -1.72, -0.52]
	var up := _rings([u0, 1.2, u1, 1.9])
	k._add(m, VehicleModels.loft("nato_mk_up", u0, u1, 1.2, 1.9, 0.05), cam, null, Vector3.ZERO)
	# the welds along the hull roof's chamfered edges (the back edge stays
	# under the bustle) and down the glacis's corners to the chamfer
	_weld(k, m, _seated(up, 0.05, [4, 5, 0, 1, 2, 3]), cam)
	var feet := _seated(up, 0.05, [0, 1, 5, 2], true)
	for s in [-1.0, 1.0]:
		var i := 1 if s > 0.0 else 0
		_weld(k, m, [Vector3(s * 1.5, 1.2, -3.82), feet[i]], cam)
		_weld(k, m, [Vector3(s * 1.78, 1.2, -3.42), feet[i + 2]], cam)
	# the nose: a heavy cast beak with tow eyes and the headlight clusters
	k._box(m, Vector3(2.9, 0.12, 0.16), Vector3(0, 1.18, -3.84), cam)
	for s in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.75, 0.98, -3.62))
		_lamp(k, m, Vector3(s * 1.25, 1.42, -3.08), 0.07)
		k._box(m, Vector3(0.36, 0.06, 0.24), Vector3(s * 1.25, 1.5, -3.06), "gunmetal_w", null, Vector3(-0.24, 0, 0))
	# glacis: the engine access panel (hinged along its top) and the big
	# intake grilles, the driver's hatch and periscopes at the top on the left
	var ga := Vector2(-3.82, 1.2)
	var gb := Vector2(-0.92, 1.9)
	_zy_grille(k, m, 0.55, 1.3, ga.lerp(gb, 0.3), ga.lerp(gb, 0.8), 0.04, cam, 7)
	_zy_hatch(k, m, -0.6, 0.9, ga.lerp(gb, 0.25), ga.lerp(gb, 0.6), 0.04, 0.02, cam)
	VehicleFittings.hatch(k, m, Vector3(-0.85, 1.92, -1.25), 0.28, cam, null, 1.0, 0.06)
	for i in 3:
		VehicleFittings.periscope(k, m, Vector3(-1.05 + i * 0.2, 1.88, -1.58), Vector3(0.15, 0.1, 0.07), Vector3(-0.24, (i - 1) * 0.3, 0))
	# the exhaust louvres on the left of the glacis, facing out of the side,
	# the recess behind them clear of the side leaning in
	VehicleFittings.grille(k, m, Vector3(-1.8, 1.48, -2.1), Vector2(1.0, 0.3), Vector3(0, -PI / 2, 0), "gunmetal_w", null, 4)
	_soot(k, m, Vector3(-1.756, 1.48, -1.6), Vector3.BACK, Vector3(0.0855, 0.9963, 0), Vector3(-0.9963, 0.0855, 0), 0.85, 0.26)
	# skirts: bolted heavy panels hanging off the sponsons, the front one raked
	for s in [-1.0, 1.0]:
		var sx: float = s * 1.82
		for i in 5:
			var z := -2.25 + i * 1.12
			VehicleEquipment.skirt(k, m, Vector3(sx, 0.93, z), Vector3(0.08, 0.62, 1.08), s, cam)
		VehicleEquipment.skirt_bow(k, m, Vector3(sx, 0.98, -3.22), Vector3(0.08, 0.55, 0.9), s, cam, null, Vector3(0.42, 0, 0))
		# the rail along the sponson edge the skirts hang from (painted with
		# the hull: bare, it read from above as a pale stripe down each side)
		# and a tow cable on it
		k._box(m, Vector3(0.1, 0.06, 6.9), Vector3(s * 1.8, 1.24, -0.02), cam)
		VehicleFittings.tow_cable(k, m, [Vector3(s * 1.79, 1.4, -2.9), Vector3(s * 1.76, 1.4, 1.6)], 0.028, 0.04)
		# tool boxes along the sponson (the hull roof aft stays clear: the
		# bustle and its chains sweep over it), the long one's latch lever
		VehicleEquipment.storage(k, m, Vector3(s * 1.82, 1.52, 1.0), Vector3(0.12, 0.3, 1.1), cam)
		VehicleEquipment.storage(k, m, Vector3(s * 1.82, 1.52, 2.3), Vector3(0.12, 0.3, 0.7), cam)
		VehicleDoors.lever(k, m, Vector3(s * 1.88, 1.55, 0.946), Vector3(s, 0, 0), Vector3.BACK, 0.134, 0.03, 0.015)
		_taillight(k, m, Vector3(s * 1.45, 1.58, 3.8))
		_shackle(k, m, Vector3(s * 0.85, 0.85, 3.6), 1.0)
		if era:
			# reactive armour bricks over the skirts and up the glacis, each
			# facing out of the side it covers
			for i in 6:
				for j in 2:
					VehicleMounts.era_brick(k, m, Vector3(s * 1.9, 0.72 + j * 0.33, -2.4 + i * 0.93), Vector3(0.86, 0.3, 0.12), Vector3(0, s * PI / 2, 0), cam)
	# cut branches tucked along the skirts' tops against the sponsons, under
	# the tow cables, clear of the tool boxes aft
	var runs := []
	for s in [-1.0, 1.0]:
		runs.append([Vector3(s * 1.84, 1.285, -1.2), Vector3(s * 1.86, 1.29, -2.75)])
		runs.append([Vector3(s * 1.84, 1.285, 0.35), Vector3(s * 1.86, 1.29, -0.85)])
	_branches(k, m, runs)
	if era:
		# the glacis bricks lie along its slope (as _zy lays a plate), turned
		# over so their covers face up and out of the plate
		var gd := (gb - ga) * 0.1
		var gn := Vector2(-gd.normalized().y, gd.normalized().x)
		var glacis := Vector3(atan2(gd.x, gd.y) + PI, 0, 0)
		for i in 4:
			for j in 5:
				var f := 0.06 + j * 0.115
				var x := (i - 1.5) * 0.72
				if absf(x + 0.6) < 0.4 and f > 0.7:
					continue
				var c := ga.lerp(gb, f + 0.05) + gn * 0.08
				VehicleMounts.era_brick(k, m, Vector3(x, c.y, c.x), Vector3(0.66, gd.length(), 0.12), glacis, cam)
	# the rear: the troop door with its lever handle and vision block, steps,
	# stowage baskets
	# (the door in the upright back plate, its sill where the tail plate
	# starts to slope away under it: run on down, its foot hung 15 cm off it)
	var sill := 0.75 if k.wreck else 1.08
	VehicleDoors.leaf(k, m, Vector3(1.0, 1.85 - sill, 0.08), Vector3(0.2, (1.85 + sill) * 0.5, 3.8), cam, null, Vector3.ZERO, 2)
	VehicleDoors.lever(k, m, Vector3(0.55, 1.415, 3.84), Vector3.BACK, Vector3.DOWN, 0.165, 0.05)
	VehicleGlazing.rectangle(k, m, Vector2(0.24, 0.14), Vector3(0.2, 1.62, 3.85), Vector3.ZERO, false, null, 0.04)
	for y in ([0.88, 1.7] if k.wreck else [1.19, 1.7]):
		VehicleDoors.hinge(k, m, Vector3(-0.32, y, 3.82), Vector3.BACK, Vector3.UP, 0.04, "gunmetal_w")
	# (the fold-down tread held level by a stay at each end, back under it to
	# the sloping tail plate: on its own it stuck out like a shelf)
	VehicleFrames.step(k, m, Vector3(0.2, 0.68, 3.9), Vector2(0.9, 0.3), Vector3.ZERO, "gunmetal_w", null)
	for x: float in ([] if k.wreck else [-0.2, 0.6]):
		_beam(k, m, Vector3(x, 0.665, 3.99), Vector3(x, 0.47, 3.51), 0.04, 0.012, "gunmetal_w")
	for s in [-1.0, 1.0]:
		VehicleMounts.basket(k, m, Vector3(s * 1.2, 1.32, 3.98), Vector3(0.62, .36, 0.36), "paint", STOW)
		k._bag(m, Vector3(0.5, 0.42, 0.3), Vector3(s * 1.2, 1.56, 3.98), "canvas", BAG)
		_jerry(k, m, Vector3(s * 1.62, 1.55, 3.92), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	var mx := 1.975 if era else 1.865
	_team_mark(k, m, team, Vector3(mx, 0.95, 1.2), Vector3(0.02, 0.24, 0.8))
	_team_mark(k, m, team, Vector3(-mx, 0.95, 1.2), Vector3(0.02, 0.24, 0.8))


## The Merkava IV turret: a long, sharply wedged nose round a small mantlet,
## the roof sloping down to it, the long bustle overhanging the hull with the
## ball-and-chain curtain hanging under it, sights, cupola, smoke dischargers,
## 120 mm with its thermal sleeve and fume extractor. up: reactive armour on
## the turret sides and a remote .50 on the roof.
static func _mk_turret(k: VehicleModels, team: int, cam: String, up: bool, seed := 0) -> void:
	var m := k.root
	var t := k._pivot(m, Vector3(0, 1.9, 0.75))
	k.turret = t
	# the turret's body: the wedge in front, the main body over the ring. Seen
	# from the side the real wedge is an arrowhead: its long upper plates slope
	# down to a sharp nose at the gun's height, and under the nose the chin is
	# cut back toward the ring (the gun depresses past it, and the nose throws
	# its shadow on the hull); behind the cheeks the sides run straight from
	# the ring to the roof, where the side modules lie
	var nose := 0.36
	var b0 := [-0.28, -2.08, 0.28, -2.08, 1.44, -0.68, 1.6, 1.2, -1.6, 1.2, -1.44, -0.68]
	var bn := [-0.3, -2.58, 0.3, -2.58, 1.4, -0.6, 1.519, 1.2, -1.519, 1.2, -1.4, -0.6]
	var b1 := [-0.26, -1.75, 0.26, -1.75, 1.3, -0.42, 1.42, 1.2, -1.42, 1.2, -1.3, -0.42]
	var shell := _rings([b0, 0.0, bn, nose, b1, 0.8])
	k._add(t, VehicleModels.solid(shell, "nato_mk_tur_nose", false, 0.05), cam, null, Vector3.ZERO)
	# the bustle, raised clear of the hull roof (the chains hang across the gap)
	var c0 := [-1.6, 1.15, 1.6, 1.15, 1.56, 2.55, 1.3, 2.85, -1.3, 2.85, -1.56, 2.55]
	var c1 := [-1.42, 1.15, 1.42, 1.15, 1.4, 2.5, 1.16, 2.76, -1.16, 2.76, -1.4, 2.5]
	k._add(t, VehicleModels.loft("nato_mk_bustle", c0, c1, 0.3, 0.8, 0.05), cam, null, Vector3.ZERO)
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.06, 0.4), 1.2, 1.25, 0.12, "gunmetal_w", null, 20)
	# The turret is welded plate under bolted modular armour: the weld along
	# the roof's chamfered edge, round the wedge and on round the bustle, the
	# roof plate over the wedge welded in ahead of the hatches. Where the
	# bustle's roof meets the turret's, their chamfers meet in a shallow vee
	# across the roof: the joint between the two castings.
	var body := _seated(shell, 0.05, [5, 0, 1, 2])
	var back := _seated(_rings([c0, 0.3, c1, 0.8]), 0.05, [1, 2, 3, 4, 5, 0])
	_weld(k, t, body + back + [body[0]], cam)
	# the weld along the nose's crease, where the upper plates meet the chin
	_weld(k, t, [Vector3(-1.4, nose, -0.6), Vector3(-0.3, nose, -2.58), Vector3(0.3, nose, -2.58), Vector3(1.4, nose, -0.6)], cam, 0.014)
	var wedge_top := [-0.18, -1.62, 0.18, -1.62, 1.1, -0.44, 1.12, -0.3, -1.12, -0.3, -1.1, -0.44]
	k._add(t, VehicleModels.loft("nato_mk_wedge_plate", wedge_top, wedge_top, 0.796, 0.82), cam, null, Vector3.ZERO)
	_weld(k, t, _loop(wedge_top, 0.8), cam, 0.012)
	if not up:
		# the wedge's flanks: the modules' joints across them and the rows
		# of heavy bolts that hold them (reactive armour covers them on the
		# urban package), each upper plate as the solid folds it
		for s in [-1.0, 1.0]:
			var q := [Vector3(0.3, nose, -2.58), Vector3(1.4, nose, -0.6), Vector3(0.26, 0.8, -1.75), Vector3(1.3, 0.8, -0.42)]
			if s < 0.0:
				q = [Vector3(-1.4, nose, -0.6), Vector3(-0.3, nose, -2.58), Vector3(-1.3, 0.8, -0.42), Vector3(-0.26, 0.8, -1.75)]
			var out := Vector3(s, 0.7, -0.5)
			# (f runs from the wedge's nose back along the flank)
			var u := func(f: float) -> float: return f if s > 0.0 else 1.0 - f
			_loft_seam(k, t, q, Vector2(u.call(0.06), 0.46), Vector2(u.call(0.98), 0.46))
			for f: float in [0.37, 0.69]:
				# (up to the foot of the roof's chamfer)
				_loft_seam(k, t, q, Vector2(u.call(f), 0.03), Vector2(u.call(f), 0.88))
			for row: float in [0.18, 0.56, 0.8]:
				for i in 9:
					var f := 0.1 + i * 0.105
					if absf(f - 0.37) < 0.04 or absf(f - 0.69) < 0.04:
						continue
					var uv := Vector2(u.call(f), row)
					VehicleBody.fastener(k, t, _on_loft(q[0], q[1], q[2], q[3], uv), _loft_normal(q[0], q[1], q[2], q[3], uv, out), 0.022)
	# ball-and-chain curtain along the bustle's rear and sides
	for i in 11:
		var x := -1.15 + i * 0.23
		_chain(k, t, Vector3(x, 0.3, 2.78 - absf(x) * 0.12))
	for s in [-1.0, 1.0]:
		for i in 3:
			_chain(k, t, Vector3(s * 1.5, 0.3, 1.5 + i * 0.4))
	# the gun: a small mantlet low in the wedge, the barrel's thermal sleeve
	# in sections, the fume extractor, the muzzle reference sensor
	var gy := 0.32
	VehicleMounts.mantlet(k, t, Vector3(0.48, 0.4, 0.5), Vector3(0, gy, -2.4), cam)
	k._cyl(t, 0.16, 0.16, 0.5, Vector3(0, gy, -2.8), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	VehicleFittings.barrel(k, t, Vector3(0, gy, -2.8), Vector3(0, gy, -5.99), 0.105, "paint", GUN)
	VehicleFittings.evacuator(k, t, Vector3(0, gy, -3.85), 0.17, 0.75, "paint", GUN)
	VehicleWeapons.muzzle_sensor(k, t, Vector3(0, gy + 0.14, -5.88), Vector3(0.07, 0.06, 0.1), Vector3(0, gy, -5.88), 0.105)
	k.gun_tip = k._tip(t, Vector3(0, gy, -6.0))
	VehicleWeapons.coax(k, t, Vector3(0.36, gy + 0.06, -2.55), 0.3, 0.025)
	k.mg_tip = k._tip(t, Vector3(0.36, gy + 0.06, -2.72))
	# the gunner's sight box forward left, the commander's big panoramic sight
	# forward right, the cupola behind it, the loader's hatch, the 60 mm mortar
	VehicleMounts.sight(k, t, Vector3(-0.68, 0.92, -0.55), Vector3(0.36, 0.3, 0.5), [Rect2(Vector2(0, 0.03), Vector2(0.28, 0.18))], cam)
	VehicleMounts.sight(k, t, Vector3(0.62, 1.18, -0.25), Vector3(0.38, 0.32, 0.38), [Rect2(Vector2(0, 0.02), Vector2(0.26, 0.16))], cam, null, Vector3(0.08, 0.1, 0.4))
	VehicleMounts.cupola(k, t, Vector3(0.62, 0.88, 0.62), 0.36, 0.38, 0.16, 5, -0.9, 0.45, cam)
	VehicleFittings.hatch(k, t, Vector3(0.62, 0.99, 0.62), 0.32, cam, null, 1.0, 0.06)
	VehicleFittings.hatch(k, t, Vector3(-0.6, 0.83, 0.75), 0.3, cam, null, 1.0, 0.06)
	k._box(t, Vector3(0.1, 0.06, 0.24), Vector3(-0.35, 0.86, 0.75), "gunmetal_w")
	k._cyl(t, 0.055, 0.055, 0.7, Vector3(-0.85, 1.0, 1.35), Vector3(PI / 2 - 0.5, 0, 0), "gunmetal_w", null, 8)
	k._box(t, Vector3(0.16, 0.16, 0.2), Vector3(-0.85, 0.86, 1.62), "gunmetal_w")
	# the loader's MG on its pintle, the wind sensor mast, antennas
	VehicleMounts.pintle(k, t, Vector3(-0.6, 0.8, 0.35), Vector3(-0.6, 1.02, 0.35), "gunmetal_w", null, Vector2(0.03, 0.04), Vector2(0.08, 0.13))
	VehicleWeapons.mmg(k, t, Vector3(-0.6, 1.02, 0.35), Vector3(-0.6, 1.03, -0.45), 1.0, 0.0)
	VehicleMounts.mast_segment(k, t, Vector3(0.0, 1.05, 2.2), 0.5, 0.02, "gunmetal_w", null)
	k._box(t, Vector3(0.12, 0.05, 0.05), Vector3(0.0, 1.3, 2.2), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_antenna(k, t, Vector3(s * 1.05, 0.8, 2.4), 1.5)
		# smoke dischargers on the wedge's flanks, side armour modules with
		# their channels, stowage baskets along the bustle
		_smoke(k, t, Vector3(s * 1.2, 0.62, -0.95), s, 5, s * -0.6)
		_xy_module(k, t, s, 0.3, 1.5, Vector2(1.6, 0.04), Vector2(1.42, 0.78), 0.08, cam, Vector2i(4, 2), 0.0)
		if not up and team >= 0:
			# the tactical number on the module, above its channel
			_stencil(k, t, _tac(seed, false), 0.22, Vector3(s * 1.551, 0.579, 0.3), Vector3(0, 0, -s), Vector3(s * 0.972, 0.236, 0))
		_xy(k, t, s, 0.3, 1.52, Vector2(1.52, 0.38), Vector2(1.51, 0.44), 0.06, 0.09, "gunmetal_w", null, false)
		VehicleMounts.basket(k, t, Vector3(s * 1.66, 0.425, 2.05), Vector3(0.3, .32, 1.3), "paint", STOW)
		k._bag(t, Vector3(0.24, 0.34, 1.2), Vector3(s * 1.64, 0.62, 2.05), "canvas", BAG if s < 0 else STOW)
	if up:
		# reactive armour bricks over the wedge's faces and the turret sides
		for s in [-1.0, 1.0]:
			_era(k, t, Vector3(s * 0.3, nose, -2.58), Vector3(s * 1.4, nose, -0.6), Vector3(s * 0.26, 0.8, -1.75), Vector3(s * 1.3, 0.8, -0.42), 4, 2, Vector3(s, 0.7, -0.5), cam, 0.12, 0.0, 0.78)
			for i in 3:
				for j in 2:
					VehicleMounts.era_brick(k, t, Vector3(s * 1.72, 0.25 + j * 0.34, -0.25 + i * 0.5), Vector3(0.46, 0.3, 0.12), Vector3(0, s * PI / 2, 0), cam)
		var gt := t
		_rcws(k, t, Vector3(-0.15, 0.8, 1.55), "hmg", cam, 0.9)
		k.turret = gt


## A hanging chain with a ball on its end (the Merkava's curtain).
static func _chain(k: VehicleModels, p: Node3D, top: Vector3) -> void:
	k._cyl(p, 0.012, 0.012, 0.2, top + Vector3(0, -0.1, 0), Vector3.ZERO, "gunmetal_w", null, 4, false)
	k._add(p, Res.sphere(0.045, 6), "gunmetal_w", null, top + Vector3(0, -0.22, 0), Vector3.ZERO, Vector3.ONE, false)


## M2A1 Slammer: the Merkava IV. up: the urban package (ERA, remote .50).
static func _slammer(k: VehicleModels, team: int, up: bool, seed := 0) -> void:
	var cam := _cam(team)
	_mk_hull(k, team, cam, up)
	_mk_turret(k, team, cam, up, seed)
	# (no air-recognition panel: on the bustle's roof it was the loudest
	# patch on the tank from the battle camera, and the hull has no deck it
	# lies flat on: the bustle and its chains sweep the roof aft, the
	# glacis carries the intakes and the driver's hatch)
	# the crew's kit on the bustle's roof, either side of the wind sensor's
	# mast and ahead of the antennas
	VmCore.roof_kit(k, k.turret, Vector3(-0.55, 0.8, 2.4), PI / 2, Vector2(0.4, 0.7), 0, BAG)
	VmCore.roof_kit(k, k.turret, Vector3(0.55, 0.8, 2.4), PI / 2, Vector2(0.4, 0.7), 1, BAG)


## M4 Scorcher: the Merkava IV hull under a tall boxy M109A7-style turret set
## aft, the long 155 mm on k.elev (pivot at the trunnion, raises to fire), a
## travel lock on the glacis, the commander's remote .50 on the roof.
static func _scorcher(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	_mk_hull(k, team, cam, false)
	# the barrel's travel lock folded down on the glacis: one box arm from its
	# hinge low on the plate up to the cradle
	var lock := Basis.from_euler(Vector3(-0.24, 0, 0))
	var lc := Vector3(0, 1.48, -2.6)
	VehicleMounts.travel_lock(k, m, lc - lock.z * 0.4, lc + lock.z * 0.38, lock.y, "gunmetal_w", null, Vector2.ZERO, Vector2(0.12, 0.1), Vector3(0.3, 0.1, 0.14))
	var t := k._pivot(m, Vector3(0, 1.9, 1.0))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.06, 0), 1.2, 1.25, 0.12, "gunmetal_w", null, 20)
	# the tall box: sloped front faces, vertical sides, the bustle
	var b0 := [-1.0, -1.85, 1.0, -1.85, 1.58, -1.3, 1.58, 2.55, -1.58, 2.55, -1.58, -1.3]
	var b1 := [-0.9, -1.55, 0.9, -1.55, 1.5, -1.05, 1.5, 2.45, -1.5, 2.45, -1.5, -1.05]
	var box := _rings([b0, 0.08, b0, 0.7, b1, 1.28])
	k._add(t, VehicleModels.solid(box, "nato_scorch_tur", false, 0.05), cam, null, Vector3.ZERO)
	# the welds along the roof's chamfered edge and along the crease where the
	# walls start leaning in, and the gun's number painted big on the walls
	_weld(k, t, _seated(box, 0.05), cam)
	_weld(k, t, _loop(b0, 0.7), cam)
	if team >= 0:
		for s in [-1.0, 1.0]:
			_stencil(k, t, _tac(seed, false), 0.26, Vector3(s * 1.541, 0.98, 2.0), Vector3(0, 0, -s), Vector3(s * 0.991, 0.137, 0))
	# side doors, roof hatches, the commander's cupola with a remote .50
	for s in [-1.0, 1.0]:
		# each door's face turned out of its own side, the grab bar near its front
		VehicleDoors.leaf(k, t, Vector3(0.04, 0.8, 0.7), Vector3(s * 1.6, 0.62, 0.9), cam, null, Vector3.ZERO, 0, s)
		VehicleDoors.pull(k, t, Vector3(s * 1.62, 0.62, 0.65), Vector3(s, 0, 0), Vector3.BACK, 0.14)
		_smoke(k, t, Vector3(s * 1.45, 0.88, -1.3), s, 4, s * -0.4)
		k._box(t, Vector3(0.3, 0.05, 1.2), Vector3(s * 1.74, 0.335, -0.15), cam)
		k._bag(t, Vector3(0.24, 0.32, 1.1), Vector3(s * 1.72, 0.52, -0.15), "canvas", BAG)
		_antenna(k, t, Vector3(s * 1.2, 1.28, 2.2), 1.4)
	VehicleFittings.panel_hatch(k, t, Vector3(-0.6, 1.31, 0.9), Vector3(0.7, 0.06, 0.6), cam)
	# the non-skid roof behind the hatches, where the crew work on top
	_walkway(k, t, Vector3(0, 1.28, 1.8), Vector2(1.7, 0.7))
	# the crew's kit on the roof's front corners, ahead of the hatch and the
	# remote gun's base (a self-propelled gun's crew stows on its roof what
	# the turret has no room for: bare, the big lid read as an empty box)
	VmCore.roof_kit(k, t, Vector3(-0.7, 1.28, -0.5), 0.0, Vector2(0.55, 0.6), 0, BAG)
	VmCore.roof_kit(k, t, Vector3(0.65, 1.28, -0.55), 0.0, Vector2(0.5, 0.55), 1, BAG)
	_bustle_basket(k, t, Vector3(0, 0.5, 2.8), Vector3(2.8, 0.42, 0.48), 2.55, cam)
	for i in 3:
		k._bag(t, Vector3(0.7, 0.36, 0.4), Vector3(-0.9 + i * 0.9, 0.7, 2.8), "canvas", BAG if i != 1 else STOW)
	_team_mark(k, t, team, Vector3(1.59, 0.42, 1.75), Vector3(0.02, 0.24, 0.6))
	_team_mark(k, t, team, Vector3(-1.59, 0.42, 1.75), Vector3(0.02, 0.24, 0.6))
	# the gun: trunnions at the turret front, the cradle, recoil cylinders, the
	# long tube with its fume extractor and the double-baffle muzzle brake
	var e := k._pivot(t, Vector3(0, 0.72, -1.4))
	k.elev = e
	# (the M109's big canvas cover gathered round the cradle's front)
	VehicleMounts.mantlet(k, e, Vector3(0.8, 0.62, 0.5), Vector3(0, 0, -0.22), cam, null, Vector3.ZERO, Vector2(0.22, 0.32))
	k._cyl(e, 0.22, 0.22, 0.8, Vector3(0, 0, -0.8), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	for s in [-1.0, 1.0]:
		VehicleFrames.ram(k, e, Vector3(s * 0.22, -0.12, -1.25), Vector3(s * 0.22, -0.12, -0.25), 0.07, "gunmetal_w", null, 0.35, Vector3.RIGHT, false, false)
	# the tube ends inside the brake's sleeve, so its windows stay open
	VehicleFittings.barrel(k, e, Vector3(0, 0, -1.0), Vector3(0, 0, -6.42), 0.11, "paint", GUN)
	VehicleFittings.evacuator(k, e, Vector3(0, 0, -3.9), 0.19, 0.9, "paint", GUN)
	VehicleWeapons.muzzle_brake(k, e, Vector3(0, 0, -6.33), Vector3(0, 0, -6.78), Vector2(0.36, 0.36), "double", "gunmetal_w", null, 0.11)
	k.gun_tip = k._tip(e, Vector3(0, 0, -6.8))
	var gt := t
	_rcws(k, t, Vector3(0.62, 1.28, 0.6), "hmg", cam, 0.85)
	k.turret = gt


## M5 Sandstorm: the Merkava IV hull with an M270-style launcher at the back:
## a traversing mount (k.turret) and the armoured box of two six-round pods
## on k.elev, pivoting at its rear so the front rises to fire.
static func _sandstorm(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	_mk_hull(k, team, cam, false)
	# the crew's cupola and periscopes forward, where a turret would be
	VehicleMounts.cupola(k, m, Vector3(0.7, 1.97, -0.5), 0.4, 0.42, 0.14, 0, 0.0, 0.0, cam)
	VehicleFittings.hatch(k, m, Vector3(0.7, 2.06, -0.5), 0.34, cam, null, 1.0, 0.06)
	VehicleFittings.hatch(k, m, Vector3(-0.55, 1.93, -0.3), 0.3, cam, null, 1.0, 0.06)
	VehicleMounts.sight(k, m, Vector3(0.2, 2.05, -0.6), Vector3(0.36, 0.3, 0.36), [Rect2(Vector2(0, 0.03), Vector2(0.24, 0.14))], cam)
	for s in [-1.0, 1.0]:
		_antenna(k, m, Vector3(s * 1.35, 1.9, -0.75), 1.5)
	# the launcher's travel rest on the roof, where the box's front end sits:
	# two posts up from the deck and the padded bar across them
	VehicleMounts.travel_lock(k, m, Vector3(0, 1.9, -0.1), Vector3(0, 2.2, -0.1), Vector3.UP, "gunmetal_w", null, Vector2(0.7, 0.7), Vector2(0.12, 0.14), Vector3(1.6, 0.08, 0.2))
	# the turntable and the launcher's base with its elevation rams
	var t := k._pivot(m, Vector3(0, 1.9, 2.2))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.07, 0), 1.15, 1.2, 0.14, "gunmetal_w", null, 20)
	k._box(t, Vector3(2.0, 0.2, 1.6), Vector3(0, 0.22, 0.6), cam)
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.16, 0.3, 0.5), Vector3(s * 1.0, 0.38, 1.25), cam)
		VehicleFrames.ram(k, t, Vector3(s * 0.7, 0.3425, 0.6495), Vector3(s * 0.7, 0.2975, -0.2495), 0.06, "steel")
	# the launcher box: hinged at its rear end, the pods' tubes facing forward
	var e := k._pivot(t, Vector3(0, 0.34, 1.3))
	k.elev = e
	var L := 3.8
	var H := 0.86
	# (an armoured box of welded plate: its edges ground off like the hull's)
	k._add(e, VehicleMounts._bevel(Vector3(2.2, H, L), 0.03), cam, null, Vector3(0, H * 0.5, -L * 0.5))
	k._box(e, Vector3(2.0, 0.3, 0.36), Vector3(0, 0.35, 0.18), "gunmetal_w")
	for s in [-1.0, 1.0]:
		# each pod's face standing proud of the box on its end plate: six tube
		# mouths in two rows behind the frangible covers
		VehicleWeapons.missile_face(k, e, Vector3(s * 0.54, H * 0.5, -L - 0.03), Vector2(1.0, H - 0.1), 2, 3, 0.12, "gunmetal_w", null, Vector3.ZERO, true, Vector2(0.31, 0.38), 0.04)
		# ribs down the sides, the boom-hoists along the top edges
		for i in 4:
			k._box(e, Vector3(0.04, H - 0.06, 0.08), Vector3(s * 1.11, H * 0.5, -0.45 - i * 0.98), "gunmetal_w", null, Vector3.ZERO, false)
		VehicleMounts.boom_box(k, e, Vector3(0.12, 0.12, L - 0.3), Vector3(s * 0.95, H + 0.06, -L * 0.5), cam)
		k._cyl(e, 0.07, 0.07, 0.14, Vector3(s * 0.95, H + 0.1, -L + 0.1), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
		k._box(e, Vector3(0.04, 0.2, 0.04), Vector3(s * 0.95, H - 0.04, -L + 0.06), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(e, Vector3(0.04, 0.03, L - 0.2), Vector3(0, H + 0.01, -L * 0.5), "gunmetal_w", null, Vector3.ZERO, false)
	# each pod's lid over its tubes: a raised cover plate with the lifting
	# straps' stiffeners across it, the biggest face the RTS camera sees
	for s in [-1.0, 1.0]:
		VehicleMounts.applique(k, e, Vector3(s * 0.5, H + 0.02, -L * 0.5), Vector3(0.78, L - 0.5, 0.04), Vector3(-PI / 2, 0, 0), cam, null, Vector2i(2, 6))
		for i in 3:
			k._box(e, Vector3(0.74, 0.035, 0.06), Vector3(s * 0.5, H + 0.055, -0.75 - i * 1.15), cam, null, Vector3.ZERO, false)
	k.gun_tip = k._tip(e, Vector3(0, H * 0.5, -L - 0.1))
	_team_mark(k, e, team, Vector3(1.105, 0.5, -2.0), Vector3(0.02, 0.26, 0.9))
	_team_mark(k, e, team, Vector3(-1.105, 0.5, -2.0), Vector3(0.02, 0.26, 0.9))


# --- tracked: the Namer family ---------------------------------------------------------

## The Namer hull: the Merkava IV's running gear, glacis and skirts, but the
## hull built up into a tall flat-sided box over the troop compartment, with
## the big hydraulic ramp at the back. Its roof is at y 2.32. cupola: the
## commander's cupola and the roof hatches; stow: the stowage rack at the back
## of the roof (leave them off where a turret or a crane sits).
static func _namer_hull(k: VehicleModels, team: int, cam: String, cupola := true, stow := true, seed := 0) -> void:
	var m := k.root
	_mk_running(k, m)
	var roof := 2.32
	k._add(m, VehicleModels.loft("nato_nm_low", [-1.08, -3.2, 1.08, -3.2, 1.08, 3.5, -1.08, 3.5], [-1.1, -3.82, 1.1, -3.82, 1.1, 3.78, -1.1, 3.78], 0.45, 1.21), cam, null, Vector3.ZERO)
	# the glacis over the engine, then the superstructure's sloped front face,
	# its sides straight up from the sponsons
	var u0 := [-1.5, -3.82, 1.5, -3.82, 1.78, -3.42, 1.78, 3.78, -1.78, 3.78, -1.78, -3.42]
	var u1 := [-1.32, -1.35, 1.32, -1.35, 1.76, -1.0, 1.76, 3.78, -1.76, 3.78, -1.76, -1.0]
	var u2 := [-1.12, -0.72, 1.12, -0.72, 1.66, -0.5, 1.66, 3.7, -1.66, 3.7, -1.66, -0.5]
	# (the roof's chamfer narrow enough that the side modules reach it)
	var up := _rings([u0, 1.2, u1, 1.8, u2, roof])
	k._add(m, VehicleModels.solid(up, "nato_nm_up", false, 0.04), cam, null, Vector3.ZERO)
	# the welds along the roof's chamfered edge, along the foot of the
	# superstructure's front and down the glacis's corners to the chamfer
	_weld(k, m, _seated(up, 0.04), cam)
	_weld(k, m, [Vector3(-1.76, 1.8, -1.0), Vector3(-1.32, 1.8, -1.35), Vector3(1.32, 1.8, -1.35), Vector3(1.76, 1.8, -1.0)], cam)
	var feet := _seated(up, 0.04, [0, 1, 5, 2], true)
	for s in [-1.0, 1.0]:
		var i := 1 if s > 0.0 else 0
		_weld(k, m, [Vector3(s * 1.5, 1.2, -3.82), Vector3(s * 1.32, 1.8, -1.35), feet[i]], cam)
		_weld(k, m, [Vector3(s * 1.78, 1.2, -3.42), Vector3(s * 1.76, 1.8, -1.0), feet[i + 2]], cam)
	# the nose with tow eyes and lights in guards
	k._box(m, Vector3(2.9, 0.12, 0.16), Vector3(0, 1.18, -3.84), cam)
	for s in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.75, 0.98, -3.62))
		_lamp(k, m, Vector3(s * 1.25, 1.42, -3.08), 0.07)
		k._box(m, Vector3(0.36, 0.06, 0.24), Vector3(s * 1.25, 1.5, -3.06), "gunmetal_w", null, Vector3(-0.24, 0, 0))
	# glacis: engine grilles, the engine access panel
	var ga := Vector2(-3.82, 1.2)
	var gb := Vector2(-1.35, 1.8)
	_zy_grille(k, m, 0.55, 1.3, ga.lerp(gb, 0.3), ga.lerp(gb, 0.85), 0.04, cam, 8)
	_zy_hatch(k, m, -0.65, 0.9, ga.lerp(gb, 0.3), ga.lerp(gb, 0.7), 0.04, 0.02, cam)
	# the exhaust louvres on the left side, as on the Merkava
	VehicleFittings.grille(k, m, Vector3(-1.8, 1.48, -2.1), Vector2(1.0, 0.3), Vector3(0, -PI / 2, 0), "gunmetal_w", null, 4)
	_soot(k, m, Vector3(-1.771, 1.48, -1.6), Vector3.BACK, Vector3(0.0333, 0.9994, 0), Vector3(-0.9994, 0.0333, 0), 0.85, 0.26)
	# the driver's hatch and periscopes on the superstructure front, left
	var fa := Vector2(-1.35, 1.8)
	var fb := Vector2(-0.72, roof)
	for i in 3:
		VehicleMaterials.glaze(k, _zy(k, m, -0.95 + i * 0.22, 0.16, fa.lerp(fb, 0.55), fa.lerp(fb, 0.8), 0.06, 0.03, "glass", null, false), "armor_glass", VehicleMounts.BLOCK)
	# the armoured brow welded over them, standing out of the plate so its
	# shadow falls across the prisms' heads and the blocks sit in the armour
	# (bare, they read from above as three black tiles stuck on the front),
	# and the cheeks between the blocks
	# (wrecks keep their old look)
	if not k.wreck:
		_zy(k, m, -0.73, 0.74, fa.lerp(fb, 0.82), fa.lerp(fb, 0.92), 0.13, 0.065, cam)
		for i in 4:
			_zy(k, m, -1.06 + i * 0.22, 0.04, fa.lerp(fb, 0.53), fa.lerp(fb, 0.82), 0.08, 0.04, cam, null, false)
	VehicleFittings.hatch(k, m, Vector3(-0.72, roof + 0.03, -0.3), 0.3, cam, null, 1.0, 0.06)
	# skirts and side armour: heavy panels low, the superstructure's armour
	# modules with a channel between them, stowage, tow cable
	for s in [-1.0, 1.0]:
		var sx: float = s * 1.82
		for i in 5:
			var z := -2.25 + i * 1.12
			VehicleEquipment.skirt(k, m, Vector3(sx, 0.93, z), Vector3(0.08, 0.62, 1.08), s, cam)
		VehicleEquipment.skirt_bow(k, m, Vector3(sx, 0.98, -3.22), Vector3(0.08, 0.55, 0.9), s, cam, null, Vector3(0.42, 0, 0))
		k._box(m, Vector3(0.1, 0.06, 6.9), Vector3(s * 1.8, 1.24, -0.02), cam)
		# The Namer's flanks are hung with heavy bolted modules in two rows,
		# the hull's band over the skirts and the superstructure's above it;
		# their thick chamfered edges and the gaps between them break up what
		# would otherwise be the biggest blank faces on the battlefield.
		for i in 5:
			var z := -0.1 + i * 0.84
			_xy_module(k, m, s, z, 0.8, Vector2(1.78, 1.24), Vector2(1.76, 1.8), 0.1, cam, Vector2i(3, 2))
			var face := _xy_module(k, m, s, z, 0.8, Vector2(1.76, 1.8), Vector2(1.66, 2.32), 0.1, cam, Vector2i(3, 2))
			if i == 1 and team >= 0:
				_stencil(k, m, _tac(seed, false), 0.22, face, Vector3(0, 0, -s), Vector3(s * 0.982, 0.189, 0))
		VehicleFittings.tow_cable(k, m, [Vector3(s * 1.8, 1.4, -2.9), Vector3(s * 1.8, 1.4, -0.6)], 0.028, 0.04)
		_taillight(k, m, Vector3(s * 1.4, 1.6, 3.8))
		_shackle(k, m, Vector3(s * 0.85, 0.85, 3.6), 1.0)
		_antenna(k, m, Vector3(s * 1.45, roof, 3.4), 1.5)
		# smoke dischargers on the front roof corners
		_smoke(k, m, Vector3(s * 1.45, roof + 0.05, -0.45), s, 4, s * -0.5)
	# cut branches tucked along the skirts' tops ahead of the armour modules,
	# and laid along the roof's edges beside the troop hatches where a
	# turret or crane leaves the roof clear
	var runs := []
	for s in [-1.0, 1.0]:
		runs.append([Vector3(s * 1.84, 1.285, -1.0), Vector3(s * 1.86, 1.29, -2.65)])
		if stow:
			runs.append([Vector3(s * 1.42, roof + 0.013, 2.35), Vector3(s * 1.44, roof + 0.013, 0.75)])
	_branches(k, m, runs)
	# roof: the commander's cupola with periscopes, hatches over the troop
	# compartment, stowage at the back
	if cupola:
		VehicleMounts.cupola(k, m, Vector3(0.62, roof + 0.08, 0.15), 0.36, 0.38, 0.16, 5, -1.0, 0.5, cam)
		VehicleFittings.hatch(k, m, Vector3(0.62, roof + 0.19, 0.15), 0.32, cam, null, 1.0, 0.06)
		for s in [-1.0, 1.0]:
			VehicleFittings.panel_hatch(k, m, Vector3(s * 0.55, roof + 0.03, 1.55), Vector3(0.7, 0.06, 0.8), cam)
			# a non-skid walkway down each side of the roof, outboard of the
			# troop hatches
			_walkway(k, m, Vector3(s * 1.22, roof, 1.45), Vector2(0.42, 1.9))
	if stow:
		# the stowage basket standing on the roof's back
		_bustle_basket(k, m, Vector3(0, roof + 0.015, 3.0), Vector3(2.8, 0.3, 0.9), 0.0, cam)
		for i in 3:
			k._bag(m, Vector3(0.7, 0.32, 0.6), Vector3(-0.85 + i * 0.85, roof + 0.2, 3.0), "canvas", BAG if i != 1 else STOW, Vector3(0, (i - 1) * 0.08, 0))
	# the rear: the big ramp with its door, hinges, steps
	VehicleDoors.leaf(k, m, Vector3(2.0, 1.55, 0.1), Vector3(0, 1.35, 3.8), cam)
	VehicleDoors.leaf(k, m, Vector3(0.62, 1.1, 0.04), Vector3(0.45, 1.4, 3.86), cam)
	VehicleDoors.lever(k, m, Vector3(0.2, 1.4, 3.88), Vector3.BACK, Vector3.DOWN, 0.12, 0.1)
	VehicleGlazing.rectangle(k, m, Vector2(0.22, 0.14), Vector3(0.45, 1.75, 3.89), Vector3.ZERO, false, null, 0.04)
	for s in [-1.0, 1.0]:
		VehicleDoors.hinge(k, m, Vector3(s * 0.7, 0.62, 3.78), Vector3.BACK, Vector3.RIGHT, 0.06, "gunmetal_w")
		_tube(k, m, Vector3(s * 0.95, 1.95, 3.6), Vector3(s * 0.95, 1.2, 3.84), 0.05, "steel")
		_jerry(k, m, Vector3(s * 1.4, 1.2, 3.92), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
		# stowage bins on the back's corners above the jerrycans, their lids'
		# latches facing out the back (the face leans in, so they stand into it)
		VehicleEquipment.storage(k, m, Vector3(s * 1.39, 1.98, 3.86), Vector3(0.6, 0.44, 0.27), cam, null, Vector3(0, PI, 0))
	# (on the middle module of the hull's band)
	_team_mark(k, m, team, Vector3(1.886, 1.52, 1.58), Vector3(0.02, 0.24, 0.7))
	_team_mark(k, m, team, Vector3(-1.886, 1.52, 1.58), Vector3(0.02, 0.24, 0.7))


## IFV-6c Panther: the Namer with a remote station carrying a 12.7 mm and a
## 40 mm grenade machine gun.
static func _panther(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	_namer_hull(k, team, cam, true, true, seed)
	_rcws(k, k.root, Vector3(-0.5, 2.32, -0.05), "both", cam, 1.15)
	# an air-recognition panel folded on the roof between the remote station
	# and the troop hatches, clear of the cupola
	VehicleEquipment.recognition_panel(k, k.root, Vector3(-0.2, 2.322, 0.8), Vector3.ZERO, true)
	# the crew's kit across the roof between the troop hatches and the
	# stowage basket, inboard of the walkways
	VmCore.roof_kit(k, k.root, Vector3(0, 2.32, 2.25), PI / 2, Vector2(0.4, 1.3), 0, BAG)


## CRV-6e Bobcat: the Namer as an engineering / recovery vehicle: a dozer
## blade on push arms across the nose, the recovery crane's boom folded along
## the roof, its winch, tools, and a remote .50.
static func _bobcat(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	_namer_hull(k, team, cam, true, false, seed)
	# the dozer blade, raised for travel: a mouldboard curved hollow toward
	# the soil (the cutting edge forward at its foot, the face sweeping back
	# and up and the top lip curling forward again, so it rolls the earth
	# ahead of it), plate joined facet to facet with its ends' edges ground
	# off; its bolted cutting edge, the push arms and the lifting rams
	var bz := -4.32
	var by := 0.28
	var face := [Vector2(-0.12, 0.0), Vector2(-0.02, 0.2), Vector2(0.06, 0.42), Vector2(0.09, 0.64), Vector2(0.06, 0.86), Vector2(-0.04, 1.0), Vector2(-0.12, 1.07)]
	for i in face.size() - 1:
		var a: Vector2 = face[i]
		var b: Vector2 = face[i + 1]
		var d := (b - a).normalized()
		var back := Vector2(d.y, -d.x) * 0.06
		if back.x < 0.0:
			back = -back
		var plate := [bz + a.x, by + a.y, bz + b.x, by + b.y, bz + b.x + back.x, by + b.y + back.y, bz + a.x + back.x, by + a.y + back.y]
		k._add(m, VehicleModels.extrude_x("nato_dozer_mb%d" % i, plate, -1.95, 1.95, 0.015), cam, null, Vector3.ZERO)
	k._box(m, Vector3(3.92, 0.1, 0.05), Vector3(0, by + 0.055, bz - 0.11), "steel", null, Vector3(0.46, 0, 0))
	for s in [-1.0, 1.0]:
		# the end plates across the curve's whole depth, the stiffening ribs
		# welded up its back
		k._box(m, Vector3(0.06, 1.0, 0.4), Vector3(s * 1.94, by + 0.52, bz + 0.08), cam)
		for x in [0.6, 1.5]:
			k._box(m, Vector3(0.06, 0.5, 0.36), Vector3(s * x, by + 0.55, bz + 0.28), "gunmetal_w")
		_beam(k, m, Vector3(s * 1.5, by + 0.35, bz + 0.25), Vector3(s * 1.55, 0.75, -2.7), 0.18, 0.16, cam)
		VehicleFrames.ram(k, m, Vector3(s * 1.1, 1.3, -3.2), Vector3(s * 1.1, by + 0.85, bz + 0.25), 0.06)
	# the crane: its slewing base on the roof's back right, the boom folded
	# forward along the right side on its luffing ram, the inner boom run out
	# onto a rest, the hook stowed at the boom's head
	var cb := Vector3(1.0, 2.32, 2.75)
	var bt := Vector3(1.0, 2.58, -0.9)
	VehicleMounts.crane(k, m, cb, cb + Vector3(0, 0.3, -0.1), bt, Vector2(0.28, 0.26), cam, null, Vector3(0.42, 0.46, 0.14), Vector3.ZERO, Vector3(0.6, 0.3, 0.7), [cb + Vector3(0.18, 0.18, -0.4), cb + Vector3(0.18, 0.3, -1.6), 0.06], bt + Vector3(0, 0, -0.75), bt + Vector3(0, 0, -0.55), Vector3(0.1, 0.2, 0.1))
	# the inner boom telescoped out of the main one: inside its box on its
	# axis, only the run-out end showing, painted as cranes' booms are
	VehicleMounts.boom(k, m, cb + Vector3(0, 0.29, -1.2), bt + Vector3(0, 0.0, -0.5), 0.2, 0.18, "paint", GUN)
	k._box(m, Vector3(0.14, 0.14, 0.14), Vector3(1.0, 2.38, -1.0), "gunmetal_w")
	# the main winch drum at the back of the roof, tow bars and tools: the
	# greasy steel rope wound on the drum between its two dark flanges (a
	# drum cased whole in dark metal read from above as a black can)
	for fx: float in [-0.93, -0.07]:
		k._cyl(m, 0.2, 0.2, 0.04, Vector3(fx, 2.55, 2.75), Vector3(0, 0, PI / 2), "gunmetal_w", null, 12)
	# (the rope dark and greasy as a recovery winch's is: bare polished steel,
	# the drum read from above as a white can; a wreck keeps its old drum)
	if k.wreck:
		k._cyl(m, 0.17, 0.17, 0.84, Vector3(-0.5, 2.55, 2.75), Vector3(0, 0, PI / 2), "steel", Color(0.27, 0.26, 0.23), 12)
	else:
		k._cyl(m, 0.17, 0.17, 0.84, Vector3(-0.5, 2.55, 2.75), Vector3(0, 0, PI / 2), "track", Color(0.2, 0.2, 0.18), 12)
	for x in [-0.98, -0.02]:
		k._box(m, Vector3(0.06, 0.32, 0.36), Vector3(x, 2.48, 2.75), "gunmetal_w")
	# the pinch bar and the pick lying on the roof in their clips: a 3 cm
	# steel bar 1.8 m long, and an ash helve with its iron head across it
	# (a wreck keeps its old pair: a 10 cm beam and a plank, which read from
	# the battle camera as girders on the roof)
	if k.wreck:
		k._box(m, Vector3(0.1, 0.1, 2.0), Vector3(-1.5, 2.37, 0.9), "gunmetal_w")
		k._box(m, Vector3(0.08, 0.08, 1.4), Vector3(-1.38, 2.37, 1.0), "wood")
	else:
		k._cyl(m, 0.016, 0.016, 1.8, Vector3(-1.5, 2.338, 0.9), Vector3(PI / 2, 0, 0), "metal_dark", null, 6, false)
		k._cyl(m, 0.019, 0.023, 0.9, Vector3(-1.34, 2.343, 1.15), Vector3(PI / 2, 0, 0), "wood", null, 6, false)
		k._box(m, Vector3(0.44, 0.045, 0.05), Vector3(-1.34, 2.345, 1.62), "metal_dark", null, Vector3.ZERO, false)
		for z: float in [0.35, 1.45]:
			k._box(m, Vector3(0.26, 0.035, 0.04), Vector3(-1.42, 2.338, z), "gunmetal_w", null, Vector3.ZERO, false)
	_rcws(k, m, Vector3(-0.5, 2.32, -0.05), "hmg", cam)


## IFV-6a Cheetah: the Namer under a Marksman-style twin 35 mm turret: a large
## box with a gun on each side, the search radar on its mast at the back, the
## tracking radar in front, two four-round missile boxes.
static func _cheetah(k: VehicleModels, team: int, seed := 0) -> void:
	var cam := _cam(team)
	var m := k.root
	_namer_hull(k, team, cam, false, false, seed)
	var t := k._pivot(m, Vector3(0, 2.32, 0.95))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.05, 0), 1.15, 1.2, 0.1, "gunmetal_w", null, 20)
	var b0 := [-0.95, -1.4, 0.95, -1.4, 1.22, -1.0, 1.22, 1.5, 1.0, 1.75, -1.0, 1.75, -1.22, 1.5, -1.22, -1.0]
	var b1 := [-0.82, -1.15, 0.82, -1.15, 1.1, -0.85, 1.1, 1.4, 0.9, 1.62, -0.9, 1.62, -1.1, 1.4, -1.1, -0.85]
	k._add(t, VehicleModels.loft("nato_ch_tur", b0, b1, 0.08, 0.92, 0.05), cam, null, Vector3.ZERO)
	_weld(k, t, _seated(_rings([b0, 0.08, b1, 0.92]), 0.05), cam)
	# a 35 mm on each flank: the trunnion housing, the cradle, the long barrel
	# with its muzzle velocity radar ring and brake
	var gy := 0.52
	for s in [-1.0, 1.0]:
		var gx: float = s * 1.42
		VehicleMounts.mantlet(k, t, Vector3(0.24, 0.42, 0.9), Vector3(s * 1.3, gy, -0.4), cam)
		# the gun's armoured housing, painted with the turret, its edges broken
		k._add(t, VehicleMounts._bevel(Vector3(0.24, 0.3, 1.1), 0.025), cam, null, Vector3(gx, gy, -0.75))
		VehicleWeapons.autocannon(k, t, Vector3(gx, gy, -1.25), Vector3(gx, gy, -4.2), Vector2(0.07, 0.6), Vector2(0.04, 0.045), Vector2(0.06, 0.2))
		k._cyl(t, 0.075, 0.075, 0.16, Vector3(gx, gy, -3.1), Vector3(PI / 2, 0, 0), "metal_dark", null, 10)
		# the ammunition feed chute and the missile box above the gun
		k._box(t, Vector3(0.18, 0.2, 0.4), Vector3(gx, gy - 0.24, -0.4), "gunmetal_w")
		# four rounds, mounted by its inboard face on the bracket
		VehicleWeapons.missile_box(k, t, Vector3(s * 1.36, 1.02, 0.55), Vector3(0.5, 0.48, 1.4), 2, 2, 0.09, cam, null, Vector3.ZERO, false, Vector3(-s, 0, 0), Vector2(0.22, 0.22))
		k._box(t, Vector3(0.08, 0.3, 0.3), Vector3(s * 1.14, 0.88, 0.55), "gunmetal_w")
		_smoke(k, t, Vector3(s * 1.12, 0.78, -1.1), s, 4, s * -0.5)
	k.mg_tip = k._tip(t, Vector3(1.42, gy, -4.22))
	# the tracking radar (a dish in a drum) on the front of the roof, the
	# optics beside it
	k._cyl(t, 0.36, 0.36, 0.3, Vector3(0, 1.08, -0.65), Vector3(PI / 2, 0, 0), cam, null, 16)
	# (the dish behind its radome: a fibreglass cover in pale grey, not the
	# black hole a bare dark disc read as; a wreck keeps the dark disc)
	k._cyl(t, 0.3, 0.3, 0.04, Vector3(0, 1.08, -0.82), Vector3(PI / 2, 0, 0), "plain_dark" if k.wreck else "plastic", null if k.wreck else VmCsat.RADOME, 16, false)
	VehicleMounts.sight(k, t, Vector3(-0.6, 1.05, -0.7), Vector3(0.3, 0.26, 0.3), [Rect2(Vector2(0, 0.02), Vector2(0.22, 0.14))], cam)
	# hatches, the search radar on its folding mast at the back
	VehicleFittings.hatch(k, t, Vector3(0.5, 0.95, 0.4), 0.28, cam, null, 1.0, 0.06)
	VehicleFittings.hatch(k, t, Vector3(-0.5, 0.95, 0.4), 0.28, cam, null, 1.0, 0.06)
	k._box(t, Vector3(0.5, 0.3, 0.5), Vector3(0, 1.07, 1.3), cam)
	k._cyl(t, 0.08, 0.1, 0.26, Vector3(0, 1.33, 1.3), Vector3.ZERO, "gunmetal_w", null, 10)
	var rp := k._pivot(t, Vector3(0, 1.45, 1.3))
	k._add(rp, Res.sphere(1.0, 16), cam, null, Vector3(0, 0.22, 0), Vector3(-0.3, 0, 0), Vector3(0.7, 0.26, 0.07))
	k._add(rp, Res.sphere(1.0, 16), "gunmetal_w", null, Vector3(0, 0.21, 0.03), Vector3(-0.3, 0, 0), Vector3(0.66, 0.23, 0.06))
	k._box(rp, Vector3(0.22, 0.14, 0.26), Vector3(0, 0.02, 0.1), "gunmetal_w")
	k._box(rp, Vector3(0.06, 0.3, 0.06), Vector3(0, 0.12, 0.08), "gunmetal_w")
	_antenna(k, t, Vector3(-0.8, 0.92, 1.4), 1.2)
	_team_mark(k, t, team, Vector3(1.165, 0.45, 0.5), Vector3(0.02, 0.24, 0.8))
	_team_mark(k, t, team, Vector3(-1.165, 0.45, 0.5), Vector3(0.02, 0.24, 0.8))


# --- HEMTT: Oshkosh M977 family ----------------------------------------------------------

## A ring in the XY plane (a cross-section) at z.
static func _ring_z(pts: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, pts.size(), 2):
		r.append(Vector3(pts[i], pts[i + 1], z))
	return r


## A cross-section (x, y pairs, convex) extruded along z from z0 to z1;
## `bevel` chamfers the edges round both end faces (as VehicleModels.solid
## does a roof's), so a pressed or cut end doesn't meet its sides at a
## dead-sharp CG edge. Without it the mesh is what it always was.
static func _extrude_z(key: String, sec: Array, z0: float, z1: float, bevel := 0.0) -> ArrayMesh:
	return VehicleModels.solid([_ring_z(sec, z0), _ring_z(sec, z1)], key, false, bevel, bevel)


## The HEMTT's cab and chassis: the wide flat-fronted cab over the front
## axles with its short blunt nose and big grille, four axles (two steering
## pairs forward, the tandem aft) on huge tyres, the exhaust stack and air
## cleaner behind the cab, fuel tank and boxes along the frame rails. The
## bodies start at z -2.45 with their deck at y 1.36.
static func _hemtt_chassis(k: VehicleModels, team: int, paint: Color, detailed := false) -> void:
	var m := k.root
	var cab := "camo_tank" if team != 1 else "camo_tank_rebel"
	var wr := 0.63
	var axles := [-3.8, -2.3, 2.15, 3.65]
	for s in [-1.0, 1.0]:
		for z in axles:
			if detailed:
				_hemtt_wheel(k, Vector3(s * 0.98, wr, z))
			else:
				k._wheel(m, Vector3(s * 0.98, wr, z), wr, 0.46)
			k._box(m, Vector3(0.36, 0.14, 0.2), Vector3(s * 0.6, wr, z), "gunmetal_w")
	# frame rails, the axles' beams and springs
	VehicleRunningGear.frame(k, m, Vector3(0, 1.0, 0.1), 0.45, 9.9, Vector2(0.14, 0.3), axles)
	for z: float in axles:
		VehicleRunningGear.axle(k, m, Vector3(0, wr, z), 1.5, 0.08, 0.45, 0.9)
	# the cab: a slightly raked windscreen, flat sides, the nose out in front
	var cb := [-1.2, -4.5, 1.2, -4.5, 1.2, -2.85, -1.2, -2.85]
	if detailed:
		# Open upper cab: the windows must reveal seats, dash and the far side,
		# not a solid painted box immediately behind transparent glass.
		k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(cb), 1.36), VehicleModels.ring_y(VehicleModels._v2(cb), 1.95)], "nato_hemtt_open_cab"), cab, null, Vector3.ZERO)
		VehicleCab.upper(k, Vector2(1.20, 1.14), Vector2(1.95, 2.86), Vector2(-4.50, -4.34), -2.91, "paint", paint)
	else:
		k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(cb), 1.36), VehicleModels.ring_y(VehicleModels._v2(cb), 1.95), VehicleModels.ring_y(VehicleModels._v2([-1.14, -4.34, 1.14, -4.34, 1.14, -2.88, -1.14, -2.88]), 2.86)], "nato_hemtt_cab"), cab, null, Vector3.ZERO)
	var nose := [-5.12, 0.96, -4.45, 0.96, -4.45, 1.98, -4.88, 1.92, -5.12, 1.74]
	k._add(m, VehicleModels.extrude_x("nato_hemtt_nose", nose, -1.1, 1.1, 0.03), cab, null, Vector3.ZERO)
	# the big grille, the bumper with the headlights in its ends, tow eyes,
	# the towing pintle
	VehicleFittings.grille(k, m, Vector3(0, 1.4, -5.19), Vector2(1.86, 0.66), Vector3(0, PI, 0), cab, null, 12)
	k._box(m, Vector3(2.0, 0.06, 0.08), Vector3(0, 1.76, -5.13), cab)
	VehicleMounts.bumper(k, m, Vector3(2.44, 0.32, 0.24), Vector3(0, 0.9, -5.14), "paint" if detailed else "paint", paint.darkened(0.15))
	for s in [-1.0, 1.0]:
		# each lamp housing: the headlight outboard, the amber indicator inboard
		VehicleFittings.lamp_unit(k, m, Vector3(s * 0.96, 0.94, -5.27), Vector3(0.3, 0.2, 0.06), -1.0, [Rect2(Vector2(s * 0.06, 0), Vector2(0.12, 0.12))], Rect2(Vector2(s * -0.08, 0), Vector2(0.08, 0.08)))
		_shackle(k, m, Vector3(s * 0.55, 0.8, -5.2))
		VehicleFittings.signal_lens(k, m, Vector3(s * 1.1, 1.82, -5.0), Vector2(0.12, 0.06), Color(0.55, 0.36, 0.08), -1.0)
	VehicleMounts.hitch(k, m, Vector3(0, 0.84, -5.3), Vector3(0.3, 0.22, 0.16), Vector3(0, PI, 0))
	# the sun visor over the windscreen
	k._box(m, Vector3(2.24, 0.04, 0.32), Vector3(0, 2.84, -4.44), cab, null, Vector3(0.12, 0, 0))
	# windscreen panes, door windows, door seams, handles, mirrors, steps
	var wa := Vector2(-4.5, 1.95)
	var wb := Vector2(-4.34, 2.86)
	for s in [-1.0, 1.0]:
		if detailed:
			VehicleFittings.wiper(k, m, Vector3(s * 0.57, 2.10, -4.54), Vector3(s * 0.44, 2.49, -4.48), Vector3(s * 0.52, 0.12, 0.02), Vector3(0, 0.16, -1), 0.53)
		else:
			_zy(k, m, s * 0.56, 0.98, wa.lerp(wb, 0.12), wa.lerp(wb, 0.82), 0.04, 0.0, "glass", null, false)
			VehicleGlazing.rectangle(k, m, Vector2(0.85, 0.6), Vector3(s * 1.2, 2.26, -3.72), (Basis.from_euler(Vector3(0, 0, s * 0.03)) * Basis(Vector3.UP, PI / 2)).get_euler(), false, null, 0.04)
		VehicleBody.seam(k, m, [Vector3(s * 1.205, 1.92, -4.275), Vector3(s * 1.205, 1.92, -3.025)])
		for dz in [-4.3, -3.05]:
			VehicleBody.seam(k, m, [Vector3(s * 1.205, 1.4, dz), Vector3(s * 1.205, 2.7, dz)])
		VehicleFittings.mirror(k, m, Vector3(s * 1.52, 2.28, -4.52), Vector2(0.24, 0.42), -s * 0.3, [Vector3(s * 1.2, 2.5, -4.35), Vector3(s * 1.2, 2.0, -4.35)])
		# the ladder steps up to the door
		VehicleFrames.ladder(k, m, Vector3(s * 1.12, 0.55, -3.05), 0.42, 0.36, 2, 0.3, Vector3(0, -s * PI / 2, 0))
		# the long black fender over both front axles, raked at its front
		VehicleBody.fender(k, m, Vector3(s * 0.98, 1.34, -3.08), Vector3(0.54, 0.06, 2.55), s, "rubber")
		VehicleBody.fender(k, m, Vector3(s * 0.98, 1.24, -4.55), Vector3(0.54, 0.06, 0.5), s, "rubber", null, Vector3(0.45, 0, 0))
		VehicleFittings.mudflap(k, m, Vector3(s * 0.98, 1.12, -1.8), Vector2(0.54, 0.45))
	# the roof hatch, marker lights, antenna
	# (on the detailed cab it sits on VehicleCab.upper's roof, 2.905 m up)
	VehicleFittings.panel_hatch(k, m, Vector3(0.35, 2.935 if detailed else 2.87, -3.5), Vector3(0.7, 0.06, 0.7), cab)
	for i in 3:
		# facing two quarter turns from the marker's +Z: forward
		VehicleFittings.marker(k, m, Vector3(-0.15 + i * 0.15, 2.86, -4.32), Vector3(0.05, 0.05, 0.08), 2.0, Color(0.55, 0.36, 0.08))
	_antenna(k, m, Vector3(-1.05, 2.84, -2.95), 1.4)
	# behind the cab: the engine's air cleaner (left) strapped to the cab's
	# back, the exhaust stack (right), the spare wheel between
	VehicleFittings.air_cleaner(k, m, Vector3(-0.85, 2.0, -2.68), 0.24, 1.3, cab, null, Vector2(0.2, 0.1), Vector3.FORWARD)
	VehicleFittings.exhaust(k, m, Vector3(0.92, 1.20, -2.7), Vector3.UP, 1.98, 0.08)
	# (its face against the cab's back plain, as nobody sees it)
	VehicleWheels.spare(k, m, Vector3(0.0, 2.0, -2.65), 0.6, 0.42, Vector3(PI / 2, 0, 0), "gunmetal_w", null, "offroad", Vector3(0.0, 2.0, -2.91))
	VehicleWheels.carrier(k, m, Vector3(0.0, 2.0, -2.65), 0.6, 0.42, Vector3(PI / 2, 0, 0), "hub", Vector3(0.0, 2.0, -2.91))
	# the round fuel tank on the left frame rail, the battery box on the
	# right, air tanks
	VehicleRunningGear.fuel_tank(k, m, Vector3(-0.95, 1.0, -1.0), Vector3(0.6, 0.6, 1.1), -1.0, "paint", paint.darkened(0.2))
	# the battery box: a lidded steel bin, its lid's catches facing outboard
	# where the mechanic on the step reaches them (a plain block read as a
	# painted crate under the cab)
	VehicleEquipment.storage(k, m, Vector3(0.95, 1.0, -1.1), Vector3(0.7, 0.5, 0.5), cab, null, Vector3(0, -PI / 2, 0))
	for s in [-1.0, 1.0]:
		VehicleEquipment.vessel(k, m, Vector3(s * 0.75, 0.72, 0.4), Vector3(0.24, 0.24, 0.8), [-0.22, 0.22], "gunmetal_w", null, false)
		_tube(k, m, Vector3(s * 1.15, 0.7, -1.7), Vector3(s * 1.15, 0.7, 1.5), 0.04, "gunmetal_w", null, 6)
	_team_mark(k, m, team, Vector3(1.205, 1.6, -3.7), Vector3(0.02, 0.24, 0.6))
	_team_mark(k, m, team, Vector3(-1.205, 1.6, -3.7), Vector3(0.02, 0.24, 0.6))


## Pressed cab panels shared by every mission body. `salt` draws the roof's
## recognition panel apart for each body.
static func _hemtt_cab_detail(k: VehicleModels, paint: Color, salt := 0) -> void:
	var m := k.root
	var dirt := Color(0.24, 0.21, 0.16)
	# The cab's roof is VehicleCab.upper's one pressing, its edge rolled over
	# into the sides and its top crowned, so the sun slides across it. (A flat
	# cap laid over it here hid that roll under a slab with a sloped rim.)
	# A camouflaging crew (VehicleCloth.camouflage) keeps its net bundled on
	# the cab roof, the one flat place a man on the step can reach: on the
	# crown beside the hatch, clear of the antenna's base and the markers.
	var net := Vector3(-0.55, 2.905, -3.58)
	var rng := VehicleCargo.kit(k, m, net, 17)
	if rng != null and VehicleCloth.camouflage(k) > 0.0 and rng.randf() < 0.5:
		VehicleCloth.roof_net(k, m, net, Vector3(1.0, 0.2, 0.7), Vector3.ZERO, rng)
	else:
		# or, in its place, an air-recognition panel folded beside the hatch,
		# drawn apart for each body: the six HEMTTs share this cab, and a
		# column of them in one kit wore one panel each, alike
		VehicleEquipment.recognition_panel(k, m, Vector3(-0.5, 2.905, -3.62), Vector3.ZERO, true, 0.2, salt)
	# the crew's own kit along the roof's right edge beside the hatch, where
	# the man in it can reach down for it (a cab roof with one hatch on it
	# read as a bare plate from the battle camera)
	VmCore.roof_kit(k, m, Vector3(0.88, 2.9, -3.55), 0.0, Vector2(0.3, 0.9), 3, paint.lerp(BAG, 0.6))
	k._box(m, Vector3(1.88, 0.035, 0.30), Vector3(0, 1.98, -4.67), "paint", paint.darkened(0.15), Vector3(0.12, 0, 0))
	for s in [-1.0, 1.0]:
		# Door recess, raised inner pressing, hinges and a grab handle.
		VehicleDoors.rectangle(k, m, Vector3(s * 1.25, 1.65, -3.71), Vector2(1.02, 0.51), Vector3(0, s * PI / 2, 0), "paint", paint)
		# Worn step lips and lower door sill, where boots contact the paint.
		k._box(m, Vector3(0.04, 0.05, 1.13), Vector3(s * 1.25, 1.39, -3.70), "paint", dirt)
		for y in [0.57, 0.93]:
			k._box(m, Vector3(0.27, 0.015, 0.06), Vector3(s * 1.13, y, -3.24), "steel", Color(0.35, 0.34, 0.30))


static func _hemtt_wheel(k: VehicleModels, pos: Vector3) -> void:
	VehicleWheels.pneumatic(k, k.root, pos, 0.63, 0.46, "paint", Color(0.18, 0.20, 0.16))


## The flat deck on its frame under the box and tank bodies, and the rear end
## behind it (_hemtt_tail); the drop-side bodies lay their deck with its sides.
static func _hemtt_deck(k: VehicleModels, paint: Color, z0 := -2.4, z1 := 5.05) -> void:
	VehicleCargo.flatbed(k, k.root, z0, z1, 2.44, 1.38, "paint", paint.darkened(0.1), 0.0, 0, 0.0, 0.0, 0.16, "", null, Vector3(1.1, 0.18, 0.2), 0.06)
	_hemtt_tail(k, paint, z1)


## The rear end behind a deck ending at z1: fenders over the tandem, tail
## lights, mud flaps, the rear bumper and its hitch.
static func _hemtt_tail(k: VehicleModels, paint: Color, z1: float) -> void:
	var m := k.root
	for s in [-1.0, 1.0]:
		VehicleBody.fender(k, m, Vector3(s * 0.98, 1.36 - 0.06, 2.9), Vector3(0.5, 0.05, 3.1), s, "rubber")
		VehicleFittings.mudflap(k, m, Vector3(s * 0.98, 0.8, 4.4), Vector2(0.46, 0.5))
		_taillight(k, m, Vector3(s * 0.95, 1.12, z1 + 0.04))
		_shackle(k, m, Vector3(s * 0.5, 0.95, z1 + 0.02), 1.0)
	VehicleMounts.bumper(k, m, Vector3(2.3, 0.16, 0.16), Vector3(0, 0.9, z1 + 0.06), "paint", paint.darkened(0.15))
	VehicleMounts.hitch(k, m, Vector3(0, 0.95, z1 + 0.1), Vector3(0.3, 0.3, 0.3))


## HEMTT variants by body: "troop" (benches under a canvas tilt), "cargo"
## (crates and pallets), "ammo" (ammunition pallets and a loading crane),
## "repair" (a workshop box), "medical" (an ambulance box with red crosses),
## "fuel" (a tanker).
static func _hemtt(k: VehicleModels, team: int, body: String, seed := 0) -> void:
	var m := k.root
	var paint := Color(0.3, 0.32, 0.23) if team != 1 else Color(0.46, 0.42, 0.32)
	var cam := "camo_tank" if team != 1 else "camo_tank_rebel"
	_hemtt_chassis(k, team, paint, true)
	_hemtt_cab_detail(k, paint, 0 if body == "troop" else hash(body) & 0xffff)
	if team >= 0:
		# the bumper code on the front bumper either side of the pintle, and on
		# the back one's (but where the ambulance's wide step covers it)
		var code := VehicleMarkings.bumper_code(seed, VehicleMarkings.US_ARMOR + VehicleMarkings.US_INFANTRY)
		VehicleMarkings.bumper(k, m, code, 0.08, 0.33, 0.97, -5.26, Vector3.FORWARD, 0.28)
		if body != "medical":
			VehicleMarkings.bumper(k, m, code, 0.07, 0.32, 0.9, 5.19, Vector3.BACK, 0.26)
	match body:
		"troop", "cargo", "ammo":
			# the deck on its frame with its drop sides, six stake posts a side,
			# the tailgate and the tall headboard, then the rear end
			var sh := 0.62 if body != "ammo" else 0.36
			# (under the troop body's tilt the deck is in the cover's shade, the
			# sky's light shut out as well as the sun's, which the renderer
			# doesn't know: lit like an open deck it read bright through the
			# rolled back, so it's taken down as the tilt's liner is, toward the
			# brown of the dirt boots carry in: darkened alone, the paint went
			# the slate of the sky it reflects. A wreck's stays as it was.)
			VehicleCargo.flatbed(k, m, -2.4, 5.05, 2.44, 1.38, cam, null, sh, 6, 1.1, 0.0, 0.16, "paint", paint.darkened(0.42).lerp(Color(0.2, 0.18, 0.1), 0.3) if body == "troop" and not k.wreck else paint.darkened(0.1), Vector3(1.1, 0.18, 0.2), 0.06)
			_hemtt_tail(k, paint, 5.05)
			if body == "troop":
				# the canvas tilt over its bows, the back rolled up over the benches
				var tilt := VehicleCargo.tilt_colour(k, m, paint.lightened(0.08))
				# (the cover's sag between its bows shows them: no bands over
				# them.) The back flap is rolled up over the benches, or on
				# some trucks in a column let down and laced shut.
				var flap := VehicleCargo.kit(k, m, Vector3(0, 2.7, 4.95), 18)
				var shut := flap != null and not k.wreck and flap.randf() < 0.3
				VehicleCloth.canopy(k, m, [Vector2(-1.22, 1.98), Vector2(-1.22, 2.55), Vector2(-0.98, 2.86), Vector2(0.98, 2.86), Vector2(1.22, 2.55), Vector2(1.22, 1.98)], [-2.35, -2.2, -0.78, 0.64, 2.06, 3.48, 4.9, 4.95], tilt, shut)
				if k.wreck:
					# (a wreck's tilt keeps its old fitted panels, and so the
					# bands over its bows)
					for i in 6:
						k._add(m, _extrude_z("nato_hemtt_bow", [-1.24, 1.98, 1.24, 1.98, 1.24, 2.56, 0.99, 2.88, -0.99, 2.88, -1.24, 2.56], -0.04, 0.04, 0.02), "canvas_white", paint.darkened(0.12), Vector3(0, 0, -2.2 + i * 1.42))
				# (past the rolled flap the tilt's own dim inside shows, and the
				# benches under it; a wreck keeps its dark board)
				if k.wreck:
					k._box(m, Vector3(2.3, 0.82, 0.02), Vector3(0, 2.38, 4.965 if not shut else 4.9), "plain_dark", null, Vector3.ZERO, false)
				if shut:
					for x: float in [-0.75, 0.0, 0.75]:
						k._box(m, Vector3(0.025, 0.84, 0.02), Vector3(x, 2.42, 4.958), "canvas_white", tilt.darkened(0.25), Vector3.ZERO, false)
				else:
					VehicleCloth.roll(k, m, Vector3(0, 2.7, 5.0), 0.12, 2.4, Vector3(0, 0, PI / 2), tilt.darkened(0.04), "canvas_white")
				for s in [-1.0, 1.0]:
					# the troop benches facing in, on folding legs, hinged to the sides
					VehicleCab.bench(k, m, Vector3(s * 0.88, 1.85, 1.3), Vector3(0.38, 0.08, 6.6), Vector3(-s, 0, 0), Vector3(0.06, 0.3, 0.06), "wood_dark", null, 0.43, true)
					# (the fittings on the bows inside, clear of the curtain where it
					# sags in between them)
					for i in 8:
						if k.wreck:
							k._box(m, Vector3(0.05, 0.03, 0.03), Vector3(s * 1.2, 2.2 + (i % 2) * 0.25, -1.8 + i * 0.85), "gunmetal_w", null, Vector3.ZERO, false)
						else:
							k._box(m, Vector3(0.03, 0.03, 0.03), Vector3(s * 1.17, 2.2 + (i % 2) * 0.25, -1.8 + i * 0.85), "gunmetal_w", null, Vector3.ZERO, false)
				# the boarding step under the tailgate
				VehicleFrames.step(k, m, Vector3(0, 0.8, 5.2), Vector2(0.6, 0.4), Vector3.ZERO, "gunmetal_w")
			elif body == "cargo":
				# palletised crates and boxes lashed down, a tarp over one load
				var loads := [[-0.55, -1.7, 1.0, 0.9, 1.0, 0], [0.55, -1.7, 1.0, 0.7, 1.0, 1], [-0.55, -0.55, 1.0, 1.0, 1.1, 2], [0.55, -0.55, 1.0, 0.8, 1.0, 0],
						[-0.55, 0.65, 1.0, 0.75, 1.1, 1], [0.55, 0.65, 1.0, 1.05, 1.1, 3], [-0.55, 1.95, 1.0, 0.9, 1.2, 0], [0.55, 1.95, 1.0, 0.6, 1.2, 2],
						[-0.55, 3.3, 1.0, 1.0, 1.2, 3], [0.55, 3.3, 1.0, 0.8, 1.2, 1], [0.0, 4.45, 2.0, 0.55, 0.8, 2]]
				for l in loads:
					if int(l[5]) == 2:
						VehicleCloth.load_cover(k, Vector3(l[0], 1.38, l[1]), Vector3(l[2], l[3], l[4]))
					else:
						_cargo(k, m, Vector3(l[0], 1.38, l[1]), Vector3(l[2], l[3], l[4]), int(l[5]))
			else:
				# ammunition: pallets of boxes, four to a pallet and strapped down
				# (plain pallet boards: slatted ones under ten stacks cost too many
				# vertices), then the knuckle-boom crane at the back, folded
				# forward over the load
				for i in 5:
					for s in [-1.0, 1.0]:
						var pz := -1.7 + i * 1.25
						# Pallets forklifted on by hand never sit square: each a
						# degree or two off the bed's line (as far as the gaps
						# between them allow), its stack turned with it, so the
						# bed isn't one block cast ten times.
						var py := 0.0
						var prng := VehicleCargo.kit(k, m, Vector3(s * 0.56, 1.44, pz), 73)
						if prng != null and not k.wreck:
							py = prng.randf_range(-0.035, 0.035)
						k._box(m, Vector3(1.05, 0.12, 1.1), Vector3(s * 0.56, 1.44, pz), "wood", null, Vector3(0, py, 0))
						var hh := 0.62 if (i + int(s > 0.0)) % 3 != 0 else 0.32
						VehicleCargo.crate_stack(k, m, Vector3(s * 0.56, 1.5, pz), Vector3(1.05, hh, 1.1), Vector3i(2, 1, 2), "paint", STOW, 0.0, [0.0], 0.15, Color(0.28, 0.26, 0.2), py)
				# the crane on its slewing ring and column with the main boom's
				# luffing ram; the knuckle boom folded back under it, the hook at
				# its end
				var cb := Vector3(0.75, 1.38, 4.55)
				VehicleMounts.crane(k, m, cb, cb + Vector3(0, 1.1, 0), cb + Vector3(0, 1.32, -2.6), Vector2(0.24, 0.26), cam, null, Vector3(0.3, 0.34, 0.3), Vector3.ZERO, Vector3(0.36, 0.9, 0.36), [cb + Vector3(0, 0.6, -0.1), cb + Vector3(0, 1.15, -1.2), 0.07], cb + Vector3(0, 0.82, -1.0), cb + Vector3(0, 1.0, -1.0), Vector3(0.1, 0.25, 0.1))
				VehicleMounts.boom(k, m, cb + Vector3(0, 1.32, -2.6), cb + Vector3(0, 1.0, -1.0), 0.18, 0.2, "paint", paint)
				for s in [-1.0, 1.0]:
					k._box(m, Vector3(0.5, 0.14, 0.14), Vector3(s * 1.0, 1.14, 4.7), "gunmetal_w")
					k._box(m, Vector3(0.14, 0.42, 0.14), Vector3(s * 1.25, 0.95, 4.7), "gunmetal_w")
					k._box(m, Vector3(0.22, 0.05, 0.22), Vector3(s * 1.25, 0.72, 4.7), "gunmetal_w")
		"repair", "medical":
			_hemtt_deck(k, paint)
			# the shelter: a tall square box body with plain sides, its rails
			# and markers; the workshop has a ladder up the back and roof vents
			var repair := body == "repair"
			# (a shelter's bonded panels meet on extruded corner rails: its
			# upright corners and the roof's edge rounded off, not cut square)
			VehicleCargo.shelter(k, m, -2.32, 4.98, 2.44, 1.39, 3.01, cam, null, Rect2(), 0, 0, 0.04, 0.06, -0.6 if repair else 0.0, 2 if repair else 0)
			_shelter_roof(k, m, -2.32, 4.98, 2.44, 3.01, 0.06)
			if repair:
				for s in [-1.0, 1.0]:
					# roll-up shutters; the tool lockers hang under the deck
					# between the axles, behind the fuel tank and battery box
					# and clear of the tandem's wheels
					for j in 3:
						VehicleCargo.roller_shutter(k, m, Vector3(s * 1.22, 2.2, -1.2 + j * 2.2), Vector2(1.9, 1.3), Vector3(s, 0, 0), "paint", paint.darkened(0.08))
					k._box(m, Vector3(0.28, 0.4, 1.8), Vector3(s * 1.09, 1.04, 0.52), "gunmetal_w")
				# the light mast, AC unit, the rear door
				_roof_unit(k, m, Vector3(0, 3.18, -1.6), Vector3(1.0, 0.34, 0.7), paint)
				k._cyl(m, 0.06, 0.06, 1.6, Vector3(-0.9, 3.08, 3.8), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
				k._box(m, Vector3(0.5, 0.14, 0.14), Vector3(-0.9, 3.08, 3.0), "gunmetal_w")
				k._box(m, Vector3(0.14, 0.14, 0.1), Vector3(-0.9, 3.06, 4.6), "gunmetal_w")
				VehicleCargo.body_door(k, m, Vector3(0.45, 2.15, 4.98), Vector2(0.9, 1.4), Vector3.BACK, 1, "paint", paint.darkened(0.08))
			else:
				# windows, the rear doors with a step, roof vents, red crosses
				for s in [-1.0, 1.0]:
					for z in [0.0, 2.2]:
						VehicleGlazing.rectangle(k, m, Vector2(0.6, 0.4), Vector3(s * 1.225, 2.45, z), (Basis.from_euler(Vector3.ZERO) * Basis(Vector3.UP, PI / 2)).get_euler(), false, null, 0.03)
					_cross(k, m, Vector3(s * 1.23, 2.2, 3.6), Vector3(0, s * PI / 2, 0), 1.0)
					_cross(k, m, Vector3(s * 1.23, 2.2, -1.25), Vector3(0, s * PI / 2, 0), 1.0)
				_cross(k, m, Vector3(0, 3.02, 1.3), Vector3(-PI / 2, 0, 0), 1.3)
				for s in [-1.0, 1.0]:
					VehicleDoors.leaf(k, m, Vector3(1.15, 1.45, 0.04), Vector3(s * 0.6, 2.15, 5.0), "paint", paint.darkened(0.05))
				_cross(k, m, Vector3(0.6, 2.4, 5.03), Vector3.ZERO, 0.6)
				VehicleFrames.step(k, m, Vector3(0, 0.95, 5.3), Vector2(1.6, 0.5), Vector3.ZERO, "gunmetal_w")
				# (the fold-down platform held level by a stay at each end, back
				# to the bumper's foot: on its own it stuck out like a shelf)
				for s in [-1.0, 1.0]:
					_beam(k, m, Vector3(s * 0.72, 0.935, 5.5), Vector3(s * 0.72, 0.83, 5.13), 0.03, 0.012, "gunmetal_w")
				_roof_unit(k, m, Vector3(0.6, 3.15, -0.8), Vector3(0.5, 0.28, 0.5), paint)
				_roof_unit(k, m, Vector3(-0.3, 3.15, 3.6), Vector3(0.8, 0.28, 0.7), paint)
		"fuel":
			_hemtt_deck(k, paint, -2.4, 5.05)
			# the tank: an oval barrel on cradles with its end caps, the walkway
			# along its crown between folding rails over the three manholes, the
			# pump cabinet and hose reels at the back
			VehicleEquipment.vessel(k, m, Vector3(0, 2.08, 0.75), Vector3(2.24, 1.36, 5.9), [-2.15, 0.0, 2.15], cam)
			VehicleEquipment.tanker_top(k, m, Vector3(0, 2.08, 0.75), Vector3(2.24, 1.36, 5.9), cam, null, Vector3(0.6, 5.6, 0.0), [-1.2, 0.75, 2.7], Vector2(0.3, 0.44), 0.24)
			VehicleEquipment.pump_cabinet(k, m, Vector3(0, 2.0, 4.42), Vector3(2.4, 1.3, 1.2), Vector3.BACK, cam)
			for s in [-1.0, 1.0]:
				VehicleFrames.hose_reel(k, m, Vector3(s * 1.05, 1.95, 4.4), 0.3, 0.32)
			# the hazard placard
			if not k.burnt:
				k._box(m, Vector3(0.36, 0.26, 0.02), Vector3(0, 1.62, 5.06), "paint", Color(0.62, 0.48, 0.12), Vector3.ZERO, false)


## The roof of a shelter body (VehicleCargo.shelter) from z0 to z1, `width`
## across, at `roof_y`, its edge rounded off by `rc`: a shelter is bonded
## sandwich panels, so its roof shows their joints across it, and a lifting
## eye bolted down at each corner for the crane that swaps it between trucks.
## From above it's the biggest face on the truck; those are what keep it from
## reading as one blank slab.
static func _shelter_roof(k: VehicleModels, p: Node3D, z0: float, z1: float, width: float, roof_y: float, rc: float) -> void:
	var hw := width * 0.5 - rc
	var panels := maxi(2, roundi((z1 - z0) / 1.25))
	for i in range(1, panels):
		var z := lerpf(z0, z1, float(i) / panels)
		VehicleBody.seam(k, p, [Vector3(-hw, roof_y, z), Vector3(hw, roof_y, z)], 0.007)
	for s in [-1.0, 1.0]:
		for z: float in [z0 + rc + 0.12, z1 - rc - 0.12]:
			var eye := Vector3(s * (hw - 0.1), roof_y, z)
			k._box(p, Vector3(0.14, 0.03, 0.14), eye + Vector3(0, 0.015, 0), "gunmetal_w")
			k._add(p, Res.torus(0.032, 0.056), "gunmetal_w", null, eye + Vector3(0, 0.07, 0), Vector3(PI / 2, 0, 0), Vector3.ONE, false)


## A shelter's air conditioner on its roof: a painted box with its edges
## broken, the condenser fan's grille on its top.
static func _roof_unit(k: VehicleModels, p: Node3D, center: Vector3, size: Vector3, paint: Color) -> void:
	k._add(p, VehicleMounts._bevel(size, 0.025), "paint", paint, center)
	VehicleFittings.grille(k, p, center + Vector3(0, size.y * 0.5 + 0.02, 0), Vector2(size.x * 0.75, size.z * 0.7), Vector3(-PI / 2, 0, 0), "paint", paint.darkened(0.25), 5)


## One crate / pallet load on the cargo bed: kind 0 wooden crate, 1 olive
## boxes on a pallet, 2 a tarp-covered load, 3 drums.
static func _cargo(k: VehicleModels, m: Node3D, base: Vector3, s: Vector3, kind: int) -> void:
	match kind:
		0:
			# the crate, two straps wrapped over it and down its sides to the bed
			VehicleCargo.crate_stack(k, m, base, Vector3(s.x - 0.04, s.y, s.z - 0.02), Vector3i.ONE, "wood", null, 0.0, [-s.z * 0.27, s.z * 0.27], 0.12, Color(0.17, 0.18, 0.13))
		1:
			VehicleCargo.crate_stack(k, m, base, Vector3(s.x - 0.06, s.y, s.z - 0.06), Vector3i(2, 1, 2), "paint", STOW, 0.12, [-s.z * 0.25, s.z * 0.25])
		2:
			VehicleCargo.pallet(k, m, base, Vector2(s.x - 0.06, s.z - 0.06), 0.12)
			k._box(m, Vector3(s.x - 0.1, s.y - 0.12, s.z - 0.1), base + Vector3(0, 0.12 + (s.y - 0.12) * 0.5, 0), "canvas", BAG)
			VehicleCargo.restraints(k, m, base, Vector3(s.x - 0.06, s.y, s.z - 0.06), [-s.z * 0.25, s.z * 0.25])
		_:
			k._box(m, Vector3(s.x - 0.06, 0.1, s.z - 0.06), base + Vector3(0, 0.05, 0), "wood")
			for i in 2:
				for j in 2:
					VehicleEquipment.drum(k, m, base + Vector3((i - 0.5) * 0.46, 0.1 + (s.y - 0.1) * 0.5, (j - 0.5) * 0.48), 0.21, s.y - 0.1, Vector3.UP, "paint", Color(0.28, 0.32, 0.22) if (i + j) % 2 == 0 else Color(0.36, 0.3, 0.2), Vector3(0.1, 0, 0.05))


## A red cross on a white board screwed to the body, facing along the
## board's local +z (VehicleMarkings.cross; gone on a wreck).
static func _cross(k: VehicleModels, p: Node3D, pos: Vector3, rot: Vector3, size: float) -> void:
	VehicleMarkings.cross(k, p, pos, Vector2(size, size), rot, VehicleMarkings.CROSS_GROUND, VehicleMarkings.CROSS_RED, 0.7, 0.22, 0.02, "plain", true)


# --- Stomper: NREC Crusher UGCV ----------------------------------------------------------

## Crusher: a low angular robot on six big wheels on long swing arms, an
## open space-frame over its armoured tub, the sensor mast forward, and a
## remote weapon station with a 12.7 mm and a 40 mm GMG on top.
static func _stomper(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.57
	for s in [-1.0, 1.0]:
		for z in [-1.85, 0.0, 1.85]:
			k._wheel(m, Vector3(s * 1.06, wr, z), wr, 0.48)
			# the swing arm from the hull to the hub, its motor housing
			_beam(k, m, Vector3(s * 0.62, 0.86, z + 0.45 * signf(z + 0.01)), Vector3(s * 0.8, wr, z), 0.14, 0.2, "gunmetal_w")
			k._cyl(m, 0.2, 0.2, 0.16, Vector3(s * 0.74, wr, z), Vector3(0, 0, PI / 2), "metal_dark", null, 12)
	# the armoured tub: a wedge nose, the flanks leaning in
	var b0 := [-0.42, -2.2, 0.42, -2.2, 0.62, -1.85, 0.62, 2.15, 0.42, 2.4, -0.42, 2.4, -0.62, 2.15, -0.62, -1.85]
	var b1 := [-0.5, -2.5, 0.5, -2.5, 0.72, -2.15, 0.72, 2.3, 0.5, 2.55, -0.5, 2.55, -0.72, 2.3, -0.72, -2.15]
	var b2 := [-0.4, -1.75, 0.4, -1.75, 0.58, -1.5, 0.58, 2.1, 0.42, 2.32, -0.42, 2.32, -0.58, 2.1, -0.58, -1.5]
	var tub := _rings([b0, 0.42, b1, 0.9, b2, 1.32])
	k._add(m, VehicleModels.solid(tub, "nato_crusher_tub", false, 0.03), cam, null, Vector3.ZERO)
	_weld(k, m, _seated(tub, 0.03), cam)
	_weld(k, m, _loop(b1, 0.9), cam)
	# side pods over the wheels (batteries / engine), angular, low
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("nato_crusher_pod", [-0.14, -1.3, 0.14, -1.3, 0.14, 1.4, -0.14, 1.4], [-0.1, -1.1, 0.1, -1.1, 0.1, 1.25, -0.1, 1.25], 0.0, 0.34), cam, null, Vector3(s * 0.7, 0.98, 0))
	# the space frame over the tub: rails, hoops and diagonals
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.62, 1.3, -1.8), Vector3(s * 0.55, 1.62, -0.9), 0.04, "gunmetal_w")
		_tube(k, m, Vector3(s * 0.55, 1.62, -0.9), Vector3(s * 0.55, 1.62, 1.6), 0.04, "gunmetal_w")
		_tube(k, m, Vector3(s * 0.55, 1.62, 1.6), Vector3(s * 0.6, 1.3, 2.25), 0.04, "gunmetal_w")
		for z in [-0.9, 0.35, 1.6]:
			_tube(k, m, Vector3(s * 0.58, 1.3, z), Vector3(s * 0.55, 1.62, z), 0.035, "gunmetal_w")
		_tube(k, m, Vector3(s * 0.58, 1.3, 0.35), Vector3(s * 0.55, 1.62, 1.6), 0.03, "gunmetal_w")
	for z in [-0.9, 1.6]:
		_tube(k, m, Vector3(-0.55, 1.62, z), Vector3(0.55, 1.62, z), 0.04, "gunmetal_w")
	# the sensor mast at the nose, raked forward over it: stereo cameras,
	# laser scanners, a GPS dome
	VehicleMounts.mast_segment(k, m, Vector3(0, 1.575, -1.675), 0.55, 0.05, "gunmetal_w", null, Vector3(0, 0, -0.15))
	k._box(m, Vector3(0.7, 0.16, 0.2), Vector3(0, 1.9, -1.78), "gunmetal_w")
	if not k.burnt:
		for x in [-0.25, 0.25]:
			k._cyl(m, 0.05, 0.05, 0.04, Vector3(x, 1.9, -1.9), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.08, 0.08, 0.12, Vector3(s * 0.45, 1.36, -2.0), Vector3.ZERO, "plain_dark", null, 10)
		k._cyl(m, 0.08, 0.08, 0.12, Vector3(s * 0.45, 1.36, 2.15), Vector3.ZERO, "plain_dark", null, 10)
		_lamp(k, m, Vector3(s * 0.4, 0.95, -2.5), 0.05, -1.0, false)
		_taillight(k, m, Vector3(s * 0.38, 0.95, 2.56))
	VehicleMounts.radome(k, m, Vector3(0, 2.02, -1.75), Vector3(0.2, 0.12, 0.2), "plain", Color(0.7, 0.7, 0.66))
	_antenna(k, m, Vector3(-0.45, 1.62, 1.9), 1.2)
	_antenna(k, m, Vector3(0.45, 1.62, 1.9), 0.8)
	k._box(m, Vector3(0.8, 0.12, 0.5), Vector3(0, 1.38, 1.95), "gunmetal_w")
	_team_mark(k, m, team, Vector3(0.66, 1.1, 1.0), Vector3(0.02, 0.18, 0.6))
	_team_mark(k, m, team, Vector3(-0.66, 1.1, 1.0), Vector3(0.02, 0.18, 0.6))
	# the RCWS on the frame
	k._box(m, Vector3(1.0, 0.06, 0.9), Vector3(0, 1.64, 0.35), "gunmetal_w")
	_rcws(k, m, Vector3(0, 1.67, 0.35), "both", cam, 0.9)
