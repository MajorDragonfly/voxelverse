extends "res://core/diagnostics/spherical_campaign_probe.gd"
## Public spherical campaign entry and physical residents. No fabricated sources,
## no free stock, no surrogate navigation and no offline reward.
const Areas = preload("res://world/tribe/resource_area_model.gd")
const Home = Areas.Home
const Space = preload("res://world/surface/gameplay_space.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
var directory: String = ""
var ledger: Array = []
var frame_usecs: Array = []
var _frame_start: int = 0

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture-dir" in arguments: directory = arguments[arguments.find("--capture-dir") + 1]
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	var path: String = saves.create_slot("R32 Sammelgebiete", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _done_areas(); return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().get("ok", false), "Home founding failed.")
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.panel.open_confirmation(), "Tribal confirmation failed.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 15000)
	if not tribe.is_active() or not tribe.navigation.is_ready(): _expect(false, "Tribe/physical navigation did not activate."); await _done_areas(); return
	var ui: VBoxContainer = tribe.panel._resource_area
	tribe.selected.clear()
	tribe.panel._tabs.current_tab = 1
	tribe.panel._collapsed = false
	tribe.panel.refresh()
	var before: Dictionary = tribe.village().duplicate(true)
	# Press the actual new-area control, preview and cancel with Esc: no job.
	await _click(ui._new, tribe)
	_expect(tribe.resource_areas.drawing, "New-area button did not enter placement.")
	_expect(tribe.village() == before, "Preview click created an area/order/material.")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	Input.parse_input_event(escape)
	await tree.process_frame
	_expect(not tribe.resource_areas.drawing and tribe.village() == before, "Esc did not cancel area preview without effects.")
	var identities: Array = tribe.village().members.map(func(m: Dictionary) -> String: return m.id)
	var a: String = await _draw_area(tribe, "wood")
	var b: String = await _draw_area(tribe, "stone")
	_expect(not a.is_empty() and not b.is_empty() and a != b and Areas.entries(tribe.village()).size() == 2, "Two world-drawn areas were not saved.")
	if a.is_empty() or b.is_empty(): await _done_areas(); return
	_expect(tribe.village().stock == before.stock and tribe.village().deposits == before.deposits and tribe.village().members == before.members, "Drawing areas spawned work or materials.")
	for pair: Array in [[a, identities[1]], [b, identities[2]]]:
		ui.select_area(pair[0])
		tribe.select_member(pair[1])
		await _click(ui._assign, tribe)
		_expect(tribe.member_record(pair[1]).get("resource_area_id", "") == pair[0], "Assign-selected button lost resident/area identity.")
	_record(tribe, "assigned")
	# Count/target changes use the actual editor and one common save transaction.
	ui.select_area(a)
	ui._count.value = 1
	ui._target.value = 2
	await _click(ui._apply, tribe)
	ui.select_area(b)
	ui._count.value = 1
	ui._target.value = 2
	await _click(ui._apply, tribe)
	await _layout_matrix(tribe, b)
	Engine.time_scale = 2.0
	var started: int = Time.get_ticks_msec()
	_frame_start = Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < 25000:
		await tree.physics_frame
		var now: int = Time.get_ticks_usec()
		frame_usecs.append(now - _frame_start)
		_frame_start = now
		var cargo: Array = []
		for id: String in identities.slice(1):
			var member: Dictionary = tribe.member_record(id)
			if member.cargo != "" and member.order != "wait":
				_record(tribe, "physical_pickup_" + member.cargo)
				_expect(Home.distance(member.position, tribe.village().deposits[member.cargo].position) <= 3.0, "Pickup skipped physical source arrival.")
				_expect(tribe.village().stock[member.cargo] == 0, "Storage grew before first physical return.")
				tribe.select_member(id)
				_expect(tribe.issue_order("wait"), "Cannot pause the held source cargo.")
			if member.cargo != "": cargo.append(member)
		if cargo.size() == 2: break
	_expect(tribe.member_record(identities[1]).cargo == "wood" and tribe.member_record(identities[2]).cargo == "stone", "Two real source trips did not acquire cargo.")
	if tribe.member_record(identities[1]).cargo == "" or tribe.member_record(identities[2]).cargo == "": await _done_areas(); return
	Engine.time_scale = 1.0
	# Freeze the host for GUI transaction checks so slow software readback cannot
	# turn a legitimate arrival between buttons into a spurious rollback failure.
	tribe.set_physics_process(false)
	await _capture(tribe, "held-cargo")
	# Deletion retains freight; reassignment cannot transfer or pay its source.
	var source: String = tribe.member_record(identities[1]).cargo_source_id
	ui.select_area(a)
	await _click(ui._delete, tribe)
	_expect(Areas.entries(tribe.village()).has(a), "Delete first click skipped confirmation.")
	await _click(ui._delete, tribe)
	_expect(not Areas.entries(tribe.village()).has(a) and tribe.member_record(identities[1]).cargo == "wood" and tribe.member_record(identities[1]).cargo_source_id == source, "Area deletion paid/discarded cargo.")
	tribe.select_member(identities[1])
	ui.select_area(b)
	await _click(ui._assign, tribe)
	_expect(tribe.member_record(identities[1]).cargo_source_id == source and tribe.village().stock.wood == 0, "Cross-resource reassignment changed held cargo.")
	tribe.select_member(identities[1])
	_expect(tribe.issue_order("wait"), "Cannot hold reassigned cargo.")
	# One held unit returns through real near physics; the second remains paused.
	tribe.set_physics_process(true)
	tribe.select_member(identities[1])
	_expect(tribe.issue_order("resume"), "Cannot resume the reassigned physical carrier.")
	await _until(func() -> bool: return tribe.village().stock.wood == 1, 15000)
	_expect(tribe.village().stock.wood == 1 and tribe.village().stock.stone == 0 and tribe.member_record(identities[1]).cargo == "", "Near courier did not arrive/deliver while second held cargo stayed paused.")
	_record(tribe, "physical_delivery_wood")
	tribe.select_member(identities[1])
	_expect(tribe.issue_order("wait"), "Cannot hold after physical delivery.")
	tribe.set_physics_process(false)
	var committed: Dictionary = tribe.village().duplicate(true)
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not tribe.resource_areas.command({"action": "workers", "id": b, "count": 0}) and tribe.village() == committed, "Failed save changed area jobs/cargo.")
	DirAccess.remove_absolute(path + ".tmp")
	# Readonly camera changes cannot alter saved bounds or source universe.
	var saved_bounds: Dictionary = Areas.entries(tribe.village()).duplicate(true)
	tribe.camera_rig.move_focus(Vector3(40, 0, 0))
	tribe.camera_rig.focus_home()
	_expect(Areas.entries(tribe.village()) == saved_bounds, "Camera movement expanded work boundaries.")
	_expect(await tribe.finish_navigation_for_departure(), "Navigation preflight failed.")
	tribe.set_physics_process(false)
	var simulation: Dictionary = await tribe.prepare_far_simulation()
	_expect(not simulation.is_empty(), "Existing physical roads could not certify area endpoints.")
	if simulation.is_empty(): await _done_areas(); return
	for worker: Dictionary in tribe.village().members.slice(1): worker.order = "stone"; worker.paused_order = ""
	tribe.village_body().village_simulation = simulation
	# Save/reload the actual campaign while near host is frozen; owner remains far
	# until explicitly transferred back. This tests the same saved held cargo.
	_expect(saves.save_now(), "Physical area checkpoint failed: " + saves.last_error)
	var freight: Dictionary = tribe.village().duplicate(true)
	_expect(saves.load_now(), "Physical area reload failed: " + saves.last_error)
	_expect(state.get_current_body_record().tribe == freight, "Live save/load changed area/cargo state.")
	var body: Dictionary = state.get_current_body_record()
	var clock: float = state.campaign.data.elapsed_seconds
	var delivered: int = body.tribe.delivered
	# Stop fresh gathers at existing shared stock thresholds, still return cargo.
	Areas.get_area(body.tribe, b).target = 0
	for i in range(160):
		clock += Simulation.STEP
		Simulation.advance(body, clock, 1.0, Callable(), true)
	_expect(body.tribe.stock.wood == 1 and body.tribe.stock.stone == 1 and body.tribe.delivered == delivered + 1, "Far return did not deliver the remaining held unit exactly once.")
	var digest: String = Migration.fingerprint(body)
	for i in range(8): Simulation.advance(body, clock, 1.0, Callable(), true)
	_expect(Migration.fingerprint(body) == digest, "Same far cursor repaid held cargo.")
	body.village_simulation.owner = "near"
	_expect(not Simulation.advance(body, clock + 20.0), "Near ownership also ran far work.")
	state.campaign.data.elapsed_seconds = clock
	_expect(Tribe.validate(body.tribe, body, state.campaign.data).is_empty(), "Combined physical/far area state invalid.")
	if not directory.is_empty(): Atomic.write(directory.path_join("world-ledger.json"), {"events": ledger, "final": body.tribe, "bounds": saved_bounds, "frame_intervals_usec": frame_usecs,
		"dispatch": {"calls": tribe.resource_areas.dispatch_calls, "total_usec": tribe.resource_areas.dispatch_total_usec, "max_usec": tribe.resource_areas.dispatch_max_usec},
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_video_adapter_name(), "scope": "Actual campaign route; shared-host/software intervals are not target-PC FPS acceptance."}, false)
	await _done_areas()


