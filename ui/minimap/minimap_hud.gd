extends CanvasLayer
## One HUD for all phases and surface modes. Source adapters provide addresses;
## profile chooses range; the projection/raster and controls are shared.
const Profile = preload("res://core/map/minimap_profile.gd")
const MapProjection = preload("res://core/map/surface_map_projection.gd")
const Terrain = preload("res://ui/minimap/minimap_terrain.gd")
const Source = preload("res://ui/minimap/minimap_source.gd")
const MapCanvas = preload("res://ui/minimap/minimap_canvas.gd")
const Layout = preload("res://ui/hud_layout.gd")
const Style = preload("res://ui/progression_style.gd")
var atlas_window: CanvasLayer
var _atlas_button: Button
var player: Node3D
var lab: Node3D
var snapshot_provider: Callable
var projection := MapProjection.new()
var terrain := Terrain.new()
var zoom_index: int = 1
var phase: int = -1
var range_m: float = 64.0
var _snapshot: Dictionary = {}
var _context_id: String = ""
var _timer: float = 0.0
var _sample_address: Callable
var _panel: PanelContainer
var _map: Control
var _title: Label
var _scale_label: Label
var _status: Label
var _minus: Button
var _plus: Button
var _reset: Button
var _camera_controls: HBoxContainer
var _pending_reset: bool = true
var _physical_size := Vector2.ZERO

func _ready() -> void:
	name = "MinimapHUD"
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"minimap_hud")
	_build()
	atlas_window = preload("res://ui/world_map/world_map_panel.gd").new()
	atlas_window.player = player
	atlas_window.lab = lab
	add_child(atlas_window)
	var state := get_node("/root/GameState")
	state.phase_changed.connect(invalidate)
	state.world_seed_changed.connect(invalidate)
	get_node("/root/SaveGameService").game_loaded.connect(invalidate)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_snapshot()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "MinimapPanel"
	_panel.add_theme_stylebox_override("panel", Style.box(Color(0.035, 0.07, 0.10, 0.94), Color("365363"), 9))
	add_child(_panel)
	var column := Style.column(_panel, 5)
	_title = Style.label("Umgebung", 14, Style.SOCIAL)
	column.add_child(_title)
	_map = MapCanvas.new()
	_map.name = "TerrainMap"
	_map.terrain = terrain
	_map.heading_requested.connect(_face_heading)
	column.add_child(_map)
	_camera_controls = HBoxContainer.new()
	_camera_controls.name = "TribeMapCameraControls"
	_camera_controls.add_theme_constant_override("separation", 4)
	column.add_child(_camera_controls)
	for item: Dictionary in [
		{"icon": "⌖", "key": "TRIBE_MAP_CENTER", "yaw": 0.0, "tilt": 0.0, "center": true},
		{"icon": "↶", "key": "TRIBE_MAP_TURN_LEFT", "yaw": -15.0, "tilt": 0.0},
		{"icon": "↷", "key": "TRIBE_MAP_TURN_RIGHT", "yaw": 15.0, "tilt": 0.0},
		{"icon": "↘", "key": "TRIBE_MAP_TILT_LOW", "yaw": 0.0, "tilt": -10.0},
		{"icon": "↗", "key": "TRIBE_MAP_TILT_HIGH", "yaw": 0.0, "tilt": 10.0}]:
		var button := _button(item.icon, _camera_action.bind(item))
		button.name = item.key
		button.tooltip_text = item.key
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camera_controls.add_child(button)
	_camera_controls.hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	column.add_child(row)
	_minus = _button("−", func() -> void: change_zoom(1))
	_minus.name = "MapZoomOut"
	_minus.tooltip_text = "Weiter herauszoomen · Taste −"
	row.add_child(_minus)
	_scale_label = Style.label("", 12)
	_scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_scale_label)
	_plus = _button("+", func() -> void: change_zoom(-1))
	_plus.name = "MapZoomIn"
	_plus.tooltip_text = "Näher heranzoomen · Taste +"
	row.add_child(_plus)
	_reset = _button("↺", func() -> void: zoom_index = 1; _refresh_range())
	_reset.name = "MapPhaseScale"
	_reset.tooltip_text = "Zum Maßstab dieses Zeitalters zurückkehren"
	row.add_child(_reset)
	_status = Style.label("", 11, Style.MUTED)
	_status.hide()
	column.add_child(_status)
	_atlas_button = _button("HUD_MAP", func() -> void: atlas_window.open_map())
	_atlas_button.custom_minimum_size.y = 30
	_atlas_button.add_theme_font_size_override("font_size", 13)
	_atlas_button.name = "OpenWorldMap"
	column.add_child(_atlas_button)

func _button(text: String, action: Callable) -> Button:
	var button := Style.button(text)
	button.custom_minimum_size = Vector2(29, 28)
	button.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, Style.box(Color("213743"), Color("436070"), 3))
	button.pressed.connect(action)
	return button

func _tribe_rig() -> RefCounted:
	var tribe: Node = get_tree().get_first_node_in_group(&"tribe_controller")
	return tribe.camera_rig if tribe != null and tribe.is_active() else null

func _camera_action(item: Dictionary) -> void:
	var rig: RefCounted = _tribe_rig()
	if rig == null or get_tree().paused: return
	if item.get("center", false): rig.focus_home()
	else: rig.adjust_view(float(item.yaw), float(item.tilt))
	_update_snapshot()

