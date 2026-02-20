extends Node

# SignalBus is a global event system (autoload singleton).
# Any node can emit or listen to these signals without needing
# a direct reference to another node. This keeps systems decoupled.
#
# Example: when a bat dies, it emits enemy_died here. The XP system
# listens for enemy_died and spawns drops. Neither knows about the other.

signal enemy_died(position: Vector2, xp_value: float)
signal level_up(new_level: int)
signal core_collected(energy_value: float)

# Stat system
signal stat_changed(stat_name: String, old_value: float, new_value: float)

# Ability system (future)
signal ability_unlocked(ability_id: String)
signal ability_activated(ability_id: String)

# UI gating (future - driven by abilities, not stats directly)
signal ui_element_unlocked(element_name: String)
