class_name TerrainMap
extends RefCounted
## What the ground itself does for you, cell by cell (1 m, over the whole map):
## roads (fast, exposed), mud (slow, exposed), woods (concealment, light
## cover), craters (dug-in light cover, slow for vehicles) and rubble. On top
## of that, a cover map: every cell next to something solid knows how good the
## cover is (heavy / light) and which way it protects. Built on every peer from
## the same data (map seed, roads, structures, explosions) and patched as
## things are built, destroyed or blown into craters.

const N := MapDims.N
const H := MapDims.HALF

enum {GROUND, ROAD, WOODS, MUD, CRATER, RUBBLE, TRENCH}
const KIND_NAMES := ["Open ground", "Road", "Woods", "Mud", "Crater", "Rubble", "Trench"]

# cover levels as stored (+1 so they fit a byte): 0 exposed, 1 none, 2 light, 3 heavy
const EXPOSED := -1
const NONE := 0
const LIGHT := 1
const HEAVY := 2
const OMNI := 8  # direction index meaning "protects from every side"

const HEAVY_KINDS := ["tall_wall", "house_wall", "concrete_wall", "sandbags", "mg_nest", "hmg_nest", "mortar_pit",
	"at_post", "bunker", "wreck", "fob", "barracks", "factory", "research", "depot", "medic_tent"]

var world
var base := PackedByteArray()  # GROUND / ROAD / MUD / WOODS
var crater := PackedByteArray()  # >0 inside a crater
var rubble := PackedByteArray()
var woods := PackedByteArray()  # number of trees within reach
var cov := PackedByteArray()  # cover level + 1
var cdir := PackedByteArray()  # direction the cover faces (0..7) or OMNI
var solid := PackedByteArray()  # inside a wall or building (nowhere to stand)
var trench := PackedByteArray()  # inside a dug trench
var _inside_hit := false
var biome_img: Image
var _dirs: Array[Vector2] = []
var version := 0  # bumps whenever cover / kinds change (UI caches)
## Ground height (m) at 4 samples per metre: shell holes and their thrown-up
## rims. The same craters are stamped on the server and every client, so the
## men lie in the same holes everywhere. Clients draw it (the ground mesh is
## displaced by it) and the physics ground follows it.
const DRES := 2  # 50 cm, like the ground mesh (a 512 m map at 25 cm would be 16 MB per upload)
const DN := N * DRES
var dh := PackedFloat32Array()
var deform_dirty := Rect2i()  # samples changed since the view last looked
var deform_img: Image  # (view only) the same heights as a texture


func _init(w) -> void:
	world = w
	for a in [base, crater, rubble, woods, cdir, solid, trench]:
		a.resize(N * N)
	cov.resize(N * N)
	cov.fill(1)
	cdir.fill(255)
	for i in 8:
		var ang := TAU * i / 8.0
		_dirs.append(Vector2(cos(ang), sin(ang)))
	dh.resize(DN * DN)
	if w.has_view:
		deform_img = Image.create(DN, DN, false, Image.FORMAT_RF)
	_make_biome()


## Same noise the ground shader paints with, so mud is where the mud looks like it is.
func _make_biome() -> void:
	var n := FastNoiseLite.new()
	n.seed = int(world.settings.get("seed", 1)) % 100000
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	biome_img = n.get_seamless_image(MapDims.BIOME, MapDims.BIOME, false, false, 0.1, true)
	var bo := MapDims.BIOME / 2 - N / 2
	for z in N:
		for x in N:
			var b := biome_img.get_pixel(x + bo, z + bo).r
			if b > 0.725:
				base[z * N + x] = MUD


func idx_of(p: Vector3) -> int:
	return clampi(floori(p.z + H), 0, N - 1) * N + clampi(floori(p.x + H), 0, N - 1)


func center(idx: int) -> Vector3:
	return Vector3(idx % N - H + 0.5, 0.0, idx / N - H + 0.5)


