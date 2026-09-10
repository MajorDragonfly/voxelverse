extends "res://core/diagnostics/spherical_campaign_probe.gd"
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Habitat = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Traits = preload("res://world/fauna/domestication/domestication_contract.gd")
const Suitability = preload("res://ui/discovery/animal_suitability.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
var metrics: Dictionary = {}

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--arch21-restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://arch21-restart.json"))
		await _open(expected.path, true)
		if _expect_world():
			_check_checkpoint(expected.saved)
			_expect(FileAccess.get_file_as_string(expected.original_path).sha256_text() == expected.original_sha256, "Restart rewrote original old save")
			_expect(saves.save_now(), "Fresh-process write failed")
		if failures.is_empty(): print("ARCH21_FRESH_PROCESS_PASSED")
		await _done(); return
	_extract_fixture()
	if not failures.is_empty(): await _done(); return
	var legacy: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://arch21-legacy-expected.json"))
	_expect(legacy.source == "905e524003c5f782f7b7daab09f0e23a1b632756", "Unexpected legacy source")
	var path: String = saves.duplicate_slot(legacy.path, "ARCH21 upgrade copy")
	_expect(not path.is_empty(), "Could not copy genuine old slot: " + saves.last_error)
	if path.is_empty(): await _done(); return
	await _open(path, true)
	if not _expect_world(): await _done(); return
	var original: Dictionary = Registry.active(legacy.saved.game_state)
	var body: Dictionary = state.get_current_body()
	var population: Node = tree.current_scene.population
	_expect(body.fauna_catalog.schema == 4 and body.fauna_catalog.species.size() == 4, "Runtime did not add the fourth species")
	_expect(_same(body.fauna_catalog.species.slice(0, 3), original.fauna_catalog.species), "Runtime replaced old species or measured bodies")
	_expect(_same(body.fauna_catalog.habitats, original.fauna_catalog.habitats), "Runtime rewrote existing habitat addresses/generations")
	_expect(_same(tree.root.get_node("ProgressionService").export_state(), legacy.saved.progression), "Migration changed existing discoveries or points")
	_expect(population.storage.record(legacy.plant_id, true).food.remaining == 2.0, "Upgrade reset harvested plant")
	var old_ids: Array = []
	for habitat: Dictionary in original.fauna_catalog.habitats:
		var id: String = Habitat.object_id(habitat)
		old_ids.append(id)
		_expect(population.storage.record(id).identity.species_id == habitat.species_id, "Upgrade replaced old individual identity")
	flow.resume()
	await _populate()
	flow.toggle_pause()
	body = state.get_current_body()
	_expect(_roles(population).size() == 4, "Four live roles did not appear: " + str(_roles(population)))
	var egg: Node3D
	for actor: Node3D in population.animals.values():
		if actor.catalog_species.get("group") == "eggs": egg = actor
	if egg == null: await _done(); return
	_expect(egg.is_on_floor() and Catalog.BodyEvidence.approved(Catalog.species_for(body.fauna_catalog, egg.catalog_species.id)), "Egg actor has no physical floor or approved body")
	var id: String = egg.get_campaign_identity().object_id
	var progression: Node = tree.root.get_node("ProgressionService")
	var discovery: Dictionary = progression.register_species_scan(egg.species_seed, egg.blueprint, state.world_seed)
	var points: int = progression.discovery_points
	progression.register_species_scan(egg.species_seed, egg.blueprint, state.world_seed)
	_expect(progression.discovery_points == points, "Repeated egg scan rewarded twice")
	var entry: Dictionary = progression.discovered_species[discovery.species_key]
	_expect(Suitability.read(entry, Traits).get("roles", []) == ["eggs"], "Scanned egg trait absent from shared book")
	var address: Dictionary = Space.encode(self, egg.global_position)
	var origin: Array = tree.current_scene.terrain.origin.duplicate()
	tree.current_scene.terrain.rebase([origin[0] + 110, origin[1] - 60, origin[2] + 35])
	_expect(Habitat.distance(address, Space.encode(self, egg.global_position), tree.current_scene.adapter.terrain.surface.body.radius) < 0.005, "Rebase moved egg individual")
	_expect(saves.save_now(), "Four-role save failed: " + saves.last_error)
	var checkpoint: Dictionary = saves._read_save(path)
	var old_scene: WeakRef = weakref(tree.current_scene)
	flow.return_to_title()
	await tree.scene_changed
	await tree.process_frame
	_expect(old_scene.get_ref() == null, "Old scene survived title transition")
	await _open(path, true)
	if not _expect_world(): await _done(); return
	_check_checkpoint(checkpoint)
	_expect(tree.current_scene.population.storage.record(id).identity.object_id == id, "Revisit lost egg identity")
	for old_id: String in old_ids: _expect(not tree.current_scene.population.storage.record(old_id).is_empty(), "Revisit lost old animal")
	flow.return_to_title()
	await tree.scene_changed
	_expect(Atomic.write("user://arch21-restart.json", {"path": path, "saved": checkpoint, "original_path": legacy.path, "original_sha256": legacy.source_sha256}, false) == OK, "Restart evidence failed")
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/egg_species_campaign_test.gd", "--", "--arch21-restart"]
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	_expect(code == 0 and str(output).contains("ARCH21_FRESH_PROCESS_PASSED"), "Fresh process failed: " + str(output))
	# A future primary must never silently load its valid older backup.
	var protected_path: String = saves.duplicate_slot(path, "ARCH21 future-version guard")
	_expect(not protected_path.is_empty(), "Cannot prepare protected slot")
	if not protected_path.is_empty():
		var valid: Dictionary = saves._read_save(protected_path)
		Atomic.write(protected_path + ".bak", valid, false)
		var future: Dictionary = valid.duplicate(true)
		Registry.active(future.game_state).fauna_catalog.role_policy = 99
		Atomic.write(protected_path, future, false)
		var primary: String = FileAccess.get_file_as_string(protected_path)
		var backup: String = FileAccess.get_file_as_string(protected_path + ".bak")
		_expect(not saves.select_slot(protected_path) and not saves.save_now(protected_path), "Future role policy fell back or was overwritten")
		_expect(FileAccess.get_file_as_string(protected_path) == primary and FileAccess.get_file_as_string(protected_path + ".bak") == backup, "Future primary or backup changed")
	_expect(FileAccess.get_file_as_string(legacy.path).sha256_text() == legacy.source_sha256, "Old original changed")
	metrics = {"roles": 4, "old_individuals_retained": old_ids.size(), "egg_id": id, "source": legacy.source,
		"revisit": true, "fresh_process": code == 0, "future_policy_protected": true}
	await _done()

func _extract_fixture() -> void:
	var zip := ZIPReader.new()
	if zip.open("res://tests/fixtures/egg_species_campaign_legacy.zip") != OK:
		_expect(false, "Missing genuine old campaign fixture"); return
	for name in zip.get_files():
		if name.ends_with("/"): continue
		if name.is_absolute_path() or ".." in name.split("/"):
			_expect(false, "Unsafe fixture member"); continue
		var destination: String = "user://".path_join(name)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null: _expect(false, "Fixture could not be written"); continue
		file.store_buffer(zip.read_file(name)); file.close()
	zip.close()
func _roles(population: Node) -> Dictionary:
	var roles: Dictionary = {}
	for actor: Node in population.animals.values():
		if not actor.catalog_species.is_empty(): roles[actor.catalog_species.group] = true
	return roles
func _populate() -> void:
	var deadline: int = Time.get_ticks_msec() + 35000
	while _roles(tree.current_scene.population).size() < 4 and Time.get_ticks_msec() < deadline: await tree.process_frame
	for tick in range(60): await tree.physics_frame
func _check_checkpoint(saved: Dictionary) -> void:
	var body: Dictionary = Registry.active(saved.game_state)
	_expect(_same(state.get_current_body().fauna_catalog, body.fauna_catalog), "Revisit/restart changed frozen species, evidence or habitats")
	_expect(_same(tree.root.get_node("ProgressionService").export_state(), saved.progression), "Revisit/restart changed discoveries or rewards")
	_expect(state.campaign.data.id == saved.game_state.campaign.id and state.active_body_id == body.id, "Revisit/restart changed campaign or body")
func _same(a: Variant, b: Variant) -> bool: return Migration.fingerprint(a) == Migration.fingerprint(b)
func _done() -> void:
	metrics.failures = failures
	print("ARCH21_CAMPAIGN ", JSON.stringify(metrics))
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
