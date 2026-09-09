extends "tribal_age_test.gd"
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
var progression: Node
var evidence: Dictionary = {}

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	progression = root.get_node("ProgressionService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	if "--verify-neighbors" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process cannot load neighbor snapshot")
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://neighbors_expected.json"))
		var actual: Dictionary = {"village": state.get_current_body()["tribe"], "neighbor": state.get_current_body()["tribal_neighbor"], "progression": progression.export_state()["tribal"]}
		_expect(JSON.parse_string(JSON.stringify(actual)) == expected, "Cold restart lost people, cargo, receipts or granted offline work")
		_finish()
		return
	Engine.time_scale = 3.0
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home()["ok"], "Cannot establish home fixture")
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _frames(15)
	if not tribe.is_active():
		_expect(false, "Cannot enter actual tribal gameplay")
		await _cleanup()
		_finish()
		return
	var ids: Array = tribe.village()["members"].map(func(m: Dictionary) -> String: return m["id"])
	# Previously gathered materials are the scenario setup, not aid receipts.
	for kind: String in ["food", "wood"]:
		tribe.village()["stock"][kind] = 18
		tribe.village()["deposits"][kind]["remaining"] -= 18
	tribe.body()["animal_retention_fixture"] = {"id": "pet-original", "species_id": "foreign-animal-species", "owner": state.campaign.data["player_faction_id"], "trust": 0.6, "order": "home"}
	var animal: Dictionary = tribe.body()["animal_retention_fixture"].duplicate(true)
	tribe.panel._tabs.current_tab = 2
	await _frames(5)
	var before: Dictionary = state.campaign.export_state()
	tribe.panel._neighbors.refresh()
	progression.get_development_path()
	_expect(state.campaign.export_state() == before and not tribe.body().has("tribal_neighbor"), "Viewing a page spawned a faction")
	saves.save_path = "user://missing-neighbor-parent/save.json"
	_expect(not tribe.neighbors.contact() and not tribe.body().has("tribal_neighbor") and tribe.neighbors.actors.is_empty(), "Failed save installed a half-faction")
	saves.save_path = SAVE
	await _click(tribe.panel._neighbors.contact_button)
	await _frames(5)
	_expect(not _neighbor().is_empty(), "No reachable neighbor was created: " + tribe.status)
	if _neighbor().is_empty():
		await _cleanup()
		_finish()
		return
	_expect(_neighbor()["species_id"] == state.campaign.data["player_species_id"] and _neighbor()["id"] != state.campaign.data["player_faction_id"], "Neighbor changed species or reused the player faction")
	_expect(tribe.actors.size() == 3 and tribe.neighbors.actors.size() == 2, "Contact duplicated own citizens or omitted neighbor residents")
	_expect(not tribe.neighbors.contact() and tribe.neighbors.actors.size() == 2, "Repeated contact created a second faction")
	_expect(tribe.navigation.route(tribe.anchor(), Model.Home.vector(_neighbor()["anchor"])).size() > 1, "Neighbor has no physical route")
	_select_pair(ids[0], ids[1])
	before = {"village": tribe.village().duplicate(true), "neighbor": _neighbor().duplicate(true)}
	saves.save_path = "user://missing-neighbor-parent/save.json"
	_expect(not tribe.neighbors.start_aid(), "Failed aid save reported success")
	_expect(tribe.village() == before["village"] and _neighbor() == before["neighbor"], "Failed aid command changed costs, cargo or orders")
	saves.save_path = SAVE
	await _click(tribe.panel._neighbors.aid_button)
	await _until(func() -> bool: return tribe.member_record(ids[0])["cargo"] != "", 700)
	_expect(tribe.member_record(ids[0])["cargo"] != "", "Carrier never physically picked up home stock")
	_expect(int(_neighbor()["aid"]["received"]["food"]) == 0 and progression.get_behavior_wallet(1)["earned"]["social"] == 0, "Pickup completed help or paid points")
	tribe.select_member(ids[0])
	_expect(tribe.issue_order("wait"), "Cannot pause aid carrier")
	paused = true
	var frozen: Dictionary = _neighbor().duplicate(true)
	var cargo: String = tribe.member_record(ids[0])["cargo"]
	await _frames(20)
	_expect(_neighbor() == frozen, "Global pause advanced neighbors or aid")
	await _cold_restart()
	_expect(saves.load_now(), "Cannot resume paused carrier snapshot")
	paused = false
	await _frames(15)
	_expect(tribe.member_record(ids[0])["cargo"] == cargo and tribe.member_record(ids[0])["order"] == "wait", "Paused cargo moved or vanished on load")
	# A different command returns carried aid; it is not new gathered material.
	tribe.select_member(ids[0])
	var gathered: int = tribe.village()["delivered"]
	_expect(tribe.issue_order("wood"), "Cannot replace aid with a regular job")
	await _until(func() -> bool: return int(_neighbor()["aid"]["returned"][cargo]) == 1, 700)
	_expect(int(_neighbor()["aid"]["returned"][cargo]) == 1 and tribe.member_record(ids[0])["cargo"] == "", "Cancelled aid was not physically returned")
	_expect(tribe.village()["delivered"] == gathered and progression.get_behavior_wallet(1)["earned"]["social"] == 0, "Returned own stock farmed gathering or tribal rewards")
	tribe.issue_order("wait")
	_select_pair(ids[0], ids[2])
	_expect(tribe.neighbors.start_aid(), "Available residents cannot take over the remaining help")
	await _until(func() -> bool: return tribe.member_record(ids[0])["cargo"] != "", 500)
	tribe.select_member(ids[0])
	tribe.issue_order("wait")
	var location: Vector3 = tribe.actors[ids[0]].global_position
	var obstacle: StaticBody3D = _box(Vector3(4, 3, 4), location + Vector3(0, 1.5, 0))
	await _frames(5)
	tribe.issue_order("resume")
	await _until(func() -> bool: return tribe.member_record(ids[0])["blocked"], 240)
	_expect(tribe.member_record(ids[0])["blocked"] and tribe.member_record(ids[0])["cargo"] != "", "Obstructed aid was delivered or lost remotely")
	obstacle.queue_free()
	await _frames(5)
	await _until(func() -> bool: return _neighbor()["aid"]["status"] == "building", 2200)
	_expect(_neighbor()["aid"]["status"] == "building", "Real aid did not reach neighbor stock: " + str(_neighbor()["aid"]))
	paused = true
	_expect(saves.save_now() and saves.load_now(), "Partial neighbor construction cannot save/load")
	paused = false
	await _frames(15)
	await _until(func() -> bool: return _neighbor()["aid"]["status"] == "completed", 650)
	_expect(_neighbor()["aid"]["status"] == "completed" and _neighbor()["relation"] == "friendly" and _neighbor()["stock"]["wood"] == 0 and _neighbor()["technology"]["shelter"] == 1, "Neighbors did not build the supplied shelter")
	_expect(progression.get_behavior_wallet(1)["earned"]["social"] == 3, "Actual help did not earn exactly three separate tribal points")
	_expect(tribe.village()["members"].map(func(m: Dictionary) -> String: return m["id"]) == ids and tribe.body()["animal_retention_fixture"] == JSON.parse_string(JSON.stringify(animal)), "Own residents or foreign animal changed")
	var view: Dictionary = progression.get_development_path()
	for epoch: Dictionary in view["epochs"]:
		_expect(not epoch["available"], "Neighbor completion unlocked an unimplemented era")
		if epoch["target"] == 2:
			for requirement: Dictionary in epoch["requirements"]:
				if requirement["id"] == "neighbors":
					_expect(requirement["supported"] and requirement["met"], "Development view misses the completed aid prerequisite")
	paused = true
	await _cold_restart()
	for repeat in range(3):
		_expect(saves.load_now() and progression.get_behavior_wallet(1)["earned"]["social"] == 3, "Repeated load repaid aid")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var copy: String = saves._write_slot_copy(source, "Nachbarhilfe Kopie", "copy")
	_expect(not copy.is_empty(), "Campaign copy cannot preserve neighbor help")
	var future: Dictionary = source.duplicate(true)
	future["game_state"]["campaign"]["bodies"]["15838"]["tribal_neighbor"]["schema"] += 1
	_expect(saves._has_unsupported_contract(future), "Future neighbor contract has no overwrite protection")
	var foreign: Dictionary = source.duplicate(true)
	foreign["game_state"]["campaign"]["bodies"]["15838"]["tribal_neighbor"]["species_id"] = "wild-species"
	_expect(not saves._validate_save(foreign).is_empty(), "Foreign wild species can become a saved civilization")
	var forged: Dictionary = source.duplicate(true)
	forged["game_state"]["campaign"]["bodies"]["15838"].erase("tribal_neighbor")
	_expect(not saves._validate_save(forged).is_empty(), "Points accepted without the completed neighbor agreement")
	evidence = {"aid": _neighbor()["aid"].duplicate(true), "neighbor_stock": _neighbor()["stock"].duplicate(), "wallet": progression.get_behavior_wallet(1)}
	paused = false
	root.size = Vector2i(800, 900)
	tribe.panel._tabs.current_tab = 2
	await _frames(10)
	for button: Button in [tribe.panel._neighbors.focus_button, tribe.panel._neighbors.home_button]:
		var rect: Rect2 = button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
		_expect(root.get_visible_rect().encloses(rect), "Neighbor control outside narrow viewport")
	await _click(tribe.panel._neighbors.focus_button)
	await _frames(2)
	var look: Vector3 = tribe._focus - Neighbor.Home.vector(_neighbor()["anchor"])
	look.y = 0
	_expect(look.length() < 0.1, "Neighbor camera button does not reach its camp")
	await _click(tribe.panel._neighbors.home_button)
	await _frames(2)
	_expect(tribe._focus.distance_to(tribe.anchor()) < 0.1, "Home camera button does not return to own village")
	state.start_world_with_seed(15838)
	await _frames(10)
	_expect(not state.get_current_body().has("tribal_neighbor") and tribe.neighbors.actors.is_empty(), "New campaign retained the old neighbor runtime")
	await _cleanup()
	_finish()

func _neighbor() -> Dictionary:
	return tribe.body().get("tribal_neighbor", {})

func _select_pair(first: String, second: String) -> void:
	tribe.select_member(first)
	tribe.select_member(second, true)

func _cold_restart() -> void:
	_expect(saves.save_now(), "Cannot save neighbor and courier state")
	var expected: Dictionary = {"village": tribe.village(), "neighbor": _neighbor(), "progression": progression.export_state()["tribal"]}
	var file: FileAccess = FileAccess.open("user://neighbors_expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()
	var output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/tribal_neighbors_world_test.gd", "--", "--verify-neighbors"], output, true)
	_expect(result == 0 and not str(output).contains("SCRIPT ERROR"), "Fresh neighbor process failed: " + str(output))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("NEIGHBOR CHECK FAILED: ", message)

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_neighbors_world", "passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