func _face_heading(requested: Vector2) -> void:
	var rig: RefCounted = _tribe_rig()
	if rig == null or get_tree().paused: return
	rig.face_map_heading(requested, _map.direction)
	_update_snapshot()

func invalidate(_value: Variant = null) -> void:
	_pending_reset = true
	zoom_index = 1
	_timer = 0.0
	# Never display the old world's pixels until the next source refresh.
	terrain.reset()
	_map.markers.clear()
	_map.queue_redraw()

func _process(delta: float) -> void:
	if get_tree().paused:
		hide()
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.12
		_update_snapshot()
	if not visible: return
	terrain.step_work()
	_map.tooltip_text = (tr("TRIBE_MAP_HEADING") if _camera_controls.visible else tr("HUD_MAP_HELP")) + "\n" + tr("HUD_MAP_SCALE") % Profile.distance_text(range_m * 0.5)
	_map.queue_redraw()

func _update_snapshot() -> void:
	if get_tree().paused: hide(); return
	var data: Dictionary = snapshot_provider.call() if snapshot_provider.is_valid() else (Source.laboratory_snapshot(lab) if is_instance_valid(lab) else Source.campaign_snapshot(player, get_tree()))
	var address: Dictionary = data.get("address", {})
	if not MapProjection.valid(address) or not data.get("sample", Callable()).is_valid():
		hide()
		return
	show()
	_atlas_button.text = tr("HUD_MAP") + " · " + atlas_window.shortcut_text()
	var new_context: String = str(data.get("context_id", "")) + ":" + str(address["body_id"]) + ":" + str(address["mode"])
	var new_phase: int = int(data.get("phase", 0))
	var body_radius: float = float(data.get("body_radius", 0.0))
	var offset: Vector2 = projection.project(address) if not projection.origin.is_empty() else Vector2(INF, INF)
	var relocate: bool = offset.length() > maxf(range_m * 4.0, 1000.0)
	if _pending_reset or new_context != _context_id or relocate:
		if not projection.configure(address, body_radius): hide(); return
		_context_id = new_context
		terrain.reset()
		_pending_reset = false
	_snapshot = data
	_sample_address = data["sample"]
	if new_phase != phase:
		phase = new_phase
		zoom_index = 1
	_refresh_range()
	_map.position_m = projection.project(address)
	_map.direction = projection.heading(data.get("forward", Vector3.FORWARD))
	_map.group_view = bool(data.get("group_view", false))
	_camera_controls.visible = _map.group_view and _tribe_rig() != null
	_map.markers.clear()
	for marker: Dictionary in data.get("markers", []):
		if _map.markers.size() >= 64: break
		var point: Vector2 = projection.project(marker.get("address", {}))
		if not point.is_finite(): continue
		var item: Dictionary = marker.duplicate()
		item["position"] = point
		_map.markers.append(item)
	_layout()

func _refresh_range() -> void:
	if _snapshot.is_empty(): return
	var profile: Dictionary = Profile.for_phase(phase, zoom_index, float(_snapshot.get("body_radius", 0.0)))
	range_m = profile["radius_m"]
	_title.text = tr(profile["name"])
	_scale_label.text = Profile.distance_text(range_m * 2.0)
	_scale_label.tooltip_text = "Gesamte Kartenbreite"
	_minus.disabled = zoom_index >= Profile.ZOOMS.size() - 1
	_plus.disabled = zoom_index <= 0
	_reset.disabled = zoom_index == 1
	terrain.request(projection.project(_snapshot["address"]), range_m, _sample_pixel)
	_map.queue_redraw()

func _sample_pixel(offset: Vector2) -> Color:
	return _sample_address.call(projection.address_at(offset))

func change_zoom(change: int) -> void:
	if not visible or get_tree().paused: return
	zoom_index = clampi(zoom_index + change, 0, Profile.ZOOMS.size() - 1)
	_refresh_range()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or get_tree().paused or not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
		change_zoom(-1)
	elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		change_zoom(1)
	else: return
	get_viewport().set_input_as_handled()

func reserved_width() -> float:
	# Physical pixels, shared with the tribe panel's existing scale convention.
	return _physical_size.x + 12.0

func _layout() -> void:
	if _panel == null: return
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var scale_factor: float = logical.x / maxf(float(get_window().size.x), 1.0)
	transform = Transform2D(0.0, Vector2.ONE * scale_factor, 0.0, Vector2.ZERO)
	var pixels: Vector2 = logical / scale_factor
	var width: float = Layout.dock_width(self)
	# Leave room below the tribe entry on short windows. MapCanvas preserves metres/aspect.
	_map.custom_minimum_size = Vector2(width - 18, width - (42 if pixels.y < 680 else 18))
	_panel.size = Vector2(width, 0)
	_physical_size = _panel.get_combined_minimum_size()
	var bottom: float = Layout.MARGIN
	if is_instance_valid(player):
		var presentation := player.get_node_or_null("HUDPresentation")
		if presentation != null and presentation.has_method("vitals_reserved_height"):
			bottom += presentation.vitals_reserved_height()
	if is_instance_valid(lab):
		var blocker: Control = lab.find_child("PlanetLabBottom", true, false)
		if blocker != null: bottom = pixels.y - blocker.get_global_rect().position.y / scale_factor + 12.0
	_panel.position = Vector2(pixels.x - _physical_size.x - 16, maxf(12, pixels.y - _physical_size.y - bottom))
