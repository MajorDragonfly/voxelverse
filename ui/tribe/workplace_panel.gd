extends VBoxContainer
## Stable controls over a read model; clicking delegates to the common writer.
const Economy = preload("res://world/tribe/village_economy.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
const Style = preload("res://ui/progression_style.gd")
var controller: Node
var _rows: Dictionary = {}
var _hint: Label

func _ready() -> void:
	_hint = Style.label("", 15, Style.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)

func refresh(data: Dictionary) -> void:
	_hint.text = Text.text("WORKPLACE_HINT")
	var stations: Dictionary = data.economy.stations
	for identity: String in _rows.keys():
		if Economy.station_key(data, identity).is_empty():
			remove_child(_rows[identity])
			_rows[identity].queue_free()
			_rows.erase(identity)
	for key: String in stations:
		var site: Dictionary = stations[key]
		if not _rows.has(site.id):
			var button := Style.button("")
			button.name = "Workplace_" + key.replace(":", "_")
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.pressed.connect(func() -> void: controller.issue_workplace(site.id))
			add_child(button)
			_rows[site.id] = button
		var assigned: int = 0
		for member: Dictionary in data.members:
			if member.get("workplace_id", "") == site.id: assigned += 1
		var button: Button = _rows[site.id]
		button.text = Text.format_text("WORKPLACE_ROW", {"name": Text.text(Presentation.PROJECTS[Economy.station_kind(key)]),
			"number": 1 if key in Economy.STATIONS else 2, "ready": Economy.station_source(data, key).remaining, "assigned": assigned})
		button.tooltip_text = Text.text("WORKPLACE_ASSIGN_HINT")
		button.disabled = controller.selected.is_empty() or get_tree().paused
