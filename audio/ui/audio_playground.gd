extends Node3D
## F6 this scene in the editor to audition effects, ambience, creatures and music.

var _audio: Node
var _loop: AudioStreamPlayer
var _position := Vector3(0, 0, -5)
var _status: Label
var _underwater := false
var _music_status: Label
var _wall: StaticBody3D
var _wall_enabled := false
var _occlusion_source: Node3D
var _action_source: Node3D
var _saved_rest_settings: Array
var _saved_bindings: Array
var _scan_running := false
var _scan_ratio := 0.0
var _scan_bar: ProgressBar
var _scan_demo_serial := 0
var _order_demo_serial := 0
const VOICE_PROFILE = preload("res://audio/runtime/creature_voice_profile.gd")
var _voice_role := "forager"
var _voice_size := 1.0


func _ready() -> void:
	_audio = get_node("/root/AudioManager")
	_saved_rest_settings = [_audio.music.play_seconds, _audio.music.rest_min_seconds,
		_audio.music.rest_max_seconds, _audio.music.rest_cycles_enabled]
	_saved_bindings = [_audio.scans.automatic_binding, _audio.orders.automatic_binding]
	_audio.scans.automatic_binding = false
	_audio.orders.automatic_binding = false
	_build_occlusion_demo()
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
	var scan_title := Label.new()
	scan_title.text = "SCANNER · Erfassen, Fortschritt, Abbruch und bekannte Art vergleichen"
	rows.add_child(scan_title)
	_scan_bar = ProgressBar.new()
	_scan_bar.custom_minimum_size.y = 24
	rows.add_child(_scan_bar)
	var scan_buttons := HFlowContainer.new()
	rows.add_child(scan_buttons)
	button(scan_buttons, "Testscan starten · 2,5 s", func():
		_scan_demo_serial += 1
		_scan_ratio = 0.0
		_scan_running = true
		_status.text = "Unbekannte Art wird gescannt · Abbruch jederzeit möglich")
	button(scan_buttons, "Ziel verlieren", func():
		_scan_running = false
		_scan_bar.value = 0.0
		_audio.cancel_scan_audio()
		_status.text = "Scan abgebrochen – kein Erfolgston")
	button(scan_buttons, "Bekannte Art ansehen", func():
		_scan_running = false
		_scan_bar.value = 100.0
		_audio.update_scan_audio(get_instance_id(), 1.0, true)
		_status.text = "Bereits bekannte Art – kein neuer Scan oder Entdeckungston")
	var order_title := Label.new()
	order_title.text = "GRUPPENBEFEHLE · Eine Rückmeldung für den gesamten Auftrag"
	rows.add_child(order_title)
	var order_buttons := HFlowContainer.new()
	rows.add_child(order_buttons)
	for item in [["Bewegen", "move"], ["Sammeln", "gather"], ["Angreifen", "attack"],
		["Bauen", "build"], ["Warten", "wait"], ["Versorgen", "feed"]]:
		var order := StringName(item[1])
		button(order_buttons, item[0], func():
			_order_demo_serial += 1
			_audio.play_group_order(order, "demo-order-%d" % _order_demo_serial)
			_status.text = "Gruppenauftrag: " + String(order))
	button(order_buttons, "Auftrag unmöglich", func():
		_order_demo_serial += 1
		_audio.play_group_order(&"move", "demo-order-%d" % _order_demo_serial, false)
		_status.text = "Abgewiesener Auftrag – eigener Rückmeldeton")
	button(order_buttons, "12 Mitglieder · ein Ton", func():
		_order_demo_serial += 1
		for index in 12:
			_audio.play_group_order(&"move", "demo-order-%d" % _order_demo_serial)
		_status.text = "Zwölf Meldungen zum selben Gruppenauftrag ergeben eine Bestätigung")
	_music_status = Label.new()
	_music_status.text = "MUSIK · Drei eigene Stücke mit weichen Übergängen"
	rows.add_child(_music_status)
	_audio.music.context_changed.connect(func(_context: StringName, _title_text: String): _refresh_music_status())
	_audio.music.rest_changed.connect(func(_resting: bool): _refresh_music_status())
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
	button(music_buttons, "Musik mit Ruhephasen", func():
		_audio.music.configure_rest_cycle()
		_audio.music.rest_cycles_enabled = true
		set_meta(&"audio_music_context", &"exploration")
		_audio.resume_music_automation())
	button(music_buttons, "Pausentest · 6 s / 5 s", func():
		_audio.music.configure_rest_cycle(6.0, 5.0, 5.0)
		_audio.music.rest_cycles_enabled = true
		set_meta(&"audio_music_context", &"exploration")
		_audio.resume_music_automation()
		_status.text = "6 Sekunden Musik, Ausblendung, 5 Sekunden Ruhe · Gefahr kann unterbrechen")
	var cover_title := Label.new()
	cover_title.text = "SCHALLVERDECKUNG · Mittlere Quelle, mit und ohne Hindernis vergleichen"
	rows.add_child(cover_title)
	var cover_buttons := HFlowContainer.new()
	rows.add_child(cover_buttons)
	button(cover_buttons, "Rufschleife starten", func():
		_audio.stop_source(_occlusion_source.get_instance_id())
		_audio.play_world(&"occlusion_demo", _occlusion_source.global_position, -6.0,
			1.0, _occlusion_source.get_instance_id())
		_status.text = "Rufschleife mittig · Fels an/aus schalten und Dämpfung vergleichen")
	button(cover_buttons, "Fels an/aus", func():
		_wall_enabled = not _wall_enabled
		_wall.position.x = 0.0 if _wall_enabled else 30.0
		_status.text = "Fels vor der mittleren Quelle: " + ("an" if _wall_enabled else "aus"))
	button(cover_buttons, "Rufschleife stoppen", func(): _audio.stop_source(_occlusion_source.get_instance_id()))
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
	var action_title := Label.new()
	action_title.text = "AKTIONEN · Je drei Klangvarianten"
	rows.add_child(action_title)
	var action_buttons := HFlowContainer.new()
	rows.add_child(action_buttons)
	for item in [["Essen", "eat"], ["Trinken", "drink"], ["Sammeln", "gather"], ["Evolution", "evolve"]]:
		var action := StringName(item[1])
		button(action_buttons, item[0], func():
			_action_source.position = _position
			_audio.play_action(action, _action_source)
			_status.text = "Aktion: " + String(action))
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


