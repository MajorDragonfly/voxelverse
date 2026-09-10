extends VBoxContainer
const Style = preload("res://ui/progression_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/neighbor_presentation.gd")
const Model = preload("res://world/tribe/neighbors/neighbor_state.gd")
var controller: Node
var detail: Label
var contact_button: Button
var aid_button: Button
var focus_button: Button
var home_button: Button

func _ready() -> void:
	name = "Nachbarn"
	process_mode = Node.PROCESS_MODE_ALWAYS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	detail = Style.label("", 18)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)
	var actions := HFlowContainer.new()
	add_child(actions)
	contact_button = Style.button("")
	aid_button = Style.button("")
	focus_button = Style.button("")
	home_button = Style.button("")
	for button: Button in [contact_button, aid_button, focus_button, home_button]:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = 200
		actions.add_child(button)
	contact_button.pressed.connect(func() -> void: controller.neighbors.contact(); controller.panel.refresh())
	aid_button.pressed.connect(func() -> void: controller.neighbors.start_aid(); controller.panel.refresh())
	focus_button.pressed.connect(func() -> void: controller.neighbors.focus())
	home_button.pressed.connect(func() -> void: controller.neighbors.focus(true))
	call_deferred("refresh")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		# Keep the existing Controls, current tab, focus and parent scroll position.
		refresh()

func refresh() -> void:
	if not is_instance_valid(home_button):
		return
	contact_button.text = Text.text("NEIGHBOR_CONTACT")
	aid_button.text = Text.text("NEIGHBOR_AID")
	focus_button.text = Text.text("NEIGHBOR_FOCUS")
	home_button.text = Text.text("NEIGHBOR_HOME")
	aid_button.tooltip_text = Text.text("NEIGHBOR_AID_HINT")
	var tabs := get_parent() as TabContainer
	if tabs != null:
		var index := tabs.get_tab_idx_from_control(self)
		if index >= 0 and index < tabs.get_tab_bar().tab_count:
			tabs.set_tab_title(index, Text.text("NEIGHBOR_TAB"))
	var data: Dictionary = controller.body().get("tribal_neighbor", {})
	contact_button.visible = data.is_empty()
	aid_button.visible = not data.is_empty() and data["aid"]["status"] in ["offered", "active"]
	focus_button.visible = not data.is_empty()
	for button: Button in [contact_button, aid_button, focus_button, home_button]:
		button.disabled = not controller.is_active() or get_tree().paused
	aid_button.disabled = aid_button.disabled or controller.selected.size() < 2
	detail.text = Presentation.detail_text(Model.progress(data))
