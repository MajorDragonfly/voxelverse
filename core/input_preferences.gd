extends RefCounted

const Text = preload("res://core/localization/ui_text.gd")
signal bindings_changed

## Local comfort settings, independent of campaigns and creature statistics.
const CONFIG_PATH := "user://input_preferences.cfg"
const ACTIONS := {
	"move_forward": "Vorwärts", "move_back": "Rückwärts",
	"move_left": "Nach links", "move_right": "Nach rechts",
	"jump": "Springen / aufsteigen", "primary_action": "Interagieren",
	"bite_action": "Beißen", "inspection_mode": "Untersuchen",
	"open_journal": "BIND_JOURNAL", "open_development": "BIND_DEVELOPMENT",
	"open_world_map": "BIND_WORLD_MAP",
	"tribe_turn_left": "TRIBE_CAMERA_LEFT", "tribe_turn_right": "TRIBE_CAMERA_RIGHT",
	"tribe_tilt_up": "TRIBE_CAMERA_UP", "tribe_tilt_down": "TRIBE_CAMERA_DOWN",
	"tribe_focus_home": "TRIBE_CAMERA_HOME", "tribe_focus_selection": "TRIBE_CAMERA_SELECTION",
	"tribe_orbit": "TRIBE_CAMERA_ORBIT",
}
const CAMERA_DEFAULTS := {"tribe_turn_left": KEY_LEFT, "tribe_turn_right": KEY_RIGHT,
	"tribe_tilt_up": KEY_PAGEUP, "tribe_tilt_down": KEY_PAGEDOWN,
	"tribe_focus_home": KEY_HOME, "tribe_focus_selection": KEY_END, "tribe_orbit": -3}
const TRIBE_CAMERA_DEFAULTS := {"pan_speed": 1.0, "tilt": 55.0}
var tribe_camera: Dictionary = TRIBE_CAMERA_DEFAULTS.duplicate()
const MENU_ACTIONS := ["open_journal", "open_development", "open_world_map"]
const FIXED_PLAY_KEYS := [KEY_F, KEY_H, KEY_N, KEY_P]
const FPS_OPTIONS := [0, 30, 60, 90, 120, 144, 165, 240]
var bindings: Dictionary = {}
var sensitivity: float = 1.0
var invert_y: bool = false
var fps_limit: int = 0
var load_message: String = ""

func _init() -> void:
	bindings = defaults()

static func defaults() -> Dictionary:
	var result := {}
	for action: String in ACTIONS:
		if action in CAMERA_DEFAULTS:
			result[action] = [CAMERA_DEFAULTS[action], 0]
			continue
		var codes: Array = []
		for event: InputEvent in ProjectSettings.get_setting("input/" + action, {}).get("events", []):
			var code: int = event_code(event)
			if code != 0 and codes.size() < 2:
				codes.append(code)
		while codes.size() < 2:
			codes.append(0)
		result[action] = codes
	return result

static func event_code(event: InputEvent) -> int:
	if event is InputEventKey:
		return int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event is InputEventMouseButton:
		return -int(event.button_index)
	return 0

static func code_label(code: int) -> String:
	match code:
		0: return "—"
		-1: return Text.text("Linksklick")
		-2: return Text.text("Rechtsklick")
		-3: return Text.text("Mittelklick")
		-8: return Text.text("Maustaste 4")
		-9: return Text.text("Maustaste 5")
		KEY_SPACE: return Text.text("Leertaste")
		KEY_UP: return Text.text("Pfeil ↑")
		KEY_DOWN: return Text.text("Pfeil ↓")
		KEY_LEFT: return Text.text("Pfeil ←")
		KEY_RIGHT: return Text.text("Pfeil →")
	var logical: int = code if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	return OS.get_keycode_string((logical if logical != 0 else code) as Key)

static func binding_label(action: String) -> String:
	var names: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		var code: int = event_code(event)
		if code != 0:
			names.append(code_label(code))
	return " / ".join(names)

static func menu_event(event: InputEvent, action: String) -> bool:
	if not event is InputEventKey or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
		return false
	for binding: InputEvent in InputMap.action_get_events(action):
		if event_code(binding) == event_code(event): return true
	return false

static func hint(key: String, values: Dictionary = {}) -> String:
	var arguments := values.duplicate()
	for name: String in ["journal", "development", "world_map"]:
		arguments[name] = binding_label("open_" + name)
	return Text.format_text(key, arguments)

static func reserved_reason(code: int) -> String:
	if code in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB] or (code >= KEY_F1 and code <= KEY_F35):
		return "Diese Taste bleibt für Menüs und Spieloberflächen reserviert."
	if code == 0 or code in [-1, -2, -3, -8, -9]:
		return ""
	if (code >= KEY_SPACE and code <= KEY_ASCIITILDE) or code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_INSERT]:
		return ""
	return "Bitte eine Buchstaben-, Zahlen-, Pfeil- oder Maustaste wählen."

static func validate(candidate: Dictionary) -> String:
	var occupied := {}
	for action: String in ACTIONS:
		var codes: Variant = candidate.get(action)
		if not codes is Array or codes.size() != 2:
			return "Unvollständige Tastenbelegung."
		var count: int = 0
		for code: Variant in codes:
			if not code is int:
				return "Ungültige Tastenbelegung."
			var reason := reserved_reason(code)
			if not reason.is_empty():
				return reason
			if code == 0:
				continue
			if action in MENU_ACTIONS:
				if code in FIXED_PLAY_KEYS:
					return Text.text("BIND_FIXED_PLAY_KEY")
				if not ((code >= KEY_A and code <= KEY_Z) or (code >= KEY_0 and code <= KEY_9)):
					return Text.text("BIND_MENU_KEY_REQUIRED")
			if occupied.has(code):
				return Text.format_text("BIND_CONFLICT", {"key": code_label(code), "action": Text.text(ACTIONS[occupied[code]])})
			occupied[code] = action
			count += 1
		if count == 0:
			return Text.format_text("BIND_REQUIRED", {"action": Text.text(ACTIONS[action])})
	return ""

