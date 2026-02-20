shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.8, 0.6);
uniform float glow_width : hint_range(0.5, 4.0) = 1.5;
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.5;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.2;
uniform float pulse_max : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Sample neighboring pixels to detect alpha edges.
	vec2 pixel_size = TEXTURE_PIXEL_SIZE * glow_width;
	float neighbor_alpha = 0.0;
	neighbor_alpha += texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a;
	neighbor_alpha += texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a;
	neighbor_alpha += texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a;
	neighbor_alpha += texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a;

	// Glow appears where there's no texture but neighbors have alpha.
	float edge = step(0.01, neighbor_alpha) * (1.0 - step(0.01, tex.a));

	// Pulsing intensity.
	float pulse = mix(pulse_min, pulse_max, (sin(TIME * pulse_speed * TAU) + 1.0) * 0.5);

	// Blend: original texture on top, glow underneath at edges.
	vec4 glow = vec4(glow_color.rgb, edge * glow_color.a * pulse);
	COLOR = mix(glow, tex, tex.a);
}
