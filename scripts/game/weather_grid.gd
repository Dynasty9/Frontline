class_name WeatherGrid
extends RefCounted
## (view) What hangs in the air over each part of the battlefield: mist, rain,
## dust and smoke, on a coarse grid laid over the map, so the atmosphere varies
## from place to place instead of being one value for the whole battle. Mist
## lies in the hollows and along the water, thickest at dawn and after rain;
## the rain comes over in heavier and lighter bands; a column of vehicles on a
## dry road and every shell that lands on dry ground raise dust; a barrage, a
## burning house or a smoke screen leave a pall that drifts off downwind and
## thins away. All of it drifts with the wind (Fires.WIND, the way the smoke
## and the clouds go).
##
## AirLayers draws it (a fog volume's density and colour, or under the browser's
## renderer the plain fog at the camera's focus). It is looks only: who can see
## whom is the host's business, through the smoke it simulates itself
## (Combat.smoke_blocks), so this runs on every peer from what each already
## has (the mood, the rain's wetness, the replicated fires, smoke rounds and
## vehicles, and the blasts' effect events) and never draws on world.rng.
##
## The grid moves with the wind rather than the wind moving through it: the
## cells drift by a sub-cell offset the shaders sample with, and the whole grid
## shifts a cell downwind once the offset reaches one (upwind, fresh air comes
## in). So there's no numerical smearing and no per-cell advection to work out.
## The cells are swept a few rows a frame (SWEEP_FRAMES for the lot), and the
## texture goes up once a sweep.

const MIST := 0
const RAIN := 1
const DUST := 2
const SMOKE := 3
## How fast the air near the ground drifts with the wind (m/s): slower than the
## clouds above (CloudShadow.SPEED).
const DRIFT := 2.2
## Frames a sweep of the whole grid is spread over.
const SWEEP_FRAMES := 10
## Half-lives (s) of what isn't topped up: dust settles quickly, smoke hangs.
const DUST_LIFE := 22.0
const SMOKE_LIFE := 55.0
## How quickly mist and rain settle toward what the weather and the ground
## make of each cell (s).
const MIST_RATE := 30.0
const RAIN_RATE := 12.0
## How much of each cell's dust and smoke spreads into its neighbours a second.
const SPREAD := 0.05

## What each mood brings: [mist over flat ground, mist in the hollows and
## along the water, rain, background dust].
const MOOD_AIR := {
	"day": [0.03, 0.14, 0.0, 0.04],
	"golden": [0.06, 0.3, 0.0, 0.06],
	"dawn": [0.2, 0.95, 0.0, 0.0],
	"dusk": [0.1, 0.45, 0.0, 0.04],
	"overcast": [0.14, 0.4, 0.0, 0.0],
	"night": [0.12, 0.6, 0.0, 0.0],
	"rain": [0.2, 0.45, 0.85, 0.0],
	"hazy": [0.08, 0.25, 0.0, 0.32],
}

var world
var n := 32  # cells across
var cell := 32.0  # metres a cell
var tex: ImageTexture  # RGBA: mist, rain, dust, smoke (0..1)
## The grid's sub-cell drift (m), for the shaders: a cell's content sits this
## far downwind of its own square.
var drift := Vector2.ZERO
var mood := "golden"
var wet := 0.0  # how soaked the ground is (Atmosphere.rain_wet): after rain, mist rises off it

var surveyed := false  # the hollows and the water have been found (survey)
var _c: Array[PackedFloat32Array] = []  # per channel, n * n
var _low := PackedFloat32Array()  # per cell: how much of a hollow it is, or how close to water (0..1)
var _bytes := PackedByteArray()
var _img: Image
var _wind := Vector2.ONE
var _air_t := 0.0  # total drift (m) along the wind, for the rain's bands
var _row := 0  # the next row the sweep does
var _sweep_dt := 0.0  # the time the sweep under way covers
var _src_t := 0.0


func _init(w) -> void:
	world = w
	n = clampi(int(MapDims.SIZE / 32.0), 32, 64)
	cell = MapDims.SIZE / n
	_wind = Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	for i in 4:
		var a := PackedFloat32Array()
		a.resize(n * n)
		_c.append(a)
	_low.resize(n * n)
	_bytes.resize(n * n * 4)
	_img = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, _bytes)
	tex = ImageTexture.create_from_image(_img)


