extends Node
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
	var source: String = saves.create_slot("Quellwelt", 15838)
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
	await _open(target)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var player: CharacterBody3D = scene.player
	_expect(player.creature_design.is_empty() and player.preview != null and Blueprint.load_best_available().name == design.name, "Original blueprint not used.")
	_expect(tree.get_first_node_in_group(&"region_background_simulation") == null, "Planar simulation ran on sphere.")
	_expect(saves.session_active and flow.can_pause() and saves.save_path == target, "Sphere did not join normal session/pause/save flow.")
	# Move through real physics, wait for streamed collision, then rebase twice
	# without converting Earth-scale positions into float32 world transforms.
	var before: Dictionary = player.location()
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
	for i in range(12): await tree.process_frame
	_expect(state.campaign.data.elapsed_seconds == paused_time and player.location() == paused_location, "Pause advanced campaign/player.")
	_expect(saves.save_now(), "Sphere pause save failed: " + saves.last_error)
	var checkpoint: Dictionary = saves._read_save(target)
	_expect(checkpoint.player.health_ratio == 0.7 and checkpoint.player.behavior_runtime.stamina == 31.0, "Unconnected needs/stamina were reset.")
	_expect(checkpoint.player.surface_address != before, "Movement did not persist its canonical location.")
	var expected := {"target": target, "source": source, "source_hash": text.sha256_text(), "saved": checkpoint}
	_expect(Atomic.write("user://sphere_campaign_restart.json", expected, false) == OK, "Restart evidence write failed.")
	flow.resume()
	flow.return_to_title()
	await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == flow.TITLE_SCENE and not saves.session_active, "Return to title did not release campaign.")
	var output: Array = []
	var arguments: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--sphere-smoke", "--sphere-restart"]
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code == 0 and str(output).contains("SPHERE_FRESH_PROCESS_PASSED"), "Fresh process failed: " + str(output))
	# Exercise the actual opt-in on the normal new-game form as well as copy
	# loading. It must create another campaign with its own design snapshot.
	tree.current_scene._show_new()
	tree.current_scene.find_child("AdventureName", true, false).text = "Neue Kugelkampagne"
	tree.current_scene.find_child("WorldSeed", true, false).text = "23757"
	tree.current_scene.find_child("SphericalCampaignChoice", true, false).button_pressed = true
	tree.current_scene.find_child("Begin", true, false).pressed.emit()
	var new_start: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - new_start < 50000: await tree.process_frame
	if _expect_world():
		_expect(saves.save_path != target and state.campaign.data.id != checkpoint.game_state.campaign.id, "Opt-in reused migrated campaign.")
		_expect(saves._design_files.is_empty(), "Opt-in inherited another campaign's design.")
		_expect(tree.root.get_node("AudioManager").director._player == null, "Planar audio sampled a radial floating origin.")
		flow.toggle_pause()
		flow.return_to_title()
		await tree.scene_changed
	await _finish()

func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://sphere_campaign_restart.json"))
	await _open(expected.target, true)
	if not _expect_world(): return
	# SessionFlow emits world_started before a physical movement step. Pause
	# immediately so restored position/velocity/time can be compared exactly.
	var player: CharacterBody3D = tree.current_scene.player
	var restored: Dictionary = player.export_runtime_state()
	var old: Dictionary = expected.saved.player
	_expect(Cube.local_position(Cube.cartesian(restored.surface_address, Surface.DEFAULT_RADIUS), Cube.cartesian(old.surface_address, Surface.DEFAULT_RADIUS)).length() < 0.002, "Fresh process relocated player.")
	_expect(Cube.vector(restored.surface_velocity).distance_to(Cube.vector(old.surface_velocity)) < 0.001, "Fresh process discarded in-flight velocity.")
	_expect(Migration.fingerprint(tree.root.get_node("ProgressionService").export_state()) == Migration.fingerprint(expected.saved.progression), "Restart changed progression.")
	_expect(saves._design_files == expected.saved.design_files, "Restart changed design revisions.")
	_expect(state.campaign.data.id == expected.saved.game_state.campaign.id, "Restart changed campaign identity.")
	var actual_map: Dictionary = state.get_current_body().exploration_atlas
	var expected_map: Dictionary = expected.saved.game_state.campaign.bodies[str(state.get_world_seed())].exploration_atlas
	if Migration.fingerprint(actual_map) != Migration.fingerprint(expected_map):
		print("MAP_RESTART_DIFFERENCE ", JSON.stringify({"actual": actual_map, "expected": expected_map,
			"disk": saves._read_save(expected.target).game_state.campaign.bodies[str(state.get_world_seed())].exploration_atlas}))
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
