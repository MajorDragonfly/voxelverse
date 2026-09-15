extends SceneTree
const Participants = preload("res://core/persistence/save_participants.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const BodyRegistry = preload("res://core/campaign/body_registry.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Animals = preload("res://world/domestication/campaign_animal_state.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const SAVE: String = "user://participant_roundtrip.json"
const EXPECTED: String = "user://participant_expected.json"
var failures: Array[String] = []
var saves: Node
var state: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.session_managed = true
	saves.session_active = true
	saves.autosave_enabled = false
	saves.save_path = SAVE
	if "--participant-restart" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process could not import participants: " + saves.last_error)
		_compare(Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED)))
		await _finish()
		return
	_expect(Participants.registration_problem(saves).is_empty(), "Live save hooks are incomplete.")
	var incomplete := Node.new()
	_expect(not Participants.registration_problem(incomplete).is_empty(), "Missing hooks were accepted.")
	incomplete.free()
	state.start_world_with_seed(15838)
	var body: Dictionary = state.get_current_body_record()
	var campaign: Dictionary = state.campaign.data
	body.home_group = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	body.home_group.members[0].order = "home"
	body.tribe = Tribe.create(body.home_group, campaign, {"position": [0, 0, 0]},
		{"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	body.tribe.members[0].merge({"cargo": "wood", "order": "wait", "paused_order": "wood", "stage": "return", "work": 1.25}, true)
	body.tribe.deposits.wood.remaining -= 1
	body.domesticated_animals = Animals.create(campaign, body)
	var atlas := Atlas.new()
	atlas.bind(Atlas.create(body.id, Participants.Surface.LEGACY))
	atlas.reveal({"body_id": body.id, "mode": Participants.Surface.LEGACY, "position": [2, 0, 2]})
	body.exploration_atlas = atlas.data
	saves.guidance.reset(true)
	saves.guidance.record("move", 2.5)
	saves._last_player_state = {"position": [0, 0, 0], "yaw": 0.7, "health_ratio": 0.63,
		"behavior_runtime": {"stamina": 31.0, "recovery_delay": 0.2}}
	_expect(saves.save_now(), "Joint participant snapshot failed: " + saves.last_error)
	if not failures.is_empty(): await _finish(); return
	var expected: Dictionary = saves._read_save(SAVE)
	var before: String = JSON.stringify(expected)
	_expect(Participants.unknown_section(expected).is_empty(), "Exporter wrote an unregistered field.")
	_expect(saves._validate_save(expected).is_empty() and not saves._has_unsupported_contract(expected), "Current participants rejected.")
	_expect(JSON.stringify(expected) == before, "Read-only validation migrated or mutated data.")
	_expect(Atomic.write(EXPECTED, expected, false) == OK, "Could not write restart expectation.")
	body.home_group.members.clear()
	body.tribe.stock.wood = 900
	saves.guidance.reset()
	_expect(saves.load_now(), "Load could not replace edited live state.")
	_compare(expected)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--participant-restart"], output, true)
	_expect(code == 0 and str(output).contains("SAVE_PARTICIPANTS_PASSED") and not str(output).contains("SCRIPT ERROR"), "Fresh process lost participants: " + str(output))
	# Independent list: removing a registration must make this check fail.
	for field in ["village_simulation", "visit", "home_group", "legacy_population", "wildlife_foraging", "wildlife_drinking",
		"surface_ecology", "fauna_catalog", "surface_population", "domesticated_animals", "exploration_atlas", "legacy_exploration_atlas", "tribe", "tribal_neighbor"]:
		var future: Dictionary = expected.duplicate(true)
		BodyRegistry.active(future.game_state)[field] = {"schema": 999}
		_protect(future, expected, "future " + field)
	var future_progression: Dictionary = expected.duplicate(true)
	future_progression.progression.schema = 999
	_protect(future_progression, expected, "future progression")
	for field in ["unregistered_module", ""]:
		var unknown: Dictionary = expected.duplicate(true)
		unknown[field] = {"schema": 1, "valuable_state": 42}
		_expect(not saves._validate_save(unknown).is_empty(), "Unknown top-level field passed validation.")
		_protect(unknown, expected, "unregistered field")
	var unknown_body: Dictionary = expected.duplicate(true)
	BodyRegistry.active(unknown_body.game_state).unregistered_module = {"schema": 1, "valuable_state": 42}
	_expect(not saves._validate_save(unknown_body).is_empty(), "Unregistered body module passed validation.")
	_protect(unknown_body, expected, "unregistered body module")
	# Existing optional onboarding policy is deliberately different: future UI
	# data is retained opaquely and does not block the campaign.
	var optional: Dictionary = expected.duplicate(true)
	optional.onboarding = {"schema": 999, "future_guide": ["retained"]}
	Atomic.write(SAVE, optional, false)
	_expect(saves.load_now() and saves.save_now(), "Optional future guide blocked the campaign.")
	_expect(_json_value(saves._read_save(SAVE).onboarding) == _json_value(optional.onboarding), "Optional future guide was discarded.")
	await _finish()

func _protect(future: Dictionary, previous: Dictionary, label: String) -> void:
	_expect(Atomic.write(SAVE + ".bak", previous, false) == OK and Atomic.write(SAVE, future, false) == OK, "Could not prepare " + label)
	var original: String = FileAccess.get_file_as_string(SAVE)
	var backup: String = FileAccess.get_file_as_string(SAVE + ".bak")
	var live: Dictionary = state.export_state()
	_expect(saves._has_unsupported_contract(future), "Missing version guard: " + label)
	_expect(not saves.load_now() and not saves.save_now(), "Future field fell back or was overwritten: " + label)
	_expect(state.export_state() == live and FileAccess.get_file_as_string(SAVE) == original and FileAccess.get_file_as_string(SAVE + ".bak") == backup, "Protection mutated live state/original/backup: " + label)
	Atomic.write(SAVE, previous, false)
	_expect(saves.load_now(), "Compatible recovery remained blocked: " + label)

func _compare(expected: Dictionary) -> void:
	var current: Dictionary = state.get_current_body_record()
	var saved: Dictionary = BodyRegistry.active(expected.game_state)
	for field in ["home_group", "tribe", "domesticated_animals", "exploration_atlas"]:
		_expect(JSON.stringify(current[field]) == JSON.stringify(saved[field]), "Import changed " + field)
	_expect(_json_value(root.get_node("ProgressionService").export_state()) == _json_value(expected.progression), "Import changed progression.")
	_expect(_json_value(saves.guidance.export_state()) == _json_value(expected.onboarding), "Import changed onboarding.")
	_expect(saves._last_player_state == expected.player and saves._pending_player_state == expected.player, "Import lost pending player state.")
	_expect(saves._regions_by_body == expected.regions_by_body and saves._design_files == expected.design_files, "Import lost regions or design bytes.")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for message in failures: push_error(message)
	if failures.is_empty(): print("SAVE_PARTICIPANTS_PASSED: shared snapshot, fresh process, registration, future guards and optional guide preservation.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _json_value(value: Variant) -> Variant:
	# JSON restores numbers as floats; compare equal persisted values rather
	# than the owner's reconstructed int/float runtime representation.
	return JSON.parse_string(JSON.stringify(value))
