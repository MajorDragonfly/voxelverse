extends "res://tools/review_r32_21_area_world.gd"
## Actual spherical entry, bounded terrain admission, physical trips and clicks.
const Sources = Areas.LocalSources

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture-dir" in arguments: directory = arguments[arguments.find("--capture-dir") + 1]
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	var path: String = saves.create_slot("R33 örtliche Quellen", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _done_local(); return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().get("ok", false), "Home founding failed.")
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.panel.open_confirmation(), "Tribal confirmation failed.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and tribe.village().economy.has(Sources.FIELD), 30000)
	_expect(tribe.is_active() and not Sources.entries(tribe.village()).is_empty(), "Bounded terrain-source admission failed.")
	if not tribe.is_active() or Sources.entries(tribe.village()).is_empty(): await _done_local(); return
	tribe.set_physics_process(false)
	var data: Dictionary = tribe.village()
	var found: Dictionary = {}
	for source: Dictionary in Sources.entries(data).values():
		if found.has(source.resource_id): continue
		if not tribe.resource_areas.reachable(data.members[1], source): continue
		found[source.resource_id] = source.id
	_expect(found.size() == 3, "Real terrain admission omitted wood/stone/flint.")
	if found.size() != 3: await _done_local(); return
	var ui: VBoxContainer = tribe.panel._resource_area
	var flint: Dictionary = Sources.get_source(data, found.flint)
	# Focus is a view-only action; source universe/bounds remain unchanged.
	var before: Dictionary = data.duplicate(true)
	tribe.camera_rig.move_focus(Space.resolve(tribe, flint.position) - tribe._focus)
	tribe.panel._collapsed = true
	tribe.panel.refresh()
	for i in range(5): await tree.process_frame
	var point: Vector3 = Space.resolve(tribe, flint.position)
	var screen: Vector2 = tribe.camera.unproject_position(point + Space.up(tribe, point) * 0.1)
	_expect(tribe.resource_at(screen).get("id") == flint.id, "World hit did not resolve actual flint source.")
	_mouse(screen, true)
	await tree.process_frame
	_mouse(screen, false)
	await tree.process_frame
	_expect(ui.source_id == flint.id and tribe.resource_details(flint.id).remaining == flint.remaining and data == before, "Real world click created quantity or read another source.")
	tribe.panel._collapsed = false
	tribe.panel._tabs.current_tab = 1
	tribe.panel.refresh()
	await _capture(tribe, "01-world-flint-click")
	await _click(ui._add, tribe)
	var flint_worker: String = ""
	for member: Dictionary in data.members:
		if member.get("resource_source_id", "") == flint.id: flint_worker = member.id
	_expect(not flint_worker.is_empty(), "Actual source worker control did not bind source.")
	if flint_worker.is_empty(): await _done_local(); return
	# Source worker follows the existing physical movement, pickup and return.
	tribe.set_physics_process(true)
	await _until(func() -> bool: return tribe.member_record(flint_worker).cargo == "flint", 25000)
	tribe.set_physics_process(false)
	_expect(tribe.member_record(flint_worker).cargo == "flint" and flint.remaining == 0 and data.stock.flint == 0, "Physical flint pickup failed or paid storage before arrival.")
	if tribe.member_record(flint_worker).cargo != "flint": await _done_local(); return
	_record_local(tribe, "flint-picked-stock-zero")
	await _capture(tribe, "02-flint-held")
	# Stop with held cargo via the existing public order, then save failure.
	tribe.selected = [flint_worker]
	_expect(tribe.issue_order("wait"), "Stop-held-cargo command failed.")
	var carried: Dictionary = tribe.member_record(flint_worker).duplicate(true)
	var committed: String = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not tribe.resource_areas.source_workers(flint.id, -1), "Failed source-worker save accepted.")
	_expect(tribe.member_record(flint_worker) == carried and FileAccess.get_file_as_string(path) == committed, "Source command save failure lost held cargo or changed durable bytes.")
	DirAccess.remove_absolute(path + ".tmp")
	_expect(tribe.resource_areas.source_workers(flint.id, -1), "Source-worker withdrawal failed.")
	tribe.set_physics_process(true)
	await _until(func() -> bool: return tribe.village().stock.flint == 1, 25000)
	tribe.set_physics_process(false)
	data = tribe.village()
	_expect(data.stock.flint == 1 and data.delivered == 1 and tribe.member_record(flint_worker).cargo == "", "Actual arrival did not deliver exactly one flint.")
	_record_local(tribe, "flint-arrived")
	await _capture(tribe, "03-flint-arrived")
	var wood: Dictionary = Sources.get_source(data, found.wood)
	var a: String = await _draw_local(tribe, wood)
	var b: String = await _draw_local(tribe, wood)
	_expect(a != "" and b != "" and a != b, "Two actual overlapping source areas failed.")
	if a == "" or b == "": await _done_local(); return
	for pair: Array in [[a, data.members[1].id], [b, data.members[2].id]]:
		tribe.selected = [pair[1]]
		_expect(tribe.resource_areas.command({"action": "assign", "id": pair[0]}), "Overlap area worker assignment failed.")
	tribe.set_physics_process(true)
	await _until(func() -> bool: return Sources.get_source(tribe.village(), found.wood).remaining == 0, 25000)
	tribe.set_physics_process(false)
	data = tribe.village()
	_expect(Sources.get_source(data, found.wood).remaining == 0 and Tribe.Economy.carried(data, "wood") == 1 and data.stock.wood == 0, "Physical overlap did not extract just the last single unit.")
	_record_local(tribe, "overlap-wood-held")
	await _capture(tribe, "04-overlap-last-unit")
	for identity: String in [a, b]: tribe.resource_areas.command({"action": "delete", "id": identity})
	_expect(await tribe.finish_navigation_for_departure(), "Navigation departure preflight failed.")
	var simulation: Dictionary = await tribe.prepare_far_simulation()
	_expect(not simulation.is_empty(), "Real graph could not certify local source endpoints within existing budget.")
	if simulation.is_empty(): await _done_local(); return
	tribe.village_body().village_simulation = simulation
	_expect(saves.save_now(), "Local physical cargo checkpoint failed: " + saves.last_error)
	var fingerprint: String = Migration.fingerprint(tribe.village())
	_expect(saves.load_now() and Migration.fingerprint(state.get_current_body_record().tribe) == fingerprint, "Physical checkpoint reload changed source/cargo quantities.")
	var body: Dictionary = state.get_current_body_record()
	var clock: float = state.campaign.data.elapsed_seconds
	for i in range(160):
		clock += Simulation.STEP
		Simulation.advance(body, clock, 1.0, Callable(), true)
	_expect(body.tribe.stock.wood == 1 and body.tribe.stock.flint == 1 and body.tribe.delivered == 2, "Certified far return failed exact local cargo ledger.")
	var digest: String = Migration.fingerprint(body)
	for i in range(8): Simulation.advance(body, clock, 1.0, Callable(), true)
	_expect(Migration.fingerprint(body) == digest, "Same cursor paid source twice.")
	body.village_simulation.owner = "near"
	_expect(not Simulation.advance(body, clock + 20.0), "Near/far shared ownership duplicated work.")
	state.campaign.data.elapsed_seconds = clock
	_expect(Tribe.validate(body.tribe, body, state.campaign.data).is_empty(), "Physical/far source ledger invalid.")
	if not directory.is_empty(): Atomic.write(directory.path_join("source-ledger.json"), {"events": ledger, "final": body.tribe,
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(), "target_pc_acceptance": false}, false)
	await _done_local()

