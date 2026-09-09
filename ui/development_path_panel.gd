extends VBoxContainer

const Style = preload("res://ui/progression_style.gd")

var _stage_labels: Dictionary = {}
var _home: Label
var _legacy: Label
var _transition: Label
var _stages: BoxContainer


func _ready() -> void:
	name = "DevelopmentPath"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	add_child(Style.label("Von deiner Kreatur zum eigenen Dorf", 28))
	add_child(Style.label("Die Nestgruppe gehört zur Kreaturenphase. Erst in der Stammesphase führst du Gruppen, stellst Werkzeuge her und baust ein Dorf.", 18, Style.MUTED))
	_stages = BoxContainer.new()
	_stages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stages.add_theme_constant_override("separation", 14)
	add_child(_stages)
	for stage_id in ["creature", "nest_group", "tribe"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", Style.box())
		_stages.add_child(panel)
		var content := Style.column(panel, 6)
		var title := Style.label("", 23, Style.SOCIAL)
		var status := Style.label("", 16, Style.MUTED)
		var control := Style.label("", 18)
		var description := Style.label("", 17, Style.MUTED)
		for label in [title, status, control, description]:
			content.add_child(label)
		_stage_labels[stage_id] = {"title": title, "status": status, "control": control, "description": description, "panel": panel}
		if stage_id == "nest_group":
			_home = Style.label("", 17)
			content.add_child(_home)
	_legacy = Style.label("", 18, Style.SOCIAL)
	add_child(_legacy)
	_transition = Style.label("", 17, Style.MUTED)
	add_child(_transition)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()


func refresh() -> void:
	if _home == null:
		return
	var data: Dictionary = get_node("/root/ProgressionService").get_development_path()
	for stage: Dictionary in data["stages"]:
		var labels: Dictionary = _stage_labels[stage["id"]]
		for key in ["title", "status", "control", "description"]:
			labels[key].text = stage[key]
		labels["panel"].add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.SOCIAL if data["current_stage"] == stage["id"] else Color("354750")))
	_home.text = data["home"]["message"]
	if not data["home"]["runtime_available"] and int(data["current_phase"]) == 0:
		_home.text += "\nNestgruppensteuerung ist in dieser Version noch nicht verfügbar."
	var cooperation: int = roundi((float(data["legacy"]["group_cooperation"]["value"]) - 1.0) * 100.0)
	var defense: int = roundi((float(data["legacy"]["group_defense"]["value"]) - 1.0) * 100.0)
	_legacy.text = "Dein gekauftes Vermächtnis für den Stamm\nKoordination +%d %% · Verteidigung +%d %%" % [cooperation, defense]
	_legacy.text += "\nKoordination beschleunigt die gemeinsame Dorfaufgaben; Verteidigung folgt mit Stammeskämpfen." if int(data["current_phase"]) == 1 else "\nIn der Nestgruppe noch nicht aktiv. Koordination wirkt nach dem Wechsel auf Dorfaufgaben; Verteidigung folgt mit Stammeskämpfen."
	_transition.text = data["transition"]["message"]
	_transition.text += "\nSoziale, aggressive und gemischte Entwicklung bleiben möglich. Punkte allein lösen keinen Phasenwechsel aus."


func _layout() -> void:
	_stages.vertical = get_viewport().get_visible_rect().size.x < 1050
