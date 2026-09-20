extends SceneTree
const Preferences = preload("res://core/graphics_preferences.gd")
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
const Water = preload("res://world/visuals/underwater_view.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
var failures: Array[String] = []
var checks: int = 0
var settings: Node
var capture_dir: String = ""
var sample: Dictionary = {"up": Vector3.UP, "height": 30.0, "moisture": 0.65, "seconds": 72.0,
	"weather": {"cloud_cover": 0.9, "precipitation": 0.4, "visibility_m": 4500.0}}

func _initialize() -> void:
	call_deferred("_run")

func _custom() -> Dictionary:
	var values := Preferences.preset(2)
	values.clouds_enabled = false
	values.haze_strength = 0.0
	values.shadow_distance = 410.0
	values.exposure = 1.18
	values.saturation = 0.55
	values.contrast = 1.08
	return values

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	settings = root.get_node("DisplaySettings")
	for i in range(4): await process_frame
	var args := OS.get_cmdline_user_args()
	if "--graphics-capture" in args: capture_dir = args[args.find("--graphics-capture") + 1]
	if "--graphics-restart" in args:
		_expect(settings.atmosphere_quality == Preferences.CUSTOM and settings.graphics_values == _custom(), "Fresh process lost custom values")
		var air := Atmosphere.new()
		root.add_child(air)
		_expect(air.graphics_values == _custom() and is_equal_approx(air.environment.tonemap_exposure, 1.18), "Fresh atmosphere ignored saved custom values")
		air.free()
		print("GRAPHICS_RESTART_PASSED" if failures.is_empty() else "GRAPHICS_RESTART_FAILED")
		await _finish()
		return
	_test_config_migration()
	var scene := Node3D.new()
	root.add_child(scene)
	var air := Atmosphere.new()
	scene.add_child(air)
	air.configure(Profile.create(15838), 15838, Vector3.UP, func(): return sample)
	air.set_process(false)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(9, 7, 18)
	camera.look_at(Vector3(0, 5, -12))
	camera.make_current()
	_fixture(scene)
	var panel: VBoxContainer = settings._graphics_settings
	settings.open_menu()
	settings._tabs.current_tab = 3
	for index in [2, 0, 1, 2]:
		panel.option.select(index)
		panel.option.item_selected.emit(index)
		_expect(panel.draft == Preferences.preset(index), "Preset retains previous custom values")
		settings._apply_menu_selection()
		_expect(air.graphics_values == Preferences.preset(index) and paused, "Preset did not reach paused atmosphere")
	# Real GUI mouse input must mark the draft custom without applying it.
	var clouds: CheckButton = panel.controls.clouds_enabled
	await _focus_control(clouds)
	await _click(clouds)
	_expect(not panel.draft.clouds_enabled and panel.preset_index == Preferences.CUSTOM, "Mouse toggle did not select Custom")
	_expect(air.graphics_values.clouds_enabled, "Draft changed live atmosphere before Apply")
	if not failures.is_empty():
		settings.close_menu()
		scene.free()
		await _finish()
		return
	settings.close_menu()
	settings.open_menu()
	_expect(panel.preset_index == 2 and panel.draft.clouds_enabled, "Back did not discard draft")
	settings._tabs.current_tab = 3
	var exposure: HSlider = panel.controls.exposure
	await _focus_control(exposure)
	await _key(KEY_RIGHT)
	_expect(float(panel.draft.exposure) > 1.0 and panel.preset_index == Preferences.CUSTOM, "Keyboard did not edit a focused slider")
	var draft_before: Dictionary = panel.draft.duplicate(true)
	root.get_node("LocaleManager").save_preference("en")
	await process_frame
	_expect(panel.draft == draft_before and exposure.has_focus(), "Language change lost draft/focus")
	panel.refresh(Preferences.CUSTOM, _custom())
	var weather_before := sample.duplicate(true)
	settings._apply_menu_selection()
	_expect(air.graphics_values == _custom() and sample == weather_before, "Custom apply changed weather or lost values")
	_expect(not air.sky_material.get_shader_parameter("clouds_enabled") and not air.environment.fog_enabled, "Cloud/haze switches are ineffective")
	_expect(is_equal_approx(air.sun.directional_shadow_max_distance, 410.0), "Shadow distance was not applied")
	_expect(is_equal_approx(air.environment.adjustment_saturation, 0.55), "Image values were not applied")
	var supported: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	_expect(air.environment.volumetric_fog_enabled == supported and air.environment.ssao_enabled == supported and air.environment.glow_enabled == supported, "Unsupported effects remain enabled")
	_expect(panel.controls.fog_enabled.disabled == not supported, "Unavailable fog control is not marked disabled")
	# Reset is a draft too; closing it must retain the applied custom settings.
	panel.find_child("ResetGraphics", true, false).pressed.emit()
	_expect(panel.draft == Preferences.preset(1) and settings.graphics_values == _custom(), "Reset changed saved settings prematurely")
	settings.close_menu()
	await _capture("custom-world")
	air.set_quality(1)
	await _capture("preset-world")
	air.apply_graphics(settings.graphics_values, settings.atmosphere_quality)
	var water := Water.new()
	water.sample_water = func(_point: Vector3): return {"water": true, "depth": 3.0}
	scene.add_child(water)
	water.update_view()
	var submerged: Environment = camera.environment
	settings.open_menu()
	panel.controls.exposure.value = 0.8
	settings._apply_menu_selection()
	_expect(camera.environment == submerged and is_equal_approx(submerged.tonemap_exposure, 0.8 * lerpf(0.85, 0.5, 1.0 - exp(-3.0 / 14.0))), "Applying underwater lost water ownership or exposure")
	_expect(not submerged.volumetric_fog_enabled and not submerged.glow_enabled and submerged.fog_enabled, "Graphics switches removed underwater visibility rules")
	settings.close_menu()
	await _capture("underwater")
	water.sample_water = func(_point: Vector3): return {"water": false, "depth": -1.0}
	water.update_view()
	_expect(camera.environment == null and is_equal_approx(air.environment.tonemap_exposure, 0.8), "Surfacing restored stale image settings")
	settings.open_menu()
	panel.refresh(Preferences.CUSTOM, _custom())
	settings._apply_menu_selection()
	settings.close_menu()
	await _layout_checks()
	scene.free()
	# Changing scene/slot and a genuine body journey must pick up the same device preferences.
	if capture_dir.is_empty(): await _campaign_round_trip()
	var output: Array = []
	var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/graphics_settings_test.gd", "--", "--graphics-restart"])
	var code: int = OS.execute(OS.get_executable_path(), command, output, true)
	_expect(code == 0 and str(output).contains("GRAPHICS_RESTART_PASSED"), "Fresh process failed: " + str(output))
	await _finish()

func _test_config_migration() -> void:
	var path: String = settings.CONFIG_PATH
	var config := ConfigFile.new()
	config.set_value("display", "atmosphere_quality", 2)
	config.save(path)
	settings._load_settings()
	_expect(settings.graphics_values == Preferences.preset(2), "Legacy preset did not migrate")
	var malformed := Preferences.normalize({"exposure": INF, "contrast": -900, "cloud_quality": 999, "clouds_enabled": "false", "saturation": "nan"})
	_expect(malformed.exposure == 1.0 and malformed.contrast == 0.75 and malformed.cloud_quality == 2 and malformed.clouds_enabled and malformed.saturation == 1.0, "Malformed values escaped bounds/defaults")
	config.set_value("graphics", "schema", 999)
	config.set_value("graphics", "future_data", "preserve me")
	config.save(path)
	settings._load_settings()
	var original: String = FileAccess.get_file_as_string(path)
	settings.open_menu()
	settings._apply_menu_selection()
	_expect(settings._graphics_read_only and FileAccess.get_file_as_string(path) == original, "Newer settings were overwritten")
	settings.close_menu()
	settings._save_settings() # F10/F11 may still save display fields, not future graphics.
	config.load(path)
	_expect(config.get_value("graphics", "schema") == 999 and config.get_value("graphics", "future_data") == "preserve me", "Display shortcut erased future graphics")
	config.erase_section("graphics")
	config.save(path)
	settings._load_settings()
	settings._apply_settings(false)
	# A failed atomic replacement preserves the previous valid file.
	DirAccess.make_dir_absolute(path + ".tmp")
	original = FileAccess.get_file_as_string(path)
	_expect(not settings._save_settings() and FileAccess.get_file_as_string(path) == original, "Failed write damaged existing config")
	DirAccess.remove_absolute(path + ".tmp")

func _campaign_round_trip() -> void:
	var saves := root.get_node("SaveGameService")
	var flow := root.get_node("SessionFlow")
	saves.session_managed = true
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	flow.new_game("Graphics lifecycle", 15838, preload("res://world/space/cube_sphere.gd").MODE)
	await _loaded(flow)
	_expect(_campaign_matches(), "Campaign start lost graphics preferences")
	if not _campaign_matches(): return
	var slot: String = saves.save_path
	flow.toggle_pause()
	_expect(saves.save_now(), "Campaign save failed")
	flow.return_to_title()
	await scene_changed
	flow.load_game(slot)
	await _loaded(flow)
	_expect(_campaign_matches(), "Loading a saved campaign lost graphics preferences")
	if not _campaign_matches(): return
	flow.toggle_pause()
	_expect(await flow.travel_to_planet(23757, 0, 23757), "Planet journey failed")
	await _loaded(flow)
	_expect(_campaign_matches(), "Planet change lost custom graphics")
	flow.toggle_pause()
	flow.return_to_title()
	await scene_changed

func _loaded(flow: Node) -> void:
	var start: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - start < 90000: await process_frame
	_expect(not flow.loading, "Campaign load timed out")

func _campaign_matches() -> bool:
	var air: Node = get_first_node_in_group(&"campaign_atmosphere")
	return air != null and air.graphics_values == _custom() and settings.graphics_values == _custom()

func _layout_checks() -> void:
	for viewport_size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		settings.display_mode = 0
		settings.resolution = viewport_size
		settings.ui_scale = 1.3
		settings._apply_settings(false)
		# Set the actual Window as well; Xvfb can retain the previous native size.
		root.size = viewport_size
		for locale: String in ["de", "en"]:
			root.get_node("LocaleManager").save_preference(locale)
			settings.open_menu()
			settings._tabs.current_tab = 3
			await _frames()
			_expect(root.get_visible_rect().encloses(settings._menu_panel.get_global_rect()), "Settings panel escapes viewport: " + str(viewport_size) + locale)
			var scroll: ScrollContainer = settings._tabs.get_child(3)
			await _focus_control(settings._graphics_settings.controls.saturation)
			_expect(scroll.scroll_vertical > 0, "Keyboard focus did not scroll to the last effect")
			var rect: Rect2 = settings._graphics_settings.controls.saturation.get_parent().get_global_rect()
			_expect(scroll.get_global_rect().grow(1.0).encloses(rect), "Last effect's slider/number row is clipped")
			await _capture("settings-%dx%d-%s-bottom" % [viewport_size.x, viewport_size.y, locale])
			scroll.scroll_vertical = 0
			await _frames()
			await _capture("settings-%dx%d-%s-top" % [viewport_size.x, viewport_size.y, locale])
			settings.close_menu()

func _focus_control(control: Control) -> void:
	control.grab_focus()
	await _frames()

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
		await process_frame
	await _frames()

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _fixture(scene: Node3D) -> void:
	for i in range(10):
		var instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(100, 1, 180) if i == 0 else Vector3(3, 3 + i, 3)
		instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("689047") if i % 2 == 0 else Color("b09b71")
		instance.material_override = material
		scene.add_child(instance)
		instance.position = Vector3(0, -1, -30) if i == 0 else Vector3((i % 3) * 7 - 7, mesh.size.y / 2, -i * 7)

func _frames() -> void:
	for i in range(8): await process_frame

func _capture(filename: String) -> void:
	if capture_dir.is_empty(): return
	await _frames()
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if filename.begins_with("settings-"):
		var dimensions := filename.get_slice("-", 1).split("x")
		_expect(picture.get_size() == Vector2i(int(dimensions[0]), int(dimensions[1])), "Capture window size differs from its filename")
	_expect(picture.save_png(capture_dir.path_join(filename + ".png")) == OK, "Screenshot failed")

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _finish() -> void:
	for message: String in failures: push_error(message)
	print("GRAPHICS_SETTINGS_PASSED" if failures.is_empty() else "GRAPHICS_SETTINGS_FAILED", " checks=", checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
