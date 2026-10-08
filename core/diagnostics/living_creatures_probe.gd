extends "res://core/diagnostics/spherical_campaign_probe.gd"
const Space = preload("res://world/surface/gameplay_space.gd")
var lifecycle: Dictionary = {}

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--r33-02-living-restart" in OS.get_cmdline_user_args():
		await _fresh_restart()
		await _finish()
		return
	var path: String = saves.create_slot("Lebendige Kreaturen", 15838, Cube.MODE)
	_stage("living_creatures_open")
	await _open(path)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var population: Node = scene.population
	await _until(func() -> bool: return population.nests.size() >= 2, 25000)
	_expect(population.nests.size() >= 2, "Public spherical campaign did not stream multiple nests")
	var members: Dictionary = {}
	await _until(func() -> bool:
		members.clear()
		for actor: Node3D in population.animals.values():
			if not actor.colony_id.is_empty(): members[actor.colony_id] = int(members.get(actor.colony_id, 0)) + 1
		return members.values().any(func(count: int) -> bool: return count >= 3), 25000)
	_expect(members.values().any(func(count: int) -> bool: return count >= 3), "No nest had three physical residents: " + str(members))
	print("LIVING_CREATURES_RESIDENTS ", JSON.stringify({"members":members, "animals":population.animals.size(),
		"plants":population.plants.size(), "nests":population.nests.size(), "peak_attempts":population.peak_spawn_attempts}))
	lifecycle.residents = members.duplicate(true)
	_stage("living_creatures_colonies")
	_expect(population.animals.size() <= population.MAX_ANIMALS and population.nests.size() <= population.MAX_NESTS, "Family generation exceeded live simulation budgets")
	_expect(population.peak_spawn_attempts <= population.MAX_SPAWN_ATTEMPTS, "Population exceeded the bounded spawn-attempt budget")
	var paused_counts: Array = [population.animals.keys(), population.plants.keys(), population.nests.keys(), population._generation_cursor]
	flow.toggle_pause()
	for frame in range(20): await tree.process_frame
	_expect(paused_counts == [population.animals.keys(), population.plants.keys(), population.nests.keys(), population._generation_cursor], "Paused population generated or published objects")
	lifecycle.pause_stable = paused_counts == [population.animals.keys(), population.plants.keys(), population.nests.keys(), population._generation_cursor]
	flow.toggle_pause()
	for nest: Node3D in population.nests.values():
		_expect(not nest.is_in_group(&"player_nest") and not nest.has_node("HomeGroup"), "Wild nest claimed player respawn/group ownership")
		_expect(nest.global_basis.y.dot(Space.up(self, nest.global_position)) > 0.99, "Nest is not aligned to the spherical surface")
		var ground: Dictionary = Space.floor_hit(scene.player, nest.global_position)
		if not ground.is_empty(): _expect(nest.global_position.distance_to(ground.position) < 0.12, "Wild nest is floating above the ground")
	var counts: Dictionary = {}
	for nest: Node3D in population.nests.values(): counts[nest.colony.id] = nest.colony.members.duplicate()
	var pending: RefCounted = _pending_skin(population)
	_expect(saves.save_now(), "Real populated world could not save: " + saves.last_error)
	if pending != null: _expect(pending.cancelled and population._skin_job == null, "Save retained an unpublished skin job")
	lifecycle.save_cancelled = pending != null and pending.cancelled and population._skin_job == null
	var expected_records: Dictionary = {}
	for id: String in population.records:
		var record: Dictionary = population.records[id]
		expected_records[id] = {"identity":record.identity.duplicate(true), "blueprint":record.blueprint.duplicate(true),
			"species_seed":record.species_seed, "individual_seed":record.individual_seed, "home":record.home.duplicate(true)}
	_expect(Atomic.write("user://r33_02_living_restart.json", {"path":path, "colonies":counts, "records":expected_records}, false) == OK, "Living restart evidence write failed")
	# Origin changes are presentation changes, never canonical nest relocation.
	var before: Dictionary = {}
	for id: String in population.nests: before[id] = Space.encode(self, population.nests[id].global_position)
	var origin: Array = scene.terrain.origin.duplicate()
	pending = _pending_skin(population)
	var pending_location: Dictionary = population._skin_record.get("location", {}).duplicate(true) if pending != null else {}
	scene.terrain.rebase([origin[0] + 32.0, origin[1] - 12.0, origin[2] + 24.0])
	if pending != null: _expect(not pending.cancelled and population._skin_record.location == pending_location, "Origin shift invalidated canonical pending skin work")
	lifecycle.origin_kept_canonical_job = pending != null and not pending.cancelled and population._skin_record.location == pending_location
	for id: String in before:
		var after: Dictionary = Space.encode(self, population.nests[id].global_position)
		_expect(preload("res://world/home_group/home_group_state.gd").distance(before[id], after) < 0.02, "Origin shift moved a nest on the planet")
	if pending != null:
		var empty_candidates: Array[Dictionary] = []
		population._spawn_candidates(empty_candidates, empty_candidates)
		_expect(pending.cancelled and population._skin_job == null, "Leaving the active candidate set retained unpublished skin work")
		lifecycle.leaving_candidates_cancelled = pending.cancelled and population._skin_job == null
	pending = _pending_skin(population)
	flow.return_to_title()
	await tree.scene_changed
	if pending != null: _expect(pending.cancelled, "World unload retained unpublished skin work")
	lifecycle.unload_cancelled = pending != null and pending.cancelled
	# A separate engine owns a cold cache and opens the actual saved world.
	var output: Array = []
	var arguments: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/living_creatures_world_test.gd", "--", "--r33-02-living-restart"]
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code == 0 and str(output).contains("R33_02_LIVING_FRESH_PROCESS_PASSED"), "Living cold restart failed: " + str(output))
	lifecycle.cold_restart = {"exit_code":code, "completion_marker":str(output).contains("R33_02_LIVING_FRESH_PROCESS_PASSED")}
	print("R33_02_LIVING_COLD_RESTART ", code, " ", str(output))
	_stage("living_creatures_reload")
	await _open(path)
	if _expect_world():
		population = tree.current_scene.population
		await _until(func() -> bool: return not population.nests.is_empty(), 20000)
		await _until(func() -> bool:
			members.clear()
			for actor: Node3D in population.animals.values():
				if not actor.colony_id.is_empty(): members[actor.colony_id] = int(members.get(actor.colony_id, 0)) + 1
			return members.values().any(func(count: int) -> bool: return count >= 3), 25000)
		_expect(members.values().any(func(count: int) -> bool: return count >= 3), "Reload did not restore three physical nest residents: " + str(members))
		print("LIVING_CREATURES_RELOADED_RESIDENTS ", JSON.stringify(members))
		lifecycle.reloaded_residents = members.duplicate(true)
		for nest: Node3D in population.nests.values():
			if counts.has(nest.colony.id): _expect(counts[nest.colony.id] == nest.colony.members, "World reload changed nest identities")
		flow.return_to_title()
		await tree.scene_changed
	_stage("living_creatures_complete")
	await _finish()

