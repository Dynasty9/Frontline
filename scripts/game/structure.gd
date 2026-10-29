class_name Structure
extends Entity
## Anything static: map cover (walls, houses, crates, cars, wrecks, trees) and
## player buildings. Every structure is built from box "parts" which give it
## collision (bullets/LOS), nav blocking and the cover points soldiers evaluate.

const C_STONE := Color(0.56, 0.53, 0.48)
const C_CONCRETE := Color(0.5, 0.49, 0.46)  # weathered, not new-white
const C_SAND := Color(0.62, 0.55, 0.38)
const C_WOOD := Color(0.5, 0.36, 0.22)
const C_DIRT := Color(0.36, 0.29, 0.2)
const C_STEEL := Color(0.25, 0.26, 0.27)
const C_OLIVE := Color(0.3, 0.34, 0.22)
const HOUSE_COLORS := [Color(0.72, 0.66, 0.55), Color(0.66, 0.6, 0.52), Color(0.62, 0.5, 0.4), Color(0.75, 0.72, 0.66), Color(0.55, 0.52, 0.47)]
const C_TOWN_FLAG := Color(0.86, 0.8, 0.56)  # a town's own colours, flown while nobody holds it
const CAR_COLORS := [Color(0.5, 0.15, 0.12), Color(0.2, 0.3, 0.45), Color(0.75, 0.72, 0.65), Color(0.3, 0.32, 0.28), Color(0.6, 0.5, 0.2)]
## The small works put up by the dozen: nobody reports them finished or under fire.
const LINE_WORKS := ["trench", "sandbags", "wire", "mines", "tank_trap", "concrete_wall", "hesco", "barricade", "camo_net"]
## How far round an ammo cache men fill their pouches from it, and how much
## is in it (a man topping up draws one a second).
const CACHE_REACH := 7.0
const CACHE_STOCK := 160.0
## Kinds with work in sim(). Include unfinished and neutral buildings in the
## world's index: completion and capture change their eligibility in place.
const SIM_KINDS := ["fob", "town", "barracks", "factory", "research", "helipad", "dock",
	"medic_tent", "mg_nest", "watchtower", "hmg_nest", "mortar_pit", "at_post", "mines", "ammo_cache"]

var skind := ""
var size := Vector3.ONE
var yaw := 0.0
var variant := 0
var built := true
var progress := 1.0
var sname := ""
var radius := 1.0
var foot := Vector2.ONE  # half extents of the footprint
var parts: Array = []
var cover_pts := PackedVector3Array()
# fighting positions round it (see Cover): where a man stands, which way he
# faces (across the barrier), how high it is there, and how he uses it
var anc_p := PackedVector3Array()
var anc_n := PackedVector3Array()
var anc_h := PackedFloat32Array()
var anc_k := PackedByteArray()
var nav_cells: Array = []
var hash_cells: Array = []
var body: StaticBody3D
var model: Node3D
var view_active := true
var defer_view := false
var _toss_received_ms := 0
var smashable := true
var indestructible := false

# FOB / economy
var supply := 0.0
var wrecked := false
var cap_prog := 0.0
var cap_team := -1
var completed_order := 0
var supply_parent: Structure = null
var road := PackedVector3Array()
var truck: Vehicle = null
var truck_t := 4.0
var supply_status := "OK"
var _alert_t := 0.0
# a town or village's supply dump ("town"; variant 1 is the town, 0 a village):
# the ground that has to be held to take the place, and how much of it still
# stands (its houses' roofs, against how many there were)
var zone_c := Vector3.INF
var zone_r := 0.0
var houses0 := -1
var intact := 1.0
var _house_t := 0.0
# production / research
var queue: Array = []
var queue_items: Array = []
var queue_frac := 0.0
var rally := Vector3.INF
var prod_status := ""
# special buildings
var gunner: Soldier = null
var manned := false  # a watchtower with a lookout up it (sees further: Vision)
var inside: Array = []
var inside_n := 0
var bearers: Array = []
var bearer_t := 0.0
var _tick_t := 0.0
var label_h := 0.0  # height of the name plate the HUD draws over FOBs and depots (0: none)
var tilt := Vector2.ZERO  # wrecks and tossed cars can lie at an angle: (pitch, roll)
var toss = null  # [from pos, from yaw, velocity, spin] while it's flying (clients animate it)
var vk := ""  # what a wreck used to be
var door_shut := false  # (a house's doorway) its doors are shut: the first man through kicks them in, or just opens them
var _door_kicked := false
var _door_leaves: Array = []  # (view) the door leaves: [hinge pivot, how far it swings open]
var _flag: MeshInstance3D
var _vis_cache := true
var burn := 0.0  # how hard it's burning, 0..1 (every peer; see Fires)
var burnt := false  # burnt out: a charred snag, a burnt-out car - it won't burn again
var fire_k := ""  # (server) what it burns as, once lit (Fires.FUEL)
var fuel := 0.0  # (server) seconds of full blaze left
var fuel_max := 0.0
var _fire_fx: Node3D  # (view) its flames, embers, smoke and glow
var _fire_shown := -1  # (view) the burn level the effects were last set for
var _char := 0.0  # (view) how charred it looks, 0..1
var _char_mats: Array = []  # (view) its materials with the char on them


func ekind() -> String:
	return "structure"


func is_static() -> bool:
	return true


func display_name() -> String:
	if skind == "fob":
		return "FOB " + sname
	if skind == "depot":
		return Defs.TEAM_NAMES[team] + " HQ"
	if skind == "town":
		return sname
	if Defs.BUILDINGS.has(skind):
		return Defs.BUILDINGS[skind].name
	return skind.capitalize()


func is_player_building() -> bool:
	return Defs.BUILDINGS.has(skind) or skind == "depot"


func apply_props(d: Dictionary) -> void:
	if world and world.structure_view:
		world.structure_view.unbatch(self)
	if d.has("skind"):
		skind = d.skind
	if d.has("team"):
		var was: int = team
		team = d.team
		if team != was and model:
			_recolor()  # (captured: the flag comes down)
	if d.has("owner"):
		owner_peer = d.owner
	if d.has("pos"):
		position = d.pos
	if d.has("yaw"):
		yaw = d.yaw
		rotation.y = yaw
	if d.has("size"):
		size = d.size
	if d.has("variant"):
		variant = d.variant
	if d.has("built"):
		built = d.built
	if d.has("progress"):
		progress = d.progress
	if d.has("hp"):
		hp = d.hp
	if d.has("max_hp"):
		max_hp = d.max_hp
	if d.has("sname"):
		sname = d.sname
	if d.has("supply"):
		supply = d.supply
	if d.has("queue"):
		queue_items = d.queue
	if d.has("seen"):
		seen_mask = d.seen
	if d.has("vk"):
		vk = d.vk
	if d.has("door"):
		door_shut = d.door
	if d.has("zc"):
		zone_c = d.zc
		zone_r = d.zr
	if d.has("tilt"):
		tilt = d.tilt
		if model:
			_apply_tilt()
	if d.has("toss"):
		_toss_received_ms = Time.get_ticks_msec()
		toss = d.toss
		if toss != null and model:
			_start_toss()
	if not srv and not parts.is_empty() and (d.has("toss") or d.has("built")):
		_compute_cover_pts()  # thrown somewhere else, or finished: its fighting positions moved
	if d.has("burnt"):
		var was := burnt
		burnt = d.burnt
		if burnt and not was and model:
			_rebuild_model()  # the snag or the shell the fire left


func get_props() -> Dictionary:
	var d := {"skind": skind, "team": team, "owner": owner_peer, "pos": position, "yaw": yaw, "size": size,
		"variant": variant, "built": built, "progress": progress, "hp": hp, "max_hp": max_hp, "sname": sname,
		"supply": supply, "queue": queue_items, "seen": seen_mask, "vk": vk, "tilt": tilt, "toss": toss, "door": door_shut,
		"burnt": burnt}
	if skind == "town":
		d["zc"] = zone_c
		d["zr"] = zone_r
	return d


func on_spawned() -> void:
	if size == Vector3.ONE:
		if Defs.BUILDINGS.has(skind):
			var s: Vector2 = Defs.BUILDINGS[skind].size
			size = Vector3(s.x, 3.0, s.y)
		else:
			match skind:
				"depot":
					size = Vector3(17, 3, 11)
				"wreck":
					size = Vector3(3.4, 2.0, 6.2)
				"car":
					size = Vector3(1.8, 1.5, 4.2)
				"crates":
					size = Vector3(2.5 if variant == 1 else 1.2, 1.2, 1.25)
				"tree":
					size = Vector3(0.6, 5.0, 0.6)
				"town":
					size = Vector3(3.6, 2.0, 2.4)
	_define_parts()
	foot = Vector2(size.x * 0.5, size.z * 0.5)
	if skind == "trench":
		foot.x += TrenchNet.HALF_W  # the hole runs on past the segment's ends
	radius = foot.length() + 0.5
	indestructible = skind in ["depot", "floor", "bridge", "town"]  # (a house's floor slab outlasts its walls)
	smashable = skind in ["low_wall", "tall_wall", "house_wall", "crates", "car", "tree", "sandbags", "concrete_wall", "wire", "rubble", "fence", "barricade"]
	if srv:
		if max_hp <= 0.0 or (hp == 100.0 and max_hp == 100.0):
			max_hp = _default_hp()
			hp = max_hp if built else max_hp * 0.1
		world.nav.add_structure(self)
		if built:
			_make_body()
		if door_shut:
			world.add_door(self)
		if skind == "ammo_cache" and supply <= 0.0:
			supply = CACHE_STOCK
	_compute_cover_pts()  # every peer: the move preview shows the same spots
	if world.has_view:
		if defer_view:
			view_active = false
			set_process(false)
		else:
			set_view_active(true)
	# a vehicle that has just brewed up burns where it died
	if srv and world.fires and variant >= 6 and skind in ["wreck", "rubble"]:
		world.fires.ignite(self, 1.0)


func set_view_active(value: bool) -> void:
	if world and world.structure_view:
		world.structure_view.unbatch(self, not value)
	view_active = value
	if value and not srv and built and body == null:
		_make_body()
	if value and model == null:
		_build_model()
		_update_visual()
		_apply_tilt()
		if toss != null and Time.get_ticks_msec() - _toss_received_ms < 2000:
			_start_toss()
		_burn_view()
	if model:
		model.visible = value
	if not srv and body:
		body.collision_layer = Defs.L_COVER if value else 0
	if is_instance_valid(_fire_fx):
		_fire_fx.visible = value
	if is_instance_valid(_damage_fx):
		_damage_fx.visible = value
	set_process(value and (team >= 0 or not built or skind in SMOKE_KINDS or skind == "roof" or burn > 0.0 or _fire_fx != null))


func _default_hp() -> float:
	if Defs.BUILDINGS.has(skind):
		return Defs.BUILDINGS[skind].hp
	match skind:
		"low_wall":
			return 260.0 * size.x / 4.0
		"tall_wall", "house_wall":
			return 600.0 * size.x / 4.0
		"bridge":
			return 99999.0
		"crates":
			return 200.0
		"car":
			return 300.0
		"wreck":
			return 5000.0
		"tree":
			return 400.0
		"rubble":
			return 2000.0
		"roof":
			return 450.0
		"depot":
			return 99999.0
	return 300.0


func on_despawn() -> void:
	if srv and world.nav:
		world.nav.remove_structure(self)
	if srv and door_shut:
		world.remove_door(self)
	if _fire_fx:
		# blown apart or burnt away: what was alight smoulders where it stood
		world.fx.vfx.smoulder(_fire_fx, 25.0 if burn > 0.0 else 10.0)
		_fire_fx = null


# --- parts ---------------------------------------------------------------------

func _part(p: Vector3, s: Vector3, nav: int, veh: int, cover := true, col := true, color := C_STONE, r := 0.0) -> Dictionary:
	return {"p": p, "s": s, "nav": nav, "veh": veh, "cover": cover, "col": col, "color": color, "r": r}


