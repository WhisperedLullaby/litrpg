class_name DecorationEntry
extends Resource

# One entry in a WorldDecorationConfig.
# The world generator rolls randf() < chance per grass tile.
# If it passes, the scene is instantiated at that position.

@export var scene: PackedScene
@export_range(0.0, 1.0, 0.001) var chance: float = 0.01
