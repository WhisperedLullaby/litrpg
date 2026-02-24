class_name StatsComponent
extends Node

# StatsComponent gives any entity a presence in "the system."
# A player, a bat, an NPC shopkeeper, a boss - if it has stats,
# it has this component. The rules (DerivedStats) apply equally.
#
# This component owns:
#   - Base stats (the entity's raw stat values)
#   - Modifier stack (buffs, debuffs, equipment bonuses)
#   - Final stat cache (base + modifiers, recalculated on change)
#
# Other components on the same entity read from this:
#   var stats: StatsComponent = $StatsComponent
#   var speed = DerivedStats.movement_speed(stats.get_stat("agility"))

signal stat_changed(stat_name: String, old_value: float, new_value: float)

# Base stats - set these per entity in the inspector or in code.
@export var base_stats: StatBlock

# All active modifiers.
var _modifiers: Array[StatModifier] = []

# Cache of final calculated values.
var _final_cache: Dictionary = {}

func _ready() -> void:
	# If no base_stats resource was assigned, create default.
	if not base_stats:
		base_stats = StatBlock.new()
	_recalculate_all()

func _process(delta: float) -> void:
	_process_durations(delta)

# --- Public API: Reading Stats ---

## Get the final calculated value of a stat.
func get_stat(stat_name: String) -> float:
	if _final_cache.has(stat_name):
		return _final_cache[stat_name]
	return base_stats.get_stat(stat_name)

## Get the unmodified base value.
func get_base_stat(stat_name: String) -> float:
	return base_stats.get_stat(stat_name)

# --- Public API: Modifying Stats ---

## Increase a base stat permanently (level up, permanent upgrade).
func increase_base_stat(stat_name: String, amount: float) -> void:
	var current := base_stats.get_stat(stat_name)
	base_stats.set_stat(stat_name, current + amount)
	_recalculate_stat(stat_name)

## Add a modifier. Returns it for later removal.
func add_modifier(modifier: StatModifier) -> StatModifier:
	_modifiers.append(modifier)
	_recalculate_stat(modifier.stat_name)
	return modifier

## Remove a specific modifier.
func remove_modifier(modifier: StatModifier) -> void:
	_modifiers.erase(modifier)
	_recalculate_stat(modifier.stat_name)

## Remove all modifiers from a source (buff expired, item unequipped).
func remove_modifiers_by_source(source: String) -> void:
	var affected: Dictionary = {}
	for mod in _modifiers:
		if mod.source == source:
			affected[mod.stat_name] = true
	_modifiers = _modifiers.filter(func(m): return m.source != source)
	for stat_name in affected:
		_recalculate_stat(stat_name)

## Get modifiers affecting a stat (for UI tooltip display).
func get_modifiers_for_stat(stat_name: String) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for mod in _modifiers:
		if mod.stat_name == stat_name:
			result.append(mod)
	return result

# --- Convenience: Derived Values ---
# These call DerivedStats so other scripts don't have to import it.

func get_movement_speed(base_speed: float = 384.0) -> float:
	return DerivedStats.movement_speed(get_stat("agility"), base_speed)

func get_max_health(base_hp: float = 100.0) -> float:
	return DerivedStats.max_health(get_stat("endurance"), base_hp)

func get_melee_attack_interval(base_interval: float = 3.0) -> float:
	return DerivedStats.melee_attack_interval(get_stat("dexterity"), base_interval)

func get_physical_damage(base_damage: float = 5.0) -> float:
	return DerivedStats.physical_damage(get_stat("strength"), base_damage)

func get_xp_absorption_rate(base_rate: float = 3.0, unlocked_nodes: int = 0) -> float:
	return DerivedStats.xp_absorption_rate(get_stat("attunement"), base_rate, unlocked_nodes)

func get_luck_multiplier() -> float:
	return DerivedStats.luck_multiplier(get_stat("luck"))

# --- Internal ---

func _recalculate_stat(stat_name: String) -> void:
	var old_value: float = _final_cache.get(stat_name, base_stats.get_stat(stat_name))
	var base: float = base_stats.get_stat(stat_name)

	var flat_total: float = 0.0
	var percent_total: float = 0.0

	for mod in _modifiers:
		if mod.stat_name != stat_name:
			continue
		match mod.type:
			StatModifier.Type.FLAT:
				flat_total += mod.value
			StatModifier.Type.PERCENT:
				percent_total += mod.value

	var new_value: float = maxf((base + flat_total) * (1.0 + percent_total), 0.0)
	_final_cache[stat_name] = new_value

	if not is_equal_approx(old_value, new_value):
		stat_changed.emit(stat_name, old_value, new_value)

func _recalculate_all() -> void:
	for stat_name in StatBlock.stat_names():
		_recalculate_stat(stat_name)

func _process_durations(delta: float) -> void:
	var expired: Array[StatModifier] = []
	for mod in _modifiers:
		if mod.duration <= 0.0:
			continue
		mod.duration -= delta
		if mod.duration <= 0.0:
			expired.append(mod)
	for mod in expired:
		remove_modifier(mod)
