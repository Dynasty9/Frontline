// Excavation buries plants beside the cut as well as removing those inside it.
float trench_disturbed(sampler2D cut, vec2 uv, float reach) {
	float coverage = textureLod(cut, uv, 0.0).r;
	coverage = max(coverage, textureLod(cut, uv + vec2(reach, 0.0), 0.0).r);
	coverage = max(coverage, textureLod(cut, uv - vec2(reach, 0.0), 0.0).r);
	coverage = max(coverage, textureLod(cut, uv + vec2(0.0, reach), 0.0).r);
	return max(coverage, textureLod(cut, uv - vec2(0.0, reach), 0.0).r);
}
