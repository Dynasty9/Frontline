class_name MapGen
extends RefCounted
## Builds the battlefield on the server: HQs and starting FOBs at the north
## and south edges; between them a town, a hamlet and farms on the country
## roads (TownGen), hedged fields, old trenches and woods.

var world: World
var rng: RandomNumberGenerator
var placed: Array = []  # [Vector2 center, Vector2 half, yaw]
var clear: Array = []  # [Vector2 center, radius]


func _init(w: World) -> void:
	world = w
	rng = w.rng


func generate() -> void:
	var r := world.rules
	var d0 := _spawn("depot", Vector3(0, 0, 116), 0.0, 0)
	var d1 := _spawn("depot", Vector3(0, 0, -116), PI, 1)
	r.depots = [d0, d1]
	var fx0 := roundf(rng.randf_range(-40.0, 40.0))
	var fx1 := roundf(rng.randf_range(-40.0, 40.0))
	var f0 := _spawn("fob", Vector3(fx0, 0, 86), 0.0, 0, {"sname": r.next_fob_name(0), "supply": float(Defs.START_SUPPLY)})
	var f1 := _spawn("fob", Vector3(fx1, 0, -86), PI, 1, {"sname": r.next_fob_name(1), "supply": float(Defs.START_SUPPLY)})
	r.register_start_fob(f0)
	r.register_start_fob(f1)
	for st in [d0, d1, f0, f1]:
		st.seen_mask = 3  # start locations are common knowledge
	for p in [d0.position, d1.position]:
		clear.append([Vector2(p.x, p.z), 26.0])
	for f in [f0, f1]:
		clear.append([Vector2(f.position.x, f.position.z), 30.0])
	# keep the lane between HQ and starting FOB open
	for t in 2:
		var a: Vector3 = [d0, d1][t].position
		var b: Vector3 = [f0, f1][t].position
		for i in 5:
			var p := a.lerp(b, i / 4.0)
			clear.append([Vector2(p.x, p.z), 10.0])

	# the town, its roads and everything that hangs off them (see TownGen)
	var tg := TownGen.new(self)
	tg.plan_town(TrenchNet.snap_pos(Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-8, 8))))
	world.roads[2] = tg.build_roads(d0.position, d1.position)
	world._rebuild_roads()
	tg.streetscape()
	tg.lots()
	tg.hamlet_houses()
	tg.farms(rng.randi_range(2, 3))
	tg.country_power()
	tg.fields(rng.randi_range(7, 10))
	tg.roadside(rng.randi_range(3, 5), rng.randi_range(2, 3))
	tg.finish()
	for i in rng.randi_range(3, 4):
		_hedgerow()
	for i in rng.randi_range(1, 2):
		_try("wreck", Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-60, 60)), rng.randf() * TAU, -1)
	for i in rng.randi_range(2, 3):
		_crate_cluster(Vector3(rng.randf_range(-105, 105), 0, rng.randf_range(-70, 70)))
	for i in rng.randi_range(3, 5):
		_old_position(Vector3(rng.randf_range(-90, 90), 0, rng.randf_range(-35, 35)))
	for i in rng.randi_range(7, 10):
		_woods(Vector3(rng.randf_range(-115, 115), 0, rng.randf_range(-100, 100)), rng.randi_range(6, 14))
	for i in 40:
		_try("tree", Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-118, 118)), 0.0, -1)

	# starting forces
	var owners := [[], []]
	var pl: Dictionary = world.settings.get("players", {})
	for id in pl:
		var t := int(pl[id].team)
		if t >= 0:
			owners[t].append(int(id))
	for t in world.settings.get("ai_teams", []):
		owners[int(t)].append(-1 - int(t))
	for t in 2:
		var f: Structure = [f0, f1][t]
		var fwd := Vector3.FORWARD if t == 0 else Vector3.BACK
		var i := 0
		for o in owners[t]:
			var side: Vector3 = Vector3.RIGHT * (i * 14.0 - (owners[t].size() - 1) * 7.0)
			r.spawn_squad("rifle_squad" if t == 0 else "fighter_cell", t, o, f.position + fwd * 11.0 + side, f.position + fwd * 18.0 + side)
			r.spawn_squad("engineer_team" if t == 0 else "digger_team", t, o, f.position - fwd * 10.0 + side + Vector3(4, 0, 0))
			i += 1
	r.rebuild_network(0)
	r.rebuild_network(1)


