extends RefCounted
## Read-only presentation of the existing catalogue, evaluation and docking check.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const Text = preload("res://core/localization/ui_text.gd")
const CATEGORIES: Array[String] = ["", "Rumpf", "Antrieb", "Energie", "Fracht", "Hangar", "Forschung", "Besatzung"]
const CATEGORY_KEYS: Array[String] = ["SY_CATEGORY_ALL", "SY_CATEGORY_HULL", "SY_CATEGORY_DRIVE", "SY_CATEGORY_POWER", "SY_CATEGORY_CARGO", "SY_CATEGORY_HANGAR", "SY_CATEGORY_RESEARCH", "SY_CATEGORY_CREW"]
const ERRORS: Dictionary = {
	"ship.overlap": "SY_ERROR_OVERLAP", "ship.disconnected": "SY_ERROR_DISCONNECTED",
	"ship.no_hull": "SY_ERROR_NO_HULL", "ship.command_count": "SY_ERROR_COMMAND_COUNT",
	"ship.power_deficit": "SY_ERROR_POWER_DEFICIT", "ship.no_energy": "SY_ERROR_NO_ENERGY",
	"ship.thrust_deficit": "SY_ERROR_THRUST_DEFICIT", "ship.no_cargo": "SY_ERROR_NO_CARGO",
	"ship.no_landing_gear": "SY_ERROR_NO_LANDING", "ship.no_hangar": "SY_ERROR_NO_HANGAR",
	"ship.size_limit": "SY_ERROR_SIZE_LIMIT", "ship.module_role": "SY_ERROR_MODULE_ROLE",
	"ship.module_limit": "SY_ERROR_MODULE_LIMIT", "ship.hangar_too_small": "SY_ERROR_HANGAR_SMALL",
	"ship.invalid_design": "SY_ERROR_INVALID_DESIGN", "ship.write_failed": "SY_ERROR_WRITE",
	"ship.protected_original": "SY_ERROR_PROTECTED", "ship.different_design": "SY_ERROR_DIFFERENT",
	"ship.unsupported_version": "SY_ERROR_VERSION", "ship.unsupported_module": "SY_ERROR_MODULE_VERSION",
	"ship.unknown_module": "SY_ERROR_UNKNOWN_MODULE", "ship.file_missing": "SY_ERROR_MISSING",
	"future_version": "SY_ERROR_FUTURE", "ship.select_anchor": "SY_ERROR_ANCHOR",
	"ship.mirror_center": "SY_ERROR_MIRROR_CENTER", "ship.placement_input": "SY_ERROR_PLACEMENT",
	"ship.identity": "SY_ERROR_IDENTITY", "ship.read_failed": "SY_ERROR_READ",
	"ship.revision_limit": "SY_ERROR_REVISION", "blueprint_too_large": "SY_ERROR_FILE_SIZE",
}

static func dimensions(value: Vector3) -> String:
	return "%s × %s × %s" % [Text.number(value.x, 1), Text.number(value.y, 1), Text.number(value.z, 1)]

static func module_name(id: String) -> String:
	return Text.text("SY_MODULE_" + id.to_upper())

static func role_name(role: String) -> String:
	return Text.text("SY_ROLE_" + role.to_upper())

static func error(code: String) -> String:
	return Text.text(ERRORS[code]) if ERRORS.has(code) else Text.format_text("SY_ERROR_OTHER", {"code": code})

static func module_details(definition: Dictionary, part: Dictionary = {}) -> String:
	var size: Vector3 = definition.size if part.is_empty() else Ship.module_box(part, definition).size
	var rows: Array[String] = [Text.format_text("SY_MODULE_DETAILS", {"role": role_name(definition.role), "size": dimensions(size)})]
	if not part.is_empty(): rows.append(Text.format_text("SY_MODULE_ROTATION", {"yaw": Text.number(Ship.vector(part.rotation).y, 0)}))
	for stat: String in ["mass", "thrust", "power", "draw", "energy", "cargo", "seats", "research", "structure", "command", "landing", "cost"]:
		if definition.stats.has(stat):
			rows.append(Text.format_text("SY_STAT_" + stat.to_upper(), {"value": Text.number(definition.stats[stat], 0)}))
	if definition.has("bay_size"): rows.append(Text.format_text("SY_BAY_INTERIOR", {"size": dimensions(definition.bay_size)}))
	return "\n".join(rows)

