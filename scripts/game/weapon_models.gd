class_name WeaponModels
extends RefCounted
## Crew-served machine guns on their mounts, built to the real weapons'
## dimensions and layout:
##   m240 - M240B 7.62 mm GPMG on the M192 lightweight ground mount: polymer
##          stock, pistol grip, feed tray cover with a rail and M145 optic, gas
##          cylinder under the barrel, carrying handle, folded bipod, 100-round
##          soft pouch feeding the belt from the left.
##   m2   - M2HB .50 cal on the M3 tripod: big flat-sided receiver, spade grips
##          and butterfly trigger on the backplate, perforated barrel support,
##          heavy barrel with carrying handle and cone flash hider, M2A1 ammo
##          can on the left tray.
##   pkm  - PKM 7.62x54R on its tripod: skeleton stock and grip in laminated
##          wood, fluted barrel, slotted flash hider, 100-round box under the
##          right side.
##   dshk - DShKM 12.7 mm: finned barrel, muzzle brake, spade grips, 50-round
##          box on the left, low tripod and a welded gun shield.
## Every gun is built around its pintle at the origin: `traverse` turns it,
## `elev` raises it, and `body` is what kicks back when it fires. Forward is -z.

const GUNS := {
	"m240": {"bore": 0.07, "muzzle": 0.78, "grip_r": Vector3(0.0, -0.05, 0.21), "grip_l": Vector3(-0.015, 0.06, 0.42), "nest_h": 0.38, "trench_h": 0.3},
	"pkm": {"bore": 0.07, "muzzle": 0.76, "grip_r": Vector3(0.0, -0.05, 0.19), "grip_l": Vector3(-0.015, 0.05, 0.38), "nest_h": 0.36, "trench_h": 0.3},
	"m2": {"bore": 0.1, "muzzle": 1.42, "grip_r": Vector3(0.085, 0.08, 0.5), "grip_l": Vector3(-0.085, 0.08, 0.5), "nest_h": 0.42, "trench_h": 0.38},
	"dshk": {"bore": 0.1, "muzzle": 1.32, "grip_r": Vector3(0.085, 0.08, 0.5), "grip_l": Vector3(-0.085, 0.08, 0.5), "nest_h": 0.42, "trench_h": 0.38},
}

const OD := Color(0.42, 0.44, 0.3)  # olive drab paint (as a tint on the paint surface)
const BRASS := Color(0.72, 0.56, 0.24)


static func build(kind: String, low := false) -> Dictionary:
	var g: Dictionary = GUNS.get(kind, GUNS.m240)
	var h: float = float(g.trench_h if low else g.nest_h)
	var root := Node3D.new()
	var trav := Node3D.new()
	root.add_child(trav)
	var elev := Node3D.new()
	trav.add_child(elev)
	var body := Node3D.new()
	elev.add_child(body)
	match kind:
		"m2":
			_m3_tripod(root, h)
			_m2(body, float(g.bore))
		"dshk":
			_low_tripod(root, h, 0.95)
			_dshk(body, elev, float(g.bore))
		"pkm":
			_pk_tripod(root, h)
			_pkm(body, float(g.bore))
		_:
			_m192(root, h)
			_m240(body, float(g.bore))
	return {"root": root, "traverse": trav, "elev": elev, "body": body, "h": h,
		"grip_r": g.grip_r, "grip_l": g.grip_l, "muzzle": Vector3(0, float(g.bore), -float(g.muzzle))}


# --- parts -------------------------------------------------------------------------

static func _p(parent: Node3D, mesh: Mesh, kind: String, pos: Vector3, rot := Vector3.ZERO, tint := Color(1, 1, 1)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	Mats.apply(mi, kind, tint)
	return mi


## A tube from a to b.
static func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, kind := "gunmetal", tint := Color(1, 1, 1), segs := 6) -> void:
	var y := b - a
	var L := y.length()
	if L < 0.001:
		return
	y /= L
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var mi := _p(parent, Res.cyl(r, r, 1.0, segs), kind, Vector3.ZERO, Vector3.ZERO, tint)
	mi.transform = Transform3D(Basis(x, y * L, z), (a + b) * 0.5)


