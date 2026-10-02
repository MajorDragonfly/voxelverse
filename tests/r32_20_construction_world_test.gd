extends "res://tests/tribal_guidance_world_test.gd"
## Two sequential real sites in the normal sphere; simultaneous independent
## settlement sites are covered by r32_20_construction_details_test.
const Details = preload("res://ui/tribe/construction_details_view.gd")
const Construction = preload("res://world/tribe/village_construction.gd")
var records: Array[Dictionary] = []
var starting_stock: Dictionary

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	root.get_node("LocaleManager")._apply("de")
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
		# Actual world is drawn at each capture boundary; this is a UI/arrival
		# review, not a cold-start benchmark or a sustained frame-rate claim.
		root.disable_3d = true
	print("R32_20_WORLD_SETUP: preparing normal sphere scene")
	var prepared: PackedScene = load(flow.SPHERE_SCENE)
	_expect(prepared != null, "Cannot prepare normal sphere")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Cannot start public tribal playtest")
	await _until(func() -> bool: return not flow.loading, 180000)
	await _until(func() -> bool:
		var host: Node = current_scene.get_node_or_null("Nest/Tribe")
		return host != null and host.panel.confirmation_open, 90000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Normal sphere failed to reach tribe confirmation")
		await _end_review()
		return
	saves.autosave_enabled = false
	tribe.panel.confirm.pressed.emit()
	if not await _wait_for_tribe("R32-20 initial"):
		await _end_review()
		return
	tribe.set_physics_process(false)
	tribe.select_all()
	var data: Dictionary = tribe.village()
	# Move finite deposit units into storage, retaining the existing writer and
	# every physical pickup/delivery thereafter. This is explicit test setup.
	for kind: String in ["wood", "stone"]:
		data.deposits[kind].remaining -= 16
		data.stock[kind] += 16
	starting_stock = data.stock.duplicate()
	_expect(saves.save_now(), "Conserving test stock invalid: " + saves.last_error)
	# The prepaid counter must not impersonate physical transport, including
	# during actual crafting through the controller and real resident work.
	await _click(tribe.panel._buttons.tool)
	tribe.panel.refresh()
	_expect(not Details.read(data).tracks_transport and tribe.panel._construction._details.text.contains("kein Transportnachweis"), "Real tool claims delivered materials")
	await _capture("01-prepaid-tool-de")
	tribe.set_physics_process(true)
	if not await _work(func() -> bool: return tribe.village().tools > 0, 30, "tool completion"):
		await _end_review()
		return
	tribe.set_physics_process(false)
	starting_stock = tribe.village().stock.duplicate()
	var first_point: Vector3 = await _preview("hut")
	if not first_point.is_finite(): await _end_review(); return
	var before: Dictionary = tribe.village().duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	await _world_click(tribe.camera.unproject_position(first_point), MOUSE_BUTTON_LEFT)
	_expect(tribe.village() == before and FileAccess.get_file_as_string(saves.save_path) == bytes and not tribe.placement.is_empty(), "Preview left click created a project or deducted stock")
	tribe.select_all()
	await _world_click(tribe.camera.unproject_position(first_point), MOUSE_BUTTON_RIGHT)
	_expect(not tribe.village().project.is_empty(), "Valid placement did not create first site")
	if tribe.village().project.is_empty(): await _end_review(); return
	var first_id: String = tribe.village().project.id
	await _world_detail("02-first-site-de")
	_record("first-reserved")
	tribe.select_all()
	tribe.set_physics_process(true)
	if not await _wait_for_tribe("R32-20 placed hut navigation"):
		await _end_review()
		return
	if not await _work(func() -> bool: return tribe.village().members.any(func(m: Dictionary) -> bool: return m.construction_id == first_id), 20, "first material pickup"):
		await _end_review()
		return
	tribe.set_physics_process(false)
	_record("first-in-transit")
	await _capture("03-first-cargo-de")
	# Disconnect actual navigation edges while retaining points. Let the actual
	# controller report blockage; no resident positions/arrival flags are forged.
	var graph: AStar3D = tribe.navigation.graph
	var disconnected := AStar3D.new()
	for id: int in graph.get_point_ids(): disconnected.add_point(id, graph.get_point_position(id))
	tribe.navigation.graph = disconnected
	tribe._routes.clear()
	tribe._goals.clear()
	tribe._route_retry = 60.0
	before = tribe.village().duplicate(true)
	tribe.set_physics_process(true)
	await _until(func() -> bool: return tribe.village().members.any(func(m: Dictionary) -> bool: return m.blocked), 5000)
	tribe.set_physics_process(false)
	_expect(tribe.village().members.any(func(m: Dictionary) -> bool: return m.blocked), "Disconnected graph did not block actual carrier")
	_expect(tribe.village().project.materials == before.project.materials and tribe.village().project.delivered_materials == before.project.delivered_materials and tribe.village().stock == before.stock, "Blocked route fabricated arrival")
	_record("first-blocked")
	tribe.panel.refresh()
	await _capture("04-first-blocked-de")
	tribe.navigation.graph = graph
	tribe._routes.clear()
	tribe._goals.clear()
	tribe._route_retry = 2.0
	# Actual GUI action must not leak into a world selection/order.
	tribe.select_all()
	var selection: Array = tribe.selected.duplicate()
	await _click(tribe.panel._construction._pause)
	_expect(Construction.state(tribe.village().project) == "paused" and tribe.selected == selection and tribe.placement.is_empty(), "Pause GUI leaked a world click")
	_record("first-paused-with-cargo")
	flow.toggle_pause()
	before = tribe.village().duplicate(true)
	await _frames(8)
	_expect(tribe.village() == before and not tribe.control_construction("resume").ok, "Game pause advanced construction or accepted resume")
	_expect(saves.save_now(), "Paused cargo checkpoint cannot save: " + saves.last_error)
	var checkpoint: Dictionary = tribe.village().duplicate(true)
	tribe.set_physics_process(true)
	_expect(saves.load_now(), "Cannot reload first site: " + saves.last_error)
	flow.resume()
	if not await _wait_for_tribe("R32-20 cargo reload"):
		await _end_review()
		return
	tribe.set_physics_process(false)
	_expect(_same(tribe.village().project, checkpoint.project) and _same(tribe.village().stock, checkpoint.stock)
		and tribe.village().members.map(func(m: Dictionary) -> Array: return [m.id, m.cargo, m.construction_id]) == checkpoint.members.map(func(m: Dictionary) -> Array: return [m.id, m.cargo, m.construction_id]), "Reload changed project identity or freight/stock")
	_record("first-reloaded")
	tribe.set_physics_process(true)
	if not await _work(func() -> bool: return tribe.village().members.all(func(m: Dictionary) -> bool: return m.construction_id.is_empty()), 25, "paused cargo arrival"):
		await _end_review()
		return
	tribe.set_physics_process(false)
	_expect(tribe.village().project.progress == 0 and tribe.village().project.materials == checkpoint.project.materials, "Paused site worked or took new reserved goods")
	_record("first-paused-arrival")
	await _language_layouts()
	tribe.panel.open_construction()
	await _frames(6)
	await _click(tribe.panel._construction._pause)
	_expect(Construction.state(tribe.village().project) == "active", "Real resume action failed")
	before = tribe.village().duplicate(true)
	await _click(tribe.panel._construction._cancel)
	_expect(tribe.panel._construction._confirming and tribe.village() == before, "First cancellation click changed site")
	root.get_node("LocaleManager")._apply("en")
	tribe.panel.refresh()
	_expect(tribe.panel._construction._confirming, "Language change lost cancellation choice")
	await _capture("05-confirm-cancel-en")
	await _click(tribe.panel._construction._cancel)
	_expect(Construction.state(tribe.village().project) == "recovering", "Confirmed cancellation skipped material recovery")
	_record("first-recovering")
	tribe.select_all()
	await _click(tribe.panel._construction._assign)
	tribe.set_physics_process(true)
	if not await _work(func() -> bool: return tribe.village().project.is_empty(), 40, "first site physical material recovery"):
		await _end_review()
		return
	tribe.set_physics_process(false)
	_expect(tribe.village().stock.wood == starting_stock.wood and tribe.village().stock.stone == starting_stock.stone and tribe.village().huts == 0, "Cancellation lost/duplicated material or finished a hut")
	_expect(not tribe.panel._construction.visible, "Cancelled site retained visible detail")
	root.get_node("LocaleManager")._apply("de")
	tribe.select_all()
	await _until(func() -> bool: return not tribe.navigation.pending, 15000)
	var second_point: Vector3 = await _preview("forester", first_point)
	if not second_point.is_finite(): await _end_review(); return
	await _world_click(tribe.camera.unproject_position(second_point), MOUSE_BUTTON_RIGHT)
	_expect(not tribe.village().project.is_empty(), "Second valid placement failed")
	if tribe.village().project.is_empty(): await _end_review(); return
	_expect(tribe.village().project.id != first_id, "Second site reused cancelled site's identity")
	await _world_detail("06-second-site-de")
	_record("second-reserved")
	tribe.select_all()
	tribe.set_physics_process(true)
	if not await _work(func() -> bool: return tribe.village().economy.stations.has("forester"), 60, "second site physical delivery and completion"):
		await _end_review()
		return
	tribe.set_physics_process(false)
	_expect(tribe.village().stock.wood == starting_stock.wood - 4 and tribe.village().stock.stone == starting_stock.stone - 1 and tribe.village().project.is_empty(), "Completion charged another site's material")
	_expect(saves.save_now(), "Completed site cannot save")
	checkpoint = tribe.village().duplicate(true)
	tribe.set_physics_process(true)
	_expect(saves.load_now(), "Completed site cannot reload")
	if await _wait_for_tribe("R32-20 completed reload"):
		tribe.set_physics_process(false)
		_expect(_same(tribe.village().economy.stations, checkpoint.economy.stations) and _same(tribe.village().stock, checkpoint.stock) and tribe.village().project.is_empty(), "Completed reload repeated building or cost")
		await _capture("07-second-completed-de")
	await _end_review()

func _preview(kind: String, avoid: Vector3 = Vector3.INF) -> Vector3:
	tribe.select_all()
	await _click(tribe.panel._buttons[kind])
	var before: Dictionary = tribe.village().duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var candidates: Array = []
	for id: int in tribe.navigation.graph.get_point_ids(): candidates.append(tribe.navigation.graph.get_point_position(id))
	for candidate: Vector3 in candidates:
		if candidate.distance_to(tribe.anchor()) < 7 or candidate.distance_to(tribe.anchor()) > 12: continue
		if avoid.is_finite() and candidate.distance_to(avoid) < 4: continue
		var point: Vector2 = tribe.camera.unproject_position(candidate)
		if not Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point): continue
		var hit: Dictionary = tribe.ground_hit(point)
		if hit.is_empty() or not tribe.placement_check(kind, hit.position).ok: continue
		await _pointer(point)
		if root.gui_get_hovered_control() != null: continue
		_expect(tribe.building_preview.visible and tribe.building_preview.result.get("ok", false), "Pointer has no valid preview")
		_expect(tribe.village() == before and FileAccess.get_file_as_string(saves.save_path) == bytes, "Viewing preview changed material/save")
		return hit.position
	_expect(false, "No reachable visible valid site: " + kind + " status=" + tribe.status)
	return Vector3.INF

