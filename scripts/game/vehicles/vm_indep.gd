class_name VmIndep
extends RefCounted
## Procedural models: AAF and LDF ground vehicles (Strider, Gorgon, Mora, Kuma, Nyx, Zamak, Zamak MRL).
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["strider", "strider_hmg", "strider_gmg", "gorgon", "mora", "kuma", "nyx_ac", "nyx_at", "nyx_aa", "nyx_recon",
	"zamak", "zamak_cargo", "zamak_ammo", "zamak_repair", "zamak_medical", "zamak_fuel", "zamak_mrl"]

## AAF digital green: camo_tank tinted greener.
const AAF := Color(0.36, 0.39, 0.28)
const Z90 := Vector3(0, 0, PI / 2)  # a cylinder lying along X (axles, wheels)
const X90 := Vector3(PI / 2, 0, 0)  # a cylinder lying along Z (barrels, pointing fore and aft)


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"strider":
			_strider(k, team, 0)
		"strider_hmg":
			_strider(k, team, 1)
		"strider_gmg":
			_strider(k, team, 2)
		"gorgon":
			_gorgon(k, team, seed)
		"mora":
			_mora(k, team, seed)
		"kuma":
			_kuma(k, team, seed)
		"nyx_ac", "nyx_at", "nyx_aa", "nyx_recon":
			_nyx(k, team, key.substr(4), seed)
		"zamak", "zamak_cargo", "zamak_ammo", "zamak_repair", "zamak_medical", "zamak_fuel", "zamak_mrl":
			_zamak(k, team, key, seed)
		_:
			return false
	return true


# --- shared helpers ---------------------------------------------------------------

## The paint: AAF green; vehicles the Rebels also field (`either`) go khaki for them.
## (AAF green is camo_tank brightened and greened; a tint above 1 is lost
## when the parts are merged and the tint baked into 8-bit vertex colours,
## so it is reached by scaling camo_tank_rebel's lighter palette down to the
## AAF colour instead: the same four camo tones, nothing clamped.)
static func _paint(team: int, either := false) -> Array:
	if either and team == 1:
		return ["camo_tank_rebel", null]
	return ["camo_tank_rebel", AAF]


## A chamfered rectangle outline (x0..x1, z0..z1; z0 the front), for lofts.
static func _oct(x0: float, x1: float, z0: float, z1: float, c: float) -> Array:
	return [x0 + c, z0, x1 - c, z0, x1, z0 + c, x1, z1 - c, x1 - c, z1, x0 + c, z1, x0, z1 - c, x0, z0 + c]


static func _ring(pts: Array, y: float) -> PackedVector3Array:
	return VehicleModels.ring_y(VehicleModels._v2(pts), y)


## The AAF's three-figure tactical number (company, platoon, vehicle), drawn
## from the vehicle's own seed by VehicleMarkings.tactical_number: two tanks
## of a kind differ, and a tank reads the same on every peer. It is painted
## in heavy stencil bars on both flanks (VehicleMarkings.side_number) in the
## AAF's grey-white.
const TAC := ["1234", "123", "1234"]


## Level rings (bottom to top, as VehicleModels.solid takes them) as cut and
## welded armour plate: the top edge chamfered `b` all round and the upright
## corners broken as much (VehicleBody.armour). Armour plate is cut and welded,
## or cast, with a broken edge; a knife-sharp roof edge or corner is what makes
## a model read as CG, and the narrow facets catch the light from the RTS
## camera.
static func _armour(rings: Array, key: String, b: float) -> ArrayMesh:
	return VehicleBody.armour(rings, key, b, 0.0, b)


## A hull block lofted from the outline `bottom` at y0 to `top` at y1 (x, z
## pairs, as VehicleModels.loft) whose top meets the hull above it: its
## upright corners and its bottom edge broken `b`, as cut plate is, its top
## left square so it seats flush under the next block (VehicleBody.armour).
static func _block(key: String, bottom: Array, top: Array, y0: float, y1: float, b: float) -> ArrayMesh:
	return VehicleBody.armour([_ring(bottom, y0), _ring(top, y1)], key, 0.0, b, b)


## A plate lying along a face of a side profile, from a to b (each (z, y));
## `lift` moves it off the face (positive: away from the hull for a front face
## walked bottom to top, or a rear face walked top to bottom). Glass is a
## shared pane, sealed round its edges (VehicleGlazing).
static func _plate(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, th: float, mat: String, col = null, lift := 0.0, shadow := true, ext := 0.0) -> Variant:
	var d := b - a
	var l := d.length()
	var n := Vector2(-d.y, d.x) / l
	var mid := (a + b) * 0.5 + n * (lift + th * 0.5)
	var rot := Vector3(atan2(d.x, d.y), 0, 0)
	if mat == "glass":
		return VehicleGlazing.rectangle(k, p, Vector2(w, l + ext), Vector3(x, mid.y, mid.x), rot, false, col, th)
	return k._box(p, Vector3(w, l + ext, th), Vector3(x, mid.y, mid.x), mat, col, rot, shadow)


## Engine louvres on a glacis face of a side profile, w wide at x, from t0 to
## t1 of the way from a to b (each (z, y), the face walked bottom to top). The
## grille stands 3 cm off the plate so its recessed radiator core shows.
static func _glacis_grille(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, t0: float, t1: float, mat: String, col, count: int) -> void:
	var d := b - a
	var mid := a.lerp(b, (t0 + t1) * 0.5) + Vector2(-d.y, d.x).normalized() * 0.03
	# Turned half a turn past the plate's own tilt, so the grille's +Z faces out.
	VehicleFittings.grille(k, p, Vector3(x, mid.y, mid.x), Vector2(w, d.length() * (t1 - t0)), Vector3(atan2(d.x, d.y) + PI, 0, 0), mat, col, count)


## A cylinder placed in a local frame t (a part group turned as one).
static func _tc(k: VehicleModels, p: Node3D, t: Transform3D, r0: float, r1: float, h: float, lp: Vector3, lr: Vector3, mat: String, col = null, segs := 12, shadow := true) -> Variant:
	return k._cyl(p, r0, r1, h, t * lp, (t.basis * Basis.from_euler(lr)).get_euler(), mat, col, segs, shadow)


## A rectangular convoy-light cluster set in a housing, facing -Z (or +Z
## with face = 1), with a two-bar guard in front: the headlamp insert beside
## its amber indicator, or at the rear the red tail lens beside the amber one.
static func _light(k: VehicleModels, p: Node3D, pos: Vector3, w: float, h: float, face := -1.0, guard := true, rear := false) -> void:
	var housing := Vector3(w + 0.05, h + 0.05, 0.08)
	var rails := "rails" if guard else ""
	var reach := Vector3(w + 0.05, h + 0.12, 0.12)
	if rear:
		VehicleFittings.lamp_unit(k, p, pos, housing, face, [], Rect2(Vector2(w * 0.24, 0), Vector2(w * 0.45, h * 0.7)), rails, reach)
		VehicleFittings.signal_lens(k, p, pos + Vector3(-w * 0.24, 0, face * housing.z * 0.5), Vector2(w * 0.45, h * 0.7), Color(0.45, 0.035, 0.025), face)
	else:
		VehicleFittings.lamp_unit(k, p, pos, housing, face, [Rect2(Vector2(-w * 0.18, 0), Vector2(w * 0.55, h * 0.72))], Rect2(Vector2(w * 0.3, 0), Vector2(w * 0.25, h * 0.5)), rails, reach)


## A round headlight in a deep housing facing -Z, with a crossed wire guard.
static func _round_light(k: VehicleModels, p: Node3D, pos: Vector3, r: float) -> void:
	VehicleFittings.lamp_unit(k, p, pos, Vector3(r * 2.6, r * 2.4, 0.16), -1.0, [r], Rect2(), "cross", Vector3(r * 2.3, r * 2.3, 0.13), "round")


## A cluster of n smoke-grenade dischargers on their bracket, fanned out, the
## bracket turned by yaw (0 faces forward) and the tubes pitched up.
static func _smoke(k: VehicleModels, p: Node3D, pos: Vector3, n: int, yaw: float, pitch := 0.45, r := 0.045) -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
	var tubes := []
	for i in n:
		var fx := (i - (n - 1) * 0.5) * r * 2.3
		tubes.append(Transform3D(t.basis * Basis.from_euler(Vector3(-PI / 2 + pitch, fx * 1.6, 0)), t * Vector3(fx, 0.06 + absf(fx) * 0.2, -0.04)))
	VehicleFittings.smoke_bank(k, p, t * Vector3(0, -0.02, 0.04), Vector3(n * r * 2.3 + 0.04, 0.08, 0.16), Vector3(0, yaw, 0), tubes, r, 0.24)


## A whip antenna on a small base.
static func _antenna(k: VehicleModels, p: Node3D, pos: Vector3, h: float) -> void:
	VehicleFittings.antenna(k, p, pos, h)


## A 20 l jerrycan (standing, its face toward +X or -X when yaw = 0).
static func _jerrycan(k: VehicleModels, p: Node3D, pos: Vector3, col: Color, yaw := 0.0) -> void:
	VehicleFittings.jerrycan(k, p, pos + Vector3(0, 0.23, 0), col, Vector3(0, yaw, 0))



## A rubber-tyred road wheel (twin discs with the guide gap between them) on
## a spinning pivot, the disc painted like the hull.
static func _road_wheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	return VehicleWheels.road(k, p, pos, r, w, mat, col)