func _draw_local(tribe: Node, source: Dictionary) -> String:
	var ui: VBoxContainer = tribe.panel._resource_area
	tribe.panel._collapsed = false
	await _click(ui._new, tribe)
	tribe.panel._collapsed = true
	tribe.panel.refresh()
	tribe.camera_rig.move_focus(Space.resolve(tribe, source.position) - tribe._focus)
	for i in range(4): await tree.process_frame
	var center: Vector3 = Space.resolve(tribe, source.position)
	var edge: Vector3 = Space.offset(tribe, center, Vector3(1.4, 0, 0))
	var start: Vector2 = tribe.camera.unproject_position(center)
	var finish: Vector2 = tribe.camera.unproject_position(edge)
	_mouse(start, true)
	await tree.process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.relative = finish - start
	tree.root.push_input(motion, true)
	await tree.process_frame
	await _capture(tribe, "draw-local-%d" % Areas.entries(tribe.village()).size())
	_mouse(finish, false)
	for i in range(3): await tree.process_frame
	var identity: String = tribe.resource_areas.selected_id
	if tribe.resource_areas.drawing or identity == "": return ""
	tribe.panel._collapsed = false
	ui.select_area(identity)
	ui._target.value = 48
	ui._kind.select(Areas.KINDS.find(source.resource_id))
	await _click(ui._apply, tribe)
	return identity

func _record_local(tribe: Node, stage: String) -> void:
	ledger.append({"stage": stage, "stock": tribe.village().stock.duplicate(), "delivered": tribe.village().delivered,
		"sources": Sources.entries(tribe.village()).duplicate(true), "members": tribe.village().members.duplicate(true)})

func _done_local() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("R33_05_LOCAL_WORLD_PASSED: actual source clicks, finite terrain objects, physical pickup/arrival, two areas, rollback and certified far return.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
