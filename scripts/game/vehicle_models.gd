class_name VehicleModels
extends RefCounted
## Procedural vehicle models (tanks, pickups, trucks, helicopters, light
## vehicles). Sloped armour comes from lofted convex solids; every part gets a
## surface from Mats. `burnt` builds the same shape as a charred wreck.
## Local -Z is forward; y = 0 is the ground.

const ImpactPlate := preload("res://scripts/game/vehicles/impact_plate.gd")

static var _cache := {}

var root: Node3D
var sling_eye := Vector3(0, 0.7, 0)  # underside of the fuselage, in model space
var helm_seat := Vector3.INF  # hip position of the driver at an open helm
var burnt := false:
	set(v):
		burnt = v
		wreck = wreck or v  # (a burnt hulk is a wreck, whoever builds it)
var wreck := false  # built for a wreck: paint and tyres are gone, a rotor keeps every blade a part of its own, to be broken
var surface_family := "armor"
var turret: Node3D
var mg_tip: Node3D  # the machine gun's muzzle (shots start here)
var gun_mount: Node3D
var gun_tip: Node3D  # the main gun's muzzle
var weapon_tips := {}  # named gunship weapons (ac25/ac40/ac105), not one shared point
var rotor: Node3D
var tail_rotor: Node3D
var blur: MeshInstance3D
var blades: Node3D
var wheels: Array = []
var antennas: Array[Node3D] = []
var _antenna_response := ImpactResponse.new()
var _antenna_velocity := Vector3.ZERO
var _antenna_active := false
var belts: Array = []
var periscope := Vector3.INF
var roof_gun := Vector3.INF  # receiver centre in turret space, for exterior filming
var engine_deck := Vector3.INF  # Fire breaks through the upper deck when damaged.
var engine_vent := Vector3.INF  # Local outlet on models with visible exhaust.
var front_skirts: Array[Node3D] = []
var _damaged_plates := {}
var skirt_plugs: Array[Node3D] = []
var elev: Node3D  # an artillery barrel or rocket launcher that rises to fire (rotation.x)
## More rotors (a tandem's rear one, a coaxial's second, a drone's four or
## six): pivots spinning about Y. Each may hold a "Blades" node (shown slow)
## and a "Blur" disc (shown fast), like the main rotor.
var rotors: Array = []
## The mouths of the exhaust pipes, in the model's own space: the origin at the
## mouth, Y the way the gas leaves (the heat haze: Vehicle.heat_sources). Kept
## as numbers, not nodes, so a fitting still folds away into its parent; the
## pipes sit on parts that never move against the model.
var exhausts: Array[Transform3D] = []
## The seed the crew's own load is drawn from (VehicleCargo.kit): the vehicle's
## seed, so a seed lays its stowage out exactly and two of a kind differ (and a
## battle wreck, built from its vehicle's seed, keeps what of the load didn't
## burn); -1 (scenery and burnt hulks, which look() shares by kind) the
## builders' one load.
var kit_seed := -1

## The cradles the machine gun (or autocannon, or twin guns) is laid in, each
## at its gun's trunnion with the gun's parts on it: they elevate to the target
## and run back when the gun fires (Vehicle._lay_guns). A mount on no turret
## (a door gun, a pintle on a hull) also traverses by itself, within mg_arc of
## its rest.
var mg_mounts: Array[Node3D] = []
var mg_rests: Array[Transform3D] = []  # each mount's rest pose on its parent
var mg_free := false
var mg_arc := 1.2
## Where a gunner's hands go on each mount, in its own space: [right, left],
## or empty for a gun worked from inside or by remote control.
var mg_hands: Array = []
## Each mount's traverse at rest: a door gun is left pointing out of its door
## (its gunner inside behind it), everything else straight ahead.
var mg_stow: Array[float] = []
## Where the man on the first crew-served gun stands, as its builder sets it
## (empty: behind the grips at arm's length, wherever they are). "on" is the
## node his floor belongs to - the hull for a pickup's bed, the turret for a
## hatch that turns with the gun - "y" his feet's height in its space and
## "area" (x, z in its space) the floor he may stand on: he keeps behind the
## grips as the gun turns but never steps off it. An area of no size is one
## spot he stands on, turning with "on" (a gunner in a hatch).
var gunner_floor: Dictionary = {}
## The gun is worked from a seat (a passenger's swing-arm gun): no gunner is
## drawn on it, as there's no seated pose for him.
var gunner_seated := false
## Every gun assembly a shared builder made (VehicleWeapons): {parent, origin,
## muzzle (both in the parent's space), parts, nodes}, so build() can put the
## machine gun's on a mount of its own once the model is done.
var _guns: Array[Dictionary] = []


## Notes an exhaust's mouth at `pos` on `parent`, the gas leaving along `dir`.
func exhaust_at(parent: Node3D, pos: Vector3, dir: Vector3) -> void:
	var t := Transform3D(VehicleFrames.aim(dir), pos)
	var p := parent
	while p != null and p != root:
		t = p.transform * t
		p = p.get_parent() as Node3D
	exhausts.append(t)