func _define_parts() -> void:
	parts = []
	var L := size.x
	match skind:
		"low_wall":
			var c: Color = [C_STONE, Color(0.2, 0.29, 0.13), Color(0.58, 0.37, 0.28)][variant % 3]
			var h := (size.y if size.y > 0.2 else 1.0) if variant % 3 != 1 else 1.15
			parts = [_part(Vector3(0, h * 0.5, 0), Vector3(L, h, 0.5 if variant % 3 != 1 else 0.9), Nav.LOW, Nav.LOW, true, true, c)]
		"tall_wall":
			parts = [_part(Vector3(0, 1.3, 0), Vector3(L, 2.6, 0.5), Nav.SOLID, Nav.LOW, true, true, C_CONCRETE)]
		"house_wall":
			var c: Color = HOUSE_COLORS[int(size.y) % HOUSE_COLORS.size()]
			var th := 0.4
			match variant:
				1:
					var w := 1.3
					var pier := (L - w) * 0.5
					parts = [
						_part(Vector3(-L * 0.5 + pier * 0.5, 1.5, 0), Vector3(pier, 3.0, th), Nav.SOLID, Nav.LOW, true, true, c),
						_part(Vector3(L * 0.5 - pier * 0.5, 1.5, 0), Vector3(pier, 3.0, th), Nav.SOLID, Nav.LOW, true, true, c),
						_part(Vector3(0, 0.5, 0), Vector3(w, 1.0, th), Nav.LOW, Nav.LOW, true, true, c),
						_part(Vector3(0, 2.5, 0), Vector3(w, 1.0, th), Nav.FREE, Nav.FREE, false, true, c),
					]
				2:
					var w := 1.9
					var pier := (L - w) * 0.5
					parts = [
						_part(Vector3(-L * 0.5 + pier * 0.5, 1.5, 0), Vector3(pier, 3.0, th), Nav.SOLID, Nav.LOW, true, true, c),
						_part(Vector3(L * 0.5 - pier * 0.5, 1.5, 0), Vector3(pier, 3.0, th), Nav.SOLID, Nav.LOW, true, true, c),
						_part(Vector3(0, 2.6, 0), Vector3(w, 0.8, th), Nav.FREE, Nav.FREE, false, true, c),
					]
					if door_shut:
						# the shut doors: no-one sees or shoots through them (men still
						# path through the doorway - see open_door)
						var dp := _part(Vector3(0, 1.05, DOOR_Z), Vector3(w, 2.1, 0.08), Nav.FREE, Nav.FREE, false, true, c)
						dp["door"] = true
						parts.append(dp)
				_:
					parts = [_part(Vector3(0, 1.5, 0), Vector3(L, 3.0, th), Nav.SOLID, Nav.LOW, true, true, c)]
		"floor":
			parts = [_part(Vector3(0, 0.03, 0), Vector3(size.x, 0.06, size.z), Nav.FREE, Nav.FREE, false, false, Color(0.45, 0.42, 0.38))]
		"dock":
			# the boat shed over the slipway on the left (see DockModel); the
			# jetty runs out over the water in front
			parts = [_part(Vector3(-size.x * 0.5 + 2.9, 1.85, 0.35), Vector3(4.9, 3.7, size.z - 1.3), Nav.SOLID, Nav.SOLID, true, true, C_STEEL)]
		"bridge":
			# a road bridge (a deck between parapet walls) or a harbour quay
			# (an open concrete deck); size.x wide, size.z long
			var W := size.x
			var Lz := size.z
			parts = [_part(Vector3(0, -0.25, 0), Vector3(W, 0.5, Lz), Nav.FREE, Nav.FREE, false, true, C_CONCRETE)]
			if variant == 0:
				for sx in [-1.0, 1.0]:
					parts.append(_part(Vector3(sx * (W * 0.5 - 0.18), 0.45, 0), Vector3(0.36, 0.9, Lz - 1.0), Nav.SOLID, Nav.SOLID, true, true, C_CONCRETE))
		"roof":
			parts = []  # looks only: no cover, no obstacle (it's 3 m up)
		"rubble":
			parts = [
				_part(Vector3(0, 0.35, 0), Vector3(L, 0.7, maxf(1.0, size.z)), Nav.LOW, Nav.FREE, true, true, Color(0.52, 0.49, 0.44)),
				_part(Vector3(L * 0.15, 0.6, 0.1), Vector3(L * 0.45, 1.0, 0.8), Nav.LOW, Nav.FREE, true, true, Color(0.48, 0.45, 0.4), 0.3),
			]
		"crates":
			if variant == 0:
				parts = [_part(Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), Nav.LOW, Nav.LOW, true, true, C_WOOD)]
			else:
				parts = [
					_part(Vector3(0, 0.6, 0), Vector3(2.5, 1.2, 1.25), Nav.SOLID, Nav.LOW, true, true, C_WOOD),
					_part(Vector3(-0.6, 1.8, 0), Vector3(1.2, 1.2, 1.2), Nav.FREE, Nav.FREE, false, true, C_WOOD.darkened(0.1), 0.15),
				]
		"car":
			var c: Color = CAR_COLORS[variant % CAR_COLORS.size()]
			parts = [
				_part(Vector3(0, 0.55, 0), Vector3(1.8, 0.8, 4.2), Nav.SOLID, Nav.LOW, true, true, c),
				_part(Vector3(0, 1.18, 0.25), Vector3(1.6, 0.5, 2.1), Nav.FREE, Nav.FREE, false, true, c.darkened(0.15)),
			]
		"wreck":
			var ws := size if size != Vector3.ONE else Vector3(3.4, 2.0, 6.2)
			parts = [
				_part(Vector3(0, ws.y * 0.375, 0), Vector3(ws.x, ws.y * 0.75, ws.z), Nav.SOLID, Nav.SOLID, true, true, Color(0.18, 0.17, 0.16)),
				_part(Vector3(0, ws.y * 0.92, ws.z * 0.05), Vector3(ws.x * 0.65, ws.y * 0.35, ws.z * 0.42), Nav.FREE, Nav.FREE, false, true, Color(0.2, 0.19, 0.17), 0.4),
			]
		"tree":
			parts = [_part(Vector3(0, 2.5, 0), Vector3(0.5, 5.0, 0.5), Nav.SOLID, Nav.LOW, true, true, Color(0.32, 0.24, 0.16))]
		"fob":
			parts = [_part(Vector3(0, 1.2, 0), Vector3(4.6, 2.4, 4.6), Nav.SOLID, Nav.SOLID, true, true, C_SAND)]
			for s in [-1.0, 1.0]:
				for side in [-1.0, 1.0]:
					parts.append(_part(Vector3(side * 4.0, 0.5, s * 6.3), Vector3(4.6, 1.0, 0.9), Nav.LOW, Nav.LOW, true, true, C_SAND))
					parts.append(_part(Vector3(s * 6.3, 0.5, side * 4.0), Vector3(0.9, 1.0, 4.6), Nav.LOW, Nav.LOW, true, true, C_SAND))
		"town":
			# the supply dump by the street: stores stacked on pallets, a row of
			# fuel drums (chest-high cover both); the front (-z) faces the road
			parts = [
				_part(Vector3(0.55, 0.62, 0.35), Vector3(2.3, 1.24, 1.4), Nav.SOLID, Nav.SOLID, true, true, C_WOOD),
				_part(Vector3(0.85, 1.7, 0.4), Vector3(1.3, 0.9, 1.1), Nav.FREE, Nav.FREE, false, true, C_WOOD),
				_part(Vector3(-1.15, 0.45, 0.2), Vector3(1.2, 0.9, 1.7), Nav.SOLID, Nav.SOLID, true, true, C_STEEL),
			]
		"barracks":
			parts = [_part(Vector3(0, 1.5, 0), Vector3(size.x, 3.0, size.z), Nav.SOLID, Nav.SOLID, true, true, C_OLIVE)]
		"factory":
			parts = [_part(Vector3(0, 2.5, 0), Vector3(size.x, 5.0, size.z), Nav.SOLID, Nav.SOLID, true, true, Color(0.45, 0.46, 0.44))]
		"medic_tent":
			parts = [_part(Vector3(0, 1.3, 0), Vector3(size.x, 2.6, size.z), Nav.SOLID, Nav.SOLID, true, true, Color(0.4, 0.41, 0.31))]
		"research":
			parts = [_part(Vector3(0, 1.6, 0), Vector3(size.x, 3.2, size.z), Nav.SOLID, Nav.SOLID, true, true, Color(0.5, 0.52, 0.5))]
		"depot":
			parts = [
				_part(Vector3(-5, 1.3, 0), Vector3(6, 2.6, 2.5), Nav.SOLID, Nav.SOLID, true, true, Color(0.55, 0.3, 0.2)),
				_part(Vector3(5, 1.3, -1), Vector3(6, 2.6, 2.5), Nav.SOLID, Nav.SOLID, true, true, Color(0.25, 0.4, 0.35)),
				_part(Vector3(0, 1.5, 3.5), Vector3(5, 3.0, 4), Nav.SOLID, Nav.SOLID, true, true, C_CONCRETE),
			]
		"sandbags":
			parts = [_part(Vector3(0, 0.5, 0), Vector3(L, 1.0, 0.9), Nav.LOW, Nav.LOW, true, true, C_SAND)]
		"concrete_wall":
			parts = [_part(Vector3(0, 1.3, 0), Vector3(L, 2.6, 0.6), Nav.SOLID, Nav.LOW, true, true, C_CONCRETE)]
		"hesco":
			# earth-filled cells, chest high and a metre thick: a man scrambles
			# over, a vehicle doesn't
			parts = [_part(Vector3(0, 0.685, 0), Vector3(L, 1.37, 1.06), Nav.LOW, Nav.SOLID, true, true, C_SAND)]
		"barricade":
			# drums, tyres and scrap, chest high; a tank shoves it aside
			parts = [_part(Vector3(0, 0.6, 0), Vector3(L, 1.2, 0.9), Nav.LOW, Nav.LOW, true, true, C_STEEL)]
		"ammo_cache":
			# the stacks of stores on their pallets, the sacks along the front
			parts = [
				_part(Vector3(0, 0.6, 0.15), Vector3(2.5, 1.2, 1.1), Nav.SOLID, Nav.SOLID, true, true, C_WOOD),
				_part(Vector3(0, 0.2, -0.95), Vector3(2.6, 0.4, 0.42), Nav.LOW, Nav.LOW, false, true, C_SAND),
			]
		"camo_net":
			parts = []  # a net on poles: it hides what's under it, it stops nothing
		"trench":
			# the earth either side of the hole and the spoil heaped on its lips:
			# from the duckboards up to the top of the parapet, that's what stops bullets
			parts = [
				_part(Vector3(0, -0.43, -1.2), Vector3(L, 1.54, 0.95), Nav.LOW, Nav.LOW, true, true, C_DIRT),
				_part(Vector3(0, -0.43, 1.2), Vector3(L, 1.54, 0.95), Nav.LOW, Nav.LOW, true, true, C_DIRT),
			]
		"wire":
			parts = [_part(Vector3(0, 0.45, 0), Vector3(L, 0.9, 1.2), Nav.SLOW, Nav.FREE, false, false, Color(0.4, 0.4, 0.4))]
		"mines":
			parts = []
		"tank_trap":
			parts = [_part(Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.8), Nav.FREE, Nav.SOLID, false, false, C_STEEL)]
		"mg_nest":
			if variant == 1:
				parts = _trench_bay_parts()
			else:
				parts = [
					_part(Vector3(0, 0.43, -1.7), Vector3(3.8, 0.86, 0.8), Nav.LOW, Nav.LOW, true, true, C_SAND),
					_part(Vector3(-1.7, 0.5, -0.4), Vector3(0.8, 1.0, 2.0), Nav.LOW, Nav.LOW, true, true, C_SAND),
					_part(Vector3(1.7, 0.5, -0.4), Vector3(0.8, 1.0, 2.0), Nav.LOW, Nav.LOW, true, true, C_SAND),
				]
		"watchtower":
			for x in [-1.2, 1.2]:
				for z in [-1.2, 1.2]:
					parts.append(_part(Vector3(x, 2.1, z), Vector3(0.25, 4.2, 0.25), Nav.SOLID, Nav.LOW, false, false, C_WOOD))
			parts.append(_part(Vector3(0, 4.1, 0), Vector3(3.0, 0.25, 3.0), Nav.FREE, Nav.FREE, false, true, C_WOOD))
			parts.append(_part(Vector3(0, 4.7, -1.45), Vector3(3.0, 0.95, 0.15), Nav.FREE, Nav.FREE, false, true, C_WOOD))
			parts.append(_part(Vector3(0, 4.7, 1.45), Vector3(3.0, 0.95, 0.15), Nav.FREE, Nav.FREE, false, true, C_WOOD))
			parts.append(_part(Vector3(-1.45, 4.7, 0), Vector3(0.15, 0.95, 3.0), Nav.FREE, Nav.FREE, false, true, C_WOOD))
			parts.append(_part(Vector3(1.45, 4.7, 0), Vector3(0.15, 0.95, 3.0), Nav.FREE, Nav.FREE, false, true, C_WOOD))
		"hmg_nest":
			if variant == 1:
				parts = _trench_bay_parts()
			else:
				parts = [
					_part(Vector3(0, 0.44, -1.85), Vector3(4.2, 0.88, 0.9), Nav.LOW, Nav.LOW, true, true, C_SAND),
					_part(Vector3(-1.85, 0.55, -0.5), Vector3(0.9, 1.1, 1.9), Nav.LOW, Nav.LOW, true, true, C_SAND),
					_part(Vector3(1.85, 0.55, -0.5), Vector3(0.9, 1.1, 1.9), Nav.LOW, Nav.LOW, true, true, C_SAND),
				]
		"mortar_pit":
			for i in 5:
				var a := -PI * 0.75 + i * PI * 0.375
				var c := Vector3(sin(a), 0, -cos(a)) * 2.0
				parts.append(_part(Vector3(c.x, 0.4, c.z), Vector3(1.7, 0.8, 0.8), Nav.LOW, Nav.LOW, true, true, C_SAND, -a))
		"at_post":
			parts = [
				_part(Vector3(0, 0.45, -1.5), Vector3(3.6, 0.9, 0.8), Nav.LOW, Nav.LOW, true, true, C_SAND),
				_part(Vector3(-1.6, 0.45, -0.5), Vector3(0.7, 0.9, 1.4), Nav.LOW, Nav.LOW, true, true, C_SAND),
			]
		"bunker":
			var wc: Color = C_CONCRETE.darkened(0.22) if team != 1 else Color(0.42, 0.31, 0.2)  # weathered, stained
			var h := 2.2
			var t := 0.6
			var hz := 2.8 - t * 0.5
			# front wall with a wide firing slit (1.1 m - 1.65 m)
			parts.append(_part(Vector3(-2.05, h * 0.5, -hz), Vector3(1.5, h, t), Nav.SOLID, Nav.SOLID, true, true, wc))
			parts.append(_part(Vector3(2.05, h * 0.5, -hz), Vector3(1.5, h, t), Nav.SOLID, Nav.SOLID, true, true, wc))
			parts.append(_part(Vector3(0, 0.55, -hz), Vector3(2.6, 1.1, t), Nav.SOLID, Nav.SOLID, true, true, wc))
			parts.append(_part(Vector3(0, 1.925, -hz), Vector3(2.6, 0.55, t), Nav.FREE, Nav.FREE, false, true, wc))
			# side walls with slits
			for sx in [-1.0, 1.0]:
				parts.append(_part(Vector3(sx * hz, h * 0.5, -1.55), Vector3(t, h, 1.3), Nav.SOLID, Nav.SOLID, true, true, wc))
				parts.append(_part(Vector3(sx * hz, h * 0.5, 1.55), Vector3(t, h, 1.3), Nav.SOLID, Nav.SOLID, true, true, wc))
				parts.append(_part(Vector3(sx * hz, 0.55, 0), Vector3(t, 1.1, 1.8), Nav.SOLID, Nav.SOLID, true, true, wc))
				parts.append(_part(Vector3(sx * hz, 1.925, 0), Vector3(t, 0.55, 1.8), Nav.FREE, Nav.FREE, false, true, wc))
			# back wall with a door
			parts.append(_part(Vector3(-1.9, h * 0.5, hz), Vector3(1.8, h, t), Nav.SOLID, Nav.SOLID, true, true, wc))
			parts.append(_part(Vector3(1.9, h * 0.5, hz), Vector3(1.8, h, t), Nav.SOLID, Nav.SOLID, true, true, wc))
			parts.append(_part(Vector3(0, 2.05, hz), Vector3(2.0, 0.3, t), Nav.FREE, Nav.FREE, false, true, wc))
			# roof: stops fragments from above
			parts.append(_part(Vector3(0, h + 0.18, 0), Vector3(5.8, 0.36, 5.8), Nav.FREE, Nav.FREE, false, true, wc.darkened(0.12)))
		"tunnel", "helipad":
			parts = []


func nav_parts() -> Array:
	var out := []
	var b := Basis(Vector3.UP, yaw)
	for p in parts:
		if p.nav == Nav.FREE and p.veh == Nav.FREE:
			continue
		var wc: Vector3 = position + b * p.p
		out.append({"c": Vector2(wc.x, wc.z), "h": Vector2(p.s.x * 0.5, p.s.z * 0.5), "yaw": yaw + p.r, "i": p.nav, "v": p.veh})
	return out


func provides_cover() -> bool:
	return built and not cover_pts.is_empty()


func _compute_cover_pts() -> void:
	Cover.build(self)
	cover_pts = anc_p


func _inside_any_part(wp: Vector3) -> bool:
	var b := Basis(Vector3.UP, yaw)
	for p in parts:
		if not p.col or p.nav == Nav.FREE:
			continue
		var wc: Vector3 = position + b * p.p
		if Defs.point_in_obb(Vector2(wp.x, wp.z), Vector2(wc.x, wc.z), Vector2(p.s.x * 0.5 + 0.25, p.s.z * 0.5 + 0.25), yaw + p.r):
			return true
	return false


func _make_body() -> void:
	if body or parts.is_empty():
		return
	body = StaticBody3D.new()
	body.collision_layer = Defs.L_COVER
	body.collision_mask = 0
	body.set_meta("eid", eid)
	var any := false
	for p in parts:
		if not p.col:
			continue
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = p.s
		cs.shape = bs
		cs.position = p.p
		cs.rotation.y = p.r
		if p.get("door", false):
			cs.name = "Door"
		body.add_child(cs)
		any = true
	if any:
		add_child(body)
		if srv and world.combat:
			world.combat.dirty_collision(eid)
	else:
		body.free()
		body = null


func is_mount() -> bool:
	return skind in ["mg_nest", "hmg_nest", "watchtower", "mortar_pit", "at_post"]


func mount_pos() -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	match skind:
		"watchtower":
			return position + Vector3(0, 4.25, 0)
		"mortar_pit":
			return position + b * Vector3(0, 0, 0.75)
		"at_post":
			return position + b * Vector3(0, 0, -0.4)
		"mg_nest", "hmg_nest":
			var g: Dictionary = WeaponModels.GUNS[mg_kind()]
			var lp := mg_pivot_local() + Vector3(0, 0, (g.grip_r as Vector3).z + (0.34 if variant == 1 else 0.5))
			var mp := position + b * Vector3(lp.x, 0, lp.z)
			if variant == 1:
				mp.y = TrenchNet.FLOOR_Y + 0.15
			return mp
	return position + b * Vector3(0, 0, -0.5)


## A machine-gun bay cut into a trench: just a low wall of bags on the lip in
## front of the gun (the trench itself is the cover), so the trench stays open.
func _trench_bay_parts() -> Array:
	var z := -(TrenchNet.HALF_W + 1.0)
	return [
		_part(Vector3(0, 0.15, z), Vector3(2.2, 0.3, 0.6), Nav.LOW, Nav.LOW, true, true, C_SAND),
		_part(Vector3(-0.95, 0.15, z + 0.55), Vector3(0.5, 0.3, 0.6), Nav.LOW, Nav.LOW, true, true, C_SAND),
		_part(Vector3(0.95, 0.15, z + 0.55), Vector3(0.5, 0.3, 0.6), Nav.LOW, Nav.LOW, true, true, C_SAND),
	]


# --- crew-served machine guns -------------------------------------------------------

var _mg := {}  # the gun's moving parts (view only, see WeaponModels.build)


## Which gun: M240B / M2HB for the Coalition, PKM / DShKM for the Rebels.
func mg_kind() -> String:
	if skind == "hmg_nest":
		return "dshk" if team == 1 else "m2"
	return "pkm" if team == 1 else "m240"


## Where the pintle sits (model space): on a platform of bags behind the front
## wall in a nest, on the front lip of the trench in a trench bay.
func mg_pivot_local() -> Vector3:
	var g: Dictionary = WeaponModels.GUNS[mg_kind()]
	if variant == 1:
		# far enough out that the tripod's rear feet are on the lip, not over the trench
		return Vector3(0, float(g.trench_h), -(TrenchNet.HALF_W + (0.55 if skind == "hmg_nest" else 0.5)))
	if skind == "hmg_nest":
		return Vector3(0, 0.45 + float(g.nest_h), -1.1)
	return Vector3(0, 0.5 + float(g.nest_h), -0.95)


## The gun's arc either side of the way the emplacement faces.
const MG_ARC := 1.2


## Where the rounds leave the barrel with the gun laid on `aim_yaw`.
func mg_muzzle(aim_yaw: float) -> Vector3:
	var g: Dictionary = WeaponModels.GUNS[mg_kind()]
	var rel := clampf(wrapf(aim_yaw - yaw, -PI, PI), -MG_ARC, MG_ARC)
	var piv := position + Basis(Vector3.UP, yaw) * mg_pivot_local()
	return piv + Vector3(0, float(g.bore), 0) + Defs.dir_of(yaw + rel) * float(g.muzzle)


## Can the gun be laid that way at all?
func mg_covers(dir: Vector3) -> bool:
	return Defs.flat(dir).normalized().dot(front_dir()) > cos(MG_ARC + 0.1)


## The gunner lays the gun (view): it swings to where he aims, within its arc,
## and bucks on the mount while he fires.
func crew_aim(aim_yaw: float, _firing: bool, dt: float) -> void:
	if _mg.is_empty():
		return
	var rel := clampf(wrapf(aim_yaw - yaw, -PI, PI), -MG_ARC, MG_ARC)
	var tr: Node3D = _mg.traverse
	tr.rotation.y = lerp_angle(tr.rotation.y, rel, 1.0 - exp(-dt * 7.0))
	# each round kicks it back on its mount (crew_kick); it runs forward again between them
	var body: Node3D = _mg.body
	var el: Node3D = _mg.elev
	if body.position.z != 0.0 or el.rotation.x != 0.0:
		body.position.z = lerpf(body.position.z, 0.0, 1.0 - exp(-dt * 16.0))
		el.rotation.x = lerpf(el.rotation.x, 0.0, 1.0 - exp(-dt * 12.0))
		if absf(body.position.z) < 0.0005 and absf(el.rotation.x) < 0.0005:
			body.position.z = 0.0
			el.rotation.x = 0.0


## A round fired (view): the gun recoils on its pintle and the muzzle jumps.
func crew_kick(k: float) -> void:
	if _mg.is_empty():
		return
	var body: Node3D = _mg.body
	var el: Node3D = _mg.elev
	body.position.z = minf(body.position.z + 0.022 * k, 0.05)
	el.rotation.x = clampf(el.rotation.x + randf_range(0.004, 0.014) * k, -0.02, 0.03)


## The gun's muzzle in world space right now (view), INF without a model.
func crew_muzzle_world() -> Vector3:
	if _mg.is_empty():
		return Vector3.INF
	return (_mg.body as Node3D).global_transform * (_mg.muzzle as Vector3)


## Where the gunner's body goes (view): behind the grips wherever the gun is
## laid, swinging round the pintle with it and riding its kick.
func crew_stance(ground_y: float) -> Transform3D:
	var g: Dictionary = WeaponModels.GUNS[mg_kind()]
	var tr: Node3D = _mg.traverse
	var body: Node3D = _mg.body
	var gb := Basis(Vector3.UP, yaw + tr.rotation.y)
	var piv := position + Basis(Vector3.UP, yaw) * mg_pivot_local()
	var back := (g.grip_r as Vector3).z + (0.34 if variant == 1 else 0.5) + body.position.z * 0.8
	var p := piv + gb * Vector3(0, 0, back)
	p.y = ground_y
	return Transform3D(gb, p)


## The gun's handles in world space: [right hand, left hand].
func crew_grips() -> Array:
	if _mg.is_empty():
		return []
	var xf: Transform3D = (_mg.body as Node3D).global_transform
	return [xf * (_mg.grip_r as Vector3), xf * (_mg.grip_l as Vector3)]


func _mg_model(rng: RandomNumberGenerator, bags: Array) -> void:
	var heavy := skind == "hmg_nest"
	_mg = WeaponModels.build(mg_kind(), variant == 1)
	var root: Node3D = _mg.root
	root.position = mg_pivot_local()
	model.add_child(root)
	var pz: float = root.position.z
	if variant == 1:
		# dug into the trench's front lip: tripod feet on the parapet, ammo
		# at the gunner's elbow
		WeaponModels.ammo_dump(model, Vector3(0.8, 0.0, -(TrenchNet.HALF_W + 0.3)), heavy, rng)
	else:
		# the gun sits on a platform of filled bags behind the front wall
		var ph := 0.45 if heavy else 0.5
		bags.append({"p": Vector3(0, ph * 0.5, pz + 0.05), "s": Vector3(1.2, ph, 0.9), "r": 0.0})
		WeaponModels.ammo_dump(model, Vector3(1.0, 0.0, 0.25), heavy, rng)
		# spent brass and links round the platform
		for i in 18:
			var bp := Vector3(rng.randf_range(-0.6, 0.6), 0.02, pz + rng.randf_range(0.35, 1.2))
			_mk(Res.cyl(0.007, 0.007, 0.05 if not heavy else 0.09, 5), "paint", bp, Vector3(PI / 2, rng.randf() * TAU, 0), WeaponModels.BRASS, false)


## Gun the crewman uses while manning this emplacement ({} = special behaviour).
func mount_weapon() -> Dictionary:
	match skind:
		"mg_nest":
			return Defs.WEAPONS.mmg
		"hmg_nest":
			return Defs.WEAPONS.m2
	return {}