## Small hand-built test setups used by automated checks (--scenario=NAME).
func scenario(sname: String) -> void:
	var r := world.rules
	var d0 := _spawn("depot", Vector3(0, 0, 116), 0.0, 0)
	var d1 := _spawn("depot", Vector3(0, 0, -116), PI, 1)
	r.depots = [d0, d1]
	var f0 := _spawn("fob", Vector3(60, 0, 95), 0.0, 0, {"sname": r.next_fob_name(0), "supply": 2000.0})
	var f1 := _spawn("fob", Vector3(60, 0, -95), PI, 1, {"sname": r.next_fob_name(1), "supply": 2000.0})
	r.register_start_fob(f0)
	r.register_start_fob(f1)
	var a := 1 if world.settings.get("scenario_player", false) else -1
	var b := -2
	match sname:
		"air":
			var hp2 := _spawn("helipad", Vector3(0, 0, 60), 0.0, 0)
			var gs: Vehicle = world.spawn("vehicle", {"vkind": "gunship", "team": 0, "owner": a, "pos": Vector3(0, 20, 50), "yaw": 0.0})
			gs.order_move(Vector3(0, 0, -20))
			world.spawn("vehicle", {"vkind": "humvee", "team": 0, "owner": a, "pos": Vector3(12, 0, 20), "yaw": 0.0}).order_move(Vector3(12, 0, -10))
			world.spawn("vehicle", {"vkind": "aa_tech", "team": 1, "owner": b, "pos": Vector3(-20, 0, -60), "yaw": PI}).order_move(Vector3(-15, 0, -45))
			world.spawn("vehicle", {"vkind": "technical", "team": 1, "owner": b, "pos": Vector3(20, 0, -55), "yaw": PI}).order_stop()
			for i in 2:
				r.spawn_squad("fighter_cell", 1, b, Vector3(-10 + i * 20, 0, -40))
		"support":
			for i in 3:
				r.spawn_squad("fighter_cell", 1, b, Vector3(-12 + i * 12, 0, -30))
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 40))
			r.support_ready = [{"airstrike": 0.0, "a10": 0.0, "ac130": 0.0, "artillery": 0.0}, {"barrage": 0.0, "mortars": 0.0}]
			r.call_support(-1, 0, "airstrike", Vector3(0, 0, -30))
			r.call_support(-2, 1, "barrage", Vector3(30, 0, 30))
		"showroom":
			var kinds := ["tank", "old_tank", "technical", "truck"]
			for i in kinds.size():
				var v: Vehicle = world.spawn("vehicle", {"vkind": kinds[i], "team": 0, "owner": a, "pos": Vector3(-14 + i * 9.0, 0, 0), "yaw": 0.4})
				v.order_stop()
			_spawn("barracks", Vector3(-20, 0, -22), 0.0, 0)
			_spawn("research", Vector3(-38, 0, -22), 0.0, 0)
			_spawn("fob", Vector3(42, 0, -34), 0.0, 0, {"sname": "Showroom"})
			_spawn("factory", Vector3(0, 0, -24), 0.0, 0)
			_spawn("medic_tent", Vector3(18, 0, -20), 0.0, 0)
			_spawn("bunker", Vector3(-22, 0, 16), 0.0, 0)
			_spawn("bunker", Vector3(-8, 0, 18), 0.0, 1)
			_spawn("hmg_nest", Vector3(5, 0, 16), 0.0, 0)
			_spawn("mortar_pit", Vector3(14, 0, 16), 0.0, 0)
			_spawn("watchtower", Vector3(24, 0, 14), 0.0, 0)
			for i in 3:
				_spawn("trench", Vector3(-12 + i * 6.0, 0, 28), 0.0, 0)
				_spawn("sandbags", Vector3(10 + i * 4.2, 0, 26), 0.0, 0, {"size": Vector3(4, 1, 0.9)})
			_spawn("wreck", Vector3(30, 0, -2), 0.7, -1, {"variant": 0})
			_spawn("wreck", Vector3(30, 0, -14), 2.1, -1, {"variant": 1})
			for i in 4:
				_spawn("tree", Vector3(-36 + i * 4.0, 0, -6 + (i % 2) * 5.0), 0.0, -1)
			_spawn("house_wall", Vector3(36, 0, 20), 0.0, -1, {"size": Vector3(6, 0, 0.4), "variant": 1})
			_spawn("house_wall", Vector3(36, 0, 28), 0.0, -1, {"size": Vector3(6, 2, 0.4)})
			_spawn("low_wall", Vector3(-30, 0, 30), 0.0, -1, {"size": Vector3(4, 1, 0.5), "variant": 2})
			_spawn("low_wall", Vector3(-30, 0, 24), 0.0, -1, {"size": Vector3(4, 1, 0.5), "variant": 0})
			_spawn("car", Vector3(-30, 0, 8), 0.5, -1, {"variant": 1})
		"guns":
			# the crew-served guns side by side, each crewed: M240B and M2HB nests,
			# PKM and DShKM nests, and a machine-gun bay of each side in a trench
			var row := [["mg_nest", 0], ["hmg_nest", 0], ["mg_nest", 1], ["hmg_nest", 1]]
			for i in row.size():
				var st := _spawn(String(row[i][0]), Vector3(-16 + i * 10.0, 0, 0), PI, int(row[i][1]), {"built": true})
				_crew(st, a if int(row[i][1]) == 0 else b)
			_trench_line(Vector3(-18, 0, 16), Vector3(18, 0, 16), 0, false)
			for i in 4:
				var sp := world.trench_mount_spot(Vector3(-13.5 + i * 9.0, 0, 16), PI)
				if sp.is_empty():
					continue
				var bay := _spawn(["mg_nest", "hmg_nest"][i % 2], sp.pos, float(sp.yaw), 0 if i < 2 else 1, {"built": true, "variant": 1})
				_crew(bay, a if i < 2 else b)
			# something for each side's guns to shoot at, out in front
			r.spawn_squad("fighter_cell", 1, b, Vector3(-10, 0, 38), Vector3(-10, 0, 46))
			r.spawn_squad("rifle_squad", 0, a, Vector3(10, 0, 38), Vector3(10, 0, 46))
		"drone":
			r.spawn_squad("fpv_team", 1, b, Vector3(0, 0, -105))
			var tank: Vehicle = world.spawn("vehicle", {"vkind": "tank", "team": 0, "owner": a, "pos": Vector3(0, 0, 0), "yaw": 0.0})
			tank.order_stop()
			r.spawn_squad("rifle_squad", 0, a, Vector3(10, 0, 5))
		"cover":
			for i in 3:
				_spawn("low_wall", Vector3(-6 + i * 4.2, 0, -12), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			_spawn("tall_wall", Vector3(14, 0, -12), 0.0, -1, {"size": Vector3(4, 2.6, 0.5)})
			_spawn("crates", Vector3(-14, 0, -12), 0.0, -1, {"variant": 1})
			_spawn("car", Vector3(-20, 0, -12), PI * 0.5, -1, {"variant": 1})
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 0), Vector3(0, 0, -8))
			r.spawn_squad("fighter_cell", 1, b, Vector3(0, 0, -60), Vector3(0, 0, -50))
		"tank":
			_spawn("low_wall", Vector3(0, 0, -20), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			_spawn("tall_wall", Vector3(4.2, 0, -20), 0.0, -1, {"size": Vector3(4, 2.6, 0.5)})
			var t2: Vehicle = world.spawn("vehicle", {"vkind": "tank", "team": 0, "owner": a, "pos": Vector3(2, 0, 0), "yaw": 0.0})
			t2.order_move(Vector3(2, 0, -45))
			r.spawn_squad("rpg_team", 1, b, Vector3(-30, 0, -50))
			r.spawn_squad("fighter_cell", 1, b, Vector3(20, 0, -55))
		"defense":
			for i in 4:
				_spawn("trench", Vector3(-12 + i * 6.0, 0, -10), 0.0, 0)
			_spawn("hmg_nest", Vector3(-20, 0, -7), 0.0, 0)
			_spawn("mortar_pit", Vector3(0, 0, 14), 0.0, 0)
			var bk := _spawn("bunker", Vector3(18, 0, -7), 0.0, 0)
			_spawn("at_post", Vector3(6, 0, -3), 0.0, 0)
			r.spawn_squad("rifle_squad", 0, a, Vector3(-4, 0, 0), Vector3(-3, 0, -10))
			var sq2 := r.spawn_squad("rifle_squad", 0, a, Vector3(14, 0, 4))
			sq2.order_enter(bk)
			r.spawn_squad("mg_team", 0, a, Vector3(-18, 0, -2))
			r.spawn_squad("mortar_team", 0, a, Vector3(3, 0, 17))
			r.spawn_squad("at_team", 0, a, Vector3(7, 0, 1))
			for i in 3:
				r.spawn_squad("fighter_cell", 1, b, Vector3(-25 + i * 25, 0, -95), Vector3(-25 + i * 25, 0, -18))
			var tech: Vehicle = world.spawn("vehicle", {"vkind": "technical", "team": 1, "owner": b, "pos": Vector3(35, 0, -100), "yaw": PI})
			tech.order_move(Vector3(15, 0, -25))
			var otk: Vehicle = world.spawn("vehicle", {"vkind": "old_tank", "team": 1, "owner": b, "pos": Vector3(-35, 0, -105), "yaw": PI})
			otk.order_move(Vector3(-10, 0, -28))
		"trenches":
			# a Rebel trench system: zig-zag front line, a second line, communication
			# trenches between them, MG nests and a bunker; a Coalition armoured assault
			_trench_line(Vector3(-36, 0, -28), Vector3(36, 0, -28), 1)
			_trench_line(Vector3(-24, 0, -52), Vector3(24, 0, -52), 1)
			_trench_line(Vector3(-12, 0, -28), Vector3(-12, 0, -52), 1, false)
			_trench_line(Vector3(12, 0, -28), Vector3(12, 0, -52), 1, false)
			# a gun bay in the front line, and a sandbagged .50 behind it
			var bay2 := world.trench_mount_spot(Vector3(-22, 0, -28), PI)
			if not bay2.is_empty():
				_spawn("mg_nest", bay2.pos, float(bay2.yaw), 1, {"variant": 1})
			_spawn("hmg_nest", Vector3(24, 0, -33), PI, 1)
			_spawn("bunker", Vector3(0, 0, -58), PI, 1)
			_spawn("wire", Vector3(-15, 0, -16), 0.0, 1)
			_spawn("wire", Vector3(-8, 0, -15), 0.0, 1)
			_spawn("wire", Vector3(8, 0, -16), 0.0, 1)
			world.terrain.tick(1 << 30)
			for i in 3:
				var dq := r.spawn_squad("fighter_cell" if i != 1 else "rpg_team", 1, b, Vector3(-20 + i * 20, 0, -40))
				dq.order_defend(Vector3(-20 + i * 20, 0, -28), Vector3(0, 0, 1))
			var pq := r.spawn_squad("pkm_team", 1, b, Vector3(4, 0, -48))
			pq.order_defend(Vector3(4, 0, -52), Vector3(0, 0, 1))
			if not world.settings.get("static", false):
				for i in 2:
					var tk: Vehicle = world.spawn("vehicle", {"vkind": "tank", "team": 0, "owner": a, "pos": Vector3(-14 + i * 28, 0, 70), "yaw": 0.0})
					tk.order_assault(Vector3(-14 + i * 28, 0, -30))
				for i in 2:
					var ifv: Vehicle = world.spawn("vehicle", {"vkind": "ifv", "team": 0, "owner": a, "pos": Vector3(-6 + i * 12, 0, 80), "yaw": 0.0})
					ifv.embark_new_squad()
					ifv.order_assault(Vector3(-6 + i * 12, 0, -22))
				for i in 2:
					var aq := r.spawn_squad("rifle_squad", 0, a, Vector3(-10 + i * 20, 0, 82))
					aq.order_assault(Vector3(-10 + i * 20, 0, -30), Vector3(0, 0, -1))
		"attack":
			# a deliberate attack: two rifle squads and a gun team against a
			# fighter cell holding a walled farmyard
			for i in 3:
				_spawn("low_wall", Vector3(-8 + i * 4.2, 0, -40), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			_spawn("sandbags", Vector3(6, 0, -41), 0.0, 1)
			_spawn("low_wall", Vector3(-12, 0, -44), PI * 0.5, -1, {"size": Vector3(4, 1, 0.5)})
			for i in 5:
				_try("tree", Vector3(-34 + i * 3.0, 0, -12 - i * 4.0), 0.0, -1)
				_try("tree", Vector3(30 + i * 2.0, 0, -6 - i * 5.0), 0.0, -1)
			_spawn("crates", Vector3(-24, 0, 6), 0.4, -1, {"variant": 1})
			_spawn("low_wall", Vector3(18, 0, 8), 0.0, -1, {"size": Vector3(4, 1, 0.5), "variant": 1})
			var dq1 := r.spawn_squad("fighter_cell", 1, b, Vector3(-4, 0, -44))
			dq1.order_defend(Vector3(-2, 0, -42), Vector3(0, 0, 1))
			var sqa := []
			for i in 2:
				sqa.append(r.spawn_squad("rifle_squad", 0, a, Vector3(-10 + i * 20, 0, 30)))
			sqa.append(r.spawn_squad("mg_team", 0, a, Vector3(0, 0, 34)))
			if not world.settings.get("static", false):
				var ids := []
				for sq in sqa:
					ids.append(sq.sid)
				world.execute_cmd(a, {"t": "assault", "squads": ids, "pos": Vector3(-2, 0, -42), "face": Vector3(0, 0, -1)})
		"solo":
			# one squad attacks on its own: fire team Alpha fixes, Bravo flanks
			_spawn("sandbags", Vector3(0, 0, -36), 0.0, 1)
			_spawn("low_wall", Vector3(-6, 0, -36), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			for i in 5:
				_try("tree", Vector3(-26 + i * 3.0, 0, -6 - i * 5.0), 0.0, -1)
			var dq2 := r.spawn_squad("fighter_cell", 1, b, Vector3(-2, 0, -39))
			dq2.order_defend(Vector3(-2, 0, -37), Vector3(0, 0, 1))
			var sq2 := r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 30))
			if not world.settings.get("static", false):
				world.execute_cmd(a, {"t": "assault", "squads": [sq2.sid], "pos": Vector3(-2, 0, -37), "face": Vector3(0, 0, -1)})
		"poses":
			# animation gallery: every stance frozen in a row, three-quarter view
			var P := Soldier.Post
			var A := Soldier.Act
			var rows := [
				[[P.STAND, A.IDLE, 0, 0.0], [P.STAND, A.SHOOT, 0, 0.0], [P.STAND, A.RELOAD, 0, 0.0], [P.STAND, A.WALK, 0, 1.6], [P.STAND, A.RUN, 0, 4.8], [P.STAND, A.THROW, 0, 0.0]],
				[[P.CROUCH, A.IDLE, 0, 0.0], [P.CROUCH, A.SHOOT, 0, 0.0], [P.CROUCH, A.WALK, 0, 1.5], [P.LEAN_L, A.SHOOT, 0, 0.0], [P.LEAN_R, A.SHOOT, 0, 0.0], [P.CROUCH, A.RELOAD, 0, 0.0]],
				[[P.PRONE, A.IDLE, 0, 0.0], [P.PRONE, A.SHOOT, 0, 0.0], [P.PRONE, A.CRAWL, 0, 1.0], [P.STAND, A.IDLE, 2, 0.0], [P.STAND, A.IDLE, 2, 0.0], [P.STAND, A.IDLE, 2, 0.0]],
				[[P.STAND, A.SHOOT, 0, 0.0, Soldier.F_OVERWALL], [P.STAND, A.IDLE, 0, 0.0, Soldier.F_OVERWALL], [P.PRONE, A.CRAWL, 0, 0.75], [P.CROUCH, A.IDLE, 0, 0.0], [P.STAND, A.SHOOT, 0, 0.0, Soldier.F_OVERWALL], [P.PRONE, A.CRAWL, 0, 0.75]],
			]
			# a low wall in front of the over-the-wall men
			for wx in [-7.5, -4.5, 4.5]:
				_spawn("low_wall", Vector3(wx, 0, 8.0 - 0.75), 0.0, -1, {"size": Vector3(2.6, 1, 0.5)})
			for ri in rows.size():
				var row: Array = rows[ri]
				for ci in row.size():
					var ut := "rifleman" if ri != 1 or ci != 2 else "mg_gunner"
					world.spawn("soldier", {"utype": ut, "team": 0 if ci % 2 == 0 else 1, "owner": a, "pos": Vector3(-7.5 + ci * 3.0, 0, -4.0 + ri * 4.0), "yaw": 2.3 if ri < 3 else 0.35, "name": "P%d%d" % [ri, ci], "dpose": row[ci]})
		"lean":
			for i in 3:
				_spawn("tall_wall", Vector3(-14 + i * 14.0, 0, -10), 0.0, -1, {"size": Vector3(6, 2.6, 0.5)})
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 0), Vector3(0, 0, -6))
			r.spawn_squad("fighter_cell", 1, b, Vector3(0, 0, -55), Vector3(0, 0, -45))
		"heli":
			var pad := _spawn("helipad", Vector3(30, 0, 100), 0.0, 0, {"built": true})
			pad.queue_item(a, "heli")
			f0.supply = 100.0
		"tunnel":
			var t1 := _spawn("tunnel", Vector3(-20, 0, -60), 0.0, 1, {"built": true})
			var t2 := _spawn("tunnel", Vector3(30, 0, 10), 0.0, 1, {"built": true})
			var sq := r.spawn_squad("fighter_cell", 1, b, Vector3(-20, 0, -50))
			sq.order_enter(t1)
			# the scenario may be torn down before it fires
			world.get_tree().create_timer(12.0, true, true).timeout.connect(func():
				if is_instance_valid(r) and is_instance_valid(t1) and is_instance_valid(t2) and not t1.gone and not t2.gone:
					r.tunnel_exit(t1, t2, b))
		"grenade":
			for i in 2:
				_spawn("low_wall", Vector3(-2 + i * 4.2, 0, -16), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 0), Vector3(0, 0, -6))
			r.spawn_squad("fighter_cell", 1, b, Vector3(0, 0, -40), Vector3(0, 0, -20))
	r.rebuild_network(0)
	r.rebuild_network(1)


