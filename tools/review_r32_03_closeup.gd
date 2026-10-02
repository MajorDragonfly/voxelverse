extends "res://tools/review_r32_03_frames.gd"
## Supplementary 720p view of the same input/geometry/camera. Fixture HUDs are
## suppressed; rendered target/body/camera samples accompany every video frame.
func _phase(name_value: String, seconds: float) -> void:
	fixture.phase = name_value
	var end: float = fixture.elapsed + seconds
	while fixture.elapsed < end:
		await process_frame
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i.ZERO
		root.content_scale_factor = 1.0
		_hide_layers(fixture, caption.get_parent())
		caption.position = Vector2(18, 18)
		caption.add_theme_font_size_override("font_size", 20)
		var body: Vector3 = fixture.point(fixture.player)
		var target: Vector3 = fixture.point(fixture.player.camera_pivot)
		caption.text = "%s | %.2fx Koerper | %d FPS-Kappung\nKoerper %.3f m | Kameraziel %.3f m | Boden %s | Versatz %.3f m" % [name_value, body_scale, cap, body.y, target.y, fixture.player.is_on_floor(), fixture.player._camera_step_offset]
		await RenderingServer.frame_post_draw
		var wall: int = Time.get_ticks_usec()
		root.get_texture().get_image().save_png(output.path_join("frame_%05d.png" % frames.size()))
		frames.append({"frame": frames.size(), "wall_us": wall, "physics_time_s": fixture.elapsed, "phase": name_value,
			"body": fixture._vec(fixture.point(fixture.player)), "pivot": fixture._vec(fixture.point(fixture.player.camera_pivot)),
			"camera": fixture._vec(fixture.point(fixture.player.camera)), "floor": fixture.player.is_on_floor(), "offset_m": fixture.player._camera_step_offset})

func _hide_layers(node: Node, kept: Node) -> void:
	if node is CanvasLayer and node != kept: node.hide()
	for child: Node in node.get_children(): _hide_layers(child, kept)
