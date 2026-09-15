extends RefCounted
## Read-only tribe presentation. Legacy German results are adapted until their
## domain owners publish structured codes; unknown diagnostics remain literal.
const Text = preload("res://core/localization/ui_text.gd")
const ORDERS := {
	"wood": "TRIBE_ORDER_WOOD",
	"stone": "TRIBE_ORDER_STONE",
	"food": "TRIBE_ORDER_FOOD",
	"supply": "TRIBE_ORDER_SUPPLY",
	"tool": "TRIBE_ORDER_TOOL",
	"hut": "TRIBE_ORDER_HUT",
	"tent": "TRIBE_ORDER_TENT",
	"garden": "TRIBE_ORDER_GARDEN",
	"feed": "TRIBE_ORDER_FEED",
	"wait": "TRIBE_ORDER_WAIT",
	"resume": "TRIBE_ORDER_RESUME",
	"water": "TRIBE_ORDER_WATER",
	"provision": "TRIBE_ORDER_PROVISION",
	"drink": "TRIBE_ORDER_DRINK",
	"well": "TRIBE_ORDER_WELL",
	"forester": "TRIBE_ORDER_FORESTER",
	"quarry": "TRIBE_ORDER_QUARRY",
	"fiberbed": "TRIBE_ORDER_FIBERBED",
	"fiber": "TRIBE_ORDER_FIBER",
	"milk": "TRIBE_ORDER_MILK",
	"move": "TRIBE_ORDER_MOVE",
	"profession": "TRIBE_ORDER_PROFESSION",
	"pen": "TRIBE_ORDER_PEN",
	"laying_site": "TRIBE_ORDER_LAYING_SITE",
	"tend": "TRIBE_ORDER_TEND",
	"eggs": "TRIBE_ORDER_EGGS"
}
const JOBS := {
	"none": "TRIBE_JOB_NONE",
	"provider": "TRIBE_JOB_PROVIDER",
	"forester": "TRIBE_JOB_FORESTER",
	"mason": "TRIBE_JOB_MASON",
	"weaver": "TRIBE_JOB_WEAVER",
	"builder": "TRIBE_JOB_BUILDER",
	"milk_carrier": "TRIBE_JOB_MILK_CARRIER",
	"keeper": "TRIBE_JOB_KEEPER",
	"egg_carrier": "TRIBE_JOB_EGG_CARRIER"
}
const RESOURCES := {
	"wood": "TRIBE_RESOURCE_WOOD",
	"stone": "TRIBE_RESOURCE_STONE",
	"food": "TRIBE_RESOURCE_FOOD",
	"water": "TRIBE_RESOURCE_WATER",
	"fiber": "TRIBE_RESOURCE_FIBER",
	"milk": "TRIBE_RESOURCE_MILK",
	"eggs": "TRIBE_RESOURCE_EGGS"
}
const ACTIVITIES := {
	"wait": "TRIBE_ACTIVITY_WAIT",
	"move": "TRIBE_ACTIVITY_MOVE",
	"wood": "TRIBE_ACTIVITY_WOOD",
	"stone": "TRIBE_ACTIVITY_STONE",
	"food": "TRIBE_ACTIVITY_FOOD",
	"tool": "TRIBE_ACTIVITY_TOOL",
	"hut": "TRIBE_ACTIVITY_HUT",
	"tent": "TRIBE_ACTIVITY_TENT",
	"pen": "TRIBE_ACTIVITY_PEN",
	"laying_site": "TRIBE_ACTIVITY_LAYING_SITE",
	"eggs": "TRIBE_ACTIVITY_EGGS",
	"tend": "TRIBE_ACTIVITY_TEND",
	"garden": "TRIBE_ACTIVITY_GARDEN",
	"supply": "TRIBE_ACTIVITY_SUPPLY",
	"feed": "TRIBE_ACTIVITY_FEED",
	"water": "TRIBE_ACTIVITY_WATER",
	"fiber": "TRIBE_ACTIVITY_FIBER",
	"milk": "TRIBE_ACTIVITY_MILK",
	"drink": "TRIBE_ACTIVITY_DRINK",
	"provision": "TRIBE_ACTIVITY_PROVISION",
	"build": "TRIBE_ACTIVITY_BUILD",
	"well": "TRIBE_ACTIVITY_WELL",
	"forester": "TRIBE_ACTIVITY_FORESTER",
	"quarry": "TRIBE_ACTIVITY_QUARRY",
	"fiberbed": "TRIBE_ACTIVITY_FIBERBED"
}
const PROJECTS := {
	"tool": "TRIBE_PROJECT_TOOL",
	"hut": "TRIBE_PROJECT_HUT",
	"tent": "TRIBE_PROJECT_TENT",
	"pen": "TRIBE_PROJECT_PEN",
	"laying_site": "TRIBE_PROJECT_LAYING_SITE",
	"garden": "TRIBE_PROJECT_GARDEN",
	"well": "TRIBE_PROJECT_WELL",
	"forester": "TRIBE_PROJECT_FORESTER",
	"quarry": "TRIBE_PROJECT_QUARRY",
	"fiberbed": "TRIBE_PROJECT_FIBERBED"
}
const LEGACY := {
	"Führe ein passendes gezähmtes Tier hierher und ordne es zu.": "HUSBANDRY_NEED_ANIMAL",
	"Art oder Körper des Tieres hat sich geändert.": "HUSBANDRY_CHANGED_ANIMAL",
	"Das Tier muss am Tierplatz bleiben.": "HUSBANDRY_STAY",
	"Tierplatz oder Zugang ist momentan nicht erreichbar.": "HUSBANDRY_ACCESS",
	"Löse zuerst die Tierzuordnung.": "HUSBANDRY_RELEASE_FIRST",
	"Warte, bis Futter und Wasser zurückgebracht wurden.": "HUSBANDRY_RETURN_SUPPLIES",
	"Das Tier ist zurzeit nicht verfügbar.": "HUSBANDRY_UNAVAILABLE",
	"Das Tierregister gehört nicht zu diesem Dorf.": "HUSBANDRY_WRONG_REGISTER",
	"Wähle ein lebendes, gezähmtes Nutztier deines Stammes.": "HUSBANDRY_OWNED_ANIMAL",
	"Dieses Tier eignet sich nicht für diesen Haltungsplatz mit Pflanzenfutter.": "HUSBANDRY_UNSUITABLE",
	"Das Tier muss in der geladenen Dorfumgebung sein.": "HUSBANDRY_NOT_LOADED",
	"Dieses Tier passt nicht zu diesem Haltungsplatz.": "HUSBANDRY_WRONG_SITE",
	"Dieser Tierplatz ist bereits belegt.": "HUSBANDRY_OCCUPIED",
	"Dieses Tier hat bereits einen Tierplatz.": "HUSBANDRY_ALREADY_ASSIGNED",
	"Art oder Körper des gespeicherten Tieres hat sich geändert.": "HUSBANDRY_CHANGED_RECORD",
	"Für dieses Tier ist kein freier Produktionsnachweis verfügbar.": "HUSBANDRY_RECORD_LIMIT",
	"Hole zuerst die fertigen Produkte ab und schaffe Lagerplatz.": "HUSBANDRY_COLLECT_FIRST",
	"Warte, bis unterwegs befindliches Tierfutter und Wasser abgeliefert sind.": "HUSBANDRY_DELIVER_FIRST",
	"Dein Stamm befindet sich bereits in einem anderen Zeitalter.": "TRIBE_AGE_OTHER",
	"Kehre zuerst mit deiner Kreatur in die geladene Welt zurück.": "TRIBE_AGE_WORLD",
	"Kehre zum Heimatplatz zurück, um mit deiner Gruppe fortzuschreiten.": "TRIBE_AGE_HOME",
	"Ein anderer Übergang wird noch abgeschlossen.": "TRIBE_AGE_PENDING",
	"Für das erste Dorf fehlen sichere Wege und fünf freie Arbeitsplätze. Verlege den Heimatplatz auf eine größere trockene Fläche.": "TRIBE_AGE_SPACE",
	"Ein Gefährte erreicht den Dorfplatz noch nicht. Hole ihn näher heran.": "TRIBE_AGE_COMPANION",
	"Deine Kreatur erreicht den Dorfplatz noch nicht.": "TRIBE_AGE_PLAYER",

	"Dein Stamm zählt sechs Bewohner.": "TRIBE_GROWTH_MAX",
	"Dorfwachstum: Baue zusätzliche Schlafplätze.": "TRIBE_GROWTH_BEDS",
	"Dorfwachstum: Wurzelgarten und Brunnen werden benötigt.": "TRIBE_GROWTH_STATIONS",
	"Dorfwachstum: Alle Bewohner müssen mindestens halb satt und mit Wasser versorgt sein.": "TRIBE_GROWTH_NEEDS",
	"Wähle Bewohner und erteile gemeinsame oder einzelne Aufträge.": "TRIBE_STATUS_SELECT",
	"Hier ist kein geladener Boden.": "TRIBE_STATUS_NO_GROUND",
	"Wähle zuerst mindestens einen Bewohner aus.": "TRIBE_STATUS_NO_SELECTION",
	"Die Gruppe kann gerade keine Befehle annehmen.": "TRIBE_STATUS_UNAVAILABLE",
	"Zuerst ein Steinwerkzeug herstellen.": "TRIBE_STATUS_TOOL",
	"Stelle zuerst ein Steinwerkzeug her.": "TRIBE_STATUS_TOOL_FIRST",
	"Rechtsklick auf einen freien Bauplatz · Esc bricht die Platzierung ab.": "TRIBE_STATUS_PLACEMENT",
	"Platzierung abgebrochen.": "TRIBE_STATUS_CANCEL",
	"Die Dorfwege werden geprüft. Bitte einen Moment warten.": "TRIBE_STATUS_PATHS",
	"Befehle bleiben zunächst in der sicheren Umgebung des Dorfes.": "TRIBE_STATUS_RANGE",
	"Mindestens ein ausgewählter Bewohner erreicht diesen Ort nicht.": "TRIBE_STATUS_ROUTE",
	"Dieser Ausbau ist bereits abgeschlossen.": "TRIBE_STATUS_DONE",
	"Schließe zuerst die laufende Arbeit ab.": "TRIBE_STATUS_BUSY",
	"Hier fehlen Platz, trockener Boden oder ein freier Weg zum Lager.": "TRIBE_STATUS_SITE",
	"Ein ausgewählter Bewohner erreicht diesen Bauplatz nicht.": "TRIBE_STATUS_SITE_ROUTE",
	"Auftrag gespeichert.": "TRIBE_STATUS_SAVED",
	"Speichern fehlgeschlagen. Der bisherige Auftrag bleibt erhalten.": "TRIBE_STATUS_SAVE_ORDER",
	"Speichern fehlgeschlagen. Der bisherige Stand bleibt erhalten.": "TRIBE_STATUS_SAVE_STATE",
	"Ein Bewohner wartet auf geladenen Boden.": "TRIBE_STATUS_GROUND",
	"Weg blockiert · der Auftrag bleibt erhalten; neue Wege werden geprüft.": "TRIBE_STATUS_BLOCKED",
	"Die Bewohner setzen ihre Aufträge fort.": "TRIBE_STATUS_RESUME",
	"Ausbau fertig · Bewohner mit Beruf setzen ihre Zuständigkeit fort.": "TRIBE_STATUS_BUILT",
	"Dorfwachstum wartet auf einen freien, erreichbaren Eingang.": "TRIBE_STATUS_GROWTH_SITE",
	"Die Abholstelle ist nicht erreichbar.": "TRIBE_STATUS_PICKUP"
}
const LEGACY_RESOURCES := {
	"Holz": "wood",
	"Stein": "stone",
	"Nahrung": "food",
	"Wasser": "water",
	"Fasern": "fiber",
	"Milch": "milk",
	"Eier": "eggs"
}

