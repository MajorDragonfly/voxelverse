extends VBoxContainer
## Two render-only previews and anatomy projections inside the existing book.

signal wish_requested(part_id: String, desired: bool)

const Text = preload("res://ui/discovery/journal_presentation.gd")
const Data = preload("res://core/discovery/species_comparison.gd")
const Symbols = preload("res://ui/discovery/stat_symbols.gd")
const Preview = preload("res://ui/discovery/journal_preview.gd")

var own_preview: SubViewportContainer
var species_preview: SubViewportContainer
var own_name: Label
var species_name: Label
var stats_grid: GridContainer
var stats_notice: Label
var part_choice: OptionButton
var part_state: Label
var part_values: VBoxContainer
var wish_button: Button
var _parts: Array[Dictionary] = []
var _selected_part: String = ""
var _species_complete: bool = false
var _deck: BoxContainer
var _models: BoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var deck := BoxContainer.new()
	_deck = deck
	deck.add_theme_constant_override("separation", 24)
	add_child(deck)
	var models := BoxContainer.new()
	_models = models
	models.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	models.add_theme_constant_override("separation", 12)
	deck.add_child(models)
	var own_column := VBoxContainer.new()
	own_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	models.add_child(own_column)
	own_name = _label("Deine Kreatur", 17)
	own_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	own_column.add_child(own_name)
	own_preview = Preview.new()
	own_preview.name = "OwnCreaturePreview"
	own_column.add_child(own_preview)
	own_preview.custom_minimum_size.y = 210
	var species_column := VBoxContainer.new()
	species_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	models.add_child(species_column)
	species_name = _label("Entdeckte Art", 17)
	species_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	species_column.add_child(species_name)
	species_preview = Preview.new()
	species_preview.name = "ObservedCreaturePreview"
	species_column.add_child(species_preview)
	species_preview.custom_minimum_size.y = 210
	var values := VBoxContainer.new()
	values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.add_child(values)
	var note := _label("JOURNAL_ANATOMY_NOTE", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("bdcebf")
	values.add_child(note)
	stats_grid = GridContainer.new()
	stats_grid.name = "ComparisonStats"
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 7)
	values.add_child(stats_grid)
	stats_notice = _label("Werte nicht verfügbar: Ein gespeicherter Körperbau ist unvollständig oder enthält frühere Teile.", 14)
	stats_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_notice.hide()
	add_child(stats_notice)
	var controls := _label("Ansichten einzeln drehen: ziehen · Zoom: Mausrad", 14)
	controls.modulate = Color("bdcebf")
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(controls)
	add_child(HSeparator.new())
	add_child(_label("KÖRPERTEILE DER ENTDECKTEN ART", 15))
	part_choice = OptionButton.new()
	part_choice.name = "ObservedPartChoice"
	part_choice.custom_minimum_size.y = 40
	part_choice.fit_to_longest_item = false
	part_choice.item_selected.connect(_select_part)
	add_child(part_choice)
	part_state = _label("", 15)
	part_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(part_state)
	part_values = VBoxContainer.new()
	part_values.name = "ObservedPartContribution"
	add_child(part_values)
	wish_button = Button.new()
	wish_button.name = "WishObservedPart"
	wish_button.custom_minimum_size.y = 40
	wish_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_layout)
	wish_button.pressed.connect(_wish)
	add_child(wish_button)


