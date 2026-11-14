extends Node
## The airframe parts of the third construction pass: helicopter trailing-arm
## main gear and tail wheels, chaff and flare dispensers, formation lights,
## air-refuelling receptacles, bombs and chin-turret housings. Each folds into
## its parent, registers no wheels or rotors, leaves the caller's wheel pivot,
## turret and muzzle alone, stays inside the envelope of the primitives it
## replaces (built here as the families built them, with the caller's wheel,
## grown only where the builder adds real hardware) and drops the seeker's
## glass on wrecks. FL_DEBUG_PART_BOUNDS=1 prints each part's bounds against
## its old envelope and its vertex count.

const DRAB := Color(0.3, 0.33, 0.26)
const GREY := Color(0.42, 0.45, 0.48)

func kit(burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	k.burnt = burnt
	return k

func parts(k: VehicleModels, node: Node3D) -> Array:
	return k._parts.get(node, [])

func bounds(k: VehicleModels, node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part: Array in parts(k, node):
		var xf: Transform3D = Transform3D(part[7], part[4]) if part[7] is Basis else Mats.place(part[4], part[5], part[6])
		var aabb := xf * (part[0] as Mesh).get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box

func vertices(k: VehicleModels, node: Node3D) -> int:
	var total := 0
	for part: Array in parts(k, node):
		var mesh: Mesh = part[0]
		for i in mesh.get_surface_count():
			total += (Mats._flat(mesh, i)[0] as PackedVector3Array).size()
	return total

func count(k: VehicleModels, node: Node3D, kind: String) -> int:
	var mat := Mats.get_mat(VehicleMaterials.key(kind, k.surface_family))
	var n := 0
	for part: Array in parts(k, node):
		if part[1] == mat:
			n += 1
	return n

## The old geometry's bounds: `build` lays the replaced primitives in a kit of
## their own, on `node` when it needs a pivot (a turret).
func old_bounds(build: Callable, at := Vector3.INF) -> AABB:
	var o := kit()
	var node := o.root
	if at.is_finite():
		node = o._pivot(o.root, at)
	build.call(o, node)
	var box := bounds(o, node)
	o.root.free()
	return box

## `k`'s parts on `node` (its root by default) fold, register nothing, are
## finite and stay inside `old` grown `side` all round and `up` more above.
func check(k: VehicleModels, old: AABB, label: String, node: Node3D = null, side := 0.006, up := 0.0) -> void:
	var on := node if node else k.root
	assert(on.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty() and k.rotors.is_empty() and k.rotor == null and k.tail_rotor == null, label + ": static parts must not register wheels or rotors")
	assert(not parts(k, on).is_empty(), label + ": nothing was built")
	var box := bounds(k, on)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	var env := AABB(old.position - Vector3.ONE * side, old.size + Vector3.ONE * side * 2.0 + Vector3(0, up, 0))
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s %s..%s old %s..%s verts=%d" % [label, box.position, box.end, old.position, old.end, vertices(k, on)])
	else:
		assert(env.encloses(box), "%s: %s escapes %s" % [label, box, env])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for part: Array in parts(k, on):
			assert(part[1] == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

## A wheel's volume: the caller's tyre, which the gear builds round.
func tyre(axle: Vector3, wheel: Vector2) -> AABB:
	return AABB(axle - Vector3(wheel.y * 0.5, wheel.x, wheel.x), Vector3(wheel.y, wheel.x * 2.0, wheel.x * 2.0))

func gear(burnt: bool, label: String, old: Callable, pivot: Vector3, top: Vector3, axle: Vector3, wheel: Vector2, beam: float, strut: float, fairing := Vector3.ZERO, hub := 0.0, hub_segments := 8) -> void:
	var o := kit()
	var owp := o._pivot(o.root, axle)
	old.call(o, owp)
	o._fold(owp)
	var envelope := bounds(o, o.root).merge(tyre(axle, wheel))
	o.root.free()
	var k := kit(burnt)
	var wp := k._pivot(k.root, axle)
	var turns: Node3D = wp if hub > 0.0 else null
	VehicleAircraft.trailing_gear(k, k.root, pivot, top, axle, wheel, beam, strut, "gunmetal_w", null, fairing, "aircraft", DRAB, turns, hub, hub_segments)
	assert(wp.get_child_count() == 0, label + ": the hub cover leaves no node on the wheel pivot")
	assert(parts(k, wp).is_empty() != (hub > 0.0), label + ": the hub cover, and only it, goes on the wheel pivot")
	if hub > 0.0:
		var cover := bounds(k, wp)
		assert(absf(cover.get_center().y) < 0.001 and absf(cover.get_center().z) < 0.001, label + ": the hub cover is centred on the axle")
		assert(cover.position.x * signf(axle.x) >= wheel.y * 0.5 - 0.05, label + ": the hub cover sits on the wheel's outer face")
	k._fold(wp)
	check(k, envelope, label, null, 0.05, 0.06)

func tail(burnt: bool, label: String, old: Callable, top: Vector3, axle: Vector3, wheel: Vector2, leg: float, brace_top := Vector3.ZERO, brace := 0.0) -> void:
	var envelope := old_bounds(old).merge(tyre(axle, wheel))
	var k := kit(burnt)
	VehicleAircraft.tailwheel(k, k.root, top, axle, wheel, leg, brace_top, brace)
	check(k, envelope, label, null, 0.05, 0.03)

func dispenser(burnt: bool, label: String, center: Vector3, size: Vector3, rotation: Vector3, face: Vector3, rows: int, cols: int, field: Vector2, slots: Array) -> void:
	var envelope := old_bounds(func(o: VehicleModels, p: Node3D) -> void:
		o._box(p, size, center, "gunmetal_w", null, rotation, false)
		for s: Array in slots:
			o._box(p, s[0], s[1], "plain_dark", null, rotation, false))
	var k := kit(burnt)
	VehicleAircraft.dispenser(k, k.root, center, size, rotation, face, rows, cols, "gunmetal_w", null, field)
	assert(parts(k, k.root).size() == 4, label + ": a dispenser is its housing, field, lips and caps whatever its count")
	check(k, envelope, label, null, 0.006)

## A formation light standing in for an old box strip: `size` the box, its
## thin axis `thin`, its long axis `long` (local axes, turned by `rotation`).
func strip(burnt: bool, label: String, center: Vector3, size: Vector3, rotation: Vector3, thin: Vector3, long: Vector3) -> void:
	var envelope := old_bounds(func(o: VehicleModels, p: Node3D) -> void:
		o._box(p, size, center, "paint", VehicleAircraft.FORMATION, rotation, false))
	var b := Basis.from_euler(rotation)
	var n := b * thin
	var thickness := absf(size.dot(thin))
	var length := absf(size.dot(long))
	var width := absf(size.dot(thin.cross(long)))
	var k := kit(burnt)
	VehicleAircraft.formation_light(k, k.root, center - n * thickness * 0.5, Vector2(length, width), n, b * long)
	assert(parts(k, k.root).size() == 2, label + ": the frame and the panel are a part each")
	check(k, envelope, label, null, 0.012)

func _ready() -> void:
	TestRun.watch()
	for burnt in [false, true]:
		# --- trailing-arm main gear, each site as its family built it -------------
		for s: float in [-1.0, 1.0]:
			# VmHeli._ghost_hawk: drag beam, shock strut, the faceted strut
			# fairing and hub cover
			gear(burnt, "ghost hawk gear %d" % int(s), func(o: VehicleModels, wp: Node3D) -> void:
				VmHeli._tube(o, o.root, Vector3(s * 0.78, 0.68, -4.35), Vector3(s * 1.36, 0.4, -3.95), 0.07, "gunmetal_w", null, 8)
				VmHeli._tube(o, o.root, Vector3(s * 1.08, 1.3, -3.8), Vector3(s * 1.38, 0.5, -3.92), 0.08, "gunmetal_w", null, 8)
				o._box(o.root, Vector3(0.22, 0.62, 0.3), Vector3(s * 1.18, 1.05, -3.84), "aircraft", DRAB, Vector3(0, 0, s * 0.35))
				o._cyl(wp, 0.3, 0.3, 0.04, Vector3(s * 0.14, 0, 0), Vector3(0, 0, PI / 2), "aircraft", DRAB, 8),
				Vector3(s * 0.78, 0.68, -4.35), Vector3(s * 1.08, 1.3, -3.8), Vector3(s * 1.48, 0.38, -3.95), Vector2(0.38, 0.26), 0.07, 0.08, Vector3(0.22, 0.62, 0.3), 0.3, 8)
		# VmHeli._blackfoot: legs out of their stubs, six-sided hub covers
		gear(burnt, "blackfoot gear", func(o: VehicleModels, wp: Node3D) -> void:
			VmHeli._tube(o, o.root, Vector3(0.82, 0.8, -3.1), Vector3(0.98, 0.34, -2.85), 0.06, "gunmetal_w", null, 8)
			VmHeli._tube(o, o.root, Vector3(0.8, 0.86, -2.7), Vector3(0.95, 0.4, -2.85), 0.04, "steel", null, 6)
			o._cyl(wp, 0.22, 0.22, 0.03, Vector3(0.08, 0, 0), Vector3(0, 0, PI / 2), "aircraft", DRAB, 6),
			Vector3(0.82, 0.8, -3.1), Vector3(0.8, 0.86, -2.7), Vector3(1.04, 0.3, -2.85), Vector2(0.3, 0.16), 0.06, 0.04, Vector3.ZERO, 0.22, 6)
		# VmHeli._kajman: trailing legs
		gear(burnt, "kajman gear", func(o: VehicleModels, _wp: Node3D) -> void:
			VmHeli._tube(o, o.root, Vector3(-0.8, 1.0, -3.65), Vector3(-1.32, 0.48, -3.2), 0.07, "gunmetal_w", null, 8)
			VmHeli._tube(o, o.root, Vector3(-0.85, 1.55, -3.4), Vector3(-1.3, 0.55, -3.22), 0.06, "steel", null, 8),
			Vector3(-0.8, 1.0, -3.65), Vector3(-0.85, 1.55, -3.4), Vector3(-1.38, 0.42, -3.2), Vector2(0.42, 0.28), 0.07, 0.06)
		# VmCore._apache: trailing arms off the avionics bays
		gear(burnt, "apache gear", func(o: VehicleModels, _wp: Node3D) -> void:
			VmHeli._tube(o, o.root, Vector3(0.8, 1.02, -3.55), Vector3(1.08, 0.4, -3.05), 0.07, "gunmetal_w", null, 8)
			VmHeli._tube(o, o.root, Vector3(0.84, 1.5, -3.2), Vector3(1.06, 0.5, -3.08), 0.055, "steel", null, 8),
			Vector3(0.8, 1.02, -3.55), Vector3(0.84, 1.5, -3.2), Vector3(1.12, 0.34, -3.05), Vector2(0.34, 0.22), 0.07, 0.055)
		# VmCore._blackhawk: the drag beam, the strut and its shock absorber
		gear(burnt, "black hawk gear", func(o: VehicleModels, _wp: Node3D) -> void:
			VmHeli._tube(o, o.root, Vector3(0.8, 0.66, -4.35), Vector3(1.38, 0.4, -3.95), 0.07, "gunmetal_w", null, 8)
			VmHeli._tube(o, o.root, Vector3(1.12, 1.35, -3.8), Vector3(1.4, 0.5, -3.92), 0.08, "gunmetal_w", null, 8)
			VmHeli._tube(o, o.root, Vector3(1.16, 1.2, -3.82), Vector3(1.36, 0.62, -3.92), 0.11, "steel", null, 8),
			Vector3(0.8, 0.66, -4.35), Vector3(1.12, 1.35, -3.8), Vector3(1.5, 0.38, -3.95), Vector2(0.38, 0.26), 0.07, 0.1)
		# --- tail wheels ---------------------------------------------------------------
		tail(burnt, "ghost hawk tail wheel", func(o: VehicleModels, p: Node3D) -> void:
			VmHeli._tube(o, p, Vector3(0, 1.88, 6.05), Vector3(0, 0.36, 6.4), 0.06, "gunmetal_w", null, 8)
			VmHeli._tube(o, p, Vector3(0, 1.84, 5.55), Vector3(0, 0.9, 6.25), 0.04, "steel", null, 6)
			o._box(p, Vector3(0.26, 0.08, 0.2), Vector3(0, 0.4, 6.42), "gunmetal_w"),
			Vector3(0, 1.88, 6.05), Vector3(0, 0.24, 6.48), Vector2(0.24, 0.16), 0.06, Vector3(0, 1.84, 5.55), 0.04)
		tail(burnt, "black hawk tail wheel", func(o: VehicleModels, p: Node3D) -> void:
			VmHeli._tube(o, p, Vector3(0, 1.92, 6.05), Vector3(0, 0.36, 6.4), 0.06, "gunmetal_w", null, 8)
			VmHeli._tube(o, p, Vector3(0, 1.86, 5.55), Vector3(0, 0.9, 6.25), 0.04, "steel", null, 6)
			o._box(p, Vector3(0.26, 0.08, 0.2), Vector3(0, 0.4, 6.42), "gunmetal_w"),
			Vector3(0, 1.92, 6.05), Vector3(0, 0.24, 6.48), Vector2(0.24, 0.16), 0.06, Vector3(0, 1.86, 5.55), 0.04)
		tail(burnt, "blackfoot tail wheel", func(o: VehicleModels, p: Node3D) -> void:
			VmHeli._tube(o, p, Vector3(0, 1.34, 4.5), Vector3(0, 0.3, 4.82), 0.045, "gunmetal_w", null, 8)
			o._box(p, Vector3(0.18, 0.06, 0.16), Vector3(0, 0.34, 4.84), "gunmetal_w"),
			Vector3(0, 1.34, 4.5), Vector3(0, 0.2, 4.88), Vector2(0.2, 0.12), 0.045)
		tail(burnt, "kajman tail wheel", func(o: VehicleModels, p: Node3D) -> void:
			VmHeli._tube(o, p, Vector3(0, 1.95, 6.8), Vector3(0, 0.38, 7.1), 0.05, "gunmetal_w", null, 8)
			o._box(p, Vector3(0.2, 0.07, 0.18), Vector3(0, 0.42, 7.12), "gunmetal_w"),
			Vector3(0, 1.95, 6.8), Vector3(0, 0.25, 7.16), Vector2(0.25, 0.16), 0.05)
		tail(burnt, "apache tail wheel", func(o: VehicleModels, p: Node3D) -> void:
			VmHeli._tube(o, p, Vector3(0, 2.12, 7.45), Vector3(0, 0.4, 7.85), 0.06, "gunmetal_w", null, 8)
			o._box(p, Vector3(0.24, 0.08, 0.2), Vector3(0, 0.42, 7.9), "gunmetal_w"),
			Vector3(0, 2.12, 7.45), Vector3(0, 0.25, 7.98), Vector2(0.25, 0.15), 0.06)
		# --- chaff and flare dispensers --------------------------------------------------
		for s: float in [-1.0, 1.0]:
			var slots := []
			for i in 3:
				slots.append([Vector3(0.02, 0.06, 0.4), Vector3(s * 2.53, 1.06 + i * 0.09, 0.85)])
			dispenser(burnt, "ac130 dispenser %d" % int(s), Vector3(s * 2.5, 1.15, 0.85), Vector3(0.06, 0.32, 0.55), Vector3(0, s * 0.35, 0), Vector3(s, 0, 0), 3, 5, Vector2(0.4, 0.27), slots)
		var bf_slots := []
		for i in 3:
			bf_slots.append([Vector3(0.02, 0.06, 0.45), Vector3(2.39, 1.1 + i * 0.09, 2.2)])
		dispenser(burnt, "blackfish dispenser", Vector3(2.36, 1.2, 2.2), Vector3(0.06, 0.34, 0.6), Vector3(0, 0.3, 0), Vector3.RIGHT, 3, 5, Vector2(0.45, 0.27), bf_slots)
		dispenser(burnt, "a10 pod dispenser", Vector3(2.62, 0.39, 0.55), Vector3(0.2, 0.012, 0.3), Vector3(0.18, 0, 0), Vector3.DOWN, 3, 4, Vector2.ZERO, [])
		dispenser(burnt, "a10 wing-tip dispenser", Vector3(-8.3, 1.0, -0.9), Vector3(0.18, 0.012, 0.5), Vector3(0, 0, -0.12), Vector3.DOWN, 2, 6, Vector2.ZERO, [])
		dispenser(burnt, "kajman dispenser", Vector3(3.5, 1.86, -1.7), Vector3(0.22, 0.26, 1.1), Vector3.ZERO, Vector3.RIGHT, 2, 7, Vector2(0.5, 0.16), [[Vector3(0.02, 0.16, 0.5), Vector3(3.62, 1.86, -1.75)]])
		# --- formation lights ---------------------------------------------------------------
		for sd: float in [-1.0, 1.0]:
			strip(burnt, "a10 nose strip %d" % int(sd), Vector3(sd * 0.5, 1.45, -6.3), Vector3(0.012, 0.06, 0.55), Vector3(0, -sd * 0.08, 0), Vector3(sd, 0, 0), Vector3.BACK)
			strip(burnt, "ac130 fin strip %d" % int(sd), Vector3(sd * 0.205, 7.6, 11.0), Vector3(0.012, 2.4, 0.08), Vector3(0.42, 0, 0), Vector3(sd, 0, 0), Vector3.UP)
			strip(burnt, "blackfish fin strip %d" % int(sd), Vector3(sd * 4.23, 5.65, 11.25), Vector3(0.012, 1.9, 0.08), Vector3(0.48, 0, -sd * 0.145), Vector3(sd, 0, 0), Vector3.UP)
		strip(burnt, "wipeout chine strip", Vector3(0.66, 1.9, -6.4), Vector3(0.012, 0.05, 0.6), Vector3(0, -0.1, 0), Vector3.RIGHT, Vector3.BACK)
		# laid on a curved skin (a hull stripe or a decal): a fuselage of radius
		# 0.6 about (0, 1), the strip running up its side from the waistline;
		# every point stays on the skin, 4 to 6.5 mm out
		var k := kit(burnt)
		var hull := func(p: Vector3) -> Vector3:
			var d := Vector2(p.x, p.y - 1.0).normalized() * 0.6
			return Vector3(d.x, 1.0 + d.y, p.z)
		VehicleAircraft.formation_light(k, k.root, Vector3(0.6, 1.0, -3.0), Vector2(0.9, 0.08), Vector3.RIGHT, Vector3.UP, VehicleAircraft.FORMATION, hull)
		for part: Array in parts(k, k.root):
			var verts: PackedVector3Array = Mats._flat(part[0] as Mesh, 0)[0]
			for v in verts:
				var out := Vector2(v.x, v.y - 1.0).length() - 0.6
				assert(out > -0.0025 and out < 0.0075, "a curved strip follows its skin (%.4f off it)" % out)
		check(k, AABB(Vector3(0.2, 0.55, -3.06), Vector3(0.42, 0.9, 0.12)), "curved strip")
		# --- refuelling receptacles -----------------------------------------------------------
		# VmAttack._a10_cockpit: the open slipway on its nose fairing, the slip
		# lines running back up the nose
		var tilt := Basis.from_euler(Vector3(-0.22, 0, 0))
		var ry := 1.9
		var rz := -6.95
		var a10 := old_bounds(func(o: VehicleModels, p: Node3D) -> void:
			o._box(p, Vector3(0.3, 0.06, 0.55), Vector3(0, ry + 0.005, rz), "aircraft", GREY, Vector3(-0.22, 0, 0))
			o._box(p, Vector3(0.12, 0.05, 0.3), Vector3(0, ry + 0.03, rz - 0.04), "plain_dark", null, Vector3(-0.22, 0, 0), false)).merge(
				AABB(Vector3(-0.17, ry + 0.06, rz + 0.3), Vector3(0.34, 0.2, 0.75)))
		k = kit(burnt)
		VehicleAircraft.refuel_receptacle(k, k.root, Vector3(0, ry, rz), Vector2(0.55, 0.3), tilt * Vector3.UP, tilt * Vector3.FORWARD, true, 0.03, -0.75, "aircraft", GREY)
		check(k, a10, "a10 receptacle", null, 0.03)
		# VmGunship._ac130_cockpit: the open slipway on the roof, the guide
		# lines ahead of it
		var ac := old_bounds(func(o: VehicleModels, p: Node3D) -> void:
			o._box(p, Vector3(0.62, 0.05, 0.9), Vector3(0, 4.74, -9.4), "plain_dark", null, Vector3(-0.02, 0, 0), false)
			o._box(p, Vector3(0.36, 0.06, 0.4), Vector3(0, 4.76, -9.4), "gunmetal_w", null, Vector3.ZERO, false)
			for s: float in [-1.0, 1.0]:
				o._box(p, Vector3(0.05, 0.02, 1.4), Vector3(s * 0.45, 4.755, -10.3), "paint", Color(0.85, 0.85, 0.8), Vector3(0, s * 0.3, 0), false))
		k = kit(burnt)
		VehicleAircraft.refuel_receptacle(k, k.root, Vector3(0, 4.74, -9.4), Vector2(0.9, 0.62), Vector3.UP, Vector3.FORWARD, true, 0.0, 1.1, "aircraft", GREY)
		check(k, ac, "ac130 receptacle", null, 0.03)
		# VmAttack._wip_cockpit: the closed door on the spine
		var wip := old_bounds(func(o: VehicleModels, p: Node3D) -> void:
			o._box(p, Vector3(0.26, 0.012, 0.5), Vector3(0, 2.11, -1.6), "aircraft", GREY, Vector3.ZERO, false))
		k = kit(burnt)
		VehicleAircraft.refuel_receptacle(k, k.root, Vector3(0, 2.104, -1.6), Vector2(0.5, 0.26), Vector3.UP, Vector3.FORWARD, false, 0.0, 0.0, "aircraft", GREY)
		check(k, wip, "wipeout receptacle", null, 0.012)
		# VmFighter._f16: the door decal and its lines ahead
		var f16 := AABB(Vector3(-0.1125, 1.0, 6.84), Vector3(0.225, 0.04, 1.06))
		k = kit(burnt)
		VehicleAircraft.refuel_receptacle(k, k.root, Vector3(0, 1.0, 7.7), Vector2(0.4, 0.2), Vector3.UP, Vector3.FORWARD, false, 0.0, 0.63, "aircraft", GREY)
		check(k, f16, "f16 receptacle", null, 0.012)
		# --- bombs, each against the old helper's own geometry ---------------------------------
		for b: Array in [["mk82", 2.2, 0.14, VehicleAircraft.BOMB_GP], ["mk82 short", 2.1, 0.16, VehicleAircraft.BOMB_GP], ["gbu12", 3.27, 0.137, VehicleAircraft.BOMB_LGB],
				["paveway", 2.4, 0.16, VehicleAircraft.BOMB_LGB], ["kab", 3.0, 0.2, VehicleAircraft.BOMB_LGB]]:
			var length: float = b[1]
			var radius: float = b[2]
			var guided: bool = b[3] == VehicleAircraft.BOMB_LGB
			var old := old_bounds(func(o: VehicleModels, p: Node3D) -> void: VmPlane.bomb(o, p, Vector3.ZERO, length, radius, guided))
			k = kit(burnt)
			VehicleAircraft.bomb(k, k.root, Vector3.ZERO, length, radius, int(b[3]), VmPlane.OLIVE)
			assert(count(k, k.root, "glass") == (1 if guided and not burnt else 0), String(b[0]) + ": only a live guided bomb's seeker has glass")
			check(k, old, String(b[0]), null, 0.006, 0.016)
		var jdam := old_bounds(func(o: VehicleModels, p: Node3D) -> void: VmFighter._gbu31(o, p, Vector3.ZERO))
		k = kit(burnt)
		VehicleAircraft.bomb(k, k.root, Vector3.ZERO, 3.88, 0.229, VehicleAircraft.BOMB_JDAM, VmPlane.OLIVE)
		assert(count(k, k.root, "glass") == 0)
		check(k, jdam, "gbu31", null, 0.006, 0.016)
		# --- chin turret housings, built on the caller's turret pivot ----------------------------
		# VmHeli._blackfoot (XM301): a faceted drum, the gun's housing tucked under it
		var at := Vector3(0, 0.68, -4.75)
		var old_turret := old_bounds(func(o: VehicleModels, t: Node3D) -> void:
			o._cyl(t, 0.2, 0.24, 0.2, Vector3(0, -0.02, 0), Vector3.ZERO, "aircraft", DRAB, 8)
			o._box(t, Vector3(0.22, 0.2, 0.55), Vector3(0, -0.18, -0.18), "gunmetal_w"), at)
		turret(burnt, "blackfoot turret", old_turret, at, func(k2: VehicleModels, t: Node3D) -> void:
			VehicleAircraft.chin_turret(k2, t, Vector3(0, -0.02, 0), Vector2(0.2, 0.24), 0.2, Vector3(0, -0.18, -0.18), Vector3(0.22, 0.2, 0.55), "aircraft", DRAB, 0.0, Vector3.ZERO, false, 8), 0.012)
		# VmHeli._kajman (2A42): the gun box hanging well below, a magazine each side
		at = Vector3(0, 0.9, -6.75)
		old_turret = old_bounds(func(o: VehicleModels, t: Node3D) -> void:
			o._cyl(t, 0.26, 0.3, 0.16, Vector3.ZERO, Vector3.ZERO, "aircraft", DRAB, 12)
			o._box(t, Vector3(0.2, 0.3, 0.3), Vector3(0, -0.2, 0), "gunmetal_w")
			o._box(t, Vector3(0.24, 0.24, 0.9), Vector3(0, -0.36, -0.2), "gunmetal_w")
			for s: float in [-1.0, 1.0]:
				o._box(t, Vector3(0.2, 0.3, 0.7), Vector3(s * 0.25, -0.34, 0.05), "aircraft", DRAB), at)
		turret(burnt, "kajman turret", old_turret, at, func(k2: VehicleModels, t: Node3D) -> void:
			VehicleAircraft.chin_turret(k2, t, Vector3.ZERO, Vector2(0.26, 0.3), 0.16, Vector3(0, -0.36, -0.2), Vector3(0.24, 0.24, 0.9), "aircraft", DRAB, 0.0, Vector3(0.2, 0.3, 0.7)), 0.03)
		# VmCore._apache (M230): the feed box on the right becomes the feeder and chute
		at = Vector3(0, 0.92, -3.85)
		old_turret = old_bounds(func(o: VehicleModels, t: Node3D) -> void:
			o._cyl(t, 0.24, 0.28, 0.16, Vector3(0, 0.02, 0), Vector3.ZERO, "aircraft", DRAB, 12)
			o._box(t, Vector3(0.24, 0.26, 0.56), Vector3(0, -0.2, -0.05), "gunmetal_w")
			o._box(t, Vector3(0.16, 0.14, 0.34), Vector3(0.18, -0.16, 0.12), "gunmetal_w"), at)
		turret(burnt, "apache turret", old_turret, at, func(k2: VehicleModels, t: Node3D) -> void:
			VehicleAircraft.chin_turret(k2, t, Vector3(0, 0.02, 0), Vector2(0.24, 0.28), 0.16, Vector3(0, -0.2, -0.05), Vector3(0.24, 0.26, 0.56), "aircraft", DRAB, 1.0), 0.13)
		# VmPlane._xian (twin 23 mm): the ball, the guns' box out of its front
		at = Vector3(0, 1.05, -7.2)
		old_turret = old_bounds(func(o: VehicleModels, t: Node3D) -> void:
			o._add(t, Res.sphere(0.36, 14), "aircraft", GREY, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1, 0.75, 1))
			o._box(t, Vector3(0.36, 0.3, 0.5), Vector3(0, -0.15, -0.3), "gunmetal_w"), at)
		turret(burnt, "twin ball turret", old_turret, at, func(k2: VehicleModels, t: Node3D) -> void:
			VehicleAircraft.chin_turret(k2, t, Vector3(0, -0.05, 0), Vector2(0.36, 0.36), 0.54, Vector3(0, -0.15, -0.3), Vector3(0.36, 0.3, 0.5), "aircraft", GREY, 0.0, Vector3.ZERO, true, 14), 0.012)
	print("VEHICLE_PARTS_AIRFRAME passed")
	TestRun.quit(get_tree())

## A chin turret's housing on a pivot that stands for the caller's k.turret:
## the pivot, the turret and the muzzle marker stay the caller's.
func turret(burnt: bool, label: String, old: AABB, at: Vector3, build: Callable, side: float) -> void:
	var k := kit(burnt)
	var t := k._pivot(k.root, at)
	k.turret = t
	build.call(k, t)
	assert(k.turret == t and k.mg_tip == null and k.gun_tip == null, label + ": the turret and its muzzle stay the caller's")
	assert(parts(k, k.root).is_empty(), label + ": the housing turns with the turret")
	check(k, old, label, t, side, 0.0)