## Which soldier types are best suited to crew it.
func mount_pref() -> Array:
	match skind:
		"mg_nest", "hmg_nest":
			return ["mg_gunner", "pkm"]
		"mortar_pit":
			return ["mortar_gunner", "r_mortar"]
		"at_post":
			return ["at_soldier", "rpg"]
	return []


var fire_queue: Array = []  # mortar pit fire mission: [[pos, kind], ...]


func queue_fire(pos: Vector3, kind: String, peer: int) -> void:
	if skind != "mortar_pit" or not built:
		return
	if gunner == null or gunner.gone or gunner.task != "man":
		world.rules.notify(peer, team, "Nobody is crewing that mortar pit. Move a squad next to it.")
		return
	var d := Defs.flat(pos - position).length()
	if d < 30.0 or d > 160.0:
		world.rules.notify(peer, team, "Out of mortar range (30-160 m).")
		return
	fire_queue.clear()
	for i in 6:
		fire_queue.append([pos, kind])
	gunner.say("Fire mission, %s! Rounds out!" % ("smoke" if kind == "smoke" else "HE"), true)


func front_dir() -> Vector3:
	return Defs.dir_of(yaw)


func exit_pos() -> Vector3:
	return position + front_dir() * (size.z * 0.5 + 3.0)


# --- damage ----------------------------------------------------------------------

var hit_from := Vector3.INF  # the last blast that reached it (a tree falls away from it)


func take_damage(amount: float, _source = null) -> void:
	if indestructible or gone or not srv:
		return
	if skind == "fob" and wrecked:
		return
	if world.battle and team >= 0 and is_player_building():
		world.battle.structure_hit(self, _source)
	hp -= amount
	net_dirty = true
	if door_shut and amount >= 20.0:
		open_door(null, true)
	if team >= 0 and is_player_building() and world.time > _alert_t and amount > 5.0 and not skind in LINE_WORKS:
		_alert_t = world.time + 25.0
		world.send_msg(team, "alert", "%s is under attack at %s!" % [display_name(), Defs.grid_ref(position)], position)
	if hp <= 0.0:
		hp = 0.0
		_destroyed()
	elif skind == "car" and burn <= 0.0 and hp < max_hp * 0.5 and world.fires and world.rng.randf() < 0.35:
		world.fires.ignite(self, 0.3)  # holed and leaking: the fuel goes up


func smash(_by) -> void:
	if not smashable or gone:
		return
	world.fx_event([Fx.DEBRIS, position + Vector3(0, 0.8, 0), _main_color(), 8])
	world.fx_event([Fx.SOUND, "thud", position])
	if skind == "tree":
		world.fx_event([Fx.TREE_FALL, position, Defs.yaw_of(Defs.flat(position - _by.position)), eid, variant])
	world.despawn(self)


func _main_color() -> Color:
	if skind == "roof":
		return Color(0.5, 0.24, 0.16) if variant % 2 == 0 else C_CONCRETE
	return parts[0].color if not parts.is_empty() else C_STONE


## The outside face of a house wall (local +z faces out): a darker plinth
## along the bottom; windows get a sill and lintel, a painted frame with a
## mullion and transom, panes (often shot out) and sometimes shutters;
## doorways a frame, a step and the doors hanging open. Plaster details share
## the wall's own surface and the woodwork shares one painted surface, so a
## wall stays two or three draw calls.
func _house_wall_detail(rng: RandomNumberGenerator) -> void:
	var L := size.x
	var ci := int(size.y)
	var wall: Color = HOUSE_COLORS[ci % HOUSE_COLORS.size()]
	var trim: Color = [Color(0.86, 0.85, 0.8), Color(0.32, 0.23, 0.16), Color(0.23, 0.34, 0.28), Color(0.84, 0.83, 0.78), Color(0.36, 0.38, 0.43)][ci % 5]
	var zo := 0.2
	_mkb(Res.box(Vector3(L, 0.34, 0.04)), "plaster", Vector3(0, 0.17, zo + 0.02), Vector3.ZERO, wall.darkened(0.3))
	match variant:
		1:
			var w := 1.3
			_mkb(Res.box(Vector3(w + 0.24, 0.07, 0.16)), "plaster", Vector3(0, 0.965, zo + 0.06), Vector3.ZERO, wall.lightened(0.25))
			_mkb(Res.box(Vector3(w + 0.16, 0.13, 0.03)), "plaster", Vector3(0, 2.07, zo + 0.015), Vector3.ZERO, wall.darkened(0.1))
			var fz := zo - 0.1
			for x in [-w * 0.5 + 0.035, w * 0.5 - 0.035]:
				_mkb(Res.box(Vector3(0.07, 1.0, 0.07)), "paint", Vector3(x, 1.5, fz), Vector3.ZERO, trim, false)
			for y in [1.035, 1.965]:
				_mkb(Res.box(Vector3(w, 0.07, 0.07)), "paint", Vector3(0, y, fz), Vector3.ZERO, trim, false)
			_mkb(Res.box(Vector3(0.05, 0.9, 0.05)), "paint", Vector3(0, 1.5, fz), Vector3.ZERO, trim, false)
			_mkb(Res.box(Vector3(w - 0.1, 0.05, 0.05)), "paint", Vector3(0, 1.7, fz), Vector3.ZERO, trim, false)
			for x in [-0.31, 0.31]:
				if rng.randf() < 0.4:
					_mkb(Res.box(Vector3(0.56, 0.86, 0.012)), "glass", Vector3(x, 1.5, fz), Vector3.ZERO, null, false)
			if rng.randf() < 0.45:
				var shc: Color = [Color(0.24, 0.36, 0.27), Color(0.31, 0.39, 0.46), Color(0.36, 0.25, 0.16), Color(0.5, 0.22, 0.17)][(ci + 1) % 4]
				for sx in [-1.0, 1.0]:
					if rng.randf() < 0.85:
						_mkb(Res.box(Vector3(0.6, 1.04, 0.035)), "paint", Vector3(sx * (w * 0.5 + 0.33), 1.5, zo + 0.03), Vector3(0, sx * rng.randf_range(0.0, 0.2), 0), shc, false)
		2:
			var w := 1.9
			var fz := zo - 0.08
			for x in [-w * 0.5 + 0.04, w * 0.5 - 0.04]:
				_mkb(Res.box(Vector3(0.08, 2.2, 0.1)), "paint", Vector3(x, 1.1, fz), Vector3.ZERO, trim, false)
			_mkb(Res.box(Vector3(w, 0.09, 0.1)), "paint", Vector3(0, 2.16, fz), Vector3.ZERO, trim, false)
			_mkb(Res.box(Vector3(w + 0.4, 0.14, 0.6)), "plaster", Vector3(0, 0.07, zo + 0.3), Vector3.ZERO, Color(0.62, 0.6, 0.56))
			# double doors: shut (till someone comes through), or swung in -
			# one may be gone. Each leaf hangs on its own hinge so it can swing.
			var dc: Color = [Color(0.3, 0.2, 0.13), Color(0.22, 0.32, 0.26), Color(0.26, 0.31, 0.4), Color(0.42, 0.2, 0.15)][(ci + 2) % 4]
			_door_leaves = []
			for sx in [-1.0, 1.0]:
				var lost := rng.randf() < 0.25
				var a: float = -sx * rng.randf_range(1.0, 1.55)
				if lost and not door_shut:
					continue
				var pv := Node3D.new()
				pv.position = Vector3(sx * (w * 0.5 - 0.09), 0, DOOR_Z)
				pv.rotation.y = 0.0 if door_shut else a
				model.add_child(pv)
				var lx: float = -sx * 0.44
				for piece in [
						[Vector3(0.88, 2.06, 0.05), Vector3(lx, 1.05, 0), dc],
						# panels, a rail and the handle
						[Vector3(0.62, 0.78, 0.02), Vector3(lx, 1.55, 0.03), dc.darkened(0.18)],
						[Vector3(0.62, 0.62, 0.02), Vector3(lx, 0.5, 0.03), dc.darkened(0.18)],
						[Vector3(0.62, 0.62, 0.02), Vector3(lx, 0.5, -0.03), dc.darkened(0.18)],
						[Vector3(0.62, 0.78, 0.02), Vector3(lx, 1.55, -0.03), dc.darkened(0.18)],
						[Vector3(0.05, 0.05, 0.16), Vector3(-sx * 0.8, 1.0, 0), Color(0.18, 0.17, 0.15)]]:
					var mi := _mk(Res.box(piece[0]), "paint", Vector3.ZERO, Vector3.ZERO, piece[2], false)
					model.remove_child(mi)
					pv.add_child(mi)
					mi.position = piece[1]
				_door_leaves.append([pv, a])


## A concrete road bridge on piers - deck, kerbed footways, parapet walls,
## the girders and pier heads under it, abutments into the banks, a lamp at
## each end - or (variant 1) a harbour quay: a massive concrete wall down to
## the seabed with bollards, fenders and a ladder.
func _bridge_model(rng: RandomNumberGenerator) -> void:
	var W := size.x
	var L := size.z
	var conc := Color(0.6, 0.58, 0.54)
	var dark := Color(0.42, 0.41, 0.39)
	var asphalt := Color(0.16, 0.16, 0.16)
	if variant == 1:
		# the quay: a block of concrete from the seabed up, a lip round the top
		_mk(Res.box(Vector3(W, 3.5, L)), "concrete", Vector3(0, -1.72, 0), Vector3.ZERO, conc)
		_mk(Res.box(Vector3(W + 0.3, 0.25, L + 0.3)), "concrete", Vector3(0, -0.02, 0), Vector3.ZERO, conc.lightened(0.06))
		_mk(Res.box(Vector3(W - 1.2, 0.02, L - 1.2)), "concrete_floor", Vector3(0, 0.115, 0), Vector3.ZERO, Color(0.5, 0.49, 0.46), false)
		for sx in [-1.0, 1.0]:
			var n := int(L / 5.0)
			for i in n:
				var z := -L * 0.5 + (i + 0.5) * L / n
				# bollards on the edge, tyre fenders on the wall
				_mk(Res.cyl(0.16, 0.2, 0.42, 10), "metal_dark", Vector3(sx * (W * 0.5 - 0.45), 0.31, z), Vector3.ZERO, Color(0.12, 0.12, 0.12))
				_mk(Res.cyl(0.22, 0.22, 0.06, 10), "metal_dark", Vector3(sx * (W * 0.5 - 0.45), 0.53, z), Vector3.ZERO, Color(0.12, 0.12, 0.12))
				var ty := Res.mi(model, Res.torus(0.18, 0.42), Res.mat(Color(0.05, 0.05, 0.05)), Vector3(sx * (W * 0.5 + 0.22), -0.55, z + 1.2), Vector3(0, 0, PI * 0.5), false)
				ty.scale = Vector3(1.0, 1.0, 1.0)
		# a ladder down the far end, a lamp and a mooring post at the head
		for i in 9:
			_mk(Res.box(Vector3(0.5, 0.04, 0.05)), "metal", Vector3(0, -0.2 - i * 0.32, -L * 0.5 - 0.06), Vector3.ZERO, Color(0.3, 0.3, 0.3), false)
		for sx in [-0.28, 0.28]:
			_mk(Res.box(Vector3(0.05, 3.0, 0.05)), "metal", Vector3(sx, -1.4, -L * 0.5 - 0.06), Vector3.ZERO, Color(0.3, 0.3, 0.3), false)
		_lamp(Vector3(W * 0.5 - 0.6, 0.1, L * 0.5 - 2.0))
		return
	# the deck: a thick slab, asphalt down the middle between kerbed footways
	_mk(Res.box(Vector3(W, 0.55, L)), "concrete", Vector3(0, -0.25, 0), Vector3.ZERO, conc)
	_mk(Res.box(Vector3(W - 2.0, 0.02, L)), "concrete_floor", Vector3(0, 0.035, 0), Vector3.ZERO, asphalt, false)
	for sx in [-1.0, 1.0]:
		_mk(Res.box(Vector3(0.62, 0.16, L)), "concrete", Vector3(sx * (W * 0.5 - 0.67), 0.08, 0), Vector3.ZERO, conc.lightened(0.05), false)
		# parapet wall with its coping, drain holes along the foot
		_mk(Res.box(Vector3(0.36, 0.9, L - 1.0)), "concrete", Vector3(sx * (W * 0.5 - 0.18), 0.45, 0), Vector3.ZERO, conc)
		_mk(Res.box(Vector3(0.46, 0.08, L - 0.9)), "concrete", Vector3(sx * (W * 0.5 - 0.18), 0.93, 0), Vector3.ZERO, conc.lightened(0.08))
		# the girder under the edge, stained by the weather
		_mk(Res.box(Vector3(0.5, 0.75, L)), "concrete", Vector3(sx * (W * 0.5 - 0.9), -0.88, 0), Vector3.ZERO, dark)
		# a white line along the edge of the carriageway
		_mk(Res.box(Vector3(0.12, 0.01, L)), "paint", Vector3(sx * (W * 0.5 - 1.15), 0.048, 0), Vector3.ZERO, Color(0.8, 0.79, 0.74), false)
	# the piers: a wall of concrete under the deck, a cutwater upstream and down
	var spans := maxi(2, int(round(L / 9.0)))
	for i in range(1, spans):
		var z := -L * 0.5 + i * L / spans
		_mk(Res.box(Vector3(W * 0.82, 2.6, 1.1)), "concrete", Vector3(0, -2.0, z), Vector3.ZERO, dark)
		_mk(Res.box(Vector3(W * 0.9, 0.35, 1.4)), "concrete", Vector3(0, -0.68, z), Vector3.ZERO, conc)
		for sx in [-1.0, 1.0]:
			_mk(Res.cyl(0.55, 0.55, 2.6, 8), "concrete", Vector3(sx * W * 0.41, -2.0, z), Vector3.ZERO, dark)
	# the abutments, into the banks at either end
	for sz in [-1.0, 1.0]:
		_mk(Res.box(Vector3(W + 0.8, 1.6, 1.4)), "concrete", Vector3(0, -0.85, sz * (L * 0.5 - 0.6)), Vector3.ZERO, dark)
		for sx in [-1.0, 1.0]:
			_mk(Res.box(Vector3(0.5, 1.1, 0.5)), "concrete", Vector3(sx * (W * 0.5 - 0.18), 0.55, sz * (L * 0.5 - 0.25)), Vector3.ZERO, conc.lightened(0.04))
	_lamp(Vector3(W * 0.5 - 0.2, 0.95, L * 0.5 - 1.2))
	_lamp(Vector3(-(W * 0.5 - 0.2), 0.95, -(L * 0.5 - 1.2)))


func _lamp(p: Vector3) -> void:
	var pole := Color(0.22, 0.23, 0.24)
	_mk(Res.cyl(0.06, 0.08, 4.6, 8), "metal", p + Vector3(0, 2.3, 0), Vector3.ZERO, pole)
	_mk(Res.box(Vector3(0.9, 0.06, 0.08)), "metal", p + Vector3(-signf(p.x) * 0.42, 4.55, 0), Vector3.ZERO, pole, false)
	_mk(Res.box(Vector3(0.36, 0.1, 0.2)), "metal", p + Vector3(-signf(p.x) * 0.86, 4.5, 0), Vector3.ZERO, Color(0.3, 0.3, 0.3), false)


## Where the doors hang in a doorway wall (local z: just inside its outer face).
const DOOR_Z := 0.08


## The doors flung open - kicked in, blown in, or pushed open by a man who
## isn't expecting trouble. They stop hiding the room and stopping rounds.
func open_door(by: Entity, kicked: bool) -> void:
	if world and world.structure_view:
		world.structure_view.unbatch(self)
	if not door_shut:
		return
	door_shut = false
	_door_kicked = kicked
	net_dirty = true
	for i in range(parts.size() - 1, -1, -1):
		if parts[i].get("door", false):
			parts.remove_at(i)
	if body:
		var dn := body.get_node_or_null("Door")
		if dn:
			body.remove_child(dn)
			dn.queue_free()
	if srv and world.combat:
		world.combat.dirty_collision(eid)
	_swing_leaves(kicked)
	if srv:
		world.remove_door(self)
		world.fx_event([Fx.SOUND, "door_kick" if kicked else "door", position + Vector3(0, 1.0, 0)])
		world.stat("door_kicked" if kicked else "door_opened")
		if kicked and by is Soldier:
			# a door kicked in is loud: whoever's in there hears where they're coming from
			for s in world.soldiers_near(position, 16.0):
				if s.team != by.team and s.team >= 0 and s.squad and s.life == Soldier.Life.ALIVE:
					s.squad.report_pos(by.position)


## Is he walking into the shut doors? (He's within a stride of them, on his
## way through.)
func door_blocks(p: Vector3, dir: Vector3) -> bool:
	var ib := Basis(Vector3.UP, -yaw)
	var lp: Vector3 = ib * (p - position)
	var ld: Vector3 = ib * dir
	var z := lp.z - DOOR_Z
	return absf(lp.x) < 1.05 and absf(z) < 0.9 and absf(ld.z) > 0.3 and z * ld.z < 0.0


