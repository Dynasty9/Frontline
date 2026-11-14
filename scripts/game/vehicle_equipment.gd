class_name VehicleEquipment
extends RefCounted
## Mounted service equipment, parameterized by real dimensions rather than
## separate small/large copies. Hardware sizes are clamped independently.

static func storage(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat: String, col = null, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var lip := minf(0.025, size.y * 0.09)
	k._add(mount, BevelMesh.make(size - Vector3(0, lip, 0), minf(lip * 0.7, minf(size.x, size.z) * 0.04)), mat, col, Vector3(0, -lip * 0.5, 0))
	k._box(mount, Vector3(size.x * 0.98, lip * 0.4, size.z * 0.98), Vector3(0, size.y * 0.5 - lip, 0), "rubber")
	k._box(mount, Vector3(size.x, lip, size.z), Vector3(0, size.y * 0.5 - lip * 0.35, 0), mat, col)
	# The pressed panel stands under a centimetre proud of the lid: its edge
	# reads the same without a chamfer of its own.
	var inset := minf(size.x, size.z) * 0.12
	k._add(mount, _plate(Vector3(size.x - inset * 2, lip * 0.3, size.z - inset * 2)), mat, col, Vector3(0, size.y * 0.5 + lip * 0.25, 0))
	var along := Vector3.FORWARD if size.z > size.x else Vector3.RIGHT
	VehicleDoors.pull(k, mount, Vector3(0, size.y * 0.5, 0), Vector3.UP, along, minf(0.18, maxf(size.x, size.z) * 0.35), minf(0.012, minf(size.x, size.z) * 0.08))
	# A lid too narrow to space two hinges a hinge's length apart (under about
	# 22 cm) hangs on one in the middle of its back edge, as a small locker's does.
	var pin := minf(0.012, size.x * 0.06)
	var hinges: Array[float] = [0.0]
	if size.x * 0.6 >= pin * 11.2:
		hinges = [-0.3, 0.3]
	for x: float in hinges:
		VehicleDoors.hinge(k, mount, Vector3(x * size.x, size.y * 0.5, size.z * 0.43), Vector3.UP, Vector3.RIGHT, pin, mat, col)
	for side: float in [-1.0, 1.0]:
		k._add(mount, _plate(Vector3(minf(0.04, size.x * 0.18), lip * 2, 0.015)), "metal_dark", null, Vector3(side * size.x * 0.3, size.y * 0.5 - lip, -size.z * 0.51))
	k._fold(mount)


static var _plates := {}

## A plain box, cached by size. Res.box chamfers anything over 1.2 cm, but a
## chamfer of a few millimetres on a tab, strap or thin plate is a pixel even
## in a close-up and costs nearly four times the triangles of the box itself.
static func _plate(size: Vector3) -> BoxMesh:
	if not _plates.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		_plates[size] = mesh
	return _plates[size]


## A cylinder along +Y (Res.cyl's) with only the caps that show: a race sitting
## on a roof, a seal sunk in a face or a rod ending inside a hub hides one or
## both. Its side is one band (Res.cyl's middle ring adds triangles, not
## shape). Cached by size.
static func _cylinder(top: float, bottom: float, height: float, segments: int, cap_top := true, cap_bottom := true) -> CylinderMesh:
	return VehicleBody.drum(top, bottom, height, segments, cap_top, cap_bottom)


## k._cyl with only the caps that show: `caps` 1 the bottom, 2 the top, 3 both.
static func _cyl(k: VehicleModels, parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, rot: Vector3, mat: String, col, segments: int, shadow := true, caps := 3) -> void:
	k._add(parent, _cylinder(top, bottom, height, segments, (caps & 2) != 0, (caps & 1) != 0), mat, col, pos, rot, Vector3.ONE, shadow)


## VehicleFrames.tube's rod from `a` to `b`, with the end caps that show:
## `ends` 1 caps `a`, 2 caps `b`, 3 both and 0 neither (both buried).
static func _rod(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: String, col, segments: int, shadow: bool, ends: int, end_radius := -1.0) -> void:
	if a.distance_squared_to(b) < 0.00000001:
		return
	var mesh := _cylinder(end_radius if end_radius >= 0.0 else radius, radius, a.distance_to(b), segments, (ends & 2) != 0, (ends & 1) != 0)
	k._add(parent, mesh, mat, col, (a + b) * 0.5, VehicleFrames.aim(b - a).get_euler(), Vector3.ONE, shadow)

static func skirt(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side: float, mat: String, col = null, rotation := Vector3.ZERO) -> void:
	var cut := minf(0.06, minf(size.y, size.z) * 0.1)
	var profile := [-size.z * 0.5 + cut, -size.y * 0.5, size.z * 0.5 - cut, -size.y * 0.5, size.z * 0.5, -size.y * 0.5 + cut, size.z * 0.5, size.y * 0.5, -size.z * 0.5, size.y * 0.5, -size.z * 0.5, -size.y * 0.5 + cut]
	k._add(parent, VehicleModels.extrude_x("skirt_" + str(size), profile, -size.x * 0.5, size.x * 0.5), mat, col, center, rotation)
	var basis := Basis.from_euler(rotation)
	var normal := basis * Vector3(side, 0, 0)
	for end: float in [-1.0, 1.0]:
		var at := center + basis * Vector3(side * size.x * 0.55, size.y * 0.38, end * size.z * 0.36)
		VehicleBody.fastener(k, parent, at, normal, 0.012)
		_rod(k, parent, at - basis.z * 0.035, at + basis.z * 0.035, minf(0.012, size.x * 0.2), "steel", null, 6, false, 3)
		# The bracket is a strap under two centimetres thick: a plain bar.
		var lo := at - basis.y * size.y * 0.08
		var hi := at + basis.y * size.y * 0.14
		k._add(parent, _plate(Vector3(0.032, lo.distance_to(hi), 0.018)), "metal_dark", null, (lo + hi) * 0.5, VehicleFrames.aim(hi - lo).get_euler())
	# A thin lower fold distinguishes formed metal from flexible rubber skirts.
	if VehicleMaterials.profile(mat, k.surface_family) != "rubber":
		var a := center + basis * Vector3(side * size.x * 0.52, -size.y * 0.46, -size.z * 0.46)
		var b := center + basis * Vector3(side * size.x * 0.52, -size.y * 0.46, size.z * 0.46)
		_rod(k, parent, a, b, 0.006, mat, col, 5, false, 3)

## The bow panel of a skirt run, raked over the idler or sprocket: the old
## rotated box's centre, size and rotation. Local X is the panel's thickness
## (outward toward `side`), Y runs up the panel, Z along the run; `lead` is the
## end of local Z the vehicle drives toward (-1 for a bow panel at the front).
## Crews swing this panel up to get at the track, so it hangs from two hinges
## on its upper edge, with a grab handle near the leading end; its leading
## lower corner is rounded off to ride over obstacles, and a rubber wear strip
## is clamped along its lower edge. The plain panels behind it stay `skirt`.
static func skirt_bow(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side: float, mat: String, col = null, rotation := Vector3.ZERO, lead := -1.0) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var s := 1.0 if side >= 0.0 else -1.0
	var l := 1.0 if lead > 0.0 else -1.0
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var cut := minf(0.06, minf(size.y, size.z) * 0.1)
	var nose := minf(size.y, size.z) * 0.32
	# Side profile (z, y), drawn for a leading -Z end and mirrored for +Z.
	var corner := [Vector2(-hz + nose, -hy), Vector2(hz - cut, -hy), Vector2(hz, -hy + cut), Vector2(hz, hy), Vector2(-hz, hy), Vector2(-hz, -hy + nose), Vector2(-hz + nose * 0.076, -hy + nose * 0.617), Vector2(-hz + nose * 0.617, -hy + nose * 0.076)]
	var profile := []
	for q: Vector2 in corner:
		profile.append_array([q.x * -l, q.y])
	k._add(mount, VehicleModels.extrude_x("skirt_bow_%s_%d" % [str(size), int(l)], profile, -hx, hx), mat, col, Vector3.ZERO)
	var out := Vector3(s, 0, 0)
	var hinge := minf(0.016, size.y * 0.04)
	for end: float in [-1.0, 1.0]:
		VehicleDoors.hinge(k, mount, Vector3(s * hx, hy - hinge * 2.4, end * hz * 0.5), out, Vector3.BACK, hinge, mat, col)
	VehicleDoors.pull(k, mount, Vector3(s * hx, -hy * 0.3, l * hz * 0.45), out, Vector3.BACK, minf(0.14, size.z * 0.25), minf(0.01, size.x * 0.15))
	# The wear strip runs between the rounded nose and the trailing chamfer.
	var a := l * (hz - nose)
	var b := -l * (hz - cut)
	var strip := minf(0.03, size.y * 0.08)
	k._add(mount, _plate(Vector3(size.x * 1.4, strip, absf(b - a))), "rubber", null, Vector3(0, -hy + strip * 0.5, (a + b) * 0.5))
	k._fold(mount)


static func winch(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var radius := size.y * 0.35
	var width := size.x * 0.66
	k._box(mount, Vector3(size.x, size.y * 0.16, size.z), Vector3(0, -size.y * 0.4, 0), "metal_dark")
	# The drum's ends are in its side plates.
	_cyl(k, mount, radius, radius, width, Vector3.ZERO, Vector3(0, 0, PI / 2), "metal_dark", null, 16, true, 0)
	for i in 9:
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.88
		ring.outer_radius = radius * 1.03
		ring.rings = 12
		ring.ring_segments = 4
		k._add(mount, ring, "steel", Color(0.23, 0.24, 0.23), Vector3(lerpf(-width * 0.43, width * 0.43, i / 8.0), 0, 0), Vector3(0, 0, PI / 2))
	for side: float in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x * 0.1, size.y * 0.85, size.z * 0.65), Vector3(side * width * 0.57, 0, 0), "metal_dark")
		var x := side * width * 0.38
		VehicleFrames.tube(k, mount, Vector3(x, -radius * 0.5, -size.z * 0.55), Vector3(x, radius * 0.5, -size.z * 0.55), radius * 0.19, "steel", null, 8, false)
	for side: float in [-1.0, 1.0]:
		VehicleFrames.tube(k, mount, Vector3(-width * 0.38, side * radius * 0.5, -size.z * 0.55), Vector3(width * 0.38, side * radius * 0.5, -size.z * 0.55), radius * 0.15, "steel", null, 8, false)
	VehicleFrames.cable(k, mount, [Vector3(0, -radius * 0.35, 0), Vector3(0, -radius * 0.35, -size.z * 0.6)], radius * 0.08, 0.0, "steel", null, false)
	for side: float in [-1.0, 1.0]:
		_cyl(k, mount, radius * 1.18, radius * 1.18, size.x * 0.025, Vector3(side * width * 0.48, 0, 0), Vector3(0, 0, PI / 2), "steel", Color(0.18, 0.19, 0.18), 16)
	# The motor's inner end is in the side plate.
	_cyl(k, mount, radius * 0.65, radius * 0.65, size.x * 0.12, Vector3(size.x * 0.43, 0, 0), Vector3(0, 0, PI / 2), "metal_dark", null, 12, true, 1)
	k._box(mount, Vector3(size.x * 0.12, size.y * 0.65, size.z * 0.45), Vector3(-size.x * 0.43, 0, 0), "metal_dark")
	k._fold(mount)


