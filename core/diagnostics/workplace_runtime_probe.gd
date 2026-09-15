extends "res://core/diagnostics/spherical_campaign_probe.gd"
const E = preload("res://world/tribe/village_economy.gd")
const Work = preload("res://world/tribe/village_work.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
const Collection = preload("res://world/tribe/settlement_collection.gd")

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("Zwei Forstplätze", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _done(); return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().get("ok", false), "Home founding failed.")
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.panel.open_confirmation(), "Confirmation failed.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 15000)
	if not tribe.is_active(): _expect(false, "Tribe did not activate."); await _done(); return
	Engine.time_scale = 2.0
	var data: Dictionary = tribe.village()
	# Bounded developed-village fixture: move existing natural stock into storage.
	# Placement, costs, construction, carrying and navigation below use live paths.
	data.tools = 1
	for kind: String in ["wood", "stone"]:
		data.stock[kind] = 16
		data.deposits[kind].remaining -= 16
	var identities: Array = data.members.map(func(member: Dictionary) -> String: return member.id)
	tribe.select_all()
	var positions: Array[Vector3] = []
	for key: String in ["forester", "forester:2"]:
		var point: Vector3 = _candidate(tribe)
		if not point.is_finite(): _expect(false, "No safe workplace candidate for " + key); await _done(); return
		positions.append(point)
		var before: Dictionary = tribe.village().duplicate(true)
		if key == "forester:2":
			_expect(not tribe.issue_order("forester", positions[0]) and tribe.village() == before, "Second workplace overwrote the first location.")
			DirAccess.make_dir_absolute(path + ".tmp")
			_expect(not tribe.issue_order("forester", point) and tribe.village() == before, "Failed construction save changed reservations or jobs.")
			DirAccess.remove_absolute(path + ".tmp")
		_expect(tribe.issue_order("forester", point), "Placement rejected: " + tribe.status)
		if tribe.village().project.is_empty(): await _done(); return
		_expect(tribe.village().project.station_key == key, "Construction received wrong instance key.")
		await _until(func() -> bool: return tribe.village().members.any(func(member: Dictionary) -> bool: return member.construction_id != ""), 15000)
		_expect(tribe.village().project.get("progress", -1) == 0 and tribe.village().members.any(func(member: Dictionary) -> bool: return member.construction_id == tribe.village().project.get("id", "missing")), "Construction progressed before physical material transport.")
		await _until(func() -> bool: return tribe.village().economy.stations.has(key), 40000)
		if not tribe.village().economy.stations.has(key):
			_expect(false, "Physical construction did not finish: " + key + " " + str(tribe.village().project) + " " + str(tribe.village().members))
			await _done(); return
		print("WORKPLACE_RUNTIME built ", key)
	var social_nodes: Array[Node] = tree.current_scene.find_children("SocialBehavior", "Node", true, false)
	_expect(not social_nodes.is_empty(), "No live social component for load lifecycle check.")
	if not social_nodes.is_empty():
		var social: Node = social_nodes[0]
		var parent: Node = social.get_parent()
		parent.remove_child(social)
		_expect(not saves.game_loaded.is_connected(social._on_game_loaded), "Detached social component retained its load listener.")
		parent.add_child(social)
		_expect(saves.game_loaded.is_connected(social._on_game_loaded), "Re-entered social component lost its load listener.")
	data = tribe.village()
	var first: String = data.economy.stations.forester.id
	var second: String = data.economy.stations["forester:2"].id
	_expect(first != second and E.next_station(data, "forester").is_empty(), "Instance IDs or limit failed.")
	var before: Dictionary = data.duplicate(true)
	_expect(not tribe.issue_order("forester", positions[1]) and tribe.village() == before, "Third workplace was accepted.")
	# Obtain work through the actual buttons. Assignment must preserve controls
	# during DE/EN refresh and a failed save must preserve held source references.
	tribe.panel._tabs.current_tab = 1
	for index in [1, 2]:
		tribe.select_member(identities[index])
		_expect(tribe.assign_profession("forester"), "Profession assignment failed.")
		var id: String = first if index == 1 else second
		tribe.panel._workplaces._rows[id].pressed.emit()
		_expect(tribe.member_record(identities[index]).get("workplace_id") == id, "Workplace UI did not assign its own source.")
		_expect(tribe.issue_order("wait"), "Cannot hold the assigned worker during UI checks.")
	var button: Button = tribe.panel._workplaces._rows[second]
	TranslationServer.set_locale("en")
	tribe.panel.refresh()
	_expect(button == tribe.panel._workplaces._rows[second] and button.text.contains("ready") and not button.text.contains("WORKPLACE_"), "Language refresh recreated or failed to translate workplace controls.")
	TranslationServer.set_locale("de")
	tribe.panel.refresh()
	await _layout_matrix(tribe, second)
	# The forester's normal reserve target is already met by initial stock.
	# Move surplus to a valid test sink, retaining the unchanged production proof.
	tribe.village().stock.wood = 0
	for index in [1, 2]:
		tribe.select_member(identities[index])
		_expect(tribe.issue_order("resume"), "Assigned worker did not resume after UI checks.")
		await _until(func() -> bool: return tribe.member_record(identities[index]).cargo == "wood", 25000)
		tribe.select_member(identities[index])
		var worker: Dictionary = tribe.member_record(identities[index])
		var id: String = first if index == 1 else second
		_expect(worker.cargo == "wood" and Home.distance(worker.position, tribe.village().economy.stations[E.station_key(tribe.village(), id)].position) <= 3.0, "Physical pickup used another source or skipped arrival.")
		_expect(tribe.issue_order("wait"), "Could not hold carried wood.")
	var held: Dictionary = tribe.member_record(identities[2]).duplicate(true)
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not tribe.issue_workplace(first) and tribe.member_record(identities[2]) == held, "Failed reassignment lost held freight or source.")
	DirAccess.remove_absolute(path + ".tmp")
	_expect(not tribe.issue_workplace("foreign-site") and tribe.member_record(identities[2]) == held, "Foreign workplace changed current job.")
	# Certify each real source, then run the same saved jobs through far work.
	tribe.select_all()
	_expect(tribe.issue_order("resume"), "Cannot resume held workers.")
	_expect(await tribe.finish_navigation_for_departure(), "Navigation preflight failed.")
	tribe.set_physics_process(false)
	var simulation: Dictionary = await tribe.prepare_far_simulation()
	_expect(not simulation.is_empty(), "Far handoff did not certify routes.")
	if simulation.is_empty(): await _done(); return
	for site: Dictionary in tribe.village().economy.stations.values():
		_expect(not Simulation.road_to(simulation, site.position).is_empty(), "Far handoff omitted an instance source.")
	var remote: Dictionary = tribe.village_body().duplicate(true)
	remote.tribe = tribe.village().duplicate(true)
	remote.village_simulation = simulation
	var stored: int = int(remote.tribe.stock.wood)
	var clock: float = float(simulation.cursor) + 30.0
	for tick in range(120): Simulation.advance(remote, clock)
	_expect(remote.tribe.stock.wood >= stored + 2, "Certified far paths failed to deliver both held units.")
	_expect(Work.Model.validate(remote.tribe, remote, state.campaign.data).is_empty(), "Near/far state invalidated the village.")
	var paused: String = Migration.fingerprint(remote)
	for tick in range(4): Simulation.advance(remote, clock)
	_expect(Migration.fingerprint(remote) == paused, "Fixed clock continued remote production.")
	# Converting the same village to the two-site collection preserves instance
	# identities and its read model without changing the shared source records.
	var collection: Dictionary = Collection.prepare_legacy(tribe.body(), state.campaign.data)
	_expect(collection.ok, "Two-site adapter rejected workplace instances.")
	if collection.ok:
		var places: Dictionary = Collection.workplaces(collection.body, tribe.village().id)
		_expect(places.has(first) and places.has(second) and places[second].kind == "forester", "Settlement view omitted or mislabeled an instance.")
	tribe.set_physics_process(true)
	flow.toggle_pause()
	_expect(saves.save_now() and saves.load_now(), "Live workplace Save/Load failed: " + saves.last_error)
	_expect(state.get_current_body_record().tribe.economy.stations["forester:2"].id == second, "Live reload replaced the second workplace.")
	await _done()

