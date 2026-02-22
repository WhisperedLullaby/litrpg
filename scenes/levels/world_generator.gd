extends Node2D

# Procedural infinite world using dual-grid tilemap technique.
# Two grids: a "world" grid (data - is this cell grass?) and a
# "display" grid offset by half a tile that picks the right
# transition tile based on its 4 neighboring world cells.
#
# Chunks of 16x16 tiles load/unload around the player seamlessly.

const CHUNK_SIZE := 16         # tiles per chunk side
const TILE_SIZE := 32          # pixels per tile
const CHUNK_PX := CHUNK_SIZE * TILE_SIZE  # 512px per chunk
const LOAD_RADIUS := 3         # chunks loaded in each direction
const UNLOAD_RADIUS := 4       # chunks freed beyond this distance

# Noise thresholds for terrain type.
const GRASS_THRESHOLD := -0.15  # above this = grass
const WATER_THRESHOLD := -0.35  # below this in water noise = water

# Decoration density (chance per grass tile to spawn a decoration).
const TREE_CHANCE := 0.02
const ROCK_CHANCE := 0.0  # Disabled until new rock sprites are drawn.
const PLANT_CHANCE := 0.06
const BUSH_CHANCE := 0.008  # 2x2 medium bush
const JAR_CHANCE := 0.005   # breakable jars

# Plant atlas coordinates (16x16 cells in Plants.png).
const PLANT_CELL := 16
const PLANT_COORDS: Array[Vector2i] = [
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2),
	Vector2i(3, 2),  # tiny tree stump
]
const FLOWER_COORDS: Array[Vector2i] = [
	Vector2i(14, 1), Vector2i(15, 1), Vector2i(16, 1), Vector2i(17, 1),
	Vector2i(14, 2), Vector2i(15, 2), Vector2i(16, 2), Vector2i(17, 2),
]
# 2x2 bush: top-left at (3,3), spans to (4,4) → 32x32 region.
const BUSH_ORIGIN := Vector2i(3, 3)

# The 16-tile dual grid lookup: bitmask index → atlas coords.
# Bitmask: TL=bit0, TR=bit1, BL=bit2, BR=bit3.
# Derived from the TileMapDual addon's "Standard" square preset.
const DUAL_GRID_MAP: Array[Vector2i] = [
	Vector2i(0, 3),  #  0: 0000 no grass corners (all dirt)
	Vector2i(3, 3),  #  1: 0001 TL
	Vector2i(0, 2),  #  2: 0010 TR
	Vector2i(1, 2),  #  3: 0011 TL+TR (top edge)
	Vector2i(0, 0),  #  4: 0100 BL
	Vector2i(3, 2),  #  5: 0101 TL+BL (left edge)
	Vector2i(2, 3),  #  6: 0110 TR+BL (diagonal)
	Vector2i(3, 1),  #  7: 0111 TL+TR+BL
	Vector2i(1, 3),  #  8: 1000 BR
	Vector2i(0, 1),  #  9: 1001 TL+BR (diagonal)
	Vector2i(1, 0),  # 10: 1010 TR+BR (right edge)
	Vector2i(2, 2),  # 11: 1011 TL+TR+BR
	Vector2i(3, 0),  # 12: 1100 BL+BR (bottom edge)
	Vector2i(2, 0),  # 13: 1101 TL+BL+BR
	Vector2i(1, 1),  # 14: 1110 TR+BL+BR
	Vector2i(2, 1),  # 15: 1111 all grass
]

var player: Node2D = null
var ysort_layer: Node2D = null

# Noise generators.
var _terrain_noise := FastNoiseLite.new()
var _water_noise := FastNoiseLite.new()
var _decoration_rng := RandomNumberGenerator.new()

# World data: Vector2i → true means grass. Absent or false = dirt.
var _world_data: Dictionary = {}

# Loaded chunks: Vector2i → { "tiles": Array[Vector2i], "decorations": Array[Node] }
var _chunks: Dictionary = {}

# Tilemap layers.
var _display_layer: TileMapLayer = null
var _tile_set: TileSet = null
var _water_bodies: Dictionary = {}  # chunk_coord → Array[StaticBody2D]

# Decoration resources (preloaded).
var _tree_sprite_frames: SpriteFrames = null
var _tree_texture: Texture2D = null
var _rock_textures: Array[Texture2D] = []
var _plant_textures: Array[Texture2D] = []
var _flower_textures: Array[Texture2D] = []
var _bush_texture: Texture2D = null
var _jar_scene: PackedScene = preload("res://scenes/interactables/jar.tscn")

func _ready() -> void:
	_setup_noise()
	_setup_tileset()
	_setup_display_layer()
	_preload_decorations()

