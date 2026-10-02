extends "res://core/diagnostics/pause_menu_probe.gd"
## Additive R32 consumer coverage; no phase, clock, input or settings replacement.
var evidence := ""
var cases: Array[Dictionary] = []

func _run() -> void:
	flow = get_node("/root/SessionFlow")
	settings = get_node("/root/DisplaySettings")
	audio = get_node("/root/AudioManager")
	evidence = OS.get_environment("VOXELVERSE_R32_15_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	var tree := get_tree()
	_expect(Playtest.start(flow), "Public campaign entry failed")
	await _until(func() -> bool:
		var tribe: Node = tree.current_scene.get_node_or_null("Nest/Tribe")
		return tribe != null and tribe.panel.confirmation_open, 90000)
	var tribe: Node = tree.current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Ordinary phase confirmation not reached")
		await _finish()
		return
	get_node("/root/SaveGameService").autosave_enabled = false
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and not tribe.panel.confirmation_open, "Confirmation cancel did not release pause")
	await _phase_route("creature")
	await _title_round_trip("creature")
	tribe = tree.current_scene.get_node_or_null("Nest/Tribe")
	if tribe != null:
		await _until(func() -> bool: return tribe.blockers().is_empty(), 60000)
	_expect(tribe != null and tribe.panel.open_confirmation(), "Ordinary confirmation cannot reopen after title/load")
	_expect(tribe != null and tribe.panel.confirmation_open and not tribe.panel.confirm.disabled, "Ordinary phase confirmation not ready after title/load")
	if tribe == null or not tribe.panel.confirmation_open or tribe.panel.confirm.disabled:
		await _finish()
		return
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 60000)
	_expect(tribe.is_active(), "Normal tribal handoff failed")
	if tribe.is_active():
		await _phase_route("tribe")
		await _tactical_pause(tribe)
		await _title_round_trip("tribe")
	await _finish()

func _phase_route(phase: String) -> void:
	var tree := get_tree()
	var scene: Node3D = tree.current_scene
	var player: Node3D = scene.player
	var tribe: Node = scene.get_node("Nest/Tribe")
	var state: Node = get_node("/root/GameState")
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scaling: float in [1.0, 1.25, 1.5]:
			for locale: String in ["de", "en"]:
				# Native: six complementary cases per phase; full 18-case matrix headless.
				if not evidence.is_empty() and not ((dimensions.x == 800 and scaling == 1.5) or (dimensions.x == 1280 and scaling == 1.25) or (dimensions.x == 1920 and scaling == 1.0)): continue
				get_node("/root/LocaleManager").save_preference(locale)
				settings.display_mode = 0
				settings.resolution = dimensions
				settings.ui_scale = scaling
				settings._apply_settings(false)
				tree.root.size = dimensions
				await _frames(4)
				var name := "%s-%s-%dx%d-%d" % [phase, locale, dimensions.x, dimensions.y, roundi(scaling * 100)]
				print("R32_15_CASE ", name)
				var previous_mouse := Input.mouse_mode
				await _key(KEY_ESCAPE)
				_expect(flow.pause_open and tree.paused and _focus_name() == "ResumeGame", "Pause/focus entry failed " + name)
				var time_before: float = state.campaign.data.elapsed_seconds
				var position_before := player.global_position
				var selection_before: Array = tribe.selected.duplicate()
				await _click_at(tree.root.get_visible_rect().end - Vector2(2, 2))
				await _key(KEY_W)
				_expect(tree.root.get_visible_rect().grow(1).encloses(flow._overlay_scroll.get_global_rect()), "Pause scroll clipped " + name)
				await _picture(name + "-pause")
				flow._overlay.find_child("ResumeGame", true, false).grab_focus()
				await _key(KEY_TAB)
				_expect(_focus_name() == "PauseSettings", "Keyboard order failed " + name)
				await _key(KEY_ENTER)
				_expect(settings.is_menu_open() and tree.paused and not flow._layer.visible, "Settings overlaps/lost pause " + name)
				_expect(settings._graphics_settings.option.has_focus(), "Graphics opening focus failed " + name)
				await _frames(5)
				_expect(tree.root.get_visible_rect().grow(1).encloses(settings._menu_panel.get_global_rect()), "Settings clipped " + name)
				await _picture(name + "-graphics")
				var bar: TabBar = settings._tabs.get_tab_bar()
				await _click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(1).get_center())
				var reset: Button = settings._control_settings.find_child("ResetControls", true, false)
				reset.grab_focus()
				await _frames(5)
				_expect(settings._control_settings.get_parent().get_global_rect().grow(1).encloses(reset.get_global_rect()), "Controls focus clipped " + name)
				await _picture(name + "-controls")
				var bind: Button = settings._control_settings.find_child("Bind_move_forward_0", true, false)
				bind.grab_focus()
				await _frames(5)
				await _key(KEY_ENTER)
				_expect(not settings._control_settings.listening_action.is_empty(), "Key capture cannot start " + name)
				await _key(KEY_ESCAPE)
				_expect(settings.is_menu_open() and settings._control_settings.listening_action.is_empty(), "Esc skipped key capture level " + name)
				await _click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(2).get_center())
				var language: OptionButton = settings._language_settings.choice
				language.grab_focus()
				await _key(KEY_ENTER)
				_expect(language.get_popup().visible, "Language dropdown failed " + name)
				await _key(KEY_ESCAPE)
				_expect(settings.is_menu_open() and not language.get_popup().visible, "Esc skipped language dropdown level " + name)
				await _picture(name + "-language")
				await _click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(4).get_center())
				_expect(is_instance_valid(audio._panel) and not settings._menu_panel.visible and tree.paused, "Audio modal ownership failed " + name)
				await _key(KEY_ESCAPE)
				_expect(settings.is_menu_open() and settings._menu_panel.visible and tree.paused, "Audio back failed " + name)
				await _key(KEY_ESCAPE)
				_expect(flow.pause_open and flow._layer.visible and tree.paused and _focus_name() == "PauseSettings", "Settings back/focus failed " + name)
				_expect(state.campaign.data.elapsed_seconds == time_before and player.global_position == position_before and tribe.selected == selection_before, "World click/time/selection leaked " + name)
				for id: String in ["PauseControls", "PauseFirstSteps"]:
					await _click(flow._overlay.find_child(id, true, false))
					await _key(KEY_ESCAPE)
					_expect(flow.pause_open and tree.paused and flow._pause_page == "pause" and _focus_name() == id, "Subpage back failed " + name + id)
				await _click(flow._overlay.find_child("ResumeGame", true, false))
				_expect(not tree.paused and not flow.pause_open and Input.mouse_mode == previous_mouse, "Resume/mouse restore failed " + name)
				cases.append({"phase": phase, "locale": locale, "window": [dimensions.x, dimensions.y], "scale": scaling, "name": name})
	await _persist_graphics(phase)

