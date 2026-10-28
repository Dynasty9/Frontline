class_name SoldierModel
extends Node3D
## Low-poly articulated soldier, sculpted from lofted shapes (BodyMesh) and
## boxes in the style of the early Metal Gear Solid games, posed procedurally.
## Local -Z is forward. Joints are Node3D pivots; poses are Euler targets
## that the joints ease towards every frame.

const H0 := 0.95

var skinned: SkinnedRifleman
var rifle_driver: RefCounted
var _native_locomotion := false
var _native_prone := false

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
var motion := HumanoidMotion.new()
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
var over_wall := false  # up over the barrier he's behind, weapon on the top
var cover_h := 0.0  # height of the barrier he's at (0: none)
var blind := false  # holding the weapon up over the top, head down
var muzzle_local := Vector3(0, 0.01, -0.8)  # the weapon's muzzle in gun space
var crew := false  # working a mounted gun: his own slung, hands on its grips
var move_yaw := 0.0  # which way he's moving, relative to where he faces (+ to his left)
var gait_amp := 0.3  # how far the thighs swing at this speed (see pose())
var nade: Node3D  # a grenade in his right hand (cooking it, throwing it)
var tails: Node3D  # a bandana's knot: its tails stream out behind him when he runs
var _back := false
var _kick := 0.0  # recoil from the shots just fired, dying away
var _kick_on := Vector3.ZERO  # what of it the joints carry now: weapon back, muzzle up, shoulders back
## Attachment sockets (torso space). Carried kit is built to one convention -
## forward along -Z, top along +Y, origin at its balance point - and sits in a
## socket: stowed across the back, or shouldered to fire.
const SOCK_BACK := Transform3D(Basis(Vector3(0.83, 0.55, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.55, -0.83, 0.0)), Vector3(0.0, 0.42, 0.29))
const SOCK_SHOULDER := Transform3D(Basis.IDENTITY, Vector3(0.14, 0.665, -0.2))
var _launch_grips := false
var crew_r := Vector3.ZERO  # world positions of the mounted gun's handles
var crew_l := Vector3.ZERO
# two-hand weapon hold: the arms are solved from where the weapon is
var weapon_slung := false
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
var t_hips_r := Vector3.ZERO
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
var t_tails := Vector3.ZERO


## The body's shape, as cross-sections down each part (see BodyMesh.ring):
## [y, half width, depth in front, depth behind, centre z]. Kit worn over a
## part follows these (see _at), so straps, pads and plates sit on the body.
const PELVIS := [[-0.14, 0.135, 0.09, 0.096], [-0.07, 0.168, 0.106, 0.118], [0.02, 0.166, 0.104, 0.11], [0.11, 0.152, 0.098, 0.1]]
const TORSO := [[-0.03, 0.152, 0.098, 0.1], [0.1, 0.156, 0.104, 0.1], [0.22, 0.178, 0.116, 0.105], [0.34, 0.2, 0.13, 0.112],
	[0.44, 0.212, 0.134, 0.115], [0.53, 0.205, 0.116, 0.11], [0.6, 0.15, 0.086, 0.095], [0.655, 0.064, 0.055, 0.06]]
const THIGH := [[0.03, 0.094, 0.094, 0.1], [-0.1, 0.1, 0.106, 0.1], [-0.26, 0.086, 0.09, 0.084], [-0.4, 0.07, 0.072, 0.07], [-0.47, 0.064, 0.066, 0.064]]
const SHIN := [[0.02, 0.067, 0.068, 0.068], [-0.1, 0.066, 0.064, 0.078], [-0.22, 0.056, 0.056, 0.06], [-0.3, 0.054, 0.054, 0.056]]
const UPPER_ARM := [[0.0, 0.07, 0.07, 0.068], [-0.08, 0.068, 0.073, 0.066], [-0.18, 0.06, 0.063, 0.058], [-0.3, 0.05, 0.05, 0.05]]
const FOREARM := [[0.02, 0.05, 0.05, 0.05], [-0.05, 0.057, 0.055, 0.054], [-0.15, 0.047, 0.046, 0.046], [-0.205, 0.04, 0.04, 0.04]]
## the head: a squared jaw set forward, cheekbones, a high brow
const HEAD := [[0.012, 0.03, 0.022, 0.03, -0.058], [0.035, 0.06, 0.05, 0.06, -0.035], [0.07, 0.078, 0.082, 0.078, -0.012],
	[0.11, 0.084, 0.096, 0.09, 0.0], [0.15, 0.086, 0.098, 0.098, 0.003], [0.19, 0.083, 0.092, 0.1, 0.006], [0.222, 0.068, 0.072, 0.086, 0.01],
	[0.243, 0.04, 0.04, 0.052, 0.012]]

