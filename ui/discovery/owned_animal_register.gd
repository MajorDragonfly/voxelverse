extends VBoxContainer
## Presentation only. The shared book supplies the read-only D2 projection.
var _entries: VBoxContainer

func _ready() -> void:
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

func present(row: Dictionary) -> void:
	clear()
	_line("Art: %s\n%s: %s\nZustand: %s\nVertrauen: %s" % [row["species"],
		"Letzter Besitzer" if row["dead"] else "Besitzer", row["owner"], row["status"], row["trust"]])
	_line("%s\n\nLetzter bekannter Ort:\n%s" % [row["order"], row["location"]])
	_line("Tierkennung: " + row["key"])

func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_child(label)
