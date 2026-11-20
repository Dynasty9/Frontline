class_name RainCover
extends RefCounted
## What keeps the rain off: the roofs over the town's houses and the camp's
## huts, for the shader every building, vehicle and soldier is drawn with
## (Mats.RAIN_COVER). Rain falls near enough straight down, so a wall under
## its eaves stays dry but for the band at its foot that the drops splash back
## onto, a gable end stays dry under its barge boards, and the rooms, floors
## and furniture inside stay dry altogether; a ruin with its roof fallen in
## takes the rain like the street.
##
## One float texture holds it: its first rows cut the map into CELL-metre
## squares, each naming up to four of the roofs over it; the rows after hold
## each roof's own lines (its middle and axes, the half-size of its walls, its
## eaves and its floor, its pitch and form), so the dry edge falls where the
## roof's underside does however coarse the squares.

const CELL := 4.0
## How far past its walls' outer faces a roof reaches (m): the eaves' and
## barge boards' overhang (BuildingRoofs, 0.35 m) and a little spare.
const REACH := 0.45
const SLOTS := 4
const TEXELS := 3  # a roof's texels in the table
## A roof's form, as the shader reads it.
const FLAT := 0.0
const GABLED := 1.0
const HIPPED := 2.0
## The buildings whose roofs are part of their own model (Structure._build_model):
## their eaves over the floor (m) and the rise to the ridge (0: flat, under a slab).
const BUILDINGS := {
	"barracks": [3.0, 1.5],  # a weatherboard hut under a sheeted gable
	"factory": [5.0, 0.0],  # a sheeted shed under a slab
	"research": [3.2, 0.0],  # a precast block under a slab
}

var _houses: Array = []  # every house roof as of the last count
var _roofs: Array[Structure] = []
var _seen := -1
var _pending := 0  # a roof's model wasn't built yet: look again (this many more times)
var _texture: ImageTexture


## Rebuilds the cover when a roof has come or gone (a house knocked down, a
## hut finished, or the map still arriving), and keeps the shader's copy current.
func refresh(world: World) -> void:
	if world.structures.size() != _seen:
		_seen = world.structures.size()
		_houses.clear()
		for e in world.structures:
			if (e as Structure).skind == "roof":
				_houses.append(e)
	var roofs: Array[Structure] = []
	for e in _houses:
		if is_instance_valid(e) and not (e as Structure).gone:
			roofs.append(e)
	for st in world.sim_structures:
		if is_instance_valid(st) and not st.gone and st.built and BUILDINGS.has(st.skind):
			roofs.append(st)
	# (sandbags going up and craters coming and going don't move a roof)
	if roofs == _roofs and _texture and _pending <= 0:
		return
	var waiting := _pending - 1 if roofs == _roofs else 10
	_roofs = roofs
	_pending = 0
	for st in _roofs:
		if st.skind == "roof" and st.roof_pitch < 0.0:
			_pending = waiting
			break
	var image := build(_roofs)
	if _texture and _texture.get_size() == Vector2(image.get_size()):
		_texture.update(image)
	else:
		_texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set(&"rain_cover", _texture)
	RenderingServer.global_shader_parameter_set(&"rain_cover_map", Vector4(-MapDims.HALF, -MapDims.HALF, CELL, float(image.get_width())))


## Takes the cover away (the rain has stopped, or the world is going).
func clear() -> void:
	_roofs.clear()
	_houses.clear()
	_seen = -1
	RenderingServer.global_shader_parameter_set(&"rain_cover_map", Vector4.ZERO)


## The cover texture for these roofs: n x n squares (each the 1-based numbers
## of up to four roofs over it, 0 for none), then three texels a roof
## (Mats.RAIN_COVER reads them back).
static func build(roofs: Array[Structure]) -> Image:
	var n := maxi(TEXELS, ceili(MapDims.SIZE / CELL))
	var per_row := floori(n / float(TEXELS))
	var rows := maxi(1, ceili(roofs.size() / float(per_row)))
	var data := PackedFloat32Array()
	data.resize(n * (n + rows) * 4)
	data.fill(0.0)
	for i in roofs.size():
		var st := roofs[i]
		var c := Vector2(st.position.x, st.position.z)
		var ax := Vector2(cos(st.yaw), -sin(st.yaw))  # (Defs.point_in_obb's axes)
		var half := Vector2(st.size.x, st.size.z) * 0.5
		var eave := st.position.y + st.size.y
		# (a house roof whose model isn't built yet is taken for a gabled one at 30 degrees)
		var pitch := st.roof_pitch if st.roof_pitch >= 0.0 else 30.0
		var hipped := st.roof_hipped
		if BUILDINGS.has(st.skind):
			# (their walls' outer faces are on the footprint's edge, 0.2 m
			# out from the line a house's walls are measured along)
			var hut: Array = BUILDINGS[st.skind]
			half -= Vector2.ONE * 0.2
			eave = st.position.y + float(hut[0])
			pitch = rad_to_deg(atan2(float(hut[1]), minf(st.size.x, st.size.z) * 0.5))
			hipped = false
		var form := FLAT if pitch == 0.0 else (HIPPED if hipped else GABLED)
		var row := floori(i / float(per_row))
		var o := ((n + row) * n + (i - row * per_row) * TEXELS) * 4
		data[o] = c.x
		data[o + 1] = c.y
		data[o + 2] = ax.x
		data[o + 3] = ax.y
		data[o + 4] = half.x
		data[o + 5] = half.y
		data[o + 6] = eave
		data[o + 7] = st.position.y
		data[o + 8] = tan(deg_to_rad(pitch))
		data[o + 9] = form
		# the squares its eaves reach over
		var r := half + Vector2.ONE * (0.2 + REACH)
		var ext := Vector2(absf(ax.x) * r.x + absf(ax.y) * r.y, absf(ax.y) * r.x + absf(ax.x) * r.y)
		var lo := ((c - ext) / CELL + Vector2.ONE * (MapDims.HALF / CELL)).floor()
		var hi := ((c + ext) / CELL + Vector2.ONE * (MapDims.HALF / CELL)).floor()
		for cy in range(maxi(0, int(lo.y)), mini(n - 1, int(hi.y)) + 1):
			for cx in range(maxi(0, int(lo.x)), mini(n - 1, int(hi.x)) + 1):
				var at := (cy * n + cx) * 4
				for k in SLOTS:
					if data[at + k] == 0.0:
						data[at + k] = float(i + 1)
						break
	return Image.create_from_data(n, n + rows, false, Image.FORMAT_RGBAF, data.to_byte_array())
