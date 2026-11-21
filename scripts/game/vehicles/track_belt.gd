extends MultiMeshInstance3D
## One draw call per belt. The contacting run travels backwards at ground speed.
var loop := Curve2D.new()
var phase := 0.0
var wheel_nodes: Array[Node3D] = []
var centers := PackedVector3Array()
var travel := PackedFloat32Array()
var shoe_width := 0.0
var printed_at := Vector3.INF
var printed_end := -1
var pitch := 0.0
var radii := PackedFloat32Array()
var half_thickness := 0.0
var turn_sign := 1.0
var rests_on_wheels := false
var free_spans := PackedVector2Array()
var dust: GeometryInstance3D

func build(hull: PackedVector2Array, width: float, thickness: float, wheels: Array, unsupported_return: bool) -> void:
	shoe_width = width
	rests_on_wheels = unsupported_return
	loop.bake_interval = 0.07
	half_thickness = thickness * 0.5
	var middle := Vector2.ZERO
	for p in hull:
		loop.add_point(p)
		middle += p
	middle /= maxf(1.0, float(hull.size()))
	# The free spans of the return run between the rollers it rests on (each
	# as its two ends, nose first), which hang as VehicleTracks.shoes hangs
	# them; a longer run has rollers the outline leaves out.
	if not rests_on_wheels:
		for i in hull.size():
			var a := hull[i]
			var b := hull[(i + 1) % hull.size()]
			var span := absf(b.x - a.x)
			if span > 0.3 and span < VehicleTracks.SAG_SPAN and a.y + b.y > middle.y * 2.0 and absf(b.y - a.y) < 0.2 * span:
				free_spans.append(a if a.x < b.x else b)
				free_spans.append(b if a.x < b.x else a)
	# Geometry2D's lower edge runs toward +Z for a counterclockwise outline.
	turn_sign = -1.0 if Geometry2D.is_polygon_clockwise(hull) else 1.0
	for wheel: Node3D in wheels:
		if is_equal_approx(position.x, wheel.position.x):
			wheel_nodes.append(wheel)
			centers.append(wheel.position)
			radii.append(wheel.get_meta(&"radius"))
	travel.resize(centers.size())
	var length := loop.get_baked_length()
	var count := roundi(length / (0.20 if rests_on_wheels else 0.166))
	pitch = length / count
	# The last wheel is the drive sprocket. One tooth engages one shoe,
	# so its effective rolling radius is set by the assembled belt.
	var teeth := int(wheel_nodes.back().get_meta(&"teeth", 0))
	if teeth > 0:
		radii[-1] = teeth * pitch / TAU
	var shoe := SurfaceTool.new()
	shoe.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steel := Color("51483d")
	var worn := Color("786e5d")
	var rubber := Color("302e29")
	# Steel the road wheels roll on and the ground wears is rubbed bright: the
	# inner face of each link or shoe and the guide horns' flanks.
	var rubbed := Color("8a857a")
	if rests_on_wheels:
		# A track without return rollers is the old Soviet single-pin steel
		# track (the T-55's): VehicleTracks' cast link with its grouser, the
		# hinge lugs that interleave with the next link's on the pin, and the
		# guide horn, polished bright by the road wheels it runs between.
		var link: Array = VehicleTracks._link(width, thickness, pitch, false, 0.0)
		_part(shoe, link[0], Transform3D.IDENTITY, steel, rubbed, Vector3.UP)
		_part(shoe, link[2], Transform3D.IDENTITY, worn)
		_finish(shoe, count)
		return
	# Otherwise a western double-pin track (the Abrams' and Bradley's): each
	# shoe's body round its two pins with its two rubber pads; the end
	# connectors and the centre guide clamp the pins of the next shoe, so
	# they sit on the hinge between shoes. The projecting pin ends and the
	# pads give the silhouette a different shape on the bend. The running
	# surface meets the tyre; the centre guide passes between the paired
	# road wheels.
	_part(shoe, Res.box(Vector3(width * 0.92, thickness * 0.72, pitch * 0.91)), Transform3D.IDENTITY, steel, rubbed, Vector3.UP)
	for side: float in [-1.0, 1.0]:
		var pad := Res.box(Vector3(width * 0.40, thickness * 0.30, pitch * 0.84))
		var xf := Transform3D(Basis(Vector3.UP,side * 0.09),Vector3(side * width * 0.226,-thickness * 0.45,0))
		_part(shoe,pad,xf,rubber)
		var end := Vector3(side * width * 0.47,0,pitch * 0.47)
		var connector := Res.box(Vector3(width * 0.071,thickness * 0.64,pitch * 0.78))
		_part(shoe,connector,Transform3D(Basis.IDENTITY,end),steel)
		var head := Res.cyl(thickness * 0.17,thickness * 0.19,width * 0.018,8)
		for pin: float in [-1.0,1.0]:
			var center := end + Vector3(side * width * 0.042,0,pin * pitch * 0.23)
			_part(shoe,head,Transform3D(Basis(Vector3.FORWARD,PI / 2),center),worn)
	var base := PackedVector2Array([Vector2(-0.036,-pitch*0.27),Vector2(0.036,-pitch*0.27),Vector2(0.036,pitch*0.27),Vector2(-0.036,pitch*0.27)])
	var tip := PackedVector2Array([Vector2(-0.014,-pitch*0.11),Vector2(0.014,-pitch*0.11),Vector2(0.014,pitch*0.11),Vector2(-0.014,pitch*0.11)])
	var guide := VehicleModels.solid([VehicleModels.ring_y(base,thickness*0.32),VehicleModels.ring_y(tip,thickness*1.15)],"track_horn_%.3f_%.3f" % [pitch,thickness])
	_part(shoe,guide,Transform3D(Basis.IDENTITY,Vector3(0,0,pitch * 0.5)),steel,rubbed,Vector3.RIGHT)
	_finish(shoe, count)


