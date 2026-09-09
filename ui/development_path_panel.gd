extends VBoxContainer

const Style = preload("res://ui/progression_style.gd")

var _stage_labels: Dictionary = {}
var _home: Label
var _legacy: Label
var _transition: Label
var _stages: BoxContainer
var _community: Label
var _factions: Label
var _epochs: Dictionary = {}


func _ready() -> void:
	name = "DevelopmentPath"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	add_child(Style.label("Die Entwicklung deiner Spezies", 28))
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
	_community = Style.label("", 18)
	add_child(_community)
	_factions = Style.label("", 18, Style.MUTED)
	add_child(_factions)
	for phase: int in [2, 3]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", Style.box())
		add_child(panel)
		var content := Style.column(panel, 10)
		var title := Style.label("", 23, Style.SOCIAL)
		var goals := Style.label("", 17, Style.MUTED)
		var action := Style.button("")
		action.disabled = true
		for control: Control in [title, goals, action]:
			content.add_child(control)
		_epochs[phase] = {"title": title, "goals": goals, "action": action}
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
	_legacy.text = "Deine wirksamen Gruppenboni für den Stamm\nKoordination +%d %% · Verteidigung +%d %%" % [cooperation, defense]
	_legacy.text += "\nKoordination beschleunigt die gemeinsamen Dorfaufgaben; Verteidigung folgt mit Stammeskämpfen." if int(data["current_phase"]) == 1 else "\nIn der Nestgruppe noch nicht aktiv. Koordination wirkt nach dem Wechsel auf Dorfaufgaben; Verteidigung folgt mit Stammeskämpfen."
	_transition.text = data["transition"]["message"]
	_transition.text += "\nSoziale, aggressive und gemischte Entwicklung bleiben möglich. Punkte allein lösen keinen Phasenwechsel aus."

	_community.text = "Stammesfortschritt · %d Sozialpunkte verfügbar\nKreaturen- und Stammespunkte bleiben getrennt." % int(data["tribal_wallet"]["available"]["social"])
	for goal: Dictionary in data["tribal_goals"]:
		_community.text += "\n\n%s · %s · +%d Stammespunkte\n%s" % ["Erreicht" if goal["completed"] else "Offen", goal["name"], goal["points"], goal["description"]]
	_factions.text = data["factions"]
	for epoch: Dictionary in data["epochs"]:
		var controls: Dictionary = _epochs[int(epoch["target"])]
		controls["title"].text = epoch["name"] + " · noch gesperrt"
		controls["goals"].text = "Spielbare Voraussetzungen für den späteren Wechsel:"
		for requirement: Dictionary in epoch["requirements"]:
			controls["goals"].text += "\n\n%s · %s" % ["Erfüllt" if requirement["met"] else "Offen" if requirement["supported"] else "Spielsystem folgt", requirement["text"]]
		controls["goals"].text += "\n\n" + epoch["retention"]
		controls["action"].text = epoch["action"]
		controls["action"].tooltip_text = epoch["blockers"][0]
		controls["action"].disabled = true


func _layout() -> void:
	_stages.vertical = get_viewport().get_visible_rect().size.x < 1050