func _swing_leaves(kicked: bool) -> void:
	for lf in _door_leaves:
		var pv: Node3D = lf[0]
		if not is_instance_valid(pv):
			continue
		var a: float = lf[1]
		var tw := pv.create_tween()
		if kicked:
			# slammed back against the wall, and a little bounce off it
			var to := signf(a) * minf(absf(a) * 1.15, 1.6)
			tw.tween_property(pv, "rotation:y", to, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(pv, "rotation:y", to * 0.86, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(pv, "rotation:y", a * 0.8, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A building's model on its own, without a world (the field manual's preview).
static func preview_model(kind: String, side: int, v := 0, sz := Vector3.ZERO, shut := false) -> Node3D:
	var st := Structure.new()
	st.skind = kind
	st.team = side
	st.variant = v
	st.built = true
	st.door_shut = shut
	if sz != Vector3.ZERO:
		st.size = sz
	elif Defs.BUILDINGS.has(kind):
		var s: Vector2 = Defs.BUILDINGS[kind].size
		st.size = Vector3(s.x, 3.0, s.y)
	st._define_parts()
	st._build_model()
	st._update_visual()
	var m := st.model
	st.remove_child(m)
	st.free()
	return m


## A tree. Its id decides the look, so every peer builds the same one and
## the tree that falls when it is felled is the one that stood: broadleaf
## (a third are conifers); variant 1 is a small orchard tree. With 16 set the
## fire has been through it: the same tree as a bare black snag. Every part
## of it is merged, so the parts go straight into the merged meshes (a
## battlefield has over a thousand trees, of twenty-odd parts each); `root`
## starts out empty.
static func tree_model(root: Node3D, id: int, v: int) -> void:
	_snag = (v & 16) != 0
	v &= 15
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + v
	var bake := Mats.Bake.new()
	if v != 1 and (id * 2654435761) % 100 < 34:
		_conifer(bake, rng)
	else:
		_broadleaf(bake, rng, v == 1)
	_snag = false
	bake.commit(root)


static var _snag := false  # building a burnt tree: charred limbs, no leaves
const C_CHAR := Color(0.07, 0.06, 0.05)


## A flared trunk forking into three or four limbs, each carrying a clump of
## leaf masses (lighter on top, darker underneath), twigs poking out of the
## crown, which is wider than it is tall.
static func _broadleaf(bake: Mats.Bake, rng: RandomNumberGenerator, small: bool) -> void:
	var k := 0.62 if small else 1.0
	var bark := Res.vary(Color(0.3, 0.24, 0.18), 0.08, rng)
	if _snag:
		bark = C_CHAR
	var leaf: Color = [Color(0.17, 0.27, 0.11), Color(0.2, 0.29, 0.12), Color(0.15, 0.24, 0.12), Color(0.23, 0.29, 0.11)][rng.randi() % 4]
	leaf = Res.vary(leaf, 0.06, rng)
	var fork := rng.randf_range(1.9, 2.7) * k
	var crown := rng.randf_range(4.6, 5.6) * k  # where the limbs end
	var spread := rng.randf_range(1.3, 2.0) * k
	var top := Vector3(rng.randf_range(-0.25, 0.25) * k, fork, rng.randf_range(-0.25, 0.25) * k)
	_bark(bake, Vector3.ZERO, top, 0.3 * k, 0.2 * k, bark)
	_bark_part(bake, Res.cyl(0.26 * k, 0.46 * k, 0.45 * k, 8), Mats.place(Vector3(0, 0.22 * k, 0)), bark)
	var limbs := rng.randi_range(3, 4)
	var a0 := rng.randf() * TAU
	for i in limbs:
		var a := a0 + TAU * i / limbs + rng.randf_range(-0.35, 0.35)
		var out := Vector3(cos(a), 0, sin(a))
		var end := top + out * spread * rng.randf_range(0.7, 1.1)
		end.y = crown + rng.randf_range(-0.6, 0.5) * k
		var mid := top.lerp(end, 0.45) + out * 0.25 * k
		_bark(bake, top, mid, 0.17 * k, 0.12 * k, bark)
		_bark(bake, mid, end, 0.12 * k, 0.05 * k, bark)
		_bark(bake, end, end + (out + Vector3(0, 0.5, 0)).normalized() * 1.2 * k, 0.05 * k, 0.015, bark)
		for j in rng.randi_range(3, 4):
			var off := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.45, 0.75), rng.randf_range(-1.0, 1.0)) * k
			var lc := Res.vary(leaf, 0.05, rng)
			if off.y > 0.3 * k:
				lc = lc.lightened(0.04)
			elif off.y < 0.0:
				lc = lc.darkened(0.14)
			_leaves(bake, end + off, rng.randf_range(0.95, 1.35) * k, rng.randf_range(0.72, 0.88), lc)
	# the heart of the crown and its top
	_leaves(bake, Vector3(top.x, crown - 0.2 * k, top.z), 1.5 * k, 0.8, leaf.darkened(0.18))
	_leaves(bake, Vector3(top.x, crown + 0.9 * k, top.z), 1.35 * k, 0.8, leaf.lightened(0.05))


## A spruce: a straight tapering stem and tiers of drooping boughs, wide and
## dark at the bottom, a narrow spire at the top.
static func _conifer(bake: Mats.Bake, rng: RandomNumberGenerator) -> void:
	var ph := rng.randf_range(8.0, 11.0)
	var needles := Res.vary(Color(0.13, 0.21, 0.14), 0.12, rng)
	_bark(bake, Vector3.ZERO, Vector3(0, ph, 0), 0.26, 0.04, Color(0.32, 0.24, 0.17))
	# many overlapping tiers, each a little askew, so it reads as one ragged
	# mass of boughs rather than a stack of plates
	var tiers := rng.randi_range(9, 12)
	var step := (ph - 2.2) / tiers
	for i in tiers:
		var t := float(i) / (tiers - 1)
		var r := lerpf(2.3, 0.45, t) * rng.randf_range(0.9, 1.1)
		var h := step * 2.6
		var y := 1.2 + i * step
		if _snag:
			# the needles are gone: a few bare, drooping black stubs where each tier was
			var a0 := rng.randf() * TAU
			for j in 3:
				var out := Vector3(cos(a0 + TAU * j / 3.0), 0, sin(a0 + TAU * j / 3.0))
				var base := Vector3(0, y + h * 0.4, 0)
				_bark(bake, base, base + out * r * rng.randf_range(0.35, 0.6) + Vector3(0, -0.25, 0), 0.05, 0.012, C_CHAR)
			continue
		# (drawn in this order: where the tier sits, how it leans, how wide, its colour)
		var pos := Vector3(rng.randf_range(-0.06, 0.06), y + h * 0.5, rng.randf_range(-0.06, 0.06))
		var rot := Vector3(rng.randf_range(-0.07, 0.07), rng.randf() * TAU, rng.randf_range(-0.07, 0.07))
		var scl := Vector3(r * rng.randf_range(0.9, 1.1), h, r * rng.randf_range(0.9, 1.1))
		bake.part(Res.cyl(0.04, 1.0, 1.0, 9), Mats.foliage(), Mats.place(pos, rot, scl), Res.vary(needles, 0.05, rng).darkened(0.12 * (1.0 - t)))


static func _bark(bake: Mats.Bake, a: Vector3, b: Vector3, r0: float, r1: float, col: Color) -> void:
	if _snag:
		col = C_CHAR
	var y := b - a
	var L := y.length()
	y /= L
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_bark_part(bake, Res.cyl(r1, r0, 1.0, 7), Transform3D(Basis(x, y * L, z), (a + b) * 0.5), col)


## A piece of trunk or limb, in bark tinted towards `col` (Mats.apply's tint).
static func _bark_part(bake: Mats.Bake, mesh: Mesh, xf: Transform3D, col: Color) -> void:
	var tint := Mats.tint_for("bark", col)
	bake.part(mesh, Mats.get_mat("bark"), xf, tint if tint != Color(1, 1, 1) else null)


static func _leaves(bake: Mats.Bake, p: Vector3, r: float, squash: float, col: Color) -> void:
	if _snag:
		return
	bake.part(Res.sphere(1.0, 10), Mats.foliage(), Mats.place(p, Vector3.ZERO, Vector3(r, r * squash, r)), col)


## A house roof: tiled and pitched (ridge along the long side, gable ends in
## the walls' colour, eaves) or flat with a parapet and the clutter people put
## on flat roofs. variant: colour index * 2 + style.
func _roof_model(rng: RandomNumberGenerator) -> void:
	var wall_col: Color = HOUSE_COLORS[(variant / 2) % HOUSE_COLORS.size()]
	var h := size.y
	var long_x := size.x >= size.z
	var L := size.x if long_x else size.z
	var W := size.z if long_x else size.x
	var holder := Node3D.new()
	model.add_child(holder)
	if not long_x:
		holder.rotation.y = PI * 0.5
	var ov := 0.35
	if variant % 2 == 0:
		var rise := W * 0.5 * tan(deg_to_rad(28.0))
		var slope := Vector2(W * 0.5 + ov, rise + ov * tan(deg_to_rad(28.0))).length()
		var ang := atan2(rise, W * 0.5)
		var tint := Res.vary(Color(0.5, 0.22, 0.14), 0.12, rng) if rng.randf() < 0.75 else Color(0.36, 0.34, 0.32)
		for s in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.mesh = Res.box(Vector3(L + ov * 2.0, 0.09, slope))
			mi.position = Vector3(0, h + rise * 0.5 - ov * 0.25, s * (W * 0.25 + ov * 0.1))
			mi.rotation = Vector3(s * ang, 0, 0)
			holder.add_child(mi)
			Mats.apply(mi, "roof_tile", Mats.tint_for("roof_tile", tint))
		# gable ends
		for e in [-1.0, 1.0]:
			var g := MeshInstance3D.new()
			g.mesh = Res.prism(Vector3(W, rise, 0.25))
			g.position = Vector3(e * (L * 0.5 - 0.12), h + rise * 0.5, 0)
			g.rotation = Vector3(0, PI * 0.5, 0)
			holder.add_child(g)
			Mats.apply(g, "plaster", Mats.tint_for("plaster", wall_col))
		var rd := MeshInstance3D.new()
		rd.mesh = Res.box(Vector3(L + ov * 2.0, 0.12, 0.22))
		rd.position = Vector3(0, h + rise + 0.03, 0)
		holder.add_child(rd)
		Mats.apply(rd, "roof_tile", Mats.tint_for("roof_tile", tint.darkened(0.2)))
		if rng.randf() < 0.6:
			var ch := MeshInstance3D.new()
			ch.mesh = Res.box(Vector3(0.6, 1.2, 0.6))
			ch.position = Vector3(rng.randf_range(-L * 0.3, L * 0.3), h + rise * 0.7, W * 0.18)
			holder.add_child(ch)
			Mats.apply(ch, "brick")
	else:
		var slab := MeshInstance3D.new()
		slab.mesh = Res.box(Vector3(L + 0.1, 0.2, W + 0.1))
		slab.position = Vector3(0, h + 0.1, 0)
		holder.add_child(slab)
		Mats.apply(slab, "concrete", Mats.tint_for("concrete", Color(0.52, 0.5, 0.47)))
		for e in [-1.0, 1.0]:
			for side in [0, 1]:
				var p := MeshInstance3D.new()
				p.mesh = Res.box(Vector3(L + 0.1, 0.55, 0.18) if side == 0 else Vector3(0.18, 0.55, W + 0.1))
				p.position = Vector3(0, h + 0.47, e * (W * 0.5 - 0.04)) if side == 0 else Vector3(e * (L * 0.5 - 0.04), h + 0.47, 0)
				holder.add_child(p)
				Mats.apply(p, "plaster", Mats.tint_for("plaster", wall_col))
		# what's up there: a water tank, an air conditioner, a dish, washing
		if rng.randf() < 0.65:
			var tank := MeshInstance3D.new()
			tank.mesh = Res.cyl(0.45, 0.45, 1.0, 12)
			tank.position = Vector3(rng.randf_range(-L * 0.3, L * 0.3), h + 0.75, rng.randf_range(-W * 0.25, W * 0.25))
			holder.add_child(tank)
			Mats.apply(tank, "paint", Mats.tint_for("paint", [Color(0.15, 0.17, 0.2), Color(0.75, 0.75, 0.72), Color(0.3, 0.42, 0.55)][rng.randi() % 3]))
		if rng.randf() < 0.6:
			var ac := MeshInstance3D.new()
			ac.mesh = Res.box(Vector3(0.8, 0.55, 0.5))
			ac.position = Vector3(rng.randf_range(-L * 0.35, L * 0.35), h + 0.47, rng.randf_range(-W * 0.3, W * 0.3))
			holder.add_child(ac)
			Mats.apply(ac, "paint", Mats.tint_for("paint", Color(0.78, 0.78, 0.75)))
		if rng.randf() < 0.45:
			var dish := MeshInstance3D.new()
			dish.mesh = Res.cyl(0.38, 0.05, 0.12, 12)
			dish.position = Vector3(L * 0.35, h + 0.75, -W * 0.3)
			dish.rotation = Vector3(-0.9, 0.6, 0)
			holder.add_child(dish)
			Mats.apply(dish, "paint", Mats.tint_for("paint", Color(0.82, 0.82, 0.8)))


var _roof_t := 0.0


## A roof is hidden while anyone is inside (so you can see your men), and
## comes back when they leave.
func _roof_view(dt: float) -> void:
	_roof_t -= dt
	if _roof_t > 0.0:
		return
	_roof_t = 0.25
	var inside := false
	var half := Vector2(size.x * 0.5 + 0.3, size.z * 0.5 + 0.3)
	for s in world.soldiers_near(position, half.length()):
		if s.visible and s.life != Soldier.Life.HIDDEN and Defs.point_in_obb(Vector2(s.position.x, s.position.z), Vector2(position.x, position.z), half, yaw):
			inside = true
			break
	if model.visible == inside:
		model.visible = not inside


## Lays the model at its tilt, resting on the ground (on its side, on its roof...).
func _apply_tilt() -> void:
	if model == null:
		return
	if tilt == Vector2.ZERO:
		if skind in ["car", "crates", "wreck"]:
			model.transform = Transform3D.IDENTITY
		return
	var b := Basis.from_euler(Vector3(tilt.x, 0, tilt.y))
	var lo := INF
	for cx in [-0.5, 0.5]:
		for cy in [0.0, 1.0]:
			for cz in [-0.5, 0.5]:
				lo = minf(lo, (b * Vector3(cx * size.x, cy * size.y, cz * size.z)).y)
	model.transform = Transform3D(b, Vector3(0, -lo, 0))


## The clients fly the model from where it was to where it is now.
func _start_toss() -> void:
	if toss == null or model == null or world.phys == null:
		return
	var tz: Array = toss
	var from_xf := Transform3D(Basis(Vector3.UP, float(tz[1])), tz[0])
	var mass: float = (float(Defs.VEHICLES[vk].get("mass", [2500.0, 16000.0, 42000.0][int(Defs.VEHICLES[vk].get("weight", 1))])) if Defs.VEHICLES.has(vk) else 2500.0) if skind != "crates" else 300.0
	world.phys.toss(self, model, from_xf, tz[2], tz[3], Vector3(size.x, maxf(size.y, 0.8), size.z), mass)


## A big blast close by throws a car or a stack of crates across the ground:
## it lands somewhere else, maybe on its side or its roof, and the cover it gave
## goes with it.
func toss_from(bp: Vector3, bsize: float) -> void:
	if gone or not srv or not skind in ["car", "crates"]:
		return
	var rng := world.rng
	var away := Defs.flat(position - bp)
	var dist := away.length()
	away = away.normalized() if dist > 0.1 else Defs.dir_of(rng.randf() * TAU)
	var pw := clampf(bsize * (1.0 - dist / (4.0 + bsize * 3.0)) / 2.6, 0.0, 1.0)
	if pw < 0.15:
		return
	var light := skind == "crates"
	var up := lerpf(3.0, 9.0 if light else 7.0, pw)
	var out := lerpf(2.0, 7.0 if light else 5.0, pw)
	var t_air := 2.0 * up / 19.6
	var dest := position + away * out * t_air
	if not Defs.in_map(dest, 4.0) or not world.nav.walkable(dest):
		return
	var old_p := position
	var old_y := yaw
	var pitch := rng.randf_range(-0.08, 0.08)
	var roll := rng.randf_range(-0.08, 0.08)
	var r := rng.randf()
	if r < 0.35 * pw:
		roll = PI
	elif r < 0.7 * pw:
		roll = PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
	var dyaw := rng.randf_range(-1.3, 1.3) * pw
	world.nav.remove_structure(self)
	world.terrain.structure_changed(self, false)
	world._shash_remove(self)
	position = Vector3(dest.x, 0.0, dest.z)
	yaw = old_y + dyaw
	rotation.y = yaw
	tilt = Vector2(pitch, roll)
	world._shash_add(self)
	world.nav.add_structure(self)
	world.terrain.structure_changed(self, true)
	_compute_cover_pts()
	var axis := away.cross(Vector3.UP).normalized()
	var spin := -axis * (absf(roll) + 1.0) / maxf(t_air, 0.35) + Vector3.UP * dyaw / maxf(t_air, 0.35)
	toss = [old_p, old_y, away * out + Vector3.UP * up, spin]
	world.push_props(self, {"pos": position, "yaw": yaw, "tilt": tilt, "toss": toss})
	if world.has_view:
		_apply_tilt()
		_start_toss()
	world.get_tree().create_timer(3.0).timeout.connect(finish_toss)


func finish_toss() -> void:
	# A bound callback disconnects if its wreck or the preview is freed early.
	if not gone:
		toss = null
		world.push_props(self, {"toss": null})


## Destroyed. quiet: it burnt away (the fire's own collapse is the effect, no
## blast debris or rubble).
func _destroyed(quiet := false) -> void:
	if world.battle and team >= 0 and is_player_building():
		world.battle.building_destroyed(self)
	match skind:
		"fob":
			wrecked = true
			net_dirty = true
			world.send_msg(team, "alert", "FOB %s has been wrecked! Repair it with engineers." % sname, position)
			world.rules.on_fob_changed(team)
			return
		"tunnel":
			for s in inside:
				if is_instance_valid(s) and not s.gone:
					s.unhide(position + Vector3(world.rng.randf_range(-2, 2), 0, world.rng.randf_range(-2, 2)))
			inside.clear()
		"mg_nest", "watchtower":
			if gunner and not gunner.gone:
				gunner.release_mount()
		"ammo_cache":
			_cook_off()
	if skind == "tree":
		# blown over, away from the blast
		var away := Defs.flat(position - hit_from) if hit_from != Vector3.INF else Vector3.ZERO
		var fy := Defs.yaw_of(away) if away.length() > 0.2 else world.rng.randf() * TAU
		world.fx_event([Fx.DEBRIS, position + Vector3(0, 1.0, 0), _main_color(), 8])
		world.fx_event([Fx.TREE_FALL, position, fy, eid, variant])
		world.despawn(self)
		return
	if not quiet:
		world.fx_event([Fx.DEBRIS, position + Vector3(0, 1.0, 0), _main_color(), 14])
	if not quiet and size.x > 3.0 and skind in ["house_wall", "tall_wall", "barracks", "factory", "research", "concrete_wall", "medic_tent"]:
		world.fx_event([Fx.EXPLODE, position + Vector3(0, 0.5, 0), 0.6])
		var rub := Vector3(size.x * 0.8, 0, 1.6 if size.z < 2.0 else size.z * 0.6)
		world.call_deferred("spawn", "structure", {"skind": "rubble", "pos": position, "yaw": yaw, "size": rub})
	if team >= 0 and is_player_building():
		world.send_msg(team, "alert", "%s destroyed at %s." % [display_name(), Defs.grid_ref(position)], position)
	world.despawn(self)


## Builders and repairers call this. amount = work-seconds.
func add_work(amount: float) -> bool:
	if gone:
		return false
	if not built:
		var t: float = Defs.BUILDINGS[skind].time if Defs.BUILDINGS.has(skind) else 10.0
		progress = minf(1.0, progress + amount / t)
		hp = maxf(hp, max_hp * progress)
		net_dirty = true
		if progress >= 1.0:
			_complete()
		return true
	if burn > 0.0:
		fuel -= amount * 4.0  # engineers beat the flames out before they patch anything up
	if hp < max_hp:
		var t2: float = Defs.BUILDINGS[skind].time if Defs.BUILDINGS.has(skind) else 20.0
		hp = minf(max_hp, hp + amount * max_hp / (t2 * 0.8))
		net_dirty = true
		if wrecked and hp >= max_hp * 0.5:
			wrecked = false
			world.send_msg(team, "info", "FOB %s is back in action." % sname, position)
			world.rules.on_fob_changed(team)
		return true
	return false


func needs_work() -> bool:
	return not built or hp < max_hp - 1.0


func _complete() -> void:
	world.stat("built")
	world.stat("built_" + skind)
	built = true
	world.terrain.structure_changed(self, true)
	progress = 1.0
	hp = max_hp
	net_dirty = true
	_make_body()
	world.push_props(self, {"built": true, "progress": 1.0})
	world.rules.on_built(self)
	if world.has_view:
		_update_visual()


