shader_type sky;
uniform sampler2D panorama : filter_linear_mipmap, repeat_enable;
void sky() {
	// Align the photographed sun with the directional light. The light
	// supplies the direct sun, the panorama supplies the sky reflection.
	vec2 uv = vec2(atan(EYEDIR.z, EYEDIR.x) / TAU + 0.7507,
		acos(clamp(EYEDIR.y, -1.0, 1.0)) / PI + 0.010);
	// Longitude jumps by one turn behind the camera axis. An implicit mip
	// derivative there blurs a vertical stripe across the open sky.
	COLOR = min(textureLod(panorama, uv, 0.0).rgb, vec3(12.0));
}