# --- queries -------------------------------------------------------------------------

func kind_at(p: Vector3) -> int:
	var i := idx_of(p)
	if trench[i] > 0:
		return TRENCH
	if crater[i] > 0:
		return CRATER
	if rubble[i] > 0:
		return RUBBLE
	if woods[i] > 0 and base[i] != ROAD:
		return WOODS
	return base[i]


## Cover level at a spot, ignoring direction.
func cover_at(p: Vector3) -> int:
	return cov[idx_of(p)] - 1


## Cover level at `p` against a threat at `from` (directional cover only counts
## when the threat is on the far side of it).
func cover_vs(p: Vector3, from: Vector3) -> int:
	var i := idx_of(p)
	var lvl: int = cov[i] - 1
	if lvl <= NONE:
		return lvl
	var d: int = cdir[i]
	if d == OMNI or d == 255:
		return lvl
	var to := Vector2(from.x - p.x, from.z - p.z)
	if to.length_squared() < 0.01:
		return lvl
	return lvl if _dirs[d].dot(to.normalized()) > 0.25 else _base_cover(i)


func _base_cover(i: int) -> int:
	if crater[i] > 0 or rubble[i] > 0 or (woods[i] > 0 and base[i] != ROAD):
		return LIGHT
	if base[i] == ROAD or base[i] == MUD:
		return EXPOSED
	return NONE


func speed_mul(p: Vector3, vehicle: bool, tracked := true) -> float:
	match kind_at(p):
		TRENCH:
			# tracks claw across a trench; wheels drop in and stick
			return (0.42 if tracked else 0.12) if vehicle else 0.95
		ROAD:
			return 1.35 if vehicle else 1.12
		MUD:
			return 0.6 if vehicle else 0.82
		WOODS:
			return 0.65 if vehicle else 0.9
		CRATER:
			return 0.65 if vehicle else 0.85
		RUBBLE:
			return 0.8 if vehicle else 0.85
	return 1.0


## Chance-to-hit multiplier from the ground the target stands on (physical cover
## like walls is handled by line of fire; this covers what bullets can't see:
## dips, undergrowth, rubble heaps, and being caught out on a road or in mud).
func hit_mul(target: Vector3, shooter: Vector3) -> float:
	var k := kind_at(target)
	match k:
		CRATER:
			return 0.6
		WOODS:
			return 0.75
		RUBBLE:
			return 0.85
		ROAD:
			return 1.12 if cover_vs(target, shooter) <= NONE else 1.0
		MUD:
			return 1.15 if cover_vs(target, shooter) <= NONE else 1.0
	return 1.0


func blast_mul(p: Vector3) -> float:
	return 0.6 if crater[idx_of(p)] > 0 else 1.0


## Woods hide you: spotting range against someone in them is shorter.
func in_trench(p: Vector3) -> bool:
	return trench[idx_of(p)] > 0


func concealment(p: Vector3) -> float:
	if in_trench(p):
		return 0.7
	var k := kind_at(p)
	return 0.6 if k == WOODS else (0.85 if k == CRATER else 1.0)


func nav_weight(idx: int, vehicle: bool) -> float:
	if trench[idx] > 0:
		return 7.0 if vehicle else 0.7  # infantry move along the trenches: covered all the way
	if crater[idx] > 0:
		return 2.8 if vehicle else 1.2
	if rubble[idx] > 0:
		return 2.2 if vehicle else 1.2
	match base[idx]:
		ROAD:
			return 0.6 if vehicle else 0.85
		MUD:
			return 2.8 if vehicle else 1.25
	if woods[idx] > 0:
		return 2.6 if vehicle else 1.05
	# wheels and tracks keep to the roads where they can: cross-country is slow and rough
	return 1.45 if vehicle else 1.0


# --- building the map ------------------------------------------------------------------

