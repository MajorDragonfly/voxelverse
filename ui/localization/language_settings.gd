extends VBoxContainer
## Hosted by the existing F8 menu; it does not own pause or mouse state.
var choice: OptionButton
var _manager: Node
var _problem: Label

func _ready() -> void:
	_manager = get_node("/root/LocaleManager")
	add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "LANGUAGE_TITLE"
	add_child(title)
	choice = OptionButton.new()
	choice.name = "LanguageChoice"
	choice.custom_minimum_size.y = 48
	choice.add_item("LANGUAGE_AUTO")
	choice.set_item_metadata(0, "auto")
	for code: String in _manager.LANGUAGES:
		choice.add_item(_manager.LANGUAGES[code])
		choice.set_item_metadata(choice.item_count - 1, code)
	add_child(choice)
	var hint := Label.new()
	hint.text = "LANGUAGE_HINT"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	_problem = Label.new()
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_problem)
	refresh()

func refresh() -> void:
	for index in choice.item_count:
		if choice.get_item_metadata(index) == _manager.preference:
			choice.select(index)
	_problem.text = _manager.load_problem

func apply() -> String:
	if choice.get_selected_metadata() == _manager.preference and _manager.load_problem.is_empty():
		return ""
	var error: Error = _manager.save_preference(choice.get_selected_metadata())
	return "" if error == OK else "LANGUAGE_SAVE_FAILED"

func close_popup() -> void:
	choice.get_popup().hide()
