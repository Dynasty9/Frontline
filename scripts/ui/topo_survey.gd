class_name TopoSurvey
## The living map's ground worked out again on the CPU, hash for hash and octave
## for octave as TopoBackdrop's shader draws it, so it can be lettered like a
## survey sheet: heights written along the index contours and spot heights on
## the summits. The ground drifts so slowly that a fresh survey every half
## second (on a worker thread) keeps the figures on their lines.
##
## Ground positions are in screen heights across the whole sheet. The view pans
## slowly over it (TopoBackdrop's camera), so a position's place on the screen
## is the position less the camera, before the loading screen zooms it or the
## cursor leans it.

## The ground's shape and drift: the shader is built from these, so the two
## can't drift apart.
const SCALE := 4.2  # noise units per screen height: how far out the map is
const LEVELS := 20.0  # contour levels per unit of height
const ROUGH := 0.45  # each finer fold of the ground this much of the one before
const CREASED := 1  # the coarsest folds cut into valleys (V-shaped, as streams cut them)
const CREASE := 1.0  # and how sharply
const CREEP := 0.016  # levels a second: the lines slide down the slopes
const WARP := Vector2(0.004, 0.0033)  # how fast the two folds of the ground turn over
const DRIFT := Vector2(0.0022, -0.0015)  # and the ground slides under them
const TILT := Vector2(0.055, -0.03)  # the lie of the land: it climbs gently toward the top right
const INTERVAL := 10  # metres between contours, for the figures
const DATUM := 300  # metres at level 0

const STEP := 0.05  # the survey's sample spacing (screen heights)
const EDGE := 0.06  # figures keep this far inside the screen
const FIGS := 9  # contour figures at most
const PER_LEVEL := 3  # and on any one contour, so several heights are lettered
const SPOTS := 5  # spot heights at most
const APART := 0.2  # no two marks closer than this
const NEAR := 1.0 / 1080.0  # a 1080p pixel, in screen heights

const M32 := 0xFFFFFFFF
const TO_UNIT := 2.0 / 4294967295.0

## Gradients at the lattice's corners, worked out once each. Only ever touched
## by one survey at a time (the first on the main thread, then one worker job
## after another), never by two at once. As the view pans on, the corners it
## has left behind are let go now and then.
static var _grad := {}
const GRAD_KEEP := 200000


## The shader's hash, a pcg2d on the corner's integer coordinates, so the CPU
## gets exactly the gradients the GPU does.
static func _corner(ix: int, iy: int) -> Vector2:
	var key := ((ix & 0xFFFF) << 16) | (iy & 0xFFFF)
	var g: Variant = _grad.get(key)
	if g != null:
		return g
	var x := ix & M32
	var y := iy & M32
	x = (x * 1664525 + 1013904223) & M32
	y = (y * 1664525 + 1013904223) & M32
	x = (x + y * 1664525) & M32
	y = (y + x * 1664525) & M32
	x ^= x >> 16
	y ^= y >> 16
	x = (x + y * 1664525) & M32
	y = (y + x * 1664525) & M32
	x ^= x >> 16
	y ^= y >> 16
	var v := Vector2(x * TO_UNIT - 1.0, y * TO_UNIT - 1.0)
	_grad[key] = v
	return v


static func _noise(x: float, y: float) -> float:
	var fx0 := floorf(x)
	var fy0 := floorf(y)
	var fx := x - fx0
	var fy := y - fy0
	var ux := fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0)
	var uy := fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0)
	var ix := int(fx0)
	var iy := int(fy0)
	var a := _corner(ix, iy)
	var b := _corner(ix + 1, iy)
	var c := _corner(ix, iy + 1)
	var d := _corner(ix + 1, iy + 1)
	var na := a.x * fx + a.y * fy
	var nb := b.x * (fx - 1.0) + b.y * fy
	var nc := c.x * fx + c.y * (fy - 1.0)
	var nd := d.x * (fx - 1.0) + d.y * (fy - 1.0)
	return lerpf(lerpf(na, nb, ux), lerpf(nc, nd, ux), uy)


static func _fbm3(x: float, y: float) -> float:
	var s := 0.5 * _noise(x, y)
	var nx := 1.6 * x - 1.2 * y + 1.7
	var ny := 1.2 * x + 1.6 * y + 9.2
	s += 0.25 * _noise(nx, ny)
	x = 1.6 * nx - 1.2 * ny + 8.3
	y = 1.2 * nx + 1.6 * ny + 2.8
	return s + 0.125 * _noise(x, y)


