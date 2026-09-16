extends "res://core/diagnostics/workplace_runtime_probe.gd"
## Uses the normal menu session, real terrain, residents and shared save writer.
func _run() -> void:
	print("CONSTRUCTION_RUNTIME: loading normal spherical campaign")
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("Baustellenverwaltung", 15838, Cube.MODE)
	await _open(path)
	print("CONSTRUCTION_RUNTIME: load returned; ", saves.last_error)
	if not _expect_world(): await _done(); return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().get("ok", false), "Cannot establish home.")
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.panel.open_confirmation(), "No tribal confirmation.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 15000)
	if not tribe.is_active(): _expect(false, "No tribal controller."); await _done(); return
	print("CONSTRUCTION_RUNTIME: tribal controller ready")
	Engine.time_scale = 2.0
	var data: Dictionary = tribe.village()
	data.tools = 1
	for kind: String in ["wood", "stone"]:
		data.stock[kind] = 16
		data.deposits[kind].remaining -= 16
	var point: Vector3 = _construction_point(tribe)
	if not point.is_finite(): _expect(false, "No reachable construction place."); await _done(); return
	tribe.select_all()
	_expect(tribe.issue_order("forester", point), "Cannot start physical construction: " + tribe.status)
	await _until(func() -> bool: return tribe.village().members.any(func(member: Dictionary) -> bool: return member.construction_id != ""), 15000)
	_expect(tribe.village().members.any(func(member: Dictionary) -> bool: return member.construction_id != ""), "No physical material pickup.")
	var ui: VBoxContainer = tribe.panel._construction
	ui._pause.pressed.emit()
	_expect(Work.Model.Construction.state(tribe.village().project) == "paused", "Pause button did not pause the project.")
	var reserved: Dictionary = tribe.village().project.materials.duplicate()
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	await _until(func() -> bool: return tribe.village().members.all(func(member: Dictionary) -> bool: return member.construction_id == ""), 15000)
	_expect(tribe.village().project.materials == reserved and tribe.village().project.progress == 0, "Paused project took new goods or performed work.")
	_expect(tribe.village().members.all(func(member: Dictionary) -> bool: return member.construction_id == ""), "Paused in-flight cargo did not arrive.")
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	# Real writer failure must restore the entire project and leave its UI bound.
	var before: Dictionary = tribe.village().duplicate(true)
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not tribe.control_construction("resume").ok and tribe.village() == before, "Failed pause transaction changed village data.")
	DirAccess.remove_absolute(path + ".tmp")
	tribe.panel.refresh()
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	# Cancelling is explicitly confirmed, and changing language keeps that choice.
	ui._cancel.pressed.emit()
	_expect(ui._confirming and Work.Model.Construction.state(tribe.village().project) == "paused", "First cancel click changed the project.")
	TranslationServer.set_locale("en")
	tribe.panel.refresh()
	_expect(ui._confirming and ui._cancel.text == "Cancel and recover materials", "Language refresh lost confirmation or translation.")
	await _construction_layout(tribe)
	ui._keep.pressed.emit()
	_expect(not ui._confirming and Work.Model.Construction.state(tribe.village().project) == "paused", "Keeping the project changed construction.")
	# A pause in gameplay blocks programmatic commands as well as buttons.
	flow.toggle_pause()
	before = tribe.village().duplicate(true)
	_expect(not tribe.control_construction("cancel").ok and tribe.village() == before, "Game pause allowed a construction command.")
	flow.toggle_pause()
	ui._cancel.pressed.emit()
	before = tribe.village().duplicate(true)
	DirAccess.make_dir_absolute(path + ".tmp")
	ui._cancel.pressed.emit()
	_expect(tribe.village() == before and ui._result == "CONSTRUCTION_SAVE_FAILED", "Failed cancellation lost materials or confirmation feedback.")
	DirAccess.remove_absolute(path + ".tmp")
	print("CONSTRUCTION_RUNTIME: UI and rollback verified")
	var deliveries: int = tribe.village().delivered
	ui._cancel.pressed.emit()
	ui._cancel.pressed.emit()
	_expect(Work.Model.Construction.state(tribe.village().project) == "recovering", "Confirmed cancellation did not begin recovery.")
	_expect(tribe.village().stock.wood < 16 and tribe.village().project.progress == 0, "Site material teleported into the warehouse.")
	await _until(func() -> bool: return tribe.village().project.is_empty(), 30000)
	_expect(tribe.village().project.is_empty() and tribe.village().stock.wood == 16 and tribe.village().stock.stone == 16, "Physical recovery did not restore the initial stock: " + str(tribe.village().project))
	_expect(tribe.village().delivered == deliveries and not tribe.village().economy.stations.has("forester"), "Recovery earned a delivery or created a workplace.")
	print("CONSTRUCTION_RUNTIME: recovery complete")
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	await _until(func() -> bool: return not tribe.navigation.pending, 15000)
	_expect(tribe.navigation.free_workplace(point, tribe.village(), "forester"), "Recovered site is still occupied.")
	_expect(tribe.issue_order("forester", point), "Recovered site cannot be rebuilt: " + tribe.status)
	ui._pause.pressed.emit()
	flow.toggle_pause()
	_expect(saves.save_now() and saves.load_now(), "Live paused Save/Load failed: " + saves.last_error)
	_expect(Work.Model.Construction.state(tribe.village().project) == "paused" and not ui._confirming, "Live reload lost pause or retained a stale confirmation.")
	flow.toggle_pause()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 15000)
	_expect(tribe.is_active(), "Loaded tribal controller did not reactivate.")
	tribe.panel.refresh()
	ui._pause.pressed.emit()
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	print("CONSTRUCTION_RUNTIME: resumed after load; ", ui._result, " ", tribe.is_active(), " ", Work.Model.Construction.state(tribe.village().project))
	await _until(func() -> bool: return tribe.village().economy.stations.has("forester"), 40000)
	_expect(tribe.village().economy.stations.has("forester") and tribe.village().project.is_empty(), "Resumed physical construction failed: " + str(tribe.village().project) + " members=" + str(tribe.village().members) + " navigation=" + str(tribe.navigation.pending) + "/" + str(tribe.navigation.is_ready()) + " active=" + str(tribe.is_active()))
	_expect(tribe.village().stock.wood == 12 and tribe.village().stock.stone == 15, "Rebuilt project cost was not charged exactly once.")
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	await _done()

