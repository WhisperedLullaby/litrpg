shader_type canvas_item;

// Keep these in sync with tree_wind.gdshader — set per-tree by tree.gd.
uniform float wind_speed    : hint_range(0.1, 4.0)  = 1.2;
uniform float wind_strength : hint_range(0.0, 60.0) = 14.0;
uniform float wind_offset   : hint_range(0.0, 6.283) = 0.0;

// Shadow appearance — tweak these to taste.
uniform float shadow_alpha : hint_range(0.0, 1.0) = 0.3;
// How flat the shadow lies. 1.0 = still upright, 0.15 = very flat.
uniform float squish : hint_range(0.05, 1.0) = 0.22;
// Sun angle. Positive = shadow falls to the right, negative = left.
uniform float skew_x : hint_range(-1.5, 1.5) = 0.65;

void vertex() {
	// Flip and squish shadow downward onto the ground.
	// Trunk base (VERTEX.y = 0) stays fixed.
	// Canopy (VERTEX.y < 0) negates to positive, landing below the trunk —
	// which is correct for a top-left light source casting shadow down-right.
	VERTEX.y = -VERTEX.y * squish;

	// Lean shadow in the sun direction.
	// VERTEX.y is now positive at the canopy, so positive skew_x pushes right.
	VERTEX.x += VERTEX.y * skew_x;

	// Sway in sync with the tree canopy — identical wave formula.
	float height = 1.0 - UV.y;
	float wave = sin(TIME * wind_speed + wind_offset) * 0.72
			   + sin(TIME * wind_speed * 0.58 + wind_offset * 1.4) * 0.28;
	VERTEX.x += wave * wind_strength * height * height;
}

void fragment() {
	// Use the tree texture's alpha as a silhouette mask, fill with dark colour.
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(0.0, 0.0, 0.05, mask * shadow_alpha);
}
