extends Node

const CONFIG_PATH: String = "user://display_settings.cfg"
const BASE_VIEWPORT_SIZE := Vector2i(1920, 1080)
const InputPreferences = preload("res://core/input_preferences.gd")
var input_preferences := InputPreferences.new()
var _control_settings: VBoxContainer
var _tabs: TabContainer
var _language_settings: VBoxContainer

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
var vsync_enabled: bool = true

var _menu_layer: CanvasLayer
var _menu_panel: PanelContainer
var _mode_option: OptionButton
var _resolution_option: OptionButton
var _scale_option: OptionButton
var _vsync_option: CheckButton
var _lab_button: Button
var _message: Label
var _quit_button: Button
var _previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _previous_paused: bool = false
var _previous_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	input_preferences.load_saved()
	_load_settings()
	call_deferred("_initialize_display")


func _input(event: InputEvent) -> void:
	if get_tree().get_first_node_in_group(&"galaxy_catalog_overlay") != null:
		return
	if is_menu_open() and _control_settings.capture_input(event):
		get_viewport().set_input_as_handled()
		return
	var flow := get_node_or_null("/root/SessionFlow")
	if flow != null and bool(flow.loading):
		return
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	match key:
		KEY_ESCAPE:
			if not is_menu_open() and flow != null and bool(flow.managed) and get_tree().paused and not bool(flow.pause_open):
				return # Another modal (for example the skill tree) owns Escape.
			if not is_menu_open() and flow != null and bool(flow.can_pause()):
				flow.toggle_pause()
				get_viewport().set_input_as_handled()
				return
			# Editors keep their own Esc/back behavior. F8 remains available there.
			var scene := get_tree().current_scene
			if is_menu_open() or (scene != null and scene.scene_file_path in ["res://core/diagnostics/legacy_world.tscn", "res://world/planet_lab/planet_lab.tscn"]):
				_toggle_settings_menu()
				get_viewport().set_input_as_handled()
		KEY_F8:
			_toggle_settings_menu()
			get_viewport().set_input_as_handled()
		KEY_F4:
			var scene := get_tree().current_scene
			if scene != null and scene.has_node("DevelopmentTools"):
				get_viewport().set_input_as_handled()
				_open_planet_lab()
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
	vsync_enabled = bool(config.get_value("display", "vsync", true))


func _save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "vsync", vsync_enabled)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("Display settings could not be saved: %s" % save_error)
	return save_error == OK


