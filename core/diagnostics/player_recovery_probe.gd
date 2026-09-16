extends "res://core/diagnostics/spherical_creature_probe.gd"
const EXPECTED: String = "user://recovery_expected.json"
var returns: int = 0

func _run() -> void:
	print("RECOVERY_STAGE: start ", OS.get_process_id(), " ", OS.get_cmdline_user_args())
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--recovery-restart" in OS.get_cmdline_user_args():
		await _restart()
		return
	var path: String = saves.create_slot("Recovery on a sphere", 15838, Cube.MODE)
	await _open(path)
	print("RECOVERY_STAGE: opened")
	if not _expect_world(): await _finish_recovery_test(); return
	var scene: Node3D = tree.current_scene
	var player: CharacterBody3D = scene.player
	player.hunger_loss_per_second = 0.0
	player.thirst_loss_per_second = 0.0
	await _until(func(): return player.is_on_floor(), 15000)
	var home: Node = scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().get("ok", false), "Could not establish original home")
	await _until(func(): return home.actors.size() == 2, 10000)
	print("RECOVERY_STAGE: home established")
	var group: Dictionary = state.get_current_body_record().home_group.duplicate(true)
	var progression: Dictionary = tree.root.get_node("ProgressionService").export_state().duplicate(true)
	var design: Dictionary = Blueprint.load_best_available().duplicate(true)
	var anchor: Dictionary = group.anchor
	var distant: Dictionary = scene.adapter.offset(anchor, scene.adapter.frame_at(anchor) * Vector3(220, 0, 0), 0.1)
	player.place(distant)
	await tree.physics_frame
	await tree.physics_frame
	player.respawn_delay = 0.2
	player.respawned.connect(func(): returns += 1)
	player.receive_damage(100000)
	flow.toggle_pause()
	var remaining: float = player.recovery.remaining
	await tree.create_timer(0.3).timeout
	_expect(player.is_dead and player.recovery.remaining == remaining and returns == 0, "Real pause consumed return countdown")
	_expect(saves.save_now(), "Could not save pending death: " + saves.last_error)
	var disk: Dictionary = saves._read_save(path)
	_expect(disk.player.health_ratio == 0.0, "Dead save lost pending recovery marker")
	flow.resume()
	await _until(func(): return returns == 1, 35000)
	print("RECOVERY_STAGE: returned ", returns, " failures ", failures)
	_expect(returns == 1 and not player.is_dead, "Radial recovery did not finish")
	_expect(Home.distance(_radius(player.location()), anchor) < 8.0, "Recovery did not use canonical home after distant rebase")
	_expect(Space.ground_ready(player, player.global_position) and not Space.floor_hit(player, player.global_position).is_empty(), "Player revived before real ground existed")
	_expect(player.up_direction.dot(scene.adapter.up_at(player.location())) > 0.999, "Recovery used global Y instead of radial up")
	_expect(player.get_health_ratio() == 1.0 and player.get_hunger_ratio() == 1.0 and player.get_thirst_ratio() == 1.0, "Radial return did not refill needs")
	_expect(tree.root.get_node("ProgressionService").export_state() == progression and Blueprint.load_best_available() == design, "Recovery changed discoveries or design")
	_expect(state.get_current_body_record().home_group.id == group.id and home.actors.size() == 2, "Recovery replaced home/companions")
	await _capture_recovery(player)
	# Save failure leaves last committed zero-health state recoverable.
	var bytes: String = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_recursive_absolute("user://blocked_recovery_save")
	_expect(not saves.save_now("user://blocked_recovery_save"), "Blocked write was reported as saved")
	_expect(FileAccess.get_file_as_string(path) == bytes, "Failed recovery save damaged committed file")
	_expect(saves.save_now(), "Recovery could not be saved after retry: " + saves.last_error)
	# Deliberately leave a new death committed. A fresh process must recover it.
	player.recovery.end_protection()
	player.respawn_delay = 30.0
	player.receive_damage(100000)
	flow.toggle_pause()
	_expect(saves.save_now(), "Second death could not be checkpointed")
	_expect(Atomic.write(EXPECTED, {"path": path, "home": group, "campaign": state.campaign.data.id,
		"progression": progression, "design_id": design.design_id}, false) == OK, "Cannot write restart expectation")
	flow.return_to_title()
	await tree.scene_changed
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/player_recovery_world_test.gd", "--", "--recovery-restart"]
	print("RECOVERY_STAGE: fresh process starting")
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	print("RECOVERY_STAGE: fresh process exited ", code, " output ", output)
	_expect(code == 0 and str(output).contains("RECOVERY_FRESH_PROCESS_PASSED"), "Fresh process failed: " + str(output))
	await _finish_recovery_test()

func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	await _open(expected.path, true)
	if not _expect_world(): await _finish_recovery_test(); return
	var player: CharacterBody3D = tree.current_scene.player
	_expect(player.is_dead and player.current_health == 0.0, "Fresh load resurrected zero health as alive")
	player.respawned.connect(func(): returns += 1)
	flow.resume()
	await _until(func(): return returns == 1, 35000)
	_expect(returns == 1 and not player.is_dead, "Fresh process failed to finish pending recovery")
	_expect(Home.distance(_radius(player.location()), expected.home.anchor) < 8.0, "Fresh process lost canonical home")
	_expect(state.campaign.data.id == expected.campaign and Blueprint.load_best_available().design_id == expected.design_id, "Fresh recovery changed campaign/design identity")
	_expect(Atomic.parse_dictionary(JSON.stringify(tree.root.get_node("ProgressionService").export_state())) == expected.progression, "Fresh recovery changed progression")
	_expect(saves.save_now(), "Fresh recovered state did not save")
	_expect(saves._read_save(expected.path).player.health_ratio > 0.99, "Fresh recovered save retained zero life")
	flow.return_to_title()
	await tree.scene_changed
	if failures.is_empty(): print("RECOVERY_FRESH_PROCESS_PASSED")
	await _finish_recovery_test()

func _capture_recovery(player: Node) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	var view: Node = player.recovery.get_child(0)
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			get_window().size = size
			for font_scale: float in [1.0, 1.5]:
				get_node("/root/DisplaySettings").ui_scale = font_scale
				for stage: String in ["countdown", "preparing", "blocked", "protected"]:
					player.recovery.stage = stage
					player.recovery.remaining = 2.0
					player.set_process(false)
					view.refresh()
					await _capture("recovery-%s-%d-%d-%s" % [locale, size.x, roundi(font_scale * 100), stage])
					_expect(get_viewport().get_visible_rect().encloses(view.panel.get_global_rect()), "Recovery card is outside the screen")
	get_node("/root/DisplaySettings").ui_scale = 1.0
	player.recovery.stage = "protected"
	player.recovery.remaining = 5.0
	player.set_process(true)

func _finish_recovery_test() -> void:
	tree.set_meta("recovery_completed", true)
	tree.paused = false
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PLAYER_RECOVERY_WORLD_PASSED: canonical home, pause, collision, failed save and fresh process")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
