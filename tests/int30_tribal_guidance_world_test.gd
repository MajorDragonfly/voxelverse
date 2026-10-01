extends "res://tests/tribal_guidance_world_test.gd"
## Real spherical entry, owner-patch UI, commands, arrivals and reload.
const Card = preload("res://ui/tutorial/tribal_guidance_card.gd")
var card: PanelContainer
var evidence: Array[Dictionary] = []

func _run() -> void:
	preload("res://tests/int30_tribal_guidance_support.gd").install_copy()
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.get_node("LocaleManager")._apply("de")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
		# Rasterize the actual world at capture boundaries. Physics, nodes,
		# commands and GUI remain live between captures; this is not an FPS test.
		root.disable_3d = true
	# This consumer checks tutorial actions, not cold asset-loading performance.
	# Prepare/hold the real scene before starting the ordinary session flow.
	print("INT30_GUIDANCE_SETUP: preparing real scene resources (not a cold-start benchmark)")
	var prepared_world: PackedScene = load(flow.SPHERE_SCENE)
	_expect(prepared_world != null and prepared_world.can_instantiate(), "Cannot prepare the actual spherical scene resources")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	print("INT30_GUIDANCE_SETUP: title ready")
	_expect(Playtest.start(flow), "Cannot start contextual guidance sphere")
	# Loading and the launcher's collision/home preparation are distinct stages.
	# Use SessionFlow's existing 180 s terrain-loading watchdog. This test
	# evaluates tutorial actions, not the old consumer's 90 s cold-start target.
	await _until(func() -> bool: return not flow.loading, 180000)
	print("INT30_GUIDANCE_SETUP: load finished=", not flow.loading, " trace=", JSON.stringify(flow.startup_diagnostics()))
	_expect(not flow.loading, "Sphere load did not finish within SessionFlow's terrain watchdog")
	await _until(func() -> bool:
		var host: Node = current_scene.get_node_or_null("Nest/Tribe")
		return host != null and host.panel.confirmation_open, 90000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		var launcher: Node = flow.get_node_or_null("TribalPlaytestLauncher")
		print("INT30_GUIDANCE_SETUP: ", JSON.stringify({"loading": flow.loading,
			"launcher_detail": launcher._detail.text if launcher != null and launcher._detail != null else "",
			"blockers": tribe.blockers() if tribe != null else [], "scene": current_scene.scene_file_path}))
		_expect(false, "Context fixture did not reach tribe confirmation")
		await _finish()
		return
	saves.autosave_enabled = false
	tribe.panel.confirm.pressed.emit()
	if not await _wait_for_tribe("context initial activation"):
		await _finish()
		return
	guide = flow.get_node("FirstSteps")
	card = tribe.panel.find_child("TribalContextHelp", true, false)
	_expect(card != null, "Chat-6 owner patch must attach the contextual card")
	if card == null:
		await _finish()
		return
	tribe.set_physics_process(false)
	await _frames(4)
	_expect(saves.guidance.tribal_completed() == 0, "Help attachment completed exercises")
	saves.guidance.select_tribal("tribe_work")
	tribe.screen_select(Rect2(-1000, -1000, 2, 2), false)
	await _expect_card("selection", "01-no-selection-de")
	# Choose an actual companion with care needs, rather than the initially full player.
	await _click(tribe.panel._residents.get_child(1))
	await _expect_card("gather", "02-selected-de")
	var before: Dictionary = tribe.village().duplicate(true)
	var tutorial: Dictionary = saves.guidance.export_state()
	var save_bytes: String = FileAccess.get_file_as_string(saves.save_path)
	await _click(card._toggle)
	await _click(card._toggle)
	_expect(tribe.village() == before and saves.guidance.export_state() == tutorial and FileAccess.get_file_as_string(saves.save_path) == save_bytes,
		"Explanation clicks mutated work, inventory, tutorial or saved bytes")
	_expect(not tribe.issue_order("hut"), "Building without a tool was accepted")
	await _expect_card("order_rejected", "03-rejected-order-de")
	# Use the real player resident for the controlled transport path.
	await _click(tribe.panel._residents.get_child(0))
	tribe.set_physics_process(true)
	await _click(tribe.panel._buttons.wood)
	_expect(saves.guidance.tribal_done("tribe_order") and not saves.guidance.tribal_done("tribe_delivery"), "Order counted as delivery")
	# Controlled obstruction: actual navigation has the same points but no edges.
	# No resident flags or arrived-work events are forged by the fixture.
	var graph: AStar3D = tribe.navigation.graph
	var disconnected := AStar3D.new()
	for identity: int in graph.get_point_ids(): disconnected.add_point(identity, graph.get_point_position(identity))
	tribe.navigation.graph = disconnected
	tribe._routes.clear()
	tribe._goals.clear()
	tribe._route_retry = 60.0
	await _until(func() -> bool: return tribe.village().members.any(func(m: Dictionary) -> bool: return m.blocked), 5000)
	tribe.set_physics_process(false)
	await _expect_card("blocked", "04-blocked-route-de")
	_expect(tribe.village().stock.wood == 0 and not saves.guidance.tribal_done("tribe_delivery"), "Obstruction generated delivery")
	tribe.navigation.graph = graph
	tribe._routes.clear()
	tribe._goals.clear()
	tribe._route_retry = 2.0
	tribe.set_physics_process(true)
	if not await _wait_work(func() -> bool: return tribe.village().members.any(func(m: Dictionary) -> bool: return m.cargo == "wood"), 25, "wood pickup"):
		await _finish()
		return
	tribe.set_physics_process(false)
	await _expect_card("cargo", "05-cargo-in-transit-de")
	_expect(not saves.guidance.tribal_done("tribe_delivery"), "Pickup counted as arrival")
	tribe.set_physics_process(true)
	if not await _wait_work(func() -> bool: return tribe.village().stock.wood > 0, 25, "wood arrival"):
		await _finish()
		return
	tribe.set_physics_process(false)
	_expect(saves.guidance.tribal_done("tribe_delivery"), "Real delivery did not advance the existing observer")
	await _click(tribe.panel._residents.get_child(1))
	await _expect_card("gather", "06-empty-pantry-de")
	await _click(tribe.panel._residents.get_child(0))
	tribe.set_physics_process(true)
	await _click(tribe.panel._buttons.food)
	if not await _wait_work(func() -> bool: return tribe.village().stock.food > 0, 25, "food arrival"):
		await _finish()
		return
	tribe.set_physics_process(false)
	await _click(tribe.panel._residents.get_child(1))
	await _expect_card("feed", "07-food-ready-de")
	tribe.set_physics_process(true)
	await _click(tribe.panel._buttons.feed)
	if not await _wait_work(func() -> bool: return saves.guidance.tribal_done("tribe_supply"), 15, "actual consumption"):
		await _finish()
		return
	tribe.set_physics_process(false)
	_expect(saves.guidance.tribal_done("tribe_supply") and tribe.village().meals > 0, "Supply did not use actual consumption")
	await _click(tribe.panel.find_child("SelectAll", true, false))
	saves.guidance.select_tribal("tribe_build")
	await _expect_card("materials", "08-missing-materials-de")
	# Existing conservation fixture for the remainder; commands and work stay real.
	for resource: String in ["wood", "stone"]:
		tribe.village().deposits[resource].remaining -= 12
		tribe.village().stock[resource] += 12
	_expect(saves.save_now(), "Conserving build fixture failed validation: " + saves.last_error)
	await _click(tribe.panel._buttons.tool)
	tribe.set_physics_process(true)
	if not await _wait_work(func() -> bool: return tribe.village().tools > 0, 25, "tool completion"):
		await _finish()
		return
	tribe.set_physics_process(false)
	if not saves.guidance.tribal_done("tribe_tool"):
		print("INT30_GUIDANCE_TOOL_STATE: ", JSON.stringify({"project": tribe.village().project, "status": tribe.status,
			"members": tribe.village().members.map(func(m: Dictionary) -> Dictionary: return {"id": m.id, "order": m.order, "stage": m.stage, "blocked": m.blocked, "work": m.work})}))
	_expect(saves.guidance.tribal_done("tribe_tool"), "Tool counted without actual work completion")
	await _click(tribe.panel._buttons.forester)
	var site := Vector3.INF
	for saved_site: Variant in tribe.village().sites:
		var candidate: Vector3 = Space.resolve(tribe, saved_site)
		var hit: Dictionary = tribe.ground_hit(tribe.camera.unproject_position(candidate))
		if not hit.is_empty() and tribe.placement_check("forester", hit.position).ok:
			await _pointer(tribe.camera.unproject_position(hit.position))
			if root.gui_get_hovered_control() != null: continue
			site = hit.position
			break
	_expect(site.is_finite(), "No actual build site in the sphere")
	if not site.is_finite():
		await _finish()
		return
	await _pointer(tribe.camera.unproject_position(site))
	await _expect_card("place", "09-valid-preview-de")
	await _world_click(tribe.camera.unproject_position(site), MOUSE_BUTTON_RIGHT)
	await _expect_card("build_materials", "10-reserved-site-materials-de")
	_expect(not saves.guidance.tribal_done("tribe_finish"), "Placement/help finished construction")
	_expect(tribe.control_construction("pause").ok, "Cannot pause actual construction")
	await _expect_card("build_paused", "11-paused-construction-de")
	await _help_page()
	await _layout_cases()
	var village: Dictionary = tribe.village().duplicate(true)
	var progress: Dictionary = saves.guidance.export_state()
	_expect(saves.save_now(), "Context checkpoint save failed")
	# Resume the actual controller so reload can rebuild its navigation.
	tribe.set_physics_process(true)
	_expect(saves.load_now(), "Context checkpoint load failed")
	if not await _wait_for_tribe("context reload"):
		await _finish()
		return
	tribe.set_physics_process(false)
	card = tribe.panel.find_child("TribalContextHelp", true, false)
	# JSON number representations may change from int to float. Compare the
	# exact serialized meaning, not Variant dictionary storage types.
	_expect(_json_equal(saves.guidance.export_state(), progress) and _json_equal(tribe.village().stock, village.stock) and _json_equal(tribe.village().project, village.project),
		"Load fabricated tutorial/material progress")
	await _expect_card("build_paused", "12-resumed-help-de")
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("stages.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"stages": evidence, "failures": failures}, "\t"))
	if failures.is_empty(): print("INT30_TRIBAL_GUIDANCE_WORLD_PASSED")
	await _finish()

func _expect_card(code: String, stage: String) -> void:
	card.refresh()
	tribe.panel._scroll.ensure_control_visible(card)
	await _frames(4)
	card.refresh()
	_expect(card.view.get("code") == code, stage + ": " + str(card.view))
	_expect(not card._reason.text.contains("TG_") and not card._next.text.contains("TG_"), "Untranslated contextual help: " + stage)
	evidence.append({"stage": stage, "code": card.view.get("code"), "step": saves.guidance.tribal_step(),
		"progress": saves.guidance.tribal_completed(), "stock": tribe.village().stock.duplicate(),
		"reason": card._reason.text, "next": card._next.text})
	await _capture(stage)

func _layout_cases() -> void:
	var tutorial: Dictionary = saves.guidance.export_state()
	var village: Dictionary = tribe.village().duplicate(true)
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = dimensions
			for scaling: float in [1.0, 1.25, 1.5]:
				root.get_node("DisplaySettings").ui_scale = scaling
				card.refresh()
				await _frames(6)
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
				_expect(screen.encloses(_physical(tribe.panel._hud)), "Context HUD offscreen: " + str([locale, dimensions, scaling]))
				for label: Control in [card._reason, card._next, card._toggle]:
					tribe.panel._scroll.ensure_control_visible(label)
					await _frames(3)
					_expect(_physical(tribe.panel._scroll).encloses(_physical(label)), "Context text/control inaccessible by scrolling: " + str([locale, dimensions, scaling, label.name]))
				await _click(card._toggle)
				_expect(card._detail.visible, "Context explanation click inaccessible")
				await _click(card._toggle)
				if scaling == 1.5:
					tribe.panel._scroll.ensure_control_visible(card._reason)
					await _frames(3)
					await _capture("layout-%s-%d-150" % [locale, dimensions.x])
	_expect(saves.guidance.export_state() == tutorial and tribe.village() == village, "Layout/help clicks mutated saved work/progress")
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("de")

func _wait_work(predicate: Callable, physics_seconds: int, label: String) -> bool:
	var first_tick: int = Engine.get_physics_frames()
	var started: int = Time.get_ticks_msec()
	# Preserve the headless consumer budgets. For native software rendering,
	# retain the same physics work limit plus the existing bounded 180 s guard.
	await _until(func() -> bool:
		return predicate.call() or Engine.get_physics_frames() - first_tick >= physics_seconds * Engine.physics_ticks_per_second,
		physics_seconds * 1000 if capture_dir.is_empty() else 180000)
	if predicate.call(): return true
	print("INT30_GUIDANCE_WORK_TIMEOUT: ", JSON.stringify({"stage": label, "wall_ms": Time.get_ticks_msec() - started,
		"physics_s": float(Engine.get_physics_frames() - first_tick) / Engine.physics_ticks_per_second,
		"selected": tribe.selected, "status": tribe.status, "project": tribe.village().project,
		"members": tribe.village().members.map(func(m: Dictionary) -> Dictionary:
			return {"id": m.id, "order": m.order, "stage": m.stage, "blocked": m.blocked, "cargo": m.cargo,
				"position": m.position, "work": m.work})}))
	_expect(false, "Actual work did not finish: " + label)
	return false

func _help_page() -> void:
	var village: Dictionary = tribe.village().duplicate(true)
	var tutorial: Dictionary = saves.guidance.export_state()
	var rewards: Dictionary = root.get_node("ProgressionService").export_state()
	var saved: String = FileAccess.get_file_as_string(saves.save_path)
	flow.toggle_pause()
	flow._show_first_steps()
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		await _frames(4)
		var source := preload("res://ui/tutorial/tribal_context_source.gd").new()
		source.bind(tribe)
		var advice = preload("res://ui/tutorial/tribal_context_guidance.gd")
		var expected: Dictionary = advice.render(advice.resolve(saves.guidance, source.read(true)))
		source.bind(null)
		var help: Node = flow._content.get_node_or_null("GuidanceHelp")
		_expect(paused and help != null and not expected.is_empty(), "Paused help has no live known context")
		if help != null and not expected.is_empty():
			_expect(_contains_label(help, expected.reason) and _contains_label(help, expected.next), "Chat-9 patch did not show the actual reason/next action")
			guide._help_scroll.scroll_vertical = 0
			await _frames(3)
			await _capture("help-context-" + locale)
	_expect(tribe.village() == village and saves.guidance.export_state() == tutorial
		and root.get_node("ProgressionService").export_state() == rewards
		and FileAccess.get_file_as_string(saves.save_path) == saved, "Reading paused help mutated saved work/rewards/progress")
	flow.resume()
	root.get_node("LocaleManager")._apply("de")

func _contains_label(node: Node, caption: String) -> bool:
	if node is Label and node.text == caption: return true
	for child: Node in node.get_children():
		if _contains_label(child, caption): return true
	return false

func _capture(label: String) -> void:
	print("INT30_GUIDANCE_WORLD_STAGE: ", label)
	if capture_dir.is_empty(): return
	root.disable_3d = false
	await _frames(2)
	await RenderingServer.frame_post_draw
	var rendered: Image = root.get_texture().get_image()
	_expect(rendered.save_png(capture_dir.path_join(label + ".png")) == OK, "Actual world capture failed: " + label)
	root.disable_3d = true

func _json_equal(left: Dictionary, right: Dictionary) -> bool:
	var restored_left: Dictionary = JSON.parse_string(JSON.stringify(left))
	var restored_right: Dictionary = JSON.parse_string(JSON.stringify(right))
	return restored_left == restored_right