## A machine gunner for a scenario's emplacement, already on the gun.
func _crew(st: Structure, owner: int) -> void:
	var ut := "pkm" if st.team == 1 else "mg_gunner"
	var s: Soldier = world.spawn("soldier", {"utype": ut, "team": st.team, "owner": owner, "pos": st.mount_pos() * Vector3(1, 0, 1), "yaw": st.yaw})
	s.start_man(st)


func _trench_line(a: Vector3, b: Vector3, team: int, zig := true) -> void:
	for it in TrenchNet.layout(a, b, zig):
		_spawn("trench", it[0], it[1], team, {"size": Vector3(it[2], 3.0, 3.2)})


func _spawn(kind: String, pos: Vector3, yaw: float, team: int, extra := {}) -> Structure:
	var props := {"skind": kind, "pos": pos, "yaw": yaw, "team": team}
	props.merge(extra, true)
	var st: Structure = world.spawn("structure", props)
	placed.append([Vector2(pos.x, pos.z), st.foot, yaw])
	return st


func _foot_of(kind: String, extra: Dictionary) -> Vector2:
	if extra.has("size"):
		var s: Vector3 = extra.size
		return Vector2(s.x * 0.5, s.z * 0.5)
	match kind:
		"wreck":
			return Vector2(1.9, 3.3)
		"car":
			return Vector2(1.0, 2.2)
		"crates":
			return Vector2(1.3, 0.7)
		"tree":
			return Vector2(0.6, 0.6)
	if Defs.BUILDINGS.has(kind):
		var s2: Vector2 = Defs.BUILDINGS[kind].size
		return s2 * 0.5
	return Vector2(1, 1)


