class_name ItemRegistry
extends RefCounted

# Static definitions for all equipment items in the game.
# Each item has passive stat modifiers and an active ability ID.

static func test_orb() -> InventoryItem:
	# Passive: tints the player red (via modulate, applied in inventory_component).
	# Active: prints "item used"
	var item := InventoryItem.new()
	item.id = "test_orb"
	item.display_name = "Test Orb"
	item.size = InventoryItem.Size.SMALL
	item.max_stack = 1
	item.active_id = "test_a"
	item.active_cooldown = 1.0
	item.color = Color(1.0, 0.3, 0.3)
	item.passive_tag = "tint_red"
	if ResourceLoader.exists("res://sprites/100 Icons RPG - Free version/Abyssal orb/Abyssal orb1.png"):
		item.icon = load("res://sprites/100 Icons RPG - Free version/Abyssal orb/Abyssal orb1.png")
	return item

static func test_lamp() -> InventoryItem:
	# Passive: adds particle trail to the player.
	# Active: prints "item super used"
	var item := InventoryItem.new()
	item.id = "test_lamp"
	item.display_name = "Test Lamp"
	item.size = InventoryItem.Size.SMALL
	item.max_stack = 1
	item.active_id = "test_b"
	item.active_cooldown = 1.0
	item.color = Color(0.3, 1.0, 0.5)
	item.passive_tag = "particle_trail"
	if ResourceLoader.exists("res://sprites/100 Icons RPG - Free version/Abyssal lamp/Abyssal lamp1.png"):
		item.icon = load("res://sprites/100 Icons RPG - Free version/Abyssal lamp/Abyssal lamp1.png")
	return item

## Get a random equipment item for loot drops.
static func random_item() -> InventoryItem:
	if randi() % 2 == 0:
		return test_orb()
	return test_lamp()
