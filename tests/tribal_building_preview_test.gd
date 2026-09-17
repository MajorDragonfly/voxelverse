extends "tribal_age_test.gd"
const Space = preload("res://world/surface/gameplay_space.gd")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Cannot prepare preview fixture.")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	if not tribe.is_active():
		_expect(false, "Tribe did not activate.")
		await _cleanup()
		_finish()
		return
	tribe.set_process(false)
	tribe.set_physics_process(false)
	var data: Dictionary = tribe.village()
	data.tools = 1
	for resource: String in ["wood", "stone"]:
		data.deposits[resource].remaining = 0
		data.stock[resource] = 16
	data.economy.stations.fiberbed = {"id": Model.Ids.scoped("workplace", data.id, "fiberbed"), "position": data.deposits.fiber.position.duplicate()}
	data.stock.fiber = 8
	data.economy.produced.fiber = 8
	_expect(saves.save_now(), "Preview stock fixture cannot save: " + saves.last_error)
	var before: Dictionary = data.duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(SAVE)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	root.get_node("DisplaySettings").ui_scale = 1.0
	tribe.select_all()
	await _frames(5)
	var site: Vector3 = Space.resolve(tribe, data.sites[0])
	var ghost: Node3D = tribe.building_preview
	await _click(tribe.panel._buttons.hut)
	await _point_at(site)
	_expect(ghost.visible and ghost.result.get("ok", false), "Free site has no valid hut preview: " + str(ghost.result))
	if not is_instance_valid(ghost._model):
		await _cleanup()
		await _finish()
		return
	_expect(ghost.global_position.distance_to(tribe.navigation.snap(site)) < 0.01, "Ghost and click use different snapping.")
	_expect(ghost.find_children("*", "CollisionObject3D", true, false).is_empty() and ghost.find_children("*", "CollisionShape3D", true, false).is_empty(), "Ghost adds collision.")
	var meshes: Array = ghost._model.get_children()
	for frame in range(3):
		ghost.show_at(site)
	_expect(ghost._model.get_children() == meshes, "Stationary ghost rebuilt its meshes.")
	_expect(tribe.village() == before and FileAccess.get_file_as_string(SAVE) == bytes, "Preview reserved goods or changed persistent data.")
	await _capture("placement-hut-free")
	await _point_at(tribe.anchor())
	_expect(ghost.visible and not ghost.result.get("ok", true), "Village center is not marked blocked.")
	await _capture("placement-hut-blocked")
	await _world_click(tribe.camera.unproject_position(tribe.anchor()), MOUSE_BUTTON_RIGHT)
	_expect(tribe.placement == "hut" and tribe.village() == before and FileAccess.get_file_as_string(SAVE) == bytes, "Blocked placement changed the village.")
	await _point_at(site)
	paused = true
	await _frames(3)
	_expect(not ghost.visible, "Ghost remains above paused/modal UI.")
	paused = false
	await _point_at(site)
	_expect(ghost.visible, "Ghost failed to return after pause.")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(tribe.placement.is_empty() and not ghost.visible and tribe.panel._hud_content.visible, "Escape failed to cancel and restore the build menu.")
	_expect(tribe.village() == before and FileAccess.get_file_as_string(SAVE) == bytes, "Escape spent materials.")
	# Every freely placed tribe structure has geometry, without committing it.
	for kind: String in ["tent", "pen", "laying_site", "well", "forester", "quarry", "fiberbed"]:
		_expect(tribe.issue_order(kind), "Cannot begin preview: " + kind)
		await _point_at(site)
		_expect(ghost.visible and ghost._kind == kind and ghost._model.get_child_count() > 0, "Missing model for " + kind)
		if kind in ["tent", "well"]:
			await _capture("placement-" + kind + "-free")
		_key(KEY_ESCAPE)
		await _frames(2)
	_expect(tribe.village() == before and FileAccess.get_file_as_string(SAVE) == bytes, "Switching building types mutated the campaign.")
	tribe.issue_order("hut")
	await _point_at(site)
	# Pointer over the HUD hides the ghost and cannot place through the controls.
	var hud_point: Vector2 = tribe.panel._collapse.get_global_transform_with_canvas() * (tribe.panel._collapse.size * 0.5)
	await _pointer(hud_point)
	_expect(not ghost.visible, "Ghost remains behind the HUD.")
	await _world_click(hud_point, MOUSE_BUTTON_RIGHT)
	_expect(tribe.village() == before, "Right-click through HUD placed a building.")
	await _point_at(site)
	data.stock.wood = 0
	ghost.show_at(site)
	_expect(not ghost.result.ok and not ghost.result.reason.is_empty(), "Missing materials appear valid.")
	data.stock.wood = before.stock.wood
	tribe.selected.clear()
	ghost.show_at(site)
	_expect(not ghost.result.ok, "No selected builder appears valid.")
	tribe.select_all()
	# A write failure keeps the pending ghost and exactly the old order/stock.
	var blocked := FileAccess.open("user://preview-blocked", FileAccess.WRITE)
	blocked.store_string("file, not directory")
	blocked.close()
	saves.save_path = "user://preview-blocked/save.json"
	await _point_at(site)
	await _world_click(tribe.camera.unproject_position(site), MOUSE_BUTTON_RIGHT)
	_expect(tribe.placement == "hut" and tribe.village() == before and FileAccess.get_file_as_string(SAVE) == bytes, "Failed placement spent goods or dismissed the ghost.")
	saves.save_path = SAVE
	# A load abandons transient placement rather than persisting a phantom site.
	_expect(saves.load_now(), "Cannot reload preview fixture.")
	tribe.set_process(true)
	tribe.set_physics_process(true)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	tribe.set_process(false)
	tribe.set_physics_process(false)
	_expect(tribe.placement.is_empty() and not ghost.visible and tribe.village().project.is_empty(), "Reload restored an unconfirmed building.")
	tribe.select_all()
	_expect(tribe.issue_order("hut"), "Cannot resume placement after load.")
	await _point_at(site)
	var destination: Vector3 = ghost.global_position
	var stock: Dictionary = tribe.village().stock.duplicate()
	await _world_click(tribe.camera.unproject_position(site), MOUSE_BUTTON_RIGHT)
	await _frames(3)
	_expect(tribe.village().project.get("kind") == "hut" and tribe.placement.is_empty() and not ghost.visible, "Valid click did not replace the ghost with construction.")
	if tribe.village().project.get("kind") == "hut":
		_expect(Space.resolve(tribe, tribe.village().project.position).distance_to(destination) < 0.01, "Committed site differs from the preview.")
		_expect(tribe.village().stock.wood == stock.wood - 6 and tribe.village().stock.stone == stock.stone - 3, "Placement charged the wrong amount.")
	await _capture("placement-committed")
	await _cleanup()
	_finish()

func _point_at(point: Vector3) -> void:
	await _pointer(tribe.camera.unproject_position(point))

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(12)

func _finish() -> void:
	if failures.is_empty(): print("TRIBAL_PREVIEW_PASSED")
	await super._finish()