## Dresses and arms a man of this unit type. The look is after the early
## Metal Gear Solid games: heroic, heavy-shouldered figures in fitted kit with
## a strong silhouette - the Coalition as FOXHOUND operators in slate sneaking
## suits, the Rebels as Genome and Gurlukovich soldiers in balaclavas, berets
## and mismatched field jackets.
func build(utype: String, team: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	seedf = float(seed % 997) * 0.731
	dvar = int(seed / 7) % 3
	var u: Dictionary = Defs.UNITS.get(utype, {})
	var bearer: bool = u.get("bearer", false)
	var is_crew: bool = u.get("crew", false)
	var medic: bool = u.get("medic", false)
	var k := _palette(team, is_crew, rng)

	root = _joint(self, Vector3.ZERO)
	hips = _joint(root, Vector3(0, H0, 0))
	torso = _joint(hips, Vector3(0, 0.05, 0))
	head = _joint(torso, Vector3(0, 0.62, 0))
	thigh_l = _joint(hips, Vector3(-0.1, -0.05, 0))
	shin_l = _joint(thigh_l, Vector3(0, -0.45, 0))
	thigh_r = _joint(hips, Vector3(0.1, -0.05, 0))
	shin_r = _joint(thigh_r, Vector3(0, -0.45, 0))
	arm_l = _joint(torso, SH_L)
	forearm_l = _joint(arm_l, Vector3(0, -0.28, 0))
	arm_r = _joint(torso, SH_R)
	forearm_r = _joint(arm_r, Vector3(0, -0.28, 0))
	_body(k)
	if bearer:
		_kit_bearer(k)
	elif is_crew:
		_kit_crew(k)
	elif team == 0:
		_kit_coalition(k, medic, rng)
	else:
		_kit_rebel(k, medic, rng)
	_head_gear(k, team, is_crew, bearer, rng)
	if medic or bearer:
		# a white armband with a red cross (a plain red one on a bearer)
		var band := Color(0.8, 0.79, 0.74) if medic else Color(0.62, 0.1, 0.08)
		_p(arm_l, BodyMesh.loft([_at(UPPER_ARM, -0.11, 0.006), _at(UPPER_ARM, -0.18, 0.006)], 10), "suit", band)
		if medic:
			_p(arm_l, Res.box(Vector3(0.012, 0.045, 0.016)), "plain", Color(0.62, 0.1, 0.08), Vector3(-0.068, -0.145, 0))
			_p(arm_l, Res.box(Vector3(0.012, 0.016, 0.045)), "plain", Color(0.62, 0.1, 0.08), Vector3(-0.068, -0.145, 0))

	var dark := Color(0.1, 0.1, 0.1)
	var steel := Color(0.15, 0.15, 0.15)
	var wood := Color(0.3, 0.2, 0.12)
	var fde := Color(0.45, 0.38, 0.27)  # flat dark earth rifle furniture
	var pack: Color = k.pouch
	# weapon (forward is -z; grip near the origin, handguard ahead of it)
	gun = _joint(torso, Vector3(0.1, 0.32, -0.3))
	look = "rifle"
	var w: String = u.get("weapon", "")
	fore_z = {"smg": -0.24, "lmg": -0.55, "pistol": -0.1, "ak": -0.27}.get(w, -0.3)
	muzzle_local = {"rifle": Vector3(0, 0.02, -0.52), "ak": Vector3(0, 0.0, -0.565), "smg": Vector3(0, 0.02, -0.4),
		"lmg": Vector3(0, 0.0, -0.85) if team == 1 else Vector3(0, 0.0, -0.77)}.get(w, Vector3(0, 0, -0.6))
	match w:
		"rifle":
			_m4(gun, dark, fde if rng.randf() < 0.35 else dark, steel, false)
		"ak":
			_akm(gun, dark, wood, steel)
		"smg":
			_m4(gun, dark, dark, steel, true)
		"lmg":
			look = "lmg"
			if team == 1:
				# PKM: slim receiver, skeleton stock and grip in laminated wood,
				# fluted barrel with a slotted flash hider, 100-round box under the right side
				Res.mi(gun, Res.box(Vector3(0.055, 0.095, 0.32)), Res.mat(dark), Vector3(0, 0, -0.06), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.06, 0.022, 0.24)), Res.mat(dark), Vector3(0, 0.058, -0.08), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.032, 0.034, 0.28)), Res.mat(wood), Vector3(0, 0.0, 0.24), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.032, 0.028, 0.29)), Res.mat(wood), Vector3(0, -0.075, 0.23), Vector3(0.22, 0, 0), false)
				Res.mi(gun, Res.box(Vector3(0.038, 0.13, 0.028)), Res.mat(wood), Vector3(0, -0.035, 0.37), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.032, 0.095, 0.042)), Res.mat(wood), Vector3(0, -0.09, 0.04), Vector3(-0.3, 0, 0), false)
				Res.mi(gun, Res.cyl(0.012, 0.012, 0.56, 6), Res.mat(dark), Vector3(0, 0.0, -0.5), Vector3(PI / 2, 0, 0), false)
				Res.mi(gun, Res.cyl(0.009, 0.009, 0.32, 5), Res.mat(dark), Vector3(0, -0.03, -0.36), Vector3(PI / 2, 0, 0), false)
				Res.mi(gun, Res.cyl(0.016, 0.016, 0.07, 6), Res.mat(dark), Vector3(0, 0.0, -0.81), Vector3(PI / 2, 0, 0), false)
				Res.mi(gun, Res.box(Vector3(0.06, 0.11, 0.11)), Res.mat(Color(0.27, 0.3, 0.2)), Vector3(0.045, -0.1, -0.08), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.015, 0.045, 0.1)), Res.mat(wood), Vector3(0.035, 0.04, -0.3), Vector3.ZERO, false)
			else:
				# M249: receiver with the feed cover and rail, heat shield over the
				# barrel, folded bipod, collapsible stock, 200-round soft pouch underneath
				Res.mi(gun, Res.box(Vector3(0.07, 0.1, 0.34)), Res.mat(dark), Vector3(0, 0, -0.08), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.074, 0.028, 0.2)), Res.mat(dark), Vector3(0, 0.062, -0.1), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.022, 0.03, 0.06)), Res.mat(dark), Vector3(0, 0.09, -0.08), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.055, 0.045, 0.14)), Res.mat(dark), Vector3(0, 0.01, -0.3), Vector3.ZERO, false)
				Res.mi(gun, Res.cyl(0.013, 0.013, 0.4, 6), Res.mat(dark), Vector3(0, 0.0, -0.52), Vector3(PI / 2, 0, 0), false)
				Res.mi(gun, Res.cyl(0.017, 0.015, 0.05, 6), Res.mat(dark), Vector3(0, 0.0, -0.74), Vector3(PI / 2, 0, 0), false)
				Res.mi(gun, Res.box(Vector3(0.045, 0.085, 0.24)), Res.mat(dark), Vector3(0, -0.02, 0.22), Vector3(0.08, 0, 0), false)
				Res.mi(gun, Res.box(Vector3(0.035, 0.1, 0.045)), Res.mat(dark), Vector3(0, -0.085, 0.04), Vector3(-0.3, 0, 0), false)
				Res.mi(gun, Res.box(Vector3(0.1, 0.11, 0.13)), Res.mat(pack), Vector3(-0.02, -0.11, -0.1), Vector3.ZERO, false)
				Res.mi(gun, Res.box(Vector3(0.025, 0.06, 0.12)), Res.mat(dark), Vector3(0.04, 0.04, -0.3), Vector3.ZERO, false)
			for sx in [-0.02, 0.02]:  # bipod, folded under the barrel
				Res.mi(gun, Res.box(Vector3(0.011, 0.011, 0.3)), Res.mat(dark), Vector3(sx, -0.04, -0.5), Vector3.ZERO, false)
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
	nade = _joint(forearm_r, Vector3(0, -0.3, -0.03))
	var nb := Res.mi(nade, Res.sphere(0.045, 8), Res.mat(Color(0.25, 0.28, 0.2)), Vector3.ZERO, Vector3.ZERO, false)
	nb.scale = Vector3(1.0, 1.25, 1.0)
	Res.mi(nade, Res.box(Vector3(0.018, 0.06, 0.03)), Res.mat(Color(0.35, 0.35, 0.33)), Vector3(0.03, 0.05, 0), Vector3(0, 0, -0.3), false)
	nade.visible = false
	is_mortar = int(u.get("mortar", 0)) > 0
	if int(u.get("rockets", 0)) > 0 or is_mortar:
		tube = _joint(torso, Vector3.ZERO)
		var tcol := Color(0.29, 0.31, 0.22) if team == 0 else Color(0.27, 0.27, 0.22)
		if is_mortar:
			# a 60 mm mortar tube with its base cap and carrying handle
			Res.mi(tube, Res.cyl(0.042, 0.042, 0.95, 12), Res.mat(tcol), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			Res.mi(tube, Res.cyl(0.055, 0.055, 0.06, 12), Res.mat(dark), Vector3(0, 0, 0.47), Vector3(PI / 2, 0, 0), false)
			Res.mi(tube, Res.box(Vector3(0.02, 0.05, 0.12)), Res.mat(dark), Vector3(0, 0.06, -0.1), Vector3.ZERO, false)
		elif team == 0:
			# AT4: the fibreglass tube, its shock-absorbing end caps, sight and trigger
			Res.mi(tube, Res.cyl(0.042, 0.042, 1.0, 12), Res.mat(tcol), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			for z in [-0.48, 0.48]:
				Res.mi(tube, Res.cyl(0.05, 0.05, 0.07, 12), Res.mat(tcol.darkened(0.25)), Vector3(0, 0, z), Vector3(PI / 2, 0, 0), false)
			Res.mi(tube, Res.box(Vector3(0.025, 0.05, 0.06)), Res.mat(dark), Vector3(0, 0.06, -0.12), Vector3.ZERO, false)
			Res.mi(tube, Res.box(Vector3(0.03, 0.06, 0.04)), Res.mat(dark), Vector3(0, -0.065, 0.02), Vector3.ZERO, false)
		else:
			# RPG-7: the tube with its wooden heat guard, grips, optic and flared
			# venturi; a PG-7 grenade loaded up front, warhead and all
			Res.mi(tube, Res.cyl(0.026, 0.026, 0.95, 10), Res.mat(dark), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			Res.mi(tube, Res.cyl(0.036, 0.036, 0.24, 10), Res.mat(wood), Vector3(0, 0, -0.04), Vector3(PI / 2, 0, 0), false)
			Res.mi(tube, Res.cyl(0.05, 0.03, 0.14, 10), Res.mat(dark), Vector3(0, 0, 0.5), Vector3(PI / 2, 0, 0), false)
			for z in [-0.12, 0.08]:
				Res.mi(tube, Res.box(Vector3(0.025, 0.08, 0.035)), Res.mat(wood), Vector3(0, -0.06, z), Vector3(-0.2, 0, 0), false)
			Res.mi(tube, Res.box(Vector3(0.025, 0.04, 0.08)), Res.mat(dark), Vector3(-0.04, 0.04, -0.06), Vector3.ZERO, false)
			Res.mi(tube, Res.cyl(0.042, 0.042, 0.12, 10), Res.mat(Color(0.3, 0.33, 0.24)), Vector3(0, 0, -0.54), Vector3(PI / 2, 0, 0), false)
			Res.mi(tube, Res.cyl(0.042, 0.004, 0.17, 10), Res.mat(Color(0.3, 0.33, 0.24)), Vector3(0, 0, -0.68), Vector3(PI / 2, 0, 0), false)
		tube.transform = SOCK_BACK
	if u.get("engineer", false):
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
	# the weapons and carried kit go from flat colours onto the shared surfaces
	_skin(self, {dark: "gunmetal", steel: "gunmetal", wood: "wood_l", fde: "plain", pack: "canvas_l"})
	# one mesh per joint (a surface per material): animation is untouched and
	# each body part is a single render instance to move
	for j in [root, hips, torso, head, tails, thigh_l, shin_l, thigh_r, shin_r, arm_l, arm_r, forearm_l, forearm_r, gun, pistol, tube, back_item, stretcher]:
		if j:
			Mats.merge_static(j, [], false, false, true)
	# Opt-in until the character source assets are installed for a release.
	if is_inside_tree() and get_parent() is Soldier and utype == "rifleman" and "--skinned-units" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://assets/local_mocap/mixamo/Swat.fbx" if "--swat-units" in OS.get_cmdline_user_args() else "res://assets/local_mocap/character/Soldier.glb"):
		skinned = SkinnedRifleman.new()
		add_child(skinned)
		if skinned.build():
			skinned.bind_procedural(self)
			skinned.ground_height = get_parent().world.ground_y
			if "--swat-units" in OS.get_cmdline_user_args():
				load("res://scripts/game/mixamo_clips.gd").install(skinned, true)
				rifle_driver = load("res://scripts/game/rifle_animation_controller.gd").new()
				rifle_driver.setup(skinned)
				get_parent().world.stat("native_riflemen")
			root.visible = false
			# Keep pose/attachment pivots, but discard geometry replaced by the skin.
			for mesh in root.find_children("*", "MeshInstance3D", true, false):
				if mesh.get_child_count() == 0: mesh.queue_free()
		else:
			skinned.queue_free()
			skinned = null



## What he wears, by side: a dictionary of colours (and the surfaces they go on).
func _palette(team: int, is_crew: bool, rng: RandomNumberGenerator) -> Dictionary:
	var k := {}
	k.skin = [Color(0.86, 0.68, 0.55), Color(0.72, 0.53, 0.4), Color(0.55, 0.38, 0.27), Color(0.4, 0.28, 0.2), Color(0.9, 0.75, 0.62)][rng.randi() % 5]
	k.hair = [Color(0.09, 0.075, 0.06), Color(0.2, 0.14, 0.09), Color(0.3, 0.22, 0.14), Color(0.06, 0.06, 0.06)][rng.randi() % 4]
	k.boot = Color(0.1, 0.095, 0.09)
	k.glove = k.skin
	k.glove_kind = "skin"
	k.rolled = false
	k.top_kind = "suit"
	k.pants_kind = "suit"
	if team == 0:
		# FOXHOUND: a slate-grey sneaking suit, its armour a shade darker,
		# black webbing and gloves
		k.top = Res.vary(Color(0.3, 0.33, 0.335), 0.025, rng)
		k.pants = k.top
		k.armor = Color(0.2, 0.215, 0.22)
		k.web = Color(0.1, 0.105, 0.105)
		k.pouch = Color(0.24, 0.26, 0.26)
		k.glove = Color(0.1, 0.1, 0.1)
		k.glove_kind = "boot"
	elif team == 1:
		# Genome and Gurlukovich soldiers: field jackets and trousers that don't
		# match, a chest rig over them, some in camouflage
		k.top = Res.vary([Color(0.4, 0.38, 0.27), Color(0.48, 0.42, 0.31), Color(0.36, 0.29, 0.21), Color(0.31, 0.33, 0.27), Color(0.22, 0.22, 0.21)][rng.randi() % 5], 0.05, rng)
		if rng.randf() < 0.15:
			k.top_kind = "camo_rebel"
		k.pants = Res.vary([Color(0.22, 0.22, 0.2), Color(0.32, 0.31, 0.23), Color(0.4, 0.36, 0.27), Color(0.2, 0.21, 0.23)][rng.randi() % 4], 0.04, rng)
		k.armor = Res.vary([Color(0.33, 0.32, 0.23), Color(0.42, 0.37, 0.27), Color(0.25, 0.26, 0.21)][rng.randi() % 3], 0.05, rng)
		k.web = Color(0.2, 0.19, 0.15)
		k.pouch = (k.armor as Color).darkened(0.08)
		k.boot = Color(0.12, 0.1, 0.08)
		k.rolled = rng.randf() < 0.35
		if rng.randf() < 0.35:
			k.glove = Color(0.14, 0.13, 0.11)
			k.glove_kind = "boot"
	else:
		# a stretcher bearer: a white smock over grey trousers
		k.top = Color(0.78, 0.78, 0.75)
		k.pants = Color(0.3, 0.32, 0.3)
		k.armor = Color(0.8, 0.8, 0.78)
		k.web = Color(0.3, 0.3, 0.28)
		k.pouch = Color(0.6, 0.6, 0.58)
	if is_crew:
		# vehicle crew: one-piece coveralls and gloves
		k.top = Res.vary(Color(0.3, 0.32, 0.29) if team == 0 else Color(0.22, 0.22, 0.2), 0.02, rng)
		k.top_kind = "suit"
		k.pants = k.top
		k.glove = Color(0.1, 0.1, 0.1)
		k.glove_kind = "boot"
		k.rolled = false
	return k


## A part of the model on one of the shared surfaces, tinted to `col`.
func _p(parent: Node3D, mesh: Mesh, kind: String, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	Mats.apply(mi, kind, Mats.tint_for(kind, col))
	return mi


static func _rg(y: float, hw: float, front: float, back: float, sq := 2.0, cx := 0.0, cz := 0.0) -> PackedFloat32Array:
	return BodyMesh.ring(y, hw, front, back, sq, cx, cz)


## A part's cross-section at height y (between the rows of its table), grown
## by g all round: kit worn over the body follows its shape.
static func _at(table: Array, y: float, g := 0.0, sq := 2.2) -> PackedFloat32Array:
	var n := table.size()
	var dir := signf(float(table[n - 1][0]) - float(table[0][0]))
	var i := 0
	while i < n - 2 and (y - float(table[i + 1][0])) * dir > 0.0:
		i += 1
	var a: Array = table[i]
	var b: Array = table[i + 1]
	var t := clampf((y - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	var cz := lerpf(float(a[4]), float(b[4]), t) if a.size() > 4 else 0.0
	return BodyMesh.ring(y, lerpf(float(a[1]), float(b[1]), t) + g, lerpf(float(a[2]), float(b[2]), t) + g, lerpf(float(a[3]), float(b[3]), t) + g, sq, 0.0, cz)


## Every row of a table as a ring.
static func _rings(table: Array, g := 0.0, sq := 2.2) -> Array:
	var out := []
	for row in table:
		out.append(_at(table, float(row[0]), g, sq))
	return out


## How far forward the front of a cross-section is at x (to set kit on it).
static func _front(r: PackedFloat32Array, x: float) -> float:
	var t := clampf(absf(x - r[5]) / r[1], 0.0, 1.0)
	return r[6] - r[2] * pow(1.0 - pow(t, r[4]), 1.0 / r[4])


## A strap or a belt laid straight from a to b (in the parent's space).
func _strip(parent: Node3D, a: Vector3, b: Vector3, w: float, th: float, kind: String, col: Color) -> void:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.UP).normalized()
	var z := x.cross(y).normalized()
	var mi := _p(parent, Res.box(Vector3(w, d.length(), th)), kind, col, (a + b) * 0.5)
	mi.basis = Basis(x, y, z)


## A strap laid across the front of the chest from (x0, y0) to (x1, y1),
## following its curve in n straight runs: a bandolier, a satchel's strap.
func _sash(x0: float, y0: float, x1: float, y1: float, n: int, w: float, th: float, kind: String, col: Color) -> void:
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		var x := lerpf(x0, x1, t)
		var y := lerpf(y0, y1, t)
		pts.append(Vector3(x, y, _front(_at(TORSO, y, 0.012, 2.3), x) - th * 0.3))
	for i in n:
		_strip(torso, pts[i], pts[i + 1], w, th, kind, col)


## The man himself in his uniform: a deep chest tapering to a narrow waist,
## heavy shoulders, limbs with muscle on them, gloved hands and big boots.
func _body(k: Dictionary) -> void:
	var top: Color = k.top
	var tk: String = k.top_kind
	var pants: Color = k.pants
	var pk: String = k.pants_kind
	_p(hips, BodyMesh.loft(_rings(PELVIS, 0.0, 2.4), 12), pk, pants)
	_p(torso, BodyMesh.loft(_rings(TORSO, 0.0, 2.3), 12), tk, top)
	for side in [-1.0, 1.0]:
		var th: Node3D = thigh_l if side < 0.0 else thigh_r
		var sh: Node3D = shin_l if side < 0.0 else shin_r
		_p(th, Res.sphere(0.094, 10), pk, pants)
		_p(th, BodyMesh.loft(_rings(THIGH, 0.0, 2.1), 10), pk, pants)
		_p(sh, Res.sphere(0.068, 10), pk, pants)
		_p(sh, BodyMesh.loft(_rings(SHIN, 0.0, 2.1), 10), pk, pants)
		_boot(sh, k)
		var ua: Node3D = arm_l if side < 0.0 else arm_r
		var fa: Node3D = forearm_l if side < 0.0 else forearm_r
		# the deltoid rounds off the shoulder; the arm swells at the bicep and
		# the forearm below the elbow
		_p(ua, Res.sphere(0.078, 10), tk, top, Vector3(0, -0.025, 0), Vector3.ZERO, Vector3(1.0, 1.1, 1.05))
		_p(ua, BodyMesh.loft(_rings(UPPER_ARM, 0.0, 2.1), 10), tk, top)
		_p(fa, Res.sphere(0.05, 8), tk, top)
		if k.rolled:
			# sleeves rolled to the elbow
			_p(fa, BodyMesh.loft([_rg(0.035, 0.062, 0.062, 0.062), _rg(-0.035, 0.064, 0.064, 0.064)], 10), tk, top.darkened(0.06))
			_p(fa, BodyMesh.loft(_rings(FOREARM, -0.004, 2.0), 10), "skin", k.skin)
		else:
			_p(fa, BodyMesh.loft(_rings(FOREARM, 0.0, 2.0), 10), tk, top)
		_hand(fa, side, k)


## A fist closed round a grip: big gauntleted gloves, or bare hands.
func _hand(fa: Node3D, side: float, k: Dictionary) -> void:
	var gc: Color = k.glove
	var gk: String = k.glove_kind
	if gk == "skin":
		_p(fa, Res.cyl(0.042, 0.04, 0.05, 10), gk, gc, Vector3(0, -0.205, 0))
	else:
		_p(fa, Res.cyl(0.056, 0.048, 0.06, 10), gk, gc, Vector3(0, -0.2, 0))  # the gauntlet cuff
	_p(fa, Res.box(Vector3(0.066, 0.08, 0.088)), gk, gc, Vector3(0, -0.25, 0), Vector3(0.15, 0, 0))
	_p(fa, Res.box(Vector3(0.062, 0.052, 0.074)), gk, gc, Vector3(0, -0.293, -0.018), Vector3(0.55, 0, 0))
	_p(fa, Res.box(Vector3(0.024, 0.052, 0.026)), gk, gc, Vector3(-side * 0.03, -0.252, -0.044), Vector3(0.3, 0, 0))


## A big combat boot: a padded shaft strapped at the ankle, a high toe box,
## a thick sole.
func _boot(sh: Node3D, k: Dictionary) -> void:
	var bc: Color = k.boot
	_p(sh, BodyMesh.loft([_rg(-0.24, 0.065, 0.066, 0.068), _rg(-0.31, 0.064, 0.066, 0.07), _rg(-0.38, 0.062, 0.068, 0.072)], 10), "boot", bc)
	_p(sh, BodyMesh.loft([_rg(-0.236, 0.07, 0.071, 0.073), _rg(-0.262, 0.07, 0.071, 0.073)], 10), "boot", bc.lightened(0.06))
	_p(sh, BodyMesh.loft([_rg(-0.318, 0.068, 0.07, 0.074), _rg(-0.342, 0.068, 0.07, 0.074)], 10), "webbing", bc.darkened(0.2))
	# the foot, lofted heel to toe (built upright, turned to point forward)
	var foot := [_rg(0.0, 0.048, 0.03, 0.055, 2.5), _rg(0.06, 0.056, 0.035, 0.085, 2.5), _rg(0.14, 0.058, 0.035, 0.06, 2.5),
		_rg(0.22, 0.056, 0.034, 0.038, 2.5), _rg(0.265, 0.044, 0.03, 0.024, 2.5)]
	_p(sh, BodyMesh.loft(foot, 10), "boot", bc, Vector3(0, -0.395, 0.085), Vector3(-PI / 2, 0, 0))
	_p(sh, Res.box(Vector3(0.124, 0.038, 0.3)), "rubber", Color(0.06, 0.055, 0.05), Vector3(0, -0.44, -0.06))


## The Coalition, as FOXHOUND: a segmented belly under a fitted armour vest
## with a high padded collar, layered shoulder pads, black webbing, a pistol
## holstered on the right thigh and knee pads - Snake's silhouette, in squads.
func _kit_coalition(k: Dictionary, medic: bool, rng: RandomNumberGenerator) -> void:
	var ar: Color = k.armor
	var web: Color = k.web
	var pouch: Color = k.pouch
	# the belly: three armoured segments between the belt and the vest
	for i in 3:
		var y := 0.045 + i * 0.05
		_p(torso, BodyMesh.plate([_at(TORSO, y, 0.012, 2.3), _at(TORSO, y + 0.036, 0.012, 2.3)], -PI * 0.92, -PI * 0.08, 10, 0.016), "armor", ar)
	# the vest: chest and back plates in one fitted shell, the suit showing at
	# the armholes
	_p(torso, BodyMesh.loft([_rg(0.19, 0.2, 0.137, 0.127, 2.7), _rg(0.3, 0.222, 0.157, 0.137, 2.7), _rg(0.42, 0.228, 0.166, 0.142, 2.7),
		_rg(0.5, 0.205, 0.154, 0.138, 2.7), _rg(0.565, 0.165, 0.118, 0.122, 2.7)], 14), "armor", ar)
	# the high padded collar, dipping at the front under his chin
	_p(torso, BodyMesh.loft([_rg(-0.045, 0.12, 0.102, 0.114, 2.2), _rg(0.02, 0.1, 0.086, 0.096, 2.2), _rg(0.055, 0.092, 0.079, 0.09, 2.2)], 12),
		"webbing", web, Vector3(0, 0.6, 0.0), Vector3(-0.34, 0, 0))
	# webbing: shoulder straps over the vest, magazine pouches, an admin pouch
	for sx in [-1.0, 1.0]:
		_p(torso, Res.box(Vector3(0.05, 0.026, 0.27)), "webbing", web, Vector3(sx * 0.115, 0.578, 0.0))
		_p(torso, Res.box(Vector3(0.045, 0.2, 0.016)), "webbing", web, Vector3(sx * 0.112, 0.47, -0.158), Vector3(-0.12, 0, 0))
	for x in [-0.1, 0.0, 0.1]:
		_p(torso, Res.box(Vector3(0.082, 0.12, 0.05)), "canvas_l", pouch, Vector3(x, 0.3, -0.17))
		_p(torso, Res.box(Vector3(0.088, 0.03, 0.058)), "canvas_l", pouch.darkened(0.15), Vector3(x, 0.365, -0.172))
	_p(torso, Res.box(Vector3(0.15, 0.07, 0.035)), "canvas_l", pouch, Vector3(0, 0.45, -0.177), Vector3(0.12, 0, 0))
	_p(torso, Res.box(Vector3(0.07, 0.15, 0.06)), "canvas_l", pouch, Vector3(-0.222, 0.34, -0.01))
	# on the back: an assault pack, or the radio with its whip antenna
	if medic or rng.randf() < 0.45:
		_p(torso, Res.box(Vector3(0.27, 0.3, 0.11)), "canvas_l", pouch, Vector3(0, 0.37, 0.192))
		_p(torso, Res.box(Vector3(0.26, 0.06, 0.12)), "canvas_l", pouch.darkened(0.1), Vector3(0, 0.535, 0.192), Vector3(-0.1, 0, 0))
		for sx in [-1.0, 1.0]:
			_p(torso, Res.box(Vector3(0.04, 0.16, 0.08)), "canvas_l", pouch.darkened(0.1), Vector3(sx * 0.155, 0.33, 0.2))
		if medic:
			_p(torso, Res.box(Vector3(0.1, 0.1, 0.012)), "plain", Color(0.8, 0.79, 0.74), Vector3(0, 0.38, 0.25))
			_p(torso, Res.box(Vector3(0.07, 0.022, 0.016)), "plain", Color(0.62, 0.1, 0.08), Vector3(0, 0.38, 0.252))
			_p(torso, Res.box(Vector3(0.022, 0.07, 0.016)), "plain", Color(0.62, 0.1, 0.08), Vector3(0, 0.38, 0.252))
	else:
		_p(torso, Res.box(Vector3(0.11, 0.18, 0.065)), "canvas_l", pouch, Vector3(-0.06, 0.4, 0.17))
		_p(torso, Res.box(Vector3(0.04, 0.03, 0.03)), "plain_dark", Color(0.08, 0.08, 0.08), Vector3(-0.09, 0.505, 0.17))
		_p(torso, Res.cyl(0.005, 0.005, 0.5, 4), "plain_dark", Color(0.08, 0.08, 0.08), Vector3(-0.1, 0.76, 0.19), Vector3(0.12, 0, 0.06))
	# the belt and its buckle, pouches round it
	_p(hips, BodyMesh.loft([_rg(0.03, 0.177, 0.115, 0.122, 2.4), _rg(0.09, 0.169, 0.109, 0.114, 2.4)], 14), "webbing", web)
	_p(hips, Res.box(Vector3(0.07, 0.052, 0.02)), "gunmetal", Color(0.32, 0.32, 0.3), Vector3(0, 0.06, -0.118))
	for a in [-1.2, 1.2, 2.45, -2.45]:
		_p(hips, Res.box(Vector3(0.07, 0.09, 0.045)), "canvas_l", pouch, Vector3(sin(a) * 0.185, 0.045, cos(a) * 0.13), Vector3(0, a, 0))
	# the pistol on the right thigh, strapped round it
	_p(thigh_r, Res.box(Vector3(0.05, 0.17, 0.1)), "webbing", web.lightened(0.05), Vector3(0.108, -0.17, 0.01), Vector3(0, 0, 0.05))
	_p(thigh_r, Res.box(Vector3(0.034, 0.075, 0.042)), "gunmetal", Color(0.12, 0.12, 0.12), Vector3(0.106, -0.05, 0.03), Vector3(0.25, 0, 0.05))
	for y in [-0.12, -0.25]:
		_p(thigh_r, BodyMesh.loft([_at(THIGH, y + 0.014, 0.006), _at(THIGH, y - 0.014, 0.006)], 10), "webbing", web)
	_p(thigh_l, Res.box(Vector3(0.04, 0.13, 0.12)), "suit", (k.pants as Color).darkened(0.08), Vector3(-0.09, -0.22, 0.0), Vector3(0, 0, -0.06))
	# knee pads
	for sh in [shin_l, shin_r]:
		_p(sh, BodyMesh.plate([_rg(0.075, 0.074, 0.08, 0.07), _rg(0.0, 0.08, 0.09, 0.07), _rg(-0.08, 0.072, 0.08, 0.07)], -PI * 0.86, -PI * 0.14, 8, 0.024), "armor", web)
	# layered pads capping the shoulders, elbow pads
	for ua in [arm_l, arm_r]:
		var sx := -1.0 if ua == arm_l else 1.0
		_p(ua, BodyMesh.loft([_rg(0.07, 0.03, 0.034, 0.034, 2.2), _rg(0.056, 0.062, 0.066, 0.066, 2.4), _rg(0.028, 0.078, 0.08, 0.08, 2.5), _rg(-0.022, 0.08, 0.082, 0.082, 2.5)], 12),
			"armor", ar, Vector3(sx * 0.004, 0.0, 0.0), Vector3(0, 0, -sx * 0.1))
		_p(ua, BodyMesh.loft([_rg(-0.018, 0.075, 0.077, 0.077, 2.5), _rg(-0.064, 0.072, 0.074, 0.074, 2.5)], 12), "armor", ar.darkened(0.18),
			Vector3(sx * 0.003, 0, 0), Vector3(0, 0, -sx * 0.06))
	for fa in [forearm_l, forearm_r]:
		_p(fa, BodyMesh.plate([_rg(0.05, 0.058, 0.06, 0.066), _rg(-0.0, 0.062, 0.062, 0.07), _rg(-0.06, 0.058, 0.058, 0.064)], PI * 0.18, PI * 0.82, 8, 0.018), "armor", web)
	# shin guards above the boots
	for sh in [shin_l, shin_r]:
		_p(sh, BodyMesh.plate([_at(SHIN, -0.09, 0.012), _at(SHIN, -0.16, 0.012), _at(SHIN, -0.235, 0.012)], -PI * 0.8, -PI * 0.2, 8, 0.016), "armor", ar)
	# a subdued unit patch on the left sleeve
	_p(arm_l, Res.box(Vector3(0.012, 0.05, 0.06)), "plain", Defs.TEAM_COLORS[0].lerp(Color(0.3, 0.3, 0.3), 0.72).darkened(0.4), Vector3(-0.068, -0.15, 0))


## The Rebels, as Genome and Gurlukovich soldiers: a field jacket worn long
## over the hips with its collar turned up, the belt over it, a chest rig of
## magazine pouches (or a bandolier) - each man a little different.
func _kit_rebel(k: Dictionary, medic: bool, rng: RandomNumberGenerator) -> void:
	var top: Color = k.top
	var tk: String = k.top_kind
	var rig: Color = k.armor
	var web: Color = k.web
	var pouch: Color = k.pouch
	# the jacket's skirt and its collar, open at the throat
	_p(torso, BodyMesh.loft([_rg(-0.115, 0.178, 0.12, 0.126, 2.4), _rg(-0.02, 0.166, 0.11, 0.112, 2.4), _rg(0.06, 0.168, 0.112, 0.11, 2.4)], 12), tk, top)
	_p(torso, BodyMesh.plate([_rg(0.585, 0.122, 0.092, 0.106, 2.2), _rg(0.645, 0.104, 0.084, 0.1, 2.2), _rg(0.675, 0.118, 0.096, 0.114, 2.2)],
		-0.95, PI + 0.95, 12, 0.018), tk, top.darkened(0.05))
	if rng.randf() < 0.3:
		# a bandolier from the left shoulder to the right hip
		_sash(-0.13, 0.57, 0.14, 0.1, 4, 0.055, 0.022, "canvas_l", rig.darkened(0.15))
	else:
		# a chest rig: a panel across the front with four AK magazine pouches
		_p(torso, BodyMesh.plate([_at(TORSO, 0.22, 0.03, 2.3), _at(TORSO, 0.4, 0.03, 2.3)], -PI * 0.86, -PI * 0.14, 10, 0.03), "canvas_l", rig)
		for x in [-0.12, -0.04, 0.04, 0.12]:
			var z := _front(_at(TORSO, 0.32, 0.03, 2.3), x) - 0.022
			_p(torso, Res.box(Vector3(0.07, 0.14, 0.05)), "canvas_l", pouch, Vector3(x, 0.32, z), Vector3(0, x * 1.4, 0))
			_p(torso, Res.box(Vector3(0.074, 0.028, 0.056)), "canvas_l", pouch.darkened(0.12), Vector3(x, 0.39, z - 0.002), Vector3(0, x * 1.4, 0))
		# its straps over the shoulders, crossing at the back
		for sx in [-1.0, 1.0]:
			_p(torso, Res.box(Vector3(0.045, 0.024, 0.26)), "webbing", web, Vector3(sx * 0.105, 0.592, 0))
			_p(torso, Res.box(Vector3(0.04, 0.42, 0.02)), "webbing", web, Vector3(0, 0.4, 0.124), Vector3(0, 0, sx * 0.6))
	# breast pockets with button-down flaps
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.09
		var z := _front(_at(TORSO, 0.47, 0.0, 2.3), x)
		_p(torso, Res.box(Vector3(0.08, 0.09, 0.02)), tk, top.darkened(0.04), Vector3(x, 0.465, z - 0.004), Vector3(0.12, sx * 0.35, 0))
		_p(torso, Res.box(Vector3(0.086, 0.028, 0.026)), tk, top.darkened(0.1), Vector3(x, 0.51, z - 0.008), Vector3(0.12, sx * 0.35, 0))
	for fa in [forearm_l, forearm_r]:
		if not k.rolled:
			_p(fa, BodyMesh.loft([_at(FOREARM, -0.165, 0.007), _at(FOREARM, -0.2, 0.007)], 10), tk, top.darkened(0.06))
	if medic or rng.randf() < 0.45:
		# a canvas pack
		_p(torso, Res.box(Vector3(0.26, 0.3, 0.12)), "canvas_l", pouch.lerp(Color(0.3, 0.32, 0.24), 0.3), Vector3(0, 0.36, 0.18))
		_p(torso, Res.box(Vector3(0.25, 0.05, 0.13)), "canvas_l", pouch.darkened(0.12), Vector3(0, 0.525, 0.18), Vector3(-0.08, 0, 0))
		if medic:
			_p(torso, Res.box(Vector3(0.1, 0.1, 0.012)), "plain", Color(0.8, 0.79, 0.74), Vector3(0, 0.38, 0.243))
			_p(torso, Res.box(Vector3(0.07, 0.022, 0.016)), "plain", Color(0.62, 0.1, 0.08), Vector3(0, 0.38, 0.245))
			_p(torso, Res.box(Vector3(0.022, 0.07, 0.016)), "plain", Color(0.62, 0.1, 0.08), Vector3(0, 0.38, 0.245))
	# the belt over the jacket, a canteen and a pouch on it
	_p(hips, BodyMesh.loft([_rg(0.032, 0.18, 0.123, 0.13, 2.4), _rg(0.082, 0.178, 0.121, 0.128, 2.4)], 14), "webbing", web)
	_p(hips, Res.box(Vector3(0.06, 0.048, 0.018)), "gunmetal", Color(0.35, 0.33, 0.28), Vector3(0, 0.057, -0.127))
	_p(hips, Res.cyl(0.045, 0.045, 0.13, 8), "canvas_l", pouch, Vector3(-0.17, -0.02, 0.1))
	_p(hips, Res.box(Vector3(0.075, 0.09, 0.05)), "canvas_l", pouch, Vector3(0.16, 0.03, 0.09), Vector3(0, 2.2, 0))
	# cargo pockets, and knee pads on some
	for th in [thigh_l, thigh_r]:
		var sx := -1.0 if th == thigh_l else 1.0
		_p(th, Res.box(Vector3(0.04, 0.13, 0.12)), "suit", (k.pants as Color).darkened(0.08), Vector3(sx * 0.09, -0.22, 0.0), Vector3(0, 0, sx * 0.06))
	if rng.randf() < 0.35:
		for sh in [shin_l, shin_r]:
			_p(sh, BodyMesh.plate([_rg(0.07, 0.072, 0.078, 0.07), _rg(0.0, 0.078, 0.086, 0.07), _rg(-0.07, 0.07, 0.078, 0.07)], -PI * 0.84, -PI * 0.16, 8, 0.02), "armor", web)


## Vehicle crew: coveralls under a light vest with a couple of pouches.
func _kit_crew(k: Dictionary) -> void:
	var vest: Color = (k.armor as Color).darkened(0.1)
	_p(torso, BodyMesh.loft([_at(TORSO, 0.2, 0.02, 2.5), _at(TORSO, 0.36, 0.024, 2.5), _at(TORSO, 0.47, 0.022, 2.5), _rg(0.54, 0.18, 0.13, 0.126, 2.5)], 12), "canvas_l", vest)
	for x in [-0.08, 0.08]:
		_p(torso, Res.box(Vector3(0.08, 0.1, 0.04)), "canvas_l", vest.darkened(0.1), Vector3(x, 0.3, _front(_at(TORSO, 0.3, 0.022, 2.5), x) - 0.012))
	_p(hips, BodyMesh.loft([_rg(0.03, 0.176, 0.115, 0.122, 2.4), _rg(0.085, 0.168, 0.109, 0.114, 2.4)], 14), "webbing", k.web)
	_p(thigh_r, Res.box(Vector3(0.05, 0.16, 0.1)), "webbing", k.web, Vector3(0.106, -0.17, 0.01), Vector3(0, 0, 0.05))


## A stretcher bearer: no kit but a satchel.
func _kit_bearer(k: Dictionary) -> void:
	_p(hips, BodyMesh.loft([_rg(0.03, 0.172, 0.112, 0.118, 2.4), _rg(0.075, 0.166, 0.107, 0.112, 2.4)], 12), "webbing", k.web)
	_sash(-0.13, 0.57, 0.15, 0.06, 4, 0.035, 0.012, "canvas_l", k.pouch)
	_p(hips, Res.box(Vector3(0.06, 0.16, 0.2)), "canvas_l", k.pouch, Vector3(0.19, -0.02, -0.02))


## The head and what's on it.
func _head_gear(k: Dictionary, team: int, is_crew: bool, bearer: bool, rng: RandomNumberGenerator) -> void:
	if is_crew:
		_face(k)
		_cvc(team)
		return
	if bearer:
		_face(k)
		_soft_cap(Color(0.8, 0.8, 0.78), true)
		return
	if team == 0:
		var s := rng.randi() % 10
		if s < 2:
			# Snake: hair, a bandana with its long tails, the codec headset
			_face(k)
			_hair(k)
			_bandana([Color(0.09, 0.09, 0.1), Color(0.14, 0.15, 0.16), Color(0.26, 0.28, 0.22)][rng.randi() % 3])
			_headset()
		elif s < 5:
			# a Genome trooper's look: balaclava, goggles down over the eyes
			_face(k, true, Color(0.13, 0.14, 0.14))
			_goggles(Transform3D(Basis.IDENTITY, Vector3(0, 0.14, -0.098)), true)
			_helmet(k, false)
		else:
			_face(k)
			_helmet(k, true)
			_headset()
		return
	var bal: Color = [Color(0.12, 0.12, 0.11), Color(0.24, 0.25, 0.2), Color(0.3, 0.28, 0.24)][rng.randi() % 3]
	match rng.randi() % 9:
		0, 1:
			# balaclava, goggles pushed up on the forehead
			_face(k, true, bal)
			_goggles(Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.198, -0.084)), true)
		2, 3:
			# a beret over the balaclava
			_face(k, true, bal)
			_beret([Color(0.42, 0.09, 0.07), Color(0.12, 0.12, 0.12), Color(0.28, 0.3, 0.22)][rng.randi() % 3])
		4:
			_face(k)
			_ushanka(Color(0.3, 0.26, 0.2) if rng.randf() < 0.5 else Color(0.2, 0.2, 0.2))
			_scarf(k)
		5:
			_face(k)
			_field_cap(k.top if rng.randf() < 0.5 else Color(0.32, 0.33, 0.25))
		6:
			_face(k)
			_watch_cap(Color(0.12, 0.12, 0.12) if rng.randf() < 0.5 else Color(0.3, 0.31, 0.24))
			_scarf(k)
		7:
			_face(k)
			_beret([Color(0.42, 0.09, 0.07), Color(0.12, 0.12, 0.12)][rng.randi() % 2])
			_scarf(k)
		_:
			_face(k)
			_shemagh([Color(0.52, 0.47, 0.38), Color(0.28, 0.28, 0.26), Color(0.4, 0.17, 0.14)][rng.randi() % 3])


## The face: a square jaw, cheekbones, a heavy brow over narrowed eyes. Under
## a balaclava only the eyes show, through the slot in the wool.
func _face(k: Dictionary, mask := false, mask_col := Color.BLACK) -> void:
	var skin: Color = k.skin
	var kind := "suit" if mask else "skin"
	var col := mask_col if mask else skin
	_p(head, BodyMesh.loft([_rg(-0.05, 0.054, 0.05, 0.054, 2.0, 0.0, 0.008), _rg(0.05, 0.05, 0.048, 0.05, 2.0, 0.0, 0.008)], 10), kind, col)
	_p(head, BodyMesh.loft(_rings(HEAD, 0.0, 2.15), 14), kind, col)
	_p(head, Res.box(Vector3(0.024, 0.05, 0.03)), kind, col, Vector3(0, 0.11, -0.097), Vector3(-0.32, 0, 0))
	for sx in [-1.0, 1.0]:
		_p(head, Res.sphere(0.028, 6), kind, col, Vector3(sx * 0.086, 0.122, 0.012), Vector3.ZERO, Vector3(0.5, 1.0, 0.8))
	if mask:
		_p(head, BodyMesh.plate([_at(HEAD, 0.122, 0.005, 2.15), _at(HEAD, 0.153, 0.005, 2.15)], -PI * 0.78, -PI * 0.22, 8, 0.012), "skin", skin)
	var brow := mask_col.lightened(0.04) if mask else skin.darkened(0.12)
	for sx in [-1.0, 1.0]:
		# the brow juts over the eyes and draws down to the nose: the squint
		_p(head, Res.box(Vector3(0.062, 0.02, 0.026)), kind, brow, Vector3(sx * 0.036, 0.156, -0.089), Vector3(0, -sx * 0.32, sx * 0.14))
		_p(head, Res.box(Vector3(0.03, 0.011, 0.01)), "plain_dark", Color(0.05, 0.045, 0.04), Vector3(sx * 0.036, 0.137, -0.087), Vector3(0, -sx * 0.32, -sx * 0.08))
	if not mask:
		_p(head, Res.box(Vector3(0.036, 0.006, 0.006)), "plain_dark", skin.darkened(0.45), Vector3(0, 0.062, -0.092))


func _hair(k: Dictionary) -> void:
	_p(head, BodyMesh.loft([_at(HEAD, 0.165, 0.008, 2.1), _at(HEAD, 0.19, 0.01, 2.1), _at(HEAD, 0.222, 0.011, 2.1), _at(HEAD, 0.243, 0.01, 2.1), _rg(0.258, 0.022, 0.022, 0.032, 2.0, 0.0, 0.012)], 14),
		"suit", k.hair)
	_p(head, BodyMesh.plate([_at(HEAD, 0.07, 0.006, 2.1), _at(HEAD, 0.11, 0.008, 2.1), _at(HEAD, 0.17, 0.008, 2.1)], PI * 0.12, PI * 0.88, 10, 0.014), "suit", k.hair)


## Snake's bandana: a band round the forehead knotted at the back, and the
## tails hanging from the knot (on their own joint, so they can fly).
func _bandana(c: Color) -> void:
	_p(head, BodyMesh.loft([_at(HEAD, 0.158, 0.011, 2.1), _at(HEAD, 0.2, 0.011, 2.1)], 14), "suit", c)
	tails = _joint(head, Vector3(0, 0.18, 0.11))
	_p(tails, Res.box(Vector3(0.045, 0.04, 0.03)), "suit", c)
	for sx in [-1.0, 1.0]:
		_p(tails, Res.box(Vector3(0.034, 0.3, 0.007)), "suit", c, Vector3(sx * 0.018, -0.14, 0.02), Vector3(0, sx * 0.15, sx * 0.1))


## The codec: an earpiece over the left ear and a boom mike to the mouth.
func _headset() -> void:
	var d := Color(0.09, 0.09, 0.09)
	_p(head, Res.cyl(0.034, 0.034, 0.03, 10), "plain_dark", d, Vector3(-0.094, 0.122, 0.012), Vector3(0, 0, PI / 2))
	_p(head, Res.box(Vector3(0.008, 0.008, 0.1)), "plain_dark", d, Vector3(-0.083, 0.088, -0.045), Vector3(0.38, 0.42, 0))
	_p(head, Res.sphere(0.012, 6), "plain_dark", d, Vector3(-0.05, 0.068, -0.092))


## Goggles: two lenses in a rubber frame on a strap round the head (or the
## helmet); `xf` puts the bridge between the lenses.
func _goggles(xf: Transform3D, strap: bool) -> void:
	var d := Color(0.08, 0.08, 0.08)
	var b := xf.basis
	for sx in [-1.0, 1.0]:
		var c := xf * Vector3(sx * 0.04, 0, -0.004)
		var mi := _p(head, Res.cyl(0.033, 0.033, 0.03, 10), "rubber", d, c)
		mi.basis = b * Basis(Vector3.RIGHT, PI / 2)
		var lens := _p(head, Res.cyl(0.026, 0.026, 0.008, 10), "glass", Color(0.22, 0.3, 0.33), xf * Vector3(sx * 0.04, 0, -0.018))
		lens.basis = b * Basis(Vector3.RIGHT, PI / 2)
	var br := _p(head, Res.box(Vector3(0.022, 0.016, 0.02)), "rubber", d, xf * Vector3(0, 0.0, 0.0))
	br.basis = b
	if strap:
		var y := xf.origin.y
		var t := b.get_euler().x
		var piv := Vector3(0, y, 0)
		var rb := Basis(Vector3.RIGHT, t)
		_p(head, BodyMesh.loft([_at(HEAD, y - 0.012, 0.008, 2.15), _at(HEAD, y + 0.012, 0.008, 2.15)], 14), "webbing", d.lightened(0.05), piv - rb * piv, Vector3(t, 0, 0))


## A combat helmet, sat well down, its rim a lip round the edge, a band
## round it; goggles on the front (or he's wearing them).
func _helmet(k: Dictionary, goggles_up: bool) -> void:
	var hc: Color = (k.armor as Color).lightened(0.08)
	var tilt := 0.16
	var piv := Vector3(0, 0.2, 0)
	var b := Basis(Vector3.RIGHT, tilt)
	var off := piv - b * piv
	var rot := Vector3(tilt, 0, 0)
	_p(head, BodyMesh.loft([_rg(0.118, 0.116, 0.126, 0.134, 2.2, 0, 0.008), _rg(0.135, 0.112, 0.122, 0.13, 2.2, 0, 0.008), _rg(0.19, 0.106, 0.114, 0.122, 2.1, 0, 0.008),
		_rg(0.24, 0.088, 0.094, 0.102, 2.0, 0, 0.01), _rg(0.272, 0.055, 0.058, 0.064, 2.0, 0, 0.01), _rg(0.287, 0.02, 0.02, 0.024, 2.0, 0, 0.01)], 16), "armor", hc, off, rot)
	_p(head, BodyMesh.loft([_rg(0.112, 0.121, 0.131, 0.139, 2.2, 0, 0.008), _rg(0.13, 0.12, 0.13, 0.138, 2.2, 0, 0.008)], 16), "armor", hc.darkened(0.2), off, rot)
	_p(head, BodyMesh.loft([_rg(0.168, 0.112, 0.12, 0.128, 2.1, 0, 0.008), _rg(0.19, 0.109, 0.117, 0.125, 2.1, 0, 0.008)], 16), "webbing", k.web, off, rot)
	if goggles_up:
		_goggles(Transform3D(b, off + b * Vector3(0, 0.2, -0.112)), false)
	for sx in [-1.0, 1.0]:
		_p(head, Res.box(Vector3(0.012, 0.024, 0.11)), "armor", hc.darkened(0.12), off + b * Vector3(sx * 0.113, 0.165, 0.01), rot)


## A tank crewman's padded helmet (a CVC): a soft dome, thick ear cups for the
## intercom, a padded brow roll, the boom mike in front of his mouth.
func _cvc(team: int) -> void:
	var c := Color(0.27, 0.28, 0.24) if team == 0 else Color(0.14, 0.14, 0.13)
	_p(head, BodyMesh.loft([_rg(0.105, 0.102, 0.112, 0.124, 2.1, 0, 0.01), _rg(0.18, 0.104, 0.112, 0.124, 2.1, 0, 0.01), _rg(0.24, 0.084, 0.09, 0.102, 2.0, 0, 0.01),
		_rg(0.272, 0.046, 0.05, 0.056, 2.0, 0, 0.01)], 14), "suit", c)
	_p(head, BodyMesh.loft([_rg(0.15, 0.108, 0.118, 0.128, 2.1, 0, 0.01), _rg(0.18, 0.108, 0.118, 0.128, 2.1, 0, 0.01)], 14), "suit", c.darkened(0.25))
	for sx in [-1.0, 1.0]:
		_p(head, Res.cyl(0.055, 0.055, 0.05, 10), "suit", c.darkened(0.15), Vector3(sx * 0.105, 0.115, 0.01), Vector3(0, 0, PI / 2))
	_p(head, Res.box(Vector3(0.01, 0.01, 0.11)), "plain_dark", Color(0.09, 0.09, 0.09), Vector3(-0.098, 0.075, -0.06), Vector3(0.3, 0.5, 0))
	_p(head, Res.sphere(0.014, 6), "plain_dark", Color(0.09, 0.09, 0.09), Vector3(-0.05, 0.066, -0.095))


## A beret pulled down to the right over the brow, a leather band, a badge.
func _beret(c: Color) -> void:
	var piv := Vector3(0, 0.17, 0)
	var b := Basis(Vector3.BACK, -0.2)
	_p(head, BodyMesh.loft([_at(HEAD, 0.168, 0.01, 2.1), _rg(0.2, 0.11, 0.116, 0.118, 2.0, 0.006, 0.01), _rg(0.235, 0.12, 0.124, 0.126, 2.0, 0.016, 0.012),
		_rg(0.258, 0.096, 0.1, 0.104, 2.0, 0.022, 0.014), _rg(0.269, 0.045, 0.05, 0.052, 2.0, 0.024, 0.014)], 14), "suit", c, piv - b * piv, b.get_euler())
	_p(head, BodyMesh.loft([_at(HEAD, 0.162, 0.012, 2.1), _at(HEAD, 0.18, 0.012, 2.1)], 14), "boot", Color(0.12, 0.1, 0.08))
	_p(head, Res.box(Vector3(0.026, 0.03, 0.01)), "gunmetal", Color(0.6, 0.5, 0.25), Vector3(-0.045, 0.2, -0.098), Vector3(0, 0.45, 0))


## A Soviet field cap: a squared crown, a short brim.
func _field_cap(c: Color) -> void:
	_p(head, BodyMesh.loft([_at(HEAD, 0.158, 0.01, 2.3), _rg(0.215, 0.096, 0.104, 0.108, 2.6, 0, 0.006), _rg(0.258, 0.094, 0.1, 0.104, 2.8, 0, 0.006)], 14), "suit", c)
	_p(head, Res.cyl(0.07, 0.07, 0.012, 12), "suit", c.darkened(0.2), Vector3(0, 0.165, -0.1), Vector3(-0.14, 0, 0), Vector3(1.25, 1.0, 0.75))


## A watch cap, rolled up at the edge.
func _watch_cap(c: Color) -> void:
	_p(head, BodyMesh.loft([_at(HEAD, 0.15, 0.012, 2.1), _at(HEAD, 0.19, 0.012, 2.1), _at(HEAD, 0.222, 0.012, 2.1), _rg(0.25, 0.05, 0.05, 0.06, 2.0, 0, 0.012),
		_rg(0.262, 0.02, 0.02, 0.026, 2.0, 0, 0.012)], 14), "suit", c)
	_p(head, BodyMesh.loft([_at(HEAD, 0.142, 0.02, 2.1), _at(HEAD, 0.172, 0.02, 2.1)], 14), "suit", c.darkened(0.12))


## A fur hat with its ear flaps tied up.
func _ushanka(c: Color) -> void:
	_p(head, BodyMesh.loft([_at(HEAD, 0.17, 0.016, 2.2), _rg(0.24, 0.098, 0.104, 0.11, 2.4, 0, 0.01), _rg(0.282, 0.092, 0.098, 0.104, 2.6, 0, 0.01)], 14), "suit", c.darkened(0.25))
	_p(head, BodyMesh.loft([_at(HEAD, 0.14, 0.036, 2.2), _at(HEAD, 0.2, 0.04, 2.2), _rg(0.215, 0.112, 0.124, 0.132, 2.2, 0, 0.006)], 14), "suit", c)
	for sx in [-1.0, 1.0]:
		_p(head, Res.box(Vector3(0.026, 0.075, 0.1)), "suit", c, Vector3(sx * 0.108, 0.24, 0.012), Vector3(0, 0, -sx * 0.18))


## A shemagh wrapped over the head and across the face below the eyes.
func _shemagh(c: Color) -> void:
	_p(head, BodyMesh.loft([_at(HEAD, 0.15, 0.014, 2.1), _at(HEAD, 0.19, 0.016, 2.1), _at(HEAD, 0.222, 0.016, 2.1), _rg(0.258, 0.05, 0.05, 0.062, 2.0, 0, 0.012)], 14), "fabric", c)
	_p(head, BodyMesh.loft([_at(HEAD, -0.02, 0.022, 2.1), _at(HEAD, 0.035, 0.018, 2.1), _at(HEAD, 0.07, 0.012, 2.1), _at(HEAD, 0.11, 0.01, 2.1)], 14), "fabric", c.darkened(0.06))
	_p(head, Res.box(Vector3(0.1, 0.2, 0.03)), "fabric", c.darkened(0.08), Vector3(0, 0.07, 0.12), Vector3(-0.2, 0, 0))


## A scarf round the neck.
func _scarf(k: Dictionary) -> void:
	_p(head, BodyMesh.loft([_rg(-0.04, 0.085, 0.08, 0.085), _rg(0.02, 0.08, 0.075, 0.08), _rg(0.04, 0.07, 0.068, 0.072)], 12), "fabric",
		[Color(0.52, 0.47, 0.38), Color(0.28, 0.28, 0.26), Color(0.4, 0.17, 0.14), Color(0.34, 0.35, 0.27)][int(seedf * 10.0) % 4])


## A soft cap, with a red cross on it for a bearer.
func _soft_cap(c: Color, cross: bool) -> void:
	_p(head, BodyMesh.loft([_at(HEAD, 0.158, 0.012, 2.2), _at(HEAD, 0.205, 0.012, 2.2), _rg(0.24, 0.086, 0.09, 0.1, 2.3, 0, 0.01)], 14), "suit", c)
	_p(head, Res.cyl(0.07, 0.07, 0.012, 12), "suit", c.darkened(0.1), Vector3(0, 0.162, -0.1), Vector3(-0.14, 0, 0), Vector3(1.2, 1.0, 0.75))
	if cross:
		_p(head, Res.box(Vector3(0.07, 0.02, 0.012)), "plain", Color(0.62, 0.1, 0.08), Vector3(0, 0.21, -0.098), Vector3(-0.4, 0, 0))
		_p(head, Res.box(Vector3(0.02, 0.06, 0.012)), "plain", Color(0.62, 0.1, 0.08), Vector3(0, 0.21, -0.098), Vector3(-0.4, 0, 0))


## An M4A1 (or, short, a Mk18 CQB carbine) at its real size: lower receiver and
## magwell, curved STANAG magazine, flat-top upper with a rail, ACOG (or a red
## dot on the short one), quad-rail handguard with a vertical grip, A-frame
## front sight, barrel and flash hider, buffer tube and collapsible stock.
## Gun space: forward -z, the bore 2 cm above the receiver's centreline.
func _m4(g: Node3D, poly: Color, furn: Color, steel: Color, short: bool) -> void:
	var hg := 0.16 if short else 0.22  # handguard length
	var bz := -0.4 if short else -0.52  # muzzle
	Res.mi(g, Res.box(Vector3(0.032, 0.07, 0.2)), Res.mat(poly), Vector3(0, -0.02, -0.03), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.036, 0.06, 0.075)), Res.mat(poly), Vector3(0, -0.075, -0.075), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.026, 0.12, 0.066)), Res.mat(poly), Vector3(0, -0.165, -0.082), Vector3(0.12, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.026, 0.08, 0.064)), Res.mat(poly), Vector3(0, -0.262, -0.101), Vector3(0.3, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.034, 0.055, 0.22)), Res.mat(poly), Vector3(0, 0.04, -0.04), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.022, 0.012, 0.2)), Res.mat(steel), Vector3(0, 0.073, -0.04), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.04, 0.012, 0.03)), Res.mat(steel), Vector3(0, 0.072, 0.08), Vector3.ZERO, false)
	if short:
		# red dot: a hooded box with its window
		Res.mi(g, Res.box(Vector3(0.036, 0.045, 0.07)), Res.mat(poly), Vector3(0, 0.1, -0.03), Vector3.ZERO, false)
	else:
		# ACOG: body, objective bell and eyepiece on its mount
		Res.mi(g, Res.box(Vector3(0.02, 0.025, 0.05)), Res.mat(poly), Vector3(0, 0.088, -0.04), Vector3.ZERO, false)
		Res.mi(g, Res.box(Vector3(0.034, 0.038, 0.12)), Res.mat(poly), Vector3(0, 0.115, -0.04), Vector3.ZERO, false)
		Res.mi(g, Res.cyl(0.024, 0.024, 0.03, 10), Res.mat(poly), Vector3(0, 0.115, -0.115), Vector3(PI / 2, 0, 0), false)
		Res.mi(g, Res.cyl(0.018, 0.018, 0.03, 10), Res.mat(poly), Vector3(0, 0.115, 0.03), Vector3(PI / 2, 0, 0), false)
	# handguard: the tube and its four rails, a vertical grip under it
	var hz := -0.15 - hg * 0.5
	Res.mi(g, Res.box(Vector3(0.046, 0.046, hg)), Res.mat(furn), Vector3(0, 0.02, hz), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.02, 0.012, hg)), Res.mat(steel), Vector3(0, 0.049, hz), Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		Res.mi(g, Res.box(Vector3(0.012, 0.02, hg * 0.8)), Res.mat(steel), Vector3(sx * 0.028, 0.02, hz), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.026, 0.075, 0.03)), Res.mat(furn), Vector3(0, -0.04, fore_z), Vector3(0.1, 0, 0), false)
	if not short:
		Res.mi(g, Res.box(Vector3(0.012, 0.055, 0.02)), Res.mat(poly), Vector3(0, 0.06, -0.39), Vector3.ZERO, false)
	Res.mi(g, Res.cyl(0.009, 0.009, absf(bz) - 0.15 - hg, 6), Res.mat(steel), Vector3(0, 0.02, (bz + 0.02 - 0.15 - hg) * 0.5), Vector3(PI / 2, 0, 0), false)
	Res.mi(g, Res.cyl(0.012, 0.012, 0.05, 8), Res.mat(steel), Vector3(0, 0.02, bz + 0.025), Vector3(PI / 2, 0, 0), false)
	# pistol grip and trigger guard, buffer tube and stock
	Res.mi(g, Res.box(Vector3(0.03, 0.09, 0.04)), Res.mat(furn), Vector3(0, -0.085, 0.05), Vector3(-0.35, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.01, 0.008, 0.05)), Res.mat(poly), Vector3(0, -0.065, 0.0), Vector3.ZERO, false)
	Res.mi(g, Res.cyl(0.015, 0.015, 0.16, 8), Res.mat(poly), Vector3(0, 0.03, 0.15), Vector3(PI / 2, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.04, 0.07, 0.12)), Res.mat(furn), Vector3(0, 0.0, 0.24), Vector3(0.06, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.042, 0.11, 0.02)), Res.mat(poly), Vector3(0, -0.01, 0.305), Vector3.ZERO, false)


