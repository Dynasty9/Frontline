class_name SoldierModel
extends Node3D
## Low-poly articulated soldier built from boxes, posed procedurally.
## Local -Z is forward. Joints are Node3D pivots; poses are Euler targets
## that the joints ease towards every frame.

const H0 := 0.95

var root: Node3D
var hips: Node3D
var torso: Node3D
var head: Node3D
var thigh_l: Node3D
var shin_l: Node3D
var thigh_r: Node3D
var shin_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var forearm_l: Node3D
var forearm_r: Node3D
var gun: Node3D
var pistol: Node3D
var tube: Node3D
var stretcher: Node3D
var back_item: Node3D
var phase := 0.0
var act_time := 0.0
var last_act := -1
var tumble := Vector3.ZERO
var look := "rifle"
var has_gun := true
var is_mortar := false
var seedf := 0.0  # per-man offset so a squad doesn't breathe in lockstep
var dvar := 0  # which way he falls when he's killed
var _last_life := -1
var _fall_t := 9.0
var _still := 0
var _baked := false
var ragdoll = null  # Ragdoll while the physics has the body
var ragdoll_done := false  # the body lies where the physics left it
var over_wall := false  # firing over low cover
# two-hand weapon hold: the arms are solved from where the weapon is
var ik_l := false
var ik_r := false
var ik_l_target := Vector3.INF  # override for the left hand (torso space), e.g. the magazine pouch
var fore_z := -0.42  # where the support hand holds the weapon (gun space)
const SH_L := Vector3(-0.27, 0.52, 0.0)
const SH_R := Vector3(0.27, 0.52, 0.0)
const UPPER := 0.28
const LOWER := 0.25

# targets for this frame
var t_root_p := Vector3.ZERO
var t_root_r := Vector3.ZERO
var t_hips_p := Vector3(0, H0, 0)
var t_torso := Vector3.ZERO
var t_head := Vector3.ZERO
var t_thl := Vector3.ZERO
var t_thr := Vector3.ZERO
var t_shl := Vector3.ZERO
var t_shr := Vector3.ZERO
var t_arl := Vector3.ZERO
var t_arr := Vector3.ZERO
var t_fal := Vector3.ZERO  # elbows
var t_far := Vector3.ZERO
var t_gun_p := Vector3.ZERO
var t_gun_r := Vector3.ZERO


