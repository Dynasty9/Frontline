class_name Landform
extends RefCounted
## Broad geology is immutable; shell holes remain in TerrainMap's finer grid.
## Roads and settlements occupy graded valley floors, with talus and ridges above.

const STEP := 4.0
var n: int
var half: float
var heights := PackedFloat32Array()
var reserve := PackedFloat32Array()
var peak := 0.0


static func valid(data: Variant, size: int) -> bool:
	if not data is PackedFloat32Array:
		return false
	if data.is_empty():
		return true
	var width := int(size / STEP) + 1
	if data.size() != width * width:
		return false
	for h in data:
		if not is_finite(h) or h < 0.0 or h > 512.0:
			return false
	return true


func _init(size: int) -> void:
	n = int(size / STEP) + 1
	half = size * 0.5


func generate(seed_value: int, roads: Array, water, settlements: Array) -> void:
	heights.resize(n * n)
	reserve.resize(n * n)
	reserve.fill(1.0)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 701
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0028
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 7
	noise.fractal_gain = 0.55
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 75.0
	noise.domain_warp_frequency = 0.004
	var amplitude := minf(half * 0.45, 300.0)
	for z in n:
		for x in n:
			var wx := x * STEP - half
			var wz := z * STEP - half
			var ridge := clampf((noise.get_noise_2d(wx, wz) + 1.0) * 0.5, 0.0, 1.0)
			# A broad mountain belt, not a field of unrelated cones.
			var belt := 0.55 + 0.45 * sin(wx / half * 3.1 + sin(wz / half * 2.6 + seed_value * 0.1))
			heights[z * n + x] = amplitude * pow(ridge, 1.8) * belt
	# Thermal weathering moves loose material down the steepest face, conserving volume.
	for iteration in 6:
		var delta := PackedFloat32Array()
		delta.resize(heights.size())
		for z in range(1, n - 1):
			for x in range(1, n - 1):
				var i := z * n + x
				var low := i
				for j in [i - 1, i + 1, i - n, i + n]:
					if heights[j] < heights[low]:
						low = j
				var amount := maxf(0.0, heights[i] - heights[low] - STEP * 0.8) * 0.22
				delta[i] -= amount
				delta[low] += amount
		for i in heights.size():
			heights[i] += delta[i]
	for group in roads:
		for path in group:
			reserve_path(path, 15.0, 110.0)
	for river in water.rivers:
		reserve_path(river.pts, float(river.w) * 0.5 + 18.0, 125.0)
	for pond in water.ponds:
		reserve_disc(pond.c, float(pond.r) + 12.0, 45.0)
	for site in settlements:
		reserve_disc(site[0], site[1], 100.0)
	for z in n:
		for x in n:
			var i := z * n + x
			var wx := x * STEP - half
			var wz := z * STEP - half
			var coast := 1.0 if water.coast.is_empty() else smoothstep(0.0, 85.0, water.coast_x(wz) - wx - 18.0)
			# Blend the boundary into the distant ground ring without a vertical seam.
			var edge := smoothstep(0.0, 36.0, half - maxf(absf(wx), absf(wz)))
			heights[i] *= reserve[i] * coast * edge
	# Rain cuts branching gullies and deposits scree at their feet. Do not clamp
	# every face to one angle: that turns ridges into artificial pyramids.
	_erode(seed_value + 1093)
	peak = 0.0
	for h in heights:
		peak = maxf(peak, h)
	reserve = PackedFloat32Array()


func _sample(p: Vector2) -> Vector3:
	var x := clampi(int(p.x), 0, n - 2)
	var z := clampi(int(p.y), 0, n - 2)
	var fx := p.x - x
	var fz := p.y - z
	var i := z * n + x
	var a := heights[i]
	var b := heights[i + 1]
	var c := heights[i + n]
	var d := heights[i + n + 1]
	return Vector3(lerpf(b - a, d - c, fz), lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz), lerpf(c - a, d - b, fx))


func _deposit(p: Vector2, amount: float) -> void:
	var x := int(p.x)
	var z := int(p.y)
	var fx := p.x - x
	var fz := p.y - z
	var i := z * n + x
	heights[i] += amount * (1.0 - fx) * (1.0 - fz) * reserve[i]
	heights[i + 1] += amount * fx * (1.0 - fz) * reserve[i + 1]
	heights[i + n] += amount * (1.0 - fx) * fz * reserve[i + n]
	heights[i + n + 1] += amount * fx * fz * reserve[i + n + 1]


