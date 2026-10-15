class_name VehicleRoster
extends RefCounted
## The Arma 3 vehicle roster, merged into Defs.VEHICLES at start-up.
##
## The Coalition fields NATO's vehicles and those of its allied army (the AAF,
## and the LDF's hand-me-downs); the Rebels field what FIA and Syndikat
## irregulars can buy, steal or bolt a gun onto, and - as their foreign
## backers commit - CSAT's. Each entry says what it's modelled on, how it
## behaves (base), what it fights with, and what research it needs (tier).
##
## Fields beyond the basics (see Defs.VEHICLES): tier 1-3; cat (production
## page); faction; role; pattern (the real vehicle); gun {dmg, at, radius, cd,
## size} for a main gun; atgm / sam [missiles, reload s]; art {shell, min, max,
## salvo, gap, cd, lay, scatter, muzzle}; service "repair" / "ammo" /
## "medical"; carry (squad that rides inside); sight (m); alt / orbit for
## drones; model (shares another's model).

static func table() -> Dictionary:
	var t := {}
	# ---------------------------------------------------------------- NATO: wheeled
	t["hunter"] = _v("Hunter", 0, 1, "light", "NATO", "MRAP", "Oshkosh M-ATV", 165, 15.0, 520.0, 1, 11.0, 1.9, "car",
		Vector3(2.5, 2.7, 6.3), 0, {"mg": "", "carry": "mech_team", "cap": 2,
		"desc": "Mine-resistant, ambush-protected. Carries a fire team through small-arms fire and roadside bombs."})
	t["hunter_hmg"] = _v("Hunter HMG", 0, 1, "light", "NATO", "MRAP", "Oshkosh M-ATV, RCWS .50", 140, 16.0, 520.0, 1, 11.0, 1.9, "car",
		Vector3(2.5, 2.7, 6.3), 0, {"mg": "m2", "gun_h": 2.9, "desc": "M-ATV with a remote .50 cal: scouts, escorts convoys, shreds technicals."})
	t["hunter_gmg"] = _v("Hunter GMG", 0, 1, "light", "NATO", "MRAP", "Oshkosh M-ATV, RCWS 40 mm GMG", 150, 16.0, 520.0, 1, 11.0, 1.9, "car",
		Vector3(2.5, 2.7, 6.3), 0, {"mg": "gmg", "gun_h": 2.9, "desc": "M-ATV with a 40 mm grenade machine gun: lobs high explosive into trenches and behind walls."})
	t["prowler"] = _v("Prowler", 0, 1, "light", "NATO", "Light strike vehicle", "Polaris DAGOR", 140, 11.0, 300.0, 0, 13.5, 2.3, "car",
		Vector3(1.9, 1.85, 4.5), 0, {"mg": "", "carry": "mech_team", "cap": 2, "sight": 60.0,
		"desc": "Open-topped and very fast: gets a fire team somewhere in a hurry. Nothing stops a bullet."})
	t["prowler_hmg"] = _v("Prowler HMG", 0, 1, "light", "NATO", "Light strike vehicle", "Polaris DAGOR with Mk30 .50", 110, 12.0, 300.0, 0, 13.5, 2.3, "car",
		Vector3(1.9, 1.85, 4.5), 0, {"mg": "m2", "gun_h": 2.4, "sight": 60.0, "desc": "Fast raider with a .50 cal on the roll cage."})
	t["prowler_at"] = _v("Prowler AT", 0, 2, "light", "NATO", "Light strike vehicle", "Polaris DAGOR with Titan launcher", 160, 15.0, 300.0, 0, 13.5, 2.3, "car",
		Vector3(1.9, 1.85, 4.5), 0, {"mg": "mmg", "gun_h": 2.4, "atgm": [6, 9.0], "desc": "Tank hunter: a Titan launcher on the roll cage, six missiles."})
	t["marshall"] = _v("AMV-7 Marshall", 0, 2, "armour", "NATO", "8x8 infantry fighting vehicle", "Patria AMV with a 40 mm turret (Denel Badger)", 270, 28.0, 900.0, 1, 10.5, 1.5, "afv",
		Vector3(2.8, 3.0, 7.7), 1, {"mg": "ac40", "carry": "mech_team", "cap": 3, "desc": "Fast eight-wheeled IFV with a 40 mm cannon. Carries a fire team."})
	t["rhino"] = _v("Rhino MGS", 0, 2, "armour", "NATO", "Wheeled tank destroyer", "Rooikat 8x8 with the 120 mm MTTD turret", 290, 28.0, 950.0, 1, 11.0, 1.4, "tank",
		Vector3(2.9, 2.8, 7.4), 1, {"cannon": true, "mg": "coax", "cap": 3, "gun": {"dmg": 150.0, "at": 300.0, "radius": 5.0, "cd": 6.0},
		"desc": "A tank's gun on eight wheels: hits like an MBT, moves like an APC, armoured like one too."})
	t["rhino_up"] = _v("Rhino MGS UP", 0, 3, "armour", "NATO", "Wheeled tank destroyer, urban", "Rooikat MTTD with ERA, slat cages and an RCWS", 330, 32.0, 1100.0, 1, 10.0, 1.3, "tank",
		Vector3(3.1, 2.9, 7.5), 1, {"cannon": true, "mg": "m2", "cap": 3, "gun": {"dmg": 150.0, "at": 300.0, "radius": 5.0, "cd": 6.0},
		"desc": "Urban package: reactive armour and slat cages against RPGs, a remote .50 cal against the men carrying them."})
	t["hemtt"] = _v("HEMTT Transport", 0, 1, "logistics", "NATO", "Heavy tactical truck", "Oshkosh M977 HEMTT", 200, 14.0, 420.0, 0, 9.0, 1.6, "util",
		Vector3(2.5, 3.0, 10.0), 1, {"mg": "", "carry": "rifle_squad", "cap": 3, "desc": "Eight-wheeled truck with benches for a full rifle squad."})
	t["hemtt_ammo"] = _v("HEMTT Ammo", 0, 1, "logistics", "NATO", "Ammunition truck", "Oshkosh M977 HEMTT with crane", 140, 15.0, 380.0, 0, 9.0, 1.6, "util",
		Vector3(2.5, 3.0, 10.0), 1, {"mg": "", "service": "ammo", "cap": 2, "desc": "Rearms troops and vehicles parked within 13 m: magazines, grenades, missiles."})
	t["hemtt_repair"] = _v("HEMTT Repair", 0, 1, "logistics", "NATO", "Repair truck", "Oshkosh M977 HEMTT, workshop body", 140, 15.0, 420.0, 0, 9.0, 1.6, "util",
		Vector3(2.5, 3.0, 10.0), 1, {"mg": "", "service": "repair", "cap": 2, "desc": "Mobile workshop: repairs vehicles within 13 m and fixes thrown tracks."})
	t["hemtt_medical"] = _v("HEMTT Medical", 0, 1, "logistics", "NATO", "Field ambulance", "Oshkosh M977 HEMTT, medical body", 140, 15.0, 400.0, 0, 9.0, 1.6, "util",
		Vector3(2.5, 3.0, 10.0), 1, {"mg": "", "service": "medical", "cap": 2, "desc": "Treats the wounded within 11 m: patches men up and gets the downed back on their feet."})
	t["stomper"] = _v("UGV Stomper RCWS", 0, 3, "logistics", "NATO", "Unmanned ground combat vehicle", "NREC Crusher UGCV", 170, 18.0, 420.0, 1, 4.5, 1.6, "car",
		Vector3(2.6, 1.6, 5.1), 0, {"hit": 1.4, "mg": "m2", "gun_h": 1.9, "cap": 1, "symbol": ["motor", "UGV"],
		"desc": "Six-wheeled robot with a .50 cal and a grenade launcher. Slow, tough, nobody inside to lose."})
	# ---------------------------------------------------------------- NATO: tracked
	t["slammer"] = _v("M2A1 Slammer", 0, 2, "armour", "NATO", "Main battle tank", "Merkava Mk IV", 340, 32.0, 1550.0, 2, 6.5, 1.1, "tank",
		Vector3(3.7, 2.7, 7.6), 2, {"cannon": true, "mg": "coax", "cap": 4, "tracked": true, "carry": "mech_team",
		"gun": {"dmg": 165.0, "at": 330.0, "radius": 5.5, "cd": 5.5},
		"desc": "Front-engined MBT with a troop compartment: carries a fire team behind the engine and the 120 mm."})
	t["slammer_up"] = _v("M2A4 Slammer UP", 0, 3, "armour", "NATO", "Main battle tank, urban", "Merkava Mk IV with reactive armour and an RCWS", 400, 36.0, 1750.0, 2, 6.0, 1.0, "tank",
		Vector3(3.9, 2.8, 7.6), 2, {"cannon": true, "mg": "m2", "cap": 4, "tracked": true, "carry": "mech_team",
		"gun": {"dmg": 165.0, "at": 330.0, "radius": 5.5, "cd": 5.5}, "desc": "Urban package: reactive armour all round and a remote .50 cal."})
	t["panther"] = _v("IFV-6c Panther", 0, 2, "armour", "NATO", "Heavy APC", "IMI Namer", 260, 26.0, 1250.0, 2, 6.5, 1.2, "afv",
		Vector3(3.6, 2.7, 7.6), 2, {"mg": "gmg", "cap": 3, "tracked": true, "carry": "rifle_squad",
		"desc": "Tank-hull APC with tank armour: a whole rifle squad and a remote GMG/HMG. The safest ride on the field."})
	t["bobcat"] = _v("CRV-6e Bobcat", 0, 2, "logistics", "NATO", "Armoured recovery / engineering vehicle", "Namer recovery vehicle (Achzaka)", 230, 26.0, 1250.0, 2, 6.0, 1.1, "util",
		Vector3(3.7, 2.8, 7.8), 2, {"mg": "m2", "gun_h": 2.9, "cap": 3, "tracked": true, "service": "repair",
		"desc": "Dozer blade, crane and a remote .50: repairs and recovers vehicles under fire, pushes through wrecks."})
	t["cheetah"] = _v("IFV-6a Cheetah", 0, 2, "support", "NATO", "Self-propelled anti-aircraft gun", "Namer hull with a Marksman twin 35 mm turret", 280, 28.0, 1150.0, 2, 6.5, 1.2, "spaa",
		Vector3(3.6, 3.1, 7.6), 2, {"mg": "twin35", "cap": 3, "tracked": true, "aa": true, "sam": [8, 6.0], "sight": 80.0,
		"desc": "Twin 35 mm guns and eight missiles under a search radar: no helicopter or drone lives long near it."})
	t["scorcher"] = _v("M4 Scorcher", 0, 3, "support", "NATO", "Self-propelled howitzer", "Merkava IV hull with an M109A7-style 155 mm turret", 340, 34.0, 1200.0, 2, 6.0, 1.0, "arty",
		Vector3(3.7, 3.1, 7.6), 2, {"mg": "m2", "gun_h": 2.6, "cap": 4, "tracked": true, "elev": 0.75,
		"art": {"shell": "arty", "min": 45.0, "max": 240.0, "salvo": 3, "gap": 2.2, "cd": 22.0, "lay": 3.0, "scatter": 3.0, "muzzle": 6.5},
		"desc": "155 mm self-propelled gun: halts, lays its barrel and drops three heavy shells on anything spotted 45-240 m away. Select it for fire missions."})
	t["sandstorm"] = _v("M5 Sandstorm", 0, 3, "support", "NATO", "Multiple rocket launcher", "Merkava IV hull with an M270 launcher", 360, 34.0, 1100.0, 2, 6.0, 1.0, "arty",
		Vector3(3.7, 3.0, 7.6), 2, {"mg": "", "cap": 4, "tracked": true, "elev": 0.7,
		"art": {"shell": "grad", "min": 60.0, "max": 250.0, "salvo": 8, "gap": 0.45, "cd": 45.0, "lay": 3.5, "scatter": 9.0, "muzzle": 1.0},
		"desc": "Twelve-tube rocket launcher: saturates an area with a ripple of rockets, then a long reload. Select it for fire missions."})
	# ---------------------------------------------------------------- AAF / LDF (Coalition allies)
	t["strider"] = _v("Strider", 0, 1, "light", "AAF", "Scout car", "KMW Fennek", 110, 14.0, 460.0, 1, 11.5, 2.0, "car",
		Vector3(2.55, 2.0, 5.6), 0, {"mg": "", "cap": 2, "sight": 85.0, "desc": "Low, quiet reconnaissance car with a sensor mast: sees far, hard to see."})
	t["strider_hmg"] = _v("Strider HMG", 0, 1, "light", "AAF", "Scout car", "KMW Fennek, RCWS .50", 130, 15.0, 460.0, 1, 11.5, 2.0, "car",
		Vector3(2.55, 2.3, 5.6), 0, {"mg": "m2", "gun_h": 2.2, "sight": 75.0, "desc": "Fennek scout car with a remote .50 cal."})
	t["strider_gmg"] = _v("Strider GMG", 0, 1, "light", "AAF", "Scout car", "KMW Fennek, RCWS 40 mm GMG", 140, 15.0, 460.0, 1, 11.5, 2.0, "car",
		Vector3(2.55, 2.3, 5.6), 0, {"mg": "gmg", "gun_h": 2.2, "sight": 75.0, "desc": "Fennek scout car with a grenade machine gun."})
	t["gorgon"] = _v("AFV-4 Gorgon", 0, 2, "armour", "AAF", "8x8 infantry fighting vehicle", "Pandur II 8x8", 260, 26.0, 860.0, 1, 10.5, 1.5, "afv",
		Vector3(2.7, 2.9, 7.4), 1, {"mg": "ac30", "carry": "mech_team", "cap": 3, "atgm": [4, 12.0],
		"desc": "Eight-wheeled IFV: 30 mm cannon, four anti-tank missiles, a fire team in the back."})
	t["mora"] = _v("FV-720 Mora", 0, 2, "armour", "AAF", "Tracked infantry fighting vehicle", "BAE FV510 Warrior", 250, 26.0, 980.0, 1, 7.5, 1.3, "afv",
		Vector3(3.0, 2.8, 6.3), 1, {"mg": "ac30", "carry": "mech_team", "cap": 3, "tracked": true,
		"desc": "Warrior-pattern tracked IFV: 30 mm cannon and a fire team, tougher than the wheeled ones."})
	t["kuma"] = _v("MBT-52 Kuma", 0, 2, "armour", "AAF", "Main battle tank", "Leopard 2 (Revolution urban upgrade)", 330, 32.0, 1500.0, 2, 7.0, 1.1, "tank",
		Vector3(3.75, 2.6, 7.7), 2, {"cannon": true, "mg": "coax", "cap": 4, "tracked": true, "gun": {"dmg": 165.0, "at": 335.0, "radius": 5.5, "cd": 5.5},
		"desc": "Leopard 2 with slat and appliqué armour: the fastest tank on the field and a long 120 mm."})
	t["nyx_ac"] = _v("AWC 304 Nyx (Autocannon)", 0, 2, "armour", "AAF", "Light tank / tankette", "Rheinmetall Wiesel AWC, 20 mm", 170, 18.0, 520.0, 1, 9.5, 2.0, "afv",
		Vector3(1.85, 1.9, 3.6), 0, {"hit": 1.4, "mg": "ac20", "cap": 2, "tracked": true, "desc": "Tiny tracked carrier with a 20 mm cannon: quick, hard to spot, hits light vehicles hard."})
	t["nyx_at"] = _v("AWC 301 Nyx (AT)", 0, 2, "armour", "AAF", "Light tank / tankette", "Rheinmetall Wiesel AWC with missiles", 210, 20.0, 520.0, 1, 9.5, 2.0, "afv",
		Vector3(1.85, 1.9, 3.6), 0, {"hit": 1.4, "mg": "m2", "cap": 2, "tracked": true, "atgm": [6, 8.0], "desc": "Wiesel with six fire-and-forget anti-tank missiles and a .50 cal."})
	t["nyx_aa"] = _v("AWC 302 Nyx (AA)", 0, 2, "support", "AAF", "Light anti-aircraft vehicle", "Rheinmetall Wiesel AWC with Stinger-class missiles", 200, 20.0, 520.0, 1, 9.5, 2.0, "spaa",
		Vector3(1.85, 1.9, 3.6), 0, {"hit": 1.4, "mg": "m2", "cap": 2, "tracked": true, "aa": true, "sam": [8, 5.0], "sight": 70.0,
		"desc": "Two four-round missile pods: a cheap, quick answer to enemy helicopters."})
	t["nyx_recon"] = _v("AWC 303 Nyx (Recon)", 0, 2, "light", "AAF", "Reconnaissance vehicle", "Rheinmetall Wiesel AWC with radar and periscope", 150, 16.0, 500.0, 1, 9.5, 2.0, "car",
		Vector3(1.85, 2.4, 3.6), 0, {"hit": 1.4, "mg": "", "cap": 1, "tracked": true, "sight": 110.0, "symbol": ["armor", "RECCE"],
		"desc": "Unarmed: a compact radar and an extending periscope see 110 m, for your artillery and your tanks."})
	t["zamak_ammo"] = _v("Zamak Ammo", 0, 1, "logistics", "AAF", "Ammunition truck", "KamAZ-4310", 120, 14.0, 340.0, 0, 8.5, 1.6, "util",
		Vector3(2.5, 2.9, 7.7), 1, {"mg": "", "service": "ammo", "cap": 2, "desc": "Allied ammunition truck: rearms troops and vehicles within 13 m."})
	# ---------------------------------------------------------------- NATO / AAF air
	t["pawnee"] = _v("AH-9 Pawnee", 0, 2, "air", "NATO", "Light attack helicopter", "MD 500 / AH-6 Little Bird", 260, 26.0, 420.0, 0, 24.0, 2.8, "attack_heli",
		Vector3(1.9, 2.4, 7.0), 0, {"hit": 1.3, "mg": "minigun", "cap": 3, "air": true, "rockets": 2, "gun_h": 0.9,
		"desc": "Little Bird with two miniguns and rocket pods: fast, nimble and fragile."})
	t["hummingbird"] = _v("MH-9 Hummingbird", 0, 1, "air", "NATO", "Light transport helicopter", "MD 500 / MH-6 Little Bird", 200, 22.0, 380.0, 0, 24.0, 2.8, "lift_heli",
		Vector3(1.9, 2.4, 7.0), 0, {"hit": 1.3, "mg": "", "cap": 2, "air": true, "carry": "mech_team",
		"desc": "Little Bird with outboard benches: drops a fire team anywhere on the map in seconds, then flies home."})
	t["ghosthawk"] = _v("UH-80 Ghost Hawk", 0, 2, "air", "NATO", "Utility helicopter", "Stealth UH-60 Black Hawk", 300, 30.0, 620.0, 1, 21.0, 2.3, "lift_heli",
		Vector3(2.4, 3.2, 15.3), 0, {"sling": 0, "mg": "minigun", "cap": 3, "air": true, "carry": "rifle_squad",
		"desc": "Air assault: flies a rifle squad in, door gunners firing, lands, they pile out, it flies home."})
	t["huron"] = _v("CH-67 Huron", 0, 1, "air", "NATO", "Heavy transport helicopter", "Stealth CH-47 Chinook", 220, 26.0, 700.0, 1, 18.0, 1.8, "lift_heli",
		Vector3(3.8, 3.6, 15.9), 0, {"sling": 1, "mg": "", "cap": 0, "air": true, "auto": true, "supply": true, "load": 160,
		"desc": "Twin-rotor heavy lifter: flies twice the supply of the light helicopter to your neediest FOB, ignoring roads."})
	t["blackfoot"] = _v("AH-99 Blackfoot", 0, 2, "air", "NATO", "Attack helicopter", "RAH-66 Comanche", 400, 36.0, 1000.0, 1, 23.0, 2.3, "attack_heli",
		Vector3(2.0, 3.4, 14.3), 0, {"mg": "m197", "cap": 4, "air": true, "rockets": 4, "atgm": [4, 10.0], "gun_h": 0.7,
		"desc": "Stealthy attack helicopter: chin 20 mm, rockets and anti-tank missiles."})
	t["falcon"] = _v("MQ-12 Falcon", 0, 3, "air", "NATO", "Armed rotary drone", "MQ-8 Fire Scout", 230, 22.0, 300.0, 0, 16.0, 2.0, "uav",
		Vector3(1.6, 1.8, 7.0), 0, {"hit": 0.7, "mg": "", "cap": 1, "air": true, "atgm": [6, 9.0], "sight": 75.0, "alt": 24.0, "orbit": 22.0, "symbol": ["air", "UAV"],
		"desc": "Unmanned helicopter: circles where you send it, spotting, and puts anti-tank missiles into armour."})
	t["darter"] = _v("AR-2 Darter", 0, 1, "air", "NATO", "Small reconnaissance drone", "Parrot-style quadcopter", 70, 10.0, 60.0, 0, 11.0, 3.0, "uav",
		Vector3(0.9, 0.4, 0.9), 0, {"hit": 0.15, "mg": "", "cap": 1, "air": true, "sight": 70.0, "alt": 18.0, "orbit": 12.0, "symbol": ["air", "UAV"],
		"desc": "Quadcopter: circles a spot and shows everything within 70 m to your side. Cheap, quiet, easy to shoot down."})
	t["mohawk"] = _v("CH-49 Mohawk", 0, 1, "air", "AAF", "Medium transport helicopter", "AgustaWestland AW101 Merlin", 280, 30.0, 680.0, 1, 19.0, 1.9, "lift_heli",
		Vector3(3.0, 3.6, 19.5), 0, {"sling": 1, "mg": "", "cap": 3, "air": true, "carry": "rifle_squad",
		"desc": "Three-engined transport: flies a rifle squad in, lands, drops them, flies home - or carries a Humvee, a technical or an APC on its sling."})
	t["hellcat"] = _v("WY-55 Hellcat", 0, 2, "air", "AAF", "Armed utility helicopter", "AgustaWestland AW159 Wildcat", 320, 30.0, 620.0, 1, 22.0, 2.3, "attack_heli",
		Vector3(2.0, 3.0, 13.0), 0, {"mg": "minigun", "cap": 3, "air": true, "rockets": 4, "gun_h": 0.9,
		"desc": "Wildcat with miniguns and rocket pods: a light gunship for the allied army."})
	# ---------------------------------------------------------------- Rebels: irregulars (FIA, Syndikat)
	t["offroad"] = _v("Offroad", 1, 1, "light", "FIA", "Pickup", "Mitsubishi L200-style pickup", 115, 9.0, 260.0, 0, 12.0, 2.0, "car",
		Vector3(1.9, 1.8, 5.1), 0, {"mg": "", "cap": 2, "carry": "mech_cell", "desc": "A pickup with four fighters in the bed. Fast, cheap, unprotected."})
	t["offroad_at"] = _v("Offroad AT", 1, 1, "light", "FIA", "Technical", "Pickup with an SPG-9 recoilless rifle", 140, 15.0, 300.0, 0, 11.0, 1.8, "car",
		Vector3(1.9, 1.9, 5.1), 0, {"cannon": true, "mg": "", "cap": 2, "gun_h": 2.1, "gun": {"dmg": 110.0, "at": 270.0, "radius": 4.0, "cd": 7.5, "size": 1.0},
		"desc": "SPG-9 recoilless rifle in the bed: a cheap tank killer that can't take a hit."})
	t["offroad_repair"] = _v("Offroad Repair", 1, 1, "logistics", "FIA", "Repair pickup", "Pickup with a workshop", 90, 12.0, 260.0, 0, 12.0, 2.0, "util",
		Vector3(1.9, 1.9, 5.1), 0, {"mg": "", "service": "repair", "cap": 1, "desc": "Tools and spares: repairs vehicles within 13 m."})
	t["mb4wd_lmg"] = _v("MB 4WD LMG", 1, 1, "light", "Syndikat", "Technical", "Jeep Wrangler with a light machine gun", 90, 11.0, 260.0, 0, 12.5, 2.2, "car",
		Vector3(1.9, 1.9, 4.2), 0, {"mg": "lmg", "gun_h": 2.2, "cap": 1, "desc": "Open jeep with an LMG on the roll bar: a fast raider."})
	t["mb4wd_at"] = _v("MB 4WD AT", 1, 1, "light", "Syndikat", "Technical", "Jeep Wrangler with an SPG-9", 130, 14.0, 260.0, 0, 12.5, 2.2, "car",
		Vector3(1.9, 1.9, 4.2), 0, {"cannon": true, "mg": "", "cap": 1, "gun_h": 2.2, "gun": {"dmg": 110.0, "at": 270.0, "radius": 4.0, "cd": 7.5, "size": 1.0},
		"desc": "Open jeep with a recoilless rifle: shoot and scoot."})
	t["quadbike"] = _v("Quadbike", 1, 1, "light", "FIA", "All-terrain vehicle", "Yamaha Grizzly ATV", 35, 6.0, 140.0, 0, 10.0, 2.6, "car",
		Vector3(1.2, 1.2, 2.0), 0, {"hit": 1.0, "mg": "", "cap": 1, "sight": 65.0, "desc": "A scout on a quad: quick and quiet, gone at the first burst."})
	t["fia_truck"] = _v("Truck", 1, 1, "logistics", "FIA", "Light truck", "Iveco Daily 4x4", 160, 12.0, 300.0, 0, 9.5, 1.8, "util",
		Vector3(2.1, 2.7, 5.6), 1, {"mg": "", "carry": "fighter_cell", "cap": 2, "desc": "Dropside truck: brings a whole fighter cell up the road."})
	t["van_ambulance"] = _v("Van Ambulance", 1, 1, "logistics", "FIA", "Ambulance", "Mercedes-Benz Sprinter", 100, 13.0, 260.0, 0, 10.5, 1.9, "util",
		Vector3(2.0, 2.6, 5.9), 1, {"mg": "", "service": "medical", "cap": 1, "desc": "A van turned ambulance: treats the wounded within 11 m."})
	t["van_transport"] = _v("Van Transport", 1, 1, "logistics", "FIA", "Minibus", "Mercedes-Benz Sprinter", 145, 11.0, 260.0, 0, 10.5, 1.9, "util",
		Vector3(2.0, 2.6, 5.9), 1, {"mg": "", "carry": "fighter_cell", "cap": 2, "desc": "Minibus: a fighter cell arrives looking like anybody else's traffic."})
	t["zamak_mrl"] = _v("Zamak MRL", 1, 3, "support", "FIA", "Truck-mounted rocket launcher", "KamAZ-4310 with a Thunderbolt-2000 launcher", 300, 30.0, 420.0, 0, 8.0, 1.5, "arty",
		Vector3(2.5, 3.0, 7.7), 1, {"mg": "", "cap": 3, "elev": 0.75,
		"art": {"shell": "grad", "min": 60.0, "max": 250.0, "salvo": 8, "gap": 0.4, "cd": 42.0, "lay": 3.0, "scatter": 10.0, "muzzle": 1.0},
		"desc": "Captured rocket truck: a ripple of rockets on anything spotted 60-250 m away, then a long reload. Select it for fire missions."})
	t["zamak_repair"] = _v("Zamak Repair", 1, 1, "logistics", "FIA", "Repair truck", "KamAZ-4310", 110, 13.0, 340.0, 0, 8.5, 1.6, "util",
		Vector3(2.5, 2.9, 7.7), 1, {"mg": "", "service": "repair", "cap": 2, "desc": "Workshop truck: repairs vehicles within 13 m."})
	# ---------------------------------------------------------------- Rebels: CSAT-supplied
	t["ifrit"] = _v("Ifrit", 1, 1, "light", "CSAT", "MRAP", "ZiL Karatel", 155, 14.0, 500.0, 1, 12.0, 1.9, "car",
		Vector3(2.4, 2.6, 6.3), 0, {"mg": "", "carry": "mech_cell", "cap": 2, "desc": "Angular armoured car: carries a fighter team through rifle fire."})
	t["ifrit_hmg"] = _v("Ifrit HMG", 1, 1, "light", "CSAT", "MRAP", "ZiL Karatel, RCWS 12.7 mm", 135, 16.0, 500.0, 1, 12.0, 1.9, "car",
		Vector3(2.4, 2.8, 6.3), 0, {"mg": "m2", "gun_h": 2.8, "desc": "Karatel with a remote 12.7 mm."})
	t["ifrit_gmg"] = _v("Ifrit GMG", 1, 1, "light", "CSAT", "MRAP", "ZiL Karatel, RCWS 40 mm GMG", 145, 16.0, 500.0, 1, 12.0, 1.9, "car",
		Vector3(2.4, 2.8, 6.3), 0, {"mg": "gmg", "gun_h": 2.8, "desc": "Karatel with a remote grenade machine gun."})
	t["qilin"] = _v("Qilin", 1, 1, "light", "CSAT", "Light strike vehicle", "ST Kinetics LSV Mk II", 130, 11.0, 290.0, 0, 13.0, 2.3, "car",
		Vector3(2.1, 1.8, 4.9), 0, {"mg": "", "carry": "mech_cell", "cap": 2, "desc": "Open light strike vehicle: a fighter team, fast."})
	t["qilin_mg"] = _v("Qilin Minigun", 1, 1, "light", "CSAT", "Light strike vehicle", "ST Kinetics LSV Mk II with a minigun", 115, 12.0, 290.0, 0, 13.0, 2.3, "car",
		Vector3(2.1, 1.9, 4.9), 0, {"mg": "minigun", "gun_h": 2.3, "desc": "LSV with a 6.5 mm minigun on the cage: a wall of bullets."})
	t["qilin_at"] = _v("Qilin AT", 1, 2, "light", "CSAT", "Light strike vehicle", "ST Kinetics LSV Mk II with Vorona missiles", 160, 15.0, 290.0, 0, 13.0, 2.3, "car",
		Vector3(2.1, 1.9, 4.9), 0, {"mg": "", "gun_h": 2.3, "atgm": [6, 9.0], "desc": "LSV with a Vorona missile launcher: hit-and-run against armour."})
	t["marid"] = _v("MSE-3 Marid", 1, 2, "armour", "CSAT", "6x6 APC", "Otokar Arma 6x6", 220, 22.0, 760.0, 1, 10.5, 1.6, "afv",
		Vector3(2.7, 2.6, 6.8), 1, {"mg": "gmg", "carry": "mech_cell", "cap": 3, "desc": "Six-wheeled APC with twin remote guns (HMG and GMG): carries a fighter team."})
	t["kamysh"] = _v("BTR-K Kamysh", 1, 2, "armour", "CSAT", "Heavy infantry fighting vehicle", "BM-2T Stalker with a Samson 30 mm turret", 290, 30.0, 1050.0, 1, 8.5, 1.3, "afv",
		Vector3(3.4, 2.5, 7.8), 1, {"mg": "ac30", "carry": "mech_cell", "cap": 3, "tracked": true, "atgm": [4, 11.0],
		"desc": "Tracked heavy IFV: 30 mm cannon, four anti-tank missiles and a fighter team. Fast for its weight."})
	t["varsuk"] = _v("T-100 Varsuk", 1, 2, "armour", "CSAT", "Main battle tank", "Object 640 'Black Eagle' / T-95 concept", 330, 32.0, 1450.0, 2, 7.0, 1.1, "tank",
		Vector3(3.6, 2.5, 7.5), 2, {"cannon": true, "mg": "coax", "cap": 4, "tracked": true, "gun": {"dmg": 170.0, "at": 340.0, "radius": 5.5, "cd": 6.0},
		"desc": "125 mm, reactive armour, a big bustle: CSAT's workhorse tank."})
	t["futura"] = _v("T-100X Futura", 1, 3, "armour", "CSAT", "Railgun tank", "T-100 hull with an experimental railgun turret", 460, 40.0, 1450.0, 2, 7.0, 1.1, "tank",
		Vector3(3.6, 2.6, 7.5), 2, {"cannon": true, "mg": "m2", "cap": 4, "tracked": true, "gun": {"dmg": 120.0, "at": 520.0, "radius": 3.0, "cd": 6.0, "size": 1.0},
		"desc": "A 75 mm railgun: a round that goes through anything, every six seconds."})
	t["angara"] = _v("T-140 Angara", 1, 3, "armour", "CSAT", "Main battle tank", "T-14 Armata", 400, 36.0, 1750.0, 2, 7.0, 1.1, "tank",
		Vector3(3.5, 3.3, 8.7), 2, {"cannon": true, "mg": "m2", "cap": 4, "tracked": true, "gun": {"dmg": 175.0, "at": 350.0, "radius": 5.5, "cd": 5.5},
		"desc": "Unmanned turret, crew capsule in the hull, reactive armour everywhere: the heaviest thing CSAT sends."})
	t["angara_k"] = _v("T-140K Angara", 1, 3, "armour", "CSAT", "Command tank", "T-14 Armata with a remote 30 mm turret", 430, 38.0, 1750.0, 2, 7.0, 1.1, "tank",
		Vector3(3.5, 3.4, 8.7), 2, {"cannon": true, "mg": "ac30", "cap": 4, "tracked": true, "sight": 85.0, "gun": {"dmg": 175.0, "at": 350.0, "radius": 5.5, "cd": 5.5},
		"desc": "Command variant: a remote 30 mm on the roof and a passive radar that spots for the whole force."})
	t["tigris"] = _v("ZSU-39 Tigris", 1, 2, "support", "CSAT", "Self-propelled anti-aircraft gun", "BM-2T Stalker hull with a Marksman twin 35 mm turret", 270, 28.0, 900.0, 1, 8.5, 1.3, "spaa",
		Vector3(3.4, 3.1, 7.8), 1, {"mg": "twin35", "cap": 3, "tracked": true, "aa": true, "sam": [8, 6.0], "sight": 80.0,
		"desc": "Twin 35 mm and eight missiles under a radar: the end of any helicopter that comes near."})
	t["sochor"] = _v("2S9 Sochor", 1, 3, "support", "CSAT", "Self-propelled howitzer", "T-100 hull with a 152 mm turret (2S35-like)", 330, 34.0, 1150.0, 2, 7.0, 1.0, "arty",
		Vector3(3.6, 3.1, 7.5), 2, {"mg": "m2", "gun_h": 2.6, "cap": 4, "tracked": true, "elev": 0.75,
		"art": {"shell": "arty", "min": 45.0, "max": 240.0, "salvo": 3, "gap": 2.2, "cd": 22.0, "lay": 3.0, "scatter": 3.5, "muzzle": 6.5},
		"desc": "Self-propelled howitzer: three heavy shells on anything spotted 45-240 m away. Select it for fire missions."})
	t["tempest"] = _v("Tempest Transport", 1, 1, "logistics", "CSAT", "Armoured truck", "KamAZ-63968 Typhoon-K", 195, 14.0, 520.0, 1, 9.0, 1.6, "util",
		Vector3(2.55, 3.3, 9.0), 1, {"mg": "", "carry": "fighter_cell", "cap": 3, "desc": "Armoured six-wheeler: a fighter cell safe from rifle fire on the way in."})
	t["tempest_ammo"] = _v("Tempest Ammo", 1, 1, "logistics", "CSAT", "Ammunition truck", "KamAZ-63968 Typhoon-K", 140, 15.0, 480.0, 1, 9.0, 1.6, "util",
		Vector3(2.55, 3.3, 9.0), 1, {"mg": "", "service": "ammo", "cap": 2, "desc": "Armoured ammunition truck: rearms troops and vehicles within 13 m."})
	t["tempest_medical"] = _v("Tempest Medical", 1, 1, "logistics", "CSAT", "Armoured ambulance", "KamAZ-63968 Typhoon-K", 140, 15.0, 480.0, 1, 9.0, 1.6, "util",
		Vector3(2.55, 3.3, 9.0), 1, {"mg": "", "service": "medical", "cap": 2, "desc": "Armoured ambulance: treats the wounded within 11 m."})
	# ---------------------------------------------------------------- Rebels: air
	t["kajman"] = _v("Mi-48 Kajman", 1, 2, "air", "CSAT", "Heavy attack helicopter", "Mi-28 cockpit, Ka-52 rotors, Mi-24 cabin", 420, 38.0, 1250.0, 1, 21.0, 2.0, "attack_heli",
		Vector3(2.4, 4.0, 16.0), 0, {"mg": "chaingun", "cap": 4, "air": true, "rockets": 6, "atgm": [8, 9.0], "gun_h": 0.8,
		"desc": "Flying tank: coaxial rotors, a 30 mm chin gun, rocket pods and anti-tank missiles."})
	t["orca"] = _v("PO-30 Orca", 1, 1, "air", "CSAT", "Light utility helicopter", "Kamov Ka-60 Kasatka", 260, 26.0, 520.0, 0, 22.0, 2.4, "lift_heli",
		Vector3(2.2, 3.4, 13.5), 0, {"sling": 0, "mg": "", "cap": 2, "air": true, "carry": "fighter_cell",
		"desc": "Fast utility helicopter: flies a fighter cell anywhere on the map and drops them."})
	t["orca_armed"] = _v("PO-30 Orca (Armed)", 1, 2, "air", "CSAT", "Armed utility helicopter", "Kamov Ka-60 with a minigun and rockets", 320, 30.0, 560.0, 0, 22.0, 2.4, "attack_heli",
		Vector3(2.2, 3.4, 13.5), 0, {"mg": "minigun", "cap": 3, "air": true, "rockets": 4, "gun_h": 0.9,
		"desc": "Ka-60 with a minigun and rocket pods: a light gunship."})
	t["taru"] = _v("Mi-290 Taru", 1, 1, "air", "CSAT", "Heavy-lift helicopter", "CH-54 Tarhe sky-crane with Ka-226 rotors", 200, 24.0, 620.0, 0, 18.0, 1.8, "lift_heli",
		Vector3(3.0, 4.2, 18.0), 0, {"sling": 1, "mg": "", "cap": 0, "air": true, "auto": true, "supply": true, "load": 140,
		"desc": "Sky-crane with a cargo pod: flies supply straight to your neediest FOB over cut roads."})
	t["taru_lift"] = _v("Mi-290 Taru (Lift)", 1, 1, "air", "CSAT", "Heavy-lift helicopter", "CH-54 Tarhe sky-crane with Ka-226 rotors", 230, 26.0, 620.0, 0, 18.0, 1.8, "lift_heli",
		Vector3(3.0, 4.2, 18.0), 0, {"sling": 1, "model": "taru", "mg": "", "cap": 1, "air": true,
		"desc": "The sky-crane without its pod: picks up a technical, a BTR or an AA truck on its sling and sets it down across the river or behind the enemy's line."})
	t["m900"] = _v("M900", 1, 1, "air", "Syndikat", "Light civilian helicopter", "MD 500D", 150, 18.0, 300.0, 0, 23.0, 2.8, "lift_heli",
		Vector3(1.9, 2.4, 7.0), 0, {"hit": 1.3, "mg": "", "cap": 1, "air": true, "carry": "mech_cell",
		"desc": "A stolen civilian helicopter: four fighters, anywhere, once."})
	t["fenghuang_uav"] = _v("KH-3A Fenghuang", 1, 3, "air", "CSAT", "Armed drone", "CASC CH-3A Rainbow", 220, 22.0, 260.0, 0, 18.0, 2.0, "uav",
		Vector3(5.5, 1.2, 8.0), 0, {"hit": 0.6, "mg": "", "cap": 1, "air": true, "atgm": [4, 10.0], "sight": 75.0, "alt": 26.0, "orbit": 26.0, "model": "fenghuang", "symbol": ["air", "UAV"],
		"desc": "Canard-winged drone: circles where it's sent, spotting, and fires small anti-tank missiles."})
	# ---------------------------------------------------------------- more variants
	t["offroad_hmg"] = _v("Offroad HMG", 1, 1, "light", "FIA", "Technical", "Pickup with an M2 .50 in the bed", 125, 15.0, 340.0, 0, 11.5, 1.8, "car",
		Vector3(1.9, 1.9, 5.1), 0, {"mg": "m2", "gun_h": 2.1, "cap": 2, "desc": "The guerrilla's workhorse: a .50 cal on a pedestal in a pickup bed."})
	t["zamak"] = _v("Zamak Transport", 1, 1, "logistics", "FIA", "Utility truck", "KamAZ-4310 6x6", 170, 14.0, 340.0, 0, 8.5, 1.6, "util",
		Vector3(2.5, 2.9, 7.7), 1, {"mg": "", "carry": "fighter_cell", "cap": 3, "desc": "Six-wheeled army truck under a canvas tilt: a whole fighter cell rides in the back."})
	t["zamak_medical"] = _v("Zamak Medical", 0, 1, "logistics", "AAF", "Field ambulance", "KamAZ-4310 6x6", 130, 14.0, 340.0, 0, 8.5, 1.6, "util",
		Vector3(2.5, 2.9, 7.7), 1, {"mg": "", "service": "medical", "cap": 2, "desc": "Allied ambulance truck: treats the wounded within 11 m."})
	t["tempest_repair"] = _v("Tempest Repair", 1, 1, "logistics", "CSAT", "Armoured repair truck", "KamAZ-63968 Typhoon-K", 140, 15.0, 480.0, 1, 9.0, 1.6, "util",
		Vector3(2.55, 3.3, 9.0), 1, {"mg": "", "service": "repair", "cap": 2, "desc": "Armoured workshop: repairs vehicles within 13 m."})
	t["ghosthawk_stub"] = _v("UH-80 Ghost Hawk (Stub Wings)", 0, 2, "air", "NATO", "Armed utility helicopter", "Black Hawk with ESSS stub wings", 330, 32.0, 640.0, 1, 21.0, 2.3, "attack_heli",
		Vector3(2.4, 3.2, 15.3), 0, {"mg": "minigun", "cap": 3, "air": true, "rockets": 6, "gun_h": 0.9,
		"desc": "Ghost Hawk with stub wings and rocket pods: a gunship that can still take a door gunner's view."})
	# ---------------------------------------------------------------- naval (the Boat Dock)
	# draft: how deep the hull sits; seats: men it carries (they land on any shore)
	t["rhib"] = _v("RHIB", 0, 1, "naval", "NATO", "Rigid-hulled inflatable", "Centre-console RHIB", 90, 10.0, 260.0, 0, 15.5, 1.7, "boat",
		Vector3(2.6, 1.6, 7.8), 0, {"mg": "", "seats": 6, "cap": 1, "draft": 0.35,
		"desc": "Fast, open and unarmed: six men up the river or along the coast, landed on any beach or bank."})
	t["speedboat_minigun"] = _v("Speedboat Minigun", 0, 2, "naval", "NATO", "Armed patrol boat", "Small Unit Riverine Craft (SURC)", 210, 20.0, 560.0, 1, 13.0, 1.5, "boat",
		Vector3(3.0, 2.4, 11.8), 1, {"mg": "gmg", "seats": 6, "cap": 2, "draft": 0.5, "gun_h": 1.9,
		"desc": "Armoured riverine craft: a 40 mm grenade machine gun in the bow and room for a squad - puts men ashore under its own fire."})
	t["patrol_ship"] = _v("Patrol Ship", 0, 2, "naval", "US Navy", "Patrol boat", "Mk VI Patrol Boat", 340, 32.0, 1700.0, 1, 12.0, 0.9, "boat",
		Vector3(6.0, 6.5, 25.0), 2, {"mg": "bushmaster", "cap": 4, "draft": 1.1, "gun_h": 3.0, "sight": 95.0,
		"desc": "Twenty-five metres of aluminium hull and a stabilised 25 mm cannon: owns the coast, shoots up anything on the shore."})
	t["motorboat"] = _v("Armed Motorboat", 1, 1, "naval", "FIA", "Speedboat", "Open runabout with a PKM", 70, 9.0, 200.0, 0, 14.5, 1.8, "boat",
		Vector3(2.3, 1.5, 6.0), 0, {"mg": "lmg", "seats": 4, "cap": 1, "draft": 0.35, "gun_h": 1.3,
		"desc": "A stolen pleasure boat with a PKM on the bow rail: four fighters across the river or along the coast."})
	t["speedboat_hmg"] = _v("Speedboat HMG", 1, 2, "naval", "CSAT", "Armed patrol boat", "Small Unit Riverine Craft (SURC)", 200, 20.0, 560.0, 1, 13.0, 1.5, "boat",
		Vector3(3.0, 2.4, 11.8), 1, {"mg": "gmg", "seats": 6, "cap": 2, "draft": 0.5, "gun_h": 1.9,
		"desc": "CSAT's riverine craft: 40 mm grenade launcher and a heavy machine gun, room for a squad."})
	t["gun_trawler"] = _v("Gun Trawler", 1, 2, "naval", "FIA", "Armed trawler", "Converted fishing trawler, ZU-23-2", 260, 30.0, 1350.0, 0, 8.5, 0.75, "boat",
		Vector3(5.5, 6.5, 18.0), 2, {"mg": "zu23", "aa": true, "cap": 3, "draft": 1.85, "gun_h": 4.6, "sight": 85.0,
		"desc": "A steel fishing boat with a twin 23 mm cannon welded on the foredeck: shreds helicopters, light boats and anything on the beach."})
	return t


