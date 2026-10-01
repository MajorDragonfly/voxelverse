extends "res://tests/tribal_playtest_test.gd"
## Public spherical village, real work/cargo/building, persisted cold-process cases.
const Space = preload("res://world/surface/gameplay_space.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const SNAPSHOT: String = "user://int30_village_expected.json"
var observations: Array = []
var capture_directory: String = ""
var capture_on_demand: bool = false
var saw_work: bool = false
var capture_work_requested: bool = false

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	flow.menu_error.connect(func(message: String) -> void: print("INT30_PUBLIC_LOAD_ERROR:", message))
	saves.autosave_enabled = false
	root.get_node("LocaleManager")._apply("de")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_directory = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_directory)
		capture_on_demand = true
		RenderingServer.render_loop_enabled = false
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	if "--capture-snapshots" in args:
		await _render_saved_village(args[args.find("--capture-snapshots") + 1])
		await _done()
		return
	if "--int30-restart" in args:
		await _cold_resume()
		await _done()
		return
	var tribe: Node
	if "--start-from-checkpoint" in args:
		var checkpoint: String = args[args.find("--start-from-checkpoint") + 1]
		flow.world_started.connect(func() -> void: state.set_simulation_speed(0.0), CONNECT_ONE_SHOT)
		await flow.load_game(_import_recorded_slot(checkpoint))
		tribe = await _active_village()
		if tribe == null: await _done(); return
		_expect(tribe.village().huts == 0 and tribe.village().project.get("kind") == "hut", "Checkpoint is not an unfinished actual hut.")
		var carried: bool = false
		for member: Dictionary in tribe.village().members:
			carried = carried or not member.construction_id.is_empty()
		_expect(carried, "Retry source has no held physical construction material.")
		observations.append({"real_checkpoint_source": checkpoint, "campaign_id": state.campaign.data.id, "clock": state.campaign.data.elapsed_seconds})
		state.set_simulation_speed(1.0)
	else:
		_expect(Playtest.start(flow), "Public spherical test entry rejected.")
		await _until(func() -> bool:
			var t: Node = current_scene.get_node_or_null("Nest/Tribe")
			return t != null and t.panel.confirmation_open, 90000)
		tribe = current_scene.get_node_or_null("Nest/Tribe")
		if tribe == null or not tribe.panel.confirmation_open:
			_expect(false, "Public sphere did not prepare tribal confirmation.")
			await _done()
			return
		tribe.panel.confirm.pressed.emit()
		await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 90000)
		if not tribe.is_active():
			_expect(false, "Explicit handoff did not activate village: " + tribe.status)
			await _done()
			return
		print("INT30_STAGE: real gathering")
		tribe.select_all()
		_expect(tribe.issue_order("wood"), "Wood order failed.")
		await _work_until(tribe, func() -> bool: return int(tribe.village().stock.wood) >= 12, 45000)
		_expect(int(tribe.village().stock.wood) >= 12, "Real wood transport did not reach warehouse.")
		if not failures.is_empty(): await _done(); return
		print("INT30_STAGE: wood delivered, gather stone")
		_expect(tribe.issue_order("stone"), "Stone order failed.")
		await _work_until(tribe, func() -> bool: return int(tribe.village().stock.stone) >= 6, 45000)
		_expect(int(tribe.village().stock.stone) >= 6 and saw_work, "Real stone/work tool not observed.")
		if not failures.is_empty(): await _done(); return
		print("INT30_STAGE: stone delivered, build tool")
		_expect(tribe.issue_order("tool"), "Tool construction failed: " + tribe.status)
		await _work_until(tribe, func() -> bool: return int(tribe.village().tools) == 1, 20000)
		_expect(int(tribe.village().tools) == 1, "Tool was not built from delivered resources.")
		if not failures.is_empty(): await _done(); return
		print("INT30_STAGE: tool built, place hut")
		await _until(func() -> bool: return tribe.navigation.is_ready(), 90000)
		var site: Vector3 = Vector3.INF
		for place: Variant in tribe.village().sites:
			var point: Vector3 = Space.resolve(tribe, place)
			if tribe.placement_check("hut", point).ok:
				site = point
				break
		_expect(site.is_finite(), "No valid hut site on real spherical terrain.")
		if not site.is_finite(): await _done(); return
		_expect(tribe.issue_order("hut", site), "Hut order failed: " + tribe.status)
		# Terrain certification uses the same setup budget as the public sphere entry.
		# Durable command latency is measured independently below.
		var certification_started: int = Time.get_ticks_msec()
		await _until(func() -> bool: return tribe.navigation.is_ready(), 90000)
		observations.append({"physical_graph_setup_ms": Time.get_ticks_msec() - certification_started})
		_expect(tribe.navigation.is_ready(), "Building footprint recertification did not finish.")
		if not tribe.navigation.is_ready(): await _done(); return
		await _work_until(tribe, func() -> bool:
			for member: Dictionary in tribe.village().members:
				if not member.construction_id.is_empty(): return true
			return false, 20000)
		var construction_cargo: bool = false
		for member: Dictionary in tribe.village().members:
			construction_cargo = construction_cargo or not member.construction_id.is_empty()
		_expect(construction_cargo, "No physically carried building material was observed.")
		if not construction_cargo: await _done(); return
	tribe.select_all()
	_expect(tribe.issue_order("wait"), "Cannot hold building freight.")
	await _checkpoint_restart(tribe, "construction_cargo")
	if not failures.is_empty(): await _done(); return
	# The child completed the saved, physically unfinished construction.
	await flow.load_game(saves.save_path)
	tribe = await _active_village()
	if tribe == null: await _done(); return
	_expect(tribe.village().huts == 1 and tribe.village().project.is_empty(), "Cold construction result did not reopen.")
	_expect(tribe._shelters.get_child_count() == 1, "Finished hut is absent or duplicated.")
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	for kind: String in tribe._visuals.stockpiles.lots:
		var lot: Node3D = tribe._visuals.stockpiles.lots[kind].root
		var hit: Dictionary = Space.floor_hit(lot, lot.global_position, 2.0, 4.0)
		_expect(not hit.is_empty() and lot.global_position.distance_to(hit.position) < 0.03, "Sphere stock lost streamed floor: " + kind)
		_expect(lot.global_basis.y.dot(Space.up(lot, lot.global_position)) > 0.9999, "Stock lost radial orientation: " + kind)
	paused = true
	await _capture_village(tribe, "01_finished_village_near", false)
	await _capture_village(tribe, "02_finished_village_far", true)
	await _capture_village(tribe, "03_finished_village_near_return", false)
	paused = false
	print("INT30_STAGE: held gathered cargo")
	tribe.select_all()
	_expect(tribe.issue_order("wait"), "Cannot stop completed builders.")
	await _sample_orders(tribe)
	var worker_id: String = tribe.village().members[1].id
	capture_work_requested = true
	tribe.select_member(worker_id)
	_expect(tribe.issue_order("wood"), "Single carrier could not gather.")
	await _work_until(tribe, func() -> bool: return tribe.member_record(worker_id).cargo == "wood", 25000)
	_expect(tribe.member_record(worker_id).cargo == "wood", "Gathered cargo never left actual source.")
	_expect(tribe.issue_order("wait"), "Cannot hold gathered cargo.")
	await _checkpoint_restart(tribe, "gathered_cargo")
	if not failures.is_empty(): await _done(); return
	await flow.load_game(saves.save_path)
	tribe = await _active_village()
	if tribe == null: await _done(); return
	print("INT30_STAGE: certified near/far handoff")
	tribe.select_all()
	_expect(tribe.issue_order("wait"), "Cannot prepare quiet far handoff.")
	tribe.select_member(worker_id)
	_expect(tribe.issue_order("wood"), "Cannot gather freight for far handoff.")
	await _work_until(tribe, func() -> bool: return tribe.member_record(worker_id).cargo == "wood", 25000)
	paused = true
	_expect(await tribe.finish_navigation_for_departure(), "Physical routes could not settle.")
	_expect(await saves.prepare_body_departure(tribe), "Actual SaveService near/far handoff failed: " + saves.last_error)
	var owner: Dictionary = tribe.village_body().get("village_simulation", {})
	_expect(owner.get("owner") == "far" and not owner.get("roads", {}).is_empty(), "Handoff lacks certified persisted routes.")
	_expect(tribe.member_record(worker_id).cargo == "wood", "Handoff lost physical cargo.")
	# The source is retained but paused; only the certified far owner may write.
	await _checkpoint_restart(tribe, "far_cargo")
	await _done()