## Where the mist gathers: the hollows (lower than the ground round about) and
## the water's edge. From the ground as it is now (call again if it changes a
## lot); starts each cell at what the weather makes of it.
func survey() -> void:
	surveyed = true
	var h := PackedFloat32Array()
	h.resize(n * n)
	var half := MapDims.HALF
	for z in n:
		for x in n:
			h[z * n + x] = world.ground_y(Vector3(-half + (x + 0.5) * cell, 0.0, -half + (z + 0.5) * cell))
	var mask: Image = world.water.mask if world.water and not world.water.is_empty() else null
	var ms := mask.get_width() if mask else 0
	for z in n:
		for x in n:
			# the mean of the ground two cells round: a cell well below it is a hollow
			var sum := 0.0
			var cnt := 0
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var xx := clampi(x + dx, 0, n - 1)
					var zz := clampi(z + dz, 0, n - 1)
					sum += h[zz * n + xx]
					cnt += 1
			var low := clampf((sum / cnt - h[z * n + x]) / 12.0, 0.0, 1.0)
			if ms > 0:
				# water anywhere in the cell or just beside it
				var wetc := 0.0
				for k in 9:
					var px := clampi(int((x + (k % 3) * 0.5 - 0.25) * ms / n), 0, ms - 1)
					var pz := clampi(int((z + (k / 3) * 0.5 - 0.25) * ms / n), 0, ms - 1)
					wetc += mask.get_pixel(px, pz).a
				low = maxf(low, minf(1.0, wetc / 4.0))
			_low[z * n + x] = low
	for i in n * n:
		var t := _targets(i % n, i / n)
		_c[MIST][i] = t.x
		_c[RAIN][i] = t.y
		_c[DUST][i] = t.z
	_upload_all()


## What the weather and the ground make of cell (x, z): mist, rain, dust.
func _targets(x: int, z: int) -> Vector3:
	var a: Array = MOOD_AIR.get(mood, MOOD_AIR.day)
	var low := _low[z * n + x]
	# (wet ground steams once the rain has passed: mist off it as it dries)
	var mist := lerpf(float(a[0]), float(a[1]), low) + wet * 0.25 * (0.4 + 0.6 * low) * (1.0 if mood != "rain" else 0.3)
	var rain := float(a[2])
	if rain > 0.0:
		# showers in bands across the wind, drifting over with it
		var u := (x + 0.5) * cell * _wind.x + (z + 0.5) * cell * _wind.y - _air_t
		var v := -(x + 0.5) * cell * _wind.y + (z + 0.5) * cell * _wind.x
		var band := 0.5 + 0.3 * sin(u * 0.011) + 0.2 * sin(u * 0.027 + v * 0.006 + 1.7)
		rain *= lerpf(0.45, 1.15, clampf(band, 0.0, 1.0))
	return Vector3(mist, rain, float(a[3]) * (1.0 - wet))


## The air at a point (bilinear between the cells, with the drift): mist,
## rain, dust, smoke.
func sample(p: Vector3) -> Vector4:
	var fx := (p.x - drift.x + MapDims.HALF) / cell - 0.5
	var fz := (p.z - drift.y + MapDims.HALF) / cell - 0.5
	var x0 := clampi(floori(fx), 0, n - 1)
	var z0 := clampi(floori(fz), 0, n - 1)
	var x1 := mini(x0 + 1, n - 1)
	var z1 := mini(z0 + 1, n - 1)
	var tx := clampf(fx - x0, 0.0, 1.0)
	var tz := clampf(fz - z0, 0.0, 1.0)
	var out := Vector4.ZERO
	for ch in 4:
		var c: PackedFloat32Array = _c[ch]
		var a := lerpf(c[z0 * n + x0], c[z0 * n + x1], tx)
		var b := lerpf(c[z1 * n + x0], c[z1 * n + x1], tx)
		out[ch] = lerpf(a, b, tz)
	return out


## Puts `amount` of a channel into the air round p, over `radius` metres.
func add(ch: int, p: Vector3, amount: float, radius := 0.0) -> void:
	var fx := (p.x - drift.x + MapDims.HALF) / cell - 0.5
	var fz := (p.z - drift.y + MapDims.HALF) / cell - 0.5
	var r := maxf(radius / cell, 0.5)
	var c: PackedFloat32Array = _c[ch]
	for z in range(maxi(0, floori(fz - r)), mini(n, ceili(fz + r) + 1)):
		for x in range(maxi(0, floori(fx - r)), mini(n, ceili(fx + r) + 1)):
			var d := Vector2(x - fx, z - fz).length() / (r + 0.5)
			if d < 1.0:
				var i := z * n + x
				c[i] = minf(1.0, c[i] + amount * (1.0 - d * d))


## A blast: smoke, and dust where it threw up dry ground (fx.gd's _explode).
## size as an effect event's (a grenade ~0.6, a heavy shell 2-3); wet: in the
## water, where it throws up spray that falls back rather than dust.
func blast(p: Vector3, size: float, wet_ground: bool, above_ground: float) -> void:
	if above_ground > 25.0:
		add(SMOKE, p, 0.05 * size, 6.0 * size)  # (an airburst: a puff high up)
		return
	add(SMOKE, p, 0.14 * size, 5.0 + 5.0 * size)
	if wet_ground:
		add(MIST, p, 0.08 * size, 4.0 + 3.0 * size)
	else:
		add(DUST, p, 0.1 * size * (1.0 - 0.8 * wet), 5.0 + 5.0 * size)


## A frame: the drift, sources, and a few rows of the sweep.
func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	var step := _wind * DRIFT * dt
	_air_t += DRIFT * dt
	drift += step
	_shift()
	_sweep_dt += dt
	_src_t -= dt
	if _src_t <= 0.0:
		_src_t = 0.5
		_sources(0.5)
	var rows := ceili(float(n) / SWEEP_FRAMES)
	for z in range(_row, mini(n, _row + rows)):
		_sweep_row(z, _sweep_dt)
	_row += rows
	if _row >= n:
		_row = 0
		_sweep_dt = 0.0
		_upload_all()


