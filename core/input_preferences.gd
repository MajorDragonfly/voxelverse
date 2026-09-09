extends RefCounted

## Local comfort settings, independent of campaigns and creature statistics.
const CONFIG_PATH := "user://input_preferences.cfg"
const ACTIONS := {
	"move_forward": "Vorwärts", "move_back": "Rückwärts",
	"move_left": "Nach links", "move_right": "Nach rechts",
	"jump": "Springen / aufsteigen", "primary_action": "Interagieren",
	"bite_action": "Beißen", "inspection_mode": "Untersuchen",
}
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
		-1: return "Linksklick"
		-2: return "Rechtsklick"
		-3: return "Mittelklick"
		-8: return "Maustaste 4"
		-9: return "Maustaste 5"
		KEY_SPACE: return "Leertaste"
		KEY_UP: return "Pfeil ↑"
		KEY_DOWN: return "Pfeil ↓"
		KEY_LEFT: return "Pfeil ←"
		KEY_RIGHT: return "Pfeil →"
	var logical: int = code if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	return OS.get_keycode_string((logical if logical != 0 else code) as Key)

static func binding_label(action: String) -> String:
	var names: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		var code: int = event_code(event)
		if code != 0:
			names.append(code_label(code))
	return " / ".join(names)

static func reserved_reason(code: int) -> String:
	if code == KEY_J:
		return "J ist für das Entdeckungsbuch reserviert."
	if code == KEY_K:
		return "K ist für den Skilltree reserviert."
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
			if occupied.has(code):
				return "%s ist bereits mit „%s“ belegt." % [code_label(code), ACTIONS[occupied[code]]]
			occupied[code] = action
			count += 1
		if count == 0:
			return "„%s“ braucht mindestens eine Taste." % ACTIONS[action]
	return ""

func load_saved(path: String = CONFIG_PATH) -> void:
	bindings = defaults()
	sensitivity = 1.0
	invert_y = false
	fps_limit = 0
	load_message = ""
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
	if validate(candidate).is_empty():
		bindings = candidate
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
	apply_runtime()

func save_and_apply(candidate: Dictionary, speed: float, inverted: bool, limit: int, path: String = CONFIG_PATH) -> String:
	var reason := validate(candidate)
	if not reason.is_empty():
		return reason
	if not is_finite(speed) or speed < 0.2 or speed > 3.0 or not limit in FPS_OPTIONS:
		return "Ungültige Kamera- oder Bildrateneinstellung."
	var config := ConfigFile.new()
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
	sensitivity = speed
	invert_y = inverted
	fps_limit = limit
	load_message = ""
	apply_runtime()
	return ""

func apply_runtime() -> void:
	for action: String in ACTIONS:
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

func camera_motion(motion: Vector2, base_sensitivity: float) -> Vector2:
	return motion * base_sensitivity * sensitivity * Vector2(1.0, -1.0 if invert_y else 1.0)
