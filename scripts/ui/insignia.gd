class_name Insignia
extends RefCounted
## Insignia: the patches, medals and badges a player wears as their icon, and
## the ranks that unlock them.
##
## A player with an account earns XP in battle (Online.battle_end; the
## matchmaker keeps the count, measured on its own clock) and climbs from
## Recruit to General of the Army over 50 ranks. Every account has the ten
## starter patches; each rank adds its own patch. The awards and unit patches
## are shown in the collection but locked for now.
##
## Ids: s01-s10 starters, r01-r50 rank patches (rNN at rank NN), m01-m50
## awards and decorations, u01-u50 unit patches. The matchmaker checks the
## same rules (matchmaker/src/ranks.js), and the website is given this
## catalog and the art by --insignia-dump=web.

const MAX_RANK := 50
const DEFAULT := "s01"
const GROUPS := [
	["starter", "Starter patches", "Every account has these ten from the start: the branches of the army."],
	["rank", "Rank patches", "One for every rank. Earn XP in battle, win for more, and climb from Recruit to General of the Army."],
	["award", "Awards and decorations", "Medals, badges and ribbons. Locked for now."],
	["unit", "Unit patches", "Company and squadron patches in the style of the Vietnam war, and the battlefield's own units. Locked for now."],
]
const TIERS := ["Private", "Corporal", "Sergeant", "Staff Sergeant", "Master Sergeant", "Lieutenant", "Captain", "Major", "Colonel"]
const GENERALS := ["Brigadier General", "Major General", "Lieutenant General", "General", "General of the Army"]

static var _by_id := {}
static var _tex := {}


## XP needed to reach rank `r`: 150 for the first, each one 20 more than the
## last, 32,000 for General of the Army.
static func rank_xp(r: int) -> int:
	return 150 * r + 10 * r * (r - 1)


static func rank_for(xp: int) -> int:
	var r := 0
	while r < MAX_RANK and rank_xp(r + 1) <= xp:
		r += 1
	return r


## "Recruit", "Private I" ... "Colonel V", then the generals by name.
static func rank_name(r: int) -> String:
	if r <= 0:
		return "Recruit"
	if r > 45:
		return GENERALS[mini(r, MAX_RANK) - 46]
	return "%s %s" % [TIERS[(r - 1) / 5], ["I", "II", "III", "IV", "V"][(r - 1) % 5]]


static func all() -> Array:
	return CATALOG


static func find(id: String) -> Dictionary:
	if _by_id.is_empty():
		for e: Dictionary in CATALOG:
			_by_id[String(e.id)] = e
	return _by_id.get(id, {})


static func group(id: String) -> String:
	return {"s": "starter", "r": "rank", "m": "award", "u": "unit"}.get(id.left(1), "")


## The rank that unlocks it: 0 for the starters, NN for rNN, -1 for the ones
## no one can wear yet.
static func unlock_rank(id: String) -> int:
	match group(id):
		"starter":
			return 0
		"rank":
			return int(id.substr(1))
	return -1


static func unlocked(id: String, rank: int) -> bool:
	var u := unlock_rank(id)
	return u >= 0 and u <= rank and not find(id).is_empty()


## How it's unlocked, for a tooltip.
static func unlock_text(id: String) -> String:
	var u := unlock_rank(id)
	if u == 0:
		return "Every account has it."
	if u > 0:
		return "Unlocked at rank %d, %s (%s XP)." % [u, rank_name(u), thousands(rank_xp(u))]
	return "Locked."


static func svg(id: String) -> String:
	var e := find(id)
	if e.is_empty():
		e = find(DEFAULT)
	return InsigniaArt.svg(e)


## The insignia as a texture `px` across (mipmapped, so it shrinks cleanly
## into a list). Rasterized once and kept.
static func texture(id: String, px := 128) -> ImageTexture:
	var key := "%s@%d" % [id, px]
	if _tex.has(key):
		return _tex[key]
	var img := Image.new()
	if img.load_svg_from_string(svg(id), px / 128.0) != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## --insignia-dump=DIR (the website: DIR is web/): every insignia as
## DIR/public/insignia/<id>.svg, and the catalog the site reads as
## DIR/src/lib/insignia.json.
static func dump(dir: String) -> int:
	var art := dir.path_join("public/insignia")
	DirAccess.make_dir_recursive_absolute(art)
	DirAccess.make_dir_recursive_absolute(dir.path_join("src/lib"))
	var ranks := []
	for r in MAX_RANK + 1:
		ranks.append({"rank": r, "name": rank_name(r), "xp": rank_xp(r)})
	var groups := []
	for g in GROUPS:
		groups.append({"key": g[0], "title": g[1], "blurb": g[2]})
	var items := []
	for e: Dictionary in CATALOG:
		var id := String(e.id)
		var f := FileAccess.open(art.path_join(id + ".svg"), FileAccess.WRITE)
		if f == null:
			push_error("Insignia: can't write %s" % art)
			return ERR_CANT_CREATE
		f.store_string(InsigniaArt.svg(e) + "\n")
		items.append({"id": id, "name": e.n, "group": group(id), "unlock": unlock_rank(id), "blurb": e.d})
	var data := {"ranks": ranks, "groups": groups, "insignia": items}
	var jf := FileAccess.open(dir.path_join("src/lib/insignia.json"), FileAccess.WRITE)
	if jf == null:
		return ERR_CANT_CREATE
	jf.store_string(JSON.stringify(data, "  ", false) + "\n")
	print("INSIGNIA %d written to %s" % [items.size(), dir])
	return OK


## --insignia-sheet=PATH: the whole collection on one image, to look over
## (or only the ids listed in `only`).
static func sheet(path: String, px := 96, cols := 16, only := PackedStringArray()) -> void:
	var list := []
	for e: Dictionary in CATALOG:
		if only.is_empty() or String(e.id) in only:
			list.append(e)
	cols = mini(cols, list.size())
	var gap := 8
	var rows := ceili(list.size() / float(cols))
	var img := Image.create(cols * (px + gap) + gap, rows * (px + gap) + gap, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.085, 0.08))
	for i in list.size():
		var one := Image.new()
		one.load_svg_from_string(InsigniaArt.svg(list[i]), px / 128.0)
		one.convert(Image.FORMAT_RGBA8)
		img.blend_rect(one, Rect2i(0, 0, px, px), Vector2i(gap + (i % cols) * (px + gap), gap + (i / cols) * (px + gap)))
	img.save_png(path)
	print("INSIGNIA sheet %s" % path)


# --- the catalog ------------------------------------------------------------------------
# n: name, d: one line about it; the rest is the picture (InsigniaArt):
#   s shape, f field [kind, colours..], b border, bw border width,
#   c devices [symbol, colour, scale, dx, dy, rotation, second colour],
#   t lettering [where, text, colour, ...], tab [text, field, letters, border],
#   m "medal" (rib: ribbon stripes, c: the pendant) or "rack" (bars).

