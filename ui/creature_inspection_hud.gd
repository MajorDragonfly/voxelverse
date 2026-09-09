extends Node

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
	Style.label(box, "ART ERKANNT", 20, Style.ACCENT)
	_detail = Style.paragraph(box, "", 16)
	_controls = Style.paragraph(box, "", 14)
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
		_scan_label.text = "Art erkannt · J öffnet das Entdeckungsbuch"
		_show_target(target)
	else:
		_scan_label.text = "Unbekannte Art · Scannen %d %%\nHalte das Tier im Fadenkreuz." % floori(_scanner.ratio() * 100.0)
	_controls.text = "%s · Scanmodus schließen\nJ · Entdeckungsbuch" % KeyHints.binding_label("inspection_mode")

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
	_detail.text = (
		"%s\n"
		+ "%s  ·  %.1f m  ·  %s\n\n"
		+ "LEBEN       %d / %d\n"
		+ "TEMPO       %.1f\n"
		+ "SPRUNG      %.1f\n"
		+ "ANGRIFF     %.1f\n"
		+ "ABWEHR      %.1f\n"
		+ "WAHRNEHMUNG %.1f\n"
		+ "GRIFF       %.1f\n"
		+ "SCHWIMMEN   %.1f\n"
		+ "NAHRUNG     %s\n"
		+ "KÖRPERTEILE %d"
	) % [
		str(data.get("name", "Unknown Creature")),
		str(data.get("role", "unknown")).capitalize(),
		distance,
		life_state,
		roundi(float(data.get("health", 0.0))),
		roundi(float(data.get("maximum_health", 0.0))),
		float(data.get("speed", 0.0)),
		float(data.get("jump", 0.0)),
		float(data.get("attack", 0.0)),
		float(data.get("defense", 0.0)),
		float(data.get("perception", 0.0)),
		float(data.get("grip", 0.0)),
		float(data.get("swim", 0.0)),
		diet_text,
		int(data.get("part_count", 0)),
	]


func _diet_label(plant: float, meat: float) -> String:
	if plant > meat * 1.35:
		return "Pflanzenfresser"
	if meat > plant * 1.35:
		return "Fleischfresser"
	if plant > 0.05 and meat > 0.05:
		return "Allesfresser"
	return "Unbekannt"
