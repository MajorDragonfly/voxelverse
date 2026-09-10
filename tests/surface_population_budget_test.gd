extends SceneTree

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
	func rebase(value: Array) -> void:
		var old: Array = origin
		origin = value
		origin_changed.emit(old, value)


var failures: Array[String] = []
var host: Node3D
var terrain: TerrainFixture
var adapter: RefCounted
var player: CharacterBody3D
var eco: Node
var descriptor: Dictionary
var center: Dictionary
var cells: Dictionary

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	_setup()
	await _publication_contract()
	await _cancel_and_reenter()
	await _worker_pause_and_close()
	_spawn_fairness()
	adapter.close()
	host.free()
	await process_frame
	for message in failures: push_error(message)
	print("SURFACE_POPULATION_BUDGET_PASSED ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _setup() -> void:
	host = Node3D.new()
	root.add_child(host)
	terrain = TerrainFixture.new()
	descriptor = System.new(false, true).bodies["m1b:terra"].duplicate(true)
	descriptor.surface_generation = "living_planet_v1"
	terrain.surface = Factory.create(descriptor)
	# Exercise a canonical cube seam on a real-radius body.
	center = Cube.address(descriptor.id, 0, 1.0 - 0.000001, 0.25)
	terrain.origin = Cube.cartesian(center, descriptor.radius)
	host.add_child(terrain)
	adapter = Adapter.new(terrain)
	player = CharacterBody3D.new()
	host.add_child(player)
	adapter.bind("observer", player, center)
	eco = Ecosystem.new()
	eco.adapter = adapter
	eco.player = player
	eco.spawn = adapter.offset(center, adapter.frame_at(center).x * 1000.0)
	eco.wildlife_enabled = false
	host.add_child(eco)
	eco.set_process(false)
	cells = eco.wanted.duplicate(true)

func _payload() -> Dictionary:
	var data: Dictionary = {"cell": cells.values()[0].duplicate(true), "anchor": Cube.cartesian(center, descriptor.radius),
		"center": center.duplicate(true), "actor": {}, "instances": 0, "batches": []}
	for asset in ["ancient_oak_v2", "layered_rock_v2", "grass_tuft_v2"]:
		var species: Dictionary = Flora.create_species_variant(terrain.surface.terrain, "forest", asset, 0)
		var batch: Dictionary = {"asset_id": asset, "species": species, "transforms": [], "custom": []}
		for index in range(3):
			batch.transforms.append(Transform3D(Basis.IDENTITY, Vector3(index * 5.0, 0, data.batches.size() * 6.0)))
			batch.custom.append(Color(0.97, index * 0.1, 0.5, 1.0))
		data.batches.append(batch)
	return data

func _publication_contract() -> void:
	var data: Dictionary = _payload()
	var expected: Dictionary = data.duplicate(true)
	for batch: Dictionary in data.batches:
		while not Assets.prepare_lods(batch.asset_id, batch.species.geometry_variant): await process_frame
	eco._begin_publication(data)
	var root_id: int = eco._publication.root.get_instance_id()
	var steps: int = 0
	while not eco._publication.is_empty() and steps < 100:
		_expect(not eco.patches.has(data.cell.id) and not adapter.attached.has(data.cell.id), "Partial patch escaped into active world")
		_expect(not eco._publication.root.is_inside_tree(), "Incomplete collider entered physics world")
		var shape_count: int = eco._publication.root.shape_count
		var meshes: int = eco._publication.root.get_child_count()
		if steps == 2:
			terrain.rebase([terrain.origin[0]+91.0, terrain.origin[1]-53.0, terrain.origin[2]+27.0])
		eco._step_publication()
		var node: Node = instance_from_id(root_id)
		_expect(node.shape_count - shape_count <= 1 and node.get_child_count() - meshes <= 1, "A step built multiple meshes or shapes")
		_expect(node.shape_count == shape_count or node.get_child_count() == meshes, "A step built a mesh AND a collision")
		steps += 1
		await process_frame
	_expect(eco.patches.has(data.cell.id), "Publication did not finish")
	if not eco.patches.has(data.cell.id): return
	var patch: Dictionary = eco.patches[data.cell.id]
	_expect(patch.instances == 9 and patch.node.shape_count == 6, "Publication lost or duplicated vegetation/collision")
	_expect(patch.node.position.distance_to(adapter.to_local(center)) < 0.001, "Staged patch used an obsolete floating origin")
	_expect(patch.node.basis.is_equal_approx(Basis.IDENTITY), "Patch double-rotated radial instance frames")
	for index in range(3):
		var visual: MultiMeshInstance3D = patch.node.get_child(index)
		var batch: Dictionary = expected.batches[index]
		_expect(visual.multimesh.instance_count == 3, "Batch lost instances")
		_expect(visual.multimesh.mesh == Assets.get_mesh(batch.asset_id, 0, batch.species.geometry_variant), "Visual/collider geometry variant diverged")
		var buffer: PackedFloat32Array = visual.multimesh.buffer
		_expect(buffer.size() == 48, "Submitted instance buffer is incomplete")
		for instance in range(3):
			var offset: int = instance * 16
			var submitted_position := Vector3(buffer[offset+3], buffer[offset+7], buffer[offset+11])
			_expect(submitted_position.is_equal_approx(batch.transforms[instance].origin), "Instance position changed during publication")
			var submitted_color := Color(buffer[offset+12], buffer[offset+13], buffer[offset+14], buffer[offset+15])
			_expect(submitted_color.is_equal_approx(batch.custom[instance]), "Instance attributes changed during publication")
	terrain.rebase([terrain.origin[0]-32.0, terrain.origin[1]+17.0, terrain.origin[2]-5.0])
	_expect(patch.node.position.distance_to(adapter.to_local(center)) < 0.001, "Published patch lost origin tracking")
	print("SURFACE_PUBLICATION_CONTRACT ", JSON.stringify({"steps":steps,"instances":patch.instances,"shapes":patch.node.shape_count,"diagnostics":eco.streaming_diagnostics()}))
	_remove_patch(data.cell.id)

func _cancel_and_reenter() -> void:
	var data: Dictionary = _payload()
	eco.wanted = cells.duplicate(true)
	eco._begin_publication(data)
	eco._step_publication()
	var stale_id: int = eco._publication.root.get_instance_id()
	adapter.place(player, adapter.offset(center, adapter.frame_at(center).x * 1000.0))
	eco._refresh()
	_expect(eco._publication.is_empty() and not is_instance_id_valid(stale_id), "Leaving a region retained staged nodes")
	adapter.place(player, center)
	eco._refresh()
	_expect(not eco.patches.has(data.cell.id), "Re-entry resurrected a cancelled publication")
	# A descriptor change must fail closed before submitting another mesh.
	eco._begin_publication(_payload())
	terrain.surface.body.id = "different-body"
	eco._step_publication()
	_expect(eco._publication.is_empty() and not eco.patches.has(data.cell.id), "Foreign body accepted an old result")
	terrain.surface.body.id = "m1b:terra"

func _worker_pause_and_close() -> void:
	eco.wanted = cells.duplicate(true)
	eco._tick(0.0)
	_expect(eco._task >= 0, "CPU placement worker did not start")
	var generation: int = eco._generation
	adapter.place(player, adapter.offset(center, adapter.frame_at(center).x * 1000.0))
	eco._refresh()
	adapter.place(player, center)
	eco._refresh()
	_expect(eco._generation > generation, "A -> B -> A did not invalidate the old request generation")
	while not WorkerThreadPool.is_task_completed(eco._task): await process_frame
	eco._tick(0.0)
	_expect(eco.patches.is_empty() and eco._publication.is_empty(), "Stale worker published after re-entry")
	# The loop may immediately schedule a fresh request, but never more than one.
	_expect(eco.streaming_diagnostics().workers <= 1 and eco.streaming_diagnostics().prepared <= 1, "Worker/queue bound exceeded")
	if eco._task >= 0:
		while not WorkerThreadPool.is_task_completed(eco._task): await process_frame
		eco._tick(0.0)
	var before: Dictionary = eco.streaming_diagnostics()
	eco.set_process(true)
	paused = true
	for frame in range(4): await process_frame
	_expect(eco.streaming_diagnostics() == before, "Paused scene advanced streaming publication")
	paused = false
	eco.set_process(false)
	# Explicitly close during partially constructed publication.
	eco.close()
	_expect(eco._task == -1 and eco._job == null and eco._publication.is_empty() and eco._prepared.is_empty(), "Close left a worker/result/staged patch")
	eco._tick(1.0)
	_expect(eco._task == -1 and eco.patches.is_empty(), "Closed host restarted streaming")
	eco.close() # Teardown is safe when invoked twice.
	var next := Ecosystem.new()
	next.adapter = adapter
	next.player = player
	next.spawn = eco.spawn
	next.wildlife_enabled = false
	host.add_child(next)
	next.set_process(false)
	next._tick(0.0)
	_expect(next._task >= 0, "Teardown fixture did not start a worker")
	host.remove_child(next)
	_expect(next._task == -1 and next._job == null, "Tree exit did not join and release its running worker")
	next.free()

func _spawn_fairness() -> void:
	var population: Node = load("res://tests/fixtures/surface_spawn_budget_fixture.gd").new()
	var animals: Array[Dictionary] = []
	var plants: Array[Dictionary] = [{"id":"food", "blocked":false}]
	for index in range(20): animals.append({"id":"animal" + str(index), "blocked":index < 19})
	for tick in range(22):
		var old: int = population.attempts.size()
		population._spawn_candidates(animals, plants)
		_expect(population.attempts.size() - old <= population.MAX_SPAWN_ATTEMPTS, "Blocked candidates exceeded attempt budget")
		if "animal19" in population.successes: break
	_expect("animal19" in population.successes, "Blocked first candidates starved reachable animal")
	_expect(population.successes.count("food") > 0, "Animal work starved plants")
	population.attempts.clear()
	var empty: Array[Dictionary] = []
	population._spawn_candidates(empty, empty)
	_expect(population.attempts.is_empty() and population.last_spawn_attempts == 0, "Empty queue reused obsolete candidates")
	population.free()

func _remove_patch(id: String) -> void:
	adapter.unbind(id)
	eco.patches[id].node.free()
	eco.patches.erase(id)

func _expect(value: bool, message: String) -> void:
	if not value and message not in failures: failures.append(message)
