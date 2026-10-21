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

enum {GROUND, ROAD, WOODS, MUD, CRATER, RUBBLE, TRENCH, WATER, SHALLOW}
const KIND_NAMES := ["Open ground", "Road", "Woods", "Mud", "Crater", "Rubble", "Trench", "Deep water", "Shallows"]

# cover levels as stored (+1 so they fit a byte): 0 exposed, 1 none, 2 light, 3 heavy
const EXPOSED := -1
const NONE := 0
const LIGHT := 1
const HEAVY := 2
const OMNI := 8  # direction index meaning "protects from every side"

const HEAVY_KINDS := ["tall_wall", "house_wall", "concrete_wall", "sandbags", "hesco", "barricade", "mg_nest", "hmg_nest", "mortar_pit",
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
var netted := PackedByteArray()  # under a camouflage net
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
	for a in [base, crater, rubble, woods, cdir, solid, trench, netted]:
		a.resize(N * N)
	cov.resize(N * N)
	cov.fill(1)
	_dirty.resize(N * N)
	_dirty.fill(0)
	cdir.fill(255)
	for i in 8:
		var ang := TAU * i / 8.0
		_dirs.append(Vector2(cos(ang), sin(ang)))
	dh.resize(DN * DN)
	if w.has_view:
		deform_img = Image.create(DN, DN, false, Image.FORMAT_RH)  # half floats: half the upload of a 1 km map at 50 cm
	_make_biome()


## The last seed's biome and the mud it lays (a test loads battle after battle,
## mostly on one seed): the noise takes a good part of a second to make, and
## it comes out the same every time for the same seed. Nothing writes to the
## image; the mud is copied in and out.
static var _biome_seed := -1
static var _biome_last: Image = null
static var _mud_last := PackedByteArray()


## Same noise the ground shader paints with, so mud is where the mud looks like it is.
func _make_biome() -> void:
	var s := int(world.settings.get("seed", 1)) % 100000
	if s == _biome_seed and _biome_last != null:
		biome_img = _biome_last
		base = _mud_last.duplicate()
		return
	var n := FastNoiseLite.new()
	n.seed = s
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
	_biome_seed = s
	_biome_last = biome_img
	_mud_last = base.duplicate()


func idx_of(p: Vector3) -> int:
	return clampi(floori(p.z + H), 0, N - 1) * N + clampi(floori(p.x + H), 0, N - 1)


func center(idx: int) -> Vector3:
	return Vector3(idx % N - H + 0.5, 0.0, idx / N - H + 0.5)


# --- queries -------------------------------------------------------------------------

func kind_at(p: Vector3) -> int:
	var i := idx_of(p)
	if base[i] >= WATER:
		return base[i]
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
	return ground_cover(crater[i], rubble[i], woods[i], base[i])


## The cover the ground itself gives: a crater, rubble or trees (not on a
## road) are light cover; a road or mud leaves you exposed.
static func ground_cover(cr: int, ru: int, wo: int, ba: int) -> int:
	if cr > 0 or ru > 0 or (wo > 0 and ba != ROAD):
		return LIGHT
	if ba == ROAD or ba == MUD:
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
		SHALLOW:
			return 0.45 if vehicle else 0.5  # wading: slow going for men and machines
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
		SHALLOW:
			return 1.2  # out in the open, floundering
	return 1.0


func blast_mul(p: Vector3) -> float:
	return 0.6 if crater[idx_of(p)] > 0 else 1.0


## Woods hide you: spotting range against someone in them is shorter.
func in_trench(p: Vector3) -> bool:
	return trench[idx_of(p)] > 0


func concealment(p: Vector3) -> float:
	var c := net_cover(p)
	if in_trench(p):
		return 0.7 * c
	var k := kind_at(p)
	return (0.6 if k == WOODS else (0.85 if k == CRATER else 1.0)) * c


## Under a camouflage net: whatever's there is seen at half the range.
func net_cover(p: Vector3) -> float:
	return 0.5 if netted[idx_of(p)] > 0 else 1.0


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
		SHALLOW:
			return 4.0 if vehicle else 2.4  # a ford is a way across, not a way to go
	if woods[idx] > 0:
		return 2.6 if vehicle else 1.05
	# wheels and tracks keep to the roads where they can: cross-country is slow and rough
	return 1.45 if vehicle else 1.0


# --- building the map ------------------------------------------------------------------

func paint_roads(polys: Array, half_w := 2.2) -> void:
	# (a cell that's road already is passed over while the ground is fresh: see _fresh)
	var keep: bool = _fresh and not (world.nav and world.nav.hnav_i and world.nav.hnav_i.built)
	for poly in polys:
		var pts: PackedVector3Array = poly
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var x0 := floori(minf(a.x, b.x) - half_w - 1.0 + H)
			var x1 := floori(maxf(a.x, b.x) + half_w + 1.0 + H)
			var z0 := floori(minf(a.z, b.z) - half_w - 1.0 + H)
			var z1 := floori(maxf(a.z, b.z) + half_w + 1.0 + H)
			# (Defs.dist_point_segment, worked through here for every cell)
			var sa := Vector3(a.x, 0, a.z)
			var ab := Vector3(b.x, 0, b.z) - sa
			var l2 := ab.length_squared()
			var dot := l2 >= 0.0001
			for z in range(maxi(0, z0), mini(N - 1, z1) + 1):
				var row := z * N
				for x in range(maxi(0, x0), mini(N - 1, x1) + 1):
					var was: int = base[row + x]
					if was >= WATER or (keep and was == ROAD):
						continue
					var c := Vector3(x - H + 0.5, 0, z - H + 0.5)
					var d := c.distance_to(sa + ab * clampf((c - sa).dot(ab) / l2, 0.0, 1.0)) if dot else c.distance_to(sa)
					if d <= half_w:
						base[row + x] = ROAD
						_refresh_cell(row + x)
	version += 1


## Sets the ground kind over a rectangle (sidewalks and squares are road).
func paint_box(c: Vector3, half: Vector2, yaw: float, kind: int) -> void:
	var r := half.length() + 1.0
	# (Defs.point_in_obb, worked through here for every cell)
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var cc := Vector2(c.x, c.z)
	for z in range(maxi(0, floori(c.z - r + H)), mini(N - 1, floori(c.z + r + H)) + 1):
		for x in range(maxi(0, floori(c.x - r + H)), mini(N - 1, floori(c.x + r + H)) + 1):
			var d := Vector2(x - H + 0.5, z - H + 0.5) - cc
			if absf(d.dot(ax)) <= half.x and absf(d.dot(az)) <= half.y:
				base[z * N + x] = kind
				_refresh_cell(z * N + x)
	version += 1


var _dirty := PackedByteArray()  # 1: the cell is in the queue
var _queue := PackedInt32Array()
## Until the first cover recompute (tick), every cell's cover and routes are
## just as its ground last left them: whatever changes a cell's ground works
## them out again there and then (_refresh_cell), and nothing else has set
## them. Working out a cell that's road already, as road again, changes
## nothing then, so paint_roads passes over it - the map's roads are painted
## three times while a battle's laid out, each stretch over the one before.
## (After a recompute it would: a road cell with nothing round it is "no
## cover" there, "exposed" from _refresh_cell. And once the routes' graphs are
## built, Nav marks every cell it's told of for a repair.)
var _fresh := true


## A structure appeared, finished building, or was destroyed: queue the cells
## around it for a cover recompute (a few thousand cells per frame).
func structure_changed(st, added := true) -> void:
	if st.skind == "tree":
		_tree_woods(st.position, 1 if added else -1)
		return
	if st.skind == "trench" and world.atmo and world.atmo.trench_net:
		world.atmo.trench_net.mark_dirty()
	if st.skind == "camo_net":
		_nets_changed(st, added)
		return
	var r: float = st.radius + 1.6
	var x0 := maxi(0, floori(st.position.x - r + H))
	var x1 := mini(N - 1, floori(st.position.x + r + H))
	var z0 := maxi(0, floori(st.position.z - r + H))
	var z1 := mini(N - 1, floori(st.position.z + r + H))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * N + x
			if _dirty[i] == 0:
				_dirty[i] = 1
				_queue.append(i)


func _tree_woods(p: Vector3, delta: int) -> void:
	var c := idx_of(p)
	var cx := c % N
	var cz := c / N
	for z in range(maxi(0, cz - 4), mini(N, cz + 5)):
		for x in range(maxi(0, cx - 4), mini(N, cx + 5)):
			var i := z * N + x
			var d := Vector3(x - H + 0.5, 0.0, z - H + 0.5) - p  # (centre(i) - p)
			if Vector3(d.x, 0.0, d.z).length() < 3.8:
				woods[i] = clampi(int(woods[i]) + delta, 0, 255)
				_refresh_cell(i)
	version += 1


## A net went up, came down or was finished: the ground under every net round
## it is worked out again from the nets that stand there now.
func _nets_changed(st, added: bool) -> void:
	var r: float = st.radius + 0.5
	var nets: Array = []
	for o in world.structures_near(st.position, r + 8.0):
		if o.skind == "camo_net" and o.built and not o.gone and (o != st or added):
			nets.append(o)
	if added and st.built and not st in nets:
		nets.append(st)
	for z in range(maxi(0, floori(st.position.z - r + H)), mini(N - 1, floori(st.position.z + r + H)) + 1):
		for x in range(maxi(0, floori(st.position.x - r + H)), mini(N - 1, floori(st.position.x + r + H)) + 1):
			var c := Vector2(x - H + 0.5, z - H + 0.5)
			var on := 0
			for o in nets:
				if Defs.point_in_obb(c, Vector2(o.position.x, o.position.z), o.foot - Vector2(0.3, 0.3), o.yaw):
					on = 1
					break
			netted[z * N + x] = on


## Processes queued cells; call every frame / tick. Each cell's cover is
## worked out from the structures within reach (_lay_out, CoverJob) and then
## written, and the routes told of it, cell by cell in the queue's order. A
## big batch (a new map's: tens of thousands of cells) is worked out on the
## worker threads, a slice of the queue each; nothing a cell's working-out
## reads is written until they're all done.
func tick(budget := 2500) -> void:
	if _queue.is_empty():
		return
	var end := mini(_qhead + budget, _queue.size())
	_fresh = false
	var cells := _queue.slice(_qhead, end)
	var lay := _lay_out(cells)
	var jobs: Array = []
	var per := cells.size() if cells.size() < THREAD_CELLS else JOB_CELLS
	for s in range(0, cells.size(), per):
		var job := CoverJob.new()
		job.lay = lay
		job.cells = cells.slice(s, mini(s + per, cells.size()))
		job.first = s
		job.crater = crater
		job.woods = woods
		job.base = base
		jobs.append(job)
	if jobs.size() == 1:
		(jobs[0] as CoverJob).run()
	else:
		var task := WorkerThreadPool.add_group_task(func(j: int): (jobs[j] as CoverJob).run(), jobs.size(), -1, true, "Cover")
		WorkerThreadPool.wait_for_group_task_completion(task)
	for job: CoverJob in jobs:
		var out := job.out
		var jc := job.cells
		for q in jc.size():
			var i := jc[q]
			_dirty[i] = 0
			rubble[i] = out[q * 5]
			trench[i] = out[q * 5 + 1]
			solid[i] = out[q * 5 + 2]
			cov[i] = out[q * 5 + 3]
			cdir[i] = out[q * 5 + 4]
			_nav_refresh(i)
	_qhead = end
	if _qhead >= _queue.size():
		_queue.clear()
		_qhead = 0
	version += 1


var _qhead := 0  # next queued cell (the queue is consumed in place, not copied)
const THREAD_CELLS := 8192  # a batch this big is shared out over the worker threads,
const JOB_CELLS := 2048  # this many cells a task

# what a structure offers in cover (see _lay_out)
enum {C_NONE, C_PARTS, C_TRENCH, C_BUNKER}
const NO_COVER := ["floor", "wire", "mines", "tank_trap", "tunnel", "helipad", "tree", "camo_net"]
# World's buckets of structures (16 m squares) are each cut into 2 m squares
# that list (in the bucket's order) the structures that can reach a cell in
# them: a town's bucket holds a hundred walls and more, a cell is near a few.
const SUB := 2.0
const SUB_PAD := 2.0  # (a cell looks into the buckets within 1.6 m of it)
const SUB_N := 10  # (World.SCELL + 2 SUB_PAD) / SUB
const SUB_LEN := SUB_N * SUB_N + 1


## What's near a batch of cells, as plain arrays (a job touches no structure):
## World's buckets the cells look into, and every structure standing in them
## once, as a slot, with what it offers in cover.
class CoverLay:
	extends RefCounted
	var sc := 16.0  # World.SCELL: a bucket's size
	var bx0 := 0  # the first bucket column (and row) on the map
	var nb := 0  # buckets across
	var bucket := PackedInt32Array()  # (bx - bx0) * nb + (bz - bx0) -> the bucket's number, -1 none
	var starts := PackedInt32Array()  # per bucket, per 2 m square (SUB_LEN each): where its list starts in idx
	var idx := PackedInt32Array()  # the lists: slots
	var slots := 0
	var pos := PackedVector3Array()  # per slot: the structure's position
	var rad := PackedFloat64Array()  # its radius
	var kind := PackedByteArray()  # C_*
	var rub := PackedByteArray()  # rubble
	var dug := PackedByteArray()  # a finished trench
	var p0 := PackedInt32Array()  # its cover parts (in wc and pf), from
	var p1 := PackedInt32Array()  # to
	var wc := PackedVector3Array()  # per cover part: its centre (world)
	var pf := PackedFloat64Array()  # and its turn (cos, sin), half size (x, z), level
	var obb := PackedVector2Array()  # per slot: centre, half size (rubble), half size (bunker), axes (2)
	var seg := PackedVector3Array()  # per slot: a trench's ends
	var centers := PackedVector3Array()  # the batch's cells' centres (TerrainMap.center), in its order


## One slice of a batch: each cell's rubble, trench, solid, cover level + 1 and
## cover direction, five bytes a cell in `out` (see TerrainMap.tick).
class CoverJob:
	extends RefCounted
	var lay: CoverLay
	var cells := PackedInt32Array()
	var first := 0  # where its cells start in the batch
	var crater := PackedByteArray()
	var woods := PackedByteArray()
	var base := PackedByteArray()
	var out := PackedByteArray()

	func run() -> void:
		var sc := lay.sc
		var bx0 := lay.bx0
		var nb := lay.nb
		var bucket := lay.bucket
		var starts := lay.starts
		var idx := lay.idx
		var pos := lay.pos
		var rad := lay.rad
		var kind := lay.kind
		var rub_of := lay.rub
		var dug := lay.dug
		var p0 := lay.p0
		var p1 := lay.p1
		var wc := lay.wc
		var pf := lay.pf
		var obb := lay.obb
		var seg := lay.seg
		var centers := lay.centers  # (worked out on the main thread: no whole-number / or % here, see HNav.build_all)
		var met := PackedInt32Array()  # per slot: the last cell (q) that met it
		met.resize(lay.slots)
		met.fill(-1)
		out.resize(cells.size() * 5)
		for q in cells.size():
			var i := cells[q]
			var c := centers[first + q]
			var best := NONE
			var bdir := 255
			var rub := 0
			var tr := 0
			var hit := false  # the cell is inside a wall or building
			# the structures within 1.6 m (World.structures_near: its buckets, in
			# its order, each structure once)
			for bx in range(floori((c.x - 1.6) / sc), floori((c.x + 1.6) / sc) + 1):
				for bz in range(floori((c.z - 1.6) / sc), floori((c.z + 1.6) / sc) + 1):
					var b := bucket[(bx - bx0) * nb + (bz - bx0)]
					if b < 0:
						continue
					var sub := b * SUB_LEN + floori((c.z - (bz * sc - SUB_PAD)) / SUB) * SUB_N + floori((c.x - (bx * sc - SUB_PAD)) / SUB)
					for j in range(starts[sub], starts[sub + 1]):
						var s := idx[j]
						if met[s] == q:
							continue
						met[s] = q
						var dv: Vector3 = pos[s] - c
						if not (Vector3(dv.x, 0.0, dv.z).length() <= 1.6 + rad[s]):
							continue
						var in_trench := false
						if dug[s] == 1:
							in_trench = TrenchNet.sd_seg(seg[s * 2], seg[s * 2 + 1], c) < -0.0  # (TrenchNet.inside)
							if in_trench:
								tr = 1
						if rub_of[s] == 1:
							# (Defs.point_in_obb)
							var d := Vector2(c.x, c.z) - obb[s * 5]
							if absf(d.dot(obb[s * 5 + 3])) <= obb[s * 5 + 1].x and absf(d.dot(obb[s * 5 + 4])) <= obb[s * 5 + 1].y:
								rub = 1
						var k := kind[s]
						if k == C_NONE or p0[s] == p1[s]:
							continue
						if k == C_TRENCH:
							# dug in: heavy cover from every side down in the trench
							if in_trench and HEAVY > best:
								best = HEAVY
								bdir = OMNI
							continue
						if k == C_BUNKER:
							var d := Vector2(c.x, c.z) - obb[s * 5]
							if absf(d.dot(obb[s * 5 + 3])) <= obb[s * 5 + 2].x and absf(d.dot(obb[s * 5 + 4])) <= obb[s * 5 + 2].y:
								# under a roof: heavy cover from every side inside the footprint
								if HEAVY > best:
									best = HEAVY
									bdir = OMNI
								continue
						# the best of its parts (the first, of those as good)
						var not_rubble := rub_of[s] == 0
						var lvl_s := 0
						var dir_s := 0
						for p in range(p0[s], p1[s]):
							# cell position in the part's local frame
							var d := c - wc[p]
							var cs := pf[p * 5]
							var sn := pf[p * 5 + 1]
							var hx := pf[p * 5 + 2]
							var hz := pf[p * 5 + 3]
							var lx := d.x * cs - d.z * sn
							var lz := d.x * sn + d.z * cs
							var qx := clampf(lx, -hx, hx)
							var qz := clampf(lz, -hz, hz)
							var gap := Vector2(lx - qx, lz - qz).length()
							var inside := gap < 0.001
							if inside and not_rubble:
								hit = true
							if inside or gap > 1.35:
								continue
							var lvl := int(pf[p * 5 + 4])
							if lvl > lvl_s:
								# direction from the cell towards the cover (world space)
								var lv := Vector2(qx - lx, qz - lz)
								var wx := lv.x * cs + lv.y * sn
								var wz := -lv.x * sn + lv.y * cs
								lvl_s = lvl
								dir_s = posmod(int(round(atan2(wz, wx) / (TAU / 8.0))), 8)
						if lvl_s > best:
							best = lvl_s
							bdir = dir_s
			# what the ground itself gives (TerrainMap.ground_cover, with the rubble just found)
			var ba := base[i]
			var bc := NONE
			if crater[i] > 0 or rub > 0 or (woods[i] > 0 and ba != ROAD):
				bc = LIGHT
			elif ba == ROAD or ba == MUD:
				bc = EXPOSED
			if bc > best or (bc == best and best == LIGHT):
				best = bc
				bdir = OMNI if bc == LIGHT else 255
			out[q * 5] = rub
			out[q * 5 + 1] = tr
			out[q * 5 + 2] = 1 if hit else 0
			out[q * 5 + 3] = best + 1
			out[q * 5 + 4] = bdir


## What's near `cells` (see CoverLay): the buckets of World's they look into,
## laid out, and what each structure in those offers in cover.
func _lay_out(cells: PackedInt32Array) -> CoverLay:
	var lay := CoverLay.new()
	var sc: float = World.SCELL
	lay.sc = sc
	lay.bx0 = floori((-H - 1.6) / sc)
	lay.nb = floori((H + 1.6) / sc) - lay.bx0 + 1
	var nb := lay.nb
	var bx0 := lay.bx0
	var want := PackedByteArray()
	want.resize(nb * nb)
	want.fill(0)
	# (and where the cells are: a structure that can reach none of them is left out)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in cells:
		var c := center(i)
		lay.centers.append(c)
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.z))
		for bx in range(floori((c.x - 1.6) / sc), floori((c.x + 1.6) / sc) + 1):
			for bz in range(floori((c.z - 1.6) / sc), floori((c.z + 1.6) / sc) + 1):
				want[(bx - bx0) * nb + (bz - bx0)] = 1
	lay.bucket.resize(nb * nb)
	lay.bucket.fill(-1)
	var slot_of := {}  # eid -> slot
	var buckets: Dictionary = world._shash
	var nbu := 0
	for w in nb * nb:
		if want[w] == 0:
			continue
		var bx := w / nb + bx0
		var bz := w % nb + bx0
		var a = buckets.get(Vector2i(bx, bz))
		if a == null:
			continue
		var list := PackedInt32Array()  # its structures standing, as slots, in its order
		for st in a:
			if not is_instance_valid(st) or st.gone:
				continue
			var reach: float = st.radius + 1.7
			var sp: Vector3 = st.position
			if sp.x + reach < lo.x or sp.x - reach > hi.x or sp.z + reach < lo.y or sp.z - reach > hi.y:
				continue
			var s: int = slot_of.get(st.eid, -1)
			if s < 0:
				s = lay.slots
				slot_of[st.eid] = s
				_add_slot(lay, st)
			list.append(s)
		if list.is_empty():
			continue
		lay.bucket[w] = nbu
		nbu += 1
		# the 2 m squares each structure can reach a cell in (1.6 m past its radius)
		var ox: float = bx * sc - SUB_PAD
		var oz: float = bz * sc - SUB_PAD
		var counts := PackedInt32Array()
		counts.resize(SUB_LEN)
		counts.fill(0)
		var spans := PackedInt32Array()
		for s in list:
			var r: float = 1.6 + lay.rad[s] + 0.05
			var p := lay.pos[s]
			var x0 := maxi(0, floori((p.x - r - ox) / SUB))
			var x1 := mini(SUB_N - 1, floori((p.x + r - ox) / SUB))
			var z0 := maxi(0, floori((p.z - r - oz) / SUB))
			var z1 := mini(SUB_N - 1, floori((p.z + r - oz) / SUB))
			spans.append(x0)
			spans.append(x1)
			spans.append(z0)
			spans.append(z1)
			for z in range(z0, z1 + 1):
				for x in range(x0, x1 + 1):
					counts[z * SUB_N + x + 1] += 1
		var at := lay.idx.size()
		for t in SUB_N * SUB_N:
			counts[t + 1] += counts[t]
		lay.idx.resize(at + counts[SUB_N * SUB_N])
		var fill := counts.duplicate()
		for k in list.size():
			for z in range(spans[k * 4 + 2], spans[k * 4 + 3] + 1):
				for x in range(spans[k * 4], spans[k * 4 + 1] + 1):
					var t := z * SUB_N + x
					lay.idx[at + fill[t]] = list[k]
					fill[t] += 1
		for t in SUB_LEN:
			counts[t] += at
		lay.starts.append_array(counts)
	return lay


