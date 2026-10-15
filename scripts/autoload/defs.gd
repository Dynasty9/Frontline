extends Node
## Global constants and data tables shared by the server and every client.

const ARMY := 0
const REBELS := 1
const TEAM_NAMES := ["Coalition", "Rebels"]
const TEAM_COLORS := [Color(0.35, 0.62, 1.0), Color(1.0, 0.36, 0.28)]
const MAP_HALF := MapDims.HALF
const GRID_N := 256

# physics layers (bit values)
const L_COVER := 2
const L_VEHICLE := 4

const CAP_PER_FOB := 20
const BASE_CAP := 6
const FOB_RADIUS := 16.0
const BUILD_RADIUS := 70.0
const FOB_EXPAND_RADIUS := 130.0
const FOB_MIN_SPACING := 45.0
const SUPPLY_PER_TRUCK := [115, 130]  # Rebels run bigger loads to make up for having no helicopters (trucks drive like trucks: fewer runs, bigger loads)
const START_SUPPLY := 500

const FOB_NAMES := [
	["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima"],
	["Viper", "Cobra", "Jackal", "Falcon", "Wolf", "Hyena", "Scorpion", "Raven", "Mamba", "Lynx", "Kestrel", "Adder"],
]

const NAMES := [
	["Miller", "Garcia", "Novak", "Reyes", "Hughes", "Brooks", "Turner", "Price", "Walsh", "Hayes", "Ortiz", "Fischer",
	"Larsen", "Duval", "Okafor", "Silva", "Park", "Murphy", "Cohen", "Patel", "Becker", "Rossi", "Dubois", "Nakamura",
	"Kowalski", "Byrne", "Lindqvist", "Moreau", "Haddad", "Santos", "Kim", "Wright", "Foster", "Grant", "Doyle", "Vance"],
	["Karim", "Yusuf", "Tariq", "Omar", "Dmitri", "Bogdan", "Rami", "Sami", "Farid", "Hakim", "Nikolai", "Zoran",
	"Jamal", "Idris", "Malik", "Anton", "Viktor", "Emir", "Rustam", "Kadir", "Ilya", "Goran", "Nabil", "Aziz",
	"Faisal", "Lev", "Marek", "Hamza", "Bilal", "Ruslan", "Selim", "Taras", "Yaro", "Zaid", "Oleg", "Darius"],
]

