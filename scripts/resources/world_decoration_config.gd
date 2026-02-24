class_name WorldDecorationConfig
extends Resource

# Assign this resource to WorldGenerator in the inspector.
# Add/remove/reorder entries to control what spawns and how often.
# Entries are checked in order — the first one that passes its chance
# roll wins, and that cell gets no further decorations.

@export var entries: Array[DecorationEntry] = []