func _work_until(tribe: Node, predicate: Callable, milliseconds: int) -> void:
	# Physics progress is measured in campaign time. Software rendering may run
	# fewer physics ticks per wall second; retain a separate bounded wall guard.
	var deadline: int = Time.get_ticks_msec() + maxi(milliseconds * 20, 120000)
	var campaign_deadline: float = state.campaign.data.elapsed_seconds + milliseconds / 1000.0
	while not predicate.call() and Time.get_ticks_msec() < deadline and state.campaign.data.elapsed_seconds < campaign_deadline:
		await physics_frame
		await process_frame
		for member: Dictionary in tribe.village().members:
			var tool: Node3D = tribe.actors[member.id].get_node_or_null("TribeWorkTool")
			if tool != null and tool.visible and (member.work > 0.0 or tribe.village().project.get("progress", 0.0) > 0.0):
				saw_work = true
				if capture_work_requested and not capture_directory.is_empty():
					capture_work_requested = false
					paused = true
					await _capture_village(tribe, "04_finished_village_actual_work", false)
					observations.append({"actual_worker": member.id, "work": member.work, "tool_visible": tool.visible, "cargo": member.cargo})
					paused = false

func _checkpoint_restart(tribe: Node, kind: String) -> void:
	paused = true
	_expect(saves.save_now(), "Checkpoint failed: " + kind + " / " + saves.last_error)
	var expected := {"path": saves.save_path, "case": kind,
		"village": tribe.village().duplicate(true), "simulation": tribe.village_body().get("village_simulation", {}).duplicate(true),
		"clock": state.campaign.data.elapsed_seconds, "campaign_id": state.campaign.data.id,
		"transitions": state.campaign.data.completed_transitions.duplicate(true)}
	_expect(Atomic.write(SNAPSHOT, expected, false) == OK, "Could not record cold expectation.")
	if not capture_directory.is_empty():
		_expect(Atomic.write(capture_directory.path_join(kind + "-expected.json"), expected, false) == OK, "Could not preserve cold expectation.")
		_copy_checkpoint(kind + ".save.json")
	var frozen: String = Atomic.stringify(tribe.village(), "")
	var clock: float = state.campaign.data.elapsed_seconds
	for frame in range(20): await process_frame
	_expect(Atomic.stringify(tribe.village(), "") == frozen and state.campaign.data.elapsed_seconds == clock, "Pause advanced work, inventory or cursor.")
	# Publish a rendered frame before unloading a software-rendered sky.
	# Pure setup frames use on-demand rendering; its texture work must drain.
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = true
		await process_frame
		await RenderingServer.frame_post_draw
		if capture_on_demand: RenderingServer.render_loop_enabled = false
	# Retire the old writer before the fresh process commits a resumed result.
	# Returning afterward would save the stale held state over that result.
	flow.return_to_title()
	await scene_changed
	var output: Array = []
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--int30-restart"])
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	var log: String = "\n".join(output)
	if not capture_directory.is_empty():
		var file := FileAccess.open(capture_directory.path_join(kind + "-restart.log"), FileAccess.WRITE)
		if file != null: file.store_string(log)
	print("INT30_COLD_CASE:", kind, " exit=", code, "\n", log)
	_expect(code == 0 and log.contains("INT30_RESTART_PASSED:" + kind) and not log.contains("SCRIPT ERROR") and not log.contains("ERROR:"), "Cold case failed: " + kind)
	observations.append({"case": kind, "exit_code": code, "held_cargo": expected.village.members.map(func(m: Dictionary) -> String: return m.cargo),
		"stock": expected.village.stock, "clock": clock, "owner": expected.simulation.get("owner", "near")})
	paused = false

