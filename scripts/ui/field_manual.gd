class_name FieldManual
extends PanelContainer
## The field manual: every soldier, team, weapon, vehicle, building, defence,
## fire mission and upgrade in the game, with its numbers (read live from Defs,
## so they are always the game's own) and a 3D model to turn over. Opened from
## the main menu and in battle (F4 / Esc menu).
## Signal (docs/UI.md): lists with a hairline under each row and the chosen one
## in the accent, each entry marked by a small square in its side's colour, the
## figures as a table of labels, counted bars and mono values.

signal closed

var embedded := false  # the website supplies the roster and details around the model
var _home_view := Vector3.ZERO

const CATS := [
	["infantry", "Infantry"], ["squads", "Squads & teams"], ["weapons", "Weapons"],
	["veh_light", "Light vehicles"], ["veh_armour", "Armour"], ["veh_support", "Support & logistics"], ["veh_air", "Helicopters & drones"],
	["bases", "Base buildings"], ["defences", "Field defences"], ["cover", "Cover"], ["drills", "Drills & reflexes"], ["support", "Fire support"],
	["aircraft", "Aircraft"], ["boats", "Boats"], ["civilian", "Civilian & other"], ["upgrades", "Upgrades"],
]
## What a soldier does without being told (SoldierBrain): [key, name, posture,
## act, what's built round him, when, the risk, what it is]. In the order he
## weighs them when a grenade lands by him.
const DRILLS := [
	["d_smother", "Smother it", Soldier.Post.PRONE, Soldier.Act.SMOTHER, "nade", "Too late to throw it, among men who can't get away",
		"He dies; they live", "When it's too late to throw it and it has landed among men who can't get clear - a wounded man being treated, a crowded trench bay - the man beside it may throw himself on it, arms and knees drawn in round it. His body takes the blast: he is killed outright, and what's left of it barely reaches the men around him. Very few do it."],
	["d_back", "Throw it back", Soldier.Post.STAND, Soldier.Act.PICKUP, "nade", "Two seconds or more on the fuse, within four metres, not pinned",
		"If it's been cooked, it goes off in his hand", "He runs to it, snatches it up and throws it back where it came from. About one man in four has the nerve, and only while there's time on the fuse; a grenade only comes back once."],
	["d_kick", "Kick it away", Soldier.Post.STAND, Soldier.Act.KICK, "nade_kick", "Lying at his feet, a second or more to go",
		"Three or four metres isn't far", "A hard kick sends it skittering off - away from his mates and back towards whoever threw it - and he hits the dirt as it goes off."],
	["d_duck", "Get down behind it", Soldier.Post.PRONE, Soldier.Act.IDLE, "wall", "A wall between him and the grenade",
		"Little: the wall takes it", "If there's a wall between him and it he doesn't run across the open: he gets down flat behind it and lets the masonry take the blast."],
	["d_dive", "Dive clear", Soldier.Post.STAND, Soldier.Act.DIVE, "nade", "Everything else",
		"Caught in the open, still close", "The first man to see it yells and everyone near it throws himself flat, away from it. Lying down, most of the fragments fly over him: a prone man takes about half the blast."],
	["d_cook", "Cooking a grenade", Soldier.Post.STAND, Soldier.Act.COOK, "", "Men in hard cover close by",
		"Holding a live grenade", "Against men behind something solid at close range, the thrower lets the spoon fly and holds it a second or so before he throws, so it goes off as it lands - too late to throw back. It's the throw-back's answer, and the reason men sometimes have to lie on one."],
	["d_house", "Clearing a house", Soldier.Post.CROUCH, Soldier.Act.COOK, "door", "Enemy seen inside a building near the squad",
		"The doorway is a fatal funnel", "The man best placed stacks beside the doorway, back to the wall. Pin out, he steps into the doorway and throws it in low under the lintel (or lobs it through a window), steps back against the wall for the bang - and then he's in, a mate right behind him, before they recover. If the door's shut he kicks it in first, and only then pulls the pin - nobody cooks a grenade with a door still to get through. A man already stacked finishes the job before he follows a new order."],
	["d_door", "Kicking a door in", Soldier.Post.STAND, Soldier.Act.KICK, "shut_door", "A shut door in his way",
		"Loud: whoever's inside knows they're coming", "Most front doors are shut. A man who comes to one in a fight puts his boot in beside the lock and the doors slam back against the wall inside; with no enemy about he just opens it. Shut, a door hides the room - nobody sees or shoots through it - and keeps a grenade out. A blast next to it blows it in."],
	# squad drills (SquadBrain): what the whole squad does
	["s_contact", "React to contact", Soldier.Post.PRONE, Soldier.Act.SHOOT, "", "Fired on, or a new enemy in sight, while the squad is moving",
		"Caught in the open", "Everyone gets down where he is - the nearest cover a few metres round him - and returns fire, while the leader calls it: direction and range (\"Contact! North-east, 150 metres!\"). Once the enemy's fire slackens the squad carries on, by bounds while they're still about. A squad ordered to move fast keeps running."],
	["s_indirect", "React to indirect fire", Soldier.Post.STAND, Soldier.Act.DIVE, "", "Shells or bombs landing among a squad that isn't dug in",
		"The next round", "Down at the first one; at the second, out of the impact area at a run - sideways or back from the enemy, never towards him - to the best cover 50-odd metres off. When it lifts they go back to what they were doing. Men in trenches stay down in them: a hole is the best place to be."],
	["s_break", "Break contact", Soldier.Post.STAND, Soldier.Act.THROW, "", "A squad losing its nerve, or (the AI's) cut up and outnumbered",
		"Turning your back on them", "Smoke between them and us, then back by bounds - one team firing while the other moves - to a rally point, usually the nearest FOB behind. There it turns, counts off and checks its ammunition. Squads holding their own base, and crews on their guns, don't pull out."],
	["s_ambush", "Lying in wait", Soldier.Post.PRONE, Soldier.Act.IDLE, "wall", "A squad set to defend somewhere the enemy doesn't know about",
		"Sprung too early, it gives the position away", "It holds its fire and lets them come on: men who lie still, low and silent are hard to see (it's movement and muzzle flash that give men away). When they're close, or several are in the open, the leader springs it and everyone fires at once - the first volley is the deadliest. Fired on first, it fires back at once."],
	["s_morale", "Morale", Soldier.Post.STAND, Soldier.Act.RUN, "", "All the time: shown on the squad card",
		"A routed squad can't be ordered", "Casualties, fire it can't answer, tanks it can't fight and losing its leader wear a squad down; quiet, a leader, friends close by, a tank alongside and a hole in the ground build it back. Steady: it fights as it should. Shaken: it shoots worse and is pinned sooner. Breaking: it breaks contact. Routed: it runs for the rear and won't take orders until it has pulled itself together."],
	# vehicle crews (VehicleBrain): tanks, IFVs, APCs and armed cars
	["v_drive", "Driving", Soldier.Post.STAND, Soldier.Act.IDLE, "humvee", "Always",
		"Too fast into a bend", "A driver steers for a point some way down the road - further the faster he's going - slows for the bends he can see coming and brakes to stop where he's sent. Wheels turn no tighter than full lock (a truck needs room to turn round); tracks skid-steer, pivoting where they stand but turning wider at speed. Heavy vehicles are slow off the mark and slow to stop. A spot just behind is backed into, not reached by a loop; it keeps its distance behind a vehicle going its way, drives round one standing in the road and keeps to the right of oncoming traffic."],
	["v_smoke", "Smoke and back out", Soldier.Post.STAND, Soldier.Act.IDLE, "tank_smoke", "A missile or rocket launched at it",
		"Two salvoes in the dischargers", "The crew fires its smoke dischargers - a wall of smoke between it and the shooter that breaks a guided missile's lock - and reverses out of the line of fire, front armour still towards him, before carrying on with the job."],
	["v_front", "Front armour to the threat", Soldier.Post.STAND, Soldier.Act.IDLE, "tank", "Halted, with enemy armour or anti-tank weapons in sight",
		"The sides and rear are thin", "A tank's armour is thickest at the front. Stopped, the driver swings the hull to face the nearest tank or anti-tank team he can see - the gun stays on its target while the hull turns under it."],
	["v_infantry", "Wait for the infantry", Soldier.Post.STAND, Soldier.Act.IDLE, "tank_inf", "(The AI's) anti-tank teams ahead and no infantry of its own about",
		"Alone, it's a target", "A tank driving into a town or a wood on its own is a dead tank: it halts and shoots from where it is until its infantry catch up and deal with the rocket teams - or, after a while, pushes on regardless."],
	["v_withdraw", "Pull back for repairs", Soldier.Post.STAND, Soldier.Act.IDLE, "tank", "Badly damaged (a third of its strength left)",
		"Out of the fight while it's patched up", "The crew takes it back to the nearest FOB, where the mechanics patch it up (engineers and a repair truck do it faster), and it's ready for work again. A player can send it straight back in; the AI's waits until it's fixed."],
	["s_bound", "Bounding overwatch", Soldier.Post.CROUCH, Soldier.Act.RUN, "", "Moving where contact is likely (the enemy about, or seen near where it's going)",
		"Slower: half the squad is always down", "The squad splits into its two fire teams. One goes firm - down, spread out, each man watching his sector - while the other dashes 30-odd metres to the next cover; then it goes firm and the first team bounds through, past it. Nobody is ever caught in the open without a team covering him. Out of contact it travels in its wedge instead; ordered to run (Shift) it just runs."],
	["s_recon", "Recon by fire", Soldier.Post.CROUCH, Soldier.Act.SHOOT, "", "Bounding past where the enemy was last heard or seen",
		"Gives your own position away", "The covering team's gunner puts a burst or two into the treeline, hedge or house where the enemy was last heard: anyone lying in wait there either fires back - and shows himself - or keeps his head down while the others move."],
	["s_occupy", "Moving in, clearing", Soldier.Post.STAND, Soldier.Act.IDLE, "door", "Sent to hold ground a way off, with the enemy about",
		"A room nobody checked", "It gets there as a squad first - in its wedge, or by bounds - and only then spreads into its positions. Any house on the ground it's taking is cleared first: two men stack on the door, kick it in and go through, room by room - a grenade first only if someone's known to be in there - and call it: \"Clear!\""],
	["s_road_ambush", "Laying an ambush", Soldier.Post.PRONE, Soldier.Act.IDLE, "wall", "(The AI) a road the enemy uses - his supply trucks, his squads",
		"Found before it's sprung", "The squad moves to a rally point back from the road, then into position: the assault line 20-odd metres off the road in cover, the gun at one end firing down the killing zone (an L), a man out on the flank watching the way they'll come. Nobody fires until they're in the killing zone - then everyone at once, rockets at the vehicles. After a short, violent burst: smoke, and away before the enemy recovers (insurgents just melt away). Nobody comes, and after a few minutes it's given up."],
	["s_near", "Near ambush", Soldier.Post.STAND, Soldier.Act.RUN, "", "Ambushed at close range, steady, not hopelessly outnumbered",
		"Charging guns", "Lying down in the killing zone is death. A squad hit from 30 metres or less that still has its nerve assaults straight into the ambush - fire and movement, through and out the other side. Further off, or too many of them, it goes to ground and fights it out."],
	["s_straggler", "Stragglers", Soldier.Post.STAND, Soldier.Act.WALK, "", "The last man of a squad, nobody left to look after",
		"Alone he's no use to anyone", "The last man standing of a squad doesn't fight on alone: he attaches himself to the nearest friendly squad and fights as one of them."],
	["v_bail", "Bail out", Soldier.Post.STAND, Soldier.Act.RUN, "bail", "A vehicle knocked out",
		"Few get out when the ammunition goes up", "The crew - those who live through it - bail out of the hatches, burnt and shaken, and run for the nearest FOB: a trained crew is worth more than the tank. Back there they crew the next one (a little of the vehicle's cost comes back). Running across the battlefield with only their carbines, they're easy meat."],
	["s_winded", "Out of breath", Soldier.Post.STAND, Soldier.Act.WINDED, "", "After sprinting, rushing or dragging a man",
		"Slow and shaky when it matters", "A sprint or a long rush leaves a man blown - slower on his feet, the muzzle heaving with his breathing - until he gets a breather, quicker lying or kneeling than standing. Long moves at a run arrive winded; a walk keeps men fresh."],
]
## Battlefield cover, and how a man fights from each: [key, name, structure
## kind, variant, size, barrier height, where it's found, what it is].
const COVER := [
	["c_stone", "Stone wall", "low_wall", 0, Vector3(4, 1, 0.5), 1.08, "Field and garden walls round the farms and the town",
		"Dry stone or rubble masonry, waist high. Stops everything short of a heavy machine gun; kneel behind it and rest the rifle on the coping."],
	["c_brick", "Brick wall", "low_wall", 2, Vector3(4, 1, 0.5), 1.08, "Garden walls in the town",
		"A brick garden wall, waist high: as good as stone against small arms."],
	["c_hedge", "Hedge", "low_wall", 1, Vector3(4, 1, 0.9), 1.15, "Field boundaries and gardens",
		"Thick enough to hide a man, not to stop a bullet: rounds go straight through and find whoever is behind it. Good for moving unseen, poor for a firefight."],
	["c_sandbags", "Sandbag wall", "sandbags", 0, Vector3(4, 3, 0.9), 1.0, "Built by engineers and diggers; around checkpoints",
		"Filled bags stacked a metre high and nearly as thick. Kneel behind and fire over; only a .50 cal works through it, slowly."],
	["c_hesco", "HESCO wall", "hesco", 0, Vector3(4.4, 3, 1.1), 1.37, "Put up by Coalition engineers round bases and across the front",
		"Welded-mesh cells lined with geotextile and filled with earth, chest high and a metre thick. Stand and fire over it: nothing short of a shell gets through, not even a .50 cal."],
	["c_barricade", "Barricade", "barricade", 0, Vector3(4, 3, 1.0), 1.2, "Thrown up by the Rebels across roads and round their positions",
		"Oil drums filled with earth, stacked tyres, rubble, pallets and sacks, chest high. Stand and fire over it; it stops what sandbags do - but a tank shoves it aside, and the tyres burn."],
	["c_car", "Car", "car", 1, Vector3.ZERO, 0.95, "Parked along the streets and lanes",
		"The engine block and wheels stop rifle rounds; the doors and panels don't stop a machine gun. A big blast throws it across the road, and the cover goes with it."],
	["c_crates", "Supply crates", "crates", 1, Vector3.ZERO, 1.2, "Yards, depots and roadsides",
		"Stacked crates of stores, chest high: stand and fire over them. They stop a rifle, not a machine gun - a lone crate stops neither."],
	["c_wreck", "Burnt-out tank", "wreck", 0, Vector3.ZERO, 1.5, "Left from earlier fighting; every knocked-out tank",
		"Tons of steel: nothing a soldier carries goes through it. High enough to stand behind, and a blast doesn't move it."],
	["c_rubble", "Rubble heap", "rubble", 0, Vector3(4, 1, 1.4), 0.75, "Wherever a building or a wall came down",
		"Broken masonry, knee to waist high. Kneel down behind it, low; it stops what a stone wall does."],
	["c_tall", "Tall wall", "tall_wall", 0, Vector3(4, 2.6, 0.5), 2.6, "Compounds, yards and the town",
		"Too tall to see over: complete protection behind it, but you can only fight from its ends, leaning out round the corner - and the enemy knows where those are."],
	["c_window", "House wall, window", "house_wall", 1, Vector3(4, 0, 0.4), 1.0, "Every house",
		"Brick and plaster: it stops a rifle, a machine gun chews through it. Kneel at the window sill and fire out; the walls either side cover you from the flanks."],
	["c_trench", "Fire trench", "trench", 0, Vector3.ZERO, 1.39, "Dug by engineers and diggers; old lines across the fields",
		"Stand on the fire step with the rifle over the parapet; duck and you're a metre and a half underground. Only fire straight down the bay or a shell in the trench reaches you."],
	["c_crater", "Shell crater", "", 0, Vector3.ZERO, 0.45, "Wherever shells, bombs and rockets have landed",
		"A dip in the ground with a lip of thrown-up earth. Lie in it and fire over the lip; it hides you better than open ground and takes the edge off blast."],
	["c_woods", "Woods", "", 0, Vector3.ZERO, 0.0, "Copses and the edges of the fields",
		"Concealment, not cover: the enemy sees you at barely half the range and hits you less, but a round that's aimed true goes straight through the leaves."],
]
const BASES := ["fob", "barracks", "factory", "helipad", "dock", "medic_tent", "research", "tunnel"]

