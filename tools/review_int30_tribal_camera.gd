extends "res://tests/tribal_camera_test.gd"
## Regression: an unchanged low camera must respond to a new physical building.
func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	root.get_node("LocaleManager")._apply("de")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Cannot establish low-camera fixture.")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	if not tribe.is_active():
		_expect(false, "Camera fixture did not activate.")
		await _cleanup()
		await _finish()
		return
	tribe.set_physics_process(false)
	var rig: RefCounted = tribe.camera_rig
	rig.tilt = 3.0
	rig.current_zoom = 12.0
	tribe._zoom = 12.0
	rig.update_camera()
	var aim: Vector3 = tribe._focus + Vector3.UP * 1.5
	var old_eye: Vector3 = tribe.camera.global_position
	var wall := StaticBody3D.new()
	wall.name = "NewBuildingCollision"
	wall.position = aim.lerp(old_eye, 0.6)
	wall.basis = tribe.camera.global_basis
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 12, 0.5)
	collider.shape = box
	wall.add_child(collider)
	scene.add_child(wall)
	await physics_frame
	await physics_frame
	var hit: Dictionary = tribe.camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(aim, old_eye, 1))
	_expect(not hit.is_empty() and hit.collider == wall, "New building does not intersect the original camera line.")
	# Same focus/yaw/tilt/zoom: original cache incorrectly suppresses collision.
	for i in range(20): rig.advance(1.0 / 60.0)
	var new_eye: Vector3 = tribe.camera.global_position
	_expect(new_eye.distance_to(old_eye) > 1.0, "Stationary low camera ignored a newly streamed/built collider.")
	print("INT30_TRIBE_COLLISION ", JSON.stringify({"old_eye": str(old_eye), "new_eye": str(new_eye), "move_m": new_eye.distance_to(old_eye), "blocked": not hit.is_empty()}))
	wall.free()
	await physics_frame
	for i in range(20): rig.advance(1.0 / 60.0)
	_expect(tribe.camera.global_position.distance_to(old_eye) < 0.1, "Camera retained the removed building collision.")
	# Real pointer/ray selection must still work with the shallow perspective lens.
	var resident_id: String = tribe.actors.keys()[0]
	var actor: Node3D = tribe.actors[resident_id]
	var pixel: Vector2 = tribe.camera.unproject_position(actor.global_position + Vector3.UP * 0.8)
	await _world_click(pixel, MOUSE_BUTTON_LEFT)
	_expect(resident_id in tribe.selected, "Low-view perspective broke resident mouse selection.")
	var map: CanvasLayer = get_first_node_in_group(&"minimap_hud")
	if map != null:
		map._update_snapshot()
		var yaw_before: float = rig.yaw
		await _click(map._camera_controls.get_node("TRIBE_MAP_TURN_RIGHT"))
		_expect(rig.yaw != yaw_before, "Real minimap mouse button did not rotate shallow view.")
	await _cleanup()
	if failures.is_empty(): print("INT30_TRIBE_CAMERA_PASSED")
	await _finish()
