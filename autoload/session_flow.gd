extends Node

signal menu_error(message: String)
signal world_started

const Style = preload("res://ui/frontend/menu_style.gd")
const TITLE_SCENE: String = "res://ui/frontend/main_menu.tscn"
const WORLD_SCENE: String = "res://main/main.tscn"
var managed: bool = false
var loading: bool = false
var pause_open: bool = false
var _layer: CanvasLayer
var _overlay: Control
var _content: VBoxContainer
var _message: Label
var _loading_label: Label
var _loading_bar: ProgressBar
var _previous_mouse: int = Input.MOUSE_MODE_CAPTURED
var _previous_pause: bool = false
var _load_started: int = 0
var _loading_scene: bool = false
var _player: Node
var _player_mode: int = Node.PROCESS_MODE_INHERIT
var _resume_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_scene_changed)

func enter_frontend() -> void:
	managed = true
	var saves := get_node("/root/SaveGameService")
	saves.session_managed = true
	saves.session_active = false
	saves.autosave_enabled = false
	get_tree().auto_accept_quit = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_open = false
	loading = false
	if is_instance_valid(_layer):
		_layer.hide()

func latest_slot() -> Dictionary:
	for slot: Dictionary in get_node("/root/SaveGameService").list_slots():
		if slot.valid:
			return slot
	return {}

func new_game(title: String, seed_value: int = 0) -> void:
	if loading or not _at_title():
		return
	_show_loading("Dein Abenteuer wird vorbereitet …")
	await get_tree().process_frame
	var saves := get_node("/root/SaveGameService")
	if str(saves.create_slot(title, seed_value)).is_empty():
		_fail_loading("Neues Spiel konnte nicht gespeichert werden. " + str(saves.last_error))
		return
	await _request_world()

func load_game(path: String) -> void:
	if loading or not _at_title():
		return
	_show_loading("Spielstand wird geladen …")
	await get_tree().process_frame
	var saves := get_node("/root/SaveGameService")
	if not bool(saves.select_slot(path)):
		_fail_loading("Laden fehlgeschlagen. " + str(saves.last_error))
		return
	await _request_world()

func _request_world() -> void:
	# GameState defers its generator rebuild. Finish it before scene _ready.
	await get_tree().process_frame
	_loading_label.text = "Welt wird geladen …"
	var error: Error = ResourceLoader.load_threaded_request(WORLD_SCENE, "PackedScene")
	if error != OK:
		_fail_loading("Die Spielwelt konnte nicht geladen werden: " + error_string(error))
		return
	_loading_scene = true

func _process(_delta: float) -> void:
	if not loading:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _loading_scene:
		var progress: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(WORLD_SCENE, progress)
		if not progress.is_empty():
			_loading_bar.value = float(progress[0]) * 100.0
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading_scene = false
			_fail_loading("Die Spielwelt konnte nicht gelesen werden. Dein Spielstand bleibt erhalten.")
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			_loading_scene = false
			var scene := ResourceLoader.load_threaded_get(WORLD_SCENE) as PackedScene
			if scene == null:
				_fail_loading("Die Spielwelt ist nicht verfügbar.")
				return
			_loading_label.text = "Gelände am Startpunkt wird aufgebaut …"
			_loading_bar.hide()
			var error: Error = get_tree().change_scene_to_packed(scene)
			if error != OK:
				_fail_loading("Die Spielwelt konnte nicht geöffnet werden: " + error_string(error))
		return
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == WORLD_SCENE:
		var manager := scene.get_node_or_null("WorldManager")
		if manager != null and bool(manager.get("world_initialized")):
			_finish_loading()
		elif Time.get_ticks_msec() - _load_started > 180000:
			_fail_loading("Der Startpunkt konnte nicht aufgebaut werden. Dein Spielstand bleibt erhalten.")

func _scene_changed() -> void:
	if not managed:
		return
	var settings := get_node("/root/DisplaySettings")
	settings.close_menu()
	var scene := get_tree().current_scene
	if loading and scene != null and scene.scene_file_path == WORLD_SCENE:
		_player = get_tree().get_first_node_in_group(&"player")
		if _player != null:
			_player_mode = _player.process_mode
			_player.process_mode = Node.PROCESS_MODE_DISABLED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Editors and the lab own their scene-specific controls. They inherit the
	# selected campaign without turning the title screen into an active save.

func _finish_loading() -> void:
	loading = false
	_layer.hide()
	if is_instance_valid(_player):
		_player.process_mode = _player_mode
	_player = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var saves := get_node("/root/SaveGameService")
	saves.autosave_enabled = true
	saves.schedule_autosave(2.0)
	world_started.emit()

func _fail_loading(message: String) -> void:
	loading = false
	_loading_scene = false
	get_node("/root/SaveGameService").session_active = false
	_layer.hide()
	if not _at_title():
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE)
		await get_tree().scene_changed
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_error.emit(message)

func can_pause() -> bool:
	if not managed or loading:
		return false
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == WORLD_SCENE

func toggle_pause() -> void:
	if pause_open:
		resume()
	elif can_pause() and not get_tree().paused:
		_previous_pause = get_tree().paused
		_previous_mouse = Input.mouse_mode
		pause_open = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_pause()