const CATALOG := [
	# starters: the branches
	{"id": "s01", "n": "Infantry", "d": "Crossed rifles on infantry blue: the queen of battle.",
		"s": "circle", "f": ["plain", "blue"], "b": "white", "c": [["rifles", "white", 0.8, 0, 2, 0, "#cfd5dc"]]},
	{"id": "s02", "n": "Armour", "d": "The three-coloured triangle of the tank arm.",
		"s": "triangle", "f": ["tri", "yellow", "blue", "red"], "b": "black", "c": [["tank", "black", 0.56, 0, 12, 0, "#3a3c3e"]]},
	{"id": "s03", "n": "Artillery", "d": "Crossed cannons in gold on red: the king of battle.",
		"s": "shield", "f": ["plain", "red"], "b": "yellow", "c": [["cannons", "yellow", 0.74, 0, -2]]},
	{"id": "s04", "n": "Combat Engineers", "d": "The castle: they build it, and they blow it up.",
		"s": "tombstone", "f": ["plain", "red"], "b": "white", "c": [["castle", "white", 0.66, 0, 6]]},
	{"id": "s05", "n": "Signal Corps", "d": "Crossed lightning on orange: the voice of command.",
		"s": "octagon", "f": ["plain", "orange"], "b": "white", "c": [["bolts", "white", 0.74]]},
	{"id": "s06", "n": "Combat Medic", "d": "A white cross on maroon. Doc, the most welcome man on any battlefield.",
		"s": "shield2", "f": ["plain", "maroon"], "b": "white", "c": [["cross", "white", 0.54, 0, -2]]},
	{"id": "s07", "n": "Scouts", "d": "The open eye of reconnaissance.",
		"s": "diamond", "f": ["plain", "jungle"], "b": "yellow", "c": [["eye", "yellow", 0.62]]},
	{"id": "s08", "n": "Paratrooper", "d": "Canopy and wings: the ones who go in first, from the sky.",
		"s": "circle", "f": ["plain", "navy"], "b": "white", "c": [["jumpwings", "white", 0.9, 0, 0, 0, "#aab6c4"]]},
	{"id": "s09", "n": "Mountain Troops", "d": "Snow-capped peaks on sky blue, for those who fight uphill.",
		"s": "shield", "f": ["plain", "sky"], "b": "navy", "c": [["mountain", "steel", 0.74, 0, 2]]},
	{"id": "s10", "n": "Naval Infantry", "d": "The fouled anchor: soldiers of the sea.",
		"s": "pentagon", "f": ["plain", "red"], "b": "yellow", "c": [["anchor", "yellow", 0.64, 0, -3]]},

	# rank patches: Private (1-5), basic training in subdued thread
	{"id": "r01", "n": "Recruit Depot", "d": "Your first patch. Everyone starts somewhere.",
		"s": "circle", "f": ["plain", "od"], "b": "black", "c": [["star", "khaki", 0.52]]},
	{"id": "r02", "n": "Rifle Range", "d": "Front sight, squeeze, follow through.",
		"s": "circle", "f": ["plain", "khaki"], "b": "od", "c": [["crosshair", "black", 0.66]]},
	{"id": "r03", "n": "Point Man", "d": "First in the column, eyes on everything.",
		"s": "shield", "f": ["plain", "od"], "b": "black", "c": [["arrow", "khaki", 0.68, 0, -2]]},
	{"id": "r04", "n": "Night Watch", "d": "Two hours on, four off, until dawn.",
		"s": "circle", "f": ["plain", "black"], "b": "od", "c": [["crescent", "khaki", 0.56, -6, 0], ["star", "khaki", 0.2, 18, -14]]},
	{"id": "r05", "n": "Fire Team", "d": "Four men, one team. Bounding overwatch.",
		"s": "shield2", "f": ["bend", "od", "black"], "b": "khaki", "c": [["lightning", "khaki", 0.62]]},
	# Corporal (6-10): colour appears
	{"id": "r06", "n": "Iron Fist", "d": "Hit hard, hit first.",
		"s": "square", "f": ["plain", "red"], "b": "black", "c": [["fist", "grey", 0.66]]},
	{"id": "r07", "n": "Bolt Battalion", "d": "Fast enough to arrive before the thunder.",
		"s": "shield2", "f": ["pale", "blue", "white"], "b": "yellow", "c": [["lightning", "yellow", 0.66]]},
	{"id": "r08", "n": "Grey Wolves", "d": "They hunt in packs.",
		"s": "circle", "f": ["plain", "grey"], "b": "black", "c": [["wolf", "white", 0.7, 0, 0, 0, "grey"]]},
	{"id": "r09", "n": "River Guard", "d": "Holding the crossings since the first bridge.",
		"s": "shield", "f": ["wave", "blue", "navy", "sky"], "b": "white", "c": [["trident", "white", 0.6, 0, -8]]},
	{"id": "r10", "n": "Thunder Company", "d": "You'll hear them coming. Too late.",
		"s": "pentagon", "f": ["plain", "black"], "b": "yellow", "c": [["bolts", "yellow", 0.7, 0, -2]]},
	# Sergeant (11-15): the lettered company patches
	{"id": "r11", "n": "Mustangs", "d": "A Troop rides again.",
		"s": "circle", "f": ["ring", "black", "red"], "b": "white", "c": [["horse", "white", 0.48, 0, 0, 0, "black"]],
		"t": [["top", "MUSTANGS", "white"], ["bot", "A TROOP", "white"]]},
	{"id": "r12", "n": "Sand Vipers", "d": "Desert patrol. Mind where you step.",
		"s": "circle", "f": ["ring", "brown", "sand"], "b": "black", "c": [["cobra", "black", 0.56, 0, -2, 0, "sand"]],
		"t": [["top", "SAND VIPERS", "sand"], ["bot", "LRRP", "sand"]]},
	{"id": "r13", "n": "Iron Dragoons", "d": "Mounted infantry: they ride to the fight and fight on foot.",
		"s": "shield", "f": ["band", "blue", "yellow"], "b": "yellow", "c": [["swords", "white", 0.66, 0, 0, 0, "yellow"]]},
	{"id": "r14", "n": "Pathfinders", "d": "They light the way for everyone else.",
		"s": "tombstone", "f": ["plain", "black"], "b": "yellow", "c": [["torch", "orange", 0.56, 0, -6, 0, "brown"]],
		"t": [["line", "PATHFINDER", "yellow", 9, 40]]},
	{"id": "r15", "n": "Hellcats", "d": "C Company, and proud of the claw marks.",
		"s": "circle", "f": ["ring", "black", "orange"], "b": "orange", "c": [["tiger", "orange", 0.5, 0, 0, 0, "lime"]],
		"t": [["top", "HELLCATS", "orange"], ["bot", "C COMPANY", "orange"]]},
	# Staff Sergeant (16-20): tabbed
	{"id": "r16", "n": "Mountain Raiders", "d": "The tab says it all.",
		"s": "shield2", "f": ["plain", "red"], "b": "white", "c": [["mountain", "white", 0.68, 0, 2]], "tab": ["MOUNTAIN", "black", "white", "white"]},
	{"id": "r17", "n": "Air Assault", "d": "Forty men down in a hot landing zone in forty seconds.",
		"s": "shield", "f": ["plain", "sky"], "b": "black", "c": [["helicopter", "black", 0.68, 0, -2]], "tab": ["AIR ASSAULT", "black", "yellow"]},
	{"id": "r18", "n": "Night Owls", "d": "They own the dark.",
		"s": "circle", "f": ["plain", "navy"], "b": "white", "c": [["owl", "brown", 0.6, 0, 0, 0, "yellow"]], "tab": ["NIGHT OWLS", "black", "white", "white"]},
	{"id": "r19", "n": "Black Scorpions", "d": "Desert warfare school graduates.",
		"s": "shield", "f": ["plain", "tan"], "b": "black", "c": [["scorpion", "black", 0.7, 0, -2]], "tab": ["DESERT", "tan", "black", "black"]},
	{"id": "r20", "n": "Storm Riders", "d": "Jump into the storm, land in the fight.",
		"s": "shield", "f": ["plain", "navy"], "b": "yellow", "c": [["parachute", "white", 0.6, 0, -4], ["lightning", "yellow", 0.3, -26, 12], ["lightning", "yellow", -0.3, 26, 12]],
		"tab": ["AIRBORNE", "black", "yellow"]},
	# Master Sergeant (21-25): bolder fields
	{"id": "r21", "n": "Dawn Eagles", "d": "First light, first strike.",
		"s": "circle", "f": ["rays", "orange", "yellow"], "b": "maroon", "c": [["eaglehead", "white", 0.68, 0, 0, 0, "yellow"]]},
	{"id": "r22", "n": "Checkmate", "d": "Every move planned, every piece in play.",
		"s": "square", "f": ["chequy", "black", "white"], "b": "red", "c": [["horse", "red", 0.68, 0, 0, 0, "white"]]},
	{"id": "r23", "n": "Four Winds", "d": "Any direction, any distance.",
		"s": "circle", "f": ["quarter", "blue", "white"], "b": "blue", "c": [["compass", "yellow", 0.82, 0, 0, 0, "red"]]},
	{"id": "r24", "n": "Iron Bears", "d": "Slow to anger. Impossible to stop.",
		"s": "shield", "f": ["pale", "steel", "black"], "b": "white", "c": [["bear", "brown", 0.66, 0, 0, 0, "tan"]]},
	{"id": "r25", "n": "Firebrands", "d": "Assault pioneers with a flamethrower habit.",
		"s": "shield2", "f": ["chevron", "black", "red"], "b": "yellow", "c": [["flame", "orange", 0.56, 0, -6, 0, "yellow"]]},
	# Lieutenant (26-30): aviation and air cavalry
	{"id": "r26", "n": "Sky Cavalry", "d": "The horses have rotors now.",
		"s": "circle", "f": ["ring", "black", "yellow"], "b": "yellow", "c": [["helicopter", "black", 0.6, 0, 2]],
		"t": [["top", "SKY CAVALRY", "yellow"], ["bot", "AIR CAV", "yellow"]]},
	{"id": "r27", "n": "Hunter Killers", "d": "One finds, the other fixes. Both kill.",
		"s": "shield", "f": ["plain", "black"], "b": "red", "c": [["crosshair", "red", 0.84, 0, -2], ["helicopter", "white", 0.56, 0, -2]]},
	{"id": "r28", "n": "Jet Wing", "d": "Fast movers, on call.",
		"s": "hexagon", "f": ["plain", "sky"], "b": "navy", "c": [["wings", "white", 0.96, 0, 8, 0, "#b9c4d0"], ["jet", "navy", 0.56, 0, -6, 0, "sky"]]},
	{"id": "r29", "n": "Thunderbolts", "d": "Close air support with a temper.",
		"s": "circle", "f": ["ring", "navy", "sky"], "b": "white", "c": [["lightning", "yellow", 0.54, 8, 4], ["jet", "white", 0.42, -8, -2, -30, "navy"]],
		"t": [["top", "THUNDERBOLTS", "white"], ["bot", "FIGHTER WING", "white"]]},
	{"id": "r30", "n": "Eagle Flight", "d": "Three stars over the eagle: the flight that leads.",
		"s": "shield", "f": ["chief", "sky", "navy"], "b": "white", "c": [["eagle", "white", 0.66, 0, 10, 0, "grey"], ["stars3", "white", 0.44, 0, -30]]},
	# Captain (31-35): special operations
	{"id": "r31", "n": "Commandos", "d": "The arrowhead and the fighting knife.",
		"s": "arrowhead", "f": ["plain", "jungle"], "b": "yellow", "c": [["dagger", "white", 0.6, 0, 6, 0, "yellow"]], "tab": ["COMMANDO", "black", "yellow"]},
	{"id": "r32", "n": "Shadow Company", "d": "Officially, they were never there.",
		"s": "arrowhead", "f": ["plain", "black"], "b": "grey", "c": [["skull", "white", 0.5, 0, 8]]},
	{"id": "r33", "n": "Black Arrows", "d": "Deep strike, no warning.",
		"s": "arrowhead", "f": ["plain", "red"], "b": "black", "c": [["arrows", "black", 0.66, 0, 10]]},
	{"id": "r34", "n": "Frogmen", "d": "In from the sea, under it.",
		"s": "circle", "f": ["ring", "black", "navy"], "b": "yellow", "c": [["waves", "teal", 0.4, 0, 16], ["trident", "yellow", 0.5, 0, -6]],
		"t": [["top", "FROGMEN", "yellow"], ["bot", "DIVE TEAM", "yellow"]]},
	{"id": "r35", "n": "Snake Eaters", "d": "Long range recon. They live off the jungle.",
		"s": "circle", "f": ["ring", "black", "jungle"], "b": "lime", "c": [["dagger", "white", 0.56, 0, 0, 0, "brown"], ["cobra", "lime", 0.5, 0, 2, 0, "black"]],
		"t": [["top", "SNAKE EATERS", "lime"], ["bot", "RECON", "lime"]]},
	# Major (36-40): armour and guns
	{"id": "r36", "n": "Thunder Run", "d": "Straight down the highway at forty miles an hour.",
		"s": "triangle", "f": ["plain", "black"], "b": "yellow", "c": [["tank", "yellow", 0.56, 0, 12, 0, "#8a6d1c"], ["lightning", "red", 0.34, 0, -16]]},
	{"id": "r37", "n": "Steel Rain", "d": "The guns that answer every call for fire.",
		"s": "octagon", "f": ["plain", "steel"], "b": "red", "c": [["cannons", "white", 0.74]]},
	{"id": "r38", "n": "Juggernaut", "d": "Nothing on the field can stop it.",
		"s": "circle", "f": ["rays", "black", "steel"], "b": "yellow", "c": [["tank", "yellow", 0.66, 0, 0, 0, "#6e5a20"]]},
	{"id": "r39", "n": "The Dukes", "d": "Old regiment, older traditions.",
		"s": "shield", "f": ["quarter", "red", "black"], "b": "yellow", "c": [["swords", "white", 0.6, 0, 8, 0, "yellow"], ["crown", "yellow", 0.36, 0, -24, 0, "red"]]},
	{"id": "r40", "n": "Line Breakers", "d": "When the line won't move, they move it.",
		"s": "diamond", "f": ["bend", "yellow", "black"], "b": "black", "c": [["lightning", "red", 0.62], ["fist", "white", 0.4, 0, 2]]},
	# Colonel (41-45): bullion
	{"id": "r41", "n": "Laurel Guard", "d": "Gold bullion on navy: honour earned.",
		"s": "circle", "f": ["plain", "navy"], "b": "@gold", "c": [["wreath", "@gold", 0.88], ["star", "@gold", 0.38, 0, -4]]},
	{"id": "r42", "n": "Crown Command", "d": "The regiment's colours, and its crown.",
		"s": "shield", "f": ["plain", "maroon"], "b": "@gold", "c": [["wreath", "@gold", 0.8, 0, 6], ["crown", "@gold", 0.42, 0, -2, 0, "red"]]},
	{"id": "r43", "n": "Order of the Sword", "d": "Silver blade, golden laurel.",
		"s": "shield2", "f": ["plain", "black"], "b": "@silver", "c": [["wreath", "@gold", 0.84, 0, 4], ["sword", "@silver", 0.7, 0, 0, 0, "@gold"]]},
	{"id": "r44", "n": "Silver Eagle", "d": "The colonel's eagle, spread in silver.",
		"s": "circle", "f": ["plain", "navy"], "b": "@silver", "c": [["eagle", "@silver", 0.84, 0, 0, 0, "#7c838a"]]},
	{"id": "r45", "n": "Phoenix Brigade", "d": "Rebuilt from the ashes, twice.",
		"s": "circle", "f": ["rays", "maroon", "red"], "b": "@gold", "c": [["flame", "orange", 0.84, 0, 4, 0, "yellow"], ["eagle", "yellow", 0.6, 0, 0, 0, "orange"]]},
	# the generals: a star for each grade
	{"id": "r46", "n": "Brigade Command", "d": "One star. A brigade answers to you.",
		"s": "shield2", "f": ["plain", "red"], "b": "@gold", "bw": 7.0, "c": [["star", "white", 0.52, 0, -2]]},
	{"id": "r47", "n": "Division Command", "d": "Two stars and the laurel.",
		"s": "shield2", "f": ["plain", "red"], "b": "@gold", "bw": 7.0, "c": [["wreath", "@gold", 0.92, 0, 4], ["stars2", "white", 0.66, 0, -2]]},
	{"id": "r48", "n": "Corps Command", "d": "Three stars. Divisions move when you speak.",
		"s": "circle", "f": ["plain", "navy"], "b": "@gold", "bw": 7.0, "c": [["wreath", "@gold", 0.94, 0, 4], ["stars3", "@gold", 0.66, 0, -2]]},
	{"id": "r49", "n": "Army Command", "d": "Four stars over the golden eagle.",
		"s": "shield", "f": ["plain", "navy"], "b": "@gold", "bw": 7.0, "c": [["eagle", "@gold", 0.6, 0, 12, 0, "#a87420"], ["stars4", "@gold", 0.66, 0, -26]]},
	{"id": "r50", "n": "Supreme Command", "d": "Five stars in a ring. General of the Army: there is no higher rank.",
		"s": "circle", "f": ["rays", "navy", "#22366e"], "b": "@gold", "bw": 8.0, "c": [["wreath", "@gold", 0.92, 0, 4], ["starsring5", "@gold", 0.62, 0, -1]]},

	# awards and decorations: medals
	{"id": "m01", "n": "Valor Cross", "d": "For extraordinary heroism in combat.",
		"m": "medal", "rib": ["blue:2", "white:1", "red:2", "white:1", "blue:2"], "c": [["pattee", "@bronze", 0.66], ["star", "@gold", 0.22]]},
	{"id": "m02", "n": "Star of Gallantry", "d": "For gallantry in action against an enemy.",
		"m": "medal", "rib": ["#e9b949:1", "blue:1", "white:1", "red:2", "white:1", "blue:1", "#e9b949:1"], "c": [["star", "@gold", 0.7], ["star", "@silver", 0.22, 0, 1]]},
	{"id": "m03", "n": "Silver Valor Star", "d": "Third highest for valour, and worn proudly.",
		"m": "medal", "rib": ["red:3", "white:1", "blue:1", "white:1", "red:3"], "c": [["star", "@silver", 0.7], ["wreath", "@gold", 0.32, 0, 1]]},
	{"id": "m04", "n": "Bronze Service Star", "d": "For meritorious service in a combat zone.",
		"m": "medal", "rib": ["red:1", "white:0.4", "blue:3", "white:0.4", "red:1"], "c": [["star", "@bronze", 0.68], ["star", "@bronze", 0.2, 0, 1]]},
	{"id": "m05", "n": "Wounded in Action", "d": "Bled for it. Nobody wants this one.",
		"m": "medal", "rib": ["white:1", "purple:8", "white:1"], "c": [["heart", "@gold", 0.6], ["heart", "purple", 0.46, 0, 1]]},
	{"id": "m06", "n": "Distinguished Service", "d": "For exceptional service in a position of great responsibility.",
		"m": "medal", "rib": ["white:1", "red:1", "white:1", "blue:4", "white:1", "red:1", "white:1"], "c": [["maltese", "@gold", 0.66, 0, 0, 0, "blue"]]},
	{"id": "m07", "n": "Air Valor Medal", "d": "For valour in aerial flight.",
		"m": "medal", "metal": "@bronze", "rib": ["ultra:3", "orange:1", "ultra:3", "orange:1", "ultra:3"], "c": [["compass", "@bronze", 0.72, 0, 0, 0, "@bronze"], ["eagle", "@bronze", 0.24]]},
	{"id": "m08", "n": "Steadfast Service", "d": "Three years of exemplary conduct. Allegedly.",
		"m": "medal", "metal": "@bronze", "rib": ["red:3", "white:0.5", "red:3", "white:0.5", "red:3"], "c": [["disc", "@bronze", 0.62], ["eaglehead", "@bronze", 0.4, 0, 0, 0, "@bronze"]]},
	{"id": "m09", "n": "Jungle Campaign", "d": "Served in the jungle war.",
		"m": "medal", "metal": "@bronze", "rib": ["yellow:2", "green:1", "yellow:1", "red:1", "yellow:1", "red:1", "yellow:1", "green:1", "yellow:2"], "c": [["disc", "@bronze", 0.62], ["palm", "@bronze", 0.42, 0, 0, 0, "@bronze"]]},
	{"id": "m10", "n": "Desert Campaign", "d": "Served in the desert war.",
		"m": "medal", "metal": "@bronze", "rib": ["tan:2", "black:0.5", "green:1", "white:0.5", "red:1", "white:0.5", "green:1", "black:0.5", "tan:2"], "c": [["disc", "@bronze", 0.62], ["mountain", "@bronze", 0.36, 0, 4], ["star", "@bronze", 0.12, 0, -12]]},
	{"id": "m11", "n": "Arctic Service", "d": "Cold enough to freeze the oil in the guns.",
		"m": "medal", "metal": "@silver", "rib": ["white:2", "sky:1", "white:1", "blue:2", "white:1", "sky:1", "white:2"], "c": [["star4", "@silver", 0.72], ["star4", "@silver", 0.42, 0, 0, 45]]},
	{"id": "m12", "n": "River Patrol", "d": "Brown water navy: the boats on the rivers.",
		"m": "medal", "metal": "@bronze", "rib": ["navy:2", "teal:2", "white:1", "teal:2", "navy:2"], "c": [["disc", "@bronze", 0.62], ["ship", "@bronze", 0.42]]},
	{"id": "m13", "n": "Delta Campaign", "d": "The paddies and canals of the delta.",
		"m": "medal", "rib": ["yellow:3", "red:1", "yellow:1", "red:1", "yellow:3"], "c": [["disc", "@gold", 0.62], ["dragon", "@gold", 0.42]]},
	{"id": "m14", "n": "Mountain Campaign", "d": "Fought along the ridgelines.",
		"m": "medal", "metal": "@silver", "rib": ["brown:2", "white:1", "green:2", "white:1", "brown:2"], "c": [["disc", "@silver", 0.62], ["mountain", "@silver", 0.42]]},
	{"id": "m15", "n": "Order of the Iron Wolf", "d": "For leading from the front.",
		"m": "medal", "metal": "@silver", "rib": ["black:2", "grey:1", "black:2", "grey:1", "black:2"], "c": [["maltese", "@silver", 0.68, 0, 0, 0, "black"], ["wolf", "@silver", 0.2, 0, 0, 0, "@silver"]]},
	{"id": "m16", "n": "Legion of the Laurel", "d": "For a career of outstanding service.",
		"m": "medal", "rib": ["white:0.6", "maroon:6", "white:0.6"], "c": [["wreath", "@gold", 0.66], ["star", "white", 0.44, 0, -2]]},
	{"id": "m17", "n": "Lifesaving Medal", "d": "For saving a life at the risk of one's own.",
		"m": "medal", "metal": "@silver", "rib": ["red:2", "white:1", "red:2", "white:1", "red:2"], "c": [["disc", "@silver", 0.62], ["cross", "red", 0.28]]},
	{"id": "m18", "n": "Airborne Assault", "d": "For a combat jump.",
		"m": "medal", "metal": "@bronze", "rib": ["navy:2", "white:1", "sky:2", "white:1", "navy:2"], "c": [["star4", "@bronze", 0.72], ["parachute", "@bronze", 0.3, 0, -2]]},
	{"id": "m19", "n": "Combat Aviation Cross", "d": "For heroism while flying.",
		"m": "medal", "metal": "@bronze", "rib": ["ultra:2", "white:1", "red:1", "white:1", "ultra:2"], "c": [["pattee", "@bronze", 0.66], ["airwings", "@gold", 0.5, 0, 0, 0, "@gold"]]},
	{"id": "m20", "n": "Long Service", "d": "Twenty years in uniform.",
		"m": "medal", "metal": "@bronze", "rib": ["green:2", "yellow:1", "green:2"], "c": [["disc", "@bronze", 0.62], ["oakleaf", "@bronze", 0.42, 0, 0, 30, "@bronze"]]},
	{"id": "m21", "n": "Supreme Valor Medal", "d": "The highest award for valour. Few live to wear it.",
		"m": "medal", "rib": ["sky:1"], "c": [["wreath", "green", 0.8, 0, 0, 0, "@gold"], ["star", "@gold", 0.64]]},
	{"id": "m22", "n": "Sea Valor Cross", "d": "For heroism at sea.",
		"m": "medal", "metal": "@bronze", "rib": ["navy:3", "white:1", "navy:3"], "c": [["pattee", "@bronze", 0.66], ["anchor", "@bronze", 0.3]]},
	{"id": "m23", "n": "Prisoner of War", "d": "For those who were held, and came home.",
		"m": "medal", "metal": "@bronze", "rib": ["black:1", "white:1", "blue:1", "white:1", "red:2", "white:1", "blue:1", "white:1", "black:1"], "c": [["disc", "@bronze", 0.62], ["eagle", "@bronze", 0.38]]},
	{"id": "m24", "n": "Expeditionary Medal", "d": "Wherever they were sent.",
		"m": "medal", "metal": "@bronze", "rib": ["green:2", "yellow:1", "blue:2", "yellow:1", "green:2"], "c": [["disc", "@bronze", 0.62], ["globe", "@bronze", 0.42, 0, 0, 0, "#5e3412"]]},
	{"id": "m25", "n": "Coalition Service", "d": "Served with the Coalition.",
		"m": "medal", "metal": "@silver", "rib": ["coalition:3", "white:1", "coalition:3"], "c": [["star", "@silver", 0.68], ["shieldc", "coalition", 0.22, 0, 1]]},
	# badges
	{"id": "m26", "n": "Jump Wings", "d": "Five jumps from a perfectly good aircraft.",
		"s": "none", "c": [["jumpwings", "@silver", 1.08, 0, 0, 0, "@silver"]]},
	{"id": "m27", "n": "Senior Jump Wings", "d": "Thirty jumps, and a star for the trouble.",
		"s": "none", "c": [["jumpwings", "@silver", 1.0, 0, 8, 0, "@silver"], ["star", "@silver", 0.24, 0, -24]]},
	{"id": "m28", "n": "Master Jump Wings", "d": "Sixty-five jumps. The wreath says master.",
		"s": "none", "c": [["jumpwings", "@silver", 1.0, 0, 10, 0, "@silver"], ["wreath", "@silver", 0.38, 0, -24], ["star", "@silver", 0.2, 0, -25]]},
	{"id": "m29", "n": "Aviator Wings", "d": "Rated to fly.",
		"s": "none", "c": [["airwings", "@silver", 1.08, 0, 0, 0, "@silver"]]},
	{"id": "m30", "n": "Combat Rifleman", "d": "The rifle on blue, in the laurel: under fire as an infantryman.",
		"s": "none", "c": [["wreath", "@silver", 0.9, 0, 10], ["bar", "#2d5aa8", 0.94, 0, -14], ["rifle", "@silver", 0.86, 0, -14, 90, "@silver"]]},
	{"id": "m31", "n": "Combat Medic Badge", "d": "Treated the wounded under fire.",
		"s": "none", "c": [["wreath", "@silver", 0.9, 0, 10], ["bar", "@silver", 0.9, 0, -16], ["cross", "maroon", 0.22, 0, -16]]},
	{"id": "m32", "n": "Expert Marksman", "d": "Forty of forty at the range.",
		"s": "none", "c": [["pattee", "@silver", 0.86], ["crosshair", "#2a2e33", 0.4]]},
	{"id": "m33", "n": "Scout Sniper", "d": "One shot.",
		"s": "none", "c": [["rifles", "@silver", 0.82, 0, 8, 0, "@silver"], ["crosshair", "@silver", 0.46, 0, -18]]},
	{"id": "m34", "n": "Bomb Disposal", "d": "Initial success or total failure.",
		"s": "none", "c": [["wreath", "@silver", 0.9, 0, 8], ["bomb", "@silver", 0.52, 2, -4, 0, "@silver"], ["lightning", "@silver", 0.26, -32, -18], ["lightning", "@silver", -0.26, 32, -18]]},
	{"id": "m35", "n": "Air Assault Badge", "d": "Rappel, sling load, repeat.",
		"s": "none", "c": [["heliwings", "@silver", 1.04, 0, 2, 0, "@silver"]]},
	{"id": "m36", "n": "Pathfinder Badge", "d": "The torch and the wings: first on the drop zone.",
		"s": "none", "c": [["torchwings", "@gold", 1.04, 0, 0, 0, "@gold"]]},
	{"id": "m37", "n": "Combat Diver", "d": "Qualified to go in under water.",
		"s": "none", "c": [["waves", "@silver", 0.62, 0, 16], ["trident", "@gold", 0.6, 0, -8]]},
	{"id": "m38", "n": "Mountain Warfare", "d": "Qualified on rock, ice and snow.",
		"s": "none", "c": [["wreath", "@silver", 0.9, 0, 4], ["mountain", "@silver", 0.56, 0, -2]]},
	{"id": "m39", "n": "Raider Tab", "d": "Sixty days of the hardest course in the army.",
		"s": "tab", "box": [6, 42, 116, 44], "f": ["plain", "black"], "b": "yellow", "bw": 4.0, "t": [["line", "RAIDER", "yellow", 20, 0]]},
	{"id": "m40", "n": "Sapper Tab", "d": "Combat engineers who lead the way.",
		"s": "tab", "box": [6, 42, 116, 44], "f": ["plain", "black"], "b": "red", "bw": 4.0, "t": [["line", "SAPPER", "white", 20, 0]]},
	{"id": "m41", "n": "Commando Badge", "d": "The winged dagger.",
		"s": "none", "c": [["wings", "@gold", 1.0, 0, 6, 0, "@gold"], ["dagger", "@gold", 0.68, 0, -2, 0, "@gold"]]},
	{"id": "m42", "n": "Tanker Badge", "d": "Qualified in armour, and under fire in it.",
		"s": "none", "c": [["wreath", "@silver", 0.92, 0, 8], ["tank", "@silver", 0.56, 0, -2, 0, "@silver"]]},
	{"id": "m43", "n": "Gunnery Badge", "d": "Master of the guns.",
		"s": "none", "c": [["wreath", "@gold", 0.92, 0, 8], ["cannons", "@gold", 0.6, 0, -4]]},
	{"id": "m44", "n": "Signal Badge", "d": "Kept the net up when it mattered.",
		"s": "none", "c": [["globe", "@silver", 0.56, 0, 0, 0, "#2a2e33"], ["bolts", "@gold", 0.84]]},
	{"id": "m45", "n": "Driver and Mechanic", "d": "Ten thousand miles without an accident.",
		"s": "none", "c": [["wreath", "@bronze", 0.92, 0, 8], ["tools", "@silver", 0.6, 0, -2, 0, "@bronze"]]},
	# ribbon racks
	{"id": "m46", "n": "Campaign Ribbons", "d": "Six campaigns, worn on the chest.",
		"m": "rack", "bars": [["yellow:2", "green:1", "red:1", "yellow:1", "red:1", "green:1", "yellow:2"], ["tan:2", "green:1", "white:1", "red:1", "white:1", "green:1", "tan:2"],
			["navy:2", "teal:2", "white:1", "teal:2", "navy:2"], ["brown:2", "white:1", "green:2", "white:1", "brown:2"], ["white:2", "sky:1", "blue:2", "sky:1", "white:2"],
			["green:2", "yellow:1", "blue:2", "yellow:1", "green:2"]]},
	{"id": "m47", "n": "Unit Citation", "d": "For the unit, not the man: everyone who was there.",
		"m": "rack", "bars": [["blue:1", "*"], ["red:2", "yellow:1", "red:2", "*"], ["green:2", "white:1", "red:1", "white:1", "green:2"]]},
	{"id": "m48", "n": "Service Ribbons", "d": "A career's worth of service.",
		"m": "rack", "bars": [["red:3", "white:0.5", "red:3"], ["white:1", "maroon:6", "white:1"], ["green:2", "yellow:1", "green:2"],
			["blue:2", "white:1", "red:2", "white:1", "blue:2"], ["navy:3", "white:1", "navy:3"], ["ultra:3", "orange:1", "ultra:3", "orange:1", "ultra:3"],
			["black:2", "grey:1", "black:2"], ["coalition:3", "white:1", "coalition:3"], ["tan:2", "brown:1", "tan:2"]]},
	{"id": "m49", "n": "Veteran's Rack", "d": "Stars on the ribbons: more than one tour.",
		"m": "rack", "bars": [["sky:1", "*"], ["purple:8", "white:1", "*"], ["red:3", "white:1", "blue:1", "white:1", "red:3", "*"],
			["red:1", "white:0.4", "blue:3", "white:0.4", "red:1"], ["yellow:2", "green:1", "red:1", "yellow:1", "red:1", "green:1", "yellow:2", "*"], ["navy:2", "white:1", "sky:2", "white:1", "navy:2"],
			["green:2", "yellow:1", "green:2", "*"], ["white:2", "sky:1", "blue:2", "sky:1", "white:2"], ["brown:2", "white:1", "green:2", "white:1", "brown:2"]]},
	{"id": "m50", "n": "Hero's Rack", "d": "Twelve ribbons, top row first. You'd want to hear the stories.",
		"m": "rack", "bars": [["sky:1", "*"], ["blue:2", "white:1", "red:2", "white:1", "blue:2", "*"], ["#e9b949:1", "blue:1", "white:1", "red:2", "white:1", "blue:1", "#e9b949:1"],
			["red:3", "white:1", "blue:1", "white:1", "red:3", "*"], ["white:1", "purple:8", "white:1", "*"], ["white:1", "red:1", "white:1", "blue:4", "white:1", "red:1", "white:1"],
			["ultra:3", "orange:1", "ultra:3", "orange:1", "ultra:3"], ["navy:3", "white:1", "navy:3"], ["red:1", "white:0.4", "blue:3", "white:0.4", "red:1", "*"],
			["yellow:2", "green:1", "red:1", "yellow:1", "red:1", "green:1", "yellow:2"], ["tan:2", "green:1", "white:1", "red:1", "white:1", "green:1", "tan:2"], ["green:2", "yellow:1", "blue:2", "yellow:1", "green:2"]]},

	# unit patches: company and squadron patches, Vietnam style, and the battlefield's own
	{"id": "u01", "n": "Snake Pit", "d": "First Platoon's hootch, and its pet.",
		"s": "circle", "f": ["ring", "black", "yellow"], "b": "yellow", "c": [["cobra", "black", 0.56, 0, -2, 0, "yellow"]],
		"t": [["top", "SNAKE PIT", "yellow"], ["bot", "1ST PLATOON", "yellow"]]},
	{"id": "u02", "n": "Gunslingers", "d": "Gunship platoon. Rockets and miniguns on call.",
		"s": "circle", "f": ["ring", "red", "black"], "b": "white", "c": [["helicopter", "white", 0.58, 0, 2]],
		"t": [["top", "GUNSLINGERS", "white"], ["bot", "GUNSHIP PLT", "white"]]},
	{"id": "u03", "n": "Dustoff", "d": "Medevac. They come in under fire for you.",
		"s": "circle", "f": ["ring", "white", "red"], "b": "red", "c": [["helicopter", "white", 0.52, 0, 8], ["cross", "white", 0.2, 0, -20]],
		"t": [["top", "DUSTOFF", "red"], ["bot", "MEDEVAC", "red"]]},
	{"id": "u04", "n": "Night Hawks", "d": "Searchlight and minigun, hunting after dark.",
		"s": "shield", "f": ["plain", "navy"], "b": "white", "c": [["eaglehead", "black", 0.66, 0, -6, 0, "yellow"], ["crescent", "white", 0.2, 26, -28]],
		"t": [["scroll", "NIGHT HAWKS", "black", "white"]]},
	{"id": "u05", "n": "River Rats", "d": "Patrol boats on the brown water.",
		"s": "circle", "f": ["ring", "navy", "teal"], "b": "white", "c": [["ship", "white", 0.58, 0, 0, 0, "grey"]],
		"t": [["top", "RIVER RATS", "white"], ["bot", "BOAT SQN", "white"]]},
	{"id": "u06", "n": "Jungle Kings", "d": "Crowned by the jungle, and they earned it.",
		"s": "shield2", "f": ["base", "jungle", "green"], "b": "yellow", "c": [["tiger", "orange", 0.56, 0, 2, 0, "lime"], ["crown", "yellow", 0.28, 0, -30, 0, "red"]],
		"t": [["scroll", "JUNGLE KINGS", "black", "yellow"]]},
	{"id": "u07", "n": "Death Dealers", "d": "Ace of spades, left on the trail.",
		"s": "square", "f": ["plain", "white"], "b": "black", "c": [["spade", "black", 0.62, 0, 2], ["skull", "white", 0.2, 0, 2]],
		"t": [["line", "A", "black", 13, -38, -36], ["line", "A", "black", 13, 38, 36]]},
	{"id": "u08", "n": "Magic Dragon", "d": "The gunship that breathes fire from the night sky.",
		"s": "circle", "f": ["ring", "black", "red"], "b": "yellow", "c": [["dragon", "yellow", 0.6, 0, 0, 0, "orange"]],
		"t": [["top", "MAGIC DRAGON", "yellow"], ["bot", "GUNSHIP", "yellow"]]},
	{"id": "u09", "n": "Wolfpack", "d": "B Company runs together.",
		"s": "circle", "f": ["ring", "black", "grey"], "b": "white", "c": [["wolf", "black", 0.58, 0, 0, 0, "grey"]],
		"t": [["top", "WOLFPACK", "white"], ["bot", "B COMPANY", "white"]]},
	{"id": "u10", "n": "Bat Company", "d": "Night ambushes, every night.",
		"s": "octagon", "f": ["plain", "navy"], "b": "yellow", "c": [["crescent", "yellow", 0.52, 10, -6], ["bat", "black", 0.7, 0, 2]],
		"t": [["line", "BAT COMPANY", "yellow", 9, 40]]},
	{"id": "u11", "n": "Tunnel Rats", "d": "A torch, a pistol, and a hole in the ground.",
		"s": "circle", "f": ["ring", "black", "brown"], "b": "khaki", "c": [["torch", "orange", 0.52, 0, 0, 0, "grey"]],
		"t": [["top", "TUNNEL RATS", "khaki"], ["bot", "GO DEEP", "khaki"]]},
	{"id": "u12", "n": "Sky Raiders", "d": "They drop in uninvited.",
		"s": "tombstone", "f": ["plain", "sky"], "b": "navy", "c": [["parachute", "white", 0.6, 0, -6], ["lightning", "yellow", 0.34, 0, 20]],
		"t": [["line", "SKY RAIDERS", "navy", 8.5, 44]]},
	{"id": "u13", "n": "Delta Devils", "d": "Fire and the fork, in the paddies.",
		"s": "shield", "f": ["pale", "red", "black"], "b": "yellow", "c": [["flame", "orange", 0.66, 0, 0, 0, "yellow"], ["trident", "black", 0.56, 0, -4]],
		"t": [["scroll", "DELTA DEVILS", "yellow", "black"]]},
	{"id": "u14", "n": "Mud Bulls", "d": "Mechanized infantry, up to the axles.",
		"s": "circle", "f": ["ring", "brown", "tan"], "b": "black", "c": [["bull", "black", 0.56, 0, 0, 0, "maroon"]],
		"t": [["top", "MUD BULLS", "tan"], ["bot", "MECH INF", "tan"]]},
	{"id": "u15", "n": "Paddy Raiders", "d": "Wet feet, every day.",
		"s": "circle", "f": ["ring", "jungle", "khaki"], "b": "khaki", "c": [["rifles", "black", 0.62, 0, 4, 0, "#3a3c3e"], ["palm", "green", 0.44, 0, -2, 0, "brown"]],
		"t": [["top", "PADDY RAIDERS", "khaki"], ["bot", "RIFLE CO", "khaki"]]},
	{"id": "u16", "n": "Hill Fighters", "d": "Took the hill. Took it again.",
		"s": "pentagon", "f": ["plain", "jungle"], "b": "khaki", "c": [["mountain", "khaki", 0.66, 0, -8]],
		"t": [["scroll", "HILL FIGHTERS", "black", "khaki", 96]]},
	{"id": "u17", "n": "Firebase", "d": "Sandbags, guns, and a long night.",
		"s": "square", "f": ["plain", "od"], "b": "khaki", "c": [["castle", "khaki", 0.56, 0, -6]],
		"t": [["line", "FIREBASE", "khaki", 11, 38]]},
	{"id": "u18", "n": "Phantoms", "d": "Recon you never see.",
		"s": "shield", "f": ["plain", "black"], "b": "grey", "c": [["hood", "steel", 0.62, 0, -4], ["skull", "white", 0.26, 0, -3]],
		"t": [["scroll", "PHANTOMS", "black", "grey"]]},
	{"id": "u19", "n": "Reapers", "d": "Assault company. Harvest season.",
		"s": "circle", "f": ["ring", "black", "red"], "b": "white", "c": [["reaper", "black", 0.5, 0, 2, 0, "brown"]],
		"t": [["top", "REAPERS", "white"], ["bot", "ASSAULT CO", "white"]]},
	{"id": "u20", "n": "Lucky Aces", "d": "Dealt from the top of the deck.",
		"s": "spade", "box": [12, 8, 104, 112], "f": ["plain", "black"], "b": "white", "c": [["star", "red", 0.22, 0, 6]], "t": [["line", "ACES", "white", 15, -12]]},
	{"id": "u21", "n": "Blue Thunder", "d": "Lift company: they carry everyone else.",
		"s": "circle", "f": ["ring", "navy", "ultra"], "b": "white", "c": [["lightning", "yellow", 0.62]],
		"t": [["top", "BLUE THUNDER", "white"], ["bot", "AVIATION", "white"]]},
	{"id": "u22", "n": "Warlords", "d": "The crown and the swords: command of the field.",
		"s": "shield", "f": ["quarter", "black", "red"], "b": "yellow", "c": [["swords", "white", 0.5, 0, 6, 0, "yellow"], ["crown", "yellow", 0.34, 0, -22, 0, "red"]],
		"t": [["scroll", "WARLORDS", "black", "yellow"]]},
	{"id": "u23", "n": "Sharks", "d": "Painted teeth on the nose of every gunship.",
		"s": "circle", "f": ["ring", "black", "sky"], "b": "white", "c": [["shark", "grey", 0.62]],
		"t": [["top", "SHARKS", "white"], ["bot", "ATTACK HELO", "white"]]},
	{"id": "u24", "n": "Sidewinders", "d": "Strike fast, strike from the side.",
		"s": "diamond", "f": ["plain", "black"], "b": "yellow", "c": [["cobra", "yellow", 0.66, 0, 0, 0, "black"]]},
	{"id": "u25", "n": "Firestorm", "d": "When they call in the big stuff.",
		"s": "hexagon", "f": ["plain", "black"], "b": "orange", "c": [["flame", "red", 0.74, 0, -4, 0, "orange"], ["bomb", "black", 0.34, -4, 14, 0, "orange"]]},
	{"id": "u26", "n": "Black Cats", "d": "Bad luck, for somebody.",
		"s": "circle", "f": ["ring", "black", "yellow"], "b": "black", "c": [["tiger", "black", 0.56, 0, 0, 0, "lime"]],
		"t": [["top", "BLACK CATS", "yellow"], ["bot", "D TROOP", "yellow"]]},
	{"id": "u27", "n": "Mad Bulls", "d": "Charge first, ask later.",
		"s": "shield2", "f": ["plain", "red"], "b": "black", "c": [["bull", "black", 0.68, 0, -6, 0, "maroon"]],
		"t": [["scroll", "MAD BULLS", "white", "black"]]},
	{"id": "u28", "n": "Iron Eagles", "d": "Steel-grey and sharp-eyed.",
		"s": "shield", "f": ["plain", "steel"], "b": "black", "c": [["eagle", "white", 0.64, 0, -8, 0, "grey"]],
		"t": [["scroll", "IRON EAGLES", "black", "white"]]},
	{"id": "u29", "n": "Bandits", "d": "Recon team. They steal the enemy's secrets.",
		"s": "circle", "f": ["ring", "red", "black"], "b": "white", "c": [["skullbones", "white", 0.58]],
		"t": [["top", "BANDITS", "white"], ["bot", "RECON TEAM", "white"]]},
	{"id": "u30", "n": "Sea Wolves", "d": "Helicopters over the river mouths.",
		"s": "shield2", "f": ["wave", "navy", "blue", "sky"], "b": "white", "c": [["wolf", "white", 0.56, 0, -10, 0, "grey"]]},
	{"id": "u31", "n": "Swamp Foxes", "d": "Scouts. Cunning, quick, and wet.",
		"s": "circle", "f": ["ring", "jungle", "od"], "b": "orange", "c": [["wolf", "orange", 0.56, 0, 0, 0, "black"]],
		"t": [["top", "SWAMP FOXES", "orange"], ["bot", "SCOUTS", "orange"]]},
	{"id": "u32", "n": "Monsoon", "d": "They fight in the rain, because it always rains.",
		"s": "tombstone", "f": ["plain", "steel"], "b": "white", "c": [["waves", "sky", 0.56, 0, 18], ["lightning", "yellow", 0.48, 0, -14]]},
	{"id": "u33", "n": "Hurricane Battery", "d": "Six guns, one storm.",
		"s": "octagon", "f": ["rays", "red", "maroon"], "b": "black", "c": [["cannons", "yellow", 0.68]]},
	{"id": "u34", "n": "Road Runners", "d": "Armoured cavalry: the convoys get through.",
		"s": "shield", "f": ["band", "yellow", "red"], "b": "black", "c": [["horseshoe", "black", 0.56, 0, -6]],
		"t": [["scroll", "ROAD RUNNERS", "black", "yellow"]]},
	{"id": "u35", "n": "Tomahawks", "d": "Strike company. Close and personal.",
		"s": "circle", "f": ["ring", "red", "white"], "b": "black", "c": [["axes", "steel", 0.6, 0, 2, 0, "brown"]],
		"t": [["top", "TOMAHAWKS", "white"], ["bot", "STRIKE CO", "white"]]},
	{"id": "u36", "n": "Diamondbacks", "d": "Rattle before they strike. Sometimes.",
		"s": "diamond", "f": ["chequy", "tan", "brown"], "b": "black", "c": [["cobra", "black", 0.66, 0, 0, 0, "tan"]]},
	{"id": "u37", "n": "Scorpions", "d": "Desert squadron, sting in the tail.",
		"s": "circle", "f": ["ring", "black", "tan"], "b": "tan", "c": [["scorpion", "black", 0.56]],
		"t": [["top", "SCORPIONS", "tan"], ["bot", "DESERT SQN", "tan"]]},
	{"id": "u38", "n": "Bomb Squad", "d": "If you see them running, keep up.",
		"s": "square", "f": ["hstripes", "yellow", "black", 7], "b": "black", "c": [["bomb", "black", 0.64, 2, 0, 0, "red"]]},
	{"id": "u39", "n": "Eyes Forward", "d": "Forward observers: the artillery's eyes.",
		"s": "shield2", "f": ["plain", "black"], "b": "sky", "c": [["eyewings", "sky", 0.94, 0, -6, 0, "#3c6d9c"]],
		"t": [["scroll", "EYES FORWARD", "black", "sky"]]},
	{"id": "u40", "n": "Coalition Armour", "d": "The Coalition's tank battalions.",
		"s": "circle", "f": ["ring", "navy", "coalition"], "b": "white", "c": [["tank", "white", 0.6, 0, 0, 0, "#9fb4d6"]],
		"t": [["top", "COALITION", "white"], ["bot", "ARMOUR", "white"]]},
	{"id": "u41", "n": "Coalition Air Wing", "d": "The Coalition's helicopters: lift, attack, rescue.",
		"s": "shield", "f": ["plain", "coalition"], "b": "white", "c": [["heliwings", "white", 0.92, 0, -6, 0, "#9fb4d6"]],
		"t": [["scroll", "AIR WING", "coalition", "white"]]},
	{"id": "u42", "n": "Rebel Militia", "d": "Farmers by day.",
		"s": "circle", "f": ["ring", "black", "rebel"], "b": "white", "c": [["rifles", "black", 0.66, 0, 4, 0, "#3a3c3e"], ["fist", "white", 0.4, 0, -4]],
		"t": [["top", "MILITIA", "white"], ["bot", "REBELS", "white"]]},
	{"id": "u43", "n": "Technicals", "d": "A pickup truck and a heavy machine gun.",
		"s": "pentagon", "f": ["fess", "sand", "rebel"], "b": "black", "c": [["bullet", "yellow", 0.44, -16, 2, -22, "orange"], ["bullet", "yellow", 0.44, 16, 2, 22, "orange"], ["star", "black", 0.22, 0, -28]]},
	{"id": "u44", "n": "Drone Hunters", "d": "Every FPV drone has a hunter.",
		"s": "circle", "f": ["ring", "black", "od"], "b": "red", "c": [["crosshair", "red", 0.66], ["jet", "black", 0.26]],
		"t": [["top", "DRONE HUNTERS", "red"], ["bot", "AIR DEFENCE", "red"]]},
	{"id": "u45", "n": "Rebel Sappers", "d": "They dig under the town, and leave surprises.",
		"s": "shield2", "f": ["chevron", "black", "rebel"], "b": "yellow", "c": [["bomb", "black", 0.58, 2, -2, 0, "orange"]]},
	{"id": "u46", "n": "Harbor Patrol", "d": "Keeping the port open.",
		"s": "circle", "f": ["ring", "navy", "white"], "b": "white", "c": [["anchor", "navy", 0.56, 0, -2]],
		"t": [["top", "HARBOR PATROL", "white"], ["bot", "NAVAL SQN", "white"]]},
	{"id": "u47", "n": "Bridgehead", "d": "Operation Broken Crossing: take the bridge and hold it.",
		"s": "shield", "f": ["wave", "jungle", "blue", "sky"], "b": "khaki", "c": [["bridge", "khaki", 0.8, 0, -4]],
		"t": [["scroll", "BRIDGEHEAD", "black", "khaki"]]},
	{"id": "u48", "n": "Kingpin", "d": "Operation Silent Gate: one night, one target.",
		"s": "circle", "f": ["ring", "black", "maroon"], "b": "yellow", "c": [["horse", "yellow", 0.5, 0, 4, 0, "black"], ["crown", "yellow", 0.24, 0, -22, 0, "red"]],
		"t": [["top", "KINGPIN", "yellow"], ["bot", "SILENT GATE", "yellow"]]},
	{"id": "u49", "n": "Night Raiders", "d": "In under the moon, out before dawn.",
		"s": "arrowhead", "f": ["plain", "navy"], "b": "white", "c": [["crescent", "yellow", 0.4, -12, -4], ["dagger", "white", 0.5, 8, 12, 30, "grey"]]},
	{"id": "u50", "n": "Last Stand", "d": "Surrounded. Still here.",
		"s": "shield", "f": ["saltire", "black", "red"], "b": "white", "c": [["skullbones", "white", 0.56, 0, -4]],
		"t": [["scroll", "LAST STAND", "white", "black"]]},
]
