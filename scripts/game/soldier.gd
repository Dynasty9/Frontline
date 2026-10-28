class_name Soldier
extends Entity
## A thinking infantryman. The server runs the brain in sim(); clients only
## receive position/posture/action and animate the model.

enum Life {ALIVE, DOWNED, DEAD, SURRENDER, CAPTIVE, HIDDEN}
enum Post {STAND, CROUCH, PRONE, LEAN_L, LEAN_R}
enum Act {IDLE, WALK, RUN, SHOOT, RELOAD, THROW, MELEE, BUILD, HEAL, DRAG, CARRY, CRAWL, DRAGGED, CARRIED, VAULT, DIVE, SLIDE, FLUNG, DAZED, FLINCH, HANDSUP, PICKUP, LIMP, PISTOL, LAUNCH, CLIMB,
	IDLE_CHAT, IDLE_LAUGH, IDLE_SMOKE, IDLE_SIT, IDLE_STRETCH, IDLE_CHECK, IDLE_LOOK, KICK, SMOTHER, COOK, WINDED}
enum Cov {NONE, LOW, LEAN, HIDE}
## Player-facing activity labels: [text, category]. %s = the related entity's name.
const DOING := [
	["", "idle"], ["Moving", "move"], ["Running", "move"], ["Firing", "fight"], ["Suppressed", "stress"],
	["Pinned down", "stress"], ["Reloading", "fight"], ["Throwing a grenade", "fight"], ["In cover", "idle"],
	["Bandaging %s", "medic"], ["Dragging %s to safety", "medic"], ["Stretcher run", "medic"], ["Building", "work"],
	["Manning the %s", "fight"], ["Falling back", "move"], ["Grabbing ammo", "work"], ["Guarding a prisoner", "work"],
	["Bleeding out", "hurt"], ["Crawling for cover", "hurt"], ["Surrendering", "hurt"], ["Prisoner", "hurt"],
	["Limping back", "hurt"], ["In the tunnels", "move"], ["Flying a drone", "fight"], ["Hand to hand!", "fight"],
	["Out of ammo", "stress"], ["Firing pistol", "fight"], ["Being dragged", "hurt"], ["Dazed", "stress"],
	["Firing launcher", "fight"], ["Vaulting", "move"], ["Throwing it back!", "fight"], ["Keeping head down", "stress"],
	["Leaning out to fire", "fight"], ["Diving for cover", "stress"],
	["Chatting with %s", "idle"], ["Having a laugh", "idle"], ["Having a smoke", "idle"], ["Taking a load off", "idle"],
	["Stretching his legs", "idle"], ["Checking his rifle", "idle"], ["Keeping an eye out", "idle"],
	["Firing over cover", "fight"], ["Blind firing", "stress"], ["Moving along the wall", "move"],
	["Throwing himself on a grenade!", "stress"], ["Kicking the grenade away", "fight"], ["Clearing the house", "fight"],
	["Stacking on the door", "fight"], ["Cooking a grenade", "fight"], ["Hitting the dirt", "stress"],
	["Catching his breath", "idle"], ["Holding fire", "fight"],
]
## Downtime chatter: each exchange alternates speakers; %s is the other man's name.
const BANTER := [[
	["%s, you snore like a diesel generator.", "Better than your singing in the shower."],
	["Who made this coffee? It's mud.", "That IS mud. Coffee ran out Tuesday."],
	["Two more weeks and I'm home.", "You said that two months ago, %s."],
	["Nice shooting yesterday, %s. You almost hit the ground.", "At least I hit something. You hit the sergeant's truck."],
	["Bet you a ration bar it rains tonight.", "You already owe me six ration bars."],
	["Hey %s, new haircut?", "It's called a helmet, genius."],
	["Remind me why I signed up?", "The free travel and the fancy hats."],
	["You hear that?", "...No.", "Exactly. Too quiet."],
	["%s, you've been chewing that gum for three days.", "It's for luck. Hasn't failed me yet."],
	["I could murder a cheeseburger right now.", "Keep dreaming. Beans again."],
	["Sarge says we move at dawn.", "Sarge says a lot of things."],
	["When this is over I'm sleeping for a week.", "When this is over you'll still be on watch, %s."],
	["Did you write your mom back?", "Did you write yours? She keeps writing to me."],
	["My boots have more holes than the enemy's plan.", "Your boots have more holes than your stories, %s."],
], [
	["%s, your aim is worse than your cooking.", "My cooking kept you alive all winter!"],
	["Who took my last cigarette?", "The wind, brother. The wind."],
	["When we win, I'm opening a tea shop.", "Who would buy your tea? It tastes like diesel."],
	["My cousin says the trucks come tonight.", "Your cousin said the war would be over last spring."],
	["%s, you run like a goat.", "A goat that's still alive."],
	["This rifle is older than my grandfather.", "And it still shoots straighter than you, %s."],
	["I miss my mother's bread.", "Everyone misses your mother's bread."],
	["They say the foreigners have hot showers.", "Then let's go and borrow one."],
	["Listen...", "What?", "Nothing. Good."],
	["Did you fix the radio, %s?", "I hit it. It works now."],
	["You've been cleaning that rifle all day.", "Unlike yours, I want it to fire."],
	["One day they'll write songs about us.", "Not with your singing, %s."],
]]
const LAUGHS := ["Ha! Fair enough.", "Hah!", "Heh. Got me.", "Ha ha!", "Okay, okay."]
const BORED := [["So quiet...", "I'm so bored.", "Wake me if something happens.", "Anyone got a deck of cards?", "My feet are killing me."],
	["Too quiet.", "Wake me when they come.", "Anyone have tea?", "My back hurts.", "Still nothing."]]

const F_SUPP := 1
const F_PINNED := 2
const F_LOWAMMO := 4
const F_NOAMMO := 8
const F_SHOOTING := 16
const F_MEDIC := 32
const F_LEADER := 64
const F_OVERWALL := 128  # firing over low cover: half-crouched, weapon rested on the wall
const SPEEDS := [3.4, 4.6, 5.3]
const PISTOL := {"name": "Pistol", "dmg": 16.0, "range": 25.0, "interval": 0.45, "burst": Vector2i(1, 2), "acc": 0.35, "mag": 12, "ammo": 9999, "reload": 1.6, "supp": 4.0, "snd": "pistol"}

var utype := "rifleman"
var udef: Dictionary = {}
var wdef: Dictionary = {}
var gun_override: Dictionary = {}
var sname := ""
var sid := 0
var squad: Squad = null
var life: int = Life.ALIVE
var posture: int = Post.STAND
var act: int = Act.IDLE
var flags := 0
var hp_frac := 1.0
var supp_net := 0.0
var ammo_frac := 1.0

var base_hp := 100.0
var times_downed := 0
var mag := 0
var reserve := 0
var frags := 0
var smokes := 0
var rockets := 0
var drones_left := 0
var suppression := 0.0
var bleed := 0.0
var bleed_max := 45.0
var loot := 0

# movement
var path := PackedVector3Array()
var path_i := 0
var door_wait := 0.0  # stopped at a shut door: kicking it in, or opening it
var bt_clear := false  # (breach) clearing a house nobody's known to be in
var bt_nofrag := false  # (breach) going in without a grenade first
var door_kick := false
var door_st: Structure = null
var _door_t := 0.0
var goal := Vector3.ZERO
var goal_kind := ""
var move_mode := 0
var base_y := 0.0
var backwards := false
var hold_pos := Vector3.ZERO
var hold_face := Vector3.FORWARD
var leash := 9.0
var vaulting := false
var slide_t := 0.0
var slide_cd := 0.0
var _sep := Vector3.ZERO
var _last_dir := Vector3.FORWARD

# cover
var cover_type: int = Cov.NONE
var cover_pos := Vector3.ZERO
var at_cover := false
var lean_dir := Vector3.ZERO
var cover_threat := Vector3.FORWARD
var next_cover_eval := 0.0
# the fighting position he's at or going to (see Cover)
var cover_n := Vector3.ZERO  # which way he faces across the barrier (zero: no barrier)
var cover_h := 0.0  # how high the barrier is there (0: ground cover or none)
var cover_mat := -1  # Cover.SOFT / MEDIUM / HARD / FORT, -1 none
var cover_st: Structure = null
var cover_ai := -1
var blind := false  # firing blind over the top, head down
var cov_net := 0  # clients: the cover byte (see cov_code)
var _peek_from := 0.0  # when he came up: a moment to find his target first
var _up_supp := 0.0  # suppression when he came up (drew fire: move along before coming up again)
var _stayed := false  # stayed up a little longer because nobody else was firing
var _watching := false  # up over the top keeping watch: nothing to shoot, nobody shooting at him
var _shifting := false  # moving along the barrier to a new spot
var _stuck_p := Vector3.ZERO
var _stuck_t := 0.0
var _pose_dt := 0.0
var _pose_skip := 0
var view_lod := false
var debug_pose: Array = []  # test gallery: [posture, act, life, view speed] frozen
var riding = null  # the vehicle he's sitting in (untyped: may be freed)
var detached := false  # under a direct order of his own until the squad is given one
# downtime
var calm_t := 0.0
var idle_act := 0
var idle_until := 0.0
var idle_next := 0.0
var chat_with = null  # untyped: the other man may be freed
var _banter: Array = []  # [time, text]
var _laugh_until := 0.0
static var _last_chat := [-99.0, -99.0]  # one new conversation per side every few seconds
var peek_up := false
var peek_t := 0.0

# combat
var target: Entity = null
var forced_target: Entity = null
var cf_until := 0.0  # his own covering-fire task (his fire team is the base of fire)
var cf_pos := Vector3.ZERO
var fteam := 0  # which fire team he's in (0 Alpha, 1 Bravo)
var _sim_prev := Vector3.ZERO
var _supp_t := -99.0  # last near miss: heads stay down a moment after the cracks stop
var _shuffle := false  # stepping aside to make room this tick
var vis_targets: Array = []
var los_ok := false
var los_t := 0.0
var los_ent: Entity = null
var fire_t := 0.0
var burst_left := 0
var reload_t := 0.0
var last_shot_t := -99.0
var grenade_cd := 0.0
var rocket_cd := 0.0
var drone_cd := 4.0
var reveal_t := 0.0
var melee_cd := 0.0
var scav_t := 0.0
var resupply_t := 0.0
var think_t := 0.0
var _path_pending := false
var _path_revision := 0
var scan_n := 0
var say_cd := 0.0
var scream_t := 0.0
var pistol_t := 0.0
var crawl_t := 0.0
var flinch_t := 0.0
var dazed_t := 0.0
var dive_t := 0.0
var dive_dir := Vector3.ZERO
var act_t := 0.0
var act_kind := ""
var act_data: Dictionary = {}
var fling_v := Vector3.ZERO
var _hit_dir := Vector3.ZERO  # the last thing that hit him, for how he falls
var _hit_kind := ""
var flinging := false
var _sector := Vector3.ZERO  # where he watches at a halt (zero: not on a war footing)
var seen_grenades := {}
var heard_drones := {}
var low_ammo_said := false
var out_said := false
var drone_ctrl: Drone = null
var build_snd_t := 0.0
var throw_kind := "frag"
var mortar_rounds := 0
var mortar_cd := 0.0
var hit_dirt_t := 0.0
var _gy := 0.0
var _gy_t := -1.0
# the behaviour tree (see SoldierBrain)
var bt_path := ""  # the leaf that last acted
var bt_cd := {}
var bt_g: Projectile = null  # the grenade he's reacting to
var bt_breach: Array = []  # [house, opening, enemy] he could clear
var bt_house: Structure = null
var bt_door: Array = []  # [wall, centre, outward normal, is a door]
var bt_next_breach := 0.0
var bt_cook_t0 := -1.0
var bt_breach_g: Projectile = null
var bt_wait := 0.0
var task_pos2 := Vector3.ZERO
var bt_reordered := false  # given a new order mid-breach: rejoin rather than go in
var stamina := 1.0  # sprinting, rushing and dragging men wear it down; rest brings it back

# tasks
var task := ""
var task_ent: Entity = null
var task_ent2: Entity = null
var task_phase := 0
var task_t := 0.0
var task_pos := Vector3.ZERO
var is_front := false
var dragged_by: Soldier = null
var doing := 0  # activity code shown to players (see DOING)
var doing_ent := 0  # entity the activity refers to (patient, casualty, weapon)
var _doing_t := 0.0
var rescue_claimed: Soldier = null
var carried_by: Array = []
var stretcher_claimed := false
var downed_t := 0.0
var captor: Soldier = null
var hidden_t := 0.0
var hidden_reason := ""
var hidden_in: Structure = null
var tent_dead := false
var home: Structure = null
var dead_t := 0.0
var mounted: Structure = null
var intel_left := 0
var intel_t := 0.0
var prison_dest: Structure = null

# view
var model: SoldierModel
var ring: MeshInstance3D
var _last_view_pos := Vector3.ZERO
var _view_speed := 0.0
var _vis := true


func ekind() -> String:
	return "soldier"


func _update_doing() -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_update_doing_work()
	if stamp:
		world.detail("_update_doing", stamp)


func _update_doing_work() -> void:
	doing_ent = 0
	var d := 0
	match life:
		Life.DOWNED:
			d = 27 if dragged_by != null or not carried_by.is_empty() else (18 if act == Act.CRAWL else 17)
			if act == Act.PISTOL:
				d = 26
		Life.SURRENDER:
			d = 19
		Life.CAPTIVE:
			d = 20
		Life.HIDDEN:
			d = 22
		Life.DEAD:
			d = 0
		_:
			match task:
				"heal":
					d = 9
				"rescue":
					d = 10
				"stretcher":
					d = 11
				"build":
					d = 12
				"man":
					d = 13
				"retreat":
					d = 14
				"resupply":
					d = 15
				"escort", "captor":
					d = 16
				"limp":
					d = 21
				"tunnel":
					d = 22
				"pilot":
					d = 23
				"grenade_pickup":
					d = 31
				"smother":
					d = 45
				"gkick":
					d = 46
				"breach":
					d = 48 if task_phase <= 1 else 47
			if d in [9, 10, 16]:
				doing_ent = task_ent.eid if task_ent and not task_ent.gone else 0
			elif d == 13:
				doing_ent = mounted.eid if mounted else (task_ent.eid if task_ent and not task_ent.gone else 0)
			if d == 0 or d == 13:
				match act:
					Act.SHOOT:
						if d == 13:
							pass
						elif posture in [Post.LEAN_L, Post.LEAN_R]:
							d = 33
						elif blind:
							d = 43
						elif _over():
							d = 42
						else:
							d = 3
					Act.RELOAD:
						d = 6
					Act.THROW:
						d = 7
					Act.MELEE:
						d = 24
					Act.LAUNCH:
						d = 29
					Act.VAULT, Act.CLIMB:
						d = 30
					Act.DIVE, Act.SLIDE:
						d = 34
					Act.DAZED, Act.FLUNG:
						d = 28
					Act.IDLE_CHAT:
						d = 35
						doing_ent = chat_with.eid if chat_with != null and is_instance_valid(chat_with) else 0
					Act.IDLE_LAUGH, Act.IDLE_SMOKE, Act.IDLE_SIT, Act.IDLE_STRETCH, Act.IDLE_CHECK, Act.IDLE_LOOK:
						d = 36 + (act - Act.IDLE_LAUGH)
					Act.KICK:
						d = 46
					Act.COOK:
						d = 49
					Act.WINDED:
						d = 51
			if d == 0:
				if hit_dirt_t > 0.0 and act != Act.DIVE:
					d = 50
				elif (flags & F_PINNED) != 0:
					d = 5
				elif (flags & F_NOAMMO) != 0:
					d = 25
				elif (flags & F_SUPP) != 0:
					d = 4
				elif goal_kind == "cover" and is_moving() and _shifting:
					d = 44
				elif squad and squad.ambush and _target_valid(target):
					d = 52
				elif act == Act.RUN:
					d = 2
				elif act == Act.WALK:
					d = 1
				elif cover_type == Cov.HIDE:
					d = 32
				elif cover_type != Cov.NONE:
					d = 8
	doing = d


## Activity text for labels ("Bandaging Doyle"), using the replicated code.
func doing_text() -> String:
	if doing <= 0 or doing >= DOING.size():
		return ""
	var t: String = DOING[doing][0]
	if t.contains("%s"):
		var e: Entity = world.entity(doing_ent) if doing_ent != 0 else null
		var nm := "a casualty" if doing != 13 else "gun"
		if e is Soldier:
			nm = (e as Soldier).sname
		elif e is Structure:
			nm = Defs.BUILDINGS[(e as Structure).skind].name if Defs.BUILDINGS.has((e as Structure).skind) else "gun"
		t = t % nm
	return t


func doing_cat() -> String:
	return DOING[doing][1] if doing > 0 and doing < DOING.size() else "idle"


func display_name() -> String:
	return "%s %s" % [udef.get("name", "Soldier"), sname]


func apply_props(d: Dictionary) -> void:
	if d.has("utype"):
		utype = d.utype
	if d.has("team"):
		team = d.team
	if d.has("owner"):
		owner_peer = d.owner
	if d.has("pos"):
		position = d.pos
		net_pos = d.pos
	if d.has("yaw"):
		rotation.y = d.yaw
		net_yaw = d.yaw
	if d.has("name"):
		sname = d.name
	if d.has("squad"):
		sid = d.squad
	if d.has("max_hp"):
		max_hp = d.max_hp
	if d.has("life"):
		life = d.life
	if d.has("posture"):
		posture = d.posture
	if d.has("dpose"):
		debug_pose = d.dpose