func _world_detail(stage: String) -> void:
	tribe.panel._collapsed = true
	tribe.panel._layout()
	await _frames(5)
	var site: Vector3 = Space.resolve(tribe, tribe.village().project.position)
	var before: Dictionary = tribe.village().duplicate(true)
	var opened: bool = false
	for rise: float in [0.0, 0.6, 1.2, 1.8, 2.4]:
		var point: Vector2 = tribe.camera.unproject_position(site + Space.up(tribe, site) * rise)
		await _pointer(point)
		if root.gui_get_hovered_control() != null or not tribe.project_at(point): continue
		await _world_click(point, MOUSE_BUTTON_LEFT)
		await _frames(6)
		if not tribe.panel._collapsed and tribe.panel._tabs.current_tab == tribe.panel._build_page.get_index(): opened = true; break
	_expect(opened, "Actual world click did not open construction detail")
	_expect(tribe.village() == before and Details.read(tribe.village()).project_id == tribe.village().project.id, "Inspection changed/bound another site")
	await _capture(stage)

func _record(stage: String) -> void:
	var data: Dictionary = tribe.village()
	var view: Dictionary = Details.read(data)
	for kind: String in view.materials:
		var row: Dictionary = view.materials[kind]
		var actual: int = 0
		for m: Dictionary in data.members:
			if m.construction_id == data.project.id and m.cargo == kind: actual += 1
		_expect(actual == row.carried and row.reserved == data.project.materials[kind] and row.delivered == data.project.delivered_materials[kind], stage + ": row differs from ledger")
		_expect(int(row.required) == int(row.reserved) + int(row.delivered) + int(row.carried) + int(row.returned), stage + ": paid unit missing")
		if view.state != "recovering": _expect(int(data.stock[kind]) + int(row.required) == int(starting_stock[kind]), stage + ": material charged twice")
	_expect(view.installed == null, stage + ": fabricated installed count")
	tribe.panel.refresh()
	records.append({"stage": stage, "clock": state.campaign.data.elapsed_seconds, "view": view, "project": data.project.duplicate(true), "stock": data.stock.duplicate(),
		"cargo": data.members.map(func(m: Dictionary) -> Dictionary: return {"member_id": m.id, "cargo": m.cargo, "construction_id": m.construction_id, "blocked": m.blocked, "position": m.position.duplicate(true)}), "display": tribe.panel._construction._details.text})
	print("R32_20_LEDGER: ", JSON.stringify(records[-1]))