var WEAPONS := {
	"rifle": {"name": "Rifle", "dmg": 30.0, "range": 60.0, "interval": 0.12, "burst": Vector2i(2, 4), "acc": 0.6, "mag": 30, "ammo": 210, "reload": 2.2, "supp": 11.0, "snd": "rifle"},
	"ak": {"name": "AK", "dmg": 32.0, "range": 55.0, "interval": 0.11, "burst": Vector2i(2, 5), "acc": 0.535, "mag": 30, "ammo": 210, "reload": 2.4, "supp": 12.0, "snd": "rifle"},
	"smg": {"name": "SMG", "dmg": 21.0, "range": 38.0, "interval": 0.08, "burst": Vector2i(3, 6), "acc": 0.55, "mag": 30, "ammo": 180, "reload": 2.0, "supp": 8.0, "snd": "smg"},
	"lmg": {"name": "LMG", "dmg": 26.0, "range": 72.0, "interval": 0.075, "burst": Vector2i(6, 12), "acc": 0.42, "mag": 100, "ammo": 500, "reload": 4.5, "supp": 22.0, "snd": "mg"},
	"pistol": {"name": "Pistol", "dmg": 16.0, "range": 25.0, "interval": 0.45, "burst": Vector2i(1, 2), "acc": 0.35, "mag": 12, "ammo": 9999, "reload": 1.6, "supp": 4.0, "snd": "pistol"},
	"hmg": {"name": "HMG", "dmg": 38.0, "range": 82.0, "interval": 0.09, "burst": Vector2i(6, 14), "acc": 0.45, "mag": 150, "ammo": 99999, "reload": 4.0, "supp": 30.0, "snd": "mg"},
	"mmg": {"name": "GPMG", "dmg": 30.0, "range": 80.0, "interval": 0.08, "burst": Vector2i(6, 12), "acc": 0.45, "mag": 200, "ammo": 99999, "reload": 3.5, "supp": 26.0, "snd": "mg"},
	"m2": {"name": ".50 cal", "dmg": 55.0, "range": 100.0, "interval": 0.12, "burst": Vector2i(4, 9), "acc": 0.5, "mag": 100, "ammo": 99999, "reload": 4.0, "supp": 38.0, "snd": "hmg", "ap": true},
	"chaingun": {"name": "30 mm chain gun", "dmg": 30.0, "range": 115.0, "interval": 0.16, "burst": Vector2i(5, 9), "acc": 0.55, "mag": 300, "ammo": 99999, "reload": 4.0, "supp": 45.0, "snd": "hmg", "ap": true, "he": 2.2},
	"zu23": {"name": "Twin 23 mm", "dmg": 15.0, "range": 110.0, "interval": 0.08, "burst": Vector2i(8, 14), "acc": 0.5, "mag": 200, "ammo": 99999, "reload": 4.0, "supp": 40.0, "snd": "hmg", "ap": true, "he": 1.2, "aa": true},
	"bushmaster": {"name": "25 mm Bushmaster", "dmg": 32.0, "range": 115.0, "interval": 0.28, "burst": Vector2i(3, 6), "acc": 0.6, "mag": 300, "ammo": 99999, "reload": 4.0, "supp": 42.0, "snd": "hmg", "ap": true, "he": 1.9, "airburst": true},
	"kpvt": {"name": "14.5 mm KPVT", "dmg": 62.0, "range": 105.0, "interval": 0.14, "burst": Vector2i(4, 8), "acc": 0.5, "mag": 100, "ammo": 99999, "reload": 4.0, "supp": 40.0, "snd": "hmg", "ap": true},
	"coax": {"name": "Coax MG", "dmg": 26.0, "range": 70.0, "interval": 0.08, "burst": Vector2i(5, 10), "acc": 0.45, "mag": 200, "ammo": 99999, "reload": 3.0, "supp": 22.0, "snd": "mg"},
	"gmg": {"name": "40 mm GMG", "dmg": 20.0, "range": 95.0, "interval": 0.17, "burst": Vector2i(3, 6), "acc": 0.42, "mag": 96, "ammo": 99999, "reload": 4.0, "supp": 34.0, "snd": "gmg", "he": 1.7},
	"ac20": {"name": "20 mm autocannon", "dmg": 24.0, "range": 105.0, "interval": 0.12, "burst": Vector2i(3, 6), "acc": 0.55, "mag": 160, "ammo": 99999, "reload": 4.0, "supp": 34.0, "snd": "ac", "ap": true, "he": 1.2},
	"ac30": {"name": "30 mm CTWS", "dmg": 30.0, "range": 115.0, "interval": 0.22, "burst": Vector2i(3, 5), "acc": 0.58, "mag": 140, "ammo": 99999, "reload": 4.0, "supp": 42.0, "snd": "ac", "ap": true, "he": 2.0},
	"ac40": {"name": "40 mm cannon", "dmg": 38.0, "range": 120.0, "interval": 0.3, "burst": Vector2i(2, 4), "acc": 0.6, "mag": 100, "ammo": 99999, "reload": 4.0, "supp": 46.0, "snd": "ac", "ap": true, "he": 2.4},
	"twin35": {"name": "Twin 35 mm", "dmg": 20.0, "range": 130.0, "interval": 0.06, "burst": Vector2i(8, 14), "acc": 0.5, "mag": 300, "ammo": 99999, "reload": 4.0, "supp": 40.0, "snd": "ac", "ap": true, "he": 1.2, "aa": true},
	"minigun": {"name": "Minigun", "dmg": 19.0, "range": 85.0, "interval": 0.035, "burst": Vector2i(14, 26), "acc": 0.3, "mag": 2000, "ammo": 99999, "reload": 3.0, "supp": 30.0, "snd": "minigun"},
	"m197": {"name": "20 mm chin gun", "dmg": 26.0, "range": 110.0, "interval": 0.1, "burst": Vector2i(5, 9), "acc": 0.52, "mag": 400, "ammo": 99999, "reload": 4.0, "supp": 40.0, "snd": "ac", "ap": true, "he": 1.3},
}

