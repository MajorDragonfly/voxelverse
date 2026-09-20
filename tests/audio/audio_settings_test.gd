extends SceneTree
## Real GUI, output-bus capture and a second process using isolated device settings.
var failures: Array[String] = []
var checks := 0
var audio: Node
var capture_dir := ""
var measurements: Dictionary = {}
const SAVED := {&"master": 0.71, &"music": 0.0, &"ambience": 0.29, &"effects": 0.43, &"ui": 0.57}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	audio = root.get_node("AudioManager")
	audio.director.automatic_tracking = false
	audio.creatures.automatic_tracking = false
	audio.music.automatic_tracking = false
	audio.music.stop_immediately()
	await _frames()
	var args := OS.get_cmdline_user_args()
	if "--audio-settings-restart" in args:
		for channel in SAVED:
			_expect(is_equal_approx(audio.get_volume(channel), SAVED[channel]), "Fresh process lost " + String(channel))
		_expect(audio.get_preference(&"night_mode") and audio.get_preference(&"mute_in_background"), "Fresh process lost preferences")
		audio.open_settings()
		await _frames()
		_expect(audio._panel._mutes[&"music"].button_pressed, "Fresh page lost saved mute")
		audio.close_settings()
		print("AUDIO_SETTINGS_RESTART_PASSED" if failures.is_empty() else "AUDIO_SETTINGS_RESTART_FAILED")
		await _finish()
		return
	if "--audio-settings-capture" in args:
		capture_dir = args[args.find("--audio-settings-capture") + 1]
	audio.reset_settings()
	var display := root.get_node("DisplaySettings")
	display.open_menu()
	var opener: Button = display._menu_panel.find_child("AudioSettings", true, false)
	opener.grab_focus()
	opener.pressed.emit()
	await _frames()
	var panel: CanvasLayer = audio._panel
	_expect(paused and panel != null and panel._sliders[&"master"].has_focus(), "Host did not open focused, paused audio page")
	var slider: HSlider = panel._sliders[&"music"]
	slider.grab_focus()
	await _key(KEY_RIGHT)
	_expect(is_equal_approx(audio.get_volume(&"music"), 0.51), "Keyboard slider did not apply immediately")
	await _click(panel._mutes[&"music"])
	_expect(audio.get_volume(&"music") == 0.0 and panel._values[&"music"].text == "0 %", "Mouse mute did not synchronize slider/value")
	await _click(panel._mutes[&"music"])
	_expect(is_equal_approx(audio.get_volume(&"music"), 0.51), "Unmute lost the previous audible value")
	var context: StringName = audio.music.current_context
	var override: StringName = audio.music._override
	for channel in audio.CHANNELS:
		var preview: Button = panel.find_child(String(channel) + "Preview", true, false)
		preview.grab_focus()
		await _frames()
		await _key(KEY_ENTER)
		_expect(audio._settings_preview.bus == audio.CHANNELS[channel], "Preview uses wrong category: " + String(channel))
		_expect(audio._preview_remaining > 0.0 and audio._settings_preview.stream != null, "No real preview stream: " + String(channel))
		_expect(audio.music.current_context == context and audio.music._override == override, "Preview changed soundtrack ownership")
	_expect(not audio.play_settings_preview(&"unknown"), "Unknown preview channel accepted")
	audio.play_settings_preview(&"music")
	var preview_voice: int = audio._settings_preview.get_instance_id()
	for i in 12: audio.play_settings_preview(&"music")
	_expect(audio._settings_preview.get_instance_id() == preview_voice, "Rapid previews allocated more voices")
	await create_timer(3.2, true, false, true).timeout
	_expect(not audio._settings_preview.playing and audio._settings_preview.stream == null, "Preview outlived its three-second limit")
	slider.grab_focus()
	root.get_node("LocaleManager").save_preference("en")
	await _frames()
	_expect(slider.has_focus() and is_equal_approx(slider.value, 51.0), "Language switch lost focus or settings")
	_expect(TranslationServer.translate("AUDIO_MASTER") == "Master volume", "Audio catalog missing")
	audio.play_settings_preview(&"music")
	await _key(KEY_ESCAPE)
	await _frames()
	_expect(not is_instance_valid(audio._panel) and paused and display.is_menu_open(), "Esc did not return to paused settings host")
	_expect(opener.has_focus() and not audio._settings_preview.playing, "Back lost host focus or left preview running")
	display.close_menu()
	_expect(not paused, "Audio page changed the host's pause ownership")
	# The diagnostic input shortcut still preserves an unpaused caller.
	audio.open_settings()
	audio.set_preference(&"night_mode", true)
	audio.set_preference(&"mute_in_background", true)
	audio._panel.find_child("ResetAudio", true, false).pressed.emit()
	_expect(audio.volumes == audio.DEFAULTS and audio.preferences == audio.PREFERENCE_DEFAULTS, "Reset missed a channel or option")
	audio.close_settings()
	await _frames()
	_expect(not paused and not audio.play_settings_preview(&"music"), "Closed page accepts previews or retains pause")
	await _measure_real_players()
	await _layouts()
	# Close flushes pending slider edits even before the debounce timer fires.
	audio.open_settings()
	for channel in SAVED: audio._panel._sliders[channel].value = SAVED[channel] * 100.0
	audio.set_preference(&"night_mode", true)
	audio.set_preference(&"mute_in_background", true)
	audio.close_settings()
	var output: Array = []
	var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/audio/audio_settings_test.gd", "--", "--audio-settings-restart"])
	var code := OS.execute(OS.get_executable_path(), command, output, true)
	_expect(code == 0 and str(output).contains("AUDIO_SETTINGS_RESTART_PASSED"), "Fresh-process persistence failed: " + str(output))
	# Scene exit/shutdown releases a streaming preview too.
	audio.open_settings()
	audio.play_settings_preview(&"music")
	audio._scene_changed()
	_expect(not is_instance_valid(audio._panel) and not audio._settings_preview.playing and not paused, "Scene change retained modal preview")
	audio.open_settings()
	audio.play_settings_preview(&"music")
	audio.prepare_shutdown()
	_expect(not audio._settings_preview.playing and audio._settings_preview.stream == null, "Shutdown retained a streaming preview")
	audio.close_settings()
	await _finish()

