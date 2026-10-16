class_name Fires
extends RefCounted
## Fire (server). Whatever is made of wood, cloth or fuel can catch alight:
## trees and hedges, crates, watchtowers, log dugouts, tents and plank huts,
## the timbers of a pitched roof, cars. A shell or a bomb sets them going (the
## bigger the blast and the closer, the likelier), and a vehicle brewing up
## burns where it died. A fire takes a few seconds to get hold, roars, then
## dies down as the fuel runs out. While it roars it throws heat and sparks at
## whatever will burn close by, far more readily downwind than up, so a
## hedgerow or a wood can go up one tree after another. A heavy round on grass
## or in the woods' undergrowth can start a grass fire that creeps off
## downwind for a while and burns itself out.
##
## What burns is charred and weakened, and in the end burns away: a tree is
## left a black snag, a car a burnt-out shell, a hedge, a crate stack or a
## roof falls in as ash. Rain damps it all down. Men caught too close get
## burnt and get back out of the heat, and nobody picks a burning wall for
## cover (see hot_at).
##
## Clients see each fire through its structure's replicated `burn` (see
## Structure.write_state) and the grass fires as effect events (Fx.FIRE).

## The way the wind blows (smoke leans the same way, see Vfx).
const WIND := Vector3(0.92, 0.0, 0.38)

## What burns: [how readily it catches (0..1), seconds it burns at full blaze,
## what's left: "snag" (a charred tree), "shell" (a burnt-out car), "ash"
## (nothing) or "stands" (still standing, the worse for it), how thick a pall
## of smoke it lays downwind at full blaze (its radius in metres)].
const FUEL := {
	"tree": [0.35, 80.0, "snag", 2.5],
	"hedge": [0.6, 45.0, "ash", 2.0],
	"crates": [0.75, 40.0, "ash", 1.8],
	"watchtower": [0.55, 60.0, "ash", 2.5],
	"medic_tent": [0.85, 35.0, "ash", 2.5],
	"barracks": [0.22, 70.0, "stands", 3.5],
	"log_bunker": [0.12, 60.0, "stands", 2.5],
	"roof": [0.3, 75.0, "ash", 4.0],
	"car": [0.45, 55.0, "shell", 3.0],
	"wreck": [0.0, 40.0, "shell", 3.5],  # a vehicle brewing up: lit as it's made, never relit
	"camo_net": [0.9, 16.0, "ash", 1.5],  # a net of dry scrim goes up in a flash
	"barricade": [0.3, 90.0, "stands", 4.0],  # tyres and pallets: slow to catch, they smoulder black for ages
}
const TICK := 0.25
const CELL := 4.0  # the heat map's cells (m)
const MAX_PATCHES := 36

var world
var burning: Array = []  # what's alight: [structure, where the heat was stamped, how far]
var patches: Array = []  # grass fires: [pos, radius, seconds left, generation]
var hot := PackedByteArray()  # per cell: how many fires are close enough to burn a man
## The smoke a fire lays across the ground downwind once it's well alight:
## [centre, radius]. Nobody sees through it (see Combat.smoke_blocks).
var smokes: Array = []
var wet := false  # raining: fires catch less, spread less and burn lower
var _hn := 0
var _t := 0.0
var _beat := 0.0


func _init(w) -> void:
	world = w
	_hn = int(ceil(MapDims.SIZE / CELL)) + 1
	hot.resize(_hn * _hn)
	wet = Atmosphere.pick_mood(w.settings) == "rain"


## Sets st alight, if it will burn and isn't burning already. heat: how hard
## it starts (0..1); it takes hold from there.
func ignite(st: Structure, heat := 0.15) -> bool:
	if st == null or st.gone or st.burn > 0.0 or st.burnt:
		return false
	var k := st.fire_kind()
	if k == "":
		return false
	var spec: Array = FUEL[k]
	st.fire_k = k
	st.fuel_max = float(spec[1]) * world.rng.randf_range(0.8, 1.2)
	st.fuel = st.fuel_max
	st.set_burn(clampf(heat, 0.1, 1.0))
	burning.append([st, st.position, st.radius + 2.5])
	_stamp(st.position, st.radius + 2.5, 1)
	world.stat("fire_" + k)
	if st.team >= 0 and st.is_player_building():
		world.send_msg(st.team, "alert", "%s is on fire at %s! Engineers can put it out." % [st.display_name(), Defs.grid_ref(st.position)], st.position)
	return true


