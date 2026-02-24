extends Node2D

# Rare environment node. A metallic stake that projects a growing energy
# field as the player approaches. Walking into the field activates the zone.
#
# The field is purely visual — no collision shapes. Activation is a simple
# distance check: when the player is inside the current field radius, trigger.
#
# Field radius grows from FIELD_MIN to FIELD_MAX as the player closes in,
# so the field "reaches out" and meets the player at around half a tile away.

const DETECTION_RANGE := 512.0  # Distance at which the field starts reacting.
const FIELD_MIN_RADIUS := 20.0  # Field size when player is far away.
const FIELD_MAX_RADIUS := 192.0 # Field size when player is very close.

var _player: Node2D = null
var _activated: bool = false
var _field_radius: float = FIELD_MIN_RADIUS
var _time: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_time += delta

	if not _activated and _player:
		var dist := global_position.distance_to(_player.global_position)

		# Field grows as player approaches (t=0 far, t=1 at stake).
		var t := clampf(1.0 - (dist / DETECTION_RANGE), 0.0, 1.0)
		_field_radius = lerpf(FIELD_MIN_RADIUS, FIELD_MAX_RADIUS, t)

		if dist <= _field_radius:
			_activate()

	queue_redraw()


func _draw() -> void:
	_draw_stake()
	if not _activated:
		_draw_field()
	else:
		_draw_activated_burst()


func _draw_stake() -> void:
	# Body: dark metallic grey rectangle, origin at ground level.
	draw_rect(Rect2(-6, -80, 12, 80), Color(0.40, 0.42, 0.48, 1.0))
	# Tip: slightly lighter pointed triangle above the body.
	draw_colored_polygon(
		PackedVector2Array([Vector2(-6, -80), Vector2(6, -80), Vector2(0, -96)]),
		Color(0.55, 0.57, 0.64, 1.0)
	)
	# Metallic sheen: a thin bright streak slightly left of center.
	draw_line(Vector2(-2, -78), Vector2(-1, -6), Color(0.80, 0.84, 0.92, 0.55), 2.0)
	# Rivets / detail bands.
	for y in [-60, -40, -20]:
		draw_line(Vector2(-6, y), Vector2(6, y), Color(0.30, 0.32, 0.38, 0.8), 1.5)


func _draw_field() -> void:
	if _field_radius <= FIELD_MIN_RADIUS + 2.0:
		return

	var pulse := sin(_time * 3.0) * 0.06
	var r := _field_radius

	# Three concentric rings with decreasing opacity toward center.
	draw_arc(Vector2.ZERO, r,        0.0, TAU, 64, Color(0.30, 0.70, 1.0, 0.18 + pulse), 6.0)
	draw_arc(Vector2.ZERO, r * 0.7,  0.0, TAU, 48, Color(0.45, 0.82, 1.0, 0.28 + pulse), 3.0)
	draw_arc(Vector2.ZERO, r * 0.40, 0.0, TAU, 32, Color(0.65, 0.92, 1.0, 0.40 + pulse), 2.0)


func _draw_activated_burst() -> void:
	# Brief visual feedback on activation — bright expanding ring.
	var burst_radius := FIELD_MAX_RADIUS * clampf(_time, 0.0, 1.0)
	var alpha := clampf(1.0 - _time, 0.0, 1.0)
	draw_arc(Vector2.ZERO, burst_radius, 0.0, TAU, 64, Color(0.8, 1.0, 1.0, alpha), 4.0)


func _activate() -> void:
	_activated = true
	_time = 0.0  # Reset so burst animation plays from the start.
	print("[EnergyStake] Zone activated at ", global_position)