## A structure's slot in a CoverLay: where it is, and what it offers the
## cells round it in cover - its cover parts (high enough to hide behind) with
## each one's centre, turn, half size and level, a rubble heap's or a
## bunker's footprint, a trench's ends.
func _add_slot(lay: CoverLay, st) -> void:
	lay.slots += 1
	lay.pos.append(st.position)
	lay.rad.append(st.radius)
	var k := C_PARTS
	if not st.built or st.skind in NO_COVER:
		k = C_NONE
	elif st.skind == "trench":
		k = C_TRENCH
	elif st.skind == "bunker":
		k = C_BUNKER
	var rubble_st: bool = st.skind == "rubble"
	lay.kind.append(k)
	lay.rub.append(1 if rubble_st else 0)
	lay.dug.append(1 if st.skind == "trench" and st.built else 0)
	lay.p0.append(lay.wc.size())
	if k != C_NONE:
		var b := Basis(Vector3.UP, st.yaw)
		var heavy: bool = st.skind in HEAVY_KINDS
		for part in st.parts:
			if not part.cover:
				continue
			var top: float = part.p.y + part.s.y * 0.5
			if top < 0.55:
				continue  # (too low to hide behind)
			var yaw: float = st.yaw + part.r
			var hx: float = part.s.x * 0.5
			var hz: float = part.s.z * 0.5
			lay.wc.append(st.position + b * part.p)
			lay.pf.append(cos(yaw))
			lay.pf.append(sin(yaw))
			lay.pf.append(hx)
			lay.pf.append(hz)
			lay.pf.append(LIGHT if rubble_st else (HEAVY if (top >= 1.35 or heavy) else LIGHT))
	lay.p1.append(lay.wc.size())
	# (Defs.point_in_obb's footprint and axes, TrenchNet.inside's ends)
	lay.obb.append(Vector2(st.position.x, st.position.z))
	lay.obb.append(st.foot + Vector2(0.4, 0.4))
	lay.obb.append(st.foot)
	lay.obb.append(Vector2(cos(st.yaw), -sin(st.yaw)))
	lay.obb.append(Vector2(sin(st.yaw), cos(st.yaw)))
	if st.skind == "trench":
		var sg := TrenchNet.seg_of(st)
		lay.seg.append(sg[0])
		lay.seg.append(sg[1])
	else:
		lay.seg.append(Vector3.ZERO)
		lay.seg.append(Vector3.ZERO)


