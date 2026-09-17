extends CanvasLayer
## Diagnostic-only warning; the normal forecast UI belongs to WEATHER-05.
const Text = preload("res://core/localization/ui_text.gd")
const Layout = preload("res://ui/hud_layout.gd")
var _panel: PanelContainer
var _label: Label
var _snapshot: Dictionary = {}
var _player: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.08, 0.94)
	style.set_content_margin_all(12.0)
	style.set_corner_radius_all(5)
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.hide()

func present(snapshot: Dictionary, player: Node) -> void:
	_snapshot = snapshot.duplicate(true)
	_player = player
	_refresh()

func _process(_delta: float) -> void:
	_refresh() # Pause/inspection and language changes still hide/update this canvas.

func _refresh() -> void:
	if not is_instance_valid(_panel): return
	_panel.visible = _snapshot.get("storm_preview_schema") == 1 and bool(_snapshot.get("preview", false)) \
		and Layout.gameplay_entries_visible(self, _player)
	if not _panel.visible: return
	var phase: String = str(_snapshot.storm_phase)
	var kind: String = Text.text("WEATHER_STORM_SAND" if _snapshot.storm_kind == "sandstorm" else "WEATHER_STORM_ASH")
	_label.text = Text.format_text("WEATHER_STORM_WARNING" if phase == "warning" else "WEATHER_STORM_STATUS", {
		"kind": kind, "seconds": int(ceil(float(_snapshot.storm_phase_remaining))),
		"phase": Text.text("WEATHER_STORM_PHASE_" + phase.to_upper()),
	})
	_label.add_theme_color_override("font_color", Color("ffe4a3") if phase == "warning" else Color("f0f3f5"))
	var screen: Vector2 = Layout.screen_size(self)
	var width: float = minf(420.0, screen.x - 32.0)
	Layout.place(_panel, Rect2(Vector2((screen.x - width) * 0.5, 80.0), Vector2(width, 76.0)))
