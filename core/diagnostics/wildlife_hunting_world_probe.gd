extends "res://core/diagnostics/spherical_creature_probe.gd"
## Normal spherical entry, generated identities, real ground/movement and the
## region archive. Stages a corpse and a hungry scavenger on loaded dry terrain.
const Model = preload("res://world/surface/campaign_population_state.gd")
var observations: Dictionary = {}

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--hunting-world-restart" in OS.get_cmdline_user_args():
		await _restart_hunting()
		await _finish()
		return
	var path: String = saves.create_slot("Jagd und Aas auf der Kugel", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var population: Node = scene.population
	population.set_process(false)
	scene.player.set_physics_process(false)
	# Exclude player combat while observing the animal's physical meal.
	scene.player.is_dead = true
	for actor: Node in tree.get_nodes_in_group(&"wildlife"): actor.set_physics_process(false)
	var records: Dictionary = {}
	# Use the production generator in nearby cells, retaining actual IDs/bodies.
	for distance in range(0, 1025, 128):
		var center: Dictionary = scene.adapter.offset(scene.player.location(), scene.adapter.frame_at(scene.player.location()).x * distance)
		var cells: Dictionary = Model.Cells.nearby(population.descriptor, center)
		for cell: Dictionary in cells.values():
			population._generate(cell)
			for record: Dictionary in population.storage.region(cell.id).objects.values():
				if record.get("catalog_species_id", "").is_empty() and not records.has(record.role): records[record.role] = record
		if records.has("scavenger") and records.has("grazer"): break
	_expect(records.has("scavenger") and records.has("grazer"), "Generated region set lacks scavenger/prey roles")
	if not records.has("scavenger") or not records.has("grazer"): await _finish(); return
	var eater: CharacterBody3D = await _stage(scene, records.scavenger, 4.0)
	var food: CharacterBody3D = await _stage(scene, records.grazer, 8.0)
	if eater == null or food == null: await _finish(); return
	food.receive_creature_attack(999.0, null)
	food.carcass_food_remaining = 35.0
	_expect(food.get_node("SocialBehavior").store_carcass(), "Spherical corpse could not save")
	eater.current_health = eater.maximum_health
	eater.satiety = 30.0
	eater._needs.satiety = 30.0
	eater._needs.seeking = true
	eater.hydration = 90.0
	eater._drinking.hydration = 90.0
	eater._drinking.seeking = false
	eater._ambient_heading = Vector3.ZERO
	eater._decision_timer = 1000.0
	var local: Vector3 = eater.global_basis.inverse() * (food.global_position - eater.global_position)
	eater._visual_root.rotation.y = atan2(-local.x, -local.z)
	var origin: Vector3 = eater.global_position
	var id: String = eater.get_campaign_identity().object_id
	var food_id: String = food.get_campaign_identity().object_id
	eater.set_physics_process(true)
	await _until(func() -> bool: return eater.satiety > 39.0, 16000)
	eater.set_physics_process(false)
	_expect(eater.satiety > 39.0 and eater.global_position.distance_to(origin) > 0.5 and eater.is_on_floor(), "Scavenger failed to reach/eat on radial ground: " + str(eater.get_ai_debug_state()))
	_expect(food.is_dead and food.carcass_food_remaining < 35.0, "Spherical meal created nutrition without consuming carcass")
	observations.meal = {"moved": eater.global_position.distance_to(origin), "satiety": eater.satiety, "food": food.carcass_food_remaining, "up": str(eater.up_direction)}
	# A failed archive publication must not award nutrition or alter either live
	# needs reference. A second animal verifies the no-event rollback contract.
	var before_food: float = food.carcass_food_remaining
	var before_satiety: float = eater.satiety
	eater._sense()
	saves.save_path = "user://unavailable_hunt_world/failure.json"
	_expect(not eater._consume_carcass(), "Spherical I/O failure committed a meal")
	saves.save_path = path
	_expect(eater.satiety == before_satiety and food.carcass_food_remaining == before_food, "Spherical failed meal did not roll back")
	food._needs.satiety = 81.0
	_expect(population.needs(food_id, "foraging", 0.0).satiety == 81.0, "Failed no-event save detached another live needs reference")
	_expect(saves.save_now(), "Regional meal checkpoint failed: " + saves.last_error)
	var expected := {"path": path, "eater": id, "food": food_id, "satiety": eater.satiety, "remaining": food.carcass_food_remaining, "role": records.scavenger.role, "blueprint": records.scavenger.blueprint}
	_expect(Atomic.write("user://hunting_world_restart.json", expected, false) == OK, "Cannot write restart expectations")
	# Unload and respawn through the production population, preserving the same
	# frozen body and object IDs instead of introducing a separate carcass owner.
	population._capture_one(id)
	population._capture_one(food_id)
	population._remove(population.animals, id)
	population._remove(population.animals, food_id)
	await tree.physics_frame
	await tree.process_frame
	_expect(population._spawn_animal(population.storage.record(id)), "Eater could not return after unload")
	_expect(population._spawn_animal(population.storage.record(food_id)), "Carcass could not return after unload")
	if population.animals.has(id) and population.animals.has(food_id):
		var returned: Node = population.animals[id]
		var carcass: Node = population.animals[food_id]
		returned.set_physics_process(false)
		carcass.set_physics_process(false)
		_expect(returned.satiety == expected.satiety and returned._hunt_target == null, "Unload reset needs or retained a scene target")
		_expect(carcass.is_dead and carcass.carcass_food_remaining == expected.remaining, "Unload resurrected/replenished food")
	flow.return_to_title()
	await tree.scene_changed
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/wildlife_hunting_world_test.gd", "--", "--hunting-world-restart"], output, true)
	_expect(code == 0 and "".join(output).contains('"passed":true'), "Spherical fresh process failed: " + str(output))
	observations.restart_exit = code
	await _finish()

func _stage(scene: Node3D, record: Dictionary, offset: float) -> CharacterBody3D:
	var population: Node = scene.population
	if population.animals.has(record.id): population._remove(population.animals, record.id)
	var point: Dictionary = scene.adapter.offset(scene.player.location(), scene.adapter.frame_at(scene.player.location()).x * offset)
	await _until(func() -> bool: return Space.ground_ready(self, Space.resolve(self, point)), 12000)
	await tree.physics_frame
	await tree.physics_frame
	# The fixed 4/8 m points may contain streamed trees, rocks or another actor.
	# Find a nearby dry, loaded spot through the production clearance query;
	# retain collisions and the generated animal's identity and frozen body.
	var frame: Basis = scene.adapter.frame_at(scene.player.location())
	var found: bool = false
	for shift: Vector2 in [Vector2.ZERO, Vector2(0, 1.5), Vector2(0, -1.5), Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(1.5, 1.5), Vector2(-1.5, -1.5), Vector2(0, 3), Vector2(0, -3), Vector2(3, 0), Vector2(-3, 0)]:
		var candidate: Dictionary = scene.adapter.offset(scene.player.location(), frame.x * (offset + shift.x) + frame.z * shift.y)
		var sample: Dictionary = scene.adapter.sample(candidate)
		candidate.height = sample.height + 0.03
		candidate.radius = population.descriptor.radius
		if sample.water or not population._spawn_position(Space.resolve(self, candidate)).is_finite(): continue
		point = candidate
		found = true
		break
	if not found:
		_expect(false, "No clear dry staging point on loaded radial terrain")
		return null
	population.storage.move(record, point)
	record.home = point.duplicate(true)
	_expect(population._spawn_animal(record), "Generated identity could not spawn on loaded radial terrain")
	var actor: CharacterBody3D = population.animals.get(record.id)
	if actor != null: actor.set_physics_process(false)
	return actor

func _restart_hunting() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://hunting_world_restart.json"))
	await _open(expected.path, true)
	if not _expect_world(): return
	var population: Node = tree.current_scene.population
	var eater: Dictionary = population.storage.record(expected.eater)
	var food: Dictionary = population.storage.record(expected.food)
	_expect(not eater.is_empty() and not food.is_empty(), "Fresh process lost region identities")
	if eater.is_empty() or food.is_empty(): return
	_expect(eater.role == expected.role and Atomic.stringify(eater.blueprint) == Atomic.stringify(expected.blueprint), "Fresh process regenerated role or body")
	_expect(population.needs(expected.eater, "foraging", 0.0).satiety == expected.satiety, "Fresh process reset hunger")
	_expect(food.encounter.dead and food.encounter.carcass_food == expected.remaining, "Fresh process resurrected or replenished prey")
	flow.resume()
	flow.return_to_title()
	await tree.scene_changed

func _finish() -> void:
	tree.paused = false
	print(JSON.stringify({"test": "wildlife_hunting_world", "passed": failures.is_empty(), "observations": observations, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