func _cold_resume() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SNAPSHOT))
	state.set_process(false)
	_expect(saves.load_now(expected.path), "Cold low-level load failed: " + saves.last_error)
	var body: Dictionary = state.get_current_body_record()
	var villages = preload("res://world/tribe/settlement_collection.gd")
	var data: Dictionary = villages.village(body)
	_expect(_fingerprint(data) == _fingerprint(expected.village), "Cold load changed order/material/progress/clock state.")
	_expect(Atomic.stringify(villages.view(body).get("village_simulation", {}), "") == Atomic.stringify(expected.simulation, ""), "Cold load replayed or changed simulation ownership/cursor.")
	_expect(state.campaign.data.id == expected.campaign_id and state.campaign.data.elapsed_seconds == expected.clock and state.campaign.data.completed_transitions == expected.transitions, "Cold load lost identity, time or transition receipt.")
	var frozen: String = _fingerprint(state.export_state())
	state._process(86400.0)
	_expect(_fingerprint(state.export_state()) == frozen, "Closed/title time produced catch-up work.")
	_expect(saves.load_now(expected.path), "Repeated load failed.")
	_expect(_fingerprint(state.export_state()) == frozen, "Repeated load paid out cargo a second time.")
	if expected.case == "far_cargo":
		# Loading for inspection is read-only. Resume the selected managed slot
		# explicitly before committing a far result without a physics scene.
		_expect(saves.select_slot(expected.path), "Far session could not select its saved slot: " + saves.last_error)
		var view: Dictionary = villages.view(state.get_current_body_record())
		var worker: Dictionary = view.tribe.members[1]
		var stock_before: int = int(view.tribe.stock.wood)
		var clock: float = state.campaign.data.elapsed_seconds
		var first_before: String = Atomic.stringify(view, "")
		_expect(not Simulation.advance(view, clock) and Atomic.stringify(view, "") == first_before, "Unadvanced campaign clock produced far work.")
		for tick in range(160):
			clock += 0.25
			state.campaign.data.elapsed_seconds = clock
			Simulation.advance(view, clock)
			if worker.cargo.is_empty(): break
		_expect(worker.cargo.is_empty() and view.tribe.stock.wood == stock_before + 1, "Certified far transport did not deliver exactly one held unit.")
		var delivered: String = Atomic.stringify(view, "")
		for tick in range(12): _expect(not Simulation.advance(view, clock), "Same far cursor advanced twice.")
		_expect(Atomic.stringify(view, "") == delivered, "Same far cursor duplicated work or freight.")
		_expect(saves.save_now(), "Far result failed persistence: " + saves.last_error)
		# Exercise the existing arrival hook while no physics host can write.
		_expect(saves.complete_body_arrival(), "Far-to-near arrival failed.")
		var near: String = Atomic.stringify(view, "")
		_expect(view.village_simulation.owner == "near" and not Simulation.advance(view, clock + 1.0) and Atomic.stringify(view, "") == near, "Far owner still wrote after near arrival.")
		_expect(Model.validate(view.tribe, view, state.campaign.data).is_empty(), "Far freight broke inventory consistency.")
	else:
		flow.world_started.connect(func() -> void: state.set_simulation_speed(0.0), CONNECT_ONE_SHOT)
		await flow.load_game(expected.path)
		var tribe: Node = await _active_village()
		if tribe == null: return
		data = tribe.village()
		_expect(tribe.actors.size() == expected.village.members.size() and tribe.home.actors.is_empty(), "Cold world duplicated resident actors.")
		_expect(data.stock == expected.village.stock and data.housing.homes == expected.village.housing.homes and data.project == expected.village.project, "Scene reconstruction changed stock/building/project.")
		for index in range(data.members.size()):
			for field: String in ["id", "order", "paused_order", "cargo", "construction_id", "stage", "work"]:
				_expect(data.members[index][field] == expected.village.members[index][field], "Scene reconstruction changed held worker: " + field)
		state.set_process(true)
		state.set_simulation_speed(1.0)
		tribe.select_all()
		_expect(tribe.issue_order("resume"), "Held saved work could not resume.")
		if expected.case == "construction_cargo":
			await _work_until(tribe, func() -> bool: return int(tribe.village().huts) == 1, 45000)
			_expect(data.huts == 1 and data.project.is_empty() and data.housing.homes.size() == 1, "Saved physical construction did not complete exactly once.")
			_expect(data.stock == expected.village.stock, "Reserved construction material was refunded/paid into stock twice.")
		else:
			var worker: Dictionary = data.members[1]
			await _until(func() -> bool: return worker.cargo.is_empty(), 20000)
			_expect(worker.cargo.is_empty() and data.stock.wood == int(expected.village.stock.wood) + 1, "Cold gathered cargo did not pay exactly one delivered unit.")
		tribe.select_all()
		_expect(tribe.issue_order("wait"), "Cannot freeze resumed result.")
		paused = true
		_expect(Model.validate(data, tribe.village_body(), state.campaign.data).is_empty(), "Resumed world broke inventory conservation.")
		_expect(saves.save_now(), "Resumed result failed save: " + saves.last_error)
		var finished: String = _fingerprint(data)
		var loaded: bool = saves.load_now()
		var restored: Dictionary = villages.village(state.get_current_body_record())
		if _fingerprint(restored) != finished:
			for key: String in data:
				if data[key] != restored.get(key): print("INT30_RELOAD_DIFFERENCE:", key, " before=", data[key], " after=", restored.get(key))
		_expect(loaded and _fingerprint(restored) == finished, "Resumed completion replayed on reload.")
	if failures.is_empty(): print("INT30_RESTART_PASSED:", expected.case)

