extends "res://core/diagnostics/spherical_campaign_probe.gd"
const Collection = preload("res://world/tribe/settlement_collection.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Navigation = preload("res://world/tribe/village_navigation.gd")
const FILE: String = "user://second-site-evidence.json"

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--second-site-restart" in OS.get_cmdline_user_args():
		await _restart_sites()
		await _done()
		return
	var path: String = saves.create_slot("Zwei echte Siedlungsorte", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _done(); return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().get("ok", false), "Home founding failed.")
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.panel.open_confirmation(), "Tribal confirmation failed.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and tribe.domestication.is_active() and not tribe.navigation.pending, 15000)
	if not tribe.is_active(): _expect(false, "Tribe inactive: " + tribe.status); await _done(); return
	# Reproduce a slow renderer through every ownership handoff, including far
	# delivery; the ordinary test keeps the user's/default frame setting.
	if "--slow-settlement-work" in OS.get_cmdline_user_args(): Engine.max_fps = 2
	var residents: Array = tribe.village().members.map(func(m: Dictionary) -> String: return m.id)
	var origin: String = tribe.village().id
	# Evaluate a bounded set of real loaded ground points, using the exact live
	# clearance/route checks. The resident walks the winning path under physics.
	tree.paused = true
	var candidate: Vector3 = await _candidate(tribe)
	tree.paused = false
	if not candidate.is_finite(): _expect(false, "No valid second site in loaded terrain."); await _done(); return
	print("SECOND_SITE candidate ", candidate, " distance ", candidate.distance_to(tribe.anchor()))
	tribe.select_member(residents[2])
	_expect(tribe.issue_order("move", candidate), "Founder movement was rejected.")
	await _until_work(func() -> bool: return tribe.member_record(residents[2]).order == "wait", 20.0, "founder walk")
	if not tribe.settlements.founding_reason().is_empty(): _expect(false, "Founder failed to arrive: " + tribe.settlements.founding_reason()); await _done(); return
	var location: Dictionary = tribe.member_record(residents[2]).position.duplicate(true)
	var home_before: Dictionary = tribe.body().home_group.duplicate(true)
	var source_stock: Dictionary = tribe.village().stock.duplicate(true)
	_expect(await tribe.settlements.found(), "Physical founding failed: " + tribe.status + " / " + saves.last_error)
	if not tribe.body().has("settlements"): await _done(); return
	print("SECOND_SITE founded")
	var second: String = Collection.ids(tribe.body())[1]
	var data: Dictionary = Collection.village(tribe.body(), second)
	_expect(data.members.size() == 1 and data.members[0].id == residents[2] and data.members[0].position == location, "Founding moved/duplicated the founder.")
	_expect(tribe.body().home_group == home_before and tribe.village().stock == source_stock, "Founding changed existing home/stock.")
	_expect(data.stock.wood == 0 and data.stock.stone == 0 and data.tools == 0, "Founding created free stock or tools.")
	_expect(not tribe.actors.has(residents[2]) and Collection.resident_count(tribe.body()) == 3, "Founder retained two physical or saved owners.")
	# Two real controllers' jobs are retained under a failed selection save.
	tribe.select_member(residents[1])
	_expect(tribe.issue_order("wood"), "Origin work was rejected.")
	await _until_work(func() -> bool: return tribe.member_record(residents[1]).cargo == "wood", 18.0, "origin pickup")
	_expect(tribe.member_record(residents[1]).cargo == "wood", "Origin carrier never picked up wood.")
	_expect(tribe.issue_order("wait"), "Could not hold cargo.")
	var held: Dictionary = tribe.member_record(residents[1]).duplicate(true)
	var selected_before: String = Collection.selected_id(tribe.body())
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not await tribe.settlements.select(second), "Failed write published selection.")
	DirAccess.remove_absolute(path + ".tmp")
	_expect(Collection.selected_id(tribe.body()) == selected_before and tribe.member_record(residents[1]) == held, "Failed selection changed held cargo or owner.")
	_expect(await tribe.settlements.select(second), "Second site selection failed: " + tribe.status + " / " + saves.last_error)
	await _until(func() -> bool: return tribe.domestication.is_active() and not tribe.navigation.pending, 8000)
	_expect(tribe.actors.size() == 1 and tribe.actors.has(residents[2]) and not tribe.actors.has(residents[0]), "Secondary site instantiated the player as its worker.")
	print("SECOND_SITE selected secondary")
	var a: Dictionary = Collection.village(tribe.body(), origin)
	_expect(a.members[1].cargo == "wood", "Held origin cargo was remotely credited.")
	tribe.select_all()
	_expect(tribe.issue_order("stone"), "Secondary stone order failed.")
	var previous_fps: int = Engine.max_fps
	if "--slow-settlement-work" in OS.get_cmdline_user_args(): Engine.max_fps = 2
	await _until_work(func() -> bool: return tribe.village().stock.stone > 0, 20.0, "secondary delivery")
	Engine.max_fps = previous_fps
	_expect(tribe.village().stock.stone > 0, "Secondary physical delivery did not reach its stock: " + JSON.stringify(tribe.village().members[0]))
	_expect(Collection.village(tribe.body(), origin).stock.stone == 0, "Secondary physical delivery changed the origin stock.")
	# Resume the same origin work through its real UI/controller, then leave it
	# active remotely while the second site's stone order continues physically.
	var returned: bool = await tribe.settlements.select(origin)
	_expect(returned, "Return to origin failed: " + tribe.status + " / " + saves.last_error)
	if not returned:
		await _done()
		return
	await _until(func() -> bool: return tribe.domestication.is_active() and not tribe.navigation.pending, 8000)
	tribe.select_member(residents[1])
	_expect(tribe.issue_order("resume"), "Held carrier could not resume.")
	_expect(await tribe.settlements.select(second), "Second return failed.")
	await _until_work(func() -> bool: return Collection.village(tribe.body(), origin).stock.wood > 0, 15.0, "origin remote delivery")
	var far: Dictionary = Collection.view(tribe.body(), origin)
	_expect(far.tribe.stock.wood > 0, "Same-body far work failed to deliver held cargo: " + JSON.stringify({"clock": state.campaign.data.elapsed_seconds, "owner": far.village_simulation.get("owner"), "cursor": far.village_simulation.get("cursor"), "roads": far.village_simulation.get("roads", {}).size(), "members": far.tribe.members.map(func(m: Dictionary) -> Dictionary: return {"id": m.id, "order": m.order, "paused_order": m.paused_order, "cargo": m.cargo, "stage": m.stage, "blocked": m.blocked, "position": m.position, "destination": m.destination}), "jobs": state.far_scheduler.queue, "paused": tree.paused}))
	if Collection.village(tribe.body(), origin).stock.wood <= 0:
		await _done()
		return
	_expect(Collection.village(tribe.body(), second).stock.wood == 0, "Origin freight appeared in the second store.")
	_expect(Collection.validate(tribe.body(), state.campaign.data).is_empty(), "Live collection invalid: " + Collection.validate(tribe.body(), state.campaign.data))
	print("SECOND_SITE both producing")
	await _capture()
	flow.toggle_pause()
	var snapshot: String = Migration.fingerprint(state.export_state())
	for index in range(12): await tree.process_frame
	_expect(Migration.fingerprint(state.export_state()) == snapshot, "Pause advanced settlement work.")
	_expect(saves.save_now(), "Two-site save failed: " + saves.last_error)
	var saved: Dictionary = saves._read_save(path)
	_expect(saves._validate_save(saved).is_empty(), "Registered collection failed save validation.")
	_expect(not Registry.active(saved.game_state).has("tribe"), "Persisted an adapter as duplicate authority.")
	_expect(Atomic.write(FILE, {"path": path, "saved": saved, "origin": origin, "second": second, "residents": residents}, false) == OK, "Restart manifest failed.")
	flow.return_to_title()
	await tree.scene_changed
	print("SECOND_SITE restart")
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/settlement_runtime_test.gd", "--", "--second-site-restart"]
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh process failed: " + str(output))
	print(str(output))
	await _done()

