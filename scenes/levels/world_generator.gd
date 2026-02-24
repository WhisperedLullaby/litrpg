extends Node2D

# Procedural infinite world using dual-grid tilemap technique.
# Two grids: a "world" grid (data - is this cell grass?) and a
# "display" grid offset by half a tile that picks the right
# transition tile based on its 4 neighboring world cells.
#
# Chunks of 16x16 tiles load/unload around the player seamlessly.

const CHUNK_SIZE := 16         # tiles per chunk side
const TILE_SIZE := 256         # pixels per tile
const CHUNK_PX := CHUNK_SIZE * TILE_SIZE  # 512px per chunk
const LOAD_RADIUS := 3         # chunks loaded in each direction
const UNLOAD_RADIUS := 4       # chunks freed beyond this distance

# Noise thresholds for terrain type.
const GRASS_THRESHOLD := -0.15  # above this = grass
const WATER_THRESHOLD := -0.35  # below this in water noise = water

# Default config is loaded automatically. Override in the inspector to swap configs.
@export var decoration_config: WorldDecorationConfig = preload("res://resources/world_decorations.tres")

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

const _SPRITE_DECORATION_SCENE: PackedScene = preload("res://scenes/environment/sprite_decoration.tscn")

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


func _ready() -> void:
	_setup_noise()
	_setup_tileset()
	_setup_display_layer()

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
	atlas.texture = preload("res://resources/256textures/exported_tile_set.png")
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
	if not decoration_config or not ysort_layer:
		return
	for entry in decoration_config.entries:
		if _decoration_rng.randf() < entry.chance:
			var node := _spawn_decoration(cell, entry)
			if node:
				chunk_data["decorations"].append(node)
			return  # One decoration per cell.

func _spawn_decoration(cell: Vector2i, entry: DecorationEntry) -> Node2D:
	var world_pos := Vector2(
		cell.x * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE),
		cell.y * TILE_SIZE + _decoration_rng.randf_range(0, TILE_SIZE)
	)
	var node: Node2D
	if not entry.textures.is_empty():
		# Sprite-based decoration: one scene, many possible textures.
		node = _SPRITE_DECORATION_SCENE.instantiate()
		node.textures = entry.textures
		node.sprite_offset = entry.sprite_offset
	elif entry.scene:
		# Scene-based decoration: trees, etc. handle their own setup.
		node = entry.scene.instantiate()
	else:
		return null
	node.position = world_pos
	node.z_index = entry.z_index
	ysort_layer.add_child(node)
	return node

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
