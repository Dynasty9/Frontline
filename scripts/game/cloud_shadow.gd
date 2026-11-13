class_name CloudShadow
extends RefCounted
## Shadows of the clouds drifting over the battle. A cloud between the sun and
## the ground takes much of the sunlight and none of the skylight, so a patch
## of shade crosses the field: on the ground, and on everything standing on it.
## A tank that drove into the shade and stayed lit would give itself away from
## above, so every surface reads the same pattern at its own world position:
## the `cloud_noise` and `cloud_shadow` global shader uniforms (project.godot),
## which the atmosphere sets for the battle and keeps moving with the wind
## (set_sky, tick).
##
## A shader takes part through two marks in its source: `// CLOUD_SHADOW`
## among its uniforms, and `// CLOUD_FRAGMENT <share>` as the last line of its
## fragment(), where <share> is the share of sunlight that gets through
## (usually `cloud_sun(world_position)`). The ground and the shaders with
## lighting of their own (OWN_LIGHT) call cloud_sun() in their light().
##
## Only direct sunlight is cut. A custom light() can do that, but it replaces
## the engine's lighting altogether, so for the shaders that had none the
## engine's own light model is redone below (CLOUD_LIGHT). The browser lights
## per vertex, where no light() runs: there the cloud dims the albedo and
## hands the skylight back through AO, which reaches only the ambient once
## AO_LIGHT_AFFECT is 0 (CLOUD_VERTEX_LIT). All of it is the Cloud shadows
## setting's; with it off, only the ground darkens, and the grass and bushes
## the cheap way (FOLD). None of it touches the simulation: it's light,
## nothing else.

## Flags for shader(): what the shader's fragment writes, which the light model
## has to take into account.
const CLEARCOAT := 1  # writes CLEARCOAT (vehicle paint's lacquer)
const BACKLIGHT := 2  # writes BACKLIGHT (leaves, grass: light through them)
const NO_SPECULAR := 4  # render_mode specular_disabled
const OWN_LIGHT := 8  # has a light() of its own, which calls cloud_sun()
## With the setting off, still darkened, by folding the share into the albedo:
## most of a meadow's light is the sun's, so near enough, and it costs nothing
const FOLD := 16
## Takes its skylight and bounce from the light probes as well (LightProbes.inject).
const PROBES := 32

## Cumulus shadows span a few hundred metres: the biome noise's features are
## about 83 texels across, stretched over 4.5 texture widths to ~370 m.
const STRETCH := 4.5
## How fast the clouds drift with the wind, in metres a second.
const SPEED := 6.5

static var _shaders: Array = []  # [WeakRef to a Shader, its source, flags], one for each make()
static var _on := false  # what the shaders were last coded for
static var _offset := Vector2.ZERO
static var _strength := 0.0
static var _scale := 1.0 / (1024.0 * STRETCH)  # pattern widths a metre (set_sky)


## Whether surfaces other than the ground take the shadows (Settings > Graphics).
static func wanted() -> bool:
	return bool(Settings.get_v("cloud_shadows"))


