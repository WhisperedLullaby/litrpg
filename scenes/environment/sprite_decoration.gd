extends Node2D

# Generic single-sprite decoration.
# The world generator sets `textures` and `sprite_offset` before add_child,
# so _ready sees them and picks a random variant.

var textures: Array[Texture2D] = []
var sprite_offset: Vector2 = Vector2(0, -128)

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.offset = sprite_offset
	if textures.is_empty():
		return
	_sprite.texture = textures[randi() % textures.size()]