func _draw_area(tribe: Node, kind: String) -> String:
	var ui: VBoxContainer = tribe.panel._resource_area
	tribe.panel._collapsed = false
	await _click(ui._new, tribe)
	tribe.panel._collapsed = true
	tribe.panel.refresh()
	for i in range(3): await tree.process_frame
	var center: Vector3 = Space.resolve(tribe, tribe.village().deposits[kind].position)
	var edge: Vector3 = Space.offset(tribe, center, Vector3(2.5, 0, 0))
	var start: Vector2 = tribe.camera.unproject_position(center)
	var finish: Vector2 = tribe.camera.unproject_position(edge)
	_mouse(start, true)
	await tree.process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.relative = finish - start
	Input.parse_input_event(motion)
	for i in range(3): await tree.process_frame
	await _capture(tribe, "preview-" + kind)
	_mouse(finish, false)
	for i in range(3): await tree.process_frame
	var identity: String = tribe.resource_areas.selected_id
	if identity.is_empty(): return ""
	tribe.panel._collapsed = false
	ui.select_area(identity)
	ui._kind.select(Areas.KINDS.find(kind))
	ui._count.value = 0
	ui._target.value = 2
	await _click(ui._apply, tribe)
	return identity

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func _click(control: Control, tribe: Node) -> void:
	tribe.panel.refresh()
	for i in range(3): await tree.process_frame
	tribe.panel._scroll.ensure_control_visible(control)
	for i in range(3): await tree.process_frame
	_expect(tribe.panel._scroll.get_global_rect().has_point(control.get_global_rect().get_center()), "Area control is outside scroll viewport: " + control.name)
	_mouse(control.get_global_rect().get_center() * tribe.panel._scale_factor, true)
	await tree.process_frame
	_mouse(control.get_global_rect().get_center() * tribe.panel._scale_factor, false)
	await tree.process_frame

