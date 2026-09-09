extends SceneTree
const Registry = preload("res://core/campaign/body_registry.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Factory = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const SAVE: String = "user://body_identity.json"
var failures: Array[String] = []
var state: Node
var saves: Node
var progression: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	progression = root.get_node("ProgressionService")
	saves.autosave_enabled = false
	saves.session_managed = true
	saves.session_active = true
	saves.save_path = SAVE
	if "--restart-check" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process could not read body-scoped save.")
		_check_saved_bodies()
		await _finish()
		return
	state.start_world_with_seed(15838)
	var a: Dictionary = state.get_current_body()
	var b: Dictionary = state.campaign.ensure_body(15838, 23757)
	_expect(a.id != b.id and a.system_id != b.system_id, "Same seed in different systems collided.")
	var count: int = state.campaign.data.bodies.size()
	_expect(state.campaign.find_body(999, a.system_id).is_empty() and state.campaign.get_body_by_id("missing").is_empty(), "Missing-body read returned a generated body.")
	_expect(state.campaign.data.bodies.size() == count, "Read allocated campaign state.")
	for record in [a, b]:
		var body: Dictionary = state.campaign.body_record(record.id)
		body.home_group = Home.create(body.id, state.campaign.data.player_species_id, Vector3.ZERO)
		body.tribe = Tribe.create(body.home_group, state.campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
		body.tribe.stock.wood = 7 if record.id == a.id else 19
		body.tribe.deposits.wood.remaining -= body.tribe.stock.wood
		body.tribe.delivered = body.tribe.stock.wood
	_expect(progression.register_species_scan(77, Factory.create_species(77)).is_new, "First body's scan missing.")
	var a_key: String = progression.species_discovery_key(77)
	_expect(state.activate_body(b.id, 23757, 0, false), "Could not activate existing B.")
	_expect(not progression.has_species_scan(77), "B inherited A's scan.")
	_expect(progression.register_species_scan(77, Factory.create_species(77)).is_new, "B's identical species seed was deduplicated against A.")
	_expect(a_key != progression.species_discovery_key(77), "Discovery keys ignored body identity.")
	var points: int = progression.discovery_points
	_expect(state.activate_body(a.id, 15838, 0, false) and progression.has_species_scan(77), "A-B-A lost original scan.")
	_expect(not progression.register_species_scan(77, Factory.create_species(77)).is_new and progression.discovery_points == points, "Revisit awarded discovery twice.")
	_expect(saves.save_now(), "Body-scoped save failed: " + saves.last_error)
	if not FileAccess.file_exists(SAVE): await _finish(); return
	_check_saved_bodies()
	_legacy_and_invalid(a)
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--restart-check"])
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--restart-pack" in user_args:
		args = PackedStringArray(["--headless", "--main-pack", user_args[user_args.find("--restart-pack") + 1], "--script", get_script().resource_path, "--", "--restart-check"])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh-process isolation failed: " + str(output))
	var good: Dictionary = saves._read_save(SAVE)
	var foreign: Dictionary = good.duplicate(true)
	foreign.game_state.system_id = "wrong-system"
	_expect(not saves._validate_save(foreign).is_empty(), "Foreign active system accepted.")
	foreign = good.duplicate(true)
	foreign.progression.discovered_species.values()[0].body_id = "missing-body"
	_expect(not saves._validate_save(foreign).is_empty(), "Foreign discovery owner accepted.")
	foreign = good.duplicate(true)
	foreign.game_state.campaign.bodies["duplicate"] = foreign.game_state.campaign.bodies.values()[0].duplicate(true)
	Atomic.write(SAVE + ".bak", good, false)
	Atomic.write(SAVE, foreign, false)
	var protected_text: String = FileAccess.get_file_as_string(SAVE)
	var before: Dictionary = state.export_state()
	_expect(not saves.inspect_slot(SAVE).valid and not saves.load_now(), "Ambiguous primary silently loaded its backup.")
	_expect(state.export_state() == before and not saves.save_now() and FileAccess.get_file_as_string(SAVE) == protected_text, "Ambiguous identity mutated live state or source.")
	await _finish()

func _check_saved_bodies() -> void:
	var seen: Array[int] = []
	for body: Dictionary in state.campaign.data.bodies.values():
		seen.append(int(body.tribe.stock.wood))
	seen.sort()
	_expect(seen == [7, 19], "Independent village inventories did not survive.")
	_expect(progression.discovered_species.size() == 2, "Independent discoveries did not survive.")
	_expect(Registry.validate(state.campaign.data).is_empty(), "Saved body index invalid.")

func _legacy_and_invalid(a: Dictionary) -> void:
	var legacy: Dictionary = state.export_state()
	legacy.schema = 3
	legacy.erase("system_id")
	legacy.campaign.schema = 2
	legacy.campaign.erase("body_lookup")
	legacy.campaign.bodies = {str(int(a.seed)): state.campaign.body_record(a.id).duplicate(true)}
	legacy.campaign.id = "copied-slot-with-preserved-opaque-ids"
	var source: Dictionary = {"schema": 8, "game_state": legacy, "regions_by_world": {str(int(a.seed)): {"world_seed": a.seed, "body_id": a.id, "regions": {}}}}
	var before: Dictionary = source.duplicate(true)
	var converted: Dictionary = Registry.upgrade_save(JSON.parse_string(JSON.stringify(source)))
	_expect(converted.ok and source == before, "Legacy conversion failed or mutated source.")
	if converted.ok:
		_expect(preload("res://core/campaign/spherical_migration.gd").fingerprint(converted.data.game_state.campaign.bodies[a.id]) == preload("res://core/campaign/spherical_migration.gd").fingerprint(before.game_state.campaign.bodies[str(int(a.seed))]), "Migration rewrote IDs, orders or inventory.")
		_expect(converted.data.game_state.system_id == a.system_id and converted.data.regions_by_body.has(a.id), "Copied legacy slot lost its original system/regions.")
	var model := Campaign.new()
	model.reset("unchanged")
	var original: Dictionary = model.export_state()
	var invalid: Dictionary = state.campaign.export_state()
	invalid.schema = 99
	_expect(not model.import_state(invalid) and model.data == original, "Future register was partially imported.")
	invalid = state.campaign.export_state()
	invalid.body_lookup.clear()
	_expect(not model.import_state(invalid) and model.data == original, "Damaged derived index was silently repaired.")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("BODY_IDENTITY_PASSED: same-seed systems, independent inventories/discoveries, A-B-A, fresh process, legacy ID preservation and protected ambiguity.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
