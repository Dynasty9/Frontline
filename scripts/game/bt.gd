class_name BT
extends RefCounted
## A small behaviour tree. A tree is built once out of composites and leaves
## and shared by every agent; each think walks it from the root for one agent.
## Leaves are functions of the agent: a condition returns a bool, an action
## returns OK, FAIL or RUN. Whatever an agent is in the middle of (a dive, a
## throw, a task) he carries himself between thinks: the tree decides, his own
## tick carries it out. The leaf that acted is left in the agent's bt_path
## (what he's doing and why, for the debug view and the stats).

enum {FAIL, OK, RUN}


class Branch extends RefCounted:
	var label := ""

	func tick(_a: Object) -> int:
		return FAIL


## Tries each child in priority order: the first that doesn't fail wins.
class Sel extends Branch:
	var kids: Array = []

	func _init(l: String, k: Array) -> void:
		label = l
		kids = k

	func tick(a: Object) -> int:
		for k in kids:
			var r: int = k.tick(a)
			if r != FAIL:
				return r
		return FAIL


## Each child in turn, as long as they succeed.
class Seq extends Branch:
	var kids: Array = []

	func _init(l: String, k: Array) -> void:
		label = l
		kids = k

	func tick(a: Object) -> int:
		for k in kids:
			var r: int = k.tick(a)
			if r != OK:
				return r
		return OK


## A question about the agent (f(agent) -> bool).
class Cond extends Branch:
	var f: Callable

	func _init(l: String, fn: Callable) -> void:
		label = l
		f = fn

	func tick(a: Object) -> int:
		return OK if f.call(a) else FAIL


## Something the agent does (f(agent) -> FAIL, OK or RUN).
class Do extends Branch:
	var f: Callable

	func _init(l: String, fn: Callable) -> void:
		label = l
		f = fn

	func tick(a: Object) -> int:
		var r: int = f.call(a)
		if r != FAIL:
			a.bt_path = label
		return r


## The child, whatever it returns, counts as done.
class Always extends Branch:
	var kid: Branch

	func _init(k: Branch) -> void:
		kid = k
		label = k.label

	func tick(a: Object) -> int:
		kid.tick(a)
		return OK


## The child gets a turn at most once every t seconds per agent (once it has
## acted: a failed try doesn't start the clock).
class Cooldown extends Branch:
	var kid: Branch
	var t := 1.0
	var key: StringName

	func _init(secs: float, k: Branch) -> void:
		t = secs
		kid = k
		label = k.label
		key = StringName("cd_" + k.label)

	func tick(a: Object) -> int:
		if a.world.time < float(a.bt_cd.get(key, -1e9)):
			return FAIL
		var r: int = kid.tick(a)
		if r != FAIL:
			a.bt_cd[key] = a.world.time + t
		return r


static func sel(l: String, kids: Array) -> Branch:
	return Sel.new(l, kids)


static func seq(l: String, kids: Array) -> Branch:
	return Seq.new(l, kids)


static func cond(l: String, fn: Callable) -> Branch:
	return Cond.new(l, fn)


static func act(l: String, fn: Callable) -> Branch:
	return Do.new(l, fn)


static func always(k: Branch) -> Branch:
	return Always.new(k)


static func cooldown(secs: float, k: Branch) -> Branch:
	return Cooldown.new(secs, k)


## The tree as indented text (the Field Manual and debugging).
static func describe(n: Branch, depth := 0) -> String:
	var pad := "  ".repeat(depth)
	var kind := "?"
	if n is Sel:
		kind = "?"
	elif n is Seq:
		kind = "->"
	elif n is Cond:
		kind = "if"
	elif n is Do:
		kind = "do"
	elif n is Always:
		kind = "always"
	elif n is Cooldown:
		kind = "every %.0fs" % (n as Cooldown).t
	var s := "%s%s %s\n" % [pad, kind, n.label]
	if n is Sel or n is Seq:
		for k in n.kids:
			s += describe(k, depth + 1)
	elif n is Always:
		s += describe((n as Always).kid, depth + 1)
	elif n is Cooldown:
		s += describe((n as Cooldown).kid, depth + 1)
	return s
