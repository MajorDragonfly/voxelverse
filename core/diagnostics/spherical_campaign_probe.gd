extends Node
const Registry = preload("res://core/campaign/body_registry.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Migration = preload("res://core/campaign/spherical_migration.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var tree: SceneTree
var failures: Array[String] = []
var saves: Node
var state: Node
var flow: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tree = get_tree()
	call_deferred("_run")

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var restarting: bool = "--sphere-restart" in OS.get_cmdline_user_args()
	if restarting:
		await _restart()
		await _finish()
		return
	var source: String = saves.create_slot("Quellwelt", 15838, Surface.LEGACY)
	var design: Dictionary = Blueprint.create_default()
	design.name = "Originaldesign beim Neustart"
	Blueprint.save_to_file(design)
	saves._last_player_state = {"position": [42.0, 19.0, -85.0], "yaw": 0.4, "health_ratio": 0.7,
		"hunger_ratio": 0.6, "thirst_ratio": 0.5, "behavior_runtime": {"stamina": 31.0}}
	_expect(saves.save_now(), "Source save failed.")
	saves.session_active = false
	var text: String = FileAccess.get_file_as_string(source)
	var target: String = saves.migrate_slot_to_sphere(source, text.sha256_text())
	_expect(not target.is_empty(), "Migration failed: " + saves.last_error)
	if target.is_empty(): await _finish(); return
	# Public loading must migrate the old source and reuse the existing copy.
	await _open(source)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var player: CharacterBody3D = scene.player
	_expect(player.creature_design.design_id == design.design_id and player.preview != null and Blueprint.load_best_available().name == design.name, "Original blueprint not used.")
	_expect(tree.get_first_node_in_group(&"region_background_simulation") == null, "Planar simulation ran on sphere.")
	_expect(saves.session_active and flow.can_pause() and saves.save_path == target, "Sphere did not join normal session/pause/save flow.")
	# Move through real physics, wait for streamed collision, then rebase twice
	# without converting Earth-scale positions into float32 world transforms.
	var before: Dictionary = player.location()
	var initial_needs: Dictionary = player.export_runtime_state()
	_expect(is_equal_approx(initial_needs.health_ratio, 0.7) and initial_needs.behavior_runtime.stamina >= 31.0, "Shared player lost imported survival values.")
	Input.action_press("move_forward")
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 2200:
		await tree.physics_frame
	Input.action_release("move_forward")
	_expect(player.traveled > 2.0, "Bound movement did not advance through physical terrain.")
	var point: Array = Cube.cartesian(player.location(), Surface.DEFAULT_RADIUS)
	for offset in [Vector3(70, -35, 17), Vector3(-20, 90, -53)]:
		scene.terrain.rebase([point[0] + offset.x, point[1] + offset.y, point[2] + offset.z])
		_expect(Cube.local_position(Cube.cartesian(player.location(), Surface.DEFAULT_RADIUS), point).length() < 0.002, "Origin shift moved persistent player.")
	var tracker: Node = tree.get_first_node_in_group(&"exploration_tracker")
	tracker.update_exploration()
	_expect(tracker.atlas.data.mode == Cube.MODE and not tracker.atlas.data.tiles.is_empty(), "Common map did not retain actual sphere exploration.")
	flow.toggle_pause()
	var paused_time: float = state.campaign.data.elapsed_seconds
	var paused_location: Dictionary = player.location()
	var paused_needs: Dictionary = player.export_runtime_state()
	for i in range(12): await tree.process_frame
	_expect(state.campaign.data.elapsed_seconds == paused_time and player.location() == paused_location, "Pause advanced campaign/player.")
	_expect(player.export_runtime_state() == paused_needs, "Pause advanced survival or stamina.")
	_expect(saves.save_now(), "Sphere pause save failed: " + saves.last_error)
	var checkpoint: Dictionary = saves._read_save(target)
	_expect(is_equal_approx(checkpoint.player.health_ratio, 0.7) and checkpoint.player.hunger_ratio < initial_needs.hunger_ratio and checkpoint.player.thirst_ratio < initial_needs.thirst_ratio and checkpoint.player.behavior_runtime.stamina > initial_needs.behavior_runtime.stamina, "Shared survival/recovery did not advance during active play.")
	_expect(checkpoint.player.surface_address != before, "Movement did not persist its canonical location.")
	var expected := {"target": target, "source": source, "source_hash": text.sha256_text(), "saved": checkpoint}
	_expect(Atomic.write("user://sphere_campaign_restart.json", expected, false) == OK, "Restart evidence write failed.")
	flow.resume()
	flow.return_to_title()
	await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == flow.TITLE_SCENE and not saves.session_active, "Return to title did not release campaign.")
	var output: Array = []
	var arguments: PackedStringArray = ["--headless"]
	# Official release templates intentionally disallow --path overrides. Their
	# own adjacent PCK is authoritative; only source editor probes need --path.
	if OS.has_feature("editor"): arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--", "--sphere-smoke", "--sphere-restart"])
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code == 0 and str(output).contains("SPHERE_FRESH_PROCESS_PASSED"), "Fresh process failed: " + str(output))
	# Exercise the only normal new-game form as well as automatic copy
	# loading. It must create another campaign with its own design snapshot.
	var slots_before: int = saves.list_slots().size()
	flow.new_game("Removed planar entry", 15838, Surface.LEGACY)
	_expect(not flow.loading and saves.list_slots().size() == slots_before, "Public new game still created a plane.")
	tree.current_scene._show_new()
	tree.current_scene.find_child("AdventureName", true, false).text = "Neue Kugelkampagne"
	tree.current_scene.find_child("WorldSeed", true, false).text = "23757"
	_expect(tree.current_scene.find_child("SphericalCampaignChoice", true, false) == null, "Obsolete surface choice is still visible.")
	tree.current_scene.find_child("Begin", true, false).pressed.emit()
	var new_start: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - new_start < 50000: await tree.process_frame
	if _expect_world():
		var flora_start: int = Time.get_ticks_msec()
		while tree.current_scene.flora.instance_count() == 0 and Time.get_ticks_msec() - flora_start < 30000:
			await tree.process_frame
		_expect(tree.current_scene.flora.instance_count() > 0, "Default campaign loaded no vegetation.")
		_expect(saves.save_path != target and state.campaign.data.id != checkpoint.game_state.campaign.id, "Default entry reused migrated campaign.")
		_expect(saves._design_files.size() == 1 and Blueprint.load_best_available().design_id != design.design_id, "Default entry did not freeze its own distinct default design.")
		_expect(tree.root.get_node("AudioManager").director._player == tree.current_scene.player, "Shared audio did not bind the radial player.")
		_expect(tree.root.get_node("AudioManager").director.sample_at(tree.current_scene.player.global_position).has("water_point"), "Audio lacks body-bound water coordinates.")
		await _lab_round_trip()
		flow.toggle_pause()
		flow.return_to_title()
		await tree.scene_changed
	await _finish()

