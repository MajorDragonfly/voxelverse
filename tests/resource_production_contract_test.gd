extends "res://tests/tribal_age_husbandry_contract_test.gd"
const E = preload("res://world/tribe/village_economy.gd")
const Work = preload("res://world/tribe/village_work.gd")
const SAVE: String = "user://arch20-production.json"

func _run() -> void:
	if "--restart-check" in OS.get_cmdline_user_args():
		_restart()
	else:
		_prepare()
		_save_protection()
		var output: Array = []
		var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--restart-check"])
		var code: int = OS.execute(OS.get_executable_path(), args, output, true)
		_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and "\n".join(output).contains('"passed":true'), "Cold production restart failed: " + str(output))
	print(JSON.stringify({"test": "resource_production_contract", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _prepare() -> void:
	campaign.reset("arch20-production")
	body = campaign.body_for_seed(15838, 1)
	body.home_group = Model.Home.create(body.id, campaign.data.player_species_id, Vector3.ZERO)
	var data: Dictionary = fixture(0.25, 1)
	for i in range(14): H.advance(data, data.husbandry.pens[0], 0.25)
	# Construct actual old bytes, independently of the new intake adapter.
	var legacy: Dictionary = {"schema": 1, "source_id": "old-milk-source", "body_id": data.body_id, "faction_id": data.faction_id, "sequence": 1, "amount": 3, "position": [0, 0, -7]}
	data.economy.receipts[legacy.source_id] = legacy.duplicate(true)
	data.economy.incoming.append(legacy.duplicate(true))
	data.economy.incoming[0]["remaining"] = 2
	data.economy.milk_received = 3
	data.members[0].merge({"cargo": "milk", "stage": "return", "order": "wait", "paused_order": "milk", "position": [0, 0, -4]}, true)
	_expect(valid(data), "Legacy production, receipt and cargo fixture invalid.")
	var before: Dictionary = data.duplicate(true)
	var upgraded: Dictionary = E.Batch.canonical(data, legacy)
	_expect(upgraded.schema == 2 and upgraded.resource_id == "milk" and upgraded.recipe_revision == 1, "Legacy batch did not gain its explicit resource/recipe contract.")
	_expect(E.receive_batch(data, upgraded).is_empty() and E.receive_milk(data, legacy).is_empty() and data == before, "Old receipt retry changed legacy bytes or quantities.")
	for field: String in ["schema", "resource_revision", "recipe_revision", "resource_id", "recipe_id", "receipt_id", "amount", "position"]:
		var bad: Dictionary = upgraded.duplicate(true)
		bad[field] = {"schema": 99, "resource_revision": 99, "recipe_revision": 99, "resource_id": "eggs", "recipe_id": "unknown.recipe", "receipt_id": "forged", "amount": 4, "position": [0, 0, -8]}[field]
		_expect(not E.receive_batch(data, bad).is_empty() and data == before, "Rejected batch mutated state: " + field)
		if field in ["schema", "resource_revision", "recipe_revision", "resource_id", "recipe_id"]:
			var future: Dictionary = before.duplicate(true)
			future.economy.receipts[legacy.source_id] = bad
			_expect(E.has_unsupported_contract(future.economy), "Unknown contract not protected: " + field)
			var save: Dictionary = {"game_state": {"campaign": {"bodies": {"fixture": {"tribe": future}}}}}
			_expect(root.get_node("SaveGameService")._has_unsupported_contract(save), "Save fallback did not see nested future contract: " + field)
	var forged: Dictionary = before.duplicate(true)
	forged.economy.incoming[0].position = [0, 0, -8]
	_expect(not valid(forged), "Altered outstanding batch disagreed with receipt but validated.")
	_expect(not E.collect(data, data.members[1], "milk") and data == before, "Remote pickup teleported resources.")
	_expect(E.Resources.definition("eggs").is_empty() and E.Batch.Production.definition("husbandry.eggs").is_empty(), "ARCH-20 activated eggs.")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"data": data, "body": body, "campaign": campaign.data}))
	file.close()