func _measure_real_players() -> void:
	# Feed a deterministic signal through the existing gameplay/music/menu voices,
	# capturing Master downstream of all VV faders, mute flags and routing.
	audio.reset_settings()
	for channel in audio.CHANNELS: audio.set_volume(channel, 1.0)
	audio.stop_ui()
	audio.music.set_process(false)
	audio.director.set_process(false)
	audio.occlusion.set_process(false)
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 0, 1)
	camera.make_current()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2)
	for i in 22050: data.encode_s16(i * 2, roundi(sin(TAU * 440.0 * i / 22050.0) * 0.1 * 32767.0))
	stream.data = data
	var loop: AudioStreamWAV = audio.director.loop_stream(stream)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var master := AudioServer.get_bus_index(&"Master")
	var capture_index := AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, capture)
	var sources := {&"music": audio.music._voices[0], &"ambience": audio.director._ambience[&"wind_loop"],
		&"effects": audio._voices[0], &"ui": audio._ui_voices[0]}
	for channel in sources:
		var voice: Node = sources[channel]
		var bus := AudioServer.get_bus_index(voice.bus)
		var reaches_category := false
		for i in AudioServer.bus_count:
			if AudioServer.get_bus_name(bus) == audio.CHANNELS[channel]: reaches_category = true
			if bus == master: break
			bus = AudioServer.get_bus_index(AudioServer.get_bus_send(bus))
		_expect(reaches_category, "Production voice bypasses category: " + String(channel))
		voice.stream = loop
		voice.volume_db = 0.0
		voice.play()
		var full := await _rms(capture)
		audio.set_volume(channel, 0.5)
		var half := await _rms(capture)
		var unrelated: StringName = &"ui" if channel != &"ui" else &"music"
		audio.set_volume(unrelated, 0.0)
		var independent := await _rms(capture)
		audio.set_volume(unrelated, 1.0)
		audio.set_volume(channel, 0.0)
		var muted := await _rms(capture)
		audio.set_volume(channel, 1.0)
		audio.set_volume(&"master", 0.0)
		var master_muted := await _rms(capture)
		audio.set_volume(&"master", 1.0)
		_expect(full > 0.001, "No captured production audio: " + String(channel))
		_expect(half > full * 0.45 and half < full * 0.55, "Fader does not halve output: " + String(channel))
		_expect(absf(independent - half) < full * 0.02, "Unrelated fader changed output: " + String(channel))
		_expect(muted < 0.000001 and master_muted < 0.000001, "Category/master mute leaks audible output: " + String(channel))
		measurements[channel] = {"full_rms": full, "half_rms": half, "unrelated_mute_rms": independent,
			"muted_rms": muted, "master_muted_rms": master_muted}
		voice.stop()
		voice.stream = null
	AudioServer.remove_bus_effect(master, capture_index)
	scene.free()
	audio.reset_settings()