# --- simulation --------------------------------------------------------------------

func sim(dt: float) -> void:
	if (team < 0 and skind != "town") or not built:
		return
	_tick_t -= dt
	match skind:
		"fob":
			_fob_tick()
		"town":
			_town_tick(dt)
		"barracks", "factory", "research", "helipad", "dock":
			_prod_tick(dt)
		"medic_tent":
			_tent_tick()
		"mg_nest", "watchtower", "hmg_nest", "mortar_pit", "at_post":
			_mount_tick()
		"mines":
			_mine_tick()
		"ammo_cache":
			_cache_tick()


func _fob_tick() -> void:
	if _tick_t > 0.0:
		return
	_tick_t = 0.5
	var counts := [0, 0]
	for s in world.soldiers_near(position, Defs.FOB_RADIUS):
		if s.life == Soldier.Life.ALIVE and s.team >= 0 and s.team <= 1 and not s.is_bearer():
			counts[s.team] += 1
	var enemy := 1 - team
	var old := cap_prog
	if counts[enemy] > 0 and counts[team] == 0:
		# a side's last FOB is its last stand: four times slower to take
		var last := world.rules.fobs(team).size() <= 1
		if cap_team != enemy:
			cap_team = enemy
			cap_prog = 0.0
			world.send_msg(team, "alert", ("LAST STAND: FOB %s is being captured! Lose it and we lose the battle." if last else "FOB %s is being captured!") % sname, position)
			if last:
				world.fx_event([Fx.SUPPORT, position, 20.0])
		cap_prog += (2.0 + minf(counts[enemy], 6)) * (0.25 if last else 1.0)
		if cap_prog >= 100.0:
			cap_prog = 0.0
			cap_team = -1
			world.rules.capture_fob(self, enemy)
			return
	elif counts[team] > 0:
		cap_prog = maxf(0.0, cap_prog - 8.0)
	else:
		cap_prog = maxf(0.0, cap_prog - 3.0)
	if cap_prog <= 0.0:
		cap_team = -1
	if cap_prog != old:
		net_dirty = true
	if not wrecked:
		for s in world.soldiers_near(position, Defs.FOB_RADIUS + 2.0):
			if s.team == team and s.life == Soldier.Life.ALIVE:
				s.resupply(0.5)


## A town or village. Whoever has men on its ground while the other side has
## none takes it - a squad holding a village for half a minute, the town for
## nearer a minute; both there, nobody gains; the holder's men there win it
## back. Whoever holds it draws supply from it into the dump for the trucks
## to take away - less the more of it lies in ruins - and their men round the
## dump fill their pouches from it.
func _town_tick(dt: float) -> void:
	var k := clampi(variant, 0, 1)
	if team >= 0:
		var full := float(Defs.TOWN_STOCK[k])
		if supply < full:
			var was := int(supply)
			supply = minf(full, supply + float(Defs.TOWN_YIELD[k]) / 60.0 * dt * town_yield_factor())
			if int(supply) != was:
				net_dirty = true
	if _tick_t > 0.0:
		return
	_tick_t = 0.5
	_house_t -= 0.5
	if _house_t <= 0.0:
		_house_t = 10.0
		_count_houses()
	var counts := [0, 0]
	for s in world.soldiers_near(zone_c, zone_r):
		if s.life == Soldier.Life.ALIVE and s.team >= 0 and s.team <= 1 and not s.is_bearer():
			counts[s.team] += 1
	var old := cap_prog
	var taker := -1
	for t in 2:
		if counts[t] > 0 and counts[1 - t] == 0 and team != t:
			taker = t
	if taker >= 0:
		if cap_team != taker:
			cap_team = taker
			cap_prog = 0.0
			if team >= 0 and world.time > _alert_t:
				_alert_t = world.time + 30.0
				world.send_msg(team, "alert", "%s is being taken! The enemy is in the %s." % [sname, "town" if k == 1 else "village"], zone_c)
		cap_prog += (0.8 + minf(counts[taker], 8) * 0.45) * float(Defs.TOWN_PACE[k]) * 0.5
		if cap_prog >= 100.0:
			cap_prog = 0.0
			cap_team = -1
			world.rules.capture_town(self, taker)
			return
	elif counts[0] == 0 or counts[1] == 0:
		cap_prog = maxf(0.0, cap_prog - (4.0 if team >= 0 and counts[team] > 0 else 1.5))
	if cap_prog <= 0.0:
		cap_team = -1
	if cap_prog != old:
		net_dirty = true
	if team >= 0:
		for s in world.soldiers_near(position, 9.0):
			if s.team == team and s.life == Soldier.Life.ALIVE:
				s.resupply(0.5)


## How much a town gives for what's left of it: a third of its worth from the
## ruins alone, the rest from the houses still standing.
func town_yield_factor() -> float:
	return 0.35 + 0.65 * intact


## Supply a minute the place gives its holder now.
func town_rate() -> float:
	return float(Defs.TOWN_YIELD[clampi(variant, 0, 1)]) * town_yield_factor()


func _count_houses() -> void:
	var n := 0
	for st in world.structures_near(zone_c, zone_r):
		if st.skind == "roof" and Defs.flat(st.position - zone_c).length() <= zone_r:
			n += 1
	if houses0 < 0:
		houses0 = n
	var f := clampf(float(n) / float(houses0), 0.0, 1.0) if houses0 > 0 else 1.0
	if absf(f - intact) > 0.003:
		intact = f
		net_dirty = true


func queue_item(peer: int, item: String) -> void:
	if not built or skind == "research":
		return
	var prods: Array = Defs.BUILDINGS[skind].produces[team]
	if not item in prods or queue.size() >= 6:
		return
	var def: Dictionary = Defs.SQUADS[item] if Defs.SQUADS.has(item) else Defs.VEHICLES[item]
	var need := world.rules.tier_needed(team, item)
	if need != "":
		world.rules.notify(peer, team, "%s needs research first: %s." % [def.name, need])
		return
	if not world.rules.spend(team, position, def.cost):
		world.rules.notify(peer, team, "Not enough supply at a nearby FOB for %s (%d)." % [def.name, def.cost])
		return
	world.battle.spent(peer, team, def.cost)
	queue.append({"item": item, "t": float(def.time), "total": float(def.time), "owner": peer, "cost": def.cost})
	_queue_changed()


func queue_research(peer: int, item: String) -> void:
	if not built or skind != "research" or not Defs.UPGRADES.has(item):
		return
	var def: Dictionary = Defs.UPGRADES[item]
	if not team in def.teams or world.rules.has_upgrade(team, item) or queue.size() >= 4:
		return
	if def.has("requires") and not world.rules.has_upgrade(team, String(def.requires)):
		world.rules.notify(peer, team, "%s needs %s first." % [def.name, Defs.item_name(String(def.requires))])
		return
	for q in queue:
		if q.item == item:
			return
	if not world.rules.spend(team, position, def.cost):
		world.rules.notify(peer, team, "Not enough supply for %s (%d)." % [def.name, def.cost])
		return
	world.battle.spent(peer, team, def.cost)
	queue.append({"item": item, "t": float(def.time), "total": float(def.time), "owner": peer, "cost": def.cost})
	_queue_changed()


func cancel_last(_peer: int) -> void:
	if queue.is_empty():
		return
	var q: Dictionary = queue.pop_back()
	world.rules.refund(team, position, int(q.cost))
	world.battle.spent(int(q.owner), team, -int(q.cost))
	_queue_changed()


func _queue_changed() -> void:
	queue_items = []
	for q in queue:
		queue_items.append(q.item)
	net_dirty = true
	world.push_props(self, {"queue": queue_items})


func _prod_tick(dt: float) -> void:
	if queue.is_empty():
		if queue_frac != 0.0:
			queue_frac = 0.0
			net_dirty = true
		return
	var q: Dictionary = queue[0]
	if skind != "research":
		var capn := 0
		if Defs.SQUADS.has(q.item):
			capn = (Defs.SQUADS[q.item].members as Array).size()
		else:
			capn = int(Defs.VEHICLES[q.item].cap)
		if not world.rules.has_cap(team, capn):
			if prod_status != "cap":
				prod_status = "cap"
				world.rules.notify(int(q.owner), team, "Unit cap reached. Build another FOB to raise it.")
			return
	prod_status = ""
	q.t -= dt
	var f: float = 1.0 - q.t / q.total
	if absf(f - queue_frac) > 0.02:
		queue_frac = f
		net_dirty = true
	if q.t > 0.0:
		return
	queue.pop_front()
	_queue_changed()
	# (ordered by someone who has since left: whoever took over their forces
	# gets it, and it goes back to them if they rejoin)
	var by := int(q.owner)
	var owner := world.acting_owner(by, team)
	world.battle.fielded(owner, team, String(q.item))
	if skind == "research":
		world.rules.apply_upgrade(team, String(q.item))
		return
	var dest := rally if rally != Vector3.INF else exit_pos() + front_dir() * 8.0
	if Defs.SQUADS.has(q.item):
		world.hold_for(by, world.rules.spawn_squad(String(q.item), team, owner, exit_pos(), dest))
	else:
		var heli: bool = Defs.VEHICLES.has(q.item) and Defs.VEHICLES[q.item].get("air", false)
		var spawn_at: Vector3 = position if heli else world.nav.nearest_walkable(exit_pos() + front_dir() * 2.0, true)
		if String(Defs.VEHICLES.get(q.item, {}).get("base", "")) == "boat":
			# off the end of the jetty
			spawn_at = world.nav.nearest_boat(position + front_dir() * (size.z * 0.5 + 16.0), 50.0)
			if spawn_at == Vector3.INF:
				spawn_at = position + front_dir() * (size.z * 0.5 + 16.0)
			dest = rally if rally != Vector3.INF else spawn_at + front_dir() * 14.0
		var v = world.spawn("vehicle", {"vkind": q.item, "team": team, "owner": owner, "pos": spawn_at, "yaw": yaw})
		if heli:
			v.heli_home = self
			if not v.vdef.get("supply", false):
				v.embark_new_squad()  # a troop helicopter comes with its section aboard
			if v.base() == "uav":
				v.order_move(dest)
		else:
			v.embark_new_squad()
			v.order_move(dest)
		world.hold_for(by, v)
	world.send_msg(team, "info", "%s ready." % Defs.item_name(String(q.item)), null)


func _tent_tick() -> void:
	if _tick_t > 0.0:
		return
	_tick_t = 1.0
	var keep := []
	for b in bearers:
		if is_instance_valid(b) and not b.gone and b.life != Soldier.Life.DEAD and b.team == team:
			keep.append(b)
	bearers = keep
	if bearers.size() < 2:
		bearer_t -= 1.0
		if bearer_t <= 0.0:
			bearer_t = 25.0
			var s: Soldier = world.spawn("soldier", {"utype": "bearer", "team": team, "owner": -1 - team, "pos": exit_pos(), "name": world.rules.random_name(team)})
			s.home = self
			bearers.append(s)
	var idle := []
	for b in bearers:
		if b.life == Soldier.Life.ALIVE and b.task == "":
			idle.append(b)
	if idle.size() >= 2 or (idle.size() == 1 and bearers.size() == 1):
		var cas: Soldier = world.rules.find_casualty(team, position, 120.0)
		if cas:
			var partner: Soldier = idle[1] if idle.size() > 1 else null
			idle[0].start_stretcher(cas, partner, self, true)
			if partner:
				partner.start_stretcher(cas, idle[0], self, false)
			cas.stretcher_claimed = true


func _mount_tick() -> void:
	if _tick_t > 0.0:
		return
	_tick_t = 0.7
	if gunner and (gunner.gone or gunner.life != Soldier.Life.ALIVE or gunner.task != "man" or gunner.task_ent != self):
		gunner = null
	if gunner == null:
		var best: Soldier = null
		var bd := 6.5
		var pref := mount_pref()
		for s in world.soldiers_near(position, 6.5):
			if s.team != team or s.life != Soldier.Life.ALIVE or s.task != "" or s.is_bearer() or s.is_moving():
				continue
			var d: float = Defs.flat(s.position - position).length() - (4.0 if s.utype in pref else 0.0)
			if d < bd:
				bd = d
				best = s
		if best:
			best.start_man(self)
			gunner = best
	var up: bool = skind == "watchtower" and gunner != null and gunner.task_phase == 2
	if up != manned:
		manned = up
		net_dirty = true
		if up:
			world.stat("tower_manned")


func _mine_tick() -> void:
	if _tick_t > 0.0:
		return
	_tick_t = 0.2
	for u in world.units_near(position, 2.6):
		if u.team == team or u.team < 0:
			continue
		if u is Soldier and u.life != Soldier.Life.ALIVE:
			continue
		var at := u is Vehicle
		world.combat.explode(position + Vector3(0, 0.2, 0), {"dmg": 150.0, "radius": 4.0, "fling": 9.0, "at": 520.0 if at else 0.0, "team": team, "src": null, "by": owner_peer, "track": 0.85, "size": 1.0})
		world.despawn(self)
		return


## An ammo cache: every man of its side round it tops up his pouches -
## magazines, grenades, rockets, mortar bombs - till it's empty, and then
## there's nothing left of it but the pallets.
func _cache_tick() -> void:
	if _tick_t > 0.0:
		return
	_tick_t = 0.5
	var was := int(supply)
	for s in world.soldiers_near(position, CACHE_REACH):
		if s.team != team or s.life != Soldier.Life.ALIVE or s.is_bearer():
			continue
		if s.ammo_fraction() >= 0.98 and s.frags >= int(s.udef.frags):
			continue
		s.resupply(0.5)
		supply -= 0.5
		world.stat("cache_draw")
	if int(supply) != was:
		net_dirty = true
	if supply <= 0.0:
		supply = 0.0
		world.send_msg(team, "info", "The ammo cache at %s is empty." % Defs.grid_ref(position), position)
		world.stat("cache_empty")
		world.despawn(self)


## Hit hard enough to wreck it, the stores go up: a blast, then rounds and
## grenades cooking off in all directions for a while.
func _cook_off() -> void:
	var left := clampf(supply / CACHE_STOCK, 0.2, 1.0)
	var at := position + Vector3(0, 0.6, 0)
	world.stat("cache_cook_off")
	var w := world
	# (once it's gone: the blast mustn't find the cache it came from)
	for i in int(4 + 5 * left):
		var big := i == 0
		var p := at if big else at + Vector3(w.rng.randf_range(-1.5, 1.5), 0.0, w.rng.randf_range(-1.5, 1.5))
		var d := {"dmg": 90.0 * left + 40.0, "radius": 4.0 + 2.0 * left, "fling": 8.0, "at": 60.0, "src": null, "size": 1.2 + left} if big \
			else {"dmg": 35.0, "radius": 2.5, "fling": 4.0, "src": null, "size": 0.5}
		w.get_tree().create_timer(0.05 if big else 0.5 + i * w.rng.randf_range(0.35, 0.9), false).timeout.connect(func():
			if is_instance_valid(w) and w.combat:
				w.combat.explode(p, d))


# --- replication ------------------------------------------------------------------

func write_state(b: StreamPeerBuffer) -> void:
	b.put_u16(int(clampf(hp / maxf(1.0, max_hp), 0.0, 1.0) * 65535.0))
	b.put_u8(int(progress * 255.0))
	b.put_8(team)
	b.put_u8(int(clampf(cap_prog, 0.0, 100.0)))
	b.put_8(cap_team)
	var private: bool = world.writing_view >= 0 and world.writing_view != team and team >= 0
	b.put_u16(0 if private else int(clampf(supply, 0.0, 65535.0)))
	b.put_u8((1 if built else 0) | (2 if wrecked else 0) | (4 if prod_status == "cap" else 0) | (8 if door_shut else 0) | (16 if _door_kicked else 0) | (32 if manned else 0))
	b.put_u8(vis_mask)
	b.put_u8(seen_mask)
	b.put_u8(0 if private else int(clampf(queue_frac, 0.0, 1.0) * 255.0))
	b.put_u8(0 if private else mini(255, inside.size()))
	b.put_u8(int(clampf(burn, 0.0, 1.0) * 255.0))
	if skind == "town":
		b.put_u8(int(clampf(intact, 0.0, 1.0) * 255.0))


func read_state(b: StreamPeerBuffer) -> void:
	hp = b.get_u16() / 65535.0 * max_hp
	progress = b.get_u8() / 255.0
	var t := b.get_8()
	cap_prog = b.get_u8()
	cap_team = b.get_8()
	supply = b.get_u16()
	var f := b.get_u8()
	vis_mask = b.get_u8()
	seen_mask = b.get_u8()
	queue_frac = b.get_u8() / 255.0
	inside_n = b.get_u8()
	var nb := b.get_u8() / 255.0
	if nb != burn:
		if OS.has_environment("FL_DEBUG_FIRE") and (nb <= 0.0) != (burn <= 0.0):
			print("FIRE client %s %d %s" % [skind, eid, "alight" if nb > 0.0 else "out"])
		burn = nb
		_burn_view()
	if skind == "town":
		intact = b.get_u8() / 255.0
	var was_built := built
	built = (f & 1) != 0
	wrecked = (f & 2) != 0
	prod_status = "cap" if (f & 4) != 0 else ""
	manned = (f & 32) != 0
	if door_shut and (f & 8) == 0:
		open_door(null, (f & 16) != 0)
	if t != team:
		team = t
		_recolor()
	if was_built != built or not built:
		_update_visual()
	if built and not was_built and not srv and world.has_view and view_active:
		_make_body()
	if built != was_built and world.terrain:
		world.terrain.structure_changed(self, true)


# --- visuals -----------------------------------------------------------------------