## An AKM: stamped receiver with its ribbed dust cover and rear sight block,
## wooden handguards round the barrel and gas tube, front sight block and
## slant brake, a curved 30-round steel magazine, wooden grip and stock.
func _akm(g: Node3D, steel_dark: Color, wood: Color, steel: Color) -> void:
	Res.mi(g, Res.box(Vector3(0.04, 0.075, 0.25)), Res.mat(steel_dark), Vector3(0, 0.0, -0.02), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.042, 0.022, 0.23)), Res.mat(steel_dark), Vector3(0, 0.045, -0.01), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.03, 0.025, 0.05)), Res.mat(steel_dark), Vector3(0, 0.048, -0.16), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.04, 0.03, 0.17)), Res.mat(wood), Vector3(0, 0.045, -0.25), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.046, 0.045, 0.18)), Res.mat(wood), Vector3(0, -0.005, -0.25), Vector3.ZERO, false)
	Res.mi(g, Res.cyl(0.009, 0.009, 0.2, 6), Res.mat(steel), Vector3(0, 0.0, -0.44), Vector3(PI / 2, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.022, 0.05, 0.03)), Res.mat(steel_dark), Vector3(0, 0.025, -0.48), Vector3.ZERO, false)
	Res.mi(g, Res.cyl(0.013, 0.013, 0.045, 8), Res.mat(steel_dark), Vector3(0, 0.0, -0.543), Vector3(PI / 2, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.03, 0.09, 0.07)), Res.mat(steel_dark), Vector3(0, -0.08, -0.09), Vector3(0.15, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.03, 0.09, 0.068)), Res.mat(steel_dark), Vector3(0, -0.16, -0.118), Vector3(0.42, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.03, 0.06, 0.065)), Res.mat(steel_dark), Vector3(0, -0.22, -0.155), Vector3(0.68, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.03, 0.09, 0.04)), Res.mat(wood), Vector3(0, -0.075, 0.06), Vector3(-0.3, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.01, 0.008, 0.06)), Res.mat(steel_dark), Vector3(0, -0.045, 0.0), Vector3.ZERO, false)
	Res.mi(g, Res.box(Vector3(0.04, 0.085, 0.24)), Res.mat(wood), Vector3(0, -0.04, 0.21), Vector3(0.15, 0, 0), false)
	Res.mi(g, Res.box(Vector3(0.042, 0.115, 0.016)), Res.mat(steel_dark), Vector3(0, -0.075, 0.33), Vector3.ZERO, false)


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
	var revived := life == Soldier.Life.ALIVE and _last_life != Soldier.Life.ALIVE
	_alive_pose = life == 0
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
	# one stride (two steps) covers more ground the faster he goes, and the
	# thighs sweep back as fast as the ground goes by under the planted foot,
	# so the feet don't skate
	var stride := 0.95 + 0.37 * speed
	if posture == Soldier.Post.CROUCH:
		stride = 0.8 + 0.3 * speed
	elif posture == Soldier.Post.PRONE:
		stride = 1.6
	gait_amp = clampf(stride / 5.2, 0.16, 0.62)
	phase += dt * TAU * speed / stride * (-1.0 if backwards else 1.0)
	_back = backwards
	var sp := sin(phase)
	var cp := cos(phase)
	# defaults: standing, rifle at low ready
	t_root_p = Vector3.ZERO
	t_root_r = Vector3.ZERO
	t_hips_p = Vector3(0, H0, 0)
	t_hips_r = Vector3.ZERO
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
	weapon_slung = false
	var show_gun := has_gun
	var show_pistol := false
	var show_nade := false
	var show_stretcher := false
	var k := 12.0

	if life != 0 or act in [Soldier.Act.THROW, Soldier.Act.BUILD, Soldier.Act.HEAL, Soldier.Act.DRAG, Soldier.Act.CARRY,
			Soldier.Act.CRAWL, Soldier.Act.CLIMB, Soldier.Act.DIVE, Soldier.Act.FLINCH, Soldier.Act.PICKUP, Soldier.Act.LIMP,
			Soldier.Act.VAULT, Soldier.Act.DAZED, Soldier.Act.MELEE, Soldier.Act.HANDSUP, Soldier.Act.LAUNCH,
			Soldier.Act.IDLE_CHAT, Soldier.Act.IDLE_LAUGH, Soldier.Act.IDLE_SMOKE, Soldier.Act.IDLE_SIT, Soldier.Act.IDLE_STRETCH, Soldier.Act.IDLE_LOOK,
			Soldier.Act.SMOTHER, Soldier.Act.COOK, Soldier.Act.WINDED]:
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
				t_root_r = Vector3(0.55, 0, 0)
				t_root_p = Vector3(0, -0.15, -0.3)
				t_hips_p = Vector3(0, 0.63, 0)
				t_thl = Vector3(0.8, 0, 0)
				t_thr = Vector3(1.1, 0, 0)
				t_shr = Vector3(-2.4, 0, 0)
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
				show_nade = a < 0.6
				k = 16.0
			Soldier.Act.COOK:
				# pin out, spoon gone, counting: the grenade held in close, the
				# rifle hanging on its sling
				if posture == Soldier.Post.CROUCH:
					_kneel()
				t_arr = Vector3(0.75, 0, 0.35)
				t_far = Vector3(1.75, 0, 0)
				t_arl = Vector3(0.55, 0, -0.35)
				t_fal = Vector3(1.4, 0, 0)
				t_gun_p = Vector3(0.12, 0.05, -0.2)
				t_gun_r = Vector3(1.25, 0, 0.3)
				t_head = Vector3(-0.15, 0, 0)
				show_nade = true
				k = 12.0
			Soldier.Act.WINDED:
				# blown: bent over, hands on his knees, his back heaving; the rifle
				# hangs from its sling
				var heave := sin(act_time * 6.5 + seedf) * 0.04
				t_hips_p = Vector3(0, H0 - 0.08, 0.06)
				_bend(H0 - 0.08)
				t_torso = Vector3(-0.85 + heave, 0, 0)
				t_head = Vector3(0.6, 0.1, 0)
				t_arl = Vector3(0.45, 0, 0.12)
				t_fal = Vector3(0.35, 0, 0)
				t_arr = Vector3(0.45, 0, -0.12)
				t_far = Vector3(0.35, 0, 0)
				t_gun_p = Vector3(0.14, 0.1, -0.24)
				t_gun_r = Vector3(1.3, 0.2, 0.25)
				k = 8.0
			Soldier.Act.KICK:
				# the right foot swings through it, leaning back for the kick
				var ka := clampf(act_time / 0.3, 0.0, 1.0)
				t_thr = Vector3(-0.45 + 1.75 * ka, 0, 0.04)
				t_shr = Vector3(-1.3 * (1.0 - ka) - 0.1, 0, 0)
				t_thl = Vector3(0.1, 0, -0.04)
				t_shl = Vector3(-0.15, 0, 0)
				t_hips_p = Vector3(0, H0 - 0.05, 0.05)
				t_torso = Vector3(0.22 * ka, 0, 0)
				k = 22.0
			Soldier.Act.SMOTHER:
				# face down on it: arms and knees drawn in round it, the body over it
				_prone()
				t_root_p.y = 0.24
				t_arl = Vector3(1.0, 0, 0.75)
				t_fal = Vector3(1.9, 0, 0)
				t_arr = Vector3(1.0, 0, -0.75)
				t_far = Vector3(1.9, 0, 0)
				t_head = Vector3(0.15, 0.3, 0)
				t_thl = Vector3(0.55, 0, -0.15)
				t_shl = Vector3(-1.0, 0, 0)
				t_thr = Vector3(0.6, 0, 0.15)
				t_shr = Vector3(-1.1, 0, 0)
				show_gun = false
				k = 14.0
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
				_sling()
				_kneel()
				t_torso = Vector3(-0.45, 0, 0)
				t_arr = Vector3(1.0 + sin(act_time * 11.0) * 0.8, 0, 0.1)
				t_arl = Vector3(0.9, 0, -0.2)
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
	_launch_grips = false
	if tube:
		# from the back socket to the shoulder and back again, turning as one
		# rigid piece (no per-axis angle blending)
		var shouldered := act == Soldier.Act.LAUNCH and look != "op" and not is_mortar and life == 0
		tube.transform = tube.transform.interpolate_with(SOCK_SHOULDER if shouldered else SOCK_BACK, 0.3 if shouldered else 0.2)
		if shouldered:
			show_gun = false
			_launch_grips = true
			ik_l = true
			ik_r = true
	if tails:
		# the bandana's tails stream out behind him as he runs, and stir when he's still
		var stream := clampf(speed / 5.0, 0.0, 1.0) if life == 0 else 0.0
		var flap := sin(Time.get_ticks_msec() * 0.009 + seedf) * (0.05 + 0.15 * stream)
		t_tails = Vector3(-0.3 - stream * 1.0 + flap, flap * 0.6, 0.0)
	gun.visible = show_gun and not (crew and life == 0)
	pistol.visible = show_pistol
	nade.visible = show_nade and life == 0
	stretcher.visible = show_stretcher
	if life == Soldier.Life.ALIVE:
		motion.apply(self, dt, speed, posture, act)
	_apply(dt, k)
	if skinned:
		skinned.ground_y = global_position.y
		if posture != Soldier.Post.CROUCH: skinned.kneel_weight = 0.0
		if life == Soldier.Life.ALIVE:
			# A death effect can arrive before its snapshot; an old alive state is not a revival.
			if revived: skinned.revive()
			var captured_walk := not over_wall and (posture == Soldier.Post.STAND or (posture == Soldier.Post.CROUCH and rifle_driver != null))
			var activity := "mixamo_activities__Smoking" if act == Soldier.Act.IDLE_SMOKE else ("mixamo_activities__Digging" if act == Soldier.Act.BUILD else "")
			var captured_activity := speed < 0.1 and not crew and skinned.native_player != null and not activity.is_empty() and skinned.native_player.has_animation(activity)
			var captured_prone := rifle_driver != null and posture == Soldier.Post.PRONE and speed < 0.1 and act in [Soldier.Act.IDLE, Soldier.Act.SHOOT] and not crew and not over_wall and skinned.native_player.has_animation(rifle_driver.PRONE_CLIP)
			if not captured_prone: _native_prone = false
			if captured_activity:
				_native_locomotion = false
				skinned.pose_activity(dt, activity)
			elif captured_prone:
				if not _native_prone: rifle_driver.prone_time = 0.0
				_native_prone = true
				_native_locomotion = false
				skinned._begin_pose(10) # Captured prone, distinct from procedural posture modes.
				rifle_driver.advance_prone(dt)
			elif captured_walk and act in [Soldier.Act.IDLE, Soldier.Act.WALK, Soldier.Act.RUN, Soldier.Act.SHOOT, Soldier.Act.RELOAD] and not crew and (act != Soldier.Act.RELOAD or rifle_driver != null):
				if rifle_driver != null:
					if not _native_locomotion: rifle_driver.reset()
					_native_locomotion = true
					skinned._begin_pose(2)
					var local_velocity := Vector3.FORWARD.rotated(Vector3.UP, move_yaw) * speed
					var reload_progress := -1.0
					if act == Soldier.Act.RELOAD:
						var seconds: float = Defs.WEAPONS["rifle"].reload
						reload_progress = act_time / seconds
					elif rifle_driver.action == "reloading":
						rifle_driver.action = ""
					rifle_driver.advance(dt, local_velocity, posture == Soldier.Post.CROUCH, true, reload_progress)
				else:
					skinned.pose(dt, speed)
			else:
				_native_locomotion = false
				skinned.pose_procedural(self, dt, posture)
				if posture == Soldier.Post.CROUCH:
					skinned.ground_kneel(dt, speed < 0.1, crew)
				elif posture in [Soldier.Post.LEAN_L, Soldier.Post.LEAN_R] and not crew:
					skinned.ground_cover(dt, speed < 0.1)
				if rifle_driver != null:
					rifle_driver.action = ""
					if posture == Soldier.Post.CROUCH and act == Soldier.Act.RELOAD and not crew:
						rifle_driver.overlay_reload(act_time / float(Defs.WEAPONS["rifle"].reload))
		elif not skinned.dead:
			_native_prone = false
			# The replicated death effect supplies the impulse and world collision layers.
			skinned.pose_procedural(self, dt, posture)
		if life == Soldier.Life.ALIVE: skinned.capture_motion(dt)


