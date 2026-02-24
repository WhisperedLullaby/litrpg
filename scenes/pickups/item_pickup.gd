extends Area2D

# A ground pickup for any InventoryItem. Shows the item's icon with
# the interactable glow shader. Collected by walking over it.

var item_data: InventoryItem = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0

	if item_data and item_data.icon:
		sprite.texture = item_data.icon

	# Spawn bounce.
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 64.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y, 0.2).set_ease(Tween.EASE_IN)

## Set up the pickup with an InventoryItem. Call before adding to tree.
func setup(item: InventoryItem) -> void:
	item_data = item

func collect(collector: Node) -> void:
	if not item_data:
		queue_free()
		return

	var inventory: InventoryComponent = null
	for child in collector.get_children():
		if child is InventoryComponent:
			inventory = child
			break

	if inventory:
		if not inventory.add_item(item_data, 1):
			# Inventory full - bounce away.
			var away: Vector2 = (global_position - collector.global_position).normalized()
			var bounce := create_tween()
			bounce.tween_property(self, "global_position", global_position + away * 160.0, 0.2)
			return

	# Collected - shrink and remove.
	var shrink := create_tween()
	shrink.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	shrink.tween_callback(queue_free)
