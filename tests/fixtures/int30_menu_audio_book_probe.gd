extends "res://core/diagnostics/pause_menu_probe.gd"
## Additive consumer cases: real scale, all chapters, previews and settings restart.

var evidence: String = ""
var cases: Array[Dictionary] = []
var preview_started: Dictionary = {}

func _ready() -> void:
	# Input, scene loading and simulation still run normally. Native evidence
	# renders exactly the requested frames rather than continuous world footage.
	if OS.get_environment("VOXELVERSE_INT30_CAPTURE_ON_DEMAND") == "1":
		RenderingServer.render_loop_enabled = false
	super._ready()

func _phase_route(phase: String) -> void:
	# The established fixture covers the 16-case pause/settings matrix once.
	if not "--int30-focused" in OS.get_cmdline_user_args():
		await super._phase_route(phase)
	evidence = OS.get_environment("VOXELVERSE_INT30_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	var ui: CanvasLayer = get_tree().current_scene.find_child("PlayerProgression", true, false)
	_expect(ui != null, "Combined campaign lacks the development book")
	if ui == null: return
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720)]:
		for language: String in ["de", "en"]:
			get_node("/root/LocaleManager").save_preference(language)
			settings.display_mode = 0
			settings.resolution = dimensions
			settings.ui_scale = 1.3
			settings._apply_settings(false)
			get_tree().root.size = dimensions
			await _frames(6)
			await _menu_audio_route(phase, language, dimensions)
			await _book_route(ui, phase, language, dimensions)
	await _persist_settings()

func _menu_audio_route(phase: String, language: String, dimensions: Vector2i) -> void:
	await _key(KEY_ESCAPE)
	_expect(flow.pause_open and get_tree().paused, "Scaled Esc entry failed: " + phase)
	await _picture("%s-%s-%dx%d-pause" % [phase, language, dimensions.x, dimensions.y], dimensions)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	_expect(settings.is_menu_open(), "Scaled settings click failed")
	await _frames(4)
	_expect(get_viewport().get_visible_rect().encloses(settings._menu_panel.get_global_rect()), "Scaled settings panel clipped: " + str(dimensions))
	await _picture("%s-%s-%dx%d-graphics" % [phase, language, dimensions.x, dimensions.y], dimensions)
	var bar: TabBar = settings._tabs.get_tab_bar()
	await _click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(4).get_center())
	_expect(is_instance_valid(audio._panel) and not settings._menu_panel.visible, "Scaled audio route overlaps its host")
	if not is_instance_valid(audio._panel): return
	var page: CanvasLayer = audio._panel
	if not audio.settings_preview_changed.is_connected(_preview_started):
		audio.settings_preview_changed.connect(_preview_started)
	var time_before: float = get_node("/root/GameState").campaign.data.elapsed_seconds
	var music_context: StringName = audio.music.current_context
	for channel: StringName in audio.CHANNELS:
		preview_started.clear()
		var preview: Button = page.find_child(String(channel) + "Preview", true, false)
		preview.grab_focus()
		await _frames(4)
		await _key(KEY_ENTER)
		# Short UI/eating clips may finish before a software-rendered input frame
		# returns. Observe the live stream at its real start signal, not later.
		_expect(preview_started.get("channel") == channel and preview_started.get("bus") == audio.CHANNELS[channel] and preview_started.get("stream", false), "Combined preview missing/wrong bus: " + String(channel))
		_expect(audio.music.current_context == music_context, "Combined preview changed soundtrack context")
		await _click(page._mutes[channel])
		_expect(audio.get_volume(channel) == 0.0 and page._mutes[channel].button_pressed, "Combined mouse mute failed: " + String(channel))
		await _click(page._mutes[channel])
		_expect(audio.get_volume(channel) > 0.0, "Combined unmute failed: " + String(channel))
	page.find_child("ResetAudio", true, false).grab_focus()
	await _key(KEY_ENTER)
	_expect(audio.volumes == audio.DEFAULTS and audio.preferences == audio.PREFERENCE_DEFAULTS, "Combined keyboard reset failed")
	_expect(get_node("/root/GameState").campaign.data.elapsed_seconds == time_before, "Audio previews advanced paused campaign time")
	await _picture("%s-%s-%dx%d-audio" % [phase, language, dimensions.x, dimensions.y], dimensions)
	await _click(page.find_child("CloseAudio", true, false))
	_expect(not is_instance_valid(audio._panel) and settings.is_menu_open() and settings._menu_panel.visible and get_tree().paused, "Audio Back did not return to settings")
	await _key(KEY_ESCAPE)
	_expect(flow.pause_open and get_tree().paused and not settings.is_menu_open(), "Settings Back did not return to pause")
	await _key(KEY_ESCAPE)
	_expect(not flow.pause_open and not get_tree().paused, "Scaled menu route did not resume")

func _preview_started(channel: StringName) -> void:
	if not channel.is_empty():
		preview_started = {"channel": channel, "bus": audio._settings_preview.bus, "stream": audio._settings_preview.stream != null}

