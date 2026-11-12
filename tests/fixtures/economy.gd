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
	# tanks, IFVs and attack helicopters need tier 2 like the rest of the roster's
	for k in ["tank", "ifv", "gunship"]:
		check(r.tier_needed(0, k) == "Armoured Warfare", "%s needs Armoured Warfare (got '%s')" % [k, r.tier_needed(0, k)])
	for k in ["old_tank", "btr"]:
		check(r.tier_needed(1, k) == "Foreign Advisers", "%s needs Foreign Advisers (got '%s')" % [k, r.tier_needed(1, k)])
	for k in ["humvee", "heli"]:
		check(r.tier_needed(0, k) == "", "%s is there from the start" % k)
	for k in ["technical", "aa_tech"]:
		check(r.tier_needed(1, k) == "", "%s is there from the start" % k)
	r.upgrades[0]["armour_doctrine"] = true
	check(r.tier_needed(0, "tank") == "", "Armoured Warfare unlocks the tank")
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
