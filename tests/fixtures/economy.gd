extends Node
## The economy's rules on their own (no battle): what research the old
## vehicles need, how much of a dump a taker gets, and how big HQ's loads are
## for a side behind on towns. Prints ECONOMY passed, or what failed.

var failed := []


func check(ok: bool, what: String) -> void:
	if not ok:
		failed.append(what)


func _ready() -> void:
	var world := World.new()
	var r := Rules.new(world)
	# the doctrine tree: tanks, IFVs and attack helicopters each come with their own step
	check(r.tier_needed(0, "tank") == "Armoured Warfare", "the tank needs Armoured Warfare (got '%s')" % r.tier_needed(0, "tank"))
	check(r.tier_needed(0, "ifv") == "Mechanised Infantry", "the IFV needs Mechanised Infantry (got '%s')" % r.tier_needed(0, "ifv"))
	check(r.tier_needed(0, "gunship") == "Attack Aviation", "the gunship needs Attack Aviation (got '%s')" % r.tier_needed(0, "gunship"))
	check(r.tier_needed(1, "btr") == "Foreign Advisers", "the BTR needs Foreign Advisers (got '%s')" % r.tier_needed(1, "btr"))
	check(r.tier_needed(1, "old_tank") == "Armour Shipments", "the old tank needs Armour Shipments (got '%s')" % r.tier_needed(1, "old_tank"))
	for k in ["humvee", "heli", "rhib"]:
		check(r.tier_needed(0, k) == "", "%s is there from the start" % k)
	for k in ["technical", "aa_tech", "motorboat"]:
		check(r.tier_needed(1, k) == "", "%s is there from the start" % k)
	# a step needs the one before it
	check(not r.can_research(0, "c_armour"), "Armoured Warfare waits for Mechanised Infantry")
	check(r.can_research(0, "c_mech"), "Mechanised Infantry can start at once")
	r.upgrades[0]["c_mech"] = true
	check(r.can_research(0, "c_armour"), "Mechanised Infantry opens Armoured Warfare")
	check(not r.can_research(1, "c_mech"), "a side can't research the other's doctrine")
	r.upgrades[0]["c_armour"] = true
	check(r.tier_needed(0, "tank") == "", "Armoured Warfare unlocks the tank")
	# every vehicle each side can build is there from the start or unlocked by
	# exactly one step of its own tree, and every step can be reached
	for t in 2:
		for b in ["factory", "helipad", "dock"]:
			for item in Defs.BUILDINGS[b].produces[t]:
				var by := []
				for k in Defs.UPGRADES:
					if t in Defs.UPGRADES[k].teams and item in Defs.UPGRADES[k].get("unlocks", []):
						by.append(k)
				check(by.size() <= 1, "%s is unlocked by one step, not %s" % [item, str(by)])
				if int(Defs.VEHICLES[item].get("tier", 1)) > 1:
					check(by.size() == 1, "%s (tier %d) is unlocked by a step of side %d's tree" % [item, int(Defs.VEHICLES[item].tier), t])
		for k in Defs.UPGRADES:
			var u: Dictionary = Defs.UPGRADES[k]
			if not t in u.teams:
				continue
			for it in u.get("unlocks", []):
				var built := false
				for b in ["factory", "helipad", "dock"]:
					if it in Defs.BUILDINGS[b].produces[t]:
						built = true
				check(built, "%s unlocks %s, which side %d builds somewhere" % [k, it, t])
			for rq in Defs.requires_of(k):
				check(Defs.UPGRADES.has(rq) and t in Defs.UPGRADES[rq].teams, "%s needs %s, a step of side %d's own tree" % [k, rq, t])
	# researching the whole tree, a step at a time, unlocks everything
	var rr := Rules.new(world)
	for t in 2:
		for _pass in 8:
			for k in Defs.UPGRADES:
				if rr.can_research(t, k):
					rr.upgrades[t][k] = true
		for b in ["factory", "helipad", "dock"]:
			for item in Defs.BUILDINGS[b].produces[t]:
				check(rr.tier_needed(t, item) == "", "side %d can get %s with the whole tree researched" % [t, item])
	# a dump that falls is half burnt
	var st := Structure.new()
	st.world = world
	st.supply = 301.0
	var burnt := r._fire_the_dump(st)
	check(burnt == 150 and int(st.supply) == 151, "a fallen dump keeps half (burnt %d, left %d)" % [burnt, int(st.supply)])
	# HQ's loads grow for each town a side is behind by, up to the cap
	check(r.hq_load(0) == Defs.SUPPLY_PER_TRUCK[0], "a side level on towns gets the usual load")
	r.hq_priority[1] = 2
	check(r.hq_load(1) == int(round(Defs.SUPPLY_PER_TRUCK[1] * (1.0 + 2.0 * Defs.HQ_PRIORITY))), "two towns behind gets a bigger load (%d)" % r.hq_load(1))
	check(r.hq_load(0) == Defs.SUPPLY_PER_TRUCK[0], "the side ahead loses nothing")
	st.free()
	world.free()
	if failed.is_empty():
		print("ECONOMY passed")
	else:
		for f in failed:
			print("ECONOMY failed: ", f)
	get_tree().quit()
