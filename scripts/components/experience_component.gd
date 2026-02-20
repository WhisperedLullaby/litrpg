class_name ExperienceComponent
extends Node

# ExperienceComponent gives any entity a presence in the system's
# progression mechanics. Like HealthComponent, it auto-discovers a
# sibling StatsComponent.
#
# The system's rules:
#   - ATT 1 = cannot absorb ambient energy (clouds). Level 0 entities are blind to it.
#   - ATT > 1 = can cultivate. Absorption rate scales with ATT (and future body nodes).
#
# total_xp_absorbed tracks how much ambient energy this entity has
# cultivated in its lifetime. When the entity dies, the loot system
# reads this to determine core quality - a well-cultivated enemy
# drops a more refined core.

signal xp_changed(current_xp: float, xp_to_next: float)
signal leveled_up(new_level: int)

@export var xp_scaling: float = 1.3
@export var base_xp_to_level: float = 20.0

var current_xp: float = 0.0
var current_level: int = 0
var xp_to_next_level: float = 20.0

# Lifetime cultivation tracker. Feeds into core quality on death.
var total_xp_absorbed: float = 0.0

var _stats: StatsComponent = null

func _ready() -> void:
	xp_to_next_level = base_xp_to_level
	_stats = _find_stats_component()

## Can this entity absorb ambient energy (XP clouds)?
## Requires ATT > 1 - the system doesn't grant cultivation to level 0 beings.
func can_absorb() -> bool:
	if not _stats:
		return false
	return _stats.get_stat("attunement") > 1.0

## How fast this entity absorbs ambient energy (XP per second).
## Returns 0 if they can't absorb at all.
func get_absorption_rate() -> float:
	if not _stats:
		return 0.0
	return _stats.get_xp_absorption_rate()

## Add XP directly. Used by whatever mechanism converts energy into
## experience (abilities, world events, cultivation techniques).
func add_direct_xp(amount: float) -> void:
	_add_xp(amount)

## Try to absorb ambient XP (from a cloud). Returns how much was
## actually absorbed this frame, based on absorption rate and delta.
## Returns 0 if this entity can't absorb.
func try_absorb(available: float, delta: float) -> float:
	if not can_absorb():
		return 0.0
	var rate := get_absorption_rate()
	var amount := minf(rate * delta, available)
	total_xp_absorbed += amount
	_add_xp(amount)
	return amount

func _add_xp(amount: float) -> void:
	current_xp += amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		current_level += 1
		xp_to_next_level = xp_to_next_level * xp_scaling
		leveled_up.emit(current_level)
		SignalBus.level_up.emit(current_level)
	xp_changed.emit(current_xp, xp_to_next_level)

func _find_stats_component() -> StatsComponent:
	for child in get_parent().get_children():
		if child is StatsComponent:
			return child
	return null
