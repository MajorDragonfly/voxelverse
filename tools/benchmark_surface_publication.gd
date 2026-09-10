extends SceneTree
## Reusable publication-only CPU probe. Run unchanged on the base revision too.
const Ecosystem = preload("res://world/surface/surface_ecosystem.gd")
const System = preload("res://world/space/celestial_system.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Job = preload("res://world/surface/surface_population_job.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")

class TerrainFixture:
	extends Node3D
	signal origin_changed(previous: Array, current: Array)
	var surface: RefCounted
	var origin: Array

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var host := Node3D.new()
	root.add_child(host)
	var terrain := TerrainFixture.new()
	var descriptor: Dictionary = System.new(false, true).bodies["m1b:terra"].duplicate(true)
	descriptor.surface_generation = "living_planet_v1"
	terrain.surface = Factory.create(descriptor)
	var center: Dictionary = Cube.address(descriptor.id, 0, 0.25, 0.25)
	terrain.origin = Cube.cartesian(center, descriptor.radius)
	host.add_child(terrain)
	var adapter := Adapter.new(terrain)
	var player := CharacterBody3D.new()
	host.add_child(player)
	var eco := Ecosystem.new()
	eco.adapter = adapter
	eco.player = player
	eco.spawn = adapter.offset(center, Vector3(1000, 1000, 1000))
	eco.wildlife_enabled = false
	host.add_child(eco)
	eco.set_process(false)
	var data: Dictionary = {"cell": Job.nearby(descriptor, center).values()[0], "anchor": terrain.origin,
		"center": center, "batches": [], "actor": {}, "instances": 0}
	for recipe in Job.RECIPES:
		var species: Dictionary = Flora.create_species_variant(terrain.surface.terrain, "forest", recipe[0], 0)
		var batch: Dictionary = {"asset_id": recipe[0], "species": species, "transforms": [], "custom": []}
		for i in range(recipe[1]):
			batch.transforms.append(Transform3D(Basis.IDENTITY, Vector3(i * 4.0, 0, data.batches.size() * 5.0)))
			batch.custom.append(Color.WHITE)
		data.batches.append(batch)
		while not Assets.prepare_lods(recipe[0], species.geometry_variant): await process_frame
	var costs: Array[float] = []
	var total: Array[float] = []
	for iteration in range(10):
		var payload: Dictionary = data.duplicate(true)
		eco.wanted = {payload.cell.id: payload.cell}
		var elapsed: float = 0.0
		if eco.has_method("_begin_publication"):
			eco._begin_publication(payload)
			while not eco._publication.is_empty():
				var started: int = Time.get_ticks_usec()
				eco._step_publication()
				var ms: float = (Time.get_ticks_usec() - started) / 1000.0
				costs.append(ms)
				elapsed += ms
				await process_frame
		else:
			var started: int = Time.get_ticks_usec()
			eco._publish(payload)
			elapsed = (Time.get_ticks_usec() - started) / 1000.0
			costs.append(elapsed)
		total.append(elapsed)
		adapter.unbind(payload.cell.id)
		eco.patches[payload.cell.id].node.queue_free()
		eco.patches.clear()
		await process_frame
	costs.sort()
	total.sort()
	print("SURFACE_PUBLICATION_METRICS ", JSON.stringify({"scope": "Headless CPU, warm actual assets, synthetic dense patch (64 instances / 7 families), no terrain/GPU; 10 repetitions", "godot": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "steps": costs.size(), "step_p50_ms": costs[costs.size()/2],
		"step_p95_ms": costs[mini(costs.size()-1, int(ceil(costs.size()*0.95))-1)], "step_max_ms": costs[-1],
		"patch_p50_ms": total[5], "patch_max_ms": total[-1]}))
	eco.close()
	adapter.close()
	host.free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self)
