extends RefCounted

const Original = preload("res://world/space/planet_surface.gd")
const Living = preload("res://world/surface/living_planet_surface.gd")
const LivingWater = preload("res://world/surface/living_planet_surface_v2.gd")


static func create(body: Dictionary) -> RefCounted:
	if body.get("surface_generation", "") == LivingWater.VERSION: return LivingWater.new(body)
	if body.get("surface_generation", "") == Living.GENERATION:
		return Living.new(body)
	return Original.new(body)
