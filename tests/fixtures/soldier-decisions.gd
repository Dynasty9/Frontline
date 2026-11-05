extends Node
## Preserve the old tree as a reference for priority and short-circuit behavior.
class Man extends Soldier:
	var calls: Array[String] = []
	var win := ""
	func record(key: String) -> bool:
		calls.append(key)
		return win == key
	func _react_grenade() -> bool: return record("grenade")
	func _react_shells(_only: bool) -> bool: return record("shell")
	func _react_drones() -> void: dive_t = 1.0 if record("drone") else 0.0
	func _try_melee() -> bool: return record("melee")
	func _scavenge() -> void:
		if record("scavenge"):
			task = "resupply"
	func _try_mortar() -> bool: return record("mortar")
	func _try_rocket() -> bool: return record("rocket")
	func _try_drone() -> bool: return record("launch drone")
	func _try_grenade() -> bool: return record("throw grenade")
	func _fight_think() -> void: record("hold")

func _ready() -> void:
	var world := World.new()
	var reference := reference_tree()
	var checks := 0
	for duty in ["", "smother", "retreat", "man", "pilot", "build"]:
		for win in ["", "grenade", "shell", "drone", "melee", "scavenge", "mortar", "rocket", "launch drone", "throw grenade"]:
			var before := Man.new()
			var after := Man.new()
			for man in [before, after]:
				man.world = world
				man.frags = 0
				man.task = duty
				man.win = win
				man.bt_path = "previous decision"
			reference.tick(before)
			SoldierBrain.think(after)
			assert(before.calls == after.calls, "%s/%s: call order changed" % [duty, win])
			assert(before.bt_path == after.bt_path, "%s/%s: debug decision changed" % [duty, win])
			assert(before.task == after.task and before._sector == after._sector)
			before.free()
			after.free()
			checks += 1
	world.free()
	print("SOLDIER_DECISIONS passed %d" % checks)
	get_tree().quit()

func reference_tree() -> BT.Branch:
	return BT.sel("brain", [
		# committed: lying on a grenade there's nothing else to decide
		BT.cond("committed", func(s): return s.task == "smother"),
		BT.seq("busy", [
			BT.cond("busy", func(s): return SoldierBrain.busy(s)),
			BT.always(BT.sel("save himself", [
				BT.act("dive from a grenade", func(s): return SoldierBrain.ok(s._react_grenade())),
				BT.act("dive from a shell", func(s): return SoldierBrain.ok(s._react_shells(true))),
			])),
		]),
		BT.sel("reflexes", [
			BT.seq("grenade!", [
				BT.cond("grenade landed by him", func(s): return SoldierBrain.grenade_close(s)),
				BT.sel("deal with it", [
					BT.seq("smother", [BT.cond("nobody else can be saved", func(s): return SoldierBrain.can_smother(s)), BT.act("throw himself on it", func(s): return SoldierBrain.smother(s))]),
					BT.seq("throw back", [BT.cond("time to throw it back", func(s): return SoldierBrain.can_throw_back(s)), BT.act("pick it up", func(s): return SoldierBrain.throw_back(s))]),
					BT.seq("kick", [BT.cond("at his feet", func(s): return SoldierBrain.can_kick(s)), BT.act("kick it away", func(s): return SoldierBrain.kick(s))]),
					BT.seq("wall", [BT.cond("a wall between", func(s): return SoldierBrain.wall_between(s)), BT.act("get down behind it", func(s): return SoldierBrain.duck(s))]),
					BT.act("dive clear", func(s): return SoldierBrain.dive_clear(s)),
				]),
			]),
			BT.act("shell incoming", func(s): return SoldierBrain.ok(s._react_shells(false))),
			BT.act("drone diving", func(s): return SoldierBrain.drone(s)),
			BT.seq("melee", [BT.cond("hands free", func(s): return s.task != "man" and s.task != "pilot"), BT.act("hand to hand", func(s): return SoldierBrain.ok(s._try_melee()))]),
		]),
		BT.seq("duty", [
			BT.always(BT.act("scavenge", func(s): return SoldierBrain.scavenge(s))),
			BT.cond("free", func(s): return s.task == ""),
			BT.always(BT.sel("fight", [
				BT.seq("clear a house", [BT.cond("enemy in a house", func(s): return SoldierBrain.can_breach(s)), BT.act("stack on the door", func(s): return SoldierBrain.breach(s))]),
				BT.act("mortar", func(s): return SoldierBrain.ok(s._try_mortar())),
				BT.act("launcher", func(s): return SoldierBrain.ok(s._try_rocket())),
				BT.act("drone", func(s): return SoldierBrain.ok(s._try_drone())),
				BT.act("grenade", func(s): return SoldierBrain.ok(s._try_grenade())),
				BT.act("hold", func(s): return SoldierBrain.hold(s)),
			])),
			BT.act("watch his sector", func(s): return SoldierBrain.sector(s)),
		]),
	])

