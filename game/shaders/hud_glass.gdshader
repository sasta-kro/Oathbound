shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 panel_size = vec2(32.0);
uniform float corner_radius = 8.0;
void fragment() {
	vec2 q = abs((UV - 0.5) * panel_size) - panel_size * 0.5 + corner_radius;
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float mask = 1.0 - smoothstep(-0.8, 0.3, distance_to_edge);
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, 2.0).rgb;
	vec3 tinted = mix(blurred, vec3(0.035, 0.075, 0.085), 0.48);
	float sheen = pow(1.0 - UV.y, 3.0) * 0.045;
	COLOR = vec4(tinted + sheen, mask * 0.9);
}
