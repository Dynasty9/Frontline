extends Node
## Support aircraft fly as aeroplanes: no snaps in position or height, banked
## turns, the gun-run's nose on the target when it fires, a climbing break
## after the bombs, and the gunship rolling into its orbit and out of it.
## FL_DEBUG_FLIGHT=1 prints the flight every half second.

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	TestRun.watch()
	for kind in ["airstrike", "a10", "ac130", "gryphon_recon"]:
		await _fly(kind)
	print("AIRCRAFT FLIGHT %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _fly(kind: String) -> void:
	var demo = load("res://scripts/ui/support_demo.gd").new()
	demo.settings = {"map_size": 1024, "seed": 7, "mood": "day"}
	demo.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(demo)
	await demo.prepare(kind)
	demo.set_physics_process(false)
	var plane: Projectile = null
	for p in demo.projectiles:
		if p.ptype in ["jet", "a10", "ac130"]:
			plane = p
	check(plane != null, kind + ": an aircraft is launched")
	if plane == null:
		demo.free()
		return
	var dt := 1.0 / 30.0
	var last := plane.position
	var max_step := 0.0
	var max_bank := 0.0
	var min_agl := INF
	var max_climb := -INF
	var fire_err := -1.0
	var fire_dive := 0.0
	var first_bank := -1.0
	var gone_at := -1.0
	var debug := OS.has_environment("FL_DEBUG_FLIGHT")
	for step in 1500:
		demo.time += dt
		demo._rebuild_uhash()
		for p in demo.projectiles.duplicate():
			if not p.gone:
				p.sim(dt)
		demo.fires.tick(dt)
		if plane.gone:
			gone_at = demo.time
			break
		var spd: float = maxf(plane.vel.length(), 1.0)
		max_step = maxf(max_step, plane.position.distance_to(last) / (spd * dt))
		last = plane.position
		var roll: float = plane._ac_bank(plane.life_t) if plane.ptype == "ac130" else plane.bank
		if first_bank < 0.0:
			first_bank = absf(roll)
		max_bank = maxf(max_bank, absf(roll))
		min_agl = minf(min_agl, plane.position.y - demo.terrain.landform.height(plane.position))
		max_climb = maxf(max_climb, plane.vel.y / spd)
		if plane.ptype == "a10" and plane._phase == 2 and fire_err < 0.0:
			# the gun points where the nose does: the burst's first rounds must be in front of it
			var nose: Vector3 = Projectile.flight_basis(plane.vel, plane.bank) * Vector3.FORWARD
			fire_err = rad_to_deg(nose.angle_to(plane._a10_pip(0.0) - plane.position))
			fire_dive = rad_to_deg(-asin(plane.vel.normalized().y))
		if debug and step % 15 == 0:
			print("FLIGHT %s t=%.1f pos=(%.0f, %.0f, %.0f) agl=%.0f v=%.0f climb=%.0f bank=%.0f phase=%d" % [kind, demo.time, plane.position.x, plane.position.y, plane.position.z,
				plane.position.y - demo.terrain.landform.height(plane.position), spd, rad_to_deg(asin(clampf(plane.vel.y / spd, -1, 1))), rad_to_deg(roll), plane._phase])
		if plane.ptype == "ac130" and plane.life_t > Projectile.AC_IN + 6.0 and plane.life_t < Projectile.AC_IN + plane.on_station() - 2.0:
			check(absf(Vector2(plane.position.x, plane.position.z).length() - Projectile.AC_R) < 1.0, kind + ": circles the target at its radius")
			check(absf(rad_to_deg(roll) - 44.7) < 1.0, kind + ": holds the bank its turn needs")
	check(max_step < 1.05, kind + ": moves no faster than it flies (no snaps), worst %.2f" % max_step)
	check(gone_at > 0.0, kind + ": flies off and is gone")
	check(min_agl > 12.0, kind + ": stays clear of the ground (lowest %.0f m)" % min_agl)
	match kind:
		"airstrike":
			check(max_bank > deg_to_rad(60.0), "the bomb run breaks away hard after the drop (bank %.0f)" % rad_to_deg(max_bank))
			check(max_climb > 0.3, "and climbs out")
			check(demo.stats.get("support_airstrike", 0) == 1, "the bombs were dropped")
		"a10":
			check(demo.stats.get("a10_run", 0) == 1, "the gun run fires")
			check(fire_err >= 0.0 and fire_err < 5.0, "the nose is on the target when the gun fires (off by %.1f deg)" % fire_err)
			check(fire_dive > 8.0 and fire_dive < 22.0, "firing in a shallow dive (%.1f deg)" % fire_dive)
			check(max_climb > 0.3 and max_bank > deg_to_rad(40.0), "pulls off in a climbing turn")
		"ac130":
			check(first_bank < 0.01, "runs in wings level")
			check(absf(plane._ac_bank(Projectile.AC_IN + plane.on_station() + Projectile.AC_OUT)) < 0.01, "rolls out to fly off")
		"gryphon_recon":
			check(max_bank < 0.05, "a recon pass flies straight along its line")
	var damaged: bool = demo.vehicles.size() < 3
	for v in demo.vehicles:
		if v.hp < v.max_hp:
			damaged = true
	if kind != "gryphon_recon":
		check(damaged, kind + ": still hits the range targets")
	demo.free()
	await get_tree().process_frame