func _posture_pose(posture: int, act: int, moving: bool, sp: float, cp: float, speed: float, lean_shoot: bool) -> void:
	var aiming := act == Soldier.Act.SHOOT or act == Soldier.Act.LAUNCH
	if aiming:
		# shouldered, cheek on the stock
		t_gun_p = Vector3(0.13, 0.47, -0.18)
		t_gun_r = Vector3(0.02, 0.0, 0.0)
		t_head = Vector3(-0.14, 0.12, 0.1)
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
				# bent at the waist and the knees, weapon up, short quick steps
				# - or, dashing for cover under fire, a low sprint
				var rush := speed > 2.3
				t_hips_p = Vector3(0, 0.84 if rush else 0.8, 0.03)
				t_torso = Vector3(-0.5 if rush else -0.3, 0, 0)
				if not aiming:
					# compressed ready: weapon high, muzzle just below the eyeline
					t_gun_p = Vector3(0.1, 0.4, -0.28)
					t_gun_r = Vector3(0.1 if rush else -0.15, 0.0, 0.0)
				_walk(sp, cp, gait_amp * (1.05 if rush else 0.95), 0.28 if rush else 0.3, 0.5 if rush else 0.75)
				_strafe()
			else:
				_crouch_still(act, lean_shoot)
		Soldier.Post.PRONE:
			_prone()
			if moving or act == Soldier.Act.CRAWL:
				_crawl(sp, cp)
			elif over_wall and cover_h > 0.0:
				_prone_over(cover_h)
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
				_walk(sp, cp, gait_amp)
				_strafe()
		_:
			if over_wall and not moving:
				_stand_over(cover_h if cover_h > 0.0 else 1.05, act == Soldier.Act.SHOOT and lean_shoot)
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
				# walking, jogging with the weapon at the ready, or sprinting
				# with it across the chest
				var run := speed > 4.1
				var jog := speed > 2.6
				_walk(sp, cp, gait_amp, 0.0, 0.18 if run else (0.14 if jog else 0.1))
				if run:
					t_torso = Vector3(-0.28, t_torso.y, 0)
					if not aiming:
						# port arms, bouncing with the stride
						t_gun_p = Vector3(0.0, 0.34 + absf(sp) * 0.03, -0.24)
						t_gun_r = Vector3(0.35, 0.75, 0.35 + cp * 0.06)
				elif jog:
					t_torso.x = -0.12
					if not aiming:
						t_gun_p = Vector3(0.1, 0.38 + absf(sp) * 0.02, -0.28)
						t_gun_r = Vector3(-0.2, 0.0, 0.0)
				_strafe()