static func _fbm5(x: float, y: float) -> float:
	var s := 0.0
	var a := 0.5
	for i in 5:
		var n := _noise(x, y)
		if i < CREASED:
			n = lerpf(n, sqrt(n * n + 0.002) - 0.22, CREASE)
		s += a * n
		var nx := 1.6 * x - 1.2 * y + 3.1
		y = 1.2 * x + 1.6 * y + 7.7
		x = nx
		a *= ROUGH
	return s


## The ground's height at a ground position, at clock t (as the shader's ground()).
static func height(g: Vector2, t: float) -> float:
	var qx := g.x * SCALE
	var qy := g.y * SCALE
	var wx := _fbm3(qx * 0.6, qy * 0.6 + t * WARP.x)
	var wy := _fbm3(qx * 0.6 + 5.2 - t * WARP.y, qy * 0.6 + 1.3)
	return _fbm5(qx + wx * 1.1 + t * DRIFT.x, qy + wy * 1.1 + t * DRIFT.y) + qx * TILT.x + qy * TILT.y


## The contour level there (fractional: lines fall on whole numbers).
static func level(g: Vector2, t: float) -> float:
	return height(g, t) * LEVELS + t * CREEP


static func metres(lv: float) -> int:
	return DATUM + roundi(lv * INTERVAL)


## The level's gradient (levels per screen height).
static func _slope(g: Vector2, lv: float, t: float) -> Vector2:
	var e := 0.0015
	return Vector2(level(g + Vector2(e, 0.0), t) - lv, level(g + Vector2(0.0, e), t) - lv) / e


## The figure's angle along the contour, kept upright.
static func _upright(grad: Vector2) -> float:
	var a := atan2(grad.x, -grad.y)  # along the line, not up it
	if a > PI * 0.5:
		a -= PI
	elif a <= -PI * 0.5:
		a += PI
	return a


## A point on level k near g, and the line's angle there; empty if the line
## there is too steep, too gentle or too bent to letter.
static func _on_contour(g: Vector2, k: int, t: float) -> Array:
	var lv := level(g, t)
	var grad := Vector2.ZERO
	for i in 2:
		grad = _slope(g, lv, t)
		var gg := grad.length_squared()
		if gg < 1e-6:
			return []
		g -= grad * ((lv - k) / gg)
		lv = level(g, t)
	var gap := 1.0 / maxf(grad.length(), 1e-6) / NEAR  # pixels (1080p) to the next line
	if gap < 12.0 or gap > 120.0 or absf(lv - k) * gap > 1.0:
		return []
	var ang := _upright(grad)
	if absf(ang) > 1.3:
		return []  # nearly upright: it would flip as it turned
	# straight enough under the figure: the line stays within 3 px of it at its ends
	var along := Vector2(cos(ang), sin(ang)) * 0.013
	for s in [-1.0, 1.0]:
		if absf(level(g + along * s, t) - k) * gap > 3.0:
			return []
	return [g, ang]


## Climb to the top of the hill near g (shrinking steps); the summit and its
## level, or empty if it runs off somewhere else.
static func _summit(g: Vector2, lv: float, t: float, r: float) -> Array:
	var start := g
	while r > 0.0012:
		var moved := false
		for d in [Vector2(r, 0.0), Vector2(-r, 0.0), Vector2(0.0, r), Vector2(0.0, -r)]:
			var l2 := level(g + d, t)
			if l2 > lv:
				lv = l2
				g += d
				moved = true
				break
		if not moved:
			r *= 0.5
	if g.distance_to(start) > 0.05:
		return []
	return [g, lv]


static func _clear(g: Vector2, taken: Array) -> bool:
	for o in taken:
		if g.distance_to(o) < APART:
			return false
	return true


static func _inside(g: Vector2, aspect: float, centre: Vector2) -> bool:
	return absf(g.x - centre.x) < aspect * 0.5 - EDGE and absf(g.y - centre.y) < 0.5 - EDGE