# hp, weapon and kit per soldier type
var UNITS := {
	"rifleman": {"name": "Rifleman", "team": 0, "weapon": "rifle", "hp": 100.0, "frags": 2, "smokes": 1, "build": 1.0, "heal": 1.0},
	"medic": {"name": "Medic", "team": 0, "weapon": "smg", "hp": 100.0, "frags": 0, "smokes": 2, "build": 1.0, "heal": 2.0, "medic": true},
	"engineer": {"name": "Engineer", "team": 0, "weapon": "smg", "hp": 100.0, "frags": 1, "smokes": 1, "build": 2.0, "heal": 1.0, "engineer": true},
	"mg_gunner": {"name": "MG Gunner", "team": 0, "weapon": "lmg", "hp": 110.0, "frags": 0, "smokes": 1, "build": 1.0, "heal": 1.0},
	"at_soldier": {"name": "AT Specialist", "team": 0, "weapon": "rifle", "hp": 100.0, "frags": 1, "smokes": 0, "build": 1.0, "heal": 1.0, "rockets": 4},
	"fighter": {"name": "Fighter", "team": 1, "weapon": "ak", "hp": 100.0, "frags": 1, "smokes": 1, "build": 1.0, "heal": 1.0},
	"r_medic": {"name": "Medic", "team": 1, "weapon": "ak", "hp": 95.0, "frags": 0, "smokes": 2, "build": 1.0, "heal": 2.0, "medic": true},
	"digger": {"name": "Digger", "team": 1, "weapon": "ak", "hp": 95.0, "frags": 1, "smokes": 0, "build": 2.0, "heal": 1.0, "engineer": true},
	"pkm": {"name": "PKM Gunner", "team": 1, "weapon": "lmg", "hp": 105.0, "frags": 0, "smokes": 1, "build": 1.0, "heal": 1.0},
	"rpg": {"name": "RPG Gunner", "team": 1, "weapon": "ak", "hp": 95.0, "frags": 1, "smokes": 0, "build": 1.0, "heal": 1.0, "rockets": 4},
	"fpv_op": {"name": "FPV Operator", "team": 1, "weapon": "pistol", "hp": 90.0, "frags": 0, "smokes": 1, "build": 1.0, "heal": 1.0, "drones": 4},
	"mortar_gunner": {"name": "Mortarman", "team": 0, "weapon": "rifle", "hp": 100.0, "frags": 1, "smokes": 1, "build": 1.0, "heal": 1.0, "mortar": 16},
	"r_mortar": {"name": "Mortarman", "team": 1, "weapon": "ak", "hp": 100.0, "frags": 1, "smokes": 1, "build": 1.0, "heal": 1.0, "mortar": 16},
	"bearer": {"name": "Stretcher Bearer", "team": -1, "weapon": "", "hp": 100.0, "frags": 0, "smokes": 0, "build": 0.0, "heal": 1.5, "bearer": true},
}

var SQUADS := {
	"rifle_squad": {"name": "Rifle Squad", "team": 0, "cost": 100, "time": 12.0, "members": ["rifleman", "rifleman", "rifleman", "rifleman", "medic"], "desc": "Four riflemen and a medic."},
	"engineer_team": {"name": "Engineers", "team": 0, "cost": 70, "time": 9.0, "members": ["engineer", "engineer", "engineer"], "desc": "Build twice as fast, repair tracks and buildings."},
	"mg_team": {"name": "MG Team", "team": 0, "cost": 80, "time": 10.0, "members": ["mg_gunner", "rifleman"], "desc": "Machine gun that pins enemies down."},
	"at_team": {"name": "AT Team", "team": 0, "cost": 90, "time": 11.0, "members": ["at_soldier", "at_soldier"], "desc": "Rocket launchers against vehicles."},
	"mortar_team": {"name": "Mortar Team", "team": 0, "cost": 100, "time": 12.0, "members": ["mortar_gunner", "rifleman"], "desc": "Mobile mortar. Shells enemies your side has spotted, even behind cover. F = fire mission."},
	"fighter_cell": {"name": "Fighter Cell", "team": 1, "cost": 85, "time": 10.0, "members": ["fighter", "fighter", "fighter", "fighter", "fighter", "r_medic"], "desc": "Five fighters and a medic."},
	"digger_team": {"name": "Diggers", "team": 1, "cost": 60, "time": 8.0, "members": ["digger", "digger", "digger"], "desc": "Build fast and dig tunnels."},
	"pkm_team": {"name": "PKM Team", "team": 1, "cost": 70, "time": 9.0, "members": ["pkm", "fighter"], "desc": "Machine gun that pins enemies down."},
	"rpg_team": {"name": "RPG Team", "team": 1, "cost": 80, "time": 10.0, "members": ["rpg", "rpg"], "desc": "RPGs against vehicles."},
	"r_mortar_team": {"name": "Mortar Team", "team": 1, "cost": 90, "time": 11.0, "members": ["r_mortar", "fighter"], "desc": "Mobile mortar. Shells enemies your side has spotted, even behind cover. F = fire mission."},
	"mech_team": {"name": "Mech Infantry", "team": 0, "cost": 0, "time": 0.0, "members": ["rifleman", "rifleman", "mg_gunner", "at_soldier"], "desc": "Rides in an IFV."},
	"mech_cell": {"name": "Mech Cell", "team": 1, "cost": 0, "time": 0.0, "members": ["fighter", "fighter", "pkm", "rpg"], "desc": "Rides in a BTR."},
	"fpv_team": {"name": "FPV Team", "team": 1, "cost": 100, "time": 12.0, "members": ["fpv_op", "fighter"], "desc": "Flies kamikaze drones into soldiers and tanks."},
}

