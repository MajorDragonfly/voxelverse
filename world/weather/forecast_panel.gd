extends CanvasLayer
## Read-only campaign forecast. The weather owner supplies its current local
## sample; this canvas has no clock, climate model or persistent state.
const Text = preload("res://core/localization/ui_text.gd")
const Layout = preload("res://ui/hud_layout.gd")

var _panel: PanelContainer
var _title: Label
var _rows: Array[Label] = []
var _forecast: Array[Dictionary] = []
var _snapshot: Dictionary = {}
var _player: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 29
	_panel = PanelContainer.new()
	_panel.name = "ForecastPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.10, 0.94)
	style.border_color = Color("365363")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(9)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	_panel.add_child(column)
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", Color("87cab2"))
	column.add_child(_title)
	for index in range(3):
		var row := Label.new()
		row.name = "Forecast%d" % (index + 1)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_font_size_override("font_size", 14)
		row.add_theme_color_override("font_color", Color("d8e6e7"))
		column.add_child(row)
		_rows.append(row)
	_panel.hide()


func present(snapshot: Dictionary, forecast: Array, player: Node) -> void:
	_snapshot = snapshot.duplicate(true)
	_forecast.clear()
	for entry in forecast:
		if entry is Dictionary: _forecast.append(entry.duplicate(true))
	_player = player
	_refresh()


func _process(_delta: float) -> void:
	# Paused/modal visibility, viewport size and live language can all change
	# without a new weather sample.
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_panel): return
	# The diagnostic storm banner owns preview messaging. Showing ordinary
	# forecast rows next to it would imply that the preview changed real fronts.
	_panel.visible = _forecast.size() == 3 and not _snapshot.is_empty() \
		and not bool(_snapshot.get("preview", false)) and Layout.gameplay_entries_visible(self, _player)
	if not _panel.visible: return
	_title.text = Text.text("WEATHER_FORECAST_TITLE")
	for index in range(3):
		var forecast: Dictionary = _forecast[index]
		var condition: String = str(forecast.get("condition", ""))
		var key: String = "WEATHER_FORECAST_" + condition.to_upper()
		if condition not in ["clear", "breeze", "overcast", "drizzle", "rain", "snow", "sleet"]:
			key = "WEATHER_FORECAST_UNKNOWN"
		_rows[index].text = Text.format_text("WEATHER_FORECAST_ROW", {
			"minutes": roundi(float(forecast.get("in_seconds", 0.0)) / 60.0),
			"condition": Text.text(key), "wind": roundi(float(forecast.get("wind_mps", 0.0)))})
	var screen: Vector2 = Layout.screen_size(self)
	var width: float = minf(292.0 if screen.x >= 1000.0 else 280.0, screen.x - 32.0)
	Layout.place(_panel, Rect2(Vector2(screen.x - width - 16.0, 16.0), Vector2(width, 112.0)))
