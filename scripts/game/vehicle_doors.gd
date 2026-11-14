class_name VehicleDoors
extends RefCounted
## Closed access leaves share edge treatment and hardware. The caller supplies
## its surface and anchors; opening animation remains owned by the vehicle.

const X90 := Vector3(PI / 2, 0, 0)

const STYLES := {
	"light": {"sheet": 0.012, "pin": 0.010, "grip": 0.009},
	"utility": {"sheet": 0.020, "pin": 0.014, "grip": 0.012},
	"armored": {"sheet": 0.035, "pin": 0.019, "grip": 0.014},
}

static func closed(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, hinges: Array[Vector2], handle: Vector2, mat: String, col = null, style := "utility", divisions := 0) -> void:
	assert(STYLES.has(style))
	var spec: Dictionary = STYLES[style]
	var thickness: float = spec.sheet
	VehicleBody.fitted(k, parent, surface, outline, mat, col, thickness, divisions, style == "armored")
	for uv in hinges:
		# The hinge's outer straps are screwed to the leaf, so they reach
		# toward the handle side of the door: a left-hand door's hinges are
		# the mirror image of a right-hand one's.
		var normal := surface.normal(uv)
		var up := _up(surface, uv)
		var toward := surface.point(handle) - surface.point(uv)
		hinge(k, parent, surface.point(uv, thickness), normal, up, spec.pin, mat, col, toward.dot(up.cross(normal)) > 0.0)
	pull(k, parent, surface.point(handle, thickness), surface.normal(handle), _up(surface, handle).cross(surface.normal(handle)), 0.14, spec.grip)

static func _up(surface: VehicleSurface, uv: Vector2) -> Vector3:
	return (surface.point(uv + Vector2(0, 0.001)) - surface.point(uv - Vector2(0, 0.001))).normalized()

## Independent fittings also serve storage lids, tailgates and cabin ramps.
## `mirror` swings the straps to the other side of the pin (the middle
## knuckle's onto the side the outer two had), the hinge of the opposite door
## of a pair; it is the same hinge as one given `axis` reversed.
static func hinge(k: VehicleModels, parent: Node3D, at: Vector3, normal: Vector3, axis: Vector3, radius := 0.014, mat := "paint", col = null, mirror := false) -> void:
	var tangent := axis.cross(normal).normalized() * (-1.0 if mirror else 1.0)
	var pin := at + normal * radius
	# The pin shows only in the gaps between the knuckles: six sides, its ends
	# inside the heads. Each peened head's inner face looks at the knuckle
	# 3 mm away, so only its outer face is closed.
	VehicleBody.rod(k, parent, pin - axis * radius * 2.8, pin + axis * radius * 2.8, radius * 0.52, "steel", null, 6, false, -1.0, false, false)
	for side: float in [-1.0, 1.0]:
		var end := pin + axis * side * radius * 2.8
		VehicleBody.rod(k, parent, end - axis * side * radius * 0.18, end + axis * side * radius * 0.18, radius * 0.76, "steel", null, 6, false, -1.0, false, true)
	for i in 3:
		var middle := pin + axis * (i - 1) * radius * 1.7
		VehicleBody.rod(k, parent, middle - axis * radius * 0.72, middle + axis * radius * 0.72, radius, mat, col, 8, false)
		var foot := middle + tangent * radius * (2.2 if i == 1 else -2.2) - normal * radius
		VehicleFrames.beam(k, parent, middle - normal * radius * 0.6, foot, radius * 1.3, radius * 0.65, mat, col)
		VehicleBody.fastener(k, parent, foot, normal, radius * 0.38)

static func pull(k: VehicleModels, parent: Node3D, at: Vector3, normal: Vector3, along: Vector3, length := 0.14, radius := 0.012, mat := "metal_dark", col = null) -> void:
	var a := at - along.normalized() * length * 0.5
	var b := at + along.normalized() * length * 0.5
	var rise := normal.normalized() * radius * 2.7
	var basis := VehicleFrames.aim(normal)
	# Each foot's screw lies under its standoff, inside the post and its pad,
	# so none is drawn; the post's own foot stands in the pad. A pad's chamfer
	# under 2.5 mm is less than a pixel, so a pad that small is a plain plate.
	var pad := Vector3(radius * 3.2, radius * 0.45, radius * 3.2)
	var plate: Mesh = BevelMesh.make(pad, radius * 0.12) if radius * 0.12 >= 0.0025 else Res.box(pad)
	for p in [a, b]:
		k._add(parent, plate, mat, col, p, basis.get_euler())
		VehicleBody.rod(k, parent, p, p + rise, radius, mat, col, 6, false, -1.0, false, true)
	VehicleBody.rod(k, parent, a + rise, b + rise, radius, mat, col, 8, false)

