class_name Vision
extends RefCounted
## What a side can see: every pair of eyes it has on the battlefield, as a
## circle of sight. The host works the fog of war out from them (Rules), and
## each player's game draws the same circles as the fog over the ground and
## the minimap (FogView) from its own side's units, which it always knows.
##
## Men see 56 m (a man up a watchtower further), vehicles what their optics
## give them (Defs "sight"; recon cars and drones far more), a FOB its
## perimeter, a watchtower over the hedges and roofs - further with a lookout
## up it - and aircraft the ground round them as they fly (Projectile.add_eyes).

const DOWNED := 22.0  # a man down still sees what's round him
const VEHICLE := 50.0
const POST := 30.0  # a built position: its sentries
const BASE := 50.0  # a FOB or the HQ: its perimeter
const TOWER := 85.0  # a watchtower: the view over the hedges and roofs
const TOWER_MANNED := 115.0  # with a lookout up it, binoculars
const FPV := 40.0  # an FPV drone's camera on its way in
# a town or village sees its own ground (Structure.zone_r): the townsfolk tell
# whoever holds it who's about


## How far a side's building sees (0: it doesn't - wire, mines, sandbags).
static func structure_sight(st: Structure) -> float:
	match st.skind:
		"fob", "depot":
			return BASE
		"watchtower":
			return TOWER_MANNED if st.manned else TOWER
		"town":
			return st.zone_r
		"mines", "wire", "tank_trap", "sandbags", "trench", "hesco", "barricade", "concrete_wall", "camo_net", "ammo_cache":
			return 0.0
	return POST


## Every eye a side has, as (x, z, radius). A recon flight's pictures (the
## strip it photographed a moment ago) come in as `marks`: (x, z, radius, until).
## `structures`: the side's own buildings, if the caller keeps a list of them
## (null: every structure on the map is looked through).
static func eyes(w: World, team: int, marks: Array = [], structures = null) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in w.soldiers:
		if s.team != team or s.gone:
			continue
		if s.life == Soldier.Life.ALIVE:
			out.append(Vector3(s.position.x, s.position.z, s.sight_range()))
		elif s.life == Soldier.Life.DOWNED:
			out.append(Vector3(s.position.x, s.position.z, DOWNED))
	for v in w.vehicles:
		if v.team == team and not v.gone:
			out.append(Vector3(v.position.x, v.position.z, float(v.vdef.get("sight", VEHICLE))))
	for st in (w.structures if structures == null else structures):
		if st.team != team or st.gone or not st.built:
			continue
		var r := structure_sight(st)
		if r > 0.0:
			var c: Vector3 = st.zone_c if st.skind == "town" else st.position  # (a town: from the middle of its ground)
			out.append(Vector3(c.x, c.z, r))
	for d in w.drones:
		if d.team == team and not d.gone:
			out.append(Vector3(d.position.x, d.position.z, FPV))
	for p in w.projectiles:
		if p.team == team and not p.gone:
			p.add_eyes(out)
	for m in marks:
		out.append(Vector3(m.x, m.y, m.z))
	return out
