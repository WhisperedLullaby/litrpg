class_name StatusEffectComponent
extends Node

# Manages active status effects on an entity. Handles duration,
# stacking, stat modifier application/removal, knockback decay,
# and damage-over-time ticking.
#
# Auto-discovers sibling StatsComponent and HealthComponent.
# The entity's movement code should add get_knockback_velocity()
# to its velocity calculation.

signal effect_applied(effect_id: String)
signal effect_removed(effect_id: String)

# Active effect instances. Key = effect id, Value = instance data.
var _active: Dictionary = {}

# Knockback state - accumulated from all active knockback effects.
var _knockback_velocity: Vector2 = Vector2.ZERO

var _stats: StatsComponent = null
var _health: HealthComponent = null

func _ready() -> void:
	_stats = _find_sibling(StatsComponent)
	_health = _find_sibling(HealthComponent)

func _physics_process(delta: float) -> void:
	var expired: Array[String] = []

	for id in _active:
		var instance: Dictionary = _active[id]
		var effect: StatusEffect = instance["effect"]

		# Tick duration (0 = permanent, managed externally).
		if effect.duration > 0:
			instance["time_remaining"] -= delta
			if instance["time_remaining"] <= 0:
				expired.append(id)
				continue

		# Tick DOT.
		if effect.damage_per_second > 0 and _health:
			_health.take_damage(effect.damage_per_second * delta)

	# Decay knockback.
	if _knockback_velocity.length() > 1.0:
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		_knockback_velocity = Vector2.ZERO

	# Clean up expired effects.
	for id in expired:
		_remove_effect_internal(id)

## Apply a status effect to this entity.
## direction is used for knockback (normalized direction of the hit).
func apply_effect(effect: StatusEffect, direction: Vector2 = Vector2.ZERO) -> void:
	if _active.has(effect.id):
		if effect.refreshable:
			# Reset the timer.
			_active[effect.id]["time_remaining"] = effect.duration
			# Re-apply knockback with fresh force.
			if effect.knockback_force > 0:
				_knockback_velocity = direction.normalized() * effect.knockback_force
			return
		elif not effect.stackable:
			return

	# Create new instance.
	var instance := {
		"effect": effect,
		"time_remaining": effect.duration,
	}
	_active[effect.id] = instance

	# Apply stat modifiers.
	if _stats and effect.stat_modifiers.size() > 0:
		for mod_template in effect.stat_modifiers:
			# Clone the modifier so each instance is independent.
			var mod := StatModifier.new()
			mod.stat_name = mod_template.stat_name
			mod.type = mod_template.type
			mod.value = mod_template.value
			mod.source = "status:" + effect.id
			_stats.add_modifier(mod)

	# Apply knockback impulse.
	if effect.knockback_force > 0 and direction != Vector2.ZERO:
		_knockback_velocity = direction.normalized() * effect.knockback_force

	effect_applied.emit(effect.id)

## Remove a status effect by id.
func remove_effect(effect_id: String) -> void:
	if _active.has(effect_id):
		_remove_effect_internal(effect_id)

## Check if an effect is currently active.
func has_effect(effect_id: String) -> bool:
	return _active.has(effect_id)

## Get current knockback velocity. Entity movement code should add
## this to their velocity calculation.
func get_knockback_velocity() -> Vector2:
	return _knockback_velocity

func _remove_effect_internal(effect_id: String) -> void:
	if not _active.has(effect_id):
		return

	# Remove stat modifiers applied by this effect.
	if _stats:
		_stats.remove_modifiers_by_source("status:" + effect_id)

	_active.erase(effect_id)
	effect_removed.emit(effect_id)

func _find_sibling(type: Variant) -> Node:
	for child in get_parent().get_children():
		if is_instance_of(child, type):
			return child
	return null