func _lab_round_trip() -> void:
	var id: String = state.campaign.data.id
	var path: String = saves.save_path
	_expect(tree.current_scene.get_node("DevelopmentTools")._open_planet_lab(), "F4 diagnostic entry failed.")
	await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == "res://world/planet_lab/planet_lab.tscn", "F4 did not reach the diagnostic lab.")
	var source_text: String = FileAccess.get_file_as_string(path)
	tree.current_scene.return_to_game()
	var started: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - started < 50000: await tree.process_frame
	if _expect_world():
		_expect(state.campaign.data.id == id and saves.save_path == path, "Lab return switched campaign or save.")
		_expect(FileAccess.get_file_as_string(path) == source_text, "Diagnostic lab wrote into the campaign before normal autosave.")

func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://sphere_campaign_restart.json"))
	await _open(expected.target, true)
	if not _expect_world(): return
	# SessionFlow emits world_started before a physical movement step. Pause
	# immediately so restored position/velocity/time can be compared exactly.
	var player: CharacterBody3D = tree.current_scene.player
	var restored: Dictionary = player.export_runtime_state()
	var old: Dictionary = expected.saved.player
	for field in ["health_ratio", "hunger_ratio", "thirst_ratio"]:
		_expect(is_equal_approx(float(restored[field]), float(old[field])), "Fresh process changed survival: " + field)
	_expect(Migration.fingerprint(restored.behavior_runtime) == Migration.fingerprint(old.behavior_runtime), "Fresh process changed stamina.")
	_expect(Cube.local_position(Cube.cartesian(restored.surface_address, Surface.DEFAULT_RADIUS), Cube.cartesian(old.surface_address, Surface.DEFAULT_RADIUS)).length() < 0.002, "Fresh process relocated player.")
	_expect(Cube.vector(restored.surface_velocity).distance_to(Cube.vector(old.surface_velocity)) < 0.001, "Fresh process discarded in-flight velocity.")
	_expect(Migration.fingerprint(tree.root.get_node("ProgressionService").export_state()) == Migration.fingerprint(expected.saved.progression), "Restart changed progression.")
	_expect(saves._design_files == expected.saved.design_files, "Restart changed design revisions.")
	_expect(state.campaign.data.id == expected.saved.game_state.campaign.id, "Restart changed campaign identity.")
	var actual_map: Dictionary = state.get_current_body().exploration_atlas
	var expected_map: Dictionary = Registry.active(expected.saved.game_state).exploration_atlas
	if Migration.fingerprint(actual_map) != Migration.fingerprint(expected_map):
		print("MAP_RESTART_DIFFERENCE ", JSON.stringify({"actual": actual_map, "expected": expected_map,
			"disk": Registry.active(saves._read_save(expected.target).game_state).exploration_atlas}))
		_expect(false, "Restart changed visited map cells.")
	_expect(FileAccess.get_file_as_string(expected.source).sha256_text() == expected.source_hash, "Restart modified original source.")
	_expect(saves.save_now(), "Fresh-process save failed.")
	if failures.is_empty(): print("SPHERE_FRESH_PROCESS_PASSED")
	flow.resume()
	flow.return_to_title()
	await tree.scene_changed

func _open(path: String, pause_when_ready: bool = false) -> void:
	tree.change_scene_to_file(flow.TITLE_SCENE)
	await tree.scene_changed
	if pause_when_ready: flow.world_started.connect(flow.toggle_pause, CONNECT_ONE_SHOT)
	flow.load_game(path)
	var start: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - start < 50000:
		await tree.process_frame
	saves.autosave_enabled = false

func _expect_world() -> bool:
	var valid: bool = tree.current_scene != null and tree.current_scene.scene_file_path == Surface.SCENE and tree.current_scene.world_initialized and not flow.loading
	_expect(valid, "Sphere campaign did not finish loading: " + str(saves.last_error))
	return valid

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	tree.paused = false
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SPHERICAL_CAMPAIGN_RUNTIME_PASSED: actual entry, original design, physics, rebase, shared map/pause/save, fresh-process resume and return path.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
