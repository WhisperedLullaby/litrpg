extends Area2D

# Cores are crystallized energy - physical items the system creates
# when an entity dies. They're loot, not experience. You pick them up
# and hold them until you find a use for them.
#
# Core quality reflects the entity's cultivation during its lifetime.
# A level 0 bat that never absorbed anything drops a dull common core.
# An attuned enemy that soaked up clouds drops something refined.

enum Quality { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var energy_value: float = 1.0
var quality: Quality = Quality.COMMON

# Quality → energy value and color mapping.
const QUALITY_DATA := {
	Quality.COMMON:    { "value": 1.0,  "inner": Color(0.5, 0.6, 0.7, 1.0),  "outer": Color(0.4, 0.5, 0.6, 0.4),  "center": Color(0.7, 0.75, 0.8, 1.0) },
	Quality.UNCOMMON:  { "value": 3.0,  "inner": Color(0.3, 0.8, 0.4, 1.0),  "outer": Color(0.2, 0.6, 0.3, 0.4),  "center": Color(0.5, 1.0, 0.6, 1.0) },
	Quality.RARE:      { "value": 8.0,  "inner": Color(0.4, 0.4, 0.9, 1.0),  "outer": Color(0.3, 0.3, 0.7, 0.4),  "center": Color(0.6, 0.6, 1.0, 1.0) },
	Quality.EPIC:      { "value": 20.0, "inner": Color(0.8, 0.5, 0.2, 1.0),  "outer": Color(0.6, 0.4, 0.1, 0.4),  "center": Color(1.0, 0.7, 0.3, 1.0) },
	Quality.LEGENDARY: { "value": 50.0, "inner": Color(0.9, 0.2, 0.2, 1.0),  "outer": Color(0.7, 0.1, 0.1, 0.4),  "center": Color(1.0, 0.4, 0.4, 1.0) },
}

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0

	# Spawn bounce animation.
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 8.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y, 0.2).set_ease(Tween.EASE_IN)

## Set quality tier. Called by the loot system after instantiation.
## Updates energy_value and visuals to match.
func setup_quality(q: Quality) -> void:
	quality = q
	var data: Dictionary = QUALITY_DATA[quality]
	energy_value = data["value"]
	queue_redraw()

## Determine core quality from an entity's lifetime cultivation.
## More absorbed XP = more refined core.
static func quality_from_cultivation(total_xp_absorbed: float) -> Quality:
	if total_xp_absorbed >= 200.0:
		return Quality.LEGENDARY
	elif total_xp_absorbed >= 80.0:
		return Quality.EPIC
	elif total_xp_absorbed >= 30.0:
		return Quality.RARE
	elif total_xp_absorbed >= 10.0:
		return Quality.UNCOMMON
	else:
		return Quality.COMMON

func _draw() -> void:
	var data: Dictionary = QUALITY_DATA[quality]
	# Outer glow
	draw_circle(Vector2.ZERO, 5.0, data["outer"])
	# Inner core
	draw_circle(Vector2.ZERO, 3.0, data["inner"])
	# Bright center
	draw_circle(Vector2.ZERO, 1.5, data["center"])

func collect(collector: Node) -> void:
	# Try to add to collector's inventory.
	var inventory := _find_inventory(collector)
	if inventory:
		var item := InventoryItem.create_core(quality)
		if not inventory.add_item(item, 1):
			# Inventory full - push the core away.
			_bounce_away(collector)
			return

	SignalBus.core_collected.emit(energy_value)
	# Quick shrink animation then remove.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _find_inventory(entity: Node) -> InventoryComponent:
	for child in entity.get_children():
		if child is InventoryComponent:
			return child
	return null

func _bounce_away(collector: Node) -> void:
	# Push core away from the collector so it doesn't re-trigger immediately.
	var away: Vector2 = (global_position - collector.global_position).normalized()
	var target_pos := global_position + away * 20.0
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.2).set_ease(Tween.EASE_OUT)
