extends Node
## The gun, crane and hull fittings of the third construction pass: muzzle
## brakes, muzzle reference sensors, hydraulic rams, cranes, travel locks,
## pintle mounts and trim vanes. Each, live and wrecked, folds into its
## parent, registers no wheels, markers or pivots, keeps any point it returns,
## stays inside an envelope close to the old hand-built geometry it replaces
## (built here from the old primitives, as the families have them today) and
## drops its glass on wrecks.

const X90 := Vector3(PI / 2, 0, 0)
const OLIVE := Color(0.3, 0.33, 0.22)

func kit(burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	k.burnt = burnt
	return k

## Every noted part, in root coordinates, whichever pivot it is noted on.
func parts(k: VehicleModels) -> Array:
	var out := []
	for node: Node3D in k._parts:
		var xf := Transform3D.IDENTITY
		var n := node
		while n and n != k.root:
			xf = n.transform * xf
			n = n.get_parent() as Node3D
		for part: Array in k._parts[node]:
			var local: Transform3D = Transform3D(part[7], part[4]) if part[7] is Basis else Mats.place(part[4], part[5], part[6])
			out.append([part, xf * local])
	return out

func bounds(k: VehicleModels) -> AABB:
	var box := AABB()
	var first := true
	for entry: Array in parts(k):
		var xf: Transform3D = entry[1]
		var aabb := xf * ((entry[0] as Array)[0] as Mesh).get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box

func vertices(k: VehicleModels) -> int:
	var count := 0
	for entry: Array in parts(k):
		var mesh: Mesh = (entry[0] as Array)[0]
		for i in mesh.get_surface_count():
			count += (Mats._flat(mesh, i)[0] as PackedVector3Array).size()
	return count

func count_material(k: VehicleModels, kind: String) -> int:
	var m := Mats.get_mat(VehicleMaterials.key(kind, k.surface_family))
	var n := 0
	for entry: Array in parts(k):
		if (entry[0] as Array)[1] == m:
			n += 1
	return n

## The bounds of the old hand-built geometry, which `old` puts in a kit of its own.
func old_bounds(old: Callable) -> AABB:
	var k := kit()
	old.call(k, k.root)
	var box := bounds(k)
	k.root.free()
	return box

func check(k: VehicleModels, envelope: AABB, label: String) -> void:
	assert(k.root.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty(), label + ": static parts must not register wheel animation")
	assert(k.turret == null and k.elev == null and k.gun_tip == null and k.mg_tip == null and k.gun_mount == null, label + ": no turret, elevation pivot or muzzle marker")
	assert(k.antennas.is_empty() and k.rotors.is_empty(), label + ": no antenna or rotor registrations")
	assert(not parts(k).is_empty(), label + ": nothing was built")
	var box := bounds(k)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s %s in %s verts=%d" % [label, box, envelope, vertices(k)])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for entry: Array in parts(k):
			assert((entry[0] as Array)[1] == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

## A (z, y) point of a family's side profile as a point on the centreline.
func zy(p: Vector2, x := 0.0) -> Vector3:
	return Vector3(x, p.y, p.x)

## The outward normal of a profile face walked from a to b, as VmNato._zy and
## VmCore._zy push their plates (VmIndep._plate's is the same direction).
func face_normal(a: Vector2, b: Vector2) -> Vector3:
	var dn := (b - a).normalized()
	return Vector3(0, dn.x, -dn.y)

## VmNato._zy as it is today: a plate from a to b pushed `push` out.
func old_zy(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, t: float, push: float, mat: String) -> void:
	var d := b - a
	var dn := d.normalized()
	var c := (a + b) * 0.5 + Vector2(-dn.y, dn.x) * push
	k._box(p, Vector3(w, d.length(), t), Vector3(x, c.y, c.x), mat, null, Vector3(atan2(d.x, d.y), 0, 0))

func _ready() -> void:
	TestRun.watch()
	for burnt in [false, true]:
		# --- Muzzle brakes keep the front they were given, along any axis.
		# Sochor: two baffle rings and the side plates on a 152 mm.
		var env := old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			for z: float in [-6.7, -7.1]:
				k._add(r, VehicleFittings._ring(0.115, 0.18), "gunmetal_w", null, Vector3(0, 0, z), X90, Vector3(1, 0.65, 1))
			for s: float in [-1.0, 1.0]:
				k._box(r, Vector3(0.08, 0.26, 0.42), Vector3(s * 0.17, 0, -6.92), "gunmetal_w")
			k._cyl(r, 0.115, 0.115, 0.49, Vector3(0, 0, -6.905), X90, "paint", OLIVE, 12))
		var k := kit(burnt)
		assert(VehicleWeapons.muzzle_brake(k, k.root, Vector3(0, 0, -6.66), Vector3(0, 0, -7.15), Vector2(0.42, 0.36), "double", "gunmetal_w", null, 0.115) == Vector3(0, 0, -7.15))
		check(k, env.grow(0.006), "muzzle_brake double, side plates")
		# Scorcher: the same brake without side plates.
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			for z: float in [-6.35, -6.68]:
				k._add(r, VehicleFittings._ring(0.11, 0.18), "gunmetal_w", null, Vector3(0, 0, z), X90, Vector3(1, 0.7, 1))
			k._cyl(r, 0.11, 0.11, 0.45, Vector3(0, 0, -6.555), X90, "paint", OLIVE, 12))
		k = kit(burnt)
		assert(VehicleWeapons.muzzle_brake(k, k.root, Vector3(0, 0, -6.33), Vector3(0, 0, -6.78), Vector2(0.36, 0.36), "double", "gunmetal_w", null, 0.11) == Vector3(0, 0, -6.78))
		check(k, env.grow(0.006), "muzzle_brake double")
		# AC-130 M102: the box brake on a gun trained out to port, depressed.
		var dep := 0.1
		var dn := Vector3(-cos(dep), -sin(dep), 0)
		var mb := Vector3(-1.9, 1.92, 3.0) + dn * 3.02
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._box(r, Vector3(0.5, 0.32, 0.4), mb, "gunmetal_w", null, Vector3(0, 0, dep))
			for f: float in [-0.12, 0.12]:
				k._box(r, Vector3(0.13, 0.22, 0.412), mb + dn * f, "plain_dark", null, Vector3(0, 0, dep), false))
		k = kit(burnt)
		assert(VehicleWeapons.muzzle_brake(k, k.root, mb - dn * 0.25, mb + dn * 0.25, Vector2(0.4, 0.32), "box", "gunmetal_w", null, 0.1) == mb + dn * 0.25)
		check(k, env.grow(0.006), "muzzle_brake box")
		# A single baffle on a tube laid along an arbitrary axis.
		var rear := Vector3(0.2, 1.0, -1.0)
		var front := Vector3(0.45, 1.25, -1.6)
		k = kit(burnt)
		assert(VehicleWeapons.muzzle_brake(k, k.root, rear, front, Vector2(0.2, 0.2), "single") == front)
		check(k, AABB(rear, Vector3.ZERO).expand(front).grow(0.11), "muzzle_brake single, tilted")

		# --- Muzzle reference sensors: the old box on top of the tube.
		# Rhino: the box stands 2 cm clear of its 120 mm.
		var gy := 0.42
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._box(r, Vector3(0.08, 0.06, 0.12), Vector3(0, gy + 0.15, -6.4), "gunmetal_w", null, Vector3.ZERO, false)
			k._cyl(r, 0.1, 0.1, 0.12, Vector3(0, gy, -6.4), X90, "paint", OLIVE, 12))
		k = kit(burnt)
		VehicleWeapons.muzzle_sensor(k, k.root, Vector3(0, gy + 0.15, -6.4), Vector3(0.08, 0.06, 0.12), Vector3(0, gy, -6.4), 0.1, "gunmetal_w")
		assert(count_material(k, "glass") == (0 if burnt else 1), "muzzle_sensor glass follows the wreck state")
		check(k, AABB(env.position - Vector3(0.027, 0.007, 0.0), env.size + Vector3(0.054, 0.007, 0.016)), "muzzle_sensor")
		# Abrams: the box sits on the tube; a gun depressed a little.
		var fwd := Vector3(0, -0.12, -1).normalized()
		var bore := Vector3(0, 0.4, -2.3) + fwd * 2.84
		var up := Vector3(0, 1, -0.12).normalized()
		k = kit(burnt)
		VehicleWeapons.muzzle_sensor(k, k.root, bore + up * 0.13, Vector3(0.09, 0.07, 0.14), bore, 0.095, "gunmetal_w", null, fwd)
		assert(count_material(k, "glass") == (0 if burnt else 1))
		check(k, AABB(bore, Vector3.ZERO).grow(0.13).expand(bore + up * 0.18), "muzzle_sensor depressed")

		# --- Hydraulic rams between their old endpoints.
		# Zamak crane's luffing ram.
		var rc := Vector3(0.6, 2.62, 2.95)
		var ry := Basis.from_euler(Vector3(-0.75, 0, 0)).y * 0.5
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._cyl(r, 0.05, 0.05, 1.0, rc, Vector3(-0.75, 0, 0), "steel", null, 8))
		k = kit(burnt)
		VehicleFrames.ram(k, k.root, rc - ry, rc + ry, 0.05)
		check(k, env.grow(0.1), "ram")
		# Sochor's recoil cylinder in the cradle: no eyes, no hoses.
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._cyl(r, 0.07, 0.07, 0.9, Vector3(0.2, 0.22, -0.9), X90, "gunmetal_w", null, 10))
		k = kit(burnt)
		VehicleFrames.ram(k, k.root, Vector3(0.2, 0.22, -1.35), Vector3(0.2, 0.22, -0.45), 0.07, "gunmetal_w", null, 0.35, Vector3.RIGHT, false, false)
		check(k, AABB(env.position - Vector3(0.03, 0.03, 0.0), env.size + Vector3(0.06, 0.06, 0.0)), "ram recoil cylinder")

		# --- Cranes, posed as the families pose them.
		# Zamak repair: ring, box column, boom forward over the roof, its ram.
		var bc := Vector3(0.6, 3.02, 2.3)
		var ba := Basis.from_euler(Vector3(0.2, 0, 0)).z * 1.15
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._cyl(r, 0.26, 0.28, 0.24, Vector3(0.6, 1.56, 3.35), Vector3.ZERO, "gunmetal_w", null, 14)
			k._box(r, Vector3(0.26, 1.15, 0.28), Vector3(0.6, 2.25, 3.35), "paint", OLIVE)
			VehicleMounts.boom_box(k, r, Vector3(0.2, 0.22, 2.3), bc, "paint", OLIVE, Vector3(0.2, 0, 0))
			k._cyl(r, 0.05, 0.05, 1.0, rc, Vector3(-0.75, 0, 0), "steel", null, 8)
			k._box(r, Vector3(0.1, 0.2, 0.12), Vector3(0.6, 3.06, 1.08), "gunmetal_w")
			k._box(r, Vector3(0.06, 0.12, 0.08), Vector3(0.6, 2.98, 1.08), "paint", Color(0.6, 0.48, 0.12)))
		k = kit(burnt)
		VehicleMounts.crane(k, k.root, Vector3(0.6, 1.44, 3.35), bc + ba, bc - ba, Vector2(0.2, 0.22), "paint", OLIVE, Vector3(0.26, 0.28, 0.24), Vector3.ZERO, Vector3(0.26, 1.15, 0.28), [rc - ry, rc + ry, 0.05], Vector3(0.6, 3.04, 1.08), Vector3.INF, Vector3(0.1, 0.24, 0.12))
		check(k, env.grow(0.06), "crane")
		# Tempest ammo: king post and head, the boom folded back, the hook at
		# the extension's end (the extension stays with the family).
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._cyl(r, 0.17, 0.21, 0.95, Vector3(0.75, 1.97, -1.78), Vector3.ZERO, "paint", OLIVE, 12)
			k._box(r, Vector3(0.36, 0.26, 0.42), Vector3(0.75, 2.5, -1.75), "paint", OLIVE)
			VehicleMounts.boom_box(k, r, Vector3(0.2, 0.2, 3.3), Vector3(0.75, 2.6, 0.0), "paint", OLIVE)
			VehicleMounts.boom_box(k, r, Vector3(0.14, 0.14, 1.2), Vector3(0.75, 2.6, 2.2), "paint", OLIVE)
			k._box(r, Vector3(0.1, 0.22, 0.12), Vector3(0.75, 2.46, 2.8), "gunmetal_w"))
		k = kit(burnt)
		VehicleMounts.crane(k, k.root, Vector3(0.75, 1.495, -1.78), Vector3(0.75, 2.6, -1.65), Vector3(0.75, 2.6, 1.65), Vector2(0.2, 0.2), "paint", OLIVE, Vector3.ZERO, Vector3(0.17, 0.21, 0.95), Vector3(0.36, 0.26, 0.42), [], Vector3(0.75, 2.46, 2.8), Vector3(0.75, 2.6, 2.8))
		VehicleMounts.boom_box(k, k.root, Vector3(0.14, 0.14, 1.2), Vector3(0.75, 2.6, 2.2), "paint", OLIVE)
		check(k, env.grow(0.06), "crane on a king post")

		# --- Travel locks.
		# Sochor: two tube arms converging on the cradle, folded on the glacis.
		var gu := Vector3(0, 0.48, 1.55).normalized()
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			for s: float in [-1.0, 1.0]:
				VehicleFrames.tube(k, r, Vector3(s * 0.3, 1.2, -3.6), Vector3(s * 0.08, 1.48, -2.7), 0.04, "gunmetal_w", null, 6)
			k._box(r, Vector3(0.36, 0.1, 0.16), Vector3(0, 1.5, -2.64), "gunmetal_w", null, Vector3(atan2(gu.z, gu.y) - PI / 2, 0, 0)))
		k = kit(burnt)
		VehicleMounts.travel_lock(k, k.root, Vector3(0, 1.2, -3.6), Vector3(0, 1.5, -2.64), Vector3(0, gu.z, -gu.y), "gunmetal_w", null, Vector2(0.3, 0.08), Vector2(0.04, 0.0), Vector3(0.36, 0.1, 0.16))
		check(k, env.grow(0.12), "travel_lock")
		# Scorcher: one box-section arm; its cradle sized for the 155 mm.
		var lock := Basis.from_euler(Vector3(-0.24, 0, 0))
		var lc := Vector3(0, 1.48, -2.6)
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._box(r, Vector3(0.12, 0.1, 0.9), lc, "gunmetal_w", null, Vector3(-0.24, 0, 0)))
		k = kit(burnt)
		VehicleMounts.travel_lock(k, k.root, lc - lock.z * 0.4, lc + lock.z * 0.38, lock.y, "gunmetal_w", null, Vector2.ZERO, Vector2(0.12, 0.1), Vector3(0.3, 0.1, 0.14))
		check(k, env.grow(0.11), "travel_lock single arm")
		# Sandstorm: the launcher's fixed rest, two posts and the bar on top.
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			for s: float in [-1.0, 1.0]:
				k._box(r, Vector3(0.12, 0.3, 0.14), Vector3(s * 0.7, 2.05, -0.1), "gunmetal_w")
			k._box(r, Vector3(1.6, 0.08, 0.2), Vector3(0, 2.2, -0.1), "gunmetal_w"))
		k = kit(burnt)
		VehicleMounts.travel_lock(k, k.root, Vector3(0, 1.9, -0.1), Vector3(0, 2.2, -0.1), Vector3.UP, "gunmetal_w", null, Vector2(0.7, 0.7), Vector2(0.12, 0.14), Vector3(1.6, 0.08, 0.2))
		check(k, env.grow(0.06), "travel_lock rest")

		# --- Pintle mounts under the family's own gun.
		# Abrams commander's .50 on the cupola.
		var cp := Vector3(0.62, 0.7, 0.3)
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			k._box(r, Vector3(0.1, 0.22, 0.14), cp + Vector3(0.0, 0.28, -0.44), "gunmetal_w")
			k._box(r, Vector3(0.16, 0.19, 0.62), cp + Vector3(0.0, 0.48, -0.4), "gunmetal_w"))
		k = kit(burnt)
		VehicleMounts.pintle(k, k.root, cp + Vector3(0, 0.17, -0.44), cp + Vector3(0, 0.48, -0.4), "gunmetal_w", null, Vector2(0.04, 0.05))
		check(k, env.grow(0.025), "pintle")
		# Prowler's swing-arm M240: a slim post under a medium gun.
		var pz := -0.78
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			VehicleFrames.tube(k, r, Vector3(0.6, 1.08, pz), Vector3(0.6, 1.38, pz), 0.03, "gunmetal_w")
			k._box(r, Vector3(0.08, 0.13, 0.42), Vector3(0.6, 1.45, pz - 0.1), "gunmetal_w"))
		k = kit(burnt)
		VehicleMounts.pintle(k, k.root, Vector3(0.6, 1.08, pz), Vector3(0.6, 1.45, pz - 0.1), "gunmetal_w", null, Vector2(0.025, 0.03), Vector2(0.08, 0.13))
		check(k, env.grow(0.035), "pintle mmg")

		# --- Trim vanes folded on their bows.
		# Marshall: on the glacis, with its old hinge brackets and latches.
		var ga := Vector2(-3.72, 1.56)
		var gb := Vector2(-2.42, 2.14)
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			old_zy(k, r, 0.0, 2.3, ga.lerp(gb, 0.12), ga.lerp(gb, 0.62), 0.06, 0.03, "paint")
			for x: float in [-0.8, 0.0, 0.8]:
				old_zy(k, r, x, 0.22, ga.lerp(gb, 0.1), ga.lerp(gb, 0.15), 0.06, 0.07, "gunmetal_w")
			for s: float in [-1.0, 1.0]:
				old_zy(k, r, s * 1.08, 0.06, ga.lerp(gb, 0.6), ga.lerp(gb, 0.72), 0.12, 0.06, "gunmetal_w"))
		k = kit(burnt)
		VehicleMounts.trim_vane(k, k.root, zy(ga.lerp(gb, 0.12)), zy(ga.lerp(gb, 0.62)), 2.3, 0.06, face_normal(ga, gb), "paint", OLIVE, 2, 3)
		check(k, env.grow(0.035), "trim_vane")
		# BTR-80: folded down the lower bow plate, which faces forward and down.
		var bow0 := Vector2(-2.95, 0.42)
		var bow1 := Vector2(-3.8, 1.11)
		var bn := face_normal(bow0, bow1)
		env = old_bounds(func(k: VehicleModels, r: Node3D) -> void:
			var a := bow0.lerp(bow1, 0.25)
			var b := bow0.lerp(bow1, 0.92)
			var d := b - a
			var c := (a + b) * 0.5 + Vector2(bn.z, bn.y) * 0.025
			k._box(r, Vector3(1.5, d.length(), 0.05), Vector3(0, c.y, c.x), "paint", OLIVE, Vector3(atan2(d.x, d.y), 0, 0)))
		k = kit(burnt)
		VehicleMounts.trim_vane(k, k.root, zy(bow0.lerp(bow1, 0.25)), zy(bow0.lerp(bow1, 0.92)), 1.5, 0.05, bn, "paint", OLIVE)
		check(k, env.grow(0.07), "trim_vane lower bow")
	print("VEHICLE_PARTS_ARMS passed")
	TestRun.quit(get_tree())
