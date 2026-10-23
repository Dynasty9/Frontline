class_name Cover
extends RefCounted
## Fighting positions. Everything solid a man can get behind is turned into
## anchors along its faces: where he stands, which way he faces, how high the
## barrier is at that spot, what it's made of, and how he fights from it -
## over the top (prone behind a low lip, kneeling behind sandbags or a car,
## standing behind a chest-high wall or a trench parapet), round the edge of
## something too tall to see over, or only sheltering behind it.
##
## Built from the structure's parts on every peer, so the move preview shows
## the spots the server will put the men in. What the barrier is made of
## decides what it's worth: a hedge hides you but bullets go straight through
## it; a car or a house wall stops a rifle but not a machine gun; sandbags,
## concrete and earth stop everything short of a heavy machine gun, and a
## trench, a bunker or a HESCO wall stops that too.

enum {OVER = 1, EDGE_L = 2, EDGE_R = 3, SHELTER = 4, STACK = 5}
enum {SOFT, MEDIUM, HARD, FORT}
enum {PRONE, KNEEL, STAND, TALL}

const MAT_NAMES := ["Soft cover", "Medium cover", "Hard cover", "Fortified"]
const MAT_STOPS := ["Hides you; bullets go through it", "Stops rifles, not machine guns", "Stops everything short of a heavy MG", "Stops everything"]
const STANCE_NAMES := ["fire prone over it", "fire kneeling over it", "fire standing over it", "fire round its edges"]
const PRONE_MAX := 0.62  # below this he lies behind it
const KNEEL_MAX := 1.12  # below this he kneels behind it
const STAND_MAX := 1.55  # below this he stands behind it; above, it's too tall to see over
const SPACING := 1.25  # a man's width and a bit between fighting positions
const TRENCH_H := 0.34 - (TrenchNet.FLOOR_Y + 0.15)  # parapet over the duckboards
# chance a round goes through, by material and by the weapon's penetration
# (pistol and SMG / rifle / machine gun / heavy machine gun and cannon)
const PASS := [[0.5, 0.75, 0.9, 1.0], [0.0, 0.08, 0.3, 0.75], [0.0, 0.0, 0.0, 0.15], [0.0, 0.0, 0.0, 0.0]]
const PASS_DMG := [0.7, 0.55, 0.45, 0.0]  # what's left of the round on the other side
const BLAST := [0.8, 0.45, 0.25, 0.2]  # share of a blast that gets round or through
const SUPP := [0.85, 0.62, 0.4, 0.35]  # how much near misses still rattle him behind it
# down behind solid cover he gathers himself even with rounds smacking into
# it: a machine gun can still pin him there (that's what it's for), but it
# can't paralyse him - he'll come up again the moment the fire slackens
const SUPP_CAP := [100.0, 86.0, 68.0, 62.0]


static func stance(h: float) -> int:
	if h < PRONE_MAX:
		return PRONE
	if h < KNEEL_MAX:
		return KNEEL
	if h <= STAND_MAX:
		return STAND
	return TALL


## How far from the face of the barrier he stands: his chest to it standing
## or kneeling (the forward knee needs a little room); lying, his head is at
## it and his body stretches back.
static func offset(h: float) -> float:
	match stance(h):
		PRONE:
			return 1.02
		KNEEL:
			return 0.56
	return 0.46


## The weapon's penetration class: 0 pistol / SMG, 1 rifle, 2 machine gun,
## 3 heavy machine gun or cannon.
static func pen_class(w: Dictionary) -> int:
	var snd := String(w.get("snd", "rifle"))
	if w.get("ap", false) or snd == "hmg":
		return 3
	if snd in ["mg", "minigun"]:
		return 2
	if snd == "rifle":
		return 1
	return 0


static func mat_of(st) -> int:
	match String(st.skind):
		"low_wall":
			return SOFT if st.variant % 3 == 1 else HARD  # a hedge, or stone / brick
		"crates":
			return SOFT if st.variant == 0 else MEDIUM
		"medic_tent", "watchtower":
			return SOFT
		"car", "house_wall", "barracks", "research", "depot", "factory", "tree", "town":
			return MEDIUM
		"trench", "bunker", "fob", "hesco":
			return FORT
		"ammo_cache":
			return MEDIUM
	return HARD