func paint_roads(polys: Array, half_w := 2.2) -> void:
	for poly in polys:
		var pts: PackedVector3Array = poly
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var x0 := floori(minf(a.x, b.x) - half_w - 1.0 + H)
			var x1 := floori(maxf(a.x, b.x) + half_w + 1.0 + H)
			var z0 := floori(minf(a.z, b.z) - half_w - 1.0 + H)
			var z1 := floori(maxf(a.z, b.z) + half_w + 1.0 + H)
			for z in range(maxi(0, z0), mini(N - 1, z1) + 1):
				for x in range(maxi(0, x0), mini(N - 1, x1) + 1):
					var c := Vector3(x - H + 0.5, 0, z - H + 0.5)
					if Defs.dist_point_segment(c, Vector3(a.x, 0, a.z), Vector3(b.x, 0, b.z)) <= half_w:
						base[z * N + x] = ROAD
						_refresh_cell(z * N + x)
	version += 1


## Sets the ground kind over a rectangle (sidewalks and squares are road).
func paint_box(c: Vector3, half: Vector2, yaw: float, kind: int) -> void:
	var r := half.length() + 1.0
	for z in range(maxi(0, floori(c.z - r + H)), mini(N - 1, floori(c.z + r + H)) + 1):
		for x in range(maxi(0, floori(c.x - r + H)), mini(N - 1, floori(c.x + r + H)) + 1):
			if Defs.point_in_obb(Vector2(x - H + 0.5, z - H + 0.5), Vector2(c.x, c.z), half, yaw):
				base[z * N + x] = kind
				_refresh_cell(z * N + x)
	version += 1


var _dirty := {}
var _queue: Array = []


## A structure appeared, finished building, or was destroyed: queue the cells
## around it for a cover recompute (a few thousand cells per frame).
func structure_changed(st, added := true) -> void:
	if st.skind == "tree":
		_tree_woods(st.position, 1 if added else -1)
		return
	if st.skind == "trench" and world.atmo and world.atmo.trench_net:
		world.atmo.trench_net.mark_dirty()
	var r: float = st.radius + 1.6
	var x0 := maxi(0, floori(st.position.x - r + H))
	var x1 := mini(N - 1, floori(st.position.x + r + H))
	var z0 := maxi(0, floori(st.position.z - r + H))
	var z1 := mini(N - 1, floori(st.position.z + r + H))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * N + x
			if not _dirty.has(i):
				_dirty[i] = true
				_queue.append(i)


func _tree_woods(p: Vector3, delta: int) -> void:
	var c := idx_of(p)
	var cx := c % N
	var cz := c / N
	for z in range(maxi(0, cz - 4), mini(N, cz + 5)):
		for x in range(maxi(0, cx - 4), mini(N, cx + 5)):
			var i := z * N + x
			if Defs.flat(center(i) - p).length() < 3.8:
				woods[i] = clampi(int(woods[i]) + delta, 0, 255)
				_refresh_cell(i)
	version += 1


## Processes queued cells; call every frame / tick.
func tick(budget := 2500) -> void:
	if _queue.is_empty():
		return
	var end := mini(_qhead + budget, _queue.size())
	for k in range(_qhead, end):
		var i: int = _queue[k]
		_dirty.erase(i)
		_recompute_cell(i)
	_qhead = end
	if _qhead >= _queue.size():
		_queue.clear()
		_qhead = 0
	version += 1


var _qhead := 0  # next queued cell (the queue is consumed in place, not copied)


