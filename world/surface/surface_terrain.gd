extends "res://world/planet_lab/adaptive_sphere_tiles.gd"

## All attached objects share the terrain's body-fixed floating origin.
signal origin_changed(previous: Array, current: Array)


func configure(descriptor: Dictionary) -> void:
	super.configure(descriptor)
	surface = preload("res://world/surface/planet_surface_factory.gd").create(descriptor)


func rebase(new_origin: Array) -> void:
	var previous: Array = origin.duplicate()
	super.rebase(new_origin)
	origin_changed.emit(previous, origin)
