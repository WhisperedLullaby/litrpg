class_name EmpoweredComponent
extends Node

# Marks an entity as carrying surplus energy.
#
# Visually: adds a pulsing additive glow overlay on top of the entity's
# "Sprite2D" child. The colour and pulse speed scale with level.
#
# Mechanically: trigger_effect() executes the stored effect when the entity
# is eventually destroyed or interacted with. Not wired to destruction yet —
# call trigger_effect() manually when that system is ready.
#
# effect_id values:
#   "expel_surplus" — spawns a large XP cloud proportional to level.

@export_range(1, 3) var level: int = 1
@export var effect_id: String = ""

# Level → glow colour.
const LEVEL_COLORS: Array[Color] = [
	Color(0.3, 0.8, 1.0),   # 1: cyan  — minor empowerment
	Color(1.0, 0.85, 0.2),  # 2: gold  — moderate
	Color(1.0, 0.35, 0.1),  # 3: ember — intense
]

# Level → XP released on expel_surplus.
const SURPLUS_XP: Array[float] = [100.0, 300.0, 800.0]

# Level → glow pulse speed (faster = more agitated energy).
const PULSE_SPEEDS: Array[float] = [1.0, 1.8, 3.0]

var _xp_cloud_scene: PackedScene = preload("res://scenes/pickups/xp_cloud.tscn")

func _ready() -> void:
	# Deferred so the parent's _ready() (e.g. tree.gd) runs first and the
	# Sprite2D has its texture assigned before we try to read it.
	_apply_visual.call_deferred()

# --- Public API ---

## Fire the stored effect. Call this when the entity is destroyed / interacted with.
func trigger_effect() -> void:
	match effect_id:
		"expel_surplus":
			_expel_surplus()

# --- Internal ---

func _apply_visual() -> void:
	# Expects the parent to have a child named "Sprite2D" with a texture.
	var sprite := get_parent().get_node_or_null("Sprite2D") as Sprite2D
	if not sprite or not sprite.texture:
		push_warning("EmpoweredComponent: no Sprite2D with texture found on %s" % get_parent().name)
		return

	var overlay := Sprite2D.new()
	overlay.texture = sprite.texture
	overlay.offset  = sprite.offset
	overlay.name    = "EmpoweredOverlay"

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/empowered.gdshader")
	mat.set_shader_parameter("glow_color",   LEVEL_COLORS[level - 1])
	mat.set_shader_parameter("intensity",    0.4 + (level - 1) * 0.2)
	mat.set_shader_parameter("pulse_speed",  PULSE_SPEEDS[level - 1])
	overlay.material = mat

	get_parent().add_child(overlay)
	# No move_child needed — added last, so it renders on top of Sprite2D.

func _expel_surplus() -> void:
	var cloud: Node2D = _xp_cloud_scene.instantiate()
	cloud.global_position = get_parent().global_position
	cloud.total_xp = SURPLUS_XP[level - 1]
	get_tree().current_scene.add_child(cloud)
