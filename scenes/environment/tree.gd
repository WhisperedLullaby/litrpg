extends Node2D

# Self-contained tree. Texture is set per-scene via the export so tree_1.tscn
# and tree_2.tscn can share this script while using different art.
#
# Wind parameters are derived from global_position so every tree sways at a
# unique phase/speed/strength. Materials are duplicated so instances are independent.
#
# A shadow sprite is created programmatically and receives the same wind
# parameters so it sways in lockstep with the canopy.

@export var tree_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if tree_texture:
		_sprite.texture = tree_texture

	# Compute per-tree wind values once — shared by both materials.
	var pos := global_position
	var wind_offset   := fmod(pos.x * 0.013 + pos.y * 0.007, TAU)
	var wind_speed    := 0.8 + fmod(absf(pos.x * 0.019 + pos.y * 0.011), 0.7)
	var wind_strength := 9.0 + fmod(absf(pos.x * 0.031 + pos.y * 0.023), 10.0)

	# Configure wind shader on the main sprite (duplicate to avoid shared state).
	var wind_mat := _sprite.material as ShaderMaterial
	if wind_mat:
		wind_mat = wind_mat.duplicate()
		wind_mat.set_shader_parameter("wind_offset",   wind_offset)
		wind_mat.set_shader_parameter("wind_speed",    wind_speed)
		wind_mat.set_shader_parameter("wind_strength", wind_strength)
		_sprite.material = wind_mat

	# Build the shadow sprite with the same texture and wind parameters.
	var shadow := Sprite2D.new()
	shadow.texture = tree_texture
	shadow.offset.y = -190.0

	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = preload("res://shaders/tree_shadow.gdshader")
	shadow_mat.set_shader_parameter("wind_offset",   wind_offset)
	shadow_mat.set_shader_parameter("wind_speed",    wind_speed)
	shadow_mat.set_shader_parameter("wind_strength", wind_strength)
	shadow.material = shadow_mat

	add_child(shadow)
	move_child(shadow, 0)  # Draw behind Sprite2D in sibling order.
