extends "res://core/diagnostics/pause_menu_probe.gd"
## Actual spherical campaign + ordinary confirmation. Captured PCM is mixer
## output, not a microphone/physical-device or target-PC listening acceptance.

const Text = preload("res://core/localization/ui_text.gd")
const SAVED := {&"master": 0.71, &"music": 0.0, &"ambience": 0.29, &"effects": 0.43, &"ui": 0.57}
var output_dir := ""
var recorded: Array[Dictionary] = []
var completed_phases: Array[String] = []
var tactical_completed := false
var _mix: AudioEffectCapture
var _mix_index := -1
var _master := -1

func _phase_route(phase: String) -> void:
	output_dir = OS.get_environment("VOXELVERSE_R32_AUDIO_CAPTURE_DIR")
	_expect(not output_dir.is_empty(), "Capture destination missing")
	if output_dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output_dir)
	settings.display_mode = 0
	settings.resolution = Vector2i(1280, 720)
	settings.ui_scale = 1.5
	settings._apply_settings(false)
	get_window().size = Vector2i(1280, 720)
	await _frames(4)
	if _mix == null:
		_mix = AudioEffectCapture.new()
		_mix.buffer_length = 5.0
		_master = AudioServer.get_bus_index(&"Master")
		_mix_index = AudioServer.get_bus_effect_count(_master)
		AudioServer.add_bus_effect(_master, _mix)
	audio.reset_settings()
	# Normal automatic music/environment sources, with no substituted test tone.
	await _sample(phase + "-live-world", 1.2, Callable(), "normal automatic world mix", true)
	# Ordinary confirmation replaces the HomeGroup actors with tribe residents.
	# Select a real audible resident without inventing or relocating an actor.
	var controller: Node = get_tree().current_scene.get_node("Nest/Tribe" if phase == "tribe" else "Nest/HomeGroup")
	var source: Node3D
	for candidate: Node3D in controller.actors.values():
		if candidate != get_tree().current_scene.player and audio.creatures.audible(candidate):
			source = candidate
			break
	_expect(is_instance_valid(source), "No audible existing resident in " + phase)
	if not is_instance_valid(source): return
	var before: Dictionary = audio.volumes.duplicate()
	for channel in audio.CHANNELS:
		audio.set_volume(channel, 1.0 if channel in [&"master", &"effects"] else 0.0)
	# Creature phase uses the existing reaction signal; tribe residents expose
	# the existing public audio port. Neither is an unscripted social encounter.
	await _sample(phase + "-companion-friend", 0.8, func():
		if source.has_signal("audio_event"):
			source.emit_signal("audio_event", &"friend")
		else:
			_expect(audio.play_creature(&"friend", source), "Scripted resident reaction rejected"),
		"scripted existing resident signal or public creature-audio port", true)
	await _sample(phase + "-action-eat", 0.8, func():
		_expect(audio.play_action(&"eat", get_tree().current_scene.player, phase + "-sample"), "Scripted action port rejected source"),
		"scripted public action-audio port, not a gameplay meal", true)
	for channel in before: audio.set_volume(channel, before[channel])
	for language in ["de", "en"]:
		get_node("/root/LocaleManager").save_preference(language)
		get_viewport().gui_release_focus()
		await _key(KEY_ESCAPE)
		_expect(flow.pause_open and get_tree().paused, "Esc failed in " + phase)
		await _click(flow._overlay.find_child("PauseSettings", true, false))
		var bar: TabBar = settings._tabs.get_tab_bar()
		await _click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(4).get_center())
		_expect(is_instance_valid(audio._panel) and not settings._menu_panel.visible, "Audio host route failed")
		if not is_instance_valid(audio._panel): return
		RenderingServer.render_loop_enabled = false
		var page: CanvasLayer = audio._panel
		var clock: float = get_node("/root/GameState").campaign.data.elapsed_seconds
		var context: StringName = audio.music.current_context
		var override: StringName = audio.music._override
		var prefix: String = phase + "-" + language
		for channel: StringName in audio.CHANNELS:
			# Hear the real stream on its own category, rather than allowing a
			# different audible bus to hide a silent or incorrectly routed one.
			for bus: StringName in audio.CHANNELS:
				audio.set_volume(bus, 1.0 if bus == &"master" or bus == channel or channel == &"master" else 0.0)
			var slider: HSlider = page._sliders[channel]
			slider.value = 100.0
			var preview: Button = page.find_child(String(channel) + "Preview", true, false)
			preview.grab_focus()
			await _frames(4)
			await _sample(prefix + "-preview-" + String(channel), 0.8, func(): await _key(KEY_ENTER), "real category preview from keyboard", true)
			_expect(audio.music.current_context == context and audio.music._override == override, "Preview changed music ownership")
			await _click(page._mutes[channel])
			_expect(audio.get_volume(channel) == 0.0 and page._values[channel].text == "0 %", "Mute/value mismatch")
			await _sample(prefix + "-zero-" + String(channel), 0.8, func():
				_expect(audio.play_settings_preview(channel), "Muted real preview rejected"),
				"real preview on isolated muted category; Master mutes every category", true, true)
			await _click(page._mutes[channel])
			_expect(audio.get_volume(channel) == 1.0, "Unmute lost last value")
			slider.grab_focus()
			await _key(KEY_LEFT)
			_expect(is_equal_approx(audio.get_volume(channel), 0.99), "Keyboard fader missed bus value")
		for bus: StringName in audio.CHANNELS: audio.set_volume(bus, 1.0)
		# The OS event is injected here, separately from native window focus tests.
		audio.set_preference(&"mute_in_background", true)
		audio.play_settings_preview(&"music")
		get_window().focus_exited.emit()
		_expect(page._status.text == Text.format_text("AUDIO_TEST_MUTED", {"channel": Text.text("AUDIO_MUSIC")}), "Background status missed mute")
		await _picture(prefix + "-background-muted")
		get_window().focus_entered.emit()
		_expect(page._status.text == Text.format_text("AUDIO_TEST_PLAYING", {"channel": Text.text("AUDIO_MUSIC")}), "Foreground status failed")
		audio.set_preference(&"mute_in_background", false)
		page.find_child("ResetAudio", true, false).grab_focus()
		await _key(KEY_ENTER)
		_expect(audio.volumes == audio.DEFAULTS and audio.preferences == audio.PREFERENCE_DEFAULTS, "Reset missed settings")
		_expect(clock == get_node("/root/GameState").campaign.data.elapsed_seconds, "Audio advanced paused campaign time")
		await _picture(prefix + "-audio")
		await _click(page.find_child("CloseAudio", true, false))
		_expect(not is_instance_valid(audio._panel) and not audio._settings_preview.playing and settings._menu_panel.visible and get_tree().paused, "Back lost host/pause or retained preview")
		_expect(settings._tabs.get_tab_bar().has_focus(), "Back lost category focus")
		await _key(KEY_ESCAPE)
		_expect(flow.pause_open and get_tree().paused and not settings.is_menu_open(), "Settings Back did not return to Pause")
		await _key(KEY_ESCAPE)
		_expect(not flow.pause_open and not get_tree().paused, "Final Back did not resume gameplay")
		RenderingServer.render_loop_enabled = true
	# Persist through the same page, then launch a genuinely fresh process with
	# the existing isolated-settings restart assertions (not a second registry).
	audio.open_settings()
	for channel in SAVED: audio._panel._sliders[channel].value = SAVED[channel] * 100.0
	audio.set_preference(&"night_mode", true)
	audio.set_preference(&"mute_in_background", true)
	audio.close_settings()
	var process_output: Array = []
	var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/audio/audio_settings_test.gd", "--", "--audio-settings-restart"])
	var code := OS.execute(OS.get_executable_path(), command, process_output, true)
	_expect(code == 0 and str(process_output).contains("AUDIO_SETTINGS_RESTART_PASSED"), "Combined fresh-process settings failed: " + str(process_output))
	audio.reset_settings()
	completed_phases.append(phase)

