extends Node

# Dash Skill — diegetic cooldown movement ability.
# Three phases: BURST (knockback impulse), BOOST (AGI buff), SLOWDOWN (AGI debuff).
# At level 0 the total distance equals normal walking. Higher levels shift the
# balance toward more burst and less penalty.

enum State { READY, BURST, BOOST, SLOWDOWN }

const LEVEL_DATA := [
	{ "burst_force": 1200.0, "boost_mod": 0.50, "boost_dur": 0.20, "slowdown_mod": -0.70, "slowdown_dur": 0.60 },
	{ "burst_force": 1520.0, "boost_mod": 0.60, "boost_dur": 0.25, "slowdown_mod": -0.55, "slowdown_dur": 0.55 },
	{ "burst_force": 1840.0, "boost_mod": 0.75, "boost_dur": 0.30, "slowdown_mod": -0.40, "slowdown_dur": 0.50 },
	{ "burst_force": 2240.0, "boost_mod": 1.00, "boost_dur": 0.35, "slowdown_mod": -0.25, "slowdown_dur": 0.45 },
]

const BURST_DURATION := 0.10

var skill_level: int = 0
var _state: State = State.READY
var _timer: float = 0.0

var _player: CharacterBody2D
var _stats: StatsComponent
var _status_effects: StatusEffectComponent


func _ready() -> void:
	_player = get_parent()
	_stats = _player.get_node("StatsComponent")
	_status_effects = _player.get_node("StatusEffectComponent")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and _state == State.READY:
		_start_dash()


func _physics_process(delta: float) -> void:
	if _state == State.READY:
		return

	_timer -= delta
	if _timer <= 0.0:
		match _state:
			State.BURST:
				_enter_boost()
			State.BOOST:
				_enter_slowdown()
			State.SLOWDOWN:
				_player.speed_modifier = 1.0
				_state = State.READY


func _start_dash() -> void:
	_state = State.BURST
	_timer = BURST_DURATION

	var dir := _facing_to_vector(_player.facing_direction)
	var force := _get_burst_force()

	var burst := StatusEffect.create_knockback(force, BURST_DURATION)
	burst.id = "dash_burst"
	_status_effects.apply_effect(burst, dir)


func _enter_boost() -> void:
	_state = State.BOOST
	var data: Dictionary = LEVEL_DATA[skill_level]
	_timer = data["boost_dur"]
	_player.speed_modifier = 1.0 + _get_boost_modifier()


func _enter_slowdown() -> void:
	_state = State.SLOWDOWN
	var data: Dictionary = LEVEL_DATA[skill_level]
	_timer = _get_slowdown_duration()
	_player.speed_modifier = 1.0 + data["slowdown_mod"]


# --- Stat-scaled getters ---

func _get_burst_force() -> float:
	var base: float = LEVEL_DATA[skill_level]["burst_force"]
	var agi: float = _stats.get_stat("agility")
	var ovr: float = _stats.get_stat("overclock")
	return base * (1.0 + (agi - 1.0) * 0.12) + ovr * 20.0


func _get_boost_modifier() -> float:
	var base: float = LEVEL_DATA[skill_level]["boost_mod"]
	var agi: float = _stats.get_stat("agility")
	return base * (1.0 + (agi - 1.0) * 0.08)


func _get_slowdown_duration() -> float:
	var base: float = LEVEL_DATA[skill_level]["slowdown_dur"]
	var dex: float = _stats.get_stat("dexterity")
	return base / (1.0 + (dex - 5.0) * 0.10)


func _facing_to_vector(facing: String) -> Vector2:
	match facing:
		"front": return Vector2.DOWN
		"back": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		_: return Vector2.DOWN
