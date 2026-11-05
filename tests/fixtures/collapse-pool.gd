extends Node

class Effects extends Vfx:
	var scorches := 0
	func _ready() -> void:
		quad = QuadMesh.new()
		spark_mat = ShaderMaterial.new()
		smoke_mat = ShaderMaterial.new()
	func _process(_dt: float) -> void:
		pass
	func scorch(_p: Vector3, _d: float) -> void:
		scorches += 1

func _ready() -> void:
	var original_gl := Vfx.gl
	var original_decals: Variant = Settings.v.decals
	Settings.v.decals = true
	for compatibility in [false, true]:
		Vfx.gl = compatibility
		var effects := Effects.new()
		add_child(effects)
		var programs := []
		for i in Vfx.MAX_COLLAPSES:
			effects._start_collapse(Vector3(0, -30, 0), Vector3.ONE)
			var rig: Array = effects._collapses.back()
			for ps: GeometryInstance3D in rig.slice(0, 2):
				assert((ps is CPUParticles3D) == compatibility)
				programs.append(ps.get_instance_id())
		assert(effects.scorches == 0, "Prewarming must not leave decals on the battlefield")
		for i in 40:
			var ext := Vector3(0.2 + i * 0.1, 2, 0.2 + i * 0.1)
			var at := Vector3(i, 0, -i)
			effects.collapse(at, ext)
			var rig: Array = effects._collapses.back()
			var k := clampf(sqrt(maxf(ext.x * ext.z * 4.0, 0.4)) * 0.5, 0.5, 2.5)
			for j in 2:
				var ps: GeometryInstance3D = rig[j]
				assert(ps.get_instance_id() in programs and ps.visible and Vfx.is_emitting(ps))
				assert(ps.global_position == at and Vfx.pm_get(ps, &"emission_box_extents") == ext)
				var count := int(30 * k * Settings.fx_mult()) + 6 if j == 0 else int(14 * k) + 4
				if ps is CPUParticles3D:
					assert(ps.amount == count)
				else:
					assert(absf(ps.amount * ps.amount_ratio - count) < 0.001)
			assert(is_equal_approx(Vfx.pm_get(rig[0], &"initial_velocity_max"), 7.0 * sqrt(k)))
			assert(is_equal_approx(Vfx.pm_get(rig[1], &"scale_min"), 1.4 * k))
			assert(is_equal_approx(Vfx.pm_get(rig[1], &"scale_max"), 2.4 * k))
		assert(effects._collapses.size() == Vfx.MAX_COLLAPSES and effects.get_child_count() == 2 * Vfx.MAX_COLLAPSES)
		assert(effects.scorches == 40, "Reusing sparks and ash must preserve collapse scorch marks")
		for rig: Array in effects._collapses:
			rig[2] = -100.0
		effects._view_process(0.5)
		for rig: Array in effects._collapses:
			assert(not rig[0].visible and not rig[1].visible, "Spent emitters stop drawing but stay ready to reuse")
		effects.free()
	Vfx.gl = original_gl
	Settings.v.decals = original_decals
	print("COLLAPSE_POOL passed")
	get_tree().quit()
