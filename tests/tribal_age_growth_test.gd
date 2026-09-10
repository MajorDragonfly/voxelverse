extends "tribal_age_test.gd"
const Housing = preload("res://world/tribe/village_housing.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
var evidence: Dictionary = {}

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	Engine.time_scale = 3.0
	if "--restart-check" in args:
		await _restart()
		return
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home()["ok"], "Could not establish growth fixture.")
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	if not tribe.is_active():
		_expect(false, "Village entry failed: " + saves.last_error)
		await _cleanup()
		_finish()
		return
	# Prior work supplies a finite material budget and completed workstations.
	# All new housing materials and subsequent food/water still travel in runtime.
	var data: Dictionary = tribe.village()
	data["tools"] = 1
	data["garden"] = 1
	data["stock"]["wood"] = 24
	data["stock"]["stone"] = 12
	data["deposits"]["wood"]["remaining"] = 0
	data["deposits"]["stone"]["remaining"] = 0
	data["deposits"]["food"]["remaining"] = 24
	for kind: String in ["well", "fiberbed"]:
		var location: Array = [0, 100.06, -7] if kind == "well" else [-8, 100.06, 0]
		data["economy"]["stations"][kind] = {"id": Model.Ids.scoped("workplace", data["id"], kind), "position": location.duplicate()}
		data["deposits"][Economy.STATIONS[kind]]["position"] = location.duplicate()
	data["economy"]["produced"]["fiber"] = 4
	data["stock"]["fiber"] = 4
	var original_ids: Array = data["members"].map(func(m: Dictionary) -> String: return m["id"])
	_expect(saves.save_now() and saves.load_now(), "Prepared growth fixture did not load.")
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	tribe.select_all()
	var before: Dictionary = tribe.village().duplicate(true)
	_expect(not tribe.issue_order("hut", tribe.anchor()) and tribe.village() == before, "Overlapping housing charged materials.")
	var block: FileAccess = FileAccess.open("user://growth-blocked", FileAccess.WRITE)
	block.store_string("not a directory")
	block.close()
	saves.save_path = "user://growth-blocked/save.json"
	_expect(not tribe.issue_order("hut", Vector3(5, 100.06, 5)) and tribe.village() == before, "Failed housing save changed state.")
	saves.save_path = SAVE
	await _click(tribe.panel._buttons["hut"])
	_expect(tribe.placement == "hut" and not tribe.panel._hud_content.visible, "Housing button did not arm free placement.")
	await _world_click(tribe.camera.unproject_position(Vector3(5, 100.06, 5)), MOUSE_BUTTON_RIGHT)
	_expect(tribe.village()["project"].get("kind") == "hut", "Free hut placement failed: " + tribe.status)
	if tribe.village()["project"].is_empty():
		await _cleanup()
		_finish()
		return
	_expect(int(tribe.village()["stock"]["wood"]) == 18 and int(tribe.village()["stock"]["stone"]) == 9 and Housing.beds(tribe.village()) == 0, "Costs or unfinished sleeping places incorrect.")
	await _until(func() -> bool: return tribe.village()["members"].any(func(m: Dictionary) -> bool: return m["construction_id"] != "" and Model.Home.vector(m["position"]).distance_to(tribe.anchor()) > 3.2), 700)
	_expect(tribe.village()["members"].any(func(m: Dictionary) -> bool: return m["construction_id"] != ""), "No actual building material transport.")
	_expect(tribe.issue_order("wait"), "Building transport could not stop.")
	_key(KEY_SPACE)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(tribe.village()))
	_expect(saves.save_now() and saves.load_now(), "Building cargo failed Save/Load.")
	_expect(tribe.village() == saved, "Building cargo, cost or paused order changed on load.")
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	tribe.select_all()
	_expect(tribe.issue_order("resume"), "Building transport could not resume.")
	await _until(func() -> bool: return int(tribe.village()["huts"]) == 1, 1800)
	_expect(int(tribe.village()["huts"]) == 1, "Hut did not finish after physical deliveries: " + str(tribe.village()["project"]))
	if int(tribe.village()["huts"]) != 1:
		print(str(tribe.village()["members"]))
		await _cleanup()
		_finish()
		return
	await _until(func(): return not tribe.navigation.pending, 1200)
	var first: Dictionary = tribe.village()["housing"]["homes"][0]
	var center: Vector3 = Model.Home.vector(first["position"])
	var wall_ray := PhysicsRayQueryParameters3D.create(center + Vector3(-3, 1, 0), center + Vector3(0, 1, 0), 1)
	var door_ray := PhysicsRayQueryParameters3D.create(center + Vector3(0, 1, 3), center + Vector3(0, 1, 0), 1)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	_expect(not space.intersect_ray(wall_ray).is_empty(), "Completed hut has no physical wall.")
	_expect(space.intersect_ray(door_ray).is_empty(), "Visible entrance is physically closed.")
	_expect(tribe.navigation.route(tribe.anchor(), center).is_empty(), "Pathfinding crosses housing footprint.")
	var path: PackedVector3Array = tribe.navigation.route(center + Vector3(-4, 0, 0), center + Vector3(4, 0, 0))
	_expect(not path.is_empty(), "Housing cut off the surrounding route.")
	for point: Vector3 in path:
		_expect(not Housing.contains(first, point), "Route enters completed building.")
	var collider: Node = tribe._shelters.get_child(0)
	tribe._changed()
	await _frames(3)
	_expect(tribe._shelters.get_child(0) == collider, "Stock refresh replaced stable house collisions.")
	print("M6 growth: placed hut, hauled costs, stopped/reloaded/resumed, collision and entrance checked")
	await _build_home("hut", Vector3(9, 100.06, 1), 2)
	await _build_home("tent", Vector3(0, 100.06, 7), 3)
	await _build_home("tent", Vector3(6, 100.06, -8), 4)
	_expect(Housing.beds(tribe.village()) == 6 and tribe.actors.size() == 3, "Shelters granted residents without sustained supplies.")
	if Housing.beds(tribe.village()) != 6:
		await _cleanup()
		_finish()
		return
	print("M6 growth: four shelters completed, six beds, three original residents")
	tribe.select_all()
	_expect(tribe.assign_profession("provider"), "Original residents could not provide for growth.")
	await _until(func() -> bool: return Housing.growth_blocker(tribe.village()).is_empty(), 2000)
	_expect(Housing.growth_blocker(tribe.village()).is_empty(), "Physical supplies did not unlock growth.")
	await _until(func() -> bool: return float(tribe.village()["housing"]["clock"]) > 5, 300)
	_key(KEY_SPACE)
	var paused_snapshot: Dictionary = tribe.village().duplicate(true)
	await _frames(60)
	_expect(tribe.village() == paused_snapshot, "Paused village continued growth or deliveries.")
	_expect(saves.save_now() and saves.load_now(), "Growth clock did not load.")
	_expect(float(tribe.village()["housing"]["clock"]) == float(paused_snapshot["housing"]["clock"]), "Growth clock reset on load.")
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	await _until(func() -> bool: return tribe.actors.size() == 4, 2400)
	_expect(tribe.actors.size() == 4, "First new resident was not created.")
	print("M6 growth: population ", tribe.actors.size())
	# The new resident is selected through its real card and assigned a saved job.
	if tribe.actors.size() == 4:
		await _click(tribe.panel._residents.get_child(3))
		_expect(tribe.selected == [tribe.village()["members"][3]["id"]], "New resident card does not select its actor.")
		_expect(tribe.assign_profession("provider"), "New resident cannot receive a profession.")
	await _until(func() -> bool: return tribe.actors.size() == 5, 2400)
	print("M6 growth: population ", tribe.actors.size())
	if tribe.actors.size() == 5:
		tribe.select_member(tribe.village()["members"][4]["id"])
		tribe.assign_profession("provider")
	await _until(func() -> bool: return tribe.actors.size() == 6, 2600)
	print("M6 growth: population ", tribe.actors.size())
	_expect(tribe.actors.size() == 6 and tribe.village()["members"].size() == 6, "Population did not reach six.")
	tribe.select_all()
	_expect(tribe.assign_profession("provider"), "Six residents cannot share work.")
	await _until(func() -> bool: return int(tribe.village()["stock"]["food"]) == 24 and int(tribe.village()["stock"]["water"]) == 24, 3200)
	_expect(int(tribe.village()["stock"]["food"]) == 24 and int(tribe.village()["stock"]["water"]) == 24, "Supply targets did not scale to six actual carriers.")
	_expect(tribe.village()["members"].slice(0, 3).map(func(m: Dictionary) -> String: return m["id"]) == original_ids, "Growth replaced original residents.")
	var batch: Dictionary = {"schema": 1, "source_id": "d3-growth-fixture", "body_id": tribe.village()["body_id"], "faction_id": tribe.village()["faction_id"], "sequence": 1, "amount": 2, "position": [-8, 100.06, -7]}
	_expect(tribe.receive_milk(batch), "Grown village rejected D3 pickup.")
	tribe.select_member(tribe.village()["members"][-1]["id"])
	_expect(tribe.assign_profession("milk_carrier"), "Sixth resident cannot transport D3 milk.")
	await _until(func() -> bool: return int(tribe.village()["stock"]["milk"]) == 2, 1300)
	_expect(int(tribe.village()["stock"]["milk"]) == 2, "New resident did not physically deliver milk.")
	var milk_before: int = int(tribe.village()["economy"]["milk_received"])
	_expect(tribe.receive_milk(batch) and int(tribe.village()["economy"]["milk_received"]) == milk_before, "Grown village duplicated a milk receipt.")
	_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(), "Final growth state invalid: " + Model.validate(tribe.village(), tribe.body(), state.campaign.data))
	tribe.select_all()
	tribe.issue_order("wait")
	_expect(saves.save_now(), "Final village did not save.")
	var final_state: Dictionary = JSON.parse_string(JSON.stringify(tribe.village()))
	var expected: FileAccess = FileAccess.open("user://growth-expected.json", FileAccess.WRITE)
	expected.store_string(JSON.stringify(final_state))
	expected.close()
	evidence = {"population": tribe.actors.size(), "beds": Housing.beds(tribe.village()), "homes": tribe.village()["housing"]["homes"].size(), "deliveries": tribe.village()["delivered"], "stock": tribe.village()["stock"].duplicate(), "original_ids_retained": true, "schema": tribe.village()["schema"]}
	await _capture_growth()
	print(JSON.stringify({"test": "tribal_age_growth", "passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	await _cleanup()
	_finish()

func _build_home(kind: String, location: Vector3, expected_count: int) -> void:
	await _until(func(): return not tribe.navigation.pending, 1200)
	tribe.select_all()
	_expect(tribe.issue_order(kind, location), "Placement rejected: " + kind + " " + tribe.status)
	await _until(func() -> bool: return tribe.village()["housing"]["homes"].size() == expected_count, 1700)
	_expect(tribe.village()["housing"]["homes"].size() == expected_count, "Construction did not finish: " + kind + " " + str(tribe.village()["project"]))

func _restart() -> void:
	_expect(saves.load_now(), "Cold restart did not load growth snapshot.")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://growth-expected.json"))
	var body: Dictionary = state.get_current_body_record()
	_expect(body["tribe"] == expected, "Cold restart changed saved growth state.")
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	_expect(tribe._active and tribe.actors.size() == 6 and Housing.beds(tribe.village()) == 6, "Cold runtime did not rebuild six residents and homes.")
	_expect(tribe.panel._residents.get_child_count() == 6, "Cold UI omitted residents.")
	tribe.select_all()
	_expect(tribe.issue_order("resume"), "Cold loaded professions/orders cannot resume.")
	await _capture_growth()
	print(JSON.stringify({"test": "tribal_age_growth_restart", "passed": failures.is_empty(), "failures": failures}))
	await _cleanup()
	_finish()

func _capture_growth() -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	root.size = Vector2i(1280, 720)
	tribe.panel._tabs.current_tab = 0
	tribe.panel.refresh()
	await _frames(10)
	_expect(tribe.panel._hud.position.y > 0 and tribe.panel._hud.size.y < 620, "Six-resident desktop HUD blocks the viewport.")
	await _capture("growth-desktop")
	root.size = Vector2i(800, 900)
	tribe.panel._tabs.current_tab = 1
	tribe.panel.refresh()
	await _frames(10)
	_expect(tribe.panel._hud.position.y > 0, "Six-resident narrow HUD exceeds viewport.")
	await _capture("growth-narrow")
	tribe.panel._collapsed = true
	tribe.panel.refresh()
	await _frames(8)
	await _capture("growth-collapsed")
