extends "tribal_age_test.gd"
const Housing = preload("res://world/tribe/village_housing.gd")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	Engine.time_scale = 3.0
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	home.establish_home()
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _frames(15)
	# Genuine pre-collision schema 3: a waiting resident saved in a hut wall.
	var old: Dictionary = tribe.village().duplicate(true)
	old["schema"] = 3
	old.erase("housing")
	old["tools"] = 1
	old["huts"] = 1
	for member: Dictionary in old["members"]:
		for field: String in ["species_id", "faction_id", "construction_id"]:
			member.erase(field)
	var trapped: Vector3 = Model.Home.vector(old["sites"][0]) + Vector3(1, 0, 0)
	old["members"][1]["position"] = Model.Home.vector_array(trapped)
	var identity: String = old["members"][1]["id"]
	tribe.body()["tribe"] = old
	paused = true
	_expect(saves.save_now() and saves.load_now(), "Old decorative hut could not migrate.")
	paused = false
	await _frames(10)
	_expect(tribe.actors[identity].global_position.distance_to(trapped) < 0.15, "Migration teleported the old resident.")
	_expect(tribe._shelters.get_child(0).collision_layer == 0, "Migration inserted a solid wall through a resident.")
	tribe.select_member(identity)
	_expect(tribe.issue_order("move", tribe.anchor()), "Migrated resident could not leave through the entrance.")
	var previous: Vector3 = tribe.actors[identity].global_position
	for frame in range(500):
		await _frames(1)
		var current: Vector3 = tribe.actors[identity].global_position
		_expect(current.distance_to(previous) < 0.8, "Resident teleported during collision recovery.")
		previous = current
		if current.distance_to(tribe.anchor()) < 0.8:
			break
	_expect(tribe.actors[identity].global_position.distance_to(tribe.anchor()) < 0.8 and tribe._shelters.get_child(0).collision_layer == 1, "Old resident could not leave or walls never became solid.")
	# A durable D3 pickup may not be buried under a new home.
	var data: Dictionary = tribe.village()
	data["stock"]["wood"] = 12
	data["stock"]["stone"] = 6
	data["deposits"]["wood"]["remaining"] = 0
	data["deposits"]["stone"]["remaining"] = 0
	var batch: Dictionary = {"schema": 1, "source_id": "d3-protected-pickup", "body_id": data["body_id"], "faction_id": data["faction_id"], "sequence": 1, "amount": 2, "position": [0, 100.06, 7]}
	_expect(tribe.receive_milk(batch), "D3 pickup fixture rejected.")
	var before: Dictionary = tribe.village().duplicate(true)
	_expect(not tribe.issue_order("hut", Vector3(0, 100.06, 7)) and tribe.village() == before, "Housing covered accepted milk or charged an invalid site.")
	# Ready growth must commit before an actor is created or supplies disappear.
	data = tribe.village()
	data["huts"] = 3
	data["housing"]["homes"].append(Housing.site(data, "hut", [9, 100.06, 0], 1))
	data["housing"]["homes"].append(Housing.site(data, "hut", [-5, 100.06, 8], 2))
	data["garden"] = 1
	data["stock"]["food"] = 12
	data["deposits"]["food"]["remaining"] = 0
	data["stock"]["water"] = 12
	data["economy"]["produced"]["water"] = 12
	data["deposits"]["water"]["position"] = [0, 100.06, -7]
	data["economy"]["stations"]["well"] = {"id": Model.Ids.scoped("workplace", data["id"], "well"), "position": [0, 100.06, -7]}
	for member: Dictionary in data["members"]:
		member["hunger"] = 75.0
		member["hydration"] = 100.0
	data["housing"]["clock"] = Housing.GROW_SECONDS
	tribe._shelters.sync(data, tribe.actors)
	tribe.navigation.rebuild(home, tribe.anchor(), data)
	var blocked_file: FileAccess = FileAccess.open("user://growth-save-failure", FileAccess.WRITE)
	blocked_file.store_string("not a directory")
	blocked_file.close()
	saves.save_path = "user://growth-save-failure/save.json"
	before = data.duplicate(true)
	tribe._grow_residents(0.01)
	_expect(tribe.actors.size() == 3 and tribe.village() == before, "Failed birth save changed residents, timer or supplies.")
	saves.save_path = SAVE
	tribe._grow_residents(1.0)
	_expect(tribe.actors.size() == 3, "Failed birth save retried without its backoff.")
	tribe._grow_residents(5.0)
	_expect(tribe.actors.size() == 4 and int(tribe.village()["stock"]["food"]) == 10 and int(tribe.village()["stock"]["water"]) == 10, "Successful retry did not create exactly one paid resident.")
	paused = true
	_expect(saves.load_now() and tribe.village()["members"].size() == 4, "Resident was visible before being durable.")
	paused = false
	await _frames(15)
	_expect(tribe.actors.size() == 4, "Reload duplicated recovered resident.")
	print(JSON.stringify({"test": "tribal_age_housing_recovery", "passed": failures.is_empty(), "failures": failures}))
	await _cleanup()
	_finish()
