extends CharacterBody2D

# The player character. Movement, animation, and stat-driven values.
# All gameplay values (speed, etc.) are derived from StatsComponent
# using the same formulas that apply to every entity in the system.

var facing_direction: String = "front"
var speed: float = 80.0
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
	#print("speed=%.1f  agi=%.2f  kb=%s" % [speed, stats.get_stat("agility"), status_effects.get_knockback_velocity()])

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

	var animations := [
		["idle_front", "res://sprites/player/MainC_Idle_Front.PNG", 9],
		["idle_back",  "res://sprites/player/MainC_Idle_Back.PNG",  9],
		["idle_left",  "res://sprites/player/MainC_Idle_Left.PNG",  9],
		["idle_right", "res://sprites/player/MainC_Idle_Right.PNG", 9],
		["walk_front", "res://sprites/player/MainC_Walk_Front.PNG", 4],
		["walk_back",  "res://sprites/player/MainC_Walk_Back.PNG",  4],
		["walk_left",  "res://sprites/player/MainC_Walk_Left.PNG",  4],
		["walk_right", "res://sprites/player/MainC_Walk_Right.PNG", 4],
	]

	for anim_data in animations:
		var anim_name: String = anim_data[0]
		var sheet_path: String = anim_data[1]
		var frame_count: int = anim_data[2]

		frames.add_animation(anim_name)
		var fps := 4.0 if anim_name.begins_with("idle") else 8.0
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, true)

		var sheet_texture: Texture2D = load(sheet_path)
		var frame_width := sheet_texture.get_width() / frame_count
		var frame_height: int = sheet_texture.get_height()

		for i in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_texture
			atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
			frames.add_frame(anim_name, atlas)

	animated_sprite.sprite_frames = frames