func _recompute_cell(i: int) -> void:
	var c := center(i)
	var best := NONE
	var bdir := 255
	var rub := 0
	var tr := 0
	_inside_hit = false
	for st in world.structures_near(c, 1.6):
		if st.gone:
			continue
		if st.skind == "trench" and st.built and TrenchNet.inside(st, c):
			tr = 1
		if st.skind == "rubble" and Defs.point_in_obb(Vector2(c.x, c.z), Vector2(st.position.x, st.position.z), st.foot + Vector2(0.4, 0.4), st.yaw):
			rub = 1
		var res: Array = _contribution(st, c)
		if res.is_empty():
			continue
		if int(res[0]) > best:
			best = int(res[0])
			bdir = int(res[1])
	rubble[i] = rub
	trench[i] = tr
	solid[i] = 1 if _inside_hit else 0
	var bc := _base_cover(i)
	if bc > best or (bc == best and best == LIGHT):
		best = bc
		bdir = OMNI if bc == LIGHT else 255
	cov[i] = best + 1
	cdir[i] = bdir
	_nav_refresh(i)


func _refresh_cell(i: int) -> void:
	var lvl: int = cov[i] - 1
	if lvl <= LIGHT and cdir[i] in [255, OMNI]:
		var b := _base_cover(i)
		cov[i] = b + 1
		cdir[i] = OMNI if b == LIGHT else 255
	_nav_refresh(i)


func _nav_refresh(i: int) -> void:
	if world.nav:
		world.nav.terrain_changed(i)


## [level, dir] this structure gives the cell at `c`, or [] if none.
func _contribution(st, c: Vector3) -> Array:
	if not st.built or st.skind in ["floor", "wire", "mines", "tank_trap", "tunnel", "helipad", "tree"]:
		return []
	var b := Basis(Vector3.UP, st.yaw)
	var best := []
	for part in st.parts:
		if not part.cover:
			continue
		var top: float = part.p.y + part.s.y * 0.5
		if top < 0.55:
			continue
		var wc: Vector3 = st.position + b * part.p
		var yaw: float = st.yaw + part.r
		# cell position in the part's local frame
		var d := c - wc
		var lx := d.x * cos(yaw) - d.z * sin(yaw)
		var lz := d.x * sin(yaw) + d.z * cos(yaw)
		var hx: float = part.s.x * 0.5
		var hz: float = part.s.z * 0.5
		var qx := clampf(lx, -hx, hx)
		var qz := clampf(lz, -hz, hz)
		var gap := Vector2(lx - qx, lz - qz).length()
		var inside := gap < 0.001
		if st.skind == "trench":
			# dug in: heavy cover from every side down in the trench
			if TrenchNet.inside(st, c):
				return [HEAVY, OMNI]
			continue
		if st.skind == "bunker":
			# under a roof: heavy cover from every side inside the footprint
			if Defs.point_in_obb(Vector2(c.x, c.z), Vector2(st.position.x, st.position.z), st.foot, st.yaw):
				return [HEAVY, OMNI]
		if inside and st.skind != "rubble":
			_inside_hit = true
		if inside or gap > 1.35:
			continue
		var lvl := HEAVY if (top >= 1.35 or st.skind in HEAVY_KINDS) else LIGHT
		if st.skind == "rubble":
			lvl = LIGHT
		# direction from the cell towards the cover (world space)
		var lv := Vector2(qx - lx, qz - lz)
		var wx := lv.x * cos(yaw) + lv.y * sin(yaw)
		var wz := -lv.x * sin(yaw) + lv.y * cos(yaw)
		var ang := atan2(wz, wx)
		var di := posmod(int(round(ang / (TAU / 8.0))), 8)
		if best.is_empty() or lvl > int(best[0]):
			best = [lvl, di]
	return best


# --- craters (destructible ground) ---------------------------------------------------------

## Explosions dig craters: light cover for infantry, rough going for vehicles.
func add_crater(p: Vector3, size: float) -> void:
	if p.y > 1.6:
		return
	if size >= 0.55:
		_stamp_crater(p, size)
	if size < 0.9:
		return
	var r := 0.7 + 0.75 * size
	var c := idx_of(p)
	var cx := c % N
	var cz := c / N
	var ri := int(ceil(r))
	for z in range(maxi(0, cz - ri), mini(N, cz + ri + 1)):
		for x in range(maxi(0, cx - ri), mini(N, cx + ri + 1)):
			var i := z * N + x
			if Defs.flat(center(i) - p).length() <= r:
				crater[i] = 1
				_refresh_cell(i)
	version += 1


