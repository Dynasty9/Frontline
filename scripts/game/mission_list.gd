class_name MissionList
extends RefCounted
## The missions on offer, and what the menu, the lobby and the loading screen
## say about each: its name, side, briefing and the seed of its map. What
## happens in them is Missions (missions.gd); this catalogue lives apart so the
## menu can list them without compiling the whole game they're played in.

const LIST := [
	{"key": "bridgehead", "title": "Bridgehead", "op": "Operation Broken Crossing", "side": 0, "seed": 1, "mood": "dawn", "mins": 5,
		"blurb": "Clear a riverside village, seize its bridge and hold it against the counterattack.",
		"force": "Two rifle squads, an MG team, an AT team and an AMV-7 Marshall",
		"area": "A farming village on the river, and its bridge",
		"brief": "Dawn. Clear the riverside village, then seize the bridge under the Marshall's covering fire. Scouts will mark mortar observers on your flank: clear that position before taking the bridge, or keep the platoon together and endure their fire. After capture, you have twenty seconds to reorganise. Cover the crossing with AT and watch the ford; infantry and a BTR are coming. Hold until Lancer's tanks reach the cleared bridgehead. Two 155 mm fire missions are available, three minutes apart."},
	{"key": "beachhead", "title": "Beachhead", "op": "Operation Iron Tide", "side": 0, "seed": 2, "mood": "golden", "mins": 5,
		"blurb": "Land from the sea, knock out the harbour's anti-aircraft guns and take the harbour.",
		"force": "Three RHIBs (two rifle squads, an MG team and an AT team) and a Mk VI patrol ship",
		"area": "The coast and the fishing harbour",
		"brief": "Two AA trucks keep our helicopters offshore. Land south of the harbour and knock them out with the patrol ship, your AT team or your one artillery mission. That opens the coast to helicopter reinforcements and an A-10 strike. Clear the harbour, then turn inland: enemy reserves will advance from the town road. Hold the quay for ninety seconds and clear the remaining attackers. Keep Neptune afloat; its guns cover both the landing and the defence."},
	{"key": "skyhook", "title": "Sky Hook", "op": "Operation Long Lantern", "side": 0, "seed": 4, "mood": "overcast", "mins": 5,
		"blurb": "Fly a tank destroyer to a cut-off outpost on a helicopter's sling, then stop the armour coming for it.",
		"force": "A CH-49 Mohawk, an AWC Nyx anti-tank vehicle and the outpost's garrison",
		"area": "The river, and Outpost Kilo on the far bank",
		"brief": "Kilo is cut off across the river. Its defenders can stop infantry, but not the two BTRs forming to the north. The vanguard moves in eighty seconds. Select the Mohawk and right-click the Nyx to hook it, then right-click the ground at Kilo to deliver it. Put the Nyx in cover facing north. Use infantry to spot the armour and protect the launcher; pull the helicopter clear. Deliver the Nyx and destroy the technical and both BTRs to win. One artillery mission is available."},
	{"key": "ambush", "title": "Ambush Alley", "op": "Operation Black Harvest", "side": 1, "seed": 3, "mood": "dusk", "mins": 5,
		"blurb": "As the Rebels: ambush a Coalition convoy on a country lane, then vanish before their reaction force arrives.",
		"force": "A fighter cell, two RPG teams, a PKM team, and an IED in the lane",
		"area": "A country lane between a village and the main road",
		"brief": "A four-vehicle convoy leaves the village in one hundred seconds. Get into the woods above the lane, RPGs covering the bend and an IED already in place. Destroy three vehicles; if two escape, the ambush fails. First damage starts a forty-five-second reaction-force countdown. The fourth vehicle is an optional target: weigh the extra kill against getting out. Bring sixty percent of surviving fighters to the rally point within two and a half minutes of breaking the convoy."},
	{"key": "kingpin", "title": "Kingpin", "op": "Operation Silent Gate", "side": 0, "seed": 5, "mood": "night", "mins": 5,
		"blurb": "A night raid into the town: break through a checkpoint, take down a Rebel commander and get out.",
		"force": "Two rifle squads, an MG team and two Hunter HMGs",
		"area": "The town, at night",
		"brief": "Kassem is in a house behind the main-street checkpoint. Clear the RPG team on foot before bringing the Hunters forward. Then breach the house and kill or capture him. He may flee: sightings update his last known position, so cover the side streets. Greyhawk comes on station two minutes in. Once Kassem is down, break contact and bring three quarters of your surviving force back to the insertion point within two and a half minutes. Keep a Hunter intact to cover the withdrawal."},
	{"key": "survey", "title": "Survey", "op": "Survey", "side": 0, "seed": 1, "mood": "day", "mins": 1, "hidden": true,
		"blurb": "", "force": "", "area": "", "brief": ""},
]


static func find(key: String) -> Dictionary:
	for m in LIST:
		if m.key == key:
			return m
	return LIST[LIST.size() - 1]


## The missions the menu offers.
static func playable() -> Array:
	return LIST.filter(func(m): return not m.get("hidden", false))
