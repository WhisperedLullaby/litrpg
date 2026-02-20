class_name PickupCollector
extends Area2D

# Detects pickups (cores) when the entity walks over them.
# Passes the parent entity to the pickup so it knows WHO collected it.
# The pickup then finds the entity's ExperienceComponent to grant XP.

func _ready() -> void:
	# Scan layer 5 (bit 16) where pickups live.
	collision_layer = 0
	collision_mask = 16
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		area.collect(get_parent())
