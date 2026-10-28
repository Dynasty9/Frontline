class_name WaterMap
extends RefCounted
## Rivers, ponds and the sea. The server lays the water out (a handful of
## shapes: a coastline, river centre-lines, ponds, fords and the bridge spans
## over them); every peer rasterizes the same shapes into the terrain - the
## ground kinds (deep water nobody can cross on foot, shallows men and
## vehicles can wade), the riverbed and sea floor carved into the ground
## heights - and the view draws the water surface over it.

const LEVEL := -0.45  # the water's surface
const WADE := -1.0  # a bed above this is shallow enough to wade (a ford, the edge of a beach)
const RIVER_FLOW := 0.45  # how fast a river runs in mid-stream (m/s)

var world
var coast := {}  # {"x": mean shoreline x (the sea is east of it), "s": seed}
var rivers: Array = []  # [{"pts": PackedVector3Array, "w": width}]
var ponds: Array = []  # [{"c": Vector3, "r": radius, "s": seed}]
var fords: Array = []  # [Vector3]: shallow across the river here
var bridges: Array = []  # [[a, b, half width]]: road decks over the water (nothing carved under them)
var deck := PackedByteArray()  # (1 m cells) on a bridge deck
var mask: Image  # (view) R depth, G shore, B sea (vs fresh water), A water
var version := 0


func _init(w) -> void:
	world = w


func is_empty() -> bool:
	return coast.is_empty() and rivers.is_empty() and ponds.is_empty()


func to_dict() -> Dictionary:
	return {"coast": coast, "rivers": rivers, "ponds": ponds, "fords": fords, "bridges": bridges}


func from_dict(d: Dictionary) -> void:
	coast = d.get("coast", {})
	rivers = d.get("rivers", [])
	ponds = d.get("ponds", [])
	fords = d.get("fords", [])
	bridges = d.get("bridges", [])


# --- the shapes ----------------------------------------------------------------------

## Where the shoreline runs at z (the sea is east of it): a long, irregular
## curve of bays and headlands.
func coast_x(z: float) -> float:
	if coast.is_empty():
		return INF
	var s := float(coast.s)
	return float(coast.x) + 22.0 * sin(z * 0.0105 + s) + 9.0 * sin(z * 0.031 + s * 2.3) + 4.0 * sin(z * 0.077 + s * 0.7)


