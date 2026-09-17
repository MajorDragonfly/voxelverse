extends "res://core/diagnostics/spherical_campaign_probe.gd"
const Space = preload("res://world/surface/gameplay_space.gd")

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("Lebendige Kreaturen", 15838, Cube.MODE)
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
	_expect(population.animals.size() <= population.MAX_ANIMALS and population.nests.size() <= population.MAX_NESTS, "Family generation exceeded live simulation budgets")
	for nest: Node3D in population.nests.values():
		_expect(not nest.is_in_group(&"player_nest") and not nest.has_node("HomeGroup"), "Wild nest claimed player respawn/group ownership")
		_expect(nest.global_basis.y.dot(Space.up(self, nest.global_position)) > 0.99, "Nest is not aligned to the spherical surface")
		var ground: Dictionary = Space.floor_hit(scene.player, nest.global_position)
		if not ground.is_empty(): _expect(nest.global_position.distance_to(ground.position) < 0.12, "Wild nest is floating above the ground")
	var counts: Dictionary = {}
	for nest: Node3D in population.nests.values(): counts[nest.colony.id] = nest.colony.members.duplicate()
	_expect(saves.save_now(), "Real populated world could not save: " + saves.last_error)
	# Origin changes are presentation changes, never canonical nest relocation.
	var before: Dictionary = {}
	for id: String in population.nests: before[id] = Space.encode(self, population.nests[id].global_position)
	var origin: Array = scene.terrain.origin.duplicate()
	scene.terrain.rebase([origin[0] + 32.0, origin[1] - 12.0, origin[2] + 24.0])
	for id: String in before:
		var after: Dictionary = Space.encode(self, population.nests[id].global_position)
		_expect(preload("res://world/home_group/home_group_state.gd").distance(before[id], after) < 0.02, "Origin shift moved a nest on the planet")
	flow.return_to_title()
	await tree.scene_changed
	await _open(path)
	if _expect_world():
		population = tree.current_scene.population
		await _until(func() -> bool: return not population.nests.is_empty(), 20000)
		for nest: Node3D in population.nests.values():
			if counts.has(nest.colony.id): _expect(counts[nest.colony.id] == nest.colony.members, "World reload changed nest identities")
		flow.return_to_title()
		await tree.scene_changed
	await _finish()

func _until(predicate: Callable, milliseconds: int) -> void:
	var started: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - started < milliseconds:
		await tree.process_frame

func _finish() -> void:
	tree.paused = false
	print(JSON.stringify({"test": "living_creatures_world", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
