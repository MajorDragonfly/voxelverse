extends SceneTree
## Combined public campaign route; shared entry/pause fixture remains unchanged.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--int30-settings-restart" in OS.get_cmdline_user_args():
		await process_frame
		var audio := root.get_node("AudioManager")
		var display := root.get_node("DisplaySettings")
		var locale := root.get_node("LocaleManager")
		var ok: bool = is_equal_approx(audio.get_volume(&"music"), 0.37) \
			and audio.get_preference(&"night_mode") \
			and is_equal_approx(display.graphics_values.exposure, 0.93) \
			and is_equal_approx(display.ui_scale, 1.3) \
			and locale.locale == "en"
		print("INT30_SETTINGS_RESTART_PASSED" if ok else "INT30_SETTINGS_RESTART_FAILED")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0 if ok else 1)
		return
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	root.add_child(load("res://tests/fixtures/int30_menu_audio_book_probe.gd").new())