func _process(_delta: float) -> void:
	if not player:
		return
	var player_chunk := _world_to_chunk(player.global_position)
	_load_chunks_around(player_chunk)
	_unload_distant_chunks(player_chunk)

# --- Setup ---

func _setup_noise() -> void:
	var seed_val := randi()
	_terrain_noise.seed = seed_val
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.frequency = 0.015
	_terrain_noise.fractal_octaves = 3

	_water_noise.seed = seed_val + 42
	_water_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_water_noise.frequency = 0.008
	_water_noise.fractal_octaves = 2

func _setup_tileset() -> void:
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://sprites/exported_tile_set.png")
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Register all 16 tiles in the 4x4 grid.
	for y in 4:
		for x in 4:
			atlas.create_tile(Vector2i(x, y))

	_tile_set.add_source(atlas)

func _setup_display_layer() -> void:
	_display_layer = TileMapLayer.new()
	_display_layer.tile_set = _tile_set
	# Offset by half a tile - the core of the dual grid technique.
	_display_layer.position = Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0)
	_display_layer.z_index = -10  # Draw under everything.
	add_child(_display_layer)

func _preload_decorations() -> void:
	# Animated tree spritesheet: 1024x64, 16 frames of 64x64.
	_tree_texture = preload("res://sprites/newTiles/AnimatedTrees/AnimatedClassicalTrees/AnimatedTreeWarmColor.png")
	_tree_sprite_frames = SpriteFrames.new()
	_tree_sprite_frames.add_animation("sway")
	_tree_sprite_frames.set_animation_speed("sway", 8.0)
	_tree_sprite_frames.set_animation_loop("sway", true)
	var frame_size := Vector2i(64, 64)
	for i in 16:
		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = _tree_texture
		atlas_tex.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
		_tree_sprite_frames.add_frame("sway", atlas_tex)
	# Remove the auto-created "default" animation.
	if _tree_sprite_frames.has_animation("default"):
		_tree_sprite_frames.remove_animation("default")

	# Rocks - individual PNGs.
	for i in range(1, 7):
		var path := "res://sprites/newTiles/Rocks/ClassicalRocks/Rock%d.png" % i
		if ResourceLoader.exists(path):
			_rock_textures.append(load(path))

	# Plants, flowers, and bush from Plants.png spritesheet.
	var plants_png: Texture2D = preload("res://sprites/newTiles/Decorations/Plants.png")
	for coord in PLANT_COORDS:
		var tex := AtlasTexture.new()
		tex.atlas = plants_png
		tex.region = Rect2(coord.x * PLANT_CELL, coord.y * PLANT_CELL, PLANT_CELL, PLANT_CELL)
		_plant_textures.append(tex)
	for coord in FLOWER_COORDS:
		var tex := AtlasTexture.new()
		tex.atlas = plants_png
		tex.region = Rect2(coord.x * PLANT_CELL, coord.y * PLANT_CELL, PLANT_CELL, PLANT_CELL)
		_flower_textures.append(tex)
	# 2x2 bush (32x32 region).
	var bush_tex := AtlasTexture.new()
	bush_tex.atlas = plants_png
	bush_tex.region = Rect2(BUSH_ORIGIN.x * PLANT_CELL, BUSH_ORIGIN.y * PLANT_CELL, PLANT_CELL * 2, PLANT_CELL * 2)
	_bush_texture = bush_tex

# --- Chunk Management ---

func _world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / CHUNK_PX),
		floori(world_pos.y / CHUNK_PX)
	)

func _load_chunks_around(center: Vector2i) -> void:
	for cy in range(center.y - LOAD_RADIUS, center.y + LOAD_RADIUS + 1):
		for cx in range(center.x - LOAD_RADIUS, center.x + LOAD_RADIUS + 1):
			var coord := Vector2i(cx, cy)
			if not _chunks.has(coord):
				_generate_chunk(coord)

func _unload_distant_chunks(center: Vector2i) -> void:
	var to_remove: Array[Vector2i] = []
	for coord in _chunks:
		var dist := maxi(absi(coord.x - center.x), absi(coord.y - center.y))
		if dist > UNLOAD_RADIUS:
			to_remove.append(coord)
	for coord in to_remove:
		_free_chunk(coord)

