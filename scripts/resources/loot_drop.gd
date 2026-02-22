class_name LootDrop
extends Resource

# A single entry in a loot table. Defines what CAN drop and the
# base probability. Luck modifies the roll at runtime.

@export var scene: PackedScene
@export var drop_chance: float = 0.5  ## Base chance 0.0 to 1.0
@export var min_count: int = 1
@export var max_count: int = 1

static func create(p_scene: PackedScene, chance: float, min_c: int = 1, max_c: int = 1) -> LootDrop:
	var drop := LootDrop.new()
	drop.scene = p_scene
	drop.drop_chance = chance
	drop.min_count = min_c
	drop.max_count = max_c
	return drop
