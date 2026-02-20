extends Area2D

# A single punch instance. Spawns in front of the player,
# jabs slightly outward (clumsy haymaker), then disappears.
# Very short range - you have to be right up in the enemy's face.
# Applies knockback on hit via the status effect system.

@export var damage: float = 8.0
@export var lifetime: float = 0.25

var direction: Vector2 = Vector2.DOWN

# Knockback effect - defined once, applied to anything we punch.
var _knockback := StatusEffect.create_knockback(120.0, 0.25)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << (3 - 1)
	area_entered.connect(_on_area_entered)

func setup(dir: Vector2) -> void:
	direction = dir

	# Position is LOCAL (relative to player, since we're a child).
	# Start close to the body, jab outward, retract, disappear.
	position = direction * 10.0
	var extended := direction * 22.0
	var retract := direction * 12.0

	var tween := create_tween()
	tween.tween_property(self, "position", extended, lifetime * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", retract, lifetime * 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Flesh-colored circle - about the size of a fist.
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.65, 0.5, 0.7))
	draw_circle(Vector2.ZERO, 3.0, Color(0.92, 0.75, 0.6, 0.9))

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		area.take_hit(damage, global_position)
		# Apply knockback to the entity we just hit.
		var entity := area.get_parent()
		var status := _find_status_effect_component(entity)
		if status:
			status.apply_effect(_knockback, direction)

func _find_status_effect_component(entity: Node) -> StatusEffectComponent:
	for child in entity.get_children():
		if child is StatusEffectComponent:
			return child
	return null
