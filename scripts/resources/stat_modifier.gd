class_name StatModifier
extends Resource

# A single modifier that adjusts a stat. Modifiers stack.
#
# Types:
#   FLAT    - adds a fixed amount (base + flat = subtotal)
#   PERCENT - multiplies the subtotal (subtotal * percent = final)
#
# Calculation order matters:
#   Final = (Base + sum(FLAT mods)) * product(1.0 + each PERCENT mod)
#
# Example: Agility base 5, +2 flat from boots, +10% from buff
#   = (5 + 2) * (1.0 + 0.10) = 7 * 1.1 = 7.7
#
# The source tag identifies WHERE this modifier came from.
# When the source is removed (buff expires, item unequipped),
# all modifiers with that source are removed cleanly.

enum Type { FLAT, PERCENT }

@export var stat_name: String          # which stat this modifies
@export var type: Type = Type.FLAT     # flat addition or percent multiplier
@export var value: float = 0.0         # the modifier amount
@export var source: String = ""        # who/what created this modifier

# Duration-based modifiers (0 = permanent until removed).
@export var duration: float = 0.0

static func create_flat(stat: String, amount: float, src: String, dur: float = 0.0) -> StatModifier:
	var mod := StatModifier.new()
	mod.stat_name = stat
	mod.type = Type.FLAT
	mod.value = amount
	mod.source = src
	mod.duration = dur
	return mod

static func create_percent(stat: String, amount: float, src: String, dur: float = 0.0) -> StatModifier:
	var mod := StatModifier.new()
	mod.stat_name = stat
	mod.type = Type.PERCENT
	mod.value = amount
	mod.source = src
	mod.duration = dur
	return mod
