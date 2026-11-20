extends SceneTree
## Run with Forward+: exercises the production feedback filter on the device.
## Bright history across a silhouette must not become a new light source.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rd := RenderingServer.create_local_rendering_device()
	assert(rd != null, "This regression needs a rendering device")
	var prep: String = SsgiFx.PASSES.prep
	var start := prep.find("vec3 previous_bounce(")
	assert(start >= 0, "Feedback must validate the previous surface")
	var helper := prep.substr(start, prep.find("void main()", start) - start)
	var source := RDShaderSource.new()
	source.source_compute = SsgiFx.HEADER + """
layout(local_size_x = 4, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 6) uniform sampler2D prev_filt_tex;
layout(set = 0, binding = 8) uniform sampler2D prev_gbuf_tex;
layout(set = 0, binding = 9, std430) restrict writeonly buffer Result { vec4 value[]; } result;
""" + helper + """
void main() {
	uint i = gl_GlobalInvocationID.x;
	vec2 uv = i == 0u ? vec2(0.25) : i == 1u ? vec2(0.75, 0.25) : i == 2u ? vec2(0.5) : vec2(0.75);
	result.value[i] = vec4(previous_bounce(uv, 1.0, vec3(0.0, 0.0, 1.0)), 1.0);
}
"""
	var spirv := rd.shader_compile_spirv_from_source(source)
	assert(spirv.compile_error_compute.is_empty(), spirv.compile_error_compute)
	var shader := rd.shader_create_from_spirv(spirv)
	var pipeline := rd.compute_pipeline_create(shader)
	var params := PackedFloat32Array()
	params.resize(SsgiFx.PARAMS)
	params[2] = 2.0
	params[3] = 2.0
	var buffer := rd.uniform_buffer_create(params.size() * 4, params.to_byte_array())
	# Only the upper left texel belongs to the receiver. The others are a
	# nearer hull, a differently facing wall and sky, all with bright history.
	var surface := texture(rd, PackedFloat32Array([0,0,1,1, 0,0,1,0.1, 1,0,0,1, 0,0,1,0]))
	var light := texture(rd, PackedFloat32Array([1,0,0,1, 0,40,0,1, 0,0,40,1, 40,40,40,1]))
	var sampler := rd.sampler_create(RDSamplerState.new())
	var output := rd.storage_buffer_create(64)
	var camera := rd.storage_buffer_create(SsgiFx.CAM_FLOATS * 4)
	var uniforms: Array[RDUniform] = []
	for item in [[0, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, [buffer]],
		[6, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, [sampler, light]],
		[8, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, [sampler, surface]],
		[9, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [output]],
		[10, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [camera]]]:
		var u := RDUniform.new()
		u.binding = item[0]
		u.uniform_type = item[1]
		for id: RID in item[2]:
			u.add_id(id)
		uniforms.append(u)
	var set := rd.uniform_set_create(uniforms, shader, 0)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipeline)
	rd.compute_list_bind_uniform_set(list, set, 0)
	rd.compute_list_dispatch(list, 1, 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var actual := rd.buffer_get_data(output).to_float32_array()
	var expected := PackedFloat32Array([1,0,0,1, 0,0,0,1, 1,0,0,1, 0,0,0,1])
	for i in expected.size():
		assert(absf(actual[i] - expected[i]) < 0.0001, "Feedback sample %d: got %f, expected %f" % [i, actual[i], expected[i]])
	for id: RID in [set, pipeline, shader, buffer, surface, light, sampler, output, camera]:
		rd.free_rid(id)
	rd.free()
	print("SSGI FEEDBACK passed: stable surface retained, disocclusion and mixed-edge taps rejected")
	quit()

func texture(rd: RenderingDevice, values: PackedFloat32Array) -> RID:
	var format := RDTextureFormat.new()
	format.width = 2
	format.height = 2
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	return rd.texture_create(format, RDTextureView.new(), [values.to_byte_array()])