## Ground height at p (bilinear between samples): 0 is the undisturbed field.
func deform_at(p: Vector3) -> float:
	var fx := (p.x + H) * DRES - 0.5
	var fz := (p.z + H) * DRES - 0.5
	var x0 := clampi(floori(fx), 0, DN - 2)
	var z0 := clampi(floori(fz), 0, DN - 2)
	var tx := clampf(fx - x0, 0.0, 1.0)
	var tz := clampf(fz - z0, 0.0, 1.0)
	var i := z0 * DN + x0
	var a := lerpf(dh[i], dh[i + 1], tx)
	var b := lerpf(dh[i + DN], dh[i + DN + 1], tx)
	return lerpf(a, b, tz)


## A shell hole: a bowl blown out of the ground (deeper for bigger rounds),
## its rim thrown up around it, irregular. A second hit in the same place
## digs it deeper. Deterministic from the position, so every machine digs
## the same hole.
func _stamp_crater(p: Vector3, size: float) -> void:
	var rad := 0.6 + 0.8 * size
	var depth := minf(0.14 + 0.3 * size, 1.15)
	var rim_h := 0.06 + 0.06 * size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(round(p.x * 8.0)), int(round(p.z * 8.0))))
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var k1 := float(rng.randi_range(3, 5))
	var amp := rng.randf_range(0.06, 0.13)
	var ext := rad * 1.9
	var cx := (p.x + H) * DRES
	var cz := (p.z + H) * DRES
	var x0 := maxi(0, floori(cx - ext * DRES))
	var x1 := mini(DN - 1, ceili(cx + ext * DRES))
	var z0 := maxi(0, floori(cz - ext * DRES))
	var z1 := mini(DN - 1, ceili(cz + ext * DRES))
	if x1 < x0 or z1 < z0:
		return  # off the edge of the map
	for z in range(z0, z1 + 1):
		var wz := (z + 0.5) / DRES - H
		for x in range(x0, x1 + 1):
			var wx := (x + 0.5) / DRES - H
			var dx := wx - p.x
			var dz := wz - p.z
			var r := sqrt(dx * dx + dz * dz)
			if r > ext:
				continue
			var ang := atan2(dz, dx)
			var rr := r / (rad * (1.0 + amp * sin(ang * k1 + ph1) + amp * 0.5 * sin(ang * (k1 + 2.0) + ph2)))
			var i := z * DN + x
			var cur := dh[i]
			var nh := cur
			if rr < 1.0:
				var bowl := -depth * pow(1.0 - rr * rr, 1.25)
				# fresh hole: at least this deep; an old one gets deeper still
				nh = minf(cur + bowl * 0.35, bowl + cur * 0.25)
			nh += rim_h * exp(-pow((rr - 1.02) / 0.3, 2.0)) * (1.0 + 0.35 * sin(ang * 7.0 + ph2))
			dh[i] = clampf(nh, -1.4, 0.55)
			if deform_img:
				deform_img.set_pixel(x, z, Color(dh[i], 0, 0))
	var rect := Rect2i(x0, z0, x1 - x0 + 1, z1 - z0 + 1)
	deform_dirty = rect if deform_dirty.size == Vector2i.ZERO else deform_dirty.merge(rect)


# --- cover snapping (Company of Heroes style) ---------------------------------------------

## The best spot within `r` of `p` to fight from against a threat at `from`:
## heavy cover beats light beats open ground beats being caught in the open,
## then the closer the better. `taken` keeps squad mates from stacking up.
func best_cover_near(p: Vector3, r: float, from: Vector3, taken: Array) -> Vector3:
	return best_spot_near(p, r, from, taken)[0]


