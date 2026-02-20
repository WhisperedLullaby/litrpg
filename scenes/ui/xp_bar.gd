extends ProgressBar

# Pure UI - displays the XP progress of an ExperienceComponent.
# Same pattern as health_bar: call setup(component) to wire it up.
# The component owns all the data; this just visualizes it.

var _xp_comp: ExperienceComponent = null

func _ready() -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.1, 0.2, 0.9)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.6, 0.3, 0.9, 1.0)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2

	add_theme_stylebox_override("background", bg_style)
	add_theme_stylebox_override("fill", fill_style)
	show_percentage = false

	max_value = 20.0
	value = 0.0

func setup(xp_component: ExperienceComponent) -> void:
	_xp_comp = xp_component
	max_value = _xp_comp.xp_to_next_level
	value = _xp_comp.current_xp
	_xp_comp.xp_changed.connect(_on_xp_changed)

func _on_xp_changed(current_xp: float, xp_to_next: float) -> void:
	max_value = xp_to_next
	var tween := create_tween()
	tween.tween_property(self, "value", current_xp, 0.2).set_ease(Tween.EASE_OUT)
