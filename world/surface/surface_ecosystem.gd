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
var max_asset_prepare_ms: float = 0.0
var max_frame_work_ms: float = 0.0
var max_animal_build_ms: float = 0.0
var peak_instances: int = 0
var paused: bool = false
var _job: RefCounted
var _task: int = -1
var _prepared: Dictionary = {}
var _timer: float = 0.0
# One CPU worker, one prepared result, one detached patch under construction.
# Each process call submits at most one MultiMesh or one collision shape.
var _publication: Dictionary = {}
var _generation: int = 0
var _job_ticket: Dictionary = {}
var _closed: bool = false
var discarded_results: int = 0
var last_publish_units: int = 0
var max_publish_units: int = 0
var publication_steps: int = 0


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	last_publish_units = 0
	if _closed: return
	var started: int = Time.get_ticks_usec()
	_tick(delta)
	max_frame_work_ms = maxf(max_frame_work_ms, (Time.get_ticks_usec() - started) / 1000.0)


func _tick(delta: float) -> void:
	last_publish_units = 0
	if _closed: return
	_timer += delta
	if _timer > 0.25:
		_timer = 0.0
		_refresh()
		_update_animals()
		# Creature meshes share the main thread with flora publication.
		# Never submit both kinds in the same streaming step.
		if last_publish_units > 0: return
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		max_worker_ms = maxf(max_worker_ms, _job.elapsed_usec / 1000.0)
		if _ticket_current(_job_ticket):
			_prepared = _job.result
		else:
			discarded_results += 1
		_job = null
	if not _publication.is_empty():
		_step_publication()
		return
	if not _prepared.is_empty():
		_begin_publication(_prepared)
		_prepared = {}
		return
	for id: String in wanted:
		if patches.has(id): continue
		_job = Job.new()
		_job.body = adapter.terrain.surface.body.duplicate(true)
		_job.cell = wanted[id].duplicate(true)
		_job_ticket = _ticket(id)
		_job.prepare()
		_task = WorkerThreadPool.add_task(_job.run, false, "Radial flora placement")
		break


func _ticket(id: String) -> Dictionary:
	return {"body_id": adapter.terrain.surface.body.id, "cell_id": id, "generation": _generation}


func _ticket_current(ticket: Dictionary) -> bool:
	return not _closed and ticket.get("generation", -1) == _generation \
		and ticket.get("body_id", "") == adapter.terrain.surface.body.id \
		and wanted.has(ticket.get("cell_id", ""))


func _refresh() -> void:
	wanted = Job.nearby(adapter.terrain.surface.body, adapter.location(player))
	var ordered: Array = wanted.keys()
	ordered.sort_custom(func(a: String, b: String): return _cell_distance(wanted[a]) < _cell_distance(wanted[b]))
	var sorted: Dictionary = {}
	for id in ordered:
		sorted[id] = wanted[id]
	wanted = sorted
	# Invalidate when leaving the requested region, including A -> B -> A
	# while its worker is still running. Re-entry cannot revive the old job.
	if (_task >= 0 or not _prepared.is_empty()) and not _ticket_current(_job_ticket):
		_generation += 1
		_prepared = {}
	if not _publication.is_empty() and not _ticket_current(_publication.ticket):
		_discard_publication()
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
			visual.multimesh.mesh = Assets.get_mesh(visual.get_meta("asset"), 0 if distance < 80.0 else 1, visual.get_meta("variant", 0))