func _process(_dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(_dt)
	if world:
		world.vp("structures", _t0)


func _view_process(_dt: float) -> void:
	if not world.has_view or not view_active or model == null:
		return
	if burn > 0.0 or _fire_fx:
		_fire_view(_dt)
	if skind == "roof":
		_roof_view(_dt)
		return
	var v := true
	var lt := world.view_team
	if team >= 0 and lt >= 0 and team != lt:
		v = ((seen_mask >> lt) & 1) == 1
		if skind == "mines":
			v = false
	if v != _vis_cache:
		_vis_cache = v
		visible = v
	if not built:
		_update_visual()
	elif skind in SMOKE_KINDS:
		_damage_view()


var _scaffold: Node3D
const SCAFFOLD_KINDS := ["barracks", "factory", "research", "medic_tent", "fob", "bunker", "helipad", "watchtower", "depot"]


## Construction sites: the building rises out of the ground inside timber
## scaffolding on a dirt foundation; small defences just rise into place.
const SMOKE_KINDS := ["barracks", "factory", "research", "medic_tent", "fob", "bunker", "depot", "helipad", "watchtower"]
var _damage_fx: Node3D
var _dmg_state := 0


## Damaged buildings smoke; badly damaged or wrecked ones burn.
func _damage_view() -> void:
	var f := hp / maxf(1.0, max_hp)
	var st := 0 if f > 0.55 else (1 if f > 0.3 else 2)
	if wrecked:
		st = 2
	if st == _dmg_state:
		return
	_dmg_state = st
	if st > 0 and _damage_fx == null and world.fx and world.fx.vfx:
		_damage_fx = world.fx.vfx.make_burner(1.2 if skind in ["factory", "barracks", "fob", "depot"] else 0.8)
		_damage_fx.position = Vector3(foot.x * 0.3, minf(_vis_height() * 0.8, 4.5), -foot.y * 0.2)
		add_child(_damage_fx)
	if _damage_fx:
		world.fx.vfx.set_burning(_damage_fx, [0.0, 0.0, 0.7][st], [0.0, 0.45, 1.0][st])


# --- fire --------------------------------------------------------------------------

## What it burns as (a key of Fires.FUEL), or "" if it won't burn: wood, cloth
## and fuel do; stone, brick, concrete, earth, sandbags and steel don't.
func fire_kind() -> String:
	if burnt or not built or gone:
		return ""
	match skind:
		"tree", "crates", "watchtower", "medic_tent", "barracks":
			return skind
		"car":
			return "car" if variant < 6 else ""
		"wreck", "rubble":
			return "wreck" if variant >= 6 else ""
		"low_wall":
			return "hedge" if variant % 3 == 1 else ""
		"roof":
			return "roof" if variant % 2 == 0 else ""  # pitched roofs are tiles on timber; flat ones are concrete
		"bunker":
			return "log_bunker" if team == 1 else ""
		"ammo_cache":
			return "crates"  # (and when it's burnt through, it cooks off)
		"camo_net", "barricade":
			return skind
	return ""


## (server) How hard it's burning now; clients hear of it in the snapshots.
func set_burn(b: float) -> void:
	if int(b * 24.0) != int(burn * 24.0) or (b <= 0.0) != (burn <= 0.0):
		net_dirty = true
	burn = b
	if world.has_view:
		_burn_view()


## (server) The fire has taken it: it falls in, leaving ash and a scorch mark.
func burned_down() -> void:
	if gone:
		return
	var box := _fire_box()
	world.fx_event([Fx.BURNT_OUT, to_global(box[0]), box[1], yaw])
	world.stat("burnt_down")
	_destroyed(true)


## (server) Burnt out, and what's left still stands: a tree's bare black snag,
## a car's burnt-out shell. It won't burn again.
func char_out() -> void:
	if burnt or gone:
		return
	burnt = true
	match skind:
		"tree":
			variant |= 16
		"car":
			variant += 6
	net_dirty = true
	world.push_props(self, {"burnt": true, "variant": variant})
	world.stat("burnt_out")
	if world.has_view and model:
		_rebuild_model()


## (view) A tree or a car rebuilt as what the fire left of it.
func _rebuild_model() -> void:
	if world and world.structure_view:
		world.structure_view.unbatch(self)
	if not skind in ["tree", "car"]:
		return
	model.queue_free()
	_char_mats.clear()
	_build_model()
	_apply_tilt()
	model.visible = view_active
	_char = 0.0  # (built charred black already)
	_char_set = -1.0


## (view) Where the flames are: [centre (local), half extents].
func _fire_box() -> Array:
	match skind:
		"tree":
			if variant & 1:
				return [Vector3(0, 2.6, 0), Vector3(1.1, 1.3, 1.1)]
			return [Vector3(0, 3.8, 0), Vector3(1.4, 2.3, 1.4)]
		"low_wall":
			return [Vector3(0, 0.6, 0), Vector3(size.x * 0.48, 0.5, 0.35)]
		"crates":
			return [Vector3(0, 0.7 if variant == 0 else 1.1, 0), Vector3(foot.x * 0.8, 0.6 if variant == 0 else 1.0, foot.y * 0.8)]
		"watchtower":
			return [Vector3(0, 3.6, 0), Vector3(1.4, 3.0, 1.4)]
		"roof":
			return [Vector3(0, size.y + 1.0, 0), Vector3(size.x * 0.4, 0.9, size.z * 0.4)]
		"car":
			return [Vector3(0, 0.9, 0.3), Vector3(0.75, 0.45, 1.5)]
		"wreck", "rubble":
			var ws := size if size != Vector3.ONE else Vector3(3.4, 2.0, 6.2)
			return [Vector3(0, ws.y * 0.6, 0), Vector3(ws.x * 0.32, ws.y * 0.35, ws.z * 0.3)]
		"bunker":
			return [Vector3(0, 2.7, 0), Vector3(2.4, 0.4, 2.4)]
		"camo_net":
			return [Vector3(0, 2.0, 0), Vector3(2.6, 0.45, 2.6)]
		"barricade":
			return [Vector3(0, 0.7, 0), Vector3(size.x * 0.45, 0.45, 0.35)]
		"ammo_cache":
			return [Vector3(0, 0.8, 0.15), Vector3(1.1, 0.5, 0.5)]
	return [Vector3(0, minf(_vis_height(), 3.0) * 0.5, 0), Vector3(foot.x * 0.8, minf(_vis_height(), 3.0) * 0.45, foot.y * 0.8)]


## (view) The flames follow the burn: lit, roaring, dying down, then smoke
## drifting off what's left.
func _burn_view() -> void:
	if not world.has_view or not view_active or model == null or world.fx == null or world.fx.vfx == null:
		return
	var lvl := int(burn * 24.0)
	if lvl == _fire_shown:
		return
	var was := _fire_shown
	_fire_shown = lvl
	if burn > 0.0:
		set_process(true)
		if _fire_fx == null:
			var box := _fire_box()
			var smoke := Vfx.SMOKE_FUEL if skind in ["car", "wreck", "rubble", "barricade"] else (Vfx.SMOKE_LEAVES if skind == "tree" or (skind == "low_wall") else Vfx.SMOKE_WOOD)
			_fire_fx = world.fx.vfx.make_fire(box[1], smoke)
			world.fx.vfx.add_child(_fire_fx)
			_fire_fx.global_transform = Transform3D(Basis(Vector3.UP, yaw), to_global(box[0]))
		world.fx.vfx.set_fire(_fire_fx, burn)
	elif _fire_fx and was > 0:
		# out: it smoulders a while, then the smoke thins away
		world.fx.vfx.smoulder(_fire_fx, 45.0 if skind in ["wreck", "rubble", "car"] else 30.0)
		_fire_fx = null


## (view) While it burns it chars, and the char glows with embers.
func _fire_view(dt: float) -> void:
	if burn > 0.0:
		_char = minf(1.0, _char + dt * burn / 32.0)
	if absf(_char - _char_set) > 0.02 or absf(burn - _glow_set) > 0.04:
		_apply_char(burn)
	if burn <= 0.0 and _fire_fx == null and team < 0 and not skind in SMOKE_KINDS and skind != "roof":
		set_process(false)


var _char_set := -1.0
var _glow_set := -1.0


## (view) Lays the char (and the glow of the embers in it) over the model:
## leaves brown, blacken and burn away; wood, cloth and paint go black.
func _apply_char(glow: float) -> void:
	if world and world.structure_view:
		world.structure_view.unbatch(self)
	if model == null:
		return
	_char_set = _char
	_glow_set = glow
	if _char_mats.is_empty() and (_char > 0.0 or glow > 0.0):
		var fol := Mats.foliage().shader
		var stack: Array = [model]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var sm := mi.material_override as ShaderMaterial
			if sm != null and sm.shader == fol:
				var own := sm.duplicate() as ShaderMaterial
				mi.material_override = own
				_char_mats.append([own, true])
			else:
				var ov := world.fx.vfx.char_material()
				mi.material_overlay = ov
				_char_mats.append([ov, false])
	for cm in _char_mats:
		var m: ShaderMaterial = cm[0]
		if cm[1]:
			m.set_shader_parameter("scorch", minf(1.0, _char * 1.8))  # leaves go long before the wood
			m.set_shader_parameter("embers", glow)
		else:
			m.set_shader_parameter("amount", _char)
			m.set_shader_parameter("glow", glow * _char)


func _update_visual() -> void:
	if world and world.structure_view:
		world.structure_view.unbatch(self)
	if model == null:
		return
	if skind == "trench":
		model.position.y = 0.0
		var site := model.get_node_or_null("Site")
		var done := model.get_node_or_null("Done")
		if site:
			site.visible = not built
			for i in 3:
				var pl := site.get_node_or_null("Pile%d" % i) as Node3D
				if pl:
					pl.scale = Vector3(1.4, 0.55, 0.9) * clampf(progress * 1.4, 0.15, 1.0)
		if done:
			done.visible = built
		return
	if built:
		model.position.y = 0.0
		model.scale = Vector3.ONE
		if _scaffold:
			_scaffold.queue_free()
			_scaffold = null
			if world.fx:
				world.fx.play([Fx.MELEE, position + Vector3(0, 0.5, 0)])
	else:
		var h := _vis_height()
		model.position.y = -(1.0 - clampf(progress, 0.0, 1.0)) * (h + 0.3)
		if _scaffold == null and skind in SCAFFOLD_KINDS:
			_build_scaffold(h)


## Which local side (+-z) of a trench faces the enemy.
func _enemy_side() -> float:
	var enemy := Vector3(0, 0, -1) if team == 0 else Vector3(0, 0, 1)
	var lz := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	return 1.0 if lz.dot(enemy) > 0.0 else -1.0


func _vis_height() -> float:
	match skind:
		"factory":
			return 6.2
		"watchtower":
			return 7.0
		"barracks", "research":
			return 4.5
		"fob":
			return 3.5
		"helipad":
			return 0.3
	return maxf(1.0, size.y)


func _build_scaffold(h: float) -> void:
	_scaffold = Node3D.new()
	add_child(_scaffold)
	var hx := foot.x + 0.45
	var hz := foot.y + 0.45
	var wood := Mats.get_mat("wood")
	var dirt := MeshInstance3D.new()
	dirt.mesh = Res.box(Vector3(hx * 2.0 + 0.6, 0.06, hz * 2.0 + 0.6))
	dirt.material_override = Mats.get_mat("earth")
	dirt.position.y = 0.03
	dirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scaffold.add_child(dirt)
	if skind == "helipad":
		return
	var ph := h + 0.7
	var nx := maxi(1, int(ceil(hx * 2.0 / 2.6)))
	var nz := maxi(1, int(ceil(hz * 2.0 / 2.6)))
	var posts := []
	for i in nx + 1:
		var x := -hx + i * (hx * 2.0 / nx)
		posts.append(Vector3(x, 0, -hz))
		posts.append(Vector3(x, 0, hz))
	for i in range(1, nz):
		var z := -hz + i * (hz * 2.0 / nz)
		posts.append(Vector3(-hx, 0, z))
		posts.append(Vector3(hx, 0, z))
	for p in posts:
		var pole := MeshInstance3D.new()
		pole.mesh = Res.cyl(0.05, 0.06, ph, 5)
		pole.material_override = wood
		pole.position = p + Vector3(0, ph * 0.5, 0)
		_scaffold.add_child(pole)
	var y := 1.3
	while y < ph:
		for sd in [-1.0, 1.0]:
			var a := MeshInstance3D.new()
			a.mesh = Res.box(Vector3(hx * 2.0, 0.05, 0.3))
			a.material_override = wood
			a.position = Vector3(0, y, sd * (hz + 0.12))
			_scaffold.add_child(a)
			var b := MeshInstance3D.new()
			b.mesh = Res.box(Vector3(0.3, 0.05, hz * 2.0))
			b.material_override = wood
			b.position = Vector3(sd * (hx + 0.12), y, 0)
			_scaffold.add_child(b)
		y += 1.5
	# a brace on each long side
	for sd in [-1.0, 1.0]:
		var br := MeshInstance3D.new()
		br.mesh = Res.cyl(0.035, 0.035, sqrt(hx * hx * 4.0 + ph * ph), 4)
		br.material_override = wood
		br.position = Vector3(0, ph * 0.5, sd * (hz + 0.05))
		br.rotation = Vector3(0, 0, atan2(hx * 2.0, ph))
		_scaffold.add_child(br)


func _recolor() -> void:
	if world and world.structure_view:
		world.structure_view.unbatch(self)
	if world.has_view and view_active and model != null and team >= 0:
		set_process(true)  # a captured neutral site now has ownership and fog to draw
	if _flag:
		_flag.material_override = Res.mat(_flag_color(), 0.8)


## Flags and markings in the side's colour, but faded cloth, not plastic; a
## town nobody holds flies its own colours.
func _flag_color() -> Color:
	if team >= 0:
		return Defs.TEAM_COLORS[team].lerp(Color(0.45, 0.45, 0.42), 0.35).darkened(0.12)
	return C_TOWN_FLAG if skind == "town" else Color.WHITE


func _box(p: Vector3, s: Vector3, c: Color, r := 0.0, shadow := true) -> MeshInstance3D:
	return Res.mi(model, Res.box(s), Res.mat(c), p, Vector3(0, r, 0), shadow)


## Model part with a procedural surface (kind from Mats) and optional colour tint.
func _mk(mesh: Mesh, kind: String, p: Vector3, rot := Vector3.ZERO, col = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(mi)
	Mats.apply(mi, kind, Mats.tint_for(kind, col) if col is Color else Color(1, 1, 1))
	return mi


## (view) The common kinds of scenery - house walls, garden walls and hedges,
## floors, rubble, crates; the town is thousands of them - put the parts of
## their models that end up merged straight into the merged meshes (see
## Mats.Bake), with the surfaces _skin would have given them. The rest are made
## as nodes as ever: the door leaves (they swing), anything glassy or glowing.
const BAKED := ["house_wall", "low_wall", "floor", "rubble", "crates"]
var _bake: Mats.Bake = null


## _box for a part nothing goes on to use: baked if it would be merged.
func _bx(p: Vector3, s: Vector3, c: Color, r := 0.0, shadow := true) -> void:
	if _bake == null:
		_box(p, s, c, r, shadow)
		return
	_skinned(Res.box(s), Res.mat(c), p, Vector3(0, r, 0), Vector3.ONE, shadow)


## _mk for a part nothing goes on to use.
func _mkb(mesh: Mesh, kind: String, p: Vector3, rot := Vector3.ZERO, col = null, shadow := true) -> void:
	if _bake == null:
		_mk(mesh, kind, p, rot, col, shadow)
		return
	var t := Mats.tint_for(kind, col) if col is Color else Color(1, 1, 1)
	_bake.part(mesh, Mats.get_mat(kind), Mats.place(p, rot), t if t != Color(1, 1, 1) else null, shadow)


## A part in a flat colour (`sm`, from Res.mat) that _skin would put on one of
## our surfaces: into the bake, else made as a node like Res.mi (and scaled).
func _skinned(mesh: Mesh, sm: StandardMaterial3D, p: Vector3, rot: Vector3, scl: Vector3, shadow: bool) -> void:
	if _bake == null or not _skinnable(sm):
		var mi := Res.mi(model, mesh, sm, p, rot, shadow)
		if scl != Vector3.ONE:
			mi.scale = scl
		return
	# (the colour _skin reads off the material: Res.mat shares one between
	# colours a hair apart, the first of them)
	var col := sm.albedo_color
	var xf := Mats.place(p, rot, scl)
	var kind := _surf_kind(col, mesh)
	if kind == "foliage":
		_bake.part(mesh, Mats.foliage(), xf, col, shadow)
	else:
		var t := Mats.tint_for(kind, col)
		_bake.part(mesh, Mats.get_mat(kind), xf, t if t != Color(1, 1, 1) else null, shadow)


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	_bake = Mats.Bake.new() if skind in BAKED else null
	var rng := RandomNumberGenerator.new()
	rng.seed = eid * 7919 + variant
	var bags: Array = []
	var works_keep: Array = []
	for p in parts:
		if skind in ["watchtower", "tree", "trench", "car", "wreck", "low_wall", "roof", "bridge", "dock", "town"] or skind in WorksModels.OWN_KINDS:
			break
		if p.color == C_SAND and p.s.y <= 1.3 and minf(p.s.x, p.s.z) <= 1.0:
			bags.append(p)
			continue
		if p.get("door", false):
			continue  # (the leaves are their own pieces: they swing open)
		var col: Color = p.color
		if skind in ["house_wall", "rubble", "crates"]:
			col = Res.vary(col, 0.05, rng)
		_bx(p.p, p.s, col, p.r, skind != "floor")
	var tc := _flag_color()
	match skind:
		"low_wall":
			var p: Dictionary = parts[0]
			if variant % 3 == 1:
				# a hedge: one continuous mass of overlapping leaf lumps, a little
				# uneven along the top, the odd shoot sticking up
				var n := maxi(3, int(size.x / 0.45))
				var hc := Res.vary(p.color, 0.06, rng)
				for i in n:
					var x := (float(i) + 0.5) / n * size.x - size.x * 0.5
					var r := rng.randf_range(0.5, 0.6)
					# (drawn in this order: the colour, then where it sits)
					var lmesh := Res.sphere(0.55, 8)
					var lmat := Res.mat(Res.vary(hc, 0.05, rng))
					_skinned(lmesh, lmat, Vector3(x, 0.6 + rng.randf_range(-0.04, 0.07), rng.randf_range(-0.05, 0.05)), Vector3.ZERO, Vector3(1.15, 1.12, 0.84) * (r / 0.55), true)
					if rng.randf() < 0.18:
						var smesh := Res.sphere(0.3, 6)
						var smat := Res.mat(Res.vary(hc, 0.05, rng).lightened(0.06))
						_skinned(smesh, smat, Vector3(x, 1.2, rng.randf_range(-0.15, 0.15)), Vector3.ZERO, Vector3(0.8, 1.3, 0.8), true)
			else:
				_bx(p.p, p.s, p.color)
				_bx(Vector3(0, p.s.y + 0.04, 0), Vector3(p.s.x + 0.06, 0.08, p.s.z + 0.08), p.color.darkened(0.15))
		"house_wall":
			_house_wall_detail(rng)
		"floor":
			pass
		"bridge":
			_bridge_model(rng)
		"dock":
			DockModel.build(model, team, size)
		"roof":
			_roof_model(rng)
		"crates":
			for p in parts:
				_bx(p.p + Vector3(0, p.s.y * 0.5 + 0.01, 0), Vector3(p.s.x * 0.9, 0.04, p.s.z * 0.9), C_WOOD.darkened(0.3), p.r)
		"car":
			# parked cars: the island's own (hatchbacks, SUVs, pickups, 4x4s)
			var civ_key: String = ["hatchback", "suv", "offroad", "mb4wd", "hatchback_sport"][variant % 5]
			if civ_key in VmCiv.KEYS:
				model.add_child(VehicleModels.build(civ_key, -1, eid, variant >= 6).root)
			else:
				var ck := VehicleModels.build_car(variant % 5, parts[0].color, variant >= 6)
				model.add_child(ck.root)
		"wreck":
			var wk := VehicleModels.build(vk if vk != "" else ("tank" if variant % 2 == 0 else "old_tank"), -1, eid, true)
			model.add_child(wk.root)
			if wk.turret:
				wk.turret.rotation = Vector3(rng.randf_range(-0.12, 0.08), rng.randf_range(-1.4, 1.4), rng.randf_range(-0.08, 0.08))
				if rng.randf() < 0.3:
					wk.turret.position += Vector3(rng.randf_range(-3.0, 3.0), -1.0, rng.randf_range(1.0, 3.0))
					wk.turret.rotation += Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.6, 0.6))
			wk.root.rotation.z = rng.randf_range(-0.04, 0.04)
		"tree":
			tree_model(model, eid, variant)
		"fob":
			# command post: HESCO block under camouflage netting, radio mast, ammo
			for x in [-2.2, 2.2]:
				for z in [-2.2, 2.2]:
					_mk(Res.cyl(0.06, 0.06, 3.6, 6), "wood_dark", Vector3(x * 1.6, 1.8, z * 1.6))
			var net := MeshInstance3D.new()
			var nm := PlaneMesh.new()
			nm.size = Vector2(8.6, 8.6)
			nm.subdivide_width = 8
			nm.subdivide_depth = 8
			net.mesh = nm
			net.material_override = Mats.netting()
			Mats.set_inst(net, &"tint", Color(0.3, 0.34, 0.2) if team != 1 else Color(0.44, 0.39, 0.27))
			net.position = Vector3(0, 3.45, 0)
			model.add_child(net)
			_mk(Res.cyl(0.05, 0.07, 9.0, 6), "steel", Vector3(-1.8, 4.5, -1.8))
			_mk(Res.cyl(0.015, 0.015, 3.0, 4), "steel", Vector3(-1.8, 8.6, -1.8), Vector3(0, 0, 0.5))
			_mk(Res.cyl(0.015, 0.015, 3.0, 4), "steel", Vector3(-1.8, 8.6, -1.8), Vector3(0, 0, -0.5))
			_flag = _box(Vector3(-1.1, 7.6, -1.8), Vector3(1.4, 0.8, 0.04), tc)
			_mk(Res.cyl(0.03, 0.03, 4.0, 4), "steel", Vector3(1.8, 4.4, 1.6))
			for i in 4:
				_mk(Res.box(Vector3(0.8, 0.5, 0.5)), "paint", Vector3(-4.5 + i * 0.9, 0.25, 3.8), Vector3(0, rng.randf_range(-0.1, 0.1), 0), Color(0.3, 0.33, 0.2))
				_mk(Res.box(Vector3(0.8, 0.4, 0.5)), "paint", Vector3(-4.5 + i * 0.9 + 0.1, 0.7, 3.8), Vector3(0, rng.randf_range(-0.15, 0.15), 0), Color(0.28, 0.31, 0.19))
			for i in 3:
				_mk(Res.cyl(0.3, 0.3, 0.9, 12), "steel", Vector3(3.6 + i * 0.65, 0.45, -3.9), Vector3.ZERO, Color(0.3, 0.33, 0.24))
			_mk(Res.box(Vector3(1.2, 0.9, 0.8)), "paint", Vector3(4.0, 0.45, 3.6), Vector3(0, 0.3, 0), Color(0.33, 0.35, 0.28))
			_add_label(display_name(), 8.0)
		"town":
			# the town's supply dump: stores crated on a pallet with more under a
			# tarp, fuel drums, and a flagpole flying the colours of whoever holds
			# the place (the town's own while nobody does)
			_mk(Res.box(Vector3(2.4, 0.14, 1.5)), "wood", Vector3(0.55, 0.07, 0.35), Vector3.ZERO, null, false)
			for ix in 2:
				for iz in 2:
					for iy in 2:
						var cp := Vector3(0.55 + (ix - 0.5) * 1.14, 0.14 + 0.275 + iy * 0.55, 0.35 + (iz - 0.5) * 0.69)
						_mk(Res.box(Vector3(1.08, 0.53, 0.64)), "wood", cp, Vector3(0, rng.randf_range(-0.05, 0.05), 0), Res.vary(C_WOOD, 0.06, rng))
			_mk(Res.box(Vector3(1.32, 0.86, 1.12)), "canvas", Vector3(0.85, 1.67, 0.4), Vector3(0, 0.06, 0), Color(0.33, 0.36, 0.25))
			_mk(Res.prism(Vector3(1.12, 0.18, 1.34)), "canvas", Vector3(0.85, 2.19, 0.4), Vector3(0, PI * 0.5 + 0.06, 0), Color(0.31, 0.34, 0.23))
			var drum_cols := [Color(0.45, 0.17, 0.12), Color(0.2, 0.3, 0.42), Color(0.3, 0.33, 0.2), Color(0.62, 0.5, 0.18)]
			for ix in 2:
				for iz in 3:
					if ix == 0 and iz == 0 and rng.randf() < 0.5:
						continue
					var dp := Vector3(-1.45 + ix * 0.6 + rng.randf_range(-0.04, 0.04), 0.44, -0.4 + iz * 0.6)
					_mk(Res.cyl(0.28, 0.28, 0.88, 12), "paint", dp, Vector3.ZERO, drum_cols[rng.randi() % drum_cols.size()])
			_mk(Res.cyl(0.24, 0.3, 0.3, 10), "concrete", Vector3(-0.2, 0.15, -0.85))
			_mk(Res.cyl(0.045, 0.065, 7.2, 6), "steel", Vector3(-0.2, 3.6, -0.85), Vector3.ZERO, Color(0.8, 0.8, 0.78))
			_mk(Res.sphere(0.09, 6), "paint", Vector3(-0.2, 7.25, -0.85), Vector3.ZERO, Color(0.75, 0.62, 0.25))
			_flag = _box(Vector3(0.52, 6.62, -0.85), Vector3(1.4, 0.86, 0.04), tc)
			_add_label(display_name(), 8.4)
		"barracks":
			# plank walls, corrugated gable roof along the long side, windows, porch
			var long_x := size.x >= size.z
			var L := size.x if long_x else size.z
			var W := size.z if long_x else size.x
			_mk(Res.prism(Vector3(W + 0.7, 1.5, L + 0.6)), "corrugated", Vector3(0, 3.75, 0), Vector3(0, PI / 2 if long_x else 0.0, 0), Color(0.42, 0.44, 0.4))
			_mk(Res.box(Vector3(size.x + 0.5, 0.25, size.z + 0.5)), "concrete", Vector3(0, 0.12, 0))
			for side in [-1.0, 1.0]:
				for i in 3:
					var t := (float(i) - 1.0) * L * 0.3
					var wp := Vector3(t, 1.75, side * (W * 0.5 + 0.02)) if long_x else Vector3(side * (W * 0.5 + 0.02), 1.75, t)
					var ws := Vector3(1.15, 0.95, 0.06) if long_x else Vector3(0.06, 0.95, 1.15)
					_mk(Res.box(ws), "wood_dark", wp)
					_mk(Res.box(ws * Vector3(0.82, 0.78, 1.0) + (Vector3(0, 0, 0.02) if long_x else Vector3(0.02, 0, 0))), "glass", wp, Vector3.ZERO, null, false)
			var front := Vector3(0, 0, -size.z * 0.5)
			_mk(Res.box(Vector3(1.4, 2.1, 0.08)), "wood_dark", front + Vector3(L * 0.15 if long_x else 0.0, 1.15, -0.02))
			_mk(Res.box(Vector3(2.4, 0.08, 1.3)), "corrugated", front + Vector3(L * 0.15 if long_x else 0.0, 2.55, -0.6), Vector3(0.2, 0, 0), Color(0.42, 0.44, 0.4))
			_mk(Res.box(Vector3(2.0, 0.2, 0.9)), "concrete", front + Vector3(L * 0.15 if long_x else 0.0, 0.1, -0.5))
			_mk(Res.cyl(0.12, 0.12, 1.6, 8), "gunmetal_w", Vector3(-L * 0.3 if long_x else 0.0, 4.6, 0.6))
			for i in 2:
				_mk(Res.cyl(0.3, 0.3, 0.9, 12), "steel", front + Vector3(-L * 0.38 + i * 0.66, 0.45, -0.8), Vector3.ZERO, Color(0.3, 0.33, 0.24))
			_mk(Res.box(Vector3(0.9, 0.6, 0.6)), "paint", Vector3(size.x * 0.5 + 0.35, 0.6, -0.8), Vector3.ZERO, Color(0.55, 0.56, 0.52))
			_flag = _box(Vector3(size.x * 0.4, 5.4, 0), Vector3(1.0, 0.6, 0.04), tc)
			_mk(Res.cyl(0.03, 0.03, 2.2, 4), "steel", Vector3(size.x * 0.4 - 0.55, 4.6, 0))
		"factory":
			_mk(Res.box(Vector3(size.x + 0.4, 0.3, size.z + 0.4)), "concrete", Vector3(0, 5.15, 0), Vector3.ZERO, Color(0.48, 0.48, 0.46))
			# sawtooth skylights
			for i in 3:
				var zx := -size.x * 0.3 + i * size.x * 0.3
				_mk(Res.prism(Vector3(size.z * 0.8, 0.9, 1.4)), "corrugated", Vector3(zx, 5.75, 0), Vector3(0, PI / 2, 0), Color(0.45, 0.47, 0.45))
				_mk(Res.box(Vector3(0.05, 0.75, size.z * 0.78)), "glass", Vector3(zx + 0.36, 5.68, 0), Vector3(0, 0, 0.45), null, false)
			# roll-up door, loading apron, pipes, vents, stack
			_mk(Res.box(Vector3(5.0, 4.0, 0.1)), "corrugated", Vector3(0, 2.0, -size.z * 0.5 - 0.03), Vector3(0, 0, PI / 2), Color(0.55, 0.5, 0.36))
			_mk(Res.box(Vector3(6.4, 0.12, 3.4)), "concrete_floor", Vector3(0, 0.06, -size.z * 0.5 - 1.7))
			_mk(Res.box(Vector3(5.6, 0.3, 0.4)), "steel", Vector3(0, 4.15, -size.z * 0.5 - 0.2), Vector3.ZERO, Color(0.4, 0.38, 0.33))
			_mk(Res.cyl(0.18, 0.18, size.z * 0.9, 8), "steel", Vector3(size.x * 0.5 + 0.25, 3.2, 0), Vector3(PI / 2, 0, 0), Color(0.5, 0.42, 0.3))
			_mk(Res.cyl(0.12, 0.12, size.z * 0.9, 8), "steel", Vector3(size.x * 0.5 + 0.25, 2.7, 0), Vector3(PI / 2, 0, 0), Color(0.35, 0.37, 0.33))
			for i in 2:
				_mk(Res.cyl(0.35, 0.35, 0.5, 12), "steel", Vector3(-size.x * 0.25 + i * 1.4, 5.55, size.z * 0.32))
			_mk(Res.cyl(0.42, 0.55, 5.0, 12), "brick", Vector3(size.x * 0.35, 7.6, size.z * 0.3))
			_mk(Res.cyl(0.46, 0.46, 0.25, 12), "concrete", Vector3(size.x * 0.35, 10.1, size.z * 0.3))
			if world != null and world.fx and world.fx.vfx and built:
				var stack := world.fx.vfx.make_burner(0.7)
				stack.position = Vector3(size.x * 0.35, 10.4, size.z * 0.3)
				model.add_child(stack)
				world.fx.vfx.set_burning(stack, 0.0, 0.35)
			_flag = _box(Vector3(-size.x * 0.4, 6.4, 0), Vector3(1.2, 0.7, 0.04), tc)
		"medic_tent":
			# (the placeholder block goes now: a deferred free would still be
			# baked into the merged model below)
			for c in model.get_children():
				model.remove_child(c)
				c.queue_free()
			var hz := size.z * 0.5
			# an olive-drab ward tent with the red cross on white panels
			_mk(Res.prism(Vector3(size.z, 2.8, size.x)), "canvas", Vector3(0, 1.4, 0), Vector3(0, PI / 2, 0), Color(0.4, 0.41, 0.31))
			for sx in [-1.0, 1.0]:
				_mk(Res.box(Vector3(0.05, 2.75, 0.05)), "wood_dark", Vector3(sx * (size.x * 0.5 - 0.1), 1.375, 0))
			var ang := atan2(2.8, hz)
			for sd in [-1.0, 1.0]:
				var nrm := Vector3(0, hz, sd * 2.8).normalized()
				var cpos := Vector3(0, 1.4, sd * hz * 0.5) + nrm * 0.03
				var rot := Vector3(sd * (PI * 0.5 - ang), 0, 0)
				_mk(Res.box(Vector3(1.9, 0.02, 1.9)), "paint", cpos, rot, Color(0.9, 0.9, 0.88), false)
				_mk(Res.box(Vector3(1.4, 0.03, 0.42)), "paint", cpos + nrm * 0.01, rot, Color(0.75, 0.08, 0.07), false)
				_mk(Res.box(Vector3(0.42, 0.03, 1.4)), "paint", cpos + nrm * 0.01, rot, Color(0.75, 0.08, 0.07), false)
				for x in [-size.x * 0.4, 0.0, size.x * 0.4]:
					var rope := _mk(Res.cyl(0.01, 0.01, 2.1, 4), "canvas", Vector3(x, 0.75, sd * (hz + 0.75)), Vector3(sd * 0.8, 0, 0), Color(0.6, 0.58, 0.5), false)
					rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mk(Res.box(Vector3(0.06, 2.0, 1.5)), "canvas", Vector3(-size.x * 0.5 - 0.02, 1.0, 0), Vector3.ZERO, Color(0.25, 0.25, 0.22))
			_mk(Res.box(Vector3(size.x + 0.6, 0.06, size.z + 0.6)), "canvas", Vector3(0, 0.03, 0), Vector3.ZERO, Color(0.3, 0.28, 0.24), false)
			for i in 2:
				var sp := Vector3(-size.x * 0.5 - 1.6, 0.35, -1.0 + i * 1.6)
				_mk(Res.box(Vector3(2.0, 0.05, 0.6)), "canvas", sp, Vector3(0, 0.1, 0), Color(0.35, 0.38, 0.28))
				_mk(Res.box(Vector3(2.4, 0.05, 0.05)), "wood", sp + Vector3(0, -0.02, 0.32), Vector3(0, 0.1, 0))
				_mk(Res.box(Vector3(2.4, 0.05, 0.05)), "wood", sp + Vector3(0, -0.02, -0.32), Vector3(0, 0.1, 0))
			_mk(Res.cyl(0.03, 0.03, 4.2, 4), "steel", Vector3(size.x * 0.5 + 0.8, 2.1, hz + 0.5))
			_mk(Res.box(Vector3(1.0, 0.65, 0.03)), "paint", Vector3(size.x * 0.5 + 1.32, 3.85, hz + 0.5), Vector3.ZERO, Color(0.92, 0.92, 0.9), false)
			_mk(Res.box(Vector3(0.6, 0.16, 0.04)), "paint", Vector3(size.x * 0.5 + 1.32, 3.85, hz + 0.5), Vector3.ZERO, Color(0.75, 0.08, 0.07), false)
			_mk(Res.box(Vector3(0.16, 0.5, 0.04)), "paint", Vector3(size.x * 0.5 + 1.32, 3.85, hz + 0.5), Vector3.ZERO, Color(0.75, 0.08, 0.07), false)
		"research":
			_mk(Res.box(Vector3(size.x + 0.3, 0.2, size.z + 0.3)), "concrete", Vector3(0, 3.3, 0), Vector3.ZERO, Color(0.42, 0.42, 0.4))
			for sd in [-1.0, 1.0]:
				_mk(Res.box(Vector3(size.x * 0.8, 0.7, 0.05)), "glass", Vector3(0, 2.1, sd * (size.z * 0.5 + 0.02)), Vector3.ZERO, null, false)
				_mk(Res.box(Vector3(0.05, 0.7, size.z * 0.8)), "glass", Vector3(sd * (size.x * 0.5 + 0.02), 2.1, 0), Vector3.ZERO, null, false)
			_mk(Res.box(Vector3(1.3, 2.1, 0.08)), "metal_dark", Vector3(-1.5, 1.05, -size.z * 0.5 - 0.03))
			_mk(Res.cyl(1.3, 0.2, 0.4, 18), "paint", Vector3(1.5, 4.5, 1.5), Vector3(0.6, 0, 0.3), Color(0.82, 0.82, 0.8))
			_mk(Res.cyl(0.08, 0.08, 1.0, 6), "steel", Vector3(1.5, 3.85, 1.5))
			_mk(Res.cyl(0.04, 0.04, 4.0, 4), "steel", Vector3(-2.2, 5.3, -2.2))
			_mk(Res.cyl(0.02, 0.02, 1.6, 4), "steel", Vector3(-2.2, 6.6, -2.2), Vector3(0, 0, PI / 2))
			_mk(Res.box(Vector3(1.0, 0.5, 0.7)), "paint", Vector3(-1.6, 3.65, 1.4), Vector3.ZERO, Color(0.6, 0.6, 0.58))
			_mk(Res.box(Vector3(1.6, 1.0, 0.9)), "paint", Vector3(size.x * 0.5 + 1.0, 0.5, 1.5), Vector3.ZERO, Color(0.32, 0.36, 0.26))
			_mk(Res.cyl(0.06, 0.06, 0.6, 6), "gunmetal_w", Vector3(size.x * 0.5 + 1.4, 1.2, 1.7))
			_flag = _box(Vector3(-2.0, 6.7, -2.2), Vector3(0.8, 0.5, 0.04), tc)
		"depot":
			for i in 6:
				Res.mi(model, Res.cyl(0.08, 0.08, 1.6, 6), Res.mat(C_WOOD), Vector3(-9 + i * 3.6, 0.8, -6))
			Res.mi(model, Res.cyl(0.06, 0.06, 9.0, 6), Res.mat(Color(0.7, 0.7, 0.7)), Vector3(0, 4.5, 0))
			_flag = _box(Vector3(0.9, 8.4, 0), Vector3(1.8, 1.0, 0.05), tc)
			_add_label(display_name(), 10.0)
		"sandbags":
			WorksModels.apron(model, size.x * 0.5 + 0.25, 0.75)
		"concrete_wall", "hesco", "barricade", "ammo_cache", "camo_net":
			works_keep = WorksModels.build(self, model, rng, bags)
		"trench":
			# the hole itself is drawn by the TrenchNet; here: the dig site while it's
			# being dug, and a little kit along the lip once it's done
			var site := Node3D.new()
			site.name = "Site"
			model.add_child(site)
			for sz in [-0.75, 0.75]:
				var tape := Res.mi(site, Res.box(Vector3(size.x, 0.03, 0.05)), Res.mat(Color(0.85, 0.82, 0.7)), Vector3(0, 0.3, sz), Vector3.ZERO, false)
				tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for x in [-size.x * 0.5, 0.0, size.x * 0.5]:
					Res.mi(site, Res.box(Vector3(0.05, 0.4, 0.05)), Res.mat(C_WOOD), Vector3(x, 0.2, sz), Vector3.ZERO, false)
			var scrape := Res.mi(site, Res.box(Vector3(size.x, 0.04, 1.4)), Res.mat(Color(0.16, 0.12, 0.08)), Vector3(0, 0.02, 0), Vector3.ZERO, false)
			scrape.name = "Scrape"
			for i in 3:
				var pile := Res.mi(site, Res.sphere(0.55, 8), Res.mat(Res.vary(Color(0.24, 0.19, 0.13), 0.05, rng)), Vector3((i - 1) * size.x * 0.33, 0.0, 1.35 * (1.0 if i % 2 == 0 else -1.0)), Vector3.ZERO, false)
				pile.scale = Vector3(1.4, 0.55, 0.9)
				pile.name = "Pile%d" % i
			var done := Node3D.new()
			done.name = "Done"
			model.add_child(done)
			var fsgn := _enemy_side()
			# kit only along fire bays, kept clear of the corners where the traverses join
			var kx := size.x * 0.5 - 1.2
			# a few filled bags along the parapet (rests for the rifles)
			var kit_bags: Array = []
			for i in (rng.randi_range(2, 4) if kx > 0.8 else 0):
				var bx := rng.randf_range(-kx, kx)
				kit_bags.append({"p": Vector3(bx, 0.32, fsgn * 1.05), "s": Vector3(0.55 * rng.randi_range(1, 2), 0.19, 0.36), "r": rng.randf_range(-0.2, 0.2)})
			if not kit_bags.is_empty():
				_bag_walls(kit_bags, rng, done)
			if kx > 0.8 and rng.randf() < 0.35:
				Res.mi(done, Res.box(Vector3(0.5, 0.3, 0.3)), Res.mat(Color(0.25, 0.28, 0.2)), Vector3(rng.randf_range(-kx, kx), -0.9, -fsgn * 0.45), Vector3(0, snappedf(rng.randf_range(-0.2, 0.2), 0.1), 0), false)
		"wire", "mines", "tank_trap":
			works_keep = WorksModels.build(self, model, rng, bags)
		"mg_nest", "hmg_nest":
			_mg_model(rng, bags)
			if variant != 1:
				WorksModels.apron(model, foot.x + 0.3, foot.y + 0.3)
		"mortar_pit":
			# the floor dug out and trodden flat inside the ring of bags
			WorksModels.pit_floor(model, 1.7)
			WorksModels.apron(model, 2.8, 2.8)
			WorksModels.build(self, model, rng, bags)
		"at_post":
			WorksModels.apron(model, foot.x + 0.3, foot.y + 0.3)
			WorksModels.build(self, model, rng, bags)
		"bunker":
			if team == 1:
				# a log-and-earth dugout: earth banked against the walls up to the
				# firing slits, a roof of logs under a mound of earth and bags,
				# log posts at the corners and a lintel log over every slit
				for i in 9:
					var lgg := Res.mi(model, Res.cyl(0.15, 0.16, 6.3, 7), Res.mat(C_WOOD.darkened(0.25)), Vector3(-2.8 + i * 0.7, 2.5, 0), Vector3(PI / 2, 0, 0))
					lgg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var mound := _mk(Res.dome(3.4, 16), "bank", Vector3(0, 2.6, 0), Vector3.ZERO, Color(0.29, 0.27, 0.17))
				mound.scale = Vector3(1.0, 0.22, 1.0)
				for x in [-2.85, 2.85]:
					for z in [-2.85, 2.85]:
						Res.mi(model, Res.cyl(0.16, 0.18, 2.5, 7), Res.mat(C_WOOD.darkened(0.3)), Vector3(x, 1.25, z))
				Res.mi(model, Res.cyl(0.13, 0.13, 3.0, 7), Res.mat(C_WOOD.darkened(0.3)), Vector3(0, 1.72, -2.86), Vector3(0, 0, PI / 2))
				for sx in [-1.0, 1.0]:
					Res.mi(model, Res.cyl(0.13, 0.13, 2.2, 7), Res.mat(C_WOOD.darkened(0.3)), Vector3(sx * 2.86, 1.72, 0), Vector3(PI / 2, 0, 0))
				WorksModels.berms(model, 2.8, 1.0, 2.0, true)
				for i in 6:
					bags.append({"p": Vector3(-2.0 + i * 0.8, 3.15, -2.2), "s": Vector3(0.75, 0.2, 0.45), "r": 0.0})
			else:
				# reinforced concrete: a thick roof slab with an overhang under a
				# layer of bags, earth banked up to the slits, steel angle round
				# the embrasure, a steel door, a vent and a whip aerial
				_box(Vector3(0, 2.62, 0), Vector3(6.3, 0.16, 6.3), C_CONCRETE.darkened(0.28))
				for row in 2:
					bags.append({"p": Vector3(0, 2.82, -2.6 + row * 0.5), "s": Vector3(5.2, 0.24, 0.48), "r": 0.0})
				bags.append({"p": Vector3(0, 2.82, 2.6), "s": Vector3(5.2, 0.24, 0.48), "r": 0.0})
				WorksModels.berms(model, 2.8, 0.95, 2.0, false)
				for y in [1.1, 1.66]:
					_mk(Res.box(Vector3(2.7, 0.07, 0.1)), "metal_dark", Vector3(0, y, -2.82), Vector3.ZERO, Color(0.2, 0.2, 0.19))
				_mk(Res.box(Vector3(1.0, 1.95, 0.06)), "paint", Vector3(0, 0.98, 2.62), Vector3.ZERO, Color(0.3, 0.32, 0.25))
				_mk(Res.cyl(0.08, 0.08, 0.7, 8), "steel", Vector3(1.8, 3.15, 1.6))
				_mk(Res.cyl(0.13, 0.13, 0.12, 8), "steel", Vector3(1.8, 3.5, 1.6), Vector3.ZERO, Color(0.2, 0.2, 0.2))
				_mk(Res.cyl(0.008, 0.012, 2.4, 4), "metal_dark", Vector3(-2.3, 4.0, 2.3), Vector3(0.05, 0, 0.04), null, false)
			_box(Vector3(0, 0.02, 0), Vector3(4.4, 0.04, 4.4), Color(0.3, 0.29, 0.27), 0.0, false)
		"watchtower":
			for p in parts:
				_box(p.p, p.s, C_WOOD if p.s.y > 1.0 else C_WOOD.lightened(0.05), p.r)
			WorksModels.tower(model, rng, bags)
		"helipad":
			var white := Color(0.9, 0.9, 0.85)
			_box(Vector3(0, 0.06, 0), Vector3(size.x, 0.12, size.z), Color(0.4, 0.4, 0.38), 0.0, false)
			_box(Vector3(-1.2, 0.13, 0), Vector3(0.5, 0.02, 3.6), white, 0.0, false)
			_box(Vector3(1.2, 0.13, 0), Vector3(0.5, 0.02, 3.6), white, 0.0, false)
			_box(Vector3(0, 0.13, 0), Vector3(2.4, 0.02, 0.5), white, 0.0, false)
			for x in [-4.6, 4.6]:
				for z in [-4.6, 4.6]:
					Res.mi(model, Res.sphere(0.12, 6), Res.mat(Color(1, 0.6, 0.2), 0.5, 3.0, true), Vector3(x, 0.2, z), Vector3.ZERO, false)
			Res.mi(model, Res.cyl(0.04, 0.04, 3.0, 4), Res.mat(Color(0.7, 0.7, 0.7)), Vector3(4.8, 1.5, -4.8))
			_box(Vector3(5.3, 2.85, -4.8), Vector3(1.0, 0.35, 0.3), Color(1.0, 0.5, 0.1))
			_flag = _box(Vector3(-4.8, 0.5, 4.8), Vector3(0.6, 0.6, 0.6), tc)
		"tunnel":
			Res.mi(model, Res.cyl(1.0, 1.0, 0.04, 14), Res.mat(Color(0.03, 0.03, 0.03)), Vector3(0, 0.04, 0), Vector3.ZERO, false)
			Res.mi(model, Res.torus(1.0, 1.6), Res.mat(C_DIRT), Vector3(0, 0.08, 0))
			_box(Vector3(0, 0.25, -1.05), Vector3(2.0, 0.2, 0.2), C_WOOD)
			_box(Vector3(0, 0.25, 1.05), Vector3(2.0, 0.2, 0.2), C_WOOD)
			_box(Vector3(-0.9, 0.7, 0), Vector3(0.15, 1.4, 0.15), C_WOOD)
			_box(Vector3(0.9, 0.7, 0), Vector3(0.15, 1.4, 0.15), C_WOOD)
			_box(Vector3(0, 1.4, 0), Vector3(2.0, 0.15, 0.15), C_WOOD)
			_flag = _box(Vector3(0, 1.75, 0), Vector3(0.5, 0.3, 0.03), tc)
	if not bags.is_empty():
		_bag_walls(bags, rng)
	_skin(model)
	var keep: Array = [_flag] if _flag else []
	keep.append_array(works_keep)
	for lf in _door_leaves:
		keep.append(lf[0])
	if not _mg.is_empty():
		# the gun turns and kicks: each moving piece is its own single mesh
		keep.append(_mg.root)
		for n in [_mg.root, _mg.traverse, _mg.elev, _mg.body]:
			Mats.merge_static(n, [], false, false, true)
	for nm in ["Site", "Done"]:
		var sub := model.get_node_or_null(nm) as Node3D
		if sub:
			keep.append(sub)
			Mats.merge_static(sub, [])
	if _bake:
		_bake.commit(model)
		_bake = null
	Mats.merge_static(model, keep)
	# (a freshly killed vehicle's fire is the server's: see Fires and _burn_view)


