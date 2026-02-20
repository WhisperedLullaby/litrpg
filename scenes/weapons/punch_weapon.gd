extends Node2D

# The punch weapon reads from the entity's StatsComponent.
# DEX governs attack speed, STR governs damage.
# Same script could work on an enemy that punches - same rules.

@export var punch_scene: PackedScene

var is_active: bool = false
var timer: Timer
var stats: StatsComponent

func _ready() -> void:
	# Find the StatsComponent on our parent entity.
	stats = get_parent().get_node("StatsComponent")

	timer = Timer.new()
	timer.autostart = false
	timer.timeout.connect(_on_punch)
	add_child(timer)

	# Listen for stat changes to update attack speed.
	stats.stat_changed.connect(_on_stat_changed)
	_recalculate_from_stats()

func _recalculate_from_stats() -> void:
	timer.wait_time = stats.get_melee_attack_interval()

func _on_stat_changed(stat_name: String, _old: float, _new: float) -> void:
	if stat_name in ["dexterity", "strength"]:
		_recalculate_from_stats()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			toggle()

func toggle() -> void:
	is_active = !is_active
	if is_active:
		timer.start()
		_on_punch()
	else:
		timer.stop()

func _on_punch() -> void:
	if not punch_scene:
		return

	var player := get_parent()
	var facing: String = player.facing_direction

	var direction: Vector2
	match facing:
		"front": direction = Vector2.DOWN
		"back": direction = Vector2.UP
		"left": direction = Vector2.LEFT
		"right": direction = Vector2.RIGHT
		_: direction = Vector2.DOWN

	var punch := punch_scene.instantiate()
	# Damage comes from STR through the system's formula.
	punch.damage = stats.get_physical_damage()
	get_parent().add_child(punch)
	punch.setup(direction)
