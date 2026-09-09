extends VBoxContainer
const Style = preload("res://ui/progression_style.gd")
const Model = preload("res://world/tribe/neighbors/neighbor_state.gd")
var controller: Node
var detail: Label
var contact_button: Button
var aid_button: Button
var focus_button: Button
var home_button: Button

func _ready() -> void:
	name = "Nachbarn"
	detail = Style.label("", 16)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)
	var actions := HFlowContainer.new()
	add_child(actions)
	contact_button = Style.button("Nachbarlager suchen")
	aid_button = Style.button("Auswahl liefert Hilfe")
	focus_button = Style.button("Nachbarlager ansehen")
	home_button = Style.button("Eigenes Dorf ansehen")
	for button: Button in [contact_button, aid_button, focus_button, home_button]:
		actions.add_child(button)
	contact_button.pressed.connect(func() -> void: controller.neighbors.contact(); controller.panel.refresh())
	aid_button.pressed.connect(func() -> void: controller.neighbors.start_aid(); controller.panel.refresh())
	focus_button.pressed.connect(func() -> void: controller.neighbors.focus())
	home_button.pressed.connect(func() -> void: controller.neighbors.focus(true))
	aid_button.tooltip_text = "Mindestens zwei freie Bewohner liefern aus dem eigenen Lager. Sechs Nahrung bleiben als Reserve. Pro Träger höchstens fünf Einheiten; Anhalten erhält die Fracht. Ein neuer Auftrag bringt übrige Hilfsfracht zuerst heim."

func refresh() -> void:
	if not is_instance_valid(detail):
		return
	var data: Dictionary = controller.body().get("tribal_neighbor", {})
	contact_button.visible = data.is_empty()
	aid_button.visible = not data.is_empty() and data["aid"]["status"] in ["offered", "active"]
	focus_button.visible = not data.is_empty()
	for button: Button in [contact_button, aid_button, focus_button, home_button]:
		button.disabled = not controller.is_active() or get_tree().paused
	aid_button.disabled = aid_button.disabled or controller.selected.size() < 2
	if data.is_empty():
		detail.text = "Nachbarstämme gehören deiner Spezies an und haben eigene Bewohner und Vorräte. Suche einen erreichbaren Kontakt in der geladenen Dorfumgebung."
	else:
		var status: String = {"offered": "Hilfsauftrag offen", "active": "Hilfslieferung läuft", "building": "Nachbarn bauen ihre Unterkunft", "completed": "Hilfe erfüllt · freundlich"}[data["aid"]["status"]]
		detail.text = "%s · Deine Spezies, eigene Fraktion · 2 Bewohner\n%s\n%s" % [data["name"], status, Model.progress(data)["text"]]
