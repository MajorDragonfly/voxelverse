extends SceneTree
## Isolated rendered book host. This is not the public spherical campaign gate.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.add_child(BookFrames.new())

class BookFrames:
	extends "res://tests/fixtures/int30_menu_audio_book_probe.gd"

	func _run() -> void:
		flow = get_node("/root/SessionFlow")
		settings = get_node("/root/DisplaySettings")
		audio = get_node("/root/AudioManager")
		get_node("/root/SaveGameService").autosave_enabled = false
		evidence = OS.get_environment("VOXELVERSE_INT30_CAPTURE_DIR")
		_expect(not evidence.is_empty(), "Book frame output is required")
		var scene := Node3D.new()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		var player := Node3D.new()
		scene.add_child(player)
		player.set_physics_process(true)
		var journal := preload("res://ui/discovery/discovery_journal.gd").new()
		journal.player = player
		scene.add_child(journal)
		var ui := preload("res://ui/behavior_skill_tree.gd").new()
		ui.player = player
		ui.journal = journal
		scene.add_child(ui)
		for phase: int in [0, 1]:
			var state := get_node("/root/GameState")
			state.start_world_with_seed(15838)
			# Declared UI fixtures select the current chapter. Only the combined
			# campaign test covers ordinary real phase confirmation.
			state.current_phase = phase
			for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720)]:
				for language: String in ["de", "en"]:
					get_node("/root/LocaleManager").save_preference(language)
					settings.display_mode = 0
					settings.resolution = dimensions
					settings.ui_scale = 1.3
					settings._apply_settings(false)
					get_tree().root.size = dimensions
					await _frames(6)
					await _book_route(ui, "creature-fixture" if phase == 0 else "tribe-fixture", language, dimensions)
		await _finish()

	func _finish() -> void:
		RenderingServer.render_loop_enabled = true
		if not evidence.is_empty():
			var file := FileAccess.open(evidence.path_join("cases.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases, "scope": "Isolated original book host; declared phase fixtures; no generated sphere or ordinary phase confirmation."}, "\t"))
		for failure: String in failures: push_error(failure)
		print("INT30_BOOK_FRAMES_PASSED" if failures.is_empty() else "INT30_BOOK_FRAMES_FAILED", " checks=", checks)
		await preload("res://core/runtime_shutdown.gd").finish(get_tree(), 0 if failures.is_empty() else 1)