func _capture(tribe: Node, name_hint: String) -> void:
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name_hint + ".png"))

func _layout_matrix(tribe: Node, identity: String) -> void:
	var ui: VBoxContainer = tribe.panel._resource_area
	var display: Node = tree.root.get_node("DisplaySettings")
	var size: Vector2i = tree.root.size
	var scale_before: float = display.ui_scale
	var was_paused: bool = tree.paused
	tree.paused = true
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for resolution: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			for scale_value: float in [1.0, 1.25, 1.5]:
				tree.root.size = resolution
				display.ui_scale = scale_value
				ui.select_area(identity)
				tribe.panel.refresh()
				for i in range(4): await tree.process_frame
				for control: Control in [ui._new, ui._kind, ui._radius, ui._target, ui._count, ui._apply, ui._assign, ui._move, ui._delete]:
					tribe.panel._scroll.ensure_control_visible(control)
					for i in range(2): await tree.process_frame
					_expect(tribe.panel._scroll.get_global_rect().has_point(control.get_global_rect().get_center()) and control.size.x <= tribe.panel._scroll.size.x + 1.0,
						"Gather control clipped: %s %s %.2f %s" % [locale, resolution, scale_value, control.name])
				await _capture(tribe, "areas-%s-%dx%d-%d" % [locale, resolution.x, resolution.y, roundi(scale_value * 100)])
	tree.root.size = size
	display.ui_scale = scale_before
	TranslationServer.set_locale("de")
	tribe.panel.refresh()
	tree.paused = was_paused

func _record(tribe: Node, stage: String) -> void:
	ledger.append({"stage": stage, "clock": state.campaign.data.elapsed_seconds, "stock": tribe.village().stock.duplicate(),
		"delivered": tribe.village().delivered, "deposits": tribe.village().deposits.duplicate(true), "members": tribe.village().members.duplicate(true), "areas": Areas.entries(tribe.village()).duplicate(true)})

func _until(predicate: Callable, milliseconds: int) -> void:
	var start: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - start < milliseconds: await tree.process_frame

func _done_areas() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("R32_21_AREA_WORLD_PASSED: public sphere, actual drag/controls, physical pickups, held cargo, certified far returns and live Save/Load.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