## What each thing is modelled on.
const PATTERN := {
	"rifle": "M4A1 carbine, 5.56x45 mm", "ak": "AKM assault rifle, 7.62x39 mm", "smg": "compact carbine, 5.56 mm",
	"lmg": "M249 SAW, 5.56 mm (Coalition) / PKM, 7.62x54R (Rebels)", "pistol": "service pistol, 9 mm",
	"mmg": "M240B on the M192 mount (Coalition) / PKM on its tripod (Rebels), 7.62 mm",
	"m2": "M2HB Browning, .50 BMG (12.7x99 mm); the Rebels' DShKM fires 12.7x108 mm",
	"chaingun": "M230 chain gun, 30x113 mm", "zu23": "ZU-23-2 twin autocannon, 23x152 mm",
	"bushmaster": "M242 Bushmaster, 25x137 mm with airburst rounds", "kpvt": "KPVT heavy machine gun, 14.5x114 mm",
	"coax": "coaxial machine gun, 7.62 mm",
	"tank": "modern main battle tank, Abrams class, 120 mm smoothbore", "old_tank": "T-55 / T-62 class, 100 / 115 mm gun",
	"technical": "Toyota Hilux pickup with a heavy machine gun in the bed", "ifv": "M2 Bradley class tracked IFV",
	"btr": "BTR-80 class 8x8 armoured personnel carrier", "humvee": "M1151 HMMWV with a roof-ring M2",
	"gunship": "AH-64 Apache class attack helicopter", "aa_tech": "pickup carrying a ZU-23-2",
	"heli": "UH-60 Black Hawk class utility helicopter", "truck": "4x4 cargo truck",
	"airstrike": "F-16 class strike jet, four 500 lb bombs", "a10": "A-10C Thunderbolt II, GAU-8 Avenger 30 mm",
	"ac130": "AC-130U Spooky II: 105 mm M102 howitzer, 40 mm Bofors, 25 mm GAU-12", "artillery": "M777 155 mm howitzers, off-map",
	"barrage": "BM-21 Grad, 122 mm rockets", "mortars": "82 mm mortar battery",
	"mg_nest": "M240B on M192 (Coalition) / PKM on tripod (Rebels); placed on a trench it becomes a gun bay",
	"hmg_nest": "M2HB on the M3 tripod (Coalition) / DShKM with a gun shield (Rebels); placed on a trench it becomes a gun bay",
	"at_post": "Javelin class guided missile (Coalition) / SPG-9 recoilless rifle (Rebels)", "mortar_pit": "81 / 82 mm mortar",
	"bunker": "concrete pillbox (Coalition) / log-and-earth dugout (Rebels), earth banked to the slits", "trench": "fire trench, revetted, with fire bays",
	"sandbags": "filled bags laid in header and stretcher courses, the face battered back", "hesco": "HESCO MIL1 Concertainer cells, 1.37 m",
	"barricade": "improvised: oil drums, tyres, rubble, pallets, sacks", "concrete_wall": "precast T-walls (Bremer type), cut down to 2.6 m",
	"wire": "triple-strand concertina on steel pickets (Rebels: wooden stakes)", "tank_trap": "Czech hedgehog: steel angle (Rebels: old rails)",
	"mines": "M15 / TM-62 anti-tank and M14 / PMN anti-personnel mines, marked on the friendly side",
	"camo_net": "a camouflage net on a centre pole and four corner poles, draped to the ground", "ammo_cache": "an ammunition point: stores on pallets under a fly sheet",
}

var _cat := "infantry"
var _side := -1  # -1 both
var _query := ""
var _sel := ""
var _entries: Array = []  # all entries (dictionaries), built once
var _cat_btns := {}
var _side_btns := {}
var _row_sb: Array = []  # the list rows' styles: at rest, under the cursor, chosen
var _bar_w := 160.0  # the figures' bar column (none when nothing on the page compares)
var _list: VBoxContainer
var _list_head: HBoxContainer  # the list's header: the category and how many it shows
var _title: Label
var _chips: HBoxContainer
var _desc: Label
var _stats: GridContainer
var _rel: Label
var _view: SubViewport
var _svc: SubViewportContainer
var _list_sc: ScrollContainer
var _stage: Node3D
var _turn: Node3D
var _cam: Camera3D
var _model: Node3D
var _floor: MeshInstance3D
var _floor_mat: ShaderMaterial
var _focus := Vector3.ZERO
var _dist := 6.0
var _yaw := 0.6
var _pitch := -0.32
var _drag := false
var _idle_t := 0.0