## Fills st.anc_* with the fighting positions round its parts.
static func build(st) -> void:
	st.anc_p = PackedVector3Array()
	st.anc_n = PackedVector3Array()
	st.anc_h = PackedFloat32Array()
	st.anc_k = PackedByteArray()
	if st.skind in ["floor", "roof", "wire", "mines", "tank_trap", "tunnel", "helipad", "tree", "camo_net"]:
		return
	if st.skind == "trench":
		_trench(st)
		return
	var b := Basis(Vector3.UP, st.yaw)
	for p in st.parts:
		if not p.cover or not p.col:
			continue
		var s: Vector3 = p.s
		var bottom: float = p.p.y - s.y * 0.5
		var top: float = p.p.y + s.y * 0.5
		if bottom > 0.5 or top < 0.3:
			continue  # a lintel, or nothing to get behind
		if st.skind == "low_wall" and st.variant % 3 != 1:
			top += 0.08  # the coping stones along the top
		var stn := stance(top)
		var pr := Basis(Vector3.UP, p.r)
		var base := Vector3(p.p.x, 0, p.p.z)
		for side in 4:
			# the face's outward normal, the direction along it, its half length
			# and how far the face is from the part's middle
			var nl: Vector3
			var tl: Vector3
			var hl: float
			var hd: float
			match side:
				0:
					nl = Vector3(0, 0, -1)
					tl = Vector3(1, 0, 0)
					hl = s.x * 0.5
					hd = s.z * 0.5
				1:
					nl = Vector3(0, 0, 1)
					tl = Vector3(-1, 0, 0)
					hl = s.x * 0.5
					hd = s.z * 0.5
				2:
					nl = Vector3(-1, 0, 0)
					tl = Vector3(0, 0, -1)
					hl = s.z * 0.5
					hd = s.x * 0.5
				_:
					nl = Vector3(1, 0, 0)
					tl = Vector3(0, 0, 1)
					hl = s.z * 0.5
					hd = s.x * 0.5
			if hl < 0.4:
				continue  # the end of a thin wall: nothing to stand behind
			# he stands on the nl side and fires across the barrier: -nl
			var wn: Vector3 = (b * pr * -nl).normalized()
			var wt: Vector3 = (b * pr * tl).normalized()
			if stn == TALL:
				var off := 0.5
				for sg in [-1.0, 1.0]:
					# just inside each end: lean out round it
					var lp: Vector3 = base + pr * (nl * (hd + off) + tl * sg * maxf(0.0, hl - 0.35))
					var kind := EDGE_R if wn.cross(Vector3.UP).dot(wt * sg) > 0.0 else EDGE_L
					_add(st, st.position + b * lp, wn, top, kind)
				# and sheltered spots between them
				var ns := int((hl * 2.0 - 1.6) / 1.6)
				for k in ns:
					var t := ((float(k) + 0.5) / ns - 0.5) * (hl * 2.0 - 1.6)
					_add(st, st.position + b * (base + pr * (nl * (hd + off) + tl * t)), wn, top, SHELTER)
				# Overflow men shelter a pace behind the front row, inside the wall's ends.
				for k in ns:
					var t := ((float(k) + 0.5) / ns - 0.5) * (hl * 2.0 - 1.6)
					_add(st, st.position + b * (base + pr * (nl * (hd + off + 1.5) + tl * t)), wn, top, STACK)
			else:
				var off := offset(top)
				var n := maxi(1, int((hl * 2.0 + 0.2) / SPACING))
				var usable := maxf(0.0, hl * 2.0 - 0.6)
				for k in n:
					var t := ((float(k) + 0.5) / n - 0.5) * usable
					_add(st, st.position + b * (base + pr * (nl * (hd + off) + tl * t)), wn, top, OVER)


static func _add(st, wp: Vector3, n: Vector3, h: float, kind: int) -> void:
	wp.y = 0.0
	if not Defs.in_map(wp, 2.0) or st._inside_any_part(wp):
		return
	st.anc_p.append(wp)
	st.anc_n.append(n)
	st.anc_h.append(h)
	st.anc_k.append(kind)


## Down in a trench a man stands on the fire step against whichever wall
## faces the enemy, rifle over the parapet: a row of positions along each wall.
static func _trench(st) -> void:
	var sg := TrenchNet.seg_of(st)
	var a := Defs.flat(sg[0])
	var ab := Defs.flat(sg[1]) - a
	var L := ab.length()
	if L < 0.5:
		return
	var dir := ab / L
	var side := Vector3(-dir.z, 0, dir.x)
	var n := maxi(1, int(L / SPACING))
	for k in n:
		var c := a + dir * ((float(k) + 0.5) / n * L)
		for s in [-1.0, 1.0]:
			var wp: Vector3 = c + side * s * (TrenchNet.HALF_W - 0.34)
			st.anc_p.append(wp)
			st.anc_n.append(side * s)
			st.anc_h.append(TRENCH_H)
			st.anc_k.append(OVER)


## Can a man get to this spot? Fighting positions sit half a metre off a
## wall, often inside a nav cell padded out by it; the path finishes those
## with a short direct step (see Nav.find_path), so a free cell close by is enough.
static func reachable(world, p: Vector3) -> bool:
	return world.nav.walkable(p) or Defs.flat(world.nav.nearest_walkable(p) - p).length() < 1.6