func _pending_skin(population: Node) -> RefCounted:
	var script: Script = preload("res://creatures/runtime/creature_runtime_preview.gd")
	if not script.has_method("cached_species_skin") or population.records.is_empty(): return null
	population._cancel_skin()
	var record: Dictionary = population.records.values()[0]
	var job := preload("res://world/surface/campaign_population_state.gd").SkinBuild.new(population.Encoding.decode(record.blueprint))
	job.advance(2000, 100)
	_expect(job.mesh == null, "Lifecycle fixture did not retain partial skin work")
	population._skin_job = job
	population._skin_record = record
	return job

func _fresh_restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://r33_02_living_restart.json"))
	_expect(not expected.is_empty(), "Cold restart lost the actual saved-world fixture")
	if expected.is_empty(): return
	await _open(expected.path)
	if not _expect_world(): return
	var population: Node = tree.current_scene.population
	await _until(func() -> bool:
		var families: Dictionary = {}
		for actor: Node3D in population.animals.values():
			if not actor.colony_id.is_empty(): families[actor.colony_id] = int(families.get(actor.colony_id, 0)) + 1
		return families.values().any(func(count: int) -> bool: return count >= 3), 25000)
	var members: Dictionary = {}
	for actor: Node3D in population.animals.values():
		if not actor.colony_id.is_empty(): members[actor.colony_id] = int(members.get(actor.colony_id, 0)) + 1
	_expect(members.values().any(func(count: int) -> bool: return count >= 3), "Cold restart did not restore three physical residents of one family")
	for id: String in expected.records:
		var record: Dictionary = population.storage.record(id)
		_expect(not record.is_empty(), "Cold restart lost a canonical resident")
		for field: String in expected.records[id]:
			_expect(record.get(field) == expected.records[id][field], "Cold restart changed resident " + field)
	for nest: Node3D in population.nests.values():
		if expected.colonies.has(nest.colony.id): _expect(expected.colonies[nest.colony.id] == nest.colony.members, "Cold restart changed colony identities")
	print("R33_02_LIVING_SKIN_LIFECYCLE ", JSON.stringify({"completed":population.skin_jobs_completed,"cancelled":population.skin_jobs_cancelled,"max_slice_ms":population.max_skin_slice_ms}))
	lifecycle.fresh_process = {"families":members, "canonical_records_checked":expected.records.size(),
		"completed_skin_jobs":population.skin_jobs_completed,"max_slice_ms":population.max_skin_slice_ms}
	flow.return_to_title()
	await tree.scene_changed
	if failures.is_empty(): print("R33_02_LIVING_FRESH_PROCESS_PASSED")

func _until(predicate: Callable, milliseconds: int) -> void:
	var started: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - started < milliseconds:
		await tree.process_frame

func _stage(label: String) -> void:
	print("LIVING_CREATURES_STAGE ", label, " elapsed_seconds=", Time.get_ticks_msec() / 1000.0)

func _finish() -> void:
	tree.paused = false
	var evidence: String = OS.get_environment("R33_02_LIFECYCLE_REPORT")
	if not evidence.is_empty():
		var suffix: String = "-child.json" if "--r33-02-living-restart" in OS.get_cmdline_user_args() else "-parent.json"
		_expect(Atomic.write(evidence + suffix, {"passed":failures.is_empty(), "failures":failures,
			"pid":OS.get_process_id(), "elapsed_ms":Time.get_ticks_msec(), "checks":lifecycle}, false) == OK, "Lifecycle evidence write failed")
	print(JSON.stringify({"test": "living_creatures_world", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
