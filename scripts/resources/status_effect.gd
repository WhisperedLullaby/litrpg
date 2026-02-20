class_name StatusEffect
extends Resource

# A status effect template. Define once, apply anywhere.
# Any attack, spell, or game event can reference the same effect
# without reimplementing the logic.
#
# Effects can do one or more of:
#   - Modify stats (slow, haste, weaken, empower)
#   - Apply knockback (punch, explosion, shield bash)
#   - Deal damage over time (poison, burn)
#
# The StatusEffectComponent on the entity handles the lifecycle:
# applying modifiers, ticking damage, decaying knockback, and
# cleaning up when the duration expires.

@export var id: String = ""
@export var duration: float = 1.0
@export var stackable: bool = false   ## Can multiple instances coexist?
@export var refreshable: bool = true  ## Does reapplying reset the timer?

# --- Stat Modifiers ---
# Applied when the effect starts, removed when it ends.
# Uses the existing StatModifier system with source = "status:<id>".
@export var stat_modifiers: Array[StatModifier] = []

# --- Knockback ---
# Impulse force applied in a direction. Decays over the duration.
@export var knockback_force: float = 0.0

# --- Damage Over Time ---
@export var damage_per_second: float = 0.0

## Create a simple knockback effect.
static func create_knockback(force: float, dur: float = 0.2) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.id = "knockback"
	effect.duration = dur
	effect.knockback_force = force
	effect.stackable = false
	effect.refreshable = true
	return effect

## Create a stat modifier effect (slow, haste, etc).
static func create_stat_effect(effect_id: String, stat_name: String,
		mod_type: StatModifier.Type, value: float, dur: float = 0.0) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.id = effect_id
	effect.duration = dur
	var mod := StatModifier.new()
	mod.stat_name = stat_name
	mod.type = mod_type
	mod.value = value
	mod.source = "status:" + effect_id
	effect.stat_modifiers = [mod]
	return effect
