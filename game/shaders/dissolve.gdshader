shader_type canvas_item;
// A creature coming apart into flecks of light.
//
// The sprite breaks up from the feet upwards while drifting off the ground, so
// a defeat reads as the creature being released rather than as its art being
// faded out. Driven by `progress`: 0 is the creature intact, 1 is nothing left.
//
// The noise is sampled in the sprite's own local space rather than from UV,
// because every battle frame is a region of a shared atlas: a UV-based pattern
// would jump to a different part of the noise on every animation frame.

#include "res://shaders/world_noise.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.95, 0.62, 1.0);
// How wide the glowing rim along the dissolving edge is.
uniform float edge_width : hint_range(0.0, 0.5) = 0.18;
// Size of the flecks the sprite breaks into, in the sprite's own pixels.
uniform float fleck_size : hint_range(1.0, 32.0) = 5.0;
// 0 dissolves the whole body evenly, 1 strictly from the feet up. Keep it
// low: the sweep is measured against the sprite's frame, and art that sits low
// in a tall frame starts near the end of the sweep, so a strong one takes the
// whole creature at once instead of lifting it away.
uniform float sweep : hint_range(0.0, 1.0) = 0.22;
// The sprite's height in its own pixels, so the sweep knows where the feet are.
uniform float sprite_height = 100.0;
// How far the body drifts up as it goes, in the sprite's own pixels.
uniform float lift : hint_range(0.0, 64.0) = 16.0;
// Per-creature randomiser, so two deaths do not break apart identically.
uniform float variant = 0.0;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
	// Eased so the lift starts gently and carries the last flecks away fastest.
	VERTEX.y -= lift * progress * progress;
}

void fragment() {
	// COLOR already holds the sampled texel times the node's modulate. Never
	// sample TEXTURE again here: multiplying the fetch by COLOR would square
	// the colour and quietly darken the sprite.
	float grain = world_value_noise(local_position / fleck_size + vec2(variant * 31.0));
	// 0 at the top of the sprite, 1 at its feet.
	float height = clamp(0.5 + local_position.y / max(sprite_height, 1.0), 0.0, 1.0);
	float value = mix(grain, grain * 0.45 + (1.0 - height) * 0.55, sweep);

	// Runs past both ends so `progress` 0 keeps every pixel and 1 keeps none.
	float threshold = mix(-0.05, 1.05 + edge_width, progress);
	float keep = smoothstep(threshold - 0.03, threshold + 0.03, value);
	float rim = (1.0 - smoothstep(threshold, threshold + edge_width, value)) * keep;

	COLOR.rgb = mix(COLOR.rgb, edge_color.rgb, rim * edge_color.a);
	COLOR.a *= keep;
}
