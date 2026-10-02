extends SceneTree
## Public spherical entry and ordinary phase/save owner. No phase flags are injected.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	root.add_child(CampaignProbe.new())

class CampaignProbe:
	extends "res://core/diagnostics/pause_menu_probe.gd"
	var output: String
	var cases: Array[Dictionary] = []
	var images: Array[String] = []

	func _run() -> void:
		flow = get_node("/root/SessionFlow")
		settings = get_node("/root/DisplaySettings")
		output = OS.get_environment("VOXELVERSE_R32_13_OUTPUT")
		var args := OS.get_cmdline_user_args()
		if "--restart-slot" in args:
			await _restart(args[args.find("--restart-slot") + 1])
			await _finish()
			return
		_expect(Playtest.start(flow), "Public tribal playtest entry rejected")
		await _until(func() -> bool:
			var scene := get_tree().current_scene
			var tribe: Node = scene.get_node_or_null("Nest/Tribe")
			return tribe != null and tribe.panel.confirmation_open, 90000)
		var tribe: Node = get_tree().current_scene.get_node_or_null("Nest/Tribe")
		if tribe == null or not tribe.panel.confirmation_open:
			_expect(false, "Ordinary phase confirmation did not become ready within 90 s")
			await _finish()
			return
		get_node("/root/SaveGameService").autosave_enabled = false
		_expect(get_node("/root/GameState").current_phase == 0, "Confirmation itself advanced the epoch")
		await _picture("00-before-confirmation")
		await _key(KEY_ESCAPE)
		_expect(not get_tree().paused and not tribe.panel.confirmation_open and get_node("/root/GameState").current_phase == 0, "Esc cancel advanced the epoch or retained pause")
		await _book_route("creature")
		_expect(tribe.panel.open_confirmation(), "Reopening ordinary phase confirmation rejected")
		await _picture("10-reopened-confirmation")
		await _click(tribe.panel.confirm)
		await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 60000)
		_expect(tribe.is_active() and get_node("/root/GameState").current_phase == 1, "Explicit confirmation failed to hand off epoch/control")
		await _book_route("tribe")
		var saves := get_node("/root/SaveGameService")
		_expect(saves.save_now(), "Save owner rejected actual tribal state")
		var expected: Dictionary = get_node("/root/ProgressionService").export_state()
		var path: String = saves.save_path
		var file := FileAccess.open(output.path_join("expected-progress.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(expected))
		file.close()
		var logs: Array = []
		var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--audio-driver", "Dummy", "--script", "res://tools/review_r32_13_campaign.gd", "--", "--restart-slot", path])
		var code := OS.execute(OS.get_executable_path(), command, logs, true)
		var log := FileAccess.open(output.path_join("restart.log"), FileAccess.WRITE)
		log.store_string("\n".join(logs))
		log.close()
		_expect(code == 0 and str(logs).contains("R32_13_RESTART_PASSED"), "Fresh-process normal slot load/progress failed: " + str(logs))
		await _finish()

	func _book_route(phase: String) -> void:
		var ui: CanvasLayer = get_tree().current_scene.find_child("PlayerProgression", true, false)
		_expect(ui != null, "Actual campaign lacks the development book")
		if ui == null: return
		for language: String in ["de", "en"]:
			get_node("/root/LocaleManager").save_preference(language)
			settings.display_mode = 0
			settings.resolution = Vector2i(1280, 720) if language == "en" else Vector2i(1920, 1080)
			settings.ui_scale = 1.5 if language == "en" else 1.0
			settings._apply_settings(false)
			get_tree().root.size = settings.resolution
			await _frames(4)
			get_viewport().gui_release_focus()
			await _key(KEY_K)
			_expect(ui.visible and get_tree().paused, "Campaign book K failed: " + phase)
			if not ui.visible: return
			var state := get_node("/root/GameState")
			var progression := get_node("/root/ProgressionService")
			var before: Dictionary = {"phase": state.current_phase, "progress": progression.export_state(), "time": state.campaign.data.elapsed_seconds}
			await _click(ui._development_tab)
			for chapter: String in ui._development.CHAPTERS:
				ui._scroll.scroll_vertical = 0
				var button: Button = ui._development._chapter_buttons[chapter]
				button.grab_focus()
				await _frames(3)
				await _key(KEY_ENTER)
				_expect(ui._development._selected == chapter, "Actual campaign chapter input failed")
				ui._scroll.scroll_vertical = 0
				await _frames(4)
				await _picture("%s-%s-%s" % [phase, language, chapter])
				if chapter in ["medieval", "modern"]:
					_expect(ui._development._epochs[2 if chapter == "medieval" else 3].action.disabled, "Future chapter enabled epoch change")
				cases.append({"phase": phase, "language": language, "size": str(settings.resolution), "ui_scale": settings.ui_scale,
					"chapter": chapter, "current_stage": progression.get_development_path().current_stage})
			await _click(ui._tree_tab)
			var id := "creature.social.support" if phase == "creature" else "tribe.social.supply"
			if not ui._cards.has(id):
				id = "tribe.social.teamwork" if phase == "tribe" else "creature.social.support"
			var card: Button = ui._cards[id].button
			ui._scroll.ensure_control_visible(card)
			await _frames(3)
			await _click(card)
			_expect(not ui._requirements.text.is_empty() and ui._selected == id, "Ability/dependency detail missing")
			await _picture("%s-%s-skill-dependencies" % [phase, language])
			_expect(before == {"phase": state.current_phase, "progress": progression.export_state(), "time": state.campaign.data.elapsed_seconds}, "Book browsing advanced campaign time/progress/phase")
			await _click(ui._close)
			_expect(not ui.visible and not get_tree().paused and not flow.pause_open, "Actual book Back did not release its pause")
			await _key(KEY_K)
			await _key(KEY_ESCAPE)
			_expect(not ui.visible and not get_tree().paused and not flow.pause_open, "Actual book Esc did not release its pause")

	func _restart(path: String) -> void:
		get_node("/root/SaveGameService").autosave_enabled = false
		await flow.load_game(path)
		await _until(func() -> bool:
			return not flow.loading and get_tree().current_scene.scene_file_path == flow.SPHERE_SCENE, 90000)
		var state := get_node("/root/GameState")
		_expect(not flow.loading and state.current_phase == 1, "Fresh process did not load confirmed tribal epoch")
		var actual: Dictionary = get_node("/root/ProgressionService").export_state()
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("expected-progress.json")))
		_expect(actual == expected, "Fresh process altered the saved progress")
		var path_data: Dictionary = get_node("/root/ProgressionService").get_development_path()
		_expect(path_data.current_stage == "tribe" and path_data.home.member_count == 2, "Fresh book summary lost actual epoch/companions")
		var ui: CanvasLayer = get_tree().current_scene.find_child("PlayerProgression", true, false)
		_expect(ui != null and ui.open_panel(), "Fresh campaign book cannot open")
		if ui != null and ui.visible:
			await _click(ui._development_tab)
			_expect(ui._development._summary.text.contains(ui.Presentation.phase_name(1)), "Fresh book does not show the saved epoch")
			await _key(KEY_ESCAPE)
		print("R32_13_RESTART_PASSED" if failures.is_empty() else "R32_13_RESTART_FAILED")

	func _picture(filename: String) -> void:
		if output.is_empty() or DisplayServer.get_name() == "headless": return
		RenderingServer.render_loop_enabled = true
		await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		_expect(picture.save_png(output.path_join(filename + ".png")) == OK, "Campaign capture failed")
		images.append(filename)
		RenderingServer.render_loop_enabled = false

	func _frames(count: int) -> void:
		RenderingServer.render_loop_enabled = not get_tree().paused
		await super._frames(count)

	func _finish() -> void:
		RenderingServer.render_loop_enabled = true
		var filename := "restart-cases.json" if "--restart-slot" in OS.get_cmdline_user_args() else "cases.json"
		if not output.is_empty():
			var file := FileAccess.open(output.path_join(filename), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases, "images": images,
				"scope": "Public title -> tribal playtest -> generated sphere; ordinary cancellation/explicit phase confirmation; existing SaveGameService and fresh-process normal slot loading."}, "\t"))
		for failure: String in failures: push_error(failure)
		print("R32_13_CAMPAIGN_PASSED" if failures.is_empty() else "R32_13_CAMPAIGN_FAILED", " checks=", checks)
		await preload("res://core/runtime_shutdown.gd").finish(get_tree(), 0 if failures.is_empty() else 1)