## A blast at p (size as Fx.EXPLODE, r its radius): the flash and the burning
## fragments may set alight what's close, and a heavy round on open grass or
## in the woods may start a grass fire.
func blast(p: Vector3, size: float, r: float) -> void:
	var k := clampf((size - 0.6) / 1.6, 0.0, 1.0)  # a grenade 0.25, a mortar bomb 0.4-0.6, a shell or a bomb ~1
	if k <= 0.0:
		return
	if wet:
		k *= 0.3
	for st in world.structures_near(p, r + 3.0):
		if st.gone or st.burn > 0.0 or st.burnt:
			continue
		var fk: String = st.fire_kind()
		if fk == "":
			continue
		var d := box_dist(st, p)
		if d > r:
			continue
		var chance := float(FUEL[fk][0]) * (0.15 + 0.85 * k) * (1.0 - d / r)
		if world.rng.randf() < chance:
			ignite(st, 0.2 + 0.4 * k)
	if p.y < 1.6 and not wet and size >= 1.15:
		var woods: bool = world.terrain.woods[world.terrain.idx_of(p)] > 0
		if world.rng.randf() < 0.28 * k * (1.6 if woods else 1.0) and _grass_at(p):
			start_patch(p, world.rng.randf_range(1.6, 2.4) + size * 0.5, world.rng.randf_range(14.0, 24.0), 0)
			world.stat("grass_fire_lit")


## A grass fire at p, r across, burning for `life` seconds.
func start_patch(p: Vector3, r: float, life: float, gen: int) -> void:
	var at := Vector3(p.x, 0.0, p.z)
	patches.append([at, r, life, gen])
	_stamp(at, r + 1.0, 1)
	world.fx_event([Fx.FIRE, at, r, life])
	world.stat("grass_fire")


## Is there a fire close enough to p to burn a man standing there?
func hot_at(p: Vector3) -> bool:
	var cx := int((p.x + MapDims.HALF) / CELL)
	var cz := int((p.z + MapDims.HALF) / CELL)
	if cx < 0 or cz < 0 or cx >= _hn or cz >= _hn:
		return false
	return hot[cz * _hn + cx] > 0


## How far p is from st's footprint (0 inside it).
static func box_dist(st: Structure, p: Vector3) -> float:
	var l := Basis(Vector3.UP, -st.yaw) * (p - st.position)
	var dx := maxf(absf(l.x) - st.foot.x, 0.0)
	var dz := maxf(absf(l.z) - st.foot.y, 0.0)
	return sqrt(dx * dx + dz * dz)


func tick(dt: float) -> void:
	_t += dt
	if _t < TICK:
		return
	var step := _t
	_t = 0.0
	# heat and sparks are reckoned once a second
	_beat -= step
	var beat := _beat <= 0.0
	if beat:
		_beat = 1.0
	for i in range(burning.size() - 1, -1, -1):
		var bt: Array = burning[i]
		var st: Structure = bt[0]
		if not st.gone:
			_burn(st, step, beat)
		if st.gone or st.burn <= 0.0:
			burning.remove_at(i)
			_stamp(bt[1], bt[2], -1)
	for i in range(patches.size() - 1, -1, -1):
		var pt: Array = patches[i]
		pt[2] = float(pt[2]) - step
		if float(pt[2]) <= 0.0:
			patches.remove_at(i)
			_stamp(pt[0], float(pt[1]) + 1.0, -1)
		elif beat:
			_patch_beat(pt)
	smokes.clear()
	for bt in burning:
		var bs: Structure = bt[0]
		var pall := float(FUEL[bs.fire_k][3]) * bs.burn
		if bs.burn > 0.45 and pall > 1.2:
			smokes.append([bs.position + WIND * pall * 1.3 + Vector3(0, 1.4, 0), pall])
	for pt in patches:
		var pr := float(pt[1]) * 0.9 * clampf(float(pt[2]) / 4.0, 0.3, 1.0)
		smokes.append([(pt[0] as Vector3) + WIND * pr + Vector3(0, 1.2, 0), pr])


func _burn(st: Structure, dt: float, beat: bool) -> void:
	var spec: Array = FUEL[st.fire_k]
	var flam := float(spec[0])
	var left := st.fuel / maxf(st.fuel_max, 1.0)
	# it takes hold over several seconds, roars, then dies down to embers as
	# the last of the fuel goes
	var want := 1.0 if left > 0.3 else 0.08 + 0.92 * left / 0.3
	if wet:
		want *= 0.6
	var b := st.burn
	b = move_toward(b, want, dt * ((0.07 + 0.1 * flam) if b < want else 0.3))
	st.fuel -= dt * b
	# the fire eats it: what burns away is gone about when the fuel is, a snag
	# or a shell is left standing with what the fire didn't take
	var eat := dt * b / maxf(st.fuel_max, 1.0)
	match String(spec[2]):
		"ash":
			st.hp -= st.max_hp * eat * 1.05
		"stands":
			st.hp -= st.max_hp * eat * 0.45
		_:
			if st.fire_k != "wreck":  # (a hulk's armour isn't what's burning)
				st.hp = maxf(minf(st.hp, st.max_hp * 0.3), st.hp - st.max_hp * eat * 0.7)
	st.net_dirty = true
	if st.hp <= 0.0:
		st.hp = 0.0
		st.set_burn(0.0)
		st.burned_down()
		return
	if st.fuel <= 0.0:
		st.set_burn(0.0)
		if String(spec[2]) in ["snag", "shell"]:
			st.char_out()
		return
	st.set_burn(b)
	if beat:
		if b > 0.25:
			_scorch(st.position, b, func(p): return box_dist(st, p), st.radius + 3.0, 1.0 + 1.2 * b, st.fire_k == "roof")
		if b > 0.45:
			_spread(st, b)