func _show_pause() -> void:
	_prepare_overlay()
	Style.label(_content, "VOXELVERSE", 37, Style.ACCENT)
	Style.label(_content, "Eine kurze Pause.", 26)
	Style.paragraph(_content, get_node("/root/SaveGameService").slot_name, 19)
	_resume_focus = Style.button(_content, "Weiterspielen", resume, "ResumeGame", true)
	Style.button(_content, "Spiel speichern", _save, "SaveGame")
	Style.button(_content, "Einstellungen", func(): get_node("/root/DisplaySettings").open_menu(), "PauseSettings")
	Style.button(_content, "Steuerung", _show_help, "PauseControls")
	Style.button(_content, "Speichern & zum Hauptmenü", return_to_title, "ReturnToTitle")
	Style.button(_content, "Speichern & beenden", request_quit, "QuitGame")
	_message = Style.paragraph(_content, "", 18)
	_resume_focus.grab_focus()

func _show_help() -> void:
	_prepare_overlay()
	Style.label(_content, "STEUERUNG", 32, Style.ACCENT)
	Style.paragraph(_content, controls_text(), 22)
	var back := Style.button(_content, "Zurück zur Pause", _show_pause, "BackToPause")
	back.grab_focus()

func resume() -> void:
	if not pause_open:
		return
	get_node("/root/DisplaySettings").close_menu()
	pause_open = false
	_layer.hide()
	get_tree().paused = _previous_pause
	Input.mouse_mode = _previous_mouse

func _save() -> bool:
	var saved: bool = bool(get_node("/root/SaveGameService").save_now())
	if is_instance_valid(_message):
		_message.text = "Spielstand gespeichert." if saved else "Speichern fehlgeschlagen. Dein Spiel bleibt geöffnet."
	return saved

func return_to_title() -> void:
	if loading or not _save():
		return
	get_node("/root/DisplaySettings").close_menu()
	get_node("/root/SaveGameService").session_active = false
	pause_open = false
	_layer.hide()
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(TITLE_SCENE)
	if error != OK:
		get_node("/root/SaveGameService").session_active = true
		toggle_pause()
		_message.text = "Das Hauptmenü konnte nicht geöffnet werden."

func request_quit() -> void:
	if loading:
		return
	if _at_title():
		get_tree().quit()
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("save_lab"):
		if bool(scene.call("save_lab")):
			get_tree().quit()
		return
	if can_pause():
		if not pause_open:
			toggle_pause()
		if _save():
			get_tree().quit()
		return
	# An editor can hold an unsaved working blueprint. Let its own Back/Save
	# action finish the edit before a window-close discards the scene.
	get_node("/root/DisplaySettings").open_menu()
	get_node("/root/DisplaySettings")._message.text = "Bitte den Entwurf im Editor speichern und zum Spiel zurückkehren."

func _notification(what: int) -> void:
	if managed and what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

func _input(event: InputEvent) -> void:
	# During loading, no hotkey may open an editor, save, or move the player.
	if loading:
		get_viewport().set_input_as_handled()

func _at_title() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == TITLE_SCENE

func _show_loading(text: String) -> void:
	loading = true
	_load_started = Time.get_ticks_msec()
	_prepare_overlay()
	Style.label(_content, "VOXELVERSE", 37, Style.ACCENT)
	_loading_label = Style.paragraph(_content, text, 25)
	_loading_bar = ProgressBar.new()
	_loading_bar.show_percentage = false
	_loading_bar.custom_minimum_size.y = 8
	_content.add_child(_loading_bar)
	Style.paragraph(_content, "Deine Welt entsteht Schritt für Schritt.\nMit Esc erreichst du im Spiel jederzeit das Pausemenü.", 19)

func _prepare_overlay() -> void:
	if not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.name = "SessionMenu"
		_layer.layer = 80
		_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_layer)
		_overlay = Control.new()
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_overlay.theme = Style.theme()
		_layer.add_child(_overlay)
	for child in _overlay.get_children():
		_overlay.remove_child(child)
		child.queue_free()
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.025, 0.07, 0.085, 0.96 if loading else 0.9)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 600
	center.add_child(panel)
	_content = VBoxContainer.new()
	panel.add_child(_content)
	_layer.show()

func controls_text() -> String:
	var preferences = preload("res://core/input_preferences.gd")
	return "%s / %s / %s / %s   Bewegen\nMaus   Umschauen\n%s   Springen / im Wasser steigen\n%s   Untersuchungsmodus\n%s   Interagieren / essen / trinken\n%s   Beißen\nF2   Kreatureneditor\nEsc   Pause / zurück\nF8   Einstellungen\nF11   Vollbild umschalten\n\nF4   Planetenlabor\nIm Labor: Tab Orbit · M Körper · B Sonnen" % [
		preferences.binding_label("move_forward"), preferences.binding_label("move_back"),
		preferences.binding_label("move_left"), preferences.binding_label("move_right"),
		preferences.binding_label("jump"), preferences.binding_label("inspection_mode"),
		preferences.binding_label("primary_action"), preferences.binding_label("bite_action")]