## Arma 3 vehicles that aren't units here: the fixed-wing aircraft (they fly
## the air-support missions), the boats (there's no water to put them on yet),
## and the civilians' cars and the like (they're the scenery). For the Field
## Manual: [key, name, page, faction, role, pattern, crew, km/h, armament, description].
static func garage() -> Array:
	return [
		["buzzard", "A-143 Buzzard", "aircraft", "AAF", "Light attack jet", "Aero L-159 ALCA", "1", 805, "Twin 20 mm gun pod, 7 pylons", "The allied air force's light attack jet: strafes with its gun pod (A-143 Buzzard Strafe)."],
		["gryphon", "A-149 Gryphon", "aircraft", "AAF", "Multirole fighter", "Saab JAS 39 Gripen", "1", 1015, "20 mm cannon, 6 pylons", "Delta-winged fighter with canards: drops guided bombs on call (A-149 Gryphon Precision Strike)."],
		["wipeout", "A-164 Wipeout", "aircraft", "NATO", "Close air support", "A-10 Thunderbolt II", "1", 730, "30 mm GAU-8, 12 pylons", "The flying gun: walks 30 mm along a line (A-164 Wipeout Gun Run)."],
		["blackwasp", "F/A-181 Black Wasp II", "aircraft", "NATO", "Stealth fighter", "Super Hornet / F-22 hybrid", "1", 1213, "20 mm cannon, internal and external pylons", "Stealth strike fighter: a stick of four bombs across a spot (Air Strike)."],
		["sentinel", "UCAV Sentinel", "aircraft", "NATO", "Stealth combat drone", "Northrop Grumman X-47B", "-", 890, "2 internal GBU-12", "Tailless flying wing: two bombs, no warning (UCAV Sentinel Strike)."],
		["greyhawk", "MQ-4A Greyhawk", "aircraft", "NATO", "Armed drone", "MQ-9 Reaper layout with canards", "-", 382, "6 Skalpel missiles", "Circles a spot firing guided missiles at whatever it finds (MQ-4A Greyhawk Drone)."],
		["blackfish", "V-44X Blackfish", "aircraft", "NATO", "Tiltrotor transport", "Enlarged V-22 Osprey / V-280", "4 + 32", 538, "None", "The tiltrotor that carries a platoon - or, armed, the gunship that orbits on call."],
		["blackfish_armed", "V-44X Blackfish (Armed)", "aircraft", "NATO", "Tiltrotor gunship", "V-22 / AC-130 concept", "4", 538, "105 mm, 40 mm and 20 mm, left side", "Thirty seconds of fire from overhead (V-44X Blackfish Gunship)."],
		["neophron", "To-199 Neophron", "aircraft", "CSAT", "Light attack jet", "Yakovlev Yak-130", "1", 835, "30 mm cannon, 8 hardpoints", "CSAT's light attack jet: strafes with its 30 mm (To-199 Neophron Strafe)."],
		["shikra", "To-201 Shikra", "aircraft", "CSAT", "Stealth fighter", "Sukhoi Su-57 / Su-35", "1", 1508, "30 mm cannon, KAB-250 bombs", "The fastest fighter in the sky: three bombs across a spot (To-201 Shikra Bomb Run)."],
		["xian", "Y-32 Xi'an", "aircraft", "CSAT", "VTOL gunship", "Fictional lift-fan VTOL", "2 + 16", 720, "30 mm cannon, rockets, missiles", "Lift fans in the wings, jets between twin tails: circles a spot raking it (Y-32 Xi'an Gunship)."],
		["fenghuang", "KH-3A Fenghuang", "aircraft", "CSAT", "Armed drone", "CASC CH-3A Rainbow", "-", 350, "4 Jian missiles", "Small canard-winged drone: the Rebels build it at the Helipad once CSAT's corps arrives."],
		["caesar", "Caesar BTT", "aircraft", "Civilian", "Light aircraft", "Cessna TTx", "1 + 3", 423, "None", "A civilian tourer: smugglers fly them in at night."],
		["assault_boat", "Assault Boat", "boats", "NATO / FIA / CSAT", "Inflatable raiding craft", "Zodiac F470 CRRC", "1 + 4", 28, "None", "Black inflatable with an outboard: how special forces and smugglers come ashore."],
		["sdv", "SDV", "boats", "NATO", "Swimmer delivery vehicle", "Mk 8 Mod 1 SEAL Delivery Vehicle", "2 + 2", 23, "Laser designator", "A free-flooding mini-submarine: divers ride it under the water."],
		["water_scooter", "Water Scooter", "boats", "Civilian", "Personal watercraft", "Jet ski", "1 + 2", 84, "None", "A jet ski from the beach resorts."],
		["hatchback", "Hatchback", "civilian", "Civilian", "Hatchback", "Hyundai i-Blue concept", "1 + 3", 191, "None", "The commonest car on the island's roads."],
		["hatchback_sport", "Hatchback (Sport)", "civilian", "Civilian", "Hot hatch", "Hyundai i-Blue concept, sport", "1 + 3", 298, "None", "Lowered, spoilered and loud."],
		["suv", "SUV", "civilian", "Civilian", "Luxury SUV", "BMW X6", "1 + 3", 250, "None", "The rich man's car."],
		["mb4wd", "MB 4WD", "civilian", "Civilian / Syndikat", "Compact 4x4", "Jeep Wrangler", "1 + 3", 196, "None", "A little go-anywhere 4x4; Syndikat bolt guns onto them."],
		["van_services", "Van Services", "civilian", "Civilian / FIA", "Utility van", "Mercedes-Benz Sprinter", "1 + 1", 158, "None", "A tradesman's van with a roof rack."],
		["fia_truck_box", "Truck Boxer", "civilian", "Civilian / FIA", "Box truck", "Iveco Daily 4x4", "1 + 2", 118, "None", "A light truck with a box body."],
		["kart", "Kart", "civilian", "Civilian", "Go-kart", "Racing kart", "1", 101, "None", "Somebody's weekend hobby."],
		["tractor", "Tractor", "civilian", "Civilian (LDF)", "Farm tractor", "Zetor 8811", "1", 36, "None", "Works the fields round the farms."],
		["hemtt_fuel", "HEMTT Fuel", "civilian", "NATO", "Tanker", "Oshkosh M978 HEMTT tanker", "2", 83, "None", "Refuels vehicles (there's no fuel to run out of here)."],
		["hemtt_cargo", "HEMTT Cargo", "civilian", "NATO", "Supply truck", "Oshkosh M977 HEMTT", "2", 83, "None", "The Coalition's supply convoy truck."],
		["zamak_cargo", "Zamak Cargo", "civilian", "FIA / AAF", "Supply truck", "KamAZ-4310", "3", 82, "None", "The Rebels' supply convoy truck."],
		["zamak_fuel", "Zamak Fuel", "civilian", "AAF", "Tanker", "KamAZ-4310 tanker", "3", 82, "None", "Refuels vehicles."],
		["tempest_fuel", "Tempest Fuel", "civilian", "CSAT", "Tanker", "KamAZ-63968 Typhoon-K", "2", 93, "None", "Armoured tanker."],
		["utility_drone", "Utility Drone", "civilian", "IDAP / all", "Hexacopter", "Six-rotor drone", "-", 100, "None", "Drops leaflets or medical supplies."],
		["demining_drone", "Demining Drone", "civilian", "IDAP", "Demining hexacopter", "TU Delft concept", "-", 100, "4 demining charges", "Finds and blows mines from the air."],
		["ed1", "ED-1 Mini UGV", "civilian", "NATO / CSAT / AAF", "Mini robot", "PackBot / Talon-class EOD robot", "-", 12, "Disruptor", "The bomb-disposal robot that rides in a backpack."],
	]


## One roster entry.
static func _v(nm: String, team: int, tier: int, cat: String, faction: String, role: String, pattern: String, cost: int, time: float,
		hp: float, armor: int, speed: float, turn: float, base: String, size: Vector3, weight: int, extra: Dictionary) -> Dictionary:
	var d := {"name": nm, "team": team, "tier": tier, "cat": cat, "faction": faction, "role": role, "pattern": pattern,
		"cost": cost, "time": time, "hp": hp, "armor": armor, "speed": speed, "turn": turn, "base": base, "size": size,
		"weight": weight, "cannon": false, "mg": "", "cap": 2, "gun_h": 2.2}
	d.merge(extra, true)
	return d