func _is_free(pos: Vector3, half: Vector2, yaw: float, margin := 0.6, use_clear := true) -> bool:
	if not Defs.in_map(pos, 6.0):
		return false
	var c := Vector2(pos.x, pos.z)
	if use_clear:
		for cl in clear:
			if c.distance_to(cl[0]) < cl[1] + half.length():
				return false
	var h := half + Vector2(margin, margin)
	for p in placed:
		if c.distance_to(p[0]) > h.length() + p[1].length() + 1.0:
			continue
		if Defs.obb_overlap(c, h, yaw, p[0], p[1], p[2]):
			return false
	return true


func _try(kind: String, pos: Vector3, yaw: float, team: int, extra := {}) -> Structure:
	var half := _foot_of(kind, extra)
	if not _is_free(pos, half, yaw):
		return null
	return _spawn(kind, pos, yaw, team, extra)


func _wobble(pts: Array, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var n := int(d.length() / 28.0)
	var side := d.normalized().cross(Vector3.UP)
	for k in range(1, n + 1):
		var t := float(k) / (n + 1)
		pts.append(a.lerp(b, t) + side * rng.randf_range(-7.0, 7.0))


## Catmull-Rom through the control points, a point every ~3 m.
func _smooth(pts: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		var k := maxi(1, int(p1.distance_to(p2) / 3.0))
		for j in k:
			var t := float(j) / k
			var t2 := t * t
			var t3 := t2 * t
			var p := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			p.x = clampf(p.x, -127.0, 127.0)
			p.z = clampf(p.z, -134.0, 134.0)
			out.append(Vector3(p.x, 0, p.z))
	out.append(pts[n - 1])
	return out


## A roofless house of wall sections, its front (door) towards the street.
## Returns false if there's no room.
func _house(c: Vector3, w: float, d: float, axis: float, street_side: float, yard := true, ruin_p := 0.35) -> bool:
	var half := Vector2(w * 0.5 + 0.3, d * 0.5 + 0.3)
	if not _is_free(c, half, axis, 1.0):
		return false
	var b := Basis(Vector3.UP, axis)
	var color := rng.randi() % Structure.HOUSE_COLORS.size()
	var ruined := rng.randf() < ruin_p
	_spawn("floor", c, axis, -1, {"size": Vector3(w, 0.06, d)})
	placed.pop_back()
	placed.append([Vector2(c.x, c.z), half, axis])
	# four walls: front faces the street
	var sides := [
		[Vector3(0, 0, -d * 0.5), w, 0.0],
		[Vector3(0, 0, d * 0.5), w, 0.0],
		[Vector3(-w * 0.5, 0, 0), d - 0.4, PI * 0.5],
		[Vector3(w * 0.5, 0, 0), d - 0.4, PI * 0.5],
	]
	var door_side := 0 if street_side > 0 else 1
	if rng.randf() < 0.3:
		door_side = 2 + rng.randi() % 2
	for si in 4:
		var s: Array = sides[si]
		var L: float = s[1]
		var segs := maxi(1, int(round(L / 2.8)))
		var seg_len := L / segs
		var door_i := rng.randi() % segs if si == door_side else -1
		for k in segs:
			var local_off := (k + 0.5) * seg_len - L * 0.5
			var lp: Vector3 = s[0] + (Vector3(local_off, 0, 0) if s[2] == 0.0 else Vector3(0, 0, local_off))
			var wp: Vector3 = c + b * lp
			# turned so the wall's local +z faces out of the house (the model
			# dresses that face: sills, frames, shutters, the door step)
			var yaw: float = axis + s[2] + (PI if si == 0 or si == 2 else 0.0)
			if ruined and rng.randf() < 0.3:
				if rng.randf() < 0.6:
					world.spawn("structure", {"skind": "rubble", "pos": wp, "yaw": yaw + rng.randf_range(-0.2, 0.2), "size": Vector3(seg_len * 0.9, 0, 1.2)})
				continue
			var variant := 0
			if k == door_i:
				variant = 2
			elif seg_len > 2.0 and rng.randf() < 0.5:
				variant = 1
			world.spawn("structure", {"skind": "house_wall", "pos": wp, "yaw": yaw, "variant": variant, "size": Vector3(seg_len, float(color), 0.4)})
	# a roof on every house still standing: tiled and pitched, or flat
	if not ruined:
		world.spawn("structure", {"skind": "roof", "pos": c, "yaw": axis, "size": Vector3(w, 3.0, d), "variant": color * 2 + (1 if rng.randf() < 0.4 else 0)})
	if rng.randf() < 0.5:
		var ip := c + b * Vector3(rng.randf_range(-w * 0.25, w * 0.25), 0, rng.randf_range(-d * 0.2, d * 0.2))
		world.spawn("structure", {"skind": "crates", "pos": ip, "yaw": axis + rng.randf_range(-0.4, 0.4), "variant": 0})
	if ruined and rng.randf() < 0.6:
		var ip2 := c + b * Vector3(rng.randf_range(-w * 0.25, w * 0.25), 0, rng.randf_range(-d * 0.25, d * 0.25))
		world.spawn("structure", {"skind": "rubble", "pos": ip2, "yaw": rng.randf() * TAU, "size": Vector3(2.2, 0, 1.4)})
	# yard wall behind the house
	if yard and rng.randf() < 0.55:
		var back := -street_side
		var yc := c + b * Vector3(0, 0, back * (d * 0.5 + 5.0))
		var segs2 := int(w / 4.0)
		for k in segs2:
			if rng.randf() < 0.25:
				continue
			var lp2 := Vector3((k + 0.5) * 4.0 - segs2 * 2.0, 0, 0)
			_try("low_wall", yc + b * lp2, axis, -1, {"size": Vector3(4.0, 1.0, 0.5), "variant": 0 if rng.randf() < 0.7 else 2})
	return true


func _hedgerow() -> void:
	# field walls run on the same 1 m / 45 degree grid as everything built
	var p := TrenchNet.snap_pos(Vector3(rng.randf_range(-110, 110), 0, rng.randf_range(-75, 75)))
	var yaw := TrenchNet.snap_yaw(rng.randf() * PI)
	if rng.randf() < 0.6:
		yaw = 0.0 if rng.randf() < 0.5 else PI * 0.5
	var dir := Vector3(cos(yaw), 0, -sin(yaw))
	var n := rng.randi_range(4, 10)
	var variant := 1 if rng.randf() < 0.55 else 0
	for i in n:
		if rng.randf() < 0.12:
			continue
		var c := p + dir * (i - n * 0.5) * 4.0
		_try("low_wall", c, yaw, -1, {"size": Vector3(4.0, 1.0, 0.5), "variant": variant})


func _crate_cluster(c: Vector3) -> void:
	for i in rng.randi_range(1, 4):
		var p := c + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		_try("crates", p, rng.randf() * TAU, -1, {"variant": rng.randi() % 2})


func _old_position(c: Vector3) -> void:
	c = TrenchNet.snap_pos(c)
	var yaw := TrenchNet.snap_yaw(rng.randf_range(-0.4, 0.4) + (0.0 if rng.randf() < 0.7 else PI * 0.5))
	var dir := Vector3(cos(yaw), 0, -sin(yaw))
	if rng.randf() < 0.5:
		var n := rng.randi_range(2, 4)
		var items := TrenchNet.layout(c, c + dir * n * 6.0, rng.randf() < 0.6)
		for it in items:
			if not _is_free(it[0], Vector2(float(it[2]) * 0.5 + TrenchNet.HALF_W, 1.6), it[1]):
				return
		for it in items:
			_spawn("trench", it[0], it[1], -1, {"size": Vector3(it[2], 3.0, 3.2)})
	else:
		for i in rng.randi_range(2, 4):
			_try("sandbags", c + dir * i * 4.2, yaw, -1)
		_try("sandbags", c - dir * 2.5 + dir.cross(Vector3.UP) * 2.0, yaw + PI * 0.5, -1)


func _woods(c: Vector3, n: int) -> void:
	for i in n:
		var p := c + Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-11, 11))
		_try("tree", p, 0.0, -1)