static func order_title(identity: String) -> String:
	return Text.text(ORDERS.get(identity, "TRIBE_COMMAND"))

static func job_title(identity: String) -> String:
	return Text.text(JOBS.get(identity, "TRIBE_UNKNOWN_JOB"))

static func resource_title(identity: String) -> String:
	return Text.text(RESOURCES.get(identity, "TRIBE_UNKNOWN_RESOURCE"))

static func activity_title(identity: String) -> String:
	return Text.text(ACTIVITIES.get(identity, "TRIBE_ACTIVITY_UNKNOWN"))

static func legacy_status(value: String) -> String:
	if value in ["Lege mit N einen Heimatplatz für deine Nestgruppe fest.", "Rufe beide Gefährten mit N → Heimkehren zum Heimatplatz."]:
		return Text.format_text("TRIBE_AGE_ESTABLISH" if value.begins_with("Lege") else "TRIBE_AGE_RECALL", {"key": preload("res://core/input_preferences.gd").code_label(KEY_N)})
	if LEGACY.has(value):
		return Text.text(LEGACY[value])
	# Anchor every adapter. Names are inserted once through UiText, never translated.
	var growth := _match("^Dorfwachstum: Halte je ([0-9]+) Nahrung und Wasser im Lager bereit\\.$", value)
	if growth != null:
		return Text.format_text("TRIBE_GROWTH_RESERVE", {"count": growth.get_string(1)})
	var materials := _match("^Es fehlen eingelagerte Materialien: ([0-9]+) (Holz|Stein|Nahrung|Wasser|Fasern|Milch|Eier)\\.$", value)
	if materials != null:
		return Text.format_text("TRIBE_STATUS_MATERIAL", {"count": materials.get_string(1), "resource": resource_title(LEGACY_RESOURCES[materials.get_string(2)])})
	var suffix := " gehört jetzt zu deinem Stamm. Wähle einen Beruf oder Auftrag."
	if value.ends_with(suffix):
		return Text.format_text("TRIBE_STATUS_JOINED", {"name": value.trim_suffix(suffix)})
	return value

static func _match(pattern: String, value: String) -> RegExMatch:
	var expression := RegEx.new()
	expression.compile(pattern)
	return expression.search(value)

static func husbandry_detail(view: Dictionary) -> String:
	var status: String = legacy_status(view.error)
	if view.state != "blocked":
		var resource: String = resource_title(view.resource)
		match view.state:
			"storage": status = Text.format_text("HUSBANDRY_STORAGE", {"resource": resource})
			"supplies": status = Text.format_text("HUSBANDRY_WAIT_SUPPLIES", {"resource": resource})
			"producing":
				var amount: String = Text.format_text("HUSBANDRY_EGG_AMOUNT" if view.resource == "eggs" else "HUSBANDRY_MILK_AMOUNT", {"count": Text.number(view["yield"], 2)})
				status = Text.format_text("HUSBANDRY_PRODUCTION", {"resource": resource, "seconds": view.seconds, "amount": amount})
	return Text.format_text("HUSBANDRY_SUPPLIES", {"food": Text.number(view.food, 1), "water": Text.number(view.water, 1), "status": status})
