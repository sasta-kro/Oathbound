shader_type canvas_item;
// The overworld's light: one full-screen pass that lifts the map's colours and
// then lays sunlight over them.
//
// It runs above the world and below the HUD, so the interface stays exactly as
// authored. Doing both jobs in one pass rather than putting a shader on each
// tile layer means the ground, the props and the creatures standing on them
// are all lit the same way, and there is one place to tune.
//
// The light is keyed to world position rather than screen position, so a patch
// of sun stays over the same ground while the camera pans. WorldAtmosphere
// feeds the camera in through `world_offset`.

#include "res://shaders/world_noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

group_uniforms colour;
// The map art is painted muted and the game reads better bright.
uniform float saturation : hint_range(0.0, 2.0) = 1.30;
uniform float brightness : hint_range(0.5, 2.0) = 1.14;
// Per-channel trim, for warming or cooling the whole map.
uniform vec3 colour_lift = vec3(1.02, 1.01, 0.98);

group_uniforms sunlight;
uniform vec3 sun_color = vec3(1.0, 0.94, 0.72);
// Flat wash of warm light over everything.
uniform float sun_strength : hint_range(0.0, 0.5) = 0.035;

group_uniforms dapple;
// Broad patches of brighter sun, as if clouds were breaking overhead.
uniform float dapple_strength : hint_range(0.0, 1.0) = 0.18;
// World pixels per noise cell. Larger patches drift more slowly past the eye.
uniform float dapple_size : hint_range(64.0, 4096.0) = 820.0;
uniform vec2 dapple_drift = vec2(16.0, 6.0);
// Share of the ground the bright patches cover.
uniform float dapple_cover : hint_range(0.0, 1.0) = 0.55;

group_uniforms shafts;
// Slanted bars of light, like sun coming through leaves off screen. They
// drift, but slowly: anything that visibly slides past reads as an overlay
// moving over the game rather than as light falling on it.
uniform float shaft_strength : hint_range(0.0, 1.0) = 0.10;
// World pixels between one shaft and the next.
uniform float shaft_spacing : hint_range(32.0, 1024.0) = 260.0;
uniform vec2 shaft_direction = vec2(0.80, 0.60);
uniform float shaft_drift : hint_range(-40.0, 40.0) = 4.0;

group_uniforms pollen;
uniform vec3 pollen_color = vec3(1.0, 0.97, 0.76);
uniform float pollen_strength : hint_range(0.0, 1.0) = 0.5;
// World pixels between motes, and how wide one mote is.
uniform float pollen_spacing : hint_range(32.0, 512.0) = 120.0;
uniform float pollen_size : hint_range(0.5, 16.0) = 5.0;
uniform vec2 pollen_drift = vec2(-11.0, -6.0);

group_uniforms camera;
// Centre of the view in world coordinates, written every frame by the script.
uniform vec2 world_offset = vec2(0.0);
uniform vec2 viewport_size = vec2(960.0, 540.0);

const vec3 LUMINANCE = vec3(0.2126, 0.7152, 0.0722);

// Sparse soft specks on a jittered grid, drifting with the wind.
float pollen_at(vec2 world) {
	vec2 grid = (world + pollen_drift * TIME) / pollen_spacing;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	float radius = pollen_size / pollen_spacing;
	float total = 0.0;
	// Neighbouring cells too, so a mote is not clipped at its cell border.
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 seed = cell + neighbour;
			// Only some cells carry a mote, so the air is not a regular grid.
			if (world_hash(seed + 41.0) > 0.3) {
				continue;
			}
			vec2 centre = neighbour + vec2(world_hash(seed), world_hash(seed + 7.0));
			// Each mote twinkles at its own rate so they do not blink together.
			float pulse = 0.35 + 0.65 * sin(TIME * (0.7 + world_hash(seed + 13.0) * 1.6) + seed.x);
			total += (1.0 - smoothstep(0.0, radius, length(local - centre))) * max(pulse, 0.0);
		}
	}
	return clamp(total, 0.0, 1.0);
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	vec2 world = world_offset + (SCREEN_UV - vec2(0.5)) * viewport_size;

	vec3 lifted = color * brightness * colour_lift;
	color = clamp(mix(vec3(dot(lifted, LUMINANCE)), lifted, saturation), vec3(0.0), vec3(1.0));

	vec3 light = sun_color * sun_strength;

	float dapple = world_fbm((world + dapple_drift * TIME) / dapple_size, 3);
	light += sun_color * dapple_strength * smoothstep(1.0 - dapple_cover, 1.0, dapple);

	vec2 across_shafts = normalize(vec2(-shaft_direction.y, shaft_direction.x));
	float shaft_phase = (dot(world, across_shafts) + TIME * shaft_drift) / shaft_spacing;
	// Cubed so the bars have soft shoulders and bright centres.
	float shaft = pow(0.5 + 0.5 * sin(shaft_phase * 6.2831), 3.0);
	light += sun_color * shaft_strength * shaft;

	light += pollen_color * pollen_at(world) * pollen_strength;

	COLOR = vec4(clamp(color + light, vec3(0.0), vec3(1.0)), 1.0);
}