## A steel idler (no tyre) on a spinning pivot.
static func _idler(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	return VehicleWheels.road(k, p, pos, r, w, mat, col, 0, false)


## A toothed drive sprocket on a spinning pivot.
static func _sprocket(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	return VehicleWheels.sprocket(k, p, pos, r, w, mat, col, 8, true)



## A track: a belt of link plates round the convex hull of its wheels (each
## circle (z, y, r)), so the road wheels show between the runs. The Leopard
## 2's, Warrior's and Wiesel's tracks are double-pin with a centre guide
## running between the twin road wheels.
static func _track_belt(k: VehicleModels, p: Node3D, x: float, w: float, circles: Array, th := 0.08, segs := 16) -> void:
	VehicleTracks.shoes(k, p, x, w, VehicleTracks.on_rollers(k, VehicleTracks.wheel_envelope(circles, th, segs), circles, th * 0.5), th, 0.20, true, true)


# --- Strider: KMW Fennek LGS scout car ---------------------------------------------

## KMW Fennek: low and wide on four big wheels, the steep armoured nose and
## sloped twin windscreen, the cabin sides leaning in, the engine deck at the
## back with its grilles; the sensor mast behind the cabin (the scout's is
## telescopic and tall), an RCWS on the roof of the armed ones (variant 1:
## 12.7 mm HMG, 2: 40 mm GMG).
static func _strider(k: VehicleModels, team: int, variant: int) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	var wr := 0.54
	var wx := 1.06
	var wz := [-1.62, 1.62]
	# the belly between the wheels (its front sloping under the nose)
	k._add(m, VehicleModels.loft("indep_str_core", _oct(-0.7, 0.7, -2.2, 2.3, 0.15), _oct(-0.84, 0.84, -2.7, 2.72, 0.1), 0.42, 1.18), cam, col, Vector3.ZERO)
	# the nose and tail blocks ahead of and behind the wheel arches, the sills between
	k._add(m, _block("indep_str_nose", _oct(-1.15, 1.15, -2.62, -2.3, 0.05), _oct(-1.26, 1.26, -2.79, -2.3, 0.08), 0.62, 1.18, 0.03), cam, col, Vector3.ZERO)
	k._add(m, _block("indep_str_tail", _oct(-1.17, 1.17, 2.3, 2.66, 0.05), _oct(-1.26, 1.26, 2.3, 2.79, 0.08), 0.62, 1.18, 0.03), cam, col, Vector3.ZERO)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.42, 0.56, 1.88), Vector3(s * 1.04, 0.9, 0.0), cam, col)
	# the upper hull: a chine all round, then the armoured nose and windscreen
	# in one steep slope, the cabin's sides leaning in, the engine deck a step
	# lower at the back
	k._add(m, _block("indep_str_hull", _oct(-1.275, 1.275, -2.79, 2.79, 0.1), _oct(-1.25, 1.25, -2.52, 2.77, 0.12), 1.18, 1.36, 0.03), cam, col, Vector3.ZERO)
	k._add(m, _armour([_ring(_oct(-1.25, 1.25, -2.52, 1.05, 0.12), 1.36), _ring(_oct(-1.02, 1.02, -1.88, 1.0, 0.1), 1.79)], "indep_str_cab", 0.04), cam, col, Vector3.ZERO)
	k._add(m, _armour([_ring(_oct(-1.25, 1.25, 0.95, 2.77, 0.12), 1.36), _ring(_oct(-1.07, 1.07, 1.0, 2.5, 0.1), 1.7)], "indep_str_deck", 0.035), cam, col, Vector3.ZERO)
	# wheels in their dark wells, mud flaps behind the rear ones
	for s: float in [-1.0, 1.0]:
		for z in wz:
			k._box(m, Vector3(0.03, 0.5, 1.25), Vector3(s * 0.855, 0.92, z), "plain_dark", null, Vector3.ZERO, false)
			k._wheel(m, Vector3(s * wx, wr, z), wr, 0.38, cam, col)
			# the arch's lip
			VehicleBody.fender(k, m, Vector3(s * 1.24, 1.16, z), Vector3(0.1, 0.06, 1.42), s, cam, col)
		VehicleFittings.mudflap(k, m, Vector3(s * 1.04, 0.8, 2.3), Vector2(0.32, 0.36))
	# windscreen: two armoured panes in heavy frames on the slope, the pillar between
	var ws_a := Vector2(-2.52, 1.36)
	var ws_b := Vector2(-1.88, 1.79)
	# (armoured glass's green-black, VmCsat.ARMOR_GLASS; a wreck's stays as it was)
	var glass: Variant = null if k.wreck else VmCsat.ARMOR_GLASS
	for s: float in [-1.0, 1.0]:
		VehicleMaterials.glaze(k, _plate(k, m, s * 0.45, 0.7, ws_a.lerp(ws_b, 0.2), ws_a.lerp(ws_b, 0.86), 0.03, "glass", glass, -0.008, false), "armor_glass", glass)
		_plate(k, m, s * 0.45, 0.8, ws_a.lerp(ws_b, 0.13), ws_a.lerp(ws_b, 0.2), 0.035, cam, col, 0.0)
	_plate(k, m, 0.0, 0.12, ws_a.lerp(ws_b, 0.13), ws_b, 0.04, cam, col, 0.0)
	# a wiper over each pane, parked along its foot with the spindle in the
	# frame under its outer corner, the blade toward the pillar (stood up the
	# middle of the pane, the arm and blade read as a T drawn on the glass)
	for s: float in [-1.0, 1.0]:
		var a := ws_a.lerp(ws_b, 0.22 if k.wreck else 0.165)
		var b := ws_a.lerp(ws_b, 0.6 if k.wreck else 0.27)
		VehicleFittings.wiper(k, m, Vector3(s * (0.5 if k.wreck else 0.7), a.y, a.x - 0.025), Vector3(s * (0.5 if k.wreck else 0.44), b.y, b.x - 0.025), Vector3.RIGHT, Vector3(0, ws_b.x - ws_a.x, ws_a.y - ws_b.y), 0.36)
	# the nose: headlight clusters in guards, tow shackles, a plate
	for s: float in [-1.0, 1.0]:
		_light(k, m, Vector3(s * 0.92, 1.02, -2.8), 0.3, 0.13)
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.55, 0.72, -2.62), -1.0, Vector3(0.1, 0.14, 0.16), 0.05)
	VehicleMarkings.plate(k, m, Vector3(0, 0.98, -2.8), Vector2(0.44, 0.12), Vector3.FORWARD, 0.0, "", 0.02, Color(0.82, 0.8, 0.72), VehicleMarkings.PLATE_INK, false)
	for s: float in [-1.0, 1.0]:
		# mirrors on their arms by the windscreen
		VehicleFittings.mirror(k, m, Vector3(s * 1.46, 1.52, -2.2), Vector2(0.15, 0.24), -s * 0.3, [Vector3(s * 1.14, 1.48, -2.2)])
		# the side door: seams, an armoured window, the handle, a step below
		var sl: float = s * 0.49
		var face := (Basis.from_euler(Vector3(0, 0, sl)) * Basis(Vector3.UP, PI / 2))
		if k.wreck:
			VehicleGlazing.rectangle(k, m, Vector2(0.58, 0.26), Vector3(s * 1.15, 1.57, -0.52), face.get_euler(), false, null, 0.03)
		else:
			# A block of armoured glass several centimetres thick, seated on a
			# steel frame bolted over the opening (a thin pane flush with the
			# plate read as a painted-on window).
			var out := Vector3(s * cos(sl), absf(sin(sl)), 0)
			var at := Vector3(s * 1.15, 1.57, -0.52)
			k._box(m, Vector3(0.68, 0.36, 0.06), at, cam, col, face.get_euler())
			VehicleMaterials.glaze(k, VehicleGlazing.rectangle(k, m, Vector2(0.58, 0.26), at + out * 0.04, face.get_euler(), false, glass, 0.03), "armor_glass", glass)
			for corner: Vector2 in [Vector2(-0.328, -0.166), Vector2(0.328, -0.166), Vector2(-0.328, 0.166), Vector2(0.328, 0.166)]:
				VehicleBody.fastener(k, m, at + face.x * corner.x + face.y * corner.y + out * 0.03, out, 0.01, cam, col)
		# the shut lines up the sill and on up the cabin's leaning side
		var lean := Basis.from_euler(Vector3(0, 0, sl)) * Vector3.UP * 0.3
		for dz: float in [-0.92, -0.04]:
			VehicleBody.seam(k, m, [Vector3(s * 1.255, 1.17, dz), Vector3(s * 1.255, 0.63, dz)], 0.01)
			VehicleBody.seam(k, m, [Vector3(s * 1.16, 1.5, dz) + lean, Vector3(s * 1.16, 1.5, dz) - lean], 0.01)
		VehicleDoors.lever(k, m, Vector3(s * 1.25, 1.06, -0.305), Vector3(s, 0, 0), Vector3.BACK, 0.125, 0.04)
		VehicleFrames.step(k, m, Vector3(s * 1.18, 0.6, -0.48), Vector2(0.18, 0.5), Vector3.ZERO, "gunmetal_w")
		# a small rear-quarter window, the stowage bin over the rear wheel
		VehicleMaterials.glaze(k, VehicleGlazing.rectangle(k, m, Vector2(0.26, 0.18), Vector3(s * 1.15, 1.57, 0.55), face.get_euler(), false, glass, 0.03), "armor_glass", glass)
		VehicleEquipment.storage(k, m, Vector3(s * 1.33, 1.3, 1.85), Vector3(0.16, 0.3, 0.9), cam, col, Vector3.ZERO)
		k._box(m, Vector3(0.02, 0.04, 0.9), Vector3(s * 1.415, 1.38, 1.85), "gunmetal_w", null, Vector3.ZERO, false)
		# smoke dischargers on the deck corners, a whip antenna at each back corner
		_smoke(k, m, Vector3(s * 0.88, 1.72, 1.15), 3, s * -0.6)
		_antenna(k, m, Vector3(s * 0.95, 1.7, 2.4), 2.1)
		# rear: tail light clusters, the jerrycan rack on the left, a box on the right
		_light(k, m, Vector3(s * 1.0, 1.25, 2.8), 0.22, 0.1, 1.0, false, true)
	_jerrycan(k, m, Vector3(-0.55, 0.62, 2.98), Color(0.3, 0.33, 0.23), PI / 2)
	_jerrycan(k, m, Vector3(-0.32, 0.62, 2.98), Color(0.3, 0.33, 0.23), PI / 2)
	k._box(m, Vector3(0.55, 0.06, 0.4), Vector3(-0.44, 0.6, 2.98), "gunmetal_w")
	# the box's catches face out the back, its lid hinged on the hull side
	VehicleEquipment.storage(k, m, Vector3(0.5, 0.86, 2.95), Vector3(0.6, 0.38, 0.3), cam, col, Vector3(0, PI, 0))
	# the towing jaw between the tow eyes
	VehicleMounts.hitch(k, m, Vector3(0, 0.66, 2.895), Vector3(0.16, 0.14, 0.25))
	# exhaust out of the right flank behind the rear wheel, under a heat shield
	# (the shield painted with the hull, as the army's heat-proof paint takes
	# it; bare, it read from above as a black slab on the flank. A wreck
	# keeps the bare one)
	k._box(m, Vector3(0.12, 0.2, 0.4), Vector3(1.3, 1.0, 2.5), "gunmetal_w" if k.wreck else cam, null if k.wreck else col)
	VehicleFittings.exhaust(k, m, Vector3(1.27, 0.9, 2.62), Vector3.RIGHT, 0.18, 0.06, false)
	# roof: the driver's and commander's hatches with periscopes, the
	# observer's hatch behind
	for s: float in [-1.0, 1.0]:
		# hinged at the front, by the periscopes, the handle at the back
		VehicleFittings.panel_hatch(k, m, Vector3(s * 0.48, 1.81, -1.3), Vector3(0.6, 0.06, 0.6), cam, col, -1.0)
		for i in 3:
			VehicleFittings.periscope(k, m, Vector3(s * 0.48 + (i - 1) * 0.18, 1.83, -1.7), Vector3(0.14, 0.08, 0.06), Vector3(-0.3, 0, 0))
	VehicleFittings.panel_hatch(k, m, Vector3(-0.45, 1.81, 0.55), Vector3(0.55, 0.05, 0.5), cam, col)
	# an air-recognition panel folded on the cabin roof behind the front
	# hatches, clear of the mast's or the weapon station's foot
	VehicleEquipment.recognition_panel(k, m, Vector3(0, 1.792, -0.6), Vector3.ZERO, true)
	# engine deck: two grilles with their slats, standing just proud of the
	# deck so the radiator core shows below them
	for s: float in [-1.0, 1.0]:
		VehicleFittings.grille(k, m, Vector3(s * 0.5, 1.73, 1.75), Vector2(0.8, 1.2), Vector3(-PI / 2, 0, 0), cam, col, 4)
	_tow_eyes(k, m, 2.84, 0.72)
	k._team_mark(m, team, Vector3(1.275, 0.9, 0.5), Vector3(0.03, 0.22, 0.6))
	k._team_mark(m, team, Vector3(-1.275, 0.9, 0.5), Vector3(0.03, 0.22, 0.6))
	if variant == 0:
		# the scout: the BAA sensor head (camera, thermal imager, rangefinder)
		# high on a telescopic mast behind the cabin; the head pans
		k._box(m, Vector3(0.36, 0.14, 0.36), Vector3(0.0, 1.86, 0.72), "gunmetal_w")
		VehicleMounts.mast_segment(k, m, Vector3(0, 2.1, 0.72), 0.55, 0.11, cam, col)
		VehicleMounts.mast_segment(k, m, Vector3(0, 2.62, 0.72), 0.55, 0.075, "gunmetal_w", null)
		VehicleMounts.mast_segment(k, m, Vector3(0, 3.1, 0.72), 0.5, 0.055, "gunmetal_w", null)
		for i in 3:
			k._cyl(m, 0.09 - i * 0.02, 0.09 - i * 0.02, 0.04, Vector3(0, 2.38 + i * 0.52, 0.72), Vector3.ZERO, "gunmetal_w", null, 10, false)
		k.turret = k._pivot(m, Vector3(0, 3.35, 0.72))
		_sensor_head(k, k.turret, Vector3(0, 0.12, 0), cam, col, 1.0)
	else:
		# the commander's periscope mast, folded low at the cabin's back corner
		VehicleMounts.mast_segment(k, m, Vector3(0.72, 1.95, 0.75), 0.32, 0.06, "gunmetal_w", null)
		_sensor_head(k, m, Vector3(0.72, 2.16, 0.75), cam, col, 0.7)
		_rcws(k, m, Vector3(0, 1.79, 0.1), variant == 2, cam, col, 0.9)


## Tow eyes and a pintle under the back.
static func _tow_eyes(k: VehicleModels, p: Node3D, z: float, y: float) -> void:
	for s: float in [-1.0, 1.0]:
		VehicleFittings.tow_shackle(k, p, Vector3(s * 0.6, y, z), 1.0, Vector3(0.08, 0.12, 0.12), 0.045)


## An electro-optical sensor head: a box with a camera window, a thermal
## imager's round lens and the rangefinder's, facing -Z.
static func _sensor_head(k: VehicleModels, p: Node3D, pos: Vector3, cam: String, col, sc := 1.0) -> void:
	VehicleEquipment.sensor(k, p, pos, Vector3(0.5, 0.26, 0.3) * sc, cam, col)
	k._box(p, Vector3(0.12, 0.2, 0.12) * sc, pos + Vector3(0, -0.2, 0.02) * sc, "gunmetal_w")


## A remote weapon station (FLW-style): a turntable, the cradle between two
## yoke arms with the 12.7 mm HMG or the 40 mm GMG, the ammunition box on one
## side and the sight on the other. Sets k.turret and k.mg_tip.
static func _rcws(k: VehicleModels, p: Node3D, pos: Vector3, gmg: bool, cam: String, col, sc := 1.0) -> void:
	var t := k._pivot(p, pos)
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.04, 0) * sc, 0.32 * sc, 0.35 * sc, 0.08 * sc, "gunmetal_w", null, 16)
	k._add(t, VehicleModels.loft("indep_rcws_base", _oct(-0.26, 0.26, -0.28, 0.3, 0.06), _oct(-0.22, 0.22, -0.2, 0.26, 0.05), 0.0, 0.2, 0.015), cam, col, Vector3(0, 0.08, 0) * sc, Vector3.ZERO, Vector3.ONE * sc)
	for s: float in [-1.0, 1.0]:
		k._box(t, Vector3(0.06, 0.3, 0.26) * sc, Vector3(s * 0.2, 0.38, 0.0) * sc, cam, col)
	k._cyl(t, 0.05 * sc, 0.05 * sc, 0.46 * sc, Vector3(0, 0.44, 0) * sc, Z90, "gunmetal_w", null, 10, false)
	# the sight box on the right (the day camera's window over the thermal
	# imager's round lens), the ammo box on the left
	VehicleMounts.sight(k, t, Vector3(0.34, 0.46, -0.05) * sc, Vector3(0.16, 0.2, 0.3) * sc, [Rect2(Vector2(0, 0.02) * sc, Vector2(0.11, 0.09) * sc)], cam, col)
	k._cyl(t, 0.035 * sc, 0.035 * sc, 0.02 * sc, Vector3(0.34, 0.39, -0.205) * sc, X90, "glass" if k.wreck else "armor_glass", null if k.wreck else VehicleMounts.OPTIC, 10, false)
	if gmg:
		# HK GMG: a squat receiver, a short thick barrel, the big belt box
		VehicleWeapons.gmg(k, t, Vector3(0, 0.46, 0.0) * sc, Vector3(0, 0.46, -0.78) * sc, sc, -1.0, false, "gunmetal_w", Color(0.3, 0.33, 0.23), 0.36)
		k.mg_tip = k._tip(t, Vector3(0, 0.46, -0.78) * sc)
	else:
		# M2: the long receiver, the barrel with its carrying handle, flash
		# hider; its ammunition box is the station's, hung outboard of the yoke
		VehicleWeapons.hmg(k, t, Vector3(0, 0.46, 0.02) * sc, Vector3(0, 0.46, -1.54) * sc, sc, 0.0)
		k._box(t, Vector3(0.17, 0.22, 0.3) * sc, Vector3(-0.32, 0.44, 0.04) * sc, "paint", Color(0.3, 0.33, 0.23))
		k.mg_tip = k._tip(t, Vector3(0, 0.46, -1.54) * sc)


## A slat cage panel: top and bottom rails, end posts and the vertical slats,
## centred at c; along X (a rear cage) or along Z (a side cage). The slats
## take `mat` / `col` (the hull's paint: a cage comes painted with the tank).
static func _slats(k: VehicleModels, p: Node3D, c: Vector3, l: float, h: float, along_x: bool, gap := 0.17, mat := "gunmetal_w", col = null) -> void:
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	VehicleMounts.slats(k, p, c - axis * l * 0.5 - Vector3.UP * h * 0.5, c + axis * l * 0.5 - Vector3.UP * h * 0.5, h, gap, true, mat, col, mat, col)



## A track set on one side: road wheels, sprocket, idler, return rollers and
## the belt round them all. side -1 / +1; rw the road wheels' z; sprocket and
## idler as (z, y, r).
static func _running_gear(k: VehicleModels, side: float, x: float, tw: float, rw: Array, rr: float, sprocket: Vector3, idler: Vector3, rollers: Array, roller_y: float, th: float, cam: String, col) -> void:
	var m := k.root
	var wy := rr + th
	var circles := []
	for z in rw:
		_road_wheel(k, m, Vector3(side * x, wy, z), rr, tw * 0.86, cam, col)
		circles.append(Vector3(z, wy, rr))
	_sprocket(k, m, Vector3(side * x, sprocket.y, sprocket.x), sprocket.z, tw * 0.8, cam, col)
	_idler(k, m, Vector3(side * x, idler.y, idler.x), idler.z, tw * 0.8, cam, col)
	circles.append(sprocket)
	circles.append(idler)
	for z in rollers:
		VehicleWheels.roller(k, m, Vector3(side * x, roller_y, z), 0.075, tw * 0.6)
		circles.append(Vector3(z, roller_y, 0.075))
	_track_belt(k, m, side * x, tw, circles, th)


