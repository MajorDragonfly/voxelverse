extends SceneTree
## Public title entry; the normal tribal confirmation remains authoritative.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--r32-15-restart" in OS.get_cmdline_user_args():
		await process_frame
		var display := root.get_node("DisplaySettings")
		var locale := root.get_node("LocaleManager")
		var ok: bool = is_equal_approx(display.graphics_values.exposure, 0.93) \
			and is_equal_approx(display.ui_scale, 1.5) and locale.preference == "en"
		print("R32_15_RESTART_PASSED" if ok else "R32_15_RESTART_FAILED")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0 if ok else 1)
		return
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	root.add_child(load("res://tools/review_r32_15_campaign_probe.gd").new())
