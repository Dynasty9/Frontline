class_name VehicleAirfoils
extends RefCounted
## Shared section shape and control-surface construction. Planforms and hinge
## stations remain authored per aircraft; the gap is measured in metres.
const PROFILE := [0.0, 0.0, 0.03, 0.52, 0.1, 0.82, 0.25, 1.0, 0.45, 0.94, 0.7, 0.6, 1.0, 0.1]

static func thickness(f: float, profile := PROFILE) -> float:
	for i in range(0, profile.size() - 2, 2):
		if f <= float(profile[i + 2]):
			return lerpf(profile[i + 1], profile[i + 3], (f - profile[i]) / (profile[i + 2] - profile[i]))
	return profile[-1]

## Fixed samples allow adjacent sections with different hinge fractions to
## loft together without mismatched rings. Zero samples follows authored knots.
static func section(le: Vector3, chord: float, depth: float, up: Vector3, f0 := 0.0, f1 := 1.0, along := Vector3.BACK, samples := 0, profile := PROFILE) -> PackedVector3Array:
	var points: Array[Vector2] = []
	if samples > 0:
		for i in samples:
			var t := float(i) / (samples - 1)
			var f := lerpf(f0, f1, t if f0 > 0.0 else 1.0 - cos(t * PI * 0.5))
			points.append(Vector2(f, thickness(f, profile) * (0.6 if i == 0 and f0 > 0.0 else 1.0)))
	else:
		if f0 > 0.0:
			points.append(Vector2(f0, 0))
			points.append(Vector2(f0 + 0.015, thickness(f0, profile) * 0.85))
		for i in range(0, profile.size(), 2):
			if profile[i] >= (0.0 if f0 <= 0.0 else f0 + 0.04) and profile[i] < f1 - 0.01:
				points.append(Vector2(profile[i], profile[i + 1]))
		points.append(Vector2(f1, thickness(f1, profile)))
	var ring := PackedVector3Array()
	for q in points:
		ring.append(le + along * q.x * chord + up * q.y * depth * 0.5)
	for i in range(points.size() - 1, -1, -1):
		var q := points[i]
		if q.y > 0.0:
			ring.append(le + along * q.x * chord - up * q.y * depth * 0.5)
	return ring

static func surface(k: VehicleModels, parent: Node3D, stations: Array, material: String, col, cuts := [], mirror := true, crease := 32.0, gap := 0.022) -> void:
	for side: float in ([1.0, -1.0] if mirror else [1.0]):
		for i in stations.size() - 1:
			var a: Array = stations[i]
			var b: Array = stations[i + 1]
			var la: Vector3 = a[0] * Vector3(side, 1, 1)
			var lb: Vector3 = b[0] * Vector3(side, 1, 1)
			var span := (lb - la) * Vector3(1, 1, 0)
			var up := Vector3.BACK.cross(span).normalized() if span.length() > 0.001 else Vector3.UP
			var fa: Array = [0.0]
			var fb: Array = [0.0]
			if i < cuts.size() and (cuts[i] as Array).size() == 2:
				fa.append_array(cuts[i][0])
				fb.append_array(cuts[i][1])
			fa.append(1.0)
			fb.append(1.0)
			assert(fa.size() == fb.size())
			for j in fa.size() - 1:
				var ga: float = gap / a[1] if j > 0 else 0.0
				var gb: float = gap / b[1] if j > 0 else 0.0
				var rings := [section(la, a[1], a[2], up, fa[j] + ga, fa[j + 1], Vector3.BACK, 8), section(lb, b[1], b[2], up, fb[j] + gb, fb[j + 1], Vector3.BACK, 8)]
				k._add(parent, VehicleProfiles.loft(rings, crease), material, col, Vector3.ZERO)
