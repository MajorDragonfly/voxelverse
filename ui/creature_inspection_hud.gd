extends Node

const Layout = preload("res://ui/hud_layout.gd")
const Symbols = preload("res://ui/discovery/stat_symbols.gd")
const ProgressStyle = preload("res://ui/progression_style.gd")
const KeyHints = preload("res://core/input_preferences.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Reticle = preload("res://ui/discovery/scan_reticle.gd")
# Retained scene property for compatibility with existing player scenes.
@export_range(3, 12, 1) var maximum_listed_creatures: int = 6
var _player: Node
var _scanner: Node
var _panel: PanelContainer
var _detail: Label
var _controls: Label
var _reticle: Control
var _scan_label: Label
var _stats: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent()
	call_deferred("_install")

func _install() -> void:
	_scanner = _player.get_node_or_null("CreatureScanner")
	var hud: CanvasLayer = _player.get_node_or_null("HUD")
	if hud == null or _scanner == null:
		return
	_panel = PanelContainer.new()
	_panel.name = "CreatureInspectionPanel"
	_panel.theme = Style.theme()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -435
	_panel.offset_top = 82
	_panel.offset_right = -22
	_panel.offset_bottom = 540
	_panel.add_theme_stylebox_override("panel", Style.box(Color(0.025, 0.08, 0.09, 0.94)))
	hud.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	Style.label(box, "HUD_IDENTIFIED", 13, Style.ACCENT)
	_detail = Style.paragraph(box, "", 16)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for metric: Dictionary in [{"id": "health", "label": "Leben"}, {"id": "speed", "label": "Tempo"},
		{"id": "attack", "label": "Angriff"}, {"id": "defense", "label": "Abwehr"}]:
		var row := Symbols.label_for(metric)
		row.get_child(0).custom_minimum_size = Vector2(22, 22)
		var label: Label = row.get_child(1)
		label.add_theme_font_size_override("font_size", 11)
		row.remove_child(label)
		var values := VBoxContainer.new()
		values.add_theme_constant_override("separation", 0)
		row.add_child(values)
		values.add_child(label)
		var amount := ProgressStyle.label("", 14)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF
		values.add_child(amount)
		_stats[metric.id] = amount
		grid.add_child(row)
	_controls = Style.paragraph(box, "", 13)
	_ignore_mouse(_panel)
	_reticle = Reticle.new()
	_reticle.name = "CreatureScanReticle"
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.offset_left = -36
	_reticle.offset_top = -36
	_reticle.offset_right = 36
	_reticle.offset_bottom = 36
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_reticle)
	_scan_label = Label.new()
	_scan_label.name = "CreatureScanStatus"
	_scan_label.set_anchors_preset(Control.PRESET_CENTER)
	_scan_label.offset_left = -340
	_scan_label.offset_top = 45
	_scan_label.offset_right = 340
	_scan_label.offset_bottom = 108
	_scan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scan_label.add_theme_font_size_override("font_size", 18)
	_scan_label.add_theme_color_override("font_shadow_color", Style.INK)
	_scan_label.add_theme_constant_override("shadow_offset_x", 2)
	_scan_label.add_theme_constant_override("shadow_offset_y", 2)
	_scan_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_scan_label)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_panel.hide()
	_reticle.hide()
	_scan_label.hide()

func _process(_delta: float) -> void:
	if _scanner == null or _panel == null:
		return
	var enabled: bool = _scanner.active()
	var target: Node = _scanner.target if is_instance_valid(_scanner.target) else null
	_panel.visible = enabled and target != null and _scanner.known
	_reticle.visible = enabled
	_scan_label.visible = enabled
	if not enabled:
		return
	_reticle.progress = _scanner.ratio()
	_reticle.known = _scanner.known
	_reticle.has_target = target != null
	_reticle.queue_redraw()
	if target == null:
		_scan_label.text = "Ziele auf eine Kreatur in deiner Nähe."
	elif _scanner.known:
		_scan_label.text = KeyHints.hint("BIND_SCAN_RECOGNIZED")
		_show_target(target)
	else:
		_scan_label.text = "Unbekannte Art · Scannen %d %%\nHalte das Tier im Fadenkreuz." % floori(_scanner.ratio() * 100.0)
	_controls.text = tr("HUD_SCAN_CONTROLS") % KeyHints.binding_label("inspection_mode")
	_layout()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _show_target(target: Node) -> void:

	var data: Dictionary = target.call("get_inspection_data")
	var distance: float = 0.0
	if target is Node3D and _player is Node3D:
		distance = (
			(_player as Node3D).global_position.distance_to(
				(target as Node3D).global_position
			)
		)
	var diet_text: String = _diet_label(
		float(data.get("diet_plant", 0.0)),
		float(data.get("diet_meat", 0.0))
	)
	var life_state: String = "TOT" if not bool(data.get("alive", true)) else "LEBEND"
	_detail.text = "%s\n%.1f m · %s\n%s" % [str(data.get("name", "Unknown Creature")), distance, life_state, diet_text]
	_stats.health.text = "%d/%d" % [roundi(float(data.get("health", 0))), roundi(float(data.get("maximum_health", 0)))]
	for metric: String in ["speed", "attack", "defense"]:
		_stats[metric].text = "%.1f" % float(data.get(metric, 0))

func _layout() -> void:
	if _panel == null: return
	var screen := Layout.screen_size(self)
	# Identity and key stats stay to the left; full detail is available in J.
	var width := 312.0 if screen.x >= 1000 else 260.0
	var top := 220.0
	var journal := get_tree().get_first_node_in_group(&"discovery_journal")
	if journal != null: top = maxf(top, journal._hud.position.y + journal._hud.size.y + 12)
	Layout.place(_panel, Rect2(Vector2(16, top), Vector2(width, 0)))
	_panel.size.y = _panel.get_combined_minimum_size().y
	var status_width := minf(440.0, screen.x - 2 * (Layout.dock_width(self) + 26))
	status_width = maxf(220, status_width)
	_scan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scan_label.add_theme_font_size_override("font_size", 14)
	Layout.place(_scan_label, Rect2(Vector2((screen.x - status_width) / 2, screen.y / 2 + 48), Vector2(status_width, 0)))



func _diet_label(plant: float, meat: float) -> String:
	if plant > meat * 1.35:
		return "Pflanzenfresser"
	if meat > plant * 1.35:
		return "Fleischfresser"
	if plant > 0.05 and meat > 0.05:
		return "Allesfresser"
	return "Unbekannt"
