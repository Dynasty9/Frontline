class_name PhysicalSky
extends RefCounted
## A sky worked out from how sunlight scatters in the air (Settings > Graphics
## > Physical sky), for the clear moods: golden hour, dawn, dusk and haze.
## Midday keeps its photographed sky, and overcast, rain and night their
## painted ones (cloud and moonlight are not what this models).
##
## Each view ray is marched through a spherical atmosphere: air molecules
## scatter blue light most (Rayleigh), haze and dust scatter all colours
## forwards round the sun (Mie, Cornette-Shanks phase), and ozone takes out
## orange high up, which is what keeps a sunset sky blue overhead. Densities,
## scale heights and coefficients are Hillaire's ("A Scalable and Production
## Ready Sky and Atmosphere Rendering Technique", EGSR 2020), after Bruneton
## and Neyret ("Precomputed Atmospheric Scattering", EGSR 2008). The light
## reaching each point along the ray is itself marched to the top of the air,
## so a low sun reddens and the earth's shadow rises in the east at dusk.
## Light scattered more than once is added as an isotropic share of what
## reached each point (the spirit of Hillaire's multiple-scattering term,
## without its lookup table), which fills the horizon with the soft, pale
## glow a single-scattering sky lacks.
##
## The sky lights the battlefield too: it is the ambient light and the
## reflections, so with it the shade under a tree at sunset takes the blue of
## the sky above it while the lit side takes the sun's orange.

## Mood -> [turbidity (haze and dust, x clear air), sky brightness, clouds].
## The brightness matches the painted sky's average over the dome, so the
## battlefield's exposure and ambient light stay where each mood set them.
const MOODS := {
	"golden": [1.6, 7.0, 0.5],
	"dawn": [2.4, 5.7, 0.45],
	"dusk": [1.9, 6.1, 0.4],
	"hazy": [5.0, 12.0, 0.35],
}

## Midday's air, for Time passes only: a battle at midday keeps its
## photographed sky, but one that passes through midday on the clock is
## scattered on either side of it (Atmosphere._apply_clock_sky). Its sky
## energy makes the scattered sky as bright over the dome as the photograph,
## so the hand-over neither brightens nor dims (tools/sky_calibration.py).
const CLOCK_MOODS := {
	"day": [1.6, 7.36, 0.3],
}

## How far toward a warm grey the battlefield's light from the sky goes in
## the deepest of the blue hour (0.45 by day).
const BLUE_HOUR_GREY := 0.12

static var _shader: Shader


