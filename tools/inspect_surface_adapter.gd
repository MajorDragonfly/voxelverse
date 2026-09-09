extends SceneTree

## Run with a graphics display; screenshot and measurements go to user://.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var lab := preload("res://world/planet_lab/surface_adapter_lab.gd").new()
	root.add_child(lab)
	for frame in range(90):
		await physics_frame
	lab.set_paused(true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://m1d_surface.png")
	print("M1D_VISUAL ", JSON.stringify({"objects": lab.adapter.attached.size(), "radius": lab.terrain.surface.body.radius,
		"player_on_floor": lab.walker.is_on_floor(), "creature_on_floor": lab.creature.is_on_floor(),
		"screenshot": ProjectSettings.globalize_path("user://m1d_surface.png")}))
	lab.queue_free()
	await process_frame
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self)
