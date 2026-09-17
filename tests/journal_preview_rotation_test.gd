extends SceneTree
## A full drag orbit must change direction without changing the preview scale.

const Preview = preload("res://ui/discovery/journal_preview.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var preview := Preview.new()
	root.add_child(preview)
	preview.size = Vector2(960, 420)
	preview.show_blueprint(Blueprint.create_default())
	await process_frame
	_orbit(preview, "creature")
	preview.show_part("feet_claws", false)
	_orbit(preview, "locked part")
	preview.show_part("feet_claws", true)
	_orbit(preview, "unlocked part")
	# Include off-origin, long, tall, wide and tiny geometry at multiple panel sizes.
	for dimensions in [Vector3(2, 2, 12), Vector3(2, 12, 2), Vector3(12, 2, 2), Vector3.ONE * 0.01]:
		preview._bounds = AABB(Vector3(7, -3, 5), dimensions)
		preview._center = preview._bounds.get_center()
		preview._radius = maxf(dimensions.length() * 0.5, 0.5)
		for panel in [Vector2(960, 420), Vector2(400, 400), Vector2(240, 800)]:
			preview.size = panel
			await process_frame
			_orbit(preview, "%s at %s" % [dimensions, panel])
	preview.size = Vector2(960, 420)
	preview.show_blueprint(Blueprint.create_default())
	await process_frame
	var initial_distance: float = preview._camera.position.distance_to(preview._center)
	_wheel(preview, MOUSE_BUTTON_WHEEL_UP)
	_check(preview._camera.position.distance_to(preview._center) < initial_distance, "Wheel still zooms in")
	_orbit(preview, "manual zoom", false)
	for step in range(20): _wheel(preview, MOUSE_BUTTON_WHEEL_UP)
	_check(is_equal_approx(preview._zoom, 0.65), "Zoom-in limit retained")
	for step in range(30): _wheel(preview, MOUSE_BUTTON_WHEEL_DOWN)
	_check(is_equal_approx(preview._zoom, 2.0), "Zoom-out limit retained")
	preview.show_blueprint(Blueprint.create_default())
	_check(is_equal_approx(preview._zoom, 1.0), "Selecting another creature resets manual zoom")
	_check(is_equal_approx(preview._camera.position.distance_to(preview._center), initial_distance), "Selection restores its fitted distance")
	preview.clear()
	_check(preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Clearing still disables rendering")
	preview.free()
	await process_frame
	for failure in failures: print("FAIL: ", failure)
	print("JOURNAL_PREVIEW_ROTATION: %d checks, %d failures" % [checks, failures.size()])
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _orbit(preview: Control, label: String, check_fit: bool = true) -> void:
	preview._frame_camera()
	var camera: Camera3D = preview._camera
	var center: Vector3 = preview._center
	var initial_position: Vector3 = camera.position
	var distance: float = camera.position.distance_to(center)
	var initial_scale: float = camera.unproject_position(center + camera.basis.x).distance_to(camera.unproject_position(center))
	var stable: bool = true
	var fitted: bool = true
	for step in range(72):
		var drag := InputEventMouseMotion.new()
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		drag.relative = Vector2(TAU / 72.0 / 0.012, 0)
		preview._on_gui_input(drag)
		stable = stable and is_equal_approx(camera.position.distance_to(center), distance)
		var pixel_scale: float = camera.unproject_position(center + camera.basis.x).distance_to(camera.unproject_position(center))
		stable = stable and is_equal_approx(pixel_scale, initial_scale)
		if check_fit:
			var inverse: Transform3D = camera.transform.affine_inverse()
			var tangent: float = tan(deg_to_rad(camera.fov * 0.5))
			var aspect: float = float(preview.viewport.size.x) / float(preview.viewport.size.y)
			for corner in range(8):
				var point: Vector3 = inverse * preview._bounds.get_endpoint(corner)
				fitted = fitted and -point.z >= camera.near and -point.z <= camera.far
				fitted = fitted and absf(point.x) <= -point.z * tangent * aspect and absf(point.y) <= -point.z * tangent
		if step == 17:
			_check(not camera.position.is_equal_approx(initial_position), label + ": drag actually rotates")
	_check(stable, label + ": camera distance and pixel scale stay constant throughout 360 degrees")
	_check(camera.position.is_equal_approx(initial_position), label + ": complete orbit returns to its starting view")
	if check_fit: _check(fitted, label + ": entire bounds fit the frustum throughout 360 degrees")


func _wheel(preview: Control, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	preview._on_gui_input(event)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
