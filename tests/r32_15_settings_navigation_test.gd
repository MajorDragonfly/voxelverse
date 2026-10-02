extends SceneTree
## Real controls without a world: focused popup/back, scroll and scale persistence.
var failures: Array[String] = []
var checks := 0
var settings: Node
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	settings = root.get_node("DisplaySettings")
	capture_dir = OS.get_environment("VOXELVERSE_R32_15_CAPTURE_DIR")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	await _frames(5)
	settings.display_mode = 0
	# Match the existing frontend consumer's fresh 1600x900/defaults fixture.
	settings.resolution = Vector2i(1600, 900)
	settings.ui_scale = 1.0
	settings._apply_settings(false)
	root.size = settings.resolution
	root.get_node("LocaleManager").save_preference("de")
	var consumer := preload("res://tools/review_r32_15_controls_consumer.gd").new()
	root.add_child(consumer)
	settings.open_menu()
	await _frames(6)
	await consumer._exercise_controls(settings)
	_expect(consumer.failures.is_empty(), "Existing Controls consumer failed: " + str(consumer.failures))
	settings.close_menu()
	consumer.free()
	var keys = preload("res://core/input_preferences.gd")
	_expect(settings.input_preferences.save_and_apply(keys.defaults(), 1.0, false, 0).is_empty(), "Test preference cleanup failed")
	settings.resolution = Vector2i(1280, 720)
	settings.ui_scale = 1.0
	settings._apply_settings(false)
	root.size = settings.resolution
	settings.open_menu(3)
	await _frames(5)
	var option: OptionButton = settings._graphics_settings.option
	option.grab_focus()
	await _key(KEY_ENTER)
	_expect(option.get_popup().visible, "Keyboard did not open graphics preset popup")
	await _key(KEY_ESCAPE)
	_expect(settings.is_menu_open() and paused and not option.get_popup().visible, "Escape closed settings together with its popup")
	if not settings.is_menu_open(): settings.open_menu(3)
	settings._tabs.current_tab = 1
	var page: Control = settings._control_settings
	var scroll: ScrollContainer = page.get_parent()
	var reset: Button = page.find_child("ResetControls", true, false)
	reset.grab_focus()
	await _frames(5)
	_expect(scroll.get_global_rect().grow(1.0).encloses(reset.get_global_rect()), "Focused control reset clipped")
	var bind: Button = page.find_child("Bind_move_forward_0", true, false)
	bind.grab_focus()
	await _frames(5)
	_expect(scroll.get_global_rect().grow(1.0).encloses(bind.get_global_rect()), "Focused binding clipped")
	await _key(KEY_ENTER)
	_expect(page.listening_action == "move_forward", "Keyboard binding selection failed")
	await _key(KEY_ESCAPE)
	_expect(page.listening_action.is_empty() and settings.is_menu_open() and paused, "Escape did not cancel only key capture")
	# Direct consumer regression: consecutive mouse bindings with manual scroll.
	await _click(bind)
	await _key(KEY_UP)
	var inspection: Button = page.find_child("Bind_inspection_mode_0", true, false)
	scroll.ensure_control_visible(inspection)
	await _frames(2)
	await _click(inspection)
	await _key(KEY_J)
	_expect(page.listening_action == "inspection_mode", "Deferred scroll lost the next mouse binding")
	await _key(KEY_R)
	_expect(page.draft.inspection_mode[0] == KEY_R, "Next mouse binding did not accept its replacement")
	settings.close_menu()
	for scale_value: float in [1.0, 1.25, 1.5]:
		settings.ui_scale = scale_value
		settings._apply_settings(false)
		_expect(settings._save_settings(), "UI scale save failed")
		settings.ui_scale = 1.0
		settings._load_settings()
		_expect(is_equal_approx(settings.ui_scale, scale_value), "Restart changed UI scale " + str(scale_value))
		settings.open_menu(3)
		_expect(is_equal_approx(float(settings._scale_option.get_selected_metadata()), scale_value), "Reopening selected a different UI scale " + str(scale_value))
		settings._apply_menu_selection()
		_expect(is_equal_approx(settings.ui_scale, scale_value), "Graphics Apply changed UI scale " + str(scale_value))
		settings.close_menu()
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale_value: float in [1.0, 1.25, 1.5]:
			settings.resolution = dimensions
			settings.ui_scale = scale_value
			settings._apply_settings(false)
			root.size = dimensions
			for locale: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(locale)
				settings.open_menu(3)
				await _frames(6)
				var label := "%dx%d-%d-%s" % [dimensions.x, dimensions.y, roundi(scale_value * 100), locale]
				_expect(root.get_visible_rect().grow(1).encloses(settings._menu_panel.get_global_rect()), "Settings clipped " + label + " " + str(settings._menu_panel.get_global_rect()))
				await _picture("graphics-" + label)
				settings._tabs.current_tab = 1
				reset.grab_focus()
				await _frames(6)
				_expect(scroll.get_global_rect().grow(1).encloses(reset.get_global_rect()), "Controls Reset clipped " + label)
				await _picture("controls-" + label)
				settings.close_menu()
	for message in failures: push_error(message)
	print("R32_15_SETTINGS_NAVIGATION_PASSED" if failures.is_empty() else "R32_15_SETTINGS_NAVIGATION_FAILED", " checks=", checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames(2)

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _picture(filename: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	_expect(picture.get_size() == root.size, "Capture dimensions mismatch " + filename)
	_expect(picture.save_png(capture_dir.path_join(filename + ".png")) == OK, "Capture failed " + filename)