## Every vehicle says what it is as well as what it's called. base: how it
## behaves - "tank" (main gun), "afv" (autocannon / heavy MG, may carry troops),
## "car" (light vehicle with a roof gun), "spaa", "attack_heli", "lift_heli",
## "supply" (the road convoy). size: the hull's box (collision, selection);
## weight: 0 light, 1 medium, 2 heavy (how blasts move it, how it rides);
## gun_h: where its guns sit; auto: runs itself (supply), not commanded.
var VEHICLES := {
	"tank": {"name": "Battle Tank", "team": 0, "cost": 300, "time": 30.0, "hp": 1400.0, "armor": 2, "speed": 6.5, "turn": 1.1, "cannon": true, "mg": "coax", "cap": 4, "tracked": true,
		"base": "tank", "size": Vector3(3.4, 2.2, 6.4), "weight": 2, "gun_h": 2.2, "desc": "Smashes walls. Small arms bounce off."},
	"old_tank": {"name": "Old Tank", "team": 1, "cost": 240, "time": 28.0, "hp": 1000.0, "armor": 2, "speed": 5.5, "turn": 0.9, "cannon": true, "mg": "coax", "cap": 4, "tracked": true,
		"base": "tank", "size": Vector3(3.4, 2.2, 6.4), "weight": 2, "gun_h": 2.2, "desc": "Smashes walls. Small arms bounce off."},
	"technical": {"name": "Technical", "team": 1, "cost": 130, "time": 16.0, "hp": 360.0, "armor": 0, "speed": 11.0, "turn": 1.8, "cannon": false, "mg": "m2", "cap": 2,
		"base": "car", "size": Vector3(2.0, 1.8, 4.6), "weight": 0, "gun_h": 2.0, "desc": "Fast pickup with a heavy machine gun."},
	"ifv": {"name": "IFV", "team": 0, "cost": 230, "time": 26.0, "hp": 820.0, "armor": 1, "speed": 8.5, "turn": 1.4, "cannon": false, "mg": "bushmaster", "cap": 3, "carry": "mech_team", "tracked": true,
		"base": "afv", "size": Vector3(2.3, 2.6, 6.0), "weight": 1, "gun_h": 2.2, "desc": "Tracked infantry fighting vehicle. Carries a fire team into the fight; its 25 mm airburst rounds burst right over trenches."},
	"btr": {"name": "BTR", "team": 1, "cost": 170, "time": 20.0, "hp": 620.0, "armor": 1, "speed": 10.5, "turn": 1.6, "cannon": false, "mg": "kpvt", "cap": 3, "carry": "mech_cell",
		"base": "afv", "size": Vector3(2.3, 2.6, 6.0), "weight": 1, "gun_h": 2.2, "desc": "Eight-wheeled APC with a 14.5 mm gun. Carries a fighter cell."},
	"humvee": {"name": "Humvee", "team": 0, "cost": 120, "time": 15.0, "hp": 460.0, "armor": 1, "speed": 12.0, "turn": 1.9, "cannon": false, "mg": "m2", "cap": 2,
		"base": "car", "size": Vector3(2.2, 2.0, 4.8), "weight": 0, "gun_h": 2.0, "desc": "Fast armoured car with a roof .50 cal. Scouts, hunts technicals, shreds soft targets."},
	"gunship": {"name": "Attack Helicopter", "team": 0, "cost": 380, "time": 35.0, "hp": 1100.0, "armor": 1, "speed": 22.0, "turn": 2.2, "cannon": false, "mg": "chaingun", "cap": 4, "air": true,
		"base": "attack_heli", "size": Vector3(2.0, 2.2, 6.5), "weight": 0, "gun_h": 0.8, "desc": "Circles its target firing a 30 mm chain gun and rocket salvos. Dreads .50 cals and AA technicals."},
	"aa_tech": {"name": "AA Technical", "team": 1, "cost": 150, "time": 18.0, "hp": 380.0, "armor": 0, "speed": 10.5, "turn": 1.8, "cannon": false, "mg": "zu23", "cap": 2, "aa": true,
		"base": "spaa", "size": Vector3(2.0, 1.9, 4.6), "weight": 0, "gun_h": 2.0, "desc": "Twin 23 mm cannon on a pickup. Tears helicopters, drones and anything soft apart."},
	"heli": {"name": "Supply Helicopter", "team": 0, "cost": 150, "time": 20.0, "hp": 320.0, "armor": 1, "speed": 20.0, "turn": 2.5, "cannon": false, "mg": "", "cap": 0, "air": true, "auto": true, "supply": true,
		"base": "lift_heli", "size": Vector3(2.2, 2.0, 6.0), "weight": 0, "gun_h": 1.0, "desc": "Keeps flying supply straight to your neediest FOB, ignoring roads. Can be shot down."},
	"truck": {"name": "Supply Truck", "team": -1, "cost": 0, "time": 0.0, "hp": 240.0, "armor": 0, "speed": 9.0, "turn": 2.0, "cannon": false, "mg": "", "cap": 0, "auto": true,
		"base": "supply", "size": Vector3(2.3, 2.6, 6.0), "weight": 1, "gun_h": 2.2, "desc": "Drives supply down the road."},
}

