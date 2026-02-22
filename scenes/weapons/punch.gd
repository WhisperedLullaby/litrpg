extends Area2D

# Persistent diegetic fist with 3 states:
#   READY    - sitting at pocket position, fully opaque, waiting
#   STRIKE   - shooting outward, hitbox active
#   RECOVERY - drifting back to pocket, semi-transparent, harmless

enum State { READY, STRIKE, RECOVERY }

signal recovery_finished

@export var damage: float = 8.0

var direction: Vector2 = Vector2.DOWN
var state: State = State.READY

# Pocket position (relative to player) based on facing direction.
var _pocket_target: Vector2 = Vector2(6, 8)
# Current alpha for draw modulation.
var _alpha: float = 1.0

# Strike config.
var _strike_target: Vector2 = Vector2.ZERO
var _strike_duration: float = 0.1
var _strike_tween: Tween

# Recovery config.
var _recovery_duration: float = 2.9
var _recovery_elapsed: float = 0.0
var _recovery_start_pos: Vector2 = Vector2.ZERO

# Knockback effect applied on hit.
var _knockback := StatusEffect.create_knockback(120.0, 0.25)

# Reference to collision shape for enable/disable.
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << (3 - 1)
	area_entered.connect(_on_area_entered)
	# Start at pocket position.
	position = _pocket_target


func _process(delta: float) -> void:
	match state:
		State.READY:
			# Smoothly track pocket position as facing changes.
			position = position.lerp(_pocket_target, 10.0 * delta)
			_alpha = 1.0

		State.STRIKE:
			# Tween handles position. Keep alpha solid.
			_alpha = 1.0

		State.RECOVERY:
			_recovery_elapsed += delta
			var t := clampf(_recovery_elapsed / _recovery_duration, 0.0, 1.0)
			# Smooth ease-out for position drift back.
			var ease_t := 1.0 - pow(1.0 - t, 2.0)
			position = _recovery_start_pos.lerp(_pocket_target, ease_t)
			# Alpha fades from 0.4 back to 1.0.
			_alpha = lerpf(0.4, 1.0, t)

			if t >= 1.0:
				_enter_ready()

	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.65, 0.5, 0.7 * _alpha))
	draw_circle(Vector2.ZERO, 3.0, Color(0.92, 0.75, 0.6, 0.9 * _alpha))


func strike(dir: Vector2) -> void:
	if state != State.READY:
		return

	direction = dir
	state = State.STRIKE
	_strike_target = dir * 22.0
	_alpha = 1.0

	# Enable hitbox.
	_collision.disabled = false

	# Kill any existing tween.
	if _strike_tween and _strike_tween.is_valid():
		_strike_tween.kill()

	_strike_tween = create_tween()
	_strike_tween.tween_property(self, "position", _strike_target, _strike_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_strike_tween.tween_callback(_on_strike_done)


func _on_strike_done() -> void:
	# Disable hitbox, enter recovery.
	_collision.disabled = true
	_enter_recovery()


func _enter_recovery() -> void:
	state = State.RECOVERY
	_recovery_elapsed = 0.0
	_recovery_start_pos = position
	_alpha = 0.4


func _enter_ready() -> void:
	state = State.READY
	_alpha = 1.0
	recovery_finished.emit()


func set_recovery_duration(t: float) -> void:
	_recovery_duration = maxf(t, 0.05)


func update_facing(dir: String) -> void:
	match dir:
		"front": _pocket_target = Vector2(6, 8)
		"back": _pocket_target = Vector2(6, -8)
		"left": _pocket_target = Vector2(8, 2)
		"right": _pocket_target = Vector2(-8, 2)


func _on_area_entered(area: Area2D) -> void:
	if state != State.STRIKE:
		return
	if area is HurtboxComponent:
		area.take_hit(damage, global_position)
		var entity := area.get_parent()
		var status := _find_status_effect_component(entity)
		if status:
			status.apply_effect(_knockback, direction)
		# Hit landed - go to recovery immediately.
		_on_strike_done()


func _find_status_effect_component(entity: Node) -> StatusEffectComponent:
	for child in entity.get_children():
		if child is StatusEffectComponent:
			return child
	return null
