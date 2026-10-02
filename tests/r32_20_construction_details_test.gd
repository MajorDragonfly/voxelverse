extends "res://tests/settlement_collection_test.gd"
## Arrived-work/radial fixture, not physical terrain or target-PC evidence.
const Details = preload("res://ui/tribe/construction_details_view.gd")
const Construction = Tribe.Construction
const ConstructionPanel = preload("res://ui/tribe/construction_panel.gd")
const CHECKPOINT: String = "user://r32-20-details.json"

class PanelController extends Node:
	var data: Dictionary
	var selected: Array = []
	func village() -> Dictionary: return data
	func is_active() -> bool: return true

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("GameState").set_process(false)
	if "--r32-20-restart" in OS.get_cmdline_user_args():
		var fixture: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(CHECKPOINT))
		_expect(not fixture.is_empty(), "Fresh process lost checkpoint")
		_check_collection(fixture.body, fixture.campaign)
		for id: String in Settlements.ids(fixture.body):
			var data: Dictionary = Settlements.village(fixture.body, id)
			_check_rows(data)
			_expect(Construction.state(data.project) == "paused", "Restart lost independent site pause")
		await _end()
		return
	var fixture: Dictionary = _legacy()
	var campaign: Dictionary = fixture.campaign
	var body: Dictionary = Settlements.prepare_legacy(fixture.body, campaign).body
	body.erase("tribal_neighbor")
	var first: String = Settlements.origin_id(body)
	var second: String = _second(body, campaign)
	var a: Dictionary = Settlements.instance_view(body, first)
	var b: Dictionary = Settlements.instance_view(body, second)
	for view: Dictionary in [a, b]:
		var data: Dictionary = view.tribe
		for kind: String in ["wood", "stone"]:
			data.stock[kind] = 20
			data.deposits[kind].remaining -= 20
		_start(data)
		_certify(view, campaign)
		view.village_simulation.cursor = campaign.elapsed_seconds
		_check_rows(data)
	_expect(a.tribe.project.id != b.tribe.project.id, "Two sites share identity")
	# Pickups come from the real arrived-work writer, with exact reservation loss.
	for view: Dictionary in [a, b]:
		var worker: Dictionary = view.tribe.members[0]
		worker.position = view.tribe.anchor.duplicate(true)
		Work.step(view.tribe, worker, 0.25, 1.0, [])
		_expect(worker.cargo == "wood" and worker.construction_id == view.tribe.project.id, "No bound pickup")
		_check_rows(view.tribe)
	_check_collection(body, campaign)
	var other: Dictionary = b.tribe.duplicate(true)
	_expect(Construction.command(a.tribe, "pause").ok, "Cannot pause A")
	a.tribe.members[0].position = a.tribe.project.entrance.duplicate(true)
	Work.step(a.tribe, a.tribe.members[0], 30.0, 1.0, [])
	_expect(a.tribe.project.delivered_materials.wood == 1 and a.tribe.project.progress == 0, "Paused arrival confused with installed work")
	_check_rows(a.tribe)
	_expect(b.tribe == other, "A delivery changed B")
	# Actual far navigation refuses a blocked bound carrier. No arrival is faked.
	b.tribe.members[0].blocked = true
	_certify(b, campaign)
	b.village_simulation.cursor = campaign.elapsed_seconds
	var cargo_before: Dictionary = b.tribe.duplicate(true)
	for tick in range(20): Simulation.advance(b, 105.0, 1.0, Callable(), true)
	_expect(b.tribe.members[0].cargo == "wood" and b.tribe.project.delivered_materials.wood == 0, "Blocked cargo arrived")
	_expect(b.tribe.stock == cargo_before.stock, "Blocked route booked stock")
	_check_rows(b.tribe)
	var frozen: Dictionary = body.duplicate(true)
	for tick in range(4):
		Simulation.advance(b, 105.0, 1.0, Callable(), true)
	_expect(body == frozen, "Repeated campaign clock produced twice")
	_expect(Construction.command(b.tribe, "pause").ok, "Cannot pause B")
	campaign.elapsed_seconds = 105.0
	_check_collection(body, campaign)
	_expect(Atomic.write(CHECKPOINT, {"body": body, "campaign": campaign}, false) == OK, "Cannot save both sites")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--r32-20-restart"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and str(output).contains("R32_20_DETAILS_PASSED") and not str(output).contains("ERROR:"), "Fresh process failed: " + str(output))
	print(str(output))
	_expect(Construction.command(a.tribe, "resume").ok, "Cannot resume A")
	_expect(Construction.command(a.tribe, "cancel").ok, "Cannot recover A")
	_check_rows(a.tribe)
	var worker: Dictionary = a.tribe.members[0]
	worker.position = a.tribe.project.entrance.duplicate(true)
	Work.step(a.tribe, worker, 0.25, 1.0, [])
	_expect(worker.cargo == "wood" and a.tribe.stock.wood == 19, "Recovery skipped return cargo")
	_check_rows(a.tribe)
	worker.position = a.tribe.anchor.duplicate(true)
	Work.step(a.tribe, worker, 0.25, 1.0, [])
	_expect(a.tribe.project.is_empty() and a.tribe.stock.wood == 20 and a.tribe.stock.stone == 20, "Recovery failed conservation")
	_expect(Details.read(a.tribe).is_empty(), "Cancelled site retained details")
	_prepaid(a.tribe)
	await _panel_checks(b.tribe)
	await _end()

