extends VBoxContainer
## A small optional editor selection control; it never saves on its own.
signal template_chosen(copy: Dictionary)

const Templates = preload("res://civilization/buildings/templates/building_templates.gd")
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
const Text = preload("res://core/localization/ui_text.gd")

var options: OptionButton
var details: Label
var use_button: Button
var _entries: Array[Dictionary] = []
var _title: Label


func _ready() -> void:
	# Existing saved-design controls can widen their scroll content. Keep this
	# optional picker readable within the editor's narrow sidebar regardless.
	custom_minimum_size.x = 280
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title = Label.new()
	add_child(_title)
	options = OptionButton.new()
	options.name = "BuildingTemplates"
	options.fit_to_longest_item = false
	options.clip_text = true
	options.item_selected.connect(func(_index: int): _refresh_details())
	add_child(options)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	use_button = Button.new()
	use_button.name = "UseTemplateCopy"
	use_button.custom_minimum_size.y = 36
	use_button.pressed.connect(_use_selected)
	add_child(use_button)
	_entries = Templates.list_templates()
	_refresh_language()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(options):
		_refresh_language()


func select_template(template_id: String) -> bool:
	for index in range(_entries.size()):
		if str(_entries[index].id) == template_id:
			options.select(index)
			_refresh_details()
			return true
	return false


func _refresh_language() -> void:
	var previous: int = maxi(options.selected, 0)
	_title.text = Text.text("BUILDING_TEMPLATES_TITLE")
	use_button.text = Text.text("BUILDING_TEMPLATE_USE_COPY")
	options.clear()
	for entry in _entries:
		options.add_item(Text.text(str(entry.title_key)))
		options.set_item_metadata(options.item_count - 1, str(entry.id))
	if options.item_count > 0:
		options.select(mini(previous, options.item_count - 1))
	_refresh_details()


func _refresh_details() -> void:
	use_button.disabled = options.selected < 0
	if options.selected < 0:
		details.text = Text.text("BUILDING_TEMPLATE_UNAVAILABLE")
		return
	var entry: Dictionary = _entries[options.selected]
	var design: Dictionary = Templates.load_template(str(entry.id))
	use_button.disabled = design.is_empty()
	if design.is_empty():
		details.text = Text.text("BUILDING_TEMPLATE_UNAVAILABLE")
		return
	var stats: Dictionary = Blueprint.calculate_stats(design)
	var values: Array[String] = []
	for key in ["cost", "housing", "commerce", "industry", "defense", "prestige", "energy", "pollution"]:
		values.append(Text.text("BUILDING_TEMPLATE_STAT_" + str(key).to_upper()) + ": " + Text.number(float(stats[key]), 0))
	details.text = Text.text(str(entry.description_key)) + "\n" + Text.format_text("BUILDING_TEMPLATE_SOURCE", {
		"id": entry.id, "revision": int(entry.revision), "count": design.parts.size(),
	}) + "\n" + " · ".join(values) + "\n" + Text.text("BUILDING_TEMPLATE_VALUES_NOTE")


func _use_selected() -> void:
	if options.selected < 0:
		return
	var copy: Dictionary = Templates.create_copy(str(_entries[options.selected].id))
	if not copy.is_empty():
		template_chosen.emit(copy)
