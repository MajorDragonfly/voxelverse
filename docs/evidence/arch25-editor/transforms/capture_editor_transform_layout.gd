extends "res://tests/editor_localization_test.gd"
## Targeted visual follow-up for the final transform-grid label correction.
func _run() -> void:
	await _settle()
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	editor = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	await _settle()
	editor._set_mode("parts")
	editor._select_part_by_index(0)
	editor._toggle_workshop_pane()
	for size_value: Vector2i in [Vector2i(800, 600), Vector2i(1920, 1080)]:
		var scale_value := 1.5 if size_value.x == 800 else 1.0
		root.size = size_value
		root.get_node("DisplaySettings").ui_scale = scale_value
		for language: String in ["de", "en"]:
			root.get_node("LocaleManager")._apply(language)
			editor._queue_workshop_layout()
			await _settle()
			var scroll: ScrollContainer = editor._right_panel.get_child(0)
			scroll.ensure_control_visible(editor._part_fields.rotation_1)
			await _settle()
			for field: String in ["position_0", "rotation_1", "shape_2"]:
				_expect(editor._part_fields[field].size.y < 80 * scale_value, "Transform label collapsed into vertical text")
			_expect(Rect2(Vector2.ZERO, Vector2(size_value)).encloses(editor._right_panel.get_global_rect()), "Inspector leaves viewport")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("transform-%s-%dx%d-%d.png" % [language, size_value.x, size_value.y, roundi(scale_value * 100)]))
	editor.free()
	await _settle()
	await _finish()
