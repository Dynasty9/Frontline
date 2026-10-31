extends "res://tests/fixtures/infantry-special.gd"

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
	Nav.N = 64; Nav.H = 32.0
	HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	checks = 0
	for mode in 12:
		for trial in 64:
			var w: World = ground_world()
			w.settings = {"rust_infantry": false}
			w.rng.seed = 73241 + trial; random.seed = 73241 + trial
			var s := make_soldier(w, 1, trial % 2)
			s.position = Vector3([0.0, 0.0999, 0.1, 0.1001, 3.0, 31.0][trial % 6], 0, 0)
			s.at_cover = true; s.peek_up = true; s.blind = true; s.cover_type = 2
			s.cover_ai = 3; s.cover_n = Vector3.BACK; s.cover_h = 1.2; s.cover_mat = 1
			s._shifting = true; s._fire_flee_t = 10.0
			s.say_cd = 3.0
			s.task = "heal" if trial % 2 == 0 else "retreat"
			var mount := Mount.new(); mount.eid = 20; w.add_child(mount); s.cover_st = mount
			var ride := Carrier.new(); ride.eid = 30; w.add_child(ride)
			match mode:
				0: pass
				1: s.life = Soldier.Life.DOWNED
				2: s.life = Soldier.Life.DEAD
				3: s.life = Soldier.Life.SURRENDER
				4: s.mounted = mount
				5: s.riding = ride
				6: s.task = "smother"
				7: s.task = "stretcher"
				8: s.task = "tunnel"
				9: s.act = Soldier.Act.DIVE
				10: s.life = Soldier.Life.HIDDEN
				11:
					for x in range(32, 48):
						for z in range(26, 38):
							w.nav.ikind[z * 64 + x] = 3
							w.nav.inf.set_point_solid(Vector2i(x, z), true)
			assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
			assert(core.load_state(InfantryState.capture(s)))
			for now in [9.99, 10.0, 12.499, 12.5]:
				w.time = now; w.nav.jobs.clear(); w.spoken.clear(); w.stats.clear()
				s.flee_fire(Vector3.ZERO)
				var result: Array = core.flee_fire(Vector3.ZERO, now, w.nav._planner, random._backend)
				assert(not result.is_empty())
				helper.check_state(s, core, "fire escape %d/%d/%s" % [mode, trial, now]); checks += 1
				assert(w.rng.state == random.state, "fire escape random")
				if result[0]:
					assert(w.stats == {"fire_flee": 1})
					assert(w.nav.jobs.size() == 1)
					assert(w.nav.jobs[0].slice(0, 5) == [s.eid, result[1], false, s.team, result[2]])
					var speech := []
					if result[3] >= 0:
						speech.append([s.eid, ["Fire! Get back!", "It's burning! Move!", "Back, back - it's going up!", "Get out of the fire!"][result[3]]]); seen.speech = true
					assert(w.spoken == speech)
					seen.escape = true
				else:
					assert(w.stats.is_empty() and w.nav.jobs.is_empty() and w.spoken.is_empty())
					seen.wait = true
				assert(core.restore(core.checkpoint()))
			w.free()
	helper.free()
	assert(seen.has("speech") and seen.has("escape") and seen.has("wait"))
	print("FIRE_ESCAPE passed states=", checks)
	get_tree().quit()