## A stride: each thigh swings about `base` (forward +); the knee folds as
## the leg comes through and is all but straight while the foot is planted
## (a little bent - `knee` - for a soldier's soft-kneed walk or a crouch).
## Shared keyed poses separate contact, passing and recovery within each step.
func _walk(sp: float, _cp: float, amp: float, base := 0.0, knee := 0.1) -> void:
	var running := clampf((amp - 0.38) / 0.24, 0.0, 1.0)
	var left := HumanoidGait.leg(phase, running)
	var right := HumanoidGait.leg(phase + PI, running)
	t_thl = Vector3(base + left.x * amp, 0, -0.03)
	t_thr = Vector3(base + right.x * amp, 0, 0.03)
	var lift := 0.45 + amp * 1.6
	t_shl = Vector3(-knee - left.y * lift, 0, 0)
	t_shr = Vector3(-knee - right.y * lift, 0, 0)
	t_torso.y += sp * 0.07 * amp
	t_hips_p.y = t_hips_p.y - absf(sp) * 0.05 * amp


## Moving one way and facing another (walking while he fires, backing off,
## edging along a wall): the hips and legs turn towards where he's going - up
## to about 60 degrees - and the upper body turns back to keep the weapon on
## the target.
func _strafe() -> void:
	var a := move_yaw
	if _back:
		a -= signf(a) * PI  # backing away: the hips turn towards the way he's backing
	var hy := clampf(a, -1.05, 1.05)
	t_hips_r = Vector3(0, hy, 0)
	t_torso.y -= hy