func get_props() -> Dictionary:
	return {"utype": utype, "team": team, "owner": owner_peer, "pos": position, "yaw": rotation.y, "name": sname,
		"squad": sid, "max_hp": max_hp, "life": life, "posture": posture}


func _ready() -> void:
	super()
	if world and world.soldier_view and world.entities.get(eid) == self:
		set_process(false)


func on_spawned() -> void:
	udef = Defs.UNITS[utype]
	wdef = Defs.WEAPONS.get(udef.weapon, {})
	if srv:
		var armor := world.rules.has_upgrade(team, "armor")
		base_hp = float(udef.hp) * (1.2 if armor else 1.0)
		max_hp = base_hp
		hp = max_hp
		if not wdef.is_empty():
			mag = int(wdef.mag)
			reserve = int(wdef.ammo) - mag
		frags = int(udef.frags) + (1 if world.rules.has_upgrade(team, "grenades") and not is_bearer() else 0)
		smokes = int(udef.smokes)
		rockets = int(udef.get("rockets", 0))
		mortar_rounds = int(udef.get("mortar", 0))
		drones_left = int(udef.get("drones", 0))
		think_t = world.rng.randf() * 0.3
		hold_pos = position
		hold_face = Defs.dir_of(rotation.y)
	net_pos = position
	net_yaw = rotation.y
	net_init = true
	if world.has_view:
		ring = Res.mi(self, Res.plane(1.25), Res.ring_mat(Defs.TEAM_COLORS[team] if team >= 0 else Color.WHITE), Vector3(0, 0.06, 0), Vector3.ZERO, false)
		ring.visible = false
		_last_view_pos = position


func is_bearer() -> bool:
	return udef.get("bearer", false)


func is_moving() -> bool:
	return _path_pending or path_i < path.size()


func cur_weapon() -> Dictionary:
	return gun_override if not gun_override.is_empty() else wdef


func total_ammo() -> int:
	return mag + reserve


func sight_range() -> float:
	return 75.0 if (mounted and mounted.skind == "watchtower" and task_phase == 2) else 56.0


func say(text: String, force := false) -> void:
	if say_cd > 0.0 and not force:
		return
	say_cd = 2.6
	world.say(self, text)


func _pick(arr: Array) -> String:
	return arr[world.rng.randi() % arr.size()]


# --- geometry helpers ------------------------------------------------------------

func eye_pos() -> Vector3:
	if posture == Post.STAND and mounted and mounted.variant == 1 and mounted.skind in ["mg_nest", "hmg_nest"]:
		return position + Vector3(0, 1.62, 0)  # on the fire step, sighting along the gun
	if _over() and peek_up and not blind:
		return position + cover_n * 0.12 + Vector3(0, cover_h + 0.13, 0)  # just over the top
	match posture:
		Post.CROUCH:
			return position + Vector3(0, 1.25 if (mounted and mounted.skind in ["mg_nest", "hmg_nest"]) else 0.95, 0)
		Post.PRONE:
			return position + Vector3(0, 0.32, 0)
		Post.LEAN_L, Post.LEAN_R:
			return position + lean_dir * 0.75 + Vector3(0, 1.45, 0)
	if life == Life.DOWNED:
		return position + Vector3(0, 0.4, 0)
	return position + Vector3(0, 1.5, 0)


## The eye the soldier would shoot from (peeking over low cover or around a corner).
func scan_eye() -> Vector3:
	if life == Life.DOWNED:
		return position + Vector3(0, 0.4, 0)
	if _over():
		return position + cover_n * 0.12 + Vector3(0, cover_h + 0.13, 0)
	if at_cover and cover_type == Cov.LOW:
		return position + Vector3(0, 1.5 if cover_h <= 0.0 and posture == Post.STAND else 1.0, 0)
	if at_cover and cover_type == Cov.LEAN:
		return position + lean_dir * 0.75 + Vector3(0, 1.45, 0)
	return eye_pos()


func exposed_points() -> Array:
	if life == Life.DOWNED or life == Life.DEAD:
		return [position + Vector3(0, 0.22, 0)]
	if _over():
		if peek_up and not blind:
			# only his head and shoulders show over the top
			var up := position + cover_n * 0.1
			return [up + Vector3(0, cover_h + 0.1, 0), up + Vector3(0, cover_h + 0.26, 0)]
		if posture == Post.PRONE:
			return [position + Vector3(0, 0.22, 0)]
		if Cover.stance(cover_h) == Cover.KNEEL:
			return [position + Vector3(0, cover_h - 0.34, 0), position + Vector3(0, cover_h - 0.16, 0)]
	match posture:
		Post.CROUCH:
			if mounted and mounted.skind in ["mg_nest", "hmg_nest"]:
				return [position + Vector3(0, 1.15, 0), position + Vector3(0, 1.35, 0)]
			return [position + Vector3(0, 0.8, 0), position + Vector3(0, 1.05, 0)]
		Post.PRONE:
			return [position + Vector3(0, 0.25, 0)]
		Post.LEAN_L, Post.LEAN_R:
			return [position + lean_dir * 0.65 + Vector3(0, 1.45, 0)]
	return [position + Vector3(0, 1.3, 0), position + Vector3(0, 1.6, 0)]


func center_point() -> Vector3:
	match posture:
		Post.PRONE:
			return position + Vector3(0, 0.25, 0)
		Post.CROUCH:
			return position + Vector3(0, 0.75, 0)
	if life != Life.ALIVE and life != Life.SURRENDER and life != Life.CAPTIVE:
		return position + Vector3(0, 0.2, 0)
	return position + Vector3(0, 1.1, 0)


func hit_factor() -> float:
	var f := 1.0
	match posture:
		Post.CROUCH:
			f = 0.5 if (mounted and mounted.skind in ["mg_nest", "hmg_nest"]) else 0.75
		Post.PRONE:
			f = 0.45
		Post.LEAN_L, Post.LEAN_R:
			f = 0.26  # half his head, a shoulder and the rifle round the corner
		Post.STAND:
			if at_cover and cover_type == Cov.LOW and not is_moving():
				f = 0.45  # popped up over cover: only head and shoulders show
	if _over() and peek_up and not blind:
		f = 0.3  # head and shoulders over the top, the weapon rested on it
	if life == Life.DOWNED:
		f = 0.5
	elif is_moving():
		# a man dashing from cover to cover is a hard target ("I'm up, he sees me, I'm down")
		f *= 0.5 if move_mode >= 2 else (0.65 if move_mode == 1 else 0.85)
	if _gy < -0.6 and life == Life.ALIVE:
		f *= 0.55  # dug into a trench: a head and a rifle over the parapet
	return f


## At a fighting position on a barrier he fights over (not just ground cover).
func _over() -> bool:
	return at_cover and cover_type == Cov.LOW and cover_h > 0.0 and mounted == null


## The posture for fighting over a barrier this high: lying behind a low lip,
## kneeling behind sandbags or a car, standing behind a chest-high wall - and
## when he ducks, low enough that it covers him.
func _over_post(up: bool) -> int:
	match Cover.stance(cover_h):
		Cover.PRONE:
			return Post.PRONE
		Cover.KNEEL:
			return Post.CROUCH if up or cover_h >= 0.8 else Post.PRONE
	return Post.STAND if up else Post.CROUCH


func _clear_cover() -> void:
	cover_n = Vector3.ZERO
	cover_h = 0.0
	cover_mat = -1
	cover_st = null
	cover_ai = -1
	blind = false
	_shifting = false


## Sent to clients for the pose: the barrier's height in 4 cm steps (bits
## 0-5) and how he's using it (bits 6-7: 1 behind it, 2 firing blind over it).
func cov_code() -> int:
	if not at_cover or cover_h <= 0.0 or mounted != null or is_moving():
		return 0
	var c := clampi(int(round(cover_h / 0.04)), 1, 63)
	return c | ((2 if blind else 1) << 6)


func _cov_seen() -> int:
	if debug_pose.size() > 5:
		return int(debug_pose[5])  # test gallery
	return cov_code() if srv else cov_net


func cover_h_view() -> float:
	var c := _cov_seen()
	return float(c & 63) * 0.04 if (c >> 6) != 0 else 0.0


func blind_view() -> bool:
	return (_cov_seen() >> 6) == 2


## "Cover me!": the nearest man down behind the same stretch of cover comes
## up to keep the fire going while this one changes magazines.
func _call_cover() -> void:
	if squad == null or vis_targets.is_empty():
		return
	for m in squad.members:
		if m == self or m.life != Life.ALIVE or not m.at_cover or m.peek_up or m.reload_t > 0.0 or m.task != "":
			continue
		if Defs.flat(m.position - position).length() > 10.0:
			continue
		m.peek_t = minf(m.peek_t, 0.2)
		if world.rng.randf() < 0.45:
			m.say(_pick(["Covering!", "Got you covered!", "I'm up!"]))
		return


## Is a squad mate near him up and firing? (Then he can afford to duck, reload
## or move; if nobody is, he stays up a little longer to keep the fire going.)
func _buddy_up() -> bool:
	if squad == null:
		return false
	for m in squad.members:
		if m == self or m.life != Life.ALIVE or Defs.flat(m.position - position).length() > 14.0:
			continue
		if (m.at_cover and m.peek_up) or world.time - m.last_shot_t < 0.6:
			return true
	return false


## Duck down, then come up somewhere else along the same barrier: a man who
## pops up in the same spot twice gets shot. At the corner of a tall wall,
## that's the other corner, behind the wall all the way.
func _shift_along() -> bool:
	var st := cover_st
	if st == null or st.gone or cover_ai < 0:
		return false
	var edge := cover_type == Cov.LEAN
	var best := -1
	var bd := 9.0
	for j in st.anc_p.size():
		if j == cover_ai or st.anc_n[j].dot(cover_n) < 0.9:
			continue
		var k: int = st.anc_k[j]
		if k == Cover.STACK or (k == Cover.OVER) == edge or (edge and k == Cover.SHELTER):
			continue
		var q: Vector3 = st.anc_p[j]
		var d := Defs.flat(q - position).length()
		if d < 0.8 or d > (8.5 if edge else 3.0) or not Cover.reachable(world, q) or world.combat._claimed(q, self):
			continue
		if d < bd:
			bd = d
			best = j
	if best < 0:
		return false
	cover_ai = best
	cover_pos = st.anc_p[best]
	cover_h = st.anc_h[best]
	if edge:
		var kb: int = st.anc_k[best]
		lean_dir = cover_n.cross(Vector3.UP) * (1.0 if kb == Cover.EDGE_R else -1.0)
	at_cover = false
	peek_up = false
	_shifting = true
	go_to(cover_pos, "cover", 0)
	world.stat("shift_along")
	return true


func _face(dir: Vector3, dt: float, rate := 9.0) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, Defs.yaw_of(dir), 1.0 - exp(-dt * rate))