static var _bag_mesh: ArrayMesh


## A filled sandbag in a unit box (its length along x): a pillow pressed flat
## top and bottom by the bags above it, slumped along the middle, the tied
## neck at +x narrower, lower and folded under.
static func _pillow() -> ArrayMesh:
	var segs := 16
	var rings := 9
	var k := 0.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for r in rings + 1:
		var row := []
		var th := PI * float(r) / rings
		for sg in segs + 1:
			var ph := TAU * float(sg) / segs
			var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var p := Vector3(signf(n.x) * pow(absf(n.x), k), signf(n.y) * pow(absf(n.y), k * 1.9), signf(n.z) * pow(absf(n.z), k * 1.1)) * 0.5
			var e := smoothstep(0.2, 0.5, p.x)
			p.y = p.y * (1.0 - 0.3 * e) - 0.07 * e
			p.z *= 1.0 - 0.18 * e
			if p.y > 0.0:
				p.y -= 0.06 * (1.0 - 4.0 * p.x * p.x) * (p.y / 0.5)
			row.append(p)
		grid.append(row)
	for r in rings:
		for sg in segs:
			var q := [grid[r][sg], grid[r][sg + 1], grid[r + 1][sg + 1], grid[r + 1][sg]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.add_vertex(q[idx])
	st.index()
	st.generate_normals()
	return st.commit()


## The bags each side fills, as [colour (against the bag cloth), share]: the
## Coalition's tan and coyote polypropylene with some olive; the Rebels'
## hessian, white feed sacks and whatever else was going; a mix for the rest.
const BAG_COLS := [
	[[Color(1.0, 1.0, 1.0), 0.55], [Color(0.98, 0.9, 0.84), 0.25], [Color(0.84, 0.97, 0.84), 0.2]],
	[[Color(0.92, 0.8, 0.66), 0.45], [Color(1.36, 1.44, 1.72), 0.3], [Color(0.9, 1.02, 0.95), 0.1], [Color(1.0, 1.0, 1.0), 0.15]],
	[[Color(1.0, 1.0, 1.0), 0.5], [Color(0.92, 0.8, 0.66), 0.3], [Color(1.36, 1.44, 1.72), 0.2]],
]
const BAG_CLOTH := Color(0.5, 0.45, 0.33)  # the "bag" surface's own colour


## Stacks individual sandbags to fill each part box the way they're laid in
## the field: courses of stretchers (along the wall) and, in a thick wall,
## headers (across it, ends to the face) between them, joints broken from one
## course to the next, each course set back a little from the one below so the
## face leans back; the odd bag a different colour, turned or askew.
func _bag_walls(list: Array, rng: RandomNumberGenerator, parent: Node3D = null) -> void:
	if _bag_mesh == null:
		_bag_mesh = _pillow()
	var pal: Array = BAG_COLS[team] if team >= 0 and team <= 1 else BAG_COLS[2]
	var lot := rng.randi() % pal.size()  # most of a wall's bags come from one lot
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	for p in list:
		var s: Vector3 = p.s
		var along_x := s.x >= s.z
		var length := s.x if along_x else s.z
		var depth := s.z if along_x else s.x
		var rows := maxi(1, int(round(s.y / 0.19)))
		var rh := s.y / rows
		var pb := Basis(Vector3.UP, float(p.r))
		var headers := depth >= 0.62 and length >= 0.9 and rows > 1
		for row in rows:
			var y := -s.y * 0.5 + rh * (row + 0.5)
			var dr := depth * (1.0 - 0.16 * float(row) / float(rows - 1)) if depth > 0.5 and rows > 2 else depth
			if headers and row % 2 == 1:
				var hn := maxi(1, int(round(dr / 0.6)))
				var cnt := maxi(1, int(floor(length / 0.3)))
				var bw := length / cnt
				for d in hn:
					var dz := (float(d) + 0.5) / hn * dr - dr * 0.5
					for i in cnt:
						var a := (float(i) + 0.5) * bw - length * 0.5
						_bag(xf, cols, p, pb, along_x, Vector3(a, y, dz), PI * 0.5, Vector3(dr / hn * 1.03, rh * 1.12, bw * 1.08), row == rows - 1, rng, pal, lot)
				continue
			var deep := maxi(1, int(round(dr / 0.42)))
			var n := maxi(1, int(ceil(length / 0.5)))
			var bl := length / n
			var course := row / 2 if headers else row
			var shifted := course % 2 == 1
			var cnt2 := n - 1 if shifted else n
			if cnt2 <= 0:
				continue
			for d in deep:
				var dz2 := (float(d) + 0.5) / deep * dr - dr * 0.5
				for i in cnt2:
					var a2 := (float(i) + 0.5) * bl - length * 0.5 + (0.5 * bl if shifted else 0.0)
					_bag(xf, cols, p, pb, along_x, Vector3(a2, y, dz2), 0.0, Vector3(bl * 1.04, rh * 1.12, minf(0.42, dr / deep) * 1.05), row == rows - 1, rng, pal, lot)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _bag_mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.get_mat("bag")
	(parent if parent else model).add_child(mmi)


## One bag: `lp` in the wall's own frame (along it, up, across it), `turn`
## more about the vertical (headers lie across), `sz` its size.
func _bag(xf: Array[Transform3D], cols: Array[Color], p: Dictionary, pb: Basis, along_x: bool, lp: Vector3, turn: float, sz: Vector3, top: bool, rng: RandomNumberGenerator, pal: Array, lot: int) -> void:
	lp += Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.012, 0.012), rng.randf_range(-0.025, 0.025))
	var q := lp if along_x else Vector3(lp.z, lp.y, lp.x)
	var yaw := (0.0 if along_x else PI / 2) + turn + rng.randf_range(-0.09, 0.09) + (PI if rng.randf() < 0.5 else 0.0)
	var b := pb * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05)) * Basis(Vector3.FORWARD, rng.randf_range(-0.04, 0.04))
	xf.append(Transform3D(b.scaled_local(sz), p.p + pb * q))
	# the colour: mostly the wall's lot, bleached a little on top
	var pick := lot
	if rng.randf() < 0.45:
		var r := rng.randf()
		for i in pal.size():
			r -= float(pal[i][1])
			if r <= 0.0:
				pick = i
				break
	var c: Color = pal[pick][0]
	var k := rng.randf_range(0.86, 1.06) + (0.06 if top else 0.0)
	var want := Color(clampf(BAG_CLOTH.r * c.r * k, 0.0, 1.0), clampf(BAG_CLOTH.g * c.g * k, 0.0, 1.0), clampf(BAG_CLOTH.b * c.b * k, 0.0, 1.0)).srgb_to_linear()
	var base := BAG_CLOTH.srgb_to_linear()
	cols.append(Color(want.r / base.r, want.g / base.g, want.b / base.b))