## Rifle slung across the back, both hands free.
func _sling() -> void:
	weapon_slung = true
	ik_l = false
	ik_r = false
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


## Kneeling or crouched at a halt: behind a barrier he's either up over it
## or down behind it.
func _crouch_still(act: int, lean_shoot: bool) -> void:
	var shooting := act == Soldier.Act.SHOOT and lean_shoot
	if cover_h <= 0.0 or cover_h >= Cover.STAND_MAX:
		_kneel()
	elif blind:
		_blind_fire(cover_h, shooting)
	elif over_wall:
		_kneel_over(cover_h, shooting)
	else:
		_hunker(cover_h, act == Soldier.Act.RELOAD)


## The weapon in the shoulder and level, whatever the lean of the body; the
## cheek on the stock.
func _shoulder(_shooting: bool) -> void:
	t_gun_p = Vector3(0.13, 0.47, -0.18)
	t_gun_r = Vector3(0.02 - t_torso.x, 0.0, 0.0)
	t_head = Vector3(-0.14 - t_torso.x * 0.85, 0.12, 0.1)


## Knees bent so the hips sit at hy with the feet flat under him, one foot
## a little ahead of the other.
func _bend(hy: float) -> void:
	var a := acos(clampf((hy - 0.05) / 0.9, 0.35, 1.0))
	t_thl = Vector3(a + 0.2, 0, -0.06)
	t_shl = Vector3(-2.0 * a - 0.15, 0, 0)
	t_thr = Vector3(a - 0.14, 0, 0.08)
	t_shr = Vector3(-2.0 * a + 0.1, 0, 0)


