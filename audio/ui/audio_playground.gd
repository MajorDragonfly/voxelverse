extends Node3D
## F6 this scene in the editor to audition effects, ambience, creatures and music.

var _audio: Node
var _loop: AudioStreamPlayer
var _position := Vector3(0, 0, -5)
var _status: Label
var _underwater := false
var _music_status: Label
const VOICE_PROFILE = preload("res://audio/runtime/creature_voice_profile.gd")
var _voice_role := "forager"
var _voice_size := 1.0


func _ready() -> void:
	_audio = get_node("/root/AudioManager")
	_audio.director.automatic_tracking = false
	_audio.creatures.automatic_tracking = false
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
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_left = 0.08
	scroll.anchor_right = 0.92
	scroll.anchor_top = 0.06
	scroll.anchor_bottom = 0.94
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 20)
	scroll.add_child(rows)
	var title := Label.new()
	title.text = "VOXELVERSE · HÖRTEST"
	title.add_theme_font_size_override("font_size", 36)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "Klänge auswählen · Richtung mit Kopfhörern prüfen · F7 für Lautstärke"
	rows.add_child(hint)
	_music_status = Label.new()
	_music_status.text = "MUSIK · Drei eigene Stücke mit weichen Übergängen"
	rows.add_child(_music_status)
	_audio.music.context_changed.connect(func(_context: StringName, title_text: String):
		_music_status.text = "MUSIK · " + title_text)
	var music_buttons := GridContainer.new()
	music_buttons.columns = 3
	music_buttons.add_theme_constant_override("h_separation", 12)
	music_buttons.add_theme_constant_override("v_separation", 12)
	rows.add_child(music_buttons)
	for item in [["Menümusik · 40 s", "menu"], ["Erkundung · 60 s", "exploration"],
		["Gefahr · 40 s", "danger"], ["Musik aus", "silent"]]:
		var context := StringName(item[1])
		button(music_buttons, item[0], func(): _audio.set_music_context(context))
	button(music_buttons, "Gefahr für 8 Sekunden", func():
		set_meta(&"audio_music_context", &"exploration")
		_audio.resume_music_automation()
		_audio.notify_music_danger(8.0))
	button(music_buttons, "Musik + Umgebung", func():
		_audio.set_music_context(&"exploration")
		_loop.stream = _audio.director.loop_stream(_audio.get_sound_stream(&"foliage_loop"))
		_loop.volume_db = -16.0
		_loop.play()
		_status.text = "Spielmix läuft · Schritte und Kreaturen dazuschalten · F7 für Lautstärke")
	var locations := HFlowContainer.new()
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
	var loops := HFlowContainer.new()
	rows.add_child(loops)
	for item in [["Wind", "wind_loop"], ["Blätter", "foliage_loop"],
		["Wasser", "water_loop"], ["Unter Wasser", "underwater_loop"]]:
		var event := StringName(item[1])
		button(loops, item[0], func():
			_loop.volume_db = -12.0
			_loop.stream = _audio.director.loop_stream(_audio.get_sound_stream(event))
			_loop.play()
			_status.text = "Umgebung: " + String(event))
	var actions := HFlowContainer.new()
	rows.add_child(actions)
	button(actions, "Umgebung stoppen", func(): _loop.stop())
	button(actions, "Unterwasserfilter an/aus", func():
		_underwater = not _underwater
		_audio.set_underwater(_underwater)
		_status.text = "Unterwasserfilter: " + ("an" if _underwater else "aus"))
	button(actions, "Lautstärke · F7", func(): _audio.open_settings())
	var voice_title := Label.new()
	voice_title.text = "KREATURENSTIMMEN · Art und Größe vergleichen"
	rows.add_child(voice_title)
	var voice_options := HBoxContainer.new()
	voice_options.add_theme_constant_override("separation", 16)
	rows.add_child(voice_options)
	var role := OptionButton.new()
	role.add_item("Heller Ruf")
	role.add_item("Kehllaut")
	role.add_item("Raues Knurren")
	role.custom_minimum_size.x = 230
	role.item_selected.connect(func(index: int): _voice_role = ["forager", "grazer", "predator"][index])
	voice_options.add_child(role)
	var size_label := Label.new()
	size_label.text = "Größe: 1,0"
	size_label.custom_minimum_size.x = 110
	voice_options.add_child(size_label)
	var size_slider := HSlider.new()
	size_slider.min_value = 0.35
	size_slider.max_value = 3.0
	size_slider.step = 0.05
	size_slider.value = 1.0
	size_slider.custom_minimum_size = Vector2(260, 36)
	size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_slider.value_changed.connect(func(value: float):
		_voice_size = value
		size_label.text = "Größe: %.2f" % value)
	voice_options.add_child(size_slider)
	var reactions := GridContainer.new()
	reactions.columns = 3
	reactions.add_theme_constant_override("h_separation", 12)
	reactions.add_theme_constant_override("v_separation", 12)
	rows.add_child(reactions)
	for item in [["Kontakt", "contact"], ["Warnung", "warn"], ["Angriff", "attack"],
		["Verletzung", "hurt"], ["Tod", "death"], ["Freundliche Antwort", "friend"]]:
		var event := StringName(item[1])
		button(reactions, item[0], func():
			var profile := VOICE_PROFILE.build(42, _voice_role, _voice_size)
			var key := StringName("creature_%s_%s" % [profile["family"], event])
			_audio.play_world(key, _position, -5.0, float(profile["pitch"]), 777, 2)
			_status.text = "Kreatur: %s · Tonhöhe %.2f" % [event, profile["pitch"]])
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
		_audio.music.reset_scene()
		_audio.set_underwater(false)
		_audio.director.automatic_tracking = true
		_audio.creatures.automatic_tracking = true