## The way the water's moving at p, and how fast: a river runs south (as the
## water is drawn: see water_view.gd), fastest in mid-stream and slack under
## the banks; the sea and the ponds lie still.
func current_at(p: Vector3) -> Vector3:
	for r in rivers:
		var pts: PackedVector3Array = r.pts
		var hw: float = float(r.w) * 0.5
		var best := hw
		var flow := Vector3.ZERO
		for si in pts.size() - 1:
			var a := pts[si]
			var b := pts[si + 1]
			if p.z < minf(a.z, b.z) - hw or p.z > maxf(a.z, b.z) + hw or p.x < minf(a.x, b.x) - hw or p.x > maxf(a.x, b.x) + hw:
				continue
			var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
			var t := clampf(((p.x - a.x) * ab.x + (p.z - a.z) * ab.z) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d := Vector2(p.x - a.x - ab.x * t, p.z - a.z - ab.z * t).length()
			if d < best:
				best = d
				flow = ab.normalized() * (-1.0 if ab.z > 0.0 else 1.0)
		if flow != Vector3.ZERO:
			return flow * RIVER_FLOW * (1.0 - (best / hw) * (best / hw))
	return Vector3.ZERO


# --- rasterizing -----------------------------------------------------------------------

var _mbytes := PackedByteArray()

## A pass over the water (paint_kinds, carve) is cut into bands of rows, each
## written by a task of its own on the worker threads. A sample is only ever
## written by its own band, and there by every shape that reaches it in the
## same order as ever (the sea, the rivers segment by segment, the ponds), so
## the ground comes out the same however the bands are shared out.
const BANDS := 32


## One band of a pass: the shapes, the arrays it writes (shared, each band
## its own rows of them), and the samples it changed. It goes row by row, and
## on each row shape by shape over the stretch the shape reaches (the work for
## each sample is written out in the loops, not called for: a call per sample
## is most of the cost, and on the worker threads it hardly gets any quicker).
class Raster:
	extends RefCounted
	var res := 1
	var n := 0
	var h := 0.0
	var carving := false  # carve (heights) rather than paint_kinds (kinds, mask)
	var view := false  # (paint) the mask too
	var listing := false  # list the samples changed, each once
	var z_lo := 0
	var z_hi := 0
	var sea := false
	var sea_x0 := 0  # the sea's first column
	var coast := PackedFloat64Array()  # the shoreline (coast_x) on each row
	var riv_pts: Array = []  # PackedVector3Array per river
	var riv_hw := PackedFloat64Array()
	var fords := PackedVector3Array()
	var pond_c := PackedVector3Array()
	var pond_r := PackedFloat64Array()
	var pond_s := PackedFloat64Array()
	var dh := PackedFloat32Array()
	var base := PackedByteArray()
	var deck := PackedByteArray()
	var mbytes := PackedByteArray()
	var span := PackedByteArray()  # under a bridge deck (see WaterMap._decks)
	var quays := PackedByteArray()
	var seen := PackedByteArray()
	var changed := PackedInt32Array()
	# (WaterMap's and TerrainMap's constants, as the band's own)
	var level := 0.0
	var wade := 0.0
	var k_water := 0
	var k_shallow := 0
	var k_road := 0
	# one shape's stretch of the row: how far in from its waterline each
	# sample is, the bed there, and whether the shape reaches it at all
	var into := PackedFloat64Array()
	var bed := PackedFloat64Array()
	var hit := PackedByteArray()

	func run() -> void:
		into.resize(n)
		bed.resize(n)
		hit.resize(n)
		# the river's segments (all the rivers', in order): the box each reaches
		var sx0 := PackedInt32Array()
		var sx1 := PackedInt32Array()
		var sz0 := PackedInt32Array()
		var sz1 := PackedInt32Array()
		var sg := PackedFloat64Array()  # ax, az, abx, abz, ll, hw
		var sford := PackedByteArray()
		for ri in riv_pts.size():
			var pts: PackedVector3Array = riv_pts[ri]
			var hw := riv_hw[ri]
			var reach := hw + 5.0
			for si in pts.size() - 1:
				var a := pts[si]
				var b := pts[si + 1]
				sx0.append(maxi(0, floori((minf(a.x, b.x) - reach + h) * res)))
				sx1.append(mini(n - 1, ceili((maxf(a.x, b.x) + reach + h) * res)))
				sz0.append(maxi(0, floori((minf(a.z, b.z) - reach + h) * res)))
				sz1.append(mini(n - 1, ceili((maxf(a.z, b.z) + reach + h) * res)))
				var abx := b.x - a.x
				var abz := b.z - a.z
				sg.append(a.x)
				sg.append(a.z)
				sg.append(abx)
				sg.append(abz)
				sg.append(maxf(abx * abx + abz * abz, 0.0001))
				sg.append(hw)
				# a ford raises the bed within 10 m of it: only a segment that comes
				# that near one need look
				var by_ford := 0
				for f: Vector3 in fords:
					if f.x > minf(a.x, b.x) - reach - 12.0 and f.x < maxf(a.x, b.x) + reach + 12.0 and f.z > minf(a.z, b.z) - reach - 12.0 and f.z < maxf(a.z, b.z) + reach + 12.0:
						by_ford = 1
				sford.append(by_ford)
		for z in range(z_lo, z_hi):
			var wz := (z + 0.5) / res - h
			var row := z * n
			if sea:
				# east of the shoreline, a beach behind it
				var cx := coast[z]
				for x in range(sea_x0, n):
					var t := (x + 0.5) / res - h - cx
					into[x] = t
					hit[x] = 1 if t >= -14.0 else 0
				_beds(sea_x0, n - 1, -3.2, 9.0, 14.0)
				_write(row, sea_x0, n - 1, true, 14.0)
			for s in sx0.size():
				if z < sz0[s] or z > sz1[s]:
					continue
				var ax := sg[s * 6]
				var az := sg[s * 6 + 1]
				var abx := sg[s * 6 + 2]
				var abz := sg[s * 6 + 3]
				var ll := sg[s * 6 + 4]
				var hw := sg[s * 6 + 5]
				var x0 := sx0[s]
				var x1 := sx1[s]
				for x in range(x0, x1 + 1):
					var wx := (x + 0.5) / res - h
					var t := clampf(((wx - ax) * abx + (wz - az) * abz) / ll, 0.0, 1.0)
					var dx := wx - ax - abx * t
					var dz := wz - az - abz * t
					var it := hw - sqrt(dx * dx + dz * dz)
					into[x] = it
					hit[x] = 0 if it < -5.0 else 1
				_beds(x0, x1, -2.3, 3.0, 5.0)
				if sford[s] == 1:
					for x in range(x0, x1 + 1):
						if hit[x] == 0:
							continue
						var wx := (x + 0.5) / res - h
						var b := bed[x]
						for f: Vector3 in fords:
							var fd := Vector2(wx - f.x, wz - f.z).length()
							if fd < 10.0:
								b = maxf(b, lerpf(-0.8, b, smoothstep(6.0, 10.0, fd)))
						bed[x] = b
				_write(row, x0, x1, false, 5.0)
			for pi in pond_c.size():
				var c := pond_c[pi]
				var pr := pond_r[pi]
				var ps := pond_s[pi]
				var rr := pr * 1.3 + 6.0
				if z < maxi(0, floori((c.z - rr + h) * res)) or z > mini(n - 1, ceili((c.z + rr + h) * res)):
					continue
				var x0 := maxi(0, floori((c.x - rr + h) * res))
				var x1 := mini(n - 1, ceili((c.x + rr + h) * res))
				for x in range(x0, x1 + 1):
					var wx := (x + 0.5) / res - h
					var rel := Vector2(wx - c.x, wz - c.z)
					var ang := rel.angle()
					var it := pr * (1.0 + 0.18 * sin(ang * 3.0 + ps) + 0.1 * sin(ang * 5.0 + ps * 1.7)) - rel.length()  # (the pond's edge, wavy)
					into[x] = it
					hit[x] = 1 if it >= -6.0 else 0
				_beds(x0, x1, -2.0, 4.0, 6.0)
				_write(row, x0, x1, false, 6.0)

	## The ground `into` metres in from the waterline (negative: up the bank),
	## over a stretch of the row: the bank sloping down to the water, a shelf
	## you can wade, then the deep.
	func _beds(x0: int, x1: int, deep: float, shelf: float, bank: float) -> void:
		var top := level + 0.07
		var lip := level - 0.05
		var edge := wade - 0.05
		for x in range(x0, x1 + 1):
			if hit[x] == 0:
				continue
			var t := into[x]
			if t <= 0.0:
				bed[x] = lerpf(top, 0.0, clampf(-t / bank, 0.0, 1.0))
			elif t < shelf:
				bed[x] = lerpf(lip, edge, t / shelf)
			else:
				bed[x] = lerpf(edge, deep, clampf((t - shelf) / 8.0, 0.0, 1.0))

	## One shape's say over a stretch of the row. Carving, the ground heights:
	## only ever lowered, nothing under a bridge. Painting, the ground kinds
	## (and, with a view, the mask); a cell whose kind changes is listed, and its
	## cover and routes are worked out again once the pass is over.
	func _write(row: int, x0: int, x1: int, salt: bool, bank: float) -> void:
		if carving:
			for x in range(x0, x1 + 1):
				if hit[x] == 0:
					continue
				var b := bed[x]
				var i := row + x
				if b < dh[i] and (b < level or span[i] == 0):
					dh[i] = b
					if listing and seen[i] == 0:
						seen[i] = 1
						changed.append(i)
			return
		for x in range(x0, x1 + 1):
			if hit[x] == 0:
				continue
			var b := bed[x]
			var i := row + x
			var on_bridge := b < level and span[i] == 1
			var was: int = base[i]
			if on_bridge:
				deck[i] = 1
				if was >= k_water:
					base[i] = k_road
			elif b < wade:
				base[i] = k_water
			elif b < level and was != k_water:
				base[i] = k_shallow
			if base[i] != was and seen[i] == 0:
				seen[i] = 1
				changed.append(i)
			if not view or (on_bridge and quays[i] == 1):
				continue  # (a quay is solid down to the seabed; a bridge has water under it)
			# the mask: the deepest water, the most shore
			var j := i * 4
			var t := into[x]
			var depth := int(clampf((level - b) / 3.0, 0.0, 1.0) * 255.0)
			var shore := 255 if t > 0.0 else int(clampf(1.0 + t / bank, 0.0, 1.0) * 255.0)
			mbytes[j] = maxi(mbytes[j], depth)
			mbytes[j + 1] = maxi(mbytes[j + 1], shore)
			if salt:
				mbytes[j + 2] = 255
			if b < level:
				mbytes[j + 3] = 255


## Runs a pass at `res` samples per metre over the terrain's arrays, band by
## band on the worker threads, and returns the samples it changed (paint:
## whose kind changed; carve, with a view: that were lowered).
func _pass(res: int, carving: bool, span: PackedByteArray, quays: PackedByteArray) -> PackedInt32Array:
	var tm = world.terrain
	var n := MapDims.N * res
	var h := MapDims.HALF
	var listing: bool = not carving or tm.deform_img != null
	var seen := PackedByteArray()
	if listing:
		seen.resize(n * n)
		seen.fill(0)
	var cxs := PackedFloat64Array()
	var x0 := 0
	if not coast.is_empty():
		cxs.resize(n)
		for z in n:
			cxs[z] = coast_x((z + 0.5) / res - h)
		x0 = maxi(0, floori((float(coast.x) - 36.0 - 14.0 + h) * res))
	var rpts: Array = []
	var rhw := PackedFloat64Array()
	for r in rivers:
		rpts.append(r.pts)
		rhw.append(float(r.w) * 0.5)
	var fps := PackedVector3Array()
	for f: Vector3 in fords:
		fps.append(f)
	var pc := PackedVector3Array()
	var pr := PackedFloat64Array()
	var pz := PackedFloat64Array()
	for p in ponds:
		pc.append(p.c)
		pr.append(float(p.r))
		pz.append(float(p.s))
	# What the bands write, each made this pass's own here and now: written
	# while something else still shares it, an array is copied first, and the
	# bands must not all start doing that at once.
	var dh: PackedFloat32Array = tm.dh
	var base: PackedByteArray = tm.base
	var dk := deck
	var mb := _mbytes
	if carving:
		dh[0] = dh[0]
	else:
		base[0] = base[0]
		dk[0] = dk[0]
		if not mb.is_empty():
			mb[0] = mb[0]
	if listing:
		seen[0] = seen[0]
	var rows := ceili(float(n) / BANDS)
	var bands: Array = []
	for b in BANDS:
		var r := Raster.new()
		r.res = res
		r.n = n
		r.h = h
		r.carving = carving
		r.view = not _mbytes.is_empty()
		r.listing = listing
		r.z_lo = mini(n, b * rows)
		r.z_hi = mini(n, (b + 1) * rows)
		r.sea = not coast.is_empty()
		r.sea_x0 = x0
		r.coast = cxs
		r.riv_pts = rpts
		r.riv_hw = rhw
		r.fords = fps
		r.pond_c = pc
		r.pond_r = pr
		r.pond_s = pz
		r.dh = dh
		r.base = base
		r.deck = dk
		r.mbytes = mb
		r.span = span
		r.quays = quays
		r.seen = seen
		r.level = LEVEL
		r.wade = WADE
		r.k_water = TerrainMap.WATER
		r.k_shallow = TerrainMap.SHALLOW
		r.k_road = TerrainMap.ROAD
		bands.append(r)
	var task := WorkerThreadPool.add_group_task(func(b: int): (bands[b] as Raster).run(), bands.size(), -1, true, "Water")
	WorkerThreadPool.wait_for_group_task_completion(task)
	var changed := PackedInt32Array()
	for r: Raster in bands:
		changed.append_array(r.changed)
	return changed


## The samples (`res` per metre) a bridge deck covers, with `pad` metres to
## spare (_in_bridge, asked only round each bridge); with `quays`, those a
## quay covers (_quay) instead.
func _decks(res: int, pad: float, quays := false) -> PackedByteArray:
	var n := MapDims.N * res
	var h := MapDims.HALF
	var out := PackedByteArray()
	out.resize(n * n)
	out.fill(0)
	for br in bridges:
		if quays and not (br.size() > 3 and br[3] == "quay"):
			continue
		var a: Vector3 = br[0]
		var b: Vector3 = br[1]
		# (the deck runs 2% past each end, and its sides lie within its half width)
		var r := float(br[2]) + pad + 1.0 + 0.03 * Defs.flat(b - a).length()
		for z in range(maxi(0, floori((minf(a.z, b.z) - r + h) * res)), mini(n - 1, ceili((maxf(a.z, b.z) + r + h) * res)) + 1):
			var wz := (z + 0.5) / res - h
			for x in range(maxi(0, floori((minf(a.x, b.x) - r + h) * res)), mini(n - 1, ceili((maxf(a.x, b.x) + r + h) * res)) + 1):
				var wx := (x + 0.5) / res - h
				if out[z * n + x] == 0 and (_quay(wx, wz) if quays else _in_bridge(wx, wz, pad)):
					out[z * n + x] = 1
	return out


func _quay(wx: float, wz: float) -> bool:
	for br in bridges:
		if br.size() > 3 and br[3] == "quay":
			var a: Vector3 = br[0]
			var b: Vector3 = br[1]
			var t := ((wx - a.x) * (b.x - a.x) + (wz - a.z) * (b.z - a.z)) / maxf(Defs.flat(b - a).length_squared(), 0.0001)
			if t >= -0.02 and t <= 1.02 and Defs.dist_point_segment(Vector3(wx, 0, wz), a, b) < float(br[2]) + 0.6:
				return true
	return false


## Height of a bridge deck under p (where there's one), else INF.
func deck_y(p: Vector3) -> float:
	return 0.06 if on_deck(p) else INF


func _in_bridge(wx: float, wz: float, pad := 0.0) -> bool:
	for br in bridges:
		var a: Vector3 = br[0]
		var b: Vector3 = br[1]
		var abx := b.x - a.x
		var abz := b.z - a.z
		var ll := maxf(abx * abx + abz * abz, 0.0001)
		var t := ((wx - a.x) * abx + (wz - a.z) * abz) / ll
		if t < -0.02 or t > 1.02:
			continue
		var dx := wx - a.x - abx * t
		var dz := wz - a.z - abz * t
		if sqrt(dx * dx + dz * dz) < float(br[2]) + pad:
			return true
	return false


## The ground kinds - deep water and shallows, the decks of the bridges - and
## (view) the water's mask: R how deep (0-1 over 3 m), G sand or mud along the
## shore, B the sea (salt, surf) rather than fresh water, A water.
func paint_kinds() -> void:
	var tm = world.terrain
	if tm == null or is_empty():
		return
	var n := MapDims.N
	deck.resize(n * n)
	deck.fill(0)
	_mbytes = PackedByteArray()
	if world.has_view:
		_mbytes.resize(n * n * 4)
	var changed := _pass(1, false, _decks(1, 0.0), _decks(1, 0.6, true))
	# the cells whose kind changed: their cover and routes, from what they are now
	tm.refresh_cells(changed)
	if world.has_view:
		mask = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, _mbytes)
	_mbytes = PackedByteArray()
	version += 1


