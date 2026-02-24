shader_type canvas_item;

// How fast the wind cycle runs.
uniform float wind_speed : hint_range(0.1, 4.0) = 1.2;
// Maximum horizontal displacement at the canopy tip (pixels).
uniform float wind_strength : hint_range(0.0, 60.0) = 14.0;
// Per-tree phase offset so trees don't sway in lockstep.
uniform float wind_offset : hint_range(0.0, 6.283) = 0.0;

void vertex() {
	// UV.y: 0 = canopy top, 1 = trunk base.
	// height: 1 at canopy top, 0 at trunk base.
	float height = 1.0 - UV.y;

	// Two overlapping sine waves at different frequencies for organic motion.
	// Primary wave + a slower, weaker secondary gives it a living feel.
	float wave = sin(TIME * wind_speed + wind_offset) * 0.72
			   + sin(TIME * wind_speed * 0.58 + wind_offset * 1.4) * 0.28;

	// Quadratic falloff: canopy tip gets full displacement,
	// midpoint ~25%, trunk base zero. This keeps the roots planted.
	VERTEX.x += wave * wind_strength * height * height;
}