# --- surfaces --------------------------------------------------------------------

const SURF_REFS := [
	[C_STONE, "stone"], [C_CONCRETE, "concrete"], [C_SAND, "sandbag"], [C_WOOD, "wood"],
	[C_DIRT, "earth"], [C_STEEL, "steel"], [C_OLIVE, "canvas"], [Color(0.86, 0.85, 0.8), "canvas_white"],
	[Color(0.45, 0.46, 0.44), "corrugated"], [Color(0.42, 0.31, 0.2), "wood_dark"],
	[Color(0.3, 0.33, 0.2), "paint"], [Color(0.58, 0.37, 0.28), "brick"], [Color(0.28, 0.38, 0.18), "foliage"],
]


## Swaps the flat colour materials of the model for procedural surfaces,
## keeping each part's colour as a tint.
func _skin(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c != _flag:
			var sm := (c as MeshInstance3D).material_override as StandardMaterial3D
			if _skinnable(sm):
				var col := sm.albedo_color
				var kind := _surf_kind(col, (c as MeshInstance3D).mesh)
				if kind == "foliage":
					c.material_override = Mats.foliage()
					Mats.set_inst(c, &"tint", col)
				else:
					Mats.apply(c, kind, Mats.tint_for(kind, col))
		_skin(c)


## A flat colour _skin puts on one of our surfaces (not glowing, unlit or see-through).
static func _skinnable(sm: StandardMaterial3D) -> bool:
	return sm != null and not sm.emission_enabled and sm.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and sm.albedo_color.a > 0.99


func _surf_kind(c: Color, mesh: Mesh) -> String:
	var v := maxf(c.r, maxf(c.g, c.b))
	var dark := v < 0.16
	match skind:
		"house_wall":
			return "plaster"
		"floor":
			return "floor_tiles"
		"rubble":
			return "rubble"
		"crates":
			return "wood" if not dark else "metal_dark"
		"car":
			if c.b > c.r and v < 0.25:
				return "glass"
			return "rubber" if dark else "car_paint"
		"wreck":
			return "burnt"
		"tree":
			return "foliage" if c.g > c.r * 1.2 else "bark"
		"factory", "depot":
			if Res.box_size(mesh) != Vector3.ZERO and c.r > 0.2 and absf(c.r - c.g) > 0.05:
				return "corrugated"
		"fob":
			if Res.box_size(mesh).y > 2.0:
				return "hesco"
		"helipad":
			return "concrete" if not dark else "metal_dark"
		"medic_tent":
			if c.r > 0.7 and c.g < 0.2:
				return "paint"
		"barracks":
			if mesh is PrismMesh:
				return "corrugated"
			if Res.box_size(mesh).y > 2.5:
				return "wood_painted"
		"bunker":
			if team != 1:
				return "precast"
			if mesh is SphereMesh or mesh is PrismMesh:
				return "earth"  # the dugout's mound and banked earth
			if team == 1 and c.r > c.b * 1.6 and v < 0.5:
				return "wood_dark"
		"trench":
			if Res.box_size(mesh).y > 0.5 and c.r < 0.4 and c.r > c.b * 1.5:
				return "earth"
	if dark:
		return "gunmetal_w"
	var best := "paint"
	var bd := 1e9
	var cn := Vector3(c.r, c.g, c.b) / v
	for r in SURF_REFS:
		var rc: Color = r[0]
		var rv := maxf(rc.r, maxf(rc.g, rc.b))
		var d := (Vector3(rc.r, rc.g, rc.b) / rv).distance_squared_to(cn) + 0.25 * (v - rv) * (v - rv)
		if d < bd:
			bd = d
			best = r[1]
	return best


func _add_label(_text: String, h: float) -> void:
	label_h = h