# --- Mora: BAE FV510 Warrior ---------------------------------------------------------

## FV510 Warrior: a big slab-sided box on six road wheels a side under deep
## skirts, the long glacis with the driver front-left and the engine louvres
## front-right, the two-man turret in the middle with the long thin 30 mm
## RARDEN and its four-barrel smoke dischargers, the big rear door between
## two stowage bins.
static func _mora(k: VehicleModels, team: int, seed := 0) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	# running gear: front sprocket, six road wheels, rear idler, three rollers
	var rw := []
	for i in 6:
		rw.append(-2.0 + i * 0.78)
	for s: float in [-1.0, 1.0]:
		_running_gear(k, s, 1.2, 0.46, rw, 0.31, Vector3(-2.74, 0.66, 0.27), Vector3(2.62, 0.6, 0.26), [-1.6, -0.1, 1.4], 0.86, 0.08, cam, col)
	# the hull: belly between the tracks, the upper hull out over them with
	# the long glacis
	k._add(m, _block("indep_mora_low", _oct(-0.9, 0.9, -2.72, 2.95, 0.1), _oct(-0.96, 0.96, -3.15, 3.15, 0.1), 0.42, 1.02, 0.04), cam, col, Vector3.ZERO)
	k._add(m, _armour([_ring(_oct(-1.45, 1.45, -3.17, 3.17, 0.06), 1.0), _ring(_oct(-1.45, 1.45, -3.0, 3.17, 0.06), 1.12), _ring(_oct(-1.43, 1.43, -2.05, 3.15, 0.05), 1.93)], "indep_mora_up", 0.05), cam, col, Vector3.ZERO)
	# skirts: five bolted panels a side, the front one raked
	for s: float in [-1.0, 1.0]:
		for i in 5:
			VehicleEquipment.skirt(k, m, Vector3(s * 1.49, 0.8, -1.9 + i * 1.1), Vector3(0.05, 0.44, 1.08), s, cam, col)
			k._box(m, Vector3(0.02, 0.03, 1.0), Vector3(s * 1.52, 0.98, -1.9 + i * 1.1), "gunmetal_w", null, Vector3.ZERO, false)
		# cut branches tucked along the skirts' top edge, against the hull side
		VehicleBody.cut_branches(k, m, Vector3(s * 1.5, 1.033, -2.2), Vector3(s * 1.5, 1.033, 1.1), Vector3(s, 0, 0), 31)
		VehicleEquipment.skirt_bow(k, m, Vector3(s * 1.49, 0.86, -2.78), Vector3(0.05, 0.36, 0.6), s, cam, col, Vector3(-0.45, 0, 0))
		# the hull's side seam at the deck line, a stowage box aft
		k._box(m, Vector3(0.04, 0.05, 6.1), Vector3(s * 1.45, 1.5, 0.05), cam, col)
		VehicleEquipment.storage(k, m, Vector3(s * 1.52, 1.45, 2.2), Vector3(0.22, 0.38, 1.1), cam, col)
		# headlight clusters in guards on the glacis corners, tow hooks
		_light(k, m, Vector3(s * 1.16, 1.22, -3.08), 0.26, 0.12)
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.62, 0.92, -3.18), -1.0, Vector3(0.12, 0.16, 0.18), 0.05)
	# glacis: the driver's hatch and vision blocks front-left, the engine
	# louvres front-right, lifting eyes
	var ga := Vector2(-3.0, 1.12)
	var gb := Vector2(-2.05, 1.93)
	VehicleFittings.panel_hatch(k, m, Vector3(-0.72, 1.95, -1.68), Vector3(0.62, 0.06, 0.66), cam, col)
	for i in 3:
		VehicleFittings.periscope(k, m, Vector3(-0.9 + i * 0.18, 1.94, -2.06), Vector3(0.15, 0.08, 0.06), Vector3(-0.4, 0, 0))
	_glacis_grille(k, m, 0.62, 1.3, ga, gb, 0.3, 0.95, cam, col, 6)
	VehicleFittings.grille(k, m, Vector3(0.62, 1.96, -1.6), Vector2(1.0, 0.7), Vector3(-PI / 2, 0, 0), cam, col, 4)
	for s: float in [-1.0, 1.0]:
		VehicleFittings.lifting_eye(k, m, Vector3(s * 1.2, 1.92, -1.95), 0.0, 0.045)
	# exhaust: the louvred outlet on the right flank, forward, and the soot
	# it streaks back along the side plate (which leans in 2 cm up its height)
	VehicleFittings.grille(k, m, Vector3(1.53, 1.62, -1.85), Vector2(0.6, 0.36), Vector3(0, PI / 2, 0), cam, col, 3)
	VehicleBody.soot(k, m, Vector3(1.4377, 1.62, -1.55), Vector3.BACK, Vector3(-0.0247, 1, 0), Vector3(1, 0.0247, 0), 1.1, 0.34)
	# roof: the troop compartment's long hatch, a vent, antennas at the back
	VehicleFittings.panel_hatch(k, m, Vector3(0, 1.96, 2.15), Vector3(1.5, 0.06, 1.2), cam, col)
	k._box(m, Vector3(0.04, 0.04, 1.1), Vector3(0, 2.0, 2.15), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(m, 0.12, 0.14, 0.12, Vector3(-0.95, 1.99, 1.35), Vector3.ZERO, "gunmetal_w", null, 10)
	# the section's camouflage net rolled and strapped across the roof's back edge
	VehicleCloth.roll(k, m, Vector3(0, 2.05, 2.93), 0.12, 2.0, Z90, Color(0.33, 0.35, 0.24))
	# rear: the big door with its vision block, hinges and handle, a stowage
	# bin either side of it, tail lights, the tow pintle
	VehicleDoors.leaf(k, m, Vector3(1.0, 1.15, 0.08), Vector3(0.12, 1.4, 3.2), cam, col, Vector3.ZERO, 2)
	VehicleGlazing.rectangle(k, m, Vector2(0.18, 0.1), Vector3(0.12, 1.75, 3.25), Vector3.ZERO, false, null, 0.04)
	for hy: float in [1.05, 1.75]:
		VehicleDoors.hinge(k, m, Vector3(-0.4, hy, 3.24), Vector3.BACK, Vector3.UP, 0.028, cam, col)
	VehicleDoors.lever(k, m, Vector3(0.52, 1.35, 3.24), Vector3.BACK, Vector3.DOWN, 0.14, 0.14, 0.025)
	for s: float in [-1.0, 1.0]:
		# the bins' lids hinge on the hull side, their catches face aft
		var bx: float = s * 1.08 + (0.0 if s < 0.0 else 0.06)
		VehicleEquipment.storage(k, m, Vector3(bx, 1.36, 3.38), Vector3(0.62 if s < 0.0 else 0.5, 0.78, 0.42), cam, col, Vector3(0, PI, 0))
		_light(k, m, Vector3(s * 1.1, 0.88, 3.24), 0.22, 0.1, 1.0, false, true)
	VehicleMounts.hitch(k, m, Vector3(0, 0.82, 3.22), Vector3(0.16, 0.14, 0.2))
	k._team_mark(m, team, Vector3(1.46, 1.3, 0.9), Vector3(0.03, 0.26, 0.7))
	k._team_mark(m, team, Vector3(-1.46, 1.3, 0.9), Vector3(0.03, 0.26, 0.7))
	# the turret: faceted, the RARDEN in its narrow mantlet, the chain gun
	# beside it, sights and hatches on the roof
	var t := k._pivot(m, Vector3(0, 1.93, -0.25))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.04, 0.1), 1.0, 1.02, 0.08, "gunmetal_w", null, 20)
	var tb := [-0.55, -1.22, 0.55, -1.22, 1.05, -0.72, 1.1, 0.95, 0.85, 1.18, -0.85, 1.18, -1.1, 0.95, -1.05, -0.72]
	var tt := [-0.42, -0.88, 0.42, -0.88, 0.86, -0.5, 0.93, 0.85, 0.72, 1.04, -0.72, 1.04, -0.93, 0.85, -0.86, -0.5]
	k._add(t, _armour([_ring(tb, 0.06), _ring(tt, 0.74)], "indep_mora_tur", 0.06), cam, col, Vector3.ZERO)
	VehicleMarkings.side_number(k, t, VehicleMarkings.tactical_number(seed, TAC), 0.38, Vector3(1.1, 0.06, 0.95), Vector3(1.05, 0.06, -0.72), Vector3(0.86, 0.74, -0.5), Vector3(0.93, 0.74, 0.85), Vector2(0.39, 0.43), VehicleMarkings.STENCIL_AAF)
	VehicleMounts.mantlet(k, t, Vector3(0.36, 0.4, 0.4), Vector3(0, 0.4, -1.18), cam, col)
	VehicleWeapons.autocannon(k, t, Vector3(0, 0.4, -1.3), Vector3(0, 0.4, -4.11), Vector2(0.075, 0.5), Vector2(0.045, 0.045), Vector2(0.065, 0.22))
	k.mg_tip = k._tip(t, Vector3(0, 0.4, -4.14))
	VehicleWeapons.coax(k, t, Vector3(-0.3, 0.3, -1.45), 0.5, 0.02)
	# gunner's sight left, the commander's sight right, two hatches
	VehicleMounts.sight(k, t, Vector3(-0.45, 0.8, -0.42), Vector3(0.32, 0.2, 0.4), [Rect2(Vector2(0, 0.02), Vector2(0.24, 0.11))], cam, col)
	VehicleMounts.sight(k, t, Vector3(0.48, 0.92, -0.22), Vector3(0.26, 0.15, 0.28), [Rect2(Vector2(0, 0.01), Vector2(0.18, 0.09))], cam, col, Vector3(0.14, 0.16, 0.19))
	for s: float in [-1.0, 1.0]:
		# the round hatch lids, hinged at the back
		VehicleFittings.hatch(k, t, Vector3(s * 0.42, 0.77, 0.45), 0.3, cam, col, 1.0, 0.07)
		# four-barrel smoke dischargers on the front corners
		_smoke(k, t, Vector3(s * 0.98, 0.52, -0.68), 4, s * -0.55, 0.5, 0.05)
		_antenna(k, t, Vector3(s * 0.7, 0.74, 0.9), 1.9)
	# the bustle: a stowage basket with a rolled tarp and kit in it
	VehicleMounts.basket(k, t, Vector3(0, 0.3, 1.42), Vector3(1.6, 0.4, 0.55))
	VehicleCloth.roll(k, t, Vector3(0, 0.5, 1.45), 0.16, 1.3, Z90, Color(0.33, 0.35, 0.24))
	k._bag(t, Vector3(0.42, 0.3, 0.3), Vector3(0.55, 0.55, 1.5), "canvas", Color(0.38, 0.37, 0.27))


# --- Kuma: Leopard 2 with the Revolution urban upgrade --------------------------