func _ready() -> void:
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 14.0, 0.0, UiKit.TICK_ARM, 0.97))
	_entries = _build_entries()
	if embedded:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		add_child(_make_view())
		_svc.custom_minimum_size = Vector2.ZERO
		return
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	# title bar: name, side filter, search, close
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	var tl := UiKit.caps("Field Manual", 18, UiKit.TEXT, 600, 2)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tl)
	var sub := UiKit.label("every unit, weapon, vehicle and work in the field, with its numbers", 13, UiKit.FAINT)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub.clip_text = true  # gives way first when the interface is scaled up
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(sub)
	# the side filter: tabs, the one in force underlined in the accent
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 16)
	top.add_child(sides)
	for s in [[-1, "Both sides"], [0, "Coalition"], [1, "Rebels"]]:
		var b := _tab(String(s[1]))
		var sv: int = s[0]
		b.pressed.connect(func(): _set_side(sv))
		sides.add_child(b)
		_side_btns[sv] = b
	var search := LineEdit.new()
	search.placeholder_text = "Search"
	search.custom_minimum_size = Vector2(170, 32)
	search.text_changed.connect(func(t: String): _query = t.strip_edges().to_lower(); _fill_list())
	top.add_child(search)
	var close := UiKit.button("Close", "secondary", 84, 32)
	close.pressed.connect(func(): closed.emit())
	top.add_child(close)
	# body: categories | list | detail
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	var csc := ScrollContainer.new()
	csc.custom_minimum_size = Vector2(170, 0)
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(csc)
	var cats := VBoxContainer.new()
	cats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cats.add_theme_constant_override("separation", 0)
	csc.add_child(cats)
	for c in CATS:
		# a row of the list: the category in capitals, how many entries it
		# holds (as filtered: a search shows at a glance where the matches are)
		var b2 := _row_button(34)
		var row := _row_box(b2)
		var cl := UiKit.caps(String(c[1]), 12, UiKit.DIM)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.clip_text = true
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cl)
		var cn := UiKit.mono_label("", 11, UiKit.FAINT)
		cn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cn)
		b2.set_meta("name", cl)
		b2.set_meta("count", cn)
		var ck: String = c[0]
		b2.pressed.connect(func(): _set_cat(ck))
		cats.add_child(b2)
		_cat_btns[ck] = b2
	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", 6)
	body.add_child(lc)
	_list_head = UiKit.header("Infantry", "0")  # (both filled in by _fill_list)
	lc.add_child(_list_head)
	var sc := ScrollContainer.new()
	_list_sc = sc
	sc.custom_minimum_size = Vector2(300, 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lc.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	sc.add_child(_list)
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_constant_override("separation", 8)
	body.add_child(det)
	det.add_child(_make_view())
	var dsc := ScrollContainer.new()
	dsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	det.add_child(dsc)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 8)
	dsc.add_child(dv)
	# the name, and whose it is and what it does as codes beside it
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	dv.add_child(head)
	_title = UiKit.caps("", 22, UiKit.TEXT, 600, 1)
	head.add_child(_title)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 7)
	_chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_chips)
	_desc = UiKit.label("", 14, UiKit.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_desc)
	# the figures: a label, a counted bar where it compares with the rest of
	# its kind, and the value; a hairline under each row (drawn by _rule_rows)
	_stats = GridContainer.new()
	_stats.columns = 3
	_stats.add_theme_constant_override("h_separation", 12)
	_stats.add_theme_constant_override("v_separation", 7)
	_stats.draw.connect(_rule_rows)
	_stats.sort_children.connect(_stats.queue_redraw)
	dv.add_child(_stats)
	_rel = UiKit.label("", 13, UiKit.DIM)
	_rel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_rel)
	_set_side(-1)
	_set_cat("infantry")
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	# the model view and the list take what the page can spare (a small screen,
	# or a big interface scale, keeps room for the text)
	resized.connect(func():
		_svc.custom_minimum_size.y = clampf(size.y * 0.5, 180.0, 420.0)
		_list_sc.custom_minimum_size.x = clampf(size.x * 0.25, 220.0, 300.0))


## Opens on a page: a category, optionally an entry, optionally one side.
func open(cat: String, key := "", side := -1) -> void:
	visible = true
	if embedded:
		for e in _entries:
			if e.key == key:
				_cat = String(e.cat)
				_sel = key
				_show_model(e)
				return
		open("entry", "tank")  # an invalid link still opens a useful model
		return
	if cat == "entry":
		cat = "veh_armour"
		for e in _entries:
			if e.key == key:
				cat = String(e.cat)
				break
	if cat == "vehicles":
		# (the old single vehicles page): whichever page that vehicle is on now
		cat = "veh_armour"
		for e in _entries:
			if String(e.cat).begins_with("veh_") and e.key == key:
				cat = e.cat
	if cat == "model" and key != "":
		# a bare model on the turntable (checking a model being built)
		var have := false
		for e in _entries:
			if e.cat == "model" and e.key == key:
				have = true
		if not have:
			_entries.append({"cat": "model", "key": key, "name": key, "team": side, "both": side < 0, "sub": "", "desc": "", "stats": [], "rel": []})
	_set_side(side)
	_set_cat(cat)
	if key != "":
		_select(key)


func _set_cat(c: String) -> void:
	_cat = c
	for k in _cat_btns:
		var b: Button = _cat_btns[k]
		b.set_pressed_no_signal(k == c)
		_paint(b)
	_sel = ""
	_fill_list()


func _set_side(s: int) -> void:
	_side = s
	for k in _side_btns:
		(_side_btns[k] as Button).set_pressed_no_signal(k == s)
	_fill_list()


func _visible_entries() -> Array:
	return _entries_in(_cat)


## A category's entries through the side filter and the search.
func _entries_in(cat: String) -> Array:
	var out := []
	for e in _entries:
		if e.cat != cat:
			continue
		if _side >= 0 and int(e.team) >= 0 and int(e.team) != _side and not (e.get("both", false)):
			continue
		if _query != "" and not (String(e.name).to_lower().contains(_query) or String(e.get("pattern", "")).to_lower().contains(_query)):
			continue
		out.append(e)
	return out


func _fill_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for k in _cat_btns:
		var cb: Button = _cat_btns[k]
		var cn := _entries_in(String(k)).size()
		cb.set_meta("n", cn)
		(cb.get_meta("count") as Label).text = "%d" % cn
		_paint(cb)
	var vis := _visible_entries()
	var cname := _cat
	for c in CATS:
		if c[0] == _cat:
			cname = String(c[1])
	(_list_head.get_node("Text") as Label).text = cname
	(_list_head.get_node("Count") as Label).text = "%d" % vis.size()
	for e in vis:
		var b := _row_button(44)
		var row := _row_box(b)
		row.add_theme_constant_override("separation", 10)
		var mk := SideMark.new()
		mk.team = int(e.team)
		mk.both = bool(e.get("both", false))
		mk.dy = -8.0  # level with the name, the first of the two lines
		mk.custom_minimum_size = Vector2(8, 0)
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mk)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var n := UiKit.caps(String(e.name), 13, UiKit.TEXT)
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(n)
		# its figures as a code (a drill's is when it happens, which is a sentence)
		var sub := String(e.get("sub", ""))
		var s2 := UiKit.label(sub, 11, UiKit.FAINT) if e.cat == "drills" else UiKit.mono_label(sub.to_upper(), 11, UiKit.FAINT)
		s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s2.clip_text = true
		s2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(s2)
		var k: String = e.key
		b.set_meta("key", k)
		b.set_meta("name", n)
		b.set_meta("rest", UiKit.TEXT)
		b.set_pressed_no_signal(e.key == _sel)
		_paint(b)
		b.pressed.connect(func(): _select(k))
		_list.add_child(b)
	if _sel == "" and not vis.is_empty():
		_select(String(vis[0].key))


func _select(key: String) -> void:
	_sel = key
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(String(b.get_meta("key", "")) == key)
			_paint(b)
	var e: Dictionary = {}
	for x in _visible_entries():
		if x.key == key:
			e = x
	if e.is_empty():
		return
	_title.text = String(e.name)
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	var both: bool = e.get("both", false)
	var mk := SideMark.new()
	mk.team = int(e.team)
	mk.both = both
	mk.custom_minimum_size = Vector2(8, 16)
	_chips.add_child(mk)
	_chips.add_child(UiKit.caps(_side_name(int(e.team), both), 12, UiKit.DIM))
	if e.has("role") and String(e.role) != "":
		_chips.add_child(UiKit.caps("·  " + String(e.role), 12, UiKit.FAINT))
	_desc.text = String(e.get("desc", ""))
	_desc.visible = _desc.text != ""
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	# (a page with no figures to compare gives the bars' column up to the values)
	_bar_w = 0.0
	for s in e.stats:
		if float(s[2]) >= 0.0:
			_bar_w = 160.0
	if String(e.get("pattern", "")) != "":
		_stat_row("Pattern", -1.0, String(e.pattern), true, UiKit.DIM)
	for s in e.stats:
		_stat_row(String(s[0]), float(s[2]), String(s[1]), e.cat == "drills")
	# where it's found, who uses it, what it's part of: as rows of the table
	# where the line names its subject ("Used by: ..."), as prose where it doesn't
	var rest := []
	for r in e.get("rel", []):
		var ln := String(r)
		var i := ln.find(": ")
		if i > 0 and i <= 24:
			_stat_row(ln.substr(0, i), -1.0, ln.substr(i + 2), true, UiKit.DIM)
		else:
			rest.append(ln)
	_rel.text = "\n".join(rest)
	_rel.visible = not rest.is_empty()
	_stats.queue_redraw()
	_show_model(e)


