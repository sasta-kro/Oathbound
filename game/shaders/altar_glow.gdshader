shader_type canvas_item;
render_mode blend_add;

// The light an altar takes on once its guardian falls: a rune ring burning on
// the stone, a column of light standing out of it, and motes drifting up.
// Drawn additively over the altar sprite, so the art underneath still reads.

uniform vec4 core_color : source_color = vec4(0.82, 0.93, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.25, 0.55, 1.0, 1.0);
// Fades the whole effect in when the altar wakes, and out if it is quenched.
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 6.0) = 1.1;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.3;
// Where on the quad the stone sits, and how far the ring lies open in y: the
// map is drawn from a raised angle, so a circle on the ground reads squashed.
uniform float ground_y : hint_range(0.0, 1.0) = 0.78;
uniform float ground_squash : hint_range(1.0, 4.0) = 2.4;
uniform float ring_radius : hint_range(0.02, 0.6) = 0.3;
uniform float ring_thickness : hint_range(0.005, 0.3) = 0.07;
// How much of the stone inside the ring catches the light.
uniform float pool_strength : hint_range(0.0, 1.0) = 0.18;
uniform float column_width : hint_range(0.01, 0.5) = 0.12;
uniform float column_strength : hint_range(0.0, 2.0) = 0.7;
uniform int mote_count : hint_range(0, 12) = 6;
uniform float mote_speed : hint_range(0.0, 2.0) = 0.28;
uniform float mote_size : hint_range(0.002, 0.08) = 0.016;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// The rune ring lying on the stone, plus the softer pool of light inside it.
float ground_light(vec2 uv, float pulse) {
	vec2 offset = (uv - vec2(0.5, ground_y)) * vec2(1.0, ground_squash);
	float distance_to_centre = length(offset);
	float radius = ring_radius * (1.0 + 0.04 * pulse);
	float ring = smoothstep(ring_thickness, 0.0, abs(distance_to_centre - radius));
	float pool = smoothstep(radius, 0.0, distance_to_centre) * pool_strength;
	return ring + pool;
}

// The column standing out of the ring: brightest at the stone, narrowing and
// fading as it rises.
float column_light(vec2 uv) {
	float height = clamp((ground_y - uv.y) / max(ground_y, 0.001), 0.0, 1.0);
	float width = column_width * (1.0 - 0.55 * height);
	float across = smoothstep(width, 0.0, abs(uv.x - 0.5));
	float along = pow(1.0 - height, 2.0);
	return across * along * column_strength;
}

// Motes rising out of the ring on their own loops.
float mote_light(vec2 uv, float time) {
	float total = 0.0;
	for (int index = 0; index < mote_count; index++) {
		float seed = float(index) + 1.0;
		float lane = (hash(seed) - 0.5) * ring_radius * 1.8;
		float phase = fract(time * mote_speed + hash(seed * 3.7));
		float wobble = sin((time + hash(seed * 7.3) * 6.28) * 1.7) * 0.02;
		vec2 at = vec2(0.5 + lane + wobble, ground_y - phase * ground_y);
		float fade = (1.0 - phase) * phase * 4.0;
		total += smoothstep(mote_size, 0.0, length(uv - at)) * fade;
	}
	return total;
}

void fragment() {
	if (intensity <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		float time = TIME;
		float pulse = sin(time * pulse_speed * 6.2831853);
		float breathe = 1.0 - pulse_depth * 0.5 * (1.0 - pulse);

		float light = ground_light(UV, pulse) * breathe;
		light += column_light(UV) * breathe;
		light += mote_light(UV, time);
		light = clamp(light, 0.0, 1.6);

		// Only the hottest part of the ring burns out to the core colour, so
		// the light keeps its colour instead of washing to white.
		vec3 tint = mix(edge_color.rgb, core_color.rgb, smoothstep(0.75, 1.4, light));
		COLOR = vec4(tint, clamp(light, 0.0, 1.0) * intensity);
	}
}