## Leopard 2 "Revolution": the long low hull with its shallow upper glacis,
## seven road wheels a side under armoured skirts, the rear engine deck; the
## boxy wedge-free 2A4 turret made boxier still by flat bolt-on armour on its
## cheeks and sides, the EMES sight doghouse and the PERI periscope on the
## roof, a remote .50 over the loader, slat cages round the turret bustle and
## the hull's back, and the long 120 mm with its thermal sleeve.
static func _kuma(k: VehicleModels, team: int, seed := 0) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	# running gear: front idler, seven road wheels, rear sprocket, four rollers
	var rw := []
	for i in 7:
		rw.append(-2.58 + i * 0.86)
	for s: float in [-1.0, 1.0]:
		_running_gear(k, s, 1.38, 0.62, rw, 0.35, Vector3(3.3, 0.72, 0.32), Vector3(-3.3, 0.68, 0.3), [-1.92, -0.64, 0.64, 1.92], 0.91, 0.1, cam, col)
	# hull: the belly between the tracks (the lower glacis its front), the
	# upper hull out over the tracks with the long shallow upper glacis
	k._add(m, _block("indep_kuma_low", _oct(-1.02, 1.02, -3.25, 3.5, 0.1), _oct(-1.06, 1.06, -3.86, 3.84, 0.1), 0.48, 1.12, 0.04), cam, col, Vector3.ZERO)
	k._add(m, _armour([_ring(_oct(-1.76, 1.76, -3.86, 3.86, 0.05), 1.12), _ring(_oct(-1.76, 1.76, -3.72, 3.86, 0.05), 1.24), _ring(_oct(-1.74, 1.74, -2.5, 3.82, 0.05), 1.68)], "indep_kuma_up", 0.05), cam, col, Vector3.ZERO)
	var ga := Vector2(-3.72, 1.24)
	var gb := Vector2(-2.5, 1.68)
	# a bolted add-on plate over the glacis, the driver's hatch front-right: a
	# thick flame-cut slab (its wide chamfer catches the light on the glacis
	# from above) held by a row of heavy bolts along its top and bottom edges
	var gd := (gb - ga).normalized()
	var gm := ga.lerp(gb, 0.46) + Vector2(-gd.y, gd.x) * 0.03
	VehicleMounts.applique(k, m, Vector3(-0.35, gm.y, gm.x), Vector3(2.2, (gb - ga).length() * 0.68, 0.06), Vector3(atan2(gd.x, gd.y) + PI, 0, 0), cam, col, Vector2i(6, 2))
	VehicleFittings.panel_hatch(k, m, Vector3(0.82, 1.7, -2.15), Vector3(0.7, 0.06, 0.62), cam, col)
	for i in 3:
		VehicleFittings.periscope(k, m, Vector3(0.64 + i * 0.18, 1.69, -2.5), Vector3(0.16, 0.08, 0.06), Vector3(-0.5, 0, 0))
	for s: float in [-1.0, 1.0]:
		# headlight clusters with guards on the front corners, tow eyes
		_light(k, m, Vector3(s * 1.45, 1.36, -3.6), 0.3, 0.13)
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.72, 1.02, -3.88), -1.0, Vector3(0.14, 0.18, 0.2), 0.055)
		# skirts: three heavy armour modules forward, three light panels aft,
		# the bow panel raked
		for i in 6:
			var heavy := i < 3
			var sz := -2.62 + i * 1.08
			VehicleEquipment.skirt(k, m, Vector3(s * (1.83 if heavy else 1.8), 0.88, sz), Vector3(0.14 if heavy else 0.06, 0.52, 1.06), s, cam, col)
			if heavy:
				k._box(m, Vector3(0.02, 0.03, 0.9), Vector3(s * 1.905, 1.06, sz), "gunmetal_w", null, Vector3.ZERO, false)
		VehicleEquipment.skirt_bow(k, m, Vector3(s * 1.83, 0.96, -3.48), Vector3(0.14, 0.4, 0.56), s, cam, col, Vector3(-0.5, 0, 0))
		# cut branches tucked along the skirts' top, against the hull side
		VehicleBody.cut_branches(k, m, Vector3(s * 1.82, 1.153, -2.8), Vector3(s * 1.82, 1.153, 1.3), Vector3(s, 0, 0), 31)
		# the hull's sides: a stowage box and the tool rack above the skirts
		VehicleEquipment.storage(k, m, Vector3(s * 1.8, 1.4, 2.6), Vector3(0.12, 0.3, 1.2), cam, col, Vector3.ZERO)
		k._cyl(m, 0.03, 0.03, 2.4, Vector3(s * 1.79, 1.5, 0.1), X90, "gunmetal_w", null, 6, false)
		# engine deck grilles either side of the centre access panel
		VehicleFittings.grille(k, m, Vector3(s * 0.85, 1.71, 2.65), Vector2(1.2, 1.5), Vector3(-PI / 2, 0, 0), cam, col, 5)
		# a tow cable along each edge of the engine deck, outboard of the grilles
		VehicleFittings.tow_cable(k, m, [Vector3(s * 1.57, 1.702, 1.35), Vector3(s * 1.57, 1.702, 3.55)], 0.022, 0.0, -1, Vector3.UP)
		# rear: tail lights, tow eyes
		_light(k, m, Vector3(s * 1.4, 1.4, 3.88), 0.22, 0.1, 1.0, false, true)
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.8, 1.0, 3.88), 1.0, Vector3(0.14, 0.18, 0.2), 0.055)
	k._box(m, Vector3(0.5, 0.05, 1.5), Vector3(0, 1.69, 2.65), cam, col)
	# the exhaust louvres across the top of the rear plate, the slat cage
	# standing off the back on its struts: painted bars a hand's width apart
	# (closer than an RPG's warhead is wide, so its nose is caught between
	# them), not a fence of black railings
	VehicleFittings.grille(k, m, Vector3(0, 1.5, 3.91), Vector2(2.8, 0.26), Vector3.ZERO, cam, col, 3)
	_slats(k, m, Vector3(0, 1.22, 4.18), 3.3, 0.8, true, 0.13, cam, col)
	for sx: float in [-1.2, 0.0, 1.2]:
		k._box(m, Vector3(0.05, 0.05, 0.32), Vector3(sx, 1.0, 4.02), "gunmetal_w", null, Vector3.ZERO, false)
	k._team_mark(m, team, Vector3(1.81, 1.4, 1.2), Vector3(0.03, 0.22, 0.7))
	k._team_mark(m, team, Vector3(-1.81, 1.4, 1.2), Vector3(0.03, 0.22, 0.7))
	# the turret, its front cheeks just behind the glacis
	var t := k._pivot(m, Vector3(0, 1.68, 0.15))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.02, 0.0), 1.2, 1.22, 0.08, "gunmetal_w", null, 22)
	var tb := [-1.25, -1.98, 1.25, -1.98, 1.66, -1.5, 1.66, 1.1, 1.42, 2.05, -1.42, 2.05, -1.66, 1.1, -1.66, -1.5]
	var tt := [-1.2, -1.92, 1.2, -1.92, 1.6, -1.45, 1.6, 1.06, 1.36, 1.98, -1.36, 1.98, -1.6, 1.06, -1.6, -1.45]
	k._add(t, _armour([_ring(tb, 0.0), _ring(tt, 0.86)], "indep_kuma_tur", 0.07), cam, col, Vector3.ZERO)
	# the tactical number on the side armour, ahead of the panel's middle strap
	# (42 cm figures, on the front module, clear of its corner bolts)
	VehicleMarkings.side_number(k, t, VehicleMarkings.tactical_number(seed, TAC), 0.42, Vector3(1.79, 0.05, 0.975), Vector3(1.79, 0.05, -1.975), Vector3(1.79, 0.81, -1.975), Vector3(1.79, 0.81, 0.975), Vector2(0.834, 0.49), VehicleMarkings.STENCIL_AAF)
	# bolt-on armour: the Revolution's passive modules, flame-cut slabs hung
	# side by side with a finger's gap between them, each held by heavy bolts
	# at its corners and carrying a lifting lug on its top edge for the crane
	# that changes it: two on each cheek either side of the mantlet, three
	# along each side
	# (about one in eight a replacement bolted on after a hit, still in its
	# plain factory paint, drawn from the kit seed so neighbours differ)
	for s: float in [-1.0, 1.0]:
		for cx: float in [0.72, 1.44]:
			var at := Vector3(s * cx, 0.43, -2.1)
			var pm := _module_paint(k, t, at, cam, col)
			VehicleMounts.applique(k, t, at, Vector3(0.7, 0.82, 0.26), Vector3(0, PI, 0), pm[0], pm[1], Vector2i(2, 2), 1)
		for cz: float in [-1.485, -0.5, 0.485]:
			var at := Vector3(s * 1.72, 0.43, cz)
			var pm := _module_paint(k, t, at, cam, col)
			VehicleMounts.applique(k, t, at, Vector3(0.965, 0.76, 0.14), Vector3(0, s * PI / 2, 0), pm[0], pm[1], Vector2i(2, 2), 1)
		k._team_mark(t, team, Vector3(s * 1.8, 0.34, 0.25), Vector3(0.03, 0.22, 0.7))
		# smoke dischargers: a group of four on each side, aft, on the roof's
		# edge and inboard of the side modules' faces
		_smoke(k, t, Vector3(s * 1.55, 0.92, 1.12), 4, s * -1.05, 0.5, 0.05)
		_antenna(k, t, Vector3(s * 1.1, 0.86, 1.75), 2.2)
	# the gun: mantlet, thermal sleeve, fume extractor, muzzle reference sensor
	var gc := Color(0.31, 0.34, 0.25)
	# (the gun's canvas boot strapped round the mantlet's face, tied round
	# the sleeve where it leaves it)
	VehicleMounts.mantlet(k, t, Vector3(0.62, 0.54, 0.36), Vector3(0, 0.42, -2.06), cam, col, Vector3.ZERO, Vector2(0.105, 0.22))
	VehicleFittings.barrel(k, t, Vector3(0, 0.42, -2.42), Vector3(0, 0.42, -5.98), 0.105, "paint", gc)
	VehicleFittings.evacuator(k, t, Vector3(0, 0.42, -3.87), 0.165, 0.7, "paint", gc)
	VehicleWeapons.muzzle_sensor(k, t, Vector3(0, 0.55, -5.78), Vector3(0.06, 0.07, 0.1), Vector3(0, 0.42, -5.78), 0.105)
	k.gun_tip = k._tip(t, Vector3(0, 0.42, -6.0))
	# the coaxial MG left of the gun
	VehicleWeapons.coax(k, t, Vector3(-0.345, 0.3, -2.3), 0.3)
	var coax := k._tip(t, Vector3(-0.345, 0.3, -2.46))
	# roof: the EMES gunner's sight doghouse front-right, the PERI periscope
	# behind it, the commander's and loader's hatches, the wind sensor
	VehicleMounts.sight(k, t, Vector3(0.92, 1.04, -1.42), Vector3(0.6, 0.4, 0.78), [Rect2(Vector2(0, 0.02), Vector2(0.42, 0.18))], cam, col)
	k._box(t, Vector3(0.64, 0.04, 0.82), Vector3(0.92, 1.25, -1.42), cam, col)
	# (the PERI's head is an armoured drum painted with the turret, its cap
	# a shade darker; bare, it read from above as a black can on the roof)
	k._box(t, Vector3(0.34, 0.1, 0.34), Vector3(0.48, 0.91, -0.55), cam, col)
	k._cyl(t, 0.17, 0.17, 0.3, Vector3(0.48, 1.11, -0.55), Vector3.ZERO, cam, col, 14)
	k._cyl(t, 0.19, 0.19, 0.04, Vector3(0.48, 1.28, -0.55), Vector3.ZERO, "paint", Color(0.24, 0.27, 0.19), 14)
	k._box(t, Vector3(0.2, 0.12, 0.02), Vector3(0.48, 1.14, -0.72), "glass" if k.wreck else "armor_glass", null if k.wreck else VehicleMounts.OPTIC, Vector3.ZERO, false)
	VehicleMounts.cupola(k, t, Vector3(0.62, 0.92, 0.25), 0.36, 0.38, 0.12, 5, -0.9, 0.45, cam, col, Vector3(0.12, 0.08, 0.05))
	VehicleFittings.panel_hatch(k, t, Vector3(-0.62, 0.89, -0.35), Vector3(0.62, 0.06, 0.62), cam, col)
	VehicleMounts.mast_segment(k, t, Vector3(0.0, 1.08, 1.55), 0.45, 0.03)
	# the roof is welded from plates: the seam across behind the sight and
	# the two along its sides, and a lifting eye at each corner for the crane
	# that pulls the turret
	var weld := Color(0.2, 0.22, 0.17)
	VehicleBody.bead(k, t, [Vector3(-1.5, 0.862, -0.95), Vector3(1.5, 0.862, -0.95)], 0.01, "paint", weld, 4, false)
	for s: float in [-1.0, 1.0]:
		VehicleBody.bead(k, t, [Vector3(s * 1.22, 0.862, -1.85), Vector3(s * 1.22, 0.862, 1.88)], 0.01, "paint", weld, 4, false)
		VehicleFittings.lifting_eye(k, t, Vector3(s * 1.38, 0.86, -1.4), 0.0, 0.05)
		VehicleFittings.lifting_eye(k, t, Vector3(s * 1.36, 0.86, 1.5), 0.0, 0.05)
	k._box(t, Vector3(0.1, 0.06, 0.1), Vector3(0.0, 1.32, 1.55), "gunmetal_w", null, Vector3.ZERO, false)
	# an air-recognition panel, folded, on the turret roof behind the
	# commander's cupola, clear of the wind sensor's mast
	VehicleEquipment.recognition_panel(k, t, Vector3(0.55, 0.862, 1.0), Vector3.ZERO, true)
	# the crew's kit on the bare plate: aft of the remote station on the
	# left, and ahead of the loader's hatch beside the sight, clear of the
	# roof's seams
	VmCore.roof_kit(k, t, Vector3(-0.75, 0.862, 1.4), PI / 2, Vector2(0.5, 0.7), 0, Color(0.33, 0.35, 0.24))
	VmCore.roof_kit(k, t, Vector3(-0.7, 0.862, -1.35), PI / 2, Vector2(0.5, 0.8), 1, Color(0.33, 0.35, 0.24))
	# the bustle's stowage basket, the slat cage round it on its struts
	VehicleMounts.basket(k, t, Vector3(0, 0.24, 2.3), Vector3(2.6, 0.44, 0.5))
	VehicleCloth.roll(k, t, Vector3(-0.4, 0.44, 2.3), 0.17, 1.6, Z90, Color(0.33, 0.35, 0.24))
	k._bag(t, Vector3(0.6, 0.32, 0.38), Vector3(0.85, 0.44, 2.3), "canvas", Color(0.38, 0.37, 0.27))
	_slats(k, t, Vector3(0, 0.46, 2.8), 3.3, 0.78, true, 0.13, cam, col)
	for s: float in [-1.0, 1.0]:
		_slats(k, t, Vector3(s * 1.86, 0.46, 1.9), 1.8, 0.78, false, 0.13, cam, col)
		k._box(t, Vector3(0.22, 0.05, 0.05), Vector3(s * 1.74, 0.64, 1.1), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.05, 0.05, 0.3), Vector3(s * 1.4, 0.64, 2.65), "gunmetal_w", null, Vector3.ZERO, false)
	# a remote .50 over the loader's hatch
	_rcws(k, t, Vector3(-0.72, 0.86, 0.45), false, cam, col, 0.85)
	k.turret = t
	k.mg_tip = coax


## A bolt-on armour module's paint, [material, colour]: the vehicle's own,
## or for about one module in eight a replacement from depot stock in its
## plain factory paint, not yet camouflaged (from the kit seed at the
## module's place; scenery and wrecks keep the builders' one look).
static func _module_paint(k: VehicleModels, p: Node3D, at: Vector3, cam: String, col) -> Array:
	var rng := VehicleCargo.kit(k, p, at, 13)
	if rng == null or rng.randf() >= 0.125:
		return [cam, col]
	return ["paint", VehicleCargo.kit_colour(rng, MODULE_SPARE[rng.randi_range(0, MODULE_SPARE.size() - 1)], VehicleCargo.KIT_PAINT, 1.0)]


## Replacement modules' factory paints: a German olive, a darker green and a
## sand.
const MODULE_SPARE: Array[Color] = [Color(0.28, 0.31, 0.21), Color(0.22, 0.25, 0.18), Color(0.5, 0.45, 0.33)]


# --- Nyx: Rheinmetall Wiesel AWC tankette -----------------------------------------