func _refresh_cell(i: int) -> void:
	var lvl: int = cov[i] - 1
	var d: int = cdir[i]
	if lvl <= LIGHT and (d == 255 or d == OMNI):
		var b := _base_cover(i)
		cov[i] = b + 1
		cdir[i] = OMNI if b == LIGHT else 255
	_nav_refresh(i)


## _refresh_cell for each of `cells`, in turn (the same, without two calls a cell).
func refresh_cells(cells: PackedInt32Array) -> void:
	var nav = world.nav
	for i in cells:
		var lvl: int = cov[i] - 1
		var d: int = cdir[i]
		if lvl <= LIGHT and (d == 255 or d == OMNI):
			var b := ground_cover(crater[i], rubble[i], woods[i], base[i])
			cov[i] = b + 1
			cdir[i] = OMNI if b == LIGHT else 255
		if _nav_hold:
			if _nav_held[i] == 0:
				_nav_held[i] = 1
				_nav_list.append(i)
		elif nav:
			nav.terrain_changed(i)


func _nav_refresh(i: int) -> void:
	if _nav_hold:
		if _nav_held[i] == 0:
			_nav_held[i] = 1
			_nav_list.append(i)
		return
	if world.nav:
		world.nav.terrain_changed(i)


## While the map is laid out nothing asks the way, and how Nav weighs a cell
## hangs only on what the cell is when it's told (nothing of what it was
## before): so until release_nav, the cells that change are only noted, and
## then told to it once each - not each time (a road painted over three
## times, every tree of a wood, the whole sea). Only before Nav.finalize: once
## the hierarchical graphs are built, the order cells come in matters to them.
var _nav_hold := false
var _nav_held := PackedByteArray()
var _nav_list := PackedInt32Array()