func _candidate(tribe: Node) -> Vector3:
	var tried: int = 0
	var candidates: Array = []
	for id: int in tribe.navigation.graph.get_point_ids():
		var point: Vector3 = tribe.navigation.graph.get_point_position(id)
		var distance: float = point.distance_to(tribe.anchor())
		if distance >= 15.5 and distance <= 17.5 and not tribe.navigation.route(tribe.anchor(), point).is_empty(): candidates.append(point)
	# Spread attempts across the existing graph instead of neighboring cells.
	for index in range(0, candidates.size(), maxi(1, candidates.size() / 20)):
		var point: Vector3 = candidates[index]
		var nav := Navigation.new()
		nav.begin(tribe.home, point)
		while nav.pending:
			nav.advance()
			if nav.pending: await tree.physics_frame
		var sites: Dictionary = nav.sites()
		if not sites.is_empty() and tribe.settlements._clear_sites(tribe.body(), Space.encode(self, point), sites): return point
		tried += 1
		if tried >= 20: break
	return Vector3.INF

func _restart_sites() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(FILE))
	await _open(expected.path, true)
	if not _expect_world(): return
	_expect(Migration.fingerprint(state.export_state()) == Migration.fingerprint(expected.saved.game_state), "Fresh process advanced work or changed collection data.")
	var body: Dictionary = state.get_current_body_record()
	_expect(Collection.selected_id(body) == expected.second and Collection.resident_count(body) == 3, "Fresh process lost selection or residents.")
	flow.resume()
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	await _until(func() -> bool: return tribe.is_active(), 15000)
	_expect(tribe.is_active() and tribe.actors.size() == 1 and tribe.actors.has(expected.residents[2]), "Fresh process bound the wrong settlement actors.")
	_expect(await tribe.settlements.select(expected.origin), "Fresh process could not revisit the origin.")
	_expect(tribe.actors.size() == 2 and tribe.actors.has(expected.residents[0]), "Revisited origin lost the player identity.")
	# Nested future versions must protect a good backup from silent fallback.
	flow.toggle_pause()
	var future: Dictionary = expected.saved.duplicate(true)
	Registry.active(future.game_state).settlements.entries[expected.second].village.economy.schema = 999
	var future_path: String = "user://second-site-future.json"
	_expect(Atomic.write(future_path, future, false) == OK, "Future fixture write failed.")
	_expect(Atomic.write(future_path + ".bak", expected.saved, false) == OK, "Future backup fixture write failed.")
	var source: String = FileAccess.get_file_as_string(future_path)
	_expect(not saves.load_now(future_path), "Future nested contract fell back to an older backup.")
	_expect(FileAccess.get_file_as_string(future_path) == source, "Future save was rewritten.")