## Wiesel: a tiny box on four road wheels a side, the long shallow glacis with
## the driver's hatch front-left and the engine grilles front-right, the
## weapon mount at the back of the roof. kind: "ac" (open 20 mm cannon
## mount), "at" (twin missile launcher and a .50), "aa" (two four-round
## Stinger-class pods and a .50) or "recon" (radar and a periscope mast).
static func _nyx(k: VehicleModels, team: int, kind: String, seed := 0) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	for s: float in [-1.0, 1.0]:
		_running_gear(k, s, 0.72, 0.26, [-0.95, -0.38, 0.19, 0.76], 0.19, Vector3(-1.42, 0.46, 0.18), Vector3(1.38, 0.38, 0.19), [-0.1], 0.53, 0.05, cam, col)
	# hull: the belly between the tracks, the upper hull over them with the
	# long glacis
	k._add(m, _block("indep_nyx_low", _oct(-0.55, 0.55, -1.38, 1.5, 0.06), _oct(-0.58, 0.58, -1.77, 1.76, 0.06), 0.28, 0.66, 0.03), cam, col, Vector3.ZERO)
	k._add(m, _armour([_ring(_oct(-0.91, 0.91, -1.775, 1.775, 0.04), 0.66), _ring(_oct(-0.91, 0.91, -1.7, 1.775, 0.04), 0.78), _ring(_oct(-0.88, 0.88, -0.92, 1.73, 0.04), 1.2)], "indep_nyx_up", 0.035), cam, col, Vector3.ZERO)
	var ga := Vector2(-1.7, 0.78)
	var gb := Vector2(-0.92, 1.2)
	# the driver's hatch and periscopes front-left, the engine grille on the
	# glacis front-right, the exhaust on the right flank
	VehicleFittings.panel_hatch(k, m, Vector3(-0.42, 1.22, -0.62), Vector3(0.48, 0.05, 0.5), cam, col)
	for i in 3:
		VehicleFittings.periscope(k, m, Vector3(-0.56 + i * 0.14, 1.21, -0.9), Vector3(0.12, 0.07, 0.05), Vector3(-0.5, 0, 0))
	_glacis_grille(k, m, 0.42, 0.72, ga, gb, 0.3, 0.92, cam, col, 5)
	# (the exhaust's heat shield in the hull's paint; a wreck keeps it bare)
	k._box(m, Vector3(0.1, 0.16, 0.45), Vector3(0.95, 0.98, -0.75), "gunmetal_w" if k.wreck else cam, null if k.wreck else col)
	VehicleFittings.exhaust(k, m, Vector3(0.98, 0.9, -0.94), Vector3.FORWARD, 0.12, 0.04, false)
	for s: float in [-1.0, 1.0]:
		# headlights with guards on the glacis corners, tow eyes, smoke
		# dischargers on the roof's front corners
		_light(k, m, Vector3(s * 0.7, 0.86, -1.72), 0.18, 0.09)
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.32, 0.6, -1.76), -1.0, Vector3(0.08, 0.1, 0.12), 0.04)
		_smoke(k, m, Vector3(s * 0.74, 1.22, -0.78), 3, s * -0.5, 0.5, 0.04)
		# a stowage box on each flank aft, tail lights, a jerrycan
		VehicleEquipment.storage(k, m, Vector3(s * 0.95, 0.98, 1.1), Vector3(0.1, 0.24, 0.6), cam, col, Vector3.ZERO)
		_light(k, m, Vector3(s * 0.7, 0.98, 1.79), 0.16, 0.08, 1.0, false, true)
	# rear: the crew door and its handle, the tow pintle, a jerrycan rack
	VehicleDoors.leaf(k, m, Vector3(0.7, 0.42, 0.05), Vector3(-0.08, 0.95, 1.79), cam, col, Vector3.ZERO, 2)
	VehicleDoors.lever(k, m, Vector3(0.18, 0.95, 1.815), Vector3.BACK, Vector3.DOWN, 0.1, 0.095)
	VehicleMounts.hitch(k, m, Vector3(0, 0.55, 1.8), Vector3(0.12, 0.1, 0.14))
	_jerrycan(k, m, Vector3(0.52, 0.6, 1.9), Color(0.3, 0.33, 0.23), PI / 2)
	_antenna(k, m, Vector3(0.72, 1.2, 1.55), 1.7)
	k._team_mark(m, team, Vector3(0.915, 0.95, 0.3), Vector3(0.03, 0.18, 0.5))
	k._team_mark(m, team, Vector3(-0.915, 0.95, 0.3), Vector3(0.03, 0.18, 0.5))
	VehicleMarkings.side_number(k, m, VehicleMarkings.tactical_number(seed, TAC), 0.17, Vector3(0.91, 0.7, 1.7), Vector3(0.91, 0.7, -0.9), Vector3(0.88, 1.18, -0.9), Vector3(0.88, 1.18, 1.7), Vector2(0.75, 0.48), VehicleMarkings.STENCIL_AAF)
	if kind == "recon":
		# the periscope mast, extended, at the back left
		k._box(m, Vector3(0.24, 0.1, 0.24), Vector3(-0.5, 1.25, 1.25), "gunmetal_w")
		VehicleMounts.mast_segment(k, m, Vector3(-0.5, 1.5, 1.25), 0.45, 0.08, cam, col)
		VehicleMounts.mast_segment(k, m, Vector3(-0.5, 1.92, 1.25), 0.45, 0.055, "gunmetal_w", null)
		VehicleMounts.mast_segment(k, m, Vector3(-0.5, 2.3, 1.25), 0.4, 0.04, "gunmetal_w", null)
		_sensor_head(k, m, Vector3(-0.5, 2.6, 1.25), cam, col, 0.55)
		# the radar: a flat array on a turning pedestal over its electronics
		var r := k._pivot(m, Vector3(0.1, 1.2, 0.2))
		k.turret = r
		VehicleMounts.turret_ring(k, r, Vector3(0, 0.04, 0), 0.3, 0.32, 0.08, "gunmetal_w", null, 14)
		k._box(r, Vector3(0.46, 0.22, 0.4), Vector3(0, 0.19, 0.05), cam, col)
		k._cyl(r, 0.06, 0.06, 0.2, Vector3(0, 0.38, 0), Vector3.ZERO, "gunmetal_w", null, 8)
		VehicleMounts.radar_array(k, r, Vector3(0.8, 0.46, 0.07), Vector3(0, 0.66, -0.02), cam, col, Vector3(0.25, 0, 0))
		k._box(r, Vector3(0.72, 0.38, 0.02), Vector3(0, 0.66, -0.065), "plain_dark", null, Vector3(0.25, 0, 0), false)
		k._box(r, Vector3(0.2, 0.12, 0.12), Vector3(0, 0.66, 0.08), "gunmetal_w")
		return
	# the weapon mount: a low armoured turntable at the back of the roof
	var t := k._pivot(m, Vector3(0, 1.2, 0.45))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.04, 0), 0.5, 0.52, 0.08, "gunmetal_w", null, 16)
	k._add(t, _armour([_ring(_oct(-0.42, 0.42, -0.5, 0.45, 0.14), 0.0), _ring(_oct(-0.36, 0.36, -0.38, 0.4, 0.12), 0.3)], "indep_nyx_mount", 0.03), cam, col, Vector3(0, 0.08, 0))
	# the roof plate welded onto the mount's sloped plates: the bead down the
	# middle of its ground-off edge (the smooth cast-looking cone had no plate
	# edge to catch the light); a wreck keeps the plain one
	if not k.wreck:
		var rim := Array(_ring(_oct(-0.348, 0.348, -0.371, 0.3875, 0.115), 0.365))
		rim.append(rim[0])
		VehicleBody.bead(k, t, rim, 0.01, cam, col, 4, false)
	match kind:
		"ac":
			# the Rh 202 in its cradle on top, ammunition boxes either side, a sight
			VehicleMounts.mantlet(k, t, Vector3(0.26, 0.2, 0.66), Vector3(-0.04, 0.47, -0.08), cam, col)
			VehicleMounts.receiver(k, t, Vector3(0.18, 0.18, 0.84), Vector3(-0.04, 0.6, -0.02))
			VehicleWeapons.autocannon(k, t, Vector3(-0.04, 0.58, -0.42), Vector3(-0.04, 0.58, -2.36), Vector2(0.06, 0.4), Vector2(0.032, 0.032), Vector2(0.05, 0.16))
			k.mg_tip = k._tip(t, Vector3(-0.04, 0.58, -2.38))
			for s: float in [-1.0, 1.0]:
				k._box(t, Vector3(0.16, 0.24, 0.38), Vector3(-0.04 + s * 0.22, 0.56, 0.1), "paint", Color(0.3, 0.33, 0.23))
			VehicleMounts.sight(k, t, Vector3(0.3, 0.5, -0.28), Vector3(0.16, 0.18, 0.24), [Rect2(Vector2(0, 0.02), Vector2(0.1, 0.08))], cam, col)
			k._cyl(t, 0.2, 0.2, 0.05, Vector3(0.18, 0.4, 0.25), Vector3.ZERO, cam, col, 12)
		"at":
			# a twin launcher for the fire-and-forget missiles on the left, a
			# sight head in the middle, the .50 on the right
			k._box(t, Vector3(0.1, 0.32, 0.3), Vector3(-0.3, 0.46, 0.0), cam, col)
			for i in 2:
				var lx := -0.44 - i * 0.2
				VehicleWeapons.launch_tube(k, t, Vector3(lx, 0.58, -0.1), 0.08, 1.1, "paint", Color(0.33, 0.35, 0.26), Color(0.3, 0.32, 0.24))
			k._box(t, Vector3(0.44, 0.04, 0.6), Vector3(-0.54, 0.68, -0.1), "gunmetal_w", null, Vector3.ZERO, false)
			k.gun_tip = k._tip(t, Vector3(-0.54, 0.58, -0.72))
			_sensor_head(k, t, Vector3(0.0, 0.62, -0.15), cam, col, 0.6)
			_nyx_m2(k, t, Vector3(0.36, 0.48, 0.0), cam, col)
		"aa":
			# two four-round pods either side of the sight head, the .50
			# under the left one
			_sensor_head(k, t, Vector3(0.0, 0.58, -0.12), cam, col, 0.65)
			k._cyl(t, 0.04, 0.04, 1.05, Vector3(0, 0.62, 0.05), Z90, "gunmetal_w", null, 8)
			for s: float in [-1.0, 1.0]:
				# each pod is lugged to the cross tube on its inboard face
				var px: float = s * 0.52
				VehicleWeapons.missile_box(k, t, Vector3(px, 0.62, -0.1), Vector3(0.3, 0.3, 1.45), 2, 2, 0.055, cam, col, Vector3.ZERO, false, Vector3(-s, 0, 0), Vector2(0.14, 0.14))
			k.gun_tip = k._tip(t, Vector3(0.52, 0.62, -0.86))
			_nyx_m2(k, t, Vector3(-0.52, 0.32, -0.05), cam, col)
	_smoke(k, t, Vector3(0.0, 0.38, 0.42), 2, PI, 0.5, 0.04)


## The Nyx's .50 cal, drawn a size down to suit the little tankette, on a
## small cradle with its ammunition box on the right. Sets k.mg_tip.
static func _nyx_m2(k: VehicleModels, p: Node3D, pos: Vector3, cam: String, col) -> void:
	k._box(p, Vector3(0.18, 0.12, 0.4), pos + Vector3(0, -0.08, 0.05), cam, col)
	VehicleWeapons.hmg(k, p, pos + Vector3(0, 0.04, 0.02), pos + Vector3(0, 0.04, -1.32), 0.8, 1.0, false, "gunmetal_w", Color(0.3, 0.33, 0.23))
	k.mg_tip = k._tip(p, pos + Vector3(0, 0.04, -1.32))


# --- Gorgon: Pandur II 8x8 ----------------------------------------------------------

