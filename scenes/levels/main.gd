extends Node2D

# The main scene wires systems together.

var item_pickup_scene: PackedScene = preload("res://scenes/pickups/item_pickup.tscn")

func _ready() -> void:
	var player := $YSortLayer/Player
	var health_bar := $UI/HealthBar
	var xp_bar := $UI/XPBar
	var world_gen := $WorldGenerator
	var ysort_layer := $YSortLayer

	# Wire health bar to player's HealthComponent.
	var health_component: HealthComponent = player.get_node("HealthComponent")
	health_bar.setup(health_component)

	# Wire XP bar to player's ExperienceComponent.
	var xp_component: ExperienceComponent = player.get_node("ExperienceComponent")
	xp_bar.setup(xp_component)

	# Give the world generator references it sdsdneeds.
	world_gen.player = player
	world_gen.ysort_layer = ysort_layer

	# Hide UI elements at start.
	health_bar.visible = false
	xp_bar.visible = false

	# Spawn test items on opposite sides of the player.
	_spawn_test_items(player)

func _spawn_test_items(player: Node2D) -> void:
	var orb_pickup := item_pickup_scene.instantiate()
	orb_pickup.setup(ItemRegistry.test_orb())
	orb_pickup.global_position = player.global_position + Vector2(-120, 0)
	$YSortLayer.add_child(orb_pickup)

	var lamp_pickup := item_pickup_scene.instantiate()
	lamp_pickup.setup(ItemRegistry.test_lamp())
	lamp_pickup.global_position = player.global_position + Vector2(120, 0)
	$YSortLayer.add_child(lamp_pickup)
