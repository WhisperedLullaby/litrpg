extends Node

# StatsSystem is a global convenience reference to the PLAYER's
# StatsComponent. It exists so that UI scripts and other global
# systems can access player stats without finding the player node.
#
# It is NOT the source of truth - the player's StatsComponent is.
# This just delegates to it.
#
# For enemy stats, access their StatsComponent directly:
#   var bat_stats: StatsComponent = bat_node.get_node("StatsComponent")

signal stat_changed(stat_name: String, old_value: float, new_value: float)

var _player_stats: StatsComponent = null

## Called by the player on _ready to register itself.
func register_player(stats_component: StatsComponent) -> void:
	_player_stats = stats_component
	# Forward the component's signals to the global bus.
	_player_stats.stat_changed.connect(_on_player_stat_changed)

func _on_player_stat_changed(stat_name: String, old_value: float, new_value: float) -> void:
	stat_changed.emit(stat_name, old_value, new_value)
	SignalBus.stat_changed.emit(stat_name, old_value, new_value)

# --- Convenience pass-through to player's StatsComponent ---

func get_stat(stat_name: String) -> float:
	if _player_stats:
		return _player_stats.get_stat(stat_name)
	return 1.0

func get_base_stat(stat_name: String) -> float:
	if _player_stats:
		return _player_stats.get_base_stat(stat_name)
	return 1.0

func increase_base_stat(stat_name: String, amount: float) -> void:
	if _player_stats:
		_player_stats.increase_base_stat(stat_name, amount)

func add_modifier(modifier: StatModifier) -> StatModifier:
	if _player_stats:
		return _player_stats.add_modifier(modifier)
	return modifier

func remove_modifier(modifier: StatModifier) -> void:
	if _player_stats:
		_player_stats.remove_modifier(modifier)

func remove_modifiers_by_source(source: String) -> void:
	if _player_stats:
		_player_stats.remove_modifiers_by_source(source)

## Direct access to the player's StatsComponent (for derived stat helpers).
func get_player_stats() -> StatsComponent:
	return _player_stats