## Pandur II 8x8: a flat-sided box overhanging eight wheels (the gap between
## the second and third axles), the sloped bow with the trim vane folded on
## it, the driver front-left and the engine front-right, the big rear door;
## a low turret aft of centre with the 30 mm cannon and a Titan tube on
## each side.
static func _gorgon(k: VehicleModels, team: int, seed := 0) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	var wr := 0.56
	var axles := [-2.3, -0.92, 0.98, 2.36]
	# the V-shaped belly between the wheels, the upper hull over them
	k._add(m, _block("indep_gorg_low", _oct(-0.6, 0.6, -3.1, 3.35, 0.1), _oct(-0.88, 0.88, -3.72, 3.7, 0.1), 0.45, 1.2, 0.04), cam, col, Vector3.ZERO)
	k._add(m, _armour([_ring(_oct(-1.335, 1.335, -3.72, 3.72, 0.08), 1.2), _ring(_oct(-1.335, 1.335, -3.06, 3.72, 0.08), 1.85), _ring(_oct(-1.17, 1.17, -2.84, 3.66, 0.08), 2.08)], "indep_gorg_up", 0.05), cam, col, Vector3.ZERO)
	for s: float in [-1.0, 1.0]:
		for z in axles:
			k._wheel(m, Vector3(s * 1.1, wr, z), wr, 0.42, cam, col)
			# the wheel well's dark liner under the overhang
			k._box(m, Vector3(0.03, 0.4, 1.2), Vector3(s * 0.885, 0.95, z), "plain_dark", null, Vector3.ZERO, false)
		# mud flaps behind the first and last axles
		for z: float in [-1.6, 3.0]:
			VehicleFittings.mudflap(k, m, Vector3(s * 1.1, 0.98, z), Vector2(0.36, 0.3))
	# the lower side plates down between the wheels, under the upper hull's
	# overhang, an arch over each wheel
	VmCore.wheel_wells(k, m, "indep_gorg_wells", 1.315, 1.35, 0.74, 1.21, -3.5, 3.5, axles, wr, wr + 0.12, 0.86, cam, col)
	for s: float in [-1.0, 1.0]:
		# the hull's side: a chine strake at mid height, stowage boxes aft,
		# the side's lifting eyes
		k._box(m, Vector3(0.05, 0.06, 7.2), Vector3(s * 1.345, 1.84, 0.0), cam, col)
		VehicleEquipment.storage(k, m, Vector3(s * 1.41, 1.5, 1.7), Vector3(0.16, 0.42, 1.0), cam, col, Vector3.ZERO)
		k._box(m, Vector3(0.02, 0.04, 0.95), Vector3(s * 1.495, 1.62, 1.7), "gunmetal_w", null, Vector3.ZERO, false)
		VehicleEquipment.storage(k, m, Vector3(s * 1.41, 1.5, -1.62), Vector3(0.16, 0.42, 0.7), cam, col, Vector3.ZERO)
		# headlight clusters with guards at the bow's corners, tow eyes
		_light(k, m, Vector3(s * 1.1, 1.6, -3.32), 0.28, 0.13)
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.62, 1.08, -3.66), -1.0, Vector3(0.12, 0.16, 0.2), 0.05)
		# rear: tail lights, tow eyes, a whip antenna on each corner
		_light(k, m, Vector3(s * 1.1, 1.75, 3.74), 0.22, 0.1, 1.0, false, true)
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.75, 1.0, 3.72), 1.0, Vector3(0.12, 0.16, 0.2), 0.05)
		_antenna(k, m, Vector3(s * 1.0, 2.08, 3.3), 2.4)
	# the bow: the trim vane folded on the glacis on its hinges, latched at
	# the top; it stands 3.5 cm off the plate, on the old plate's inner face
	var ga := Vector2(-3.72, 1.2)
	var gb := Vector2(-3.06, 1.85)
	var gd := (gb - ga).normalized()
	var off := Vector2(-gd.y, gd.x) * 0.035
	var vh := ga.lerp(gb, 0.12) + off
	var vt := ga.lerp(gb, 0.92) + off
	VehicleMounts.trim_vane(k, m, Vector3(0, vh.y, vh.x), Vector3(0, vt.y, vt.x), 2.2, 0.05, Vector3(0, gd.x, -gd.y), cam, col)
	# roof: the driver's hatch and periscopes front-left, a mirror; the engine
	# grille front-right; the exhaust on the right flank
	VehicleFittings.panel_hatch(k, m, Vector3(-0.62, 2.1, -2.35), Vector3(0.6, 0.06, 0.62), cam, col)
	for i in 3:
		VehicleFittings.periscope(k, m, Vector3(-0.8 + i * 0.18, 2.09, -2.72), Vector3(0.15, 0.08, 0.06), Vector3(-0.4, 0, 0))
	VehicleFittings.mirror(k, m, Vector3(-1.46, 1.96, -2.95), Vector2(0.15, 0.24), 0.3, [Vector3(-1.15, 1.92, -2.95)])
	VehicleFittings.grille(k, m, Vector3(0.62, 2.11, -2.1), Vector2(0.95, 1.15), Vector3(-PI / 2, 0, 0), cam, col, 5)
	# an air-recognition panel folded on the roof behind the driver's hatch,
	# beside the engine grille and clear of the turret's sweep
	VehicleEquipment.recognition_panel(k, m, Vector3(-0.56, 2.082, -1.62), Vector3.ZERO, true)
	# the exhaust's housing on the flank, its louvres on the outer face, the
	# soot streaked back from it as far as the forward bin
	k._box(m, Vector3(0.1, 0.34, 0.55), Vector3(1.38, 1.55, -2.55), "gunmetal_w")
	VehicleFittings.grille(k, m, Vector3(1.46, 1.55, -2.55), Vector2(0.55, 0.34), Vector3(0, PI / 2, 0), cam, col, 3)
	VehicleBody.soot(k, m, Vector3(1.335, 1.55, -2.275), Vector3.BACK, Vector3.UP, Vector3.RIGHT, 0.6, 0.32)
	# the troop compartment's roof hatches, aft, hinged at the back
	for s: float in [-1.0, 1.0]:
		VehicleFittings.panel_hatch(k, m, Vector3(s * 0.5, 2.1, 2.55), Vector3(0.66, 0.06, 0.8), cam, col, 1.0)
	# a camouflage net rolled across the roof behind the hatches
	VehicleCloth.roll(k, m, Vector3(0, 2.2, 3.3), 0.12, 1.5, Z90, Color(0.33, 0.35, 0.24))
	# the rear door: vision block, handle, hinges; a step under it. (The door
	# is in the upright back plate, its sill where the lower plate starts to
	# slope away under it: run on down, its foot hung 15 cm off that plate.)
	var sill := 0.875 if k.wreck else 1.17
	VehicleDoors.leaf(k, m, Vector3(1.1, 2.125 - sill, 0.08), Vector3(0.1, (2.125 + sill) * 0.5, 3.74), cam, col, Vector3.ZERO, 2)
	VehicleGlazing.rectangle(k, m, Vector2(0.2, 0.12), Vector3(0.1, 1.85, 3.79), Vector3.ZERO, false, null, 0.03)
	VehicleDoors.lever(k, m, Vector3(0.5, 1.45, 3.78), Vector3.BACK, Vector3.DOWN, 0.12, 0.12, 0.025)
	for hy: float in ([1.1, 1.9] if k.wreck else [1.34, 1.9]):
		VehicleDoors.hinge(k, m, Vector3(-0.45, hy, 3.78), Vector3.BACK, Vector3.UP, 0.028, cam, col)
	# (the tread held level by a stay at each end, back under it to the
	# sloping lower plate: 15 cm behind the plate, it hung in the air)
	VehicleFrames.step(k, m, Vector3(0.1, 0.82, 3.8), Vector2(0.9, 0.25), Vector3.ZERO, "gunmetal_w")
	for x: float in ([] if k.wreck else [-0.3, 0.5]):
		VehicleFrames.beam(k, m, Vector3(x, 0.805, 3.89), Vector3(x, 0.58, 3.41), 0.04, 0.012, "gunmetal_w")
	k._team_mark(m, team, Vector3(1.345, 1.45, 0.3), Vector3(0.03, 0.26, 0.7))
	k._team_mark(m, team, Vector3(-1.345, 1.45, 0.3), Vector3(0.03, 0.26, 0.7))
	# the tactical number on each flank, between the forward bin and the panel
	VehicleMarkings.side_number(k, m, VehicleMarkings.tactical_number(seed, TAC), 0.38, Vector3(1.335, 1.2, 3.0), Vector3(1.335, 1.2, -3.0), Vector3(1.335, 1.85, -3.0), Vector3(1.335, 1.85, 3.0), Vector2(0.603, 0.46), VehicleMarkings.STENCIL_AAF)
	# the turret: low and faceted, the 30 mm in its mantlet with the coax
	# beside it, a Titan tube on each side
	var t := k._pivot(m, Vector3(0, 2.08, 0.3))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.03, 0.05), 0.92, 0.94, 0.06, "gunmetal_w", null, 20)
	var tb := [-0.5, -1.12, 0.5, -1.12, 0.96, -0.7, 1.0, 0.78, 0.8, 1.08, -0.8, 1.08, -1.0, 0.78, -0.96, -0.7]
	var tt := [-0.4, -0.86, 0.4, -0.86, 0.8, -0.55, 0.85, 0.7, 0.66, 0.94, -0.66, 0.94, -0.85, 0.7, -0.8, -0.55]
	k._add(t, _armour([_ring(tb, 0.05), _ring(tt, 0.58)], "indep_gorg_tur", 0.05), cam, col, Vector3.ZERO)
	VehicleMounts.mantlet(k, t, Vector3(0.42, 0.34, 0.32), Vector3(0, 0.32, -1.12), cam, col)
	VehicleWeapons.autocannon(k, t, Vector3(0, 0.32, -1.25), Vector3(0, 0.32, -4.4), Vector2(0.085, 0.5), Vector2(0.05, 0.05), Vector2(0.075, 0.2))
	k.mg_tip = k._tip(t, Vector3(0, 0.32, -4.42))
	VehicleWeapons.coax(k, t, Vector3(0.26, 0.24, -1.3), 0.4, 0.02)
	for s: float in [-1.0, 1.0]:
		# the Titan tube on its bracket
		k._box(t, Vector3(0.22, 0.12, 0.3), Vector3(s * 0.98, 0.36, -0.15), "gunmetal_w")
		VehicleWeapons.launch_tube(k, t, Vector3(s * 1.1, 0.44, -0.2), 0.09, 1.3, "paint", Color(0.33, 0.35, 0.26), Color(0.3, 0.32, 0.24))
		# smoke dischargers on the front corners
		_smoke(k, t, Vector3(s * 0.82, 0.48, -0.66), 3, s * -0.6, 0.5, 0.045)
	k.gun_tip = k._tip(t, Vector3(-1.1, 0.44, -0.9))
	# roof: the gunner's sight front-left, the commander's panoramic sight
	# right, his hatch behind it
	VehicleMounts.sight(k, t, Vector3(-0.4, 0.68, -0.48), Vector3(0.3, 0.24, 0.36), [Rect2(Vector2(0, 0.02), Vector2(0.22, 0.13))], cam, col)
	VehicleMounts.sight(k, t, Vector3(0.5, 0.82, -0.15), Vector3(0.3, 0.18, 0.26), [Rect2(Vector2(0, 0.01), Vector2(0.2, 0.09))], cam, col, Vector3(0.06, 0.07, 0.24))
	VehicleFittings.hatch(k, t, Vector3(0.35, 0.61, 0.5), 0.28, cam, col, 1.0, 0.06)
	VehicleFittings.panel_hatch(k, t, Vector3(-0.35, 0.6, 0.45), Vector3(0.5, 0.05, 0.5), cam, col)
	_antenna(k, t, Vector3(-0.6, 0.58, 0.8), 1.9)
	# a stowage basket on the turret's back, a bag in its left half and the
	# crew's kit in the right (half a basket of bare wire read as empty)
	VehicleMounts.basket(k, t, Vector3(0, 0.2, 1.2), Vector3(1.4, 0.3, 0.4))
	VmCore.roof_kit(k, t, Vector3(0.38, 0.215, 1.2), PI / 2, Vector2(0.34, 0.6), 0, Color(0.33, 0.35, 0.24))
	k._bag(t, Vector3(0.7, 0.24, 0.3), Vector3(-0.3, 0.34, 1.2), "canvas", Color(0.36, 0.36, 0.26))


# --- Zamak: KamAZ-4310 6x6 -------------------------------------------------------

## The Zamak's axles: one at the front, two in tandem at the back.
const ZK_AXLES := [-2.45, 0.9, 2.22]


## Zamak trucks: the shared chassis and bonneted cab, then the body for
## `kind`. Rebel-captured ones (team 1) wear khaki.
static func _zamak(k: VehicleModels, team: int, kind: String, seed: int) -> void:
	var pc := _paint(team, true)
	var cam: String = pc[0]
	var col = pc[1]
	var tarp := Color(0.37, 0.39, 0.27) if team != 1 else Color(0.5, 0.46, 0.34)
	_zamak_cab(k, team, cam, col)
	match kind:
		"zamak":
			_zamak_bed(k, cam, col, 0.55)
			_zamak_tilt(k, VehicleCargo.tilt_colour(k, k.root, tarp))
		"zamak_cargo":
			_zamak_bed(k, cam, col, 0.55)
			_zamak_cargo(k, tarp, seed)
		"zamak_ammo":
			_zamak_bed(k, cam, col, 0.45)
			_zamak_ammo(k, tarp)
		"zamak_repair":
			_zamak_bed(k, cam, col, 0.0)
			_zamak_repair(k, cam, col)
		"zamak_medical":
			_zamak_bed(k, cam, col, 0.0)
			_zamak_medical(k, cam, col)
		"zamak_fuel":
			_zamak_fuel(k, cam, col)
		"zamak_mrl":
			_zamak_bed(k, cam, col, 0.0)
			_zamak_mrl(k, cam, col)


