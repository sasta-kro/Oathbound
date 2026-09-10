shader_type canvas_item;
// Wind through the plant layer. Geometry only: the colour of the map is lifted
// once, for the whole screen, in `world_atmosphere.gdshader`.
//
// The displacement is a smooth wave over world position rather than a per-tile
// value, for a reason: a tile map draws each tile as one quad and a shader
// cannot tell where that quad's own top and bottom are, so anything computed
// per tile tears on the tall tiles that span several cells. A continuous wave
// shifts nearby tiles by nearly the same amount, which reads as a gust
// crossing the field, and shears wide tiles slightly, which reads as bending.
//
// Keep `sway_pixels` small. This slides a plant rather than bending it from
// its base, and past a couple of pixels that starts to look like sliding.

// Peak sideways displacement, in the layer's own pixels.
uniform float sway_pixels : hint_range(0.0, 6.0) = 1.8;
uniform float sway_speed : hint_range(0.0, 6.0) = 1.15;
// Distance between wave crests, in the layer's own pixels.
uniform float wave_length : hint_range(16.0, 512.0) = 120.0;
// A slower swell over the top, so the wind comes in gusts instead of ticking
// like a metronome.
uniform float gust_speed : hint_range(0.0, 2.0) = 0.23;
uniform float gust_depth : hint_range(0.0, 1.0) = 0.55;

void vertex() {
	// The wave travels diagonally, so rows of tiles do not move in lockstep.
	float phase = (VERTEX.x + VERTEX.y * 0.4) / wave_length;
	float gust = 1.0 - gust_depth * 0.5 * (1.0 - sin(TIME * gust_speed + phase * 0.25));
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_pixels * gust;
}
