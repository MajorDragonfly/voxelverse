extends Node

const CONFIG_PATH: String = "user://display_settings.cfg"
const BASE_VIEWPORT_SIZE := Vector2i(1920, 1080)

const MODE_WINDOWED: int = 0
const MODE_BORDERLESS: int = 1
const MODE_EXCLUSIVE_FULLSCREEN: int = 2

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

var display_mode: int = MODE_BORDERLESS
var resolution: Vector2i = Vector2i(1600, 900)
var ui_scale: float = 1.0

var _menu_layer: CanvasLayer
var _menu_panel: PanelContainer
var _mode_option: OptionButton
var _resolution_option: OptionButton
var _scale_option: OptionButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	call_deferred("_initialize_display")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_F8:
			_toggle_settings_menu()
			get_viewport().set_input_as_handled()
		KEY_F10:
			display_mode = (display_mode + 1) % 3
			_apply_settings(true)
			get_viewport().set_input_as_handled()
		KEY_F11:
			if display_mode == MODE_WINDOWED:
				display_mode = MODE_BORDERLESS
			else:
				display_mode = MODE_WINDOWED
			_apply_settings(true)
			get_viewport().set_input_as_handled()


func _initialize_display() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root_window.content_scale_size = BASE_VIEWPORT_SIZE
	_build_settings_menu()
	_apply_settings(false)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var load_error: Error = config.load(CONFIG_PATH)
	if load_error != OK:
		return

	display_mode = clampi(
		int(config.get_value("display", "mode", MODE_BORDERLESS)),
		MODE_WINDOWED,
		MODE_EXCLUSIVE_FULLSCREEN
	)
	resolution = Vector2i(
		int(config.get_value("display", "width", 1600)),
		int(config.get_value("display", "height", 900))
	)
	ui_scale = clampf(
		float(config.get_value("display", "ui_scale", 1.0)),
		0.75,
		1.35
	)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("display", "ui_scale", ui_scale)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("Display settings could not be saved: %s" % save_error)


func _apply_settings(save_after_apply: bool) -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_factor = ui_scale

	match display_mode:
		MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(resolution)
			_center_window(resolution)
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	_sync_menu_controls()
	if save_after_apply:
		_save_settings()


func _center_window(window_size: Vector2i) -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var target_position: Vector2i = (screen_size - window_size) / 2
	DisplayServer.window_set_position(target_position)


func _build_settings_menu() -> void:
	if is_instance_valid(_menu_layer):
		return

	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "DisplaySettingsLayer"
	_menu_layer.layer = 90
	get_tree().root.add_child(_menu_layer)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.025, 0.035, 0.76)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_layer.add_child(dimmer)

	_menu_panel = PanelContainer.new()
	_menu_panel.name = "DisplaySettingsPanel"
	_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	_menu_panel.offset_left = -280.0
	_menu_panel.offset_top = -220.0
	_menu_panel.offset_right = 280.0
	_menu_panel.offset_bottom = 220.0
	_menu_layer.add_child(_menu_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.070, 0.085, 0.98)
	panel_style.border_color = Color(0.22, 0.58, 0.62, 0.90)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 26.0
	panel_style.content_margin_right = 26.0
	panel_style.content_margin_top = 22.0
	panel_style.content_margin_bottom = 22.0
	_menu_panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_menu_panel.add_child(content)

	var title := Label.new()
	title.text = "VOXELVERSE · DISPLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.76, 0.94, 0.92, 1.0))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "F8 menu · F10 cycle mode · F11 quick fullscreen"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.70, 0.72, 1.0))
	content.add_child(subtitle)

	_mode_option = _add_option_row(content, "Display mode")
	_mode_option.add_item("Windowed", MODE_WINDOWED)
	_mode_option.add_item("Borderless fullscreen", MODE_BORDERLESS)
	_mode_option.add_item("Exclusive fullscreen", MODE_EXCLUSIVE_FULLSCREEN)

	_resolution_option = _add_option_row(content, "Window resolution")
	for size in RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [size.x, size.y])
		_resolution_option.set_item_metadata(
			_resolution_option.item_count - 1,
			size
		)

	_scale_option = _add_option_row(content, "Interface scale")
	for scale_value in [0.80, 0.90, 1.00, 1.10, 1.20, 1.30]:
		_scale_option.add_item("%d%%" % roundi(float(scale_value) * 100.0))
		_scale_option.set_item_metadata(
			_scale_option.item_count - 1,
			float(scale_value)
		)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	content.add_child(buttons)

	var apply_button := Button.new()
	apply_button.text = "Apply and save"
	apply_button.custom_minimum_size = Vector2(170.0, 40.0)
	apply_button.pressed.connect(_apply_menu_selection)
	buttons.add_child(apply_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120.0, 40.0)
	close_button.pressed.connect(_toggle_settings_menu)
	buttons.add_child(close_button)

	_menu_layer.visible = false
	_sync_menu_controls()


func _add_option_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190.0, 36.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(290.0, 36.0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	return option


func _apply_menu_selection() -> void:
	if _mode_option != null:
		display_mode = _mode_option.get_selected_id()
	if _resolution_option != null:
		var selected_resolution: Variant = _resolution_option.get_selected_metadata()
		if selected_resolution is Vector2i:
			resolution = selected_resolution
	if _scale_option != null:
		ui_scale = float(_scale_option.get_selected_metadata())

	_apply_settings(true)


func _sync_menu_controls() -> void:
	if _mode_option != null:
		for index in range(_mode_option.item_count):
			if _mode_option.get_item_id(index) == display_mode:
				_mode_option.select(index)
				break

	if _resolution_option != null:
		for index in range(_resolution_option.item_count):
			if _resolution_option.get_item_metadata(index) == resolution:
				_resolution_option.select(index)
				break

	if _scale_option != null:
		var closest_index: int = 0
		var closest_distance: float = INF
		for index in range(_scale_option.item_count):
			var value: float = float(_scale_option.get_item_metadata(index))
			var distance: float = absf(value - ui_scale)
			if distance < closest_distance:
				closest_distance = distance
				closest_index = index
		_scale_option.select(closest_index)


func _toggle_settings_menu() -> void:
	if not is_instance_valid(_menu_layer):
		return

	_menu_layer.visible = not _menu_layer.visible
	if _menu_layer.visible:
		_sync_menu_controls()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
