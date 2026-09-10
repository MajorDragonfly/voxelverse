extends VBoxContainer
## Presentation only. The shared book supplies the read-only D2 projection.
const Presentation = preload("res://ui/discovery/owned_animal_presentation.gd")
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
	_line(Presentation.format_text("OWNED_ENTRY", {"name": display_name, "species": species_text,
		"owner": owner_text, "trust": trust_text, "order": order_text, "location": location_text}))

func present(row: Dictionary) -> void:
	var lines: Array[String] = Presentation.detail_lines(row)
	# Reuse detail Labels during language changes to preserve the scroll owner.
	if _entries.get_child_count() != lines.size():
		clear()
		for value: String in lines: _line(value)
	else:
		for index in lines.size(): _entries.get_child(index).text = lines[index]

func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_child(label)
