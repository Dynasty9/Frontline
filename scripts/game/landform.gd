class_name Landform
extends RefCounted
## Broad geology is immutable; shell holes remain in TerrainMap's finer grid.
## Roads and settlements occupy graded valley floors, with talus and ridges above.

const STEP := 4.0
const FORMS = preload("res://assets/terrain/alpine_forms.tres")
var n: int
var half: float
var heights := PackedFloat32Array()
var reserve := PackedFloat32Array()
var drainage := PackedFloat32Array()
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


func generate(seed_value: int, roads: Array, water, settlements: Array, fractured := true) -> void:
	drainage.clear()
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
	if fractured:
		# Skirmishes occupy the foothills; towering massifs belong in the distant scenery.
		amplitude = minf(amplitude, 80.0)
	for z in n:
		for x in n:
			var wx := x * STEP - half
			var wz := z * STEP - half
			var ridge := clampf((noise.get_noise_2d(wx, wz) + 1.0) * 0.5, 0.0, 1.0)
			# A broad mountain belt, not a field of unrelated cones.
			var belt := 0.55 + 0.45 * sin(wx / half * 3.1 + sin(wz / half * 2.6 + seed_value * 0.1))
			heights[z * n + x] = amplitude * pow(ridge, 1.2 if fractured else 1.8) * belt
	if fractured:
		# Jointed bedrock forms shelves and buttresses before weathering loosens its edges.
		var joints := FastNoiseLite.new()
		joints.seed = seed_value + 331
		joints.frequency = 0.018
		joints.fractal_octaves = 3
		for z in n:
			for x in n:
				var i := z * n + x
				var h := heights[i]
				var wx := x * STEP - half
				var wz := z * STEP - half
				var fracture := joints.get_noise_2d(wx, wz)
				var bedding := h / 14.0 + wx * 0.006 + wz * 0.003 + fracture * 1.4
				var shelf := (smoothstep(0.22, 0.78, fposmod(bedding, 1.0)) - fposmod(bedding, 1.0)) * 14.0
				heights[i] = maxf(0.0, h + (shelf * 0.65 + fracture * 11.0) * smoothstep(12.0, 45.0, h))
	if fractured:
		_place_forms(seed_value)
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


## Baked buttresses, cirques and saddles replace patches of noise with coherent rock masses.
## They enter the authoritative heightfield before road grading and erosion, not a visual shell.
func _place_forms(seed_value: int) -> void:
	if half < 100.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 2753
	var original := heights.duplicate()
	var names := ["buttress", "cirque", "saddle"]
	var spacing := 224.0
	for iz in ceili(half * 2.0 / spacing):
		for ix in ceili(half * 2.0 / spacing):
			var c := Vector2(-half + (ix + 0.5) * spacing, -half + (iz + 0.5) * spacing)
			c += Vector2(rng.randf_range(-35, 35), rng.randf_range(-35, 35))
			var cell := Vector2i((c + Vector2.ONE * half) / STEP).clamp(Vector2i.ZERO, Vector2i.ONE * (n - 1))
			var base := original[cell.y * n + cell.x]
			var radius := rng.randf_range(85.0, 145.0)
			var angle := rng.randf_range(-PI, PI)
			var form: PackedFloat32Array = FORMS.get_meta(names[rng.randi_range(0, 2)])
			if base < 28.0:
				continue
			var cells := ceili(radius / STEP)
			for z in range(maxi(0, cell.y - cells), mini(n, cell.y + cells + 1)):
				for x in range(maxi(0, cell.x - cells), mini(n, cell.x + cells + 1)):
					var q := (Vector2(x * STEP - half, z * STEP - half) - c).rotated(angle) / radius
					var blend := 1.0 - smoothstep(0.55, 1.0, q.length())
					if blend <= 0.0:
						continue
					var uv := (q * 0.5 + Vector2.ONE * 0.5) * 32.0
					var a := Vector2i(uv).clamp(Vector2i.ZERO, Vector2i(31, 31))
					var f := uv - Vector2(a)
					var j := a.y * 33 + a.x
					var h := lerpf(lerpf(form[j], form[j + 1], f.x), lerpf(form[j + 33], form[j + 34], f.x), f.y)
					heights[z * n + x] = lerpf(heights[z * n + x], minf(490.0, base * (0.32 + h * 1.1)), blend)


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


## Rain follows every downhill neighbour; accumulated flow marks weathered gullies.
static func bake_drainage(samples: PackedFloat32Array, width: int, rainfall := 1.0) -> PackedFloat32Array:
	var order: Array[int] = []
	order.resize(samples.size())
	for i in order.size():
		order[i] = i
	order.sort_custom(func(a: int, b: int) -> bool: return samples[a] > samples[b])
	var flow := PackedFloat32Array()
	flow.resize(samples.size())
	flow.fill(rainfall)
	var directions: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
	var weights := PackedFloat32Array()
	weights.resize(8)
	var targets := PackedInt32Array()
	targets.resize(8)
	for i in order:
		var z := int(float(i) / width)
		var x := i - z * width
		var total := 0.0
		for k in 8:
			var d := directions[k]
			var nx := x + d.x
			var nz := z + d.y
			weights[k] = 0.0
			if nx < 0 or nz < 0 or nx >= width or nz >= width:
				continue
			var j := nz * width + nx
			targets[k] = j
			var distance := 1.41421356237 if d.x != 0 and d.y != 0 else 1.0
			weights[k] = pow(maxf(0.0, samples[i] - samples[j]) / distance, 1.1)
			total += weights[k]
		if total > 0.0:
			for k in 8:
				if weights[k] > 0.0:
					flow[targets[k]] += flow[i] * weights[k] / total
	for i in flow.size():
		flow[i] = clampf((log(flow[i]) / log(2.0) - 3.0) / 7.0, 0.0, 1.0)
	# A narrow blur hides grid steps without spreading stains across the watershed.
	var smooth := flow.duplicate()
	for z in width:
		for x in width:
			var i := z * width + x
			smooth[i] = flow[z * width + maxi(0, x - 1)] * 0.209 + flow[i] * 0.582 + flow[z * width + mini(width - 1, x + 1)] * 0.209
	for z in width:
		for x in width:
			var i := z * width + x
			flow[i] = smooth[maxi(0, z - 1) * width + x] * 0.209 + smooth[i] * 0.582 + smooth[mini(width - 1, z + 1) * width + x] * 0.209
	return flow


## Bake sky visibility, concavity, sun occlusion and drainage; crater normals stay live.
func bake_surface(sun_direction := Vector3.UP) -> Image:
	var size := ceili(half * 2.0 / 8.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	if drainage.is_empty() and not heights.is_empty():
		drainage = bake_drainage(heights, n)
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
			var flow := 0.0 if drainage.is_empty() else drainage[(z * 2 + 1) * n + x * 2 + 1]
			img.set_pixel(x, z, Color(1.0 - occlusion / 8.0 * 0.75, clampf(0.5 + basin / 128.0, 0.0, 1.0), sunlight, flow))
	img.generate_mipmaps()
	return img
