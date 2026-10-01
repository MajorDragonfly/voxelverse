extends RefCounted
## Read-only D2 projection. The host owns the controller, context and name lookup.
## No inferred ownership, generated names, command callbacks or persistence.
signal changed
const Presentation = preload("res://ui/discovery/owned_animal_presentation.gd")
const STATE_PATH := "res://world/domestication/animal_state.gd"
const Suitability = preload("res://ui/discovery/animal_suitability.gd")
const ORDERS := {"follow": "Folgen", "wait": "Warten", "home": "Heimkehr"}
var _source: WeakRef
var _context: Callable
var _names: Callable
var _validator: Script
var _scope: Array = []

func bind_source(source: Object, context: Callable, names: Callable = Callable()) -> bool:
	unbind()
	if not is_instance_valid(source) or not context.is_valid() or not source.has_method("owned_animals") or not source.has_signal("animal_changed"):
		return false
	if not ResourceLoader.exists(STATE_PATH):
		return false
	_validator = load(STATE_PATH) as Script
	if _validator == null or not _validator.has_method("validate"):
		return false
	_source = weakref(source)
	_context = context
	_names = names
	source.connect("animal_changed", _on_animal_changed)
	check_context()
	return true

func unbind() -> void:
	var source: Object = _source.get_ref() if _source != null else null
	if is_instance_valid(source) and source.is_connected("animal_changed", _on_animal_changed):
		source.disconnect("animal_changed", _on_animal_changed)
	_source = null
	_context = Callable()
	_names = Callable()
	_validator = null
	_scope = []

func check_context() -> void:
	# Cheap identity check while the page is open. Loading into the same controller
	# has no D2 event; the host also calls the journal's refresh_owned_animals().
	var source: Object = _source.get_ref() if _source != null else null
	var context := _read_context()
	var registry: Dictionary = _registry(source)
	var scope := [is_instance_valid(source), context.get("campaign_id"), context.get("body_id"),
		context.get("faction_id"), registry.get("schema"), registry.get("campaign_id"), registry.get("body_id")]
	if scope != _scope:
		_scope = scope
		changed.emit()

func read(query: String = "", life_filter: String = "living", sort_code: String = "name", order_filter: String = "", observations: Dictionary = {}) -> Dictionary:
	var source: Object = _source.get_ref() if _source != null else null
	if not is_instance_valid(source) or _validator == null:
		return _unavailable("owned.unavailable")
	var context := _read_context()
	var registry := _registry(source)
	var error := scope_code(registry, context, _validator)
	if not error.is_empty():
		return _unavailable(error)
	var rows: Array[Dictionary] = []
	var owned_count := 0
	var order_codes: Array[String] = []
	var role_cache: Dictionary = {}
	for animal: Dictionary in source.call("owned_animals", context["faction_id"], true):
		# Explicit owner/body guard also protects a reused host binding after travel.
		if animal.get("owner_faction_id") != context["faction_id"] or animal.get("body_id") != context["body_id"] or animal.get("status") not in ["tamed", "dead"]:
			continue
		owned_count += 1
		var dead: bool = animal["status"] == "dead"
		if (life_filter == "living" and dead) or (life_filter == "dead" and not dead):
			continue
		var order_code: String = "none" if dead else str(animal.order)
		if order_code not in order_codes: order_codes.append(order_code)
		if not order_filter.is_empty() and order_code != order_filter: continue
		if not role_cache.has(animal.species_id):
			role_cache[animal.species_id] = _observed_roles(animal, observations)
		var row := _row(animal, role_cache[animal.species_id])
		var haystack: String = Presentation.search_text(row._display_data)
		if query.strip_edges().is_empty() or haystack.to_lower().contains(query.strip_edges().to_lower()):
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: Dictionary = a._display_data
		var second: Dictionary = b._display_data
		var compared := 0
		match sort_code:
			"species":
				if first.species.is_empty() != second.species.is_empty(): return not first.species.is_empty()
				compared = str(first.species).naturalnocasecmp_to(str(second.species))
			"trust":
				if first.trust_value != second.trust_value: return first.trust_value > second.trust_value
			"order":
				var rank := ["follow", "wait", "home", "none"]
				var first_order: String = "none" if first.dead else first.order_code
				var second_order: String = "none" if second.dead else second.order_code
				compared = rank.find(first_order) - rank.find(second_order)
		if compared == 0: compared = str(first.name).naturalnocasecmp_to(str(second.name))
		return str(a.key) < str(b.key) if compared == 0 else compared < 0)
	order_codes.sort()
	var code := "owned.empty" if owned_count == 0 else "owned.no_matches"
	return {"available": true, "rows": rows, "code": code, "message": Presentation.result_text(code), "order_codes": order_codes, "owned_count": owned_count}

