extends ProgressBar

# Simple health bar using Godot's built-in ProgressBar with custom colors.
# No sprite sheet needed - we style it with a theme override.

var health_component: HealthComponent

func _ready() -> void:
	# Style the bar with code. This creates a clean colored bar
	# without needing any external textures.
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.1, 0.1, 0.9)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.1, 0.1, 1.0)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2

	add_theme_stylebox_override("background", bg_style)
	add_theme_stylebox_override("fill", fill_style)

func setup(component: HealthComponent) -> void:
	health_component = component
	health_component.health_changed.connect(_on_health_changed)
	max_value = component.max_health
	value = component.current_health

func _on_health_changed(current: float, maximum: float) -> void:
	max_value = maximum
	var tween := create_tween()
	tween.tween_property(self, "value", current, 0.3).set_ease(Tween.EASE_OUT)