## KamAZ-4310 running gear and cab: ladder chassis on three axles of big
## single tyres (tandem bogie at the back), the protruding engine bonnet
## with its grille, flat-topped wings carrying round headlights, the
## squared-off cab with a split windscreen, the spare wheel upright behind it.
static func _zamak_cab(k: VehicleModels, team: int, cam: String, col) -> void:
	var m := k.root
	# chassis rails and cross members, axles with their differentials, springs
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.1, 0.08, 1.3), Vector3(s * 0.6, 0.8, -2.45), "gunmetal_w")
		k._box(m, Vector3(0.12, 0.14, 1.9), Vector3(s * 0.62, 0.78, 1.56), "gunmetal_w")
		k._cyl(m, 0.13, 0.13, 0.22, Vector3(s * 0.62, 0.84, 1.56), Z90, "gunmetal_w", null, 10)
		for z in ZK_AXLES:
			k._wheel(m, Vector3(s * 1.03, 0.6, z), 0.6, 0.42, cam, col)
		# mud flaps behind the front wheel and the bogie
		for z: float in [-1.78, 2.9]:
			VehicleFittings.mudflap(k, m, Vector3(s * 1.03, 0.82, z), Vector2(0.44, 0.42))
	VehicleRunningGear.frame(k, m, Vector3(0, 1.0, 0.1), 0.48, 7.2, Vector2(0.14, 0.22), [-3.3, -1.0, 0.2, 1.56, 3.55])
	for z: float in ZK_AXLES:
		VehicleRunningGear.axle(k, m, Vector3(0, 0.6, z), 1.7, 0.08)
	# the bonnet: louvres down its sides, the grille in front
	k._add(m, _armour([_ring(_oct(-0.6, 0.6, -3.62, -2.12, 0.08), 1.12), _ring(_oct(-0.5, 0.5, -3.48, -2.12, 0.14), 1.84)], "indep_zk_bonnet", 0.035), cam, col, Vector3.ZERO)
	VehicleFittings.grille(k, m, Vector3(0, 1.48, -3.62), Vector2(0.92, 0.65), Vector3(-0.20, PI, 0), cam, col, 7, true)
	k._box(m, Vector3(0.9, 0.03, 0.04), Vector3(0, 1.84, -2.2), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.03, 0.02, 1.3), Vector3(0, 1.845, -2.85), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		VehicleBody.panel(k, m, Vector3(s * 0.57, 1.54, -2.75), Vector2(0.62, 0.42), Vector3(0, s * PI / 2, s * 0.14), cam, col, true)
		# the wing over the front wheel: flat top, raked front, a valance
		var fx: float = s * 0.93
		VehicleBody.fender(k, m, Vector3(fx, 1.42, -2.56), Vector3(0.68, 0.05, 1.12), s, cam, col, Vector3.ZERO, 0.2)
		_plate(k, m, fx, 0.68, Vector2(-3.42, 1.02), Vector2(-3.12, 1.42), 0.05, cam, col, -0.025)
		_plate(k, m, fx, 0.68, Vector2(-2.0, 1.42), Vector2(-1.86, 1.2), 0.05, cam, col, -0.025)
		# a round headlight on the wing's front, the sidelight on top of it
		_round_light(k, m, Vector3(s * 0.88, 1.24, -3.34), 0.1)
		VehicleFittings.marker(k, m, Vector3(s * 1.12, 1.47, -3.0), Vector3(0.1, 0.06, 0.08), 2.0, Color(0.62, 0.45, 0.12))
	# the bumper with its tow hooks and plate
	VehicleMounts.bumper(k, m, Vector3(2.42, 0.22, 0.2), Vector3(0, 0.95, -3.72), cam, col)
	for s: float in [-1.0, 1.0]:
		VehicleFittings.tow_shackle(k, m, Vector3(s * 0.72, 0.88, -3.85), -1.0, Vector3(0.1, 0.16, 0.12), 0.05)
	VehicleMarkings.plate(k, m, Vector3(0, 0.96, -3.83), Vector2(0.5, 0.12), Vector3.FORWARD, 0.0, "", 0.02, Color(0.82, 0.8, 0.72), VehicleMarkings.PLATE_INK, false)
	# the cab: vertical lower half, the glasshouse leaning in a little
	k._add(m, VehicleModels.solid([_ring(_oct(-1.2, 1.2, -2.15, -0.72, 0.08), 1.22), _ring(_oct(-1.2, 1.2, -2.15, -0.72, 0.08), 2.0)], "indep_zk_open_cab"), cam, col, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		VehicleDoors.rectangle(k, m, Vector3(side * 1.21, 1.63, -1.59), Vector2(0.80, 0.48), Vector3(0, side * PI / 2, 0), cam, col)
	VehicleCab.upper(k, Vector2(1.2, 1.12), Vector2(2.0, 2.72), Vector2(-2.15, -2.0), -0.76, cam, col)
	var wa := Vector2(-2.15, 2.0)
	var wb := Vector2(-2.0, 2.72)
	for s: float in [-1.0, 1.0]:
		VehicleFittings.wiper(k, m, Vector3(s * 0.5, 2.09, -2.15), Vector3(s * 0.5, 2.39, -2.09), Vector3.RIGHT, Vector3(0, 0.2, -1), 0.38)
	_plate(k, m, 0.0, 0.1, wa.lerp(wb, 0.05), wa.lerp(wb, 0.95), 0.035, cam, col, 0.0)
	for s: float in [-1.0, 1.0]:
		# the door's shut lines up the lower cab to the window line, the step
		# and grab handle, the mirror on its arm
		for dz: float in [-2.04, -1.13]:
			VehicleBody.seam(k, m, [Vector3(s * 1.2, 2.0, dz), Vector3(s * 1.2, 1.23, dz)], 0.01)
		VehicleFrames.step(k, m, Vector3(s * 1.12, 0.92, -1.58), Vector2(0.32, 0.44))
		k._box(m, Vector3(0.04, 0.34, 0.04), Vector3(s * 1.2, 1.1, -1.38), "gunmetal_w", null, Vector3.ZERO, false)
		VehicleFittings.mirror(k, m, Vector3(s * 1.56, 2.22, -2.1), Vector2(0.22, 0.36), -s * 0.3, [Vector3(s * 1.23, 2.32, -2.1), Vector3(s * 1.23, 1.75, -2.1)])
		k._team_mark(m, team, Vector3(s * 1.205, 1.65, -1.6), Vector3(0.03, 0.24, 0.5))
	# the roof hatch and marker lights, an antenna on the back corner
	VehicleFittings.hatch(k, m, Vector3(0.42, 2.745, -1.35), 0.3, cam, col, 1.0, 0.05)
	for x: float in [-0.3, 0.0, 0.3]:
		VehicleFittings.marker(k, m, Vector3(x, 2.74, -1.94), Vector3(0.06, 0.05, 0.09), 2.0, Color(0.62, 0.45, 0.12))
	_antenna(k, m, Vector3(-1.0, 2.72, -0.86), 1.6)
	# a camouflage net bundled on the cab roof between the hatch and the
	# antenna, by a crew that camouflages its truck (VehicleCloth.camouflage)
	var net_at := Vector3(-0.42, 2.72, -1.3)
	var rng := VehicleCargo.kit(k, m, net_at, 17)
	var camo := VehicleCloth.camouflage(k)
	if rng != null and camo > 0.0 and rng.randf() < camo + 0.2:
		VehicleCloth.roof_net(k, m, net_at, Vector3(0.78, rng.randf_range(0.1, 0.17), 0.72), Vector3(0, rng.randf_range(-0.2, 0.2), 0), rng)
	else:
		# or, in its place, an air-recognition panel folded on the roof
		VehicleEquipment.recognition_panel(k, m, Vector3(-0.42, 2.765, -1.3), Vector3.ZERO, true)
	# behind the cab: the spare wheel upright in its frame, the air intake,
	# the fuel tank on the left and the battery box on the right
	VehicleWheels.spare(k, m, Vector3(0, 1.74, -0.5), 0.6, 0.4, X90, cam, col)
	VehicleWheels.carrier(k, m, Vector3(0, 1.74, -0.5), 0.6, 0.4, X90, "cradle", Vector3(0, 1.11, -0.5))
	# the air cleaner canister strapped to the cab's back, its pre-cleaner on top
	VehicleFittings.air_cleaner(k, m, Vector3(0.95, 1.85, -0.52), 0.17, 0.9, cam, col, Vector2(0.2, 0.08), Vector3.FORWARD)
	VehicleRunningGear.fuel_tank(k, m, Vector3(-0.98, 0.95, -0.18), Vector3(0.52, 0.52, 0.85), -1.0, cam, col)
	# the battery box's catches face outboard, its lid hinged on the frame side
	VehicleEquipment.storage(k, m, Vector3(0.98, 0.95, -0.18), Vector3(0.6, 0.4, 0.42), cam, col, Vector3(0, -PI / 2, 0))
	# the exhaust's silencer under the right side of the cab
	VehicleFittings.silencer(k, m, Vector3(0.78, 0.8, -1.35), Vector3(0.2, 0.2, 0.6), "metal_dark")
	# Sandbags laid on the front wings over the wheels on some, a third on
	# top, where a mine under the front wheel blows up through the wing into
	# the cab (as convoy drivers have done since Vietnam and Afghanistan); the
	# Rebels' captured trucks more often than the army's.
	var lot := VehicleCloth.sack_lot(k)
	var bags := VehicleCargo.kit(k, m, Vector3(0, 1.445, -2.58), 43)
	if bags != null and bags.randf() < (0.5 if team == 1 else 0.25):
		for s: float in [-1.0, 1.0]:
			VehicleCloth.sandbags(k, m, Vector3(s * 0.93, 1.445, -2.96), Vector3(s * 0.93, 1.445, -2.2), bags, lot, 2 if bags.randf() < 0.6 else 1)


## The flatbed on the chassis, on its runners; `sides` > 0 gives it dropsides
## that high on five stake posts a side, a headboard and a tailgate (a flat
## deck keeps the posts' pockets). Tail lights, bumper and pintle under the back.
static func _zamak_bed(k: VehicleModels, cam: String, col, sides: float) -> void:
	var m := k.root
	VehicleCargo.flatbed(k, m, -0.25, 3.8, 2.5, 1.44, cam, col, sides, 5, sides + 0.25 if sides > 0.0 else 0.0, 0.0, 0.12, "", null, Vector3(0.48, 0.14, 0.16))
	# under the back: tail lights on their brackets, the bumper bar, pintle, plate
	for s: float in [-1.0, 1.0]:
		_light(k, m, Vector3(s * 0.98, 1.16, 3.74), 0.24, 0.1, 1.0, false, true)
	VehicleMounts.bumper(k, m, Vector3(2.0, 0.1, 0.1), Vector3(0, 0.82, 3.72), "gunmetal_w")
	VehicleMounts.hitch(k, m, Vector3(0, 0.98, 3.74), Vector3(0.14, 0.14, 0.2))
	VehicleMarkings.plate(k, m, Vector3(0, 1.18, 3.79), Vector2(0.44, 0.12), Vector3.BACK, 0.0, "", 0.02, Color(0.82, 0.8, 0.72), VehicleMarkings.PLATE_INK, false)


## Troop transport: a canvas tilt over hoops, the back flap rolled up.
static func _zamak_tilt(k: VehicleModels, tarp: Color) -> void:
	var m := k.root
	# (the hoops show as the ridges the cover sags from, and its hem is laced
	# to the bed's hooks, both the canopy's own)
	# The back: the flap rolled up under the roof over the dark inside and the
	# benches, or on some trucks let down and laced shut.
	var flap := VehicleCargo.kit(k, m, Vector3(0, 2.72, 3.72), 18)
	var shut := flap != null and not k.wreck and flap.randf() < 0.3
	VehicleCloth.canopy(k, m, [Vector2(-1.27, 1.9), Vector2(-1.27, 2.6), Vector2(-1.03, 2.88), Vector2(1.03, 2.88), Vector2(1.27, 2.6), Vector2(1.27, 1.9)], [-0.2, 0.45, 1.25, 2.05, 2.85, 3.62, 3.72], tarp, shut)
	if k.wreck:
		# (a wreck's tilt keeps its old fitted panels, and so the hoops over
		# them and the lashing bar along the bottom)
		var rib := tarp.darkened(0.18)
		for z: float in [0.45, 1.25, 2.05, 2.85, 3.62]:
			k._box(m, Vector3(2.08, 0.035, 0.07), Vector3(0, 2.895, z), "canvas_white", rib, Vector3.ZERO, false)
			for s: float in [-1.0, 1.0]:
				k._box(m, Vector3(0.035, 0.68, 0.07), Vector3(s * 1.285, 2.25, z), "canvas_white", rib, Vector3.ZERO, false)
				k._box(m, Vector3(0.035, 0.37, 0.07), Vector3(s * 1.165, 2.75, z), "canvas_white", rib, Vector3(0, 0, s * 0.69), false)
	# the hooks the cord is laced round, along the bed's top rail
	for s: float in [-1.0, 1.0]:
		if k.wreck:
			k._box(m, Vector3(0.03, 0.03, 3.9), Vector3(s * 1.285, 1.93, 1.76), "plain_dark", null, Vector3.ZERO, false)
			for i in 8:
				k._box(m, Vector3(0.02, 0.12, 0.02), Vector3(s * 1.285, 1.86, -0.05 + i * 0.52), "plain_dark", null, Vector3.ZERO, false)
		else:
			k._box(m, Vector3(0.03, 0.03, 3.9), Vector3(s * 1.285, 1.82, 1.76), "plain_dark", null, Vector3.ZERO, false)
	var back := 3.725 if not shut else 3.6
	# (past the rolled flap the tilt's own dim inside shows, and the benches
	# under it; a wreck keeps its dark board)
	if k.wreck:
		k._box(m, Vector3(2.36, 0.62, 0.02), Vector3(0, 2.27, back), "plain_dark", null, Vector3.ZERO, false)
	if not shut:
		VehicleCloth.roll(k, m, Vector3(0, 2.72, 3.76), 0.11, 2.3, Z90, tarp.darkened(0.1), "canvas_white")
	# The roll's ties and the shut flap's lacing straps are webbing, the dark
	# olive of the roll's own straps (a wreck's keep their old dark bars).
	var tie := tarp.darkened(0.1).darkened(0.35)
	for s: float in [-1.0, 1.0]:
		# (the board's battens: gone with it)
		if k.wreck:
			k._box(m, Vector3(0.4, 0.05, 0.03), Vector3(s * 0.8, 2.05, back + 0.005), "wood_dark", null, Vector3.ZERO, false)
		# the roll's ties, or the shut flap's lacing straps
		if k.wreck:
			if shut:
				k._box(m, Vector3(0.03, 0.82, 0.02), Vector3(s * 0.55, 2.33, 3.73), "plain_dark", null, Vector3.ZERO, false)
			else:
				k._box(m, Vector3(0.03, 0.3, 0.03), Vector3(s * 0.55, 2.57, 3.79), "plain_dark", null, Vector3.ZERO, false)
		elif shut:
			# down the flap's face from the roof bow to the tailboard
			VehicleCloth.strap(k, m, [Vector3(s * 0.55, 2.74, 3.724), Vector3(s * 0.55, 1.92, 3.724)], 0.03, tie, Vector3.RIGHT)
		else:
			# the tails left hanging from the roll's buckled straps
			var x := s * 0.69
			VehicleCloth.strap(k, m, [Vector3(x, 2.66, 3.865), Vector3(x, 2.6, 3.868), Vector3(x, 2.43, 3.85)], 0.03, tie, Vector3.RIGHT)


## The Rebels' supply truck: drums, crates, a tarpaulined pile, sacks and
## jerrycans in the open bed (laid out by seed).
static func _zamak_cargo(k: VehicleModels, tarp: Color, seed: int) -> void:
	var m := k.root
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# two oil drums at the front left, a crate stack at the front right
	var drum: Color = [Color(0.25, 0.3, 0.22), Color(0.22, 0.26, 0.32), Color(0.4, 0.2, 0.14)][rng.randi() % 3]
	for z: float in [0.15, 0.78]:
		VehicleEquipment.drum(k, m, Vector3(-0.86, 1.88, z), 0.29, 0.88, Vector3.UP, "paint", drum, Vector3(0.1, 0, 0.12), 0.0, [], 14)
	VehicleCargo.crate_stack(k, m, Vector3(0.62, 1.44, 0.22), Vector3(0.95, 0.62, 0.72), Vector3i.ONE, "wood")
	VehicleCargo.crate_stack(k, m, Vector3(0.55, 2.06, 0.25), Vector3(0.7, 0.46, 0.6), Vector3i.ONE, "wood", null, 0.0, [], 0.12, Color(0.28, 0.26, 0.2), rng.randf_range(-0.2, 0.2))
	# the middle: a pile under a tarpaulin, lashed down
	VehicleCloth.load_cover(k, Vector3(0, 1.44, 1.825), Vector3(2.4, 0.94, 1.53), tarp)
	# the back: crates, sacks and jerrycans
	VehicleCargo.crate_stack(k, m, Vector3(-0.62, 1.44, 3.1), Vector3(0.82, 0.56, 0.58), Vector3i.ONE, "wood", null, 0.0, [], 0.12, Color(0.28, 0.26, 0.2), rng.randf_range(-0.12, 0.12))
	VehicleCargo.crate_stack(k, m, Vector3(-0.6, 2.0, 3.05), Vector3(0.6, 0.4, 0.5), Vector3i.ONE, "wood_dark", null, 0.0, [], 0.12, Color(0.28, 0.26, 0.2), rng.randf_range(-0.3, 0.3))
	# (grain sacks: woven bags filled soft, slumped one on another, their
	# sewn ends pinched; square boxes in their place read as crates)
	for i in 3:
		var sack := Vector3(0.5, 1.555 + i * 0.19, 2.95 + (i % 2) * 0.12)
		var turn := rng.randf_range(-0.4, 0.4)
		if k.wreck:
			k._add(m, VehicleCloth._shell(Vector3(0.55, 0.24, 0.36)), "canvas_white", Color(0.56, 0.5, 0.38).darkened(0.04 * i), sack, Vector3(0, turn, 0.04 * (i - 1)))
			var tie := Basis.from_euler(Vector3(0, turn, 0)) * Vector3(0.3, 0, 0)
			k._add(m, VehicleCloth._shell(Vector3(0.07, 0.1, 0.16)), "canvas_white", Color(0.5, 0.45, 0.33), sack + tie, Vector3(0, turn, 0))
		else:
			# (the sandbag's sack, a grain sack's size: rounded at its closed
			# end, its mouth tied off with an ear of cloth past the tie)
			k._add(m, VehicleCloth._sack(1 + 2 * (i % 2)), "canvas_white", Color(0.56, 0.5, 0.38).darkened(0.04 * i), sack - Vector3(0, 0.12, 0), Vector3(0, turn, 0.04 * (i - 1)), Vector3(1.1, 1.75, 1.3))
	# (three cans stood broad face to broad face against the tailgate, as a
	# crew packs them so they can't fall over: 17 cm thick, 5 cm apart; a
	# wreck's stand where they always stood)
	for i in 3:
		_jerrycan(k, m, Vector3(0.38 + i * 0.22, 1.44, 3.55), Color(0.3, 0.33, 0.23), PI / 2 if k.wreck else 0.0)


## Ammunition: palletised crates in stacks, strapped down, the front ones
## under a tarpaulin.
static func _zamak_ammo(k: VehicleModels, tarp: Color) -> void:
	var m := k.root
	var box := Color(0.3, 0.33, 0.22)
	for row in 3:
		var z := 0.4 + row * 1.13
		for s: float in [-1.0, 1.0]:
			var x: float = s * 0.6
			if row == 0:
				VehicleCargo.pallet(k, m, Vector3(x, 1.44, z), Vector2(1.05, 0.98))
				continue
			# three layers of boxes on the pallet, strapped twice, a stencilled
			# label on the outboard face
			VehicleCargo.crate_stack(k, m, Vector3(x, 1.44, z), Vector3(1.05, 0.82, 0.98), Vector3i(1, 3, 1), "paint", box, 0.1, [-0.25, 0.25], 0.0)
			k._box(m, Vector3(0.012, 0.05, 0.4), Vector3(x + s * 0.505, 1.66, z), "paint", Color(0.6, 0.52, 0.2), Vector3.ZERO, false)
	# the front stacks under a tarp, its rolled edge
	VehicleCloth.load_cover(k, Vector3(0, 1.54, 0.37), Vector3(2.46, 0.78, 1.18), tarp, false)
	k._cyl(m, 0.08, 0.08, 0.5, Vector3(1.0, 1.7, 3.5), Vector3.ZERO, "paint", Color(0.5, 0.12, 0.08), 10)


## A box body (kung) on the bed, z0..z1: chamfered corners and roof edge, its
## rails, roof vents and clearance markers. The sides stay plain for each
## body's windows, doors and lockers; any rear door is the body's own.
## (`_key` named the old lofted body's mesh; the shelter keys its own.)
static func _zamak_box(k: VehicleModels, cam: String, col, z0: float, z1: float, _key: String) -> void:
	VehicleCargo.shelter(k, k.root, z0, z1, 2.48, 1.44, 2.98, cam, col, Rect2(), 0, 0, 0.06, 0.06)


## Workshop truck: the box body with windows and a side door, a ladder up
## the back, the knuckle crane, generator and gas bottles on the open deck
## behind it.
static func _zamak_repair(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	_zamak_box(k, cam, col, -0.2, 2.85, "indep_zk_shop")
	for s: float in [-1.0, 1.0]:
		for z: float in [0.35, 1.5]:
			VehicleGlazing.rectangle(k, m, Vector2(0.62, 0.42), Vector3(s * 1.245, 2.35, z), Vector3(0, PI / 2, 0), false, null, 0.03)
			k._box(m, Vector3(0.05, 0.05, 0.7), Vector3(s * 1.25, 2.6, z), "gunmetal_w", null, Vector3.ZERO, false)
	# the side door on the right, hinged at its front edge, with its fold-down
	# step; a shuttered locker on the left
	VehicleCargo.body_door(k, m, Vector3(1.24, 2.15, 2.36), Vector2(0.72, 1.32), Vector3.RIGHT, 1, cam, col)
	VehicleFrames.step(k, m, Vector3(1.38, 1.3, 2.36), Vector2(0.36, 0.6), Vector3.ZERO, "gunmetal_w", null)
	# (braced from under its outer edge up to the body's bottom rail: alone it
	# stuck out from under the floor like a shelf)
	for z: float in ([] if k.wreck else [2.1, 2.62]):
		VehicleFrames.beam(k, m, Vector3(1.5, 1.285, z), Vector3(1.245, 1.45, z), 0.012, 0.04, "gunmetal_w")
	VehicleCargo.roller_shutter(k, m, Vector3(-1.24, 1.85, 2.35), Vector2(0.9, 0.7), Vector3.LEFT, cam, col)
	# a ladder from the open deck up the back of the body, over the roof edge
	VehicleCargo.rung_ladder(k, m, Vector3(-0.9, 1.44, 2.85), 3.23, Vector3.BACK, 0.3)
	# the crane on the deck: slewing ring, column, the boom folded forward
	# over the roof from its heel at the column's top, its luffing ram and
	# the hook hung under the boom's end. The column stands tall enough that
	# the folded boom clears the body's roof (2.98) and rear edge, and the ram
	# runs from the column's face up to the boom behind the body.
	var bc := Vector3(0.6, 3.24, 2.3)
	var ba := Basis.from_euler(Vector3(0.2, 0, 0)).z * 1.15
	VehicleMounts.crane(k, m, Vector3(0.6, 1.44, 3.35), bc + ba, bc - ba, Vector2(0.2, 0.22), cam, col, Vector3(0.26, 0.28, 0.24), Vector3.ZERO, Vector3(0.26, 1.37, 0.28), [Vector3(0.6, 2.62, 3.2), Vector3(0.6, 3.0, 2.93), 0.05], Vector3(0.6, 3.23, 1.08), Vector3.INF, Vector3(0.1, 0.24, 0.12), Color(0.6, 0.48, 0.12))
	# the generator with its cooling louvres, the gas bottles racked by the
	# bed's edge
	k._box(m, Vector3(0.75, 0.62, 0.5), Vector3(-0.42, 1.75, 3.45), "paint", Color(0.27, 0.3, 0.22))
	VehicleFittings.grille(k, m, Vector3(-0.5, 1.78, 3.705), Vector2(0.48, 0.4), Vector3.ZERO, "gunmetal_w", null, 4, true)
	VehicleEquipment.gas_bottle(k, m, [Vector3(-1.02, 1.97, 3.2), Vector3(-1.02, 1.97, 3.46)], 0.11, 1.05, [Color(0.42, 0.2, 0.14), Color(0.22, 0.27, 0.32)], Vector3.LEFT)


## Field ambulance: the box body with red crosses on white on both sides,
## the back doors and the roof; frosted windows, a step, an awning rolled up.
static func _zamak_medical(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	_zamak_box(k, cam, col, -0.2, 3.72, "indep_zk_med")
	# The red crosses are painted on white panels on the body, and stay on a
	# wreck.
	var white := Color(0.84, 0.83, 0.78)
	var red := Color(0.62, 0.08, 0.07)
	for s: float in [-1.0, 1.0]:
		VehicleMarkings.cross(k, m, Vector3(s * 1.252, 2.2, 1.95), Vector2(0.92, 0.92), Vector3(0, s * PI / 2, 0), white, red, 0.761, 0.239, 0.02, "paint", false, false)
		for z: float in [0.4, 3.15]:
			VehicleGlazing.rectangle(k, m, Vector2(0.6, 0.34), Vector3(s * 1.245, 2.4, z), Vector3(0, PI / 2, 0), false, null, 0.03)
	# the roof: a white panel with its cross, the rolled awning
	VehicleMarkings.cross(k, m, Vector3(0.2, 2.99, 1.9), Vector2(1.3, 1.3), Vector3(-PI / 2, 0, 0), white, red, 0.769, 0.231, 0.02, "paint", false, false)
	VehicleCloth.roll(k, m, Vector3(1.2, 2.84, 1.76), 0.09, 3.3, X90, Color(0.4, 0.4, 0.3))
	# the back: two doors with the cross across them, two steps hung under them
	VehicleCargo.body_door(k, m, Vector3(0, 2.15, 3.72), Vector2(2.0, 1.3), Vector3.BACK, 2, cam, col)
	VehicleMarkings.cross(k, m, Vector3(0, 2.25, 3.735), Vector2(0.8, 0.8), Vector3.ZERO, white, red, 0.75, 0.225, 0.02, "paint", false, false)
	VehicleFrames.step(k, m, Vector3(0, 1.28, 3.9), Vector2(0.9, 0.22), Vector3.ZERO, "gunmetal_w")
	VehicleFrames.step(k, m, Vector3(0, 1.02, 3.96), Vector2(0.9, 0.22), Vector3.ZERO, "gunmetal_w")
	# (their stringers lean in to the body's bottom rail and hang from it:
	# stopped short under the upper tread, the pair floated behind the box)
	for s: float in [-1.0, 1.0]:
		if k.wreck:
			k._box(m, Vector3(0.04, 0.36, 0.04), Vector3(s * 0.45, 1.15, 3.93), "gunmetal_w", null, Vector3.ZERO, false)
		else:
			VehicleFrames.beam(k, m, Vector3(s * 0.465, 0.97, 3.99), Vector3(s * 0.465, 1.46, 3.74), 0.03, 0.04, "gunmetal_w", null, false)


## Fuel tanker: the elliptical tank on its saddles with dished ends, manholes
## and a walkway on top, the pump cabinet behind with a hose reel, a ladder,
## hazard placards.
static func _zamak_fuel(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.16, 0.14, 4.0), Vector3(s * 0.48, 1.19, 1.775), "gunmetal_w")
	for z: float in [0.25, 1.5, 2.75]:
		k._box(m, Vector3(1.8, 0.2, 0.2), Vector3(0, 1.32, z), cam, col)
	VehicleEquipment.vessel(k, m, Vector3(0, 2.02, 1.5), Vector3(2.34, 1.44, 3.42), [-1.2, 0.0, 1.2], cam, col, false)
	# on top: the walkway beside the two manholes, fold-down rails either side
	VehicleEquipment.tanker_top(k, m, Vector3(0, 2.02, 1.5), Vector3(2.34, 1.44, 3.42), cam, col, Vector3(0.36, 2.9, -0.42), [0.75, 2.25], Vector2(0.62, 0.14), 0.22)
	for s: float in [-1.0, 1.0]:
		# hazard placards and the fire extinguisher by the cabinet
		k._box(m, Vector3(0.02, 0.32, 0.42), Vector3(s * 1.17, 2.02, 1.5), "paint", Color(0.7, 0.42, 0.12), Vector3.ZERO, false)
		k._cyl(m, 0.08, 0.08, 0.45, Vector3(s * 1.2, 1.75, 3.25), Vector3.ZERO, "paint", Color(0.5, 0.1, 0.08), 10)
	# the pump cabinet at the back: louvred doors over the outlets, a hazard
	# placard on the left leaf, the hose reel on top, and a ladder up its back
	# by the left leaf's hinges, clear of them and of the outlets
	VehicleEquipment.pump_cabinet(k, m, Vector3(0, 1.88, 3.48), Vector3(2.3, 1.05, 0.62), Vector3.BACK, cam, col)
	k._box(m, Vector3(0.34, 0.3, 0.02), Vector3(-0.62, 1.9, 3.82), "paint", Color(0.7, 0.42, 0.12), Vector3.ZERO, false)
	k._box(m, Vector3(1.2, 0.06, 0.5), Vector3(0.45, 2.43, 3.48), "gunmetal_w")
	VehicleFrames.hose_reel(k, m, Vector3(0.45, 2.7, 3.48), 0.26, 0.52)
	VehicleCargo.rung_ladder(k, m, Vector3(-0.95, 1.325, 3.79), 2.575, Vector3.BACK, 0.28)
	# under the back: tail lights, bumper, pintle
	for s: float in [-1.0, 1.0]:
		_light(k, m, Vector3(s * 0.98, 1.16, 3.74), 0.24, 0.1, 1.0, false, true)
	VehicleMounts.bumper(k, m, Vector3(2.0, 0.1, 0.1), Vector3(0, 0.82, 3.72), "gunmetal_w")
	VehicleMounts.hitch(k, m, Vector3(0, 0.98, 3.74), Vector3(0.14, 0.14, 0.2))


## The MRL: a flat deck carrying the 12-cell launcher pod on a traversing
## turntable (k.turret), the pod hinged at its back (k.elev) and resting
## level, pointing forward over the cab; stabiliser jacks at the back.
static func _zamak_mrl(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.14, 4.05), Vector3(s * 1.225, 1.51, 1.775), cam, col)
		# stabiliser jacks behind the rear wheels, raised
		k._box(m, Vector3(0.18, 0.4, 0.22), Vector3(s * 1.08, 1.05, 3.5), cam, col)
		k._cyl(m, 0.06, 0.06, 0.45, Vector3(s * 1.08, 0.78, 3.5), Vector3.ZERO, "steel", null, 8)
		k._box(m, Vector3(0.3, 0.05, 0.3), Vector3(s * 1.08, 0.55, 3.5), "gunmetal_w")
	# the fire-control and reload boxes at the front of the deck
	k._box(m, Vector3(2.3, 0.5, 0.5), Vector3(0, 1.69, 0.1), cam, col)
	k._box(m, Vector3(2.32, 0.03, 0.02), Vector3(0, 1.8, -0.155), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.6, 0.3, 0.02), Vector3(-0.6, 1.66, -0.155), cam, col)
	# the turntable and its trunnion brackets
	var t := k._pivot(m, Vector3(0, 1.44, 2.45))
	k.turret = t
	VehicleMounts.turret_ring(k, t, Vector3(0, 0.05, 0), 0.82, 0.84, 0.1, "gunmetal_w", null, 20)
	k._cyl(t, 0.72, 0.76, 0.24, Vector3(0, 0.22, 0), Vector3.ZERO, cam, col, 20)
	for s: float in [-1.0, 1.0]:
		k._box(t, Vector3(0.14, 0.62, 0.62), Vector3(s * 0.84, 0.5, 0.4), cam, col)
		k._cyl(t, 0.1, 0.1, 0.2, Vector3(s * 0.84, 0.72, 0.62), Z90, "gunmetal_w", null, 10)
	# the elevating ram's base on the turntable
	k._box(t, Vector3(0.3, 0.22, 0.4), Vector3(0, 0.42, -0.45), "gunmetal_w")
	# the pod: twelve cells, three rows of four, in the face on its end
	# frame; its frame bands and the rear cover
	var e := k._pivot(t, Vector3(0, 0.72, 0.62))
	k.elev = e
	k._box(e, Vector3(1.48, 0.96, 3.05), Vector3(0, 0.42, -1.4), cam, col)
	for bz: float in [-0.3, -1.4, -2.5]:
		k._box(e, Vector3(1.52, 1.0, 0.07), Vector3(0, 0.42, bz), "gunmetal_w")
	VehicleWeapons.missile_face(k, e, Vector3(0, 0.42, -2.95), Vector2(1.5, 0.98), 3, 4, 0.115, "gunmetal_w", null, Vector3.ZERO, false, Vector2(0.34, 0.28), 0.06)
	k._box(e, Vector3(1.44, 0.9, 0.04), Vector3(0, 0.42, 0.13), "plain_dark")
	k._box(e, Vector3(0.3, 0.2, 0.4), Vector3(0.82, 0.3, -0.8), "gunmetal_w")
	k._box(e, Vector3(0.2, 0.3, 0.2), Vector3(0, 0.0, -2.4), "gunmetal_w")
	k.gun_tip = k._tip(e, Vector3(0, 0.42, -3.0))
