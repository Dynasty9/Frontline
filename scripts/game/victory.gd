class_name Victory
extends RefCounted
## How a skirmish is won, on the server. A side is beaten when it has no base
## left (every FOB taken, or wrecked and left in ruins), or when its resolve
## runs out.
##
## Resolve is the side's will to go on, as its high command counts it: it
## starts at START, and drains away while the enemy holds more of the ground
## that matters (the town, the villages, working FOBs) and with every man and
## vehicle lost. A side that sits behind its wire while the other takes the
## villages loses; so does one that throws its army away. The longer the
## battle drags on, the faster the drain (the ramp); and from the twentieth
## minute both sides tire of it (weariness, growing by the minute), so one that
## is even all the way through is still decided before half an hour, against
## whichever side has less left. Missions have their
## own ends and never use it.

const START := 600.0
const BLEED_FROM := 180.0  # (the first three minutes: both sides are still coming up)
const RATE := 0.13  # resolve a second for each point of ground the enemy holds more than us
const RAMP_FROM := 900.0  # from the quarter hour the drain speeds up...
const RAMP_PER := 300.0  # ...by its own rate again every five minutes
const WEARY_FROM := 1200.0  # from the twentieth minute both sides lose resolve...
const WEARY_PER := 240.0  # ...a point a second more for every four minutes past it
const MAN_VALUE := 20.0  # a man (20 supply's worth) lost costs one point; a vehicle its cost / 20
const FOB_LOST := 25.0
const WRECK_GRACE := 120.0  # a wrecked FOB still counts as a base this long, for its engineers
const LOW := 150.0  # the side is warned when it falls this low

## What each holding is worth: the town, a village, a working FOB.
const TOWN_PTS := 3
const VILLAGE_PTS := 1
const FOB_PTS := 1

var world: World
var points: Array = [START, START]
var held: Array = [0, 0]  # what each side's ground is worth now
var bleed: Array = [0.0, 0.0]  # the drain a second each side is under now
var on := true  # off: the old rule, every enemy FOB taken (the lobby's "victory" setting)
var _lost_val: Array = [0.0, 0.0]  # casualties already counted against resolve
var _warned: Array = [false, false]
var _wrecked_at := {}  # FOB eid -> when it was wrecked
var bleed_from := BLEED_FROM
var wreck_grace := WRECK_GRACE


func _init(w: World) -> void:
	world = w
	# (a test scenario is a set-piece fight, not a battle to be won on points)
	on = String(w.settings.get("victory", "resolve")) != "fobs" and String(w.settings.get("scenario", "")) == ""
	bleed_from = float(w.settings.get("victory_from", BLEED_FROM))
	wreck_grace = float(w.settings.get("victory_grace", WRECK_GRACE))


## Has either side no base left? (Then it has lost.) True if the battle is over.
func check_bases() -> bool:
	if world.winner >= 0 or world.mission != null or world.time < 10.0:
		return world.winner >= 0
	var bases := [0, 0]
	for t in 2:
		for f in world.rules.fobs(t):
			if f.wrecked:
				if not _wrecked_at.has(f.eid):
					_wrecked_at[f.eid] = world.time
				if world.time - float(_wrecked_at[f.eid]) > wreck_grace:
					continue
			else:
				_wrecked_at.erase(f.eid)
			bases[t] += 1
	for t in 2:
		if bases[t] == 0:
			world.stat("victory_no_base")
			world.declare_winner(1 - t)
			return true
	return false


## Once a second.
func tick() -> void:
	if check_bases() or not on or world.mission != null or world.time < 10.0:
		return
	for t in 2:
		held[t] = ground(t)
	var ramp := 1.0 + maxf(0.0, world.time - RAMP_FROM) / RAMP_PER
	for t in 2:
		var b := 0.0
		if world.time >= bleed_from:
			b = maxi(0, held[1 - t] - held[t]) * RATE * ramp
		b += maxf(0.0, world.time - WEARY_FROM) / WEARY_PER
		bleed[t] = b
		var val: float = float(world.battle.sides[t].val_lost) if world.battle else 0.0
		var cas := (val - float(_lost_val[t])) / MAN_VALUE
		_lost_val[t] = val
		points[t] = maxf(0.0, float(points[t]) - b - cas)
		if not _warned[t] and points[t] < LOW:
			_warned[t] = true
			world.send_msg(t, "alert", "Our resolve is failing (%d). Take ground back or the battle is lost." % int(points[t]))
			world.send_msg(1 - t, "info", "The enemy is close to breaking. Keep up the pressure.")
	if points[0] <= 0.0 or points[1] <= 0.0:
		world.stat("victory_resolve")
		world.declare_winner(0 if points[0] > points[1] else 1)


## What the ground a side holds is worth.
func ground(t: int) -> int:
	var n := 0
	for tn in world.rules.towns(t):
		n += TOWN_PTS if tn.variant == 1 else VILLAGE_PTS
	for f in world.rules.fobs(t, false):
		n += FOB_PTS
	return n


## A FOB taken: a blow to the side that lost it.
func fob_lost(t: int) -> void:
	if on and t >= 0 and t <= 1:
		points[t] = maxf(0.0, float(points[t]) - FOB_LOST)


## For the status line: [resolve 0, resolve 1, drain on 0, drain on 1] (whole numbers and tenths).
func info() -> Array:
	if not on or world.mission != null:
		return []
	return [int(ceil(float(points[0]))), int(ceil(float(points[1]))), snappedf(float(bleed[0]), 0.1), snappedf(float(bleed[1]), 0.1)]
