extends "res://tools/review_r32_04_campaign_capture.gd"
## Supplementary views at an actual sampled shore inside the existing camera
## range. No substituted terrain, collider, water or render/streaming budget.

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Could not begin ordinary shore campaign.")
	await _until(func() -> bool:
		var owner: Node = current_scene.get_node_or_null("Nest/Tribe")
		return owner != null and owner.panel.confirmation_open, 90000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Ordinary shore campaign preparation failed.")
		await _finish()
		return
	saves.autosave_enabled = false
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 20000)
	if not tribe.is_active() or tribe.navigation.pending:
		_expect(false, "Shore campaign did not activate.")
		await _finish()
		return
	state.set_process(false)
	state.campaign.data.elapsed_seconds = 120.0
	tribe.set_physics_process(false)
	var village_before: Dictionary = tribe.village().duplicate(true)
	var rig: RefCounted = tribe.camera_rig
	var frame: Basis = Space.frame(tribe, tribe.anchor())
	var shore: Dictionary = _find_shore(frame)
	_expect(not shore.is_empty(), "No actual freshwater shore found inside the unchanged 128 m camera range.")
	if shore.is_empty():
		await _finish()
		return
	var map: Node = get_first_node_in_group(&"minimap_hud")
	if map != null: map.set_process(false)
	rig.focus_home()
	rig.move_focus(shore.dry - tribe.anchor())
	var focus_frame: Basis = Space.frame(tribe, tribe._focus)
	var toward_water: Vector3 = (shore.wet - shore.dry).slide(focus_frame.y).normalized()
	var shore_yaw: float = rad_to_deg((-frame.z).signed_angle_to(toward_water, frame.y))
	var terrain: Node = current_scene.terrain
	for pose: Dictionary in [
		{"label":"shore-eye-level", "tilt":3.0,"zoom":12.0,"yaw":shore_yaw},
		{"label":"shore-eye-level-side", "tilt":3.0,"zoom":12.0,"yaw":shore_yaw + 90.0},
		{"label":"shore-low-wide", "tilt":3.0,"zoom":72.0,"yaw":shore_yaw},
		{"label":"shore-lens-boundary", "tilt":25.0,"zoom":72.0,"yaw":shore_yaw}]:
		paused = false
		rig.yaw = pose.yaw
		rig.tilt = pose.tilt
		rig.current_zoom = pose.zoom
		tribe._zoom = pose.zoom
		rig.update_camera()
		for i in range(3): await process_frame
		var address: Dictionary = Space.address(tribe,tribe._focus)
		await _until(func() -> bool:
			var tile: Dictionary = terrain.layout.find_at(address.face,address.u,address.v,terrain.leaves)
			return not tile.is_empty() and float(tile.width) * terrain.surface.body.radius <= 32.0 and terrain._job == null and terrain._pending.is_empty(), 90000)
		var tile: Dictionary = terrain.layout.find_at(address.face,address.u,address.v,terrain.leaves)
		_expect(not tile.is_empty() and float(tile.width) * terrain.surface.body.radius <= 32.0 and terrain._job == null and terrain._pending.is_empty(), "Shore visual publication did not settle at the existing detail level.")
		if map != null: map._update_snapshot()
		await _capture(pose.label)
		var row: Dictionary = capture_rows.back()
		_expect(row.minimum_frame_clearance_m >= 0.8, "Shore frame corner remains buried: " + pose.label)
		if pose.label == "shore-eye-level":
			_expect(row.forward_up_abs < 0.15, "Actual shore violated the original eye-level criterion.")
	var record := {"shore_dry_address":Space.address(tribe,shore.dry), "shore_wet_address":Space.address(tribe,shore.wet),
		"dry_sample":Space.sample(tribe,shore.dry), "wet_sample":Space.sample(tribe,shore.wet),
		"focus_distance_m":tribe._focus.distance_to(tribe.anchor()), "camera_range_m":rig.RANGE,
		"tiles":terrain.leaves.size(), "colliders":terrain.active.size(), "peak_meshes":terrain.peak_resident_meshes,
		"limits":"Camera observation only. Residents and physical cover remain at the village; drinking reach is checked separately."}
	var file := FileAccess.open(capture_dir.path_join("shore.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"))
	_expect(tribe.village() == village_before, "Shore observation changed village state.")
	_expect(terrain.leaves.size() <= 768 and terrain.active.size() <= 24 and terrain.peak_resident_meshes <= 1536, "Shore camera exceeded existing terrain budgets.")
	print("R32_04_SHORE_METRICS ",JSON.stringify(record))
	if failures.is_empty(): print("R32_04_SHORE_CAPTURE_PASSED")
	await _finish()

func _find_shore(frame: Basis) -> Dictionary:
	var closest: Dictionary = {}
	var distance: float = INF
	for x: int in range(-120,121,4):
		for z: int in range(-120,121,4):
			var offset := Vector2(x,z)
			if offset.length() > 120.0: continue
			var dry: Vector3 = tribe.anchor() + frame.x * x + frame.z * z
			var dry_sample: Dictionary = Space.sample(tribe,dry)
			if dry_sample.water: continue
			for direction: Vector2 in [Vector2(4,0),Vector2(-4,0),Vector2(0,4),Vector2(0,-4)]:
				var wet: Vector3 = dry + frame.x * direction.x + frame.z * direction.y
				var sample: Dictionary = Space.sample(tribe,wet)
				if not sample.water or sample.get("water_kind", "ocean") not in ["lake","river"] or sample.water_level - sample.height < 0.2: continue
				if offset.length() < distance:
					distance = offset.length()
					var dry_place: Dictionary = Space.address(tribe,dry)
					var wet_place: Dictionary = Space.address(tribe,wet)
					dry_place.height = dry_sample.height + 0.08
					wet_place.height = sample.water_level + 0.08
					closest = {"dry":Space.adapter(tribe).to_local(dry_place),"wet":Space.adapter(tribe).to_local(wet_place)}
	return closest
