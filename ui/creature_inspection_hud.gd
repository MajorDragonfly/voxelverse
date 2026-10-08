extends Node

const Layout = preload("res://ui/hud_layout.gd")
const Design = preload("res://ui/design/design_system.gd")
const GameSymbols = preload("res://ui/design/game_symbols.gd")
const Symbols = preload("res://ui/discovery/stat_symbols.gd")
const ProgressStyle = preload("res://ui/progression_style.gd")
const KeyHints = preload("res://core/input_preferences.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Reticle = preload("res://ui/discovery/scan_reticle.gd")
const Text = preload("res://core/localization/ui_text.gd")
const METRIC_KEYS := {"health": "BP_METRIC_HEALTH", "speed": "BP_METRIC_SPEED", "attack": "BP_METRIC_ATTACK", "defense": "BP_METRIC_DEFENSE"}
# Retained scene property for compatibility with existing player scenes.
@export_range(3, 12, 1) var maximum_listed_creatures: int = 6
var _player: Node
var _scanner: Node
var _panel: PanelContainer
var _species_name: Label
var _diet: Label
var _diet_icon: TextureRect
var _detail: Label
var _controls: Label
var _reticle: Control
var _scan_label: Label
var _stats: Dictionary = {}
var _metric_labels: Dictionary = {}

func scan_circle() -> Dictionary:
	return _reticle.scan_circle() if is_instance_valid(_reticle) else {}

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
	_panel.theme = Design.theme()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -435
	_panel.offset_top = 82
	_panel.offset_right = -22
	_panel.offset_bottom = 540
	_panel.add_theme_stylebox_override("panel", Design.box(Design.PANEL, Design.EDGE, 12))
	hud.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	box.add_child(identity)
	var scan_icon := GameSymbols.view("scan", 18, Design.ACCENT)
	scan_icon.name = "CreatureIdentitySymbol"
	identity.add_child(scan_icon)
	Style.label(identity, "HUD_IDENTIFIED", 13, Design.ACCENT)
	_species_name = Style.paragraph(box, "", 19)
	_species_name.name = "CreatureSpeciesName"
	_species_name.add_theme_color_override("font_color", Design.TEXT)
	_detail = Style.paragraph(box, "", 14)
	_detail.name = "CreatureInspectionDetail"
	var diet_row := HBoxContainer.new()
	diet_row.add_theme_constant_override("separation", 8)
	box.add_child(diet_row)
	_diet_icon = GameSymbols.view("diet_plant", 18, Design.MUTED)
	_diet_icon.name = "CreatureDietSymbol"
	diet_row.add_child(_diet_icon)
	_diet = Style.paragraph(diet_row, "", 13)
	_diet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for metric: Dictionary in [{"id": "health", "label": "Leben"}, {"id": "speed", "label": "Tempo"},
		{"id": "attack", "label": "Angriff"}, {"id": "defense", "label": "Abwehr"}]:
		var row := Symbols.label_for(metric)
		row.get_child(0).custom_minimum_size = Vector2(22, 22)
		row.get_child(0).texture = GameSymbols.texture(metric.id, Design.ACCENT)
		var label: Label = row.get_child(1)
		_metric_labels[metric.id] = label
		label.text = tr(METRIC_KEYS[metric.id])
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
	_controls.add_theme_color_override("font_color", Design.MUTED)
	_ignore_mouse(_panel)
	_reticle = Reticle.new()
	_reticle.name = "CreatureScanReticle"
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.offset_left = -36
	_reticle.offset_top = -36
	_reticle.offset_right = 36
	_reticle.offset_bottom = 36
	_reticle.pivot_offset = Vector2(36, 36)
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
	_scan_label.add_theme_color_override("font_color", Design.TEXT)
	_scan_label.add_theme_color_override("font_shadow_color", Style.INK)
	_scan_label.add_theme_constant_override("shadow_offset_x", 2)
	_scan_label.add_theme_constant_override("shadow_offset_y", 2)
	_scan_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_scan_label)
	get_viewport().size_changed.connect(_layout)
	get_node("/root/LocaleManager").language_changed.connect(_language_changed)
	_layout()
	_panel.hide()
	_reticle.hide()
	_scan_label.hide()

func _language_changed(_locale: String) -> void:
	for id: String in _metric_labels:
		_metric_labels[id].text = tr(METRIC_KEYS[id])
	if _scanner != null and is_instance_valid(_scanner.target) and _panel.visible:
		_show_target(_scanner.target)
	_layout()

func _process(_delta: float) -> void:
	if _scanner == null or _panel == null:
		return
	var enabled: bool = _scanner.active()
	var target: Node = _scanner.target if is_instance_valid(_scanner.target) else null
	var nest: bool = target != null and target.is_in_group(&"wildlife_nest")
	_panel.visible = enabled and target != null and _scanner.known and not nest
	_reticle.visible = enabled
	_scan_label.visible = enabled
	if not enabled:
		return
	_reticle.progress = _scanner.ratio()
	_reticle.known = _scanner.known
	_reticle.has_target = target != null
	if target != null:
		_reticle.target_pixel = _reticle.get_global_transform_with_canvas().affine_inverse() * _scanner.target_pixel
	_reticle.queue_redraw()
	if target == null:
		_scan_label.text = tr("HUD_SCAN_AIM")
	elif nest:
		_scan_label.text = tr("LIVING_NEST_AIMED") if _scanner.known else tr("LIVING_NEST_SCANNING") % floori(_scanner.ratio() * 100.0)
	elif _scanner.known:
		_scan_label.text = KeyHints.hint("BIND_SCAN_RECOGNIZED")
		_show_target(target)
	else:
		_scan_label.text = tr("HUD_SCAN_UNKNOWN") % floori(_scanner.ratio() * 100.0)
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
	var life_state: String = tr("HUD_CREATURE_ALIVE") if bool(data.get("alive", true)) else tr("HUD_CREATURE_DEAD")
	_species_name.text = str(data.get("name", tr("Unbekannte Art")))
	_detail.text = "%.1f m · %s" % [distance, life_state]
	_diet.text = diet_text
	var plant: float = float(data.get("diet_plant", 0.0))
	var meat: float = float(data.get("diet_meat", 0.0))
	_diet_icon.texture = GameSymbols.texture("diet_plant" if plant > meat * 1.35 else "diet_meat" if meat > plant * 1.35 else "food", Design.MUTED)
	var behavior: String = str(data.get("ai_description", ""))
	if not behavior.is_empty():
		_detail.text += "\n" + Text.format_text("HUD_CREATURE_BEHAVIOR", {"state": behavior})
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
		return tr("HUD_CREATURE_DIET_PLANT")
	if meat > plant * 1.35:
		return tr("HUD_CREATURE_DIET_MEAT")
	if plant > 0.05 and meat > 0.05:
		return tr("HUD_CREATURE_DIET_OMNIVORE")
	return tr("Unbekannt")