## A civilian car: 0 saloon, 1 hatchback, 2 pickup, 3 van, 4 estate.
static func build_car(variant: int, col: Color, is_burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k.burnt = is_burnt
	k.surface_family = "automotive"
	k._baking = true
	k._car(variant % 5, col)
	k._merge_parts(k.root, Vector3.ZERO)
	k._baked()
	return k


static func build(kind: String, team: int, seed: int, is_burnt := false, is_wreck := false) -> VehicleModels:
	var b := start(kind, team, seed, is_burnt, is_wreck)
	b.step(-1)
	return b.k


## The model build() makes, made a piece at a time: Build.step() does the next
## pieces each frame (see Build).
static func start(kind: String, team: int, seed: int, is_burnt := false, is_wreck := false) -> Build:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k.burnt = is_burnt
	k.wreck = is_wreck or is_burnt
	k.kit_seed = seed if team >= 0 and not is_burnt else -1
	k._baking = true
	return Build.new(k, _assemble.bind(k, kind, team, seed))


## Finished models kept to copy, by look (see look()). Every parked car of a
## kind and paint is the same model, and every burnt-out tank on the map the
## same hulk: a copy, sharing the meshes, takes a millisecond or two where
## building one took a fifth of a second.
static var _stock := {}
const STOCK_KEEP := 96


## What a model will look like, as a key for the stock: "" when that can't be
## told without building it (a kind whose seed does more than pick a paint,
## a team's own markings).
static func look(kind: String, team: int, seed: int, is_burnt := false) -> String:
	if team >= 0:
		return ""
	var civ := VmCiv.look(kind, seed, is_burnt)
	if civ != "":
		return civ
	if is_burnt and kind in ["tank", "old_tank"]:
		return kind + "/burnt"  # (a hulk's paint is gone: nothing tells two apart)
	return ""


## A copy of the model with that look, or null if none is kept yet.
static func stocked(look_key: String) -> VehicleModels:
	var kept: VehicleModels = _stock.get(look_key)
	return kept.copy() if kept != null else null


## Keeps a copy of a finished model to copy for its look.
static func stock(look_key: String, k: VehicleModels) -> void:
	if look_key == "" or _stock.has(look_key):
		return
	if _stock.size() >= STOCK_KEEP:
		for kept: VehicleModels in _stock.values():
			kept.root.free()
		_stock.clear()  # (a long run's worth of looks: start again)
	_stock[look_key] = k.copy()


## A copy to stand as scenery (a parked car, a hulk) sharing this one's meshes
## and materials: its root and the moving parts scenery poses (the turret, the
## gun, the rotor), not the wheels, skirts or plates a driven vehicle works.
func copy() -> VehicleModels:
	var c := VehicleModels.new()
	c.root = root.duplicate() as Node3D
	c.burnt = burnt
	c.wreck = wreck
	c.surface_family = surface_family
	c.sling_eye = sling_eye
	c.engine_deck = engine_deck
	c.engine_vent = engine_vent
	c.turret = _same_in(c.root, turret)
	c.gun_mount = _same_in(c.root, gun_mount)
	c.gun_tip = _same_in(c.root, gun_tip)
	for whip: Node3D in antennas:
		c.antennas.append(_same_in(c.root, whip))
	c.rotor = _same_in(c.root, rotor)
	return c


## The node in `other` (a copy of root) where `part` is in root: found by
## its place among its siblings, since a copy names nodes made unnamed afresh.
func _same_in(other: Node3D, part: Node3D) -> Node3D:
	if part == null:
		return null
	var places: Array[int] = []
	var n: Node = part
	while n != root:
		places.push_front(n.get_index())
		n = n.get_parent()
	var found: Node = other
	for i in places:
		found = found.get_child(i)
	return found as Node3D


## Every part of the model noted down (see _add), for the merge to make into meshes.
static func _assemble(k: VehicleModels, kind: String, team: int, seed: int) -> void:
	# a vehicle may share another's model (a variant), named in its definition
	var mk := kind
	if Defs.VEHICLES.has(kind):
		mk = String(Defs.VEHICLES[kind].get("model", kind))
	k.surface_family = VehicleMaterials.family(mk)
	# the aircraft builders in scripts/game/vehicles/ come first: until one of
	# them builds a key, the older model below stands
	if VmCore.build(k, mk, team, seed) or VmGunship.build(k, mk, team, seed) or VmAttack.build(k, mk, team, seed) or VmFighter.build(k, mk, team, seed):
		k._mount_guns()
		return
	match mk:
		"tank":
			k._tank(team)
		"old_tank":
			k._old_tank(team)
		"technical":
			k._technical(team, seed)
		"heli":
			k._heli(team, false)
		"gunship":
			k._heli(team, true)
		"humvee":
			k._humvee(team)
		"jet":
			k._jet(team)  # (superseded by VmFighter once it builds one)
		"a10":
			k._a10(team)
		"ac130":
			k._ac130(team)
		"apc", "btr":
			k._apc(team)
		"ifv":
			k._ifv(team)
		"aa_tech":
			k._technical(team, seed, true)
		"truck":
			# the supply convoy: a HEMTT for the Coalition, a Zamak for the Rebels
			if not ((team == 0 and VmNato.build(k, "hemtt_cargo", team, seed)) or (team == 1 and VmIndep.build(k, "zamak_cargo", team, seed))):
				k._truck(team)
		_:
			# the rest of the roster lives in scripts/game/vehicles/, by family
			if not (VmNato.build(k, mk, team, seed) or VmCsat.build(k, mk, team, seed) or VmIndep.build(k, mk, team, seed)
					or VmCiv.build(k, mk, team, seed) or VmHeli.build(k, mk, team, seed) or VmPlane.build(k, mk, team, seed)
					or VmBoat.build(k, mk, team, seed) or VmShips.build(k, mk, team, seed)):
				k._truck(team)
	k._mount_guns()


func scorch_finish() -> ShaderMaterial:
	var soot := ShaderMaterial.new()
	soot.render_priority = -2
	soot.shader = preload("res://scripts/shaders/vehicle_soot.gdshader")
	for part: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not part is ImpactPlate:
			part.material_overlay = soot
	return soot


## The burn creeps outwards over the half minute the fire takes hold
## (BURN_SPREAD), as far as `reach` times 2.56 m from where it started.
const BURN_SPREAD := 45.0
static func spread_soot(soot: ShaderMaterial, origin: Vector3, age: float, reach := 1.0) -> void:
	soot.set_shader_parameter("source_world", origin)
	soot.set_shader_parameter("extent", (0.46 + 2.1 * (1.0 - exp(-maxf(0.0, age) * 0.11))) * reach)


func make_impact_plate(side: float, layers := 2) -> ImpactPlate:
	var plate := ImpactPlate.new()
	plate.fit(layers)
	if front_skirts.is_empty():
		root.add_child(plate)
		plate.position = Vector3(side * 1.669, 1.18, -0.55)
	else:
		front_skirts[1 if side > 0 else 0].add_child(plate)
		plate.position = Vector3(side * 0.056, -0.395, -0.40)
	plate.rotation.y = side * PI / 2
	return plate


## Each bit records a bent front skirt, from the left side to the right.
func pose_skirts(mask: int) -> void:
	for i in front_skirts.size():
		var skirt := front_skirts[i]
		var side := signf(skirt.position.x)
		var damaged := (mask & (1 << i)) != 0
		skirt.rotation = Vector3(-0.23, 0.0, side * 0.41) if damaged else Vector3.ZERO
		skirt_plugs[i].visible = not damaged
	for i in 2:
		var damaged := (mask & (1 << i)) != 0
		if damaged and not _damaged_plates.has(i):
			var plate := make_impact_plate(-1.0 if i == 0 else 1.0, 1)
			plate.take_hit()
			_damaged_plates[i] = plate
		elif not damaged and _damaged_plates.has(i):
			_damaged_plates[i].queue_free()
			_damaged_plates.erase(i)


## Every model key the families build (for the Field Manual's model pages).
static func family_keys() -> Array[String]:
	var out: Array[String] = []
	for ks in [VmNato.KEYS, VmCsat.KEYS, VmIndep.KEYS, VmCiv.KEYS, VmHeli.KEYS, plane_keys(), VmBoat.KEYS, VmShips.KEYS]:
		out.append_array(ks)
	return out


## Every fixed-wing model key. The plane family spans several builders: VmPlane,
## and the newer aircraft builders build() asks first (each builds its own keys).
static func plane_keys() -> Array[String]:
	var out: Array[String] = []
	for ks in [VmPlane.KEYS, VmAttack.KEYS, VmFighter.KEYS, VmGunship.KEYS]:
		out.append_array(ks)
	return out


## Each moving part (hull, turret, every wheel, rotor) becomes one mesh with a
## surface per material: the detail costs vertices, not draw calls. The
## camouflage stays continuous across the parts.
func _merge_parts(n: Node3D, off: Vector3) -> void:
	Build.new(self, Callable(), n, off).step(-1)


## The holders _merge_parts merges, in its order: the ones under a holder first.
func _merge_order(n: Node3D, off: Vector3, nodes: Array, offs: Array) -> void:
	for c in n.get_children():
		if c is Node3D and not (c is MeshInstance3D):
			_merge_order(c, off + (c as Node3D).position, nodes, offs)
	nodes.append(n)
	offs.append(off)


## A noted part into the holder's mesh (see _add).
static func _bake_part(bake: Mats.Bake, pt: Array) -> void:
	var xf: Transform3D = Transform3D(pt[7], pt[4]) if pt[7] is Basis else Mats.place(pt[4], pt[5], pt[6])
	bake.part(pt[0], pt[8] if pt[8] is ShaderMaterial else pt[1], xf, pt[2] if pt[2] != Color(1, 1, 1) else null, pt[3])


## A holder's parts made as nodes merged in with its meshes.
func _merge_holder(n: Node3D, off: Vector3) -> void:
	var before := n.get_child_count()
	Mats.merge_static(n, [blur] if blur else [], false, false, true)
	for i in range(before, n.get_child_count()):
		var mi := n.get_child(i) as MeshInstance3D
		if mi and off != Vector3.ZERO and not mi.has_meta(&"shadow_proxy"):
			Mats.set_inst(mi, &"pofs", off)
	if not burnt and not front_skirts.is_empty() and (n == root or n == turret):
		for child in n.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is ArrayMesh and not child.has_meta(&"shadow_proxy"):
				Mats.set_inst(child, &"armour_section", 0.0 if n == root else 1.0)


## A model built a piece at a time. A parked car took 100-250 ms to build, a
## tank wreck about 200: a hitch each time one came into view. step() does the
## next pieces for up to `budget_us` (at least one) and says whether the model
## is done; the slow welding and simplifying of its distant mesh goes to a
## worker meanwhile. With no budget (-1) it all happens at once, as build()
## does. Each holder's noted parts go into its mesh, its nodes are merged in,
## and (unless burnt) it gets its distant mesh, as _merge_parts always did.
class Build:
	var k: VehicleModels
	var done := false
	var _make: Callable  # notes down the model's parts (or nothing: they're noted already)
	var _top: Node3D
	var _top_off: Vector3
	var _nodes: Array = []
	var _offs: Array = []
	var _at := -1  # the holder being merged (-1: not assembled yet)
	var _stage := 0  # its next piece: 0 its parts, 1 its merge, 2 its distant mesh, 3 waiting for that
	var _part := 0
	var _bake: Mats.Bake
	var _lod: Array = []
	var _job: Dictionary = {}

	func _init(model: VehicleModels, assemble: Callable, top: Node3D = null, off := Vector3.ZERO) -> void:
		k = model
		_make = assemble
		_top = top if top != null else model.root
		_top_off = off

	func step(budget_us: int) -> bool:
		var started := Time.get_ticks_usec()
		while not done:
			if not _next(budget_us < 0):
				return false  # (its distant mesh isn't ready yet)
			if budget_us >= 0 and Time.get_ticks_usec() - started >= budget_us:
				break
		return done

	## The next piece of work: false if it has to wait.
	func _next(now: bool) -> bool:
		if _at < 0:
			if _make.is_valid():
				_make.call()
			k._merge_order(_top, _top_off, _nodes, _offs)
			_at = 0
			_holder_done(false)
			return true
		var n: Node3D = _nodes[_at]
		match _stage:
			0:
				var pts: Array = k._parts.get(n, [])
				if _part < pts.size():
					if _bake == null:
						_bake = Mats.Bake.new(true)
					VehicleModels._bake_part(_bake, pts[_part])
					_part += 1
				else:
					_stage = 1
			1:
				if k._parts.has(n):
					k._parts.erase(n)
					if _bake == null:
						_bake = Mats.Bake.new(true)
					_bake.commit(n)
				_bake = null
				k._merge_holder(n, _offs[_at])
				_stage = 2
				if k.burnt:
					_holder_done(true)
			2:
				_lod = Mats.distance_lod_parts(n, [k.blur] if k.blur else [])
				if _lod.is_empty():
					_holder_done(true)
				elif now:
					Mats.attach_distance_lod(n, 100.0, _lod[1], Mats._bake_groups(_lod[0]))
					_holder_done(true)
				else:
					_job = Mats.bake_groups_later(_lod[0])
					_stage = 3
			3:
				if not Mats.bake_done(_job):
					return false
				Mats.attach_distance_lod(n, 100.0, _lod[1], Mats.bake_result(_job))
				_holder_done(true)
		return true

	## Stops where it is (waiting out a distant mesh in the works, if any).
	func abandon() -> void:
		if _stage == 3:
			Mats.bake_result(_job)
		done = true
		if is_instance_valid(k.root):
			k.root.free()

	## On to the next holder (`advance`), or the first; the model is done after the last.
	func _holder_done(advance: bool) -> void:
		if advance:
			_at += 1
		_stage = 0
		_part = 0
		_lod = []
		_job = {}
		if _at >= _nodes.size():
			if _make.is_valid():
				k._baked()
			done = true


# --- mesh helpers ----------------------------------------------------------------

static func _v2(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in range(0, a.size(), 2):
		p.append(Vector2(a[i], a[i + 1]))
	return p


## Ring in the XZ plane at height y.
static func ring_y(pts: PackedVector2Array, y: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for p in pts:
		r.append(Vector3(p.x, y, p.y))
	return r


## Ring in the ZY plane (a side profile) at x.
static func ring_x(pts: PackedVector2Array, x: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for p in pts:
		r.append(Vector3(x, p.y, p.x))
	return r


static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in r:
		c += p
	return c / maxf(1.0, r.size())


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-10:
		return
	if cr.dot((a + b + c) / 3.0 - inside) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var n := -cr.normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


## Lofts between successive convex rings (same point count) and caps both ends.
## `bevel` chamfers the edge round the last ring (a hull's roof, a turret's
## top, a box's lid) by about that many metres, `bevel_bottom` the first
## ring's: armour plate is flame-cut and welded or cast, and its broken edge
## is a narrow facet that catches the light along the hull from the RTS
## camera, where a two-ring loft meets its cap at a dead-sharp CG edge. The
## cap keeps its plane, so whatever stands on it stays where it was; the side
## and cap keep their flat normals and the chamfer gets its own. Without
## either the mesh is exactly what it always was.
static func solid(rings: Array, key: String, smooth := false, bevel := 0.0, bevel_bottom := 0.0) -> ArrayMesh:
	key = _bevel_key(key, bevel, bevel_bottom)
	if _cache.has(key):
		return _cache[key]
	# the chamfers are rings of their own (see _chamfered); n0/n1 count the
	# strips that are chamfers at each end
	var n0 := 0
	var n1 := 0
	if bevel > 0.0:
		var c: Array = _chamfered(rings, bevel, true)
		n1 = c.size() - rings.size()
		rings = c
	if bevel_bottom > 0.0:
		var c: Array = _chamfered(rings, bevel_bottom, false)
		n0 = c.size() - rings.size()
		rings = c
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in rings.size() - 1:
		if smooth and n0 + n1 > 0:
			# a rolled edge on a rounded solid: smooth round the ring, but a
			# crease where it meets the side
			st.set_smooth_group(2 if (k < n0 or k >= rings.size() - 1 - n1) else 0)
		var r0: PackedVector3Array = rings[k]
		var r1: PackedVector3Array = rings[k + 1]
		var cen := (_centroid(r0) + _centroid(r1)) * 0.5
		var n := r0.size()
		for i in n:
			var j := (i + 1) % n
			_tri(st, r0[i], r0[j], r1[j], cen)
			_tri(st, r0[i], r1[j], r1[i], cen)
	if smooth:
		st.set_smooth_group(1)  # keep the flat caps separate from the curved sides
	for e in [0, rings.size() - 1]:
		var r: PackedVector3Array = rings[e]
		var other: PackedVector3Array = rings[1 if e == 0 else rings.size() - 2]
		var inside := _centroid(other)
		for i in range(1, r.size() - 1):
			_tri(st, r[0], r[i], r[i + 1], inside)
	if smooth:
		st.generate_normals()
	# (what st.commit() makes, keeping the arrays: see Mats.keep_arrays)
	var arrays := st.commit_to_arrays()
	var m := ArrayMesh.new()
	if arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] != null and not (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		Mats.keep_arrays(m, arrays)
	_cache[key] = m
	return m


## Two level outlines (x, z pairs, convex, same count) lofted from y0 to y1;
## `bevel` / `bevel_bottom` chamfer the top / bottom edge as in solid.
## `smooth` rolls the top edge over in a quarter round about `bevel` wide
## instead (up to 70% of the top's half-width): a pressed or moulded cowling
## is rounded over its shoulders, and a single chamfer facet only suggests
## that. The light slides round the roll from above; the outline's gentle
## corners (under 50 degrees) shade round too, its sharp ones stay creased,
## and the flat top keeps its plane and its height.
static func loft(key: String, bottom: Array, top: Array, y0: float, y1: float, bevel := 0.0, bevel_bottom := 0.0, smooth := false) -> ArrayMesh:
	if not smooth or bevel <= 0.0:
		if _cache.has(_bevel_key(key, bevel, bevel_bottom)):
			return _cache[_bevel_key(key, bevel, bevel_bottom)]
		return solid([ring_y(_v2(bottom), y0), ring_y(_v2(top), y1)], key, false, bevel, bevel_bottom)
	var skey := "%s|roll%.3f,%.3f" % [key, bevel, bevel_bottom]
	if _cache.has(skey):
		return _cache[skey]
	var base := ring_y(_v2(bottom), y0)
	var edge := ring_y(_v2(top), y1)
	var c := _centroid(edge)
	var reach := INF
	for i in edge.size():
		var q := edge[(i + 1) % edge.size()]
		if edge[i].distance_squared_to(q) > 1e-10:
			reach = minf(reach, absf((c - edge[i]).dot(Vector3.UP.cross(q - edge[i]).normalized())))
	var b := minf(bevel, minf((y1 - y0) * 0.6, reach * 0.7))
	var cut := _inset_ring(edge, Vector3.UP, c, b)
	while cut.is_empty() and b > 0.01:
		b *= 0.6
		cut = _inset_ring(edge, Vector3.UP, c, b)
	if cut.is_empty():
		return solid([base, edge], key, false, 0.0, bevel_bottom)
	# the roll: from b down the side, over the old edge, to b in on the top
	var side := PackedVector3Array()
	for i in edge.size():
		side.append(edge[i].lerp(base[i], b / (y1 - y0)))
	var rings: Array = [base, side]
	for s in range(1, 5):
		var t := s / 4.0
		var r := PackedVector3Array()
		for i in edge.size():
			r.append(side[i] * (1.0 - t) * (1.0 - t) + edge[i] * 2.0 * t * (1.0 - t) + cut[i] * t * t)
		rings.append(r)
	var n0 := 0
	if bevel_bottom > 0.0:
		var lowered: Array = _chamfered(rings, bevel_bottom, false)
		n0 = lowered.size() - rings.size()
		rings = lowered
	# each side face of the outline its own smoothing group, shared across a
	# gentle corner, so the long flat flanks stay flat
	var m := edge.size()
	var turn := PackedFloat32Array()
	turn.resize(m)
	var start := -1
	for i in m:
		var d0 := edge[i] - edge[(i - 1 + m) % m]
		var d1 := edge[(i + 1) % m] - edge[i]
		turn[i] = 0.0 if d0.length_squared() < 1e-10 or d1.length_squared() < 1e-10 else rad_to_deg(d0.angle_to(d1))
		if start < 0 and turn[i] > 50.0:
			start = i
	var group := PackedInt32Array()
	group.resize(m)
	var g := 0
	for j in m:
		var i := (maxi(start, 0) + j) % m
		if j > 0 and turn[i] > 50.0:
			g += 1
		group[i] = g + 2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in rings.size() - 1:
		var r0: PackedVector3Array = rings[k]
		var r1: PackedVector3Array = rings[k + 1]
		var cen := (_centroid(r0) + _centroid(r1)) * 0.5
		for i in m:
			var j := (i + 1) % m
			# (a bottom chamfer is a crease of its own, as in solid)
			st.set_smooth_group(1 if k < n0 else group[i])
			_tri(st, r0[i], r0[j], r1[j], cen)
			_tri(st, r0[i], r1[j], r1[i], cen)
	for e in [0, rings.size() - 1]:
		st.set_smooth_group(0xFFFF0 + e)
		var r: PackedVector3Array = rings[e]
		var inside := _centroid(rings[1 if e == 0 else rings.size() - 2])
		for i in range(1, r.size() - 1):
			_tri(st, r[0], r[i], r[i + 1], inside)
	st.generate_normals()
	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()
	if arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] != null and not (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		Mats.keep_arrays(mesh, arrays)
	_cache[skey] = mesh
	return mesh


## A side profile ((z, y) pairs, convex) extruded across x0..x1; `bevel`
## chamfers both side faces' edges all round, the roof's and glacis's edges
## among them, as in solid.
static func extrude_x(key: String, profile: Array, x0: float, x1: float, bevel := 0.0) -> ArrayMesh:
	if _cache.has(_bevel_key(key, bevel, bevel)):
		return _cache[_bevel_key(key, bevel, bevel)]
	var p := _v2(profile)
	return solid([ring_x(p, x0), ring_x(p, x1)], key, false, bevel, bevel)


## A chamfered mesh is another mesh: it is cached under its own key.
static func _bevel_key(key: String, top: float, bottom: float) -> String:
	if top <= 0.0 and bottom <= 0.0:
		return key
	return "%s|bevel%.3f,%.3f" % [key, top, bottom]


## `rings` with the edge round one end ring (the last if `top`) cut back by
## about b along both faces: a new ring b in from the end on the way to it,
## and the end ring moved in by b within its own plane, each edge parallel to
## its old self. b is kept under 40% of the end segment's length and 30% of
## the ring's half-width, so a thin plate or a narrow rail gets a smaller
## chamfer rather than a folded one; the rings come back unchanged if the
## end is degenerate (a point, a line) or no chamfer fits.
static func _chamfered(rings: Array, b: float, top: bool) -> Array:
	var n := rings.size()
	if n < 2:
		return rings
	var e: PackedVector3Array = rings[n - 1] if top else rings[0]
	var nb: PackedVector3Array = rings[n - 2] if top else rings[1]
	var nrm := _ring_normal(e)
	if nrm == Vector3.ZERO or nb.size() != e.size():
		return rings
	var c := _centroid(e)
	var h := absf((c - _centroid(nb)).dot(nrm))
	var reach := INF  # the nearest edge to the centre, in the ring's plane
	for i in e.size():
		var a := e[i]
		var q := e[(i + 1) % e.size()]
		if a.distance_squared_to(q) < 1e-10:
			continue
		var side := nrm.cross(q - a).normalized()
		reach = minf(reach, absf((c - a).dot(side)))
	b = minf(b, minf(h * 0.4, reach * 0.3))
	var cut := PackedVector3Array()
	for _attempt in 3:
		if b < 0.003:
			return rings
		cut = _inset_ring(e, nrm, c, b)
		if not cut.is_empty():
			break
		b *= 0.5
	if cut.is_empty():
		return rings
	var mid := PackedVector3Array()
	var t := b / h
	for i in e.size():
		mid.append(e[i].lerp(nb[i], t))
	var out := rings.duplicate()
	if top:
		out[n - 1] = mid
		out.append(cut)
	else:
		out[0] = mid
		out.insert(0, cut)
	return out


## The normal of a planar ring (Newell's method), or zero for a point or a line.
static func _ring_normal(r: PackedVector3Array) -> Vector3:
	var s := Vector3.ZERO
	for i in r.size():
		var p := r[i]
		var q := r[(i + 1) % r.size()]
		s += Vector3((p.y - q.y) * (p.z + q.z), (p.z - q.z) * (p.x + q.x), (p.x - q.x) * (p.y + q.y))
	if s.length_squared() < 1e-12:
		return Vector3.ZERO
	return s.normalized()


## A convex ring in the plane normal to `nrm`, centred on c, moved in by d,
## each edge parallel to its old self (mitred; repeated points move as one);
## empty if an edge shorter than its corners' cut would turn over.
static func _inset_ring(r: PackedVector3Array, nrm: Vector3, c: Vector3, d: float) -> PackedVector3Array:
	var m := r.size()
	var out := PackedVector3Array()
	for i in m:
		var p := r[i]
		var a := r[_distinct(r, i, -1)]
		var q := r[_distinct(r, i, 1)]
		var n0 := nrm.cross(p - a).normalized()
		var n1 := nrm.cross(q - p).normalized()
		if n0.dot(c - (a + p) * 0.5) < 0.0:
			n0 = -n0
		if n1.dot(c - (p + q) * 0.5) < 0.0:
			n1 = -n1
		var dir := n0 + n1
		dir = n0 if dir.length_squared() < 1e-8 else dir.normalized()
		out.append(p + dir * d / maxf(0.35, dir.dot(n0)))
	for i in m:
		var j := (i + 1) % m
		var was := r[j] - r[i]
		if was.length_squared() > 1e-10 and (out[j] - out[i]).dot(was) <= 0.0:
			return PackedVector3Array()
	return out


## The index of the nearest point before (step -1) or after (step 1) point i
## of ring r that isn't at the same place.
static func _distinct(r: PackedVector3Array, i: int, step: int) -> int:
	var m := r.size()
	var j := i
	for _k in m - 1:
		j = (j + step + m) % m
		if r[j].distance_squared_to(r[i]) > 1e-10:
			return j
	return j


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var key := "cap%.2f,%.2f" % [r, h]
	if _cache.has(key):
		return _cache[key]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 6
	_cache[key] = m
	return m


# --- part helpers ----------------------------------------------------------------

## A part of the model on one of our surfaces, tinted to `col`. While the
## model is built it's only noted down (and the note returned: see _turn,
## _unshadow, _restyle for changing it afterwards): _merge_parts puts it
## straight into its piece's merged mesh without making a node of it (a tank
## is four hundred parts). Otherwise it's made as a node, and that returned.
func _add(parent: Node3D, mesh: Mesh, kind: String, col, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> Variant:
	if wreck and kind in ["canvas", "cloth", "fabric"]:
		# burnt away (the note is still handed back, so callers can treat it as made)
		return [mesh, null, Color(1, 1, 1), shadow, pos, rot, scl, null, null]
	var k := kind
	if burnt:
		k = "abrams_scorched" if kind in ["abrams_olive", "abrams_sand"] else "burnt"
	k = VehicleMaterials.key(k, surface_family)
	var t := Mats.tint_for(k, col) if col is Color and not burnt else Color(1, 1, 1)
	if burnt and kind in ["glass", "armor_glass", "headlamp", "signal_lens"]:
		# A burnt-out vehicle's windows and lamps have cracked out in the heat:
		# what's left is a sooty empty frame, not rusted steel (the char shader
		# leaves anything this dark black with soot).
		t = Color(0.3, 0.3, 0.3)
	if not burnt and VehicleMaterials.profile(kind, surface_family) in ["armor", "aircraft", "marine", "service"]:
		mesh = VehicleBody.paint_mesh(mesh)
	var pt := [mesh, Mats.get_mat(k), t, shadow, pos, rot, scl, null, null]
	if profiling:
		_profile(mesh)
	if not _baking:
		return _add_node(parent, pt)
	if not _parts.has(parent):
		_parts[parent] = []
	(_parts[parent] as Array).append(pt)
	return pt


## tools/vehicles/builder-profile.tscn: while set, every part's triangle-list
## vertex count is charged to the outermost shared builder that made it (or to
## the family function that added it itself), so a pass can see where a
## roster's geometry goes. Needs script backtraces: development builds only.
static var profiling := false
static var profile := {}


func _profile(mesh: Mesh) -> void:
	var n := 0
	for i in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(i)
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index is PackedInt32Array and (index as PackedInt32Array).size() > 0:
			n += (index as PackedInt32Array).size()
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var owner := "?"
	for trace: ScriptBacktrace in Engine.capture_script_backtraces():
		var started := false
		for f in trace.get_frame_count():
			var file := trace.get_frame_file(f)
			var here := file.get_file().get_basename() + "." + trace.get_frame_function(f)
			# Skip this class's own primitives (_add, _box, _cyl ...) first.
			if not started:
				if file.ends_with("vehicle_models.gd"):
					continue
				started = true
			if file.contains("/vehicles/vm_") or file.ends_with("vehicle_models.gd"):
				if owner == "?":
					owner = here
				break
			owner = here
		break
	profile[owner] = int(profile.get(owner, 0)) + n


var _baking := false  # build(): parts are noted down for _merge_parts (see _add)
## node -> its parts noted down: [mesh, material, tint, shadow, position, rotation,
## scale, basis (or null: from rotation and scale), material set over it (or null)]
var _parts := {}


## A noted part as a node (as every part once was made).
func _add_node(parent: Node3D, pt: Array) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = pt[0]
	mi.position = pt[4]
	mi.rotation = pt[5]
	mi.scale = pt[6]
	if not pt[3]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# (Mats.apply)
	Mats.set_material(mi, pt[1])
	if pt[2] != Color(1, 1, 1):
		Mats.set_inst(mi, &"tint", pt[2])
	# continuous camouflage across parts: offset the local pattern space
	var off: Vector3 = pt[4]
	var p := parent
	while p and p != root:
		off += p.position
		p = p.get_parent() as Node3D
	Mats.set_inst(mi, &"pofs", off)
	if pt[7] is Basis:
		mi.basis = pt[7]
	if pt[8] is Material:
		mi.material_override = pt[8]
	return mi


## A part turned by `b` after it was made (laid from a to b): its basis.
func _turn(part: Variant, b: Basis) -> void:
	if part is Array:
		part[7] = b
	else:
		(part as MeshInstance3D).basis = b


## A part that casts no shadow after all.
func _unshadow(part: Variant) -> void:
	if part is Array:
		part[3] = false
	else:
		(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A part given a surface of its own after it was made (a tinted canopy).
func _restyle(part: Variant, m: Material) -> void:
	if part is Array:
		part[8] = m
	else:
		(part as MeshInstance3D).material_override = m


## Moves pv's parts and nodes onto its parent, where they already are, and
## drops pv (VmBoat._bake: a tilted assembly the Field Manual would stand
## wrongly).
func _fold(pv: Node3D) -> void:
	var par := pv.get_parent() as Node3D
	for c in pv.get_children():
		var n := c as Node3D
		var t: Transform3D = pv.transform * n.transform
		pv.remove_child(n)
		par.add_child(n)
		n.transform = t
	if _parts.has(pv):
		if not _parts.has(par):
			_parts[par] = []
		for pt: Array in _parts[pv]:
			# (placed as the part's node, set to the same transform, would be)
			var t2: Transform3D = pv.transform * (Transform3D(pt[7], pt[4]) if pt[7] is Basis else Mats.place(pt[4], pt[5], pt[6]))
			pt[4] = t2.origin
			pt[7] = t2.basis
			(_parts[par] as Array).append(pt)
		_parts.erase(pv)
	par.remove_child(pv)
	pv.free()


## A shared gun builder's assembly `m` is done, its muzzle at `muzzle` in its
## parent's space: noted down (see _guns), then folded into the parent like
## any other construction pivot.
## `hands` are where a gunner holds it, in `m`'s own space ([right, left]).
func _gun(m: Node3D, muzzle: Vector3, hands: Array = []) -> void:
	var parent := m.get_parent() as Node3D
	var parts: Array = (_parts.get(m, []) as Array).duplicate()
	var nodes: Array = m.get_children()
	var held: Array = []
	for h: Vector3 in hands:
		held.append(m.transform * h)
	_guns.append({"parent": parent, "origin": m.position, "muzzle": muzzle, "parts": parts, "nodes": nodes, "hands": held})
	_fold(m)


## A hand-built gun assembly on its own pivot `m` (at its trunnion, square
## to its parent), noted down as the shared builders' are.
func gun_assembly(m: Node3D, muzzle_local: Vector3, hands: Array = []) -> void:
	_gun(m, m.transform * muzzle_local, hands)


## The model is built: the machine gun (and a twin beside it, laid as one) is
## lifted off whatever carries it onto a cradle of its own at its trunnion, so
## the crew can lay it and it can recoil. Its parts move with it unchanged, so
## at rest the model, its muzzle marker and the authority's sockets are exactly
## as built. Wrecks keep their guns where they fell.
func _mount_guns() -> void:
	# (a fixed-wing aircraft's guns are fixed in its nose or its side)
	var fixed_wing := surface_family == "aircraft" and rotor == null and rotors.is_empty()
	if burnt or fixed_wing or mg_tip == null or mg_tip == gun_tip:
		_guns.clear()
		return
	var parent := mg_tip.get_parent() as Node3D
	if parent != turret and parent != root and turret and turret.is_ancestor_of(parent) and absf(parent.rotation.x) > 0.001 and absf(parent.rotation.y) < 0.001 and absf(parent.rotation.z) < 0.001:
		# The builder made the cradle itself, already laid a little (a twin
		# AA gun's, receivers, boxes and all): it is the mount.
		_add_mount(parent)
		_guns.clear()
		return
	var best: Dictionary = {}
	var nearest := 0.3
	for g: Dictionary in _guns:
		# (a gun laid along its carrier's -Z: a cradle elevates about X)
		var axis: Vector3 = (g.muzzle as Vector3) - (g.origin as Vector3)
		if is_instance_valid(g.parent) and g.parent == parent and axis.normalized().dot(Vector3.FORWARD) > 0.95:
			var d := (g.muzzle as Vector3).distance_to(mg_tip.position)
			if d < nearest:
				nearest = d
				best = g
	if best.is_empty():
		_guns.clear()
		return
	var mount := _lift(best)
	_onto(mg_tip, mount)
	_add_mount(mount, best)
	# A twin beside it (the other barrel of a twin AA gun) is laid with it.
	var at: Vector3 = best.origin
	var tip: Vector3 = best.muzzle
	for g: Dictionary in _guns:
		if g == best or not is_instance_valid(g.parent) or g.parent != parent:
			continue
		var o: Vector3 = g.origin
		var t: Vector3 = g.muzzle
		if absf(o.x - at.x) > 0.1 and absf(o.y - at.y) < 0.05 and absf(o.z - at.z) < 0.08 and absf(t.y - tip.y) < 0.05 and absf(t.z - tip.z) < 0.08:
			var twin := _lift(g)
			_add_mount(twin, g)
			# (a twin's own muzzle marker, where it has one, goes with it)
			if gun_tip and gun_tip.get_parent() == parent and gun_tip.position.distance_to(t) < 0.3:
				_onto(gun_tip, twin)
	_guns.clear()


## A cradle at the assembly's origin with its parts and nodes moved onto it.
func _lift(g: Dictionary) -> Node3D:
	var parent: Node3D = g.parent
	var mount := _pivot(parent, g.origin)
	var noted: Array = _parts.get(parent, [])
	for pt: Array in g.parts:
		var i := noted.find(pt)
		if i < 0:
			continue
		noted.remove_at(i)
		pt[4] = (pt[4] as Vector3) - mount.position
		if not _parts.has(mount):
			_parts[mount] = []
		(_parts[mount] as Array).append(pt)
	for n: Node in g.nodes:
		if is_instance_valid(n) and n.get_parent() == parent:
			_onto(n as Node3D, mount)
	return mount


## Moves `n` from its parent onto `mount`, a child of that parent, where it
## already is (the model isn't in the scene tree yet: no global transforms).
func _onto(n: Node3D, mount: Node3D) -> void:
	var xf := mount.transform.affine_inverse() * n.transform
	n.get_parent().remove_child(n)
	mount.add_child(n)
	n.transform = xf


func _add_mount(mount: Node3D, g: Dictionary = {}) -> void:
	mg_mounts.append(mount)
	mg_rests.append(mount.transform)
	var hands: Array = []
	for h: Vector3 in g.get("hands", []):
		hands.append(h - mount.position)
	mg_hands.append(hands)
	var free := turret == null or not turret.is_ancestor_of(mount)
	var door := free and surface_family == "aircraft" and absf(mount.position.x) > 0.5
	mg_stow.append(-signf(mount.position.x) * 1.05 if door else 0.0)
	mg_free = turret == null or not turret.is_ancestor_of(mount)


## Every noted part on surface `from` put on `to`.
func _swap_noted(from: Material, to: Material) -> void:
	for parent: Node3D in _parts:
		for pt: Array in _parts[parent]:
			if Mats.base_of(pt[8] if pt[8] is Material else pt[1]) == from:
				pt[8] = to


## The model is built: a part noted down on a node _merge_parts didn't reach
## is made as a node after all, as it always was.
func _baked() -> void:
	_baking = false
	for parent: Node3D in _parts:
		for pt: Array in _parts[parent]:
			_add_node(parent, pt)
	_parts.clear()


func _box(parent: Node3D, s: Vector3, pos: Vector3, kind: String, col = null, rot := Vector3.ZERO, shadow := true) -> Variant:
	return _add(parent, Res.box(s), kind, col, pos, rot, Vector3.ONE, shadow)


func _bag(parent: Node3D, s: Vector3, pos: Vector3, kind: String, col = null, rot := Vector3.ZERO, shadow := true) -> Variant:
	return VehicleCloth.bag(self, parent, s, pos, kind, col, rot, shadow)

## Res.cyl's cylinder at the same size, but with one band of sides: its middle
## ring splits a straight side in two and adds triangles, not shape.
func _cyl(parent: Node3D, r0: float, r1: float, h: float, pos: Vector3, rot: Vector3, kind: String, col = null, segs := 12, shadow := true) -> Variant:
	return _add(parent, VehicleFrames.rod_mesh(r0, r1, h, segs), kind, col, pos, rot, Vector3.ONE, shadow)


## An empty marker at a muzzle.
func _tip(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## Wheel with tyre and hub on a spinning pivot (axis X).
func _wheel(parent: Node3D, pos: Vector3, r: float, w: float, hub_kind := "gunmetal_w", hub_col = null) -> Node3D:
	var profile := "aircraft" if surface_family == "aircraft" else ("offroad" if surface_family == "armor" and r >= 0.4 else "road")
	return VehicleWheels.pneumatic(self, parent, pos, r, w, hub_kind, hub_col, profile)


## A side's identification mark, painted on as armies paint them for a
## campaign (the inverted-V chevrons of 2003, the bands of others): where the
## old panel box `s` sat, centred on `pos`, on the face its thin axis is the
## normal of (a roof's faces up, a flank's out to its side, an end's fore or
## aft). It's brushed on in the vehicle's own paint, so it takes the dust,
## grime and wear the hull round it takes and never stands clean and dark
## like a hole in the roof; the side's colour, sunk toward the hull's grey,
## still tells the sides apart from the battle camera, and so does its shape
## (`_mark_outline`). Laid on the box's outer face, which stood clear of the
## hull everywhere the box showed. Burnt off a wreck with the paint.
## On a curved skin (a tail boom, a fuselage's tapering flank) a flat card
## stands off the curve with its arms in the air: the caller's `skin` (a
## point in model space moved onto the skin, a few millimetres proud of it)
## lays the mark on the curve instead, in finer pieces that follow it.
func _team_mark(parent: Node3D, team: int, pos: Vector3, s: Vector3, skin := Callable()) -> void:
	if wreck or team < 0:
		return
	var normal := Vector3.UP
	var along := Vector3.RIGHT
	var up := Vector3.FORWARD  # (a roof's mark points at the bow)
	var size := Vector2(s.x, s.z)
	var thin := s.y
	if s.x < s.y and s.x <= s.z:
		normal = Vector3(-1.0 if pos.x < 0.0 else 1.0, 0, 0)
		along = Vector3.BACK
		up = Vector3.UP
		size = Vector2(s.z, s.y)
		thin = s.x
	elif s.z < s.y and s.z < s.x:
		normal = Vector3(0, 0, -1.0 if pos.z < 0.0 else 1.0)
		up = Vector3.UP
		size = Vector2(s.x, s.y)
		thin = s.z
	var o := pos + normal * thin * 0.5
	var col := _mark_col(team, false, normal == Vector3.UP)
	if skin.is_valid():
		VehicleMarkings.polygons(self, parent, [_mark_outline(team, size)], func(q: Vector2) -> Vector3: return skin.call(o + along * q.x + up * q.y), normal, col, "paint", true, 2)
		return
	VehicleMarkings.polygons(self, parent, [_mark_outline(team, size)], func(q: Vector2) -> Vector3: return o + along * q.x + up * q.y, normal, col, "paint", true, 0)


## A team mark's outline, `size` (across, up) centred on the origin: the
## coalition's inverted-V chevron, its arms half the mark's height thick,
## apex up (toward the bow on a roof or wing); the other side's band, its
## ends cut on a slant leaning forward. Two shapes, so the sides read apart
## even where the colour doesn't.
static func _mark_outline(team: int, size: Vector2) -> PackedVector2Array:
	# (a flank's mark box is wide and short: a chevron stretched across all of
	# it, arms half its height thick, read from the battle camera as a smear.
	# Painted no wider than 1.6 times its height, centred, with slimmer arms,
	# it reads as a chevron)
	var wide := size.x > size.y * 1.6
	var w := minf(size.x, size.y * 1.6) * 0.5
	var h := size.y * 0.5
	if team == 0:
		var t := size.y * (0.34 if wide else 0.52)
		return PackedVector2Array([Vector2(0, h), Vector2(w, -h + t), Vector2(w, -h), Vector2(0, h - t), Vector2(-w, -h), Vector2(-w, -h + t)])
	var slant := minf(size.y * 0.6, size.x * 0.3)
	return PackedVector2Array([Vector2(-w + slant, -h), Vector2(w, -h), Vector2(w - slant, h), Vector2(-w, h)])


## A team mark's paint: the side's colour mixed most of the way into a mid
## grey, as a unit's tactical marks are brushed in flat, subdued paint that
## the sun and dust fade further: a dusty slate blue for one side and a dull
## brick for the other, both of about the lightness of the hull round them
## and of each other. Pale tints of the side's colour glowed (a cornflower
## or salmon sticker, the loudest thing on a drab vehicle from the battle
## camera) and a dark navy read as a hole in the roof; mixed this far the
## side's hue still shows against tan, olive and grey, and so does the mark's
## shape (`_mark_outline`). A roof's mark (`roof`) faces the sun and the
## battle camera square on and takes more light than a flank's, so it is
## mixed a shade darker to come out no brighter. A wing's tip band (`band`)
## lies flat to the sun across a wide, lit airfoil on a light grey airframe:
## its paint is the duller still, so it frames the wing without reading as a
## lit strip.
static func _mark_col(team: int, band := false, roof := false) -> Color:
	var tc: Color = Defs.TEAM_COLORS[team]
	# (the red side's grey is a warm one: mixed into a neutral grey its red
	# turned a mauve under the sky's blue light, where a red oxide's brick
	# stays red)
	var grey := Vector3(1.0, 0.93, 0.83) if team != 0 else Vector3.ONE
	var v := 0.35 if band else (0.34 if roof else 0.4)
	return tc.lerp(Color(grey.x * v, grey.y * v, grey.z * v), 0.8 if band else (0.78 if roof else 0.75))


# --- tanks -----------------------------------------------------------------------

func _tank(team: int) -> void:
	var cam := "camo_tank"
	var m := root
	# lower hull between the tracks
	_add(m, loft("t_low", [-1.1, -2.95, 1.1, -2.95, 1.1, 3.0, -1.1, 3.0], [-1.1, -3.4, 1.1, -3.4, 1.1, 3.15, -1.1, 3.15], 0.38, 1.0), cam, null, Vector3.ZERO)
	# upper hull with a long sloped glacis
	_add(m, loft("t_up", [-1.74, -3.4, 1.74, -3.4, 1.74, 3.2, -1.74, 3.2], [-1.64, -1.85, 1.64, -1.85, 1.64, 3.15, -1.64, 3.15], 0.98, 1.52), cam, null, Vector3.ZERO)
	# tracks: side profile extruded across x
	var tp := [-3.45, 0.62, -3.0, 0.06, 2.85, 0.06, 3.35, 0.58, 3.1, 0.98, -3.1, 0.98]
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("t_trk", tp, -0.32, 0.32), "track", null, Vector3(s * 1.43, 0, 0))
		for i in 7:
			_wheel(m, Vector3(s * 1.45, 0.38, -2.45 + i * 0.8), 0.33, 0.5)
		_wheel(m, Vector3(s * 1.45, 0.56, -3.05), 0.3, 0.45)
		_wheel(m, Vector3(s * 1.45, 0.6, 2.95), 0.34, 0.45)
		# side skirts: bolted panels with gaps between them, the front one angled
		for i in 6:
			_box(m, Vector3(0.07, 0.62, 0.9), Vector3(s * 1.78, 0.74, -2.0 + i * 0.92), cam)
			_box(m, Vector3(0.09, 0.05, 0.06), Vector3(s * 1.8, 1.0, -2.0 + i * 0.92), "gunmetal_w", null, Vector3.ZERO, false)
		_box(m, Vector3(0.07, 0.5, 0.9), Vector3(s * 1.78, 0.8, -2.95), cam, null, Vector3(0.35, 0, 0))
		_box(m, Vector3(0.22, 0.05, 6.4), Vector3(s * 1.66, 1.06, 0.1), cam)
		# headlights and tow hooks
		_box(m, Vector3(0.22, 0.12, 0.1), Vector3(s * 1.2, 1.12, -3.36), "gunmetal_w")
		_box(m, Vector3(0.12, 0.16, 0.2), Vector3(s * 0.7, 0.62, -3.42), "gunmetal_w")
	# rear deck: engine grilles and exhaust
	_box(m, Vector3(2.6, 0.04, 1.6), Vector3(0, 1.53, 2.2), "gunmetal_w")
	_box(m, Vector3(2.4, 0.5, 0.06), Vector3(0, 1.15, 3.2), "gunmetal_w")
	_cyl(m, 0.24, 0.24, 0.12, Vector3(0, 1.53, -1.55), Vector3.ZERO, cam, null, 12)
	# turret
	turret = _pivot(m, Vector3(0, 1.55, 0.4))
	var tb := [-0.5, -1.95, 0.5, -1.95, 1.3, -1.15, 1.4, 1.0, 1.15, 1.9, -1.15, 1.9, -1.4, 1.0, -1.3, -1.15]
	var tt := [-0.42, -1.72, 0.42, -1.72, 1.14, -1.0, 1.24, 0.95, 1.04, 1.74, -1.04, 1.74, -1.24, 0.95, -1.14, -1.0]
	_add(turret, loft("t_tur", tb, tt, 0.0, 0.74), cam, null, Vector3.ZERO)
	# bustle rack with stowage
	_box(turret, Vector3(2.2, 0.05, 0.6), Vector3(0, 0.25, 2.15), "gunmetal_w")
	_box(turret, Vector3(2.2, 0.35, 0.04), Vector3(0, 0.45, 2.45), "gunmetal_w")
	# stowage bins along the turret sides, the commander's independent sight
	for s in [-1.0, 1.0]:
		_box(turret, Vector3(0.3, 0.4, 1.0), Vector3(s * 1.35, 0.36, 1.0), cam, null, Vector3(0, s * -0.12, 0))
	_box(turret, Vector3(0.3, 0.32, 0.32), Vector3(-0.25, 0.92, -0.15), cam)
	_box(turret, Vector3(0.24, 0.16, 0.02), Vector3(-0.25, 0.95, -0.32), "glass")
	_box(turret, Vector3(0.6, 0.06, 0.5), Vector3(-0.55, 0.77, 0.5), cam)
	_box(turret, Vector3(0.8, 0.4, 0.45), Vector3(-0.55, 0.5, 2.15), "canvas", Color(0.33, 0.35, 0.24), Vector3(0, 0.1, 0))
	_box(turret, Vector3(0.6, 0.32, 0.42), Vector3(0.45, 0.46, 2.18), "canvas", Color(0.4, 0.38, 0.28), Vector3(0, -0.15, 0))
	# mantlet, barrel, fume extractor, muzzle
	_box(turret, Vector3(0.95, 0.52, 0.4), Vector3(0, 0.36, -1.95), cam)
	_cyl(turret, 0.1, 0.13, 3.9, Vector3(0, 0.38, -3.85), Vector3(PI / 2, 0, 0), "paint", Color(0.3, 0.33, 0.24), 12)
	_cyl(turret, 0.17, 0.17, 0.75, Vector3(0, 0.38, -3.25), Vector3(PI / 2, 0, 0), "paint", Color(0.3, 0.33, 0.24), 12)
	_cyl(turret, 0.13, 0.13, 0.18, Vector3(0, 0.38, -5.75), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	gun_tip = _tip(turret, Vector3(0, 0.38, -5.86))
	# coaxial MG beside the main gun
	_cyl(turret, 0.022, 0.022, 0.32, Vector3(0.34, 0.3, -2.28), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0.34, 0.3, -2.45))
	# commander cupola + MG, loader hatch, gunner sight
	_cyl(turret, 0.36, 0.38, 0.26, Vector3(0.55, 0.86, 0.35), Vector3.ZERO, cam, null, 14)
	_cyl(turret, 0.3, 0.3, 0.06, Vector3(0.55, 1.02, 0.35), Vector3(0.0, 0, -0.5), cam, null, 12)
	_box(turret, Vector3(0.1, 0.14, 0.8), Vector3(0.55, 1.1, -0.05), "gunmetal_w")
	_cyl(turret, 0.28, 0.28, 0.08, Vector3(-0.55, 0.78, 0.5), Vector3.ZERO, cam, null, 12)
	_box(turret, Vector3(0.36, 0.3, 0.45), Vector3(-0.72, 0.88, -1.15), cam)
	_box(turret, Vector3(0.3, 0.2, 0.02), Vector3(-0.72, 0.9, -1.38), "glass")
	# smoke grenade launchers
	for s in [-1.0, 1.0]:
		for i in 4:
			_cyl(turret, 0.05, 0.05, 0.25, Vector3(s * (1.12 + i * 0.02), 0.55 + (i % 2) * 0.1, -1.05 + i * 0.12), Vector3(-0.9, 0, s * 0.4), "gunmetal_w", null, 6, false)
		_cyl(turret, 0.012, 0.012, 2.3, Vector3(s * 0.9, 1.85, 1.6), Vector3.ZERO, "gunmetal_w", null, 4, false)
	_team_mark(turret, team, Vector3(1.22, 0.42, 0.3), Vector3(0.04, 0.26, 0.8))
	_team_mark(turret, team, Vector3(-1.22, 0.42, 0.3), Vector3(0.04, 0.26, 0.8))


func _old_tank(team: int) -> void:
	var cam := "camo_tank_rebel"
	var m := root
	_add(m, loft("o_low", [-1.08, -2.9, 1.08, -2.9, 1.08, 2.95, -1.08, 2.95], [-1.08, -3.25, 1.08, -3.25, 1.08, 3.05, -1.08, 3.05], 0.42, 0.95), cam, null, Vector3.ZERO)
	_add(m, loft("o_up", [-1.62, -3.25, 1.62, -3.25, 1.62, 3.1, -1.62, 3.1], [-1.55, -2.15, 1.55, -2.15, 1.55, 3.05, -1.55, 3.05], 0.93, 1.38), cam, null, Vector3.ZERO)
	var tp := [-3.35, 0.7, -2.85, 0.06, 2.75, 0.06, 3.25, 0.66, 3.0, 0.92, -3.0, 0.92]
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("o_trk", tp, -0.3, 0.3), "track", null, Vector3(s * 1.38, 0, 0))
		for i in 5:
			_wheel(m, Vector3(s * 1.4, 0.44, -2.25 + i * 1.12), 0.42, 0.48, "paint", Color(0.42, 0.38, 0.27))
		_wheel(m, Vector3(s * 1.4, 0.62, -2.95), 0.3, 0.42)
		# fenders and external fuel tanks
		_box(m, Vector3(0.66, 0.05, 6.3), Vector3(s * 1.4, 0.96, 0.0), cam)
		for i in 3:
			_box(m, Vector3(0.42, 0.4, 0.6), Vector3(s * 1.42, 1.2, 0.6 + i * 0.68), "steel", Color(0.32, 0.3, 0.23))
	# rear fuel drums and unditching log
	for s in [-1.0, 1.0]:
		_cyl(m, 0.28, 0.28, 0.9, Vector3(s * 0.7, 1.68, 3.15), Vector3(PI / 2, 0, 0), "steel", Color(0.3, 0.32, 0.24))
	_cyl(m, 0.14, 0.14, 2.9, Vector3(0, 1.5, 3.45), Vector3(0, 0, PI / 2), "bark")
	_box(m, Vector3(2.4, 0.04, 1.4), Vector3(0, 1.39, 2.0), "gunmetal_w")
	# dome turret
	turret = _pivot(m, Vector3(0, 1.4, 0.25))
	_cyl(turret, 1.15, 1.2, 0.18, Vector3(0, 0.05, 0), Vector3.ZERO, cam, null, 20)
	_add(turret, Res.sphere(1.0, 20), cam, null, Vector3(0, 0.12, 0.05), Vector3.ZERO, Vector3(1.22, 0.62, 1.32))
	_box(turret, Vector3(0.62, 0.48, 0.5), Vector3(0, 0.32, -1.18), cam)
	_cyl(turret, 0.09, 0.11, 3.6, Vector3(0, 0.34, -3.15), Vector3(PI / 2, 0, 0), "paint", Color(0.44, 0.4, 0.29), 10)
	_cyl(turret, 0.14, 0.14, 0.4, Vector3(0, 0.34, -4.1), Vector3(PI / 2, 0, 0), "paint", Color(0.44, 0.4, 0.29), 10)
	gun_tip = _tip(turret, Vector3(0, 0.34, -4.32))
	_cyl(turret, 0.02, 0.02, 0.28, Vector3(0.24, 0.28, -1.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0.24, 0.28, -1.65))
	_box(turret, Vector3(0.25, 0.25, 0.25), Vector3(-0.45, 0.62, -1.0), "gunmetal_w")
	_cyl(turret, 0.3, 0.32, 0.18, Vector3(-0.45, 0.72, 0.35), Vector3.ZERO, cam, null, 12)
	_cyl(turret, 0.28, 0.28, 0.16, Vector3(0.5, 0.72, 0.35), Vector3.ZERO, cam, null, 12)
	# DShK on the loader hatch
	_box(turret, Vector3(0.1, 0.14, 0.7), Vector3(0.5, 0.95, 0.0), "gunmetal_w")
	_cyl(turret, 0.03, 0.03, 0.9, Vector3(0.5, 0.97, -0.75), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	_cyl(turret, 0.012, 0.012, 2.0, Vector3(-0.7, 1.4, 0.6), Vector3.ZERO, "gunmetal_w", null, 4, false)
	_team_mark(turret, team, Vector3(1.18, 0.35, 0.2), Vector3(0.04, 0.22, 0.6))
	_team_mark(turret, team, Vector3(-1.18, 0.35, 0.2), Vector3(0.04, 0.22, 0.6))


# --- wheeled ---------------------------------------------------------------------

func _technical(team: int, seed: int, aa := false) -> void:
	# sun-faded civilian paint, the way these trucks actually look
	var paint: Color = [Color(0.66, 0.64, 0.58), Color(0.55, 0.48, 0.36), Color(0.36, 0.37, 0.3), Color(0.34, 0.17, 0.14)][seed % 4]
	var m := root
	_box(m, Vector3(1.3, 0.22, 4.5), Vector3(0, 0.55, 0.1), "gunmetal_w")
	# body sides, hood and cab
	_add(m, loft("pk_lo", [-0.92, -2.35, 0.92, -2.35, 0.92, 2.35, -0.92, 2.35], [-0.92, -2.3, 0.92, -2.3, 0.92, 2.35, -0.92, 2.35], 0.62, 1.05), "car_paint", paint, Vector3.ZERO)
	_add(m, loft("pk_hood", [-0.9, -2.3, 0.9, -2.3, 0.9, -1.0, -0.9, -1.0], [-0.86, -2.2, 0.86, -2.2, 0.86, -1.0, -0.86, -1.0], 1.04, 1.2), "car_paint", paint, Vector3.ZERO)
	_add(m, loft("pk_cab", [-0.9, -1.02, 0.9, -1.02, 0.9, 0.3, -0.9, 0.3], [-0.8, -0.42, 0.8, -0.42, 0.8, 0.22, -0.8, 0.22], 1.04, 1.78), "car_paint", paint, Vector3.ZERO)
	# glass
	_box(m, Vector3(1.55, 0.6, 0.03), Vector3(0, 1.45, -0.74), "glass", null, Vector3(-0.85, 0, 0), false)
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.03, 0.4, 0.75), Vector3(s * 0.86, 1.5, -0.12), "glass", null, Vector3(0, 0, s * 0.12), false)
	_box(m, Vector3(1.45, 0.38, 0.03), Vector3(0, 1.5, 0.27), "glass", null, Vector3.ZERO, false)
	# bed
	_box(m, Vector3(1.75, 0.06, 1.95), Vector3(0, 1.06, 1.35), "steel", paint.darkened(0.3))
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.06, 0.42, 2.0), Vector3(s * 0.9, 1.28, 1.35), "car_paint", paint)
	_box(m, Vector3(1.8, 0.42, 0.06), Vector3(0, 1.28, 2.35), "car_paint", paint)
	# bumpers, grille, lights
	_box(m, Vector3(1.9, 0.18, 0.16), Vector3(0, 0.75, -2.4), "steel")
	_box(m, Vector3(1.9, 0.14, 0.14), Vector3(0, 0.72, 2.42), "steel")
	_box(m, Vector3(1.1, 0.25, 0.03), Vector3(0, 0.98, -2.35), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.24, 0.13, 0.03), Vector3(s * 0.68, 0.98, -2.36), "glass")
	# wheels with arches
	for s in [-1.0, 1.0]:
		for z in [-1.55, 1.5]:
			_wheel(m, Vector3(s * 0.84, 0.4, z), 0.4, 0.28)
	# bull bar, mirrors, a roll bar behind the cab with lights, door seams,
	# wheel-arch flares
	for s in [-1.0, 1.0]:
		_cyl(m, 0.03, 0.03, 0.55, Vector3(s * 0.55, 1.0, -2.55), Vector3.ZERO, "gunmetal_w", null, 6)
		_box(m, Vector3(0.12, 0.14, 0.03), Vector3(s * 1.02, 1.42, -0.85), "gunmetal_w")
		_cyl(m, 0.035, 0.035, 0.75, Vector3(s * 0.75, 1.55, 0.42), Vector3.ZERO, "gunmetal_w", null, 6)
		_box(m, Vector3(0.02, 0.4, 0.03), Vector3(s * 0.925, 1.2, -0.15), "gunmetal_w", null, Vector3.ZERO, false)
		for z in [-1.55, 1.5]:
			_box(m, Vector3(0.12, 0.05, 1.0), Vector3(s * 0.94, 1.02, z), "car_paint", paint.darkened(0.15))
	_cyl(m, 0.03, 0.03, 1.15, Vector3(0, 0.82, -2.6), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6)
	_cyl(m, 0.03, 0.03, 1.1, Vector3(0, 1.27, -2.55), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6)
	_cyl(m, 0.035, 0.035, 1.55, Vector3(0, 1.93, 0.42), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6)
	for x in [-0.3, 0.3]:
		_box(m, Vector3(0.18, 0.12, 0.1), Vector3(x, 2.0, 0.4), "gunmetal_w")
	# spare tyre and ammo cans in the bed
	_cyl(m, 0.36, 0.36, 0.24, Vector3(-0.42, 1.22, 0.75), Vector3(0, 0, 0), "rubber", null, 12)
	_box(m, Vector3(0.3, 0.2, 0.18), Vector3(0.5, 1.19, 2.0), "paint", Color(0.3, 0.33, 0.22))
	_box(m, Vector3(0.3, 0.2, 0.18), Vector3(0.5, 1.39, 2.0), "paint", Color(0.3, 0.33, 0.22))
	if aa:
		# ZU-23 twin cannon on a turntable in the bed
		turret = _pivot(m, Vector3(0, 1.15, 1.35))
		_cyl(turret, 0.55, 0.6, 0.18, Vector3(0, 0.05, 0), Vector3.ZERO, "paint", Color(0.33, 0.35, 0.27), 14)
		_box(turret, Vector3(0.9, 0.45, 0.9), Vector3(0, 0.4, 0.05), "paint", Color(0.33, 0.35, 0.27))
		for sx in [-0.17, 0.17]:
			_cyl(turret, 0.05, 0.06, 2.3, Vector3(sx, 0.62, -1.2), Vector3(PI / 2 + 0.15, 0, 0), "gunmetal_w", null, 8)
			_cyl(turret, 0.08, 0.08, 0.25, Vector3(sx, 0.78, -2.3), Vector3(PI / 2 + 0.15, 0, 0), "gunmetal_w", null, 8, false)
		_box(turret, Vector3(0.5, 0.35, 0.03), Vector3(-0.45, 0.75, -0.3), "steel", Color(0.32, 0.3, 0.25))
		_box(turret, Vector3(0.25, 0.3, 0.3), Vector3(0.45, 0.5, 0.3), "paint", Color(0.3, 0.33, 0.22))
		mg_tip = _tip(turret, Vector3(0, 0.81, -2.44))
		_team_mark(m, team, Vector3(0.93, 1.2, 1.35), Vector3(0.03, 0.2, 0.8))
		return
	# heavy MG on a pintle
	turret = _pivot(m, Vector3(0, 1.3, 1.1))
	_cyl(turret, 0.05, 0.06, 0.9, Vector3(0, 0.25, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	_box(turret, Vector3(0.18, 0.2, 0.75), Vector3(0, 0.78, -0.05), "gunmetal_w")
	_cyl(turret, 0.035, 0.035, 1.15, Vector3(0, 0.8, -0.95), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	_cyl(turret, 0.06, 0.06, 0.2, Vector3(0, 0.8, -1.45), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	mg_tip = _tip(turret, Vector3(0, 0.8, -1.56))
	_box(turret, Vector3(0.75, 0.5, 0.04), Vector3(0, 0.92, -0.35), "steel", Color(0.32, 0.3, 0.25))
	_box(turret, Vector3(0.12, 0.12, 0.25), Vector3(0.14, 0.7, 0.15), "paint", Color(0.3, 0.33, 0.22))
	_team_mark(m, team, Vector3(0.93, 1.2, 1.35), Vector3(0.03, 0.2, 0.8))


## Where a car's side profile (z, y pairs) crosses height y at its nose
## (`front`) or tail: x the face's z there, y how far it leans (dz per metre up).
static func _car_face(prof: Array, y: float, front: bool) -> Vector2:
	var best := Vector2(INF if front else -INF, 0.0)
	var n := prof.size()
	for i in range(0, n, 2):
		var a := Vector2(prof[i], prof[i + 1])
		var b := Vector2(prof[(i + 2) % n], prof[(i + 3) % n])
		if (y - a.y) * (y - b.y) <= 0.0 and absf(b.y - a.y) > 1e-5:
			var z := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
			if (z < best.x) if front else (z > best.x):
				best = Vector2(z, (b.x - a.x) / (b.y - a.y))
	return best


## Civilian cars, side profiles extruded across the width: a body with a
## shaped bonnet and boot, a narrower glasshouse on top, dark glass, bumpers,
## lights, wheels in arches. Local -Z is the front.
func _car(v: int, col: Color) -> void:
	var m := root
	var w := 0.88  # half width
	var body: Array
	var house: Array
	match v:
		1:  # hatchback: short, upright back
			body = [-1.9, 0.3, 1.85, 0.3, 1.92, 0.58, 1.86, 0.92, -1.0, 0.95, -1.88, 0.82, -1.95, 0.52]
			house = [-0.95, 0.93, 1.78, 0.93, 1.72, 1.42, -0.35, 1.46]
		2:  # pickup: cab and an open bed
			body = [-2.45, 0.38, 2.4, 0.38, 2.45, 0.7, 2.4, 1.02, -1.15, 1.02, -2.4, 0.92, -2.48, 0.6]
			house = [-1.1, 1.0, 0.45, 1.0, 0.42, 1.68, -0.62, 1.7]
		3:  # van: one tall box
			body = [-2.3, 0.35, 2.3, 0.35, 2.32, 0.7, 2.3, 1.05, -1.55, 1.05, -2.28, 0.95, -2.34, 0.6]
			house = [-1.55, 1.03, 2.28, 1.03, 2.28, 2.0, -0.9, 2.05]
		4:  # estate: long roof to the back
			body = [-2.3, 0.3, 2.25, 0.3, 2.32, 0.6, 2.28, 0.92, -1.15, 0.95, -2.25, 0.83, -2.33, 0.55]
			house = [-1.1, 0.93, 2.2, 0.93, 2.12, 1.43, -0.5, 1.46]
		_:  # saloon: bonnet, cabin, boot
			body = [-2.25, 0.3, 2.2, 0.3, 2.28, 0.6, 2.18, 0.9, 1.25, 0.95, -1.15, 0.96, -2.2, 0.82, -2.3, 0.55]
			house = [-1.1, 0.93, 1.3, 0.93, 0.75, 1.43, -0.45, 1.45]
	var key := "car%d" % v
	var bf: float = minf(body[0], body[body.size() - 2])
	var bb: float = maxf(body[2], body[4])
	var wz := [bf + 0.75, bb - 0.75]
	# The body is pressed sheet: its shoulders and the bends into the bonnet
	# and boot roll over (shaded smooth, as the drivable cars'), the nose and
	# tail round off in plan, and the arches are cut round the tyres. A flat
	# slab with dead-sharp edges read as a painted box from the RTS camera.
	VehicleWheelArches._xbody(self, m, key + "b", body, -w, w, 0.05, [[wz[0], 0.33, 0.37], [wz[1], 0.33, 0.37]], "car_paint", col, 6, [0.42, 0.07, 0.36, 0.06], VmCiv.ROLL)
	var hw := w - 0.1 if v != 3 else w - 0.02
	var hz: Array = house
	var fz: float = hz[0]
	var fy: float = hz[1]
	var tz: float = hz[6]
	var rz: float = hz[4]
	var bz: float = hz[2]
	var by: float = hz[3]
	# The roof is pressed with a crown and rolls over into the pillars, so the
	# sun slides across it as a soft highlight: a dead-flat top flashed white
	# from above whatever the paint (the drivable cars' _yloft). Its sides stay
	# upright, so the side glass still lies on them.
	var ty: float = (float(hz[5]) + float(hz[7])) * 0.5
	var ry: float = ty
	VmCiv._yloft(self, m, key + "h", [[-hw, fz, hw, fz, hw, bz, -hw, bz], [-hw, tz, hw, tz, hw, rz, -hw, rz]], [fy, ty], 0.05, "car_paint", col, Vector3.ZERO, 0.6)
	# glass: windscreen, rear screen, side windows (inset a touch)
	if not burnt:
		var inside := Vector3(0, (fy + ty) * 0.5, (fz + bz) * 0.5)
		var front_face := [Vector3(-hw, fy, fz), Vector3(hw, fy, fz), Vector3(hw, ty, tz), Vector3(-hw, ty, tz)]
		var rear_face := [Vector3(hw, by, bz), Vector3(-hw, by, bz), Vector3(-hw, ry, rz), Vector3(hw, ry, rz)]
		VehicleGlazing.quad(self, m, key + "front_glass", front_face, inside, Rect2(0.06, 0.08, 0.88, 0.84), 0.012, 0.012, "glass")
		VehicleGlazing.quad(self, m, key + "rear_glass", rear_face, inside, Rect2(0.08, 0.12, 0.84, 0.76), 0.012, 0.012, "glass")
		for side in [-1.0, 1.0]:
			var face := [Vector3(side * hw, fy, fz), Vector3(side * hw, by, bz), Vector3(side * hw, ry, rz), Vector3(side * hw, ty, tz)]
			var panes := 1 if v == 2 else 2
			for pane in panes:
				VehicleGlazing.quad(self, m, key + "side_%s_%d" % [side, pane], face, inside, Rect2(0.06 + pane * 0.46, 0.13, 0.88 if panes == 1 else 0.42, 0.74), 0.012, 0.012, "glass")
			# The wing mirror: a car's is a moulded shell on a short foot at
			# the window's front corner, in the body's paint (black on the
			# older cars that keep their chrome), its glass facing back. (A
			# truck's mirror on tubular arms and a ball joint read as fitted
			# kit, and cost a thousand vertices a side.)
			var black := absi(hash(col.to_html(false) + str(v))) % 3 == 0
			var glass_at := Vector3(side * (w + 0.075), fy + 0.12, fz + 0.24)
			VmCiv._strut(self, m, Vector3(side * (hw + 0.03), fy + 0.03, fz + 0.27), glass_at + Vector3(-side * 0.04, -0.03, 0.0), 0.06, 0.03, "plain", VmCiv.TRIM, false)
			_add(m, BevelMesh.make(Vector3(0.16, 0.1, 0.07), 0.022), "plain" if black else "car_paint", VmCiv.TRIM if black else col, glass_at)
			_box(m, Vector3(0.135, 0.075, 0.006), glass_at + Vector3(0, 0, 0.036), "mirror", Color(0.78, 0.82, 0.84), Vector3.ZERO, false)
	# The doors' shut lines down the sides, each stopping on the sill or over
	# the rear arch, a handle near each door's rear edge, and the bonnet's U:
	# the gaps that break a car's flank and bonnet into the pressings they are.
	var last := minf(bz - 0.03, float(wz[1]) - 0.1) if v != 2 else bz - 0.02
	var edges: Array = [fz + 0.02, (fz + last) * 0.5, last] if v in [0, 1, 4] else [fz + 0.02, last if v == 2 else fz + 0.92]
	for side in [-1.0, 1.0]:
		for i in edges.size():
			var z: float = edges[i]
			var foot := float(body[1]) + 0.07
			for c: float in wz:
				if absf(z - c) < 0.37:
					foot = maxf(foot, 0.33 + sqrt(0.37 * 0.37 - (z - c) * (z - c)) + 0.03)
			VehicleBody.seam(self, m, [Vector3(side * (w + 0.002), fy - 0.04, z), Vector3(side * (w + 0.002), foot, z)], 0.004)
			if i > 0 and not burnt:
				# a flush pull handle moulded into the door skin, black (a
				# truck's bar handle on its posts stood off a car's door)
				_add(m, BevelMesh.make(Vector3(0.014, 0.03, 0.13), 0.005), "plain", VmCiv.TRIM, Vector3(side * (w + 0.004), fy - 0.09, z - 0.16), Vector3.ZERO, Vector3.ONE, false)
	VmCiv._bonnet_line(self, m, body, w - 0.22, fz - 0.06, bf + 0.16)
	# Moulded bumpers, lights, plate. Parked cars of one shape differ by more
	# than paint, as a street's do: some older ones keep chrome bumpers, and
	# the wheel trims are silver, white or painted dark (drawn from the paint
	# and shape, so a look still builds the same).
	var trim := absi(hash(col.to_html(false) + str(v)))
	var chrome := trim % 3 == 0
	for z: float in [bf - 0.02, bb + 0.02]:
		VehicleMounts.bumper(self, m, Vector3(w * 2.0 + 0.04, 0.16, 0.12), Vector3(0, 0.42, z), "steel" if chrome else "rubber", Color(0.7, 0.71, 0.72) if chrome else null, Vector3.ZERO, true)
	var hub: Color = [Color(0.62, 0.63, 0.62), Color(0.76, 0.76, 0.74), Color(0.24, 0.245, 0.25)][(trim >> 3) % 3]
	# About one car in four runs on a bonnet from a breaker's yard, never
	# painted to match: grey primer, or another car's colour. From above the
	# bonnet is the biggest panel the battle camera sees, so this is what keeps
	# a street of one shape from looking stamped from one mould. (A film on
	# the bonnet's own slope, inside its shut lines.)
	# (hashed shape first, so each shape of one paint draws its own)
	var odd := absi(hash(str(v) + col.to_html(false)))
	if odd % 4 == 0 and not burnt:
		VmCiv._odd_bonnet(self, m, body, w - 0.22, fz - 0.1, bf + 0.2, col, odd >> 3)
	# The lamps sit on the nose and tail as they lean (they floated a few
	# centimetres ahead of a raked nose): sealed rectangular headlamps either
	# side of a black grille, amber indicators under them, and tail clusters,
	# each a housing round a ribbed lens rather than a flat white tile.
	var nose := _car_face(body, 0.68, true)
	var tail := _car_face(body, 0.74, false)
	var rake := atan(nose.y)
	for s in [-1.0, 1.0]:
		VehicleFittings.rectangular_headlamp(self, m, Vector3(s * (w - 0.24), 0.68, nose.x - 0.006), Vector2(0.3, 0.1), Vector3(rake, 0, 0))
		var lamp := _pivot(m, Vector3(s * (w - 0.2), 0.74, tail.x - 0.004))
		lamp.rotation.x = atan(tail.y)
		VehicleFittings.signal_lens(self, lamp, Vector3.ZERO, Vector2(0.24, 0.12), Color(0.62, 0.06, 0.05))
		_fold(lamp)
		if not burnt:
			var low := _car_face(body, 0.585, true)
			_add(m, Res.box(Vector3(0.16, 0.04, 0.02)), "signal_lens", Color(0.8, 0.46, 0.1), Vector3(s * (w - 0.24), 0.585, low.x - 0.004), Vector3(atan(low.y), 0, 0), Vector3.ONE, false)
	# the grille between them: a black mesh panel behind three slats, bright
	# on a car that keeps its chrome
	var grille := _pivot(m, Vector3(0, 0.68, nose.x - 0.004))
	grille.rotation.x = rake
	_box(grille, Vector3(w * 2.0 - 0.86, 0.11, 0.012), Vector3.ZERO, "rubber", Color(0.025, 0.025, 0.025), Vector3.ZERO, false)
	for i in 3:
		_box(grille, Vector3(w * 2.0 - 0.9, 0.012, 0.014), Vector3(0, (i - 1) * 0.034, -0.008), "steel" if chrome else "rubber", Color(0.7, 0.71, 0.72) if chrome else Color(0.1, 0.1, 0.1), Vector3.ZERO, false)
	_fold(grille)
	if not burnt:
		VehicleMarkings.plate(self, m, Vector3(0, 0.5, bb + 0.09), Vector2(0.42, 0.11), Vector3.BACK, 0.0, "", 0.02, Color(0.9, 0.88, 0.8))
	if v == 2:
		# the bed: its sides (their top rails rolled over, as pressed sheet's
		# are), the ribbed tailgate between them, the rubber mat
		for s in [-1.0, 1.0]:
			VmCiv._rolled(self, m, key + "bed%d" % int(s), Vector3(s * (w - 0.03), 1.2, 1.4), Vector3(0.06, 0.38, 1.95), "car_paint", col)
		VehicleCargo.sideboard(self, m, Vector3(w * 2.0, 0.38, 0.06), Vector3(0, 1.2, 2.38), "car_paint", col, Vector3.ZERO, 2)
		_box(m, Vector3(w * 2.0 - 0.1, 0.04, 1.9), Vector3(0, 1.03, 1.4), "rubber")
	# wheels under black plastic arch trims: a band round the top of each tyre,
	# a few centimetres proud of the side so the arch reads from above without
	# hiding the wheel (a flat slab here sat over it like a mud flap)
	for s: float in [-1.0, 1.0]:
		for z: float in wz:
			var x0 := w - 0.03 if s > 0.0 else -(w + 0.012)
			var x1 := w + 0.012 if s > 0.0 else -(w - 0.03)
			VehicleWheelArches._flare(self, m, "%sarch_%d_%d" % [key, int(s), roundi(z * 100.0)], z, 0.33, 0.345, 0.41, x0, x1, 0.0, PI, "rubber", null, 6)
			_wheel(m, Vector3(s * (w - 0.1), 0.33, z), 0.33, 0.22, "steel", hub)


## M1151 Humvee: wide and low, a long sloping bonnet over the grille, the
## armoured crew cab with its thick little windows and four heavy doors, the
## rear cargo shell, fender flares over big tyres, and the gunner's
## protection kit with an M2 on the roof.
func _humvee(team: int) -> void:
	var cam := "camo_tank" if team == 0 else "camo_tank_rebel"
	var m := root
	_box(m, Vector3(1.5, 0.25, 4.4), Vector3(0, 0.6, 0), "gunmetal_w")
	_add(m, loft("hv2_low", [-1.08, -2.42, 1.08, -2.42, 1.1, 2.45, -1.1, 2.45], [-1.1, -2.42, 1.1, -2.42, 1.1, 2.45, -1.1, 2.45], 0.62, 1.12), cam, null, Vector3.ZERO)
	_add(m, loft("hv2_hood", [-1.05, -2.42, 1.05, -2.42, 1.05, -0.85, -1.05, -0.85], [-0.95, -2.22, 0.95, -2.22, 1.0, -0.85, -1.0, -0.85], 1.11, 1.3), cam, null, Vector3.ZERO)
	_add(m, loft("hv2_cab", [-1.1, -0.9, 1.1, -0.9, 1.1, 1.3, -1.1, 1.3], [-1.02, -0.62, 1.02, -0.62, 1.02, 1.22, -1.02, 1.22], 1.11, 1.92), cam, null, Vector3.ZERO)
	_add(m, loft("hv2_rear", [-1.1, 1.28, 1.1, 1.28, 1.1, 2.45, -1.1, 2.45], [-1.06, 1.28, 1.06, 1.28, 1.06, 2.4, -1.06, 2.4], 1.11, 1.5), cam, null, Vector3.ZERO)
	# grille with its slats, headlights in their guards, bumper and winch
	_box(m, Vector3(1.1, 0.42, 0.04), Vector3(0, 0.92, -2.43), "gunmetal_w")
	for i in 7:
		_box(m, Vector3(0.05, 0.38, 0.03), Vector3(-0.45 + i * 0.15, 0.92, -2.455), cam, null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.24, 0.16, 0.06), Vector3(s * 0.78, 1.02, -2.43), "gunmetal_w")
		_box(m, Vector3(0.16, 0.1, 0.02), Vector3(s * 0.78, 1.02, -2.465), "glass")
	_box(m, Vector3(2.05, 0.2, 0.22), Vector3(0, 0.68, -2.55), "steel")
	_box(m, Vector3(0.5, 0.18, 0.2), Vector3(0, 0.7, -2.68), "gunmetal_w")
	# split windscreen, armoured door windows, door seams, mirrors
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.82, 0.5, 0.05), Vector3(s * 0.46, 1.62, -0.78), "glass", null, Vector3(-0.38, 0, 0), false)
		_box(m, Vector3(0.05, 0.62, 0.06), Vector3(s * 1.0, 1.62, -0.75), cam, null, Vector3(-0.38, 0, 0), false)
		for dz in [-0.32, 0.72]:
			_box(m, Vector3(0.04, 0.34, 0.52), Vector3(s * 1.07, 1.62, dz), "glass", null, Vector3(0, 0, s * 0.06), false)
		for dz in [-0.88, 0.2, 1.28]:
			_box(m, Vector3(0.02, 0.8, 0.03), Vector3(s * 1.105, 1.35, dz), "gunmetal_w", null, Vector3.ZERO, false)
		_box(m, Vector3(0.03, 0.04, 0.12), Vector3(s * 1.11, 1.32, -0.15), "gunmetal_w", null, Vector3.ZERO, false)
		_box(m, Vector3(0.16, 0.2, 0.04), Vector3(s * 1.25, 1.65, -0.9), "gunmetal_w")
		# fender flares over the wheels
		for z in [-1.62, 1.62]:
			_box(m, Vector3(0.18, 0.06, 1.15), Vector3(s * 1.08, 1.13, z), cam)
			_wheel(m, Vector3(s * 0.95, 0.48, z), 0.48, 0.4)
	_box(m, Vector3(2.0, 0.42, 0.05), Vector3(0, 1.3, 2.47), cam)
	_box(m, Vector3(0.5, 0.35, 0.4), Vector3(0.6, 1.72, 1.85), "canvas", Color(0.32, 0.33, 0.25))
	_cyl(m, 0.012, 0.012, 2.4, Vector3(-0.95, 2.6, 1.9), Vector3.ZERO, "gunmetal_w", null, 4, false)
	# the gunner's turret: armoured shields with ballistic windows, the M2
	turret = _pivot(m, Vector3(0, 1.93, 0.45))
	_cyl(turret, 0.58, 0.58, 0.12, Vector3(0, 0.06, 0), Vector3.ZERO, cam, null, 18)
	_box(turret, Vector3(1.15, 0.6, 0.06), Vector3(0, 0.45, -0.55), cam, null, Vector3(0.1, 0, 0))
	_box(turret, Vector3(0.4, 0.22, 0.03), Vector3(0, 0.6, -0.6), "glass", null, Vector3(0.1, 0, 0), false)
	for s in [-1.0, 1.0]:
		_box(turret, Vector3(0.06, 0.55, 0.62), Vector3(s * 0.6, 0.42, -0.28), cam, null, Vector3(0, s * 0.45, 0))
		_box(turret, Vector3(0.03, 0.2, 0.3), Vector3(s * 0.64, 0.55, -0.3), "glass", null, Vector3(0, s * 0.45, 0), false)
	_box(turret, Vector3(0.18, 0.2, 0.75), Vector3(0, 0.45, -0.05), "gunmetal_w")
	_cyl(turret, 0.035, 0.035, 1.15, Vector3(0, 0.47, -0.95), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	_cyl(turret, 0.05, 0.035, 0.1, Vector3(0, 0.47, -1.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0, 0.47, -1.6))
	_box(turret, Vector3(0.16, 0.14, 0.28), Vector3(-0.2, 0.38, 0.0), "paint", Color(0.3, 0.33, 0.22))
	_team_mark(m, team, Vector3(1.11, 1.0, 1.9), Vector3(0.03, 0.18, 0.6))


## Tracked IFV: a tall slab-sided hull, rear ramp, small two-man turret with
## the 25 mm and a missile box.
func _ifv(team: int) -> void:
	var cam := "camo_tank"
	var m := root
	_add(m, loft("ifv_low", [-1.15, -2.9, 1.15, -2.9, 1.15, 3.1, -1.15, 3.1], [-1.15, -3.25, 1.15, -3.25, 1.15, 3.2, -1.15, 3.2], 0.38, 1.0), cam, null, Vector3.ZERO)
	_add(m, loft("ifv_up", [-1.62, -3.25, 1.62, -3.25, 1.62, 3.2, -1.62, 3.2], [-1.5, -2.2, 1.5, -2.2, 1.55, 3.15, -1.55, 3.15], 0.98, 1.95), cam, null, Vector3.ZERO)
	var tp := [-3.3, 0.6, -2.9, 0.06, 2.8, 0.06, 3.25, 0.55, 3.0, 0.95, -3.0, 0.95]
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("ifv_trk", tp, -0.3, 0.3), "track", null, Vector3(s * 1.33, 0, 0))
		for i in 6:
			_wheel(m, Vector3(s * 1.35, 0.36, -2.25 + i * 0.88), 0.31, 0.46)
		for i in 6:
			_box(m, Vector3(0.06, 0.6, 0.9), Vector3(s * 1.66, 0.72, -2.3 + i * 0.93), cam)
		_box(m, Vector3(0.24, 0.12, 0.1), Vector3(s * 1.1, 1.15, -3.2), "gunmetal_w")
		_box(m, Vector3(0.18, 0.08, 0.02), Vector3(s * 1.1, 1.15, -3.26), "glass")
		# appliqué armour tiles
		for i in 4:
			_box(m, Vector3(0.08, 0.5, 1.1), Vector3(s * 1.68, 1.45, -1.6 + i * 1.2), cam)
	_box(m, Vector3(2.2, 1.0, 0.08), Vector3(0, 1.45, 3.22), cam)
	_box(m, Vector3(0.9, 0.8, 0.05), Vector3(0, 1.4, 3.27), "gunmetal_w")
	# trim vane folded on the glacis, the ramp's hinges, tow points
	_box(m, Vector3(2.4, 0.05, 0.7), Vector3(0, 1.32, -2.75), cam, null, Vector3(-0.5, 0, 0))
	for s in [-1.0, 1.0]:
		_cyl(m, 0.06, 0.06, 0.3, Vector3(s * 0.75, 0.55, 3.25), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
		_box(m, Vector3(0.12, 0.14, 0.18), Vector3(s * 0.75, 0.55, -3.35), "gunmetal_w")
	_box(m, Vector3(2.0, 0.05, 1.2), Vector3(0, 1.96, 2.2), "gunmetal_w")
	turret = _pivot(m, Vector3(0.25, 1.95, -0.4))
	_add(turret, loft("ifv_tur", [-0.85, -1.0, 0.85, -1.0, 0.95, 0.9, -0.95, 0.9], [-0.7, -0.75, 0.7, -0.75, 0.8, 0.8, -0.8, 0.8], 0.0, 0.62), cam, null, Vector3.ZERO)
	_cyl(turret, 0.06, 0.07, 2.4, Vector3(0, 0.32, -2.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	_cyl(turret, 0.1, 0.1, 0.3, Vector3(0, 0.32, -3.25), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	mg_tip = _tip(turret, Vector3(0, 0.32, -3.42))
	_box(turret, Vector3(0.36, 0.42, 1.3), Vector3(-1.08, 0.38, 0.1), cam)
	_cyl(turret, 0.2, 0.2, 0.2, Vector3(0.45, 0.72, 0.35), Vector3.ZERO, cam, null, 10)
	_box(turret, Vector3(0.3, 0.22, 0.35), Vector3(-0.45, 0.72, -0.4), cam)
	for s in [-1.0, 1.0]:
		for i in 2:
			_cyl(turret, 0.05, 0.05, 0.22, Vector3(s * (0.9 + i * 0.05), 0.45 + i * 0.1, -0.7), Vector3(-0.9, 0, s * 0.4), "gunmetal_w", null, 6, false)
	_team_mark(m, team, Vector3(1.66, 1.5, 2.3), Vector3(0.04, 0.3, 0.7))
	_team_mark(m, team, Vector3(-1.66, 1.5, 2.3), Vector3(0.04, 0.3, 0.7))


## BTR-80: a long boat-shaped hull (it swims), the bow sloping back over a
## trim vane, sides angled in above the wheels, eight wheels with the gap for
## the side doors between the second and third axles, firing ports, hatches,
## and the small conical turret with its 14.5 mm KPVT and smoke dischargers.
func _apc(team: int) -> void:
	var cam := "camo_tank" if team == 0 else "camo_tank_rebel"
	var m := root
	var lo := [-0.85, -3.1, 0.85, -3.1, 1.15, -2.3, 1.15, 3.55, -1.15, 3.55, -1.15, -2.3]
	var mid := [-1.0, -3.8, 1.0, -3.8, 1.42, -2.95, 1.42, 3.75, -1.42, 3.75, -1.42, -2.95]
	var hi := [-0.62, -2.65, 0.62, -2.65, 1.1, -2.2, 1.1, 3.6, -1.1, 3.6, -1.1, -2.2]
	_add(m, loft("btr_lo", lo, mid, 0.5, 1.28), cam, null, Vector3.ZERO)
	_add(m, loft("btr_hi", mid, hi, 1.28, 2.05), cam, null, Vector3.ZERO)
	# trim vane on the bow, the driver's and commander's vision blocks, lights
	_box(m, Vector3(1.8, 0.05, 0.55), Vector3(0, 1.35, -3.55), cam, null, Vector3(-0.9, 0, 0))
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.5, 0.12, 0.05), Vector3(s * 0.32, 1.92, -2.58), "glass", null, Vector3(-0.6, 0, 0), false)
		_box(m, Vector3(0.18, 0.1, 0.1), Vector3(s * 0.7, 1.5, -3.3), "gunmetal_w")
		_box(m, Vector3(0.14, 0.07, 0.02), Vector3(s * 0.7, 1.5, -3.36), "glass")
		# wheels: two pairs forward, two aft
		for z in [-2.45, -1.1, 0.75, 2.1]:
			_wheel(m, Vector3(s * 1.28, 0.55, z), 0.55, 0.4)
		# the side door between the axle pairs, firing ports along the flank
		_box(m, Vector3(0.05, 0.62, 0.62), Vector3(s * 1.3, 1.62, -0.18), cam, null, Vector3(0, 0, s * 0.38))
		for z in [-1.6, 1.3, 2.5]:
			_cyl(m, 0.06, 0.08, 0.06, Vector3(s * 1.26, 1.68, z), Vector3(0, 0, s * (PI / 2 - 0.38)), "gunmetal_w", null, 8, false)
		# stowage boxes and a tow cable over the rear wheels
		_box(m, Vector3(0.32, 0.22, 0.9), Vector3(s * 1.05, 2.12, 2.4), "steel", Color(0.32, 0.31, 0.24))
		_box(m, Vector3(0.05, 0.05, 2.4), Vector3(s * 1.36, 1.3, 1.4), "gunmetal_w", null, Vector3.ZERO, false)
	# roof hatches, engine grilles, exhaust
	for z in [-1.7, 0.3]:
		for s2 in [-1.0, 1.0]:
			_cyl(m, 0.27, 0.27, 0.06, Vector3(s2 * 0.55, 2.08, z), Vector3.ZERO, cam, null, 14)
	_box(m, Vector3(1.6, 0.04, 1.2), Vector3(0, 2.07, 2.7), "gunmetal_w")
	_box(m, Vector3(1.4, 0.18, 0.12), Vector3(0, 1.5, 3.75), "gunmetal_w")
	_cyl(m, 0.012, 0.012, 2.2, Vector3(0.9, 3.1, 1.6), Vector3.ZERO, "gunmetal_w", null, 4, false)
	# the turret: a low cone with the KPVT and coax in its mantlet
	turret = _pivot(m, Vector3(0, 2.05, -1.0))
	_cyl(turret, 0.66, 0.68, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, cam, null, 20)
	_cyl(turret, 0.42, 0.62, 0.42, Vector3(0, 0.31, 0), Vector3.ZERO, cam, null, 20)
	_cyl(turret, 0.24, 0.24, 0.06, Vector3(0.12, 0.55, 0.12), Vector3.ZERO, cam, null, 12)
	_box(turret, Vector3(0.36, 0.28, 0.3), Vector3(0, 0.3, -0.58), cam)
	_cyl(turret, 0.05, 0.05, 1.8, Vector3(0, 0.3, -1.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	_cyl(turret, 0.075, 0.075, 0.5, Vector3(0, 0.3, -0.95), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	_cyl(turret, 0.07, 0.07, 0.16, Vector3(0, 0.3, -2.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	_cyl(turret, 0.02, 0.02, 0.4, Vector3(0.14, 0.25, -0.85), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0, 0.3, -2.65))
	_box(turret, Vector3(0.12, 0.14, 0.14), Vector3(-0.2, 0.55, -0.35), "gunmetal_w")
	for s in [-1.0, 1.0]:
		for i in 3:
			_cyl(turret, 0.045, 0.045, 0.2, Vector3(s * 0.55, 0.32 + i * 0.07, 0.25 - i * 0.05), Vector3(-0.7, 0, s * 0.6), "gunmetal_w", null, 6, false)
	_team_mark(m, team, Vector3(1.3, 1.7, 2.4), Vector3(0.03, 0.22, 0.7))


func _truck(team: int) -> void:
	var cab := Color(0.32, 0.35, 0.25) if team != 1 else Color(0.45, 0.38, 0.28)
	var m := root
	_box(m, Vector3(1.2, 0.25, 6.0), Vector3(0, 0.75, 0.2), "gunmetal_w")
	_add(m, loft("tr_hood", [-0.9, -3.4, 0.9, -3.4, 0.9, -2.45, -0.9, -2.45], [-0.82, -3.3, 0.82, -3.3, 0.82, -2.45, -0.82, -2.45], 0.8, 1.55), "paint", cab, Vector3.ZERO)
	_add(m, loft("tr_cab", [-1.1, -2.5, 1.1, -2.5, 1.1, -1.0, -1.1, -1.0], [-1.0, -2.2, 1.0, -2.2, 1.0, -1.05, -1.0, -1.05], 1.0, 2.45), "paint", cab, Vector3.ZERO)
	_box(m, Vector3(1.75, 0.6, 0.03), Vector3(0, 2.02, -2.37), "glass", null, Vector3(-0.2, 0, 0), false)
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.03, 0.5, 0.6), Vector3(s * 1.06, 2.0, -1.65), "glass", null, Vector3(0, 0, s * 0.05), false)
		_box(m, Vector3(0.05, 0.3, 0.2), Vector3(s * 1.2, 2.0, -2.35), "gunmetal_w")
	_box(m, Vector3(1.0, 0.45, 0.04), Vector3(0, 1.15, -3.42), "gunmetal_w")
	_box(m, Vector3(2.1, 0.2, 0.2), Vector3(0, 0.75, -3.5), "steel")
	# cargo bed with a canvas cover
	_box(m, Vector3(2.35, 0.15, 4.2), Vector3(0, 1.1, 1.15), "wood_dark")
	_box(m, Vector3(2.35, 1.2, 4.1), Vector3(0, 1.8, 1.15), "canvas", cab.lightened(0.05))
	_add(m, Res.cyl(1.17, 1.17, 4.1, 16), "canvas", cab.lightened(0.05), Vector3(0, 2.4, 1.15), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.42))
	for i in 4:
		_box(m, Vector3(2.4, 0.05, 0.08), Vector3(0, 2.42, -0.6 + i * 1.18), "canvas", cab.darkened(0.2))
	_cyl(m, 0.28, 0.28, 1.1, Vector3(-1.12, 0.95, -0.45), Vector3(PI / 2, 0, 0), "steel", null, 10)
	_box(m, Vector3(0.5, 0.4, 0.5), Vector3(1.12, 0.95, -0.45), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_wheel(m, Vector3(s * 1.0, 0.5, -2.75), 0.5, 0.36)
		_wheel(m, Vector3(s * 1.0, 0.5, 1.0), 0.5, 0.36)
		_wheel(m, Vector3(s * 1.0, 0.5, 2.15), 0.5, 0.36)
	_team_mark(m, team, Vector3(1.19, 1.9, 1.15), Vector3(0.03, 0.35, 1.2))


# --- jet ----------------------------------------------------------------------

func _jet(team: int) -> void:
	var m := root
	var paint := Color(0.44, 0.47, 0.5) if team != 1 else Color(0.5, 0.47, 0.4)
	_add(m, _capsule(0.72, 13.0), "aircraft", paint, Vector3(0, 0, 0.3), Vector3(PI / 2, 0, 0), Vector3(1.0, 0.85, 1.0))
	_add(m, Res.sphere(0.6, 14), "glass", null, Vector3(0, 0.55, -3.2), Vector3.ZERO, Vector3(0.75, 0.7, 2.0))
	# swept wings, tailplanes and fin as thin lofted plates
	_add(m, loft("jet_wing", [-0.6, -1.4, 0.6, -1.4, 6.2, 2.6, 6.2, 3.6, -6.2, 3.6, -6.2, 2.6], [-0.6, -1.3, 0.6, -1.3, 6.2, 2.65, 6.2, 3.55, -6.2, 3.55, -6.2, 2.65], -0.08, 0.08), "aircraft", paint, Vector3(0, -0.1, 0))
	_add(m, loft("jet_tail", [-0.4, 5.0, 0.4, 5.0, 2.8, 6.6, 2.8, 7.2, -2.8, 7.2, -2.8, 6.6], [-0.4, 5.05, 0.4, 5.05, 2.8, 6.62, 2.8, 7.18, -2.8, 7.18, -2.8, 6.62], -0.06, 0.06), "aircraft", paint, Vector3(0, 0.1, 0))
	_add(m, extrude_x("jet_fin", [4.6, 0.5, 6.9, 0.5, 7.4, 3.0, 6.6, 3.0], -0.07, 0.07), "aircraft", paint, Vector3.ZERO)
	_cyl(m, 0.55, 0.6, 0.8, Vector3(0, 0, 7.0), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	for s in [-1.0, 1.0]:
		_cyl(m, 0.14, 0.14, 1.6, Vector3(s * 2.6, -0.45, 1.6), Vector3(PI / 2, 0, 0), "paint", Color(0.3, 0.32, 0.26), 8)
		_cyl(m, 0.25, 0.25, 2.6, Vector3(s * 4.0, -0.5, 2.2), Vector3(PI / 2, 0, 0), "aircraft", paint.darkened(0.2), 8)
	_team_mark(m, team, Vector3(3.6, 0.1, 3.0), Vector3(0.8, 0.03, 0.5))
	_team_mark(m, team, Vector3(-3.6, 0.1, 3.0), Vector3(0.8, 0.03, 0.5))
	if not burnt:
		var glow := MeshInstance3D.new()
		glow.name = "Afterburner"
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.6)
		glow.mesh = q
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		gm.albedo_color = Color(1.0, 0.55, 0.25)
		gm.albedo_texture = Res.puff_mat(true).albedo_texture
		glow.material_override = gm
		glow.position = Vector3(0, 0, 7.5)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_child(glow)


## A-10 Warthog: straight wings, twin tail, engines high on the rear fuselage,
## the GAU-8's barrels poking out of the nose.
func _a10(team: int) -> void:
	var m := root
	var paint := Color(0.42, 0.45, 0.47)
	_add(m, _capsule(0.82, 14.5), "aircraft", paint, Vector3(0, 0, 0.2), Vector3(PI / 2, 0, 0), Vector3(1.0, 0.9, 1.0))
	_add(m, Res.sphere(0.55, 14), "glass", null, Vector3(0, 0.62, -4.4), Vector3.ZERO, Vector3(0.85, 0.75, 1.7))
	_cyl(m, 0.17, 0.17, 0.9, Vector3(0, -0.25, -7.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	# straight, thick wings with drooped tips
	_add(m, loft("a10_wing", [-0.9, -0.9, 0.9, -0.9, 8.6, -0.3, 8.6, 1.3, -8.6, 1.3, -8.6, -0.3], [-0.9, -0.8, 0.9, -0.8, 8.6, -0.25, 8.6, 1.25, -8.6, 1.25, -8.6, -0.25], -0.12, 0.12), "aircraft", paint, Vector3(0, -0.35, 0.4))
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.9, 0.06, 1.5), Vector3(s * 9.0, -0.5, 0.95), "aircraft", paint, Vector3(0, 0, s * 0.35))
		# engine pods high on the back, on short pylons
		_cyl(m, 0.62, 0.55, 3.0, Vector3(s * 1.45, 1.05, 3.4), Vector3(PI / 2, 0, 0), "aircraft", paint.darkened(0.08), 14)
		_cyl(m, 0.5, 0.5, 0.1, Vector3(s * 1.45, 1.05, 1.88), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
		_box(m, Vector3(0.18, 0.55, 1.4), Vector3(s * 0.9, 0.7, 3.4), "aircraft", paint)
		# underwing stores
		for k in 3:
			_cyl(m, 0.13, 0.13, 1.9, Vector3(s * (2.6 + k * 1.8), -0.7, 0.2), Vector3(PI / 2, 0, 0), "paint", Color(0.36, 0.38, 0.33), 8)
	# tailplane with twin fins
	_add(m, loft("a10_tail", [-2.9, 6.2, 2.9, 6.2, 2.9, 7.6, -2.9, 7.6], [-2.9, 6.25, 2.9, 6.25, 2.9, 7.55, -2.9, 7.55], -0.07, 0.07), "aircraft", paint, Vector3(0, 0.45, 0))
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("a10_fin", [6.0, -0.6, 7.7, -0.6, 7.6, 2.1, 6.6, 2.1], -0.06, 0.06), "aircraft", paint, Vector3(s * 2.9, 0.45, 0))
	_team_mark(m, team, Vector3(4.5, -0.22, 0.6), Vector3(0.8, 0.03, 0.8))
	_team_mark(m, team, Vector3(-4.5, -0.22, 0.6), Vector3(0.8, 0.03, 0.8))


## AC-130 gunship: high wing, four turboprops, upswept tail, guns along the
## left side (25 mm forward, 40 mm and the 105 mm howitzer aft).
func _ac130(team: int) -> void:
	var m := root
	var paint := Color(0.27, 0.29, 0.31)
	_add(m, _capsule(2.0, 29.0), "aircraft", paint, Vector3(0, 0, 0), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.05, 1.0))
	_add(m, Res.sphere(1.5, 14), "glass", null, Vector3(0, 1.0, -12.4), Vector3.ZERO, Vector3(1.0, 0.45, 0.9))
	# upswept rear fuselage and the tail
	_add(m, loft("ac_tailcone", [-1.9, 9.0, 1.9, 9.0, 1.0, 15.5, -1.0, 15.5], [-1.9, 9.0, 1.9, 9.0, 1.0, 15.5, -1.0, 15.5], 0.2, 2.2), "aircraft", paint, Vector3(0, 0, 0))
	_add(m, loft("ac_hstab", [-8.2, 13.6, 8.2, 13.6, 8.2, 16.2, -8.2, 16.2], [-8.2, 13.7, 8.2, 13.7, 8.2, 16.1, -8.2, 16.1], -0.12, 0.12), "aircraft", paint, Vector3(0, 2.4, 0))
	_add(m, extrude_x("ac_fin", [11.5, 1.6, 16.4, 1.6, 16.6, 8.6, 14.6, 8.6], -0.14, 0.14), "aircraft", paint, Vector3.ZERO)
	# high wing with four engines
	_add(m, loft("ac_wing", [-20.0, -3.8, 20.0, -3.8, 20.0, -1.6, -20.0, -1.6], [-20.0, -3.7, 20.0, -3.7, 20.0, -1.7, -20.0, -1.7], -0.18, 0.18), "aircraft", paint, Vector3(0, 2.15, 0))
	for x in [-10.2, -5.3, 5.3, 10.2]:
		_cyl(m, 0.62, 0.55, 4.2, Vector3(x, 1.55, -3.4), Vector3(PI / 2, 0, 0), "aircraft", paint.darkened(0.08), 12)
		var prop := _pivot(m, Vector3(x, 1.55, -5.65))
		_cyl(prop, 0.25, 0.1, 0.5, Vector3.ZERO, Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		if not burnt:
			var disc := MeshInstance3D.new()
			disc.mesh = Res.cyl(2.05, 2.05, 0.04, 24)
			disc.rotation = Vector3(PI / 2, 0, 0)
			disc.material_override = _blur_mat()
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prop.add_child(disc)
		wheels.append(prop)
	# the guns, poking out of the left side
	_cyl(m, 0.08, 0.08, 1.6, Vector3(-2.3, -0.4, -7.0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	_cyl(m, 0.12, 0.12, 1.8, Vector3(-2.35, -0.5, 3.0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	_cyl(m, 0.22, 0.24, 2.6, Vector3(-2.6, -0.6, 6.5), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	_team_mark(m, team, Vector3(12.0, 2.35, -2.6), Vector3(1.5, 0.03, 1.2))
	_team_mark(m, team, Vector3(-12.0, 2.35, -2.6), Vector3(1.5, 0.03, 1.2))


# --- helicopters --------------------------------------------------------------

func _heli(team: int, attack: bool) -> void:
	var m := root
	var cam := "camo_tank" if team != 1 else "camo_tank_rebel"
	var dark := Color(0.24, 0.27, 0.21)
	if attack:
		# slim fuselage, tandem cockpit, stub wings with rocket pods, chin gun
		_add(m, _capsule(0.62, 5.2), cam, null, Vector3(0, 1.45, -0.1), Vector3(PI / 2, 0, 0), Vector3(0.85, 1.25, 1.0))
		_add(m, Res.sphere(0.6, 14), "glass", null, Vector3(0, 1.95, -1.85), Vector3.ZERO, Vector3(0.7, 0.75, 1.5))
		_add(m, Res.sphere(0.5, 12), "glass", null, Vector3(0, 2.05, -0.75), Vector3.ZERO, Vector3(0.75, 0.8, 1.3))
		_add(m, _capsule(0.4, 2.4), cam, null, Vector3(0, 2.15, 0.6), Vector3(PI / 2, 0, 0), Vector3(1.7, 1.0, 1.0))
		_cyl(m, 0.42, 0.18, 4.6, Vector3(0, 1.75, 4.2), Vector3(PI / 2, 0, 0), cam, null, 12)
		for s in [-1.0, 1.0]:
			_box(m, Vector3(1.4, 0.08, 0.7), Vector3(s * 1.0, 1.45, 0.3), cam, null, Vector3(0, 0, s * -0.08))
			for j in 2:
				var px: float = s * (0.8 + j * 0.6)
				_cyl(m, 0.17, 0.17, 1.1, Vector3(px, 1.2, 0.2), Vector3(PI / 2, 0, 0), "paint", Color(0.28, 0.3, 0.23), 10)
				_cyl(m, 0.12, 0.12, 0.05, Vector3(px, 1.2, -0.36), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
			_cyl(m, 0.035, 0.035, 1.7, Vector3(s * 0.35, 0.35, -0.5), Vector3(0, 0, s * 0.35), "gunmetal_w", null, 6)
			_cyl(m, 0.14, 0.14, 0.1, Vector3(s * 0.65, 0.18, -0.5), Vector3(0, 0, PI / 2), "rubber", null, 10)
		_box(m, Vector3(0.12, 1.3, 0.8), Vector3(0, 2.45, 6.25), cam, null, Vector3(-0.3, 0, 0))
		_box(m, Vector3(1.6, 0.06, 0.45), Vector3(0, 1.8, 6.0), cam)
		turret = _pivot(m, Vector3(0, 0.8, -2.25))
		_cyl(turret, 0.13, 0.15, 0.4, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, 10)
		_cyl(turret, 0.035, 0.035, 1.3, Vector3(0, -0.1, -0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
		mg_tip = _tip(turret, Vector3(0, -0.1, -1.27))
		_team_mark(m, team, Vector3(0, 1.98, 3.6), Vector3(0.3, 0.04, 1.2))
		_cyl(m, 0.1, 0.1, 0.45, Vector3(0, 2.6, 0.0), Vector3.ZERO, "gunmetal_w", null, 10)
		rotor = _pivot(m, Vector3(0, 2.9, 0.0))
		tail_rotor = _pivot(m, Vector3(0.2, 2.55, 6.4))
	else:
		# utility transport: wide cabin, big sliding doors, skids
		_add(m, _capsule(0.98, 5.6), cam, null, Vector3(0, 1.45, 0.1), Vector3(PI / 2, 0, 0), Vector3(0.92, 1.0, 1.0))
		_add(m, Res.sphere(0.95, 16), "glass", null, Vector3(0, 1.62, -1.95), Vector3.ZERO, Vector3(0.88, 0.72, 1.05))
		_add(m, Res.sphere(0.9, 14), cam, null, Vector3(0, 1.15, -2.15), Vector3.ZERO, Vector3(0.82, 0.62, 0.95))
		_add(m, _capsule(0.45, 2.6), cam, null, Vector3(0, 2.38, 0.35), Vector3(PI / 2, 0, 0), Vector3(1.5, 0.9, 1.0))
		for s in [-1.0, 1.0]:
			_box(m, Vector3(0.04, 0.95, 1.3), Vector3(s * 0.9, 1.45, 0.15), "paint", dark)
			_box(m, Vector3(0.04, 0.4, 0.45), Vector3(s * 0.91, 1.75, 0.0), "glass")
			_box(m, Vector3(0.04, 0.35, 0.4), Vector3(s * 0.88, 1.7, 1.35), "glass")
			_cyl(m, 0.05, 0.05, 3.6, Vector3(s * 0.95, 0.08, 0.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
			for z in [-0.8, 1.0]:
				_cyl(m, 0.04, 0.04, 0.6, Vector3(s * 0.85, 0.35, z), Vector3(0, 0, s * 0.35), "gunmetal_w", null, 6, false)
		_cyl(m, 0.48, 0.24, 5.2, Vector3(0, 1.85, 4.9), Vector3(PI / 2, 0, 0), cam, null, 12)
		_box(m, Vector3(0.12, 1.6, 0.9), Vector3(0, 2.6, 7.2), cam, null, Vector3(-0.35, 0, 0))
		_box(m, Vector3(1.9, 0.06, 0.5), Vector3(0, 1.95, 6.7), cam)
		_cyl(m, 0.1, 0.1, 0.45, Vector3(0, 2.75, 0.1), Vector3.ZERO, "gunmetal_w", null, 10)
		rotor = _pivot(m, Vector3(0, 2.98, 0.1))
		tail_rotor = _pivot(m, Vector3(0.18, 2.8, 7.35))
		_team_mark(m, team, Vector3(0, 2.15, 4.0), Vector3(0.5, 0.04, 1.6))
	# main rotor: hub, blades (visible slow) and a blur disc (visible fast)
	_cyl(rotor, 0.22, 0.22, 0.18, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, 10)
	blades = _pivot(rotor, Vector3.ZERO)
	var bl := 5.4 if not attack else 4.6
	for i in 4:
		var bp := _pivot(blades, Vector3.ZERO)
		bp.rotation.y = i * PI / 2
		_box(bp, Vector3(0.32, 0.04, bl), Vector3(0, 0.05, bl * 0.5 + 0.15), "gunmetal_w", null, Vector3(0, 0, 0.06))
	if not burnt:
		blur = MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(bl + 0.2, bl + 0.2) * 2.0
		blur.mesh = disc
		blur.material_override = _blur_mat()
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blur.position = Vector3(0, 0.06, 0)
		blur.visible = false
		rotor.add_child(blur)
	for i in 2:
		_box(tail_rotor, Vector3(0.03, 1.5, 0.14), Vector3.ZERO, "gunmetal_w", null, Vector3(i * PI / 2, 0, 0))


static var _blur: ShaderMaterial


## The disc a rotor's blades sweep at flight speed, on a plane mesh the size
## of the rotor, turning with the hub: one material for every rotor, its
## blade count and colour per rotor (see VehicleRotors.BLUR_SHADER, which the
## propellers' discs share).
static func _blur_mat() -> ShaderMaterial:
	if _blur == null:
		var sh := Shader.new()
		sh.code = Mats.code(VehicleRotors.BLUR_SHADER)
		_blur = ShaderMaterial.new()
		_blur.shader = sh
	return _blur


## Cosmetic motion in world space, shared by every whip on this vehicle.
## One spring per vehicle and one transform per whip; no mesh or physics updates.
func update_antennas(travel: Vector3, dt: float, active := true) -> void:
	if antennas.is_empty() or dt <= 0.0:
		return
	if not active or dt > 0.25 or not travel.is_finite() or travel.length_squared() > 1600.0:
		if _antenna_active:
			for whip in antennas:
				whip.rotation = Vector3.ZERO
		_antenna_response.offset = Vector3.ZERO
		_antenna_response.velocity = Vector3.ZERO
		_antenna_velocity = Vector3.ZERO
		_antenna_active = false
		return
	var acceleration := ((travel - _antenna_velocity) / dt).limit_length(15.0) if _antenna_active else Vector3.ZERO
	_antenna_velocity = travel
	_antenna_active = true
	# Air drag trails travel; inertia also reacts to braking and lateral turns.
	var target := (-travel * 0.009 - acceleration * 0.012).limit_length(0.28)
	target.y = 0.0
	_antenna_response.offset -= target
	_antenna_response.step(dt, 7.0)
	_antenna_response.offset += target
	for whip in antennas:
		# Turret-mounted whips must keep the same world-space response when traversing.
		var parent := whip.get_parent() as Node3D
		var lean := parent.global_basis.orthonormalized().inverse() * _antenna_response.offset
		var angles := Vector3(lean.z, 0, -lean.x)
		if not whip.rotation.is_equal_approx(angles):
			whip.rotation = angles
