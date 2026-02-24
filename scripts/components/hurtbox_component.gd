class_name HurtboxComponent
extends Area2D

# The hurtbox is "I can be hurt." It listens for hitboxes entering
# its area. When one does, it finds the HealthComponent on our
# parent and applies damage.
#
# Collision layers separate WHO can hurt WHOM:
#   Layer 2 = "player hurtbox"  (enemy hitboxes scan for this)
#   Layer 3 = "enemy hurtbox"   (player weapons scan for this)
#
# This prevents friendly fire - player projectiles only look for
# layer 3, so they skip the player's own hurtbox on layer 2.

@export_enum("player:2", "enemy:3") var hurtbox_layer: int = 2
@export var invincibility_time: float = 0.5
@export var knockback_on_hit: float = 0.0  ## Knockback force applied to self when hit.
@export var show_blood: bool = false  ## Spawn blood particles on hit.

var _can_be_hurt: bool = true
var _knockback_effect: StatusEffect = null

func _ready() -> void:
	collision_layer = 1 << (hurtbox_layer - 1)
	collision_mask = 0
	if knockback_on_hit > 0:
		_knockback_effect = StatusEffect.create_knockback(knockback_on_hit, 0.2)

func take_hit(damage: float, hit_from: Vector2 = Vector2.ZERO) -> void:
	if not _can_be_hurt:
		return

	var health := _get_health_component()
	if health:
		health.take_damage(damage)

	# Apply knockback to ourselves (pushed away from the attacker).
	if _knockback_effect and hit_from != Vector2.ZERO:
		var direction: Vector2 = (get_parent().global_position - hit_from).normalized()
		var status := _get_status_effect_component()
		if status:
			status.apply_effect(_knockback_effect, direction)

	# Spawn blood particles.
	if show_blood:
		_spawn_blood()

	# I-frames.
	_can_be_hurt = false
	get_tree().create_timer(invincibility_time).timeout.connect(
		func(): _can_be_hurt = true
	)

func _spawn_blood() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()

	# Blood red, tiny droplets spraying outward.
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 160.0
	mat.initial_velocity_max = 400.0
	mat.gravity = Vector3(0, 480, 0)
	mat.scale_min = 8.0
	mat.scale_max = 20.0
	mat.color = Color(0.7, 0.05, 0.05, 0.9)

	particles.process_material = mat
	particles.amount = 8
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	particles.global_position = get_parent().global_position + Vector2(0, -48)

	# Add to scene tree (not as child of entity, so it persists after i-frames).
	get_tree().current_scene.add_child(particles)
	# Auto-cleanup after particles finish.
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)

func _get_health_component() -> HealthComponent:
	for child in get_parent().get_children():
		if child is HealthComponent:
			return child
	return null

func _get_status_effect_component() -> StatusEffectComponent:
	for child in get_parent().get_children():
		if child is StatusEffectComponent:
			return child
	return null