func _active_village() -> Node:
	await _until(func() -> bool:
		var t: Node = current_scene.get_node_or_null("Nest/Tribe")
		return not flow.loading and t != null and t.is_active() and t.navigation.is_ready(), 150000)
	var tribe: Node = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.is_active():
		_expect(false, "Saved village did not regain real group/terrain ownership: " + JSON.stringify({
			"save_error": saves.last_error, "scene": current_scene.scene_file_path,
			"loading": flow.loading, "phase": state.current_phase,
			"tribe_status": tribe.status if tribe != null else "absent"}))
		return null
	return tribe

func _capture_village(tribe: Node, name: String, far: bool) -> void:
	if capture_directory.is_empty(): return
	var hut: Node3D = tribe._shelters.get_child(0)
	var center: Vector3 = (tribe.anchor() + hut.global_position) * 0.5
	var frame: Basis = Space.frame(tribe, center)
	tribe.camera.global_position = center + frame * (Vector3(0, 82, 85) if far else Vector3(0, 22, 24))
	tribe.camera.look_at(center, frame.y)
	tribe.camera.size = 82.0 if far else 29.0
	tribe._visuals._process(0.3)
	tribe._shelters._process(0.3)
	if DisplayServer.get_name() == "headless":
		_expect(saves.save_now(), "Actual village snapshot failed: " + saves.last_error)
		_copy_checkpoint(name + ".save.json")
	else:
		RenderingServer.render_loop_enabled = true
		for tick in range(3): await process_frame
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(capture_directory.path_join(name + ".png")) == OK, "Capture failed: " + name)
	var labels: Array = []
	for node: Node in tribe._visuals.get_children():
		if node is Label3D:
			labels.append({"text": node.text, "visible": node.visible})
			_expect(node.visible != far, "Combined view caption distance failed: " + node.text)
	var caption: Label3D = hut.get_child(hut.get_child_count() - 1)
	_expect(caption.visible != far, "Combined shelter caption distance failed.")
	observations.append({"capture": name, "huts": tribe.village().huts, "stock": tribe.village().stock.duplicate(), "labels": labels,
		"camera_distance": tribe.camera.global_position.distance_to(center), "terrain": "public spherical campaign"})
	if capture_on_demand: RenderingServer.render_loop_enabled = false