## Sensor cases share recessed lenses and protective bezels. No turret or
## animation registration happens here; a caller may provide its own pivot.
## `center` and `size` are the old head (box, or the sphere's centre and
## diameters for "ball"); its windows look out of the head's -Z face.
## `neck` = (radius at the head, radius at the airframe, reach) hangs an EO/IR
## ball on its azimuth housing: the neck runs from the head's centre straight
## up `reach` to the airframe (a negative reach stands the head on a neck that
## runs down to a mast or nose), ending in a bolted flange, with the dark
## rotary joint where it leaves the head. The neck stays upright; `rotation`
## turns only the head, so a turret can look sideways or down. `windows` is
## 1 (one centred aperture), 2 (the main and the second sensor side by side)
## or 3 (a small rangefinder window above the second). `lens` > 0 sets the main
## window's glass radius in metres (a thermal sight's big objective, 5.5 cm on
## the Vorona's), the others keeping their size relative to it; 0 sizes them
## from the head.
static func sensor(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat: String, col = null, style := "box", neck := Vector3.ZERO, windows := 2, rotation := Vector3.ZERO, lens := 0.0) -> void:
	if neck.z != 0.0:
		_sensor_neck(k, parent, center, size, neck, mat, col)
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	if style == "ball":
		k._add(mount, Res.sphere(0.5, 16), mat, col, Vector3.ZERO, Vector3.ZERO, size)
	else:
		k._box(mount, size, Vector3.ZERO, mat, col)
		k._box(mount, Vector3(size.x * 1.07, size.y * 0.08, size.z * 1.08), Vector3(0, size.y * 0.54, 0), mat, col)
	# Each window: x and y as fractions of the face, and its radius as a
	# fraction of the head's width.
	var panes: Array = [Vector3(0, 0, 0.16)] if windows <= 1 else [Vector3(-0.19, 0, 0.13), Vector3(0.19, 0, 0.09)]
	if windows >= 3:
		panes.append(Vector3(0.19, 0.25, 0.05))
	var main := minf(size.x * (panes[0] as Vector3).z, size.y * 0.22)
	var grow := lens / main if lens > 0.0 and main > 0.0 else 1.0
	for pane: Vector3 in panes:
		var radius := minf(size.x * pane.z, size.y * 0.22) * grow
		# A raised window on a ball sits back on the curve, as the row does.
		var depth := 0.49 if pane.y == 0.0 or style != "ball" else sqrt(maxf(0.0, 0.25 - pane.x * pane.x - pane.y * pane.y)) + 0.0275
		var at := Vector3(size.x * pane.x, size.y * pane.y, -size.z * depth)
		# The glass shows only its face, its back in the seal; the seal's back is
		# in a box head (a ball curves away behind it).
		_cyl(k, mount, radius * 1.25, radius * 1.25, radius * 0.35, at, Vector3(PI / 2, 0, 0), "rubber", null, 12, false, 1 if style != "ball" else 3)
		if not k.burnt:
			_cyl(k, mount, radius, radius, radius * 0.08, at + Vector3(0, 0, -radius * 0.2), Vector3(PI / 2, 0, 0), "glass", Color(0.13, 0.20, 0.23), 12, false, 1)
		var rim := VehicleFittings._ring(radius, radius * 1.2)
		k._add(mount, rim, "metal_dark", null, at + Vector3(0, 0, -radius * 0.28), Vector3(PI / 2, 0, 0), Vector3(1, 0.45, 1))
	for side: float in [-1.0, 1.0]:
		# The trunnion bosses: their inner faces are inside the head.
		_cyl(k, mount, size.y * 0.16, size.y * 0.16, size.x * 0.06, Vector3(side * size.x * 0.5, 0, 0), Vector3(0, 0, PI / 2), mat, col, 10, false, 1 if side > 0.0 else 2)
	if style == "box":
		k._box(mount, Vector3(size.x * 1.08, size.y * 0.07, size.z * 0.24), Vector3(0, size.y * 0.50, -size.z * 0.48), mat, col)
	else:
		k._add(mount, VehicleFittings._ring(size.y * 0.17, size.y * 0.21), "rubber", null, Vector3(0, size.y * 0.46, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	var cover := Vector3(0, 0, size.z * 0.49)
	if style == "ball":
		_cyl(k, mount, minf(size.x, size.y) * 0.22, minf(size.x, size.y) * 0.22, size.z * 0.12, Vector3(0, 0, size.z * 0.44), Vector3(PI / 2, 0, 0), mat, col, 12, true, 2)
	else:
		k._add(mount, BevelMesh.make(Vector3(size.x * 0.44, size.y * 0.42, size.z * 0.035), minf(size.z * 0.012, size.y * 0.03)), mat, col, cover)
	for side: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, cover + Vector3(side * size.x * 0.15, 0, size.z * 0.025), Vector3.BACK, minf(0.009, size.y * 0.035))
	k._fold(mount)


## The azimuth housing between a sensor head and the airframe (see sensor).
static func _sensor_neck(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, neck: Vector3, mat: String, col) -> void:
	var up := Vector3.UP if neck.z > 0.0 else Vector3.DOWN
	var reach := absf(neck.z)
	var far := center + up * reach
	# The neck's ends are in the head and under its flange.
	_rod(k, parent, center, far, neck.x, mat, col, 12, true, 0, neck.y)
	# The flange stays within a fat neck's own airframe footprint; its face on
	# the airframe never shows.
	var flange := minf(neck.y * 1.3, neck.y + 0.03)
	var plate := minf(0.02, reach * 0.1)
	_cyl(k, parent, flange, flange, plate, far - up * plate * 0.5, Vector3.ZERO, mat, col, 12, true, 1 if up.y > 0.0 else 2)
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		VehicleBody.fastener(k, parent, far - up * (plate + 0.002) + Vector3(cos(a), 0, sin(a)) * (neck.y + flange) * 0.5, -up, minf(0.009, (flange - neck.y) * 0.4 + 0.003))
	var head := size.y * 0.5
	if reach > head + 0.03:
		var joint := lerpf(neck.x, neck.y, head / reach) * 1.12
		k._cyl(parent, joint, joint, minf(0.03, (reach - head) * 0.3), center + up * (head + minf(0.015, (reach - head) * 0.15)), Vector3.ZERO, "metal_dark", null, 12, false)


## Dished cylindrical/oval vessel along local Z, with straps and optional
## saddles. Width, height and length are independent for different tank bodies.
static func vessel(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, straps: Array, mat: String, col = null, saddles := true) -> void:
	var cap := minf(size.z * 0.12, size.y * 0.18)
	var half := size.z * 0.5
	var profile := [Vector2(0, -half), Vector2(0.7, -half + cap * 0.2), Vector2(1, -half + cap), Vector2(1, half - cap), Vector2(0.7, half - cap * 0.2), Vector2(0, half)]
	var scale := Vector3(size.x * 0.5, size.y * 0.5, 1)
	# Sides enough to keep the outline round: 24 round a tanker's barrel, down
	# to 16 round a saddle tank 40 cm across, whose flats then stand 4 mm inside
	# the true circle. Welds and straps follow the shell.
	var sides := clampi(roundi(maxf(size.x, size.y) * 20.0) * 2, 16, 24)
	k._add(parent, VehicleProfiles.revolve(profile, sides, 65), mat, col, center, Vector3.ZERO, scale)
	for end: float in [-1.0, 1.0]:
		var z := end * (half - cap)
		var weld := [Vector2(1, z - 0.008), Vector2(1.006, z), Vector2(1, z + 0.008)]
		k._add(parent, VehicleProfiles.revolve(weld, sides), mat, col, center, Vector3.ZERO, scale)
	for z: float in straps:
		var band := [Vector2(1, z - 0.024), Vector2(1.012, z - 0.02), Vector2(1.012, z + 0.02), Vector2(1, z + 0.024)]
		k._add(parent, VehicleProfiles.revolve(band, sides), "metal_dark", null, center, Vector3.ZERO, scale)
		var pad := [Vector2(1, z - 0.036), Vector2(1.004, z - 0.032), Vector2(1.004, z + 0.032), Vector2(1, z + 0.036)]
		k._add(parent, VehicleProfiles.revolve(pad, sides), "rubber", null, center, Vector3.ZERO, scale)
		if saddles:
			k._box(parent, Vector3(size.x * 0.8, size.y * 0.14, 0.12), center + Vector3(0, -size.y * 0.48, z), "metal_dark")
		for side: float in [-1.0, 1.0]:
			VehicleBody.fastener(k, parent, center + Vector3(side * size.x * 0.38, -size.y * 0.30, z), Vector3(side, 0.5, 0).normalized(), 0.014)


## The top of a road tanker's barrel. `center` and `size` are the barrel's own
## (as given to vessel), so the fittings follow its elliptical crown, and `mat`
## / `col` its finish, for the manhole collars welded to it. A walkway of open
## steel bar grating `walkway.x` wide and `walkway.y` long runs along the
## crown, centred on the barrel's length and `walkway.z` to the side of its
## centre line: level, between side channels, on cross bearers with legs down
## to the shell where it falls away; its grating opens round any manhole
## reaching more than 4 cm into it, the side channels running on past.
## `manholes` are the z of the manholes along the centre line: a collar welded
## to the shell under a hinged lid of radius `manhole` (VehicleFittings.hatch)
## with its vent valve. `rails` = (x, height) stands folding handrails either
## side at +-x from the centre line, their top rail `height` over the walkway:
## stanchions hinged on the walkway's edge (or on the shell when they stand
## clear of it), with a knee rail when taller than 35 cm; zero height for none.
## A finite `ladder` is the foot of an access ladder on the barrel's end face
## (VehicleCargo.rung_ladder, `ladder_width` wide, its rails 7 cm off the face),
## the stiles reaching the handrails' height as handholds. Walkway, rails,
## lids and ladder are made of `fittings`. Stays within the barrel's width,
## its length but for the ladder and 17 cm over the crown but for the rails;
## the pump cabinet behind the barrel is pump_cabinet, and hose reels and
## placards stay with the caller.
static func tanker_top(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat: String, col, walkway: Vector3, manholes: Array, rails := Vector2.ZERO, manhole := 0.25, ladder := Vector3.INF, ladder_width := 0.4, fittings := "gunmetal_w") -> void:
	var hz := size.z * 0.5
	var cap := minf(size.z * 0.12, size.y * 0.18)
	var w := walkway.x
	var hw := w * 0.5
	var wx := center.x + walkway.z
	var wz0 := center.z - walkway.y * 0.5
	var wz1 := center.z + walkway.y * 0.5
	# Level, it rests where the crown under it is highest.
	var floor_y := _crown(center, size, clampf(center.x, wx - hw, wx + hw)) + 0.005
	var grate := 0.03
	var deck := floor_y + grate
	var coaming := manhole + 0.04
	var zs: Array[float] = []
	for z: float in manholes:
		zs.append(z)
	zs.sort()
	# The grating opens 6 cm clear of the coaming of any manhole reaching more
	# than 4 cm into the walkway; its side channels run on past.
	var holes: Array[Vector2] = []
	if w > 0.0 and absf(wx - center.x) < hw + coaming - 0.04:
		for z: float in zs:
			holes.append(Vector2(z - coaming - 0.06, z + coaming + 0.06))
	var segments: Array[Vector2] = []
	var start := wz0
	for hole: Vector2 in holes:
		if minf(hole.x, wz1) > start + 0.1:
			segments.append(Vector2(start, minf(hole.x, wz1)))
		start = maxf(start, hole.y)
	if w > 0.0 and wz1 > start + 0.1:
		segments.append(Vector2(start, wz1))
	var lo := center.z - hz + cap + 0.05
	var hi := center.z + hz - cap - 0.05
	if w > 0.0:
		for s: float in [-1.0, 1.0]:
			k._box(parent, Vector3(0.03, grate, walkway.y), Vector3(wx + s * (hw - 0.015), floor_y + grate * 0.5, center.z), fittings)
	for seg: Vector2 in segments:
		var length := seg.y - seg.x
		var zc := (seg.x + seg.y) * 0.5
		k._add(parent, _grating(Vector2(w - 0.06, length - 0.06), grate), fittings, null, Vector3(wx, floor_y + grate * 0.5, zc), Vector3.ZERO, Vector3.ONE, false)
		# Seen from above, the dark between the bars reads as one walkway.
		k._box(parent, Vector3(w - 0.06, 0.004, length - 0.06), Vector3(wx, floor_y + 0.003, zc), "plain_dark", Color(0.05, 0.05, 0.05), Vector3.ZERO, false)
		for s: float in [-1.0, 1.0]:
			k._box(parent, Vector3(w - 0.06, grate, 0.03), Vector3(wx, floor_y + grate * 0.5, zc + s * (length * 0.5 - 0.015)), fittings)
		var stations := maxi(2, ceili(length / 1.2) + 1)
		for i in stations:
			var z := clampf(lerpf(seg.x + 0.08, seg.y - 0.08, float(i) / (stations - 1)), lo, hi)
			k._box(parent, Vector3(w - 0.04, 0.025, 0.04), Vector3(wx, floor_y - 0.0125, z), fittings, null, Vector3.ZERO, false)
			for s: float in [-1.0, 1.0]:
				var x := wx + s * (hw - 0.03)
				var shell := _crown(center, size, x)
				if floor_y - shell > 0.02:
					VehicleFrames.beam(k, parent, Vector3(x, floor_y - 0.02, z), Vector3(x, shell - 0.01, z), 0.03, 0.03, fittings, null, false)
	for z: float in zs:
		var x := center.x
		var crown := _crown(center, size, x)
		var drop := crown - _crown(center, size, x + coaming)
		# The collar's foot is in the shell.
		_cyl(k, parent, coaming, coaming, 0.04 + drop, Vector3(x, crown + (0.02 - drop) * 0.5, z), Vector3.ZERO, mat, col, 20, true, 2)
		VehicleFittings.hatch(k, parent, Vector3(x, crown + 0.09, z), manhole, fittings, null, 1.0, 0.035)
		# The pressure and vacuum vent on the lid, clear of hinges and handle.
		var vent := Vector3(x - manhole * 0.25, crown + 0.1075, z + manhole * 0.3)
		k._cyl(parent, 0.026, 0.03, 0.045, vent + Vector3(0, 0.0225, 0), Vector3.ZERO, fittings, null, 8, false)
		k._cyl(parent, 0.038, 0.038, 0.014, vent + Vector3(0, 0.05, 0), Vector3.ZERO, fittings, null, 8, false)
	if rails.y > 0.0:
		var r := 0.016
		var top := deck + rails.y
		var span := (walkway.y if w > 0.0 else size.z - cap * 2.0) - 0.3
		var count := maxi(2, roundi(span / 1.3) + 1)
		for s: float in [-1.0, 1.0]:
			var x := center.x + s * rails.x
			var on_walk := w > 0.0 and absf(x - wx) <= hw + 0.05
			var on_grating := absf(x - wx) < hw - 0.04
			var feet: Array[Vector3] = []
			for i in count:
				var z := center.z - span * 0.5 + span * float(i) / (count - 1)
				var bare := not on_walk
				for hole: Vector2 in holes:
					bare = bare or (on_grating and z > hole.x and z < hole.y)
				feet.append(Vector3(x, _crown(center, size, x) if bare else deck, z))
			for i in count:
				var foot := feet[i]
				# Each stanchion folds flat on a hinge at its foot for travel.
				VehicleFrames.tube(k, parent, foot, Vector3(foot.x, top, foot.z), r, fittings, null, 6, false)
				k._box(parent, Vector3(r * 5, r, r * 4), foot + Vector3(0, r * 0.5, 0), fittings, null, Vector3.ZERO, false)
				k._cyl(parent, r * 1.6, r * 1.6, r * 5, foot + Vector3(0, r * 1.6, 0), Vector3(PI / 2, 0, 0), "steel", null, 8, false)
				if i > 0:
					var last := feet[i - 1]
					VehicleFrames.tube(k, parent, Vector3(last.x, top, last.z), Vector3(foot.x, top, foot.z), r, fittings, null, 6, false)
					if rails.y > 0.35:
						VehicleFrames.tube(k, parent, Vector3(last.x, (last.y + top) * 0.5, last.z), Vector3(foot.x, (foot.y + top) * 0.5, foot.z), r * 0.8, fittings, null, 6, false)
	if ladder.is_finite():
		var normal := Vector3.BACK if ladder.z >= center.z else Vector3.FORWARD
		VehicleCargo.rung_ladder(k, parent, ladder, deck + maxf(rails.y, 0.1), normal, ladder_width)


## The barrel's top surface `x` from its axis (an ellipse in section).
static func _crown(center: Vector3, size: Vector3, x: float) -> float:
	var u := clampf((x - center.x) / (size.x * 0.5), -1.0, 1.0)
	return center.y + size.y * 0.5 * sqrt(1.0 - u * u)


static var _gratings := {}

## Open bar grating `size.x` across and `size.y` long, `depth` deep and
## centred: bearing bars across it every 6 cm, tied by three cross rods along
## its top. One cached mesh a size.
static func _grating(size: Vector2, depth: float) -> ArrayMesh:
	var key := Vector3(snappedf(size.x, 0.001), snappedf(size.y, 0.001), depth)
	if _gratings.has(key):
		return _gratings[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bar := BoxMesh.new()
	bar.size = Vector3(size.x, depth * 0.8, 0.008)
	var bars := maxi(2, roundi(size.y / 0.06))
	for i in bars:
		st.append_from(bar, 0, Transform3D(Basis.IDENTITY, Vector3(0, -depth * 0.1, lerpf(-size.y * 0.5 + 0.004, size.y * 0.5 - 0.004, float(i) / (bars - 1)))))
	var rod := BoxMesh.new()
	rod.size = Vector3(0.008, depth * 0.2, size.y)
	for x: float in [-0.3, 0.0, 0.3]:
		st.append_from(rod, 0, Transform3D(Basis.IDENTITY, Vector3(x * size.x, depth * 0.4, 0)))
	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	_gratings[key] = mesh
	return mesh


## The pump and valve cabinet of a tanker or bowser: the old box's centre and
## size in the parent's axes, its doors on the face toward `face` (level and
## outward: BACK for a cabinet across the tail). A pressed box with a pair of
## doors (one when narrower than 70 cm) in VehicleCargo.body_door's frame,
## hinges, handles and locking bars, louvres in their upper panels to let the
## pump's heat and fumes out, and under them the bottom-loading outlets:
## `outlets` capped hose couplings (0 for none) along the foot of the face, each
## with its lever valve. Stays within the box but for 6.5 cm in front of the
## face. Hose reels, placards, extinguishers and ladders stay with the caller.
static func pump_cabinet(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, face: Vector3, mat: String, col = null, outlets := 2) -> void:
	var n := Vector3(face.x, 0, face.z).normalized()
	if n.is_zero_approx():
		n = Vector3.BACK
	var basis := Basis(Vector3.UP.cross(n), Vector3.UP, n)
	var m := k._pivot(parent, center)
	m.basis = basis
	var w := absf(basis.x.x) * size.x + absf(basis.x.z) * size.z
	var d := absf(n.x) * size.x + absf(n.z) * size.z
	var h := size.y
	k._add(m, BevelMesh.make(Vector3(w, h, d), minf(0.02, minf(w, d) * 0.05)), mat, col, Vector3.ZERO)
	var foot := 0.14 if outlets > 0 else 0.08
	var dh := maxf(0.2, h - foot - 0.12)
	var dw := maxf(0.3, w - 0.2)
	var dy := h * 0.5 - 0.1 - dh * 0.5
	var leaves := 2 if dw > 0.7 else 1
	VehicleCargo.body_door(k, m, Vector3(0, dy, d * 0.5), Vector2(dw, dh), Vector3.BACK, leaves, mat, col)
	var lw := dw / leaves
	var pitch := minf(0.05, dh * 0.08)
	for i in leaves:
		var x := -dw * 0.5 + lw * (i + 0.5)
		for j in 4:
			var y := dy + dh * 0.5 - 0.07 - j * pitch
			k._box(m, Vector3(lw * 0.5, pitch * 0.5, 0.004), Vector3(x, y, d * 0.5 + 0.022), "plain_dark", Color(0.03, 0.03, 0.03), Vector3.ZERO, false)
			k._box(m, Vector3(lw * 0.52, pitch * 0.55, 0.008), Vector3(x, y + pitch * 0.12, d * 0.5 + 0.03), mat, col, Vector3(-0.6, 0, 0), false)
	if outlets > 0:
		var y := -h * 0.5 + foot * 0.45
		for i in outlets:
			var x := lerpf(-w * 0.32, w * 0.32 - 0.1, float(i) / (outlets - 1)) if outlets > 1 else -w * 0.2
			var at := Vector3(x, y, d * 0.5)
			k._cyl(m, 0.036, 0.036, 0.03, at + Vector3(0, 0, 0.015), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
			k._cyl(m, 0.046, 0.046, 0.02, at + Vector3(0, 0, 0.04), Vector3(PI / 2, 0, 0), "steel", null, 10, false)
			k._box(m, Vector3(0.08, 0.011, 0.011), at + Vector3(0, 0, 0.0555), "steel", null, Vector3.ZERO, false)
			# The quarter-turn valve behind each coupling, its lever beside it.
			k._cyl(m, 0.02, 0.02, 0.02, at + Vector3(0.075, 0, 0.01), Vector3(PI / 2, 0, 0), "steel", null, 8, false)
			k._box(m, Vector3(0.1, 0.016, 0.011), at + Vector3(0.115, 0, 0.026), "gunmetal_w", null, Vector3.ZERO, false)
	k._fold(m)


## Gas bottles standing in a rack: a welding set's oxygen and acetylene, or
## bottled fuel gas. `centers` are the old cylinders' centres and `radius` and
## `height` their size: each bottle's foot ring stands at the bottom of its
## cylinder and its domed shoulder reaches the top, the neck, valve and cap
## standing about a radius above. `colors` paint the bottles in turn. The rack
## is a tray under the row with a kerb along its front, a back frame on the
## side toward `back` (level: the wall or bed side it is bolted to) and two
## webbing clamp bands round every bottle, each closed by a buckle in front.
## `cap` screws a ventilated cap over each valve; false leaves the valve open
## with its handwheel and outlet, as on a set in use. Rack in `mat`/`col`.
## Stays within the cylinders but for the tops above, the tray's 3 cm round
## the row and 3 cm of back frame behind it.
static func gas_bottle(k: VehicleModels, parent: Node3D, centers: Array, radius: float, height: float, colors: Array, back: Vector3, cap := true, mat := "gunmetal_w", col = null) -> void:
	if centers.is_empty():
		return
	var b := Vector3(back.x, 0, back.z).normalized()
	var first: Vector3 = centers[0]
	var last: Vector3 = centers[centers.size() - 1]
	var row := Vector3(last.x - first.x, 0, last.z - first.z)
	row = row.normalized() if row.length() > 0.001 else b.cross(Vector3.UP)
	var rb := Basis(row, Vector3.UP, row.cross(Vector3.UP))
	var body := _bottle(radius, height)
	var band := VehicleCargo._ring(radius + 0.006, 0.006)
	var webbing := Color(0.16, 0.16, 0.14)
	for i in centers.size():
		var c: Vector3 = centers[i]
		var tint: Color = colors[posmod(i, colors.size())] if not colors.is_empty() else Color(0.3, 0.32, 0.3)
		var foot := c.y - height * 0.5
		var top := foot + height
		k._add(parent, body, "paint", tint, Vector3(c.x, foot, c.z), Vector3(-PI / 2, 0, 0))
		k._cyl(parent, radius * 0.38, radius * 0.38, 0.025, Vector3(c.x, top + 0.0125, c.z), Vector3.ZERO, "steel", null, 10, false)
		if cap:
			var ch := radius * 0.85
			k._cyl(parent, radius * 0.5, radius * 0.56, ch, Vector3(c.x, top + 0.025 + ch * 0.5, c.z), Vector3.ZERO, mat, col, 10)
			k._cyl(parent, radius * 0.54, radius * 0.54, 0.012, Vector3(c.x, top + 0.019 + ch, c.z), Vector3.ZERO, mat, col, 10, false)
		else:
			k._cyl(parent, 0.02, 0.024, 0.06, Vector3(c.x, top + 0.055, c.z), Vector3.ZERO, "steel", null, 8, false)
			k._add(parent, Res.torus(radius * 0.22, radius * 0.3), "gunmetal_w", null, Vector3(c.x, top + 0.09, c.z))
			VehicleFrames.tube(k, parent, Vector3(c.x, top + 0.05, c.z), Vector3(c.x, top + 0.05, c.z) + row * 0.05, 0.011, "steel", null, 6, false)
		for f: float in [0.3, 0.72]:
			var y := foot + height * f
			k._add(parent, band, "webbing", webbing, Vector3(c.x, y, c.z), Vector3.ZERO, Vector3(1, 2.4, 1), false)
			k._box(parent, Vector3(0.035, 0.03, 0.01), Vector3(c.x, y, c.z) - b * (radius + 0.011), "steel", null, rb.get_euler(), false)
	# The rack: a tray with its kerb, a frame behind bolted to the wall.
	var floor_y := first.y - height * 0.5
	var lo := Vector3(first.x, floor_y, first.z) - row * (radius + 0.03)
	var hi := Vector3(last.x, floor_y, last.z) + row * (radius + 0.03)
	var mid := (lo + hi) * 0.5
	var span := lo.distance_to(hi)
	k._box(parent, Vector3(span, 0.025, radius * 2.0 + 0.06), mid + Vector3(0, -0.0005, 0), mat, col, rb.get_euler())
	k._box(parent, Vector3(span, 0.06, 0.012), mid - b * (radius + 0.024) + Vector3(0, 0.03, 0), mat, col, rb.get_euler())
	var behind := b * (radius + 0.015)
	for end: Vector3 in [lo, hi]:
		VehicleFrames.beam(k, parent, end + behind, end + behind + Vector3.UP * height * 0.8, 0.03, 0.025, mat, col)
		VehicleBody.fastener(k, parent, end + behind + Vector3.UP * height * 0.75 - b * 0.0135, -b, 0.008)
	for f: float in [0.3, 0.72]:
		VehicleFrames.beam(k, parent, lo + behind + Vector3.UP * height * f, hi + behind + Vector3.UP * height * f, 0.025, 0.025, mat, col)


## A seamless steel gas bottle standing on its foot ring, its domed shoulder
## up to `height`; drawn along Z (revolved), stood up by its caller.
static func _bottle(radius: float, height: float) -> ArrayMesh:
	var r := radius
	var h := height
	return VehicleProfiles.revolve([Vector2(0, 0.02), Vector2(r * 0.86, 0.0), Vector2(r, 0.04), Vector2(r, h - r * 0.9), Vector2(r * 0.84, h - r * 0.36), Vector2(r * 0.5, h - r * 0.06), Vector2(r * 0.36, h), Vector2(0, h)], 12, 40.0)


## A 200-litre steel drum (a 55-gallon oil or fuel drum): the old cylinder's
## `center`, `radius` and `length`, its `axis` running from the bottom head to
## the top (UP for a drum standing, along the bed or hull for one lying). Each
## head is pressed in a centimetre or so below the rolled chime round its rim;
## two rolling hoops ride round the body `hoop` either side of its middle (0:
## the usual 18% of the length), and the top head carries the 2-inch filler
## bung toward `bung` (a direction across the head; zero picks one) and the
## 3/4-inch vent bung opposite, outside a pressed stiffening ring. `col` is the
## paint (several families pick it per drum or per seed: they pass it in).
## `straps` are offsets along the axis of the steel bands that hold a drum on
## its brackets, each drawn tight by a bolted lug on the side toward `bung`;
## the brackets themselves stay with the caller. Drums ride in loads by the
## dozen, so the shell is one revolved profile `segments` round, cached by
## size, with no hidden caps. Stays within the old cylinder but for 1 cm round
## the chimes and hoops, the bungs standing under 2 cm proud of the top chime
## and 4 cm of strap lug.
static func drum(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, axis := Vector3.UP, mat := "paint", col := Color(0.28, 0.31, 0.22), bung := Vector3.ZERO, hoop := 0.0, straps: Array = [], segments := 12) -> void:
	var up := axis.normalized() if not axis.is_zero_approx() else Vector3.UP
	var m := k._pivot(parent, center)
	m.basis = VehicleFrames.aim(up)
	var r := radius
	var h := length * 0.5
	var c := r * 0.042
	var head := h - c
	k._add(m, _drum_shell(r, length, hoop if hoop > 0.0 else length * 0.18, segments), mat, col, Vector3.ZERO, Vector3(-PI / 2, 0, 0))
	# The bungs on a diameter of the top head, out near the chime.
	var across := m.basis.inverse() * (bung - up * bung.dot(up))
	across.y = 0.0
	across = across.normalized() if across.length() > 0.001 else Vector3.RIGHT
	var big := across * r * 0.68 + Vector3(0, head, 0)
	k._add(m, VehicleProfiles.revolve([Vector2(r * 0.13, 0.0), Vector2(r * 0.13, 0.006), Vector2(r * 0.095, 0.006), Vector2(r * 0.095, 0.018), Vector2(0, 0.018)], 8), "gunmetal_w", null, big, Vector3(-PI / 2, 0, 0), Vector3.ONE, false)
	k._box(m, Vector3(r * 0.15, 0.008, 0.012), big + Vector3(0, 0.022, 0), "gunmetal_w", null, Vector3(0, atan2(across.x, across.z), 0), false)
	k._add(m, VehicleProfiles.revolve([Vector2(r * 0.085, 0.0), Vector2(r * 0.085, 0.006), Vector2(r * 0.06, 0.006), Vector2(r * 0.06, 0.016), Vector2(0, 0.016)], 6), "gunmetal_w", null, -across * r * 0.7 + Vector3(0, head, 0), Vector3(-PI / 2, 0, 0), Vector3.ONE, false)
	if not straps.is_empty():
		# The strap's lug: on the side toward the filler bung, and level on a
		# drum lying down, where a spanner reaches it from the side.
		var lying := absf(up.y) < 0.9
		var side := bung - up * bung.dot(up)
		if lying:
			side.y = 0.0
		if side.length() < 0.001:
			side = up.cross(Vector3.UP) if lying else Vector3.RIGHT
		var lug := m.basis.inverse() * side
		lug.y = 0.0
		lug = lug.normalized()
		var tangent := lug.cross(Vector3.UP)
		var turn := Vector3(0, atan2(lug.x, lug.z), 0)
		var band := r + 0.006
		for off: float in straps:
			# The band's faces are 6 mm rims on the shell: an open band reads the same.
			_cyl(k, m, band, band, 0.04, Vector3(0, off, 0), Vector3.ZERO, "gunmetal_w", null, segments, true, 0)
			var foot := lug * (band + 0.012) + Vector3(0, off, 0)
			for edge: float in [-1.0, 1.0]:
				k._box(m, Vector3(0.012, 0.04, 0.03), foot + tangent * edge * 0.014, "gunmetal_w", null, turn, false)
			VehicleFrames.tube(k, m, foot + tangent * 0.03, foot - tangent * 0.03, 0.006, "steel", null, 6, false)
	k._fold(m)


## The drum's shell along +Z, revolved from one profile: the bottom head
## pressed in below its rolled chime, the body with its two rolling hoops
## `hoop` either side of the middle, the top chime, and the top head with its
## stiffening ring. Cached by size.
static func _drum_shell(r: float, length: float, hoop: float, segments: int) -> ArrayMesh:
	var h := length * 0.5
	var c := r * 0.042
	var profile := [Vector2(0, -h + c), Vector2(r - c * 1.35, -h + c), Vector2(r - c * 0.2, -h), Vector2(r + c * 0.65, -h + c), Vector2(r, -h + c * 2.0)]
	for end: float in [-1.0, 1.0]:
		profile.append_array([Vector2(r, end * hoop - c * 0.8), Vector2(r + c * 0.7, end * hoop), Vector2(r, end * hoop + c * 0.8)])
	profile.append_array([Vector2(r, h - c * 2.0), Vector2(r + c * 0.65, h - c), Vector2(r - c * 0.2, h), Vector2(r - c * 1.35, h - c)])
	profile.append_array([Vector2(r * 0.53, h - c), Vector2(r * 0.5, h - c * 0.6), Vector2(r * 0.47, h - c), Vector2(0, h - c)])
	return VehicleProfiles.revolve(profile, segments, 30.0)
