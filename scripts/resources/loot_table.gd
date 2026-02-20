class_name LootTable
extends Resource

# A loot table defines the possible drops for an entity.
# Each entry is rolled independently - an entity could drop
# nothing, one thing, or several things.
#
# Luck influences drop chance: effective_chance = base_chance * luck_multiplier.
# A luck_multiplier of 1.0 is neutral. The system's luck formula
# (DerivedStats.luck_multiplier) produces values like 1.0 to 1.9.

@export var drops: Array[LootDrop] = []

## Roll the table. Returns an array of PackedScenes to instantiate.
## Each entry is rolled independently against its drop_chance * luck.
func roll(luck_multiplier: float = 1.0) -> Array[PackedScene]:
	var results: Array[PackedScene] = []
	for drop in drops:
		if not drop.scene:
			continue
		var effective_chance := clampf(drop.drop_chance * luck_multiplier, 0.0, 1.0)
		if randf() <= effective_chance:
			var count := randi_range(drop.min_count, drop.max_count)
			for i in count:
				results.append(drop.scene)
	return results
