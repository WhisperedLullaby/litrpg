class_name HealthComponent
extends Node

# Health component. Can optionally scale with the entity's
# Endurance stat if a StatsComponent sibling exists.

signal health_changed(current_health: float, max_health: float)
signal died

@export var max_health: float = 100.0
@export var base_max_health: float = 100.0

var current_health: float:
	set(value):
		current_health = clampf(value, 0.0, max_health)
		health_changed.emit(current_health, max_health)
		if current_health <= 0.0:
			died.emit()

var _stats: StatsComponent = null

func _ready() -> void:
	# Initialize health BEFORE stats scaling so proportional math works.
	# Without this, current_health is 0.0 and scaling preserves that zero.
	current_health = max_health

	# Look for a StatsComponent sibling. If found, scale HP with END.
	_stats = _find_stats_component()
	if _stats:
		_stats.stat_changed.connect(_on_stat_changed)
		_recalculate_from_stats()

func take_damage(amount: float) -> void:
	current_health -= amount

func heal(amount: float) -> void:
	current_health += amount

func _recalculate_from_stats() -> void:
	var old_max := max_health
	max_health = _stats.get_max_health(base_max_health)

	# Scale current health proportionally.
	if old_max > 0:
		current_health = current_health * (max_health / old_max)
	else:
		current_health = max_health

func _on_stat_changed(stat_name: String, _old: float, _new: float) -> void:
	if stat_name == "endurance":
		_recalculate_from_stats()

func _find_stats_component() -> StatsComponent:
	for child in get_parent().get_children():
		if child is StatsComponent:
			return child
	return null
