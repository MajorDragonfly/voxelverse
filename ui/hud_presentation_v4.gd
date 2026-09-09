extends "res://ui/hud_presentation.gd"
## Compact read-only survival display. Player state and original bar references
## remain owned by the player controller; menus retain the existing HUD layer.
const Style = preload("res://ui/progression_style.gd")
const Symbols = preload("res://ui/discovery/stat_symbols.gd")
var _vitals: Dictionary = {}
var _tick: float = 0.0

func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0: return
	_tick = 0.15
	for key: String in _vitals:
		var row: Dictionary = _vitals[key]
		var source: ProgressBar = row["source"]
		row["bar"].max_value = source.max_value
		row["bar"].value = source.value
		row["value"].text = "%d / %d" % [roundi(source.value), roundi(source.max_value)]
		row["value"].add_theme_color_override("font_color", Color("ffab89") if source.value < source.max_value * 0.25 else Style.TEXT)

func _install_hud_presentation() -> void:
	if _player == null: return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null: return
	_style_status_panel()
	# ContextActionHUD already owns the crosshair; the scanner replaces it with E.

func _style_status_panel() -> void:
	var original := _hud.get_node_or_null("StatusContainer") as Control
	if original == null: return
	original.hide()
	var panel := PanelContainer.new()
	panel.name = "CompactVitals"
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(282, 108)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Style.box(Color(0.035, 0.07, 0.10, 0.86), Color("365361"), 12))
	_hud.add_child(panel)
	var column := Style.column(panel, 7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in [["HealthBar", "health", "Leben"], ["HungerBar", "diet_plant", "Sättigung"], ["ThirstBar", "swim", "Wasser"]]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Symbols.ICONS[item[1]]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(21, 21)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Style.label(item[2], 12)
		label.custom_minimum_size.x = 56
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(74, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", Style.box(Color("253947"), Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", Style.box(_get_bar_color(item[0]), Color.TRANSPARENT, 0))
		row.add_child(bar)
		var value := Style.label("", 12)
		value.custom_minimum_size.x = 62
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_vitals[item[0]] = {"source": original.get_node(item[0]), "bar": bar, "value": value}
	_process(1.0)

func _update_world_label() -> void:
	pass
