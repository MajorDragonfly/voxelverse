extends RefCounted
## WEATHER-02. Immutable profile references belong to campaign bodies. Weather
## fronts still derive exclusively from the existing campaign clock.
const SCHEMA: int = 1
const REVISION: int = 1
const FIELD: String = "weather_climate"
const POLICY: String = "weather_policy"
const CATALOG: Dictionary = {
	"earth_temperate": {"atmosphere": "temperate", "temperature_scale": 1.0, "temperature_offset": 0.0, "moisture_scale": 1.0, "cloud_scale": 1.0, "precipitation_scale": 1.0},
	"arid": {"atmosphere": "temperate", "temperature_scale": 0.3, "temperature_offset": 0.65, "moisture_scale": 0.18, "cloud_scale": 0.45, "precipitation_scale": 0.35},
	"frozen": {"atmosphere": "temperate", "temperature_scale": 0.08, "temperature_offset": 0.0, "moisture_scale": 0.85, "cloud_scale": 0.9, "precipitation_scale": 0.7},
	"volcanic": {"atmosphere": "temperate", "temperature_scale": 0.1, "temperature_offset": 0.9, "moisture_scale": 0.0, "cloud_scale": 0.65, "precipitation_scale": 0.0},
	"airless": {"atmosphere": "none", "temperature_scale": 1.0, "temperature_offset": 0.0, "moisture_scale": 0.0, "cloud_scale": 0.0, "precipitation_scale": 0.0},
}

static func new_policy() -> Dictionary:
	return {"schema": SCHEMA, "origin_status": "pending", "origin_body_id": "", "protected_body_ids": []}

static func make_reference(body_id: String, profile_id: String, protected: bool = false) -> Dictionary:
	return {"schema": SCHEMA, "body_id": body_id, "profile_id": profile_id,
		"revision": REVISION, "home_protected": protected}

static func catalog() -> Dictionary:
	return CATALOG.duplicate(true)

static func prepare_body(campaign: Dictionary, body: Dictionary) -> Dictionary:
	var result: Dictionary = body.duplicate(true)
	var first: bool = campaign[POLICY].origin_status == "pending" and campaign.bodies.is_empty()
	# Fixed revision-1 selection, independent of creation order and global RNG.
	var choices: Array[String] = ["earth_temperate", "earth_temperate", "arid", "frozen", "volcanic", "airless"]
	var key: String = "%s:%d:weather-v1" % [body.id, int(body.seed)]
	var index: int = key.sha256_text().substr(0, 8).hex_to_int() % choices.size()
	result[FIELD] = make_reference(body.id, "earth_temperate" if first else choices[index], first)
	return result

static func commit_origin(campaign: Dictionary, body: Dictionary) -> void:
	# Called only after successful explicit creation, never on active-body reads.
	if campaign[POLICY].origin_status != "pending": return
	campaign[POLICY] = {"schema": SCHEMA, "origin_status": "known", "origin_body_id": body.id,
		"protected_body_ids": [body.id]}

static func migrate(campaign: Dictionary) -> void:
	if campaign.has(POLICY): return
	# Historical saves did not record the first planet. Current location, seed,
	# dictionary order and an established nest are not evidence of that origin.
	var protected: Array = []
	for body: Dictionary in campaign.bodies.values():
		protected.append(body.id)
		body[FIELD] = make_reference(body.id, "earth_temperate", true)
	protected.sort()
	campaign[POLICY] = {"schema": SCHEMA, "origin_status": "legacy_unknown", "origin_body_id": "",
		"protected_body_ids": protected}

static func unsupported_body(body: Dictionary) -> bool:
	if not body.has(FIELD): return false
	var value: Variant = body[FIELD]
	return not value is Dictionary or value.get("schema") != SCHEMA \
		or value.get("revision") != REVISION or not CATALOG.has(value.get("profile_id"))

static func unsupported_campaign(campaign: Dictionary) -> bool:
	if not campaign.has(POLICY): return false
	var value: Variant = campaign[POLICY]
	return not value is Dictionary or value.get("schema") != SCHEMA \
		or value.get("origin_status") not in ["pending", "known", "legacy_unknown"]

static func validate_body(body: Dictionary, campaign: Dictionary) -> String:
	if not body.has(FIELD):
		return "Planet climate reference missing." if campaign.has(POLICY) else ""
	if unsupported_body(body): return "Unsupported planet climate; source remains protected."
	var value: Dictionary = body[FIELD]
	if value.get("body_id") != body.get("id") or not value.get("home_protected") is bool:
		return "Invalid climate body binding or protection flag."
	if not campaign.has(POLICY): return "Climate reference without origin policy."
	var policy: Variant = campaign[POLICY]
	if not policy is Dictionary or not policy.get("protected_body_ids") is Array: return "Invalid climate protection policy."
	var protected: bool = body.id in policy.protected_body_ids
	if value.home_protected != protected or (protected and value.profile_id != "earth_temperate"):
		return "Protected planet must retain its mild climate."
	return ""

static func validate_campaign(campaign: Dictionary) -> String:
	if unsupported_campaign(campaign): return "Unsupported weather origin policy; source remains protected."
	var bodies: Dictionary = campaign.get("bodies", {})
	if campaign.has(POLICY):
		var policy: Dictionary = campaign[POLICY]
		if not policy.get("origin_body_id") is String or not policy.get("protected_body_ids") is Array:
			return "Invalid weather origin policy."
		var ids: Array = []
		for body: Dictionary in bodies.values(): ids.append(body.id)
		var seen: Array = []
		for id in policy.protected_body_ids:
			if not id is String or id not in ids or id in seen: return "Invalid protected planet identity."
			seen.append(id)
		match policy.origin_status:
			"pending":
				if not bodies.is_empty() or not seen.is_empty() or policy.origin_body_id != "": return "Pending origin already owns planets."
			"known":
				if policy.origin_body_id.is_empty() or seen != [policy.origin_body_id]: return "Home planet protection is missing."
			"legacy_unknown":
				if policy.origin_body_id != "": return "Historical origin must not be guessed."
	for body: Dictionary in bodies.values():
		var problem: String = validate_body(body, campaign)
		if not problem.is_empty(): return problem
	return ""

static func profile_for(body: Dictionary) -> Dictionary:
	if not body.has(FIELD): return CATALOG.earth_temperate.duplicate(true)
	if unsupported_body(body) or body[FIELD].get("body_id") != body.get("id"): return {}
	return CATALOG[body[FIELD].profile_id].duplicate(true)