func load_saved(path: String = CONFIG_PATH) -> void:
	bindings = defaults()
	sensitivity = 1.0
	invert_y = false
	fps_limit = 0
	load_message = ""
	tribe_camera = TRIBE_CAMERA_DEFAULTS.duplicate()
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		apply_runtime()
		return
	if error != OK:
		load_message = "Steuerungsdatei nicht lesbar; Standardwerte sind aktiv."
		apply_runtime()
		return
	var candidate := defaults()
	for action: String in ACTIONS:
		candidate[action] = config.get_value("bindings", action, candidate[action])
	# Older profiles have no menu actions. Preserve every existing game binding,
	# including M, and add only missing menu bindings using unoccupied keys.
	var occupied := {}
	for action: String in ACTIONS:
		if (action in MENU_ACTIONS or action in CAMERA_DEFAULTS) and not config.has_section_key("bindings", action): continue
		if candidate[action] is Array:
			for code: Variant in candidate[action]:
				if code is int and code != 0: occupied[code] = true
	var adjusted: bool = false
	for action: String in MENU_ACTIONS + CAMERA_DEFAULTS.keys():
		if config.has_section_key("bindings", action): continue
		var preferred: int = candidate[action][0]
		var choices: Array = [preferred] + range(KEY_A, KEY_Z + 1) + range(KEY_0, KEY_9 + 1)
		for code: int in choices:
			if occupied.has(code) or code in FIXED_PLAY_KEYS: continue
			candidate[action] = [code, 0]
			occupied[code] = true
			adjusted = adjusted or code != preferred
			break
	if validate(candidate).is_empty():
		bindings = candidate
		if adjusted: load_message = Text.text("BIND_MENUS_ADDED")
	else:
		load_message = "Ungültige Tastenbelegung; Standardtasten sind aktiv."
	var speed: Variant = config.get_value("camera", "sensitivity", 1.0)
	if (speed is float or speed is int) and is_finite(float(speed)):
		sensitivity = clampf(float(speed), 0.2, 3.0)
	var inverted: Variant = config.get_value("camera", "invert_y", false)
	invert_y = inverted if inverted is bool else false
	var limit: Variant = config.get_value("display", "fps_limit", 0)
	if limit is int and limit in FPS_OPTIONS:
		fps_limit = limit
	for field: String in TRIBE_CAMERA_DEFAULTS:
		var value: Variant = config.get_value("tribe_camera", field, TRIBE_CAMERA_DEFAULTS[field])
		if (value is float or value is int) and is_finite(float(value)):
			tribe_camera[field] = clampf(float(value), 0.5 if field == "pan_speed" else 30.0, 3.0 if field == "pan_speed" else 80.0)
	apply_runtime()

func save_and_apply(candidate: Dictionary, speed: float, inverted: bool, limit: int, path: String = CONFIG_PATH, camera_options: Dictionary = {}) -> String:
	var reason := validate(candidate)
	if not reason.is_empty():
		return reason
	if not is_finite(speed) or speed < 0.2 or speed > 3.0 or not limit in FPS_OPTIONS:
		return "Ungültige Kamera- oder Bildrateneinstellung."
	var camera_candidate: Dictionary = tribe_camera if camera_options.is_empty() else camera_options
	for field: String in TRIBE_CAMERA_DEFAULTS:
		var value: Variant = camera_candidate.get(field)
		if not (value is float or value is int) or not is_finite(float(value)):
			return Text.text("TRIBE_CAMERA_INVALID")
		if float(value) < (0.5 if field == "pan_speed" else 30.0) or float(value) > (3.0 if field == "pan_speed" else 80.0):
			return Text.text("TRIBE_CAMERA_INVALID")
	var config := ConfigFile.new()
	for field: String in TRIBE_CAMERA_DEFAULTS: config.set_value("tribe_camera", field, camera_candidate[field])
	for action: String in ACTIONS:
		config.set_value("bindings", action, candidate[action])
	config.set_value("camera", "sensitivity", speed)
	config.set_value("camera", "invert_y", inverted)
	config.set_value("display", "fps_limit", limit)
	var error := config.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error != OK:
		return "Steuerung konnte nicht gespeichert werden. Die bisherigen Werte bleiben aktiv."
	bindings = candidate.duplicate(true)
	tribe_camera = camera_candidate.duplicate(true)
	sensitivity = speed
	invert_y = inverted
	fps_limit = limit
	load_message = ""
	apply_runtime()
	return ""

func apply_runtime() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for code: int in bindings[action]:
			if code > 0:
				var key := InputEventKey.new()
				key.physical_keycode = code as Key
				InputMap.action_add_event(action, key)
			elif code < 0:
				var mouse := InputEventMouseButton.new()
				mouse.button_index = -code as MouseButton
				InputMap.action_add_event(action, mouse)
	Engine.max_fps = fps_limit
	bindings_changed.emit()

func camera_motion(motion: Vector2, base_sensitivity: float) -> Vector2:
	return motion * base_sensitivity * sensitivity * Vector2(1.0, -1.0 if invert_y else 1.0)