## Kneeling with the hips at hy: the back knee on the ground, the front foot
## flat - up on the knee, or sat back on the heel.
func _kneel_legs(hy: float) -> void:
	var tr := acos(clampf((hy - 0.12) / 0.45, 0.0, 1.0))
	t_thr = Vector3(tr, 0, 0.05)
	t_shr = Vector3(-PI * 0.5 - tr + 0.02, 0, 0)
	var v := clampf((hy - 0.56) * 1.5, -0.35, 0.1)
	var u := acos(clampf((hy - 0.1) / 0.45 - cos(v), -1.0, 1.0))
	t_thl = Vector3(u, 0, -0.06)
	t_shl = Vector3(v - u, 0, 0)


## Standing behind a chest-high wall or on a trench's fire step: knees bent
## as far as the height asks so the weapon rests on the top, leaning into it.
func _stand_over(h: float, shooting: bool) -> void:
	var hy := clampf(h - 0.47, 0.6, H0)
	t_hips_p = Vector3(0, hy, 0.04)
	_bend(hy)
	t_torso = Vector3(-0.12, 0, 0)
	_shoulder(shooting)
	t_gun_p.y += clampf(h + 0.05 - (hy + 0.5), 0.0, 0.12)  # a tall one: arms up a little more


## Kneeling behind sandbags or a car: up on the knee for a high one, sat back
## on the heel and bent over it for a low one, the weapon on the top.
func _kneel_over(h: float, shooting: bool) -> void:
	var hy := clampf(h - 0.47, 0.42, 0.7)
	_kneel_legs(hy)
	t_hips_p = Vector3(0, hy, 0.02)
	t_torso = Vector3(-0.06 - clampf((hy + 0.52 - h - 0.05) * 2.4, 0.0, 0.65), 0, 0)
	_shoulder(shooting)