## Off-map support, called on a spot (Z). One per side, with a cooldown.
## Off-map support. shape: how the call is aimed (line / strafe runs take a
## direction, dragged out when calling it in), r: radius drawn on the map.
## fly: how it's flown - "jet" (a bomb run), "a10" (a strafing run), "orbit"
## (circles the spot firing its guns); model: the aircraft; bombs: how many;
## guns: an orbit's weapons (Projectile.GUNSETS); quiet: no warning to the enemy.
var SUPPORT := {
	"airstrike": {"name": "F/A-181 Black Wasp II Strike", "team": 0, "cost": 220, "cooldown": 120.0, "shape": "line", "r": 4.0, "fly": "jet", "model": "blackwasp", "bombs": 4,
		"pattern": "F/A-181 Black Wasp II (Super Hornet / F-22 hybrid), four 500 lb bombs",
		"desc": "A stealth fighter runs in and drops a stick of four bombs across the spot. Devastating in the open. Drag to set the run-in direction."},
	"a10": {"name": "A-10C Thunderbolt II Gun Run", "team": 0, "cost": 260, "cooldown": 150.0, "shape": "strafe", "r": 20.0, "fly": "a10", "model": "a10",
		"pattern": "Fairchild Republic A-10C Thunderbolt II, 30 mm GAU-8/A Avenger",
		"desc": "The Warthog comes in low and walks a burst of 30 mm through the spot: the impacts first, then the BRRRT. Drag to set the strafing line."},
	"wipeout": {"name": "A-164 Wipeout Gun Run", "team": 0, "cost": 250, "cooldown": 140.0, "shape": "strafe", "r": 20.0, "fly": "a10", "model": "wipeout",
		"pattern": "A-164 Wipeout (Arma's A-10 successor), 30 mm GAU-8 Avenger",
		"desc": "The Wipeout walks a burst of 30 mm through the spot. You'll see it, and the impacts, before you hear it. Drag to set the strafing line."},
	"ac130": {"name": "AC-130U Spooky Gunship", "team": 0, "cost": 420, "cooldown": 240.0, "shape": "orbit", "r": 38.0, "fly": "orbit", "model": "ac130", "guns": "ac130",
		"pattern": "Lockheed AC-130U Spooky II: 105 mm M102 howitzer, 40 mm Bofors, 25 mm GAU-12 Equalizer",
		"desc": "Spooky orbits overhead for 25 seconds, port wing down, hunting anything in the circle with its side-firing 105, 40 and 25 mm. You hear the guns, then the rounds arrive."},
	"blackfish": {"name": "V-44X Blackfish Gunship", "team": 0, "cost": 380, "cooldown": 220.0, "shape": "orbit", "r": 34.0, "fly": "orbit", "model": "blackfish_armed", "guns": "blackfish",
		"pattern": "V-44X Blackfish (enlarged V-22 / V-280 tiltrotor), 105 mm howitzer, 40 mm and 20 mm cannon",
		"desc": "The tiltrotor gunship orbits overhead for 25 seconds hunting anything in the circle with 105 mm, 40 mm and 20 mm - fewer heavy rounds than Spooky, and cheaper."},
	"buzzard": {"name": "A-143 Buzzard Strafe", "team": 0, "cost": 170, "cooldown": 110.0, "shape": "strafe", "r": 16.0, "fly": "a10", "model": "buzzard",
		"pattern": "A-143 Buzzard (Aero L-159 ALCA), twin 20 mm gun pod", "desc": "The allied light attack jet strafes the line with its 20 mm gun pod. Cheaper and lighter than the Wipeout. Drag to set the strafing line."},
	"gryphon": {"name": "A-149 Gryphon Precision Strike", "team": 0, "cost": 200, "cooldown": 130.0, "shape": "line", "r": 4.0, "fly": "jet", "model": "gryphon", "bombs": 2,
		"pattern": "A-149 Gryphon (Saab JAS 39 Gripen), two laser-guided bombs", "desc": "Two guided bombs, close together, exactly on the spot. Drag to set the run-in direction."},
	"greyhawk": {"name": "MQ-4A Greyhawk Drone", "team": 0, "cost": 240, "cooldown": 160.0, "shape": "orbit", "r": 30.0, "fly": "orbit", "model": "greyhawk", "guns": "greyhawk",
		"pattern": "MQ-4A Greyhawk (MQ-9 Reaper layout), six Skalpel missiles", "desc": "An armed drone circles the spot for 25 seconds firing guided missiles at whatever it finds there."},
	"sentinel": {"name": "UCAV Sentinel Strike", "team": 0, "cost": 260, "cooldown": 170.0, "shape": "line", "r": 4.0, "fly": "jet", "model": "sentinel", "bombs": 2, "quiet": true,
		"pattern": "UCAV Sentinel (Northrop Grumman X-47B), two GBU-12", "desc": "A stealth drone drops two bombs on the spot. The enemy gets no warning. Drag to set the run-in direction."},
	"neophron": {"name": "To-199 Neophron Strafe", "team": 1, "cost": 190, "cooldown": 120.0, "shape": "strafe", "r": 18.0, "fly": "a10", "model": "neophron",
		"pattern": "To-199 Neophron (Yakovlev Yak-130), 30 mm cannon", "desc": "CSAT's light attack jet walks its 30 mm cannon along the line. Drag to set the strafing line."},
	"shikra": {"name": "To-201 Shikra Bomb Run", "team": 1, "cost": 250, "cooldown": 150.0, "shape": "line", "r": 4.0, "fly": "jet", "model": "shikra", "bombs": 3,
		"pattern": "To-201 Shikra (Sukhoi Su-57 / Su-35), three KAB-250 bombs", "desc": "A CSAT stealth fighter drops three bombs across the spot. Drag to set the run-in direction."},
	"xian": {"name": "Y-32 Xi'an Gunship", "team": 1, "cost": 360, "cooldown": 220.0, "shape": "orbit", "r": 32.0, "fly": "orbit", "model": "xian", "guns": "xian",
		"pattern": "Y-32 Xi'an VTOL gunship, 30 mm cannon and Skyfire rockets", "desc": "A CSAT VTOL gunship circles the spot for 25 seconds raking it with 30 mm and rockets."},
	"artillery": {"name": "155 mm Artillery", "team": 0, "cost": 300, "cooldown": 180.0, "shape": "circle", "r": 22.0,
		"desc": "Eight heavy howitzer shells. Brings down buildings and digs out trenches."},
	"barrage": {"name": "Rocket Barrage", "team": 1, "cost": 180, "cooldown": 90.0, "shape": "circle", "r": 20.0,
		"desc": "Off-map launchers saturate the area with sixteen rockets. Inaccurate, but nobody likes being under it."},
	"mortars": {"name": "Mortar Barrage", "team": 1, "cost": 110, "cooldown": 60.0, "shape": "circle", "r": 15.0,
		"desc": "Off-map mortars drop twelve rounds on the spot."},
	"smoke": {"name": "Smoke Screen", "team": -1, "cost": 0, "cooldown": 0.0, "shape": "circle", "r": 14.0,
		"desc": "Mortar smoke rounds screen the area (observer demo)."},
}
const DEMO_SUPPORT := ["a10", "wipeout", "ac130", "blackfish", "airstrike", "buzzard", "gryphon", "greyhawk", "sentinel", "neophron", "shikra", "xian", "artillery", "barrage", "mortars", "smoke"]