func _save_protection() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	var path: String = saves.create_slot("ARCH-20 version protection", 15838)
	_expect(not path.is_empty(), "Could not create version protection slot.")
	if path.is_empty(): return
	var original: String = FileAccess.get_file_as_string(path)
	var future: Dictionary = JSON.parse_string(original)
	var active: Dictionary = preload("res://core/campaign/body_registry.gd").active(future.game_state)
	active["tribe"] = {"economy": {"schema": 1, "receipts": {"future": {"schema": 99}}, "incoming": []}}
	var future_bytes: String = JSON.stringify(future)
	for target: String in [path, path + ".bak"]:
		var file := FileAccess.open(target, FileAccess.WRITE)
		file.store_string(future_bytes if target == path else original)
		file.close()
	_expect(not saves.load_now(path) and not saves.save_now(path), "Future resource contract fell back to backup or was overwritten.")
	_expect(FileAccess.get_file_as_string(path) == future_bytes and FileAccess.get_file_as_string(path + ".bak") == original, "Version rejection altered primary or backup bytes.")
	var restored := FileAccess.open(path, FileAccess.WRITE)
	restored.store_string(original)
	restored.close()
	_expect(saves.load_now(path), "Compatible slot did not recover after restoring its original.")

func _restart() -> void:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	body = saved.body
	campaign.data = saved.campaign
	var data: Dictionary = saved.data
	var before: Dictionary = data.duplicate(true)
	var record: Dictionary = data.husbandry.records["d3-unit-animal"]
	_expect(valid(data) and record.cycles == 3 and record.clock == 0.5 and record.produced == 0 and data.members[0].cargo == "milk", "Restart lost fractions, unfinished cycle or loaded carrier.")
	var effects: Array = []
	Work.step(data, data.members[0], 0.25, 1, effects)
	for delta: float in [0.0, -1.0, INF, 1000.0]: H.advance(data, data.husbandry.pens[0], delta)
	_expect(data == before and effects.is_empty(), "Paused/offline work advanced after restart.")
	var legacy: Dictionary = data.economy.receipts["old-milk-source"].duplicate(true)
	_expect(E.receive_milk(data, legacy).is_empty() and data == before, "Restart repeated the old receipt.")
	for i in range(2): H.advance(data, data.husbandry.pens[0], 0.25)
	_expect(record.cycles == 4 and record.produced == 1 and H.offer(data, "d3-unit-animal"), "Saved fractional production did not resume as exactly one unit.")
	_expect(data.economy.receipts["d3-unit-animal"].schema == 2 and E.pending(data, "milk") == 3 and data.stock.milk == 0, "Production bypassed resource inbox or storage transport.")
	var member: Dictionary = data.members[0]
	member.order = "milk"
	member.paused_order = ""
	member.position = data.anchor.duplicate(true)
	Work.step(data, member, 0.25, 1, effects)
	before = data.duplicate(true)
	Work.step(data, member, 0.25, 1, effects)
	_expect(data.stock.milk == 1 and member.cargo == "" and data == before, "Delivery repeated or picked up remote cargo.")
	member.hunger = 50.0
	_expect(Work.eat(data, member, effects) and member.hunger == 75.0 and data.stock.milk == 0 and data.economy.milk_meals == 1, "Resource nutrition or consumption changed.")
	var next: Dictionary = E.Batch.create(data, legacy.source_id, 2, 1, legacy.position, E.Batch.Production.MILK)
	_expect(E.receive_batch(data, next).is_empty(), "Old producer could not continue with a versioned batch.")
	before = data.duplicate(true)
	_expect(E.receive_batch(data, next).is_empty() and data == before, "Resource batch retry changed totals.")
	_expect(valid(data) and E.pending(data, "milk") + E.reserve(data, "milk") + E.Resources.total(data.economy, "milk", "consumed") == E.Resources.total(data.economy, "milk", "received"), "Mixed legacy/new batches broke conservation.")
