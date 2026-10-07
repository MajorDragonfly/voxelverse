extends "res://ui/hud_presentation.gd"
## Read-only survival display; original controller-owned bars remain in place.
const Style = preload("res://ui/progression_style.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
const Design = preload("res://ui/design/design_system.gd")
const Layout = preload("res://ui/hud_layout.gd")
const ITEMS := [["HealthBar", "health", "HUD_HEALTH", Design.SOCIAL],
	["HungerBar", "diet_plant", "HUD_FOOD", Design.ACCENT],
	["ThirstBar", "thirst", "HUD_THIRST", Design.MUTED]]
var _vitals: Dictionary = {}
var _panel: PanelContainer
var _tick: float = 0.0
var _critical: bool = false

func _ready() -> void:
	add_to_group(&"hud_top_dock")
	super._ready()

func hud_top_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not is_instance_valid(_hud): return rects
	for path: String in ["ProgressionDock", "CombatTargetPanel", "GameplayMessage", "DiscoveryNotification"]:
		var control := _hud.get_node_or_null(path) as Control
		if control != null and control.is_visible_in_tree():
			rects.append(Layout.physical_rect(control))
	return rects

func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0: return
	_tick = 0.1
	var critical := false
	for key: String in _vitals:
		var row: Dictionary = _vitals[key]
		var source: ProgressBar = row.source
		row.bar.max_value = source.max_value
		row.bar.value = source.value
		var low := source.value <= source.max_value * 0.25
		critical = critical or low
		row.value.text = ("! " if low else "") + "%d/%d" % [roundi(source.value), roundi(source.max_value)]
		if row.low != low:
			row.low = low
			row.value.add_theme_color_override("font_color", Design.DANGER if low else Design.TEXT)
	if _panel != null and critical != _critical:
		_critical = critical
		_panel.get_theme_stylebox("panel").border_color = Design.DANGER if critical else Design.EDGE
	_layout()

func _install_hud_presentation() -> void:
	if _player == null: return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null: return
	_style_status_panel()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _style_status_panel() -> void:
	var original := _hud.get_node_or_null("StatusContainer") as Control
	if original == null: return
	original.hide()
	_panel = PanelContainer.new()
	_panel.name = "CompactVitals"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", Design.box(Design.PANEL, Design.EDGE, 12))
	_hud.add_child(_panel)
	var column := Style.column(_panel, 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: Array in ITEMS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		var icon := TextureRect.new()
		icon.name = "VitalIcon_" + item[1]
		icon.texture = Symbols.texture(item[1], item[3])
		icon.tooltip_text = tr(item[2])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Style.label(item[2], 13)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 52
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(38, 7)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", Design.box(Design.INK, Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", Design.box(item[3], Color.TRANSPARENT, 0))
		row.add_child(bar)
		var value := Style.label("", 12)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.custom_minimum_size.x = 66
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_vitals[item[0]] = {"source": original.get_node(item[0]), "bar": bar, "value": value, "low": false}
	_process(1.0)

func vitals_reserved_height() -> float:
	return _panel.size.y + Layout.GAP if _panel != null and _hud.visible else 0.0

func vitals_reserved_width() -> float:
	return _panel.get_combined_minimum_size().x if _panel != null and _hud.visible else 0.0

func _layout() -> void:
	if _panel == null: return
	var font_scale := Layout.text_scale(self)
	Layout.scale_fonts(_panel, font_scale)
	var screen := Layout.screen_size(self)
	var width := maxf(Layout.dock_width(self), _panel.get_combined_minimum_size().x)
	var height := _panel.get_combined_minimum_size().y
	Layout.place(_panel, Rect2(screen - Vector2(width, height) - Vector2.ONE * Layout.MARGIN, Vector2(width, height)))
	var dock := _hud.get_node_or_null("ProgressionDock") as Control
	if dock != null:
		Layout.scale_fonts(dock, font_scale)
		var dock_width := maxf(292.0 if screen.x >= 1000 else 240.0, dock.get_combined_minimum_size().x)
		Layout.place(dock, Rect2(Vector2.ONE * Layout.MARGIN, Vector2(dock_width, dock.get_combined_minimum_size().y)))
	var target := _hud.get_node_or_null("CombatTargetPanel") as Control
	if target != null:
		var combat_width := 300.0 if screen.x >= 1000 else 240.0
		var combat_x := (screen.x - combat_width) / 2.0
		if dock != null and dock.visible: combat_x = maxf(combat_x, dock.position.x / Layout.canvas_scale(self) + dock.size.x + Layout.GAP)
		Layout.place(target, Rect2(Vector2(combat_x, 16), Vector2(combat_width, target.get_combined_minimum_size().y)))
	# The combat header, gameplay message and discovery receipt get separate rows.
	var top := maxf(108.0, target.size.y + 26.0) if target != null and target.visible else 108.0
	for node_name: String in ["GameplayMessage", "DiscoveryNotification"]:
		var label := _hud.get_node_or_null(node_name) as Label
		if label == null or not label.visible: continue
		Layout.scale_fonts(label, font_scale)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not label.minimum_size_changed.is_connected(_request_layout):
			label.minimum_size_changed.connect(_request_layout)
		var message_width := minf(520.0, screen.x - 2.0 * Layout.MARGIN)
		Layout.place(label, Rect2(Vector2((screen.x - message_width) / 2.0, top), Vector2(message_width, 0)))
		top += label.size.y + 10.0
	var behavior := _hud.get_node_or_null("BehaviorActions") as Label
	if behavior != null:
		var action_width := maxf(220, minf(480, screen.x - 2 * (Layout.dock_width(self) + 26)))
		behavior.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		behavior.add_theme_font_size_override("font_size", 14)
		Layout.place(behavior, Rect2(Vector2((screen.x - action_width) / 2, screen.y / 2 + 125), Vector2(action_width, 0)))

func _request_layout() -> void:
	call_deferred("_layout")

func _update_world_label() -> void:
	pass
