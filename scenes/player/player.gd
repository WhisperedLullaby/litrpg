extends CharacterBody2D

# The player character. Movement, animation, and stat-driven values.
# All gameplay values (speed, etc.) are derived from StatsComponent
# using the same formulas that apply to every entity in the system.

var facing_direction: String = "front"
var speed: float = 384.0
var speed_modifier: float = 1.0

# Pre-built "wounded" effect - applied when below 50% HP.
# 25% speed reduction. Duration 0 = permanent (managed manually).
var _wounded_effect: StatusEffect = StatusEffect.create_stat_effect(
	"wounded", "agility", StatModifier.Type.PERCENT, -0.25, 0.0
)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: StatsComponent = $StatsComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var status_effects: StatusEffectComponent = $StatusEffectComponent
@onready var inventory: InventoryComponent = $InventoryComponent

func _ready() -> void:
	_setup_animations()
	animated_sprite.play("idle_front")

	# Register with the global StatsSystem so UI and global scripts
	# can access player stats conveniently.
	StatsSystem.register_player(stats)

	# Listen for stat changes to recalculate derived values.
	stats.stat_changed.connect(_on_stat_changed)
	_recalculate_from_stats()

	# Listen for health changes to apply/remove wounded slow.
	health_component.health_changed.connect(_on_health_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_prev"):
		inventory.cycle_selection(-1)
	elif event.is_action_pressed("cycle_next"):
		inventory.cycle_selection(1)
	elif event.is_action_pressed("use_item"):
		inventory.use_selected_active(self)

func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction.normalized() * speed * speed_modifier + status_effects.get_knockback_velocity()
	move_and_slide()
	_update_animation(input_direction)
	#print("speed=%.1f  agi=%.2f  kb=%s" % [speed * speed_modifier, stats.get_stat("agility"), status_effects.get_knockback_velocity()])

func _recalculate_from_stats() -> void:
	# Speed is derived from AGI through the system's universal formula.
	speed = stats.get_movement_speed()

func _on_stat_changed(stat_name: String, _old: float, _new: float) -> void:
	if stat_name == "agility":
		_recalculate_from_stats()

func _on_health_changed(current_health: float, max_health: float) -> void:
	var ratio := current_health / max_health if max_health > 0 else 1.0
	if ratio < 0.5 and not status_effects.has_effect("wounded"):
		status_effects.apply_effect(_wounded_effect)
		# Recalculate speed since AGI modifier changed.
		_recalculate_from_stats()
	elif ratio >= 0.5 and status_effects.has_effect("wounded"):
		status_effects.remove_effect("wounded")
		_recalculate_from_stats()

func _update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		animated_sprite.play("idle_" + facing_direction)
		return

	if abs(direction.x) > abs(direction.y):
		facing_direction = "right" if direction.x > 0 else "left"
	else:
		facing_direction = "front" if direction.y > 0 else "back"

	animated_sprite.play("walk_" + facing_direction)

func _setup_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# Pre-alpha placeholder — single static sprite for all animation states.
	var tex: Texture2D = load("res://sprites/prealphs-charsprite.png")

	for anim_name in [
		"idle_front", "idle_back", "idle_left", "idle_right",
		"walk_front", "walk_back", "walk_left", "walk_right",
	]:
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 1.0)
		frames.set_animation_loop(anim_name, true)
		frames.add_frame(anim_name, tex)

	animated_sprite.sprite_frames = frames