func build(utype: String, team: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	seedf = float(seed % 997) * 0.731
	dvar = int(seed / 7) % 3
	var skin: Color = [Color(0.86, 0.68, 0.55), Color(0.72, 0.53, 0.4), Color(0.55, 0.38, 0.27), Color(0.4, 0.28, 0.2), Color(0.9, 0.75, 0.62)][rng.randi() % 5]
	var shirt: Color
	var pants: Color
	var vest: Color
	var hat: Color
	if team == 0:
		shirt = Res.vary(Color(0.38, 0.41, 0.29), 0.04, rng)
		pants = Res.vary(Color(0.34, 0.37, 0.26), 0.04, rng)
		vest = Color(0.42, 0.4, 0.29)
		hat = Color(0.31, 0.34, 0.23)
	elif team == 1:
		shirt = Res.vary([Color(0.55, 0.47, 0.35), Color(0.35, 0.33, 0.3), Color(0.26, 0.29, 0.22), Color(0.5, 0.5, 0.47), Color(0.42, 0.3, 0.22)][rng.randi() % 5], 0.06, rng)
		pants = Res.vary([Color(0.25, 0.24, 0.22), Color(0.32, 0.29, 0.21), Color(0.22, 0.25, 0.2)][rng.randi() % 3], 0.05, rng)
		vest = Res.vary(Color(0.3, 0.27, 0.2), 0.08, rng)
		hat = [Color(0.6, 0.12, 0.1), Color(0.12, 0.12, 0.12), Color(0.3, 0.32, 0.22), Color(0.55, 0.5, 0.4)][rng.randi() % 4]
	else:
		shirt = Color(0.85, 0.85, 0.82)
		pants = Color(0.3, 0.32, 0.3)
		vest = Color(0.9, 0.9, 0.9)
		hat = Color(0.9, 0.9, 0.9)
	var boots := Color(0.12, 0.1, 0.08)
	var dark := Color(0.1, 0.1, 0.1)

	var pouch := vest.darkened(0.15)
	var pack := vest.darkened(0.2)
	var gloves := Color(0.17, 0.155, 0.13) if team == 0 else skin
	var pads := Color(0.22, 0.22, 0.19)
	var wood := Color(0.3, 0.2, 0.12)
	var steel := Color(0.15, 0.15, 0.15)
	var scarf: Color = [Color(0.55, 0.5, 0.42), Color(0.2, 0.22, 0.2), Color(0.45, 0.15, 0.12), Color(0.85, 0.84, 0.8)][rng.randi() % 4]
	var bearer := utype == "bearer"

	root = Node3D.new()
	add_child(root)
	hips = Node3D.new()
	hips.position = Vector3(0, H0, 0)
	root.add_child(hips)
	var pel := Res.mi(hips, Res.cyl(0.165, 0.155, 0.2, 10), Res.mat(pants), Vector3(0, -0.01, 0))
	pel.scale = Vector3(1.0, 1.0, 0.68)
	if team == 0 and not bearer:
		var belt := Res.mi(hips, Res.cyl(0.175, 0.175, 0.06, 10), Res.mat(vest), Vector3(0, 0.06, 0), Vector3.ZERO, false)
		belt.scale = Vector3(1.0, 1.0, 0.7)
	# legs: rounded limbs, boots, knee pads on the regulars
	for side in [-1.0, 1.0]:
		var th := _joint(hips, Vector3(0.1 * side, -0.05, 0))
		Res.mi(th, Res.capsule(0.085, 0.5), Res.mat(pants), Vector3(0, -0.22, 0))
		var sh := _joint(th, Vector3(0, -0.45, 0))
		Res.mi(sh, Res.capsule(0.07, 0.46), Res.mat(pants), Vector3(0, -0.21, 0))
		Res.mi(sh, Res.box(Vector3(0.13, 0.11, 0.27)), Res.mat(boots), Vector3(0, -0.44, -0.045), Vector3.ZERO, false)
		if team == 0 and not bearer:
			Res.mi(sh, Res.box(Vector3(0.12, 0.13, 0.05)), Res.mat(pads), Vector3(0, -0.02, -0.075), Vector3.ZERO, false)
		if side < 0.0:
			thigh_l = th
			shin_l = sh
		else:
			thigh_r = th
			shin_r = sh
	# thigh rig / dump pouch
	Res.mi(thigh_r, Res.box(Vector3(0.06, 0.14, 0.12)), Res.mat(pouch), Vector3(0.09, -0.12, 0.0), Vector3.ZERO, false)

	torso = _joint(hips, Vector3(0, 0.05, 0))
	# an oval waist widening into the chest, rounded shoulders
	var waist := Res.mi(torso, Res.cyl(0.18, 0.163, 0.3, 10), Res.mat(shirt), Vector3(0, 0.16, 0))
	waist.scale = Vector3(1.0, 1.0, 0.6)
	var chest := Res.mi(torso, Res.cyl(0.205, 0.185, 0.3, 10), Res.mat(shirt), Vector3(0, 0.42, 0))
	chest.scale = Vector3(1.0, 1.0, 0.58)
	Res.mi(torso, Res.capsule(0.07, 0.48), Res.mat(shirt), Vector3(0, 0.53, 0), Vector3(0, 0, PI / 2), false)
	if not bearer:
		if team == 0:
			# plate carrier: front and back plates, mag pouches, radio, assault pack
			for z in [-0.125, 0.125]:
				Res.mi(torso, Res.box(Vector3(0.34, 0.31, 0.05)), Res.mat(vest), Vector3(0, 0.4, z))
			var cb := Res.mi(torso, Res.cyl(0.208, 0.205, 0.15, 10), Res.mat(vest), Vector3(0, 0.3, 0))
			cb.scale = Vector3(1.0, 1.0, 0.68)
			for x in [-0.12, 0.12]:
				Res.mi(torso, Res.box(Vector3(0.07, 0.035, 0.27)), Res.mat(vest), Vector3(x, 0.57, 0), Vector3.ZERO, false)
			for x in [-0.11, 0.0, 0.11]:
				Res.mi(torso, Res.box(Vector3(0.09, 0.12, 0.06)), Res.mat(pouch), Vector3(x, 0.33, -0.18), Vector3.ZERO, false)
			Res.mi(torso, Res.box(Vector3(0.2, 0.06, 0.05)), Res.mat(pouch), Vector3(0, 0.47, -0.17), Vector3.ZERO, false)
			Res.mi(torso, Res.box(Vector3(0.07, 0.16, 0.08)), Res.mat(pouch), Vector3(-0.22, 0.33, -0.02), Vector3.ZERO, false)
			Res.mi(torso, Res.box(Vector3(0.31, 0.36, 0.15)), Res.mat(pack), Vector3(0, 0.36, 0.22), Vector3.ZERO, false)
			Res.mi(torso, Res.box(Vector3(0.24, 0.1, 0.12)), Res.mat(pack), Vector3(0, 0.6, 0.2), Vector3.ZERO, false)
		else:
			# a chest rig over whatever he's wearing, sometimes a bag on his back
			Res.mi(torso, Res.box(Vector3(0.36, 0.17, 0.08)), Res.mat(vest), Vector3(0, 0.3, -0.135))
			for x in [-0.12, -0.04, 0.04, 0.12]:
				Res.mi(torso, Res.box(Vector3(0.07, 0.13, 0.05)), Res.mat(pouch), Vector3(x, 0.3, -0.18), Vector3.ZERO, false)
			Res.mi(torso, Res.box(Vector3(0.04, 0.32, 0.25)), Res.mat(vest), Vector3(-0.17, 0.48, 0), Vector3(0, 0, 0.3), false)
			Res.mi(torso, Res.box(Vector3(0.04, 0.32, 0.25)), Res.mat(vest), Vector3(0.17, 0.48, 0), Vector3(0, 0, -0.3), false)
			if rng.randf() < 0.55:
				Res.mi(torso, Res.box(Vector3(0.28, 0.3, 0.13)), Res.mat(pack), Vector3(0, 0.36, 0.19), Vector3.ZERO, false)

	head = _joint(torso, Vector3(0, 0.62, 0))
	Res.mi(head, Res.cyl(0.05, 0.055, 0.1, 8), Res.mat(skin), Vector3(0, -0.02, 0), Vector3.ZERO, false)
	var face := Res.mi(head, Res.sphere(0.11, 12), Res.mat(skin), Vector3(0, 0.12, -0.005), Vector3.ZERO, false)
	face.scale = Vector3(0.9, 1.06, 1.0)
	# jaw, nose, ears and a brow shading the eyes: enough to read a face and
	# which way he is looking
	var jaw := Res.mi(head, Res.sphere(0.08, 10), Res.mat(skin), Vector3(0, 0.07, -0.035), Vector3.ZERO, false)
	jaw.scale = Vector3(1.0, 0.8, 1.0)
	Res.mi(head, Res.box(Vector3(0.028, 0.045, 0.04)), Res.mat(skin), Vector3(0, 0.112, -0.113), Vector3(-0.3, 0, 0), false)
	for sx in [-1.0, 1.0]:
		var ear := Res.mi(head, Res.sphere(0.03, 6), Res.mat(skin), Vector3(sx * 0.098, 0.118, 0.005), Vector3.ZERO, false)
		ear.scale = Vector3(0.5, 1.0, 0.8)
	var brow := skin.darkened(0.3)
	Res.mi(head, Res.box(Vector3(0.13, 0.014, 0.025)), Res.mat(brow), Vector3(0, 0.146, -0.099), Vector3.ZERO, false)
	if team == 0:
		# modern helmet: a cut-high dome with its rim and rails, NVG mount,
		# headset over the ears, goggles strapped round the back; eye pro
		var hm := Res.mi(head, Res.dome(0.146, 14), Res.mat(hat), Vector3(0, 0.13, 0.012), Vector3.ZERO, false)
		hm.scale = Vector3(1.0, 0.92, 1.08)
		var rim := Res.mi(head, Res.cyl(0.149, 0.153, 0.024, 14), Res.mat(hat), Vector3(0, 0.132, 0.012), Vector3.ZERO, false)
		rim.scale = Vector3(1.0, 1.0, 1.08)
		Res.mi(head, Res.box(Vector3(0.05, 0.04, 0.03)), Res.mat(steel), Vector3(0, 0.2, -0.13), Vector3.ZERO, false)
		for sx in [-1.0, 1.0]:
			Res.mi(head, Res.box(Vector3(0.014, 0.026, 0.12)), Res.mat(pouch), Vector3(sx * 0.147, 0.165, 0.01), Vector3.ZERO, false)
			Res.mi(head, Res.cyl(0.045, 0.045, 0.04, 8), Res.mat(pouch), Vector3(sx * 0.115, 0.11, 0.0), Vector3(0, 0, PI / 2), false)
		Res.mi(head, Res.box(Vector3(0.2, 0.035, 0.05)), Res.mat(steel), Vector3(0, 0.19, 0.14), Vector3.ZERO, false)
		if rng.randf() < 0.6:
			Res.mi(head, Res.box(Vector3(0.165, 0.032, 0.02)), Res.mat(dark), Vector3(0, 0.128, -0.106), Vector3.ZERO, false)
	elif team == 1:
		var style := rng.randi() % 4
		if style == 0:
			# watch cap, rolled up
			var w2 := Res.mi(head, Res.dome(0.122, 10), Res.mat(hat), Vector3(0, 0.15, 0.008), Vector3.ZERO, false)
			w2.scale = Vector3(1.0, 0.95, 1.05)
			var roll := Res.mi(head, Res.cyl(0.124, 0.126, 0.04, 10), Res.mat(hat.darkened(0.1)), Vector3(0, 0.155, 0.008), Vector3.ZERO, false)
			roll.scale = Vector3(1.0, 1.0, 1.05)
		elif style == 1:
			# shemagh wrapped over the head and face
			var sh2 := Res.mi(head, Res.sphere(0.125, 10), Res.mat(scarf), Vector3(0, 0.15, 0.0), Vector3.ZERO, false)
			sh2.scale = Vector3(1.05, 0.95, 1.05)
			Res.mi(head, Res.box(Vector3(0.2, 0.08, 0.05)), Res.mat(scarf), Vector3(0, 0.07, -0.1), Vector3.ZERO, false)
		elif style == 2:
			# beret, pulled down to one side
			var br := Res.mi(head, Res.sphere(0.135, 12), Res.mat(hat), Vector3(0.025, 0.205, 0.01), Vector3(0, 0, 0.28), false)
			br.scale = Vector3(1.12, 0.36, 1.08)
			Res.mi(head, Res.cyl(0.118, 0.118, 0.025, 12), Res.mat(hat.darkened(0.25)), Vector3(0, 0.178, 0.005), Vector3.ZERO, false)
		else:
			# ball cap: a rounded crown and a curved brim
			var cap := Res.mi(head, Res.dome(0.12, 10), Res.mat(hat), Vector3(0, 0.158, 0.005), Vector3.ZERO, false)
			cap.scale = Vector3(1.0, 0.8, 1.04)
			var brim := Res.mi(head, Res.cyl(0.075, 0.08, 0.015, 10), Res.mat(hat.darkened(0.15)), Vector3(0, 0.16, -0.125), Vector3(0.18, 0, 0), false)
			brim.scale = Vector3(1.0, 1.0, 0.75)
		# scarf round the neck
		Res.mi(head, Res.cyl(0.085, 0.09, 0.07, 10), Res.mat(scarf), Vector3(0, -0.02, 0), Vector3.ZERO, false)
	else:
		var hm2 := Res.mi(head, Res.dome(0.132, 10), Res.mat(hat), Vector3(0, 0.14, 0.01), Vector3.ZERO, false)
		hm2.scale = Vector3(1.0, 0.8, 1.06)
		Res.mi(head, Res.box(Vector3(0.1, 0.03, 0.06)), Res.mat(Color(0.8, 0.1, 0.1)), Vector3(0, 0.22, -0.06), Vector3.ZERO, false)

	# canteen and, now and then, a radio antenna
	Res.mi(hips, Res.cyl(0.045, 0.045, 0.13, 8), Res.mat(vest), Vector3(-0.19, -0.04, 0.08), Vector3.ZERO, false)
	if team == 0 and rng.randf() < 0.2 and not bearer:
		Res.mi(torso, Res.cyl(0.008, 0.008, 0.75, 4), Res.mat(dark), Vector3(-0.1, 0.85, 0.26), Vector3(0.15, 0, 0.1), false)

	# arms: rounded, gloved
	for side in [-1.0, 1.0]:
		var ua := _joint(torso, Vector3(0.27 * side, 0.52, 0))
		Res.mi(ua, Res.capsule(0.058, 0.34), Res.mat(shirt), Vector3(0, -0.13, 0), Vector3.ZERO, false)
		var delt := Res.mi(ua, Res.sphere(0.072, 8), Res.mat(shirt), Vector3(0.005 * side, -0.02, 0), Vector3.ZERO, false)
		delt.scale = Vector3(1.0, 1.1, 1.0)
		var fa := _joint(ua, Vector3(0, -0.28, 0))
		Res.mi(fa, Res.capsule(0.05, 0.3), Res.mat(shirt), Vector3(0, -0.11, 0), Vector3.ZERO, false)
		var hand := Res.mi(fa, Res.box(Vector3(0.075, 0.095, 0.09)), Res.mat(gloves), Vector3(0, -0.245, 0), Vector3.ZERO, false)
		hand.rotation = Vector3(0.15, 0, 0)
		if side < 0.0:
			arm_l = ua
			forearm_l = fa
		else:
			arm_r = ua
			forearm_r = fa
	if team == 0 and not bearer:
		Res.mi(arm_l, Res.box(Vector3(0.012, 0.06, 0.08)), Res.mat(Defs.TEAM_COLORS[0].darkened(0.25)), Vector3(-0.058, -0.06, 0), Vector3.ZERO, false)
	if Defs.UNITS.has(utype) and Defs.UNITS[utype].get("medic", false):
		Res.mi(arm_l, Res.cyl(0.064, 0.064, 0.08, 10), Res.mat(Color(0.92, 0.92, 0.9)), Vector3(0, -0.12, 0), Vector3.ZERO, false)
		Res.mi(arm_l, Res.box(Vector3(0.13, 0.04, 0.05)), Res.mat(Color(0.8, 0.1, 0.1)), Vector3(0, -0.12, 0), Vector3.ZERO, false)
		Res.mi(torso, Res.box(Vector3(0.3, 0.28, 0.14)), Res.mat(Color(0.85, 0.85, 0.8)), Vector3(0, 0.3, 0.25), Vector3.ZERO, false)
	if bearer:
		Res.mi(arm_l, Res.cyl(0.064, 0.064, 0.08, 10), Res.mat(Color(0.8, 0.1, 0.1)), Vector3(0, -0.12, 0), Vector3.ZERO, false)

	# weapon (forward is -z; grip near the origin, handguard ahead of it)
	gun = _joint(torso, Vector3(0.1, 0.32, -0.3))
	look = "rifle"
	var w: String = Defs.UNITS[utype].weapon if Defs.UNITS.has(utype) else ""
	fore_z = {"smg": -0.3, "lmg": -0.55, "pistol": -0.1}.get(w, -0.42)
	match w:
		"rifle":
			# carbine: receiver, rail with an optic, handguard, collapsible stock
			Res.mi(gun, Res.box(Vector3(0.055, 0.09, 0.36)), Res.mat(dark), Vector3(0, 0, -0.1), Vector3.ZERO, false)
			Res.mi(gun, Res.box(Vector3(0.06, 0.07, 0.3)), Res.mat(dark), Vector3(0, 0.005, -0.42), Vector3.ZERO, false)
			Res.mi(gun, Res.cyl(0.014, 0.014, 0.24, 6), Res.mat(dark), Vector3(0, 0.01, -0.68), Vector3(PI / 2, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.045, 0.085, 0.24)), Res.mat(dark), Vector3(0, -0.025, 0.2), Vector3(0.12, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.035, 0.1, 0.045)), Res.mat(dark), Vector3(0, -0.085, 0.03), Vector3(-0.3, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.035, 0.14, 0.065)), Res.mat(dark), Vector3(0, -0.1, -0.13), Vector3(0.15, 0, 0), false)
			Res.mi(gun, Res.cyl(0.024, 0.024, 0.12, 8), Res.mat(steel), Vector3(0, 0.075, -0.12), Vector3(PI / 2, 0, 0), false)
		"ak":
			# AK: wooden furniture, curved magazine
			Res.mi(gun, Res.box(Vector3(0.055, 0.09, 0.36)), Res.mat(dark), Vector3(0, 0, -0.1), Vector3.ZERO, false)
			Res.mi(gun, Res.box(Vector3(0.065, 0.075, 0.22)), Res.mat(wood), Vector3(0, 0.0, -0.38), Vector3.ZERO, false)
			Res.mi(gun, Res.cyl(0.014, 0.014, 0.3, 6), Res.mat(dark), Vector3(0, 0.015, -0.62), Vector3(PI / 2, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.05, 0.1, 0.26)), Res.mat(wood), Vector3(0, -0.04, 0.2), Vector3(0.2, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.035, 0.1, 0.045)), Res.mat(wood), Vector3(0, -0.085, 0.03), Vector3(-0.3, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.035, 0.09, 0.06)), Res.mat(dark), Vector3(0, -0.08, -0.15), Vector3(0.2, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.035, 0.09, 0.06)), Res.mat(dark), Vector3(0, -0.15, -0.12), Vector3(0.55, 0, 0), false)
		"smg":
			Res.mi(gun, Res.box(Vector3(0.055, 0.09, 0.36)), Res.mat(dark), Vector3(0, 0, -0.1), Vector3.ZERO, false)
			Res.mi(gun, Res.box(Vector3(0.04, 0.08, 0.16)), Res.mat(dark), Vector3(0, -0.02, 0.15), Vector3.ZERO, false)
			Res.mi(gun, Res.box(Vector3(0.035, 0.14, 0.05)), Res.mat(dark), Vector3(0, -0.1, -0.12), Vector3.ZERO, false)
			Res.mi(gun, Res.cyl(0.02, 0.02, 0.1, 8), Res.mat(steel), Vector3(0, 0.07, -0.1), Vector3(PI / 2, 0, 0), false)
		"lmg":
			look = "lmg"
			Res.mi(gun, Res.box(Vector3(0.08, 0.11, 0.5)), Res.mat(dark), Vector3(0, 0, -0.1), Vector3.ZERO, false)
			Res.mi(gun, Res.cyl(0.02, 0.02, 0.5, 6), Res.mat(dark), Vector3(0, 0.01, -0.6), Vector3(PI / 2, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.05, 0.1, 0.26)), Res.mat(dark), Vector3(0, -0.03, 0.24), Vector3(0.1, 0, 0), false)
			Res.mi(gun, Res.box(Vector3(0.12, 0.13, 0.14)), Res.mat(pack), Vector3(-0.07, -0.09, -0.1), Vector3.ZERO, false)
			Res.mi(gun, Res.box(Vector3(0.012, 0.18, 0.012)), Res.mat(dark), Vector3(-0.03, -0.09, -0.7), Vector3(0.4, 0, 0.25), false)
			Res.mi(gun, Res.box(Vector3(0.012, 0.18, 0.012)), Res.mat(dark), Vector3(0.03, -0.09, -0.7), Vector3(0.4, 0, -0.25), false)
		"pistol":
			look = "op"
			Res.mi(gun, Res.box(Vector3(0.22, 0.05, 0.14)), Res.mat(steel), Vector3(-0.1, 0, 0.05), Vector3.ZERO, false)
			Res.mi(gun, Res.box(Vector3(0.18, 0.11, 0.02)), Res.mat(Color(0.3, 0.5, 0.6), 0.3, 1.0), Vector3(-0.1, 0.07, 0.11), Vector3(-0.5, 0, 0), false)
		_:
			has_gun = false
			gun.visible = false
	pistol = _joint(forearm_r, Vector3(0, -0.28, -0.06))
	Res.mi(pistol, Res.box(Vector3(0.04, 0.1, 0.18)), Res.mat(dark), Vector3(0, 0, -0.06), Vector3.ZERO, false)
	pistol.visible = false
	is_mortar = Defs.UNITS.has(utype) and int(Defs.UNITS[utype].get("mortar", 0)) > 0
	if Defs.UNITS.has(utype) and (int(Defs.UNITS[utype].get("rockets", 0)) > 0 or is_mortar):
		tube = _joint(torso, Vector3(0.18, 0.45, 0.22))
		Res.mi(tube, Res.cyl(0.07, 0.07, 1.1, 10), Res.mat(Color(0.25, 0.28, 0.2) if team == 0 else Color(0.32, 0.3, 0.22)), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
		if not is_mortar:
			Res.mi(tube, Res.cyl(0.11, 0.07, 0.24, 10), Res.mat(Color(0.25, 0.28, 0.2) if team == 0 else Color(0.32, 0.3, 0.22)), Vector3(0, 0, -0.62), Vector3(PI / 2, 0, 0), false)
		tube.rotation = Vector3(0.3, 0, 0.2)
	if Defs.UNITS.has(utype) and Defs.UNITS[utype].get("engineer", false):
		back_item = _joint(torso, Vector3(-0.1, 0.35, 0.28))
		Res.mi(back_item, Res.box(Vector3(0.05, 0.75, 0.05)), Res.mat(wood), Vector3.ZERO, Vector3(0, 0, 0.5), false)
		Res.mi(back_item, Res.box(Vector3(0.18, 0.22, 0.03)), Res.mat(steel), Vector3(-0.17, 0.35, 0), Vector3(0, 0, 0.5), false)
	# stretcher (shown while carried)
	stretcher = Node3D.new()
	root.add_child(stretcher)
	Res.mi(stretcher, Res.box(Vector3(0.62, 0.04, 2.0)), Res.mat(Color(0.35, 0.38, 0.28)), Vector3.ZERO)
	for x in [-0.33, 0.33]:
		Res.mi(stretcher, Res.box(Vector3(0.04, 0.04, 2.5)), Res.mat(Color(0.5, 0.45, 0.35)), Vector3(x, 0, 0), Vector3.ZERO, false)
	stretcher.visible = false
	var cloth := "camo_army" if team == 0 else "fabric"
	var map := {skin: "skin", shirt: cloth, pants: cloth, hat: cloth if team == 0 else "fabric",
		vest: "canvas_l", pouch: "canvas_l", pack: "canvas_l", boots: "boot", dark: "gunmetal",
		wood: "wood_l", steel: "gunmetal", Color(0.12, 0.12, 0.12): "gunmetal", pads: "canvas_l", scarf: "fabric"}
	if team == 0:
		map[gloves] = "boot"
	_skin(self, map)
	# one mesh per joint (a surface per material): animation is untouched and
	# each body part is a single render instance to move
	for j in [root, hips, torso, head, thigh_l, shin_l, thigh_r, shin_r, arm_l, arm_r, forearm_l, forearm_r, gun, pistol, tube, back_item, stretcher]:
		if j:
			Mats.merge_static(j, [], false, false, true)


## Swaps flat colours for cloth / camo / skin surfaces (tint keeps the colour).
func _skin(n: Node, map: Dictionary) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var sm := (c as MeshInstance3D).material_override as StandardMaterial3D
			if sm and not sm.emission_enabled:
				var col := sm.albedo_color
				# anything else plain-coloured goes on the shared surface too, so
				# the whole body merges into one mesh per joint
				var kind: String = map.get(col, "plain_dark" if col.get_luminance() < 0.25 else "plain")
				if col.a >= 0.999:
					Mats.apply(c, kind, Mats.tint_for(kind, col))
		_skin(c, map)


func _joint(parent: Node3D, p: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = p
	parent.add_child(j)
	return j


## life/posture/act are the Soldier enums; speed in m/s; backwards = moving opposite to facing.
func pose(dt: float, life: int, posture: int, act: int, speed: float, backwards: bool, lean_shoot: bool) -> void:
	if ragdoll != null:
		return  # the physics owns the body
	if ragdoll_done:
		if life == 2 and not act in [Soldier.Act.CARRIED, Soldier.Act.DRAGGED]:
			if not _baked:
				_still += 1
				if _still > 20:
					_baked = true
					Mats.merge_static(root, [stretcher], true, true, true)
			return
		ragdoll_done = false  # picked up: the animation takes over again
	if act != last_act:
		last_act = act
		act_time = 0.0
		_still = 0
	act_time += dt
	if life != _last_life:
		if (life == 1 or life == 2) and _last_life == 0:
			_fall_t = 0.0
		_last_life = life
		_still = 0
	_fall_t += dt
	# a body that has finished falling doesn't move again: stop posing it, and
	# bake what's left into one mesh (a dead man is two draws, not fifteen)
	if life == 2 and act != Soldier.Act.FLUNG and _fall_t > 2.5:
		_still += 1
		if _still > 40:
			if not _baked:
				_baked = true
				gun.visible = false
				Mats.merge_static(root, [stretcher], true, true, true)
			return
	var moving := speed > 0.25
	phase += dt * (speed * 3.2 + (0.0 if moving else 0.0)) * (-1.0 if backwards else 1.0)
	var sp := sin(phase)
	var cp := cos(phase)
	# defaults: standing, rifle at low ready
	t_root_p = Vector3.ZERO
	t_root_r = Vector3.ZERO
	t_hips_p = Vector3(0, H0, 0)
	t_torso = Vector3.ZERO
	t_head = Vector3.ZERO
	t_thl = Vector3.ZERO
	t_thr = Vector3.ZERO
	t_shl = Vector3.ZERO
	t_shr = Vector3.ZERO
	t_arl = Vector3(1.25, 0.0, -0.35)
	t_arr = Vector3(0.75, 0.0, 0.1)
	t_fal = Vector3.ZERO
	t_far = Vector3.ZERO
	if not has_gun:
		t_arl = Vector3(0.1, 0, -0.1)
		t_arr = Vector3(0.1, 0, 0.1)
		t_fal = Vector3(0.25, 0, 0)
		t_far = Vector3(0.25, 0, 0)
	# low ready: muzzle down and a little across, both hands on the weapon
	t_gun_p = Vector3(0.1, 0.3, -0.3)
	t_gun_r = Vector3(-0.45, 0.22, 0.0)
	ik_l = has_gun and look != "op"
	ik_r = has_gun and look != "op"
	ik_l_target = Vector3.INF
	var show_gun := has_gun
	var show_pistol := false
	var show_stretcher := false
	var k := 12.0

	if life != 0 or act in [Soldier.Act.THROW, Soldier.Act.BUILD, Soldier.Act.HEAL, Soldier.Act.DRAG, Soldier.Act.CARRY,
			Soldier.Act.CRAWL, Soldier.Act.CLIMB, Soldier.Act.DIVE, Soldier.Act.FLINCH, Soldier.Act.PICKUP, Soldier.Act.LIMP,
			Soldier.Act.VAULT, Soldier.Act.DAZED, Soldier.Act.MELEE, Soldier.Act.HANDSUP, Soldier.Act.LAUNCH,
			Soldier.Act.IDLE_CHAT, Soldier.Act.IDLE_LAUGH, Soldier.Act.IDLE_SMOKE, Soldier.Act.IDLE_SIT, Soldier.Act.IDLE_STRETCH, Soldier.Act.IDLE_LOOK]:
		ik_l = false
		ik_r = false
	if act == Soldier.Act.IDLE_CHECK:
		ik_r = false
	if life == 1 and act == Soldier.Act.CRAWL:  # wounded crawling to cover
		_prone()
		t_arl = Vector3(2.6 + sp * 0.5, 0, -0.3)
		t_arr = Vector3(2.6 - sp * 0.5, 0, 0.3)
		t_thl = Vector3(0.0, 0, -0.1)
		t_thr = Vector3(0.3, 0, 0.1)
		t_shr = Vector3(-0.8, 0, 0)
		show_gun = false
	elif (life == 1 or life == 2) and _fall_t < 0.42 and not act in [Soldier.Act.FLUNG, Soldier.Act.CARRIED, Soldier.Act.DRAGGED]:
		# hit: the legs go first - knees buckle and the body folds before he drops
		show_gun = false
		t_hips_p = Vector3(0, 0.55, 0.1)
		t_thl = Vector3(1.0, 0, -0.1)
		t_shl = Vector3(-1.4, 0, 0)
		t_thr = Vector3(0.6, 0, 0.1)
		t_shr = Vector3(-1.1, 0, 0)
		t_torso = Vector3(-0.55 if dvar == 1 else 0.3, 0, 0.15)
		t_head = Vector3(-0.4 if dvar == 1 else 0.4, 0, 0)
		t_arl = Vector3(0.5, 0, -0.4)
		t_arr = Vector3(0.3, 0, 0.5)
		t_fal = Vector3(0.6, 0, 0)
		t_far = Vector3(0.4, 0, 0)
		k = 9.0
	elif life == 2:
		show_gun = false
		_death_pose()
		k = 6.0 if _fall_t < 1.4 else 12.0
		if act == Soldier.Act.FLUNG:
			_flung(dt)
			return
	elif life == 1:  # downed: lying on the back
		t_root_r = Vector3(PI * 0.5, 0, 0)
		t_root_p = Vector3(0, 0.13, -0.8)
		show_gun = false
		if _fall_t < 1.2:
			k = 7.0
		var writhe := sin(act_time * 2.3) * 0.12
		t_torso = Vector3(-0.15, 0, writhe)
		t_head = Vector3(-0.35 + writhe, 0, 0)
		t_thl = Vector3(0.6 + writhe, 0, -0.1)
		t_shl = Vector3(-1.0, 0, 0)
		t_thr = Vector3(0.1, 0, 0.1)
		t_arl = Vector3(0.6, 0, -0.5)
		t_arr = Vector3(0.4, 0, 0.6)
		if act == Soldier.Act.DRAGGED:
			t_arl = Vector3(PI - 0.3, 0, -0.2)
			t_arr = Vector3(PI - 0.3, 0, 0.2)
			t_head = Vector3(-0.5, 0, 0)
		if act == Soldier.Act.CARRIED:
			t_root_p = Vector3(0, 0.72, 0.1)
			t_thl = Vector3(0.1, 0, 0)
			t_shl = Vector3.ZERO
			show_stretcher = true
		if act == Soldier.Act.PISTOL or (act == Soldier.Act.DRAGGED and fmod(act_time, 1.6) < 0.8 and lean_shoot):
			t_arr = Vector3(0.55, 0, 0.1)
			show_pistol = true
		if act == Soldier.Act.FLUNG:
			_flung(dt)
			return
	elif life == 3 or life == 4:  # surrendered / captive: hands up
		show_gun = false
		t_arl = Vector3(PI - 0.15, 0, -0.25)
		t_arr = Vector3(PI - 0.15, 0, 0.25)
		t_head = Vector3(0.15, 0, 0)
		if moving:
			_walk(sp, cp, 0.4)
	else:
		match act:
			Soldier.Act.FLUNG:
				_flung(dt)
				return
			Soldier.Act.DIVE:
				t_root_r = Vector3(-PI * 0.5, 0, 0)
				t_root_p = Vector3(0, 0.25, 0.8)
				t_arl = Vector3(2.8, 0, -0.2)
				t_arr = Vector3(2.8, 0, 0.2)
				k = 16.0
			Soldier.Act.SLIDE:
				t_root_r = Vector3(0.85, 0, 0)
				t_root_p = Vector3(0, -0.15, -0.3)
				t_thl = Vector3(1.4, 0, 0)
				t_thr = Vector3(0.7, 0, 0)
				t_shr = Vector3(-1.2, 0, 0)
				k = 18.0
			Soldier.Act.VAULT:
				t_hips_p = Vector3(0, H0 + 0.1, 0)
				t_thl = Vector3(1.3, 0, 0)
				t_shl = Vector3(-1.2, 0, 0)
				t_thr = Vector3(0.9, 0, 0)
				t_shr = Vector3(-1.4, 0, 0)
				t_torso = Vector3(-0.45, 0, 0)
				t_arl = Vector3(0.4, 0, -0.2)
				k = 18.0
			Soldier.Act.DAZED:
				var wob := sin(act_time * 2.4)
				t_torso = Vector3(-0.25, 0, wob * 0.28)
				t_head = Vector3(0.2, 0, -wob * 0.3)
				t_arl = Vector3(0.2, 0, -0.2)
				t_arr = Vector3(0.3, 0, 0.2)
				t_gun_p = Vector3(0.15, 0.1, -0.2)
				t_gun_r = Vector3(1.0, 0, 0.3)
				_walk(sp, cp, 0.35)
				t_hips_p.x = wob * 0.08
			Soldier.Act.FLINCH:
				t_hips_p = Vector3(0, 0.78, 0)
				t_thl = Vector3(0.7, 0, 0)
				t_shl = Vector3(-1.0, 0, 0)
				t_thr = Vector3(0.4, 0, 0)
				t_shr = Vector3(-0.9, 0, 0)
				t_torso = Vector3(-0.55, 0, 0)
				t_arl = Vector3(2.5, 0, -0.6)
				t_arr = Vector3(2.5, 0, 0.6)
				t_head = Vector3(-0.4, 0, 0)
				k = 20.0
			Soldier.Act.THROW:
				var a := act_time / 0.6
				t_arr = Vector3(-2.4, 0, 0.2) if a < 0.55 else Vector3(1.9, 0, 0.1)
				t_arl = Vector3(1.4, 0, -0.1)
				t_torso = Vector3(0.1 if a < 0.55 else -0.35, 0.4 if a < 0.55 else -0.3, 0)
				t_gun_p = Vector3(-0.15, 0.2, -0.25)
				t_gun_r = Vector3(0.8, 0, 0.6)
				k = 16.0
			Soldier.Act.MELEE:
				var lunge := act_time < 0.3
				t_torso = Vector3(-0.35 if lunge else 0.0, 0, 0)
				t_arr = Vector3(1.6, 0, 0.0)
				t_arl = Vector3(1.7, 0, -0.3)
				t_gun_p = Vector3(0.05, 0.45, -0.7 if lunge else -0.3)
				t_gun_r = Vector3(-0.6 if lunge else 0.0, 0, 0)
				t_thl = Vector3(0.6, 0, 0)
				t_thr = Vector3(-0.4, 0, 0)
				k = 18.0
			Soldier.Act.BUILD:
				_kneel()
				t_torso = Vector3(-0.45, 0, 0)
				t_arr = Vector3(1.0 + sin(act_time * 11.0) * 0.8, 0, 0.1)
				t_arl = Vector3(0.9, 0, -0.2)
				show_gun = false
			Soldier.Act.HEAL:
				_kneel()
				t_torso = Vector3(-0.55, 0, 0)
				t_arr = Vector3(1.0 + sin(act_time * 6.0) * 0.25, 0, 0.0)
				t_arl = Vector3(1.0 - sin(act_time * 6.0) * 0.25, 0, 0.0)
				show_gun = false
			Soldier.Act.PICKUP:
				t_hips_p = Vector3(0, 0.62, 0)
				t_thl = Vector3(1.2, 0, 0)
				t_shl = Vector3(-1.4, 0, 0)
				t_thr = Vector3(0.6, 0, 0)
				t_shr = Vector3(-1.4, 0, 0)
				t_torso = Vector3(-0.9, 0, 0)
				t_arr = Vector3(1.3, 0, 0)
				k = 18.0
			Soldier.Act.DRAG:
				t_torso = Vector3(-0.7, 0, 0)
				t_arl = Vector3(1.0, 0, 0)
				t_arr = Vector3(1.0, 0, 0)
				t_hips_p = Vector3(0, 0.85, 0)
				show_gun = false
				_walk(sp, cp, 0.45)
			Soldier.Act.CARRY:
				t_arl = Vector3(0.25, 0, -0.1)
				t_arr = Vector3(0.25, 0, 0.1)
				show_gun = false
				_walk(sp, cp, 0.5)
			Soldier.Act.LIMP:
				t_torso = Vector3(-0.1, 0, sp * 0.12)
				t_arl = Vector3(0.3, 0, -0.1)
				t_arr = Vector3(0.6, 0, 0.1)
				t_thl = Vector3(sp * 0.18, 0, 0)
				t_thr = Vector3(-sp * 0.5, 0, 0)
				t_shr = Vector3(-maxf(0.0, cp) * 0.6, 0, 0)
				t_hips_p.y = H0 - absf(sp) * 0.06
			Soldier.Act.CRAWL:
				_prone()
				t_arl = Vector3(2.6 + sp * 0.4, 0, -0.3)
				t_arr = Vector3(2.6 - sp * 0.4, 0, 0.3)
				t_thl = Vector3(0.0, 0, -0.2 - sp * 0.2)
				t_thr = Vector3(0.0, 0, 0.2 - sp * 0.2)
				show_gun = false
			Soldier.Act.CLIMB:
				t_arl = Vector3(2.6 + sp * 0.4, 0, -0.1)
				t_arr = Vector3(2.6 - sp * 0.4, 0, 0.1)
				t_thl = Vector3(maxf(0.0, sp) * 1.2, 0, 0)
				t_thr = Vector3(maxf(0.0, -sp) * 1.2, 0, 0)
				show_gun = false
			Soldier.Act.IDLE_CHAT:
				_sling()
				var g := sin(act_time * 1.9 + seedf)
				var g2 := sin(act_time * 3.3 + seedf * 2.0)
				t_arr = Vector3(0.35 + maxf(0.0, g) * 0.35, 0, -0.15)
				t_far = Vector3(1.1 + g2 * 0.35, 0, 0)
				t_arl = Vector3(0.1, 0, -0.08)
				t_fal = Vector3(0.2 + maxf(0.0, -g) * 0.9, 0, 0)
				t_head = Vector3(sin(act_time * 2.6) * 0.07, sin(act_time * 0.7 + seedf) * 0.12, 0)
				t_torso = Vector3(0, sin(act_time * 0.6) * 0.07, 0)
				t_hips_p.x = sin(act_time * 0.4 + seedf) * 0.03
				k = 7.0
			Soldier.Act.IDLE_LAUGH:
				_sling()
				var sh := sin(act_time * 24.0) * 0.06
				var lean_back := act_time < 0.5
				t_torso = Vector3((0.25 if lean_back else -0.3) + sh, 0, 0)
				t_head = Vector3((0.45 if lean_back else 0.1) + sh, 0, 0)
				t_arl = Vector3(0.35, 0, 0.35)
				t_fal = Vector3(1.3, 0, 0)
				t_arr = Vector3(0.35, 0, -0.35)
				t_far = Vector3(1.3, 0, 0)
				t_hips_p.y = H0 - (0.0 if lean_back else 0.05)
				k = 16.0
			Soldier.Act.IDLE_SMOKE:
				_sling()
				var ph := fmod(act_time + seedf * 3.0, 5.0)
				var drag := ph < 1.3
				t_arr = Vector3(0.45 if drag else 0.25, 0, -0.45 if drag else -0.1)
				t_far = Vector3(2.35 if drag else 1.2, 0, 0)
				t_arl = Vector3(0.1, 0, -0.1)
				t_fal = Vector3(0.3, 0, 0)
				t_head = Vector3(0.25 if ph > 1.4 and ph < 2.4 else 0.0, sin(act_time * 0.3 + seedf) * 0.3, 0)
				t_hips_p.x = 0.04
				t_thr = Vector3(0, 0, 0.08)
				k = 6.0
			Soldier.Act.IDLE_SIT:
				_sling()
				t_hips_p = Vector3(0, 0.2, 0.05)
				t_thl = Vector3(1.35, 0, -0.12)
				t_shl = Vector3(-1.5, 0, 0)
				t_thr = Vector3(1.45, 0, 0.12)
				t_shr = Vector3(-1.9, 0, 0)
				t_torso = Vector3(-0.12, 0, 0)
				t_arl = Vector3(0.85, 0, 0.1)
				t_fal = Vector3(0.5, 0, 0)
				t_arr = Vector3(0.85, 0, -0.1)
				t_far = Vector3(0.5, 0, 0)
				t_head = Vector3(-0.15 + sin(act_time * 0.5) * 0.05, sin(act_time * 0.23 + seedf) * 0.5, 0)
				k = 5.0
			Soldier.Act.IDLE_STRETCH:
				_sling()
				var up := act_time < 2.2
				t_arl = Vector3(PI - 0.25, 0, 0.35) if up else Vector3(0.1, 0, -0.1)
				t_arr = Vector3(PI - 0.25, 0, -0.35) if up else Vector3(0.1, 0, 0.1)
				t_fal = Vector3(0.7, 0, 0) if up else Vector3(0.2, 0, 0)
				t_far = t_fal
				t_torso = Vector3(0.22 if up else 0.0, 0, sin(act_time * 2.0) * 0.12)
				t_head = Vector3(0.35 if up else 0.0, 0, 0)
				k = 5.0
			Soldier.Act.IDLE_CHECK:
				t_gun_p = Vector3(0.0, 0.36, -0.36)
				t_gun_r = Vector3(0.25, 0.35 + sin(act_time * 0.9) * 0.3, 1.2)
				t_arl = Vector3(0.75, 0, 0.25)
				t_fal = Vector3(1.0, 0, 0)
				t_arr = Vector3(0.65, 0, -0.2)
				t_far = Vector3(1.1, 0, 0)
				t_head = Vector3(-0.45, 0, 0)
				t_torso = Vector3(-0.12, 0, 0)
				k = 8.0
			Soldier.Act.IDLE_LOOK:
				var sw := sin(act_time * 0.7 + seedf)
				t_head = Vector3(0.05, sw * 0.75, 0)
				t_torso = Vector3(0, sw * 0.25, 0)
				if act_time > 1.5 and act_time < 4.0:
					t_arl = Vector3(1.6, 0, 0.45)
					t_fal = Vector3(1.5, 0, 0)
				k = 6.0
			_:
				_posture_pose(posture, act, moving, sp, cp, speed, lean_shoot)
	if tube:
		if act == Soldier.Act.LAUNCH and look != "op" and not is_mortar:
			tube.position = tube.position.lerp(Vector3(0.18, 0.62, -0.1), 0.3)
			tube.rotation = tube.rotation.lerp(Vector3(0, 0, 0), 0.3)
			show_gun = false
		else:
			tube.position = tube.position.lerp(Vector3(0.18, 0.45, 0.18), 0.2)
			tube.rotation = tube.rotation.lerp(Vector3(0.3, 0, 0.2), 0.2)
	gun.visible = show_gun
	pistol.visible = show_pistol
	stretcher.visible = show_stretcher
	_apply(dt, k)


func _posture_pose(posture: int, act: int, moving: bool, sp: float, cp: float, speed: float, lean_shoot: bool) -> void:
	var aiming := act == Soldier.Act.SHOOT or act == Soldier.Act.LAUNCH
	if aiming:
		# shouldered, cheek on the stock
		t_gun_p = Vector3(0.13, 0.47, -0.18)
		t_gun_r = Vector3(0.02, 0.0, 0.0)
		t_head = Vector3(-0.14, 0.12, 0.1)
		if lean_shoot and act == Soldier.Act.SHOOT:
			# recoil: the muzzle climbs and the shoulder rocks with each shot
			var kick := maxf(0.0, sin(act_time * 38.0 + seedf)) * 0.035
			t_gun_p.z += kick
			t_gun_r.x += kick * 2.2
			t_torso.x += kick * 0.6
		if look == "op":
			ik_l = false
			ik_r = false
			t_arr = Vector3(1.1, 0, -0.3)
			t_arl = Vector3(1.1, 0, 0.3)
			t_gun_p = Vector3(0.1, 0.3, -0.38)
	if act == Soldier.Act.RELOAD:
		# weapon canted in, support hand to the pouch and back to the magwell
		t_gun_p = Vector3(0.08, 0.36, -0.26)
		t_gun_r = Vector3(0.35, 0.25, 0.55)
		var ph := fmod(act_time, 1.6)
		ik_l_target = Vector3(-0.12, 0.08, -0.12) if ph < 0.7 else Vector3(0.02, 0.24, -0.36)
		t_head = Vector3(-0.35, 0.15, 0)
	match posture:
		Soldier.Post.CROUCH:
			if moving:
				t_hips_p = Vector3(0, 0.72, 0)
				t_torso = Vector3(-0.35, 0, 0)
				if not aiming:
					# compressed ready: weapon high, muzzle just below the eyeline
					t_gun_p = Vector3(0.1, 0.4, -0.28)
					t_gun_r = Vector3(-0.15, 0.0, 0.0)
				t_thl = Vector3(0.7 + sp * 0.45, 0, 0)
				t_thr = Vector3(0.7 - sp * 0.45, 0, 0)
				t_shl = Vector3(-1.0 - maxf(0.0, -sp) * 0.4, 0, 0)
				t_shr = Vector3(-1.0 - maxf(0.0, sp) * 0.4, 0, 0)
			else:
				_kneel()
		Soldier.Post.PRONE:
			_prone()
			if moving or act == Soldier.Act.CRAWL:
				_crawl(sp, cp)
		Soldier.Post.LEAN_L, Soldier.Post.LEAN_R:
			var s := 1.0 if posture == Soldier.Post.LEAN_L else -1.0
			if lean_shoot or aiming:
				# step out and tilt round the corner, weapon still on the shoulder
				t_torso = Vector3(-0.08, 0, s * 0.42)
				t_hips_p = Vector3(-s * 0.16, H0 - 0.08, 0)
				t_head = Vector3(-0.1, 0.1, -s * 0.26)
				t_thl = Vector3(0.18, 0, 0.12 if s > 0.0 else -0.05)
				t_thr = Vector3(-0.1, 0, 0.05 if s > 0.0 else -0.12)
				t_shl = Vector3(-0.3, 0, 0)
				t_shr = Vector3(-0.25, 0, 0)
			else:
				t_gun_p = Vector3(0.1, 0.4, -0.26)
				t_gun_r = Vector3(0.9, 0.0, 0.1)
			if moving:
				_walk(sp, cp, 0.45)
		_:
			if over_wall and not moving:
				overwall()
			elif not moving and not aiming:
				var tt := Time.get_ticks_msec() * 0.001
				t_torso.x += sin(tt * 1.7 + seedf) * 0.02
				if act == Soldier.Act.IDLE:
					t_head.y += sin(tt * 0.33 + seedf) * 0.3
			if moving and not has_gun:
				var amp := 0.85 if speed > 3.2 else 0.45
				t_arl = Vector3(-sp * amp * 0.8, 0, -0.08)
				t_arr = Vector3(sp * amp * 0.8, 0, 0.08)
				t_fal = Vector3(0.35 + maxf(0.0, -sp) * amp * 0.9, 0, 0)
				t_far = Vector3(0.35 + maxf(0.0, sp) * amp * 0.9, 0, 0)
			if moving:
				var run := speed > 3.2
				_walk(sp, cp, 0.85 if run else 0.45)
				if run:
					t_torso = Vector3(-0.28, 0, 0)
					if not aiming:
						# port arms, bouncing with the stride
						t_gun_p = Vector3(0.0, 0.34 + absf(sp) * 0.03, -0.24)
						t_gun_r = Vector3(0.35, 0.75, 0.35 + cp * 0.06)


func _walk(sp: float, cp: float, amp: float) -> void:
	t_thl = Vector3(sp * amp, 0, 0)
	t_thr = Vector3(-sp * amp, 0, 0)
	t_torso.y += sp * 0.07 * amp
	t_shl = Vector3(-maxf(0.0, -cp) * amp * 1.4, 0, 0)
	t_shr = Vector3(-maxf(0.0, cp) * amp * 1.4, 0, 0)
	t_hips_p.y = t_hips_p.y - absf(sp) * 0.04 * amp


## Rifle slung across the back, both hands free.
func _sling() -> void:
	t_gun_p = Vector3(0.0, 0.32, 0.2)
	t_gun_r = Vector3(0.8, PI * 0.5, 0)


## Where he ends up when he's killed (one of three, fixed per man).
func _death_pose() -> void:
	match dvar:
		0:  # on his back, one knee up, head rolled aside
			t_root_r = Vector3(PI * 0.5, 0, 0)
			t_root_p = Vector3(0, 0.13, -0.8)
			t_arl = Vector3(0.35, 0, -0.6)
			t_fal = Vector3(0.6, 0, 0)
			t_arr = Vector3(0.1, 0, 0.3)
			t_head = Vector3(0, 0.7, 0)
			t_thl = Vector3(0.55, 0, -0.1)
			t_shl = Vector3(-1.0, 0, 0)
			t_thr = Vector3(0.05, 0, 0.18)
		1:  # face down, one arm flung out ahead
			t_root_r = Vector3(-PI * 0.5, 0, 0)
			t_root_p = Vector3(0, 0.14, 0.8)
			t_arl = Vector3(2.8, 0, -0.4)
			t_fal = Vector3(0.3, 0, 0)
			t_arr = Vector3(0.3, 0, 0.35)
			t_far = Vector3(0.9, 0, 0)
			t_head = Vector3(0.5, 0.9, 0)
			t_thl = Vector3(0.05, 0, -0.2)
			t_thr = Vector3(0.45, 0, 0.12)
			t_shr = Vector3(-0.7, 0, 0)
		_:  # on his side, curled up
			t_root_r = Vector3(0, 0, PI * 0.5)
			t_root_p = Vector3(0.78, 0.2, 0)
			t_torso = Vector3(-0.35, 0, 0)
			t_head = Vector3(-0.3, 0, 0)
			t_thl = Vector3(1.0, 0, 0)
			t_shl = Vector3(-1.4, 0, 0)
			t_thr = Vector3(0.7, 0, 0)
			t_shr = Vector3(-1.1, 0, 0)
			t_arl = Vector3(1.1, 0, 0.2)
			t_fal = Vector3(1.2, 0, 0)
			t_arr = Vector3(0.9, 0, -0.1)
			t_far = Vector3(0.8, 0, 0)


## Low crawl: belly down, the arm on one side reaches forward as the knee on
## the same side draws up, then the other; the body snakes from side to side.
func _crawl(sp: float, cp: float) -> void:
	t_arl = Vector3(2.75 + sp * 0.4, 0, -0.45 - maxf(0.0, sp) * 0.2)
	t_arr = Vector3(2.75 - sp * 0.4, 0, 0.45 + maxf(0.0, -sp) * 0.2)
	t_fal = Vector3(0.9 - sp * 0.5, 0, 0)
	t_far = Vector3(0.9 + sp * 0.5, 0, 0)
	t_thl = Vector3(maxf(0.0, sp) * 0.5, 0, -0.35 - maxf(0.0, sp) * 0.45)
	t_thr = Vector3(maxf(0.0, -sp) * 0.5, 0, 0.35 + maxf(0.0, -sp) * 0.45)
	t_shl = Vector3(-maxf(0.0, sp) * 1.1, 0, 0)
	t_shr = Vector3(-maxf(0.0, -sp) * 1.1, 0, 0)
	t_torso = Vector3(0, sp * 0.18, cp * 0.06)
	t_head = Vector3(0.75, -sp * 0.15, 0)
	# rifle slung across the forearms
	t_gun_p = Vector3(0.05, 0.62, -0.32)
	t_gun_r = Vector3(PI * 0.5, 0.5, 0)
	ik_l = false
	ik_r = false


## Firing over a low wall: knees bent, leaning into the wall, the weapon
## rested on top of it.
func overwall() -> void:
	t_hips_p = Vector3(0, 0.78, 0.06)
	t_thl = Vector3(0.55, 0, -0.08)
	t_shl = Vector3(-0.8, 0, 0)
	t_thr = Vector3(0.2, 0, 0.1)
	t_shr = Vector3(-0.55, 0, 0)
	t_torso = Vector3(-0.32, 0, 0)
	t_gun_p = Vector3(0.12, 0.47, -0.2)
	t_gun_r = Vector3(0.05, 0.0, 0.0)


func _kneel() -> void:
	t_hips_p = Vector3(0, 0.56, 0)
	t_thl = Vector3(1.45, 0, 0)
	t_shl = Vector3(-1.5, 0, 0)
	t_thr = Vector3(0.05, 0, 0.05)
	t_shr = Vector3(-1.55, 0, 0)
	t_torso.x += -0.08


func _prone() -> void:
	t_root_r = Vector3(-PI * 0.5, 0, 0)
	t_root_p = Vector3(0, 0.14, 0.8)
	t_thl = Vector3(0, 0, -0.12)
	t_thr = Vector3(0, 0, 0.12)
	t_shl = Vector3.ZERO
	t_shr = Vector3.ZERO
	t_torso = Vector3.ZERO
	t_head = Vector3(0.9, 0, 0)
	t_arl = Vector3(2.75, 0, -0.35)
	t_arr = Vector3(2.75, 0, 0.3)
	t_gun_p = Vector3(0.1, 0.82, -0.18)
	t_gun_r = Vector3(PI * 0.5, 0, 0)


func _flung(dt: float) -> void:
	if tumble == Vector3.ZERO:
		tumble = Vector3(randf_range(5.0, 9.0), randf_range(-2.0, 2.0), randf_range(-4.0, 4.0))
	root.rotation += tumble * dt
	root.position = root.position.lerp(Vector3(0, 0.0, 0), 0.2)
	thigh_l.rotation = thigh_l.rotation.lerp(Vector3(0.8, 0, -0.6), 0.2)
	thigh_r.rotation = thigh_r.rotation.lerp(Vector3(-0.5, 0, 0.6), 0.2)
	arm_l.rotation = arm_l.rotation.lerp(Vector3(2.0, 0, -1.4), 0.2)
	arm_r.rotation = arm_r.rotation.lerp(Vector3(1.0, 0, 1.6), 0.2)
	gun.visible = false


func _apply(dt: float, k: float) -> void:
	if ik_l or ik_r:
		_solve_hands()
	tumble = Vector3.ZERO
	var f := 1.0 - exp(-dt * k)
	# a joint that has reached its pose isn't touched (every set re-transforms
	# its meshes on the render server)
	_mv(root, t_root_p, f)
	_rot(root, t_root_r, f)
	_mv(hips, t_hips_p, f)
	_rot(torso, t_torso, f)
	_rot(head, t_head, f)
	_rot(thigh_l, t_thl, f)
	_rot(thigh_r, t_thr, f)
	_rot(shin_l, t_shl, f)
	_rot(shin_r, t_shr, f)
	_rot(arm_l, t_arl, f)
	_rot(arm_r, t_arr, f)
	_rot(forearm_l, t_fal, f)
	_rot(forearm_r, t_far, f)
	if gun.visible:
		_mv(gun, t_gun_p, f)
		_rot(gun, t_gun_r, f)


func _rot(n: Node3D, target: Vector3, f: float) -> void:
	var cur := n.rotation
	var nr := _lerp_rot(cur, target, f)
	if (nr - cur).length_squared() > 1e-8:
		n.rotation = nr


func _mv(n: Node3D, target: Vector3, f: float) -> void:
	var cur := n.position
	var np := cur.lerp(target, f)
	if (np - cur).length_squared() > 1e-9:
		n.position = np


func _lerp_rot(a: Vector3, b: Vector3, f: float) -> Vector3:
	return Vector3(lerp_angle(a.x, b.x, f), lerp_angle(a.y, b.y, f), lerp_angle(a.z, b.z, f))



# --- arm IK ------------------------------------------------------------------------------

## Puts the hands on the weapon (grip and handguard) wherever the pose has put
## the weapon, bending the elbows like a person would.
func _solve_hands() -> void:
	var gb := Basis.from_euler(t_gun_r)
	var grip := t_gun_p + gb * Vector3(0.0, -0.08, 0.04)
	var fore := t_gun_p + gb * Vector3(0.0, -0.06, fore_z)
	if ik_r:
		var r := _ik(SH_R, grip, Vector3(0.75, -0.65, 0.25))
		t_arr = r[0]
		t_far = r[1]
	if ik_l:
		var tl := ik_l_target if ik_l_target != Vector3.INF else fore
		var l := _ik(SH_L, tl, Vector3(-0.35, -1.0, 0.1))
		t_arl = l[0]
		t_fal = l[1]


## Two-bone IK in torso space: [upper arm euler, forearm euler] reaching from
## shoulder `s` to `t`, the elbow pushed towards `pole`.
static func _ik(s: Vector3, t: Vector3, pole: Vector3) -> Array:
	var to := t - s
	var d := clampf(to.length(), 0.08, UPPER + LOWER - 0.002)
	var tn := to.normalized() if to.length() > 0.001 else Vector3.DOWN
	var cos_e := clampf((UPPER * UPPER + LOWER * LOWER - d * d) / (2.0 * UPPER * LOWER), -1.0, 1.0)
	var bend := PI - acos(cos_e)
	var cos_a := clampf((UPPER * UPPER + d * d - LOWER * LOWER) / (2.0 * UPPER * d), -1.0, 1.0)
	var a := acos(cos_a)
	var pp := pole - tn * pole.dot(tn)
	if pp.length() < 0.001:
		pp = Vector3(0, -1, 0) - tn * (-tn.y)
	pp = pp.normalized()
	var u := (tn * cos(a) + pp * sin(a)).normalized()
	var elbow := s + u * UPPER
	var f := (s + tn * d - elbow).normalized()
	var y := -u
	var zp := -(f - u * f.dot(u))
	if zp.length() < 0.001:
		zp = pp
	zp = zp.normalized()
	var x := y.cross(zp).normalized()
	zp = x.cross(y).normalized()
	var arm := Basis(x, y, zp).get_euler()
	return [arm, Vector3(bend, 0, 0)]
