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


func _pond_r(p: Dictionary, ang: float) -> float:
	var s := float(p.s)
	return float(p.r) * (1.0 + 0.18 * sin(ang * 3.0 + s) + 0.1 * sin(ang * 5.0 + s * 1.7))


## The ground `into` metres in from the waterline (negative: up the bank):
## the bank sloping down to the water, a shelf you can wade, then the deep.
static func _bed(into: float, deep: float, shelf: float, bank: float) -> float:
	if into <= 0.0:
		return lerpf(LEVEL + 0.07, 0.0, clampf(-into / bank, 0.0, 1.0))
	if into < shelf:
		return lerpf(LEVEL - 0.05, WADE - 0.05, into / shelf)
	return lerpf(WADE - 0.05, deep, clampf((into - shelf) / 8.0, 0.0, 1.0))


# --- rasterizing -----------------------------------------------------------------------

var _mode := 0  # 0: kinds and the mask (1 m), 1: carving the ground (DRES per metre)
var _mbytes := PackedByteArray()


## Visits every sample near water on a grid of `res` per metre and writes it
## (see _write): the sea east of the shoreline with a beach behind it, the
## rivers segment by segment, the ponds.
func _visit(res: int) -> void:
	var n := MapDims.N * res
	var h := MapDims.HALF
	if not coast.is_empty():
		var bank := 14.0
		var x_min := float(coast.x) - 36.0 - bank
		for z in n:
			var wz := (z + 0.5) / res - h
			var cx := coast_x(wz)
			for x in range(maxi(0, floori((x_min + h) * res)), n):
				var wx := (x + 0.5) / res - h
				var into := wx - cx
				if into >= -bank:
					_write(z * n + x, x, z, wx, wz, _bed(into, -3.2, 9.0, bank), true, into, bank)
	for r in rivers:
		var pts: PackedVector3Array = r.pts
		var hw: float = float(r.w) * 0.5
		var bank := 5.0
		var reach := hw + bank
		for si in pts.size() - 1:
			var a := pts[si]
			var b := pts[si + 1]
			var x0 := maxi(0, floori((minf(a.x, b.x) - reach + h) * res))
			var x1 := mini(n - 1, ceili((maxf(a.x, b.x) + reach + h) * res))
			var z0 := maxi(0, floori((minf(a.z, b.z) - reach + h) * res))
			var z1 := mini(n - 1, ceili((maxf(a.z, b.z) + reach + h) * res))
			var abx := b.x - a.x
			var abz := b.z - a.z
			var ll := maxf(abx * abx + abz * abz, 0.0001)
			for z in range(z0, z1 + 1):
				var wz := (z + 0.5) / res - h
				for x in range(x0, x1 + 1):
					var wx := (x + 0.5) / res - h
					var t := clampf(((wx - a.x) * abx + (wz - a.z) * abz) / ll, 0.0, 1.0)
					var dx := wx - a.x - abx * t
					var dz := wz - a.z - abz * t
					var into := hw - sqrt(dx * dx + dz * dz)
					if into < -bank:
						continue
					var bed := _bed(into, -2.3, 3.0, bank)
					for f in fords:
						var fd := Vector2(wx - f.x, wz - f.z).length()
						if fd < 10.0:
							bed = maxf(bed, lerpf(-0.8, bed, smoothstep(6.0, 10.0, fd)))
					_write(z * n + x, x, z, wx, wz, bed, false, into, bank)
	for p in ponds:
		var c: Vector3 = p.c
		var bank := 6.0
		var rr := float(p.r) * 1.3 + bank
		for z in range(maxi(0, floori((c.z - rr + h) * res)), mini(n - 1, ceili((c.z + rr + h) * res)) + 1):
			var wz := (z + 0.5) / res - h
			for x in range(maxi(0, floori((c.x - rr + h) * res)), mini(n - 1, ceili((c.x + rr + h) * res)) + 1):
				var wx := (x + 0.5) / res - h
				var rel := Vector2(wx - c.x, wz - c.z)
				var into := _pond_r(p, rel.angle()) - rel.length()
				if into >= -bank:
					_write(z * n + x, x, z, wx, wz, _bed(into, -2.0, 4.0, bank), false, into, bank)


func _write(i: int, x: int, z: int, wx: float, wz: float, bed: float, sea: bool, into: float, bank: float) -> void:
	var tm = world.terrain
	if _mode == 1:
		# the ground heights: only ever lowered, nothing under a bridge
		if bed < tm.dh[i] and not (bed >= LEVEL and _in_bridge(wx, wz, 0.6)):
			tm.dh[i] = bed
			if tm.deform_img:
				tm.deform_img.set_pixel(x, z, Color(bed, 0, 0))
		return
	var on_bridge := bed < LEVEL and _in_bridge(wx, wz)
	var was: int = tm.base[i]
	if on_bridge:
		deck[i] = 1
		if was >= TerrainMap.WATER:
			tm.base[i] = TerrainMap.ROAD
	elif bed < WADE:
		tm.base[i] = TerrainMap.WATER
	elif bed < LEVEL and was != TerrainMap.WATER:
		tm.base[i] = TerrainMap.SHALLOW
	if tm.base[i] != was:
		tm._refresh_cell(i)
	if _mbytes.is_empty() or (on_bridge and _quay(wx, wz)):
		return  # (a quay is solid down to the seabed; a bridge has water under it)
	# the mask: the deepest water, the most shore
	var j := i * 4
	var depth := int(clampf((LEVEL - bed) / 3.0, 0.0, 1.0) * 255.0)
	var shore := 255 if into > 0.0 else int(clampf(1.0 + into / bank, 0.0, 1.0) * 255.0)
	_mbytes[j] = maxi(_mbytes[j], depth)
	_mbytes[j + 1] = maxi(_mbytes[j + 1], shore)
	if sea:
		_mbytes[j + 2] = 255
	if bed < LEVEL:
		_mbytes[j + 3] = 255


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
	_mode = 0
	_visit(1)
	if world.has_view:
		mask = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, _mbytes)
	_mbytes = PackedByteArray()
	version += 1


## The riverbeds, the sea floor and the banks, carved into the ground heights.
func carve() -> void:
	var tm = world.terrain
	if tm == null or is_empty():
		return
	_mode = 1
	_visit(TerrainMap.DRES)
	tm.deform_dirty = Rect2i(0, 0, TerrainMap.DN, TerrainMap.DN)
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
