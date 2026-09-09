extends Node

const Job = preload("res://world/surface/surface_population_job.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Obstacles = preload("res://world/visuals/scenery/environment_obstacles.gd")
const Buffer = preload("res://core/multimesh_buffer.gd")
const Creature = preload("res://world/surface/surface_creature.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const MAX_PATCHES: int = 25
const MAX_ANIMALS: int = 4
const MAX_RECORDS: int = 256
var domestic: RefCounted
var wildlife_enabled: bool = true
var adapter: RefCounted
var player: CharacterBody3D
var spawn: Dictionary
var patches: Dictionary = {}
var animals: Dictionary = {}
var animal_records: Dictionary = {}
var wanted: Dictionary = {}
var loaded: int = 0
var unloaded: int = 0
var max_publish_ms: float = 0.0
var max_worker_ms: float = 0.0
var max_frame_work_ms: float = 0.0
var max_animal_build_ms: float = 0.0
var peak_instances: int = 0
var paused: bool = false
var _job: RefCounted
var _task: int = -1
var _prepared: Dictionary = {}
var _timer: float = 0.0


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_tick(delta)
	max_frame_work_ms = maxf(max_frame_work_ms, (Time.get_ticks_usec() - started) / 1000.0)


func _tick(delta: float) -> void:
	_timer += delta
	if _timer > 0.25:
		_timer = 0.0
		_refresh()
		_update_animals()
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		max_worker_ms = maxf(max_worker_ms, _job.elapsed_usec / 1000.0)
		_prepared = _job.result if wanted.has(_job.cell.id) else {}
		_job = null
	if not _prepared.is_empty():
		for batch: Dictionary in _prepared.batches:
			if not Assets.prepare_lods(batch.asset_id, batch.species.geometry_variant):
				return
		if wanted.has(_prepared.cell.id):
			_publish(_prepared)
		_prepared = {}
		return
	for id: String in wanted:
		if patches.has(id):
			continue
		_job = Job.new()
		_job.body = adapter.terrain.surface.body.duplicate(true)
		_job.cell = wanted[id].duplicate(true)
		_task = WorkerThreadPool.add_task(_job.run, false, "Radial flora placement")
		break


func _refresh() -> void:
	wanted = Job.nearby(adapter.terrain.surface.body, adapter.location(player))
	var ordered: Array = wanted.keys()
	ordered.sort_custom(func(a: String, b: String): return _cell_distance(wanted[a]) < _cell_distance(wanted[b]))
	var sorted: Dictionary = {}
	for id in ordered:
		sorted[id] = wanted[id]
	wanted = sorted
	for id in patches.keys():
		if not wanted.has(id):
			adapter.unbind(id)
			patches[id].node.get_parent().remove_child(patches[id].node)
			patches[id].node.queue_free()
			patches.erase(id)
			unloaded += 1
	for data: Dictionary in patches.values():
		var distance: float = data.node.position.distance_to(player.position)
		data.node.collision_layer = 2 if distance < 90.0 else 0
		for visual: MultiMeshInstance3D in data.node.get_children():
			visual.multimesh.mesh = Assets.get_mesh(visual.get_meta("asset"), 0 if distance < 80.0 else 1)


func _cell_distance(cell: Dictionary) -> float:
	var location: Dictionary = Cube.address(adapter.terrain.surface.body.id, cell.face,
		-1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
	location.height = adapter.location(player).height
	return adapter.to_local(location).distance_squared_to(player.position)


func _publish(data: Dictionary) -> void:
	if patches.size() >= MAX_PATCHES:
		return
	var started: int = Time.get_ticks_usec()
	var root := Obstacles.new()
	get_parent().add_child(root)
	# Transforms inside the batch are already body-fixed radial frames.
	# The patch itself translates with the origin and must have identity basis.
	var center: Dictionary = Cube.from_cartesian(adapter.terrain.surface.body.id, data.anchor, adapter.terrain.surface.body.radius)
	adapter.bind(data.cell.id, root, center)
	root.basis = Basis.IDENTITY
	root.collision_layer = 2
	data.instances = 0
	for batch: Dictionary in data.batches:
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		for index in range(batch.transforms.size()):
			var transform: Transform3D = batch.transforms[index]
			if (root.position + transform.origin).distance_to(adapter.to_local(spawn)) < 8.0:
				continue
			transforms.append(transform)
			colors.append(batch.custom[index])
		batch.transforms = transforms
		data.instances += transforms.size()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = Assets.get_mesh(batch.asset_id, 0)
		multimesh.instance_count = transforms.size()
		multimesh.buffer = Buffer.pack(transforms, colors)
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = multimesh
		visual.material_override = Assets.get_material(adapter.terrain.surface.terrain, batch.species)
		visual.set_meta("asset", batch.asset_id)
		root.add_child(visual)
		if Obstacles.has_collision(batch.asset_id):
			root.add_batch(batch)
	data.node = root
	data.erase("batches")
	patches[data.cell.id] = data
	loaded += 1
	peak_instances = maxi(peak_instances, instance_count())
	max_publish_ms = maxf(max_publish_ms, (Time.get_ticks_usec() - started) / 1000.0)


func _update_animals() -> void:
	if not wildlife_enabled: return
	if domestic != null:
		domestic.update(self)
		if domestic.built_this_update: return
	for id in animals.keys():
		if domestic != null and domestic.owns(id): continue
		var animal: CharacterBody3D = animals[id]
		animal.enabled = not paused
		if animal.position.distance_to(player.position) > 105.0 or not wanted.has(id.trim_suffix(":animal")):
			_capture_animal(id)
			adapter.unbind(id)
			animal.get_parent().remove_child(animal)
			animal.queue_free()
			animals.erase(id)
	if paused or animals.size() >= MAX_ANIMALS:
		return
	for patch: Dictionary in patches.values():
		var actor: Dictionary = patch.actor
		if actor.is_empty() or animals.has(actor.id):
			continue
		var state: Dictionary = animal_records.get(actor.id, {})
		var here: Dictionary = actor.location if state.is_empty() else state.location
		if adapter.to_local(here).distance_to(player.position) > 70.0 or not adapter.collision_ready(here):
			continue
		var started: int = Time.get_ticks_usec()
		if state.is_empty():
			if animal_records.size() >= MAX_RECORDS:
				continue
			var design: Dictionary = Species.create_species(actor.species_seed, Vector2i(patch.cell.x / 8, patch.cell.y / 8), actor.role)
			var frame: Basis = adapter.frame_at(here)
			state = {"location": here.duplicate(true), "forward": [-frame.z.x, -frame.z.y, -frame.z.z], "velocity": [0.0, 0.0, 0.0],
				"traveled": 0.0, "home": here.duplicate(true), "goal": adapter.offset(here, frame.x * 7.0, 1.1),
				"returning": false, "design": JSON.from_native(design)}
			animal_records[actor.id] = state
		var animal := Creature.new()
		animal.adapter = adapter
		animal.home = state.home.duplicate(true)
		animal.goal = state.goal.duplicate(true)
		animal.forward = Cube.vector(state.forward)
		animal.velocity = Cube.vector(state.velocity)
		animal.traveled = state.traveled
		animal.returning = state.returning
		# Preserve Vector3/Color anatomy fields through JSON, not their lossy
		# printed strings. Object decoding stays disabled.
		animal.design = JSON.to_native(state.design, false)
		get_parent().add_child(animal)
		adapter.bind(actor.id, animal, here, animal.forward)
		animals[actor.id] = animal
		max_animal_build_ms = maxf(max_animal_build_ms, (Time.get_ticks_usec() - started) / 1000.0)
		# One creature build per update; all others remain pending.
		break


func _capture_animal(id: String) -> void:
	if domestic != null and domestic.owns(id):
		domestic.capture_one(self, id)
		return
	var animal: CharacterBody3D = animals[id]
	animal_records[id].merge({"location": adapter.location(animal), "forward": [animal.forward.x, animal.forward.y, animal.forward.z],
		"velocity": [animal.velocity.x, animal.velocity.y, animal.velocity.z], "traveled": animal.traveled, "returning": animal.returning}, true)


func capture() -> Dictionary:
	for id: String in animals:
		_capture_animal(id)
	return animal_records.duplicate(true)


func instance_count() -> int:
	var count: int = 0
	for patch: Dictionary in patches.values():
		count += patch.instances
	return count


func close() -> void:
	if domestic != null: domestic.close(self)
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_prepared = {}
	for id: String in animals:
		adapter.unbind(id)
		animals[id].get_parent().remove_child(animals[id])
		animals[id].queue_free()
	animals.clear()
	for id: String in patches:
		adapter.unbind(id)
		patches[id].node.get_parent().remove_child(patches[id].node)
		patches[id].node.queue_free()
	patches.clear()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