static func rectangle(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, mat: String, col = null, style := "utility") -> void:
	var basis := Basis.from_euler(rotation)
	var surface := VehicleSurface.plane(center - basis.x * size.x * 0.5 - basis.y * size.y * 0.5, basis.x * size.x, basis.y * size.y)
	var hinge_x := 0.92 if basis.x.z < 0.0 else 0.08
	closed(k, parent, surface, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), [Vector2(hinge_x, 0.2), Vector2(hinge_x, 0.8)], Vector2(1.0 - hinge_x, 0.72), mat, col, style)


## Leaf only: retain existing authored hinges, handles, glazing and animation.
## Axis is the panel thickness axis (0 X, 1 Y, 2 Z). This also serves gear doors
## and ramp panels whose hardware differs from a passenger door. The sealed
## face (gasket and folded edge) looks along +axis; `facing` -1 turns it to
## -axis within the same slab, for the other door of a mirrored pair.
static func leaf(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO, axis := 2, facing := 1.0) -> void:
	var basis := Basis.from_euler(rotation)
	var u := Vector3.RIGHT
	var v := Vector3.UP
	var dims := Vector2(size.x, size.y)
	if axis == 0:
		u = Vector3.FORWARD
		dims = Vector2(size.z, size.y)
	elif axis == 1:
		v = Vector3.FORWARD
		dims = Vector2(size.x, size.z)
	if facing < 0.0:
		u = -u
	var normal := u.cross(v)
	var origin := center - basis * (u * dims.x * 0.5 + v * dims.y * 0.5 + normal * size[axis] * 0.5)
	var surface := VehicleSurface.plane(origin, basis * u * dims.x, basis * v * dims.y)
	VehicleBody.fitted(k, parent, surface, PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), mat, col, size[axis], 0, false)


## A lever door handle on an armoured door, a hatch or a locker: a round
## cast boss bolted to the door, the spindle standing out of it, the lever
## on the spindle's end (a round boss, the flat bar, a round grip) and the
## latch keeper on the door that the lever's tip drops into when it is shut.
## `at` is the spindle's foot on the door's outer face, `normal` the face's
## outward normal and `along` the way the lever points from its spindle (laid
## flat in the face). `length` runs from the spindle to the tip of the grip,
## `reach` from the face to the lever's outer side, `radius` is half the bar's
## width and sizes the rest. The boss reaches 1.75 radii round the spindle.
## An old stub handle standing out of a door becomes a lever as far out
## (`reach` its protrusion); an old bar lying on a door keeps its length and
## depth with `at` 1.75 radii in from the bar's back end and `length` the rest.
static func lever(k: VehicleModels, parent: Node3D, at: Vector3, normal: Vector3, along: Vector3, length := 0.16, reach := 0.06, radius := 0.02, mat := "gunmetal_w", col = null) -> void:
	var z := normal.normalized()
	var x := (along - z * along.dot(z)).normalized()
	if x.is_zero_approx():
		x = (Vector3.UP - z * z.y).normalized() if absf(z.y) < 0.95 else Vector3.RIGHT
	var mount := k._pivot(parent, at)
	mount.basis = Basis(x, z.cross(x), z)
	var r := radius
	var bar := minf(r, reach * 0.4)
	var mid := reach - bar * 0.5
	var flange := minf(r * 0.45, reach * 0.25)
	# (the boss's back is on the door and the spindle's ends are in the boss
	# and the lever's hub, so those faces are left open)
	VehicleBody.cylinder(k, mount, r * 1.6, r * 1.75, flange, Vector3(0, 0, flange * 0.5), X90, mat, col, 8, false, true, false)
	for s: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(0, s * r * 1.25, flange), Vector3.BACK, r * 0.3)
	if reach - bar > flange + 0.002:
		VehicleBody.cylinder(k, mount, r * 0.7, r * 0.85, reach - bar - flange, Vector3(0, 0, (flange + reach - bar) * 0.5), X90, "steel", null, 6, false, false, false)
	var tip := maxf(length - r * 0.75, r)
	VehicleBody.cylinder(k, mount, r * 1.15, r * 1.15, bar, Vector3(0, 0, mid), X90, mat, col, 8, false)
	VehicleFrames.beam(k, mount, Vector3(0, 0, mid), Vector3(tip, 0, mid), r * 1.4, bar, mat, col, false)
	VehicleBody.cylinder(k, mount, r * 0.75, r * 0.75, bar * 1.2, Vector3(tip, 0, mid - bar * 0.1), X90, mat, col, 6, false)
	# The keeper: two cheeks welded to the door either side of the grip.
	for s: float in [-1.0, 1.0]:
		k._box(mount, Vector3(r * 1.3, r * 0.3, mid), Vector3(tip, s * r * 0.9, mid * 0.5), mat, col, Vector3.ZERO, false)
	k._fold(mount)