func _apply_settings(save_after_apply: bool) -> bool:
	var root_window: Window = get_tree().root
	root_window.content_scale_factor = ui_scale
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

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
		return _save_settings()
	return true


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
	# This layer lives under the root Window, not under this ALWAYS autoload.
	# Its controls must explicitly keep receiving GUI input while paused.
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_menu_layer)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.025, 0.035, 0.76)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_layer.add_child(dimmer)

	_menu_panel = PanelContainer.new()
	_menu_panel.name = "DisplaySettingsPanel"
	_menu_panel.theme = preload("res://ui/frontend/menu_style.gd").theme()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_layer.add_child(center)
	center.add_child(_menu_panel)

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
	title.text = "VOXELVERSE · EINSTELLUNGEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.76, 0.94, 0.92, 1.0))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Esc / F8 Menü · F11 Vollbild"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.70, 0.72, 1.0))
	content.add_child(subtitle)
	_tabs = TabContainer.new()
	_tabs.name = "SettingsTabs"
	content.add_child(_tabs)
	var display_scroll := ScrollContainer.new()
	display_scroll.name = "Anzeige"
	display_scroll.custom_minimum_size = Vector2(600, 440)
	display_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	display_scroll.follow_focus = true
	_tabs.add_child(display_scroll)
	var display_content := VBoxContainer.new()
	display_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_content.add_theme_constant_override("separation", 14)
	display_scroll.add_child(display_content)

	_mode_option = _add_option_row(display_content, "Bildschirmmodus")
	_mode_option.name = "DisplayMode"
	_mode_option.add_item("Fenster", MODE_WINDOWED)
	_mode_option.add_item("Randloses Vollbild", MODE_BORDERLESS)
	_mode_option.add_item("Exklusives Vollbild", MODE_EXCLUSIVE_FULLSCREEN)
	_mode_option.item_selected.connect(func(_index: int): _resolution_option.disabled = _mode_option.get_selected_id() != MODE_WINDOWED)

	_resolution_option = _add_option_row(display_content, "Fensterauflösung")
	for size in RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [size.x, size.y])
		_resolution_option.set_item_metadata(
			_resolution_option.item_count - 1,
			size
		)

	_scale_option = _add_option_row(display_content, "Oberflächengröße")
	for scale_value in [0.80, 0.90, 1.00, 1.10, 1.20, 1.30]:
		_scale_option.add_item("%d%%" % roundi(float(scale_value) * 100.0))
		_scale_option.set_item_metadata(
			_scale_option.item_count - 1,
			float(scale_value)
		)

	_vsync_option = CheckButton.new()
	_vsync_option.name = "VSync"
	_vsync_option.text = "VSync – Bildrisse vermeiden"
	display_content.add_child(_vsync_option)
	_lab_button = Button.new()
	_lab_button.name = "PlanetLab"
	_lab_button.text = "Planetenlabor öffnen  ·  F4"
	_lab_button.custom_minimum_size.y = 42
	_lab_button.pressed.connect(_open_planet_lab)
	display_content.add_child(_lab_button)
	var audio_button := Button.new()
	audio_button.name = "AudioSettings"
	audio_button.text = "Ton und Musik …"
	audio_button.custom_minimum_size.y = 42
	audio_button.pressed.connect(func() -> void: get_node("/root/AudioManager").open_settings())
	display_content.add_child(audio_button)
	var control_scroll := ScrollContainer.new()
	control_scroll.name = "Steuerung"
	control_scroll.custom_minimum_size = Vector2(600, 440)
	control_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	control_scroll.follow_focus = true
	_tabs.add_child(control_scroll)
	_control_settings = preload("res://ui/frontend/controls_settings.gd").new()
	_control_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_scroll.add_child(_control_settings)
	_control_settings.setup(input_preferences)
	var language_scroll := ScrollContainer.new()
	language_scroll.name = "LANGUAGE_TAB"
	language_scroll.custom_minimum_size = Vector2(600, 440)
	language_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	language_scroll.follow_focus = true
	_tabs.add_child(language_scroll)
	_language_settings = preload("res://ui/localization/language_settings.gd").new()
	_language_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_scroll.add_child(_language_settings)
	_tabs.tab_changed.connect(func(_tab: int): _control_settings.cancel_binding())
	_message = _control_settings.message
	_message.name = "Status"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 480
	content.add_child(_message)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	content.add_child(buttons)

	var apply_button := Button.new()
	apply_button.name = "Apply"
	apply_button.text = "Übernehmen & speichern"
	apply_button.custom_minimum_size = Vector2(170.0, 40.0)
	apply_button.pressed.connect(_apply_menu_selection)
	buttons.add_child(apply_button)

	var close_button := Button.new()
	close_button.name = "Resume"
	close_button.text = "Zurück"
	close_button.custom_minimum_size = Vector2(120.0, 40.0)
	close_button.pressed.connect(_toggle_settings_menu)
	buttons.add_child(close_button)
	_quit_button = Button.new()
	_quit_button.name = "Quit"
	_quit_button.text = "Speichern & beenden"
	_quit_button.pressed.connect(_quit_game)
	content.add_child(_quit_button)

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
	if not _control_settings.listening_action.is_empty():
		_message.text = "Bitte zuerst die Tastenauswahl beenden."
		return
	var language_reason: String = _language_settings.apply()
	if not language_reason.is_empty():
		_message.text = language_reason
		return
	var reason: String = _control_settings.apply()
	if not reason.is_empty():
		_message.text = reason
		return
	if _mode_option != null:
		display_mode = _mode_option.get_selected_id()
	if _resolution_option != null:
		var selected_resolution: Variant = _resolution_option.get_selected_metadata()
		if selected_resolution is Vector2i:
			resolution = selected_resolution
	if _scale_option != null:
		ui_scale = float(_scale_option.get_selected_metadata())
	vsync_enabled = _vsync_option.button_pressed

	var saved: bool = _apply_settings(true)
	_control_settings.refresh()
	_message.text = "Einstellungen übernommen und gespeichert." if saved else "Steuerung gespeichert. Anzeige übernommen; Speichern der Anzeige fehlgeschlagen."


