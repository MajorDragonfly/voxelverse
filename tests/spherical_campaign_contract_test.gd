extends SceneTree
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Migration = preload("res://core/campaign/spherical_migration.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var failures: Array[String] = []
var saves: Node
var state: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.session_managed = true
	saves.autosave_enabled = false
	var source: String = saves.create_slot("Flachwelt", 15838)
	_expect(not source.is_empty(), "Could not create source.")
	if source.is_empty(): await _finish(); return
	var design: Dictionary = Blueprint.create_default()
	design.name = "Meine unveränderte Art"
	_expect(Blueprint.save_to_file(design) == OK, "Could not save authored design.")
	var body: Dictionary = state.get_current_body_record()
	var atlas := Atlas.new()
	atlas.bind(Atlas.create(body.id, Surface.LEGACY))
	atlas.reveal({"body_id": body.id, "mode": Surface.LEGACY, "position": [123.25, 10.0, -71.0]})
	body.exploration_atlas = atlas.data
	saves._last_player_state = {"position": [123.25, 10.0, -71.0], "yaw": 0.75, "health_ratio": 0.63,
		"hunger_ratio": 0.44, "thirst_ratio": 0.77, "behavior_runtime": {"stamina": 31.0, "recovery_delay": 0.2}}
	state.campaign.data.elapsed_seconds = 25.0
	_expect(saves.save_now(), "Could not save source design/map/runtime.")
	saves.session_active = false
	var data: Dictionary = saves._read_save(source)
	# Exercise the actual previous released format, not just new planar saves.
	data.schema = 7
	data.game_state.schema = 3
	data.game_state.erase("system_id")
	var legacy_bodies: Dictionary = {}
	for saved_body: Dictionary in data.game_state.campaign.bodies.values():
		legacy_bodies[str(int(saved_body.seed))] = saved_body
	data.game_state.campaign.bodies = legacy_bodies
	data.game_state.campaign.erase("body_lookup")
	data.regions_by_world = {}
	for record: Dictionary in data.regions_by_body.values():
		data.regions_by_world[str(int(record.world_seed))] = record
	data.erase("regions_by_body")
	data.game_state.campaign.schema = 1
	data.game_state.campaign.erase("surface_policy")
	data.game_state.campaign.erase("surface_migration")
	_expect(Atomic.write(source, data, false) == OK, "Could not write schema 7 fixture.")
	var source_text: String = FileAccess.get_file_as_string(source)
	var original_state: Dictionary = state.export_state()
	var plan: Dictionary = saves.preview_spherical_migration(source)
	_expect(plan.ok, "Early migration rejected: " + str(plan.get("blockers")))
	if not plan.ok: await _finish(); return
	_expect(state.export_state() == original_state and FileAccess.get_file_as_string(source) == source_text, "Preflight mutated live/source state.")
	_expect(saves.migrate_slot_to_sphere(source, "stale-hash").is_empty(), "Stale preview was committed.")
	var target: String = saves.migrate_slot_to_sphere(source, source_text.sha256_text())
	_expect(not target.is_empty() and target != source, "Copy was not committed: " + saves.last_error)
	if target.is_empty(): await _finish(); return
	var copied: Dictionary = saves._read_save(target)
	_expect(FileAccess.get_file_as_string(source) == source_text, "Migration changed source bytes.")
	_expect(Migration.inventory(copied) == Migration.inventory(data), "Migration lost identities, designs, regions, time or progression.")
	_expect(Migration.validate(copied.game_state.campaign.surface_migration).is_empty(), "Written manifest invalid.")
	var sphere: Dictionary = copied.game_state.campaign.bodies[str(state.get_world_seed())]
	_expect(sphere.id == body.id and sphere.seed == body.seed, "Body identity/seed replaced.")
	_expect(sphere.legacy_exploration_atlas == data.game_state.campaign.bodies[str(state.get_world_seed())].exploration_atlas and sphere.exploration_atlas.tiles.is_empty(), "Old map was lost or sphere pre-explored.")
	_expect(copied.player.position == data.player.position and copied.player.health_ratio == data.player.health_ratio and copied.player.behavior_runtime == data.player.behavior_runtime, "Player inventory/runtime changed.")
	_expect(Surface.location(copied.player.surface_address, body.id), "Player did not receive a canonical address.")
	var target_text: String = FileAccess.get_file_as_string(target)
	_expect(saves.migrate_slot_to_sphere(source, source_text.sha256_text()) == target and FileAccess.get_file_as_string(target) == target_text, "Repeated manifest duplicated or overwrote its copy.")
	_expect(saves.select_slot(target), "Sphere copy did not load.")
	_expect(state.campaign_scene() == Surface.SCENE and Blueprint.load_best_available().name == design.name, "Surface routing/design snapshot lost.")
	_expect(saves.save_now(), "Common SaveGameService could not resave sphere.")
	_expect(saves._read_save(target).player.surface_address == copied.player.surface_address, "Annotation replaced sphere coordinates with XYZ.")
	_expect(saves.select_slot(source) and state.campaign_scene() == "res://main/main.tscn", "Return to legacy source failed.")
	saves.session_active = false
	var recovered: String = saves.restore_spherical_source(target)
	_expect(not recovered.is_empty() and saves._read_save(recovered).design_files == data.design_files, "Complete source archive could not be recovered independently.")
	_expect(saves._read_save(recovered).game_state.campaign.bodies.values()[0].exploration_atlas == data.game_state.campaign.bodies.values()[0].exploration_atlas, "Archived planar map was not accessible through recovery.")
	_test_blockers(data)
	_test_future_and_failure(source, source_text, target, copied)
	var new_path: String = saves.create_slot("Neue Kugel", 23757, Cube.MODE)
	_expect(not new_path.is_empty() and state.get_current_body().id != body.id, "New sphere campaign failed or reused reference ID.")
	_expect(state.get_current_body().surface_context.radius == Surface.DEFAULT_RADIUS, "New sphere lost Earth scale.")
	_expect(saves._read_save(new_path).design_files.size() == 1 and Blueprint.load_best_available().design_id != design.design_id, "New campaign inherited migration designs or failed to freeze its default.")
	var default_id: String = Blueprint.load_best_available().design_id
	_expect(saves.select_slot(new_path) and Blueprint.load_best_available().design_id == default_id, "Reload regenerated the new campaign's default design ID.")
	await _finish()

func _test_blockers(data: Dictionary) -> void:
	var home: Dictionary = data.duplicate(true)
	var campaign: Dictionary = home.game_state.campaign
	var body: Dictionary = campaign.bodies.values()[0]
	body.home_group = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	_expect(saves._validate_save(home).is_empty(), "Valid home fixture rejected before preflight.")
	_expect(Migration.blockers(home).is_empty(), "Supported home was blocked before location checking.")
	var converted: Dictionary = Migration.plan(home, JSON.stringify(home), "user://home.json")
	_expect(converted.ok and converted.data.game_state.campaign.bodies.values()[0].home_group.members[0].id == body.home_group.members[0].id, "Home migration discarded its original member.")
	body.home_group.schema = 999
	_expect(saves._has_unsupported_contract(home), "Future home version not protected.")
	var unknown: Dictionary = data.duplicate(true)
	unknown.game_state.campaign.bodies.values()[0].future_possessions = {"owner": "saved"}
	_expect(str(Migration.blockers(unknown)).contains("future_possessions"), "Unknown ownership was silently lost.")
	unknown.regions_by_world = {"15838": {"regions": {"0:0": {"modified": true}}}}
	_expect(str(Migration.blockers(unknown)).contains("Regionen"), "Persistent region changes received no blocker.")
	unknown.game_state.phase = 1
	_expect(str(Migration.blockers(unknown)).contains("M1g"), "Tribe could be loaded through creature runtime.")
	var newer_design: Dictionary = data.duplicate(true)
	var encoded: Dictionary = JSON.parse_string(newer_design.design_files[Blueprint.SAVE_PATH])
	encoded.version = 999
	newer_design.design_files[Blueprint.SAVE_PATH] = JSON.stringify(encoded)
	_expect(saves._has_unsupported_contract(newer_design) and not Migration.blockers(newer_design).is_empty(), "Future player design was silently normalized.")

func _test_future_and_failure(source: String, source_text: String, target: String, copied: Dictionary) -> void:
	var future: Dictionary = copied.duplicate(true)
	future.game_state.campaign.bodies.values()[0].surface_context.schema = 999
	Atomic.write(target + ".bak", copied, false)
	Atomic.write(target, future, false)
	var future_text: String = FileAccess.get_file_as_string(target)
	_expect(not saves.inspect_slot(target).valid and not saves.load_now(target), "Future surface fell back to an older backup.")
	_expect(saves.migrate_slot_to_sphere(source, source_text.sha256_text()).is_empty() and FileAccess.get_file_as_string(target) == future_text, "Repeat migration overwrote future target.")
	var future_source: Dictionary = Atomic.parse_dictionary(source_text)
	future_source.schema = 999
	Atomic.write(source + ".bak", Atomic.parse_dictionary(source_text), false)
	Atomic.write(source, future_source, false)
	_expect(not saves.preview_spherical_migration(source).ok, "Future primary migrated its older backup.")
	Atomic._write_text(source, source_text)
	var corrupt: Dictionary = copied.duplicate(true)
	corrupt.game_state.campaign.surface_migration.source_text += " "
	_expect(not saves._validate_save(corrupt).is_empty(), "Damaged archive was accepted.")
	corrupt = copied.duplicate(true)
	corrupt.player.surface_address.body_id = "another-body"
	_expect(not saves._validate_save(corrupt).is_empty(), "Cross-body player location accepted.")
	corrupt = copied.duplicate(true)
	corrupt.player.surface_address.u = INF
	_expect(not saves._validate_save(corrupt).is_empty(), "Infinite surface position accepted.")
	corrupt = copied.duplicate(true)
	corrupt.game_state.campaign.bodies.values()[0].surface_context.radius = 50000.0
	_expect(not saves._validate_save(corrupt).is_empty(), "Changed migration radius invalidated all places without rejection.")
	# A filesystem blocker at the staging path must leave the source and slot
	# list intact, with no apparent successfully migrated adventure.
	DirAccess.remove_absolute(target)
	DirAccess.remove_absolute(target + ".bak")
	DirAccess.make_dir_recursive_absolute(target + ".migration-stage")
	_expect(saves.migrate_slot_to_sphere(source, FileAccess.get_file_as_string(source).sha256_text()).is_empty(), "Blocked staging write succeeded.")
	_expect(not FileAccess.file_exists(target), "Failed stage published a target.")
	_expect(FileAccess.get_file_as_string(source) == source_text, "Failure changed source bytes.")

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SPHERICAL_CAMPAIGN_CONTRACT_PASSED: shared slots, source/identity/design preservation, atomic copy, manifest, idempotence, blockers and future guards.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
