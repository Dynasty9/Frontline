class_name VehicleWheels
extends RefCounted
## Wheel assemblies share their construction, never their moving pivots.

static var _rings := {}
const AXLE := Vector3(0, 0, PI / 2)

static func pneumatic(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, w: float, hub_kind := "gunmetal_w", hub_col = null, profile := "offroad", register := true) -> Node3D:
	var pv := k._pivot(parent, pos)
	# Rounded shoulders and recessed rims share meshes at every wheel size.
	# Tiny trolley wheels and broad tracked road wheels retain their solid discs.
	if r < 0.18 or w > r * 1.2:
		k._cyl(pv, r, r, w, Vector3.ZERO, Vector3(0, 0, PI / 2), "rubber", null, 24)
	else:
		k._add(pv, ring(0.50, 1.0), "rubber", Color(0.17, 0.18, 0.17), Vector3.ZERO, Vector3(0, 0, PI / 2), Vector3(r, w / 0.50, r))
		if profile != "aircraft":
			var offroad := profile == "offroad"
			var count := 36 if offroad else 48
			for i in count:
				for row in [-1.0, 1.0]:
					var a := TAU * (float(i) + (0.45 if row > 0 else 0.0)) / float(count)
					var depth := r * (0.055 if offroad else 0.018)
					k._box(pv, Vector3(w * 0.43, depth, r * (0.13 if offroad else 0.095)), Vector3(row * w * 0.24, cos(a) * r * 0.975, sin(a) * r * 0.975), "rubber", Color(0.20, 0.21, 0.19), Vector3(a, row * 0.20, 0))
	k._cyl(pv, r * 0.54, r * 0.54, w * 0.67, Vector3.ZERO, Vector3(0, 0, PI / 2), hub_kind, hub_col, 32, false)
	for side in [-1.0, 1.0]:
		k._add(pv, ring(0.49, 0.55), hub_kind, hub_col, Vector3(side * w * 0.37, 0, 0), Vector3(0, 0, PI / 2), Vector3.ONE * r, false)
		for i in 8:
			var a := TAU * i / 8.0
			k._cyl(pv, r * 0.03, r * 0.03, w * 0.08, Vector3(side * w * 0.38, sin(a) * r * 0.31, cos(a) * r * 0.31), Vector3(0, 0, PI / 2), "steel", Color(0.35, 0.36, 0.33), 6, false)
	k._cyl(pv, r * 0.23, r * 0.26, w * 0.89, Vector3.ZERO, Vector3(0, 0, PI / 2), hub_kind, hub_col, 20, false)
	if register:
		k.wheels.append(pv)
	else:
		k._fold(pv)
		return parent
	return pv


## Cached unit rings keep rounded tyres and rim lips affordable across the roster.
static func ring(inner: float, outer: float) -> TorusMesh:
	var key := "tyre_ring_%s_%s" % [inner, outer]
	if not _rings.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 40
		mesh.ring_segments = 12
		_rings[key] = mesh
	return _rings[key]


## Twin road wheels leave space for the track guide teeth. Spoked wheels retain
## their characteristic pressed ribs; rubber tyres never receive road tread.
static func road(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, w: float, mat := "gunmetal_w", col = null, spokes := 0, rubber := true) -> Node3D:
	var pv := k._pivot(parent, pos)
	for side in [-1.0, 1.0]:
		var x: float = side * w * 0.30
		k._cyl(pv, r, r, w * 0.38, Vector3(x, 0, 0), AXLE, "rubber" if rubber else "gunmetal_w", null, 28)
		k._cyl(pv, r * 0.82, r * 0.77, w * 0.40, Vector3(x, 0, 0), AXLE, mat, col, 28)
		k._cyl(pv, r * 0.66, r * 0.66, w * 0.41, Vector3(x, 0, 0), AXLE, mat, col, 24, false)
		for i in 8:
			var a := TAU * i / 8.0
			k._cyl(pv, r * 0.03, r * 0.03, 0.025, Vector3(side * w * 0.52, sin(a) * r * 0.47, cos(a) * r * 0.47), AXLE, "gunmetal_w", null, 6, false)
	k._cyl(pv, r * 0.24, r * 0.28, w + 0.06, Vector3.ZERO, AXLE, mat, col, 16, false)
	var outer := signf(pos.x) if pos.x != 0 else 1.0
	for i in spokes:
		var a := TAU * i / float(spokes)
		k._box(pv, Vector3(0.025, r * 0.44, r * 0.18), Vector3(outer * w * 0.52, sin(a) * r * 0.53, cos(a) * r * 0.53), mat, col, Vector3(-a + PI / 2, 0, 0), false)
	k.wheels.append(pv)
	return pv


## A spare shares the running tyre's construction but never a rotating pivot.
## Rotation follows CylinderMesh convention: its unrotated axle points up.
static func spare(k: VehicleModels, parent: Node3D, pos: Vector3, radius: float, width: float, rot := Vector3.ZERO, mat := "gunmetal_w", col = null, profile := "offroad") -> void:
	var mount := k._pivot(parent, pos)
	mount.basis = Basis.from_euler(rot) * Basis.from_euler(AXLE).inverse()
	pneumatic(k, mount, Vector3.ZERO, radius, width, mat, col, profile, false)
	k._fold(mount)
