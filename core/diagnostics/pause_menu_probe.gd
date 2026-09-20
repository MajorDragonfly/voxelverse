extends Node
## Public title entry, actual sphere and ordinary creature -> tribe confirmation.
const Playtest = preload("res://ui/frontend/tribal_playtest.gd")
var failures: Array[String] = []
var checks: int = 0
var flow: Node
var settings: Node
var audio: Node
var captures: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	flow = get_node("/root/SessionFlow")
	settings = get_node("/root/DisplaySettings")
	audio = get_node("/root/AudioManager")
	captures = OS.get_environment("VOXELVERSE_PAUSE_CAPTURE_DIR")
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	var tree := get_tree()
	_expect(Playtest.start(flow), "Public campaign entry could not start")
	await _until(func() -> bool:
		var t: Node = tree.current_scene.get_node_or_null("Nest/Tribe")
		return t != null and t.panel.confirmation_open, 90000)
	var tribe: Node = tree.current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Tribal playtest did not reach the ordinary phase confirmation")
		await _finish()
		return
	get_node("/root/SaveGameService").autosave_enabled = false
	await _frames(3)
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and not tribe.panel.confirmation_open, "Confirmation cancel did not release pause")
	await _phase_route("creature")
	_expect(tribe.panel.open_confirmation(), "Could not reopen phase confirmation")
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 60000)
	_expect(tribe.is_active(), "Tribal camera did not acquire control")
	if tribe.is_active(): await _phase_route("tribe")
	await _finish()

func _phase_route(phase: String) -> void:
	print("PAUSE_MENU_STAGE ", phase)
	var tree := get_tree()
	var player: Node3D = tree.current_scene.player
	for locale: String in ["de", "en"]:
		get_node("/root/LocaleManager")._apply(locale)
		for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			for scaling: float in [0.8, 1.3]:
				settings.display_mode = 0
				settings.resolution = dimensions
				settings.ui_scale = scaling
				settings._apply_settings(false)
				if DisplayServer.get_name() == "headless": tree.root.size = dimensions
				await _frames(4)
				var original_mouse := Input.mouse_mode
				await _key(KEY_ESCAPE)
				_expect(flow.pause_open and tree.paused, "Esc failed in " + phase)
				if not flow.pause_open: return
				_expect(_focus_name() == "ResumeGame", "Pause lacks keyboard focus")
				var position_before := player.global_position
				var time_before: float = get_node("/root/GameState").campaign.data.elapsed_seconds
				await _key(KEY_W)
				await _key(KEY_J)
				await _key(KEY_M)
				_expect(player.global_position == position_before and get_node("/root/GameState").campaign.data.elapsed_seconds == time_before, "World input/simulation leaked through pause")
				_expect(tree.root.get_visible_rect().encloses(flow._content.get_global_rect()), "Pause actions clipped: " + str([phase, locale, dimensions, scaling]))
				if dimensions.y == 720 and scaling == 1.3: await _capture(phase + "-" + locale + "-pause")
				# Reach Settings with keyboard alone, then change categories by mouse.
				await _key(KEY_TAB)
				_expect(_focus_name() == "PauseSettings", "Settings is not second in the keyboard order")
				await _key(KEY_ENTER)
				_expect(settings.is_menu_open() and tree.paused and not flow._layer.visible, "Settings overlaps pause or loses ownership")
				_expect(settings._tabs.current_tab == 3, "Pause settings did not open Graphics")
				for tab: int in [3, 4, 1, 2, 0]:
					var bar: TabBar = settings._tabs.get_tab_bar()
					await _click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(tab).get_center())
					_expect(settings._tabs.current_tab == tab, "Category click failed: " + str(tab))
					_expect(tree.root.get_visible_rect().encloses(settings._menu_panel.get_global_rect()), "Settings clipped: " + str([phase, locale, dimensions, scaling, tab, settings._menu_panel.get_global_rect()]))
					if tab == 4:
						_expect(not is_instance_valid(audio._panel), "Audio opened a second settings window")
						var slider: HSlider = settings._audio_settings._sliders[&"music"]
						slider.grab_focus()
						await _frames(2)
						await _key(KEY_LEFT)
						_expect(is_equal_approx(audio.get_volume(&"music"), slider.value / 100.0), "Keyboard audio value did not reach the existing mixer")
					if dimensions.y == 720 and scaling == 1.3 and tab in [3, 4]:
						await _capture(phase + "-" + locale + ("-graphics" if tab == 3 else "-audio"))
				await _key(KEY_ESCAPE)
				_expect(not settings.is_menu_open() and flow.pause_open and tree.paused and flow._layer.visible, "Settings Esc failed to return to pause")
				_expect(_focus_name() == "PauseSettings", "Settings lost its return focus")
				# Every pause subpage must return one level, including long help.
				for id: String in ["PauseControls", "PauseFirstSteps", "TravelDestinations"]:
					await _click(flow._overlay.find_child(id, true, false))
					await _key(KEY_ESCAPE)
					_expect(flow.pause_open and tree.paused and flow._pause_page == "pause", "Esc resumed from subpage: " + id)
					_expect(_focus_name() == id, "Back lost originating focus: " + id)
				await _key(KEY_ESCAPE)
				_expect(not tree.paused and not flow.pause_open and Input.mouse_mode == original_mouse, "Final Esc failed to restore gameplay")
	# Applied graphics persist; an abandoned draft is discarded on reopen.
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	settings._graphics_settings.controls.exposure.value = 0.93
	await _click(settings._menu_panel.find_child("Apply", true, false))
	_expect(is_equal_approx(settings.graphics_values.exposure, 0.93), "Apply ignored graphics")
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	_expect(is_equal_approx(settings._graphics_settings.draft.exposure, 0.93), "Reopen lost applied graphics")
	settings._graphics_settings.controls.exposure.value = 1.04
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	_expect(is_equal_approx(settings._graphics_settings.draft.exposure, 0.93), "Dismissed draft overwrote saved graphics")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await _frames(2)

func _click(control: Control) -> void:
	if not is_instance_valid(control):
		_expect(false, "Missing clickable menu control")
		return
	await _frames(3)
	await _click_at(control.get_global_transform_with_canvas() * (control.size * 0.5))

func _focus_name() -> String:
	var focus := get_viewport().gui_get_focus_owner()
	return str(focus.name) if is_instance_valid(focus) else "<none>"

func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await _frames(3)

func _frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame

func _until(predicate: Callable, milliseconds: int) -> void:
	var end := Time.get_ticks_msec() + milliseconds
	while not predicate.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame

func _capture(name: String) -> void:
	if captures.is_empty(): return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(captures.path_join(name + ".png")) == OK, "Screenshot failed")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _finish() -> void:
	for message: String in failures: push_error(message)
	print("PAUSE_MENU_PASSED" if failures.is_empty() else "PAUSE_MENU_FAILED", " checks=", checks)
	await preload("res://core/runtime_shutdown.gd").finish(get_tree(), 0 if failures.is_empty() else 1)