## A barrel-like cylinder along -z from z0 to z1 at height y.
static func _tube(parent: Node3D, y: float, z0: float, z1: float, r: float, kind := "gunmetal", r2 := -1.0, x := 0.0, tint := Color(1, 1, 1)) -> void:
	_p(parent, Res.cyl(r if r2 < 0.0 else r2, r, absf(z1 - z0), 10), kind, Vector3(x, y, (z0 + z1) * 0.5), Vector3(-PI / 2, 0, 0), tint)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, kind := "gunmetal", rot := Vector3.ZERO, tint := Color(1, 1, 1)) -> MeshInstance3D:
	return _p(parent, Res.box(size), kind, pos, rot, tint)


## The belt running from the ammo container up into the feed tray.
static func _belt(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var n := 7
	for i in n:
		var t := (float(i) + 0.5) / n
		var p := a.lerp(b, t) + Vector3(0, -sin(t * PI) * 0.025, 0)
		_box(parent, Vector3(0.05, 0.012, 0.016), p, "paint", Vector3(0, 0, 0), BRASS)


# --- guns --------------------------------------------------------------------------

static func _m240(b: Node3D, y: float) -> void:
	_box(b, Vector3(0.07, 0.11, 0.38), Vector3(0, y, 0.08))  # receiver
	_box(b, Vector3(0.076, 0.03, 0.22), Vector3(0, y + 0.068, 0.02))  # feed tray cover
	_box(b, Vector3(0.026, 0.014, 0.26), Vector3(0, y + 0.09, 0.06))  # top rail
	_tube(b, y + 0.14, 0.0, 0.14, 0.021)  # M145 optic
	_box(b, Vector3(0.02, 0.035, 0.05), Vector3(0, y + 0.115, 0.07))
	_box(b, Vector3(0.048, 0.12, 0.27), Vector3(0, y - 0.015, 0.39), "gunmetal", Vector3(0.07, 0, 0))  # stock
	_box(b, Vector3(0.052, 0.15, 0.025), Vector3(0, y - 0.025, 0.53))  # butt plate
	_box(b, Vector3(0.036, 0.11, 0.05), Vector3(0, y - 0.105, 0.21), "gunmetal", Vector3(-0.3, 0, 0))  # pistol grip
	_box(b, Vector3(0.012, 0.035, 0.08), Vector3(0, y - 0.07, 0.15))  # trigger guard
	_box(b, Vector3(0.062, 0.05, 0.16), Vector3(0, y - 0.005, -0.18))  # heat shield
	_tube(b, y, -0.1, -0.7, 0.014)  # barrel
	_tube(b, y - 0.036, -0.1, -0.52, 0.012)  # gas cylinder
	_tube(b, y, -0.7, -0.78, 0.019, "gunmetal", 0.015)  # flash hider
	_box(b, Vector3(0.01, 0.05, 0.016), Vector3(0, y + 0.035, -0.66))  # front sight
	_box(b, Vector3(0.02, 0.07, 0.025), Vector3(0.035, y + 0.045, -0.24))  # carrying handle
	_box(b, Vector3(0.02, 0.02, 0.13), Vector3(0.035, y + 0.09, -0.24))
	for sx in [-0.018, 0.018]:  # bipod, folded
		_box(b, Vector3(0.011, 0.011, 0.33), Vector3(sx, y - 0.058, -0.42))
	_box(b, Vector3(0.1, 0.12, 0.15), Vector3(-0.1, y - 0.055, 0.02), "canvas_l")  # 100-round pouch
	_belt(b, Vector3(-0.08, y + 0.01, 0.02), Vector3(-0.03, y + 0.05, 0.02))


static func _pkm(b: Node3D, y: float) -> void:
	_box(b, Vector3(0.06, 0.1, 0.32), Vector3(0, y, 0.06))  # receiver
	_box(b, Vector3(0.066, 0.025, 0.24), Vector3(0, y + 0.06, 0.04))  # top cover
	_box(b, Vector3(0.012, 0.03, 0.03), Vector3(0, y + 0.085, -0.02))  # rear sight
	# skeleton stock in laminated wood
	_box(b, Vector3(0.034, 0.036, 0.3), Vector3(0, y + 0.005, 0.36), "wood_l")
	_box(b, Vector3(0.034, 0.03, 0.31), Vector3(0, y - 0.075, 0.35), "wood_l", Vector3(0.22, 0, 0))
	_box(b, Vector3(0.04, 0.14, 0.03), Vector3(0, y - 0.035, 0.5), "wood_l")
	_box(b, Vector3(0.034, 0.1, 0.045), Vector3(0, y - 0.1, 0.19), "wood_l", Vector3(-0.3, 0, 0))  # grip
	_box(b, Vector3(0.012, 0.035, 0.07), Vector3(0, y - 0.065, 0.13))
	_tube(b, y, -0.1, -0.68, 0.012)  # fluted barrel
	_tube(b, y - 0.03, -0.1, -0.44, 0.01)  # gas tube
	_box(b, Vector3(0.03, 0.04, 0.03), Vector3(0, y + 0.0, -0.44))  # gas block
	_box(b, Vector3(0.012, 0.05, 0.02), Vector3(0, y + 0.03, -0.66))  # front sight
	_tube(b, y, -0.68, -0.76, 0.016)  # slotted flash hider
	_box(b, Vector3(0.016, 0.05, 0.11), Vector3(0.04, y + 0.04, -0.16), "wood_l")  # carrying handle
	_box(b, Vector3(0.065, 0.12, 0.12), Vector3(0.05, y - 0.115, 0.02), "paint", Vector3.ZERO, Color(0.27, 0.3, 0.2))  # 100-round box
	_belt(b, Vector3(0.05, y - 0.05, 0.02), Vector3(0.03, y + 0.02, 0.02))


static func _m2(b: Node3D, y: float) -> void:
	_box(b, Vector3(0.17, 0.2, 0.6), Vector3(0, y - 0.02, 0.12))  # receiver
	_box(b, Vector3(0.18, 0.03, 0.44), Vector3(0, y + 0.095, 0.1))  # top cover
	_box(b, Vector3(0.04, 0.06, 0.015), Vector3(0, y + 0.135, 0.3))  # leaf sight
	_box(b, Vector3(0.16, 0.17, 0.03), Vector3(0, y - 0.02, 0.43))  # backplate
	for sx in [-0.085, 0.085]:  # spade grips
		_p(b, Res.cyl(0.022, 0.022, 0.14, 8), "gunmetal", Vector3(sx, y + 0.08, 0.5))
		_box(b, Vector3(0.025, 0.025, 0.08), Vector3(sx, y + 0.0, 0.47))
		_box(b, Vector3(0.025, 0.025, 0.08), Vector3(sx, y + 0.15, 0.47))
	_box(b, Vector3(0.07, 0.035, 0.025), Vector3(0, y + 0.05, 0.47))  # butterfly trigger
	_box(b, Vector3(0.03, 0.045, 0.1), Vector3(0.1, y + 0.01, 0.05))  # charging handle
	_tube(b, y, -0.18, -0.43, 0.048)  # barrel support
	for z in [-0.22, -0.3, -0.38]:
		_tube(b, y, z, z - 0.03, 0.052)
	_tube(b, y, -0.43, -1.32, 0.029)  # heavy barrel
	_box(b, Vector3(0.025, 0.07, 0.11), Vector3(0, y + 0.06, -0.62))  # carrying handle
	_box(b, Vector3(0.012, 0.055, 0.02), Vector3(0, y + 0.05, -1.24))  # front sight
	_tube(b, y, -1.32, -1.43, 0.03, "gunmetal", 0.05)  # cone flash hider, widening
	_box(b, Vector3(0.08, 0.06, 0.24), Vector3(0, y - 0.15, 0.04))  # cradle
	_box(b, Vector3(0.14, 0.02, 0.3), Vector3(-0.17, y - 0.2, 0.06))  # ammo tray
	_box(b, Vector3(0.1, 0.18, 0.28), Vector3(-0.19, y - 0.1, 0.06), "paint", Vector3.ZERO, OD)  # M2A1 can
	_box(b, Vector3(0.11, 0.02, 0.05), Vector3(-0.19, y + 0.0, -0.02), "paint", Vector3.ZERO, OD.darkened(0.2))
	_belt(b, Vector3(-0.17, y + 0.0, 0.07), Vector3(-0.08, y + 0.04, 0.07))


static func _dshk(b: Node3D, elev: Node3D, y: float) -> void:
	_box(b, Vector3(0.13, 0.15, 0.56), Vector3(0, y, 0.12))  # receiver
	_box(b, Vector3(0.14, 0.04, 0.24), Vector3(0, y + 0.09, 0.02))  # feed cover
	_box(b, Vector3(0.14, 0.15, 0.03), Vector3(0, y + 0.01, 0.42))  # backplate
	for sx in [-0.085, 0.085]:  # spade grips, wood
		_p(b, Res.cyl(0.024, 0.024, 0.14, 8), "wood_l", Vector3(sx, y + 0.08, 0.5))
		_box(b, Vector3(0.025, 0.025, 0.08), Vector3(sx, y + 0.0, 0.47))
		_box(b, Vector3(0.025, 0.025, 0.08), Vector3(sx, y + 0.15, 0.47))
	_tube(b, y, -0.16, -1.2, 0.028)  # barrel
	for i in 7:  # cooling fins
		var z := -0.2 - i * 0.05
		_tube(b, y, z, z - 0.016, 0.055)
	_tube(b, y - 0.06, -0.16, -0.78, 0.016)  # gas cylinder
	_box(b, Vector3(0.025, 0.07, 0.1), Vector3(0, y + 0.06, -0.6))  # carrying handle
	_tube(b, y, -1.2, -1.32, 0.042)  # muzzle brake
	for z in [-1.24, -1.28]:
		_box(b, Vector3(0.09, 0.012, 0.012), Vector3(0, y, z))
	_box(b, Vector3(0.09, 0.16, 0.22), Vector3(-0.14, y - 0.08, 0.06), "paint", Vector3.ZERO, Color(0.26, 0.29, 0.2))  # 50-round box
	_belt(b, Vector3(-0.12, y + 0.0, 0.06), Vector3(-0.05, y + 0.05, 0.06))
	# the welded shield turns with the gun but doesn't kick
	_box(elev, Vector3(0.72, 0.42, 0.014), Vector3(0, y + 0.02, -0.3), "paint", Vector3(0.12, 0, 0), Color(0.3, 0.32, 0.24))
	_box(elev, Vector3(0.14, 0.4, 0.014), Vector3(-0.35, y, -0.26), "paint", Vector3(0.12, 0.5, 0), Color(0.3, 0.32, 0.24))
	_box(elev, Vector3(0.14, 0.4, 0.014), Vector3(0.35, y, -0.26), "paint", Vector3(0.12, -0.5, 0), Color(0.3, 0.32, 0.24))


# --- mounts ------------------------------------------------------------------------

## M192: one front leg, two splayed rear legs, a traverse bar between them and
## the T&E screw up to the gun.
static func _m192(r: Node3D, h: float) -> void:
	_p(r, Res.cyl(0.03, 0.03, 0.08, 8), "gunmetal", Vector3(0, -0.04, 0))
	_rod(r, Vector3(0, -0.05, -0.02), Vector3(0, -h, -0.6), 0.013)
	for sx in [-1.0, 1.0]:
		_rod(r, Vector3(sx * 0.02, -0.05, 0.02), Vector3(sx * 0.42, -h, 0.42), 0.013)
		_box(r, Vector3(0.06, 0.012, 0.08), Vector3(sx * 0.42, -h + 0.006, 0.42))
	_box(r, Vector3(0.05, 0.012, 0.08), Vector3(0, -h + 0.006, -0.6))
	var tb := -h * 0.45
	_rod(r, Vector3(-0.21, tb, 0.21), Vector3(0.21, tb, 0.21), 0.01)
	_rod(r, Vector3(0, tb, 0.21), Vector3(0, -0.02, 0.16), 0.012)


## M3: a long front leg, two heavy rear legs, the traversing bar across the
## back and the T&E mechanism up to the receiver.
static func _m3_tripod(r: Node3D, h: float) -> void:
	_p(r, Res.cyl(0.045, 0.05, 0.1, 8), "gunmetal", Vector3(0, -0.05, 0))
	_rod(r, Vector3(0, -0.07, -0.03), Vector3(0, -h, -0.95), 0.02)
	for sx in [-1.0, 1.0]:
		_rod(r, Vector3(sx * 0.03, -0.07, 0.03), Vector3(sx * 0.55, -h, 0.48), 0.02)
		_box(r, Vector3(0.09, 0.015, 0.12), Vector3(sx * 0.55, -h + 0.008, 0.48))
	_box(r, Vector3(0.07, 0.015, 0.12), Vector3(0, -h + 0.008, -0.95))
	var tb := -h * 0.5
	_rod(r, Vector3(-0.29, tb, 0.27), Vector3(0.29, tb, 0.27), 0.014)
	_box(r, Vector3(0.05, 0.05, 0.05), Vector3(0, tb, 0.27))
	_rod(r, Vector3(0, tb, 0.27), Vector3(0, -0.06, 0.24), 0.016)


static func _pk_tripod(r: Node3D, h: float) -> void:
	_p(r, Res.cyl(0.025, 0.03, 0.07, 8), "gunmetal", Vector3(0, -0.035, 0))
	_rod(r, Vector3(0, -0.05, -0.02), Vector3(0, -h, -0.55), 0.011)
	for sx in [-1.0, 1.0]:
		_rod(r, Vector3(sx * 0.02, -0.05, 0.02), Vector3(sx * 0.38, -h, 0.4), 0.011)
	_rod(r, Vector3(-0.17, -h * 0.5, 0.2), Vector3(0.17, -h * 0.5, 0.2), 0.008)


static func _low_tripod(r: Node3D, h: float, reach: float) -> void:
	_p(r, Res.cyl(0.04, 0.045, 0.1, 8), "gunmetal", Vector3(0, -0.05, 0))
	_rod(r, Vector3(0, -0.07, -0.03), Vector3(0, -h, -reach), 0.018)
	for sx in [-1.0, 1.0]:
		_rod(r, Vector3(sx * 0.03, -0.07, 0.03), Vector3(sx * 0.52, -h, 0.5), 0.018)
	_rod(r, Vector3(-0.26, -h * 0.5, 0.26), Vector3(0.26, -h * 0.5, 0.26), 0.012)


## Ammunition cans stacked beside the gun, and spent brass under it.
static func ammo_dump(parent: Node3D, at: Vector3, heavy: bool, rng: RandomNumberGenerator) -> void:
	var cs := Vector3(0.11, 0.19, 0.29) if heavy else Vector3(0.1, 0.18, 0.27)
	for i in 3:
		var p := at + Vector3(0.0 if i < 2 else 0.06, cs.y * (0.5 + (1.0 if i == 2 else 0.0)), (float(i % 2) - 0.5) * 0.32)
		_box(parent, cs, p, "paint", Vector3(0, rng.randf_range(-0.15, 0.15), 0), OD.darkened(rng.randf_range(0.0, 0.15)))
		_box(parent, Vector3(cs.x * 0.9, 0.02, 0.05), p + Vector3(0, cs.y * 0.5 + 0.01, 0), "paint", Vector3.ZERO, OD.darkened(0.3))