func _face_now(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		rotation.y = Defs.yaw_of(dir)


func _threats() -> Array:
	var out := []
	if squad:
		out = squad.threat_points(position, 3)
	if out.is_empty():
		out.append(hold_pos + hold_face * 40.0 + Vector3(0, 1.5, 0))
	return out


func _threat_dir(threats: Array) -> Vector3:
	var d := Vector3.ZERO
	for t in threats:
		d += Defs.flat(t - position).normalized()
	if d.length() < 0.01:
		return hold_face
	return d.normalized()


func _danger() -> bool:
	return suppression > 5.0 or not vis_targets.is_empty() or (squad != null and squad.in_combat())


# --- main loop -------------------------------------------------------------------

func sim(dt: float) -> void:
	if not debug_pose.is_empty():
		posture = int(debug_pose[0])
		act = int(debug_pose[1])
		life = int(debug_pose[2])
		flags = int(debug_pose[4]) if debug_pose.size() > 4 else 0
		return
	_doing_t -= dt
	if _doing_t <= 0.0:
		_doing_t = 0.25
		_update_doing()
	if suppression > 0.0 and world.time - _supp_t > 1.4:
		var rec := 8.0 if suppression > 50.0 else 13.0
		if at_cover and cover_type != Cov.NONE:
			rec *= 1.15
		suppression = maxf(0.0, suppression - dt * rec)
	if at_cover and cover_mat >= 0 and not peek_up and suppression > Cover.SUPP_CAP[cover_mat]:
		suppression = move_toward(suppression, Cover.SUPP_CAP[cover_mat], dt * 16.0)
	say_cd -= dt
	if hit_dirt_t > 0.0:
		hit_dirt_t -= dt
	if flinging:
		_fling_tick(dt)
	else:
		match life:
			Life.ALIVE:
				_alive(dt)
			Life.DOWNED:
				_downed(dt)
			Life.DEAD:
				_dead(dt)
			Life.SURRENDER, Life.CAPTIVE:
				_captive(dt)
			Life.HIDDEN:
				_hidden(dt)
	_posture_sanity(dt)
	_update_flags()


## Nobody glides across the ground: a man who is moving is on his feet (or
## crawling, deliberately) and moving his legs.
func _posture_sanity(dt: float) -> void:
	if life != Life.ALIVE or dt <= 0.0:
		_sim_prev = position
		return
	var sp := Defs.flat(position - _sim_prev).length() / dt
	_sim_prev = position
	if sp < 0.3 or act in [Act.CRAWL, Act.DIVE, Act.FLUNG, Act.SLIDE, Act.DRAGGED, Act.CARRIED, Act.VAULT, Act.SMOTHER]:
		return
	var fixed := ""
	if posture == Post.PRONE:
		posture = Post.CROUCH if sp < 3.2 else Post.STAND
		fixed = "prone"
	if act in [Act.IDLE, Act.IDLE_CHAT, Act.IDLE_LOOK, Act.IDLE_CHECK, Act.FLINCH]:
		act = Act.RUN if sp > 3.2 else Act.WALK
		fixed += "idle"
	if fixed != "" and OS.has_environment("FL_DEBUG_PRONE"):
		world.stat("posture_fix_%s_%s_%s" % [fixed, task, goal_kind])


func _update_flags() -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_update_flags_work()
	if stamp:
		world.detail("_update_flags", stamp)


func _update_flags_work() -> void:
	var f := 0
	if suppression > 25.0:
		f |= F_SUPP
	if suppression >= 60.0:
		f |= F_PINNED
	var w := cur_weapon()
	if not w.is_empty() and int(w.ammo) < 9000:
		if total_ammo() <= 0:
			f |= F_NOAMMO
		elif total_ammo() < int(w.ammo * 0.3):
			f |= F_LOWAMMO
	if world.time - last_shot_t < 0.6:
		f |= F_SHOOTING
	if life == Life.DOWNED:
		f |= F_MEDIC
	if squad and squad.leader == self:
		f |= F_LEADER
	if at_cover and cover_type == Cov.LOW and peek_up and not blind and (cover_h > 0.0 or posture == Post.STAND):
		f |= F_OVERWALL
	flags = f


## Out of breath: rushes, sprints and dragging a man wear him down; a breather
## (lower down, sooner) brings it back.
func _fatigue_tick(dt: float) -> void:
	var drain := 0.0
	if is_moving() or dive_t > 0.0:
		drain = [0.0, 0.022, 0.045][clampi(move_mode, 0, 2)]
		if act == Act.CRAWL:
			drain = 0.012
		if task in ["rescue", "stretcher", "smother"]:
			drain += 0.025
	elif task == "stretcher" or act in [Act.DRAG, Act.CARRY]:
		drain = 0.025
	if drain > 0.0:
		stamina = maxf(0.0, stamina - drain * dt)
	else:
		stamina = minf(1.0, stamina + (0.06 if posture != Post.STAND else 0.045) * dt)


func _alive(dt: float) -> void:
	_fatigue_tick(dt)
	if dazed_t > 0.0:
		_dazed_tick(dt)
		return
	if dive_t > 0.0:
		dive_t -= dt
		act = Act.DIVE
		var np := position + dive_dir * 5.5 * dt
		if world.nav.walkable(np):
			position = np
		position.y = maxf(base_y + _ground(), position.y - dt * 3.0)
		if dive_t <= 0.0:
			posture = Post.PRONE
			act = Act.IDLE
			at_cover = false
			next_cover_eval = world.time + 0.8
		return
	if act_t > 0.0:
		act_t -= dt
		_action_tick(dt)
		if act_t <= 0.0:
			_action_done()
		return
	if flinch_t > 0.0:
		flinch_t -= dt
		act = Act.FLINCH
		if flinch_t > 0.0:
			return
		act = Act.IDLE
	think_t -= dt
	if think_t <= 0.0:
		think_t = 0.24 + world.rng.randf() * 0.1
		_think()
		if act_t > 0.0 or dive_t > 0.0 or life != Life.ALIVE:
			return
	match task:
		"":
			_fight_tick(dt)
		"rescue":
			_rescue_tick(dt)
		"escort":
			_escort_tick(dt)
		"heal":
			_heal_tick(dt)
		"build":
			_build_tick(dt)
		"stretcher":
			_stretcher_tick(dt)
		"limp":
			_limp_tick(dt)
		"captor":
			_captor_tick(dt)
		"man":
			_man_tick(dt)
		"tunnel":
			_tunnel_tick(dt)
		"board":
			_board_tick(dt)
		"resupply":
			_resupply_tick(dt)
		"grenade_pickup":
			_gpick_tick(dt)
		"smother":
			SoldierBrain.smother_tick(self, dt)
		"gkick":
			SoldierBrain.gkick_tick(self, dt)
		"breach":
			SoldierBrain.breach_tick(self, dt)
		"retreat":
			_retreat_tick(dt)
		"throw":
			_throw_tick(dt)
		"pilot":
			_pilot_tick(dt)
		_:
			task = ""


## What he sees, then what he does about it: the reflexes and the fight are
## a behaviour tree (SoldierBrain).
func _think() -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_think_work()
	if stamp:
		world.detail("_think", stamp)


func _think_work() -> void:
	scan_n += 1
	if scan_n % 2 == 0 or target == null:
		_scan()
	_compute_sep()
	SoldierBrain.think(self)


## Where a man at a halt keeps watch: towards the threat, spread across the
## squad's frontage by where he stands in it (the flanks look out to the
## flanks); in a big squad the last man covers the rear.
func _sector_dir() -> Vector3:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	var result := _sector_dir_work()
	if stamp:
		world.detail("_sector_dir", stamp)
	return result


func _sector_dir_work() -> Vector3:
	var threats: Array = squad.sector_threats(position)
	var f := _threat_dir(threats)
	if threats.is_empty():
		var watch := Defs.flat(hold_pos + hold_face * 40.0 - position)
		if watch.length() >= 0.01:
			f = watch.normalized()
	var right := Vector3(-f.z, 0, f.x)
	var mems: Array = squad.members
	if mems.size() >= 6 and mems.back() == self and not vis_targets.size():
		return -f
	var side := clampf((position - squad.centroid()).dot(right) / 5.0, -1.0, 1.0)
	return (f + right * side * 0.85).normalized()


# --- perception --------------------------------------------------------------------

func _scan() -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_scan_work()
	if stamp:
		world.detail("_scan", stamp)


func _scan_work() -> void:
	var phase := Time.get_ticks_usec() if world.measure_details else 0
	vis_targets.clear()
	if is_bearer():
		target = null
		return
	var arr := scan_candidates()
	var best: Entity = null
	if phase:
		world.detail("scan candidates", phase)
		phase = Time.get_ticks_usec()
	var best_s := -1e9
	var checked := 0
	var eye := scan_eye()
	var exclude := get_exclude()
	var cache_sight := _path_pending or not is_moving()
	for it in arr:
		if checked >= 7:
			break
		checked += 1
		var e: Entity = it[1]
		if world.combat.can_see_from(eye, e, exclude, cache_sight):
			vis_targets.append(e)
			if squad:
				squad.report(e)
			# A gunner still reports flanking contacts, but aims within the mount's arc.
			if task == "man" and task_phase == 2 and mounted and mounted.skind in ["mg_nest", "hmg_nest"] and not mounted.mg_covers(e.position - position):
				continue
			var s := -sqrt(it[0])
			if e is Soldier:
				if e.life == Life.DOWNED:
					s -= 35.0
				if e.utype in ["mg_gunner", "pkm"]:
					s += 5.0
			elif e is Vehicle:
				if rockets > 0:
					s += 30.0
				elif int(e.vdef.get("armor", 1)) >= 2 and not cur_weapon().get("ap", false):
					continue  # rifle fire off a tank's armour only draws its machine gun: keep down
				elif int(e.vdef.get("armor", 1)) >= 1 and not cur_weapon().get("ap", false):
					s -= 40.0
				else:
					s -= 12.0
			if e == target:
				s += 6.0
			if s > best_s:
				best_s = s
				best = e
	if phase:
		world.detail("scan LOS", phase)
	for d in world.drones:
		if d.team == team or d.dead:
			continue
		var dd := position.distance_to(d.position)
		if dd < 38.0 and world.combat.clear_line(eye, d.position):
			vis_targets.append(d)
			if dd < 30.0 or d.diving:
				best = d
	if forced_target and not forced_target.gone:
		if forced_target in vis_targets:
			best = forced_target
		elif forced_target is Structure and Defs.flat(forced_target.position - position).length() < cur_weapon().get("range", 50.0):
			best = forced_target
	target = best


## Visit nearby cells first. Once seven eligible contacts are found, entire
## cells farther away can be rejected before touching their soldiers. The
## actual LOS and concealment rules are unchanged, including off-screen fights.
func scan_candidates() -> Array:
	var out := []
	var p := position
	var r := sight_range()
	if world.perception:
		var ids: PackedInt32Array = world.perception.nearest(p.x, p.z, team, r)
		for id in ids:
			var e := world.entity(id)
			if e and not e.gone:
				if e is Soldier and (e.life not in [Life.ALIVE, Life.DOWNED] or (e.life == Life.DOWNED and world.time - e.last_shot_t > 2.0)):
					continue
				var diff := e.position - p
				out.append([diff.x * diff.x + diff.z * diff.z, e])
		return out
	var limit := maxf(r, 85.0) ** 2
	var cell := Vector2i(floori(p.x / World.HCELL), floori(p.z / World.HCELL))
	for offset: Vector2i in world.perception_cells:
		var key := cell + offset
		var dx := maxf(0.0, absf((key.x + 0.5) * World.HCELL - p.x) - World.HCELL * 0.5)
		var dz := maxf(0.0, absf((key.y + 0.5) * World.HCELL - p.z) - World.HCELL * 0.5)
		if dx * dx + dz * dz > limit:
			continue
		var bucket: Array = world._uhash.get(key, [])
		for e: Entity in bucket:
			if e.gone or e.team == team or e.team < 0:
				continue
			var ep := e.position
			var diff := ep - p
			var d2 := diff.x * diff.x + diff.z * diff.z
			if d2 > limit:
				continue
			if e is Soldier:
				var s := e as Soldier
				if s.life != Life.ALIVE and s.life != Life.DOWNED:
					continue
				if s.life == Life.DOWNED and world.time - s.last_shot_t > 2.0:
					continue
				var rr := r * world.terrain.concealment(ep)
				if world.time - s.last_shot_t > 8.0 and not s.is_moving() and (s.at_cover or s.posture == Post.PRONE):
					rr *= 0.7
				if d2 > rr * rr:
					continue
			elif e is Vehicle:
				var v := e as Vehicle
				if not v.is_air() and world.terrain.netted[world.terrain.idx_of(ep)] > 0 and d2 > maxf(r, 85.0) ** 2 * 0.25:
					continue
			var at := out.size()
			while at > 0 and (float(out[at - 1][0]) > d2 or (float(out[at - 1][0]) == d2 and (out[at - 1][1] as Entity).eid > e.eid)):
				at -= 1
			out.insert(at, [d2, e])
			if out.size() > 7:
				out.pop_back()
			if out.size() == 7:
				limit = float(out[6][0])
	return out


func _target_valid(e: Entity) -> bool:
	if e == null or e.gone:
		return false
	if e is Soldier:
		return e.life == Life.ALIVE or e.life == Life.DOWNED
	if e is Drone:
		return not e.dead
	return true


func _has_los_now(e: Entity) -> bool:
	if e != los_ent or world.time > los_t:
		los_ent = e
		los_t = world.time + 0.3
		if e is Structure:
			los_ok = world.combat.sees_structure(eye_pos(), e)
		elif e is Drone:
			los_ok = world.combat.clear_line(eye_pos(), e.position)
		else:
			los_ok = world.combat.can_see_from(eye_pos(), e, get_exclude(), _path_pending or not is_moving())
	return los_ok


func _aim_point(e: Entity) -> Vector3:
	if e is Soldier and e._over() and world.rng.randf() < 0.35:
		# at the middle of him, through whatever he's behind
		return e.position + Vector3(0, minf(e.cover_h - 0.12, 1.0), 0)
	if e is Soldier:
		var pts: Array = e.exposed_points()
		return pts[world.rng.randi() % pts.size()]
	if e is Drone:
		return e.position
	return e.center_point()


# --- fighting ----------------------------------------------------------------------

## His place in the fight: in cover where his squad is holding, out of ammo
## and looking for more. (The special weapons come first: see SoldierBrain.)
func _fight_think() -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_fight_think_work()
	if stamp:
		world.detail("_fight_think", stamp)


func _fight_think_work() -> void:
	var w := cur_weapon()
	if w.is_empty():
		return
	if total_ammo() <= 0 and int(w.ammo) < 9000:
		if not out_said:
			out_said = true
			say("Out of ammo!", true)
		if _seek_resupply():
			return
	if goal_kind == "slot" and is_moving():
		return
	if goal_kind == "cover" and is_moving():
		return
	var need := false
	if not at_cover:
		need = world.time > next_cover_eval
	elif cover_st != null and (not is_instance_valid(cover_st) or cover_st.gone or cover_ai >= cover_st.anc_p.size() 			or Defs.flat(cover_st.anc_p[cover_ai] - cover_pos).length() > 0.3):
		# the wall he was behind came down, or the car was blown across the road
		cover_st = null
		need = true
	elif cover_st != null and cover_st.burn > 0.3:
		cover_st = null  # it's caught fire: he'll not stay behind that
		need = true
	elif world.time > next_cover_eval:
		var threats := _threats()
		var td := _threat_dir(threats)
		if td.dot(cover_threat) < 0.55 or cover_type == Cov.NONE:
			need = true
		elif suppression > 45.0 and cover_type == Cov.HIDE and not vis_targets.is_empty():
			need = true
		else:
			next_cover_eval = world.time + 2.5
	if need:
		_seek_cover(hold_pos, leash, _threats())


func _seek_cover(anchor: Vector3, radius: float, threats: Array) -> void:
	next_cover_eval = world.time + world.rng.randf_range(3.5, 6.0)
	var res: Dictionary = world.combat.find_cover(self, anchor, radius, threats, false)
	peek_up = false
	blind = false
	if res.is_empty():
		cover_type = Cov.NONE
		_clear_cover()
		cover_threat = _threat_dir(threats)
		if Defs.flat(position - anchor).length() > radius:
			go_to(anchor, "slot", 0)
		else:
			at_cover = true
			cover_pos = position
		return
	cover_pos = res.pos
	cover_type = res.type
	lean_dir = res.lean
	cover_threat = res.tdir
	cover_n = res.get("n", Vector3.ZERO)
	cover_h = float(res.get("h", 0.0))
	cover_mat = int(res.get("mat", -1))
	cover_st = res.get("st")
	cover_ai = int(res.get("ai", -1))
	_shifting = false
	if Defs.flat(position - cover_pos).length() < 0.6:
		at_cover = true
		return
	at_cover = false
	go_to(cover_pos, "cover", (2 if suppression > 35.0 else 1) if _danger() else 0)


func go_to(p: Vector3, kind: String, mode: int) -> void:
	# retreats keep well clear of known enemy fire; ordinary moves skirt it
	var care := 0.0
	if task == "retreat" or task == "limp":
		care = 1.6
	elif kind == "slot":
		care = 0.8 if mode == 0 else 0.35
	_path_revision += 1
	var revision := _path_revision
	_path_pending = true
	path = PackedVector3Array()
	_stuck_p = position
	_stuck_t = 0.0
	path_i = 0
	goal = p
	goal_kind = kind
	move_mode = mode
	world.nav.request_path(self, p, false, team, care, func(points: PackedVector3Array):
		if revision != _path_revision:
			return
		_path_pending = false
		if life == Life.DEAD or life == Life.HIDDEN:
			return
		path = points
		path_i = 0
		if path.is_empty():
			if Defs.flat(position - goal).length_squared() < 1.7 * 1.7:
				_arrived()
			else:
				world.stat("path_unreachable")
				if goal_kind == "cover":
					_clear_cover()
					at_cover = false
					next_cover_eval = world.time + 1.0
				stop_moving())


func stop_moving() -> void:
	_path_revision += 1
	_path_pending = false
	if world.nav:
		world.nav.cancel_path(eid)
	path = PackedVector3Array()
	path_i = 0
	goal_kind = ""


func _arrived() -> void:
	var k := goal_kind
	goal_kind = ""
	path = PackedVector3Array()
	path_i = 0
	slide_t = 0.0
	match k:
		"slot":
			at_cover = false
			next_cover_eval = 0.0
		"cover":
			at_cover = true
			_shifting = false
			peek_t = world.rng.randf_range(0.3, 1.0)
			if cover_n != Vector3.ZERO and world.time - last_shot_t > 0.5:
				_face_now(cover_n)
		"prison":
			world.rules.prisoner_arrived(self)


## Under heavy fire a man rushes for cover and only crawls the last couple
## of metres; a long crawl in the open just gets him shot.
func _crawling() -> bool:
	if goal_kind != "cover" or path_i >= path.size():
		return false
	if _shifting and cover_h > 0.0 and cover_h < Cover.KNEEL_MAX and _danger():
		return true  # along a low wall under fire: on his belly, below the top
	return suppression >= 70.0 and Defs.flat(goal - position).length() < 2.6


func _speed() -> float:
	if _crawling():
		return 0.95
	var s: float = SPEEDS[clampi(move_mode, 0, 2)]
	if utype in ["mg_gunner", "pkm"]:
		s *= 0.9
	if move_mode == 0 and posture == Post.CROUCH:
		s *= 0.8
	if stamina < 0.35:
		s *= 0.65 + stamina  # blown: the sprint becomes a stagger
	return s


func _move_tick(dt: float, speed: float) -> bool:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	var result := _move_tick_work(dt, speed)
	if stamp:
		world.detail("_move_tick", stamp)
	return result


func _move_tick_work(dt: float, speed: float) -> bool:
	if _path_pending:
		return true  # callers must not finish a task while its route is queued
	if path_i >= path.size():
		return false
	# watchdog: no progress for a while -> plan again from here
	_stuck_t += dt
	if _stuck_t > 3.0:
		if Defs.flat(position - _stuck_p).length() < 0.8 and slide_t <= 0.0:
			world.stat("repath")
			var g2 := path[path.size() - 1]
			go_to(g2, goal_kind, move_mode)
			return true  # replanning still counts as travelling to the task
		_stuck_t = 0.0
		_stuck_p = position
	var tgt := path[path_i]
	var to := Defs.flat(tgt - position)
	var d := to.length()
	if d < 0.3:
		path_i += 1
		if path_i >= path.size():
			_arrived()
			return false
		tgt = path[path_i]
		to = Defs.flat(tgt - position)
		d = to.length()
		if d < 0.001:
			return true
	var k := world.nav.kind_at(position)
	vaulting = k == Nav.LOW and life == Life.ALIVE and _barrier_ahead(to / d)
	var mul := 1.0
	if k == Nav.SLOW:
		mul = 0.3
	elif vaulting:
		mul = 0.7
	if slide_t > 0.0:
		slide_t -= dt
		mul = 1.3
	mul *= world.terrain.speed_mul(position, false)
	var step := minf(d, speed * mul * dt)
	var dir := to / d
	if (door_wait > 0.0 or (not world.door_cells.is_empty() and world.time > _door_t)) and _door_tick(dt, dir):
		return true
	_last_dir = dir
	position += dir * step
	var ty := base_y + (0.5 if vaulting else 0.0) + _ground()
	position.y = lerpf(position.y, ty, 1.0 - exp(-dt * 12.0))
	if not backwards:
		_face(dir, dt, 10.0)
	# slide into cover when dashing under fire
	if goal_kind == "cover" and move_mode >= 1 and path_i == path.size() - 1 and slide_t <= 0.0 and world.time > slide_cd:
		var rem := Defs.flat(path[path.size() - 1] - position).length()
		if rem < 2.4 and rem > 1.2 and suppression > 10.0:
			slide_t = 0.45
			world.stat("slide")
			slide_cd = world.time + 4.0
	return true


## A shut door in his way: in a fight he kicks it in, otherwise he just opens
## it. He stops there while he does (true).
func _door_tick(dt: float, dir: Vector3) -> bool:
	if door_wait > 0.0:
		door_wait -= dt
		_stuck_t = 0.0
		if door_wait > 0.0:
			return true
		if door_st and not door_st.gone and door_st.door_shut:
			door_st.open_door(self, door_kick)
		door_st = null
		return false
	_door_t = world.time + 0.12
	var ds: Structure = world.door_in_way(position, dir)
	if ds == null or life != Life.ALIVE:
		return false
	door_st = ds
	door_kick = _danger()
	door_wait = 0.5 if door_kick else 0.8
	_face_now(dir)
	if door_kick and world.rng.randf() < 0.4:
		say(_pick(["Breaching!", "Door!", "Kicking it in!"]), true)
	return true


var _bar_t := 0.0
var _bar := false


## Is there something knee-high right in front of him to get over? (A man
## walking along a wall in its padded nav cells isn't climbing it.)
func _barrier_ahead(dir: Vector3) -> bool:
	if world.time > _bar_t:
		_bar_t = world.time + 0.2
		var a := position + Vector3(0, 0.45, 0)
		_bar = not world.combat.ray(a, a + dir * 0.9).is_empty()
	return _bar


func _compute_sep() -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_compute_sep_work()
	if stamp:
		world.detail("_compute_sep", stamp)


func _compute_sep_work() -> void:
	_sep = Vector3.ZERO
	if life != Life.ALIVE or dragged_by or task in ["stretcher", "captor"]:
		return
	for o in world.soldiers_near(position, 0.85):
		if o == self or o.life == Life.HIDDEN or o.life == Life.DEAD:
			continue
		var d := Defs.flat(position - o.position)
		var l := d.length()
		if l < 0.01:
			d = Vector3(world.rng.randf_range(-1, 1), 0, world.rng.randf_range(-1, 1))
			l = 0.5
		_sep += d.normalized() * (0.85 - l)


func _apply_sep(dt: float) -> void:
	_shuffle = false
	if _sep.length_squared() < 0.0001 or posture == Post.PRONE:
		return
	var v := _sep * 2.5
	if v.length() > 1.4:
		v = v.normalized() * 1.4
	var np := position + v * dt
	if world.nav.walkable(np):
		position = np
		_shuffle = v.length() > 0.3


## Ground level under the soldier: about half a metre down inside a finished trench.
func _ground() -> float:
	if not world.terrain.landform.heights.is_empty() or world.time > _gy_t:
		_gy_t = world.time + 0.3
		_gy = world.ground_y(position)
	return _gy


func _settle_y(dt: float) -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_settle_y_work(dt)
	if stamp:
		world.detail("_settle_y", stamp)


func _settle_y_work(dt: float) -> void:
	var settled := position
	settled.y = lerpf(position.y, base_y + _ground(), 1.0 - exp(-dt * 8.0))
	if settled != position:
		position = settled


func _fight_tick(dt: float) -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_fight_tick_work(dt)
	if stamp:
		world.detail("_fight_tick", stamp)


func _fight_tick_work(dt: float) -> void:
	var moving := _move_tick(dt, _speed())
	if not moving:
		_apply_sep(dt)
		_settle_y(dt)
		if at_cover and cover_n != Vector3.ZERO:
			# tight to the barrier on his spot, watching across it
			var off := Defs.flat(cover_pos - position)
			if off.length() > 0.02 and off.length() < 0.9:
				position += off.limit_length(dt * 1.4)
			if world.time - last_shot_t > 1.0 and not (peek_up and _target_valid(target)) and cover_type != Cov.LEAN:
				_face(cover_n, dt, 5.0)
		elif _sector != Vector3.ZERO and world.time - last_shot_t > 1.2 and not (at_cover and cover_type != Cov.NONE) and not _target_valid(target):
			_face(_sector, dt, 3.0)
	else:
		_shuffle = false
	_weapon_tick(dt, moving, "normal")
	_choose_act(moving or _shuffle)
	_idle_tick(dt, moving)


# --- downtime -------------------------------------------------------------------------

## When nothing has happened for a while men get bored: they chat and rib each
## other, smoke, sit down, stretch, check their kit. Anything at all - an order,
## a shot, an enemy seen - and it's over.
func _idle_tick(dt: float, moving: bool) -> void:
	var calm := not moving and not _danger() and _sector == Vector3.ZERO and reload_t <= 0.0 and world.time - last_shot_t > 12.0 and mounted == null and not _target_valid(target)
	if not calm:
		calm_t = 0.0
		if idle_act != 0:
			_end_idle()
		return
	calm_t += dt
	if idle_act != 0:
		var partner_gone: bool = idle_act == Act.IDLE_CHAT and (chat_with == null or not is_instance_valid(chat_with) or chat_with.gone or chat_with.chat_with != self or chat_with.life != Life.ALIVE)
		if world.time > idle_until or partner_gone:
			_end_idle()
			return
		act = idle_act
		posture = Post.STAND
		if idle_act == Act.IDLE_CHAT and chat_with != null:
			var to: Vector3 = Defs.flat(chat_with.position - position)
			if to.length() > 0.3:
				_face(to.normalized(), dt, 4.0)
			_banter_tick()
		return
	if calm_t < 12.0 or world.time < idle_next:
		return
	_start_idle()


func _start_idle() -> void:
	idle_next = world.time + world.rng.randf_range(6.0, 16.0)
	var ti := 1 if team == 1 else 0
	if world.rng.randf() < 0.35 and world.time - float(_last_chat[ti]) > 8.0:
		var mate := _chat_mate()
		if mate:
			_start_chat(mate)
			return
	var picks := [Act.IDLE_SMOKE, Act.IDLE_SIT, Act.IDLE_STRETCH, Act.IDLE_CHECK, Act.IDLE_LOOK, Act.IDLE_LOOK]
	idle_act = picks[world.rng.randi() % picks.size()]
	var dur := {Act.IDLE_SMOKE: 16.0, Act.IDLE_SIT: 24.0, Act.IDLE_STRETCH: 3.2, Act.IDLE_CHECK: 5.0, Act.IDLE_LOOK: 6.0}
	idle_until = world.time + float(dur[idle_act]) * world.rng.randf_range(0.8, 1.3)
	if world.rng.randf() < 0.22:
		say(_pick(BORED[1 if team == 1 else 0]))


func _chat_mate() -> Soldier:
	for o in world.soldiers_near(position, 6.0):
		if o == self or o.team != team or o.life != Life.ALIVE or o.chat_with != null or o.calm_t < 5.0 or o.task != "" or o.is_moving():
			continue
		return o
	return null


func _start_chat(mate: Soldier) -> void:
	var lines: Array = BANTER[1 if team == 1 else 0]
	var ex: Array = lines[world.rng.randi() % lines.size()]
	var dur := 3.5 + ex.size() * 2.8
	for s in [self, mate]:
		s.chat_with = mate if s == self else self
		s.idle_act = Act.IDLE_CHAT
		s.idle_until = world.time + dur
		s.idle_next = world.time + dur + world.rng.randf_range(25.0, 60.0)
		s._banter.clear()
	for i in ex.size():
		var who: Soldier = self if i % 2 == 0 else mate
		var other: Soldier = mate if i % 2 == 0 else self
		var txt: String = ex[i]
		if txt.contains("%s"):
			txt = txt % other.sname
		who._banter.append([world.time + 0.3 + i * 2.8, txt])
	# the one who didn't get the last word laughs it off
	var listener: Soldier = mate if ex.size() % 2 == 1 else self
	listener._banter.append([world.time + ex.size() * 2.8 - 0.6, "!laugh"])
	world.stat("banter")
	_last_chat[1 if team == 1 else 0] = world.time


func _banter_tick() -> void:
	while not _banter.is_empty() and world.time >= float(_banter[0][0]):
		var e: Array = _banter.pop_front()
		if String(e[1]) == "!laugh":
			_laugh_until = world.time + 1.8
			if world.rng.randf() < 0.6:
				say(_pick(LAUGHS), true)
		else:
			say(String(e[1]), true)
	if world.time < _laugh_until:
		act = Act.IDLE_LAUGH


func _end_idle() -> void:
	idle_act = 0
	_banter.clear()
	_laugh_until = 0.0
	if chat_with != null and is_instance_valid(chat_with) and chat_with.chat_with == self:
		chat_with.chat_with = null
	chat_with = null
	idle_next = world.time + world.rng.randf_range(5.0, 12.0)


func _choose_act(moving: bool) -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_choose_act_work(moving)
	if stamp:
		world.detail("_choose_act", stamp)


func _choose_act_work(moving: bool) -> void:
	if door_wait > 0.0:
		act = Act.KICK if door_kick else Act.IDLE
	elif reload_t > 0.0:
		act = Act.RELOAD
	elif world.time - last_shot_t < 0.35:
		act = Act.SHOOT
	elif moving:
		if _crawling():
			act = Act.CRAWL
		elif slide_t > 0.0:
			act = Act.SLIDE
		elif vaulting:
			act = Act.VAULT
		else:
			act = Act.RUN if _speed() > 3.2 else Act.WALK
	else:
		act = Act.IDLE
		# blown after a long rush: bent over, hands on his knees
		if stamina < 0.3 and posture == Post.STAND and world.time - last_shot_t > 1.5 and not _target_valid(target):
			act = Act.WINDED


func _lean_post() -> int:
	var right := Vector3(cos(rotation.y), 0, -sin(rotation.y))
	return Post.LEAN_R if lean_dir.dot(right) > 0.0 else Post.LEAN_L


## Fighting from a barrier: come up, find the target, fire a few bursts, get
## back down - reload only while down - and every so often move along the
## wall before coming up again, especially if they had him spotted. If no-one
## else near him is firing he stays up a little longer; pinned, a regular
## waits for the fire to slacken, a fighter may hold his rifle up over the
## wall and fire blind.
func _cover_cycle(dt: float, w: Dictionary, want_fire: bool, pinned: bool) -> void:
	peek_t -= dt
	# nothing to shoot at and nobody shooting at him: up over the top keeping
	# watch, the weapon on the wall - not curled up behind it. The first round
	# that cracks past and he's down.
	var calm := not want_fire and not pinned and suppression < 12.0 and world.time - _supp_t > 4.0 and reload_t <= 0.0 and hit_dirt_t <= 0.0
	if calm:
		if not peek_up:
			peek_up = true
			_peek_from = world.time
			_up_supp = suppression
		blind = false
		_watching = true
		return
	if _watching:
		_watching = false
		if want_fire and peek_up:
			# already up and looking: he opens fire from there
			peek_t = world.rng.randf_range(2.2, 4.0)
			_peek_from = world.time - 0.4
			_up_supp = suppression
			_stayed = false
		else:
			peek_up = false
			peek_t = world.rng.randf_range(0.6, 1.4)
		return
	if peek_up:
		# drew fire: once he's got a burst off, rounds start cracking round his head
		var drew := suppression - _up_supp > 28.0 and world.time - _peek_from > 1.1
		# (a pinned man's snap shot is short already: it's peek_t that ends it)
		var done := peek_t <= 0.0 or reload_t > 0.0 or not want_fire or drew or suppression >= 88.0
		if done and peek_t <= 0.0 and not drew and not pinned and want_fire and reload_t <= 0.0 and not _stayed and not _buddy_up():
			_stayed = true
			peek_t = world.rng.randf_range(0.8, 1.6)
			done = false
		if done:
			if drew and world.settings.get("debug", false):
				world.stat("t%d_drew" % team)
			peek_up = false
			blind = false
			# they had him zeroed: give it a moment before trying again
			peek_t = world.rng.randf_range(0.6, 1.4) * (1.8 if suppression > 30.0 else 1.0) * (2.2 if drew else 1.0)
			# a fresh magazine while he's down - and someone else up meanwhile
			if not w.is_empty() and int(w.ammo) < 9000 and mag < int(w.get("mag", 30)) * 0.5 and reserve > 0:
				_start_reload()
				_call_cover()
			elif drew or (cover_type == Cov.LOW and world.rng.randf() < 0.2):
				_shift_along()
		return
	if peek_t > 0.0 or reload_t > 0.0 or not want_fire:
		return
	if pinned:
		if team == 1 and cover_type == Cov.LOW and cover_h >= Cover.PRONE_MAX and _target_valid(target) and world.rng.randf() < 0.4:
			blind = true
			peek_up = true
			peek_t = world.rng.randf_range(1.0, 2.0)
			world.stat("blind_fire")
		elif world.rng.randf() < 0.22 + (0.15 if cover_mat >= Cover.HARD else 0.0) + (0.1 if _gy < -0.6 else 0.0):
			peek_up = true  # pinned men still snap off the odd shot - briefly (more often behind something solid)
			peek_t = world.rng.randf_range(0.9, 1.6)
		else:
			peek_t = world.rng.randf_range(0.5, 1.1)
			return
	else:
		peek_up = true
		peek_t = world.rng.randf_range(2.2, 4.0)
	_peek_from = world.time
	_up_supp = suppression
	_stayed = false
	if world.settings.get("debug", false):
		world.stat("t%d_peek" % team)


func _weapon_tick(dt: float, moving: bool, mode: String) -> void:
	var stamp := Time.get_ticks_usec() if world.measure_details else 0
	_weapon_tick_work(dt, moving, mode)
	if stamp:
		world.detail("_weapon_tick", stamp)


func _weapon_tick_work(dt: float, moving: bool, mode: String) -> void:
	fire_t -= dt
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			_finish_reload()
	var w := cur_weapon()
	var pinned := suppression >= (squad.pin_at() if squad else 60.0)  # a shaken squad is pinned sooner
	var danger := _danger()
	var have_target := _target_valid(target)
	var own_cf := cf_until > world.time
	var cf := own_cf or (squad != null and squad.cover_fire_until > world.time)
	var cfp: Vector3 = cf_pos if own_cf else (squad.cover_fire_pos if squad else Vector3.ZERO)
	var want_fire := have_target or cf
	var want := Post.STAND
	var shoot_ok := false
	if mode == "escort":
		want = Post.STAND
		shoot_ok = true
	elif mode == "crew":
		# behind the gun: kneeling in a nest, standing on the fire step of a
		# trench bay; under fire too heavy to work the gun he gets down
		var bay: bool = mounted != null and mounted.variant == 1
		var down := suppression >= 88.0
		want = (Post.CROUCH if bay else Post.PRONE) if down else (Post.STAND if bay else Post.CROUCH)
		shoot_ok = not down
		peek_up = false
		if not have_target and not cf:
			_face(cover_threat, dt, 3.0)
	elif moving:
		if _crawling():
			want = Post.PRONE
		elif goal_kind == "cover" and danger and Defs.flat(goal - position).length() < 4.0:
			want = Post.CROUCH  # the last few metres to the wall, or along it: bent double
		else:
			want = Post.CROUCH if (move_mode == 0 and danger and suppression > 20.0) else Post.STAND
		shoot_ok = move_mode == 0 and want != Post.PRONE and not _shifting
		peek_up = false
		blind = false
	elif at_cover and cover_type == Cov.LOW and cover_h <= 0.0 and mounted == null:
		# in the trees or a fold of ground with nothing to get behind: down on a knee and fight
		want = Post.PRONE if pinned else Post.CROUCH
		shoot_ok = true
		peek_up = false
	elif at_cover and (cover_type == Cov.LOW or cover_type == Cov.LEAN):
		_cover_cycle(dt, w, want_fire, pinned)
		if cover_type == Cov.LOW:
			want = _over_post(peek_up) if cover_h > 0.0 else (Post.STAND if peek_up else Post.CROUCH)
		else:
			if peek_up:
				_face_now(cover_threat)
				want = _lean_post()
			else:
				want = Post.STAND
		# coming up takes a moment: find the target, settle the weapon on the wall
		shoot_ok = peek_up and (blind or world.time - _peek_from > 0.35)
	elif at_cover and cover_type == Cov.HIDE:
		want = Post.CROUCH
		shoot_ok = true
	else:
		if pinned:
			want = Post.PRONE
		elif danger:
			want = Post.PRONE if suppression > 35.0 else Post.CROUCH
		elif _sector != Vector3.ZERO:
			# out in the open at a halt: take a knee; the gun goes down on its bipod
			want = Post.PRONE if utype in ["mg_gunner", "pkm"] else Post.CROUCH
		else:
			want = Post.STAND
		# pinned flat in the open he mostly hugs the ground: now and then he
		# lifts his head and fires a burst
		shoot_ok = not pinned or fmod(world.time + float(eid % 13) * 0.37, 4.0) < 1.3
	if pinned and want == Post.STAND and mode != "escort" and mode != "crew":
		want = Post.CROUCH
	if hit_dirt_t > 0.0 and mode != "escort" and not moving:
		want = Post.PRONE
		shoot_ok = false
	posture = want
	if not shoot_ok or reload_t > 0.0 or fire_t > 0.0 or w.is_empty():
		return
	if suppression >= 88.0 and mode != "escort":
		return
	if squad and squad.ambush and mode == "normal" and forced_target == null:
		return  # holding fire till the leader springs it
	var aim_ent: Entity = null
	var aim_pt := Vector3.INF
	if blind and have_target:
		aim_ent = target  # roughly where he last saw him, head down
		aim_pt = target.position + Vector3(world.rng.randf_range(-1.5, 1.5), world.rng.randf_range(0.5, 1.8), world.rng.randf_range(-1.5, 1.5))
	elif have_target and _has_los_now(target):
		aim_ent = target
		aim_pt = _aim_point(target)
	elif cf and Defs.flat(cfp - position).length() < float(w.range) * 1.1:
		aim_pt = cfp + Vector3(world.rng.randf_range(-2.5, 2.5), world.rng.randf_range(0.6, 1.4), world.rng.randf_range(-2.5, 2.5))
	elif squad and (utype in ["mg_gunner", "pkm"] or not gun_override.is_empty()):
		var lk: Dictionary = squad.last_known_near(position, float(w.range), 5.0)
		if not lk.is_empty():
			aim_pt = lk.pos + Vector3(world.rng.randf_range(-1.5, 1.5), 1.0, world.rng.randf_range(-1.5, 1.5))
	if aim_pt == Vector3.INF:
		return
	var aim_dir := Defs.flat(aim_pt - position).normalized()
	if mode == "crew" and mounted and not mounted.mg_covers(aim_dir):
		return  # outside the gun's arc
	if mode != "escort" and not (posture == Post.LEAN_L or posture == Post.LEAN_R):
		if blind and cover_n != Vector3.ZERO and aim_dir.dot(cover_n) < 0.5:
			return  # he can't hold it over the wall that far round
		_face_now(aim_dir)
	_shoot(aim_pt, aim_ent, moving, cf)


func _shoot(aim_pt: Vector3, aim_ent: Entity, moving: bool, cover_fire: bool) -> void:
	var w := cur_weapon()
	var infinite := int(w.ammo) >= 9000
	if mag <= 0 and not infinite:
		_start_reload()
		return
	var low := not infinite and total_ammo() < int(w.ammo * 0.3)
	if burst_left <= 0:
		var b: Vector2i = w.burst
		burst_left = 1 if low else world.rng.randi_range(b.x, b.y)
		if low and not low_ammo_said:
			low_ammo_said = true
			world.stat("low_ammo")
			say("Low on ammo!", true)
	if not infinite:
		mag -= 1
	burst_left -= 1
	last_shot_t = world.time
	act = Act.SHOOT
	var muzzle := eye_pos() + Defs.dir_of(rotation.y) * 0.55 - Vector3(0, 0.08, 0)
	if crew_mount() != null:
		muzzle = mounted.mg_muzzle(rotation.y)
	var accm := 1.0
	if blind:
		# the weapon held up over the top, nobody looking down the sights
		muzzle = position + cover_n * 0.55 + Vector3(0, cover_h + 0.12, 0)
		accm *= 0.12
	if moving:
		accm *= 0.55
	if not gun_override.is_empty():
		accm *= 1.15
	if squad:
		accm *= squad.acc_mult()  # shaken men snatch their shots
		if squad.ambush_t > world.time:
			accm *= 1.3  # the first volley of an ambush, at men who didn't know they were there
	accm *= 0.75 + 0.25 * clampf(stamina / 0.5, 0.0, 1.0)  # the muzzle heaving with his breathing
	world.combat.fire_bullet(self, muzzle, aim_pt, aim_ent, w, accm)
	if burst_left <= 0:
		# a man under fire shoots less: longer between bursts the more rounds
		# are cracking past him (that's what winning the firefight means)
		var supp_k := 1.0 + clampf(suppression - 20.0, 0.0, 80.0) / 40.0
		fire_t = world.rng.randf_range(0.5, 1.2) * (2.4 if low else 1.0) * (0.65 if cover_fire else 1.0) * supp_k
	else:
		fire_t = float(w.interval) * world.rng.randf_range(0.9, 1.25)
	if mag <= 0 and reserve > 0 and not infinite:
		_start_reload()


func _start_reload() -> void:
	if reserve <= 0 or reload_t > 0.0:
		return
	reload_t = float(cur_weapon().get("reload", 2.0))
	burst_left = 0
	if world.rng.randf() < 0.3:
		say(_pick(["Reloading!", "Changing mag!", "Cover me, reloading!"]))


func _finish_reload() -> void:
	var take := mini(int(cur_weapon().get("mag", 30)), reserve)
	mag += take
	reserve -= take


# --- special attacks ---------------------------------------------------------------

func _begin_action(kind: String, dur: float, data: Dictionary) -> void:
	act_kind = kind
	act_t = dur
	act_data = data
	stop_moving()
	match kind:
		"throw", "rethrow", "throw_in":
			act = Act.THROW
		"kick", "door_kick":
			act = Act.KICK
		"cook":
			act = Act.COOK
		"melee":
			act = Act.MELEE
		"pickup":
			act = Act.PICKUP
		"launch", "launch_drone", "mortar":
			act = Act.LAUNCH
	if data.has("pos"):
		_face_now(Defs.flat(data.pos - position))
	elif data.has("target") and data.target is Entity:
		_face_now(Defs.flat(data.target.position - position))


func _action_tick(_dt: float) -> void:
	if act_kind == "mortar":
		posture = Post.CROUCH
		return
	if act_kind == "cook":
		return  # holding it in whatever stance he's in
	if act_kind == "kick" or act_kind == "door_kick":
		posture = Post.STAND
		return
	if act_kind == "launch" or act_kind == "throw" or act_kind == "rethrow" or act_kind == "throw_in":
		posture = Post.STAND if act_kind != "launch" else Post.CROUCH
		if act_data.has("target") and act_data.target is Entity and not act_data.target.gone:
			_face_now(Defs.flat(act_data.target.position - position))


func _action_done() -> void:
	var k := act_kind
	act_kind = ""
	act = Act.IDLE
	if k == "cook" and not _queued_throw.is_empty():
		var qt := _queued_throw
		_queued_throw = {}
		_begin_action("throw", 0.6, qt)
		say(_pick(["Frag out!", "Grenade out!", "Fire in the hole!"]), true)
		return
	match k:
		"throw":
			world.combat.throw_grenade(self, act_data.pos, String(act_data.kind), float(act_data.get("fuse", 3.4)))
		"throw_in":
			bt_breach_g = world.combat.throw_grenade_low(self, act_data.pos, float(act_data.get("fuse", 3.4)))
		"kick":
			var kg: Projectile = act_data.get("g")
			if kg and not kg.gone and kg.held_by == null and Defs.flat(kg.position - position).length() < 1.4:
				kg.kick(self, act_data.v)
				world.stat("kicked")
			hit_dirt_t = maxf(hit_dirt_t, 1.6)  # and down
		"pickup":
			var g: Projectile = act_data.get("g")
			if g and not g.gone and g.held_by == self:
				var tp := _rethrow_target(g)
				_begin_action("rethrow", 0.3, {"g": g, "pos": tp})
		"rethrow":
			var g: Projectile = act_data.get("g")
			if g and not g.gone and g.held_by == self:
				g.release_throw(self, act_data.pos)
				world.stat("throwback")
				say("Throwing it back!", true)
		"door_kick":
			var dr: Structure = act_data.get("door")
			if dr and not dr.gone:
				dr.open_door(self, true)
		"melee":
			world.combat.melee_hit(self, act_data.get("target"))
		"launch":
			var t: Entity = act_data.get("target")
			if t and not t.gone:
				world.combat.fire_rocket(self, t)
		"mortar":
			world.combat.fire_mortar(self, position + Vector3(0, 1.0, 0), act_data.pos, String(act_data.kind))
		"launch_drone":
			var t2: Entity = act_data.get("target")
			if t2 and not t2.gone:
				drone_ctrl = world.combat.launch_drone(self, t2)
				if drone_ctrl:
					task = "pilot"


func _rethrow_target(g: Projectile) -> Vector3:
	var src: Entity = world.entity(g.thrower_id)
	if src and not src.gone and src.team != team:
		return src.position
	if squad:
		var lk: Dictionary = squad.last_known_near(position, 30.0, 10.0)
		if not lk.is_empty():
			return lk.pos
	return position + Defs.dir_of(rotation.y) * 18.0


func _try_grenade() -> bool:
	if frags <= 0 or world.time < grenade_cd or suppression > 70.0 or squad == null or squad.ambush:
		return false
	if is_moving():
		return false
	grenade_cd = world.time + 2.5
	var best: Soldier = null
	var best_n := 0
	for k in squad.known.values():
		var e = k.e
		if not (e is Soldier) or e.gone or e.life != Life.ALIVE:
			continue
		if world.time - float(k.t) > 6.0:
			continue
		var d := Defs.flat(e.position - position).length()
		if d < 9.0 or d > 27.0:
			continue
		var hidden: bool = not (e in vis_targets) or e.posture == Post.CROUCH or e.posture == Post.PRONE
		if not hidden:
			continue
		var n := 1
		if e.at_cover and e.cover_mat >= Cover.HARD:
			n += 1  # behind sandbags or stone a rifle won't shift him: a grenade will
		for o in world.soldiers_near(e.position, 4.0):
			if o != e and o.team == e.team and o.life == Life.ALIVE:
				n += 1
		if n > best_n:
			best_n = n
			best = e
	if best == null or world.rng.randf() > 0.3 + 0.12 * best_n:
		return false
	var d2 := Defs.flat(best.position - position).length()
	var tp := best.position + Vector3(world.rng.randf_range(-1, 1), 0, world.rng.randf_range(-1, 1)) * d2 * 0.07
	frags -= 1
	grenade_cd = world.time + world.rng.randf_range(12.0, 20.0)
	world.stat("frag_auto")
	var ck := SoldierBrain.cook_time(self, best, d2)
	if ck > 0.0:
		# held after the spoon flies, so it goes off before they can throw it back
		world.stat("frag_cooked")
		_begin_action("cook", ck, {})
		_queued_throw = {"pos": tp, "kind": "frag", "fuse": 3.4 - ck - 0.6}
		if world.rng.randf() < 0.4:
			say(_pick(["Cooking one!", "Two... three...", "Hold it, hold it..."]), true)
		return true
	_begin_action("throw", 0.6, {"pos": tp, "kind": "frag"})
	say(_pick(["Frag out!", "Grenade out!", "Fire in the hole!"]), true)
	return true


var _queued_throw: Dictionary = {}  # the throw that follows cooking it


func _try_rocket() -> bool:
	if rockets <= 0 or world.time < rocket_cd:
		return false
	if squad and squad.ambush:
		return false
	var tgt: Entity = null
	for e in vis_targets:
		if e is Vehicle and Defs.flat(e.position - position).length() < 75.0:
			tgt = e
			break
	if tgt == null and squad:
		# down in a trench or behind a wall he can't see it himself, but his mates
		# have called it: he pops up, takes aim and fires
		var eye := position + Vector3(0, 1.6 + _ground(), 0)
		for k in squad.known.values():
			var ke = k.e
			if ke is Vehicle and not ke.gone and world.time - float(k.t) < 6.0 and Defs.flat(ke.position - position).length() < 70.0:
				if world.combat.clear_line(eye, ke.center_point(), get_exclude() + ke.get_exclude()):
					tgt = ke
					break
	if tgt == null and forced_target is Structure and not forced_target.gone and Defs.flat(forced_target.position - position).length() < 60.0:
		tgt = forced_target
	if tgt == null:
		return false
	rockets -= 1
	rocket_cd = world.time + 4.5
	world.stat("rocket")
	_begin_action("launch", 0.8, {"target": tgt})
	say("RPG!" if team == 1 else "Rocket out! Backblast clear!", true)
	return true


func _try_drone() -> bool:
	if drones_left <= 0 or world.time < drone_cd or drone_ctrl != null:
		return false
	drone_cd = world.time + 3.0
	var tgt: Entity = world.rules.fpv_target(team, position, 230.0)
	if tgt == null:
		return false
	drones_left -= 1
	drone_cd = world.time + world.rng.randf_range(18.0, 26.0)
	world.stat("drone_launch")
	_begin_action("launch_drone", 1.4, {"target": tgt})
	say("Drone up.", true)
	return true


func _try_melee() -> bool:
	if world.time < melee_cd or wdef.is_empty():
		return false
	for e in world.soldiers_near(position, 1.9):
		if e.team == team or e.team < 0 or e.life != Life.ALIVE or e.flinging:
			continue
		melee_cd = world.time + 1.4
		world.stat("melee")
		_begin_action("melee", 0.55, {"target": e})
		return true
	return false


func _react_grenade(dive_only: bool) -> bool:
	for g in world.projectiles:
		if g.ptype != "frag" or g.held_by != null:
			continue
		var d := Defs.flat(g.position - position).length()
		if d > 7.5:
			continue
		if seen_grenades.has(g.eid):
			continue
		if g.flying and g.fuse > 2.2 and d > 4.0:
			continue
		if seen_grenades.size() > 24:
			seen_grenades.clear()  # old rounds are long gone
		seen_grenades[g.eid] = true
		say(_pick(["GRENADE!", "Grenade! Get down!", "Frag!"]), true)
		if not dive_only and d < 3.8 and g.fuse > 1.8 and g.thrown_back < 1 and suppression < 75.0 and world.rng.randf() < 0.25 and not wdef.is_empty():
			task = "grenade_pickup"
			world.stat("grenade_pickup")
			task_ent = g
			stop_moving()
			return true
		_dive_from(g.position)
		return true
	return false


func _dive_from(p: Vector3) -> void:
	var d := Defs.flat(position - p)
	dive_dir = d.normalized() if d.length() > 0.1 else Defs.dir_of(world.rng.randf() * TAU)
	_face_now(dive_dir)
	dive_t = 0.5
	act = Act.DIVE
	world.stat("dive")
	stop_moving()
	at_cover = false
	peek_up = false


var _fire_flee_t := 0.0


## Too close to a fire: he gets back out of the heat, shouting about it, and
## finds somewhere else to fight from.
func flee_fire(from: Vector3) -> void:
	if life != Life.ALIVE or mounted != null or riding != null or task in ["smother", "stretcher", "tunnel"] or act == Act.DIVE:
		return
	if world.time < _fire_flee_t:
		return
	_fire_flee_t = world.time + 2.5
	var away := Defs.flat(position - from)
	away = away.normalized() if away.length() > 0.1 else Defs.dir_of(world.rng.randf() * TAU)
	var dest := world.nav.nearest_walkable(position + away * 7.0)
	at_cover = false
	peek_up = false
	_clear_cover()
	next_cover_eval = world.time + 2.0
	go_to(dest, "slot", 2)
	world.stat("fire_flee")
	if world.rng.randf() < 0.4:
		say(_pick(["Fire! Get back!", "It's burning! Move!", "Back, back - it's going up!", "Get out of the fire!"]), true)


func _react_drones() -> void:
	for d in world.drones:
		if d.team == team or d.dead:
			continue
		var dist := position.distance_to(d.position)
		if dist > 45.0:
			continue
		if not heard_drones.has(d.eid):
			if heard_drones.size() > 16:
				heard_drones.clear()
			heard_drones[d.eid] = true
			say(_pick(["Drone! Drone!", "I hear a drone!", "FPV inbound!"]), true)
		if d.diving and dist < 9.0 and Defs.flat(d.target_pos - position).length() < 5.5 and world.rng.randf() < 0.8:
			_dive_from(d.position)
			return


func _gpick_tick(dt: float) -> void:
	var g := task_ent as Projectile
	if g == null or g.gone or (g.held_by != null and g.held_by != self):
		task = ""
		return
	if g.fuse < 0.7:
		task = ""
		_dive_from(g.position)
		return
	var to := Defs.flat(g.position - position)
	act = Act.RUN
	posture = Post.STAND
	if to.length() < 0.9:
		g.pick_up(self)
		task = ""
		_begin_action("pickup", 0.2, {"g": g})
		return
	var np := position + to.normalized() * minf(to.length(), 5.0 * dt)
	if world.nav.walkable(np):
		position = np
	_face(to, dt, 14.0)


func _scavenge() -> void:
	if wdef.is_empty() or world.time < scav_t or int(wdef.ammo) >= 9000:
		return
	if total_ammo() >= int(wdef.ammo * 0.65):
		return
	scav_t = world.time + 1.5
	for s in world.soldiers_near(position, 3.2):
		if s.life == Life.DEAD and s.loot > 0:
			var need := int(wdef.ammo) - total_ammo()
			var take := mini(need, s.loot)
			s.loot -= take
			reserve += take
			out_said = false
			world.stat("scavenge")
			low_ammo_said = false
			if world.rng.randf() < 0.6:
				say(_pick(["Grabbing ammo.", "Taking his mags.", "He won't need these."]))
			if mag <= 0:
				_start_reload()
			return


func _seek_resupply() -> bool:
	if world.time < resupply_t:
		return false
	resupply_t = world.time + 6.0
	var best: Soldier = null
	var bd := 25.0
	for s in world.soldiers_near(position, 25.0):
		if s.life == Life.DEAD and s.loot > 0:
			var d := Defs.flat(s.position - position).length()
			if d < bd:
				bd = d
				best = s
	if best:
		task = "resupply"
		world.stat("resupply_body")
		task_ent = best
		go_to(best.position, "task", 1)
		return true
	var f: Structure = world.rules.nearest_fob(team, position)
	var fd := Defs.flat(f.position - position).length() if f else INF
	# a forward ammo cache, if there's one nearer than the FOB
	var cache: Structure = null
	for st in world.structures_near(position, minf(fd, 70.0)):
		if st.skind == "ammo_cache" and st.team == team and st.built and not st.gone:
			var d := Defs.flat(st.position - position).length()
			if d < fd:
				fd = d
				cache = st
	if cache:
		task = "resupply"
		task_ent = cache
		go_to(cache.position + Defs.flat(position - cache.position).normalized() * 2.2 + Vector3(world.rng.randf_range(-1, 1), 0, world.rng.randf_range(-1, 1)), "task", 1)
		say("Back to the ammo cache!", true)
		world.stat("resupply_cache")
		return true
	if f and fd < 90.0:
		task = "resupply"
		task_ent = f
		go_to(f.position + Vector3(world.rng.randf_range(-4, 4), 0, world.rng.randf_range(-4, 4)), "task", 1)
		say("Falling back for ammo!", true)
		world.stat("resupply_fob")
		return true
	return false


func _resupply_tick(dt: float) -> void:
	var t := task_ent
	if t == null or t.gone:
		task = ""
		return
	if _move_tick(dt, _speed()):
		_choose_act(true)
		return
	act = Act.IDLE
	if t is Soldier:
		if t.loot > 0:
			var take := mini(int(wdef.ammo) - total_ammo(), t.loot)
			t.loot -= take
			reserve += take
			say("Got ammo.")
		_return_to_hold()
	elif total_ammo() >= int(wdef.ammo) - 5:
		_return_to_hold()


func resupply(dt: float) -> void:
	if wdef.is_empty() or int(wdef.ammo) >= 9000:
		return
	var mx := int(wdef.ammo)
	if total_ammo() < mx:
		reserve = mini(mx - mag, reserve + int(60.0 * dt) + 1)
		out_said = false
		low_ammo_said = false
		if mag <= 0:
			_start_reload()
	if world.rng.randf() < dt * 0.1:
		frags = mini(int(udef.frags) + (1 if world.rules.has_upgrade(team, "grenades") else 0), frags + 1)
		smokes = mini(int(udef.smokes), smokes + 1)
	if world.rng.randf() < dt * 0.12:
		rockets = mini(int(udef.get("rockets", 0)), rockets + 1)
	if world.rng.randf() < dt * 0.05:
		drones_left = mini(int(udef.get("drones", 0)), drones_left + 1)
	if world.rng.randf() < dt * 0.2:
		mortar_rounds = mini(int(udef.get("mortar", 0)), mortar_rounds + 1)


func _return_to_hold() -> void:
	task = ""
	task_ent = null
	task_ent2 = null
	backwards = false
	at_cover = false
	next_cover_eval = 0.0
	if Defs.flat(position - hold_pos).length() > leash:
		go_to(hold_pos, "slot", 1)


# --- orders (from Squad) ----------------------------------------------------------------

func can_take_orders() -> bool:
	if life != Life.ALIVE:
		return false
	if task in ["stretcher", "captor", "limp", "tunnel"]:
		return false
	if task == "rescue" and task_phase >= 1:
		return false
	return true


func cmd_move(slot: Vector3, mode: int, face: Vector3) -> void:
	if not can_take_orders():
		return
	if task == "breach" and task_phase >= 1:
		# stacked on the door with the pin out: the grenade goes in first, then
		# he comes on to wherever the squad is going (see SoldierBrain)
		hold_pos = slot
		hold_face = face if face.length() > 0.1 else hold_face
		leash = 9.0
		bt_reordered = true
		return
	_clear_task()
	hold_pos = slot
	hold_face = face if face.length() > 0.1 else hold_face
	leash = 9.0
	at_cover = false
	cover_type = Cov.NONE
	_clear_cover()
	peek_up = false
	forced_target = null
	go_to(slot, "slot", mode)


## Contact: down where he is - the best cover a few metres round him - facing
## the enemy, and return fire; the squad moves on when it has the upper hand.
func cmd_halt(face: Vector3) -> void:
	if not can_take_orders() or task != "":
		return
	stop_moving()
	hold_pos = world.nav.nearest_walkable(position)
	hold_face = face if face.length() > 0.1 else hold_face
	leash = 8.0
	at_cover = false
	cover_type = Cov.NONE
	_clear_cover()
	peek_up = false
	next_cover_eval = 0.0


## Keep station in the squad's formation (no change of task, no fuss).
func follow_to(p: Vector3, mode: int, face: Vector3) -> void:
	if not can_take_orders() or task != "":
		return
	hold_pos = p
	hold_face = face
	at_cover = false
	if is_moving() and Defs.flat(goal - p).length() < 3.0:
		move_mode = mode
		return
	go_to(p, "slot", mode)


func cmd_attack(t: Entity, slot: Vector3) -> void:
	if not can_take_orders():
		return
	_clear_task()
	forced_target = t
	hold_pos = slot
	hold_face = Defs.flat(t.position - slot).normalized()
	leash = 10.0
	at_cover = false
	go_to(slot, "slot", 0)


func cmd_retreat(p: Vector3) -> void:
	if life != Life.ALIVE or task in ["stretcher", "captor", "limp", "tunnel"]:
		return
	_clear_task()
	task = "retreat"
	forced_target = null
	hold_pos = p
	at_cover = false
	go_to(p, "task", 2)


func cmd_throw(p: Vector3, kind: String) -> void:
	if not can_take_orders():
		return
	_clear_task()
	task = "throw"
	task_pos = p
	throw_kind = kind
	if Defs.flat(p - position).length() > 24.0:
		go_to(position + Defs.flat(p - position).normalized() * (Defs.flat(p - position).length() - 22.0), "task", 1)


## A direct order from the player to this one soldier. He leaves the squad's
## formation (still shares what it knows) until the squad is given an order.
func unit_order(d: Dictionary) -> void:
	if not can_take_orders():
		return
	var o := String(d.get("o", "move"))
	match o:
		"move":
			var p: Vector3 = d.pos
			var face: Vector3 = d.get("face", Vector3.ZERO)
			if face.length() < 0.1:
				face = Defs.flat(p - position).normalized()
			var q := world.terrain.best_cover_near(p, 2.0, p + face * 40.0, [])
			cmd_move(world.nav.nearest_walkable(q), int(d.get("mode", 0)), face)
			leash = 5.0
		"attack":
			var t = world.entities.get(int(d.get("target", 0)))
			if not (t is Entity) or not t.is_hostile_to(team):
				return
			var w := cur_weapon()
			var rng := float(w.get("range", 40.0)) * 0.8 if not w.is_empty() else 25.0
			var dd: Vector3 = Defs.flat(t.position - position)
			var slot: Vector3 = position if dd.length() <= rng else t.position - dd.normalized() * rng
			cmd_attack(t, world.nav.nearest_walkable(slot))
		"throw":
			var kind := String(d.get("kind", "frag"))
			if kind == "smoke" and smokes <= 0 or kind == "frag" and frags <= 0:
				say("I'm out!", true)
				return
			cmd_throw(d.pos, kind)
		"stop":
			cmd_stop()
		"retreat":
			var f: Structure = world.rules.nearest_fob(team, position)
			if f:
				cmd_retreat(world.nav.nearest_walkable(f.position + Vector3(world.rng.randf_range(-4, 4), 0, world.rng.randf_range(-4, 4))))
		"man":
			var st = world.entities.get(int(d.get("target", 0)))
			if st is Structure and st.team == team and st.built and st.is_mount() and (st.gunner == null or st.gunner.gone or st.gunner.mounted != st):
				start_man(st)
				st.gunner = self
	detached = true
	say(_pick(["On it.", "Moving.", "Copy that.", "Roger.", "Got it.", "Going."]), true)


func cmd_stop() -> void:
	if not can_take_orders():
		return
	_clear_task()
	forced_target = null
	stop_moving()
	hold_pos = position
	at_cover = false
	next_cover_eval = 0.0


func _clear_task() -> void:
	match task:
		"rescue":
			if task_ent is Soldier:
				if task_ent.dragged_by == self:
					task_ent.dragged_by = null
				if task_ent.rescue_claimed == self:
					task_ent.rescue_claimed = null
		"man":
			if mounted:
				release_mount()
				return
		"pilot":
			pass
		"build":
			pass
		"breach":
			if squad and squad.breach_by == self:
				squad.breach_by = null
	task = ""
	task_ent = null
	task_ent2 = null
	backwards = false


func _throw_tick(dt: float) -> void:
	if Defs.flat(task_pos - position).length() <= 25.0:
		var kind := throw_kind
		if kind == "smoke" and smokes <= 0 or kind == "frag" and frags <= 0:
			task = ""
			return
		if kind == "smoke":
			smokes -= 1
			world.stat("smoke")
		else:
			frags -= 1
		task = ""
		_begin_action("throw", 0.6, {"pos": task_pos, "kind": kind})
		say("Smoke out!" if kind == "smoke" else "Frag out!", true)
		return
	if not _move_tick(dt, _speed()):
		task = ""
	_choose_act(true)


func _retreat_tick(dt: float) -> void:
	posture = Post.STAND
	if _move_tick(dt, SPEEDS[2]):
		act = Act.RUN
		return
	task = ""
	act = Act.IDLE
	hold_pos = position
	at_cover = false
	next_cover_eval = 0.0


# --- damage / states ---------------------------------------------------------------------

func add_suppression(amount: float, from_pos: Vector3) -> void:
	if life != Life.ALIVE:
		return
	if task == "retreat":
		amount *= 0.5  # running for it: heads down, legs going
	# cover stops the bullets, not the fear: rounds cracking overhead and
	# smacking into the wall in front of you still keep your head down
	var m := 1.0
	var cap := 100.0
	if mounted and mounted.skind != "watchtower":
		m = 0.5
	elif at_cover and cover_type != Cov.NONE:
		# rounds cracking overhead rattle anyone; rounds thumping into sandbags
		# a foot from your face rattle you less than ones coming through a hedge
		m = Cover.SUPP[cover_mat] if cover_mat >= 0 else 0.62
		if cover_mat >= 0 and not peek_up:
			cap = Cover.SUPP_CAP[cover_mat]
	if _gy < -0.6:
		m *= 0.5  # dug into a trench: the parapet takes it
	suppression = minf(maxf(cap, suppression), suppression + amount * m)
	_supp_t = world.time
	if squad and world.time > reveal_t:
		reveal_t = world.time + 1.0
		squad.report_pos(from_pos)
	if suppression >= 60.0 and world.rng.randf() < 0.05:
		say(_pick(["I'm pinned!", "Can't move!", "Heads down!", "They've got us pinned!"]))


func take_damage(amount: float, src, _dir: Vector3, kind := "bullet") -> void:
	if life == Life.DEAD or life == Life.HIDDEN:
		return
	if world.battle:
		world.battle.soldier_hit(self, amount, src)
	_hit_dir = _dir
	_hit_kind = kind
	if life == Life.DOWNED:
		bleed -= amount * 0.3
		if (kind == "explosion" and amount > 45.0) or bleed <= 0.0 or world.rng.randf() < amount / 300.0:
			_die()
		return
	hp -= amount
	suppression = minf(100.0, suppression + 22.0)
	if src is Entity and squad and not src.gone:
		squad.report(src)
	if hp <= 0.0 and OS.has_environment("FL_DEBUG_DEATH"):
		print("DEATH %s team=%d kind=%s src=%s pos=%s in_trench=%s terrain_trench=%s posture=%d cover=%d at_cover=%s" % [sname, team, kind, (src.ekind() if src is Entity else "?"), str(position.snapped(Vector3.ONE * 0.1)), str(world.in_trench(position)), str(world.terrain.in_trench(position)), posture, cover_type, str(at_cover)])
	if world.settings.get("debug", false) and life == Life.ALIVE:
		# what he was doing when it hit him (tuning the cover game)
		var st := "moving" if is_moving() else ("up" if peek_up else ("cover" if at_cover and cover_type != Cov.NONE else "open"))
		world.stat("t%d_hitwhile_%s%s_%s" % [team, st, ("_" + task) if task != "" else "", Post.keys()[posture]])
	if hp <= 0.0 and world.settings.get("debug", false):
		var who := "unknown"
		if src is Vehicle:
			who = src.vkind
		elif src is Soldier:
			who = src.utype + ("@" + src.mounted.skind if src.mounted else "")
		world.stat("t%d_hit_by_%s_%s" % [team, who, kind])
	if hp <= 0.0 and src is Soldier and src.squad and src.team != team and life == Life.ALIVE:
		src.squad.morale = minf(100.0, src.squad.morale + 3.0)  # winning the firefight
	if hp <= 0.0:
		if life == Life.SURRENDER or life == Life.CAPTIVE or is_bearer() and world.rng.randf() < 0.3:
			_die()
			return
		var over := -hp
		var p_die := 0.14 + over / 150.0 + (0.25 if kind == "explosion" else 0.0)
		if times_downed >= 3:
			p_die = 1.0
		if world.rng.randf() < p_die:
			_die()
		else:
			_go_down()
	elif world.rng.randf() < 0.3:
		say(_pick(["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"]))


func _go_down() -> void:
	_hit_kind = ""
	life = Life.DOWNED
	act = Act.IDLE
	hp = 0.0
	bleed_max = [50.0, 38.0, 26.0, 16.0][mini(times_downed, 3)]
	bleed = bleed_max
	posture = Post.PRONE
	peek_up = false
	blind = false
	_release_all()
	stop_moving()
	scream_t = 0.4
	pistol_t = 2.5
	crawl_t = 1.5
	downed_t = world.time
	world.stat("downed")
	if world.battle:
		world.battle.soldier_down(self)
	stretcher_claimed = false
	rescue_claimed = null
	if squad:
		squad.on_member_down(self)


func _die() -> void:
	if life == Life.DEAD:
		return
	if world.battle:
		world.battle.soldier_died(self)
	life = Life.DEAD
	act = Act.IDLE
	hp = 0.0
	dead_t = world.time
	loot = 0
	world.stat("killed")
	if not wdef.is_empty() and int(wdef.ammo) < 9000:
		loot = maxi(30, total_ammo())
	mag = 0
	reserve = 0
	dragged_by = null
	rescue_claimed = null
	_release_all()
	stop_moving()
	if squad:
		squad.on_member_down(self)
	# once this tick's blast (if any) has thrown him: send how he goes down
	call_deferred("_death_fx")


## The clients turn him into a ragdoll with this impulse: thrown by the blast
## that killed him, knocked back by the round, or he just slumps.
func _death_fx() -> void:
	if gone:
		return
	var kind := 2
	var imp := Vector3.ZERO
	var d := Defs.flat(_hit_dir)
	d = d.normalized() if d.length() > 0.05 else Defs.dir_of(rotation.y + PI)
	if flinging:
		kind = 1
		imp = fling_v
	elif _hit_kind == "explosion":
		kind = 1
		imp = d * 4.0 + Vector3.UP * 2.5
	elif _hit_kind in ["bullet", "melee"]:
		kind = 0
		imp = d * 2.6 + Vector3.UP * 0.4
	world.fx_event([Fx.DIE, eid, imp, kind])


func _release_all() -> void:
	if task == "rescue" and task_ent is Soldier:
		if task_ent.dragged_by == self:
			task_ent.dragged_by = null
		if task_ent.rescue_claimed == self:
			task_ent.rescue_claimed = null
	if task == "stretcher" and task_ent is Soldier:
		task_ent.carried_by.erase(self)
	if mounted:
		mounted = null
		gun_override = {}
		base_y = 0.0
	if drone_ctrl and not drone_ctrl.gone:
		drone_ctrl.lose_control()
	drone_ctrl = null
	if task == "breach" and squad and squad.breach_by == self:
		squad.breach_by = null
	_queued_throw = {}
	task = ""
	task_ent = null
	task_ent2 = null
	backwards = false
	act_t = 0.0
	act_kind = ""


func revive(full := false) -> void:
	times_downed += 1
	world.stat("revived")
	if world.battle:
		world.battle.revived(self)
	life = Life.ALIVE
	var mult: float = [1.0, 0.8, 0.62, 0.45, 0.35][mini(times_downed, 4)]
	max_hp = base_hp * mult
	hp = max_hp * (1.0 if full else 0.85)
	act = Act.IDLE
	posture = Post.CROUCH
	suppression = 25.0
	dragged_by = null
	rescue_claimed = null
	carried_by.clear()
	stretcher_claimed = false
	at_cover = false
	next_cover_eval = 0.0
	if position.y < world.ground_y(position):
		position.y = world.ground_y(position)
	if wdef.is_empty() and Defs.WEAPONS.has(udef.weapon):
		wdef = Defs.WEAPONS[udef.weapon]
		mag = int(wdef.mag)
		reserve = 0
	world.push_props(self, {"max_hp": max_hp})
	say(_pick(["Thanks, doc.", "I'm good, I'm good!", "Back in the fight.", "Ugh... let's go."]), true)


func fling_from(c: Vector3, power: float) -> void:
	if life == Life.HIDDEN or power <= 0.8 or not carried_by.is_empty() or flinging:
		return
	var d := Defs.flat(position - c)
	var dir := d.normalized() if d.length() > 0.05 else Defs.dir_of(world.rng.randf() * TAU)
	fling_v = dir * power + Vector3.UP * (2.5 + power * 0.45)
	world.stat("flung")
	flinging = true
	act = Act.FLUNG
	if dragged_by:
		dragged_by = null
	if life == Life.ALIVE:
		_release_all()
	stop_moving()


func _fling_tick(dt: float) -> void:
	act = Act.FLUNG
	var np := position + fling_v * dt
	if not world.nav.walkable(np) and np.y < world.ground_y(np) + 1.5:
		fling_v.x = -fling_v.x * 0.2
		fling_v.z = -fling_v.z * 0.2
		np = position + Vector3(0, fling_v.y * dt, 0)
	position = np
	fling_v.y -= 20.0 * dt
	if position.y <= world.ground_y(position) and fling_v.y < 0.0:
		position.y = world.ground_y(position)
		flinging = false
		act = Act.IDLE
		if life == Life.ALIVE:
			dazed_t = world.rng.randf_range(2.5, 5.0)
			world.stat("dazed")
			posture = Post.STAND
			task_t = 0.0
			if world.rng.randf() < 0.5:
				say(_pick(["...my ears...", "What... what happened?", "Ugh..."]), true)


func flinch_from(_c: Vector3, dist: float, max_r: float) -> void:
	if life != Life.ALIVE or flinging or dazed_t > 0.0:
		return
	suppression = minf(100.0, suppression + 45.0 * (1.0 - dist / max_r))
	if dist < max_r * 0.75 and act_t <= 0.0 and dive_t <= 0.0 and task != "stretcher" and not (task == "rescue" and task_phase >= 1):
		flinch_t = 0.5
		act = Act.FLINCH


func _dazed_tick(dt: float) -> void:
	dazed_t -= dt
	act = Act.DAZED
	posture = Post.STAND
	task_t -= dt
	if task_t <= 0.0:
		task_t = world.rng.randf_range(0.6, 1.3)
		dive_dir = Defs.dir_of(world.rng.randf() * TAU)
	var np := position + dive_dir * 0.8 * dt
	if world.nav.walkable(np):
		position = np
	_face(dive_dir, dt, 2.0)
	if dazed_t <= 0.0:
		act = Act.IDLE
		at_cover = false
		next_cover_eval = 0.0


func surrender() -> void:
	if life != Life.ALIVE:
		return
	_release_all()
	life = Life.SURRENDER
	world.stat("surrender")
	act = Act.HANDSUP
	posture = Post.STAND
	stop_moving()
	world.fx_event([Fx.RIFLE_DROP, position + Vector3(0, 1.2, 0), Defs.dir_of(rotation.y + PI * 0.5)])
	say(_pick(["Don't shoot! I surrender!", "I give up! I give up!", "Okay! Okay! Don't shoot!"]), true)
	if squad:
		squad.remove(self)
	wdef = {}
	mag = 0
	reserve = 0
	world.send_msg(team, "alert", "%s has surrendered at %s." % [sname, Defs.grid_ref(position)], position)
	world.send_msg(1 - team, "info", "An enemy soldier is surrendering at %s." % Defs.grid_ref(position), position)


# --- downed / dead / captive / hidden -------------------------------------------------------

func _downed(dt: float) -> void:
	var rate := 1.0
	if dragged_by or not carried_by.is_empty():
		rate = 0.35
	if world.rules.has_upgrade(team, "medicine"):
		rate *= 0.67
	bleed -= dt * rate
	if bleed <= 0.0:
		_die()
		return
	if dragged_by and (dragged_by.gone or dragged_by.life != Life.ALIVE or dragged_by.task != "rescue"):
		dragged_by = null
	if not carried_by.is_empty():
		var ok := false
		for b in carried_by:
			if is_instance_valid(b) and not b.gone and b.life == Life.ALIVE:
				ok = true
		if not ok:
			carried_by.clear()
	scream_t -= dt
	if scream_t <= 0.0:
		scream_t = world.rng.randf_range(4.0, 8.0)
		say(_pick(["MEDIC!", "I'm hit! Medic!", "Help me!", "Medic! Over here!", "Argh! I'm hit!", "Somebody help!"]), true)
	if not carried_by.is_empty():
		act = Act.CARRIED
		return
	pistol_t -= dt
	if pistol_t <= 0.0:
		pistol_t = world.rng.randf_range(0.9, 1.7)
		_pistol_fire()
	if dragged_by:
		act = Act.DRAGGED
		return
	position.y = lerpf(position.y, _ground(), 1.0 - exp(-dt * 8.0))
	if goal_kind == "crawl" and is_moving():
		act = Act.CRAWL
		_move_tick(dt, 0.55)
		return
	act = Act.PISTOL if world.time - last_shot_t < 0.6 else Act.IDLE
	crawl_t -= dt
	if crawl_t <= 0.0:
		crawl_t = 3.0
		if bleed > bleed_max * 0.5:
			var threats := _threats()
			if world.combat.prot_at(position, threats, 0.3) < 0.99:
				var res: Dictionary = world.combat.find_cover(self, position, 8.0, threats, true)
				if not res.is_empty() and Defs.flat(res.pos - position).length() > 0.8:
					go_to(res.pos, "crawl", 0)
					world.stat("crawl_to_cover")


func _pistol_fire() -> void:
	var eye := position + Vector3(0, 0.45, 0)
	var best: Entity = null
	var bd := 22.0
	for e in world.soldiers_near(position, 22.0):
		if e.team == team or e.team < 0 or e.life != Life.ALIVE:
			continue
		var d := Defs.flat(e.position - position).length()
		if d < bd and world.combat.can_see_from(eye, e, []):
			bd = d
			best = e
	if best == null:
		return
	if dragged_by == null:
		_face_now(Defs.flat(best.position - position))
	world.stat("pistol_while_down")
	last_shot_t = world.time
	world.combat.fire_bullet(self, eye + Defs.flat(best.position - position).normalized() * 0.4, _aim_point(best), best, PISTOL, 0.75)


func _dead(_dt: float) -> void:
	position.y = lerpf(position.y, _ground(), 0.2) if carried_by.is_empty() else position.y
	if not carried_by.is_empty():
		act = Act.CARRIED
		var ok := false
		for b in carried_by:
			if is_instance_valid(b) and not b.gone and b.life == Life.ALIVE:
				ok = true
		if not ok:
			carried_by.clear()
			act = Act.IDLE
		return
	act = Act.IDLE
	if world.time - dead_t > 300.0 and not stretcher_claimed:
		world.despawn(self)


func _captive(dt: float) -> void:
	act = Act.HANDSUP
	posture = Post.STAND
	if life == Life.CAPTIVE and is_moving():
		_move_tick(dt, 1.7)


func hide_in(reason: String, t: float, where: Structure) -> void:
	life = Life.HIDDEN
	hidden_reason = reason
	hidden_t = t
	hidden_in = where
	stop_moving()
	carried_by.clear()
	dragged_by = null
	if where:
		position = where.position


func unhide(p: Vector3) -> void:
	life = Life.ALIVE
	hidden_reason = ""
	hidden_in = null
	position = world.nav.nearest_walkable(p)
	position.y = world.ground_y(position)
	act = Act.IDLE
	at_cover = false
	next_cover_eval = 0.0
	hold_pos = position


func _hidden(dt: float) -> void:
	if hidden_reason == "vehicle":
		if riding != null and is_instance_valid(riding) and not riding.gone:
			position = riding.position
			return
		# the vehicle's gone: bail out wherever it was
		riding = null
		unhide(position)
		return
	hidden_t -= dt
	if hidden_t > 0.0:
		return
	match hidden_reason:
		"tent":
			_leave_tent()
		"tunnel_travel":
			if hidden_in and is_instance_valid(hidden_in):
				hidden_in.inside.erase(self)
			unhide(task_pos)
		"interrogation", "held":
			world.rules.prisoner_done(self)
		_:
			hidden_t = 9999.0


func enter_tent(tent: Structure) -> void:
	tent_dead = life == Life.DEAD
	world.stat("into_tent")
	if squad:
		squad.remove(self)
	hide_in("tent", 35.0 if tent_dead else 20.0, tent)


func _leave_tent() -> void:
	var tent := hidden_in
	world.stat("out_of_tent")
	life = Life.ALIVE
	revive(true)
	var p: Vector3 = tent.exit_pos() if tent and not tent.gone else position
	unhide(p)
	var f: Structure = world.rules.nearest_fob(team, position)
	task = "limp"
	go_to(f.position + Vector3(world.rng.randf_range(-5, 5), 0, world.rng.randf_range(-5, 5)) if f else position, "task", 0)
	world.send_msg(team, "info", "%s is patched up and limping back to base." % sname)


func _limp_tick(dt: float) -> void:
	posture = Post.STAND
	if _move_tick(dt, 1.3):
		act = Act.LIMP
		return
	act = Act.IDLE
	task = ""
	world.rules.rejoin_squad(self)


# --- squad tasks -----------------------------------------------------------------------------

func start_rescue(w: Soldier) -> void:
	_clear_task()
	task = "rescue"
	task_ent = w
	task_phase = 0
	w.rescue_claimed = self
	posture = Post.STAND
	go_to(w.position, "task", 2)
	world.stat("rescue")


func _rescue_tick(dt: float) -> void:
	var w := task_ent as Soldier
	if w == null or w.gone or w.life != Life.DOWNED or (w.dragged_by != null and w.dragged_by != self) or not w.carried_by.is_empty():
		_end_rescue()
		return
	match task_phase:
		0:
			posture = Post.STAND
			if Defs.flat(w.position - position).length() < 1.2:
				task_phase = 1
				w.dragged_by = self
				task_pos = _safe_spot(w)
				world.stat("drag")
				go_to(task_pos, "task", 0)
				if path.is_empty():
					task_phase = 2
					task_t = heal_time()
				say(_pick(["I've got you!", "Hang on, I've got you!", "Grab on!", "Moving him!"]), true)
				return
			if not is_moving() or w.position.distance_to(goal) > 1.5:
				go_to(w.position, "task", 2)
			_move_tick(dt, 4.8)
			act = Act.RUN
		1:
			backwards = true
			posture = Post.STAND
			var moved := _move_tick(dt, 1.15)
			var f := -_last_dir
			_face(f, dt, 12.0)
			w.position = position + Defs.dir_of(rotation.y) * 1.05
			w.position.y = world.ground_y(w.position)
			w.rotation.y = rotation.y
			act = Act.DRAG
			if not moved:
				task_phase = 2
				task_t = heal_time()
				backwards = false
		2:
			act = Act.HEAL
			posture = Post.CROUCH
			w.dragged_by = null
			_face(Defs.flat(w.position - position), dt, 8.0)
			task_t -= dt
			if task_t <= 0.0:
				w.revive()
				world.stat("patched_up")
				_end_rescue()


func heal_time() -> float:
	var t := 8.0 / float(udef.get("heal", 1.0))
	if world.rules.has_upgrade(team, "medicine"):
		t *= 0.67
	return t


func _end_rescue() -> void:
	var w := task_ent as Soldier
	if w:
		if w.dragged_by == self:
			w.dragged_by = null
		if w.rescue_claimed == self:
			w.rescue_claimed = null
	task = ""
	task_ent = null
	backwards = false
	at_cover = false
	next_cover_eval = 0.0


func _safe_spot(w: Soldier) -> Vector3:
	var threats := _threats()
	var away := -_threat_dir(threats)
	var anchor := w.position + away * 11.0
	if squad and squad.members.size() > 0:
		var c := squad.order_pos
		if Defs.flat(c - w.position).length() < 22.0 and Defs.flat(c - w.position).dot(away) > 0.0:
			anchor = c
	anchor = world.nav.nearest_walkable(anchor)
	var res: Dictionary = world.combat.find_cover(self, anchor, 8.0, threats, true)
	if not res.is_empty():
		return res.pos
	return anchor


func start_escort(w: Soldier, rescuer: Soldier) -> void:
	_clear_task()
	task = "escort"
	world.stat("escort")
	task_ent = w
	task_ent2 = rescuer


func _escort_tick(dt: float) -> void:
	var r := task_ent2 as Soldier
	var w := task_ent as Soldier
	if r == null or r.gone or r.life != Life.ALIVE or r.task != "rescue" or r.task_phase == 2 or w == null or w.gone:
		task = ""
		backwards = false
		at_cover = false
		next_cover_eval = 0.0
		return
	var thr := _threat_dir(_threats())
	var side := thr.cross(Vector3.UP).normalized()
	if side.dot(Defs.flat(position - r.position)) < 0.0:
		side = -side
	var want := r.position + side * 1.6 + thr * 0.9
	var to := Defs.flat(want - position)
	var spd := 4.4 if to.length() > 3.0 else 1.3
	var np := position + to.normalized() * minf(to.length(), spd * dt)
	if to.length() > 0.2 and world.nav.walkable(np):
		position = np
	backwards = to.length() > 0.2 and to.normalized().dot(thr) < 0.0
	_face(thr, dt, 8.0)
	_weapon_tick(dt, false, "escort")
	if world.time - last_shot_t < 0.35:
		act = Act.SHOOT
	else:
		act = Act.WALK if to.length() > 0.2 else Act.IDLE


func start_heal(w: Soldier) -> void:
	_clear_task()
	task = "heal"
	task_ent = w
	task_phase = 0
	go_to(w.position, "task", 0)


func _heal_tick(dt: float) -> void:
	var w := task_ent as Soldier
	if w == null or w.gone or w.life != Life.ALIVE or w.hp >= w.max_hp:
		task = ""
		return
	if task_phase == 0:
		if Defs.flat(w.position - position).length() < 1.4:
			task_phase = 1
			task_t = heal_time() * 0.6
			stop_moving()
		else:
			if not is_moving():
				go_to(w.position, "task", 0)
			_move_tick(dt, _speed())
			_choose_act(true)
		return
	act = Act.HEAL
	posture = Post.CROUCH
	_face(Defs.flat(w.position - position), dt, 8.0)
	task_t -= dt
	if task_t <= 0.0:
		w.hp = w.max_hp
		task = ""


func start_build(st: Entity) -> void:
	_clear_task()
	task = "build"
	task_ent = st
	task_phase = 0
	task_pos = _work_spot(st)
	go_to(task_pos, "task", 1)


func _work_spot(st: Entity) -> Vector3:
	if st is Structure and not st.cover_pts.is_empty():
		var arr := []
		for p in st.cover_pts:
			arr.append([Defs.flat(p - position).length(), p])
		arr.sort_custom(func(a, b): return a[0] < b[0])
		var n := mini(5, arr.size())
		return arr[world.rng.randi() % n][1]
	var r: float = st.radius + 0.8 if st is Structure else 2.6
	var d := Defs.flat(position - st.position)
	if d.length() < 0.1:
		d = Vector3.FORWARD
	return world.nav.nearest_walkable(st.position + d.normalized().rotated(Vector3.UP, world.rng.randf_range(-0.8, 0.8)) * r)


func _build_tick(dt: float) -> void:
	var st := task_ent
	var done := st == null or st.gone
	if not done:
		if st is Structure:
			done = not st.needs_work()
		elif st is Vehicle:
			done = not st.needs_repair()
	if done:
		task = ""
		if squad:
			squad.on_build_done(st)
		return
	if suppression > 55.0:
		posture = Post.CROUCH
		act = Act.IDLE
		_weapon_tick(dt, false, "normal")
		return
	if is_moving():
		_move_tick(dt, _speed())
		_choose_act(true)
		return
	if Defs.flat(position - task_pos).length() > 1.6:
		go_to(task_pos, "task", 1)
		return
	if _target_valid(target) and Defs.flat(target.position - position).length() < 18.0:
		_weapon_tick(dt, false, "normal")
		_choose_act(false)
		return
	_face(Defs.flat(st.position - position), dt, 8.0)
	act = Act.BUILD
	posture = Post.CROUCH
	var rate := float(udef.get("build", 1.0))
	if st is Structure:
		st.add_work(rate * dt)
	elif st is Vehicle:
		st.repair(rate * dt)
	build_snd_t -= dt
	if build_snd_t <= 0.0:
		build_snd_t = world.rng.randf_range(0.5, 0.9)
		world.fx_event([Fx.SOUND, "build", position])


func start_stretcher(cas: Soldier, partner: Soldier, tent: Structure, front: bool) -> void:
	_clear_task()
	task = "stretcher"
	task_ent = cas
	task_ent2 = partner
	task_phase = 0
	home = tent
	is_front = front
	world.stat("stretcher_job")
	var off := Vector3(1.1 if front else -1.1, 0, 0)
	go_to(cas.position + off, "task", 1)


func _stretcher_valid(cas: Soldier) -> bool:
	if cas == null or cas.gone or cas.life == Life.HIDDEN:
		return false
	if cas.life != Life.DOWNED and cas.life != Life.DEAD:
		return false
	if cas.dragged_by != null:
		return false
	return true


func _stretcher_tick(dt: float) -> void:
	var cas := task_ent as Soldier
	var partner := task_ent2 as Soldier
	var partner_ok := partner != null and not partner.gone and partner.life == Life.ALIVE and partner.task == "stretcher" and partner.task_ent == cas
	if home == null or home.gone or not _stretcher_valid(cas):
		_end_stretcher(false)
		return
	posture = Post.STAND
	match task_phase:
		0:
			if is_moving():
				_move_tick(dt, 4.4)
				act = Act.RUN
				return
			if Defs.flat(cas.position - position).length() > 1.8:
				go_to(cas.position, "task", 1)
				return
			task_phase = 1
			task_t = 1.4
		1:
			act = Act.PICKUP
			task_t -= dt
			if partner_ok and partner.task_phase == 0 and task_t > -8.0:
				return
			if task_t > 0.0:
				return
			if is_front or not partner_ok:
				task_phase = 2
				cas.carried_by = [self]
				if partner_ok:
					cas.carried_by.append(partner)
					partner.task_phase = 3
				go_to(home.exit_pos(), "task", 0)
				say("Lift on three!" if partner_ok else "I've got him!", true)
		2:
			var solo := not partner_ok
			var moved := _move_tick(dt, 0.95 if solo else 1.9)
			if solo:
				backwards = true
				act = Act.DRAG
				_face(-_last_dir, dt, 10.0)
				cas.position = position + Defs.dir_of(rotation.y) * 1.5 + Vector3(0, -0.55, 0)
				cas.rotation.y = rotation.y
				if cas.carried_by.size() > 1:
					cas.carried_by = [self]
					say("Bearer down! I'll drag him!", true)
			else:
				backwards = false
				act = Act.CARRY
				cas.position = position - _last_dir * 1.15
				cas.position.y = world.ground_y(cas.position)
				cas.rotation.y = Defs.yaw_of(-_last_dir)
			if not moved:
				var c := cas
				_end_stretcher(true)
				if partner_ok:
					partner._end_stretcher(true)
				c.enter_tent(home)
		3:
			if not partner_ok or partner.task_phase != 2:
				task_phase = 2
				cas.carried_by = [self]
				go_to(home.exit_pos(), "task", 0)
				return
			var md := Defs.dir_of(partner.rotation.y)
			var want := partner.position - md * 2.3
			position = position.lerp(want, 1.0 - exp(-dt * 10.0))
			position.y = world.ground_y(position)
			rotation.y = partner.rotation.y
			act = Act.CARRY


func _end_stretcher(delivered: bool) -> void:
	var cas := task_ent as Soldier
	if cas and not cas.gone:
		cas.carried_by.erase(self)
		if cas.carried_by.is_empty() and not delivered:
			cas.stretcher_claimed = false
			cas.position.y = world.ground_y(cas.position)
	task = ""
	task_ent = null
	task_ent2 = null
	backwards = false
	if home and not home.gone:
		go_to(home.exit_pos() + Vector3(world.rng.randf_range(-2, 2), 0, world.rng.randf_range(-2, 2)), "slot", 0)


func start_captor(p: Soldier) -> void:
	_clear_task()
	task = "captor"
	world.stat("captor")
	task_ent = p
	task_phase = 0
	go_to(p.position, "task", 1)


func _captor_tick(dt: float) -> void:
	var p := task_ent as Soldier
	if p == null or p.gone or (p.life != Life.SURRENDER and p.life != Life.CAPTIVE) or p.captor != self:
		_return_to_hold()
		return
	posture = Post.STAND
	match task_phase:
		0:
			if Defs.flat(p.position - position).length() < 2.6:
				task_phase = 1
				world.rules.take_prisoner(p, self)
				say(_pick(["Move! Hands where I can see them!", "On your feet! Walk!", "Easy... keep those hands up."]), true)
				return
			if not is_moving():
				go_to(p.position, "task", 1)
			_move_tick(dt, 4.0)
			act = Act.RUN
		1:
			var d := Defs.flat(p.position - position)
			if d.length() > 2.3:
				var np := position + d.normalized() * minf(d.length() - 2.0, 1.9 * dt)
				if world.nav.walkable(np):
					position = np
				else:
					position = position.lerp(p.position, 0.02)
				act = Act.WALK
			else:
				act = Act.SHOOT if world.rng.randf() < 0.0 else Act.IDLE
			_face(d, dt, 8.0)


func start_man(st: Structure) -> void:
	_clear_task()
	task = "man"
	world.stat("manned")
	task_ent = st
	mounted = st
	task_phase = 0
	go_to(Vector3(st.mount_pos().x, 0, st.mount_pos().z) + (Defs.flat(position - st.position).normalized() * 1.8 if st.skind == "watchtower" else Vector3.ZERO), "task", 1)


func release_mount() -> void:
	var st := mounted
	mounted = null
	gun_override = {}
	if base_y > 0.0 and st:
		position = world.nav.nearest_walkable(st.position + Vector3(2.0, 0, 0))
	base_y = 0.0
	position.y = world.ground_y(position)
	task = ""
	task_ent = null
	at_cover = false
	cover_type = Cov.NONE
	_clear_cover()
	next_cover_eval = 0.0


func _man_tick(dt: float) -> void:
	var st := task_ent as Structure
	if st == null or st.gone or not st.built:
		release_mount()
		return
	match task_phase:
		0:
			if is_moving():
				_move_tick(dt, _speed())
				_choose_act(true)
				return
			if st.skind == "watchtower":
				task_phase = 1
				task_t = 1.6
				position = st.position
			else:
				task_phase = 2
				position = st.mount_pos()
				gun_override = st.mount_weapon()
				match st.skind:
					"mortar_pit":
						say("On the mortar!", true)
					"at_post":
						say("AT post manned!", true)
					_:
						say("Manning the gun!", true)
		1:
			task_t -= dt
			act = Act.CLIMB
			position.y = st.position.y + lerpf(0.0, 4.25, clampf(1.0 - task_t / 1.6, 0.0, 1.0))
			if task_t <= 0.0:
				task_phase = 2
				base_y = 4.25
				position = st.mount_pos()
	if task_phase != 2:
		return
	position = st.mount_pos()
	match st.skind:
		"mortar_pit":
			_mortar_pit_tick(dt, st)
			return
		"at_post":
			_at_post_tick(dt, st)
			return
		"mg_nest", "hmg_nest":
			at_cover = true
			cover_type = Cov.LOW
			cover_threat = _threat_dir(_threats())
			_weapon_tick(dt, false, "crew")
			_choose_act(false)
			return
	at_cover = true
	cover_type = Cov.LOW
	cover_threat = _threat_dir(_threats())
	_weapon_tick(dt, false, "normal")
	_choose_act(false)


func _mortar_pit_tick(dt: float, st: Structure) -> void:
	posture = Post.CROUCH
	act = Act.LAUNCH if world.time - last_shot_t < 0.7 else Act.IDLE
	if world.time < mortar_cd:
		return
	var tp := Vector3.INF
	var kind := "he"
	if not st.fire_queue.is_empty():
		var fm: Array = st.fire_queue.pop_front()
		tp = fm[0]
		kind = fm[1]
		mortar_cd = world.time + 2.2
	else:
		mortar_cd = world.time + 2.0
		tp = world.rules.mortar_target(team, st.position, 30.0, 160.0)
		if tp == Vector3.INF:
			_face(st.front_dir(), dt, 3.0)
			return
		mortar_cd = world.time + 5.0
	_face_now(Defs.flat(tp - position))
	last_shot_t = world.time
	world.combat.fire_mortar(self, st.position + Vector3(0, 1.0, 0), tp, kind)


func _at_post_tick(_dt: float, st: Structure) -> void:
	posture = Post.CROUCH
	act = Act.LAUNCH if world.time - last_shot_t < 1.0 else Act.IDLE
	if world.time < rocket_cd:
		return
	rocket_cd = world.time + 0.7
	var eye := st.position + Vector3(0, 1.3, 0)
	var best: Vehicle = null
	var bd := 130.0
	for v in world.vehicles:
		if v.team == team or v.team < 0 or not v.visible_to_team(team):
			continue
		var d: float = Defs.flat(v.position - st.position).length()
		if d > bd or not world.combat.can_see_from(eye, v, []):
			continue
		bd = d
		best = v
	if best == null:
		return
	var dir := Defs.flat(best.position - st.position).normalized()
	_face_now(dir)
	rocket_cd = world.time + 7.0
	last_shot_t = world.time
	world.combat.fire_at(self, eye + dir * 0.9, best, team == Defs.ARMY)
	say("Missile away!" if team == Defs.ARMY else "Recoilless, fire!")


## Mobile mortar teams: fire missions first, otherwise shell spotted enemies.
func _try_mortar() -> bool:
	if mortar_rounds <= 0 or world.time < mortar_cd or is_moving() or squad == null:
		return false
	var tp := Vector3.INF
	var kind := "he"
	if not squad.fire_queue.is_empty():
		var fm: Array = squad.fire_queue.pop_front()
		tp = fm[0]
		kind = fm[1]
		var d := Defs.flat(tp - position).length()
		if d < 25.0 or d > 140.0:
			squad.fire_queue.clear()
			say("Target's out of range!", true)
			return false
	else:
		mortar_cd = world.time + 2.0
		tp = world.rules.mortar_target(team, position, 30.0, 130.0)
		if tp == Vector3.INF:
			return false
	mortar_rounds -= 1
	mortar_cd = world.time + 3.5
	_begin_action("mortar", 1.0, {"pos": tp, "kind": kind})
	if world.rng.randf() < 0.4:
		say(_pick(["Rounds out!", "Firing for effect!", "Hang it!"]))
	return true


## Incoming mortar rounds whistle: duck, or dive if it's landing right here.
func _react_shells(dive_only: bool) -> bool:
	for g in world.projectiles:
		if g.ptype != "mortar" or seen_grenades.has(g.eid):
			continue
		var rem: float = g.shell_t - g.life_t
		if rem > 1.6:
			continue
		var d := Defs.flat(g.target - position).length()
		if d > 14.0:
			continue
		seen_grenades[g.eid] = true
		say(_pick(["Incoming!", "INCOMING!", "Mortars! Get down!"]), d < 8.0)
		suppression = minf(100.0, suppression + 20.0)
		if d < 4.5 and not dive_only:
			_dive_from(g.target)
			return true
		hit_dirt_t = 2.5
	return false


func cmd_garrison(st: Structure) -> void:
	if not can_take_orders():
		return
	cmd_move(st.position, 1, st.front_dir())
	leash = 2.6


## Go and climb into a friendly vehicle.
func order_board(v: Vehicle) -> void:
	if not can_take_orders():
		return
	_clear_task()
	task = "board"
	task_ent = v
	go_to(v.position, "task", 1)


func _board_tick(dt: float) -> void:
	var v := task_ent as Vehicle
	if v == null or v.gone or v.seats_free() <= 0 or (v.is_heli() and v.position.y - world.ground_y(v.position) > 1.0):
		task = ""
		return
	var d := Defs.flat(v.position - position).length()
	var boat := v.is_boat()
	if d < 3.6 or (boat and (d < 8.0 or (d < 18.0 and not is_moving()))):
		task = ""
		v.board(self)
		return
	var moving := _move_tick(dt, _speed())
	if boat and not moving and Defs.flat(v.position - position).length() < 18.0:
		# waded out as far as he can: hauled over the side
		task = ""
		v.board(self)
		return
	if not moving or Defs.flat(goal - v.position).length() > 3.0:
		go_to(v.position, "task", 1)
	_choose_act(true)


func order_tunnel(st: Structure) -> void:
	if not can_take_orders():
		return
	_clear_task()
	task = "tunnel"
	task_ent = st
	go_to(st.position, "task", 1)


func _tunnel_tick(dt: float) -> void:
	var st := task_ent as Structure
	if st == null or st.gone or not st.built:
		task = ""
		return
	if _move_tick(dt, _speed()):
		_choose_act(true)
		return
	if Defs.flat(st.position - position).length() > 2.5:
		go_to(st.position, "task", 1)
		return
	task = ""
	hide_in("tunnel_wait", 9999.0, st)
	world.stat("tunnel_in")
	st.inside.append(self)
	st.net_dirty = true


func _pilot_tick(dt: float) -> void:
	posture = Post.CROUCH
	act = Act.LAUNCH
	if drone_ctrl == null or drone_ctrl.gone or drone_ctrl.dead:
		drone_ctrl = null
		task = ""
		return
	_face(Defs.flat(drone_ctrl.position - position), dt, 4.0)


# --- replication -------------------------------------------------------------------------

func write_state(b: StreamPeerBuffer) -> void:
	put_v3(b, position)
	put_ang(b, rotation.y)
	b.put_u8(life)
	b.put_u8(posture)
	b.put_u8(act)
	b.put_u8(flags)
	b.put_u8(int(clampf(hp / maxf(1.0, max_hp), 0.0, 1.0) * 255.0) if life == Life.ALIVE else int(clampf(bleed / maxf(1.0, bleed_max), 0.0, 1.0) * 255.0))
	b.put_u16(sid)
	b.put_u8(vis_mask)
	b.put_u8(int(suppression))
	var w := cur_weapon()
	b.put_u8(255 if w.is_empty() or int(w.ammo) >= 9000 else int(clampf(float(total_ammo()) / float(w.ammo), 0.0, 1.0) * 255.0))
	b.put_8(team)
	b.put_u8(doing)
	b.put_u32(doing_ent)
	b.put_u8(cov_code())


func read_state(b: StreamPeerBuffer) -> void:
	net_pos = get_v3(b)
	net_yaw = get_ang(b)
	life = b.get_u8()
	posture = b.get_u8()
	act = b.get_u8()
	flags = b.get_u8()
	hp_frac = b.get_u8() / 255.0
	sid = b.get_u16()
	vis_mask = b.get_u8()
	supp_net = b.get_u8()
	ammo_frac = b.get_u8() / 255.0
	team = b.get_8()
	doing = b.get_u8()
	doing_ent = b.get_u32()
	cov_net = b.get_u8()


var _was_on_gun := false


## Where his shots visibly leave his weapon (view): the crew-served gun's
## muzzle when he's on one, otherwise the muzzle of the weapon in his hands.
func muzzle_world() -> Vector3:
	var cm := crew_mount()
	if cm != null:
		return cm.crew_muzzle_world()
	if model == null or not is_visible_in_tree():
		return Vector3.INF
	return model.muzzle_world()


## The crew-served gun this man is working (server: his mount once he's on
## it; clients: what he's reported manning, once he's in place behind it).
func crew_mount() -> Structure:
	var st = mounted if srv else world.entity(doing_ent)
	if st is Structure and st.skind in ["mg_nest", "hmg_nest"] and not st.gone and Defs.flat(position - st.mount_pos()).length() < 0.8:
		return st
	return null


## A body lying still is sent like a building: when it changes, and now and then.
func is_static() -> bool:
	return life == Life.DEAD and not flinging and act != Act.CARRIED and act != Act.DRAGGED


func health_frac() -> float:
	if srv:
		if life == Life.ALIVE:
			return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		if life == Life.DOWNED:
			return clampf(bleed / maxf(1.0, bleed_max), 0.0, 1.0)
		return 0.0
	return hp_frac


func ammo_fraction() -> float:
	if srv:
		var w := cur_weapon()
		if w.is_empty() or int(w.ammo) >= 9000:
			return 1.0
		return clampf(float(total_ammo()) / float(w.ammo), 0.0, 1.0)
	return ammo_frac


func supp_value() -> float:
	return suppression if srv else supp_net


# --- view ----------------------------------------------------------------------------------

var _corpse_t := 0.0


func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("soldiers", _t0)


func _view_process(dt: float) -> void:
	if not world.has_view:
		return
	# a body that has come to rest only needs a look now and then
	if model and life == Life.DEAD and model._baked and is_static():
		_corpse_t -= dt
		if _corpse_t > 0.0:
			return
		_corpse_t = 0.4
	if not srv:
		if absf(net_pos.y - position.y) > 0.01 or position.distance_to(net_pos) > 0.01:
			net_smooth(dt)
		else:
			var facing := rotation
			facing.y = lerp_angle(facing.y, net_yaw, 1.0 - exp(-dt * 14.0))
			if facing != rotation:
				rotation = facing
	var v := life != Life.HIDDEN and seen_by_local()
	if v != _vis:
		visible = v
		_vis = v
	if not v:
		view_lod = false
		_last_view_pos = position
		return
	if world.cam and world.soldier_view and debug_pose.is_empty():
		var distance := world.cam.cam.global_position.distance_to(position)
		view_lod = distance > (80.0 if view_lod else 90.0) or not world.cam.cam.is_position_in_frustum(position + Vector3(0, 1.0, 0))
		if not view_lod and model == null and not world.soldier_view.acquire_detail_slot():
			view_lod = true  # keep the shared model visible while detail warms up
	else:
		view_lod = false
	if view_lod:
		if model:
			model.visible = false
		ring.visible = selected
		_last_view_pos = position
		return
	if model == null:
		model = SoldierModel.new()
		add_child(model)
		model.build(utype, team, eid * 31 + 7)
	model.visible = true
	# off-screen men are posed a few times a second, distant ones every other
	# or third frame, close ones every frame
	_pose_dt += dt
	var cm := crew_mount() if life == Life.ALIVE else null
	if world.cam and cm == null:
		var every := 1
		if not world.cam.cam.is_position_in_frustum(position + Vector3(0, 1.0, 0)):
			every = 6
		else:
			var cd := world.cam.cam.global_position.distance_to(position)
			every = 3 if cd > 90.0 else (2 if cd > 50.0 else 1)
		_pose_skip += 1
		if _pose_skip < every:
			return
	_pose_skip = 0
	var pdt := _pose_dt
	_pose_dt = 0.0
	var mv := Defs.flat(position - _last_view_pos)
	_last_view_pos = position
	var sp := mv.length() / maxf(pdt, 0.001)
	_view_speed = lerpf(_view_speed, sp, 1.0 - exp(-pdt * 8.0))
	if debug_pose.size() > 3:
		_view_speed = float(debug_pose[3])
	if debug_pose.size() > 6:
		model.move_yaw = float(debug_pose[6])  # test gallery: walking one way, facing another
	var fwd := Defs.dir_of(rotation.y)
	var back := sp > 0.3 and mv.normalized().dot(fwd) < -0.3
	if sp > 0.3:
		# which way he's going relative to where he faces: the legs follow it
		model.move_yaw = lerp_angle(model.move_yaw, fwd.signed_angle_to(mv.normalized(), Vector3.UP), 1.0 - exp(-pdt * 10.0))
	model.over_wall = (flags & F_OVERWALL) != 0
	model.cover_h = cover_h_view() if life == Life.ALIVE else 0.0
	model.blind = blind_view()
	var on_gun := false
	if cm != null:
		cm.crew_aim(rotation.y, (flags & F_SHOOTING) != 0, pdt)
		var gr: Array = cm.crew_grips()
		on_gun = not gr.is_empty() and posture != Post.PRONE and not (cm.variant == 1 and posture == Post.CROUCH)
		if on_gun:
			# he's on the gun: behind its grips wherever it's laid, hands on them
			model.global_transform = cm.crew_stance(position.y)
			model.crew_r = gr[0]
			model.crew_l = gr[1]
	model.crew = on_gun
	if not on_gun:
		if srv:
			# between simulation steps (see Entity.ip_offset)
			var off := ip_offset()
			if _ip_moving or not model.transform.is_equal_approx(off):
				model.transform = off
		elif _was_on_gun:
			model.transform = Transform3D.IDENTITY
	_was_on_gun = on_gun
	model.pose(pdt, life, posture, act, _view_speed, back, (flags & F_SHOOTING) != 0)
	ring.visible = selected