func hold_nav() -> void:
	_nav_hold = true
	_nav_held.resize(N * N)
	_nav_held.fill(0)
	_nav_list = PackedInt32Array()


func release_nav() -> void:
	if not _nav_hold:
		return
	_nav_hold = false
	var cells := _nav_list
	_nav_list = PackedInt32Array()
	_nav_held = PackedByteArray()
	if world.nav:
		for i in cells:
			world.nav.terrain_changed(i)


# --- craters (destructible ground) ---------------------------------------------------------

## Explosions dig craters: light cover for infantry, rough going for vehicles.
func add_crater(p: Vector3, size: float) -> void:
	if base[idx_of(p)] >= WATER:
		return  # a fountain of water, not a hole
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
func best_spot_near(p: Vector3, r: float, from: Vector3, taken: Array, group_center := Vector3.INF, group_radius := 0.0) -> Array:
	var best := p if group_center == Vector3.INF else group_center
	var bs := -1e9
	var c := idx_of(p if group_center == Vector3.INF else group_center)
	var cx := c % N
	var cz := c / N
	var ri := int(ceil(r if group_center == Vector3.INF else group_radius))
	for z in range(maxi(0, cz - ri), mini(N, cz + ri + 1)):
		for x in range(maxi(0, cx - ri), mini(N, cx + ri + 1)):
			var i := z * N + x
			if solid[i] > 0:
				continue
			var q := center(i)
			var d := Defs.flat(q - p).length()
			if (group_center == Vector3.INF and d > r) or (group_center != Vector3.INF and not group_spot(q, group_center, group_radius)):
				continue
			var sc := cover_vs(q, from) * 3.0 - d * 0.6 + (2.5 if trench[i] > 0 else 0.0)
			for t in taken:
				if Defs.flat((t as Vector3) - q).length() < 1.4:
					sc -= 100.0 if group_center != Vector3.INF else 5.0
			if sc > bs:
				bs = sc
				best = q
	var an := Cover.best_near(world, p, r + 0.8 if group_center == Vector3.INF else group_radius * 2.0, from, taken, group_center, group_radius)
	if not an.is_empty() and float(an[1]) + 0.5 >= bs:
		return [an[0], Cover.level_of(int(an[2].mat)), an[2]]
	return [best, cover_vs(best, from), {}]


