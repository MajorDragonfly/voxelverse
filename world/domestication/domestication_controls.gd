extends VBoxContainer
## Compact extension inside the EXISTING tribal HUD. No second pause owner.
const Style = preload("res://ui/progression_style.gd")
var runtime: Node
var targets: OptionButton
var detail: Label
var buttons: Dictionary = {}
var _ids: Array[String] = []
var _names: Array[String] = []

func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(Style.label("Tierhaltung", 17, Style.SOCIAL))
	targets = OptionButton.new()
	targets.custom_minimum_size.x = 190
	targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets.clip_text = true
	targets.focus_mode = Control.FOCUS_NONE
	row.add_child(targets)
	var actions := HFlowContainer.new()
	add_child(actions)
	for entry: Array in [["approach", "Zum Tier", func(): runtime.approach(selected_id())], ["offer", "Füttern / Zähmen · 1 Nahrung", func(): runtime.offer(selected_id())], ["cancel", "Abbrechen", func(): runtime.cancel(selected_id())], ["follow", "Folgen", func(): runtime.issue_command(selected_id(), "follow")], ["wait", "Warten", func(): runtime.issue_command(selected_id(), "wait")], ["home", "Heimkehr", func(): runtime.issue_command(selected_id(), "home")], ["abandon", "Zähmung aufgeben", func(): runtime.abandon(selected_id())]]:
		var button := Style.button(entry[1])
		button.pressed.connect(entry[2])
		button.focus_mode = Control.FOCUS_NONE
		actions.add_child(button)
		buttons[entry[0]] = button
	detail = Style.label("", 15, Style.MUTED)
	add_child(detail)
	hide()

func selected_id() -> String:
	return _ids[targets.selected] if targets.selected >= 0 and targets.selected < _ids.size() else ""

func refresh() -> void:
	visible = runtime._ready_runtime and runtime.tribe._active and runtime.tribe.panel.animal_panel_open
	if not visible: return
	var ids: Array[String] = []
	var names: Array[String] = []
	for actor: Node3D in runtime.visible_animals():
		var id: String = actor.get_campaign_identity()["object_id"]
		if id in ids: continue
		var record: Dictionary = runtime.controller.record(id)
		ids.append(id)
		var title: String = actor.get_display_name()
		names.append(title + (" · eigenes Tier" if record.get("status") == "tamed" else " · verstorben" if actor.is_dead else " · wild / Zähmung"))
	if ids != _ids or names != _names:
		var previous: String = selected_id()
		_ids = ids
		_names = names
		targets.clear()
		for title: String in names: targets.add_item(title)
		targets.select(maxi(0, _ids.find(previous)) if not _ids.is_empty() else -1)
	var record: Dictionary = runtime.controller.record(selected_id())
	var handler: String = runtime.chosen_handler()
	var selected: Dictionary = runtime.tribe.member_record(handler)
	var prefix: String = "Betreuer: " + str(selected.get("name", "einen Bewohner auswählen"))
	if not record.is_empty(): prefix += " · Vertrauen %d %% · %s" % [roundi(record["trust"]), {"follow": "Folgen", "wait": "Warten", "home": "Heimkehr"}[record["order"]]]
	detail.text = prefix + "\n" + ("Keine Tiere in der geladenen Dorfumgebung." if _ids.is_empty() else runtime.status)
	for key: String in buttons: buttons[key].disabled = not runtime.is_active() or _ids.is_empty()
