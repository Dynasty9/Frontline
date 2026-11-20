// The battle's lights in the smoke and the air (air_lights.gd, AirLights):
// the lights that matter most to the camera this frame, three texels each
// (where and how far it reaches; its colour times its strength, and whether
// it's a line; a line's other end).
global uniform sampler2D air_lights : filter_nearest;
global uniform vec4 air_light_info;  // how many lights, how many of them glow in the fog, the fog's and the smoke's share

vec3 air_light(vec3 p, int n, out vec3 dir) {
	vec3 sum = vec3(0.0);
	dir = vec3(0.0);
	for (int i = 0; i < n; i++) {
		vec4 a = texelFetch(air_lights, ivec2(i, 0), 0);
		vec4 b = texelFetch(air_lights, ivec2(i, 1), 0);
		vec3 q = a.xyz;
		if (b.w > 0.5) {
			// a tracer: the nearest point of its lit streak
			vec3 s = texelFetch(air_lights, ivec2(i, 2), 0).xyz - q;
			q += s * clamp(dot(p - q, s) / max(dot(s, s), 1e-4), 0.0, 1.0);
		}
		vec3 d = q - p;
		float d2 = dot(d, d);
		float r2 = a.w * a.w;
		if (d2 < r2) {
			// bright close in, falling away as the square of the distance and
			// gone at the light's range
			float w = 1.0 - d2 / r2;
			vec3 c = b.rgb * (w * w / (1.0 + d2 * 20.0 / r2));
			sum += c;
			dir += d * ((c.r + c.g + c.b) * inversesqrt(d2 + 0.04));
		}
	}
	return sum;
}

// how much of a light's glow the fog takes at this density (the fog weighs
// it by the density again): all of it in the thin night haze, where a streak
// would hardly show otherwise, and no more than that in thick mist or smoke,
// where it would blaze
float air_light_glow(float thick) {
	return air_light_info.z * min(1.0, 0.008 / max(thick, 1e-6));
}