func _construction_point(tribe: Node) -> Vector3:
	for id: int in tribe.navigation.graph.get_point_ids():
		var point: Vector3 = tribe.navigation.graph.get_point_position(id)
		var distance: float = point.distance_to(tribe.anchor())
		if distance > 7.0 and distance < 12.0 and tribe.navigation.free_workplace(point, tribe.village(), "forester") and not tribe.neighbors.occupies(point) and not tribe.settlements.occupies(point): return point
	return Vector3.INF

func _construction_layout(tribe: Node) -> void:
	tribe.panel._tabs.current_tab = tribe.panel._build_page.get_index()
	var ui: VBoxContainer = tribe.panel._construction
	var original: Vector2i = tree.root.size
	var display: Node = tree.root.get_node("DisplaySettings")
	var original_scale: float = display.ui_scale
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			for scale_value: float in [1.0, 1.5]:
				tree.root.size = size
				display.ui_scale = scale_value
				tribe.panel.refresh()
				tribe.panel._layout()
				await _reveal_action(tribe.panel._scroll, ui._cancel)
				var area: Rect2 = tribe.panel._scroll.get_global_rect()
				var rect: Rect2 = ui._cancel.get_global_rect()
				_expect(area.has_point(rect.get_center()) and rect.size.x <= area.size.x + 1, "Construction action inaccessible: %s %s %.1f area=%s button=%s" % [locale, size, scale_value, area, rect])
				_expect(ui._confirming and not ui._details.text.contains("CONSTRUCTION_"), "Layout refresh lost confirmation or localization.")
	tree.root.size = original
	display.ui_scale = original_scale
	TranslationServer.set_locale("de")
	tribe.panel.refresh()

func _reveal_action(scroll: ScrollContainer, button: Control) -> void:
	# Font wrapping and feedback reparenting need several deferred container
	# passes after a resize. Scroll against the settled geometry, retaining a
	# bounded failure if the action never becomes reachable.
	var previous: Array = []
	var stable: int = 0
	for frame in range(30):
		await tree.process_frame
		scroll.ensure_control_visible(button)
		var area: Rect2 = scroll.get_global_rect()
		var rect: Rect2 = button.get_global_rect()
		var current: Array = [area, rect, scroll.scroll_vertical]
		stable = stable + 1 if current == previous else 0
		previous = current
		if stable >= 3 and area.has_point(rect.get_center()) and rect.size.x <= area.size.x + 1: return

func _done() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("CONSTRUCTION_RUNTIME_PASSED: physical pickup/pause/return/rebuild, atomic rollback, live load and 12 UI layouts.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