## Moves the grid a cell downwind once the drift reaches one.
func _shift() -> void:
	while drift.x >= cell:
		drift.x -= cell
		for ch in 4:
			var c: PackedFloat32Array = _c[ch]
			for z in n:
				var r := z * n
				for x in range(n - 1, 0, -1):
					c[r + x] = c[r + x - 1]
				c[r] = _fresh(ch, 0, z)
	while drift.x <= -cell:
		drift.x += cell
		for ch in 4:
			var c: PackedFloat32Array = _c[ch]
			for z in n:
				var r := z * n
				for x in n - 1:
					c[r + x] = c[r + x + 1]
				c[r + n - 1] = _fresh(ch, n - 1, z)
	while drift.y >= cell:
		drift.y -= cell
		for ch in 4:
			var c: PackedFloat32Array = _c[ch]
			var moved := c.slice(0, n * (n - 1))
			for x in n:
				c[x] = _fresh(ch, x, 0)
			for i in moved.size():
				c[n + i] = moved[i]
	while drift.y <= -cell:
		drift.y += cell
		for ch in 4:
			var c: PackedFloat32Array = _c[ch]
			for i in n * (n - 1):
				c[i] = c[i + n]
			for x in n:
				c[(n - 1) * n + x] = _fresh(ch, x, n - 1)


## The air coming in upwind: what the weather makes of the edge cell.
func _fresh(ch: int, x: int, z: int) -> float:
	if ch == SMOKE:
		return 0.0
	return _targets(x, z)[ch]


## What's alight, smoking or driving about: fires (Vfx's burners), smoke
## rounds' screens, and vehicles raising dust off dry ground. All of it is
## replicated (or drawn) on every peer.
func _sources(dt: float) -> void:
	if world.fx and world.fx.vfx:
		for b in world.fx.vfx.fire_sources():
			add(SMOKE, b[0], 0.05 * float(b[1]) * dt, 10.0 + 6.0 * float(b[1]))
	for p in world.smoke_projectiles:
		if is_instance_valid(p) and p.smoke_r > 0.8:
			add(SMOKE, p.position, 0.06 * dt * p.smoke_r / 6.5, p.smoke_r * 1.6)
	if wet > 0.6 or mood == "rain":
		return
	for v in world.vehicles:
		if not is_instance_valid(v) or v.is_air() or v.is_boat() or v.speed < 4.0:
			continue
		add(DUST, v.position, 0.012 * dt * minf(v.speed, 18.0) * (1.0 - wet), 9.0)


## One row of the sweep: mist and rain settle toward the weather's, dust and
## smoke thin away and spread a little into their neighbours.
func _sweep_row(z: int, dt: float) -> void:
	var km := 1.0 - exp(-dt / MIST_RATE)
	var kr := 1.0 - exp(-dt / RAIN_RATE)
	var kd := pow(0.5, dt / DUST_LIFE)
	var ks := pow(0.5, dt / SMOKE_LIFE)
	var sp := minf(0.2, SPREAD * dt)
	var mist := _c[MIST]
	var rain := _c[RAIN]
	var dust := _c[DUST]
	var smoke := _c[SMOKE]
	var zu := maxi(z - 1, 0) * n
	var zd := mini(z + 1, n - 1) * n
	var r := z * n
	for x in n:
		var i := r + x
		var t := _targets(x, z)
		mist[i] += (t.x - mist[i]) * km
		rain[i] += (t.y - rain[i]) * kr
		var xl := r + maxi(x - 1, 0)
		var xr := r + mini(x + 1, n - 1)
		var dn := (dust[xl] + dust[xr] + dust[zu + x] + dust[zd + x]) * 0.25
		var sn := (smoke[xl] + smoke[xr] + smoke[zu + x] + smoke[zd + x]) * 0.25
		var d := lerpf(dust[i], dn, sp) * kd
		dust[i] = d + (t.z - d) * (1.0 - kd)
		smoke[i] = lerpf(smoke[i], sn, sp) * ks


func _upload_all() -> void:
	var mist := _c[MIST]
	var rain := _c[RAIN]
	var dust := _c[DUST]
	var smoke := _c[SMOKE]
	for i in n * n:
		var o := i * 4
		_bytes[o] = int(clampf(mist[i], 0.0, 1.0) * 255.0)
		_bytes[o + 1] = int(clampf(rain[i], 0.0, 1.0) * 255.0)
		_bytes[o + 2] = int(clampf(dust[i], 0.0, 1.0) * 255.0)
		_bytes[o + 3] = int(clampf(smoke[i], 0.0, 1.0) * 255.0)
	_img.set_data(n, n, false, Image.FORMAT_RGBA8, _bytes)
	tex.update(_img)


## How much of the map's air is in each channel (for --stats and the tests).
func totals() -> Vector4:
	var out := Vector4.ZERO
	for ch in 4:
		var s := 0.0
		for v in _c[ch]:
			s += v
		out[ch] = s / (n * n)
	return out
