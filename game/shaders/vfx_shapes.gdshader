shader_type canvas_item;
// One procedural effect shader for every move in the game.
//
// A move does not get its own shader or its own art: it picks a `pattern`,
// two colours and a speed, and that is the whole effect. Everything is drawn
// from the UV, so an effect costs nothing but a quad and scales to any size.
//
// `progress` is the only animated uniform. 0 is before the effect, 1 is after
// it, and the caller tweens between the two; VfxPlayer does that, and the
// shader never reads TIME so a paused or replayed effect stays deterministic.

// Effect shapes, matching VfxPreset.Pattern.
const int PATTERN_BURST = 0;
const int PATTERN_RING = 1;
const int PATTERN_SLASH = 2;
const int PATTERN_BEAM = 3;
const int PATTERN_MOTES = 4;
const int PATTERN_SPARKS = 5;

uniform int pattern : hint_range(0, 5) = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Colour at the hot inner edge of the shape.
uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.60, 1.0);
// Colour at its cooling outer edge.
uniform vec4 edge_color : source_color = vec4(0.95, 0.35, 0.10, 1.0);
// Width of the drawn band, in UV units. MOTES and SPARKS draw no band and read
// it as the size of one speck instead.
uniform float thickness : hint_range(0.02, 1.0) = 0.26;
// How far the band fades out at its edges. 0 draws hard pixel-art edges.
uniform float softness : hint_range(0.0, 0.5) = 0.10;
// Distorts the shape's outline. 0 is a clean geometric shape.
uniform float ragged : hint_range(0.0, 1.0) = 0.35;
// Per-cast randomiser, so two casts of the same move are not identical.
uniform float variant = 0.0;
// Quad width divided by its height, so round shapes stay round on any quad.
uniform float aspect = 1.0;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth per-angle distortion in roughly -1..1, used to break up outlines.
// Three harmonics at unrelated frequencies and phases, because two symmetric
// ones make every burst come out as the same regular star.
float outline_wobble(float angle) {
	return sin(angle * 3.0 + variant * 6.2831) * 0.45
		+ sin(angle * 7.0 - variant * 11.0 + 1.7) * 0.35
		+ sin(angle * 11.0 + variant * 4.0 + 3.9) * 0.20;
}

// Coverage of a band `width` wide whose outer edge sits at `radius`.
float band(float distance_to_centre, float radius, float width) {
	float inside = 1.0 - smoothstep(radius, radius + softness, distance_to_centre);
	float hole = 1.0 - smoothstep(radius - width, radius - width + softness, distance_to_centre);
	return clamp(inside - hole, 0.0, 1.0);
}

// Fades the whole effect in quickly and out over its last third.
float envelope(float t) {
	return smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.68, 1.0, t));
}

// A ragged ball that swells and then hollows out as it cools, the way an
// explosion does. It stays a soft-edged blob rather than a clean ring: a hard
// inner edge reads as a cut-out flower, not as fire.
void burst(vec2 p, out float mask, out float heat) {
	float distance_to_centre = length(p);
	float angle = atan(p.y, p.x);
	float grow = mix(0.08, 0.48, 1.0 - pow(1.0 - progress, 2.0));
	float radius = grow * (1.0 + outline_wobble(angle) * ragged * 0.3);
	float fill = 1.0 - smoothstep(radius * (1.0 - thickness), radius + softness, distance_to_centre);
	// The centre gives out first, so a late frame is a shell without ever
	// having a hard hole punched in it.
	float hollow = smoothstep(0.0, radius * 0.8, distance_to_centre);
	mask = fill * mix(1.0, hollow, smoothstep(0.15, 0.9, progress));
	heat = clamp(1.0 - distance_to_centre / max(radius, 0.001), 0.0, 1.0);
}

// A flat ellipse on the ground, for anything that hits from below.
void ring(vec2 p, out float mask, out float heat) {
	vec2 flattened = vec2(p.x, p.y * 3.0);
	float distance_to_centre = length(flattened);
	float angle = atan(flattened.y, flattened.x);
	float radius = mix(0.08, 0.46, 1.0 - pow(1.0 - progress, 3.0));
	radius *= 1.0 + outline_wobble(angle) * ragged * 0.15;
	mask = band(distance_to_centre, radius, thickness * 0.6);
	heat = clamp(1.0 - progress, 0.0, 1.0);
}

// A crescent that sweeps through an arc, brightest at its leading edge.
void slash(vec2 p, out float mask, out float heat) {
	float distance_to_centre = length(p);
	float angle = atan(p.y, p.x);
	float arc = band(distance_to_centre, 0.44, thickness);
	float head = mix(-1.4, 1.4, 1.0 - pow(1.0 - progress, 2.0));
	float tail = head - 1.7;
	float wedge = smoothstep(tail, tail + 0.5, angle) * (1.0 - smoothstep(head - 0.12, head, angle));
	mask = arc * wedge;
	heat = clamp(1.0 - (head - angle) / 1.7, 0.0, 1.0);
}

