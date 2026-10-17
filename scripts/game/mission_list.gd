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
		"brief": "Dawn. Rebel fighters hold the village on our bank of the river, and the bridge beyond it. Clear the village house by house and take the bridge before they can blow it. Then hold it: they will come back across hard, with armour, before our tanks can get up the lane. 155 mm artillery is on call."},
	{"key": "beachhead", "title": "Beachhead", "op": "Operation Iron Tide", "side": 0, "seed": 2, "mood": "golden", "mins": 5,
		"blurb": "Land from the sea, knock out the harbour's anti-aircraft guns and take the harbour.",
		"force": "Three RHIBs (two rifle squads, an MG team and an AT team) and a Mk VI patrol ship",
		"area": "The coast and the fishing harbour",
		"brief": "Two anti-aircraft trucks guard the harbour, and until they are gone no helicopter can get near the coast. Their twin 23 mm guns will cut infantry to pieces in the open. Run the RHIBs onto the beach south of the harbour, then destroy the guns: with the patrol ship's guns from the water, the AT team, or the one artillery fire mission you have. Then clear the harbour for the battalion landing behind you. Expect boats."},
	{"key": "skyhook", "title": "Sky Hook", "op": "Operation Long Lantern", "side": 0, "seed": 4, "mood": "overcast", "mins": 5,
		"blurb": "Fly a tank destroyer to a cut-off outpost on a helicopter's sling, then stop the armour coming for it.",
		"force": "A CH-49 Mohawk, an AWC Nyx anti-tank vehicle and the outpost's garrison",
		"area": "The river, and Outpost Kilo on the far bank",
		"brief": "Outpost Kilo, across the river, reports an armoured column forming to the north, and it has nothing that can stop a BTR. The bridge is wired with charges. Hook the Nyx under the Mohawk (select the helicopter, right-click the Nyx), fly it over the river and set it down at Kilo (right-click the ground there), then hold the outpost until the column is broken."},
	{"key": "ambush", "title": "Ambush Alley", "op": "Operation Black Harvest", "side": 1, "seed": 3, "mood": "dusk", "mins": 5,
		"blurb": "As the Rebels: ambush a Coalition convoy on a country lane, then vanish before their reaction force arrives.",
		"force": "A fighter cell, two RPG teams, a PKM team, and an IED in the lane",
		"area": "A country lane between a village and the main road",
		"brief": "At dusk a Coalition convoy will leave the village and run down the lane to the main road. There is an IED dug into the lane. Get into the woods above it before the convoy moves, let the IED open the ambush, and destroy the convoy. Then break contact and get back to the rally point: their quick reaction force, helicopters and all, will be on the spot within minutes."},
	{"key": "kingpin", "title": "Kingpin", "op": "Operation Silent Gate", "side": 0, "seed": 5, "mood": "night", "mins": 5,
		"blurb": "A night raid into the town: break through a checkpoint, take down a Rebel commander and get out.",
		"force": "Two rifle squads, an MG team and two Hunter HMGs",
		"area": "The town, at night",
		"brief": "A Rebel commander is spending the night in a house in the town, behind a checkpoint on the main street. Go in on foot, clear the checkpoint (it has RPGs: keep the Hunters back until it's down), breach the house and kill or capture him. Once he is down every Rebel in town will come for you: get back to the Hunters before they cut the road. A Greyhawk drone comes on station two minutes in."},
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