## The shoe's material and the multimesh of `count` of them, posed.
func _finish(shoe: SurfaceTool, count: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.metallic = 0.26
	mat.roughness = 0.83
	shoe.set_material(mat)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = shoe.commit()
	multimesh.instance_count = count
	for i in count:
		var shade := 0.85 + 0.15 * fposmod(i * 0.618, 1.0)
		multimesh.set_instance_color(i, Color(shade, shade, shade, 1))
	_pose()

## A part of the shoe in `color`; given a `rub` colour, its faces turned
## along `along` (either way, in the shoe's space) take that instead.
func _part(shoe: SurfaceTool, mesh: Mesh, xf: Transform3D, color: Color, rub := Color(0, 0, 0, 0), along := Vector3.UP) -> void:
	var triangles := Mats._flat(mesh,0)
	var points: PackedVector3Array = triangles[0]
	var normals: PackedVector3Array = triangles[1]
	for i in points.size():
		var n := xf.basis * normals[i]
		shoe.set_color(rub if rub.a > 0.0 and absf(n.normalized().dot(along)) > 0.6 else color)
		shoe.set_normal(n)
		shoe.add_vertex(xf * points[i])

func advance(distance: float, ground: Callable) -> void:
	phase = fposmod(phase + distance * turn_sign, loop.get_baked_length())
	var changed := not is_zero_approx(distance)
	for i in centers.size():
		var wheel := wheel_nodes[i]
		var center := centers[i]
		var radius := radii[i]
		wheel.rotation.x -= distance / radius
		if i >= centers.size() - 2:
			continue
		var sole := to_global(Vector3(0, center.y - radius - half_thickness * 2.0, center.z))
		var displacement := clampf((float(ground.call(sole)) - sole.y) / global_basis.y.y, -0.24, 0.24)
		changed = changed or absf(displacement - travel[i]) > 0.0001
		travel[i] = displacement
		wheel.position.y = center.y + displacement
	if changed:
		_pose()

func print_ground(fx: Vfx, distance: float) -> void:
	if is_zero_approx(distance):
		return
	var end := centers.size() - 3 if distance > 0.0 else 0
	var contact := wheel_nodes[end].global_position
	if end != printed_end or not printed_at.is_finite() or Defs.flat(contact - printed_at).length_squared() > 4.0:
		printed_at = contact
		printed_end = end
	var delta := Defs.flat(contact - printed_at)
	var length := delta.length()
	var count := floori(length / pitch)
	if count > 0:
		var step := delta / length * pitch
		for i in count:
			printed_at += step
			printed_at.y = contact.y
			fx.tread_print(printed_at, -global_basis.z, shoe_width, pitch)


## Dust lifts where a shoe peels away from the soil. That end of the
## contact run changes on reversing, even on one side of a pivot turn.
func stir_dust(speed: float) -> void:
	if not dust:
		return
	var moving := absf(speed) > 0.65
	if moving:
		var i := centers.size() - 3 if speed > 0.0 else 0
		dust.position = Vector3(0, wheel_nodes[i].position.y - radii[i] + 0.05, centers[i].z)
	if moving != Vfx.is_emitting(dust):
		Vfx.set_emitting(dust, moving)


func _point(offset: float) -> Vector2:
	var p := loop.sample_baked(fposmod(offset, loop.get_baked_length()))
	# Road wheels are stored nose to tail, then the fixed idler and sprocket.
	# Blend into the two fixed ends and leave the upper return run on its rollers.
	var lift := 0.0
	var sag := 0.0
	for i in centers.size() - 2:
		var prev := centers.size() - 2 if i == 0 else i - 1
		var next := centers.size() - 1 if i == centers.size() - 3 else i + 1
		var z := centers[i].z
		if p.x >= centers[prev].z and p.x <= centers[next].z:
			if rests_on_wheels and p.x >= z and next == i + 1 and next < centers.size() - 2:
				var span := centers[next].z - z
				var fraction := (p.x - z) / span
				sag = 0.035 * span * sin(PI * fraction) * sin(PI * fraction)
			var edge := centers[prev].z if p.x < z else centers[next].z
			lift += travel[i] * (1.0 - absf((p.x - z) / (edge - z)))
	# Over return rollers the run hangs about 2 cm a metre of free span.
	for j in range(0, free_spans.size(), 2):
		var a := free_spans[j]
		var b := free_spans[j + 1]
		if p.x > a.x and p.x < b.x:
			var fraction := (p.x - a.x) / (b.x - a.x)
			if absf(p.y - lerpf(a.y, b.y, fraction)) < 0.01:
				sag = 0.02 * (b.x - a.x) * sin(PI * fraction) * sin(PI * fraction)
				break
	var top := smoothstep(0.18, 0.60, p.y)
	p.y += lerpf(lift, lift - sag if rests_on_wheels else -sag, top)
	return p

## The exporter can sample the same rig without reading a GPU instance buffer.
func shoe_pose(index: int) -> Transform3D:
	var start := phase + index * pitch
	return _shoe_between(_point(start), _point(start + pitch))

func _shoe_between(a: Vector2, b: Vector2) -> Transform3D:
	var mid := (a + b) * 0.5
	var angle := atan2(a.y - b.y, b.x - a.x)
	return Transform3D(Basis(Vector3.RIGHT, angle), Vector3(0, mid.y, mid.x))

func _pose() -> void:
	var a := _point(phase)
	for i in multimesh.instance_count:
		var b := _point(phase + (i + 1) * pitch)
		multimesh.set_instance_transform(i, _shoe_between(a, b))
		a = b