static func _blocked_near(world, from: Vector3, to: Vector3) -> bool:
	var r: Dictionary = world.combat.ray(from, to)
	return not r.is_empty() and from.distance_to(r.position) < 3.5


## How anchor i of st serves against the threats (enemy eye points): {} if it
## gives no protection from any of them. "fire" is whether he can shoot back
## from it (over the top or round the edge) at at least one of them.
static func evaluate(world, st, i: int, threats: Array, prone := false) -> Dictionary:
	var p: Vector3 = st.anc_p[i]
	var n: Vector3 = st.anc_n[i]
	var h: float = st.anc_h[i]
	var k: int = st.anc_k[i]
	var g: float = world.ground_y(p)
	var stn := stance(h)
	var hide_h := 0.28 if (prone or stn == PRONE or h < 0.8) else (h - 0.2 if stn == KNEEL else 1.0)
	var lean := Vector3.ZERO
	if k == EDGE_R:
		lean = n.cross(Vector3.UP)
	elif k == EDGE_L:
		lean = -n.cross(Vector3.UP)
	var prot := 0
	var fire := 0
	var td := Vector3.ZERO
	for th in threats:
		var to := Defs.flat(th - p)
		if to.length() < 0.5:
			continue
		to = to.normalized()
		td += to
		if n.dot(to) < 0.25:
			continue  # the threat isn't on the far side of it
		if not _blocked_near(world, p + Vector3(0, g + hide_h, 0), th):
			continue
		prot += 1
		var fp := Vector3.INF
		if k == OVER:
			fp = p + n * 0.2 + Vector3(0, g + h + 0.14, 0)
		elif k == EDGE_L or k == EDGE_R:
			fp = p + lean * 0.75 + Vector3(0, g + 1.45, 0)
		if fp != Vector3.INF and world.combat.ray(fp, th).is_empty():
			fire += 1
	if prot == 0:
		return {}
	var typ: int = Soldier.Cov.HIDE
	if k == OVER:
		typ = Soldier.Cov.LOW
	elif (k == EDGE_L or k == EDGE_R) and fire > 0:
		typ = Soldier.Cov.LEAN
	return {"type": typ, "prot": float(prot) / threats.size(), "fire": fire > 0, "lean": lean,
		"tdir": td.normalized() if td.length() > 0.01 else n, "pos": p, "n": n, "h": h,
		"mat": anchor_mat(st, i), "st": st, "ai": i}


static func anchor_mat(st, i: int) -> int:
	# A pace back, less of the man is sheltered from flanks and near misses.
	return maxi(SOFT, mat_of(st) - 1) if st.anc_k[i] == STACK else mat_of(st)


## The best anchor within r of p to fight from against a threat at `from`,
## as [pos, terrain cover level, info] - or [] if none faces that way.
## Shared by the server's formation slots and the client's move preview.
static func best_near(world, p: Vector3, r: float, from: Vector3, taken: Array, group_center := Vector3.INF, group_radius := 0.0) -> Array:
	var best := []
	var bs := -1e9
	for st in world.structures_near(p, r + 2.0):
		if not st.provides_cover():
			continue
		for i in st.anc_p.size():
			var m := anchor_mat(st, i)
			var q: Vector3 = st.anc_p[i]
			var d := Defs.flat(q - p).length()
			if d > r or (group_center != Vector3.INF and not world.terrain.group_spot(q, group_center, group_radius, st.anc_n[i])):
				continue
			var to := Defs.flat(from - q)
			if to.length() < 0.5 or st.anc_n[i].dot(to.normalized()) < 0.3:
				continue
			var k: int = st.anc_k[i]
			var sc: float = [3.5, 5.0, 6.5, 7.0][m] - d * 0.6 + (2.5 if st.skind == "trench" else 0.0)
			if k == SHELTER:
				sc -= 1.5
			elif k == STACK:
				sc -= 2.5
			elif k == OVER and stance(st.anc_h[i]) == PRONE:
				sc -= 0.5
			for t in taken:
				if Defs.flat((t as Vector3) - q).length() < 1.15:
					sc -= 100.0 if group_center != Vector3.INF else 6.0
			if sc > bs:
				bs = sc
				best = [q, sc, {"n": st.anc_n[i], "h": st.anc_h[i], "k": k, "mat": m, "eid": st.eid}]
	return best


## Terrain cover level an anchor counts as on the map's scale.
static func level_of(mat: int) -> int:
	return TerrainMap.HEAVY if mat >= HARD else TerrainMap.LIGHT


static func describe(info: Dictionary) -> String:
	var m: int = info.mat
	var k: int = info.k
	var how: String = STANCE_NAMES[stance(info.h)]
	if k == STACK:
		how = "second row shelter; less protection"
	elif k == SHELTER:
		how = "no line of fire"
	elif k == EDGE_L or k == EDGE_R:
		how = STANCE_NAMES[TALL]
	return "%s  -  %s" % [MAT_NAMES[m], how]
