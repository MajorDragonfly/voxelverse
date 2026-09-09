extends VBoxContainer
## UI-only D2 preparation. No production binding until D2's reviewed contract exists.
## All arguments are already formatted display text, not a save or ownership schema.
var _entries: VBoxContainer

func _ready() -> void:
	var note := Label.new()
	note.text = "EIGENE TIERE\nHier stehen einzelne Tiere und ihre Bindung. Gescannte Arten und befreundete Wildtiere gehören nicht automatisch dazu."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	_entries = VBoxContainer.new()
	_entries.add_theme_constant_override("separation", 14)
	add_child(_entries)

func clear() -> void:
	for entry in _entries.get_children():
		_entries.remove_child(entry)
		entry.queue_free()

func show_unavailable(message: String) -> void:
	clear()
	_line(message)

func add_entry(display_name: String, species_text: String, owner_text: String,
		trust_text: String, order_text: String, location_text: String) -> void:
	_line("%s\nArt: %s · Besitzer: %s\nVertrauen: %s · Auftrag: %s\nAufenthalt: %s" % [
		display_name, species_text, owner_text, trust_text, order_text, location_text])

func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_child(label)