## The Arma 3 roster joins the original vehicles; the Factory and the Helipad
## build them (air at the Helipad, everything else at the Factory).
func _init() -> void:
	var roster := VehicleRoster.table()
	VEHICLES.merge(roster)
	for k in roster:
		var d: Dictionary = roster[k]
		var team := int(d.team)
		if team < 0 or team > 1:
			continue
		var b := "helipad" if d.get("air", false) else "factory"
		(BUILDINGS[b].produces[team] as Array).append(k)


func supports_for(team: int) -> Array:
	var out := []
	for k in SUPPORT:
		if int(SUPPORT[k].team) == team and team >= 0:
			out.append(k)
	return out


var BUILDINGS := {
	"fob": {"name": "FOB", "cost": 250, "time": 70.0, "hp": 2500.0, "size": Vector2(14, 14), "teams": [0, 1], "desc": "Forward base: +20 unit cap, ammo, lays a supply road."},
	"barracks": {"name": "Barracks", "cost": 150, "time": 35.0, "hp": 1500.0, "size": Vector2(9, 6), "teams": [0, 1], "desc": "Trains infantry squads.", "produces": [["rifle_squad", "engineer_team", "mg_team", "at_team", "mortar_team"], ["fighter_cell", "digger_team", "pkm_team", "rpg_team", "fpv_team", "r_mortar_team"]]},
	"factory": {"name": "Factory", "cost": 250, "time": 45.0, "hp": 2200.0, "size": Vector2(11, 10), "teams": [0, 1], "desc": "Builds vehicles.", "produces": [["tank", "ifv", "humvee"], ["technical", "btr", "old_tank", "aa_tech"]]},
	"helipad": {"name": "Helipad", "cost": 180, "time": 30.0, "hp": 1000.0, "size": Vector2(10, 10), "teams": [0, 1], "desc": "Builds helicopters and drones. Supply helicopters fly over cut roads straight to your FOBs.", "produces": [["heli", "gunship"], []]},
	"medic_tent": {"name": "Medic Tent", "cost": 120, "time": 25.0, "hp": 900.0, "size": Vector2(7, 5), "teams": [0, 1], "desc": "Stretcher bearers bring back the wounded and the dead."},
	"research": {"name": "Research Post", "cost": 200, "time": 40.0, "hp": 1200.0, "size": Vector2(7, 7), "teams": [0, 1], "desc": "Unlocks upgrades."},
	"sandbags": {"name": "Sandbags", "cost": 15, "time": 5.0, "hp": 450.0, "size": Vector2(4, 0.9), "teams": [0, 1], "desc": "Low cover. Crouch and pop up to shoot."},
	"concrete_wall": {"name": "Concrete Wall", "cost": 40, "time": 10.0, "hp": 1600.0, "size": Vector2(4, 0.6), "teams": [0], "desc": "Tall cover. Soldiers lean around the ends."},
	"trench": {"name": "Trench", "cost": 20, "time": 9.0, "hp": 3000.0, "size": Vector2(6, 3.2), "teams": [0, 1], "desc": "Soldiers stand half a metre below ground: only their heads show when they fire. Drag to dig a line."},
	"wire": {"name": "Barbed Wire", "cost": 10, "time": 4.0, "hp": 160.0, "size": Vector2(5, 1.2), "teams": [0, 1], "desc": "Slows infantry to a crawl."},
	"mines": {"name": "Minefield", "cost": 30, "time": 6.0, "hp": 60.0, "size": Vector2(3, 3), "teams": [0, 1], "desc": "Hidden. Blows up vehicles and infantry."},
	"tank_trap": {"name": "Tank Trap", "cost": 20, "time": 5.0, "hp": 900.0, "size": Vector2(2, 2), "teams": [0, 1], "desc": "Blocks vehicles (and supply trucks)."},
	"mg_nest": {"name": "MG Nest", "cost": 70, "time": 15.0, "hp": 900.0, "size": Vector2(4.2, 4.2), "teams": [0, 1], "desc": "Sandbagged GPMG. A nearby soldier crews it and pins down infantry."},
	"hmg_nest": {"name": ".50 Cal Nest", "cost": 110, "time": 18.0, "hp": 1100.0, "size": Vector2(4.6, 4.6), "teams": [0, 1], "desc": "Heavy machine gun: 100 m range, crushing suppression, shreds trucks, technicals, helicopters and drones."},
	"mortar_pit": {"name": "Mortar Pit", "cost": 130, "time": 22.0, "hp": 900.0, "size": Vector2(5, 5), "teams": [0, 1], "desc": "Crewed mortar. Shells enemies your side can see, even behind cover (30-160 m). Select it for fire missions."},
	"bunker": {"name": "Bunker", "cost": 160, "time": 30.0, "hp": 2600.0, "size": Vector2(5.6, 5.6), "teams": [0, 1], "desc": "Pillbox with firing slits and a roof that stops shrapnel. Right-click it with a squad to garrison."},
	"at_post": {"name": "AT Post", "cost": 150, "time": 24.0, "hp": 900.0, "size": Vector2(4, 4), "teams": [0, 1], "desc": "Crewed anti-tank launcher (guided missile / recoilless rifle). Kills vehicles out to 130 m."},
	"watchtower": {"name": "Watchtower", "cost": 50, "time": 14.0, "hp": 500.0, "size": Vector2(3, 3), "teams": [0, 1], "desc": "Long sight range, shoots over walls."},
	"tunnel": {"name": "Tunnel Entrance", "cost": 60, "time": 18.0, "hp": 700.0, "size": Vector2(3, 3), "teams": [1], "desc": "Move squads through the tunnel network. Prisoners are interrogated here."},
}