## Down behind it: sat back on his heels, curled forward with his chin down
## and his head below the top, the weapon upright against his chest.
func _hunker(h: float, reloading: bool) -> void:
	var hy := 0.36
	_kneel_legs(hy)
	t_hips_p = Vector3(0, hy, 0.08)
	t_torso = Vector3(-0.55 - clampf((1.12 - h) * 1.2, 0.0, 0.4), 0, 0)
	t_head = Vector3(0.3, 0.1, 0)
	if not reloading:
		t_gun_p = Vector3(0.06, 0.34, -0.2)
		t_gun_r = Vector3(1.25, 0.15, 0.1)


## Firing blind: head down behind the barrier, the weapon held up over the
## top in both hands and pointed roughly at the enemy.
func _blind_fire(h: float, shooting: bool) -> void:
	_hunker(h, true)
	t_torso = Vector3(-0.3, 0, 0)
	t_head = Vector3(0.5, 0.15, 0)
	var y := (h + 0.12 - 0.41 + 0.124) / 0.955  # torso space, through the lean
	t_gun_p = Vector3(0.04, clampf(y, 0.45, 1.0), -0.4)
	t_gun_r = Vector3(0.3, 0.0, 0.0)
	if shooting:
		# held out at arm's length it wanders off the aim between shots
		t_gun_r.y += sin(act_time * 9.0 + seedf) * 0.08


## Up on his elbows behind a low lip so the weapon clears it.
func _prone_over(h: float) -> void:
	var lift := clampf((h - 0.25) * 0.9, 0.0, 0.35)
	t_root_r.x += lift
	t_gun_r.x -= lift
	t_head.x -= lift * 0.8


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
	if crew and life_alive_pose():
		# his own weapon laid by (hidden in pose()), leaning into the gun, both hands on it
		ik_l = true
		ik_r = true
		t_torso.x = minf(t_torso.x, -0.32)
		t_head.x = maxf(t_head.x, 0.22)
	if ik_l or ik_r:
		_solve_hands()
	tumble = Vector3.ZERO
	# last frame's recoil off the joints, so the pose eases from where it was
	if _kick_on != Vector3.ZERO:
		gun.position.z -= _kick_on.x
		gun.rotation.x -= _kick_on.y
		torso.rotation.x -= _kick_on.z
		_kick_on = Vector3.ZERO
	var f := 1.0 - exp(-dt * k)
	# a joint that has reached its pose isn't touched (every set re-transforms
	# its meshes on the render server)
	_mv(root, t_root_p, f)
	_rot(root, t_root_r, f)
	_mv(hips, t_hips_p, f)
	_rot(hips, t_hips_r, f)
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
	if tails:
		_rot(tails, t_tails, f)
	if gun.visible:
		_mv(gun, t_gun_p, f)
		_rot(gun, t_gun_r, f)
	if _kick > 0.02:
		# the shot slams the weapon back into his shoulder and throws the
		# muzzle up, rocking his shoulders back; it settles within a few frames
		_kick_on = Vector3(0.032, 0.075, 0.045) * _kick if gun.visible else Vector3(0.0, 0.0, 0.045 * _kick)
		if crew:
			_kick_on.z *= 0.5
		gun.position.z += _kick_on.x
		gun.rotation.x += _kick_on.y
		torso.rotation.x += _kick_on.z
		_kick *= exp(-dt * 24.0)
	else:
		_kick = 0.0


## A shot just left his weapon (`k`: how hard it kicks; 1 a rifle).
func fire_kick(k: float) -> void:
	if skinned: skinned.fire_kick(k)
	_kick = minf(_kick + k, 1.8)


var _alive_pose := true


## Where the shot leaves the weapon in his hands right now (world space), or
## INF if he isn't visibly holding one.
func muzzle_world() -> Vector3:
	if skinned and not skinned.dead:
		return skinned.weapon.global_transform * Vector3(0, 0.03, 0.6)
	if pistol and pistol.is_visible_in_tree():
		return pistol.global_transform * Vector3(0, 0.0, -0.16)
	if gun and gun.is_visible_in_tree() and look != "op":
		return gun.global_transform * muzzle_local
	return Vector3.INF


func life_alive_pose() -> bool:
	return _alive_pose


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
	if _launch_grips:
		# the launcher's trigger grip and its fore grip
		grip = SOCK_SHOULDER * Vector3(0.0, -0.075, 0.1)
		fore = SOCK_SHOULDER * Vector3(0.0, -0.07, -0.16)
		ik_l_target = Vector3.INF
	if crew and life_alive_pose():
		# the mounted gun's handles, brought into torso space
		var inv := torso.global_transform.affine_inverse()
		grip = inv * crew_r
		fore = inv * crew_l
		ik_l_target = Vector3.INF
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
