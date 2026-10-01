extends CanvasLayer
## Read-only campaign forecast. The weather owner supplies its current local
## sample; this canvas has no clock, climate model or persistent state.
const Text = preload("res://core/localization/ui_text.gd")
const Layout = preload("res://ui/hud_layout.gd")
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")

var _panel: PanelContainer
var _title: Label
var _day: Label
var _day_bar: ProgressBar
var _segments: Array[ColorRect] = []
var _warning: Label
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
	_day = Label.new()
	_day.name = "DayClock"
	_day.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day.add_theme_font_size_override("font_size", 14)
	_day.add_theme_color_override("font_color", Color("e9d8a4"))
	column.add_child(_day)
	_day_bar = ProgressBar.new()
	_day_bar.name = "DayProgress"
	_day_bar.show_percentage = false
	_day_bar.step = 0.0
	_day_bar.custom_minimum_size.y = 9
	_day_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var night := StyleBoxFlat.new()
	night.bg_color = Color("283a56")
	_day_bar.add_theme_stylebox_override("background", night)
	var daylight := StyleBoxFlat.new()
	daylight.bg_color = Color("e9bb67")
	_day_bar.add_theme_stylebox_override("fill", daylight)
	column.add_child(_day_bar)
	var strip := HBoxContainer.new()
	strip.name = "WeatherTimeline"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_constant_override("separation", 3)
	column.add_child(strip)
	for index in range(4):
		var segment := ColorRect.new()
		segment.name = "WeatherSegment%d" % index
		segment.custom_minimum_size = Vector2(32, 9)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(segment)
		_segments.append(segment)
	_warning = Label.new()
	_warning.name = "IncomingStorm"
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.add_theme_font_size_override("font_size", 14)
	_warning.add_theme_color_override("font_color", Color("ffca85"))
	column.add_child(_warning)
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
	_forecast.clear()
	for entry in forecast:
		if entry is Dictionary: _forecast.append(entry.duplicate(true))
	present_current(snapshot, player)


func present_current(snapshot: Dictionary, player: Node) -> void:
	# The inexpensive current/day port follows every campaign sample. Future
	# regional samples keep their independent one-second refresh budget.
	_snapshot = snapshot.duplicate(true)
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
	var clock: float = float(_snapshot.get("elapsed_seconds", 0.0))
	var day_fraction: float = Atmosphere.day_progress(clock)
	var minute_of_day: int = int(floor(day_fraction * 1440.0))
	_day.text = Text.format_text("WEATHER_DAY_CLOCK", {
		"day": int(floor(maxf(clock, 0.0) / Atmosphere.DAY_SECONDS + Atmosphere.CLOCK_START)) + 1,
		"hour": str(floori(float(minute_of_day) / 60.0)).pad_zeros(2),
		"minute": str(minute_of_day % 60).pad_zeros(2)})
	_day_bar.value = day_fraction * 100.0
	_segments[0].color = _condition_color(str(_snapshot.get("condition", "")))
	var storm_minutes: int = 0
	for index in range(3):
		var forecast: Dictionary = _forecast[index]
		var condition: String = str(forecast.get("condition", ""))
		_segments[index + 1].color = _condition_color(condition)
		if storm_minutes == 0 and _is_upcoming_storm(forecast):
			storm_minutes = roundi(float(forecast.get("in_seconds", 0.0)) / 60.0)
		var key: String = "WEATHER_FORECAST_" + condition.to_upper()
		if condition not in ["clear", "breeze", "overcast", "drizzle", "rain", "snow", "sleet", "sandstorm", "ashstorm", "firestorm", "blizzard"]:
			key = "WEATHER_FORECAST_UNKNOWN"
		_rows[index].text = Text.format_text("WEATHER_FORECAST_ROW", {
			"minutes": roundi(float(forecast.get("in_seconds", 0.0)) / 60.0),
			"condition": Text.text(key), "wind": roundi(float(forecast.get("wind_mps", 0.0)))})
	_warning.visible = storm_minutes > 0
	if _warning.visible:
		_warning.text = Text.format_text("WEATHER_STORM_APPROACHES", {"minutes": storm_minutes})
	var screen: Vector2 = Layout.screen_size(self)
	var width: float = minf(292.0 if screen.x >= 1000.0 else 280.0, screen.x - 32.0)
	var placement := Rect2(Vector2(screen.x - width - 16.0, 16.0), Vector2(width, 164.0 if _warning.visible else 143.0))
	Layout.place(_panel, avoid_tribe_controls(self, placement))


static func avoid_tribe_controls(context: Node, placement: Rect2) -> Rect2:
	# Read the existing HUD's actual bounds; its owner remains free to relayout.
	var controller: Node = context.get_tree().get_first_node_in_group(&"tribe_controller")
	if controller == null: return placement
	var canvas: Node = controller.get("panel")
	if not is_instance_valid(canvas): return placement
	var factor: float = Layout.canvas_scale(context)
	for node_name: String in ["TribalAgeEntry", "TribeResourceBar"]:
		var control := canvas.get_node_or_null(node_name) as Control
		if control == null or not control.is_visible_in_tree(): continue
		var bounds: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		bounds.position /= factor
		bounds.size /= factor
		if bounds.intersects(placement): placement.position.y = bounds.end.y + Layout.GAP
	return placement


static func _is_upcoming_storm(entry: Dictionary) -> bool:
	# Diagnostics cannot manufacture a campaign warning, even if a future
	# consumer accidentally passes their entries alongside a normal snapshot.
	if bool(entry.get("preview", false)) or entry.has("storm_preview_schema"): return false
	var horizon: float = float(entry.get("in_seconds", 0.0))
	if not is_finite(horizon) or horizon <= 0.0: return false
	var storms: Array[String] = ["sandstorm", "ashstorm", "firestorm", "blizzard"]
	return str(entry.get("condition", "")) in storms or str(entry.get("hazard_kind", "none")) in storms

func _condition_color(condition: String) -> Color:
	match condition:
		"clear": return Color("e5bd68")
		"breeze": return Color("a5c9b6")
		"overcast": return Color("849ba6")
		"drizzle": return Color("6d9dbb")
		"rain", "sleet": return Color("4882a7")
		"snow": return Color("c4d7de")
		"sandstorm", "ashstorm", "firestorm", "blizzard": return Color("e19a60")
	return Color("647985")
