extends RefCounted
## Read-only display of the host's copied D2 values. Names remain literal.
const Text = preload("res://core/localization/ui_text.gd")
const Catalogs = preload("res://localization/catalogs.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const ORDER_KEYS := {"follow": "OWNED_FOLLOW", "wait": "OWNED_WAIT", "home": "OWNED_HOME"}
const RESULT_KEYS := {
	"owned.unavailable": "OWNED_UNAVAILABLE", "owned.invalid": "OWNED_INVALID",
	"owned.scope_mismatch": "OWNED_SCOPE_MISMATCH", "owned.empty": "OWNED_EMPTY",
	"owned.no_matches": "OWNED_NO_MATCHES",
}

static func text(key: String, locale: String = "") -> String:
	if locale.is_empty(): return Text.text(key)
	for catalog: Translation in Catalogs.CATALOGS:
		if catalog.get_locale() == locale: return catalog.get_message(key)
	return key

static func format_text(key: String, values: Dictionary, locale: String = "") -> String:
	return Text._substitute(text(key, locale), values)

static func number(value: float, decimals: int = 1, locale: String = "") -> String:
	var result := String.num(value, decimals).trim_suffix(".0")
	var language := TranslationServer.get_locale() if locale.is_empty() else locale
	return result.replace(".", ",") if language.begins_with("de") else result

static func point(value: Variant, locale: String = "") -> String:
	if value is Dictionary:
		var direction: Array = Cube.direction(value.face, value.u, value.v)
		return format_text("OWNED_SPHERE_POINT", {
			"latitude": number(rad_to_deg(asin(clampf(direction[1], -1.0, 1.0))), 5, locale),
			"longitude": number(rad_to_deg(atan2(direction[2], direction[0])), 5, locale),
			"height": number(value.height, 1, locale)}, locale)
	return format_text("OWNED_PLANE_POINT", {"x": number(value[0], 1, locale), "y": number(value[1], 1, locale), "z": number(value[2], 1, locale)}, locale)

static func project(data: Dictionary, locale: String = "") -> Dictionary:
	var order: String = text("OWNED_NO_ORDER" if data.dead else ORDER_KEYS.get(data.order_code, "OWNED_UNKNOWN"), locale)
	if not data.dead:
		match data.order_code:
			"follow": order += " · " + (data.handler if not data.handler.is_empty() else text("OWNED_UNNAMED_HANDLER", locale))
			"wait": order += " · " + format_text("OWNED_WAIT_TARGET", {"point": point(data.wait_position, locale)}, locale)
			"home": order += " · " + format_text("OWNED_HOME_TARGET", {"point": point(data.home, locale)}, locale)
	return {"key": data.key,
		"name": data.name if not data.name.is_empty() else format_text("OWNED_UNNAMED_ANIMAL", {"id": data.key}, locale),
		"species": data.species if not data.species.is_empty() else format_text("OWNED_UNNAMED_SPECIES", {"id": data.species_id}, locale),
		"owner": data.owner if not data.owner.is_empty() else text("OWNED_YOUR_TRIBE", locale),
		"trust": format_text("OWNED_TRUST_VALUE", {"trust": number(data.trust_value, 1, locale)}, locale),
		"status": text("OWNED_DEAD" if data.dead else "OWNED_TAMED", locale), "dead": data.dead, "order": order,
		"location": (data.body if not data.body.is_empty() else text("OWNED_CURRENT_WORLD", locale)) + " · " + point(data.position, locale),
		"_display_data": data}

static func search_text(data: Dictionary) -> String:
	# Both installed languages remain searchable across an in-place switch.
	var values: Array[String] = []
	for language: String in ["de", "en"]:
		var row := project(data, language)
		for key: String in ["name", "species", "owner", "order", "location", "key", "status"]: values.append(row[key])
	return " ".join(values).to_lower()

static func result_text(code: String) -> String:
	return text(RESULT_KEYS.get(code, "OWNED_UNAVAILABLE"))

static func list_text(row: Dictionary) -> String:
	return format_text("OWNED_DEAD_NAME", {"name": row.name}) if row.dead else str(row.name)

static func detail_lines(row: Dictionary) -> Array[String]:
	return [format_text("OWNED_DETAIL", {"species": row.species, "owner_label": text("OWNED_LAST_OWNER" if row.dead else "OWNED_OWNER"), "owner": row.owner, "status": row.status, "trust": row.trust}),
		format_text("OWNED_LOCATION_DETAIL", {"order": row.order, "location": row.location}),
		format_text("OWNED_ID", {"id": row.key})]
