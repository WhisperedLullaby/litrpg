extends Area2D

# A projectile flies in a straight line and damages the first
# enemy it hits. It's an Area2D (not CharacterBody2D) because
# we don't need physics collisions - just overlap detection.

@export var speed: float = 200.0
@export var damage: float = 10.0
@export var max_range: float = 300.0  # despawn after traveling this far

var direction := Vector2.RIGHT
var distance_traveled := 0.0

func _ready() -> void:
	# The projectile scans for ENEMY hurtboxes (layer 3).
	# Layer 2 is player hurtboxes - we skip that so we don't hit ourselves.
	collision_layer = 0
	collision_mask = 1 << (3 - 1)  # Layer 3 = enemy hurtboxes
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Move in our direction every frame.
	var movement := direction * speed * delta
	position += movement
	distance_traveled += movement.length()

	# Despawn if we've gone too far (missed everything).
	# Without this, missed projectiles would fly forever and leak memory.
	if distance_traveled >= max_range:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# When we overlap a hurtbox, deal damage and destroy ourselves.
	if area is HurtboxComponent:
		area.take_hit(damage)
		queue_free()
