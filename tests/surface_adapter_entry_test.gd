extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = true
	var original: Node = preload("res://world/planet_lab/planet_lab.tscn").instantiate()
	root.add_child(original)
	current_scene = original
	original.walker.enabled = false
	for frame in range(3):
		await process_frame
	var button: Button = original.find_child("OpenSurfaceAdapter", true, false)
	_expect(button != null and button.is_visible_in_tree(), "M1d entry missing from the existing lab")
	# Exercise the rendered button using viewport mouse input.
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	for frame in range(6):
		await process_frame
	var probe: Node = current_scene
	_expect(probe != original and probe.scene_file_path.ends_with("surface_adapter_lab.tscn"), "Actual M1d button click failed to open its scene")
	if probe == original:
		await _finish()
		return
	probe.set_paused(true)
	_expect(not probe.walker.enabled and not probe.creature.enabled and not saves.session_active, "Probe did not pause both actors or protect campaign writes")
	_expect(probe.save_lab() and probe.load_lab(), "Interactive M1d save/load failed")
	_expect(not probe.walker.enabled and not probe.creature.enabled, "Loading unpaused a paused probe")
	probe.next_body()
	_expect(probe.body_id == "m1b:100" and probe.terrain.surface.body.radius == 50000.0,
		"Next-body action did not open the real Neris reference")
	_expect(is_instance_valid(probe.tree) and is_instance_valid(probe.creature), "Neris lost its surface specimens")
	probe.leave_lab()
	for frame in range(6):
		await process_frame
	_expect(current_scene != probe and current_scene.scene_file_path.ends_with("planet_lab.tscn"), "Returning to the existing lab failed")
	_expect(not saves.session_managed and not saves.autosave_enabled, "The original lab did not recover its prior session state")
	await _finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	current_scene.queue_free()
	await process_frame
	await process_frame
	_expect(root.get_node("SaveGameService").autosave_enabled, "Leaving both labs did not restore campaign autosave")
	for message in failures:
		push_error(message)
	print("SURFACE_ENTRY_PASSED ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
