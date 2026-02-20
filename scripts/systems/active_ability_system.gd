extends Node

# Global system that executes active abilities by ID.
# Items reference abilities by string ID; this system maps those
# to actual gameplay effects. Keeps item data clean of logic.

## Execute an ability. Returns true if it fired.
func use_ability(ability_id: String, user: Node2D) -> bool:
	match ability_id:
		"energy_blast":
			return _energy_blast(user)
		"heal_pulse":
			return _heal_pulse(user)
		"shadow_dash":
			return _shadow_dash(user)
		"test_a":
			return _test_a(user)
		"test_b":
			return _test_b(user)
	return false

# --- Ability Implementations ---

func _energy_blast(user: Node2D) -> bool:
	# AoE damage around the user.
	var damage := 15.0
	var radius := 60.0

	# Visual: expanding ring.
	var ring := Node2D.new()
	ring.global_position = user.global_position
	ring.set_script(_ring_script())
	ring.set_meta("radius", radius)
	ring.set_meta("color", Color(0.5, 0.3, 1.0, 0.7))
	get_tree().current_scene.add_child(ring)

	# Find and damage nearby enemies.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(user.global_position) <= radius:
			var health: HealthComponent = null
			for child in enemy.get_children():
				if child is HealthComponent:
					health = child
					break
			if health:
				health.take_damage(damage)

	return true

func _heal_pulse(user: Node2D) -> bool:
	# Restore 20% max HP.
	var health: HealthComponent = null
	for child in user.get_children():
		if child is HealthComponent:
			health = child
			break
	if not health:
		return false

	var heal_amount := health.max_health * 0.2
	health.heal(heal_amount)

	# Visual: green flash.
	var flash := Node2D.new()
	flash.global_position = user.global_position
	flash.set_script(_flash_script())
	flash.set_meta("color", Color(0.2, 0.9, 0.3, 0.6))
	get_tree().current_scene.add_child(flash)

	return true

func _shadow_dash(user: Node2D) -> bool:
	# Quick dash in facing direction.
	var status: StatusEffectComponent = null
	for child in user.get_children():
		if child is StatusEffectComponent:
			status = child
			break
	if not status:
		return false

	# Get facing direction from player.
	var direction := Vector2.DOWN
	if user.has_method("get") and "facing_direction" in user:
		match user.facing_direction:
			"front": direction = Vector2.DOWN
			"back": direction = Vector2.UP
			"left": direction = Vector2.LEFT
			"right": direction = Vector2.RIGHT

	var dash := StatusEffect.create_knockback(250.0, 0.15)
	dash.id = "shadow_dash"
	status.apply_effect(dash, direction)

	return true

func _test_a(user: Node2D) -> bool:
	print("item used")
	return true

func _test_b(user: Node2D) -> bool:
	print("item super used")
	return true

# --- Visual effect scripts (created dynamically) ---

func _ring_script() -> GDScript:
	if not has_meta("_ring_script_cache"):
		var script := GDScript.new()
		script.source_code = """extends Node2D
var _t := 0.0
var _max_radius := 60.0
var _color := Color.WHITE

func _ready():
	_max_radius = get_meta("radius")
	_color = get_meta("color")

func _process(delta):
	_t += delta * 4.0
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw():
	var r := _max_radius * _t
	var alpha := (1.0 - _t) * _color.a
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(_color.r, _color.g, _color.b, alpha), 2.0)
"""
		script.reload()
		set_meta("_ring_script_cache", script)
	return get_meta("_ring_script_cache")

func _flash_script() -> GDScript:
	if not has_meta("_flash_script_cache"):
		var script := GDScript.new()
		script.source_code = """extends Node2D
var _t := 0.0
var _color := Color.WHITE

func _ready():
	_color = get_meta("color")

func _process(delta):
	_t += delta * 3.0
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw():
	var alpha := (1.0 - _t) * _color.a
	var r := 12.0 + _t * 8.0
	draw_circle(Vector2.ZERO, r, Color(_color.r, _color.g, _color.b, alpha))
"""
		script.reload()
		set_meta("_flash_script_cache", script)
	return get_meta("_flash_script_cache")