func _process(delta: float) -> void:
	if not _scan_running:
		return
	if get_tree().paused or not _audio.is_window_focused():
		_scan_running = false
		_scan_bar.value = 0.0
		_audio.scans.reset_playback()
		return
	_scan_ratio = minf(1.0, _scan_ratio + minf(delta, 0.1) / 2.5)
	_scan_bar.value = _scan_ratio * 100.0
	_audio.update_scan_audio(get_instance_id(), _scan_ratio)
	if _scan_ratio >= 1.0:
		_scan_running = false
		_audio.complete_scan_audio("demo-species-%d" % _scan_demo_serial)
		_status.text = "Scan abgeschlossen – vorhandener Entdeckungston"


func _refresh_music_status() -> void:
	_music_status.text = "MUSIK · " + ("Ruhephase – Umgebung und Kreaturen bleiben hörbar" if _audio.music.is_resting() else _audio.music.get_title())


func _build_occlusion_demo() -> void:
	_wall = StaticBody3D.new()
	_wall.name = "ListeningObstacle"
	_wall.position = Vector3(30, 0, -3)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	shape.shape = box
	_wall.add_child(shape)
	add_child(_wall)
	_occlusion_source = Node3D.new()
	_occlusion_source.position = Vector3(0, 0, -6)
	add_child(_occlusion_source)
	_action_source = Node3D.new()
	add_child(_action_source)
	_audio.register_sound(&"occlusion_demo", [_audio.director.loop_stream(_audio.get_sound_stream(&"creature_chirp_warn"))])


func button(parent: Control, text: String, callback: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(180, 48)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.pressed.connect(callback)
	parent.add_child(control)


func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.scans.reset_scene()
		_audio.orders.reset_scene()
		_audio.scans.automatic_binding = _saved_bindings[0]
		_audio.orders.automatic_binding = _saved_bindings[1]
		_audio.stop_source(_occlusion_source.get_instance_id())
		_audio.stop_source(_action_source.get_instance_id())
		_audio.music.configure_rest_cycle(_saved_rest_settings[0], _saved_rest_settings[1], _saved_rest_settings[2])
		_audio.music.rest_cycles_enabled = _saved_rest_settings[3]
		_audio.music.reset_scene()
		_audio.set_underwater(false)
		_audio.director.automatic_tracking = true
		_audio.creatures.automatic_tracking = true
