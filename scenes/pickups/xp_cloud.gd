extends Area2D

# The XP Cloud is ambient energy released when an entity dies.
# It decays over time - the system reclaims what isn't absorbed.
#
# ANY entity with an ExperienceComponent that can_absorb() will
# pull from this cloud while standing inside it. Multiple entities
# can compete for the same pool - a high-ATT enemy could drain it
# before the player does.
#
# At level 0 (ATT 1), entities can't absorb at all. The energy
# just fades. This is by the system's design.

@export var total_xp: float = 15.0
@export var decay_rate: float = 2.0       # XP lost per second passively
@export var initial_radius: float = 30.0  # starting cloud size in pixels

var xp_remaining: float

# Track all entities currently inside the cloud that can absorb.
# Key: the CharacterBody2D, Value: its ExperienceComponent.
var _absorbers: Dictionary = {}

func _ready() -> void:
	xp_remaining = total_xp

	# Layer 5 (bit 16) so other systems can detect us.
	# Mask layer 1 (bit 1) to detect CharacterBody2D nodes walking in.
	collision_layer = 16
	collision_mask = 1

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	$CollisionShape2D.shape.radius = initial_radius

func _physics_process(delta: float) -> void:
	if xp_remaining <= 0:
		queue_free()
		return

	# --- Passive decay: the system reclaims uncultivated energy ---
	xp_remaining -= decay_rate * delta

	# --- Active absorption: entities inside pull at their own rate ---
	if xp_remaining > 0 and _absorbers.size() > 0:
		for entity in _absorbers:
			if xp_remaining <= 0:
				break
			var xp_comp: ExperienceComponent = _absorbers[entity]
			var absorbed := xp_comp.try_absorb(xp_remaining, delta)
			xp_remaining -= absorbed

	# --- Update visuals to match remaining XP ---
	_update_visual()

	# Cloud is empty - remove it.
	if xp_remaining <= 0:
		xp_remaining = 0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)

func _update_visual() -> void:
	var ratio := xp_remaining / total_xp
	var current_radius := initial_radius * ratio
	$CollisionShape2D.shape.radius = maxf(current_radius, 5.0)
	queue_redraw()

func _draw() -> void:
	var ratio := xp_remaining / total_xp if total_xp > 0 else 0.0
	var radius := initial_radius * ratio

	# Outer haze - soft, transparent.
	draw_circle(Vector2.ZERO, maxf(radius, 2.0), Color(0.6, 0.3, 0.9, 0.15 * ratio))
	# Middle ring.
	draw_circle(Vector2.ZERO, maxf(radius * 0.6, 1.5), Color(0.7, 0.4, 1.0, 0.25 * ratio))
	# Dense center.
	draw_circle(Vector2.ZERO, maxf(radius * 0.3, 1.0), Color(0.8, 0.5, 1.0, 0.4 * ratio))

func _on_body_entered(body: Node2D) -> void:
	# Any entity with an ExperienceComponent that can absorb.
	var xp_comp := _find_experience_component(body)
	if xp_comp and xp_comp.can_absorb():
		_absorbers[body] = xp_comp

func _on_body_exited(body: Node2D) -> void:
	_absorbers.erase(body)

func _find_experience_component(entity: Node) -> ExperienceComponent:
	for child in entity.get_children():
		if child is ExperienceComponent:
			return child
	return null
