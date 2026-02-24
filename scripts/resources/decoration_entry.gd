class_name DecorationEntry
extends Resource

# One entry in a WorldDecorationConfig.
# The world generator rolls randf() < chance per grass tile.
# If it passes, a decoration is spawned at that position.
#
# Two spawn modes (mutually exclusive — textures takes priority):
#   textures non-empty → instantiates sprite_decoration.tscn and picks a random texture.
#   scene only          → instantiates that scene directly (used for trees, etc.).
#
# z_index is applied to the spawned node:
#   -1  ground cover (grass tufts) — always behind the player and y-sorted objects.
#    0  y-sorted objects (bushes, trees) — sorted by Y with the player.

@export var scene: PackedScene
@export var textures: Array[Texture2D] = []
@export_range(0.0, 1.0, 0.001) var chance: float = 0.01
@export var z_index: int = 0
# Sprite2D.offset applied when using the sprite path.
# Default puts the bottom of a 256-px-tall texture at the spawn point.
@export var sprite_offset: Vector2 = Vector2(0, -128)
