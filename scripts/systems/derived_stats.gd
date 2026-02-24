class_name DerivedStats

# DerivedStats defines THE SYSTEM's rules for how raw stats
# translate into gameplay values. These formulas are universal -
# they apply to every entity equally. A bat with AGI 2 uses the
# same speed formula as a player with AGI 2.
#
# This is a static utility class - no instances, just functions.
# Every formula is documented with example values so you can
# reason about game balance without running the game.

# --- Movement ---

## Calculates movement speed from Agility.
## AGI 1 → 384, AGI 3 → 476, AGI 5 → 568, AGI 10 → 798
static func movement_speed(agility: float, base_speed: float = 384.0) -> float:
	return base_speed * (1.0 + (agility - 1.0) * 0.12)

# --- Combat ---

## Calculates melee attack interval (seconds) from Dexterity.
## DEX 1 → 3.0s, DEX 3 → 2.3s, DEX 5 → 1.8s, DEX 10 → 1.05s
static func melee_attack_interval(dexterity: float, base_interval: float = 3.0) -> float:
	return base_interval / (1.0 + (dexterity - 1.0) * 0.15)

## Calculates physical damage from Strength.
## STR 1 → 5, STR 3 → 8, STR 5 → 11, STR 10 → 18.5
static func physical_damage(strength: float, base_damage: float = 5.0) -> float:
	return base_damage + (strength - 1.0) * 1.5

## Calculates ranged/spell attack interval from Dexterity + Attunement mix.
## (Future: will use attunement for magic weapons)
static func ranged_attack_interval(dexterity: float, base_interval: float = 0.8) -> float:
	return base_interval / (1.0 + (dexterity - 1.0) * 0.10)

# --- Survival ---

## Calculates max HP from Endurance.
## END 1 → 100, END 3 → 130, END 5 → 160, END 10 → 235
static func max_health(endurance: float, base_hp: float = 100.0) -> float:
	return base_hp * (1.0 + (endurance - 1.0) * 0.15)

## Calculates i-frame duration from Agility.
## AGI 1 → 0.5s, AGI 5 → 0.7s, AGI 10 → 0.95s
static func invincibility_duration(agility: float, base_duration: float = 0.5) -> float:
	return base_duration * (1.0 + (agility - 1.0) * 0.05)

# --- Perception ---

## Calculates detection/awareness range from Perception.
## PER 1 → 800px, PER 5 → 1280px, PER 10 → 1880px
static func awareness_range(perception: float, base_range: float = 800.0) -> float:
	return base_range * (1.0 + (perception - 1.0) * 0.15)

# --- Luck ---

## Calculates a luck multiplier for drop quality/rarity.
## LCK 1 → 1.0x, LCK 5 → 1.4x, LCK 10 → 1.9x
static func luck_multiplier(luck: float) -> float:
	return 1.0 + (luck - 1.0) * 0.10

# --- Magic (Attunement) ---

## Calculates mana/magic resource pool from Attunement.
## ATT 1 → 50, ATT 5 → 90, ATT 10 → 140
static func magic_pool(attunement: float, base_pool: float = 50.0) -> float:
	return base_pool * (1.0 + (attunement - 1.0) * 0.20)

## Calculates XP absorption rate from Attunement.
## The system only allows cultivation when ATT > 1.
## At level 0, all entities have ATT 1 - they cannot absorb ambient energy.
## Each point of ATT above 1 adds base_rate XP/s of absorption capacity.
## Future: unlocked_nodes (body cultivation nodes) add bonus rate.
## ATT 1 → 0/s (blocked), ATT 2 → 3/s, ATT 5 → 12/s, ATT 10 → 27/s
static func xp_absorption_rate(attunement: float, base_rate: float = 3.0, unlocked_nodes: int = 0) -> float:
	if attunement <= 1.0:
		return 0.0
	var att_rate := base_rate * (attunement - 1.0)
	var node_bonus := unlocked_nodes * 0.5
	return att_rate + node_bonus
