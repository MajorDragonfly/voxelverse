extends "tribal_age_test.gd"
## Reuses the real world/player fixture and real mouse helpers. This script also
## runs beside its base probe against the release PCK outside the source tree.

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
	_expect(home.establish_home()["ok"], "Supply fixture could not establish home.")
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _frames(15)
	if not tribe.is_active():
		_expect(false, "Supply fixture could not enter tribal age.")
		await _cleanup()
		_finish()
		return
	# A completed schema-1 village: 15 wood/8 stone spent on tool and huts;
	# 37 meals used, 11 food left. No renewable food or replacement residents.
	var data: Dictionary = tribe.village()
	data["tools"] = 1
	data["huts"] = 2
	data["stock"] = {"wood": 4, "stone": 1, "food": 11}
	data["deposits"]["wood"]["remaining"] = 29
	data["deposits"]["stone"]["remaining"] = 39
	data["deposits"]["food"]["remaining"] = 0
	data["meals"] = 37
	for member: Dictionary in data["members"]:
		member["hunger"] = 85.0
	data["schema"] = 1
	data.erase("housing")
	for key in ["garden", "growth", "grown", "economy"]:
		data.erase(key)
	for kind in ["water", "fiber"]:
		data["deposits"].erase(kind)
	for member: Dictionary in data["members"]:
		for key in ["hydration", "profession", "paused_order", "task", "blocked", "species_id", "faction_id", "construction_id"]:
			member.erase(key)
	# Compare with the actual JSON representation, including its float precision.
	var originals: Array = JSON.parse_string(JSON.stringify(data["members"]))
	_expect(saves.save_now(), "Legacy fixture could not save.")
	var legacy_bytes: String = FileAccess.get_file_as_string(SAVE)
	_expect(saves.load_now(), "Schema-1 village did not load.")
	_expect(originals.all(func(m: Dictionary) -> bool: return m.keys().all(func(key: String) -> bool: return tribe.member_record(m["id"])[key] == m[key])) and int(tribe.village()["schema"]) == Model.LEGACY_SCHEMA, "Migration changed residents or orders: expected=%s actual=%s" % [originals, tribe.village()["members"]])
	_expect(FileAccess.get_file_as_string(SAVE) == legacy_bytes, "Read migration overwrote the previous save.")
	_expect(int(tribe.village()["garden"]) == 0 and int(tribe.village()["grown"]) == 0 and int(tribe.village()["stock"]["food"]) == 11, "Migration granted a garden or changed the food stock.")
	await _frames(15)
	tribe.select_all()
	var before_failure: Dictionary = tribe.village().duplicate(true)
	var blocked: FileAccess = FileAccess.open("user://supply-blocked-parent", FileAccess.WRITE)
	blocked.store_string("not a directory")
	blocked.close()
	saves.save_path = "user://supply-blocked-parent/save.json"
	_expect(not tribe.issue_order("garden") and tribe.village() == before_failure, "Failed garden save lost resources or installed work.")
	saves.save_path = SAVE
	await _click(tribe.panel._buttons["garden"])
	_expect(int(tribe.village()["stock"]["wood"]) == 0 and int(tribe.village()["stock"]["stone"]) == 0, "Garden did not reserve exactly four wood and one stone.")
	_expect(tribe.issue_order("garden"), "Additional builders could not join the existing garden.")
	await _until(func() -> bool: return not tribe.village()["project"].is_empty() and float(tribe.village()["project"]["progress"]) > 2, 350)
	_key(KEY_SPACE)
	var work: Dictionary = JSON.parse_string(JSON.stringify(tribe.village()["project"]))
	_expect(not work.is_empty(), "Builders never reached the actual garden.")
	_expect(saves.save_now() and saves.load_now(), "Could not resume garden construction.")
	_expect(tribe.village()["project"] == work and int(tribe.village()["stock"]["wood"]) == 0, "Load repeated costs or construction progress: expected=%s actual=%s stock=%s" % [work, tribe.village()["project"], tribe.village()["stock"]])
	await _frames(12)
	tribe.select_all()
	await _until(func() -> bool: return int(tribe.village()["garden"]) == 1, 400)
	_expect(int(tribe.village()["garden"]) == 1, "Garden construction never completed.")
	_expect(not tribe.issue_order("garden"), "Completed garden could be built twice.")
	await _capture("07_garden")
	# All three workers share one reserve target, including food in transit.
	await _click(tribe.panel._buttons["supply"])
	await _until(func() -> bool: return int(tribe.village()["stock"]["food"]) == Model.FOOD_TARGET, 1000)
	_expect(int(tribe.village()["stock"]["food"]) == Model.FOOD_TARGET and int(tribe.village()["grown"]) >= 1, "No renewed root was harvested and carried home.")
	var deliveries: int = int(tribe.village()["delivered"])
	await _frames(80)
	_expect(int(tribe.village()["delivered"]) == deliveries and Model.cargo_count(tribe.village(), "food") == 0, "Supply workers overfilled the target with concurrent harvests.")
	_expect(tribe.village()["members"].all(func(m: Dictionary) -> bool: return m["order"] == "supply"), "Satisfied supply order was discarded.")
	await _capture("08_supply")
	_key(KEY_SPACE)
	var paused_data: Dictionary = tribe.village().duplicate(true)
	await _frames(20)
	_expect(paused and tribe.village() == paused_data, "Garden or workers advanced while paused.")
	_key(KEY_SPACE)
	var worker_id: String = str(tribe.village()["members"][0]["id"])
	tribe.select_member(worker_id)
	await _click(tribe.panel._buttons["stone"])
	await _until(func() -> bool: return tribe.member_record(worker_id)["cargo"] == "stone", 450)
	_expect(tribe.member_record(worker_id)["cargo"] == "stone", "Worker did not acquire cargo before becoming hungry.")
	tribe.member_record(worker_id)["hunger"] = 39.0
	var first_meal: int = int(tribe.village()["meals"])
	await _until(func() -> bool: return int(tribe.village()["meals"]) > first_meal, 400)
	_expect(int(tribe.village()["stock"]["stone"]) >= 1, "Meal detour discarded carried stone.")
	await _until(func() -> bool: return tribe.actors[worker_id].global_position.distance_to(tribe.anchor()) > 3 and tribe.member_record(worker_id)["cargo"] == "", 300)
	tribe.member_record(worker_id)["hunger"] = 39.0
	await _until(func() -> bool: return tribe.member_record(worker_id)["stage"] == "meal", 400)
	_expect(tribe.member_record(worker_id)["stage"] == "meal", "Hungry worker did not start a meal detour from the field.")
	_expect(tribe.member_record(worker_id)["cargo"] == "" and int(tribe.village()["stock"]["stone"]) >= 1, "Meal detour discarded carried stone.")
	_expect(tribe.member_record(worker_id)["order"] == "stone", "Meal detour replaced the assigned profession.")
	_key(KEY_SPACE)
	_expect(saves.save_now(), "Meal detour did not save.")
	var saved_meals: int = int(tribe.village()["meals"])
	_expect(saves.load_now(), "Meal detour did not load.")
	_expect(tribe.member_record(worker_id)["stage"] == "meal" and int(tribe.village()["meals"]) == saved_meals, "Load ate food prematurely or lost meal detour.")
	await _frames(1)
	await _capture("09_meal")
	await _until(func() -> bool: return int(tribe.village()["meals"]) > saved_meals, 350)
	_expect(float(tribe.member_record(worker_id)["hunger"]) > 60 and tribe.member_record(worker_id)["order"] == "stone", "Worker did not eat and retain the stone order.")
	await _until(func() -> bool: return tribe.member_record(worker_id)["cargo"] == "stone" and int(tribe.village()["stock"]["food"]) == Model.FOOD_TARGET, 1100)
	_expect(tribe.member_record(worker_id)["cargo"] == "stone", "Fed worker did not return to harvesting stone.")
	_expect(int(tribe.village()["stock"]["food"]) == Model.FOOD_TARGET, "Supply did not automatically replace the eaten meal.")
	tribe.select_all()
	await _click(tribe.panel._buttons["wait"])
	var stopped: Dictionary = tribe.village()["stock"].duplicate(true)
	for member: Dictionary in tribe.village()["members"]:
		member["hunger"] = 10.0
	await _frames(25)
	_expect(tribe.village()["stock"] == stopped, "Stop did not stop automatic meals or cargo delivery.")
	# Boundary cases use a detached snapshot so they cannot affect the live loop.
	var edge: Dictionary = tribe.village().duplicate(true)
	edge["deposits"]["food"]["remaining"] = 7
	edge["growth"] = 19.5
	var grown_before: int = int(edge["grown"])
	Model.grow(edge, 4000.0)
	_expect(int(edge["deposits"]["food"]["remaining"]) == 8 and int(edge["grown"]) == grown_before + 1 and float(edge["growth"]) == 0, "Full garden accumulated an unlimited growth backlog.")
	edge = tribe.village().duplicate(true)
	edge["stock"]["food"] = 48
	edge["members"][0]["cargo"] = "food"
	edge["grown"] = 100
	_expect(not Model.validate(edge, tribe.body(), state.campaign.data).is_empty(), "Cargo reservations can overflow the store.")
	_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty() and saves.save_now(), "Renewable economy cannot be saved.")
	# Every action must be reachable on its tab through the actual scroll container.
	root.size = Vector2i(800, 900)
	await _frames(8)
	await _check_scrolled_actions()
	await _capture("10_supply_narrow")
	await _cleanup()
	_finish()

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_age_supply", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