func _until(predicate: Callable, milliseconds: int) -> void:
	var start: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - start < milliseconds: await tree.process_frame

func _until_work(predicate: Callable, seconds: float, label: String) -> void:
	# Software rendering can exhaust the per-frame physics budget. A wall-clock
	# wait then observes less walking/work than the same test at normal FPS.
	# Keep the original simulation budget and a separate finite wall-time cap;
	# residents still have to walk, gather and deliver through the live runtime.
	var started: int = Time.get_ticks_msec()
	var first_frame: int = Engine.get_physics_frames()
	var first_clock: float = state.campaign.data.elapsed_seconds
	var physics_seconds: float = 0.0
	while not predicate.call() and physics_seconds < seconds and Time.get_ticks_msec() - started < 120000:
		await tree.physics_frame
		physics_seconds = float(Engine.get_physics_frames() - first_frame) / Engine.physics_ticks_per_second
	print("SECOND_SITE_WORK ", JSON.stringify({"step": label, "complete": predicate.call(), "physics_seconds": physics_seconds, "max_fps": Engine.max_fps, "campaign_seconds": state.campaign.data.elapsed_seconds - first_clock, "wall_seconds": (Time.get_ticks_msec() - started) / 1000.0}))

func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or "--capture-dir" not in args: return
	var directory: String = args[args.find("--capture-dir") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	var page: Node
	for index in range(tribe.panel._tabs.get_tab_count()):
		if tribe.panel._tabs.get_tab_control(index).name == "Siedlungen":
			tribe.panel._tabs.current_tab = index
			page = tribe.panel._tabs.get_tab_control(index)
	page._places.select(1)
	var ids: Array = page._ids.duplicate()
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			DisplayServer.window_set_size(size)
			get_viewport().size = size
			for frame in range(8): await tree.process_frame
			page.refresh()
			tribe.panel._layout()
			for frame in range(4): await tree.process_frame
			tribe.panel._scroll.ensure_control_visible(page._places)
			for frame in range(2): await tree.process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("settlements-%s-%dx%d.png" % [locale, size.x, size.y]))
			_expect(page._places.selected == 1 and page._ids == ids, "Language/resolution changed the selected site.")
			_expect(page._found.text != "SETTLEMENT_FOUND", "Untranslated settlement action.")
	TranslationServer.set_locale("de")

func _done() -> void:
	tree.paused = false
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("SECOND_SITE_RUNTIME_PASSED: real sphere, walked founder, two sites, isolated stock, held freight, failed save, near/far, pause and fresh process.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