func _book_route(ui: CanvasLayer, phase: String, language: String, dimensions: Vector2i) -> void:
	get_viewport().gui_release_focus()
	await _key(KEY_K)
	_expect(ui.visible and get_tree().paused, "Book shortcut failed in " + phase)
	if not ui.visible: return
	await _click(ui._development_tab)
	var state := get_node("/root/GameState")
	var before: Dictionary = {"state": state.export_state(), "progression": get_node("/root/ProgressionService").export_state()}
	for chapter: String in ui._development.CHAPTERS:
		var button: Button = ui._development._chapter_buttons[chapter]
		button.grab_focus()
		await _frames(5)
		_expect(ui._scroll.get_global_rect().encloses(button.get_global_rect()), "Chapter focus clipped: " + chapter)
		if chapter in ["creature", "tribe", "modern"]:
			await _click(button)
		else:
			await _key(KEY_ENTER)
		_expect(ui._development._selected == chapter, "Chapter input failed: " + chapter)
		var visible_count := 0
		for detail: Control in ui._development._chapter_details.values():
			if detail.visible: visible_count += 1
		_expect(visible_count == 1, "Chapter selection shows multiple details")
		var detail: Control = ui._development._chapter_details[chapter]
		if chapter in ["tribe", "medieval", "modern"]:
			ui._scroll.ensure_control_visible(ui._development._stage_labels[chapter]["title"])
			await _frames(5)
			await _picture("%s-%s-%dx%d-book-%s-top" % [phase, language, dimensions.x, dimensions.y, chapter], dimensions)
		ui._scroll.ensure_control_visible(detail)
		await _frames(5)
		_expect(get_viewport().get_visible_rect().encloses(ui._panel.get_global_rect()), "Scaled book panel clipped: " + str([dimensions, language, ui._panel.get_global_rect()]))
		_expect(get_viewport().get_visible_rect().encloses(ui._close.get_global_rect()), "Scaled book Close clipped")
		_expect(ui._scroll.size.y >= 80, "Scaled book has no useful detail viewport")
		_expect(not _labels(detail).contains("PATH_"), "Untranslated detail: " + chapter)
		var viewport_size := get_viewport().get_visible_rect().size
		var window_size := Vector2(get_window().size)
		var pixel_scale := minf(window_size.x / viewport_size.x, window_size.y / viewport_size.y)
		var minimum_pixels := _minimum_label_font(detail) * pixel_scale
		_expect(minimum_pixels >= 12.0, "Book text falls below 12 physical pixels: " + str([phase, language, dimensions, chapter, minimum_pixels]))
		_expect(button.get_theme_font_size("font_size") * pixel_scale >= 13.0, "Chapter text falls below 13 physical pixels")
		if chapter in ["medieval", "modern"]:
			_expect(ui._development._epochs[2 if chapter == "medieval" else 3].action.disabled, "Future chapter enabled a transition")
		var filename := "%s-%s-%dx%d-book-%s" % [phase, language, dimensions.x, dimensions.y, chapter]
		await _picture(filename, dimensions)
		cases.append({"phase": phase, "language": language, "size": [dimensions.x, dimensions.y], "ui_scale": settings.ui_scale, "chapter": chapter, "viewport": str(viewport_size), "minimum_text_pixels": minimum_pixels})
	_expect(before == {"state": state.export_state(), "progression": get_node("/root/ProgressionService").export_state()}, "Browsing all chapters changed campaign data")
	await _key(KEY_ESCAPE)
	_expect(not ui.visible and not get_tree().paused and not flow.pause_open, "Book Esc did not release only its own pause")

func _labels(node: Node) -> String:
	var result: String = node.text + "\n" if node is Label else ""
	for child: Node in node.get_children(): result += _labels(child)
	return result

func _minimum_label_font(node: Node) -> float:
	var minimum := float(node.get_theme_font_size("font_size")) if node is Label or node is Button else INF
	for child: Node in node.get_children(): minimum = minf(minimum, _minimum_label_font(child))
	return minimum

func _persist_settings() -> void:
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	settings._graphics_settings.controls.exposure.value = 0.93
	await _click(settings._menu_panel.find_child("Apply", true, false))
	audio.set_volume(&"music", 0.37)
	audio.set_preference(&"night_mode", true)
	audio.save_settings()
	get_node("/root/LocaleManager").save_preference("en")
	var output: Array = []
	var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/int30_menu_audio_book_test.gd", "--", "--int30-settings-restart"])
	var code := OS.execute(OS.get_executable_path(), command, output, true)
	_expect(code == 0 and str(output).contains("INT30_SETTINGS_RESTART_PASSED"), "Combined fresh-process settings failed: " + str(output))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)

func _picture(filename: String, dimensions: Vector2i) -> void:
	if evidence.is_empty(): return
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	_expect(picture.get_size() == dimensions, "Wrong actual capture size: " + filename)
	_expect(picture.save_png(evidence.path_join(filename + ".png")) == OK, "Capture failed: " + filename)
	if OS.get_environment("VOXELVERSE_INT30_CAPTURE_ON_DEMAND") == "1" and get_tree().paused:
		RenderingServer.render_loop_enabled = false

func _frames(count: int) -> void:
	# Real GUI input and container layout continue; each evidence frame is
	# explicitly rendered. World loading also does not need redundant GL frames.
	if OS.get_environment("VOXELVERSE_INT30_CAPTURE_ON_DEMAND") == "1":
		RenderingServer.render_loop_enabled = false
	await super._frames(count)

func _finish() -> void:
	RenderingServer.render_loop_enabled = true
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("cases.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases}, "\t"))
	print("INT30_MENU_AUDIO_BOOK_PASSED" if failures.is_empty() else "INT30_MENU_AUDIO_BOOK_FAILED", " checks=", checks)
	await super._finish()
