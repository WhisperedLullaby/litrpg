extends Node2D

# Draws inventory items in-world around the player.
# At level 0 there's no UI panel - this IS the inventory display.
#
# Cores (is_core) orbit the player as small colored orbs.
# Equipment items trail behind the player using their icon texture.
# The selected item is larger and has the interactable glow shader.

const ORBIT_RADIUS := 20.0
const BOB_AMPLITUDE := 1.5
const BOB_SPEED := 2.0
const ORBIT_SPEED := 0.4
const NORMAL_SCALE := Vector2(0.7, 0.7)
const SELECTED_SCALE := Vector2(1.0, 1.0)

# Trail settings for equipment items.
const TRAIL_SPACING := 14.0
const TRAIL_LERP_SPEED := 5.0
const TRAIL_BOB_AMPLITUDE := 1.0
const TRAIL_BOB_SPEED := 2.5
const ITEM_WORLD_SCALE := Vector2(0.5, 0.5)
const ITEM_SELECTED_SCALE := Vector2(0.7, 0.7)

var _inventory: InventoryComponent = null
var _orbit_nodes: Array[Node2D] = []
var _trail_nodes: Array[Node2D] = []
var _trail_targets: Array[Vector2] = []
var _glow_shader: Shader = preload("res://shaders/interactable_glow.gdshader")
var _time: float = 0.0
var _last_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	for child in get_parent().get_children():
		if child is InventoryComponent:
			_inventory = child
			break

	if _inventory:
		_inventory.inventory_changed.connect(_rebuild_visuals)
		_inventory.selection_changed.connect(_update_selection)
		_rebuild_visuals()

func _process(delta: float) -> void:
	_time += delta

	# Track player movement direction for trailing.
	# Only update from intentional input velocity, ignore knockback.
	var parent := get_parent()
	if parent is CharacterBody2D:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir.length() > 0.1:
			_last_direction = input_dir.normalized()

	_update_orbit(delta)
	_update_trail(delta)

func _update_orbit(_delta: float) -> void:
	if _orbit_nodes.is_empty():
		return
	var count := _orbit_nodes.size()
	for i in count:
		var node: Node2D = _orbit_nodes[i]
		var angle := _time * ORBIT_SPEED * TAU + (float(i) / count) * TAU
		var bob := sin(_time * BOB_SPEED + i * 1.2) * BOB_AMPLITUDE
		var y_pos := sin(angle) * ORBIT_RADIUS * 0.5 + bob
		node.position = Vector2(cos(angle) * ORBIT_RADIUS, y_pos)
		node.z_index = 1 if y_pos > 0 else -1

func _update_trail(delta: float) -> void:
	if _trail_nodes.is_empty():
		return

	# Calculate trail positions behind the player.
	var behind := -_last_direction
	for i in _trail_nodes.size():
		var target := behind * TRAIL_SPACING * (i + 1)
		var bob := sin(_time * TRAIL_BOB_SPEED + i * 1.5) * TRAIL_BOB_AMPLITUDE
		target.y += bob

		var node: Node2D = _trail_nodes[i]
		node.position = node.position.lerp(target, delta * TRAIL_LERP_SPEED)
		# Trail items behind draw on top.
		node.z_index = 1 if node.position.y > 0 else -1

func _rebuild_visuals() -> void:
	# Clear old nodes.
	for node in _orbit_nodes:
		node.queue_free()
	_orbit_nodes.clear()
	for node in _trail_nodes:
		node.queue_free()
	_trail_nodes.clear()

	if not _inventory:
		return

	# Cores orbit.
	var cores := _inventory.get_occupied_cores()
	for entry in cores:
		var item: InventoryItem = entry["item"]
		var count: int = entry["count"]
		_create_orbit_node(item, count, entry["index"])

	# Equipment trails.
	var equipped := _inventory.get_equipped_items()
	for entry in equipped:
		var item: InventoryItem = entry["item"]
		_create_trail_node(item, entry["index"])

	_update_selection(_inventory.selected_index)

func _create_orbit_node(item: InventoryItem, count: int, slot_index: int) -> void:
	var container := Node2D.new()
	var sprite := _create_orb_sprite(item)
	container.add_child(sprite)

	if count > 1:
		var label := Label.new()
		label.text = str(count)
		label.add_theme_font_size_override("font_size", 6)
		label.position = Vector2(4, -4)
		container.add_child(label)

	container.set_meta("slot_index", slot_index)
	container.set_meta("is_core", true)
	add_child(container)
	_orbit_nodes.append(container)

func _create_trail_node(item: InventoryItem, slot_index: int) -> void:
	var container := Node2D.new()

	var sprite := Sprite2D.new()
	if item.icon:
		sprite.texture = item.icon
	else:
		# Fallback: colored orb if no icon.
		sprite.texture = _create_orb_texture(item)
	sprite.scale = ITEM_WORLD_SCALE
	container.add_child(sprite)

	# Start behind the player.
	var behind := -_last_direction
	container.position = behind * TRAIL_SPACING * (_trail_nodes.size() + 1)

	container.set_meta("slot_index", slot_index)
	container.set_meta("is_core", false)
	add_child(container)
	_trail_nodes.append(container)

func _update_selection(selected: int) -> void:
	# Cores never get glow or selection - they just orbit.
	for node in _orbit_nodes:
		var sprite: Sprite2D = node.get_child(0)
		sprite.scale = NORMAL_SCALE
		_remove_glow(sprite)

	# Update trail nodes.
	for node in _trail_nodes:
		var slot_index: int = node.get_meta("slot_index")
		var sprite: Sprite2D = node.get_child(0)
		if slot_index == selected:
			sprite.scale = ITEM_SELECTED_SCALE
			_apply_glow(sprite)
		else:
			sprite.scale = ITEM_WORLD_SCALE
			_remove_glow(sprite)

	# Reorder trail: selected item trails closest.
	_reorder_trail(selected)

func _reorder_trail(selected: int) -> void:
	if _trail_nodes.size() <= 1:
		return
	var selected_idx := -1
	for i in _trail_nodes.size():
		if _trail_nodes[i].get_meta("slot_index") == selected:
			selected_idx = i
			break
	if selected_idx > 0:
		var node := _trail_nodes[selected_idx]
		_trail_nodes.remove_at(selected_idx)
		_trail_nodes.insert(0, node)

func _create_orb_sprite(item: InventoryItem) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _create_orb_texture(item)
	sprite.scale = NORMAL_SCALE
	return sprite

func _create_orb_texture(item: InventoryItem) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	var center := Vector2(6, 6)
	var radius := 5.0

	for y in 12:
		for x in 12:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha := 1.0 - (dist / radius) * 0.3
				var bright := 1.0 - (dist / radius) * 0.4
				var c := item.color
				img.set_pixel(x, y, Color(c.r * bright, c.g * bright, c.b * bright, alpha))

	return ImageTexture.create_from_image(img)

func _apply_glow(sprite: Sprite2D) -> void:
	if sprite.material:
		return
	var mat := ShaderMaterial.new()
	mat.shader = _glow_shader
	mat.set_shader_parameter("glow_color", Color(1, 1, 0.8, 0.5))
	mat.set_shader_parameter("glow_width", 2.0)
	mat.set_shader_parameter("pulse_speed", 1.0)
	mat.set_shader_parameter("pulse_min", 0.2)
	mat.set_shader_parameter("pulse_max", 0.6)
	sprite.material = mat

func _remove_glow(sprite: Sprite2D) -> void:
	sprite.material = null