## The riverbeds, the sea floor and the banks, carved into the ground heights.
func carve() -> void:
	var tm = world.terrain
	if tm == null or is_empty():
		return
	var changed := _pass(TerrainMap.DRES, true, _decks(TerrainMap.DRES, 0.6), PackedByteArray())
	var img: Image = tm.deform_img
	if img:
		# (view) the heights' texture, where they were lowered
		var dh: PackedFloat32Array = tm.dh
		for i in changed:
			img.set_pixel(i % TerrainMap.DN, i / TerrainMap.DN, Color(dh[i], world.terrain.landform.height(Vector3((i % TerrainMap.DN + 0.5) / TerrainMap.DRES - MapDims.HALF, 0, (i / TerrainMap.DN + 0.5) / TerrainMap.DRES - MapDims.HALF)), 0))
	if img:
		tm.deform_dirty.clear()
		tm.deform_dirty.append(Rect2i(0, 0, TerrainMap.DN, TerrainMap.DN))
	version += 1


# --- queries -------------------------------------------------------------------------------

## Water a man would have to swim (a boat's water).
func deep_at(p: Vector3) -> bool:
	return world.terrain.base[world.terrain.idx_of(p)] == TerrainMap.WATER


## Any water here (deep or shallow).
func wet_at(p: Vector3) -> bool:
	var b: int = world.terrain.base[world.terrain.idx_of(p)]
	return b == TerrainMap.WATER or b == TerrainMap.SHALLOW


func on_deck(p: Vector3) -> bool:
	return not deck.is_empty() and deck[world.terrain.idx_of(p)] == 1


func on_deck_i(i: int) -> bool:
	return not deck.is_empty() and deck[i] == 1