// A lance of energy that grows from the left edge of the quad. The caller
// rotates the quad so it points at whatever is being hit.
void beam(vec2 p, out float mask, out float heat) {
	float along = (p.x / max(aspect, 0.001)) + 0.5;
	float head = 1.0 - pow(1.0 - progress, 2.0);
	float reached = 1.0 - smoothstep(head, head + 0.06, along);
	float taper = 0.35 + 0.65 * sin(clamp(along, 0.0, 1.0) * 3.1416);
	// Interpolated rather than per-cell, so the beam ripples instead of
	// showing hard vertical bands.
	float ripple_at = along * 12.0;
	float cell = floor(ripple_at);
	float blend = smoothstep(0.0, 1.0, fract(ripple_at));
	float noise = mix(hash(vec2(cell, variant)), hash(vec2(cell + 1.0, variant)), blend);
	float flicker = 1.0 + (noise - 0.5) * ragged;
	float half_width = thickness * 0.5 * taper * flicker;
	mask = (1.0 - smoothstep(half_width, half_width + softness, abs(p.y))) * reached;
	heat = clamp(1.0 - abs(p.y) / max(half_width, 0.001), 0.0, 1.0);
}

// Scattered specks that drift upwards, for gusts, buffs and lights released.
void motes(vec2 uv, out float mask, out float heat) {
	// Square cells whatever shape the quad is, so a mote is a dot and not a
	// pill, and drift the whole field rather than each mote inside its own
	// cell: a mote that leaves its cell is clipped at the border and squared
	// off. Neighbouring cells are checked too, which lets a mote sit anywhere
	// in its cell instead of near the middle, so the motes scatter rather than
	// showing the lattice they were placed on.
	vec2 cells = vec2(5.0, max(5.0 / max(aspect, 0.001), 2.0));
	vec2 grid = uv * cells - vec2(0.0, progress * cells.y * 0.45);
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	// MOTES reads `thickness` as the size of one speck, in cell widths.
	float radius = clamp(thickness, 0.02, 0.45);
	mask = 0.0;
	heat = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 seed = cell + neighbour;
			// Some cells stay empty, so the air is not evenly filled.
			if (hash(seed + 19.0) > 0.7) {
				continue;
			}
			vec2 centre = neighbour + vec2(hash(seed), hash(seed + 7.0));
			// A slow sideways wander, so nothing rises on a straight line.
			centre.x += sin(progress * 3.0 + hash(seed + 5.0) * 6.2831) * 0.18;
			float fade = clamp(1.0 - progress * (0.7 + hash(seed + 3.0) * 0.6), 0.0, 1.0);
			float speck = 1.0 - smoothstep(radius * 0.3, radius, length(local - centre));
			mask = max(mask, speck * fade);
			heat = max(heat, fade);
		}
	}
	mask = clamp(mask, 0.0, 1.0);
}


// A body coming apart: every speck starts inside the shape and flies out from
// there, thinning as it goes.
//
// Unlike MOTES this is not a field of drifting dots. A field reads as weather
// falling through the scene; these have to read as the thing itself scattering,
// which means they must all start together on the body and separate from it.
// So there is no grid here: a fixed set of sparks each get their own origin
// inside the body and their own direction out of it.
void sparks(vec2 p, out float mask, out float heat) {
	mask = 0.0;
	heat = 0.0;
	// Fast at first, then coasting, the way thrown pieces lose speed.
	float flight = 1.0 - pow(1.0 - progress, 2.0);
	for (int i = 0; i < 28; i++) {
		float index = float(i);
		float spread = hash(vec2(index, variant));
		float rate = hash(vec2(index + 13.0, variant));
		float heading = hash(vec2(index + 29.0, variant));
		// Start scattered through the body rather than at a single point.
		vec2 origin = (vec2(spread, rate) - vec2(0.5)) * vec2(0.20, 0.26);
		float angle = heading * 6.2831;
		// Outward in every direction, but biased upwards: released light rises.
		vec2 drift = vec2(cos(angle) * 0.26, -0.24 - spread * 0.26);
		vec2 position = origin + drift * flight;
		// Long enough that the last sparks are still going when the body is
		// gone, so the creature is seen turning into them rather than beside
		// them.
		float life = clamp(1.0 - progress * (0.55 + rate * 0.45), 0.0, 1.0);
		float radius = (0.010 + thickness * 0.045) * (0.45 + life);
		float speck = 1.0 - smoothstep(radius * 0.35, radius, length(p - position));
		mask = max(mask, speck * life);
		heat = max(heat, life);
	}
	mask = clamp(mask, 0.0, 1.0);
}


void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float mask = 0.0;
	float heat = 0.0;

	if (pattern == PATTERN_RING) {
		ring(p, mask, heat);
	} else if (pattern == PATTERN_SLASH) {
		slash(p, mask, heat);
	} else if (pattern == PATTERN_BEAM) {
		beam(p, mask, heat);
	} else if (pattern == PATTERN_MOTES) {
		motes(UV, mask, heat);
	} else if (pattern == PATTERN_SPARKS) {
		sparks(p, mask, heat);
	} else {
		burst(p, mask, heat);
	}

	vec4 tint = mix(edge_color, core_color, clamp(heat, 0.0, 1.0));
	COLOR = vec4(tint.rgb, tint.a * mask * envelope(progress) * COLOR.a);
}