const BUILD_MENU := [
	["fob", "barracks", "factory", "medic_tent", "research", "helipad", "sandbags", "concrete_wall", "trench", "wire", "mines", "tank_trap", "mg_nest", "hmg_nest", "mortar_pit", "bunker", "at_post", "watchtower"],
	["fob", "barracks", "factory", "medic_tent", "research", "helipad", "tunnel", "sandbags", "trench", "wire", "mines", "tank_trap", "mg_nest", "hmg_nest", "mortar_pit", "bunker", "at_post", "watchtower"],
]

var UPGRADES := {
	"armor": {"name": "Body Armor", "cost": 150, "time": 40.0, "teams": [0, 1], "desc": "+20% soldier health."},
	"grenades": {"name": "Grenade Pouches", "cost": 100, "time": 30.0, "teams": [0, 1], "desc": "+1 frag grenade for every soldier."},
	"medicine": {"name": "Field Medicine", "cost": 120, "time": 30.0, "teams": [0, 1], "desc": "Patch up and bleed out 50% slower."},
	"optics": {"name": "Optics", "cost": 150, "time": 40.0, "teams": [0, 1], "desc": "+15% accuracy."},
	"warheads": {"name": "FPV Warheads", "cost": 150, "time": 35.0, "teams": [1], "desc": "+50% drone damage."},
	"deep_tunnels": {"name": "Deep Tunnels", "cost": 100, "time": 30.0, "teams": [1], "desc": "Tunnel travel twice as fast."},
	# vehicle tiers: what the Factory and the Helipad can build
	"armour_doctrine": {"name": "Armoured Warfare", "cost": 220, "time": 50.0, "teams": [0], "tier": 2,
		"desc": "Unlocks tier 2: main battle tanks, infantry fighting vehicles, anti-aircraft vehicles and attack helicopters."},
	"combined_arms": {"name": "Combined Arms", "cost": 320, "time": 70.0, "teams": [0], "tier": 3, "requires": "armour_doctrine",
		"desc": "Unlocks tier 3: self-propelled artillery, the heaviest tanks, drones and the UGV."},
	"csat_advisers": {"name": "Foreign Advisers", "cost": 200, "time": 50.0, "teams": [1], "tier": 2,
		"desc": "CSAT advisers bring tier 2: tanks, IFVs, anti-aircraft vehicles and attack helicopters."},
	"csat_corps": {"name": "Expeditionary Corps", "cost": 300, "time": 70.0, "teams": [1], "tier": 3, "requires": "csat_advisers",
		"desc": "A CSAT expeditionary corps brings tier 3: artillery, the T-140 and the Futura, drones."},
}


