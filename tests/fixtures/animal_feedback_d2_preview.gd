extends "res://tests/fixtures/owned_animal_d2_preview.gd"
## A host example around the unchanged D2 lab, not a second taming simulation.
const Feedback = preload("res://ui/frontend/animal_action_feedback.gd")
const Style = preload("res://ui/progression_style.gd")
var feedback: Node
var _request := 0
var _last_result: Dictionary = {}
var _feedback_scroll: ScrollContainer
var _lab_panel: PanelContainer

func _ready() -> void:
	super()
	feedback = Feedback.new()
	add_child(feedback)
	feedback.feedback_changed.connect(_present)
	if lab == null: return
	feedback.bind_source(lab.controller, _context, _names)
	_compact_lab()
	_last_result = lab.controller.last_result.duplicate()
	for key in ["offer", "cancel", "follow", "wait", "home", "abandon", "hurt"]:
		var button: Button = lab.buttons[key]
		for connection: Dictionary in button.pressed.get_connections():
			button.pressed.disconnect(connection["callable"])
		button.pressed.connect(perform.bind(key))

func perform(action: String) -> Dictionary:
	var id: String = lab.fixture.ANIMAL
	var result: Dictionary
	match action:
		"offer": result = lab.controller.begin_offer(id, lab.selected_food, lab.live_context())
		"cancel": result = lab.controller.interrupt_offer(id)
		"abandon": result = lab.controller.abandon_claim(id, lab.live_context())
		"hurt": result = lab.controller.damage(id, 50.0)
		_: result = lab.controller.command(id, action, lab.live_context())
	forward_result(result)
	return result

func forward_result(result: Dictionary) -> void:
	_request += 1
	feedback.report_result(lab.fixture.ANIMAL, result, "lab-request-%d" % _request)
	_last_result = result.duplicate()

func _process(_delta: float) -> void:
	if lab == null: return
	# Only this lab wrapper observes last_result: D2's existing physics loop calls
	# advance_offer internally. A production host forwards that actual return directly.
	var result: Dictionary = lab.controller.last_result
	if result != _last_result:
		forward_result(result)

func load_probe() -> void:
	super()
	if is_instance_valid(feedback):
		_last_result = lab.controller.last_result.duplicate()
		feedback.clear_after_load()

func reset_probe() -> void:
	super()
	if is_instance_valid(feedback):
		_last_result = lab.controller.last_result.duplicate()
		feedback.clear_after_load()

func _present(text: String, kind: String) -> void:
	if not is_instance_valid(lab): return
	lab.message_text = text
	lab._update_ui()
	lab.message.modulate = Style.AGGRESSION if kind == "error" else (Style.SOCIAL if kind == "success" else Style.MUTED)
	if _feedback_scroll != null and not text.is_empty():
		_feedback_scroll.set_deferred("scroll_vertical", 0)

func _compact_lab() -> void:
	# Only this labelled host preview changes layout; the D2 lab source is untouched.
	var column: VBoxContainer = lab.message.get_parent()
	_lab_panel = column.get_parent()
	column.move_child(lab.message, 2)
	for item: Node in column.get_children():
		if item is Label:
			item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item.custom_minimum_size.x = 0
		elif item is HBoxContainer:
			for button: Button in item.get_children():
				button.clip_text = true
				button.tooltip_text = button.text
	# Keep the single journal's entry inside the preview controls, away from them.
	journal._hud.get_child(0).hide()
	var book := Style.button("Entdeckungsbuch · J")
	book.pressed.connect(journal.open_journal)
	column.add_child(book)
	column.move_child(book, 2)
	_lab_panel.remove_child(column)
	_feedback_scroll = ScrollContainer.new()
	_feedback_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lab_panel.add_child(_feedback_scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_scroll.add_child(column)
	get_viewport().size_changed.connect(_layout_lab)
	_layout_lab()

func _layout_lab() -> void:
	var extent := get_viewport().get_visible_rect().size
	var scale_factor := extent.x / maxf(float(get_window().size.x), 1.0)
	var layer: CanvasLayer = _lab_panel.get_parent()
	layer.transform = Transform2D(0.0, Vector2.ONE * scale_factor, 0.0, Vector2.ZERO)
	extent /= scale_factor
	_lab_panel.custom_minimum_size.x = 0
	_lab_panel.size = Vector2(minf(420, extent.x - 36), extent.y - 36)