## A squad shares open ground; better cover across a wall must not split it.
func group_spot(p: Vector3, c: Vector3, radius: float, normal := Vector3.ZERO) -> bool:
	# Wall anchors sit inside padded nav cells; approach from their outward side.
	var approach := p - normal * 0.8
	return Defs.flat(p - c).length_squared() <= radius * radius and world.nav.walkable(approach) and world.nav._line_free(c, approach, false)


## Compact circular slots, shared by orders and their preview. Defence has a
## little more room to occupy cover, but never stretches into a squad-wide line.
func slots(c: Vector3, face: Vector3, n: int, wide := false) -> Array:
	if face.length() < 0.1:
		face = Vector3.FORWARD
	c = world.nav.nearest_walkable(c)
	if world.nav.kind_at(c) != Nav.FREE:
		# A click on a vaultable wall belongs beside it, on the sheltered side.
		var best := INF
		var clicked := c
		for z in range(-3, 4):
			for x in range(-3, 4):
				var q := clicked + Vector3(x, 0, z)
				var score := q.distance_squared_to(clicked) + face.dot(q - clicked) * 0.1
				if world.nav.kind_at(q) == Nav.FREE and score < best:
					best = score
					c = q
	var side := face.cross(Vector3.UP).normalized()
	var threat := c + face * 40.0
	var taken := []
	var out := []
	var radius := 6.5 if wide else 5.5
	for i in n:
		var angle := i * 2.399963
		var spread := minf(4.5 if wide else 3.5, sqrt(float(i)) * 1.5)
		var p := c + (side * cos(angle) + face * sin(angle)) * spread
		var sp := best_spot_near(p, 3.4 if wide else 2.6, threat, taken, c, radius)
		taken.append(sp[0])
		out.append(sp)
	return out


func describe(p: Vector3, from := Vector3.INF) -> String:
	var k := kind_at(p)
	var lvl := cover_at(p) if from == Vector3.INF else cover_vs(p, from)
	var cs: String = ["Exposed", "No cover", "Light cover", "Heavy cover"][lvl + 1]
	return "%s  -  %s" % [cs, KIND_NAMES[k]]