## Heat and sparks off a fire at full blaze: whatever will burn nearby may
## catch, much more readily downwind.
func _spread(st: Structure, b: float) -> void:
	var reach := 2.0 + 3.0 * b + (1.5 if st.fire_k in ["roof", "watchtower", "tree"] else 0.0)
	for o in world.structures_near(st.position, reach + st.radius + 6.0):
		if o == st or o.gone or o.burn > 0.0 or o.burnt:
			continue
		var k: String = o.fire_kind()
		if k == "" or float(FUEL[k][0]) <= 0.0:
			continue
		var d := maxf(box_dist(o, st.position) - st.radius * 0.5, 0.0)
		if d > reach:
			continue
		var dir := Defs.flat(o.position - st.position).normalized()
		var p := 0.1 * float(FUEL[k][0]) * b * (1.0 - d / reach) * (1.0 + 0.9 * dir.dot(WIND))
		if wet:
			p *= 0.25
		if world.rng.randf() < p:
			ignite(o, 0.15)


## A grass fire, once a second: it sets alight what stands in it, burns the
## men in it and may creep on downwind.
func _patch_beat(pt: Array) -> void:
	var c: Vector3 = pt[0]
	var r: float = pt[1]
	var life: float = pt[2]
	var b := clampf(life / 4.0, 0.2, 1.0)  # (it dies down at the end)
	_scorch(c, b, func(p): return maxf(Defs.flat(p - c).length() - r * 0.8, 0.0), r + 2.0, 1.0, false)
	for st in world.structures_near(c, r + 4.0):
		if st.gone or st.burn > 0.0 or st.burnt:
			continue
		var fk: String = st.fire_kind()
		if fk != "" and box_dist(st, c) < r + 0.8 and world.rng.randf() < 0.12 * float(FUEL[fk][0]):
			ignite(st, 0.15)
	if int(pt[3]) >= 2 or patches.size() >= MAX_PATCHES or life < 5.0 or world.rng.randf() > 0.05:
		return
	# the grass downwind catches (a strike's fire creeps on a way, then dies out:
	# about one more patch for each a shell starts)
	var dir := Basis(Vector3.UP, world.rng.randf_range(-1.1, 1.1)) * WIND
	var np: Vector3 = c + dir * r * world.rng.randf_range(1.3, 1.8)
	if not Defs.in_map(np, 6.0) or not _grass_at(np):
		return
	for o in patches:
		if Defs.flat((o[0] as Vector3) - np).length() < float(o[1]) * 1.1:
			return
	start_patch(np, r * world.rng.randf_range(0.85, 1.05), world.rng.randf_range(12.0, 20.0), int(pt[3]) + 1)
	world.stat("grass_fire_spread")


## Burns the men within `r` of a fire (dist_fn: how far a point is from it)
## and sends them back out of the heat. A roof fire burns whoever's in the
## house under it.
func _scorch(c: Vector3, b: float, dist_fn: Callable, near: float, r: float, roof: bool) -> void:
	for s in world.soldiers_near(c, near + r):
		if s.life == Soldier.Life.DEAD or s.life == Soldier.Life.HIDDEN:
			continue
		var d: float = dist_fn.call(s.position)
		if d > r:
			continue
		var k := 1.0 - d / r
		if OS.has_environment("FL_DEBUG_FIRE"):
			print("FIRE burns %s life=%d task=%s act=%d mounted=%s d=%.1f hp=%.0f" % [s.sname, s.life, s.task, s.act, str(s.mounted != null), d, s.hp])
		s.take_damage((3.0 + 12.0 * k) * b * (0.6 if roof else 1.0), null, Defs.flat(s.position - c).normalized(), "fire")
		s.flee_fire(c)
		world.stat("fire_burns")


## Plain grass or the woods (not a road, the town's paving, mud, water or a trench).
func _grass_at(p: Vector3) -> bool:
	if not Defs.in_map(p, 2.0) or world.town_rect.has_point(Vector2(p.x, p.z)):
		return false
	var tm: TerrainMap = world.terrain
	var i := tm.idx_of(p)
	if tm.trench[i] > 0 or tm.solid[i] > 0:
		return false
	if world.water and not world.water.is_empty() and world.water.wet_at(p):
		return false
	return tm.base[i] == TerrainMap.GROUND or tm.base[i] == TerrainMap.WOODS


## Marks (d = 1) or clears (d = -1) the ground a fire makes too hot to stand
## on: no cover is taken there, and routes go round it (Nav.stamp_heat).
func _stamp(p: Vector3, r: float, d: int) -> void:
	world.nav.stamp_heat(p, r - 0.5, d)
	var x0 := maxi(0, int((p.x - r + MapDims.HALF) / CELL))
	var x1 := mini(_hn - 1, int((p.x + r + MapDims.HALF) / CELL))
	var z0 := maxi(0, int((p.z - r + MapDims.HALF) / CELL))
	var z1 := mini(_hn - 1, int((p.z + r + MapDims.HALF) / CELL))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * _hn + x
			hot[i] = clampi(hot[i] + d, 0, 255)
