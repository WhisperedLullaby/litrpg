extends Node2D

# Scatters trees, rocks, and other decorations across the map.
# These are purely visual for now - no collision. This keeps the
# VS "run anywhere" feel while making the world look alive.

@export var tree_count: int = 40
@export var rock_count: int = 60
@export var map_size: Vector2 = Vector2(3200, 2240)

# We'll slice decoration sprites from the sprite sheets using AtlasTexture,
# same technique as the player animations but for static images.

func _ready() -> void:
	_spawn_decorations()

func _spawn_decorations() -> void:
	var tree_sheet: Texture2D = load("res://sprites/Nature v1.4/Topdown RPG 32x32 - Trees 1.1.PNG")
	var rock_sheet: Texture2D = load("res://sprites/Nature v1.4/Topdown RPG 32x32 - Rocks 1.1.PNG")

	# Define decoration types: [texture, region, scale]
	# Each region is a Rect2 that crops a specific sprite from the sheet.
	var tree_variants := [
		_make_atlas(tree_sheet, Rect2(0, 0, 64, 96)),     # big tree 1
		_make_atlas(tree_sheet, Rect2(64, 0, 64, 96)),    # big tree 2
		_make_atlas(tree_sheet, Rect2(128, 0, 64, 96)),   # big tree 3
		_make_atlas(tree_sheet, Rect2(192, 0, 64, 96)),   # big tree 4
		_make_atlas(tree_sheet, Rect2(288, 0, 32, 64)),   # small tree 1
		_make_atlas(tree_sheet, Rect2(320, 0, 32, 64)),   # small tree 2
		_make_atlas(tree_sheet, Rect2(352, 0, 32, 64)),   # small tree 3
	]

	var rock_variants := [
		_make_atlas(rock_sheet, Rect2(0, 0, 64, 32)),     # big rock 1
		_make_atlas(rock_sheet, Rect2(64, 0, 64, 32)),    # big rock 2
		_make_atlas(rock_sheet, Rect2(192, 0, 64, 32)),   # flat rock
		_make_atlas(rock_sheet, Rect2(320, 0, 32, 32)),   # small rock 1
		_make_atlas(rock_sheet, Rect2(352, 0, 32, 32)),   # small rock 2
	]

	var half_w := map_size.x / 2.0
	var half_h := map_size.y / 2.0

	# Spawn trees at random positions across the map.
	for i in tree_count:
		var pos := Vector2(
			randf_range(-half_w, half_w),
			randf_range(-half_h, half_h)
		)
		# Keep a clear zone around the player spawn point (320, 180).
		if pos.distance_to(Vector2(320, 180)) < 100:
			continue
		_place_sprite(tree_variants[randi() % tree_variants.size()], pos)

	# Spawn rocks.
	for i in rock_count:
		var pos := Vector2(
			randf_range(-half_w, half_w),
			randf_range(-half_h, half_h)
		)
		if pos.distance_to(Vector2(320, 180)) < 100:
			continue
		_place_sprite(rock_variants[randi() % rock_variants.size()], pos)

func _make_atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas

func _place_sprite(texture: AtlasTexture, pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	# z_index based on y position = things lower on screen draw on top.
	# This creates a natural depth effect without a full sorting system.
	sprite.z_as_relative = false
	sprite.z_index = int(pos.y)
	add_child(sprite)