func _tactical_pause(tribe: Node) -> void:
	get_viewport().gui_release_focus()
	await _key(KEY_SPACE)
	_expect(get_tree().paused and tribe.panel.owns_world_pause(), "Space did not enter tactical pause")
	await _key(KEY_ESCAPE)
	await _click(flow._overlay.find_child("PauseSettings", true, false))
	var bar: TabBar = settings._tabs.get_tab_bar()
	await _click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(4).get_center())
	_expect(is_instance_valid(audio._panel) and get_tree().paused, "Tactical Audio route failed")
	if is_instance_valid(audio._panel):
		audio._panel._sliders[&"master"].grab_focus()
		await _key(KEY_SPACE)
		_expect(get_tree().paused and is_instance_valid(audio._panel), "Audio leaked Space into tactical world")
		await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_expect(get_tree().paused and not flow.pause_open and tribe.panel.owns_world_pause(), "Audio back discarded tactical pause")
	get_viewport().gui_release_focus()
	await _key(KEY_SPACE)
	_expect(not get_tree().paused and tribe.is_active(), "Audio return did not restore tactical controls")
	tactical_completed = true

func _sample(filename: String, seconds: float, start: Callable, recipe: String,
		require_signal: bool, expect_silent: bool = false) -> void:
	_mix.clear_buffer()
	if start.is_valid(): await start.call()
	# The World low-pass retains a short transition tail. Match the existing
	# routing test's 180-ms settling window for steady mute measurements; the
	# original un-settled capture remains a separate negative review artifact.
	if expect_silent:
		await get_tree().create_timer(0.18, true, false, true).timeout
		_mix.clear_buffer()
	await get_tree().create_timer(seconds, true, false, true).timeout
	var frames := _mix.get_buffer(_mix.get_frames_available())
	var energy := 0.0
	var peak := 0.0
	var pcm := PackedByteArray()
	pcm.resize(frames.size() * 4)
	for i in frames.size():
		energy += frames[i].length_squared() * 0.5
		peak = maxf(peak, maxf(absf(frames[i].x), absf(frames[i].y)))
		pcm.encode_s16(i * 4, roundi(clampf(frames[i].x, -1.0, 1.0) * 32767.0))
		pcm.encode_s16(i * 4 + 2, roundi(clampf(frames[i].y, -1.0, 1.0) * 32767.0))
	var rms := sqrt(energy / maxf(float(frames.size()), 1.0))
	_expect(not frames.is_empty(), "No mixer frames: " + filename)
	if require_signal: _expect(rms < 0.000001 if expect_silent else rms > 0.000001, "Unexpected output signal: " + filename)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = int(AudioServer.get_mix_rate())
	stream.data = pcm
	_expect(stream.save_to_wav(output_dir.path_join(filename)) == OK, "PCM capture failed: " + filename)
	recorded.append({"file": filename + ".wav", "recipe": recipe, "frames": frames.size(),
		"settle_seconds": 0.18 if expect_silent else 0.0,
		"mix_rate": stream.mix_rate, "rms": rms, "peak": peak, "volumes": audio.volumes.duplicate(),
		"music_context": audio.music.current_context, "paused": get_tree().paused})
	print("R32_AUDIO_SAMPLE ", recorded.back())

func _picture(filename: String) -> void:
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_expect(image.get_size() == Vector2i(1280, 720), "Wrong image size")
	_expect(image.save_png(output_dir.path_join(filename + ".png")) == OK, "Screenshot failed")
	RenderingServer.render_loop_enabled = not get_tree().paused

func _finish() -> void:
	RenderingServer.render_loop_enabled = true
	_expect(completed_phases == ["creature", "tribe"], "Both audio routes must finish")
	_expect(recorded.size() == 46, "All 46 PCM cases must finish")
	_expect(tactical_completed, "Tactical audio lifecycle must finish")
	if _mix_index >= 0:
		AudioServer.remove_bus_effect(_master, _mix_index)
	if not output_dir.is_empty():
		var file := FileAccess.open(output_dir.path_join("cases.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "completed_phases": completed_phases,
			"tactical_completed": tactical_completed, "recorded": recorded}, "\t"))
	print("R32_AUDIO_CAMPAIGN_PASSED" if failures.is_empty() else "R32_AUDIO_CAMPAIGN_FAILED", " checks=", checks)
	await super._finish()
