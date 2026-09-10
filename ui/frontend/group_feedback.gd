extends VBoxContainer
## Read-only presentation of the controller's selection and committed receipts.
const Text = preload("res://core/localization/ui_text.gd")
const NeighborPresentation = preload("res://ui/tribe/neighbor_presentation.gd")
const Style = preload("res://ui/progression_style.gd")
const LABELS := {"move": "Laufen", "wood": "Holz sammeln", "stone": "Stein sammeln",
	"food": "Nahrung sammeln", "supply": "Versorgung sichern", "tool": "Werkzeug herstellen",
	"hut": "Hütte bauen", "garden": "Garten anlegen", "feed": "Essen", "wait": "Anhalten"}
var controller: Node
var selection: Label
var result: Label
var _last_receipt := ""
var _last_status := ""
var _text := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var row := HBoxContainer.new()
	add_child(row)
	selection = Style.label("", 17, Style.SOCIAL)
	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	selection.name = "GroupSelectionSummary"
	row.add_child(selection)
	var book := Style.button("Buch · J")
	book.name = "OpenGroupJournal"
	book.pressed.connect(func() -> void:
		var journal := get_tree().get_first_node_in_group(&"discovery_journal")
		if journal != null:
			journal.open_journal())
	row.add_child(book)
	result = Style.label("", 16, Style.MUTED)
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	result.name = "GroupOrderResult"
	add_child(result)
	controller.order_resolved.connect(_on_result)
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()

func refresh() -> void:
	var data: Dictionary = controller.village()
	var names := PackedStringArray()
	var carrying := 0
	for member: Dictionary in data.get("members", []):
		if str(member.get("id", "")) in controller.selected:
			names.append(str(member.get("name", "Bewohner")))
			if not str(member.get("cargo", "")).is_empty():
				carrying += 1
	selection.text = Text.text("GROUP_SELECTION_EMPTY")
	if not names.is_empty():
		selection.text = Text.format_text("GROUP_SELECTION", {"count": names.size(), "total": data.get("members", []).size(), "names": ", ".join(names)})
		if carrying > 0:
			selection.text += Text.format_text("GROUP_CARRYING", {"count": carrying})
	if controller.status != _last_status:
		_last_status = controller.status
		_text = _last_status
		result.add_theme_color_override("font_color", Style.MUTED)
	var display_text := _text
	# Only the current neighbor result owns these parameters. Other group commands
	# retain their existing feedback and cannot replay a stale neighbor receipt.
	if NeighborPresentation.RESULT_KEYS.has(_text):
		var outcome: Dictionary = controller.neighbors.last_result
		display_text = NeighborPresentation.result_text(outcome if outcome.get("code") == _text else {})
	result.text = (Text.text("GROUP_PAUSED") if get_tree().paused else "") + display_text

func _on_result(order: StringName, command_id: String, accepted: bool) -> void:
	if command_id.is_empty() or command_id == _last_receipt or get_tree().paused:
		return
	_last_receipt = command_id
	_last_status = controller.status
	var title: String = LABELS.get(String(order), "Gruppenbefehl")
	_text = ("✓ %s · Auftrag für %d Bewohner gespeichert." % [title, controller.selected.size()]
		if accepted else "Nicht ausgeführt · %s" % controller.status)
	result.add_theme_color_override("font_color", Style.SOCIAL if accepted else Style.AGGRESSION)
	refresh()