func _copy_checkpoint(name: String) -> void:
	var file := FileAccess.open(capture_directory.path_join(name), FileAccess.WRITE)
	_expect(file != null, "Checkpoint copy failed: " + name)
	if file != null: file.store_string(FileAccess.get_file_as_string(saves.save_path))

func _import_recorded_slot(path: String) -> String:
	# Public loading deliberately accepts managed slots only. Copy the exact
	# bytes of our genuine checkpoint into this isolated test's slot directory.
	var target: String = "user://saves/slot_int30_" + path.get_file().sha256_text().left(16) + ".json"
	_expect(DirAccess.make_dir_recursive_absolute("user://saves") == OK, "Cannot prepare isolated recorded slot.")
	var file := FileAccess.open(target, FileAccess.WRITE)
	_expect(file != null, "Cannot import recorded slot.")
	if file != null:
		file.store_string(FileAccess.get_file_as_string(path))
		file.close()
	return target

func _render_saved_village(directory: String) -> void:
	# These snapshots were produced by actual work in the headless functional
	# run. Freeze the simulation before reconstructing its completed village.
	flow.world_started.connect(func() -> void: state.set_simulation_speed(0.0), CONNECT_ONE_SHOT)
	await flow.load_game(_import_recorded_slot(directory.path_join("01_finished_village_near.save.json")))
	var tribe: Node = await _active_village()
	if tribe == null: return
	_expect(tribe.village().huts == 1 and tribe.village().project.is_empty(), "Rendered snapshot lacks its completed physical hut.")
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	paused = true
	await _capture_village(tribe, "01_finished_village_near", false)
	await _capture_village(tribe, "02_finished_village_far", true)
	await _capture_village(tribe, "03_finished_village_near_return", false)
	RenderingServer.render_loop_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	flow.return_to_title()
	await scene_changed
	flow.world_started.connect(func() -> void: state.set_simulation_speed(0.0), CONNECT_ONE_SHOT)
	await flow.load_game(_import_recorded_slot(directory.path_join("04_finished_village_actual_work.save.json")))
	tribe = await _active_village()
	if tribe == null: return
	# A tool pulse is emitted by the real work path; reconstructing an order
	# alone must never manufacture the visible work evidence.
	state.set_simulation_speed(1.0)
	capture_work_requested = true
	await _work_until(tribe, func() -> bool: return not capture_work_requested, 15000)
	_expect(not capture_work_requested and saw_work, "Rendered resumed source did not visibly advance real work.")