func _rms(capture: AudioEffectCapture) -> float:
	await create_timer(0.18, true, false, true).timeout
	capture.clear_buffer()
	await create_timer(0.14, true, false, true).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	_expect(not frames.is_empty(), "Mixer capture returned no frames")
	var energy := 0.0
	for frame in frames: energy += frame.length_squared() * 0.5
	return sqrt(energy / maxf(float(frames.size()), 1.0))

func _layouts() -> void:
	var display := root.get_node("DisplaySettings")
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		display.display_mode = 0
		display.resolution = dimensions
		display.ui_scale = 1.5
		display._apply_settings(false)
		if DisplayServer.get_name() == "headless": root.size = dimensions
		for locale: String in ["de", "en"]:
			root.get_node("LocaleManager").save_preference(locale)
			audio.open_settings()
			await _frames()
			var page: CanvasLayer = audio._panel
			_expect(root.get_visible_rect().encloses(page._panel.get_global_rect()), "Audio page escapes viewport: " + str(dimensions) + locale)
			await _capture("audio-%dx%d-%s-top" % [dimensions.x, dimensions.y, locale])
			# Tab through the scroll contents; every focused control must become visible.
			for i in 16:
				await _key(KEY_TAB)
				await _frames()
				var focused := root.gui_get_focus_owner()
				_expect(focused != null and page._panel.is_ancestor_of(focused), "Keyboard focus escaped audio modal")
				if focused != null and page._scroll.is_ancestor_of(focused):
					_expect(page._scroll.get_global_rect().encloses(focused.get_global_rect()), "Keyboard target clipped: " + str(focused.name))
			page._preferences[&"mute_in_background"].grab_focus()
			await _frames()
			_expect(page._scroll.scroll_vertical > 0 or dimensions.y >= 1080, "Options cannot scroll into view")
			await _capture("audio-%dx%d-%s-bottom" % [dimensions.x, dimensions.y, locale])
			await _click(page.find_child("CloseAudio", true, false))
			_expect(not is_instance_valid(audio._panel) and not paused, "Visible Back button does not close page")

func _capture(filename: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png")) == OK, "Screenshot failed")

func _click(control: Control) -> void:
	control.grab_focus()
	await _frames()
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
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

func _frames() -> void:
	for i in 4: await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	print("AUDIO_SETTINGS_RESULT ", JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "output_measurements": measurements}))
	print("AUDIO_SETTINGS_PASSED" if failures.is_empty() else "AUDIO_SETTINGS_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
