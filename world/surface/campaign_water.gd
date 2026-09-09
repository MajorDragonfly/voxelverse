extends Node
## The rendered, physical and audible water all sample the same body surface.
const Space = preload("res://world/surface/gameplay_space.gd")
const Cube = preload("res://world/space/cube_sphere.gd")

func freshwater_at(point: Vector3) -> Dictionary:
	var data: Dictionary = Space.sample(self, point)
	if not data.water or data.get("water_kind", "ocean") not in ["lake", "river"] or data.height > data.water_level - 0.15: return {}
	var place: Dictionary = Space.address(self, point)
	place.height = data.water_level
	return {"point": Space.adapter(self).to_local(place), "kind": data.water_kind}

func is_dry_at(point: Vector3) -> bool:
	return Space.dry(self, point)

func view_sample(point: Vector3) -> Dictionary:
	var data: Dictionary = Space.sample(self, point)
	return {"water": data.water, "depth": data.water_level - data.altitude, "color": Color("237887") if data.get("water_kind") == "lake" else Color("12546a")}

func audio_sample(point: Vector3) -> Dictionary:
	var data: Dictionary = Space.sample(self, point)
	var place: Dictionary = Space.address(self, point)
	place.height = data.water_level
	return {"water_present": data.water and Space.ground_ready(self, point), "water_point": Space.adapter(self).to_local(place),
		"up": Space.up(self, point), "water_height": data.water_level, "ground_height": data.height, "biome_name": data.biome}