## A row of the figures: the label in faint capitals, a counted bar when the
## figure compares with the rest of its kind (frac >= 0), and the value -
## a figure or a short code in mono, a phrase as prose.
func _stat_row(label: String, frac: float, value: String, prose := false, col := UiKit.TEXT) -> void:
	var lab := UiKit.caps(label, 11, UiKit.FAINT)
	lab.custom_minimum_size = Vector2(150, 0)
	var pad := UiKit.bare()
	pad.content_margin_top = 3.0  # on the value's line
	lab.add_theme_stylebox_override("normal", pad)
	_stats.add_child(lab)
	var bar := StatBar.new()
	bar.frac = frac
	bar.custom_minimum_size = Vector2(_bar_w, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stats.add_child(bar)
	var code := not prose and (frac >= 0.0 or value.length() <= 16 or _figure(value))
	var val := UiKit.mono_label(value, 13, col) if code else UiKit.label(value, 13, col)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # wraps rather than widening the page
	_stats.add_child(val)


static func _figure(s: String) -> bool:
	for ch in s:
		if ch >= "0" and ch <= "9":
			return true
	return false


## A hairline under each row of the figures.
func _rule_rows() -> void:
	var vs := float(_stats.get_theme_constant("v_separation"))
	var n := _stats.get_child_count()
	for i in range(0, n, 3):
		var c := _stats.get_child(i) as Control
		var y := floorf(c.position.y + c.size.y + vs * 0.5) + 0.5
		_stats.draw_line(Vector2(0, y), Vector2(_stats.size.x, y), UiKit.LINE, 1.0)


func _side_name(t: int, both: bool) -> String:
	if both or t < 0:
		return "Both sides"
	return Defs.TEAM_NAMES[t]


## A tab of the side filter: capitals, the one in force in the accent and
## underlined.
func _tab(text: String) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiKit.cond(600, 1))
	b.add_theme_font_size_override("font_size", 12)
	var on := UiKit.underline(UiKit.ACCENT, 2.0, 6.0)
	var off := UiKit.bare()
	off.content_margin_left = 2
	off.content_margin_right = 2
	off.content_margin_top = 6
	off.content_margin_bottom = 6
	for st in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, off)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_color", UiKit.FAINT)
	b.add_theme_color_override("font_hover_color", UiKit.TEXT)
	b.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", UiKit.ACCENT)
	return b


## A row of a list (the categories, the entries): a hairline under it, a
## faint fill under the cursor, and the chosen one washed with the accent
## behind a 2 px accent edge, its name in the accent (_paint).
func _row_button(h: float) -> Button:
	if _row_sb.is_empty():
		var rest := UiKit.box(Color(0, 0, 0, 0), 0, UiKit.LINE, 0, 0.0)
		rest.border_width_bottom = 1
		var hover := UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, UiKit.LINE, 0, 0.0)
		hover.border_width_bottom = 1
		var chosen := UiKit.box(UiKit.fa(UiKit.ACCENT, 0.08), 0, UiKit.ACCENT, 0, 0.0)
		chosen.border_width_left = 2
		_row_sb = [rest, hover, chosen]
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.text = ""
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, _row_sb[0])
	b.add_theme_stylebox_override("hover", _row_sb[1])
	b.add_theme_stylebox_override("pressed", _row_sb[2])
	b.add_theme_stylebox_override("hover_pressed", _row_sb[2])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _row_box(b: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	return row


## A row's name in the accent while it's the chosen one (an empty category's faint).
func _paint(b: Button) -> void:
	var nl: Label = b.get_meta("name", null)
	if nl == null:
		return
	var rest: Color = b.get_meta("rest", UiKit.DIM)
	if int(b.get_meta("n", 1)) == 0:
		rest = UiKit.FAINT
	nl.add_theme_color_override("font_color", UiKit.ACCENT if b.button_pressed else rest)


# --- the 3D view ---------------------------------------------------------------------

func _make_view() -> Control:
	var svc := SubViewportContainer.new()
	_svc = svc
	svc.stretch = true
	svc.custom_minimum_size = Vector2(0, 420)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_view_input)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(_view)
	_stage = Node3D.new()
	_view.add_child(_stage)
	# a dark studio: warm key light, a cold rim from behind that outlines the
	# silhouette, a faint fill, and a matte floor with a tactical grid that
	# fades into the dark
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.028, 0.032, 0.036)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.65, 0.62)
	env.ambient_light_energy = 0.16
	if ProjectSettings.get_setting("rendering/shading/overrides/force_vertex_shading", false):
		# lit per vertex (the browser build), the floor loses the key light's
		# sheen and the model much of its modelling: more fill makes up for it
		env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX  # as in the game
	env.tonemap_exposure = 0.85
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.86
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-38), 0)
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.93, 0.82)
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 40.0
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-14), deg_to_rad(165), 0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.78, 0.86, 1.0)
	_stage.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-10), deg_to_rad(70), 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.88, 0.95)
	_stage.add_child(fill)
	_floor = MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(80, 80)
	_floor.mesh = fm
	var fsh := Shader.new()
	fsh.code = FLOOR_SHADER
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = fsh
	_floor.material_override = _floor_mat
	if ProjectSettings.get_setting("rendering/shading/overrides/force_vertex_shading", false):
		_floor_mat.set_shader_parameter("sheen", 1.0)
	_stage.add_child(_floor)
	_turn = Node3D.new()
	_stage.add_child(_turn)
	_cam = Camera3D.new()
	_cam.fov = 28.0  # a longer lens: less of the toy-like close-up distortion
	_stage.add_child(_cam)
	return svc


