extends CharacterBody2D

# The bat - simplest enemy. Walks toward the player, deals contact damage.
# Its speed is derived from its own StatsComponent through the same
# formula the player uses. The system treats all entities equally.

@export var xp_value: float = 15.0
@export var base_movement_speed = 240

var cloud_scene: PackedScene = preload("res://scenes/pickups/xp_cloud.tscn")
var core_scene: PackedScene = preload("res://scenes/pickups/core_pickup.tscn")

var player: Node2D = null
var is_dying: bool = false
var is_hit: bool = false
var speed: float = 400.0
var _facing: String = "front"

# Bat loot table - built in _ready. Core drop is not guaranteed.
var _loot_table: LootTable

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var stats: StatsComponent = $StatsComponent
@onready var status_effects: StatusEffectComponent = $StatusEffectComponent

func _ready() -> void:
	_setup_animations()
	animated_sprite.play("walk_front")
	player = get_tree().get_first_node_in_group("player")
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)

	# Derive speed from the bat's own Agility stat.
	# Bats have a base speed of 30 (slower than player's 80).
	speed = stats.get_movement_speed(base_movement_speed)

	# Build the bat's loot table.
	_loot_table = LootTable.new()
	_loot_table.drops = [
		LootDrop.create(core_scene, 0.45),  # 45% base chance to drop a core
	]

func _physics_process(_delta: float) -> void:
	if is_dying or not player:
		return

	var direction := global_position.direction_to(player.global_position)
	velocity = direction * speed + status_effects.get_knockback_velocity()
	move_and_slide()
	_update_animation(direction)

func _on_died() -> void:
	is_dying = true
	velocity = Vector2.ZERO

	SignalBus.enemy_died.emit(global_position, xp_value)

	# Energy cloud ALWAYS releases - this is physics, not loot.
	# The system reclaims some energy, the rest lingers as a cloud.
	_spawn_cloud()

	# Loot is rolled separately - cores aren't guaranteed.
	_roll_loot()

	animated_sprite.play("die_front")
	await animated_sprite.animation_finished
	queue_free()

func _on_health_changed(current: float, max_hp: float) -> void:
	if is_dying or is_hit:
		return
	if current >= max_hp:
		return  # Not actually damaged (e.g. healed).
	is_hit = true
	animated_sprite.play("hit_" + _facing)
	await animated_sprite.animation_finished
	is_hit = false

func _spawn_cloud() -> void:
	var cloud := cloud_scene.instantiate()
	cloud.global_position = global_position
	cloud.total_xp = xp_value
	get_tree().current_scene.add_child(cloud)

func _roll_loot() -> void:
	var luck := stats.get_luck_multiplier()
	var scenes := _loot_table.roll(luck)

	# Check if this entity cultivated (has ExperienceComponent with absorbed XP).
	var xp_comp := _find_experience_component()
	var cultivation := xp_comp.total_xp_absorbed if xp_comp else 0.0

	for scene in scenes:
		var drop := scene.instantiate()
		drop.global_position = global_position + Vector2(randf_range(-48, 48), randf_range(-48, 48))

		# If this is a core, set quality based on cultivation.
		if drop.has_method("setup_quality"):
			var quality = drop.quality_from_cultivation(cultivation)
			drop.setup_quality(quality)

		get_tree().current_scene.add_child(drop)

func _find_experience_component() -> ExperienceComponent:
	for child in get_children():
		if child is ExperienceComponent:
			return child
	return null

func _update_animation(direction: Vector2) -> void:
	if is_dying or is_hit:
		return
	if abs(direction.x) > abs(direction.y):
		_facing = "right"
		animated_sprite.play("walk_right")
		animated_sprite.flip_h = direction.x < 0
	else:
		animated_sprite.flip_h = false
		if direction.y > 0:
			_facing = "front"
			animated_sprite.play("walk_front")
		else:
			_facing = "back"
			animated_sprite.play("walk_back")

func _setup_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var base_path := "res://sprites/enemies/Bat01/TopDown"
	var animations := [
		["walk_front", base_path + "/Front/Export/Bat01_01_T_F_Walk.png", 4, true],
		["walk_back",  base_path + "/Back/Export/Bat01_01_T_B_Walk.png",  4, true],
		["walk_right", base_path + "/Right/Export/Bat01_01_T_R_Walk.png", 4, true],
		["die_front",  base_path + "/Front/Export/Bat01_01_T_F_Die.png", 11, false],
		["hit_front",  base_path + "/Bat_Abridged_Get_hit_front.png", 4, false],
		["hit_right",  base_path + "/Bat_Abridged_Get_hit_right.png", 6, false],
		["hit_back",   base_path + "/Bat_Abridged_Get_hit_back.png",  6, false],
	]

	for anim_data in animations:
		var anim_name: String = anim_data[0]
		var sheet_path: String = anim_data[1]
		var frame_count: int = anim_data[2]
		var looping: bool = anim_data[3]

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 10.0)
		frames.set_animation_loop(anim_name, looping)

		var sheet_texture: Texture2D = load(sheet_path)
		var frame_width := sheet_texture.get_width() / frame_count
		var frame_height: int = sheet_texture.get_height()

		for i in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_texture
			atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
			frames.add_frame(anim_name, atlas)

	animated_sprite.sprite_frames = frames
