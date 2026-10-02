extends SceneTree
## Real book controls in an explicitly isolated UI fixture. No sphere/phase claims.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.add_child(BookProbe.new())

class BookProbe:
	extends "res://core/diagnostics/pause_menu_probe.gd"
	var cases: Array[Dictionary] = []
	var output: String
	var ui: CanvasLayer
	var strict: bool

	func _run() -> void:
		flow = get_node("/root/SessionFlow")
		settings = get_node("/root/DisplaySettings")
		get_node("/root/SaveGameService").autosave_enabled = false
		output = OS.get_environment("VOXELVERSE_R32_13_OUTPUT")
		strict = not "--baseline" in OS.get_cmdline_user_args()
		var state := get_node("/root/GameState")
		state.start_world_with_seed(15838)
		var scene := Node3D.new()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		var player := Node3D.new()
		scene.add_child(player)
		player.set_physics_process(true)
		ui = preload("res://ui/behavior_skill_tree.gd").new()
		ui.player = player
		scene.add_child(ui)
		await _frames(3)
		await _key(KEY_K)
		_expect(ui.visible and get_tree().paused, "K must open the real book")
		await _click(ui._development_tab)
		var snapshot: Dictionary = get_node("/root/ProgressionService").export_state()
		for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			for scaling: float in [1.0, 1.25, 1.5]:
				for language: String in ["de", "en"]:
					get_node("/root/LocaleManager").save_preference(language)
					settings.display_mode = 0
					settings.resolution = dimensions
					settings.ui_scale = scaling
					settings._apply_settings(false)
					get_tree().root.size = dimensions
					ui._layout()
					await _frames(6)
					for chapter: String in ui._development.CHAPTERS:
						ui._scroll.scroll_vertical = 0
						var button: Button = ui._development._chapter_buttons[chapter]
						button.grab_focus()
						await _frames(3)
						await _key(KEY_ENTER)
						_expect(ui._development._selected == chapter, "Chapter keyboard input failed: " + chapter)
						ui._scroll.scroll_vertical = 0
						await _frames(5)
						var scale_pixels := Vector2(get_window().size).x / get_viewport().get_visible_rect().size.x
						var title: Label = ui._development._stage_labels[chapter].title
						var nav_visible := true
						var clipped_navigation: Array[String] = []
						for nav: Button in ui._development._chapter_buttons.values():
							nav_visible = nav_visible and ui._scroll.get_global_rect().encloses(nav.get_global_rect())
							var style: StyleBox = nav.get_theme_stylebox("normal")
							var available: float = nav.size.x - style.get_minimum_size().x
							var text_width := nav.get_theme_font("font").get_multiline_string_size(nav.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nav.get_theme_font_size("font_size")).x
							if text_width > available: clipped_navigation.append(str(nav.name))
						var record := {"language": language, "size": [dimensions.x, dimensions.y], "ui_scale": scaling,
							"chapter": chapter, "all_navigation_visible_at_top": nav_visible, "clipped_navigation": clipped_navigation,
							"title_visible_at_top": ui._scroll.get_global_rect().encloses(title.get_global_rect()),
							"scroll_range": ui._scroll.get_v_scroll_bar().max_value - ui._scroll.get_v_scroll_bar().page,
							"minimum_text_pixels": _minimum_font(ui._development._chapter_details[chapter]) * scale_pixels,
							"viewport": str(get_viewport().get_visible_rect().size), "panel": str(ui._panel.get_global_rect())}
						if chapter == "tribe":
							record["transition_visible_at_top"] = ui._scroll.get_global_rect().encloses(ui._development._transition.get_global_rect())
						cases.append(record)
						_expect(get_viewport().get_visible_rect().encloses(ui._panel.get_global_rect()), "Book panel clipped: " + str(record))
						_expect(get_viewport().get_visible_rect().encloses(ui._close.get_global_rect()), "Back clipped")
						_expect(record.minimum_text_pixels >= 12.0, "Text below 12 physical pixels")
						_expect(not _labels(ui._development).contains("PATH_"), "Untranslated chapter")
						if strict:
							_expect(nav_visible, "Compulsory navigation scroll: " + str(record))
							_expect(record.title_visible_at_top, "Selected chapter starts below viewport: " + str(record))
							_expect(clipped_navigation.is_empty(), "Chapter status ellipsized: " + str(record))
							if chapter in ["medieval", "modern", "space"]:
								_expect(button.text.contains(ui.Text.text("SKILLS_LOCKED")), "Future navigation lacks an explicit lock state")
							if chapter == "tribe" and not get_node("/root/ProgressionService").get_development_path().transition.available:
								_expect(ui._development._stage_labels[chapter].status.text == ui.Text.text("SKILLS_LOCKED"), "Blocked tribe shown as playable")
							if chapter == "tribe" and dimensions.x >= 1280:
								_expect(record.transition_visible_at_top, "Actual transition requires scrolling past optional milestones")
						if chapter in ["medieval", "modern"]:
							_expect(ui._development._epochs[2 if chapter == "medieval" else 3].action.disabled, "Future transition enabled")
						await _picture("%s-%dx%d-%d-%s-top" % [language, dimensions.x, dimensions.y, roundi(scaling * 100), chapter])
						if strict and chapter == "tribe":
							var toggle: Button = ui._development._goals_toggle
							toggle.grab_focus()
							await _frames(3)
							await _key(KEY_ENTER)
							_expect(ui._development._goals.visible and toggle.button_pressed, "Milestone expansion failed")
							await _picture("%s-%dx%d-%d-tribe-milestones" % [language, dimensions.x, dimensions.y, roundi(scaling * 100)])
							await _key(KEY_ENTER)
							_expect(not ui._development._goals.visible and not toggle.button_pressed, "Milestone collapse failed")
						if record.scroll_range > 1:
							ui._scroll.scroll_vertical = ceili(ui._scroll.get_v_scroll_bar().max_value)
							await _frames(4)
							await _picture("%s-%dx%d-%d-%s-bottom" % [language, dimensions.x, dimensions.y, roundi(scaling * 100), chapter])
					_expect(snapshot == get_node("/root/ProgressionService").export_state(), "Read-only browsing changed progress")
		await _click(ui._close)
		_expect(not ui.visible and not get_tree().paused and not flow.pause_open, "Back did not restore gameplay")
		await _key(KEY_K)
		await _key(KEY_ESCAPE)
		_expect(not ui.visible and not get_tree().paused and not flow.pause_open, "Esc did not restore gameplay")
		RenderingServer.render_loop_enabled = true
		if not output.is_empty():
			var file := FileAccess.open(output.path_join("cases.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases,
				"scope": "Isolated UI fixture, real controls and display canvas; phase 0; 150% is injected because settings only expose up to 135%."}, "\t"))
		for failure: String in failures: push_error(failure)
		print("R32_13_BOOK_PASSED" if failures.is_empty() else "R32_13_BOOK_FAILED", " checks=", checks)
		await preload("res://core/runtime_shutdown.gd").finish(get_tree(), 0 if failures.is_empty() else 1)

	func _picture(filename: String) -> void:
		if output.is_empty() or DisplayServer.get_name() == "headless": return
		RenderingServer.render_loop_enabled = true
		await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		_expect(picture.get_size() == get_window().size, "Wrong native capture dimensions")
		_expect(picture.save_png(output.path_join(filename + ".png")) == OK, "Capture failed")
		RenderingServer.render_loop_enabled = false

	func _minimum_font(node: Node) -> float:
		var result := float(node.get_theme_font_size("font_size")) if node is Label or node is Button else INF
		for child: Node in node.get_children(): result = minf(result, _minimum_font(child))
		return result

	func _labels(node: Node) -> String:
		var result: String = node.text + "\n" if node is Label or node is Button else ""
		for child: Node in node.get_children(): result += _labels(child)
		return result
