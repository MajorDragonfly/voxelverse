extends VBoxContainer

const Preferences = preload("res://core/input_preferences.gd")
var preferences: RefCounted
var draft: Dictionary = {}
var listening_action: String = ""
var listening_slot: int = 0
var sensitivity: HSlider
var invert_y: CheckButton
var fps: OptionButton
var message: Label
var _speed_label: Label
var _buttons: Dictionary = {}

func setup(source: RefCounted) -> void:
	preferences = source
	add_theme_constant_override("separation", 12)
	var camera := HBoxContainer.new()
	add_child(camera)
	var label := Label.new()
	label.text = "Mausempfindlichkeit"
	label.custom_minimum_size.x = 245
	camera.add_child(label)
	sensitivity = HSlider.new()
	sensitivity.name = "MouseSensitivity"
	sensitivity.min_value = 0.2
	sensitivity.max_value = 3.0
	sensitivity.step = 0.05
	sensitivity.custom_minimum_size.x = 185
	sensitivity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sensitivity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	camera.add_child(sensitivity)
	_speed_label = Label.new()
	_speed_label.custom_minimum_size.x = 72
	camera.add_child(_speed_label)
	sensitivity.value_changed.connect(func(value: float): _speed_label.text = "%d%%" % roundi(value * 100.0))
	sensitivity.value_changed.connect(func(_value: float): _mark_changed())
	invert_y = CheckButton.new()
	invert_y.name = "InvertCameraY"
	invert_y.text = "Kamera vertikal umkehren"
	invert_y.toggled.connect(func(_value: bool): _mark_changed())
	add_child(invert_y)
	var fps_row := HBoxContainer.new()
	add_child(fps_row)
	label = Label.new()
	label.text = "Maximale Bildrate"
	label.custom_minimum_size.x = 245
	fps_row.add_child(label)
	fps = OptionButton.new()
	fps.name = "FPSLimit"
	fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for limit: int in Preferences.FPS_OPTIONS:
		fps.add_item("Unbegrenzt" if limit == 0 else "%d FPS" % limit, limit)
	fps_row.add_child(fps)
	fps.item_selected.connect(func(_index: int): _mark_changed())
	label = Label.new()
	label.text = "VSync kann die Bildrate zusätzlich begrenzen."
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	var separator := HSeparator.new()
	add_child(separator)
	label = Label.new()
	label.text = "SPIELTASTEN · HAUPT- UND ZWEITBELEGUNG"
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 7)
	add_child(grid)
	for action: String in Preferences.ACTIONS:
		label = Label.new()
		label.text = Preferences.ACTIONS[action]
		label.custom_minimum_size.x = 245
		label.add_theme_font_size_override("font_size", 20)
		grid.add_child(label)
		for slot in range(2):
			var button := Button.new()
			button.name = "Bind_%s_%d" % [action, slot]
			button.custom_minimum_size = Vector2(150, 44)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 18)
			button.pressed.connect(func(): begin_binding(action, slot))
			grid.add_child(button)
			_buttons[button.name] = button
	message = Label.new()
	message.custom_minimum_size = Vector2(0, 58)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 18)
	var reset := Button.new()
	reset.name = "ResetControls"
	reset.text = "Steuerung auf Standard zurücksetzen"
	reset.pressed.connect(_reset)
	add_child(reset)
	refresh()

func refresh() -> void:
	listening_action = ""
	draft = preferences.bindings.duplicate(true)
	sensitivity.value = preferences.sensitivity
	_speed_label.text = "%d%%" % roundi(sensitivity.value * 100.0)
	invert_y.set_pressed_no_signal(preferences.invert_y)
	fps.select(fps.get_item_index(preferences.fps_limit))
	_update_buttons()
	message.text = preferences.load_message if not preferences.load_message.is_empty() else "Belegung anklicken, dann eine Taste drücken. Änderungen mit „Übernehmen & speichern“ sichern."

func begin_binding(action: String, slot: int) -> void:
	listening_action = action
	listening_slot = slot
	message.text = "Taste für „%s“ drücken. Esc bricht ab; Rücktaste entfernt diese Belegung." % Preferences.ACTIONS[action]
	_update_buttons()

func capture_input(event: InputEvent) -> bool:
	if listening_action.is_empty():
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	if not event.is_pressed() or event.is_echo():
		return true
	var code: int = Preferences.event_code(event)
	if code == KEY_ESCAPE:
		cancel_binding()
		return true
	if event is InputEventWithModifiers and (event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed):
		message.text = "Bitte eine einzelne Taste ohne Strg, Alt oder Umschalt drücken."
		return true
	if code == KEY_BACKSPACE or code == KEY_DELETE:
		code = 0
	var candidate := draft.duplicate(true)
	candidate[listening_action][listening_slot] = code
	var reason: String = Preferences.validate(candidate)
	if not reason.is_empty():
		message.text = reason + " Andere Taste wählen oder Esc drücken."
		return true
	draft = candidate
	listening_action = ""
	_update_buttons()
	message.text = "Belegung vorgemerkt. Mit „Übernehmen & speichern“ aktivieren."
	return true

func cancel_binding() -> void:
	if listening_action.is_empty():
		return
	listening_action = ""
	_update_buttons()
	message.text = "Tastenauswahl abgebrochen."

func _mark_changed() -> void:
	if is_instance_valid(message):
		message.text = "Änderungen vorgemerkt. Mit „Übernehmen & speichern“ aktivieren."

func apply() -> String:
	if not listening_action.is_empty():
		return "Bitte zuerst die Tastenauswahl beenden."
	return preferences.save_and_apply(draft, sensitivity.value, invert_y.button_pressed, fps.get_selected_id())

func _reset() -> void:
	listening_action = ""
	draft = Preferences.defaults()
	sensitivity.value = 1.0
	invert_y.set_pressed_no_signal(false)
	fps.select(fps.get_item_index(0))
	_update_buttons()
	message.text = "Standardwerte vorgemerkt. Mit „Übernehmen & speichern“ aktivieren."

func _update_buttons() -> void:
	for action: String in Preferences.ACTIONS:
		for slot in range(2):
			var button: Button = _buttons["Bind_%s_%d" % [action, slot]]
			button.text = "Taste drücken …" if listening_action == action and listening_slot == slot else Preferences.code_label(draft[action][slot])