## One survey at clock t over a screen of that aspect, the view's centre at
## `centre` on the sheet. The marks already on the map ([id, spot, ground
## position, level]) are carried along if they're still on it, and new ones
## fill the gaps (the ground coming into view). Returns [id (-1: new), spot,
## ground position, angle, level, text] for each.
static func survey(t: float, aspect: float, centre: Vector2, old: Array) -> Array:
	if _grad.size() > GRAD_KEEP:
		_grad.clear()
	var out: Array = []
	var taken: Array = []
	# what's already lettered, moved with the ground
	for o in old:
		var id: int = o[0]
		var at: Vector2 = o[2]
		if o[1]:
			var s := _summit(at, level(at, t), t, 0.01)
			if not s.is_empty() and _inside(s[0], aspect, centre) and _clear(s[0], taken):
				out.append([id, true, s[0], 0.0, roundi(s[1]), str(metres(s[1]))])
				taken.append(s[0])
		else:
			var k: int = o[3]
			var c := _on_contour(at, k, t)
			if not c.is_empty() and _inside(c[0], aspect, centre) and _clear(c[0], taken) and (c[0] as Vector2).distance_to(at) < 0.03:
				out.append([id, false, c[0], c[1], k, str(DATUM + k * INTERVAL)])
				taken.append(c[0])
	# sample the ground
	var cols := int(ceil(aspect / STEP)) + 1
	var rows := int(ceil(1.0 / STEP)) + 1
	var x0 := centre.x - float(cols - 1) * STEP * 0.5
	var y0 := centre.y - float(rows - 1) * STEP * 0.5
	var lv := PackedFloat32Array()
	lv.resize(cols * rows)
	for r in rows:
		for c in cols:
			lv[r * cols + c] = level(Vector2(x0 + c * STEP, y0 + r * STEP), t)
	var figs := 0
	var spots := 0
	var on_level := {}
	for m in out:
		if m[1]:
			spots += 1
		else:
			figs += 1
			on_level[m[4]] = int(on_level.get(m[4], 0)) + 1
	# index contours (every fifth level) crossing between neighbouring samples,
	# best first where the slope is even; they come before the spot heights, as
	# on a printed sheet, where the contours carry most of the figures
	if figs < FIGS:
		var cand: Array = []
		for r in rows:
			for c in cols:
				var a := lv[r * cols + c]
				for nb in [[0, 1], [1, 0]]:
					var r2: int = r + nb[0]
					var c2: int = c + nb[1]
					if r2 >= rows or c2 >= cols:
						continue
					var b := lv[r2 * cols + c2]
					var k := int(ceil(minf(a, b) / 5.0)) * 5
					if float(k) > maxf(a, b) or is_equal_approx(a, b):
						continue
					var f := (k - a) / (b - a)
					var g := Vector2(x0 + (c + nb[1] * f) * STEP, y0 + (r + nb[0] * f) * STEP)
					if not _inside(g, aspect, centre):
						continue
					# an even slope, judged by how far apart the neighbours say the lines are
					var gap := STEP / maxf(absf(b - a), 1e-4) / NEAR
					cand.append([absf(gap - 24.0), g, k])
		cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var tries := 0
		for cd in cand:
			if figs >= FIGS or tries >= 90:
				break
			if not _clear(cd[1], taken) or int(on_level.get(cd[2], 0)) >= PER_LEVEL:
				continue
			tries += 1
			var c := _on_contour(cd[1], cd[2], t)
			if c.is_empty() or not _inside(c[0], aspect, centre) or not _clear(c[0], taken):
				continue
			out.append([-1, false, c[0], c[1], cd[2], str(DATUM + int(cd[2]) * INTERVAL)])
			taken.append(c[0])
			figs += 1
			on_level[cd[2]] = int(on_level.get(cd[2], 0)) + 1
	# summits: samples higher than all eight round them, highest first
	if spots < SPOTS:
		var peaks: Array = []
		for r in range(1, rows - 1):
			for c in range(1, cols - 1):
				var v := lv[r * cols + c]
				var top := true
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if (dr != 0 or dc != 0) and lv[(r + dr) * cols + c + dc] >= v:
							top = false
				if top:
					peaks.append([v, Vector2(x0 + c * STEP, y0 + r * STEP)])
		peaks.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for pk in peaks:
			if spots >= SPOTS:
				break
			if not _clear(pk[1], taken):
				continue
			var s := _summit(pk[1], pk[0], t, STEP * 0.4)
			if s.is_empty() or not _inside(s[0], aspect, centre) or not _clear(s[0], taken):
				continue
			out.append([-1, true, s[0], 0.0, roundi(s[1]), str(metres(s[1]))])
			taken.append(s[0])
			spots += 1
	return out
