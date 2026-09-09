extends "res://tests/tribal_age_test.gd"
const AnimalState = preload("res://world/domestication/animal_state.gd")
const AnimalSave = preload("res://world/domestication/campaign_animal_state.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
const TamingPolicy = preload("res://world/domestication/d1_taming_policy.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var d2: Node
var animal_id: String
var source_identity: Dictionary
var source_body: Dictionary
var observations: Dictionary = {}
var assertions: int = 0
var campaign_save: String = "user://d2-campaign.json"
var proof_path: String = "user://d2-campaign-proof.json"

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = campaign_save
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--d2-campaign-read" in args:
		campaign_save = args[args.find("--d2-campaign-read") + 1]
		proof_path = args[args.find("--d2-campaign-read") + 2]
		saves.save_path = campaign_save
		await _restart()
		return
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	d2 = tribe.get_node("Domestication")
	await _frames(25)
	_expect(not d2.offer("missing")["ok"], "Phase 0 allowed taming")
	_expect(home.establish_home()["ok"], "Could not establish actual home")
	await _frames(15)
	var catalog: Dictionary = Catalog.ensure(state)
	var species: Dictionary = catalog["species"][0]
	var fauna: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	fauna.configure(species["species_seed"], 781, Vector2i.ZERO, species["role"], "d2-campaign-fixture", species)
	scene.add_child(fauna)
	fauna.position = Vector3(3, 100.03, 0)
	fauna.set_physics_process(false)
	source_identity = fauna.get_campaign_identity()
	source_body = Contract.encode(fauna.blueprint)
	animal_id = source_identity["object_id"]
	var progression: Node = root.get_node("ProgressionService")
	var friend: Dictionary = fauna.get_node("SocialBehavior").entry()
	friend["relation"] = "ally"
	friend["trust"] = 100.0
	_expect(progression.store_creature_encounter(friend)["ok"], "Cannot prepare existing friendship")
	var friends_before: Dictionary = progression.get_saved_creature_encounter(animal_id)
	tribe.panel.open_confirmation()
	_expect(not tribe.panel.confirm.disabled, "Tribal confirmation blocked")
	tribe.panel._confirm()
	await _frames(25)
	_expect(tribe.is_active() and d2.is_active(), "D2 did not attach to the confirmed real tribe")
	if not d2.is_active():
		await _done()
		return
	var player_health: float = player.current_health
	fauna._try_predator_attack(player)
	_expect(player.current_health == player_health, "Legacy predator attack damaged phase-1 group cursor")
	fauna.receive_creature_attack(5.0)
	_expect(progression.get_saved_creature_encounter(animal_id)["health_ratio"] == fauna.get_health_ratio(), "Phase-1 fauna damage was not persisted")
	# Let fear expire before offering; no relationship reward or rewrite is allowed.
	fauna._threat_timer = 0.0
	var members_before: Array = tribe.village()["members"].map(func(m: Dictionary): return m["id"])
	# Put REAL harvested stock into the shared village, preserving conservation.
	tribe.village()["deposits"]["food"]["remaining"] -= 12
	tribe.village()["stock"]["food"] = 12
	tribe.select_member(members_before[0])
	_expect(d2.controller.owned_animals(state.campaign.data["player_faction_id"]).is_empty(), "Friendship became ownership")
	var invalid_parent := FileAccess.open("user://d2-blocked-parent", FileAccess.WRITE)
	invalid_parent.store_string("sentinel")
	invalid_parent.close()
	saves.save_path = "user://d2-blocked-parent/save.json"
	_expect(not d2.offer(animal_id)["ok"], "Failed first adoption was accepted")
	_expect(not tribe.body().has(AnimalSave.FIELD) and d2.animals.is_empty() and tribe.village()["stock"]["food"] == 12, "Failed adoption changed body, actors or food")
	saves.save_path = campaign_save
	var tabs: TabBar = tribe.panel._tabs.get_tab_bar()
	var tab_index: int = d2.controls.get_index()
	await _world_click(tabs.get_global_transform_with_canvas() * tabs.get_tab_rect(tab_index).get_center(), MOUSE_BUTTON_LEFT)
	await _frames(18)
	_expect(d2.controls.visible and d2.controls.selected_id() == animal_id, "Existing HUD did not open the actual animal controls")
	await _click(d2.controls.buttons["offer"])
	_expect(d2.controller.last_result["ok"], "Cannot offer D1 animal food through HUD: " + d2.status)
	await _frames(25)
	_expect(d2.animals.has(animal_id) and not d2.controller.record(animal_id)["pending"].is_empty(), "Animal not transferred during offering")
	if d2.controller.record(animal_id)["pending"].is_empty():
		print({"record": d2.controller.record(animal_id), "context": d2.context(animal_id, members_before[0]), "last": d2.controller.last_result})
		await _done()
		return
	_expect(JSON.stringify(Contract.encode(d2.animals[animal_id].blueprint)) == JSON.stringify(source_body), "Adoption regenerated body")
	_expect(d2.controller.record(animal_id)["design_ref"]["revision"] == source_identity["design_ref"]["revision"], "Adoption invented a body revision")
	var damaged: Dictionary = tribe.body().duplicate(true)
	damaged[AnimalSave.FIELD]["sources"][animal_id]["blueprint"]["species"]["id"] = "another_species"
	_expect(not AnimalSave.validate_body(damaged, state.campaign.data).is_empty(), "Mismatched frozen species accepted")
	var streamer: Node3D = load("res://world/fauna/fauna_streamer_v7.gd").new()
	scene.add_child(streamer)
	streamer.set_process(false)
	_expect(streamer._has_active_identity(animal_id), "Streamer failed to reserve held object ID")
	var saved_partial: float = d2.controller.record(animal_id)["pending"]["elapsed"]
	_expect(saves.save_now(), "Save partial campaign offering")
	_expect(saves.load_now(), "Load partial campaign offering")
	await _frames(4)
	_expect(d2.controller.record(animal_id)["pending"]["elapsed"] >= saved_partial, "Partial campaign offering lost progress")
	await _until(func(): return d2.controller.record(animal_id)["pending"].is_empty(), 150)
	var gain: float = TamingPolicy.evaluate(d2.resolve_suitability(source_identity["species_id"]), "plant")["trust_gain"]
	var meals: int = ceili(100.0 / gain)
	_expect(tribe.village()["stock"]["food"] == 11 and is_equal_approx(d2.controller.record(animal_id)["trust"], gain), "First meal did not consume exactly one shared unit or apply D1 trainability")
	for i in range(meals - 1):
		tribe.select_member(members_before[0])
		_expect(d2.offer(animal_id)["ok"], "Additional offer rejected: " + d2.status)
		await _until(func(): return d2.controller.record(animal_id)["pending"].is_empty(), 150)
	_expect(d2.controller.record(animal_id)["status"] == "tamed" and tribe.village()["stock"]["food"] == 12 - meals, "Campaign did not tame at exact cost")
	_expect(animal_id in tribe.husbandry.candidates(), "D3 cannot read the actually tamed D1 milktier")
	var live_source: Dictionary = tribe.husbandry.source.read(tribe.village(), state.campaign.data["id"], animal_id)
	_expect(live_source.get("error") == "" and live_source.get("actor") == d2.animals[animal_id], "D3 resolved a different individual or unavailable source")
	_expect(tribe.village()["members"].map(func(m: Dictionary): return m["id"]) == members_before, "Taming created or replaced citizen")
	_expect(progression.get_saved_creature_encounter(animal_id)["trust"] == friends_before["trust"] and progression.get_saved_creature_encounter(animal_id)["relation"] == friends_before["relation"], "Taming rewrote friendship")
	tribe.select_member(members_before[0])
	_expect(d2.issue_command(animal_id, "follow")["ok"], "Cannot follow real tribe member")
	var before: Vector3 = d2.animals[animal_id].global_position
	_expect(tribe.issue_order("move", Vector3(8, 100.06, 4)), "Cannot move real handler")
	await _frames(160)
	observations["follow_m"] = before.distance_to(d2.animals[animal_id].global_position)
	# D1 fixes the animal's speed; let the real handler finish its route before
	# checking the final following distance, rather than requiring it to catch a moving equal-speed target.
	await _until(func(): return tribe.member_record(members_before[0])["order"] == "wait", 300)
	await _frames(40)
	observations["follow_gap_m"] = player.global_position.distance_to(d2.animals[animal_id].global_position)
	_expect(float(observations["follow_m"]) > 3 and float(observations["follow_gap_m"]) < 2.0, "Held animal did not follow the real moving member")
	_expect(d2.issue_command(animal_id, "wait")["ok"], "Cannot wait")
	before = d2.animals[animal_id].global_position
	tribe.issue_order("move", Vector3(4, 100.06, -4))
	await _frames(80)
	_expect(before.distance_to(d2.animals[animal_id].global_position) < 0.1, "Waiting animal followed changing handler")
	_expect(d2.issue_command(animal_id, "home")["ok"], "Cannot return home")
	before = d2.animals[animal_id].global_position
	await _frames(220)
	observations["home_travel_m"] = before.distance_to(d2.animals[animal_id].global_position)
	observations["home_gap_m"] = tribe.anchor().distance_to(d2.animals[animal_id].global_position)
	_expect(float(observations["home_gap_m"]) < 1.6 and float(observations["home_travel_m"]) > 3.0, "Held animal did not return to real home area")
	_expect(saves.save_now(), "Save held animal before process restart")
	var proof: Dictionary = {"id": animal_id, "identity": source_identity, "body": source_body, "members": members_before,
		"record": d2.controller.record(animal_id), "food": tribe.village()["stock"]["food"]}
	_expect(Atomic.write(proof_path, proof, false) == OK, "Cannot save restart assertions")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/domestication_campaign_test.gd", "--", "--d2-campaign-read", ProjectSettings.globalize_path(campaign_save), ProjectSettings.globalize_path(proof_path)], output, true)
	_expect(code == 0 and str(output).contains("D2_CAMPAIGN_PASS") and not str(output).contains("SCRIPT ERROR"), "Fresh-process campaign restore failed: " + str(output))
	# Validate invalid future animal payload before fallback to a valid backup.
	var snapshot: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(campaign_save))
	var future: Dictionary = snapshot.duplicate(true)
	future["game_state"]["campaign"]["bodies"]["15838"][AnimalSave.FIELD]["schema"] = 99
	Atomic.write("user://d2-campaign-future.json", future, false)
	Atomic.write("user://d2-campaign-future.json.bak", snapshot, false)
	_expect(not saves.load_now("user://d2-campaign-future.json") and not saves.save_now("user://d2-campaign-future.json"), "Future animal schema was downgraded or overwritten")
	_expect(saves.load_now(campaign_save), "Cannot return to supported campaign")
	await _done()

func _restart() -> void:
	_expect(saves.load_now(), "Fresh process could not load real campaign: " + saves.last_error)
	var proof: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(proof_path))
	animal_id = proof["id"]
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	d2 = tribe.get_node("Domestication")
	await _frames(25)
	_expect(d2.is_active() and d2.animals.has(animal_id), "Fresh process did not recreate held individual")
	_expect(animal_id in tribe.husbandry.candidates(), "Fresh process did not reconnect D3 to the loaded D2 animal")
	if not d2.animals.has(animal_id):
		await _done()
		return
	var a: Dictionary = d2.controller.record(animal_id)
	_expect(a["object_id"] == proof["id"] and a["species_id"] == proof["identity"]["species_id"] and a["owner_faction_id"] == state.campaign.data["player_faction_id"] and a["order"] == "home", "Restart lost identity, owner or command")
	_expect(tribe.village()["stock"]["food"] == proof["food"] and a["trust"] == 100, "Restart changed food or trust")
	_expect(AnimalState.vector(a["position"]).distance_to(AnimalState.vector(proof["record"]["position"])) < 0.15, "Restart lost animal position")
	_expect(JSON.stringify(Contract.encode(d2.animals[animal_id].blueprint)) == JSON.stringify(proof["body"]), "Restart regenerated animal body")
	_expect(tribe.village()["members"].map(func(m: Dictionary): return m["id"]) == proof["members"], "Restart changed citizens")
	tribe.select_member(proof["members"][0])
	var previous: Dictionary = d2.controller.record(animal_id)
	saves.save_path = "user://nonexistent-parent-file/blocked/save.json"
	var blocker := FileAccess.open("user://nonexistent-parent-file", FileAccess.WRITE)
	blocker.store_string("block")
	blocker.close()
	_expect(not d2.issue_command(animal_id, "follow")["ok"] and d2.controller.record(animal_id) == previous, "Failed command write changed order")
	saves.save_path = campaign_save
	_expect(d2.damage_animal(animal_id, 100), "Cannot persist death")
	_expect(saves.load_now(), "Cannot reload dead individual")
	await _frames(8)
	_expect(d2.controller.record(animal_id)["status"] == "dead" and d2.animals[animal_id].is_dead, "Dead individual revived")
	_expect(root.get_node("ProgressionService").get_saved_creature_encounter(animal_id)["dead"], "Fauna lifecycle lost D2 tombstone")
	_expect(not d2.issue_command(animal_id, "home")["ok"], "Dead individual accepted command")
	await _done()

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("D2_CAMPAIGN_FAIL: " + message)

func _done() -> void:
	print(JSON.stringify({"test": "domestication_campaign", "checks": assertions, "failures": failures, "measurements": observations}))
	print("D2_CAMPAIGN_PASS" if failures.is_empty() else "D2_CAMPAIGN_FAIL")
	if is_instance_valid(scene): scene.queue_free()
	await _frames(6)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
