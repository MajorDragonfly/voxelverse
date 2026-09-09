extends Control
## Deliberate UI fixture, never installed in the campaign or shared journal.
func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var title := Label.new()
	title.text = "PRÜFANSICHT · Beispieldaten, keine gespeicherten Tiere"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var register := preload("res://ui/discovery/owned_animal_register.gd").new()
	column.add_child(register)
	register.add_entry("Beispieltier A", "Beispielart", "Beispielfraktion", "Beispielwert", "Warten", "Beispielheimat")
	register.add_entry("Beispieltier B mit besonders langem Namen", "Zweite Beispielart", "Beispielfraktion", "nicht angegeben", "Heimkehr", "nicht angegeben")