func _erode(seed_value: int) -> void:
	var rain := RandomNumberGenerator.new()
	rain.seed = seed_value
	var offsets: Array[Vector2i] = []
	var weights := PackedFloat32Array()
	var total := 0.0
	for z in range(-2, 3):
		for x in range(-2, 3):
			var weight := maxf(0.0, 2.5 - Vector2(x, z).length())
			if weight > 0.0:
				offsets.append(Vector2i(x, z))
				weights.append(weight)
				total += weight
	for i in weights.size():
		weights[i] /= total
	for drop in int(n * n * 0.5):
		var p := Vector2(rain.randf_range(3.0, n - 4.0), rain.randf_range(3.0, n - 4.0))
		var direction := Vector2.ZERO
		var speed := 1.0
		var water := 1.0
		var sediment := 0.0
		for age in 45:
			var old := _sample(p)
			direction = direction * 0.25 - Vector2(old.x, old.z) * 0.75
			if direction.length_squared() < 0.000001:
				break
			direction = direction.normalized()
			var next := p + direction
			if next.x < 3.0 or next.y < 3.0 or next.x >= n - 4.0 or next.y >= n - 4.0:
				break
			var delta := _sample(next).y - old.y
			var capacity := maxf(-delta, 0.02) * speed * water * 3.0
			if sediment > capacity or delta > 0.0:
				var deposit := minf(delta, sediment) if delta > 0.0 else (sediment - capacity) * 0.3
				_deposit(p, deposit)
				sediment -= deposit
			else:
				var amount := minf((capacity - sediment) * 0.24, -delta)
				var cell := Vector2i(p)
				for j in offsets.size():
					var q := cell + offsets[j]
					var i := q.y * n + q.x
					var removed := minf(heights[i], amount * weights[j]) * reserve[i]
					heights[i] -= removed
					sediment += removed
			speed = sqrt(maxf(0.01, speed * speed - delta * 0.4))
			water *= 0.97
			p = next


func reserve_path(points: PackedVector3Array, width: float, blend: float) -> void:
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(1, ceili(Defs.flat(b - a).length() / (STEP * 2.0)))
		for j in steps + 1:
			reserve_disc(a.lerp(b, float(j) / steps), width, blend)


func reserve_disc(p: Vector3, radius: float, blend: float) -> void:
	var reach := radius + blend
	var lo := Vector2i(floori((p.x - reach + half) / STEP), floori((p.z - reach + half) / STEP)).clamp(Vector2i.ZERO, Vector2i.ONE * (n - 1))
	var hi := Vector2i(ceili((p.x + reach + half) / STEP), ceili((p.z + reach + half) / STEP)).clamp(Vector2i.ZERO, Vector2i.ONE * (n - 1))
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var d := Vector2(x * STEP - half - p.x, z * STEP - half - p.z).length()
			var i := z * n + x
			reserve[i] = minf(reserve[i], smoothstep(radius, reach, d))


func height(p: Vector3) -> float:
	if heights.is_empty():
		return 0.0
	var fx := clampf((p.x + half) / STEP, 0.0, n - 1.0)
	var fz := clampf((p.z + half) / STEP, 0.0, n - 1.0)
	var x := mini(int(fx), n - 2)
	var z := mini(int(fz), n - 2)
	var i := z * n + x
	return lerpf(lerpf(heights[i], heights[i + 1], fx - x), lerpf(heights[i + n], heights[i + n + 1], fx - x), fz - z)


func slope(p: Vector3) -> float:
	return Vector2(height(p + Vector3.RIGHT * 2.0) - height(p - Vector3.RIGHT * 2.0), height(p + Vector3.BACK * 2.0) - height(p - Vector3.BACK * 2.0)).length() * 0.25


func fits(p: Vector3, footprint: Vector2, yaw: float, tolerance := 0.35) -> bool:
	var basis := Basis(Vector3.UP, yaw)
	var h := height(p)
	for z in [-1.0, 0.0, 1.0]:
		for x in [-1.0, 0.0, 1.0]:
			if absf(height(p + basis * Vector3(x * footprint.x, 0, z * footprint.y)) - h) > tolerance:
				return false
	return true


## Bake sky visibility, concavity and distant sun occlusion; crater normals stay live.
func bake_surface(sun_direction := Vector3.UP) -> Image:
	var size := ceili(half * 2.0 / 8.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var toward_sun := Vector3(sun_direction.x, 0, sun_direction.z)
	var sun_slope := sun_direction.y / maxf(toward_sun.length(), 0.001)
	toward_sun = toward_sun.normalized()
	var directions: Array[Vector3] = []
	for i in 8:
		directions.append(Vector3(cos(i * TAU / 8.0), 0, sin(i * TAU / 8.0)))
	for z in size:
		for x in size:
			var p := Vector3((x + 0.5) * 8.0 - half, 0, (z + 0.5) * 8.0 - half)
			var h := height(p)
			var occlusion := 0.0
			var basin := 0.0
			for direction in directions:
				var horizon := 0.0
				for distance in [8.0, 16.0, 32.0, 64.0, 128.0]:
					var rise := height(p + direction * distance) - h
					horizon = maxf(horizon, rise / distance)
					if distance == 16.0:
						basin += rise
				occlusion += horizon / sqrt(1.0 + horizon * horizon)
			var sun_horizon := 0.0
			for distance in [8.0, 16.0, 32.0, 48.0, 64.0, 96.0, 128.0, 192.0, 256.0, 384.0, 512.0]:
				sun_horizon = maxf(sun_horizon, (height(p + toward_sun * distance) - h - 0.5) / distance)
			var sunlight := 1.0 - smoothstep(sun_slope - 0.035, sun_slope + 0.035, sun_horizon)
			img.set_pixel(x, z, Color(1.0 - occlusion / 8.0 * 0.75, clampf(0.5 + basin / 128.0, 0.0, 1.0), sunlight))
	img.generate_mipmaps()
	return img
