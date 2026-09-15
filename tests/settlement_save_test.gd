extends "res://tests/settlement_collection_test.gd"
## Native save participant cases; geometry fixtures are synthetic. Actual
## movement and route certification belong to settlement_runtime_test.
const SAVE: String = "user://second-site-save.json"
const EVIDENCE: String = "user://second-site-save-expected.json"

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	state.set_process(false)
	if "--second-site-save-restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EVIDENCE))
		_expect(saves.load_now(SAVE), "Native collection reload failed: " + saves.last_error)
		_expect(_fingerprint(state.export_state()) == _fingerprint(expected.state), "Native restart lost construction, work clocks or held cargo.")
		var body: Dictionary = state.get_current_body_record()
		var ids: Array = Settlements.ids(body)
		for id: String in ids:
			var view: Dictionary = Settlements.view(body, id)
			view.village_simulation.owner = "far"
			for member: Dictionary in view.tribe.members: member.blocked = false
			for tick in range(320): Simulation.advance(view, 180.0)
			_expect(view.tribe.huts == 1 and view.tribe.project.is_empty(), "Construction failed to resume: " + id)
			_expect(Tribe.cargo_count(view.tribe, "wood") == 0 and view.tribe.stock.wood == 0, "Construction freight duplicated into stock: " + id)
		state.campaign.data.elapsed_seconds = 180.0
		_expect(Settlements.validate(body, state.campaign.data).is_empty(), "Resumed construction invalidated native collection.")
		_expect(saves.save_now(SAVE), "Resumed construction did not save: " + saves.last_error)
		await _done()
		return
	var slot: String = saves.create_slot("Save-only two-site fixture", 15838, Home.Cube.MODE)
	_expect(not slot.is_empty(), "Could not create native radial save.")
	saves.save_path = SAVE
	state.current_phase = 1
	state.campaign.data.elapsed_seconds = 100.0
	var campaign: Dictionary = state.campaign.data
	var body: Dictionary = state.get_current_body_record()
	var anchor: Dictionary = body.surface_context.spawn.duplicate(true)
	anchor.radius = body.surface_context.radius
	var home: Dictionary = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	home.merge({"schema": Home.SCHEMA, "surface_mode": Home.Cube.MODE, "anchor": anchor}, true)
	for member: Dictionary in home.members: member.position = Home.offset_place(anchor, Home.vector(member.position))
	body.home_group = home
	body.tribe = Tribe.create(home, campaign, {"surface_address": anchor}, _sites(anchor))
	_well(body.tribe, 2)
	var founder: Dictionary = body.tribe.members[2]
	var target: Dictionary = Home.offset_place(anchor, Vector3(17, 0, 0))
	founder.position = target.duplicate(true)
	founder.destination = target.duplicate(true)
	_certify(body, campaign)
	body.village_simulation.owner = "near"
	var source: Dictionary = body.duplicate(true)
	for mode: String in ["player", "cargo", "too_close", "far_away", "wrong_body"]:
		var proposed: Dictionary = source.duplicate(true)
		var position: Dictionary = target.duplicate(true)
		var identity: String = founder.id
		match mode:
			"player": identity = campaign.player_object_id
			"cargo":
				proposed.tribe.members[2].cargo = "wood"
				proposed.tribe.deposits.wood.remaining -= 1
			"too_close": position = anchor
			"far_away": position = Home.offset_place(anchor, Vector3(100, 0, 0))
			"wrong_body": position.body_id = "another-body"
		var before: String = _fingerprint(proposed)
		_expect(not Settlements.found(proposed, campaign, identity, position, _sites(target)).ok and _fingerprint(proposed) == before, "Invalid founding modified live data: " + mode)
	var result: Dictionary = Settlements.found(body, campaign, founder.id, target, _sites(target))
	_expect(result.ok, "Founding model failed: " + str(result))
	if not result.ok: await _done(); return
	body.clear()
	body.merge(result.body)
	_expect(not Settlements.found(body, campaign, founder.id, target, _sites(target)).ok, "Third site exceeded the instance budget.")
	var growth_fixture: Dictionary = body.duplicate(true)
	var extra_ids: Array = []
	for index in range(3):
		var identity: String = Settlements.next_resident_id(growth_fixture)
		_expect(not identity.is_empty() and identity not in extra_ids, "Growth reused an existing identity.")
		extra_ids.append(identity)
		var place_id: String = Settlements.ids(growth_fixture)[index % 2]
		var resident: Dictionary = Settlements.village(growth_fixture, place_id).members[0].duplicate(true)
		resident.id = identity
		Settlements.village(growth_fixture, place_id).members.append(resident)
	_expect(Settlements.resident_count(growth_fixture) == 6 and Settlements.next_resident_id(growth_fixture).is_empty(), "Growth exceeded the shared six-resident budget.")
	var second: String = result.settlement_id
	var ids: Array = Settlements.ids(body)
	_well(Settlements.village(body, second), 0)
	for id: String in ids:
		var view: Dictionary = Settlements.view(body, id)
		_project(view.tribe, view.tribe.members.back())
		_certify(view, campaign)
		for member: Dictionary in view.tribe.members: member.blocked = true
		view.tribe.project.progress = 0.0
		view.tribe.members.back().work = 0.75
	_expect(Settlements.validate(body, campaign).is_empty(), "Two native constructions are invalid: " + Settlements.validate(body, campaign))
	_expect(saves.save_now(), "Native registered save failed: " + saves.last_error)
	var committed: String = FileAccess.get_file_as_string(SAVE)
	DirAccess.make_dir_absolute(SAVE + ".tmp")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(SAVE) == committed, "Failed native write replaced committed jobs.")
	DirAccess.remove_absolute(SAVE + ".tmp")
	_expect(saves.load_now(), "Native same-process reload failed.")
	body = state.get_current_body_record()
	_expect(not body.has("tribe") and not body.has("village_simulation"), "Native reload created a second authority.")
	# Verify the return preflight drains BOTH village cursors with the player
	# absent even when the secondary site is selected. No real travel claim.
	Settlements.select(body, second)
	for id: String in ids:
		var view: Dictionary = Settlements.view(body, id)
		view.village_simulation.owner = "far"
		view.village_simulation.cursor = 99.0
	var player_before: Dictionary = Settlements.player_member(body, state.campaign.data).duplicate(true)
	var original: Dictionary = state.export_state()
	saves._body_transfer = {"player": saves._export_player_state()}
	_expect(await saves.prepare_body_target(state.system_seed, state.current_planet_index, state.world_seed, body.id), "Collection return preflight failed: " + saves.last_error)
	for id: String in ids: _expect(Settlements.view(body, id).village_simulation.cursor == 100.0, "Return left old work debt at " + id)
	_expect(Settlements.player_member(body, state.campaign.data) == player_before, "Returning player worked while absent.")
	saves._body_transfer.clear()
	state.import_state(original)
	_expect(saves.save_now(SAVE), "Could not checkpoint native restart state.")
	var expected: Dictionary = {"state": Atomic.parse_dictionary(Atomic.stringify(state.export_state()))}
	_expect(Atomic.write(EVIDENCE, expected, false) == OK, "Restart metadata write failed.")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--second-site-save-restart"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Native process restart failed: " + str(output))
	print(str(output))
	await _done()

func _done() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("SETTLEMENT_SAVE_PASSED: %d checks; native save, two constructions, conserved freight, invalid founding, return debt and fresh process." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