func _start(data: Dictionary) -> void:
	data.project = Tribe.Housing.site(data, "hut", data.sites[0], data.housing.homes.size())
	data.project.merge({"progress": 0.0, "materials": Tribe.Housing.COSTS.hut.duplicate(), "delivered_materials": {"wood": 0, "stone": 0}})
	for kind: String in Construction.costs(data.project): data.stock[kind] -= Construction.costs(data.project)[kind]
	data.members[0].order = "build"

func _check_collection(body: Dictionary, campaign: Dictionary) -> void:
	_expect(Settlements.validate(body, campaign).is_empty(), "Two-site ledger invalid: " + Settlements.validate(body, campaign))

func _check_rows(data: Dictionary) -> void:
	var before: Dictionary = data.duplicate(true)
	var view: Dictionary = Details.read(data)
	_expect(view.project_id == data.project.id and view.settlement_id == data.id, "Wrong detail identity")
	_expect(view.installed == null and view.tracks_transport, "Invented installed-unit counter")
	for kind: String in view.materials:
		var row: Dictionary = view.materials[kind]
		_expect([row.required, row.delivered, row.reserved, row.carried, row.returned].all(func(value: Variant) -> bool: return value is int), "Loaded unit display differs from fresh ledger")
		var cargo: int = 0
		for member: Dictionary in data.members:
			if member.construction_id == data.project.id and member.cargo == kind: cargo += 1
		_expect(row.carried == cargo and row.delivered == data.project.delivered_materials[kind] and row.reserved == data.project.materials[kind], "Row differs from actual cargo/reservation/arrival: " + kind)
		_expect(int(row.required) == int(row.reserved) + int(row.delivered) + int(row.carried) + int(row.returned), "Row loses a paid unit: " + kind)
	view.materials.wood.delivered = 999
	_expect(data == before, "Viewing/mutating detached details changed ledger")

func _prepaid(data: Dictionary) -> void:
	for kind: String in ["tool", "garden"]:
		data.project = {"kind": kind, "progress": 2.0, "attempt_id": Tribe.Ids.create("construction")}
		for resource: String in Construction.costs(data.project): data.stock[resource] -= Construction.costs(data.project)[resource]
		var legacy: Dictionary = Construction.summary(data)
		var view: Dictionary = Details.read(data)
		_expect(not view.tracks_transport, "Prepaid project has a transport ledger")
		for resource: String in view.materials:
			_expect(legacy.materials[resource].delivered == legacy.materials[resource].required, "Baseline false-delivery reproduction no longer applies")
			_expect(view.materials[resource].delivered == null and view.materials[resource].carried == null and view.materials[resource].reserved == null, "Prepaid costs claimed physical delivery")
		_expect(Construction.command(data, "cancel").ok, "Cannot recover prepaid project")

func _panel_checks(data: Dictionary) -> void:
	var controller := PanelController.new()
	controller.data = data
	root.add_child(controller)
	var panel := ConstructionPanel.new()
	panel.controller = controller
	root.add_child(panel)
	var before: Dictionary = data.duplicate(true)
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		panel.refresh(data)
		_expect(not panel._details.text.contains("CONSTRUCTION_"), "Owner localization append not applied")
		_expect(panel._details.text.contains("nicht mengenweise" if locale == "de" else "not tracked per unit"), "Unknown installed amount not identified")
	_expect(data == before, "DE/EN refresh changed real ledger")
	panel.queue_free()
	controller.queue_free()
	await process_frame

func _end() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("R32_20_DETAILS_PASSED: %d checks; two simultaneous settlement sites, exact rows, blocked carrier, pause/recovery, fresh restart, prepaid display and DE/EN." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
