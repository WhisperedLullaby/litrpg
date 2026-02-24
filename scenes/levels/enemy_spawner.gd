extends Node2D

# The spawner creates enemies at random positions just outside the
# visible screen, so they walk in from the edges naturally.

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 20.0
@export var spawn_distance: float = 1200.0
@export var initial_delay: float = 2.0

var player: Node2D = null
var spawn_timer: Timer

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = false
	spawn_timer.timeout.connect(_on_spawn)
	add_child(spawn_timer)

	var delay_timer := Timer.new()
	delay_timer.wait_time = initial_delay
	delay_timer.one_shot = true
	delay_timer.timeout.connect(_on_delay_finished)
	add_child(delay_timer)
	delay_timer.start()

func _on_delay_finished() -> void:
	spawn_timer.start()
	_on_spawn()

func _on_spawn() -> void:
	if not player or not enemy_scene:
		return

	var angle := randf() * TAU
	var spawn_pos := player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance

	var enemy := enemy_scene.instantiate()
	enemy.global_position = spawn_pos

	# Spawn into YSortLayer for proper depth ordering.
	var ysort := get_parent().get_node("YSortLayer")
	if ysort:
		ysort.add_child(enemy)
	else:
		get_parent().add_child(enemy)
