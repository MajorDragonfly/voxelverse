extends SceneTree
## Locate the five materials on the current campaign's generation, not v1 lab.
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign := Campaign.new()
	campaign.reset("r32-08-inventory-only")
	campaign.data.surface_policy = Cube.MODE
	var body: Dictionary = campaign.ensure_body(15838, 15838)
	if body.is_empty():
		push_error("Current campaign body creation failed")
		quit(1)
		return
	var surface: RefCounted = Factory.create(Context.descriptor(body))
	var categories: Array[String] = ["grassland", "desert", "rocky_highlands", "snow", "coast"]
	var locations: Dictionary = {}
	for face in range(6):
		for y in range(-9, 10):
			for x in range(-9, 10):
				var direction: Array = Cube.direction(face, float(x) * 0.1, float(y) * 0.1)
				var height: float = surface.height_precise(direction)
				var field: Dictionary = surface.fields(direction, height)
				if field.biome in categories and not locations.has(field.biome):
					locations[field.biome] = {"face": face, "u": float(x) * 0.1, "v": float(y) * 0.1, "height": height,
						"pigment": var_to_str(surface.color_at(Cube.vector(direction), height))}
				if locations.size() == categories.size(): break
			if locations.size() == categories.size(): break
		if locations.size() == categories.size(): break
	if surface.body.surface_generation != "living_planet_v2": failures.append("Probe used an obsolete surface generation")
	for category: String in categories:
		if not locations.has(category): failures.append("Missing current campaign biome: " + category)
	print("R32_08_GROUND_LOCATIONS ", JSON.stringify({"generation": surface.body.surface_generation, "seed": 15838, "locations": locations}))
	for failure: String in failures: push_error(failure)
	print("R32_08_GROUND_LOCATIONS_PASSED ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