func _language_layouts() -> void:
	var before: Dictionary = tribe.village().duplicate(true)
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			for scale_value: float in [1.0, 1.25, 1.5]:
				root.get_node("DisplaySettings").ui_scale = scale_value
				tribe.panel.open_construction()
				await _frames(8)
				for button: Button in [tribe.panel._construction._pause, tribe.panel._construction._cancel, tribe.panel._construction._assign]:
					tribe.panel._scroll.ensure_control_visible(button)
					await _frames(5)
					_expect(_physical(tribe.panel._scroll).has_point(_physical(button).get_center()) and _physical(button).size.x <= _physical(tribe.panel._scroll).size.x + 1, "Construction action clipped: " + str([locale, size, scale_value, button.name]))
				_expect(not tribe.panel._construction._details.text.contains("CONSTRUCTION_"), "Untranslated detail")
				if scale_value == 1.5:
					tribe.panel._scroll.ensure_control_visible(tribe.panel._construction._details)
					await _frames(4)
					await _capture("layout-%s-%d-150" % [locale, size.x])
	_expect(tribe.village() == before, "Language/layout changes mutated construction")
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("de")

func _work(predicate: Callable, seconds: int, stage: String) -> bool:
	var ticks: int = Engine.get_physics_frames()
	await _until(func() -> bool: return predicate.call() or Engine.get_physics_frames() - ticks >= seconds * Engine.physics_ticks_per_second, 180000)
	if predicate.call(): return true
	print("R32_20_WORK_TIMEOUT: ", JSON.stringify({"stage": stage, "clock": state.campaign.data.elapsed_seconds, "active": tribe.is_active(), "processing": tribe.is_physics_processing(), "navigation_pending": tribe.navigation.pending, "paused": paused, "time_scale": Engine.time_scale, "members": tribe.village().members}))
	_expect(false, "Real work timeout: " + stage + " project=" + str(tribe.village().project) + " status=" + tribe.status)
	return false

func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func _capture(stage: String) -> void:
	print("R32_20_WORLD_STAGE: ", stage)
	if capture_dir.is_empty(): return
	if tribe != null and not tribe.village().project.is_empty():
		tribe.panel.refresh()
		tribe.panel._scroll.ensure_control_visible(tribe.panel._construction._details)
		await _frames(5)
	root.disable_3d = false
	await _frames(2)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(stage + ".png")) == OK, "World image failed")
	root.disable_3d = true

func _end_review() -> void:
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("ledger.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"stages": records, "failures": failures}, "\t"))
	if failures.is_empty(): print("R32_20_WORLD_PASSED: real preview/click, two sequential sites, disconnected route, carrier arrival/recovery, pause, save/load, DE/EN and 18 layouts")
	await _finish()
