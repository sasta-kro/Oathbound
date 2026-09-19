shader_type canvas_item;
// Washes a creature sprite toward a flat light silhouette while it evolves.
// Alpha is kept, so only the creature's own shape glows.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(base.rgb, glow_color.rgb, flash), base.a);
}
