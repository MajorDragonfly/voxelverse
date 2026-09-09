extends RefCounted

const Original = preload("res://world/space/planet_surface.gd")
const Living = preload("res://world/surface/living_planet_surface.gd")


static func create(body: Dictionary) -> RefCounted:
	if body.get("surface_generation", "") == Living.GENERATION:
		return Living.new(body)
	return Original.new(body)
