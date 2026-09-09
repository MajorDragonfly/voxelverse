extends "res://world/planet_lab/adaptive_sphere_tiles.gd"

## All attached objects share the terrain's body-fixed floating origin.
signal origin_changed(previous: Array, current: Array)
var presentation: RefCounted


func configure(descriptor: Dictionary) -> void:
	super.configure(descriptor)
	surface = preload("res://world/surface/planet_surface_factory.gd").create(descriptor)
	if descriptor.get("surface_generation") in ["living_planet_v1", "living_planet_v2"]:
		presentation = preload("res://world/surface/visuals/living_surface_materials.gd").new()
		presentation.setup(self)


func _process(delta: float) -> void:
	super._process(delta)
	if presentation != null:
		presentation.advance(delta)


func rebase(new_origin: Array) -> void:
	var previous: Array = origin.duplicate()
	super.rebase(new_origin)
	if presentation != null:
		presentation.rebase(new_origin)
	origin_changed.emit(previous, origin)