func _sync_menu_controls() -> void:
	if _mode_option != null:
		for index in range(_mode_option.item_count):
			if _mode_option.get_item_id(index) == display_mode:
				_mode_option.select(index)
				break

	if _resolution_option != null:
		_resolution_option.disabled = display_mode != MODE_WINDOWED
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
	if _vsync_option != null:
		_vsync_option.set_pressed_no_signal(vsync_enabled)


func _toggle_settings_menu() -> void:
	if not is_instance_valid(_menu_layer):
		return

	if not is_menu_open():
		_previous_mouse_mode = Input.mouse_mode
		_previous_paused = get_tree().paused
		_previous_focus = get_viewport().gui_get_focus_owner()
		_menu_layer.show()
		_sync_menu_controls()
		_tabs.current_tab = 0
		_control_settings.refresh()
		_language_settings.refresh()
		var scene := get_tree().current_scene
		_lab_button.visible = scene != null and scene.has_node("DevelopmentTools")
		_quit_button.visible = scene != null and (scene.has_method("save_lab") or scene.scene_file_path == "res://core/diagnostics/legacy_world.tscn")
		var flow := get_node_or_null("/root/SessionFlow")
		if flow != null and bool(flow.managed):
			_quit_button.hide()
		_message.text = input_preferences.load_message if not input_preferences.load_message.is_empty() else "Änderungen mit „Übernehmen & speichern“ aktivieren. Zurück verwirft ungespeicherte Änderungen."
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		_mode_option.grab_focus()
	else:
		close_menu()


func is_menu_open() -> bool:
	return is_instance_valid(_menu_layer) and _menu_layer.visible


func open_menu() -> void:
	if not is_menu_open():
		_toggle_settings_menu()


func close_menu() -> void:
	if not is_menu_open():
		return
	for option: OptionButton in [_mode_option, _resolution_option, _scale_option]:
		option.get_popup().hide()
	_control_settings.fps.get_popup().hide()
	_language_settings.close_popup()
	_control_settings.cancel_binding()
	_menu_layer.hide()
	get_tree().paused = _previous_paused
	Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()


func camera_motion(motion: Vector2, base_sensitivity: float) -> Vector2:
	return input_preferences.camera_motion(motion, base_sensitivity)


func _open_planet_lab() -> void:
	var scene := get_tree().current_scene
	var entry: Node = scene.get_node_or_null("DevelopmentTools") if scene != null else null
	if entry == null:
		return
	if not bool(entry.call("_open_planet_lab")):
		if not is_menu_open():
			_toggle_settings_menu()
		_message.text = "Planetenlabor nicht geöffnet: Spielstand konnte nicht gesichert oder Szene nicht geladen werden."
		return
	close_menu()
	var flow := get_node_or_null("/root/SessionFlow")
	if flow != null and bool(flow.pause_open):
		flow.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _quit_game() -> void:
	var scene := get_tree().current_scene
	var saved: bool = false
	if scene != null and scene.has_method("save_lab"):
		saved = bool(scene.call("save_lab"))
	else:
		var saves := get_node_or_null("/root/SaveGameService")
		saved = saves != null and bool(saves.call("save_now"))
	if saved:
		await preload("res://core/runtime_shutdown.gd").finish(get_tree())
	else:
		_message.text = "Speichern fehlgeschlagen. Das Spiel bleibt geöffnet."
