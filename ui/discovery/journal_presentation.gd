extends RefCounted
## Read-only projections. Saved names, IDs and domain state remain literal.
const Text = preload("res://core/localization/ui_text.gd")
const Language = preload("res://ui/discovery/owned_animal_presentation.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Research = preload("res://core/discovery/research_goals.gd")

static func text(key: String, locale: String = "") -> String:
	var translated := Language.text(key, locale)
	return key if translated.is_empty() else translated

static func bind(control: Control, property: String, key: String) -> void:
	control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	control.set_meta("journal_" + property, key)
	control.set(property, text(key))

static func refresh(node: Node) -> void:
	for property: String in ["text", "tooltip_text", "placeholder_text"]:
		if node.has_meta("journal_" + property): node.set(property, text(node.get_meta("journal_" + property)))
	if node.has_meta("journal_number"):
		var value: Array = node.get_meta("journal_number")
		node.text = number(value[0], value[1])
	for child in node.get_children(): refresh(child)

static func number(value: float, signed_value: bool = false) -> String:
	if absf(value) < 0.005: value = 0.0
	return ("+" if signed_value and value > 0 else "") + Text.number(value, 2)

static func part(id: String, field: String = "name", locale: String = "") -> String:
	var definition: Dictionary = Records.Parts.get_part(id)
	var key := "EDITOR_PART_" + id.to_upper() + "_" + field.to_upper()
	var translated := text(key, locale)
	if translated != key: return translated
	return str(definition.get(field, id if field == "name" else ""))

static func location(row: Dictionary, locale: String = "") -> String:
	var journal: Dictionary = Records.as_dictionary(row.get("journal", {}))
	if row.get("location_generated", not journal.has("location")):
		return text("Welt %s", locale) % Records.saved_integer(row.get("world_seed", text("unbekannt", locale)))
	return str(journal.get("location", row.get("location", "")))

static func name(row: Dictionary, tab: int, locale: String = "") -> String:
	if tab == 1: return part(str(row.id), "name", locale)
	if tab == 4: return goal(row, locale).name
	if tab == 2: return text("Region %s / %s", locale) % [Records.saved_integer(row.get("x", "?")), Records.saved_integer(row.get("z", "?"))]
	return str(row.get("name", text("Unbekannte Art", locale)))

static func source(id: String, state: Dictionary, locale: String = "") -> String:
	var unlocks: Dictionary = state.get("unlocked_parts", {})
	if not unlocks.has(id): return text("Noch gesperrt · weitere Arten beobachten", locale)
	var unlock: Dictionary = Records.as_dictionary(unlocks[id])
	var species: Dictionary = state.get("discovered_species", {})
	var key: String = str(unlock.get("species_key", ""))
	if not key.is_empty() and species.get(key) is Dictionary:
		return text("Entdeckt bei %s · %s", locale) % [species[key].get("name", text("unbekannter Art", locale)), location(species[key], locale)]
	match str(unlock.get("reason", "")):
		"Starter part": return text("Von Beginn an verfügbar", locale)
		"Species discovery": return text("Durch Artenentdeckung · ursprüngliche Art nicht vermerkt", locale)
		"Migrated creature save": return text("Aus deinem bisherigen Kreaturenentwurf übernommen", locale)
	return text("Bereits freigeschaltet", locale)

static func part_rows(state: Dictionary, query: String, category: String, status: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in Records.part_rows(state, "", category, status):
		var aliases := ""
		for locale: String in ["de", "en"]:
			aliases += " " + part(row.id, "name", locale) + " " + source(row.id, state, locale) + " " + text(Records.CATEGORIES.get(row.category, row.category), locale)
		if query.strip_edges().is_empty() or aliases.to_lower().contains(query.strip_edges().to_lower()): result.append(row)
	return result

static func goal(row: Dictionary, locale: String = "") -> Dictionary:
	var display: Dictionary = row.duplicate()
	if row.get("kind") == "part":
		display.name = part(str(row.key), "name", locale)
	else:
		display.name = text(str(row.get("name", "")), locale)
	display.unit = text(str(row.get("unit", "")), locale)
	var description: String = str(row.get("description", ""))
	match str(row.get("id", "")):
		"species.first": description = "Entdecke deine erste Tierart. Öffne mit %s den Scanmodus und halte ein Tier im Fadenkreuz, bis der Kreis voll ist."
		"role.swimmer": description = "Entdecke eine wasserbewohnende Tierart. Suche an Gewässern und scanne sie mit %s."
	display.description = text(description, locale)
	if row.get("id") in ["species.first", "role.swimmer"]:
		display.description = display.description % Records.KeyHints.binding_label("inspection_mode")
	return display

static func goals(state: Dictionary, query: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in Research.rows(state):
		var aliases := ""
		for locale: String in ["de", "en"]:
			var display := goal(row, locale)
			aliases += " " + display.name + " " + display.description
		if query.strip_edges().is_empty() or aliases.to_lower().contains(query.strip_edges().to_lower()): result.append(row)
	return result

static func discovery_search(row: Dictionary) -> String:
	var aliases := ""
	for locale: String in ["de", "en"]:
		aliases += " " + text(Records.ROLES.get(str(row.get("role", "")), "Noch nicht bekannt"), locale) + " " + location(row, locale)
	return aliases

static func hint(state: Dictionary, health: float = 1.0, thirst: float = 1.0, hunger: float = 1.0) -> String:
	if health <= 0.0: return text("Zurück zum Nest · nach der Erholung kannst du weiter erkunden.")
	if thirst < 0.3: return text("Wasser suchen · gehe ans Wasser und trinke mit Linksklick.")
	if hunger < 0.3: return text("Nahrung suchen · nutze Linksklick an Nahrung, die zu deiner Kreatur passt.")
	var key := "Deine erste Art · %s öffnet den Scanmodus. Halte ein Tier im Fadenkreuz, bis der Kreis voll ist." if Records.as_dictionary(state.get("discovered_species", {})).is_empty() else "Weiter entdecken · scanne mit %s unbekannte Arten. Neue Teile findest du im Editor mit F2."
	return text(key) % Records.KeyHints.binding_label("inspection_mode")
