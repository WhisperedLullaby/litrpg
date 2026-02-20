class_name HitboxComponent
extends Area2D

# The hitbox is "I deal damage." When it overlaps a hurtbox,
# it tells the hurtbox to take a hit.
#
# target_layer controls WHO this hitbox can damage:
#   2 = targets player hurtboxes  (used by enemy hitboxes)
#   3 = targets enemy hurtboxes   (used by player weapons)

@export var damage: float = 10.0
@export_enum("player:2", "enemy:3") var target_layer: int = 2
@export var recoil_force: float = 0.0  ## Pushes self back on hit.

var _recoil_effect: StatusEffect = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << (target_layer - 1)
	area_entered.connect(_on_area_entered)
	if recoil_force > 0:
		_recoil_effect = StatusEffect.create_knockback(recoil_force, 0.2)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		area.take_hit(damage, global_position)
		# Recoil: push ourselves away from what we just hit.
		if _recoil_effect:
			var away: Vector2 = (get_parent().global_position - area.get_parent().global_position).normalized()
			var status := _find_status_effect_component()
			if status:
				status.apply_effect(_recoil_effect, away)

func _find_status_effect_component() -> StatusEffectComponent:
	for child in get_parent().get_children():
		if child is StatusEffectComponent:
			return child
	return null