func _generate_chunk(chunk_coord: Vector2i) -> void:
	var chunk_data := {
		"display_tiles": [] as Array[Vector2i],
		"decorations": [] as Array[Node],
	}

	# Seed RNG deterministically per chunk for decorations.
	_decoration_rng.seed = hash(chunk_coord) ^ _terrain_noise.seed

	var base_x := chunk_coord.x * CHUNK_SIZE
	var base_y := chunk_coord.y * CHUNK_SIZE

	# Step 1: Generate world data for this chunk (+ 1 border for display).
	for y in range(base_y - 1, base_y + CHUNK_SIZE + 1):
		for x in range(base_x - 1, base_x + CHUNK_SIZE + 1):
			var cell := Vector2i(x, y)
			if not _world_data.has(cell):
				_world_data[cell] = _sample_terrain(x, y)

	# Step 2: Update display tiles for this chunk.
	for y in range(base_y, base_y + CHUNK_SIZE + 1):
		for x in range(base_x, base_x + CHUNK_SIZE + 1):
			var display_coord := Vector2i(x, y)
			_update_display_cell(display_coord)
			chunk_data["display_tiles"].append(display_coord)

	# Step 3: Spawn decorations and water collision.
	var water_rects: Array[Rect2] = []

	for y in range(base_y, base_y + CHUNK_SIZE):
		for x in range(base_x, base_x + CHUNK_SIZE):
			var cell := Vector2i(x, y)
			var terrain: int = _world_data.get(cell, 0)

			if terrain == 2:  # Water
				water_rects.append(Rect2(
					x * TILE_SIZE, y * TILE_SIZE,
					TILE_SIZE, TILE_SIZE
				))
			elif terrain == 1:  # Grass - maybe spawn decoration
				_try_spawn_decoration(cell, chunk_data)

	# Create water collision bodies for this chunk.
	_create_water_collision(chunk_coord, water_rects)

	_chunks[chunk_coord] = chunk_data

func _free_chunk(chunk_coord: Vector2i) -> void:
	if not _chunks.has(chunk_coord):
		return

	var chunk_data: Dictionary = _chunks[chunk_coord]

	# Erase display tiles.
	for coord in chunk_data["display_tiles"]:
		_display_layer.erase_cell(coord)

	# Free decorations.
	for node in chunk_data["decorations"]:
		if is_instance_valid(node):
			node.queue_free()

	# Free water collision.
	if _water_bodies.has(chunk_coord):
		for body in _water_bodies[chunk_coord]:
			if is_instance_valid(body):
				body.queue_free()
		_water_bodies.erase(chunk_coord)

	# Clean up world data for this chunk (keep border cells for neighbors).
	var base_x := chunk_coord.x * CHUNK_SIZE
	var base_y := chunk_coord.y * CHUNK_SIZE
	for y in range(base_y, base_y + CHUNK_SIZE):
		for x in range(base_x, base_x + CHUNK_SIZE):
			_world_data.erase(Vector2i(x, y))

	_chunks.erase(chunk_coord)

# --- Terrain Sampling ---

func _sample_terrain(x: int, y: int) -> int:
	# Check water first (separate noise layer).
	var water_val := _water_noise.get_noise_2d(x, y)
	if water_val < WATER_THRESHOLD:
		return 2  # Water

	# Grass vs dirt.
	var terrain_val := _terrain_noise.get_noise_2d(x, y)
	if terrain_val > GRASS_THRESHOLD:
		return 1  # Grass
	return 0  # Dirt

# --- Dual Grid Display ---

func _update_display_cell(display_coord: Vector2i) -> void:
	# Each display cell checks 4 world cells at its corners.
	# The display grid is offset by -0.5 tiles, so display cell (x,y)
	# corresponds to world cells: TL=(x-1,y-1), TR=(x,y-1), BL=(x-1,y), BR=(x,y)
	var tl := _is_grass(display_coord + Vector2i(-1, -1))
	var t_r := _is_grass(display_coord + Vector2i(0, -1))
	var bl := _is_grass(display_coord + Vector2i(-1, 0))
	var br := _is_grass(display_coord + Vector2i(0, 0))

	var bitmask := tl * 1 + t_r * 2 + bl * 4 + br * 8
	var atlas_coord: Vector2i = DUAL_GRID_MAP[bitmask]

	_display_layer.set_cell(display_coord, 0, atlas_coord)

func _is_grass(cell: Vector2i) -> int:
	# Grass = 1, everything else (dirt, water) = 0 for the dual grid.
	return 1 if _world_data.get(cell, 0) == 1 else 0

# --- Decorations ---

