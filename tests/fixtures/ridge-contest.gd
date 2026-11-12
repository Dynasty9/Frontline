extends RefCounted
## Two independent drivers play a ridge-control game. Relay posts spend a charge,
## supply posts refill it, and a forward objective can decide a close contest.
## Positions here are local to each ridge, with +X towards the valley.

enum Post { SUPPLY_LEFT, SUPPLY_RIGHT, RELAY_LEFT, RELAY_RIGHT, OBJECTIVE }
const POSTS := [Vector2(-10, -5), Vector2(-9, 5), Vector2(1, -4), Vector2(-1, 5), Vector2(13, 1)]
const GAP := 140.0
const RIDGE := 40.0

class Driver:
	var rng := RandomNumberGenerator.new()
	var post := -1
	var sites: Array[Vector2] = []
	var charge := true
	var claims := 0
	var supplies := 0
	var visits := PackedInt32Array([0, 0, 0, 0, 0])
	var hold := 0.0
	var patience := 1.0
	var advance := false
	var seen_rival_claims := -1

	func choose(at: Vector2, rival_claims: int) -> void:
		seen_rival_claims = rival_claims
		var best := -INF
		for j in sites.size():
			var supply := j <= Post.SUPPLY_RIGHT
			if supply == charge:
				continue
			if j == Post.OBJECTIVE and (claims < 1 or maxi(claims, rival_claims) < 2):
				continue
			var utility := -at.distance_to(sites[j]) - visits[j] * 8.0 + rng.randf_range(-4.0, 4.0)
			if j == Post.OBJECTIVE:
				utility += 15.0 + 6.0 * rival_claims
			if utility > best:
				best = utility
				post = j
		advance = post == Post.OBJECTIVE
		patience = rng.randf_range(3.65, 4.25)
		hold = 0.0

var drivers: Array[Driver] = []
var winner := -1
var actions := 0

func _init(seed_value: int) -> void:
	for i in 2:
		var driver := Driver.new()
		driver.rng.seed = seed_value * 97 + i * 763 + 1
		for site: Vector2 in POSTS:
			driver.sites.append(site + Vector2(driver.rng.randf_range(-1.8, 1.8), driver.rng.randf_range(-2.5, 2.5)))
		driver.choose(Vector2(-18, 0), 0)
		drivers.append(driver)

static func position_of(i: int, local: Vector2) -> Vector3:
	var sign_x := 1.0 if i == 0 else -1.0
	return Vector3(sign_x * (local.x - RIDGE - GAP), 0, sign_x * (local.y - 2.0))

static func local_of(i: int, p: Vector3) -> Vector2:
	var sign_x := 1.0 if i == 0 else -1.0
	return Vector2(RIDGE + GAP + sign_x * p.x, 2.0 + sign_x * p.z)

func destination(i: int) -> Vector3:
	return position_of(i, drivers[i].sites[drivers[i].post])

## The decision is a function of current possession and position. A changed
## rival score can make a driver abandon an ordinary relay for the final post.
func step(i: int, at: Vector3, speed: float, dt: float) -> int:
	if winner >= 0:
		return -1
	var driver := drivers[i]
	var rival := drivers[1 - i]
	var local := local_of(i, at)
	if driver.charge and driver.claims >= 1 and rival.claims >= 2 and rival.claims != driver.seen_rival_claims and not driver.advance:
		driver.choose(local, rival.claims)
	if local.distance_to(driver.sites[driver.post]) > 1.45 or absf(speed) > 1.1:
		driver.hold = 0.0
		return -1
	driver.hold += dt
	if driver.hold < driver.patience:
		return -1
	var completed := driver.post
	driver.visits[completed] += 1
	if completed <= Post.SUPPLY_RIGHT:
		driver.supplies += 1
		driver.charge = true
	else:
		driver.claims += 1
		driver.charge = false
		actions += 1
	if completed == Post.OBJECTIVE:
		winner = i
	else:
		driver.choose(local, rival.claims)
	return completed