func _candidate(tribe: Node) -> Vector3:
	for id: int in tribe.navigation.graph.get_point_ids():
		var point: Vector3 = tribe.navigation.graph.get_point_position(id)
		if point.distance_to(tribe.anchor()) <= 12.0 and tribe.navigation.free_workplace(point, tribe.village(), "forester") and not tribe.neighbors.occupies(point) and not tribe.settlements.occupies(point): return point
	return Vector3.INF

func _until(predicate: Callable, milliseconds: int) -> void:
	var start: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - start < milliseconds: await tree.process_frame

func _layout_matrix(tribe: Node, identity: String) -> void:
	var window: Window = tree.root
	var original_size: Vector2i = window.size
	var display: Node = tree.root.get_node("DisplaySettings")
	var original_scale: float = display.ui_scale
	var row: Button = tribe.panel._workplaces._rows[identity]
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--capture-dir") + 1] if "--capture-dir" in args else ""
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			for scale_value: float in [1.0, 1.5]:
				window.size = size
				display.ui_scale = scale_value
				tribe.panel.refresh()
				for frame in range(4): await tree.process_frame
				tribe.panel._scroll.ensure_control_visible(row)
				for frame in range(3): await tree.process_frame
				var area: Rect2 = tribe.panel._scroll.get_global_rect()
				var control: Rect2 = row.get_global_rect()
				_expect(area.has_point(control.get_center()) and control.size.x <= area.size.x + 1, "Workplace action inaccessible: %s %s %.1f" % [locale, size, scale_value])
				_expect(row == tribe.panel._workplaces._rows[identity], "Layout refresh replaced the workplace control.")
				if not directory.is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(directory.path_join("workplaces-%s-%dx%d-%d.png" % [locale, size.x, size.y, roundi(scale_value * 100)]))
	window.size = original_size
	display.ui_scale = original_scale
	TranslationServer.set_locale("de")
	tribe.panel.refresh()

func _done() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("WORKPLACE_RUNTIME_PASSED: real sphere, two physically built sources, UI assignment, failure rollback, carrying, certified far paths and reload.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
