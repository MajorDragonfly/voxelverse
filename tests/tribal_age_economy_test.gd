extends "tribal_age_test.gd"
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
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home()["ok"], "Could not establish economy fixture.")
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	if not tribe.is_active():
		_expect(false, "Could not enter village: " + saves.last_error)
		await _cleanup()
		_finish()
		return
	# Existing developed village: finite start materials spent/transported before
	# this probe. No unlimited source or water is granted by the migration.
	var data: Dictionary = tribe.village()
	data["tools"] = 1
	data["huts"] = 2
	data["garden"] = 1
	data["stock"]["wood"] = 20
	data["stock"]["stone"] = 12
	data["stock"]["food"] = 12
	data["deposits"]["wood"]["remaining"] = 0
	data["deposits"]["stone"]["remaining"] = 0
	data["deposits"]["food"]["remaining"] = 0
	var old: Dictionary = data.duplicate(true)
	old["schema"] = 2
	old.erase("economy")
	old.erase("housing")
	for kind: String in Economy.EXTRA:
		old["stock"].erase(kind)
	for kind: String in ["water", "fiber"]:
		old["deposits"].erase(kind)
	for member: Dictionary in old["members"]:
		for key in ["hydration", "profession", "paused_order", "task", "blocked", "species_id", "faction_id", "construction_id"]:
			member.erase(key)
	tribe.body()["tribe"] = old
	# No live tick is allowed on the deliberately old snapshot.
	paused = true
	_expect(saves.save_now(), "Legacy economy snapshot failed.")
	var bytes: String = FileAccess.get_file_as_string(SAVE)
	var ids: Array = old["members"].map(func(m: Dictionary) -> String: return m["id"])
	_expect(saves.load_now(), "Legacy economy load failed.")
	paused = false
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	data = tribe.village()
	_expect(int(data["schema"]) == Model.LEGACY_SCHEMA and data["economy"]["stations"].is_empty() and int(data["stock"]["water"]) == 0, "Migration granted water or workstations.")
	_expect(data["members"].map(func(m: Dictionary) -> String: return m["id"]) == ids and FileAccess.get_file_as_string(SAVE) == bytes, "Migration replaced residents or rewrote old bytes.")
	# Keep this three-worker economy probe at three beds. Population growth has
	# a separate integration test; the legacy migration above retains both huts.
	data["housing"]["homes"][1]["kind"] = "tent"
	data["huts"] = 1
	# Empty jobs persist before there is a replacement source.
	tribe.select_all()
	_expect(tribe.issue_order("wood"), "Cannot assign empty wood source.")
	await _frames(110)
	_expect(tribe.village()["members"].all(func(m: Dictionary) -> bool: return m["order"] == "wood"), "Empty material source discarded jobs.")
	tribe.panel._tabs.current_tab = 1
	await _frames(3)
	var sites: Dictionary = {"well": Vector3(0, 100.06, -7), "forester": Vector3(-5, 100.06, -4), "quarry": Vector3(5, 100.06, -4), "fiberbed": Vector3(-8, 100.06, 0)}
	# Failed placement and failed atomic save never charge construction costs.
	var before: Dictionary = tribe.village().duplicate(true)
	_expect(not tribe.issue_order("well", tribe.anchor()) and tribe.village() == before, "Invalid workplace charged materials.")
	var block_file: FileAccess = FileAccess.open("user://economy-blocked", FileAccess.WRITE)
	block_file.store_string("not a directory")
	block_file.close()
	saves.save_path = "user://economy-blocked/save.json"
	_expect(not tribe.issue_order("well", sites["well"]) and tribe.village() == before, "Failed workplace save lost materials or jobs.")
	saves.save_path = SAVE
	for station: String in sites:
		tribe.select_all()
		# Real button arms placement; real world right click commits it.
		await _click(tribe.panel._buttons[station])
		_expect(tribe.placement == station and not tribe.panel._hud_content.visible, "Workplace placement did not reveal the world.")
		await _world_click(tribe.camera.unproject_position(sites[station]), MOUSE_BUTTON_RIGHT)
		_expect(not tribe.village()["project"].is_empty(), "Workplace was not placed: " + station + " " + tribe.status)
		if tribe.village()["project"].is_empty():
			continue
		await _until(func() -> bool: return not tribe.village()["project"].is_empty() and float(tribe.village()["project"]["progress"]) > 1, 400)
		if station == "well":
			paused = true
			var project: Dictionary = JSON.parse_string(JSON.stringify(tribe.village()["project"]))
			var stock: Dictionary = JSON.parse_string(JSON.stringify(tribe.village()["stock"]))
			_expect(saves.save_now() and saves.load_now(), "Workplace construction failed Save/Load.")
			_expect(tribe.village()["project"] == project and tribe.village()["stock"] == stock, "Construction restarted or charged twice after load: expected=%s/%s actual=%s/%s" % [project, stock, tribe.village()["project"], tribe.village()["stock"]])
			paused = false
			await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
		await _until(func() -> bool: return tribe.village()["economy"]["stations"].has(station), 650)
		_expect(tribe.village()["economy"]["stations"].has(station), "Workplace did not complete: " + station)
		_expect(not tribe.issue_order(station, sites[station]), "Completed station can be built twice.")
	await _capture("01_workplaces")
	if tribe.village()["economy"]["stations"].size() != 4:
		await _cleanup()
		_finish()
		return
	print("M6: four workplaces built and partial construction reloaded")
	# A single provider maintains both needs; all resources must travel home.
	tribe.select_all()
	_expect(tribe.assign_profession("provider"), "Profession could not be assigned.")
	await _until(func() -> bool: return int(tribe.village()["stock"]["water"]) == 12, 1400)
	_expect(int(tribe.village()["stock"]["water"]) == 12, "Well water did not physically reach reserve target.")
	var delivered: int = int(tribe.village()["delivered"])
	await _frames(70)
	_expect(int(tribe.village()["delivered"]) == delivered and Economy.carried(tribe.village(), "water") == 0, "Concurrent providers overfilled a target.")
	var worker: String = ids[0]
	tribe.select_member(worker)
	_expect(tribe.assign_profession("forester"), "Forester assignment failed.")
	# Existing reserve is above the job's target; consuming it wakes the worker.
	tribe.village()["stock"]["wood"] = 0
	await _until(func() -> bool: return tribe.member_record(worker)["cargo"] == "wood", 700)
	_expect(tribe.member_record(worker)["cargo"] == "wood", "Renewed wood was not picked up.")
	_expect(tribe.issue_order("wait"), "Pause order failed.")
	var stopped: Dictionary = tribe.member_record(worker).duplicate(true)
	var wood: int = int(tribe.village()["stock"]["wood"])
	await _frames(25)
	_expect(tribe.member_record(worker)["cargo"] == "wood" and int(tribe.village()["stock"]["wood"]) == wood, "Paused carrier delivered remotely or lost cargo.")
	_expect(saves.save_now() and saves.load_now(), "Paused cargo could not survive reload.")
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	_expect(tribe.member_record(worker)["paused_order"] == stopped["paused_order"] and tribe.member_record(worker)["profession"] == "forester", "Paused work or profession was lost.")
	tribe.select_member(worker)
	_expect(tribe.issue_order("resume"), "Saved order did not resume.")
	await _until(func() -> bool: return int(tribe.village()["stock"]["wood"]) > wood, 450)
	_expect(int(tribe.village()["stock"]["wood"]) > wood, "Resumed carrier did not deliver.")
	# Automatic drink detour retains profession; save in the detour itself.
	await _until(func() -> bool: return tribe.actors[worker].global_position.distance_to(tribe.anchor()) > 4.0 and tribe.member_record(worker)["cargo"] == "", 400)
	tribe.member_record(worker)["hydration"] = 39.0
	await _until(func() -> bool: return tribe.member_record(worker)["stage"] == "drink", 550)
	paused = true
	var drinks: int = int(tribe.village()["economy"]["drinks"])
	_expect(tribe.member_record(worker)["stage"] == "drink" and saves.save_now() and saves.load_now(), "Drink detour did not save/load.")
	_expect(int(tribe.village()["economy"]["drinks"]) == drinks, "Load consumed water prematurely.")
	paused = false
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	await _until(func() -> bool: return int(tribe.village()["economy"]["drinks"]) > drinks, 500)
	_expect(tribe.member_record(worker)["order"] == "wood" and float(tribe.member_record(worker)["hydration"]) > 60, "Drink did not return worker to prior job.")
	# More materials, visibly collected at their distinct reachable stations.
	tribe.select_member(ids[1])
	_expect(tribe.assign_profession("mason"), "Mason assignment failed.")
	var stone: int = int(tribe.village()["stock"]["stone"])
	tribe.select_member(ids[2])
	_expect(tribe.assign_profession("weaver"), "Fiber job assignment failed.")
	await _until(func() -> bool: return int(tribe.village()["stock"]["stone"]) > stone and int(tribe.village()["stock"]["fiber"]) > 0, 1000)
	_expect(int(tribe.village()["stock"]["stone"]) > stone and int(tribe.village()["stock"]["fiber"]) > 0, "Stone/fiber failed real transport.")
	await _capture("02_professions")
	print("M6: providers, professions, cargo resume, drinking and materials passed")
	# New collision completely blocks the former path. Same saved job retries
	# after the obstacle disappears; no new order or teleport is issued.
	tribe.select_member(worker)
	_expect(tribe.issue_order("wait"), "Could not stop for obstruction setup.")
	tribe.village()["stock"]["wood"] = 0
	var location: Vector3 = tribe.actors[worker].global_position
	var obstacle: StaticBody3D = _box(Vector3(4, 3, 4), location + Vector3(0, 1.5, 0))
	await _frames(5)
	_expect(tribe.issue_order("resume"), "Could not resume blocked job.")
	await _until(func() -> bool: return tribe.member_record(worker)["blocked"], 220)
	_expect(tribe.member_record(worker)["blocked"] and tribe.member_record(worker)["order"] == "wood", "Blockage did not retain job.")
	obstacle.queue_free()
	await _frames(5)
	var previous: int = int(tribe.village()["stock"]["wood"])
	await _until(func() -> bool: return int(tribe.village()["stock"]["wood"]) > previous, 750)
	_expect(int(tribe.village()["stock"]["wood"]) > previous, "Worker did not automatically resume after obstruction removal.")
	# D3 adapter fixture: production itself belongs to the D3 owner.
	tribe.select_all()
	tribe.issue_order("wait")
	var batch: Dictionary = {"schema": 1, "source_id": "d3-fixture-animal", "body_id": tribe.village()["body_id"], "faction_id": tribe.village()["faction_id"], "sequence": 1, "amount": 3, "position": [0, 100.06, 7]}
	_expect(tribe.receive_milk(batch), "D3 delivery was not accepted.")
	_expect(int(tribe.village()["stock"]["milk"]) == 0 and Economy.milk_pending(tribe.village()) == 3, "Milk teleported to stock.")
	_expect(tribe.receive_milk(batch) and Economy.milk_pending(tribe.village()) == 3, "Repeated D3 delivery duplicated milk.")
	var changed_batch: Dictionary = batch.duplicate(true)
	changed_batch["amount"] = 4
	_expect(not tribe.receive_milk(changed_batch), "Changed batch reused delivery number.")
	tribe.select_member(ids[2])
	_expect(tribe.assign_profession("milk_carrier"), "Milk carrier assignment failed.")
	await _until(func() -> bool: return tribe.member_record(ids[2])["cargo"] == "milk", 800)
	_expect(tribe.member_record(ids[2])["cargo"] == "milk", "Milk was not picked up at source.")
	_expect(saves.save_now() and saves.load_now(), "Milk in transit did not save/load.")
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	_expect(tribe.receive_milk(batch), "D3 retry after reload not acknowledged.")
	_expect(Economy.milk_pending(tribe.village()) + Economy.reserve(tribe.village(), "milk") == 3, "Save/load duplicated milk in transit.")
	await _until(func() -> bool: return int(tribe.village()["stock"]["milk"]) == 3, 1000)
	_expect(int(tribe.village()["stock"]["milk"]) == 3, "Milk carriers did not finish transport.")
	tribe.select_member(ids[2])
	tribe.member_record(ids[2])["hunger"] = 39.0
	var meals: int = int(tribe.village()["economy"]["milk_meals"])
	await _until(func() -> bool: return int(tribe.village()["economy"]["milk_meals"]) > meals, 400)
	_expect(int(tribe.village()["economy"]["milk_meals"]) == meals + 1 and int(tribe.village()["stock"]["milk"]) == 2, "Milk was not consumed once from shared store.")
	await _capture("03_milk_adapter")
	print("M6: obstruction and milk adapter complete")
	paused = true
	var snapshot: Dictionary = tribe.village().duplicate(true)
	await _frames(25)
	_expect(tribe.village() == snapshot, "Economy advanced while paused.")
	_expect(saves.save_now() and saves.load_now(), "Final economy failed persistence.")
	_expect(tribe.village()["economy"] == JSON.parse_string(JSON.stringify(snapshot["economy"])), "Load advanced clocks or altered receipts.")
	paused = false
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)
	# Long simulation uses the real movement/work loop with all initial sources
	# exhausted. Higher needs repeatedly trigger replacement transports.
	tribe.select_all()
	tribe.assign_profession("provider")
	for cycle in range(5):
		for member: Dictionary in tribe.village()["members"]:
			member["hunger"] = 39.0
			member["hydration"] = 39.0
		await _until(func() -> bool: return tribe.village()["members"].all(func(m: Dictionary) -> bool: return m["hunger"] > 55 and m["hydration"] > 60) and int(tribe.village()["stock"]["food"]) == 12 and int(tribe.village()["stock"]["water"]) == 12, 1800)
		_expect(tribe.village()["members"].all(func(m: Dictionary) -> bool: return m["hunger"] > 55 and m["hydration"] > 60), "Sustained supply failed cycle " + str(cycle))
	_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(), "Economy produced invalid save: " + Model.validate(tribe.village(), tribe.body(), state.campaign.data))
	evidence = {"delivered": tribe.village()["delivered"], "meals": tribe.village()["meals"], "drinks": tribe.village()["economy"]["drinks"], "produced": tribe.village()["economy"]["produced"], "grown": tribe.village()["grown"], "stock": tribe.village()["stock"].duplicate()}
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(800, 900)]:
		root.size = size
		await _frames(10)
		await _check_scrolled_actions()
		for tab in range(3):
			tribe.panel._tabs.current_tab = tab
			await _frames(3)
			await _capture("04_ui_%d_%d_%d" % [size.x, size.y, tab])
	tribe.panel._collapse.pressed.emit()
	await _frames(5)
	_expect(not tribe.panel._hud_content.visible and tribe.panel._hud.size.y < 180, "Collapsed village HUD still obscures the world.")
	await _capture("05_collapsed")
	_expect(saves.save_now(), "Final economy cannot save.")
	await _cleanup()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("M6 CHECK FAILED: ", message)

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_age_economy", "passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