## Per-vertex lighting (the browser build), where no light() function runs.
static func vertex_lit() -> bool:
	return bool(ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading"))


## A shader whose source carries the marks, recoded whenever the setting changes.
static func make(src: String, flags := 0) -> Shader:
	refresh()  # (the setting may have changed since the last ones were made, in the menu)
	var sh := Shader.new()
	sh.code = shader(src, flags, _on)
	_shaders.append([weakref(sh), src, flags])
	return sh


## The source with its marks filled in.
static func shader(src: String, flags := 0, on := false) -> String:
	if flags & PROBES:
		src = LightProbes.inject(src)
	var lit := vertex_lit()
	var head := ""
	if on:
		head = "#define CLOUD_ON\n#define CLOUD_VERTEX_LIT\n" if lit else "#define CLOUD_ON\n#define CLOUD_LIGHT\n"
	var own_light := flags & OWN_LIGHT != 0
	var fold := not on and flags & FOLD != 0
	if on or own_light or fold:
		head += PATTERN
	var tail := ""
	if fold:
		tail = FOLDED
	elif on and lit:
		tail = DIM
	elif on and not own_light:
		head += "varying float cloud_k;\n"
		tail = "cloud_k = __SHARE__;\n"
		if flags & NO_SPECULAR == 0:
			head += "varying float cloud_specular;\n"
			tail += "cloud_specular = SPECULAR;\n"
		if flags & CLEARCOAT:
			head += "#define CLOUD_CLEARCOAT\nvarying vec3 cloud_geo;\nvarying vec2 cloud_coat;\n"
			tail += "cloud_geo = normalize(NORMAL);\ncloud_coat = vec2(CLEARCOAT, CLEARCOAT_ROUGHNESS);\n"
		if flags & BACKLIGHT:
			head += "#define CLOUD_BACKLIGHT\n"
		if flags & NO_SPECULAR:
			head += "#define CLOUD_NO_SPECULAR\n"
		head += LIGHT
	var out := src.replace("// CLOUD_SHADOW", head)
	var at := out.find("// CLOUD_FRAGMENT ")
	while at >= 0:
		var eol := out.find("\n", at)
		var share := out.substr(at + 18, eol - at - 18).strip_edges()
		out = out.substr(0, at) + tail.replace("__SHARE__", share) + out.substr(eol)
		at = out.find("// CLOUD_FRAGMENT ", at + 1)
	return out


## Recodes every shader made here for the setting, if it changed.
static func refresh() -> void:
	var on := wanted()
	if on == _on:
		return
	_on = on
	var alive: Array = []
	for e in _shaders:
		var sh: Shader = (e[0] as WeakRef).get_ref()
		if sh:
			sh.code = shader(String(e[1]), int(e[2]), on)
			alive.append(e)
	_shaders = alive


## The battle's cloud pattern (the biome noise, `MapDims.BIOME` texels across)
## and how much sunlight its clouds take (0 for none).
static func set_sky(pattern: Texture2D, strength: float) -> void:
	if pattern:
		RenderingServer.global_shader_parameter_set("cloud_noise", pattern)
	_scale = 1.0 / (float(MapDims.BIOME) * STRETCH)
	_offset = Vector2.ZERO
	set_strength(strength)


static func set_strength(strength: float) -> void:
	_strength = strength
	RenderingServer.global_shader_parameter_set("cloud_shadow", Vector4(strength, _offset.x, _offset.y, _scale))


## Where the sun is (the light the clouds stand in front of), and how much the
## engine widens its light for the size of its disc (which it does only while
## the sun throws soft shadows): the `cloud_sun_disc` global, for the light
## model below.
static func set_sun(sun: DirectionalLight3D) -> void:
	var size := 0.0
	if sun.shadow_enabled and sun.shadow_blur > 0.0:
		size = 1.0 - cos(deg_to_rad(sun.light_angular_distance))
	var to_sun := sun.global_transform.basis.z.normalized()
	RenderingServer.global_shader_parameter_set("cloud_sun_disc", Vector4(to_sun.x, to_sun.y, to_sun.z, size))


## Moves the clouds on downwind, the way the smoke goes (Fires.WIND).
static func tick(dt: float) -> void:
	var wind := Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	# the pattern is read at position * scale + offset, so it travels against the offset
	_offset = (_offset - wind * SPEED * _scale * dt).posmod(1.0)
	RenderingServer.global_shader_parameter_set("cloud_shadow", Vector4(_strength, _offset.x, _offset.y, _scale))


## The pattern and cloud_sun(): the share of sunlight that gets through at a
## world position. The noise is filtered linearly with no mipmaps, so it reads
## the same in a vertex, fragment or light function. cloud_is_sun(): whether a
## light() is lighting with the battle's sun, the one light the clouds stand in
## front of (not the rim light opposite, the sky's fill, nor the Field Manual's
## studio lights, opened mid-battle).
const PATTERN := """
#define CLOUD_PATTERN
global uniform sampler2D cloud_noise : filter_linear, repeat_enable;
global uniform vec4 cloud_shadow;  // how much the clouds take, the drift (x, z), the pattern's scale
global uniform vec4 cloud_sun_disc;  // toward the sun (world), how much its disc widens its light

bool cloud_is_sun(vec3 light, mat4 view) {
	return dot(light, normalize((view * vec4(cloud_sun_disc.xyz, 0.0)).xyz)) > 0.9999;
}

float cloud_sun(vec3 p) {
	if (cloud_shadow.x <= 0.0) {
		return 1.0;
	}
	float c = textureLod(cloud_noise, p.xz * cloud_shadow.w + cloud_shadow.yz, 0.0).r;
	return 1.0 - cloud_shadow.x * smoothstep(0.45, 0.75, c);
}
"""

## FOLD, with the setting off: the shade folded into the albedo, a little
## lighter since the skylight goes down with it (in linear light, as DIM).
const FOLDED := """{
	float cloud_f = mix(1.0, __SHARE__, 0.8);
	ALBEDO *= OUTPUT_IS_SRGB ? pow(cloud_f, 1.0 / 2.2) : cloud_f;
}
"""

## Per-vertex lighting: the light has already been worked out at the vertices
## by the time fragment() runs, and is multiplied by the albedo afterwards, as
## the skylight is (and by AO). So the albedo goes down by the share and AO up
## by as much, and AO stops reaching the direct light, taking over what it did
## there (Compatibility never lets AO reach direct light). Compatibility
## linearises the albedo after fragment() (it's sRGB there), hence the power.
const DIM := """{
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float cloud_d = max(__SHARE__, 0.05);
#else
	float cloud_d = max((__SHARE__) * mix(1.0, AO, AO_LIGHT_AFFECT), 0.05);
#endif
	ALBEDO *= OUTPUT_IS_SRGB ? pow(cloud_d, 1.0 / 2.2) : cloud_d;
	AO /= cloud_d;
	AO_LIGHT_AFFECT = 0.0;
}
"""

## The engine's light model, as Godot 4.7 computes it (light_compute in its
## scene shaders): Lambert diffuse (its default), Schlick-GGX specular with
## multiple-scatter energy compensation, a clearcoat lobe, light through thin
## leaves, the sun's disc widening its highlights. Only the battle's sun is
## scaled by the cloud (cloud_is_sun). The engine's compensation reads a
## lookup table shaders can't reach, so it's approximated (Lazarov 2013, as
## Compatibility does its reflections); for anything but polished metal it's
## within a few percent of 1 either way. A fire's light is a point here
## (light() isn't told its size), which shows only in a sharp highlight.
## Drawn both ways, a test scene of every kind of surface came out within 5 of
## 255 at any pixel and 0.05 on average.
const LIGHT := """
float cloud_fresnel(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}

float cloud_ggx(float noh, float r) {
	float a = noh * r;
	float k = r / (1.0 - noh * noh + a * a);
	return k * k * (1.0 / PI);
}

void light() {
	float att = ATTENUATION;
	float A = 0.0;
	if (LIGHT_IS_DIRECTIONAL && cloud_is_sun(LIGHT, VIEW_MATRIX)) {
		att *= cloud_k;
		A = cloud_sun_disc.w;
	}
	float cNdotL = clamp(A + dot(NORMAL, LIGHT), 0.0, 1.0);
	float cNdotV = max(dot(NORMAL, VIEW), 1e-4);
	vec3 H = normalize(VIEW + LIGHT);
	float cLdotH = clamp(A + dot(LIGHT, H), 0.0, 1.0);
	float cLdotH5 = cloud_fresnel(cLdotH);
	float cc = 1.0;
#ifdef CLOUD_CLEARCOAT
	if (cloud_coat.x > 0.0) {
		float ccNdotL = clamp(A + dot(cloud_geo, LIGHT), 0.0, 1.0);
		float ccNdotH = clamp(A + dot(cloud_geo, H), 0.0, 1.0);
		float Fr = mix(0.04, 1.0, cLdotH5) * cloud_coat.x;
		cc = 1.0 - Fr;
		float Gr = 0.25 / (cLdotH * cLdotH + 1e-4);
		SPECULAR_LIGHT += cloud_ggx(ccNdotH, mix(0.001, 0.1, cloud_coat.y)) * Gr * Fr * ccNdotL * LIGHT_COLOR * att * SPECULAR_AMOUNT;
	}
#endif
	if (METALLIC < 1.0) {
		float brdf = cNdotL * (1.0 / PI);
		DIFFUSE_LIGHT += LIGHT_COLOR * brdf * att * cc;
#ifdef CLOUD_BACKLIGHT
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		DIFFUSE_LIGHT += LIGHT_COLOR * (vec3(1.0 / PI) - brdf) * BACKLIGHT * att * cc;
#else
		DIFFUSE_LIGHT += LIGHT_COLOR * (vec3(1.0 / PI) - brdf) * BACKLIGHT * att;
#endif
#endif
	}
#ifndef CLOUD_NO_SPECULAR
	if (ROUGHNESS > 0.0) {
		float cNdotH = clamp(A + dot(NORMAL, H), 0.0, 1.0);
		float a2 = ROUGHNESS * ROUGHNESS;
		float D = cloud_ggx(cNdotH, a2);
		float G = 0.5 / mix(2.0 * cNdotL * cNdotV, cNdotL + cNdotV, a2);
		vec3 f0 = mix(vec3(0.16 * cloud_specular * cloud_specular), ALBEDO, METALLIC);
#ifdef CLOUD_CLEARCOAT
		f0 = mix(f0, clamp(f0 * (f0 * (0.941892 - 0.263008 * f0) + 0.346479) - 0.0285998, 0.0, 1.0), cloud_coat.x);
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
		vec3 ec = vec3(1.0);
#else
		float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), METALLIC, 1.0);
		vec4 r = ROUGHNESS * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
		float a004 = min(r.x * r.x, exp2(-9.28 * clamp(dot(NORMAL, VIEW), 0.0001, 1.0))) * r.x + r.y;
		vec2 env = vec2(-1.04, 1.04) * a004 + r.zw;
		vec3 ec = 1.0 + f0 * (1.0 / max(env.x + env.y, 0.05) - 1.0);
#endif
		vec3 F = f0 + (f90 - f0) * cLdotH5;
		SPECULAR_LIGHT += ec * cNdotL * D * F * G * LIGHT_COLOR * att * cc * SPECULAR_AMOUNT;
	}
#endif
}
"""
