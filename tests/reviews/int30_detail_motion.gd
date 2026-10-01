extends "res://tests/reviews/int30_materials.gd"
## Controlled material-only motion strip. Semantic palette planes isolate grain
## flicker from geometric aliasing; this is not a campaign walking/LOD video.

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		push_error("Requires native renderer, output directory and baseline shader directory")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960, 540)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	report = {"seed": 15838, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info().string,
		"resolution": [960, 540], "shader_sha256": {}, "frames": [], "failures": [],
		"scope": "64 fixed camera poses per version on palette planes; isolates material phase/frequency, not real walking, wind or silhouette LOD."}
	for version: String in ["before", "after"]:
		var include_path: String = args[1].path_join("planet_surface_detail.gdshaderinc") if version == "before" else "res://assets/catalog/planet_surface_detail.gdshaderinc"
		var shader_path: String = args[1].path_join("planet_foliage.gdshader") if version == "before" else "res://assets/catalog/planet_foliage.gdshader"
		var detail: String = FileAccess.get_file_as_string(include_path)
		var code: String = FileAccess.get_file_as_string(shader_path)
		if code.is_empty() or detail.is_empty():
			push_error("Missing source shader")
			quit(1)
			return
		report.shader_sha256[version + "/include"] = detail.sha256_text()
		report.shader_sha256[version + "/planet_foliage"] = code.sha256_text()
		var shader := Shader.new()
		shader.code = code.replace('#include "res://assets/catalog/planet_surface_detail.gdshaderinc"', detail).replace("render_mode diffuse_burley;", "render_mode unshaded;")
		shaders[version + "/planet_foliage"] = shader
	await _scene("forest")
	_make_probe_planes()
	atmosphere.environment.background_mode = Environment.BG_COLOR
	atmosphere.environment.background_color = Color("15202b")
	atmosphere.environment.fog_enabled = false
	atmosphere.environment.volumetric_fog_enabled = false
	atmosphere.environment.glow_enabled = false
	atmosphere.environment.ssao_enabled = false
	for version: String in ["before", "after"]:
		_apply(version)
		for index in range(64):
			var progress: float = float(index) / 63.0
			var distance_m: float = 8.0 + sin(progress * PI) * 102.0
			var lateral_m: float = sin(progress * TAU * 4.0) * 0.025
			camera.look_at_from_position(Vector3(lateral_m, 2.0, distance_m), Vector3(0, 2, 0))
			if index == 0:
				for warm in range(6): await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			if image.save_png(output.path_join("%s_%03d.png" % [version, index])) != OK:
				report.failures.append("Missing motion frame")
			report.frames.append({"version": version, "index": index, "distance_m": distance_m,
				"lateral_m": lateral_m, "camera_transform": var_to_str(camera.transform)})
	await _teardown()
	for index in range(64):
		if report.frames[index].camera_transform != report.frames[index + 64].camera_transform:
			report.failures.append("Before/after camera pose changed")
	report.passed = report.failures.is_empty()
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("INT30_DETAIL_MOTION ", JSON.stringify({"passed": report.passed, "frames": report.frames.size(), "renderer": report.renderer}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.passed else 1)
