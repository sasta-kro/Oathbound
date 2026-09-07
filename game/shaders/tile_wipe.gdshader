shader_type canvas_item;
// Chunky square wipe used between the overworld and the battle screen.
//
// Every cell of a coarse grid grows a filled square from its centre. Cells
// start in a diagonal order with a little per-cell jitter, so the screen fills
// as a readable sweep rather than a single fade. `progress` 0 is a clear
// screen and 1 is a fully covered one, so the same material plays the wipe in
// both directions.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cells = vec2(24.0, 14.0);
uniform vec4 fill_color : source_color = vec4(0.06, 0.07, 0.10, 1.0);
// Share of `progress` a single cell takes to fill. The rest is the sweep.
uniform float cell_span : hint_range(0.05, 1.0) = 0.45;
// How far a cell may start ahead of or behind its diagonal position.
uniform float jitter : hint_range(0.0, 0.5) = 0.14;

float cell_noise(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * cells);
	float diagonal = (cell.x / cells.x + cell.y / cells.y) * 0.5;
	float offset = clamp(diagonal + cell_noise(cell) * jitter, 0.0, 1.0);
	float start = offset * (1.0 - cell_span);
	float amount = clamp((progress - start) / cell_span, 0.0, 1.0);

	vec2 local = fract(UV * cells) - vec2(0.5);
	float reach = max(abs(local.x), abs(local.y));
	float covered = step(reach, amount * 0.5);
	COLOR = vec4(fill_color.rgb, fill_color.a * covered);
}