func _persist_graphics(phase: String) -> void:
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	settings._graphics_settings.controls.exposure.value = 0.93
	await _click(settings._menu_panel.find_child("Apply", true, false))
	_expect(is_equal_approx(settings.graphics_values.exposure, 0.93), "Graphics Apply failed " + phase)
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	_expect(is_equal_approx(settings._graphics_settings.draft.exposure, 0.93), "Applied value lost on back " + phase)
	settings._graphics_settings.controls.exposure.value = 1.04
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	_expect(is_equal_approx(settings._graphics_settings.draft.exposure, 0.93), "Discarded value saved " + phase)
	settings.ui_scale = 1.5
	settings._apply_settings(true)
	get_node("/root/LocaleManager").save_preference("en")
	var output: Array = []
	var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/r32_15_campaign_menu_test.gd", "--", "--r32-15-restart"])
	var code := OS.execute(OS.get_executable_path(), command, output, true)
	_expect(code == 0 and str(output).contains("R32_15_RESTART_PASSED") and not str(output).contains("ERROR:"), "Fresh settings process failed " + phase + str(output).right(1200))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)

func _title_round_trip(phase: String) -> void:
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("ReturnToTitle", true, false))
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == flow.TITLE_SCENE, 90000)
	_expect(get_tree().current_scene.scene_file_path == flow.TITLE_SCENE and not get_tree().paused and not settings.is_menu_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Title return failed " + phase)
	await _picture(phase + "-title")
	await _click(get_tree().current_scene.find_child("Continue", true, false))
	await _until(func() -> bool: return not flow.loading and get_tree().current_scene.scene_file_path == flow.SPHERE_SCENE, 90000)
	_expect(not flow.loading and get_tree().current_scene.scene_file_path == flow.SPHERE_SCENE, "Title continue failed " + phase)
	await _frames(5)
	_expect(is_equal_approx(settings.graphics_values.exposure, 0.93), "Title/load lost graphics " + phase)

func _frames(count: int) -> void:
	if not evidence.is_empty(): RenderingServer.render_loop_enabled = not get_tree().paused
	await super._frames(count)

func _picture(filename: String) -> void:
	if evidence.is_empty(): return
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	_expect(picture.get_size() == get_window().size, "Wrong capture size " + filename)
	_expect(picture.save_png(evidence.path_join(filename + ".png")) == OK, "Capture failed " + filename)
	RenderingServer.render_loop_enabled = not get_tree().paused

func _finish() -> void:
	RenderingServer.render_loop_enabled = true
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("cases.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases}, "\t"))
	print("R32_15_CAMPAIGN_MENU_PASSED" if failures.is_empty() else "R32_15_CAMPAIGN_MENU_FAILED", " checks=", checks)
	await super._finish()
