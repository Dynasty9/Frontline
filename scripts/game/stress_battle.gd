class_name StressBattle
extends RefCounted
## Repeatable workloads using the real squad orders, weapons and simulation.

static func populate(w: World) -> void:
	var count := clampi(int(w.settings.get("stress_units", 500)), 2, 2000)
	var mode := String(w.settings.get("stress_mode", "combat"))
	var scenery := clampi(int(w.settings.get("stress_scenery", 200)), 0, 10000)
	for i in scenery:
		var x := float(i % 25 - 12) * 8.0
		var z := float(i / 25) * 8.0 - 32.0
		w.spawn("structure", {"skind": "sandbags" if i % 4 == 0 else "tree", "pos": Vector3(x, 0, z), "team": -1})
	var made := 0
	var index := [0, 0]
	while made < count:
		var team := made % 2
		# Alternate squads, rather than individual soldiers, between the sides.
		team = (index[0] + index[1]) % 2
		var key := "rifle_squad" if team == 0 else "fighter_cell"
		var spec: Dictionary = Defs.SQUADS[key]
		var owner := -1 - team
		if w.settings.get("scenario_player", false):
			for peer in Net.players:
				if int(Net.players[peer].team) == team:
					owner = int(peer)
					break
		var sq := w.new_squad(team, owner, key)
		var n: int = index[team]
		index[team] += 1
		var spread := mode in ["idle", "march"]
		var spacing := 32.0 if spread else 12.0
		var x := (n % 10 - 4.5) * spacing
		var z := (110.0 + (n / 10) * spacing) if spread else (24.0 + (n / 10) * spacing)
		if team == 1:
			z = -z
		var pos := Vector3(x, 0, z)
		for ut in spec.members:
			if made >= count:
				break
			var j := sq.members.size()
			var p := w.nav.nearest_walkable(pos + Vector3((j % 3) * 1.4, 0, (j / 3) * 1.4))
			var s: Soldier = w.spawn("soldier", {"utype": ut, "team": team, "owner": sq.owner, "pos": p, "squad": sq.sid, "name": "Stress %d" % made})
			sq.add(s)
			made += 1
		sq.order_pos = pos
		sq.facing = Vector3.FORWARD if team == 0 else Vector3.BACK
		if mode == "march":
			sq.order_move(pos + Vector3(0, 0, -180 if team == 0 else 180), sq.facing)
		elif mode == "combat":
			sq.order_move(Vector3(x, 0, 0), sq.facing)
		else:
			sq.order_defend(pos, sq.facing)
	var vehicles := clampi(int(w.settings.get("stress_vehicles", 0)), 0, 64)
	for i in vehicles:
		var team := i % 2
		var choices := ["tank", "ifv", "humvee"] if team == 0 else ["old_tank", "btr", "technical"]
		var p := Vector3((i / 2 - vehicles / 4) * 12.0, 0, 75.0 if team == 0 else -75.0)
		p = w.nav.nearest_walkable(p, true)
		var v: Vehicle = w.spawn("vehicle", {"vkind": choices[(i / 2) % 3], "team": team, "owner": -1 - team, "pos": p, "yaw": 0.0 if team == 0 else PI})
		if mode != "idle":
			v.order_move(p + Vector3(0, 0, -90.0 if team == 0 else 90.0))
	print("STRESS units=%d vehicles=%d mode=%s scenery=%d map=%d" % [made, vehicles, mode, scenery, MapDims.N])
