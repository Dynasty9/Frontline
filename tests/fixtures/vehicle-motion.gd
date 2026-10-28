extends Node

class MountCombat extends Combat:
	var mortars := 0
	var rockets := 0
	func fire_mortar(_shooter: Soldier, _from: Vector3, _to: Vector3, _kind: String) -> void:
		mortars += 1

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	TestRun.watch()
	for hz in [30, 60]:
		for kind: String in Defs.VEHICLES:
			var v := Vehicle.new()
			v.vkind = kind
			v.vdef = Defs.VEHICLES[kind]
			var p := v.motion_profile()
			var previous := 0.0
			for step in hz * 12:
				var old := v.turret_yaw
				v._slew_turret(PI * 0.5, 1.0 / hz)
				check(absf(wrapf(v.turret_yaw - old, -PI, PI)) <= float(p.traverse) / hz + 0.00001, kind + " traverse cap")
				check(absf(v._traverse - previous) <= float(p.traverse_accel) / hz + 0.00001, kind + " traverse acceleration/braking")
				previous = v._traverse
			check(absf(v.turret_yaw - PI * 0.5) < 0.01, kind + " settles on bearing")
			v.free()
	var old_tank := VehicleMotion.profile("old_tank", Defs.VEHICLES.old_tank)
	var modern := VehicleMotion.profile("tank", Defs.VEHICLES.tank)
	check(float(old_tank.traverse) < float(modern.traverse) * 0.5, "older drive is substantially slower")
	var heavy := VehicleMotion.profile("huron", Defs.VEHICLES.huron)
	var light := VehicleMotion.profile("hummingbird", Defs.VEHICLES.hummingbird)
	check(float(heavy.hull_turn) < float(light.hull_turn), "heavy lift yaw slower than a light helicopter")
	var field := World.new()
	field.has_view = false
	field.set_process(false)
	field.set_physics_process(false)
	# Do not run World._ready/map generation; only its entity lookup is needed.
	var vehicle := Vehicle.new()
	vehicle.world = field
	vehicle.vkind = "gunship"
	vehicle.vdef = Defs.VEHICLES.gunship
	vehicle.eid = 42
	add_child(vehicle)
	vehicle.position = Vector3(40, 18, -12)
	vehicle.rotation.y = 0.7
	vehicle.turret_yaw = -0.6
	var k := VehicleModels.build("gunship", 0, 0)
	vehicle.model = k.root
	vehicle.turret = k.turret
	vehicle._vm = k
	vehicle.add_child(k.root)
	field.entities[42] = vehicle
	var fx := Fx.new()
	fx.world = field
	var fallback := vehicle.position + Vector3(0, 6, 0)
	var muzzle := vehicle.muzzle_world(false)
	check(muzzle.distance_to(fallback) > 4.0, "fixture reproduces the old distance rejection")
	check(fx._muzzle_of([Fx.SHOT, fallback, Vector3.ZERO, 1, "ac", 42], 5, fallback, false) == muzzle,
		"moving aircraft effect uses its visible barrel, beyond the former four metre cutoff")
	check(vehicle.weapon_muzzle("mg").distance_to(muzzle) < 0.001, "authority and visible rotated helicopter barrel agree")
	field.entities.clear()
	check(fx._muzzle_of([Fx.SHOT, fallback, Vector3.ZERO, 1, "ac", 42], 5, fallback, false) == fallback, "missing shooter uses authoritative fallback")
	fx.free()
	vehicle.free()
	for kind in ["ac130", "blackfish_armed"]:
		var aircraft := Projectile.new()
		aircraft.world = field
		aircraft.srv = true
		aircraft.ptype = "ac130"
		aircraft.mk = kind
		aircraft.position = Vector3(300, 88, -200)
		aircraft.life_t = 5.0
		add_child(aircraft)
		aircraft.model = Node3D.new()
		aircraft.add_child(aircraft.model)
		var model := VehicleModels.build(kind, 0, 0)
		aircraft._vm = model
		aircraft.model.add_child(model.root)
		aircraft._ac130_view(0.0)
		for weapon in ["ac25", "ac40", "ac105"]:
			check(aircraft.aircraft_muzzle(weapon).distance_to(aircraft.muzzle_world(weapon)) < 0.001, kind + " " + weapon + " banked origin matches its own barrel")
		check(aircraft.aircraft_muzzle("ac25").distance_to(aircraft.aircraft_muzzle("ac105")) > 1.0, kind + " distinct guns have distinct launch points")
		aircraft.free()
	field.free()
	# The server's mounted gun cannot instantly acquire a target 60 degrees away.
	var gunner := Soldier.new()
	var mount := Structure.new()
	mount.skind = "hmg_nest"
	mount.built = true
	gunner.srv = true
	gunner.mounted = mount
	gunner._face(Defs.dir_of(1.0), 1.0 / 30.0)
	check(gunner.rotation.y > 0.0 and gunner.rotation.y <= deg_to_rad(35.0) / 30.0 + 0.00001, "mounted gun respects traverse rate")
	for entry in [["mg_nest", 55.0], ["mortar_pit", 12.0], ["at_post", 20.0]]:
		mount.skind = entry[0]
		gunner.position = mount.mount_pos()
		gunner.rotation.y = 0.0
		gunner._face(Defs.dir_of(1.0), 1.0 / 30.0)
		check(gunner.rotation.y <= deg_to_rad(float(entry[1])) / 30.0 + 0.00001, String(entry[0]) + " traverse cap")
	var mortar_field := World.new()
	mortar_field.has_view = false
	var combat := MountCombat.new(mortar_field)
	mortar_field.combat = combat
	gunner.world = mortar_field
	mount.skind = "mortar_pit"
	gunner.position = mount.mount_pos()
	gunner.rotation.y = 0.0
	gunner._pit_aim = gunner.position + Vector3(50, 0, 0)
	gunner._mortar_pit_tick(1.0 / 30.0, mount)
	check(combat.mortars == 0 and gunner._pit_aim != Vector3.INF, "mortar holds its fire mission while laying")
	for i in 300:
		mortar_field.time += 1.0 / 30.0
		gunner._mortar_pit_tick(1.0 / 30.0, mount)
	check(combat.mortars == 1, "mortar fires after its slow traverse settles")
	gunner.free()
	mortar_field.free()
	mount.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-out="):
			var audit := {}
			for kind: String in Defs.VEHICLES:
				var definition: Dictionary = Defs.VEHICLES[kind]
				var p := VehicleMotion.profile(kind, definition)
				audit[kind] = {"name": definition.name, "base": definition.get("base", "tank"),
					"speed": definition.speed, "traverse": rad_to_deg(float(p.traverse)),
					"hull": rad_to_deg(float(p.hull_turn)), "accel": p.handling[0], "brake": p.handling[1]}
			var file := FileAccess.open(arg.get_slice("=", 1), FileAccess.WRITE)
			file.store_string(JSON.stringify(audit, "\t", true, true))
	print("VEHICLE_MOTION failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
