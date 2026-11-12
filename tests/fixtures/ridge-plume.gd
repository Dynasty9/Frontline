extends MeshInstance3D
## The smoke field is sampled in world space so it stays upright on a sloping hull.
const EXTENT := Vector3(14,12,6)
const SOURCE := Vector3(2,0.5,3)
const BAKE := "res://tests/fixtures/ridge-light/engine-fire.bin"

var frames: Array[PackedByteArray] = []
var first := ImageTexture.new()
var second := ImageTexture.new()
var material := ShaderMaterial.new()
var previous := -2
var scale_factor := 1.0

static func read_bake() -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	var source := FileAccess.open(BAKE,FileAccess.READ)
	if not source:
		return result
	var count := source.get_32()
	for i in count:
		result.append(source.get_buffer(source.get_32()))
	return result

func setup(bake: Array[PackedByteArray], size: float) -> void:
	frames = bake
	scale_factor = size
	var box := BoxMesh.new()
	box.size = EXTENT * size
	mesh = box
	material.shader = preload("res://tests/fixtures/ridge-plume.gdshader")
	material.set_shader_parameter("extent",box.size)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func _decode(index: int, target: ImageTexture) -> void:
	var pixels := Image.new()
	if pixels.load_webp_from_buffer(frames[index]) == OK:
		if target.get_width() == 0:
			target.set_image(pixels)
		else:
			target.update(pixels)

func advance(source: Vector3, age: float, ignition: float) -> void:
	if frames.is_empty() or age <= 0.0:
		return
	var sample := minf(age * 12.0, frames.size() - 1.0)
	var index := floori(sample)
	if index != previous:
		if index == previous + 1:
			var spare := first
			first = second
			second = spare
		else:
			_decode(index, first)
		_decode(mini(index+1, frames.size()-1),second)
		material.set_shader_parameter("frame_a",first)
		material.set_shader_parameter("frame_b",second)
		previous = index
	var low := source - SOURCE * scale_factor
	global_position = low + EXTENT * scale_factor * 0.5
	material.set_shader_parameter("corner",low)
	material.set_shader_parameter("phase", sample - index)
	material.set_shader_parameter("heat", smoothstep(ignition,ignition+1.4,age))
	visible = true
