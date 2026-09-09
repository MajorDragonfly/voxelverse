extends SceneTree

const World = preload("res://world/planet_lab/living_planet.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var lab: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	lab = World.new()
	root.add_child(lab)
	lab.set_paused(true)
	var shore: Dictionary = {}
	var heading: Vector3
	var score: float = INF
	for face in range(6):
		for x in range(-6, 7):
			for y in range(-6, 7):
				var point: Dictionary = Cube.address(lab.body_id, face, x / 7.0, y / 7.0)
				var sample: Dictionary = lab.adapter.sample(point)
				if sample.height < 1.5 or sample.height > 8.0:
					continue
				var up: Vector3 = lab.adapter.up_at(point)
				var downhill: Vector3 = sample.normal.slide(up)
				if downhill.length() < 0.025 or downhill.length() > 0.25:
					continue
				var cost: float = absf(sample.height - 2.5) + absf(downhill.length() - 0.07) * 15.0
				if cost < score:
					score = cost
					shore = point
					heading = downhill.normalized().rotated(up, 0.55)
	assert(not shore.is_empty(), "Missing dry shoreline review fixture")
	# Move the review camera to an actual local shore, with water within metres.
	# A merely low altitude can still sit behind another dry ridge.
	var start: Dictionary = shore.duplicate(true)
	var shore_frame: Basis = lab.adapter.frame_at(start)
	var wet: Vector3 = Vector3.ZERO
	var nearest: float = INF
	for step in range(1, 9):
		for angle in range(16):
			var tangent: Vector3 = shore_frame.x * cos(angle * TAU / 16.0) + shore_frame.z * sin(angle * TAU / 16.0)
			var offset: Vector3 = tangent * step * 16.0
			var point: Dictionary = lab.adapter.offset(start, offset)
			if lab.adapter.sample(point).height < -0.3 and offset.length() < nearest:
				nearest = offset.length()
				wet = offset
	assert(wet != Vector3.ZERO, "No sea near the shoreline review fixture")
	var dry_fraction: float = 0.0
	var wet_fraction: float = 1.0
	for step in range(20):
		var middle: float = (dry_fraction + wet_fraction) * 0.5
		shore = lab.adapter.offset(start, wet * middle)
		if lab.adapter.sample(shore).height > 0.6:
			dry_fraction = middle
		else:
			wet_fraction = middle
	heading = wet.normalized().rotated(lab.adapter.up_at(shore), 0.55)
	shore.height = lab.adapter.sample(shore).height + 1.1
	lab.records[lab.body_id].player = lab._pose(shore, heading)
	lab.records[lab.body_id].spawn = shore.duplicate(true)
	lab.open_body(lab.body_id, false)
	lab._clear_ecosystem()
	lab.set_process(false)
	for child in lab.get_children():
		if child is CanvasLayer:
			child.hide()
	lab.walker.camera.position = Vector3(0.0, 5.0, 12.0)
	lab.walker.camera.look_at(lab.walker.global_position + heading * 14.0, lab.walker.up_direction)
	lab.terrain.presentation.frozen = true
	lab.terrain.presentation.time = 12.0
	for frame in range(6):
		await process_frame
	for material in lab.terrain.presentation.ground:
		material.shader = preload("res://world/planet_lab/planet_land.gdshader")
	for material in lab.terrain.presentation.water:
		material.shader = preload("res://world/planet_lab/planet_water.gdshader")
		material.set_shader_parameter("water", true)
	await _capture("surface_before")
	lab.terrain.presentation.setup(lab.terrain)
	await _capture("surface_after")
	lab.terrain.presentation.time = 17.0
	await _capture("surface_motion")
	var immersed: Dictionary = lab.adapter.offset(shore, wet.normalized() * 32.0)
	immersed.height = -1.0
	lab.walker.camera.global_position = lab.adapter.to_local(immersed)
	lab.walker.camera.look_at(lab.walker.camera.global_position + wet.normalized() * 12.0 + lab.walker.up_direction * 2.0, lab.walker.up_direction)
	lab.underwater.update_view()
	await _capture("surface_underwater")
	print("LIVING_SURFACE_REVIEW ", JSON.stringify({"shore": shore, "height": lab.adapter.sample(shore).height,
		"terrain_tiles": lab.terrain.tiles.size(), "screenshot_folder": ProjectSettings.globalize_path("user://")}))
	lab.queue_free()
	await process_frame
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self)


func _capture(filename: String) -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://" + filename + ".png")