func _try_spawn_decoration(cell: Vector2i, chunk_data: Dictionary) -> void:
	if not ysort_layer:
		return

	var roll := _decoration_rng.randf()
	var threshold := 0.0

	# Trees (animated, with collision).
	threshold += TREE_CHANCE
	if roll < threshold and _tree_sprite_frames:
		var node := _create_tree(cell)
		chunk_data["decorations"].append(node)
		return

	# Rocks (static, with collision).
	threshold += ROCK_CHANCE
	if roll < threshold and _rock_textures.size() > 0:
		var tex: Texture2D = _rock_textures[_decoration_rng.randi() % _rock_textures.size()]
		var node := _create_decoration(cell, tex, Vector2(40, 20))
		chunk_data["decorations"].append(node)
		return

	# Breakable jars (interactable, has loot).
	threshold += JAR_CHANCE
	if roll < threshold and _jar_scene:
		var node := _create_jar(cell)
		chunk_data["decorations"].append(node)
		return

	# 2x2 bush (no collision, purely visual).
	threshold += BUSH_CHANCE
	if roll < threshold and _bush_texture:
		var node := _create_plant(cell, _bush_texture)
		chunk_data["decorations"].append(node)
		return

	# Small plants and flowers (no collision, ground scatter).
	threshold += PLANT_CHANCE
	if roll < threshold:
		# Mix plants and flowers roughly 60/40.
		var tex: Texture2D
		if _decoration_rng.randf() < 0.6 and _plant_textures.size() > 0:
			tex = _plant_textures[_decoration_rng.randi() % _plant_textures.size()]
		elif _flower_textures.size() > 0:
			tex = _flower_textures[_decoration_rng.randi() % _flower_textures.size()]
		if tex:
			var node := _create_plant(cell, tex)
			chunk_data["decorations"].append(node)

func _create_tree(cell: Vector2i) -> Node2D:
	var world_pos := Vector2(
		cell.x * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE),
		cell.y * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE)
	)

	var container := Node2D.new()
	container.position = world_pos

	# Animated sprite drawing upward from the base.
	var anim_sprite := AnimatedSprite2D.new()
	anim_sprite.sprite_frames = _tree_sprite_frames
	anim_sprite.offset.y = -32.0  # 64px tall, origin at bottom center.
	anim_sprite.play("sway")
	# Start at a random frame so trees don't sway in sync.
	anim_sprite.frame = _decoration_rng.randi() % 16
	container.add_child(anim_sprite)

	# Collision at the trunk base.
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 12)
	shape.shape = rect
	body.add_child(shape)
	container.add_child(body)

	ysort_layer.add_child(container)
	return container

func _create_jar(cell: Vector2i) -> Node2D:
	var world_pos := Vector2(
		cell.x * TILE_SIZE + _decoration_rng.randf_range(4, TILE_SIZE - 4),
		cell.y * TILE_SIZE + _decoration_rng.randf_range(4, TILE_SIZE - 4)
	)

	var jar := _jar_scene.instantiate()
	jar.position = world_pos
	ysort_layer.add_child(jar)
	return jar

func _create_plant(cell: Vector2i, tex: Texture2D) -> Node2D:
	var world_pos := Vector2(
		cell.x * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE),
		cell.y * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE)
	)

	# Plants are pure visual - no collision, just a sprite on the ground.
	var container := Node2D.new()
	container.position = world_pos

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.offset.y = -tex.get_height() / 2.0  # Origin at bottom.
	container.add_child(sprite)

	ysort_layer.add_child(container)
	return container

func _create_decoration(cell: Vector2i, tex: Texture2D, collision_size: Vector2) -> Node2D:
	var world_pos := Vector2(
		cell.x * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE),
		cell.y * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE)
	)

	# Container node at the base position (for y-sort).
	var container := Node2D.new()
	container.position = world_pos

	# Sprite draws upward from the base.
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.offset.y = -tex.get_height() / 2.0  # Origin at bottom center.
	container.add_child(sprite)

	# Collision at the base.
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = collision_size
	shape.shape = rect
	body.add_child(shape)
	container.add_child(body)

	ysort_layer.add_child(container)
	return container

# --- Water Collision ---

func _create_water_collision(chunk_coord: Vector2i, rects: Array[Rect2]) -> void:
	if rects.is_empty():
		return

	var bodies: Array[StaticBody2D] = []
	# Merge adjacent water tiles into larger bodies for efficiency.
	# Simple approach: one body per water tile (can optimize later).
	for rect in rects:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = rect_shape
		shape.position = rect.position + rect.size / 2.0
		body.add_child(shape)

		# Water visual — blue tinted overlay so water doesn't look like dirt.
		var visual := ColorRect.new()
		visual.color = Color(0.18, 0.32, 0.50, 0.75)
		visual.size = Vector2(TILE_SIZE, TILE_SIZE)
		visual.position = rect.position
		visual.z_index = -9  # Above ground tiles (-10), below everything else.
		body.add_child(visual)

		add_child(body)
		bodies.append(body)

	_water_bodies[chunk_coord] = bodies
