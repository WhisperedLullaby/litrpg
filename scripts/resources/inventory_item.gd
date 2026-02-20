class_name InventoryItem
extends Resource

# Defines what an item IS. Shared between all stacks of the same item.
# The inventory stores references to these plus a count per slot.
#
# Items can have:
#   - Passive effects: StatModifiers applied while the item is held
#   - Active ability: triggered with Space when selected (Q/E to pick)

enum Size { TINY, SMALL, MEDIUM, LARGE }

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var size: Size = Size.TINY
@export var max_stack: int = 1
@export var energy_value: float = 0.0
@export var quality: int = 0  ## Maps to core quality tiers.

# Colors for visual representation (orbit sprites, UI icons).
@export var color: Color = Color.WHITE

# Passive stat modifiers - always active when in inventory.
@export var passive_effects: Array[StatModifier] = []

# Active ability - usable with Space when this item is selected.
@export var active_id: String = ""  ## Maps to ActiveAbilitySystem.
@export var active_cooldown: float = 0.0
@export var active_description: String = ""

# Visual passive tag - triggers a visual effect on the holder.
@export var passive_tag: String = ""

## True if this item is a core (orbits) vs a real item (trails).
func is_core() -> bool:
	return id.begins_with("core_")

## Factory for core items by quality tier.
static func create_core(quality_tier: int) -> InventoryItem:
	var item := InventoryItem.new()
	item.size = Size.TINY
	item.max_stack = 10
	item.quality = quality_tier

	match quality_tier:
		0:  # COMMON
			item.id = "core_common"
			item.display_name = "Common Core"
			item.energy_value = 1.0
			item.color = Color(0.6, 0.7, 0.8)
		1:  # UNCOMMON
			item.id = "core_uncommon"
			item.display_name = "Uncommon Core"
			item.energy_value = 3.0
			item.color = Color(0.3, 0.8, 0.3)
		2:  # RARE
			item.id = "core_rare"
			item.display_name = "Rare Core"
			item.energy_value = 8.0
			item.color = Color(0.3, 0.5, 1.0)
		3:  # EPIC
			item.id = "core_epic"
			item.display_name = "Epic Core"
			item.energy_value = 20.0
			item.color = Color(0.9, 0.5, 0.1)
		4:  # LEGENDARY
			item.id = "core_legendary"
			item.display_name = "Legendary Core"
			item.energy_value = 50.0
			item.color = Color(0.9, 0.15, 0.15)

	return item

## Factory for equipment items with passives and actives.
static func create_item(item_id: String, name: String, icon_path: String,
		item_size: Size, active: String, cooldown: float,
		passives: Array[StatModifier] = []) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = item_id
	item.display_name = name
	item.size = item_size
	item.max_stack = 1
	item.active_id = active
	item.active_cooldown = cooldown
	item.passive_effects = passives
	item.color = Color.WHITE
	if ResourceLoader.exists(icon_path):
		item.icon = load(icon_path)
	return item
