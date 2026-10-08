extends CanvasLayer
const Design = preload("res://ui/design/design_system.gd")
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
var _exposure: Label
var _rows: Array[Label] = []
var _scroll: ScrollContainer
var _content: VBoxContainer
var _forecast: Array[Dictionary] = []
var _snapshot: Dictionary = {}
var _player: Node


func _ready() -> void:
	add_to_group(&"weather_forecast_hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 29
	_panel = PanelContainer.new()
	_panel.name = "ForecastPanel"
	_panel.theme = Design.theme()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Design.INK, 0.94)
	style.border_color = Design.EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(9)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.name = "ForecastScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_scroll)
	var column := VBoxContainer.new()
	_content = column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	_scroll.add_child(column)
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", Design.ACCENT)
	column.add_child(_title)
	_day = Label.new()
	_day.name = "DayClock"
	_day.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day.add_theme_font_size_override("font_size", 14)
	_day.add_theme_color_override("font_color", Design.TEXT)
	column.add_child(_day)
	_day_bar = ProgressBar.new()
	_day_bar.name = "DayProgress"
	_day_bar.show_percentage = false
	_day_bar.step = 0.0
	_day_bar.custom_minimum_size.y = 9
	_day_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var night := StyleBoxFlat.new()
	night.bg_color = Design.INK
	_day_bar.add_theme_stylebox_override("background", night)
	var daylight := StyleBoxFlat.new()
	daylight.bg_color = Design.ACCENT
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
	_warning.add_theme_color_override("font_color", Design.AGGRESSION)
	column.add_child(_warning)
	_exposure = Label.new()
	_exposure.name = "ExtremeExposure"
	_exposure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_exposure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exposure.add_theme_font_size_override("font_size", 14)
	_exposure.add_theme_color_override("font_color", Design.AGGRESSION)
	column.add_child(_exposure)
	for index in range(3):
		var row := Label.new()
		row.name = "Forecast%d" % (index + 1)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_font_size_override("font_size", 14)
		row.add_theme_color_override("font_color", Design.TEXT)
		column.add_child(row)
		_rows.append(row)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var regular: bool = _snapshot.get("normal_storm_schema") == 1
	if regular and bool(_snapshot.get("storm_warning", false)):
		storm_minutes = maxi(1, ceili(float(_snapshot.get("storm_start_in_seconds", 0.0)) / 60.0))
	for index in range(3):
		var forecast: Dictionary = _forecast[index]
		var condition: String = str(forecast.get("condition", ""))
		_segments[index + 1].color = _condition_color(condition)
		if not regular and storm_minutes == 0 and _is_upcoming_storm(forecast):
			storm_minutes = roundi(float(forecast.get("in_seconds", 0.0)) / 60.0)
		var key: String = "WEATHER_FORECAST_" + condition.to_upper()
		# Central catalogue append is delivered to R32-01 separately. Until that
		# patch lands, reuse the existing translated rain label, never a raw key.
		if condition == "rainstorm" and Text.text(key) == key: key = "WEATHER_FORECAST_RAIN"
		if condition not in ["clear", "breeze", "overcast", "drizzle", "rain", "rainstorm", "snow", "sleet", "sandstorm", "ashstorm", "firestorm", "blizzard"]:
			key = "WEATHER_FORECAST_UNKNOWN"
		_rows[index].text = Text.format_text("WEATHER_FORECAST_ROW", {
			"minutes": roundi(float(forecast.get("in_seconds", 0.0)) / 60.0),
			"condition": Text.text(key), "wind": roundi(float(forecast.get("wind_mps", 0.0)))})
	_warning.visible = storm_minutes > 0
	if _warning.visible:
		_warning.text = Text.format_text("WEATHER_STORM_APPROACHES", {"minutes": storm_minutes})
	_exposure.visible = _snapshot.get("extreme_storm_schema") == 1 and float(_snapshot.get("hazard_intensity", 0.0)) >= 0.25
	if _exposure.visible:
		var actual: Dictionary = _snapshot.get("exposure_result", {})
		var key: String = "WEATHER_EXTREME_PROTECTED" if bool(actual.get("protected", false)) else "WEATHER_EXTREME_EXPOSED"
		var tribe: Node = get_tree().get_first_node_in_group(&"tribe_controller")
		if tribe != null and tribe.is_active(): key = "WEATHER_EXTREME_WORK"
		_exposure.text = Text.text(key)
		if _exposure.text == key: _exposure.text = Text.text("WEATHER_FORECAST_SANDSTORM") + " · " + Text.text("WEATHER_STORM_PHASE_" + str(_snapshot.storm_phase).to_upper())
	var screen: Vector2 = Layout.screen_size(self)
	# The full-width rows keep their enlarged font in a short window too.
	var width: float = minf(292.0, screen.x - 32.0)
	var placement := Rect2(Vector2(screen.x - width - 16.0, 16.0), Vector2(width, 164.0 if _warning.visible else 143.0))
	Layout.scale_fonts(_panel, Layout.text_scale(self))
	placement = avoid_tribe_controls(self, placement)
	# The scroll viewport owns the finite right-hand stack. Long translated
	# warning/exposure text stays reachable without moving behind village orders.
	Layout.place(_panel, placement)
	var chrome: float = _panel.get_theme_stylebox("panel").get_minimum_size().y
	var natural_height: float = maxf(placement.size.y, _content.get_combined_minimum_size().y + chrome)
	var panel_minimum: float = _panel.get_combined_minimum_size().y
	var whole_control: float = 0.0
	for control: Control in _content.get_children():
		if control.is_visible_in_tree(): whole_control = maxf(whole_control, control.get_combined_minimum_size().y)
	var useful_height: float = maxf(panel_minimum, whole_control + chrome)
	var bottom: float = Layout.bottom_dock_y(self, placement, screen.y - Layout.MARGIN)
	var minimap: Node = get_tree().get_first_node_in_group(&"minimap_hud")
	if minimap != null:
		bottom = minf(bottom, minimap.dock_bottom() - minimap.minimum_dock_height() - Layout.GAP)
		# Before village activation the age entry can consume the right stack.
		# Use the left lane only when its measured, unobstructed viewport can
		# show a whole control and offers more space than the right lane.
		if bottom - placement.position.y < useful_height:
			var candidate := placement
			candidate.position.x = maxf(Layout.MARGIN, screen.x - Layout.dock_width(self) - width - 2.0 * Layout.MARGIN - Layout.GAP)
			candidate.position.y = Layout.MARGIN
			candidate = avoid_tribe_controls(self, candidate)
			var candidate_bottom: float = Layout.bottom_dock_y(self, candidate, screen.y - Layout.MARGIN)
			if candidate_bottom - candidate.position.y >= useful_height and candidate_bottom - candidate.position.y > bottom - placement.position.y:
				placement = candidate
				bottom = candidate_bottom
	placement.size.y = minf(natural_height, maxf(panel_minimum, bottom - placement.position.y))
	Layout.place(_panel, placement)

func hud_reserved_rect() -> Rect2:
	return Layout.physical_rect(_panel) if is_instance_valid(_panel) and _panel.is_visible_in_tree() else Rect2()


static func avoid_tribe_controls(context: Node, placement: Rect2) -> Rect2:
	placement.position.y = Layout.top_dock_y(context, placement)
	return placement


static func _is_upcoming_storm(entry: Dictionary) -> bool:
	# Diagnostics cannot manufacture a campaign warning, even if a future
	# consumer accidentally passes their entries alongside a normal snapshot.
	if bool(entry.get("preview", false)) or entry.has("storm_preview_schema"): return false
	var horizon: float = float(entry.get("in_seconds", 0.0))
	if not is_finite(horizon) or horizon <= 0.0: return false
	if entry.get("normal_storm_schema") == 1:
		return entry.get("storm_kind") in ["rainstorm", "sandstorm"] and not str(entry.get("storm_event_id", "")).is_empty() \
			and entry.get("storm_phase") in ["rising", "peak"] and float(entry.get("storm_intensity", 0.0)) >= 0.25
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
		"rainstorm", "sandstorm", "ashstorm", "firestorm", "blizzard": return Color("e19a60")
	return Color("647985")
