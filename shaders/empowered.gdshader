shader_type canvas_item;
render_mode blend_add;

// Set by EmpoweredComponent based on level.
uniform vec4 glow_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float intensity  : hint_range(0.0, 2.0) = 0.5;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;

void fragment() {
	// Use the tree (or any entity) texture's alpha as a silhouette mask.
	float mask = texture(TEXTURE, UV).a;

	// Pulse the glow. Two overlapping waves give it a living, unsteady feel.
	float pulse = sin(TIME * pulse_speed) * 0.6
				+ sin(TIME * pulse_speed * 1.7) * 0.4;
	pulse = 0.5 + 0.5 * pulse;

	float alpha = mask * intensity * (0.5 + 0.5 * pulse);
	COLOR = vec4(glow_color.rgb, alpha);
}
