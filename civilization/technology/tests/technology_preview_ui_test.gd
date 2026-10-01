extends SceneTree
## Real pointer/keyboard UI flow plus actual viewport-scale captures.
const Preview = preload("res://civilization/technology/technology_preview.gd")
const Text = preload("res://civilization/technology/preview_text.gd")
const Catalog = preload("res://civilization/technology/technology_catalog.gd")
var failures: Array[String] = []
var checks: int = 0
var panel: Control
var capture_dir: String = ""
var close_requests: int = 0

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var index: int = arguments.find("--capture")
	if index >= 0 and index + 1 < arguments.size(): capture_dir = arguments[index + 1]
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _frames(count: int = 2) -> void:
	for frame: int in range(count): await process_frame

func _key(key: Key, viewport: Viewport = null) -> void:
	if viewport == null: viewport = root
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)

func _click(control: Control) -> void:
	_expect(control.is_visible_in_tree(), "Pointer target hidden: " + str(control))
	var point: Vector2 = control.get_global_rect().get_center()
	_expect(root.get_visible_rect().has_point(point), "Pointer target outside viewport: " + str(control))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(2)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)

func _choose_scenario(index: int) -> void:
	for step: int in range(3):
		if panel.model.scenario == index: break
		await _click(panel._scenario)
	_expect(panel.model.scenario == index, "Scenario button did not change the real preview state")

func _select(id: String) -> void:
	if not panel._picker.visible:
		await _click(panel._cards[id])
	else:
		for step: int in range(5):
			if panel.selected_id == id: break
			await _click(panel._next)
	_expect(panel.selected_id == id, "Actual technology navigation failed: " + id)

func _resize(dimensions: Vector2i, scale_factor: float) -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_factor = scale_factor
	root.size = dimensions
	await _frames(8)
	_expect(root.size == dimensions and is_equal_approx(root.content_scale_factor, scale_factor), "Actual window/scale differs from fixture")

func _capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.get_size() == root.size, "Capture does not match physical window: " + name)
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Cannot save rendered capture")

func _visible_text() -> String:
	var lines := PackedStringArray()
	for child: Node in panel._detail.get_children():
		if child is Label: lines.append(child.text)
	return "\n".join(lines)

