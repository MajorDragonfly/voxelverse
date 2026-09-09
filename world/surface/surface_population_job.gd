extends RefCounted

## Pure CPU patch preparation. No Node, asset loading, renderer or shared RNG.
const Cube = preload("res://world/space/cube_sphere.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const RECIPES: Array = [
	["ancient_oak_v2", 8], ["tall_pine_v2", 5],
	["dense_bush_v2", 7], ["layered_rock_v2", 4],
	["grass_tuft_v2", 22], ["fern_cluster_v2", 9], ["flower_cluster_v2", 9]]
var body: Dictionary
var cell: Dictionary
var result: Dictionary = {}
var elapsed_usec: int = 0


static func level_for(radius: float) -> int:
	return ceili(log(radius * 2.0 / 64.0) / log(2.0))


static func nearby(body_value: Dictionary, address: Dictionary) -> Dictionary:
	var level: int = level_for(body_value.radius)
	var count: int = 1 << level
	var step: float = 2.0 / count
	var cx: int = clampi(floori((address.u + 1.0) / step), 0, count - 1)
	var cy: int = clampi(floori((address.v + 1.0) / step), 0, count - 1)
	var result_cells: Dictionary = {}
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var normalized: Dictionary = Cube.address(body_value.id, address.face, -1.0 + (cx + dx + 0.5) * step, -1.0 + (cy + dy + 0.5) * step)
			var x: int = clampi(floori((normalized.u + 1.0) / step), 0, count - 1)
			var y: int = clampi(floori((normalized.v + 1.0) / step), 0, count - 1)
			var id: String = "%s:land1:%d:%d:%d:%d" % [body_value.id, level, normalized.face, x, y]
			result_cells[id] = {"id": id, "level": level, "face": normalized.face, "x": x, "y": y, "step": step}
	return result_cells


func run() -> void:
	var started: int = Time.get_ticks_usec()
	var surface: RefCounted = Factory.create(body)
	var u: float = -1.0 + cell.x * cell.step
	var v: float = -1.0 + cell.y * cell.step
	var center: Dictionary = Cube.address(body.id, cell.face, u + cell.step * 0.5, v + cell.step * 0.5)
	center.height = surface.sample(center).height
	var anchor: Array = Cube.cartesian(center, body.radius)
	var composition: Dictionary = surface.composition(center)
	var biome: String = surface.sample(center).biome
	var random := RandomNumberGenerator.new()
	random.seed = body.seed + cell.x * 73856093 + cell.y * 19349663 + cell.face * 83492791
	var batches: Array[Dictionary] = []
	var trees: Array[Vector3] = []
	var instances: int = 0
	for recipe in RECIPES:
		var asset: String = recipe[0]
		var species: Dictionary = Flora.create_species_variant(surface.terrain, biome, asset, 0)
		var batch: Dictionary = {"asset_id": asset, "species": species, "transforms": [], "custom": []}
		var chance: float = clampf(composition.families.get(asset, 0.0), 0.0, 0.95)
		for attempt in range(recipe[1]):
			if random.randf() > chance:
				continue
			var address: Dictionary = Cube.address(body.id, cell.face,
				u + random.randf_range(0.05, 0.95) * cell.step, v + random.randf_range(0.05, 0.95) * cell.step)
			var sample: Dictionary = surface.sample(address)
			var up: Vector3 = Cube.vector(Cube.direction(address.face, address.u, address.v))
			if sample.height < 0.6 or sample.normal.dot(up) < 0.87:
				continue
			address.height = snappedf(sample.height, 0.5) - 0.1
			var position: Vector3 = Cube.local_position(Cube.cartesian(address, body.radius), anchor)
			var tree_asset: bool = asset in ["ancient_oak_v2", "tall_pine_v2"]
			var blocked: bool = false
			if tree_asset:
				for previous in trees:
					blocked = blocked or position.distance_to(previous) < 6.0
			if blocked:
				continue
			var scale_value: float = random.randf_range(0.8, 1.2)
			var frame: Basis = Cube.frame(up).rotated(up, random.randf() * TAU)
			batch.transforms.append(Transform3D(frame.scaled_local(Vector3.ONE * scale_value), position))
			batch.custom.append(Color(random.randf_range(0.95, 1.03), random.randf(), 0.5, 1))
			instances += 1
			if tree_asset:
				trees.append(position)
		if not batch.transforms.is_empty():
			batches.append(batch)
	var actor: Dictionary = {}
	if center.height > 2.0 and center.height < 95.0 and composition.fauna_weights.grazer > 0.1:
		center.height += 1.1
		actor = {"id": cell.id + ":animal", "location": center, "species_seed": int(body.seed + cell.face * 971 + (cell.x / 8) * 193 + (cell.y / 8) * 389) & 0x7fffffff,
			"role": "grazer" if composition.fauna_weights.grazer > composition.fauna_weights.forager else "forager"}
	result = {"cell": cell, "anchor": anchor, "center": center, "batches": batches, "instances": instances, "actor": actor}
	elapsed_usec = Time.get_ticks_usec() - started
