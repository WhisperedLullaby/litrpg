extends StaticBody2D

# A breakable jar that shatters when the player bumps into it.
# Rolls a loot table on break and drops items at its position.

var core_scene: PackedScene = preload("res://scenes/pickups/core_pickup.tscn")
var item_pickup_scene: PackedScene = preload("res://scenes/pickups/item_pickup.tscn")

const ITEM_DROP_CHANCE := 1.0  # 100% for testing.

var _loot_table: LootTable
var _is_breaking: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_loot_table = LootTable.new()
	_loot_table.drops = [
		LootDrop.create(core_scene, 1.0),  # Always drop a core
	]

func _on_detection_area_body_entered(body: Node2D) -> void:
	if _is_breaking:
		return
	if not body.is_in_group("player"):
		return
	_break()

func _break() -> void:
	_is_breaking = true

	# Stop detecting further collisions.
	$DetectionArea.set_deferred("monitoring", false)

	# Let the player bump against it briefly before it breaks.
	await get_tree().create_timer(0.15).timeout

	# Now disable the solid body so player walks through.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	# Roll loot and animate the break.
	_roll_loot()

	var tween := create_tween()
	tween.tween_property(sprite, "rotation", 0.15, 0.06)
	tween.tween_property(sprite, "rotation", -0.2, 0.08)
	tween.tween_property(sprite, "rotation", 0.4, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.6), 0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.15)
	tween.tween_callback(queue_free)

func _roll_loot() -> void:
	var scenes := _loot_table.roll(1.0)
	for scene in scenes:
		var drop := scene.instantiate()
		drop.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(20, 30))
		if drop.has_method("setup_quality"):
			drop.setup_quality(drop.quality_from_cultivation(0.0))
		get_tree().current_scene.add_child(drop)

	# Roll for equipment item drop.
	if randf() <= ITEM_DROP_CHANCE:
		var pickup := item_pickup_scene.instantiate()
		pickup.setup(ItemRegistry.random_item())
		pickup.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(20, 30))
		get_tree().current_scene.add_child(pickup)