static func issue_parts(issue: Dictionary, blueprint: Dictionary, compact: bool = false) -> String:
	var names: Array[String] = []
	for index: int in issue.parts:
		if index < 0 or index >= blueprint.parts.size(): continue
		names.append("#%02d %s" % [index + 1, module_name(blueprint.parts[index].part_id)])
	if names.is_empty(): return Text.text("SY_WHOLE_DESIGN")
	if compact and names.size() > 2:
		return Text.format_text("SY_MORE_MODULES", {"modules": ", ".join(names.slice(0, 2)), "count": names.size() - 2})
	return ", ".join(names)

static func issue_summary(issue: Dictionary, blueprint: Dictionary) -> String:
	var key: String = "SY_ISSUE_" + str(issue.code).trim_prefix("ship.").to_upper()
	var title: String = Text.text(key)
	if title == key: title = error(issue.code)
	var parts: Array[String] = []
	for index: int in issue.parts: parts.append("#%02d" % [index + 1])
	return title + (" · " + ", ".join(parts) if not parts.is_empty() else "")

static func issue_details(issue: Dictionary, blueprint: Dictionary) -> String:
	var key: String = "SY_FIX_" + str(issue.code).trim_prefix("ship.").to_upper()
	var hint: String = Text.text(key)
	if hint == key: hint = Text.text("SY_FIX_GENERIC")
	return error(issue.code) + "\n" + issue_parts(issue, blueprint) + "\n" + hint

static func hangar_report(host: Dictionary, guest: Dictionary) -> Dictionary:
	# The production check is the sole fit authority. This only explains it.
	var result: Dictionary = Ship.find_hangar_fit(host, guest)
	var a: Dictionary = Ship.evaluate(host)
	var b: Dictionary = Ship.evaluate(guest)
	var rows: Array[String] = [Text.format_text("SY_FIT_PAIR", {"host": host.name, "guest": guest.name, "host_revision": host.revision, "guest_revision": guest.revision})]
	if not a.ok or not b.ok:
		rows.append(error(result.code))
		for pair: Array in [[host, a], [guest, b]]:
			if pair[1].ok: continue
			rows.append(Text.format_text("SY_FIT_INVALID", {"name": pair[0].name, "count": pair[1].issues.size()}))
			for issue: Dictionary in pair[1].issues: rows.append("• " + issue_summary(issue, pair[0]))
	else:
		rows.append(Text.format_text("SY_FIT_GUEST", {"size": dimensions(b.bounds.size)}))
		for index in range(host.parts.size()):
			var part: Dictionary = host.parts[index]
			if not a.bays.has(part.uid): continue
			var available: Vector3 = a.bays[part.uid].size
			rows.append(Text.format_text("SY_FIT_BAY", {"number": index + 1, "size": dimensions(available)}))
			for yaw: int in [0, 90]:
				var size: Vector3 = b.bounds.size if yaw == 0 else Vector3(b.bounds.size.z, b.bounds.size.y, b.bounds.size.x)
				var attempt: Dictionary = Ship.hangar_fit(host, guest, part.uid, yaw)
				if attempt.ok:
					rows.append(Text.format_text("SY_FIT_ORIENTATION_OK", {"yaw": yaw, "size": dimensions(size), "space": dimensions(attempt.clearance)}))
				else:
					rows.append(Text.format_text("SY_FIT_ORIENTATION_FAIL", {"yaw": yaw, "size": dimensions(size), "excess": dimensions((size - available).max(Vector3.ZERO))}))
		rows.append(Text.format_text("SY_FIT_SUCCESS", {"guest": guest.name, "host": host.name, "yaw": result.yaw}) if result.ok else error(result.code))
	rows.append(Text.text("SY_FIT_SCOPE"))
	return {"ok": result.ok, "code": result.code, "result": result, "text": "\n".join(rows)}
