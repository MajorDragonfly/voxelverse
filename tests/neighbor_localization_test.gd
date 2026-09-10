extends SceneTree
## UI fixture only; physical delivery/save failures are covered by the world test.
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Runtime = preload("res://world/tribe/neighbors/neighbor_runtime.gd")
const Page = preload("res://ui/tribe/neighbor_panel.gd")
const Feedback = preload("res://ui/frontend/group_feedback.gd")
const Presentation = preload("res://ui/tribe/neighbor_presentation.gd")
const Style = preload("res://ui/progression_style.gd")
var failures: Array[String] = []
var checks: int = 0

class Controller extends Node:
	signal order_resolved(order: StringName, command_id: String, accepted: bool)
	var record: Dictionary = {}
	var selected: Array = []
	var status: String = ""
	var neighbors: Node3D
	var panel: Node
	func body() -> Dictionary: return record
	func village() -> Dictionary: return record.tribe
	func is_active() -> bool: return true
	func refresh() -> void: pass

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _frames(count: int = 4) -> void:
	for frame in range(count): await process_frame

func _run() -> void:
	await process_frame
	root.get_node("SaveGameService").autosave_enabled = false
	var locale := root.get_node("LocaleManager")
	var campaign: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/home_group_pr20.json")).campaign
	var home: Dictionary = campaign.bodies["15838"].home_group
	var village: Dictionary = Tribe.create(home, campaign, {"position": home.anchor}, {"wood": home.anchor, "stone": home.anchor, "food": home.anchor, "huts": [home.anchor, home.anchor]})
	var center: Vector3 = Tribe.Home.vector(home.anchor) + Vector3(10, 0, 0)
	var data := Neighbor.create(campaign, village, center, [center + Vector3(1, 0, 1), center + Vector3(-1, 0, 1)])
	var controller := Controller.new()
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	controller.record = {"tribe": village, "tribal_neighbor": data}
	controller.panel = controller
	root.add_child(controller)
	controller.neighbors = Runtime.new()
	controller.neighbors.controller = controller
	controller.add_child(controller.neighbors)
	controller.selected = village.members.slice(0, 2).map(func(m: Dictionary) -> String: return m.id)
	# Both model commands and fact reads are independent of the selected locale.
	var outcomes: Array[Dictionary] = []
	for language: String in ["de", "en"]:
		locale._apply(language)
		outcomes.append(Neighbor.begin_result(data.duplicate(true), village.duplicate(true), controller.selected))
	_expect(outcomes[0] == outcomes[1] and outcomes[0].ok, "Command result changes with language")
	var before := data.duplicate(true)
	var rejected := Neighbor.begin_result(data, village, [controller.selected[0]])
	_expect(not rejected.ok and rejected.code == "neighbor.selection_required" and data == before, "Rejected command changed shipment")
	var facts := Neighbor.progress(data)
	facts.received.food = 999
	facts.required.food = 999
	_expect(data == before and Neighbor.COST.food == 6, "Presentation facts expose mutable stock or costs")
	village.members[0].name = "Beenden {count}"
	data.name = "Uferbund der langen Flusslandschaft {name}"
	var background := ColorRect.new()
	background.color = Color("081820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Style.box())
	root.add_child(frame)
	var column := VBoxContainer.new()
	frame.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.use_hidden_tabs_for_min_size = false
	scroll.add_child(tabs)
	var placeholder := Control.new()
	placeholder.name = "Fixture"
	tabs.add_child(placeholder)
	var page := Page.new()
	page.controller = controller
	tabs.add_child(page)
	tabs.current_tab = 1
	var feedback := Feedback.new()
	feedback.controller = controller
	column.add_child(feedback)
	controller.neighbors._publish(Neighbor.result(true, "neighbor.contacted", {"name": data.name, "food": 6, "wood": 4}))
	feedback.refresh()
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(800, 600)
	frame.position = Vector2(20, 20)
	frame.size = Vector2(740, 480)
	await _frames()
	page.aid_button.grab_focus()
	paused = true
	var stored := JSON.stringify(controller.record)
	var save := FileAccess.open("user://neighbor-locale-fixture.json", FileAccess.WRITE)
	save.store_string(stored)
	save.close()
	for language: String in ["de", "en", "de", "en"]:
		locale._apply(language)
		await _frames()
		_expect(tabs.current_tab == 1 and page.aid_button.has_focus(), "Language change lost tab or keyboard focus")
		_expect(controller.selected.size() == 2 and paused, "Language change lost selection or pause")
		_expect(JSON.stringify(controller.record) == stored, "Language change mutated campaign data")
		_expect(FileAccess.get_file_as_string("user://neighbor-locale-fixture.json") == stored, "Language change changed saved bytes")
		_expect(data.name in page.detail.text and data.name in feedback.result.text and village.members[0].name in feedback.selection.text, "Names or placeholder-like name text were translated")
		_expect(tabs.get_tab_title(1) == ("Neighbors" if language == "en" else "Nachbarn"), "Tab title did not refresh")
		_expect(("needs 6 food" if language == "en" else "braucht 6 Nahrung") in feedback.result.text, "Existing command feedback did not retranslate")
		_expect(page.aid_button.disabled, "Paused command became enabled after language change")
	# Every state and runtime result has a real translation in both catalogs.
	for language: String in ["de", "en"]:
		locale._apply(language)
		for code: String in Presentation.RESULT_KEYS:
			var message := Presentation.result_text(Neighbor.result(false, code, {"name": "Beenden", "count": 2, "food": 6, "wood": 4}))
			_expect(not message.begins_with("NEIGHBOR_") and "{count}" not in message, "Missing command translation: " + code)
		for status: String in Presentation.STATUS_KEYS:
			data.aid.status = status
			page.refresh()
			_expect(Presentation.detail_text(Neighbor.progress(JSON.parse_string(JSON.stringify(data)))) == page.detail.text, "JSON reload changed displayed quantities")
			_expect(("Food 0 / 6" if language == "en" else "Nahrung 0 / 6") in page.detail.text, "Missing translated delivery counts")
		controller.record.erase("tribal_neighbor")
		page.refresh()
		_expect(page.contact_button.visible and not page.aid_button.visible and not page.focus_button.visible, "Empty view actions are incorrect")
		_expect(("Neighboring tribes" if language == "en" else "Nachbarstämme") in page.detail.text, "Empty view is untranslated")
		controller.record.tribal_neighbor = data
	# Force vertical overflow to verify scroll retention, without replacing nodes.
	data.name = "\n".join(Array(PackedStringArray([data.name, data.name, data.name, data.name, data.name, data.name])))
	page.refresh()
	frame.size.y = 250
	await _frames()
	scroll.scroll_vertical = 45
	await _frames()
	var previous_scroll := scroll.scroll_vertical
	locale._apply("de")
	await _frames()
	_expect(previous_scroll > 0 and scroll.scroll_vertical == previous_scroll, "Language change lost scroll position")
	data.name = "Uferbund der langen Flusslandschaft {name}"
	data.aid.status = "active"
	data.aid.received.food = 3
	data.aid.received.wood = 1
	paused = false
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = resolution
		for zoom: float in [1.0, 1.5]:
			frame.scale = Vector2.ONE * zoom
			frame.size = Vector2(minf(900, (resolution.x - 40) / zoom), (resolution.y - 40) / zoom)
			for language: String in ["de", "en"]:
				locale._apply(language)
				page.refresh()
				feedback.refresh()
				await _frames(8)
				var viewport_rect := Rect2(Vector2.ZERO, Vector2(resolution))
				_expect(viewport_rect.encloses(frame.get_global_rect()), "Panel exceeds viewport: " + str(resolution) + "/" + str(zoom))
				for button: Button in [page.aid_button, page.focus_button, page.home_button]:
					_expect(button.get_global_rect().end.x <= frame.get_global_rect().end.x, "Action overflows panel horizontally")
				if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
					scroll.scroll_vertical = 0
					await _frames()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("user://neighbor-%s-%dx%d-%d.png" % [language, resolution.x, resolution.y, roundi(zoom * 100)])
				for button: Button in [page.aid_button, page.focus_button, page.home_button]:
					scroll.ensure_control_visible(button)
					await _frames()
					_expect(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Scrolled action remains unreachable")
				if resolution == Vector2i(800, 600) and zoom == 1.5 and "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("user://neighbor-%s-800x600-150-actions.png" % language)
	paused = false
	frame.queue_free()
	background.queue_free()
	controller.queue_free()
	await _frames()
	print("NEIGHBOR_LOCALIZATION_TEST: ", checks, " checks; failures=", failures)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