## A piano hinge: one long continuous hinge down an edge (a fold-down door
## or step, a trim vane): a row of knuckles (curled alternately from each
## leaf) on one pin with peened ends, and the two leaves riveted either side
## of the hinge line, one onto the hull and one onto the door. `a` and `b` are the ends of the
## old hinge bar or rod along its long axis and `radius` its radius (half its
## smaller cross size); `normal` is the outward normal of the face it lies on.
## The knuckles stay on the line from `a` to `b`, the pin's heads stand 0.35
## radii past each end, and the leaves lie behind the knuckles, reaching 2.4
## radii either side of the line. `knuckles` 0 spaces them about 5 radii apart.
static func piano_hinge(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, radius: float, normal: Vector3, mat := "gunmetal_w", col = null, knuckles := 0) -> void:
	var length := a.distance_to(b)
	if length < radius:
		return
	var axis := (b - a) / length
	var z := (normal - axis * normal.dot(axis)).normalized()
	var across := axis.cross(z)
	var n := knuckles if knuckles > 0 else clampi(roundi(length / (radius * 5.0)), 3, 31)
	if knuckles <= 0 and (n & 1) == 0:
		n += 1
	var pitch := length / n
	var gap := minf(pitch * 0.06, radius * 0.25)
	for i in n:
		var c := a + axis * (pitch * (i + 0.5))
		VehicleBody.rod(k, parent, c - axis * (pitch - gap) * 0.5, c + axis * (pitch - gap) * 0.5, radius, mat, col, 6, false)
	# (the pin's heads stand on the end knuckles' faces)
	VehicleBody.rod(k, parent, a, a - axis * radius * 0.35, radius * 0.55, "steel", null, 6, false, -1.0, false, true)
	VehicleBody.rod(k, parent, b, b + axis * radius * 0.35, radius * 0.55, "steel", null, 6, false, -1.0, false, true)
	var euler := Basis(across, axis, z).get_euler()
	var rivets := 3 if length > radius * 30.0 else 2
	for s: float in [-1.0, 1.0]:
		var line := across * s * radius * 1.3 - z * radius * 0.7
		k._box(parent, Vector3(radius * 2.2, length, radius * 0.3), (a + b) * 0.5 + line, mat, col, euler, false)
		for i in rivets:
			var t := lerpf(0.12, 0.88, float(i) / (rivets - 1))
			VehicleBody.fastener(k, parent, a.lerp(b, t) + line + across * s * radius * 0.4 + z * radius * 0.15, z, radius * 0.32)


## The rail a sliding door runs on (a helicopter's cabin door): a channel laid
## along the skin, its two flanges standing proud of a recessed web, a stop at
## each end and bolts along the web. `surface` maps the rail onto the skin: q.x
## runs along it from 0 to 1, q.y across it from 0 to 1 (either way up: the
## channel is symmetric), and lift 0 is the skin itself. `length` is the rail's length in metres (it sets
## the stations along a curved skin and the bolts' spacing), `lift` how far
## the flanges stand out of the skin and `depth` how far the rail is seated
## below it, as the old strip's. Doors and their animation stay with the family.
static func slide_rail(k: VehicleModels, parent: Node3D, surface: VehicleSurface, length: float, lift := 0.02, depth := 0.03, mat := "gunmetal_w", col = null) -> void:
	var stations := clampi(ceili(length / 0.3), 1, 16)
	for band: Vector2 in [Vector2(0.0, 0.24), Vector2(0.76, 1.0)]:
		k._add(parent, surface.patch(_band(stations, 0.0, 1.0, band.x, band.y), lift, lift + depth), mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	k._add(parent, surface.patch(_band(stations, 0.0, 1.0, 0.24, 0.76), lift * 0.45, lift * 0.45 + depth), mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var stop := clampf(0.035 / maxf(length, 0.01), 0.005, 0.2)
	for end: Vector2 in [Vector2(0.0, stop), Vector2(1.0 - stop, 1.0)]:
		k._add(parent, surface.patch(_band(1, end.x, end.y, 0.0, 1.0), lift * 1.4, lift * 1.4 + depth), mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var bolts := clampi(roundi(length / 1.0), 2, 4)
	for i in bolts:
		var q := Vector2(lerpf(0.1, 0.9, float(i) / (bolts - 1)), 0.5)
		VehicleBody.fastener(k, parent, surface.point(q, lift * 0.45), surface.normal(q), minf(0.008, lift * 0.5))


## A band of a rail's domain from u0 to u1 along it and v0 to v1 across,
## split at `stations` points along so it bends with a curved skin.
static func _band(stations: int, u0: float, u1: float, v0: float, v1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in stations + 1:
		out.append(Vector2(lerpf(u0, u1, float(i) / stations), v0))
	for i in range(stations, -1, -1):
		out.append(Vector2(lerpf(u0, u1, float(i) / stations), v1))
	return out
