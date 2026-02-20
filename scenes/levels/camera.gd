extends Camera2D

func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	# Prevent the camera from inheriting sub-pixel offsets.
	top_level = true

func _physics_process(_delta: float) -> void:
	# Follow parent (player) but snap to whole pixels.
	global_position = get_parent().global_position.round()
