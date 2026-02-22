extends Node2D

# Punch weapon controller. Manages a single persistent fist node.
# DEX governs attack speed, STR governs damage.
# The fist drives its own rhythm: strike → recovery → signal → next strike.

@export var punch_scene: PackedScene

var is_active: bool = false
var stats: StatsComponent
var fist: Area2D


func _ready() -> void:
	stats = get_parent().get_node("StatsComponent")

	stats.stat_changed.connect(_on_stat_changed)

	# Instantiate one persistent fist, hidden until toggled on.
	if punch_scene:
		fist = punch_scene.instantiate()
		fist.damage = stats.get_physical_damage()
		fist.set_recovery_duration(stats.get_melee_attack_interval() - 0.1)
		fist.recovery_finished.connect(_on_recovery_finished)
		get_parent().add_child.call_deferred(fist)
		fist.visible = false


func _process(_delta: float) -> void:
	if not fist or not is_active:
		return
	fist.update_facing(get_parent().facing_direction)


func _on_stat_changed(stat_name: String, _old: float, _new: float) -> void:
	if stat_name in ["dexterity", "strength"]:
		if fist:
			fist.damage = stats.get_physical_damage()
			fist.set_recovery_duration(stats.get_melee_attack_interval() - 0.1)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			toggle()


func toggle() -> void:
	is_active = !is_active
	if not fist:
		return

	if is_active:
		fist.visible = true
		fist.update_facing(get_parent().facing_direction)
		_do_strike()
	else:
		fist.visible = false


func _on_recovery_finished() -> void:
	if is_active:
		_do_strike()


func _do_strike() -> void:
	if not fist:
		return

	var facing: String = get_parent().facing_direction
	var dir: Vector2
	match facing:
		"front": dir = Vector2.DOWN
		"back": dir = Vector2.UP
		"left": dir = Vector2.LEFT
		"right": dir = Vector2.RIGHT
		_: dir = Vector2.DOWN

	fist.strike(dir)
