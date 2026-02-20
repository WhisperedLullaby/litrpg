class_name StatBlock
extends Resource

# StatBlock is pure data - it defines base stat values.
# It knows nothing about modifiers, abilities, or gameplay.
# Think of it as a character sheet before any buffs are applied.
#
# Stats:
#   AGI - Agility: Movement, reflexes, dodging, acrobatics
#   DEX - Dexterity: Hand skill, coordination, fine motor, weapon handling
#   STR - Strength: Physical power, melee damage, carry capacity
#   END - Endurance: Survival, vitality, toughness, stamina
#   ATT - Attunement: Magic, willpower, spells
#   PER - Perception: Senses, awareness, accuracy, processing speed
#   LCK - Luck: Rare drops, better offerings, hidden opportunities
#   OVR - Overclock: Magic systems, progression mechanics (deep system)

@export var agility: float = 1.0
@export var dexterity: float = 1.0
@export var strength: float = 1.0
@export var endurance: float = 1.0
@export var attunement: float = 1.0
@export var perception: float = 1.0
@export var luck: float = 1.0
@export var overclock: float = 0.0

# Utility: get/set stats by name string.
# This lets systems reference stats dynamically without
# giant match statements everywhere.
func get_stat(stat_name: String) -> float:
	match stat_name:
		"agility": return agility
		"dexterity": return dexterity
		"strength": return strength
		"endurance": return endurance
		"attunement": return attunement
		"perception": return perception
		"luck": return luck
		"overclock": return overclock
		_:
			push_warning("StatBlock: Unknown stat '%s'" % stat_name)
			return 0.0

func set_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"agility": agility = value
		"dexterity": dexterity = value
		"strength": strength = value
		"endurance": endurance = value
		"attunement": attunement = value
		"perception": perception = value
		"luck": luck = value
		"overclock": overclock = value
		_:
			push_warning("StatBlock: Unknown stat '%s'" % stat_name)

# Returns all stat names. Useful for iterating.
static func stat_names() -> PackedStringArray:
	return PackedStringArray([
		"agility", "dexterity", "strength", "endurance",
		"attunement", "perception", "luck", "overclock"
	])
