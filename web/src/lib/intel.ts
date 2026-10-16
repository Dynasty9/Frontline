// What the front page says about the game. All of it comes from the game:
// the radio lines are what the missions really say over the net
// (scripts/game/missions.gd, rules.gd), the names are from the vehicle and
// fire-support tables (vehicle_roster.gd, defs.gd), and the numbers are
// counted from them. Keep them true when those change.

/** Radio traffic, word for word, from the missions. */
export const RADIO: [string, string][] = [
  ["Overlord", "Rebels hold the village at C6 and the bridge behind it. Clear the village, then take that bridge before they blow it."],
  ["Fire control", "Shot, over. 155 on C6, eight rounds."],
  ["Overlord", "Feet dry. The AA guns are just inland of the harbour, G4."],
  ["Neptune", "Two enemy boats coming out of the harbour. Engaging."],
  ["Overlord", "AA is down! Blackfoot and a Ghost Hawk with reinforcements inbound from the sea. A-10 on call."],
  ["Lookout", "They're moving! Four vehicles, a Hunter in front."],
  ["Cell leader", "In position. Wait for it... let the lead car into the bend."],
  ["Overlord", "BTR heading for the bridge. Get your AT up."],
  ["Wolf 2", "Outnumbered at C6, gone firm. Need fires or reinforcements!"],
  ["Kilo", "Two BTRs behind them! Where's that Nyx?"],
  ["Overlord", "Checkpoint down. The house is seventy metres up the street, doors barred. Breach it."],
  ["Fire control", "A-10C Thunderbolt inbound, gun run on G4. Danger close!"],
  ["Lancer 6", "Tanks on the bridge. Good work, we have it from here."],
]

/** The first ticker: what you'll do. */
export const TICKER = [
  "Squads that think for themselves",
  "97 vehicles",
  "16 kinds of fire support",
  "House-to-house fighting",
  "Fire that spreads with the wind",
  "Amphibious landings",
  "Armour on a helicopter's sling",
  "Co-op against the AI",
  "Head to head online",
  "Free and open source",
]

/** The second ticker: the hardware. */
export const HARDWARE = [
  "M2A1 Slammer",
  "T-140 Angara",
  "AH-99 Blackfoot",
  "Mi-48 Kajman",
  "A-10C Thunderbolt II",
  "AC-130U Spooky",
  "CH-49 Mohawk",
  "AMV-7 Marshall",
  "T-100X Futura railgun tank",
  "M5 Sandstorm MLRS",
  "UH-80 Ghost Hawk",
  "Mk VI patrol ship",
  "RHIB",
  "Gun Trawler",
  "MQ-4A Greyhawk",
  "155 mm artillery",
]

/** Counted from the game's tables. `from` is where the counter starts. */
export const STATS: { value: number; from: number; unit?: string; label: string; note: string }[] = [
  { value: 97, from: 0, label: "Vehicles", note: "Quad bikes to railgun tanks, gunships to gun trawlers" },
  { value: 16, from: 0, label: "Fire-support assets", note: "Mortars, 155s, rocket barrages, A-10s and the AC-130" },
  { value: 5, from: 0, label: "Missions", note: "Played alone or in co-op, dawn to dead of night" },
  { value: 1, from: 0, unit: "km²", label: "Battlefield", note: "Of countryside: a town, villages, a river and the sea" },
  { value: 0, from: 999, label: "Imported assets", note: "Every model, texture and sound is made in code" },
]

export type Mission = {
  key: string
  title: string
  op: string
  time: string
  blurb: string
  force: string
}

/** The missions, as the game's menu lists them (scripts/game/missions.gd). */
export const MISSIONS: Mission[] = [
  {
    key: "bridgehead",
    title: "Bridgehead",
    op: "Operation Broken Crossing",
    time: "Dawn",
    blurb: "Clear a riverside village, seize its bridge and hold it against the counterattack.",
    force: "Two rifle squads, an MG team, an AT team and an AMV-7 Marshall",
  },
  {
    key: "beachhead",
    title: "Beachhead",
    op: "Operation Iron Tide",
    time: "Golden hour",
    blurb: "Land from the sea, knock out the harbour's anti-aircraft guns and take the harbour.",
    force: "Three RHIBs and a Mk VI patrol ship",
  },
  {
    key: "skyhook",
    title: "Sky Hook",
    op: "Operation Long Lantern",
    time: "Overcast",
    blurb: "Fly a tank destroyer to a cut-off outpost on a helicopter's sling, then stop the armour coming for it.",
    force: "A CH-49 Mohawk, an AWC Nyx and the outpost's garrison",
  },
  {
    key: "ambush",
    title: "Ambush Alley",
    op: "Operation Black Harvest",
    time: "Dusk",
    blurb: "As the Rebels: ambush a Coalition convoy on a country lane, then vanish before their reaction force arrives.",
    force: "A fighter cell, two RPG teams, a PKM team and an IED",
  },
  {
    key: "kingpin",
    title: "Kingpin",
    op: "Operation Silent Gate",
    time: "Night",
    blurb: "A night raid into the town: break through a checkpoint, take down a Rebel commander and get out.",
    force: "Two rifle squads, an MG team and two Hunter HMGs",
  },
]