func _run() -> void:
	print("MEDTECH_UI_STAGE: starting")
	root.gui_embed_subwindows = true
	_expect(root.get_node_or_null("GameState") == null and root.get_node_or_null("SaveGameService") == null, "Standalone UI loaded campaign/save autoloads")
	TranslationServer.set_locale("de")
	panel = Preview.new()
	root.add_child(panel)
	await _resize(Vector2i(1280, 720), 1.0)
	var source_catalog: Dictionary = panel.model.catalog.duplicate(true)
	_expect(panel._mark.disabled and panel.model.marks.is_empty(), "Empty example offers a preview mark")
	print("MEDTECH_UI_STAGE: initial layout")
	await _choose_scenario(1)
	print("MEDTECH_UI_STAGE: example selection")
	_expect(not panel._mark.disabled, "Supplied example does not offer housing mark")
	for id: String in ["medieval.housing", "medieval.storage", "medieval.crafting", "medieval.roads", "medieval.trade"]:
		await _click(panel._cards[id])
		_expect(panel.selected_id == id and not panel._mark.disabled, "Technology navigation/lock wrong: " + id)
		await _click(panel._mark)
		_expect(id in panel.model.marks and not panel.model.status(id)["available"], "Mark awarded a real unlock or did not update: " + id)
	_expect(panel.model.marks.size() == 5, "Real preview flow did not mark all foundations")
	print("MEDTECH_UI_STAGE: preview marks")
	await _click(panel._cards["medieval.storage"])
	await _click(panel._mark)
	_expect("medieval.storage" not in panel.model.marks and "medieval.crafting" not in panel.model.marks and "medieval.trade" not in panel.model.marks, "Removing storage left invalid derived marks")
	await _click(panel._reset)
	_expect(panel.model.scenario == 0 and panel.model.marks.is_empty() and panel.model.facts.is_empty(), "Reset did not clear transient example state")
	for locale: String in ["de", "en"]:
		print("MEDTECH_UI_STAGE: locale ", locale)
		if not TranslationServer.get_locale().begins_with(locale): await _click(panel._language)
		_expect(TranslationServer.get_locale().begins_with(locale) and panel._title.text == Text.text("MEDTECH_TITLE"), "Language input did not refresh presentation")
		for entry: Array in [[Vector2i(1280,720), 1.0], [Vector2i(800,600), 1.5], [Vector2i(1920,1080), 1.0]]:
			var dimensions: Vector2i = entry[0]
			await _resize(dimensions, float(entry[1]))
			await _select("medieval.trade")
			_expect(panel.selected_id == "medieval.trade" and panel._mark.disabled, "Compact selection bypassed prerequisites")
			_expect(root.get_visible_rect().encloses(panel._mark.get_global_rect()) and root.get_visible_rect().encloses(panel._exit.get_global_rect()), "Actions overflow actual scaled viewport")
			_expect(panel._scroll.size.y >= 60, "Detail scroll has no usable height")
			_expect(panel._sidebar.visible == (panel.size.x >= 850) and panel._picker.visible != panel._sidebar.visible, "Responsive navigation wrong")
			_expect(not _visible_text().contains("MEDTECH_") and panel._epoch.text == Text.text("MEDTECH_EPOCH"), "Missing localized explanations or epoch warning")
			await _capture("locks-%dx%d-%s" % [dimensions.x, dimensions.y, locale])
			if dimensions.x == 800:
				# Real wheel input, not an assigned scroll position.
				var point: Vector2 = panel._scroll.get_global_rect().get_center()
				var motion := InputEventMouseMotion.new()
				motion.position = point
				root.push_input(motion, true)
				for tick: int in range(24):
					var scrollbar: VScrollBar = panel._scroll.get_v_scroll_bar()
					if scrollbar.value >= scrollbar.max_value - scrollbar.page: break
					var wheel := InputEventMouseButton.new()
					wheel.position = point
					wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
					wheel.factor = 8.0
					wheel.pressed = true
					root.push_input(wheel, true)
					wheel.pressed = false
					root.push_input(wheel, true)
					await _frames(1)
				_expect(panel._scroll.scroll_vertical > 0, "Small-window details cannot scroll with real wheel input")
				_expect(panel._scroll.get_global_rect().encloses(panel._detail.get_child(-1).get_global_rect()), "Last detail explanation cannot be reached by scrolling")
				await _capture("details-bottom-800x600-" + locale)
		await _resize(Vector2i(1280,720), 1.0)
		await _choose_scenario(2)
		await _click(panel._cards["medieval.trade"])
		_expect(panel.model.marks.size() == 5 and panel._mark.text == Text.text("MEDTECH_UNMARK"), "Complete example not visibly local/marked")
		_expect(_visible_text().contains(Text.text("MEDTECH_PREVIEW_ONLY")) and _visible_text().contains(Text.text("MEDTECH_BALANCE")), "Complete example hides missing effect or provisional balance")
		await _capture("complete-plan-1280x720-" + locale)
		await _click(panel._reset)
	_expect(panel.model.catalog == source_catalog, "UI navigation mutated catalog definitions")
	# Closing and reopening the scene always discards ephemeral marks.
	panel.queue_free()
	await _frames()
	panel = Preview.new()
	panel.close_requested.connect(func() -> void: close_requests += 1)
	root.add_child(panel)
	await _frames()
	_expect(panel.model.marks.is_empty() and panel.model.facts.is_empty(), "Reopening preview restored simulated technology")
	# Keyboard focus stays on reachable controls without changing any model.
	panel._reset.grab_focus()
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() != null and panel.is_ancestor_of(root.gui_get_focus_owner()), "Keyboard focus escaped preview")
	await _click(panel._exit)
	_expect(close_requests == 1, "Close button did not request host-controlled closure")
	await _key(KEY_ESCAPE)
	_expect(close_requests == 2, "Escape did not request host-controlled closure")
	panel.queue_free()
	await _frames()
	if failures.is_empty(): print("MEDTECH_UI_PASSED: ", checks, " checks; real inputs, DE/EN, 3 windows, 150% scale, transient state")
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