func present(own: Dictionary, observed: Dictionary, state: Dictionary) -> void:
	own_name.text = Text.text("Deine Kreatur")
	own_name.tooltip_text = str(own.get("name", ""))
	species_name.text = Text.text("Entdeckte Art")
	species_name.tooltip_text = str(observed.get("name", ""))
	own_preview.call("show_blueprint", own)
	species_preview.call("show_blueprint", observed)
	var own_stats: Dictionary = Data.stats_for(own)
	var observed_stats: Dictionary = Data.stats_for(observed)
	_species_complete = not observed_stats.is_empty()
	_clear_children(stats_grid)
	for title in ["Körperbau", "Du", "Art", "Art − Du"]:
		var label := _label(title, 14)
		label.modulate = Color("bdcebf")
		stats_grid.add_child(label)
	for metric in Data.METRICS:
		var id: String = metric["id"]
		if id not in Data.MAIN_METRICS:
			continue
		stats_grid.add_child(_metric(metric))
		stats_grid.add_child(_number(own_stats, id))
		stats_grid.add_child(_number(observed_stats, id))
		var difference := _label("—", 16)
		difference.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not own_stats.is_empty() and not observed_stats.is_empty():
			var delta: float = float(observed_stats[id]) - float(own_stats[id])
			difference.set_meta("journal_number", [delta, true])
			difference.text = Text.number(delta, true)
			difference.modulate = Color("a8ddba") if delta > 0.005 else (Color("e8b7a1") if delta < -0.005 else Color("bdcebf"))
		Text.bind(difference, "tooltip_text", "Wert der entdeckten Art minus dein Körperbauwert.")
		stats_grid.add_child(difference)
	stats_notice.visible = own_stats.is_empty() or observed_stats.is_empty()
	_parts = Data.part_rows(observed, state)
	part_choice.clear()
	var selected: int = 0
	for row in _parts:
		part_choice.add_item("%s · %d×" % [Text.part(row.id), row.count])
		part_choice.set_item_metadata(part_choice.item_count - 1, row["id"])
		if row["id"] == _selected_part:
			selected = part_choice.item_count - 1
	part_choice.disabled = _parts.is_empty()
	if not _parts.is_empty():
		part_choice.select(selected)
	_select_part(selected)


func clear() -> void:
	own_preview.call("clear")
	species_preview.call("clear")
	_clear_children(stats_grid)
	_clear_children(part_values)
	_parts.clear()
	part_choice.clear()
	wish_button.hide()


func _select_part(index: int) -> void:
	_clear_children(part_values)
	wish_button.hide()
	if index < 0 or index >= _parts.size():
		part_state.text = Text.text("Keine gespeicherten Körperteile.")
		return
	var part: Dictionary = _parts[index]
	_selected_part = part["id"]
	if part.available and _species_complete and not part.contribution.is_empty():
		for metric in Data.METRICS:
			var id: String = metric["id"]
			if not part["contribution"].has(id):
				continue
			var line := _metric(metric)
			var value := _label(Text.number(part["contribution"][id], true), 16)
			value.set_meta("journal_number", [part.contribution[id], true])
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(value)
			part_values.add_child(line)
	wish_button.visible = part["wished"] or (part["available"] and not part["unlocked"])
	_render_part_text()


func _wish() -> void:
	if part_choice.selected >= 0 and part_choice.selected < _parts.size():
		var row: Dictionary = _parts[part_choice.selected]
		wish_requested.emit(str(row["id"]), not bool(row["wished"]))


func _number(stats: Dictionary, id: String) -> Label:
	var label := _label("—" if stats.is_empty() else Text.number(float(stats[id])), 17)
	if not stats.is_empty(): label.set_meta("journal_number", [float(stats[id]), false])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.name = "Value_" + id
	return label


func _label(text: String, size_value: int) -> Label:
	var label := Label.new()
	if not text.is_empty(): Text.bind(label, "text", text)
	label.add_theme_font_size_override("font_size", size_value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _metric(metric: Dictionary) -> HBoxContainer:
	var row := Symbols.label_for(metric)
	Text.bind(row, "tooltip_text", metric.hint)
	var label: Label = row.get_child(1)
	Text.bind(label, "text", metric.label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 80
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _render_part_text() -> void:
	if part_choice.selected < 0 or part_choice.selected >= _parts.size():
		part_state.text = Text.text("Keine gespeicherten Körperteile.")
		return
	var part: Dictionary = _parts[part_choice.selected]
	part_state.text = Text.text("Freigeschaltet · im Editor verfügbar" if part.unlocked else "Noch gesperrt")
	if not part.available: part_state.text = Text.text("Dieses frühere Teil fehlt im aktuellen Katalog.")
	elif not _species_complete: part_state.text += Text.text("JOURNAL_PART_LEGACY")
	elif part.contribution.is_empty(): part_state.text += Text.text("JOURNAL_PART_NEUTRAL")
	else: part_state.text += Text.text("JOURNAL_PART_CONTRIBUTION") % part.count
	wish_button.text = Text.text("Von Merkliste entfernen" if part.wished else "Auf Merkliste setzen")


func refresh_language() -> void:
	Text.refresh(self)
	for index in _parts.size():
		part_choice.set_item_text(index, "%s · %d×" % [Text.part(_parts[index].id), _parts[index].count])
	_render_part_text()
	_layout()


func _layout() -> void:
	if _deck == null: return
	_deck.vertical = size.x < 900
	_models.vertical = size.x < 460