func yaw_of(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func dir_of(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func grid_ref(p: Vector3) -> String:
	var col := clampi(int((p.x + MAP_HALF) / MapDims.CELL), 0, MapDims.GRID - 1)
	var row := clampi(int((p.z + MAP_HALF) / MapDims.CELL), 0, MapDims.GRID - 1)
	return "%s%d" % ["ABCDEFGHIJKLMNOP"[col], row + 1]


func compass(from: Vector3, to: Vector3) -> String:
	var d := to - from
	var a := rad_to_deg(atan2(d.x, -d.z))
	var dirs := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return dirs[posmod(int(round(a / 45.0)), 8)]


func _axes(r: float) -> Array:
	return [Vector2(cos(r), -sin(r)), Vector2(sin(r), cos(r))]


## Separating-axis test for two oriented rectangles on the ground plane (x,z).
func obb_overlap(c1: Vector2, h1: Vector2, r1: float, c2: Vector2, h2: Vector2, r2: float) -> bool:
	var a1 := _axes(r1)
	var a2 := _axes(r2)
	var d := c2 - c1
	for ax in [a1[0], a1[1], a2[0], a2[1]]:
		var p1: float = h1.x * absf(a1[0].dot(ax)) + h1.y * absf(a1[1].dot(ax))
		var p2: float = h2.x * absf(a2[0].dot(ax)) + h2.y * absf(a2[1].dot(ax))
		if absf(d.dot(ax)) > p1 + p2:
			return false
	return true


func point_in_obb(p: Vector2, c: Vector2, h: Vector2, r: float) -> bool:
	var a := _axes(r)
	var d := p - c
	return absf(d.dot(a[0])) <= h.x and absf(d.dot(a[1])) <= h.y


func in_map(p: Vector3, margin := 4.0) -> bool:
	return absf(p.x) < MAP_HALF - margin and absf(p.z) < MAP_HALF - margin


func dist_point_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func seg_sphere(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	return dist_point_segment(c, a, b) < r


func item_name(key: String) -> String:
	if SQUADS.has(key):
		return SQUADS[key].name
	if VEHICLES.has(key):
		return VEHICLES[key].name
	if BUILDINGS.has(key):
		return BUILDINGS[key].name
	if UPGRADES.has(key):
		return UPGRADES[key].name
	return key
