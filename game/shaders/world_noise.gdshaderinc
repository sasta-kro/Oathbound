// Shared value noise for the overworld shaders.
//
// Cheap enough to run full screen on integrated graphics, and stable: the same
// world position always gives the same value, so cloud shadows and ground
// patches stay put as the camera moves.

float world_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float world_value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local = fract(position);
	// Smoothstep the interpolation so the grid the noise is built on never
	// shows up as visible seams.
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float bottom_left = world_hash(cell);
	float bottom_right = world_hash(cell + vec2(1.0, 0.0));
	float top_left = world_hash(cell + vec2(0.0, 1.0));
	float top_right = world_hash(cell + vec2(1.0, 1.0));
	return mix(
		mix(bottom_left, bottom_right, blend.x), mix(top_left, top_right, blend.x), blend.y
	);
}

float world_fbm(vec2 position, int octaves) {
	float total = 0.0;
	float amplitude = 0.5;
	float weight = 0.0;
	for (int i = 0; i < octaves; i++) {
		total += world_value_noise(position) * amplitude;
		weight += amplitude;
		position *= 2.0;
		amplitude *= 0.5;
	}
	return total / max(weight, 0.001);
}
