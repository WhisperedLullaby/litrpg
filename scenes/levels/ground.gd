extends Node2D

# For a Vampire Survivors style game, the ground is just a large
# flat surface. Instead of fighting with tileset edge pieces,
# we use a simple colored rectangle as the base and let the
# decorations (trees, rocks) provide visual interest.
#
# This is actually what many VS-like games do - the ground is
# simple so it doesn't compete with the chaos of enemies and
# projectiles filling the screen.

@export var map_size: Vector2 = Vector2(3200, 2240)
@export var ground_color: Color = Color(0.32, 0.42, 0.22, 1.0)  # muted grass green

func _ready() -> void:
	# Create a large colored rectangle as the ground.
	var bg := ColorRect.new()
	bg.color = ground_color
	bg.size = map_size
	# Center it so the player spawn (320, 180) is roughly in the middle.
	bg.position = -map_size / 2.0 + Vector2(320, 180)
	add_child(bg)