func _view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(_dist * 0.9, 0.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(_dist * 1.1, 80.0)
	elif ev is InputEventMagnifyGesture:
		# a trackpad: pinch, or two fingers, to zoom
		_dist = clampf(_dist / (ev as InputEventMagnifyGesture).factor, 0.6, 80.0)
	elif ev is InputEventPanGesture:
		_dist = clampf(_dist * pow(1.1, (ev as InputEventPanGesture).delta.y * 0.4), 0.6, 80.0)
	elif ev is InputEventMouseMotion and _drag:
		var mm := ev as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.01
		_pitch = clampf(_pitch - mm.relative.y * 0.006, -1.3, 0.05)
		_idle_t = 2.5


func _process(dt: float) -> void:
	if _cam == null:
		return
	_idle_t -= dt
	if _idle_t <= 0.0 and not _drag and not embedded:
		_yaw += dt * 0.28  # a slow turntable when left alone
	var off := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Vector3(0, 0, _dist)
	_cam.position = _focus + off
	_cam.look_at(_focus, Vector3.UP)


func _show_model(e: Dictionary) -> void:
	if _model:
		_model.queue_free()
		_model = null
	var m: Node3D = _make_model(e)
	if m == null:
		_view.get_parent().visible = false
		return
	_view.get_parent().visible = true
	_model = m
	_turn.add_child(m)
	# frame it: everything it's made of, seen from a little above
	var ab := AABB()
	var first := true
	for n in _all_visuals(m):
		var vi := n as VisualInstance3D
		var t: Transform3D = m.global_transform.affine_inverse() * vi.global_transform
		var b := t * vi.get_aabb()
		ab = b if first else ab.merge(b)
		first = false
	if first:
		ab = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	# stand it on the floor (aircraft are built round their fuselage, so they
	# fly a little above it)
	var lift := -ab.position.y + (1.2 if String(e.cat) == "support" and ab.size.x > 6.0 and not m.has_meta("on_gear") else 0.0)
	m.position.y = lift
	ab.position.y += lift
	_focus = ab.get_center()
	if OS.has_environment("FL_DEBUG_FM"):
		print("FM ", e.key, " aabb=", ab, " vs=", _view.size)
	# fit it whichever way the turntable has it: a cylinder round its footprint,
	# seen from the camera's pitch, inside the vertical and horizontal field
	var vs: Vector2 = _view.size
	# (before the first layout the view has no size yet)
	var aspect := clampf(vs.x / vs.y, 1.2, 4.0) if vs.x > 16.0 and vs.y > 16.0 else 2.4
	var wide := maxf(ab.size.x, ab.size.z)
	var rxz := Vector2(ab.size.x, ab.size.z).length() * 0.5
	_pitch = -0.28 if ab.size.y > wide * 0.5 else -0.42
	var half_v := ab.size.y * 0.5 * cos(_pitch) + rxz * sin(absf(_pitch))
	var tv := tan(deg_to_rad(_cam.fov * 0.5))
	_dist = maxf(half_v / tv, rxz / (tv * aspect)) * 1.0 + rxz * 0.35
	var span := maxf(wide, ab.size.y)
	_floor_mat.set_shader_parameter("radius", maxf(1.6, span * 1.3))
	_floor_mat.set_shader_parameter("cell", 1.0 if span > 3.0 else (0.5 if span > 1.2 else 0.25))
	# a front three-quarter view (models face -z)
	# (soldiers more side-on, so a raised rifle isn't pointing at the lens)
	_yaw = PI - (1.05 if String(e.cat) in ["infantry", "squads"] else 0.62)
	if String(e.cat) == "cover":
		_yaw = 0.75  # over his shoulder: the man, his weapon on the top, and what he's looking at
	elif String(e.cat) == "drills":
		_yaw = 0.55 if e.key in ["d_house", "d_door"] else (PI - 0.62 if String(e.key).begins_with("v_") else PI - 1.25)  # the doorway from outside, the vehicle three-quarter, or the man side-on
	_idle_t = 4.0  # hold the opening view a moment before the turntable starts
	_home_view = Vector3(_yaw, _pitch, _dist)


## The website's keyboard-accessible buttons operate the same camera as dragging.
func control_model(action: String) -> void:
	match action:
		"left": _yaw -= PI / 8.0
		"right": _yaw += PI / 8.0
		"zoom-in": _dist = maxf(_dist * 0.85, 0.6)
		"zoom-out": _dist = minf(_dist / 0.85, 80.0)
		"reset":
			_yaw = _home_view.x
			_pitch = _home_view.y
			_dist = _home_view.z


func _all_visuals(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is VisualInstance3D and (c as VisualInstance3D).is_visible_in_tree():
			out.append(c)
		out.append_array(_all_visuals(c))
	return out


func _make_model(e: Dictionary) -> Node3D:
	var side: int = int(e.team) if int(e.team) >= 0 else (_side if _side >= 0 else 0)
	match String(e.cat):
		"infantry":
			# armed men stand to, weapon up; the rest at ease
			var armed: bool = String(Defs.UNITS[e.key].weapon) in ["rifle", "ak", "smg", "lmg"]
			if int(Defs.UNITS[e.key].get("rockets", 0)) > 0:
				return _soldier(String(e.key), side, Soldier.Act.LAUNCH)  # launcher shouldered
			return _soldier(String(e.key), side, Soldier.Act.SHOOT if armed else Soldier.Act.IDLE)
		"squads":
			var g := Node3D.new()
			var mem: Array = Defs.SQUADS[e.key].members
			for i in mem.size():
				var armed2: bool = String(Defs.UNITS[mem[i]].weapon) in ["rifle", "ak", "smg", "lmg"]
				var s := _soldier(String(mem[i]), side, Soldier.Act.SHOOT if armed2 and i % 2 == 0 else Soldier.Act.IDLE, 11 + i * 7)
				s.position = Vector3((i - (mem.size() - 1) * 0.5) * 0.95, 0, absf(i - (mem.size() - 1) * 0.5) * 0.35)
				g.add_child(s)
			return g
		"weapons":
			return _weapon_model(String(e.key), side)
		"veh_light", "veh_armour", "veh_support", "veh_air", "aircraft", "boats", "civilian":
			var vm := VehicleModels.build(String(e.key), side if int(e.team) >= 0 else 0, 7)
			var eg := vm.root.get_node_or_null("Afterburner")
			if eg:
				eg.visible = false  # the exhaust glow is for flight
			return vm.root
		"bases", "defences":
			if e.key == "trench":
				return _trench_diorama()
			if e.key == "town":
				return Structure.preview_model("town", side, 0, Vector3(3.6, 2.0, 2.4))
			var bteams: Array = Defs.BUILDINGS[e.key].teams
			var bs: int = side if side in bteams else int(bteams[0])
			return Structure.preview_model(String(e.key), bs)
		"cover":
			return _cover_diorama(String(e.key), side if side >= 0 else 0)
		"drills":
			return _drill_diorama(String(e.key), side if side >= 0 else 0)
		"model":
			return _on_the_ground(VehicleModels.build(String(e.key), side if side >= 0 else 0, 7).root)
		"support":
			var smk := String(Defs.SUPPORT.get(e.key, {}).get("model", ""))
			if smk != "":
				return _on_the_ground(VehicleModels.build(smk, 0 if int(e.team) != 1 else 1, 3).root)
			match String(e.key):
				"airstrike":
					var jm := VehicleModels.build("jet", 0, 3).root
					var ab_node := jm.get_node_or_null("Afterburner")
					if ab_node:
						ab_node.visible = false  # the exhaust glow is for flight
					return jm
				"a10":
					return _on_the_ground(VehicleModels.build("a10", 0, 3).root)
				"ac130":
					return _on_the_ground(VehicleModels.build("ac130", 0, 3).root)
				"mortars":
					return Structure.preview_model("mortar_pit", 1)
				_:
					return _shells(String(e.key))
	return null


## An aircraft on display: gear down if it has any, the exhaust glow off.
func _on_the_ground(root: Node3D) -> Node3D:
	var gear := root.find_child("Gear", true, false)
	if gear:
		(gear as Node3D).visible = true
		root.set_meta("on_gear", true)
	var glow := root.get_node_or_null("Afterburner")
	if glow:
		glow.visible = false  # the exhaust glow is for flight
	return root


func _soldier(ut: String, side: int, act: int, sd := 7) -> Node3D:
	var sm := SoldierModel.new()
	sm.build(ut, side if Defs.UNITS[ut].team < 0 else int(Defs.UNITS[ut].team), sd)
	for i in 6:
		sm.pose(0.5, 0, Soldier.Post.STAND, act, 0.0, false, false)
	sm.rotation.y = 0.0
	return sm


## Small arms come out of a soldier's hands; crew-served guns on their mounts;
## vehicle guns on the vehicle.
func _weapon_model(key: String, side: int) -> Node3D:
	match key:
		"mmg", "m2", "hmg":
			var cg := WeaponModels.build(("pkm" if side == 1 else "m240") if key == "mmg" else ("dshk" if side == 1 else "m2"))
			var cr: Node3D = cg.root
			cr.position.y = float(cg.h)  # tripod feet on the floor
			var hold := Node3D.new()
			hold.add_child(cr)
			return hold
		"chaingun":
			return VehicleModels.build("gunship", 0, 7).root
		"zu23":
			return VehicleModels.build("aa_tech", 1, 7).root
		"bushmaster":
			return VehicleModels.build("ifv", 0, 7).root
		"kpvt":
			return VehicleModels.build("btr", 1, 7).root
		"coax":
			return VehicleModels.build("tank" if side != 1 else "old_tank", side if side >= 0 else 0, 7).root
	var ut: String = {"rifle": "rifleman", "ak": "fighter", "smg": "medic", "lmg": "pkm" if side == 1 else "mg_gunner", "pistol": "fpv_op"}.get(key, "rifleman")
	var sm := SoldierModel.new()
	sm.build(ut, int(Defs.UNITS[ut].team), 3)
	var g: Node3D = sm.gun
	g.get_parent().remove_child(g)
	g.transform = Transform3D.IDENTITY
	g.visible = true
	sm.free()
	var holder := Node3D.new()
	holder.add_child(g)
	g.position.y = 0.6
	return holder


## Shells and rockets for the off-map fire missions.
func _shells(key: String) -> Node3D:
	var g := Node3D.new()
	var n := 4
	for i in n:
		var x := (i - (n - 1) * 0.5) * 0.32
		if key == "barrage":
			# 122 mm Grad rocket: long tube, ogive nose, tail fins
			WeaponModels._tube(g, 0.12, -1.4, 1.2, 0.061, "paint", -1.0, x, Color(0.5, 0.53, 0.42))
			WeaponModels._tube(g, 0.12, -1.4, -1.75, 0.061, "paint", 0.01, x, Color(0.5, 0.53, 0.42))
			for a in 4:
				WeaponModels._box(g, Vector3(0.006, 0.12, 0.18), Vector3(x, 0.12, 1.12), "gunmetal", Vector3(0, 0, a * PI / 2))
		else:
			# 155 mm high-explosive shell with its fuze and driving band
			WeaponModels._tube(g, 0.08, -0.3, 0.25, 0.0775, "paint", -1.0, x, Color(0.42, 0.45, 0.3))
			WeaponModels._tube(g, 0.08, -0.3, -0.58, 0.0775, "paint", 0.02, x, Color(0.42, 0.45, 0.3))
			WeaponModels._tube(g, 0.08, 0.18, 0.21, 0.082, "paint", -1.0, x, Color(0.72, 0.45, 0.25))
			WeaponModels._tube(g, 0.08, -0.58, -0.66, 0.02, "paint", 0.012, x, Color(0.75, 0.62, 0.3))
	g.rotation.x = 0.0
	return g


## A piece of cover with a man fighting from it the way he would in battle:
## kneeling with his rifle on the wall, standing at a chest-high one, lying
## at the lip of a crater, leaning round the end of a tall wall.
func _cover_diorama(key: String, side: int) -> Node3D:
	var c: Array = []
	for x in COVER:
		if x[0] == key:
			c = x
	if c.is_empty():
		return null
	var g := Node3D.new()
	var h: float = c[5]
	var ut := "rifleman" if side != 1 else "fighter"
	var man_z := 0.0
	var man_x := 0.0
	var man_y := 0.0
	match String(c[2]):
		"":
			if key == "c_crater":
				# a shallow bowl: a ring of thrown-up earth
				for i in 18:
					var a := TAU * i / 18.0
					var lump := MeshInstance3D.new()
					lump.mesh = Res.sphere(0.5, 8)
					lump.scale = Vector3(1.25, 0.42 + 0.08 * sin(i * 2.3), 1.0)
					lump.position = Vector3(cos(a) * 1.75, 0.0, sin(a) * 1.75)
					lump.rotation.y = -a
					Mats.apply(lump, "earth")
					g.add_child(lump)
				man_z = 0.55
			else:
				for i in 3:
					var tr := Node3D.new()
					Structure.tree_model(tr, 11 + i * 5, 0)
					tr.position = Vector3(-1.6 + i * 1.9, 0, -1.2 - (i % 2) * 1.3)
					g.add_child(tr)
				man_z = 0.4
		"trench":
			g.add_child(_trench_diorama())
			man_z = TrenchNet.HALF_W - 0.34
			h = 1.52  # the diorama's sandbags sit a little higher than the game's parapet
		_:
			var st := Structure.preview_model(String(c[2]), -1, int(c[3]), c[4] as Vector3)
			if c[2] in ["car", "wreck"]:
				st.rotation.y = PI * 0.5  # broadside on
			g.add_child(st)
			var half := 0.25
			match String(c[2]):
				"sandbags", "barricade":
					half = 0.45
				"hesco":
					half = 0.53
				"car":
					half = 0.9
				"crates":
					half = 0.62
				"wreck":
					half = 1.7
				"rubble":
					half = 0.7
				"house_wall":
					half = 0.2
				"low_wall":
					half = float((c[4] as Vector3).z) * 0.5
			man_z = half + Cover.offset(h)
			if h >= Cover.STAND_MAX:
				man_z = half + 0.5
				man_x = float((c[4] as Vector3).x) * 0.5 - 0.35
	var sm := SoldierModel.new()
	sm.build(ut, side, 17)
	var post := Soldier.Post.CROUCH
	if h <= 0.0:
		sm.cover_h = 0.0
	elif h >= Cover.STAND_MAX:
		post = Soldier.Post.LEAN_R
	else:
		sm.cover_h = h
		sm.over_wall = true
		post = [Soldier.Post.PRONE, Soldier.Post.CROUCH, Soldier.Post.STAND][Cover.stance(h)]
	for i in 8:
		sm.pose(0.5, 0, post, Soldier.Act.SHOOT, 0.0, false, false)
	if key == "c_trench":
		var hold := g.get_child(0) as Node3D
		sm.position = Vector3(0.6, TrenchNet.FLOOR_Y + 0.025, -man_z)
		hold.add_child(sm)
		return g
	sm.position = Vector3(man_x, man_y, man_z)
	g.add_child(sm)
	return g


## A soldier mid-drill, with what it's about: a grenade on the ground, the
## wall he's behind, the doorway he's stacked beside.
func _drill_diorama(key: String, side: int) -> Node3D:
	var d: Array = []
	for x in DRILLS:
		if x[0] == key:
			d = x
	if d.is_empty():
		return null
	if key.begins_with("v_"):
		return _crew_diorama(String(d[4]), side)
	var g := Node3D.new()
	var sm := SoldierModel.new()
	sm.build("rifleman" if side != 1 else "fighter", side, 23)
	var nade_at := Vector3.INF
	match String(d[4]):
		"nade":
			nade_at = Vector3(0.0, 0.05, -1.1 if key != "d_smother" else -0.78)
		"nade_kick":
			nade_at = Vector3(0.12, 0.05, -1.35)
		"wall":
			var wall := Structure.preview_model("low_wall", -1, 0, Vector3(3.0, 1.0, 0.5))
			wall.position = Vector3(0, 0, -1.4)
			g.add_child(wall)
			sm.position.z = 0.55  # flat out behind it, head to the wall
			nade_at = Vector3(0.3, 0.05, -2.4)
		"door":
			# a house wall with its doorway; he's outside, back to the wall,
			# facing along it towards the door
			var hw := Structure.preview_model("house_wall", -1, 2, Vector3(4.6, 2.0, 0.4))
			hw.position = Vector3(-1.55, 0, -0.55)
			g.add_child(hw)
			sm.rotation.y = PI * 0.5
		"shut_door":
			# the doors shut in front of him, his boot going in
			var sw := Structure.preview_model("house_wall", -1, 2, Vector3(4.6, 2.0, 0.4), true)
			sw.position = Vector3(0, 0, -0.95)
			g.add_child(sw)
	var spd: float = {"s_morale": 5.3, "s_near": 5.3, "s_bound": 4.6, "s_straggler": 1.6}.get(key, 0.0)  # running for it, or walking
	for i in 12:
		sm.pose(0.3 if spd == 0.0 else 0.07, 0, d[2], d[3], spd, false, d[3] == Soldier.Act.SHOOT)
	g.add_child(sm)
	if nade_at != Vector3.INF:
		var nd := MeshInstance3D.new()
		nd.mesh = Res.sphere(0.05, 8)
		nd.scale = Vector3(1.0, 1.25, 1.0)
		nd.position = nade_at
		nd.material_override = Res.mat(Color(0.25, 0.28, 0.2))
		g.add_child(nd)
	return g


## A vehicle crew's drill: the vehicle, and what it's about (its smoke, the
## infantry it waits for).
func _crew_diorama(what: String, side: int) -> Node3D:
	var g := Node3D.new()
	var vk := "humvee" if what == "humvee" else ("tank" if side != 1 else "old_tank")
	g.add_child(_on_the_ground(VehicleModels.build(vk, side, 7).root))
	if what == "tank_smoke":
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		# a wall of it across the front: soft, see-through at the edges
		for i in 4:
			var dir := Vector3(0, 0, -1).rotated(Vector3.UP, (i - 1.5) * 0.32)
			for j in 6:
				var puff := MeshInstance3D.new()
				puff.mesh = Res.sphere(1.0, 12)
				var r := rng.randf_range(0.8, 1.5)
				puff.scale = Vector3(r, r * 0.75, r)
				puff.position = dir * rng.randf_range(8.5, 11.0) + Vector3(rng.randf_range(-1.2, 1.2), 0.5 + j * 0.45, rng.randf_range(-1.0, 1.0))
				var sm2 := StandardMaterial3D.new()
				sm2.albedo_color = Color(0.74, 0.74, 0.72, rng.randf_range(0.28, 0.45))
				sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm2.roughness = 1.0
				puff.material_override = sm2
				puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				g.add_child(puff)
	elif what == "bail":
		# the crew scrambling away from it
		for i in 2:
			var cm := SoldierModel.new()
			cm.build("crewman" if side != 1 else "r_crewman", side, 41 + i)
			for k in 12:
				cm.pose(0.07, 0, Soldier.Post.STAND, Soldier.Act.RUN, 5.0, false, false)
			cm.position = Vector3(3.2 + i * 1.1, 0, 1.0 + i * 1.8)
			cm.rotation.y = PI * 0.8
			g.add_child(cm)
	elif what == "tank_inf":
		for i in 3:
			var sm := SoldierModel.new()
			sm.build("rifleman" if side != 1 else "fighter", side, 31 + i)
			for k in 12:
				sm.pose(0.3, 0, Soldier.Post.CROUCH if i != 1 else Soldier.Post.STAND, Soldier.Act.IDLE, 0.0, false, false)
			sm.position = Vector3(2.8 + (i % 2) * 0.9, 0, -1.5 + i * 1.6)
			g.add_child(sm)
	return g


## A short length of fire trench cut into a block of ground, revetted.
func _trench_diorama() -> Node3D:
	var g := Node3D.new()
	var L := 6.0
	var hw := TrenchNet.HALF_W
	var d := -TrenchNet.FLOOR_Y
	for s in [-1.0, 1.0]:
		var blk := MeshInstance3D.new()
		blk.mesh = Res.box(Vector3(L, d, 2.0))
		blk.position = Vector3(0, -d * 0.5, s * (hw + 1.0))
		Mats.apply(blk, "earth")
		g.add_child(blk)
		# revetment boards and posts on the trench wall
		var wall := MeshInstance3D.new()
		wall.mesh = Res.box(Vector3(L, d * 0.8, 0.05))
		wall.position = Vector3(0, -d * 0.55, s * (hw + 0.02))
		Mats.apply(wall, "wood", Color(0.7, 0.6, 0.48))
		g.add_child(wall)
		for i in 5:
			var post := MeshInstance3D.new()
			post.mesh = Res.box(Vector3(0.1, d + 0.1, 0.1))
			post.position = Vector3(-L * 0.5 + 0.6 + i * 1.2, -d * 0.5 + 0.05, s * (hw - 0.03))
			Mats.apply(post, "wood_dark")
			g.add_child(post)
	var fl := MeshInstance3D.new()
	fl.mesh = Res.box(Vector3(L, 0.05, hw * 2.0))
	fl.position = Vector3(0, -d, 0)
	Mats.apply(fl, "wood", Color(0.55, 0.48, 0.38))
	g.add_child(fl)
	# spoil thrown up as a parapet in front, sandbags along it
	var berm := MeshInstance3D.new()
	berm.mesh = Res.box(Vector3(L, 0.3, 1.2))
	berm.position = Vector3(0, 0.15, -(hw + 0.7))
	Mats.apply(berm, "earth")
	g.add_child(berm)
	for i in 8:
		var bag := MeshInstance3D.new()
		bag.mesh = Res.box(Vector3(0.55, 0.16, 0.32))
		bag.position = Vector3(-L * 0.5 + 0.5 + i * 0.7, 0.38, -(hw + 0.45))
		bag.rotation.y = (i % 3) * 0.06
		Mats.apply(bag, "sandbag")
		g.add_child(bag)
	var gun := WeaponModels.build("m240", true)
	var gr: Node3D = gun.root
	gr.position = Vector3(0.8, float(gun.h), -(hw + 0.5))
	g.add_child(gr)
	g.position.y = d
	return g


const FLOOR_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform float radius = 6.0;
uniform float cell = 1.0;
uniform float sheen = 0.0;  // the key light's sheen, painted on where lighting is per vertex
varying vec3 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	float r = length(wp.xz);
	vec2 q = wp.xz / cell;
	vec2 g = abs(fract(q) - 0.5);
	float w = fwidth(q.x) * 1.2;
	float ln = 1.0 - smoothstep(0.0, w, 0.5 - max(g.x, g.y));
	vec2 g10 = abs(fract(q / 5.0) - 0.5);
	float ln2 = 1.0 - smoothstep(0.0, w * 0.2, 0.5 - max(g10.x, g10.y));
	vec3 c = vec3(0.034, 0.037, 0.04);
	c = mix(c, vec3(0.06, 0.075, 0.08), max(ln * 0.5, ln2 * 0.8));
	float fade = 1.0 - smoothstep(radius * 0.3, radius, r);
	ALBEDO = c * fade;
	EMISSION = vec3(0.3, 0.26, 0.21) * sheen * (1.0 - smoothstep(0.0, radius * 1.6, length(wp.xz + vec2(0.0, radius * 0.5))));
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
}
"""


# --- the entries -----------------------------------------------------------------------

func _build_entries() -> Array:
	var out := []
	# who carries / mounts each weapon
	var users := {}
	for u in Defs.UNITS:
		var w: String = Defs.UNITS[u].weapon
		if w != "":
			users[w] = users.get(w, []) + [String(Defs.UNITS[u].name)]
	for v in Defs.VEHICLES:
		var vw: String = Defs.VEHICLES[v].get("mg", "")
		if vw != "":
			users[vw] = users.get(vw, []) + [String(Defs.VEHICLES[v].name)]
	users["mmg"] = users.get("mmg", []) + ["MG Nest"]
	users["m2"] = users.get("m2", []) + [".50 Cal Nest"]
	var squads_of := {}
	for sq in Defs.SQUADS:
		for m in Defs.SQUADS[sq].members:
			if not String(Defs.SQUADS[sq].name) in squads_of.get(m, []):
				squads_of[m] = squads_of.get(m, []) + [String(Defs.SQUADS[sq].name)]
	# category maxima for the bars
	var mx := func(table: Dictionary, f: Callable) -> float:
		var best := 0.001
		for k in table:
			best = maxf(best, float(f.call(table[k])))
		return best

	# weapons
	var wmax := {"dmg": mx.call(Defs.WEAPONS, func(w): return w.dmg), "range": mx.call(Defs.WEAPONS, func(w): return w.range),
		"rpm": mx.call(Defs.WEAPONS, func(w): return 60.0 / float(w.interval)), "supp": mx.call(Defs.WEAPONS, func(w): return w.supp),
		"dps": mx.call(Defs.WEAPONS, func(w): return _dps(w)), "acc": mx.call(Defs.WEAPONS, func(w): return w.acc)}
	for k in Defs.WEAPONS:
		if not users.has(k):
			continue  # nothing in the game carries it
		var w: Dictionary = Defs.WEAPONS[k]
		var rpm := 60.0 / float(w.interval)
		var bmin: int = (w.burst as Vector2i).x
		var bmax: int = (w.burst as Vector2i).y
		var flags := []
		if w.get("ap", false):
			flags.append("armour-piercing")
		if w.has("he"):
			flags.append("high-explosive (%.1f m)" % float(w.he))
		if w.get("airburst", false):
			flags.append("airburst over trenches")
		if w.get("aa", false):
			flags.append("anti-aircraft")
		var sides := {}
		for u in Defs.UNITS:
			if Defs.UNITS[u].weapon == k:
				sides[int(Defs.UNITS[u].team)] = true
		for v in Defs.VEHICLES:
			if Defs.VEHICLES[v].get("mg", "") == k:
				sides[int(Defs.VEHICLES[v].team)] = true
		var wt := -1 if sides.size() != 1 else int(sides.keys()[0])
		out.append({"cat": "weapons", "key": k, "name": String(w.name), "team": wt, "both": sides.size() > 1 or k in ["mmg", "m2"],
			"sub": "%d dmg · %d m · %d rpm" % [int(w.dmg), int(w.range), int(rpm)], "pattern": PATTERN.get(k, ""),
			"role": "crew-served" if k in ["mmg", "m2"] else ("vehicle weapon" if not k in ["rifle", "ak", "smg", "lmg", "pistol"] else "small arm"),
			"desc": ", ".join(flags).capitalize() + ("." if not flags.is_empty() else "Bursts of %d-%d rounds." % [bmin, bmax]),
			"stats": [
				["Damage per hit", "%d" % int(w.dmg), float(w.dmg) / wmax.dmg],
				["Effective range", "%d m" % int(w.range), float(w.range) / wmax.range],
				["Rate of fire", "%d rounds / min" % int(rpm), rpm / wmax.rpm],
				["Accuracy", "%d%%" % int(float(w.acc) * 100.0), float(w.acc) / wmax.acc],
				["Sustained damage", "%.0f / s" % _dps(w), _dps(w) / wmax.dps],
				["Suppression", "%d per burst round" % int(w.supp), float(w.supp) / wmax.supp],
				["Bursts", "%d-%d rounds" % [bmin, bmax], -1.0],
				["Magazine / belt", ("%d" % int(w.mag)) + ("" if int(w.ammo) >= 9000 else "  (%d carried)" % int(w.ammo)), -1.0],
				["Reload", "%.1f s" % float(w.reload), -1.0],
			],
			"rel": ["Used by: " + ", ".join(users.get(k, []))]})

	# infantry
	var hmax: float = mx.call(Defs.UNITS, func(u): return u.hp)
	for k in Defs.UNITS:
		var u: Dictionary = Defs.UNITS[k]
		var wk: String = u.weapon
		var wd: Dictionary = Defs.WEAPONS.get(wk, {})
		var kit := []
		if int(u.frags) > 0:
			kit.append("%d frag grenade%s" % [int(u.frags), "s" if int(u.frags) > 1 else ""])
		if int(u.smokes) > 0:
			kit.append("%d smoke" % int(u.smokes))
		if int(u.get("rockets", 0)) > 0:
			kit.append("%d %s" % [int(u.rockets), "RPG-7 rockets" if int(u.team) == 1 else "AT rockets"])
		if int(u.get("mortar", 0)) > 0:
			kit.append("%d mortar bombs" % int(u.mortar))
		if int(u.get("drones", 0)) > 0:
			kit.append("%d FPV drones" % int(u.drones))
		var role := "rifleman"
		if u.get("crew", false):
			role = "vehicle crew"
		elif u.get("medic", false):
			role = "medic"
		elif u.get("engineer", false):
			role = "engineer"
		elif int(u.get("rockets", 0)) > 0:
			role = "anti-tank"
		elif int(u.get("mortar", 0)) > 0:
			role = "indirect fire"
		elif int(u.get("drones", 0)) > 0:
			role = "drone operator"
		elif wk == "lmg":
			role = "automatic rifleman"
		elif u.get("bearer", false):
			role = "casualty evacuation"
		var st := [
			["Health", "%d" % int(u.hp), float(u.hp) / hmax],
			["Weapon", (String(wd.get("name", "unarmed")) + ("  (%d dmg, %d m)" % [int(wd.dmg), int(wd.range)] if not wd.is_empty() else "")), -1.0],
			["Kit", ", ".join(kit) if not kit.is_empty() else "-", -1.0],
		]
		if float(u.get("heal", 1.0)) > 1.0:
			st.append(["First aid", "x%.1f faster" % float(u.heal), -1.0])
		if float(u.get("build", 1.0)) > 1.0:
			st.append(["Building / digging", "x%.1f faster" % float(u.build), -1.0])
		out.append({"cat": "infantry", "key": k, "name": String(u.name), "team": int(u.team), "role": role,
			"sub": "%s · %d hp" % [String(wd.get("name", "unarmed")), int(u.hp)], "pattern": PATTERN.get(wk, "") if wk != "" else "",
			"desc": _unit_desc(k, u), "stats": st,
			"rel": (["In: " + ", ".join(squads_of.get(k, []))] if squads_of.has(k) else [])})

	# squads
	var cmax: float = mx.call(Defs.SQUADS, func(s): return s.cost)
	var fmax: float = mx.call(Defs.SQUADS, func(s): return _squad_fire(s))
	for k in Defs.SQUADS:
		var s: Dictionary = Defs.SQUADS[k]
		var names := []
		for m in s.members:
			names.append(String(Defs.UNITS[m].name))
		var free: bool = int(s.cost) == 0
		out.append({"cat": "squads", "key": k, "name": String(s.name), "team": int(s.team),
			"sub": ("%d men · %d supply" % [s.members.size(), int(s.cost)]) if not free else "%d men · comes with its vehicle" % s.members.size(),
			"desc": String(s.desc), "stats": [
				["Men", "%d" % s.members.size(), float(s.members.size()) / 6.0],
				["Firepower", "%.0f damage / s" % _squad_fire(s), _squad_fire(s) / fmax],
				["Cost", ("%d supply" % int(s.cost)) if not free else "-", float(s.cost) / cmax],
				["Training time", ("%d s" % int(s.time)) if not free else "-", -1.0],
			], "rel": ["Members: " + ", ".join(names), "Trained at: " + ("the Barracks" if not free else ("an IFV (Factory)" if int(s.team) == 0 else "a BTR (Factory)"))]})

	# vehicles
	var vhp: float = mx.call(Defs.VEHICLES, func(v): return v.hp)
	var vsp: float = mx.call(Defs.VEHICLES, func(v): return v.speed)
	var vco: float = mx.call(Defs.VEHICLES, func(v): return v.cost)
	for k in Defs.VEHICLES:
		var v: Dictionary = Defs.VEHICLES[k]
		var arm: String = ["none (soft-skinned)", "light (stops rifle fire)", "heavy (small arms bounce off)"][clampi(int(v.armor), 0, 2)]
		var guns := []
		if v.get("cannon", false):
			guns.append("main gun")
		if String(v.get("mg", "")) != "":
			guns.append(String(Defs.WEAPONS[v.mg].name))
		if v.has("atgm"):
			guns.append("%d anti-tank missiles" % int(v.atgm[0]))
		if v.has("sam"):
			guns.append("%d anti-aircraft missiles" % int(v.sam[0]))
		if int(v.get("rockets", 0)) > 0 and String(v.get("base", "")) == "attack_heli":
			guns.append("rocket pods")
		if v.has("art"):
			guns.append(("%s, %d-%d m" % ["rocket artillery" if String(v.art.shell) == "grad" else "howitzer", int(v.art.min), int(v.art.max)]))
		var where := "the Factory"
		for b in Defs.BUILDINGS:
			var pr: Array = Defs.BUILDINGS[b].get("produces", [[], []])
			for side_list in pr:
				if k in side_list:
					where = "the " + String(Defs.BUILDINGS[b].name)
		var st2 := [
			["Hit points", "%d" % int(v.hp), float(v.hp) / vhp],
			["Armour", arm, float(v.armor) / 2.0],
			["Top speed", "%d km/h" % int(float(v.speed) * 3.6), float(v.speed) / vsp],
			["Armament", ", ".join(guns) if not guns.is_empty() else "unarmed", -1.0],
			["Cost", ("%d supply" % int(v.cost)) if int(v.cost) > 0 else "-", float(v.cost) / vco],
			["Build time", ("%d s" % int(v.time)) if float(v.time) > 0.0 else "-", -1.0],
		]
		if v.has("carry"):
			st2.append(["Carries", "%s (%d men)" % [String(Defs.SQUADS[v.carry].name), Defs.SQUADS[v.carry].members.size()], -1.0])
		if v.has("service"):
			st2.append(["Service", {"repair": "repairs vehicles within 13 m", "ammo": "rearms men and vehicles within 13 m", "medical": "treats the wounded within 11 m"}.get(String(v.service), String(v.service)), -1.0])
		if v.has("sight"):
			st2.append(["Sees", "%d m" % int(v.sight), -1.0])
		if int(v.get("tier", 1)) > 1:
			var tier_r := ""
			for uk in Defs.UPGRADES:
				if int(Defs.UPGRADES[uk].get("tier", 0)) == int(v.tier) and int(v.team) in Defs.UPGRADES[uk].teams:
					tier_r = String(Defs.UPGRADES[uk].name)
			st2.append(["Unlocked by", "%s (tier %d)" % [tier_r, int(v.tier)], -1.0])
		var vpage: String = "veh_air" if v.get("air", false) else {"light": "veh_light", "armour": "veh_armour", "support": "veh_support", "logistics": "veh_support", "air": "veh_air", "naval": "boats"}.get(
			String(v.get("cat", "")), "veh_armour" if String(v.get("base", "")) in ["tank", "afv"] else ("veh_support" if String(v.get("base", "")) in ["spaa", "supply", "util", "arty"] else "veh_light"))
		var rel := ["Built at " + where] if int(v.cost) > 0 else ["Drives supply from your depot to the FOBs"]
		if v.has("faction"):
			rel.append("%s - %s" % [String(v.faction), String(v.get("role", ""))])
		out.append({"cat": vpage, "key": k, "name": String(v.name), "team": int(v.team),
			"role": String(v.get("faction", "aircraft" if v.get("air", false) else ("tracked" if v.get("tracked", false) else "wheeled"))),
			"sub": "%d hp · %s" % [int(v.hp), ", ".join(guns) if not guns.is_empty() else "unarmed"], "pattern": String(v.get("pattern", PATTERN.get(k, ""))),
			"desc": String(v.desc), "stats": st2, "rel": rel})
	# the rest of the Arma 3 garage: aircraft, boats, civilian vehicles
	for g in VehicleRoster.garage():
		var gteam := -1
		var gf: String = g[3]
		if gf.begins_with("NATO") or gf.begins_with("AAF"):
			gteam = 0
		elif gf.begins_with("CSAT") or gf.begins_with("FIA") or gf.begins_with("Syndikat"):
			gteam = 1
		out.append({"cat": g[2], "key": g[0], "name": g[1], "team": gteam, "both": gteam < 0, "role": gf,
			"sub": "%s · %s" % [g[4], gf], "pattern": g[5], "desc": g[9],
			"stats": [["Role", g[4], -1.0], ["Crew / passengers", g[6], -1.0], ["Top speed", "%d km/h" % int(g[7]), clampf(float(g[7]) / 1500.0, 0.0, 1.0)], ["Armament", g[8], -1.0]],
			"rel": ["Faction: " + gf]})

	# buildings and defences
	var bhp: float = mx.call(Defs.BUILDINGS, func(b): return b.hp)
	var bco: float = mx.call(Defs.BUILDINGS, func(b): return b.cost)
	for k in Defs.BUILDINGS:
		var b: Dictionary = Defs.BUILDINGS[k]
		var tms: Array = b.teams
		var rel := []
		var pr2: Array = b.get("produces", [])
		for si in pr2.size():
			if not (pr2[si] as Array).is_empty():
				var nm := []
				for it in pr2[si]:
					nm.append(String(Defs.SQUADS[it].name) if Defs.SQUADS.has(it) else String(Defs.VEHICLES[it].name))
				rel.append("%s: %s" % [Defs.TEAM_NAMES[si], ", ".join(nm)])
		if k == "research":
			var ups := []
			for u2 in Defs.UPGRADES:
				ups.append(String(Defs.UPGRADES[u2].name))
			rel.append("Researches: " + ", ".join(ups))
		var crew := ""
		match k:
			"mg_nest":
				crew = "GPMG: %d dmg, %d m" % [int(Defs.WEAPONS.mmg.dmg), int(Defs.WEAPONS.mmg.range)]
			"hmg_nest":
				crew = ".50 cal: %d dmg, %d m, armour-piercing" % [int(Defs.WEAPONS.m2.dmg), int(Defs.WEAPONS.m2.range)]
		var st3 := [
			["Hit points", "%d" % int(b.hp), float(b.hp) / bhp],
			["Cost", "%d supply" % int(b.cost), float(b.cost) / bco],
			["Build time", "%d s (one engineer)" % int(b.time), -1.0],
			["Footprint", "%.1f x %.1f m" % [(b.size as Vector2).x, (b.size as Vector2).y], -1.0],
		]
		if crew != "":
			st3.insert(0, ["Crewed weapon", crew, -1.0])
		out.append({"cat": "bases" if k in BASES else "defences", "key": k, "name": String(b.name),
			"team": int(tms[0]) if tms.size() == 1 else -1, "both": tms.size() > 1,
			"sub": "%d supply · %d hp" % [int(b.cost), int(b.hp)], "pattern": PATTERN.get(k, ""),
			"desc": String(b.desc), "stats": st3, "rel": rel})

	# the towns: taken, not built
	out.append({"cat": "bases", "key": "town", "name": "Town supply dump", "team": -1, "both": true,
		"sub": "taken, not built · %d-%d supply a minute" % [int(Defs.TOWN_YIELD[0]), int(Defs.TOWN_YIELD[1])],
		"pattern": "a town's stores: crated goods on pallets, fuel drums, the flag of whoever holds it",
		"desc": "The town and every village have one, by the main street. Whoever holds the place draws on it - food, fuel, lorries, labour - and its own lorry trucks the stock to their nearest FOB along a road you can ambush like any supply road. To take one, get men inside its ring with none of the other side's there: a squad takes a village in about half a minute, the town in nearer a minute; both sides there and nobody gains; the holder's men push it back. A town shelled to ruins gives about a third of what it did. A FOB can go up near a town you hold, and your men round the dump fill their pouches from it.",
		"stats": [
			["Supply a minute", "%d (village) / %d (town)" % [int(Defs.TOWN_YIELD[0]), int(Defs.TOWN_YIELD[1])], -1.0],
			["Dump holds", "%d / %d" % [int(Defs.TOWN_STOCK[0]), int(Defs.TOWN_STOCK[1])], -1.0],
			["Truck leaves at", "%d / %d supply" % [int(Defs.TOWN_LOAD[0]), int(Defs.TOWN_LOAD[1])], -1.0],
			["Ground to hold", "%d m / %d m ring" % [int(Defs.TOWN_RADIUS[0]), int(Defs.TOWN_RADIUS[1])], -1.0],
		], "rel": ["On every map: the town in the middle, a village on each country road", "Trucks to the holder's nearest FOB"]})

	# fire support
	var sco: float = mx.call(Defs.SUPPORT, func(s): return s.cost)
	var scd: float = mx.call(Defs.SUPPORT, func(s): return s.cooldown)
	var srr: float = mx.call(Defs.SUPPORT, func(s): return 0.0 if s.get("recon", false) else s.r)  # (a recon flight's sight is on another scale)
	for k in Defs.SUPPORT:
		var s2: Dictionary = Defs.SUPPORT[k]
		if int(s2.team) < 0:
			continue
		var shape: String = {"line": "a line, dragged to set the run-in", "strafe": "a strafing line, dragged", "orbit": "an orbit over a circle", "circle": "a circle",
			"sweep": "a line it flies along, dragged", "watch": "an orbit over a circle"}.get(String(s2.shape), String(s2.shape))
		var from_min := int(Defs.support_from(k) / 60.0)
		out.append({"cat": "support", "key": k, "name": String(s2.name), "team": int(s2.team),
			"sub": "%d supply · every %d s" % [int(s2.cost), int(s2.cooldown)], "pattern": String(s2.get("pattern", PATTERN.get(k, ""))),
			"desc": String(s2.desc), "stats": [
				["Cost", "%d supply" % int(s2.cost), float(s2.cost) / sco],
				["Cooldown", "%d s" % int(s2.cooldown), float(s2.cooldown) / scd],
				["Sees" if s2.get("recon", false) else "Area", ("%d m either side" if String(s2.shape) == "sweep" else "%d m radius") % int(s2.r), minf(1.0, float(s2.r) / srr)],
				["Aimed as", shape, -1.0],
			], "rel": ["Called from the support panel or Z, from minute %s" % ["one", "two", "three", "four", "five", "six"][clampi(from_min - 1, 0, 5)]]})

	# battlefield cover
	for c in COVER:
		var m := Cover.FORT if c[2] == "trench" else (Cover.mat_of({"skind": c[2], "variant": c[3]}) if c[2] != "" else (Cover.HARD if c[0] == "c_crater" else -1))
		var h: float = c[5]
		var how: String = "fire round its ends" if h >= Cover.STAND_MAX else (["lie behind it and fire over the lip", "kneel and fire over it", "stand and fire over it", ""][Cover.stance(h)] if h > 0.0 else "kneel among the trees")
		var stops: String = Cover.MAT_STOPS[m] if m >= 0 else "Nothing - but it hides you"
		var cst := [
			["Protection", (Cover.MAT_NAMES[m] if m >= 0 else "Concealment"), (float(m) + 1.0) / 4.0 if m >= 0 else 0.08],
			["Stops", stops, -1.0],
			["Height", ("%.2f m" % h) if h > 0.0 else "-", clampf(h / 2.6, 0.0, 1.0) if h > 0.0 else -1.0],
			["Fight from it", how, -1.0],
		]
		if m >= 0 and c[0] != "c_crater":
			cst.append(["Rifle / MG / .50 through it", "%d%% / %d%% / %d%%" % [int(Cover.PASS[m][1] * 100.0), int(Cover.PASS[m][2] * 100.0), int(Cover.PASS[m][3] * 100.0)], -1.0])
			cst.append(["Blast behind it", "%d%%" % int(Cover.BLAST[m] * 100.0), Cover.BLAST[m]])
		out.append({"cat": "cover", "key": c[0], "name": c[1], "team": -1, "both": true,
			"sub": "%s · %s" % [(Cover.MAT_NAMES[m] if m >= 0 else "Concealment"), how], "desc": c[7], "stats": cst,
			"rel": ["Found: " + c[6]]})

	# drills and reflexes
	for di in DRILLS.size():
		var dr: Array = DRILLS[di]
		out.append({"cat": "drills", "key": dr[0], "name": dr[1], "team": -1, "both": true,
			"sub": String(dr[5]), "desc": String(dr[7]), "stats": [
				["When", String(dr[5]), -1.0], ["The risk", String(dr[6]), -1.0]],
			"rel": ["Every squad, both sides" if String(dr[0]).begins_with("s_") else ("Every tank, IFV, APC and armed car" if String(dr[0]).begins_with("v_") else "Every soldier, both sides"), "A behaviour tree decides it (see README)"]})

	# upgrades
	for k in Defs.UPGRADES:
		var up: Dictionary = Defs.UPGRADES[k]
		var ut: Array = up.teams
		out.append({"cat": "upgrades", "key": k, "name": String(up.name), "team": int(ut[0]) if ut.size() == 1 else -1, "both": ut.size() > 1,
			"sub": "%d supply · %d s" % [int(up.cost), int(up.time)], "desc": String(up.desc), "stats": [
				["Cost", "%d supply" % int(up.cost), -1.0], ["Research time", "%d s" % int(up.time), -1.0]],
			"rel": ["Researched at the Research Post"]})
	return out


## Damage per second over a long fight: bursts with the pauses between them,
## times the chance a round hits.
static func _dps(w: Dictionary) -> float:
	var b: Vector2i = w.burst
	var avg := (b.x + b.y) * 0.5
	var cycle := avg * float(w.interval) + 0.85
	return float(w.dmg) * float(w.acc) * avg / cycle


static func _squad_fire(s: Dictionary) -> float:
	var t := 0.0
	for m in s.members:
		var wk: String = Defs.UNITS[m].weapon
		if Defs.WEAPONS.has(wk):
			t += _dps(Defs.WEAPONS[wk])
	return t


func _unit_desc(k: String, u: Dictionary) -> String:
	if u.get("medic", false):
		return "Patches up the wounded under fire, drags them to cover and calls the stretcher bearers."
	if u.get("engineer", false):
		return "Builds bases and defences, digs trenches%s and repairs tracks." % (" and tunnels" if int(u.team) == 1 else "")
	if int(u.get("rockets", 0)) > 0:
		return "Hunts vehicles and bunkers with rockets; pops up from cover to fire."
	if int(u.get("mortar", 0)) > 0:
		return "Carries a light mortar and drops bombs on anything his side has spotted, behind cover too."
	if int(u.get("drones", 0)) > 0:
		return "Flies kamikaze FPV drones into infantry and armour from behind cover."
	if u.get("bearer", false):
		return "Carries the wounded and the dead back to the medic tent."
	if u.weapon == "lmg":
		return "The squad's automatic weapon: pins the enemy down so the riflemen can move. Crews MG nests."
	return "The backbone of the squad: fights from cover, throws grenades, moves by bounds."


## How a number compares with the rest of its kind, as a counted bar: as
## many steps lit as its share of the biggest (never none, if it has any).
class StatBar extends Control:
	var frac := 0.0

	func _draw() -> void:
		if frac < 0.0:
			return
		var n := maxi(4, int((size.x + 2.0) / 9.0))
		var lit := ceilf(clampf(frac, 0.0, 1.0) * n - 0.25) if frac > 0.0 else 0.0
		UiKit.steps(self, Vector2(0, floorf(size.y * 0.5) - 5.0), maxf(lit, 1.0 if frac > 0.0 else 0.0), n, UiKit.TEXT, 7.0, 10.0)


## Whose something is: a small square in its side's colour, halved between
## the two when both sides have it.
class SideMark extends Control:
	var team := -1
	var both := false
	var dy := 0.0  # up or down from the middle, to sit level with a line of text

	func _draw() -> void:
		var s := 8.0
		var p := Vector2(0, floorf(size.y * 0.5 - s * 0.5 + dy))
		if both or team < 0:
			draw_rect(Rect2(p, Vector2(s * 0.5, s)), Defs.TEAM_COLORS[0])
			draw_rect(Rect2(p + Vector2(s * 0.5, 0), Vector2(s * 0.5, s)), Defs.TEAM_COLORS[1])
		else:
			draw_rect(Rect2(p, Vector2(s, s)), Defs.TEAM_COLORS[team])
