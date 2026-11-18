class_name SnowLie
extends RefCounted
## How deep a fresh fall of snow lies on the land, before anything churns or
## melts it: the one rule the ground (Atmosphere's ground shader) and the grass
## standing in it (Grass) both follow, so the blades stand out of the snow
## just where the ground shows through it.
##
## Snow never lies evenly. The wind (Fires.WIND) strips it off the rises that
## face it and off the ridges, and drops what it carries in the hollows and on
## the slopes in its lee, where it lies deep and smooth; it scours long streaks
## along its own line. The sun takes it first off the slopes that face it, and
## the fall itself is heavier in some places than others over a few hundred
## metres. snow_lie() returns 1 for a full cover, more in a hollow, less where
## it's thin, and nothing (or less) where the ground is bare. It reads the
## ground's height at the point and `spacing` metres either side of it (the
## caller samples those: each shader reads the ground its own way), and the
## direction to the sun (cloud_sun_disc where the cloud pattern is in, else
## the snow's own sun, Atmosphere's "snow" mood).

const GLSL := """
float snow_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float snow_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(snow_hash(i), snow_hash(i + vec2(1.0, 0.0)), f.x), mix(snow_hash(i + vec2(0.0, 1.0)), snow_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
// around: the ground's height `spacing` metres to +x, -x, +z and -z of p
float snow_lie(vec2 p, float here, vec4 around, float spacing, vec3 to_sun) {
	vec2 sl_grad = vec2(around.x - around.y, around.z - around.w) / (2.0 * spacing);
	// (positive in a hollow, negative on a ridge or a knoll)
	float sl_hollow = (around.x + around.y + around.z + around.w - 4.0 * here) / (spacing * spacing);
	vec2 sl_wind = vec2(0.924, 0.382);
	// (the ground rising along the wind faces into it; falling, it's in its lee)
	float sl_into_wind = dot(sl_grad, sl_wind);
	float sl_lie = 0.94;
	sl_lie -= clamp(sl_into_wind * 5.0, 0.0, 0.85);
	sl_lie += clamp(-sl_into_wind * 3.5, 0.0, 0.55);
	sl_lie += clamp(sl_hollow * 14.0, -0.7, 0.6);
	// (a slope facing the sun falls away toward it)
	vec2 sl_sun = to_sun.xz / max(length(to_sun.xz), 0.001);
	sl_lie -= clamp(-dot(sl_grad, sl_sun) * 3.0, 0.0, 0.4) * smoothstep(0.05, 0.35, to_sun.y);
	sl_lie += (snow_noise(p / 260.0 + 3.1) - 0.5) * 0.8 + (snow_noise(p / 53.0 + 7.7) - 0.5) * 0.55;
	// long streaks scoured along the wind, tens of metres long and a few across
	float sl_streak = snow_noise(vec2(dot(p, sl_wind) / 34.0, dot(p, vec2(-sl_wind.y, sl_wind.x)) / 6.0) + 0.53);
	sl_lie -= smoothstep(0.55, 0.85, sl_streak) * 0.45;
	return sl_lie;
}
vec3 snow_sun() {
#ifdef CLOUD_PATTERN
	return cloud_sun_disc.xyz;
#else
	return vec3(0.415, 0.559, 0.718);  // (the "snow" mood's sun: elevation 34, azimuth 30)
#endif
}
"""
