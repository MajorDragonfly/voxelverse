extends Node3D
## F6 this scene in the editor to audition the complete first sound package.

var _audio: Node
var _loop: AudioStreamPlayer
var _position := Vector3(0, 0, -5)
var _status: Label
var _underwater := false


func _ready() -> void:
	_audio = get_node("/root/AudioManager")
	_audio.director.automatic_tracking = false
	_audio.director.reset_tracking()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	_loop = AudioStreamPlayer.new()
	_loop.bus = &"VV Ambience"
	add_child(_loop)
	var layer := CanvasLayer.new()
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.060)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 780
	rows.add_theme_constant_override("separation", 20)
	center.add_child(rows)
	var title := Label.new()
	title.text = "VOXELVERSE · HÖRTEST"
	title.add_theme_font_size_override("font_size", 36)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "Klänge auswählen · Richtung mit Kopfhörern prüfen · F7 für Lautstärke"
	rows.add_child(hint)
	var locations := HBoxContainer.new()
	rows.add_child(locations)
	for item in [["Links", Vector3(-5, 0, -2)], ["Mitte", Vector3(0, 0, -5)],
		["Rechts", Vector3(5, 0, -2)], ["Weit entfernt", Vector3(0, 0, -35)]]:
		var position: Vector3 = item[1]
		button(locations, item[0], func():
			_position = position
			_audio.play_world(&"step_stone", _position, 0.0, 1.0, 777))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	rows.add_child(grid)
	for item in [["Gras", "step_grass"], ["Sand", "step_sand"], ["Stein", "step_stone"],
		["Schnee", "step_snow"], ["Holz", "step_wood"], ["Waten", "step_water"],
		["Springen", "jump"], ["Landen", "land"], ["Wassereintritt", "splash"],
		["Wasserbewegung", "swim"], ["Bestätigen", "ui_confirm"], ["Entdeckung", "discovery"]]:
		var event := StringName(item[1])
		button(grid, item[0], func():
			_status.text = "Klang: " + String(event)
			if event == &"ui_confirm" or event == &"discovery":
				_audio.play_ui(event)
			else:
				_audio.play_world(event, _position, 0.0, 1.0, 777))
	var loops := HBoxContainer.new()
	rows.add_child(loops)
	for item in [["Wind", "wind_loop"], ["Blätter", "foliage_loop"],
		["Wasser", "water_loop"], ["Unter Wasser", "underwater_loop"]]:
		var event := StringName(item[1])
		button(loops, item[0], func():
			_loop.stream = _audio.director.loop_stream(_audio.get_sound_stream(event))
			_loop.play()
			_status.text = "Umgebung: " + String(event))
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	button(actions, "Umgebung stoppen", func(): _loop.stop())
	button(actions, "Unterwasserfilter an/aus", func():
		_underwater = not _underwater
		_audio.set_underwater(_underwater)
		_status.text = "Unterwasserfilter: " + ("an" if _underwater else "aus"))
	button(actions, "Lautstärke · F7", func(): _audio.open_settings())
	_status = Label.new()
	_status.text = "Bereit · Eigene Prototyp-Klänge für Voxelverse"
	rows.add_child(_status)


func button(parent: Control, text: String, callback: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(180, 48)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.pressed.connect(callback)
	parent.add_child(control)


func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.set_underwater(false)
		_audio.director.automatic_tracking = true