## The same as [pos, cover level, fighting position or {}]: a fighting
## position on a wall, the sandbags or a car (see Cover) beats the bare cells
## beside it, since that's exactly where a man would kneel or stand to fire.
func best_spot_near(p: Vector3, r: float, from: Vector3, taken: Array) -> Array:
	var best := p
	var bs := -1e9
	var c := idx_of(p)
	var cx := c % N
	var cz := c / N
	var ri := int(ceil(r))
	for z in range(maxi(0, cz - ri), mini(N, cz + ri + 1)):
		for x in range(maxi(0, cx - ri), mini(N, cx + ri + 1)):
			var i := z * N + x
			if solid[i] > 0:
				continue
			var q := center(i)
			var d := Defs.flat(q - p).length()
			if d > r:
				continue
			var sc := cover_vs(q, from) * 3.0 - d * 0.6 + (2.5 if trench[i] > 0 else 0.0)
			for t in taken:
				if Defs.flat((t as Vector3) - q).length() < 1.4:
					sc -= 5.0
			if sc > bs:
				bs = sc
				best = q
	var an := Cover.best_near(world, p, r + 0.8, from, taken)
	if not an.is_empty() and float(an[1]) + 0.5 >= bs:
		return [an[0], Cover.level_of(int(an[2].mat)), an[2]]
	return [best, cover_vs(best, from), {}]


## The closest trench cell to p within r that nobody has taken (INF if none).
func nearest_trench(p: Vector3, r: float, taken: Array) -> Vector3:
	var best := Vector3.INF
	var bs := 1e9
	var c := idx_of(p)
	var cx := c % N
	var cz := c / N
	var ri := int(ceil(r))
	for z in range(maxi(0, cz - ri), mini(N, cz + ri + 1)):
		for x in range(maxi(0, cx - ri), mini(N, cx + ri + 1)):
			var i := z * N + x
			if trench[i] == 0 or solid[i] > 0:
				continue
			var q := center(i)
			var d := Defs.flat(q - p).length()
			if d > r:
				continue
			for t in taken:
				if Defs.flat((t as Vector3) - q).length() < 1.4:
					d += 6.0
			if d < bs:
				bs = d
				best = q
	return best if bs < r else Vector3.INF


## Formation slots for n men around `c` facing `face`, each snapped to the
## best cover in reach. Returns [[pos, cover level], ...]. A defensive line
## (wide) spreads further apart in a shallow arc and looks further for cover.
func slots(c: Vector3, face: Vector3, n: int, wide := false) -> Array:
	if face.length() < 0.1:
		face = Vector3.FORWARD
	var side := face.cross(Vector3.UP).normalized()
	var threat := c + face * 40.0
	var taken := []
	var out := []
	var spacing := 4.0 if wide else 3.2
	for i in n:
		var col := float(i) - (n - 1) * 0.5
		var depth := -absf(col) * 0.7 if wide else (-1.2 if i % 2 == 0 else 1.0)
		var p := c + side * col * spacing + face * depth
		var sp := best_spot_near(p, 3.4 if wide else 2.6, threat, taken)
		var q: Vector3 = sp[0]
		if wide and trench[idx_of(q)] == 0:
			# a defensive line mans the trench if there's one in reach
			var tq := nearest_trench(p, 7.0, taken)
			if tq != Vector3.INF:
				var ts := best_spot_near(tq, 1.6, threat, taken)
				sp = ts if trench[idx_of(ts[0])] > 0 else [tq, cover_vs(tq, threat), {}]
				q = sp[0]
		taken.append(q)
		out.append(sp)
	return out


func describe(p: Vector3, from := Vector3.INF) -> String:
	var k := kind_at(p)
	var lvl := cover_at(p) if from == Vector3.INF else cover_vs(p, from)
	var cs: String = ["Exposed", "No cover", "Light cover", "Heavy cover"][lvl + 1]
	return "%s  -  %s" % [cs, KIND_NAMES[k]]