static func scope_error(registry: Dictionary, context: Dictionary, validator: Script) -> String:
	# Preserve the existing diagnostic API; the display uses stable result codes.
	return {"owned.invalid": "Dieser Tierbestand kann derzeit nicht gelesen werden.",
		"owned.scope_mismatch": "Für deinen aktuellen Stamm und diese Welt ist kein Tierbestand verfügbar."}.get(scope_code(registry, context, validator), "")

static func scope_code(registry: Dictionary, context: Dictionary, validator: Script) -> String:
	if validator == null or not validator.has_method("validate") or not validator.call("validate", registry).is_empty():
		return "owned.invalid"
	if not context.get("faction_id") is String or context["faction_id"].is_empty() or context.get("campaign_id") != registry["campaign_id"] or context.get("body_id") != registry["body_id"]:
		return "owned.scope_mismatch"
	return ""

func _observed_roles(animal: Dictionary, observations: Dictionary) -> Array:
	# Only exact stable species/body identity and a completed, supported D1 scan.
	# Neither display names nor the unobserved fauna catalog can establish evidence.
	var contract := Suitability.contract()
	for value: Variant in observations.values():
		if not value is Dictionary or value.get("id") != animal.species_id or value.get("body_id") != animal.body_id: continue
		var profile: Dictionary = Suitability.read(value, contract)
		if not profile.is_empty(): return profile.get("roles", []).duplicate()
	return []

func _row(animal: Dictionary, roles: Array = []) -> Dictionary:
	var data := {"key": animal.object_id, "species_id": animal.species_id, "roles": roles.duplicate(),
		"name": _name("animal", animal.object_id), "species": _name("species", animal.species_id),
		"owner": _name("faction", animal.owner_faction_id), "body": _name("body", animal.body_id),
		"handler": _name("handler", animal.handler_id), "trust_value": float(animal.trust),
		"dead": animal.status == "dead", "order_code": animal.order,
		"position": animal.position.duplicate(true), "home": animal.home.duplicate(true),
		"wait_position": animal.wait_position.duplicate(true)}
	return Presentation.project(data)

func _name(kind: String, id: String, fallback: String = "") -> String:
	var value: Variant = _names.call(kind, id) if _names.is_valid() else null
	return value.strip_edges() if value is String and not value.strip_edges().is_empty() else fallback

func _point(point: Variant) -> String:
	return Presentation.point(point)

static func number(value: Variant) -> String:
	return Presentation.number(float(value))

func _read_context() -> Dictionary:
	var value: Variant = _context.call() if _context.is_valid() else null
	return value if value is Dictionary else {}

func _registry(source: Object) -> Dictionary:
	var value: Variant = source.get("registry") if is_instance_valid(source) else null
	return value if value is Dictionary else {}

func _unavailable(code: String) -> Dictionary:
	return {"available": false, "rows": [], "code": code, "message": Presentation.result_text(code)}

func _on_animal_changed(_object_id: String, _code: String) -> void:
	changed.emit()