static func make(mood: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = Atmosphere.with_photo(with_night(SHADER))
	m.shader = _shader
	apply(m, mood)
	return m


## The sun as the sky sees it: passed in, not read from the light, because a
## reflection probe draws the sky with no light set up (its direction would be
## zero, and a sky of NaNs blacks out everything that reflects it).
static func set_sun(m: ShaderMaterial, sun: DirectionalLight3D) -> void:
	var basis := sun.global_transform.basis if sun.is_inside_tree() else sun.basis
	m.set_shader_parameter("sun_direction", basis.z.normalized())
	m.set_shader_parameter("sun_energy", sun.light_energy)


## The sky for a moment of Time passes' clock (TimeOfDay.light): the air of
## the daylight moods either side, and the sun where it really is, up or down
## (the dusk sky goes on glowing after the light has gone from the ground).
static func apply_clock(m: ShaderMaterial, st: Dictionary) -> void:
	var sm: Array = st.sun_moods
	var a := _params(String(sm[0]))
	var b := _params(String(sm[1]))
	var k := float(sm[2])
	m.set_shader_parameter("turbidity", lerpf(float(a[0]), float(b[0]), k))
	m.set_shader_parameter("sky_energy", lerpf(float(a[1]), float(b[1]), k))
	m.set_shader_parameter("cloudiness", lerpf(float(a[2]), float(b[2]), k))
	var sp: Vector2 = st.sun
	# once the sun is down the sky's light is the blue of the clear sky
	# overhead, and the battlefield takes it so: the blue hour
	m.set_shader_parameter("warm_grey", lerpf(0.45, BLUE_HOUR_GREY, TimeOfDay.blue_hour(sp.x)))
	m.set_shader_parameter("sun_direction", TimeOfDay.toward(sp.x, sp.y))
	m.set_shader_parameter("sun_energy", float(st.sun_energy))


## The physical sky with the painted night to fade into after dusk (and out
## of before dawn): `night` 0..1, the painted sky's own uniforms, and
## `night_light` toward the moon. At 0 it draws exactly as before.
static func with_night(code: String) -> String:
	var start := code.find("void sky()")
	var at := code.rfind("COLOR = col;")
	assert(at > start and start > 0)
	return code.substr(0, start) + Atmosphere.PAINTED_SKY + NIGHT_UNIFORMS + code.substr(start, at - start) + NIGHT_MIX + code.substr(at)


const NIGHT_UNIFORMS := """uniform float night = 0.0;
uniform vec3 night_light = vec3(0.0, 1.0, 0.0);

"""
const NIGHT_MIX := """if (night > 0.0) {
		col = mix(col, painted_sky(d, night_light, 0.0), night);
	}
	"""


static func _params(mood: String) -> Array:
	return MOODS.get(mood, CLOCK_MOODS.get(mood, MOODS.golden))


static func apply(m: ShaderMaterial, mood: String) -> void:
	var p: Array = MOODS.get(mood, MOODS.golden)
	m.set_shader_parameter("turbidity", float(p[0]))
	m.set_shader_parameter("sky_energy", float(p[1]))
	m.set_shader_parameter("cloudiness", float(p[2]))


const SHADER := """
shader_type sky;
render_mode use_debanding;

uniform float turbidity = 1.6;
uniform float sky_energy = 7.0;
uniform float cloudiness = 0.5;
uniform float sun_disk = 1.0;
uniform vec3 sun_direction = vec3(0.0, 0.42, 0.9);
uniform float sun_energy = 2.0;
uniform vec3 ground_albedo = vec3(0.09, 0.085, 0.06);
// how far the light the battlefield takes from the sky goes to a warm grey
uniform float warm_grey = 0.45;

// kilometres, and per kilometre
const float RG = 6360.0;
const float RT = 6460.0;
const vec3 RAYLEIGH = vec3(5.802e-3, 13.558e-3, 33.1e-3);
const float MIE_SCATTER = 3.996e-3;
const float MIE_EXTINCT = 8.396e-3;
const vec3 OZONE = vec3(0.650e-3, 1.881e-3, 0.085e-3);
const float EYE_HEIGHT = 0.3;

vec2 sphere(vec3 o, vec3 d, float r) {
	float b = dot(o, d);
	float c = dot(o, o) - r * r;
	float h = b * b - c;
	if (h < 0.0) {
		return vec2(-1.0);
	}
	h = sqrt(h);
	return vec2(-b - h, -b + h);
}

// air molecules, haze, ozone at a height (km)
vec3 density(float h) {
	return vec3(exp(-h / 8.0), exp(-h / 1.2), max(0.0, 1.0 - abs(h - 25.0) / 15.0));
}

vec3 extinction(vec3 n) {
	return RAYLEIGH * n.x + vec3(MIE_EXTINCT * turbidity * n.y) + OZONE * n.z;
}

// sunlight left at p after its way down through the air
vec3 sun_light(vec3 p, vec3 l) {
	float r = length(p);
	float mu = dot(p, l) / r;
	// the earth's shadow, softened over the sun's own width
	float rim = -sqrt(max(0.0, 1.0 - (RG * RG) / (r * r)));
	float lit = smoothstep(rim - 0.012, rim + 0.004, mu);
	if (lit <= 0.0) {
		return vec3(0.0);
	}
	float t = sphere(p, l, RT).y;
	float dt = t / 6.0;
	vec3 depth = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		vec3 q = p + l * ((float(i) + 0.5) * dt);
		depth += extinction(density(length(q) - RG)) * dt;
	}
	return exp(-depth) * lit;
}

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 l = normalize(sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 o = vec3(0.0, RG + EYE_HEIGHT, 0.0);
	float t_end = sphere(o, d, RT).y;
	vec2 tg = sphere(o, d, RG);
	bool ground = tg.x > 0.0;
	if (ground) {
		t_end = tg.x;
	}
	float mu = dot(d, l);
	float phase_r = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
	const float G = 0.8;
	float phase_m = 3.0 / (8.0 * PI) * ((1.0 - G * G) * (1.0 + mu * mu)) / ((2.0 + G * G) * pow(1.0 + G * G - 2.0 * G * mu, 1.5));
	vec3 lum = vec3(0.0);
	vec3 seen = vec3(1.0);
	float prev = 0.0;
	const int N = 16;
	for (int i = 0; i < N; i++) {
		// samples crowd close in, where the air is thickest
		float t1 = t_end * pow((float(i) + 1.0) / float(N), 2.0);
		float dt = t1 - prev;
		vec3 p = o + d * (prev + dt * 0.5);
		prev = t1;
		vec3 n = density(length(p) - RG);
		vec3 ext = extinction(n);
		vec3 sr = RAYLEIGH * n.x;
		float sm = MIE_SCATTER * turbidity * n.y;
		vec3 sun = sun_light(p, l);
		vec3 multi = (sr + sm) * (sun * 0.3 + vec3(0.01)) * (1.0 / (4.0 * PI));
		vec3 s = (sr * phase_r + sm * phase_m) * sun + multi;
		vec3 through = exp(-ext * dt);
		// integrated over the step, not point-sampled (Hillaire 2015)
		lum += seen * (s - s * through) / max(ext, vec3(1e-7));
		seen *= through;
	}
	if (ground) {
		vec3 p = o + d * t_end;
		lum += seen * ground_albedo / PI * sun_light(p, l) * max(dot(normalize(p), l), 0.0);
	}
	float energy = sun_energy;
	vec3 col = lum * energy * sky_energy;
	if (!ground) {
		// the sun's disc, darker towards its limb, reddened by the air in front of it
		float ang = acos(clamp(mu, -1.0, 1.0));
		float r = ang / 0.0087;
		if (r < 1.0) {
			float limb = 1.0 - 0.6 * (1.0 - sqrt(max(0.0, 1.0 - r * r)));
			col += seen * limb * energy * 60.0 * sun_disk * (AT_CUBEMAP_PASS ? 0.25 : 1.0) * smoothstep(1.0, 0.85, r);
		}
	}
	if (d.y > 0.0 && cloudiness > 0.0) {
		// a thin layer of fair-weather cloud, lit by the sun as it reaches cloud height
		vec2 uv = d.xz / (d.y + 0.18) * 1.2;
		float c = fbm(uv * 1.6);
		c = smoothstep(1.0 - cloudiness - 0.15, 1.0 - cloudiness + 0.35, c) * smoothstep(0.0, 0.2, d.y);
		vec3 at_cloud = sun_light(o + vec3(0.0, 2.0, 0.0), l) * energy;
		float silver = 0.35 + 0.9 * pow(max(mu, 0.0), 6.0);
		vec3 cl = at_cloud * silver * 0.55 + col * 0.45 + vec3(0.02, 0.025, 0.035) * energy;
		col = mix(col, cl, c * 0.8);
	}
	if (AT_CUBEMAP_PASS) {
		// what the battlefield is lit and reflects by: nearly half way to a
		// warm grey, so the shade under a low sun is cool without going cyan
		col = mix(col, dot(col, vec3(0.2126, 0.7152, 0.0722)) * vec3(1.12, 1.0, 0.84), warm_grey) * 1.2;
	}
	COLOR = col;
}
"""
