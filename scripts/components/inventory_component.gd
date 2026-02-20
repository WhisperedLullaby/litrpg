class_name InventoryComponent
extends Node

# Manages the entity's inventory.
#
# Cores (TINY) stack in separate core storage - they orbit the player.
# Equipment goes into 3 carry slots (two hands + one pocket).
#   SMALL  = 1 slot
#   MEDIUM = 2 slots (both hands, blocks pocket access)
#   LARGE  = 3 slots (fills everything)
#
# Q/E cycles selection through equipped items. Space fires the active.

signal inventory_changed()
signal selection_changed(index: int)

const CORE_SLOTS := 10
const EQUIP_CAPACITY := 3

# Core storage: array of { "item": InventoryItem, "count": int } or null.
var core_slots: Array = []

# Equipment storage: each entry is { "item": InventoryItem, "slots_used": int } or null.
# Items occupy consecutive slots starting from their index.
var equip_items: Array[Dictionary] = []

# Index into equip_items for the currently selected equipment (-1 = none).
var selected_index: int = -1

# Cooldown tracking per equip index.
var _cooldowns: Dictionary = {}

var _stats: StatsComponent = null
var _equip_used: int = 0  # How many of the 3 slots are occupied.

func _ready() -> void:
	core_slots.resize(CORE_SLOTS)

	for child in get_parent().get_children():
		if child is StatsComponent:
			_stats = child
			break

func _process(delta: float) -> void:
	var finished: Array = []
	for key in _cooldowns:
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0.0:
			finished.append(key)
	for key in finished:
		_cooldowns.erase(key)

## How many equip slots an item size costs.
static func slots_for_size(size: int) -> int:
	match size:
		InventoryItem.Size.SMALL: return 1
		InventoryItem.Size.MEDIUM: return 2
		InventoryItem.Size.LARGE: return 3
	return 1

## Try to add an item. Returns true if successful.
func add_item(item: InventoryItem, count: int = 1) -> bool:
	if item.is_core():
		return _add_core(item, count)
	else:
		return _add_equipment(item)

## Try to use the active ability of the selected item.
func use_selected_active(user: Node2D) -> bool:
	var item := get_selected_item()
	if item == null:
		return false
	if item.active_id.is_empty():
		return false
	if _cooldowns.has(selected_index):
		return false

	var fired := ActiveAbilitySystem.use_ability(item.active_id, user)
	if fired and item.active_cooldown > 0.0:
		_cooldowns[selected_index] = item.active_cooldown
	return fired

## Get remaining cooldown for an equip index.
func get_cooldown(equip_index: int) -> float:
	return _cooldowns.get(equip_index, 0.0)

## Get the currently selected InventoryItem (or null).
func get_selected_item() -> InventoryItem:
	if selected_index < 0 or selected_index >= equip_items.size():
		return null
	return equip_items[selected_index]["item"]

## Cycle selection through equipped items.
func cycle_selection(direction: int) -> void:
	if equip_items.is_empty():
		if selected_index != -1:
			selected_index = -1
			selection_changed.emit(selected_index)
		return

	if selected_index == -1:
		selected_index = 0
	else:
		selected_index = (selected_index + direction) % equip_items.size()
		if selected_index < 0:
			selected_index += equip_items.size()

	selection_changed.emit(selected_index)

## Remove an equipped item by index.
func remove_equip(index: int) -> void:
	if index < 0 or index >= equip_items.size():
		return
	var entry: Dictionary = equip_items[index]
	var item: InventoryItem = entry["item"]
	var cost: int = entry["slots_used"]
	_equip_used -= cost
	equip_items.remove_at(index)
	_remove_passives(item)

	# Fix selection.
	if equip_items.is_empty():
		selected_index = -1
	elif selected_index >= equip_items.size():
		selected_index = equip_items.size() - 1
	selection_changed.emit(selected_index)
	inventory_changed.emit()

## Get all occupied core slots.
func get_occupied_cores() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in CORE_SLOTS:
		if core_slots[i] != null:
			var slot: Dictionary = core_slots[i]
			result.append({ "index": i, "item": slot["item"], "count": slot["count"] })
	return result

## Get all equipped items.
func get_equipped_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in equip_items.size():
		var entry: Dictionary = equip_items[i]
		result.append({ "index": i, "item": entry["item"], "slots_used": entry["slots_used"] })
	return result

# --- Internal ---

func _add_core(item: InventoryItem, count: int) -> bool:
	# Try to stack with existing.
	for i in CORE_SLOTS:
		if core_slots[i] != null:
			var slot: Dictionary = core_slots[i]
			var slot_item: InventoryItem = slot["item"]
			if slot_item.id == item.id and slot["count"] < item.max_stack:
				var space: int = item.max_stack - slot["count"]
				var to_add := mini(count, space)
				slot["count"] += to_add
				count -= to_add
				if count <= 0:
					inventory_changed.emit()
					return true

	# Find empty core slots.
	while count > 0:
		var empty := -1
		for i in CORE_SLOTS:
			if core_slots[i] == null:
				empty = i
				break
		if empty == -1:
			return false
		var to_add := mini(count, item.max_stack)
		core_slots[empty] = { "item": item, "count": to_add }
		count -= to_add

	inventory_changed.emit()
	return true

func _add_equipment(item: InventoryItem) -> bool:
	var cost := slots_for_size(item.size)
	if _equip_used + cost > EQUIP_CAPACITY:
		return false

	equip_items.append({ "item": item, "slots_used": cost })
	_equip_used += cost
	_apply_passives(item)

	# Auto-select first item if nothing selected.
	if selected_index == -1:
		selected_index = 0
		selection_changed.emit(selected_index)

	inventory_changed.emit()
	return true

func _apply_passives(item: InventoryItem) -> void:
	if _stats and not item.passive_effects.is_empty():
		for mod in item.passive_effects:
			_stats.add_modifier(mod)
	_apply_visual_passive(item)

func _remove_passives(item: InventoryItem) -> void:
	if _stats and not item.passive_effects.is_empty():
		_stats.remove_modifiers_by_source(item.id)
	_remove_visual_passive(item)

func _apply_visual_passive(item: InventoryItem) -> void:
	if item.passive_tag.is_empty():
		return
	var owner_node := get_parent()
	match item.passive_tag:
		"tint_red":
			var sprite := owner_node.get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.modulate = Color(1.0, 0.4, 0.4)
		"particle_trail":
			var particles := GPUParticles2D.new()
			particles.name = "PassiveParticles_" + item.id
			particles.amount = 6
			particles.lifetime = 0.8
			particles.emitting = true
			var mat := ParticleProcessMaterial.new()
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 30.0
			mat.initial_velocity_min = 10.0
			mat.initial_velocity_max = 20.0
			mat.gravity = Vector3(0, 15, 0)
			mat.scale_min = 1.0
			mat.scale_max = 2.0
			mat.color = Color(0.3, 1.0, 0.5, 0.6)
			particles.process_material = mat
			particles.position = Vector2(0, 4)
			owner_node.add_child(particles)

func _remove_visual_passive(item: InventoryItem) -> void:
	if item.passive_tag.is_empty():
		return
	var owner_node := get_parent()
	match item.passive_tag:
		"tint_red":
			var sprite := owner_node.get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.modulate = Color.WHITE
		"particle_trail":
			var particles := owner_node.get_node_or_null("PassiveParticles_" + item.id)
			if particles:
				particles.queue_free()