func _cell_distance(cell: Dictionary) -> float:
	var location: Dictionary = Cube.address(adapter.terrain.surface.body.id, cell.face,
		-1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
	location.height = adapter.location(player).height
	return adapter.to_local(location).distance_squared_to(player.position)


func _begin_publication(data: Dictionary) -> void:
	if _closed or not wanted.has(data.cell.id) or patches.has(data.cell.id) or patches.size() >= MAX_PATCHES:
		return
	var center: Dictionary = Cube.from_cartesian(adapter.terrain.surface.body.id, data.anchor, adapter.terrain.surface.body.radius)
	# Detached until every visual and shape exists. No half-built collider or
	# origin binding can become visible to navigation, actors or save consumers.
	data.instances = 0
	_publication = {"data": data, "root": Obstacles.new(), "center": center,
		"ticket": _ticket(data.cell.id), "batch_index": 0, "shape_index": 0, "phase": "mesh"}


func _step_publication() -> void:
	last_publish_units = 0
	if _publication.is_empty(): return
	if not _ticket_current(_publication.ticket):
		_discard_publication()
		return
	var started: int = Time.get_ticks_usec()
	var data: Dictionary = _publication.data
	var patch_root: StaticBody3D = _publication.root
	if _publication.batch_index >= data.batches.size():
		# Resolve the canonical anchor NOW: origin shifts during preparation
		# must not publish a patch at yesterday's local coordinates.
		get_parent().add_child(patch_root)
		adapter.bind(data.cell.id, patch_root, _publication.center)
		patch_root.basis = Basis.IDENTITY
		patch_root.collision_layer = 2 if patch_root.position.distance_to(player.position) < 90.0 else 0
		data.node = patch_root
		data.erase("batches")
		patches[data.cell.id] = data
		loaded += 1
		peak_instances = maxi(peak_instances, instance_count())
		_publication = {}
	else:
		var batch: Dictionary = data.batches[_publication.batch_index]
		if _publication.phase == "mesh":
			var assets_ready: bool = Assets.prepare_lods(batch.asset_id, batch.species.geometry_variant)
			max_asset_prepare_ms = maxf(max_asset_prepare_ms, (Time.get_ticks_usec() - started) / 1000.0)
			if not assets_ready: return
			var transforms: Array[Transform3D] = []
			var colors: Array[Color] = []
			var origin: Vector3 = adapter.to_local(_publication.center)
			var exclusions: Array[Dictionary] = _campaign_exclusions()
			for index in range(batch.transforms.size()):
				var transform: Transform3D = batch.transforms[index]
				var point: Vector3 = origin + transform.origin
				if point.distance_to(adapter.to_local(spawn)) < 8.0: continue
				var reserved: bool = false
				for place: Dictionary in exclusions:
					if point.distance_to(place.point) < place.radius: reserved = true; break
				if reserved: continue
				transforms.append(transform)
				colors.append(batch.custom[index])
			batch.transforms = transforms
			data.instances += transforms.size()
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_custom_data = true
			multimesh.mesh = Assets.get_mesh(batch.asset_id, 0, batch.species.geometry_variant)
			multimesh.instance_count = transforms.size()
			multimesh.buffer = Buffer.pack(transforms, colors)
			var visual := MultiMeshInstance3D.new()
			visual.multimesh = multimesh
			visual.material_override = Assets.get_material(adapter.terrain.surface.terrain, batch.species)
			visual.set_meta("asset", batch.asset_id)
			visual.set_meta("variant", batch.species.geometry_variant)
			patch_root.add_child(visual)
			_publication.phase = "shapes"
			_publication.shape_index = 0
		elif Obstacles.has_collision(batch.asset_id) and _publication.shape_index < batch.transforms.size():
			var single: Dictionary = batch.duplicate()
			single.transforms = [batch.transforms[_publication.shape_index]]
			patch_root.add_batch(single)
			_publication.shape_index += 1
		else:
			_publication.batch_index += 1
			_publication.phase = "mesh"
	last_publish_units = 1
	max_publish_units = maxi(max_publish_units, last_publish_units)
	publication_steps += 1
	max_publish_ms = maxf(max_publish_ms, (Time.get_ticks_usec() - started) / 1000.0)


func _discard_publication() -> void:
	if _publication.is_empty(): return
	_publication.root.free()
	_publication = {}
	discarded_results += 1


func streaming_diagnostics() -> Dictionary:
	return {"workers": int(_task >= 0), "prepared": int(not _prepared.is_empty()),
		"staged_patches": int(not _publication.is_empty()), "patches": patches.size(),
		"last_publish_units": last_publish_units, "max_publish_units": max_publish_units,
		"publication_steps": publication_steps, "generation": _generation,
		"discarded_results": discarded_results, "max_asset_prepare_ms": max_asset_prepare_ms, "closed": _closed}

func _campaign_exclusions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if preload("res://world/surface/gameplay_space.gd").adapter(self) == null: return result
	var body: Dictionary = get_node("/root/GameState").get_current_body_record()
	if body.has("home_group"): result.append({"point": adapter.to_local(body.home_group.anchor), "radius": 4.0})
	var village: Dictionary = body.get("tribe", {})
	var structures: Array = village.get("housing", {}).get("homes", []).duplicate()
	structures.append_array(village.get("husbandry", {}).get("pens", []))
	structures.append_array(village.get("economy", {}).get("stations", {}).values())
	if village.get("project", {}).has("position"): structures.append(village.project)
	for object: Dictionary in structures: result.append({"point": adapter.to_local(object.position), "radius": 3.0})
	if body.has("tribal_neighbor"): result.append({"point": adapter.to_local(body.tribal_neighbor.anchor), "radius": 4.0})
	return result


func _update_animals() -> void:
	if not wildlife_enabled: return
	if domestic != null:
		domestic.update(self)
		if domestic.built_this_update:
			last_publish_units = 1
			return
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
		last_publish_units = 1
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
	_closed = true
	_generation += 1
	_discard_publication()
	wanted.clear()
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
	_closed = true
	_generation += 1
	_discard_publication()
	_prepared = {}
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_job = null
