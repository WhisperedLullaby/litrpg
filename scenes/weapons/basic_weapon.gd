extends Node2D

# The basic auto-fire weapon. Finds the nearest enemy and shoots
# a projectile at it on a timer. The player doesn't need to aim -
# this is Vampire Survivors style, everything is automatic.

@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.8
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 200.0

# Locked weapons don't fire. Unlock later through progression.
var is_locked: bool = true
var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = fire_rate
	timer.autostart = false  # Don't start until unlocked
	timer.timeout.connect(_on_fire)
	add_child(timer)

func unlock() -> void:
	is_locked = false
	timer.start()

func _on_fire() -> void:
	if is_locked:
		return
	var nearest_enemy := _find_nearest_enemy()
	if not nearest_enemy:
		return

	# Calculate direction from player to enemy.
	var direction: Vector2 = global_position.direction_to(nearest_enemy.global_position)

	# Instantiate and configure the projectile.
	var projectile := projectile_scene.instantiate()
	projectile.global_position = global_position
	projectile.direction = direction
	projectile.damage = projectile_damage
	projectile.speed = projectile_speed
	# Rotate the sprite to face the direction of travel.
	projectile.rotation = direction.angle()

	# Add to the scene tree at the level root (not as our child).
	# If we added it as our child, it would move with the player.
	get_tree().current_scene.add_child(projectile)

func _find_nearest_enemy() -> Node2D:
	# get_nodes_in_group returns all nodes tagged "enemies".
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF  # start with infinity, anything will be closer

	for enemy in enemies:
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest
