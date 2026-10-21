extends VBoxContainer
const State = preload("res://core/map/navigation_state.gd")
const View = preload("res://ui/world_map/navigation_presentation.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
signal selected(id: String)
signal tracked(id: String)
signal stopped
var selected_id: String = ""
var _list: VBoxContainer
var _title: Label
var _target: Label
var _detail: Label
var _message: Label
var _empty: Label
var _track: Button
var _stop: Button
var _signature: Array = []

func _ready() -> void:
	name = "AnimalNavigationPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_title = Style.label(self, "NAV_ANIMALS", 22)
	Style.paragraph(self, "NAV_ANIMALS_LIST_HELP", 16)
	_target = Style.paragraph(self, "", 16)
	_target.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_message = Style.paragraph(self, "", 16)
	_message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)
	_empty = Style.paragraph(self, "NAV_ANIMALS_EMPTY", 16)
	_detail = Style.paragraph(self, "NAV_ANIMALS_SELECT", 16)
	_detail.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var actions := HFlowContainer.new()
	add_child(actions)
	_track = _button(actions, "NAV_TRACK", "AnimalNavigationTrack", func() -> void: tracked.emit(selected_id))
	_stop = _button(actions, "NAV_STOP", "AnimalNavigationStop", func() -> void: stopped.emit())

func _button(parent: Node, key: String, id: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = key
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func refresh(body: Dictionary, animals: Array[Dictionary], address: Dictionary, radius: float, target_title: String, editable: bool, message: String) -> void:
	var point: Dictionary = State.animal(body, selected_id, animals)
	_title.text = Text.format_text("NAV_ANIMALS_COUNT", {"count": animals.size()})
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_target.text = Text.text("NAV_NO_TARGET") if target_title.is_empty() else Text.format_text("NAV_CURRENT_TARGET", {"name": target_title})
	_message.text = message
	_message.visible = not message.is_empty()
	_empty.visible = animals.is_empty()
	var signature: Array = []
	for animal: Dictionary in animals: signature.append(animal.id)
	if signature != _signature:
		_signature = signature
		for child: Node in _list.get_children(): _list.remove_child(child); child.queue_free()
		for animal: Dictionary in animals:
			var id: String = animal.id
			var button := _button(_list, "", "NavigationAnimal_" + str(_list.get_child_count()), func() -> void: selected.emit(id))
			button.set_meta("animal_id", id)
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.toggle_mode = true
	for child: Button in _list.get_children():
		var animal: Dictionary = State.animal(body, child.get_meta("animal_id"), animals)
		child.text = View.name_of(animal)
		child.tooltip_text = View.animal_detail(animal, address, radius)
		child.button_pressed = animal.id == selected_id
	_detail.text = Text.text("NAV_ANIMALS_SELECT") if selected_id.is_empty() else View.animal_detail(point, address, radius)
	_track.disabled = not editable or point.is_empty() or State.view(body).get("target", {}) == {"kind": "owned_animal", "id": selected_id}
	_stop.disabled = not editable or State.view(body).get("target", {}).is_empty()
