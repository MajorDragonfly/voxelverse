extends RefCounted
## Disposable read model. Progression remains the sole discovery/save owner.
## Index metadata once; copy full observations only for a visible preview.
const Records = preload("res://core/discovery/discovery_records.gd")
const PAGE_SIZE: int = 100
var state: Dictionary = {}
var _source: WeakRef
var _matches: Array[String] = []
var _query_key: Array = []
var queries: int = 0
var detail_reads: int = 0

func clear() -> void:
	state.clear()
	_source = null
	_matches.clear()
	_query_key.clear()

func bind(source: Node, profile_reader: Callable) -> void:
	clear()
	_source = weakref(source)
	state = {"discovery_points": source.get("discovery_points"),
		"unlocked_parts": source.get("unlocked_parts").duplicate(true),
		"research": source.call("get_research_settings"), "discovered_species": {}, "discovered_regions": {}}
	for section in ["discovered_species", "discovered_regions"]:
		var entries: Dictionary = source.get(section)
		for key in entries:
			if not entries[key] is Dictionary: continue
			var entry: Dictionary = entries[key]
			var row: Dictionary = {}
			for field in ["name", "role", "world_seed", "species_seed", "x", "z", "body_id", "unlocked_part"]:
				var value: Variant = entry.get(field)
				if value is String or value is int or value is float or value is bool: row[field] = value
			row.key = str(key)
			row.location = Records.location_for(entry)
			row.journal = {"location": row.location}
			if section == "discovered_species":
				row.role_label = Records.ROLES.get(str(row.get("role", "")), "Noch nicht bekannt")
				row.domestic_roles = _roles(entry, profile_reader)
			else:
				row.name = "Region %s / %s" % [Records.saved_integer(row.get("x", "?")), Records.saved_integer(row.get("z", "?"))]
			state[section][str(key)] = row

func _roles(entry: Dictionary, reader: Callable) -> Array:
	# Feed only the D1 payload to the existing reader. Filtering never decodes
	# every observed body's mesh/attachments just to obtain a role label.
	var journal: Dictionary = Records.as_dictionary(entry.get("journal", {}))
	var visual: Dictionary = Records.as_dictionary(journal.get("visual", {}))
	if journal.get("version") != 1 or not visual.get("body") is Dictionary or not visual.get("parts") is Array: return []
	var species: Dictionary = Records.as_dictionary(visual.get("species", {}))
	var compact: Dictionary = {"scan": entry.get("scan", {}), "journal": {"version": 1,
		"visual": {"body": {}, "parts": [], "species": {"domestication": species.get("domestication")}}}}
	var profile: Dictionary = reader.call(compact) if reader.is_valid() else {}
	return profile.get("roles", []).duplicate()

func page(kind: String, query: String, role: String, requested_page: int, role_labels: Dictionary = {}) -> Dictionary:
	var normalized: String = query.strip_edges().to_lower()
	var query_key: Array = [kind, normalized, role, role_labels]
	var entries: Dictionary = state.get("discovered_species" if kind == "species" else "discovered_regions", {})
	if query_key != _query_key:
		_matches.clear()
		_query_key = query_key.duplicate(true)
		queries += 1
		for key: String in entries:
			var row: Dictionary = entries[key]
			if kind == "species":
				if role.begins_with("domestic:"):
					if role.trim_prefix("domestic:") not in row.domestic_roles: continue
				elif not role.is_empty() and role != row.get("role", ""): continue
			var searchable: String = "%s %s %s" % [row.get("name", ""), row.location, row.get("role_label", "")]
			for ability in row.get("domestic_roles", []): searchable += " " + str(role_labels.get(ability, ability))
			if not normalized.is_empty() and not searchable.to_lower().contains(normalized): continue
			_matches.append(key)
		_matches.sort_custom(func(a: String, b: String) -> bool:
			var first: Dictionary = entries[a]
			var second: Dictionary = entries[b]
			if kind == "species":
				var comparison: int = str(first.get("name", "")).naturalnocasecmp_to(str(second.get("name", "")))
				return a < b if comparison == 0 else comparison < 0
			return (first.location + first.name + a).naturalnocasecmp_to(second.location + second.name + b) < 0)
	var number: int = clampi(requested_page, 0, maxi((_matches.size() - 1) / PAGE_SIZE, 0))
	var rows: Array[Dictionary] = []
	for index in range(number * PAGE_SIZE, mini((number + 1) * PAGE_SIZE, _matches.size())):
		rows.append(entries[_matches[index]].duplicate(true))
	return {"rows": rows, "page": number, "total": _matches.size()}

func page_for(key: String) -> int:
	var index: int = _matches.find(key)
	return index / PAGE_SIZE if index >= 0 else -1

func species_detail(key: String) -> Dictionary:
	if _source == null or _source.get_ref() == null: return {}
	var entries: Dictionary = _source.get_ref().get("discovered_species")
	if not entries.get(key) is Dictionary: return {}
	detail_reads += 1
	var row: Dictionary = entries[key].duplicate(true)
	row.key = key
	row.role_label = Records.ROLES.get(str(row.get("role", "")), "Noch nicht bekannt")
	row.location = Records.location_for(row)
	return row
