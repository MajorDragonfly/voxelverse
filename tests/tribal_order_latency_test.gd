extends "tribal_age_test.gd"
## Actual writer/controller/GUI. Timings are observations, not a CI speed gate.
var samples: Array = []

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
	_expect(home.establish_home().ok, "Cannot prepare command fixture.")
	await _frames(15)
	tribe.panel.open_confirmation()
	tribe.panel._confirm()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	if not tribe.is_active():
		_expect(false, "Tribe did not activate.")
		await _cleanup()
		_finish()
		return
	tribe.set_process(false)
	tribe.set_physics_process(false)
	tribe.select_all()
	var nodes: Array = tribe._visuals.get_children()
	var revision: int = tribe._visuals.rebuild_count
	for index in range(100):
		tribe.select_member(str(tribe.village().members[0].id)) if index % 2 == 0 else tribe.select_all()
		var order: String = ["wood", "stone", "food", "wait", "resume"][index % 5]
		_expect(tribe.issue_order(order), "Command rejected: " + order)
		samples.append({"order": tribe.last_order_metrics.duplicate(true), "save": saves.last_save_metrics.duplicate(true)})
		_expect(tribe.last_order_metrics.ok and saves.last_save_metrics.ok, "Successful command has failed timing receipt.")
		_expect(tribe.last_order_metrics.total_ms >= tribe.last_order_metrics.save_ms, "Command timing misses save work.")
		_expect(tribe._visuals.rebuild_count == revision and tribe._visuals.get_children() == nodes, "Pure assignment rebuilt unchanged village props.")
		var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		var persisted: Array = Registry.active(on_disk.game_state).tribe.members
		for member_index in range(persisted.size()):
			for field: String in ["id", "order", "paused_order", "cargo", "stage", "construction_id", "profession", "workplace_id"]:
				_expect(persisted[member_index].get(field) == tribe.village().members[member_index].get(field), "Acknowledged command was not persisted: " + field)
		await process_frame
	# Source amounts remain visual inputs, even though commands no longer rebuild.
	tribe.village().deposits.wood.remaining -= 1
	tribe._visuals.rebuild(tribe.village())
	_expect(tribe._visuals.rebuild_count == revision + 1 and tribe._visuals.get_children() != nodes, "Changed resource amount did not refresh props.")
	var row: Dictionary = tribe.village().members[0]
	row.cargo = "wood"
	row.stage = "return"
	_expect(saves.save_now(), "Cannot save transport fixture.")
	var before: Dictionary = tribe.village().duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(SAVE)
	var blocked := FileAccess.open("user://orders-blocked", FileAccess.WRITE)
	blocked.store_string("file, not directory")
	blocked.close()
	saves.save_path = "user://orders-blocked/save.json"
	_expect(not tribe.issue_order("stone"), "Blocked save accepted a command.")
	_expect(tribe.village() == before and FileAccess.get_file_as_string(SAVE) == bytes, "Failed command changed state, cargo or saved bytes.")
	_expect(not tribe.last_order_metrics.ok and not saves.last_save_metrics.ok, "Failed write reported successful timing receipt.")
	saves.save_path = SAVE
	_expect(saves.load_now(), "Saved command cannot reload.")
	tribe.set_process(true)
	tribe.set_physics_process(true)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	_expect(tribe.is_active(), "Reloaded command did not reactivate the controller.")
	tribe.set_process(false)
	tribe.set_physics_process(false)
	_expect(tribe.village().members[0].cargo == "wood", "Reload lost carried material.")
	tribe.select_all()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	root.get_node("DisplaySettings").ui_scale = 1.0
	tribe.panel._tabs.current_tab = 0
	tribe.panel.refresh()
	await _frames(8)
	print("TRIBAL_COMPACT_HUD ", JSON.stringify({"resolution": [1920, 1080], "height": _physical_rect(tribe.panel._hud).size.y, "ui_scale": 1.0}))
	_expect(_physical_rect(tribe.panel._hud).size.y <= 324, "Standard commands exceed 30% of the 1080p screen.")
	_expect(not tribe.panel._construction.is_visible_in_tree(), "Construction details occupy the everyday command view.")
	_expect(not tribe.panel._buttons.tool.is_visible_in_tree(), "Build actions were not separated from everyday orders.")
	await _capture("m6-compact-orders")
	for resource: String in ["wood", "stone"]:
		tribe.village().deposits[resource].remaining -= 10 - tribe.village().stock[resource]
		tribe.village().stock[resource] = 10
	await _click(tribe.panel._buttons.tool)
	_expect(tribe.village().project.get("kind") == "tool", "Build tab failed to issue a real command.")
	_expect(tribe.panel._construction.is_visible_in_tree(), "Active construction details are inaccessible.")
	await _capture("m6-construction-details")
	print("TRIBAL_ORDER_METRICS ", JSON.stringify({"target_pc_acceptance": false, "samples": samples}))
	await _cleanup()
	_finish()