func _done() -> void:
	RenderingServer.render_loop_enabled = true
	paused = true
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
	paused = false
	if current_scene != null:
		var scene: Node = current_scene
		current_scene = null
		root.remove_child(scene)
		scene.queue_free()
	for frame in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var report := {"test": "int30_village_resume", "passed": failures.is_empty(), "failures": failures, "observations": observations, "saw_actual_work_tool": saw_work}
	print(JSON.stringify(report))
	if not capture_directory.is_empty(): Atomic.write(capture_directory.path_join("village-report.json"), report, false)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _fingerprint(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(Atomic.stringify(value, "")), "", true, true)

func _sample_orders(tribe: Node) -> void:
	state.set_simulation_speed(0.0)
	var metrics: Array = []
	tribe.select_all()
	var meshes: MultiMesh = tribe._visuals.stockpiles.lots.wood.stored.multimesh
	for index in range(100):
		_expect(tribe.issue_order("wait"), "Sphere latency command was not durably acknowledged.")
		metrics.append(tribe.last_order_metrics.duplicate(true))
		_expect(tribe.last_order_metrics.ok and saves.last_save_metrics.ok, "Timing success did not match committed save.")
		_expect(tribe._visuals.stockpiles.lots.wood.stored.multimesh == meshes, "Latency commands rebuilt storage meshes.")
	var times: Array = metrics.map(func(m: Dictionary) -> float: return m.total_ms)
	times.sort()
	observations.append({"orders": 100, "scene": "public sphere with completed hut", "p50_ms": times[49], "p95_ms": times[94], "max_ms": times[99], "samples": metrics,
		"scope": "container observations; target-PC frame-time acceptance remains separate"})
	state.set_simulation_speed(1.0)
