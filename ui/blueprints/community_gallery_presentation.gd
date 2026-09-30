extends RefCounted
## Read-only presentation. Service v1 deliberately has no requirements field.
const Text = preload("res://core/localization/ui_text.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")


static func origin(entry: Dictionary, endpoint: String) -> String:
	var author: String = str(entry.get("author", ""))
	if author.is_empty(): author = Text.text("BP_AUTHOR_UNKNOWN")
	return Text.format_text("CG_ORIGIN", {"author": author, "service": endpoint})


static func revision(entry: Dictionary) -> String:
	return Text.format_text("CG_REVISION", {"id": entry.design_id, "revision": int(entry.revision), "bytes": int(entry.bytes)})


static func requirements(package: Dictionary, prepare: Callable) -> String:
	if package.is_empty(): return Text.text("CG_REQUIREMENTS_UNKNOWN")
	var checked: Dictionary = Package.inspect(package)
	if not checked.ok: return error(checked)
	var names: Array[String] = []
	for id: String in checked.required_parts:
		var part: Dictionary = Package.Parts.get_part(id)
		names.append(Text.text(str(part.get("name", id))))
	var result: String = Text.format_text("CG_REQUIREMENTS", {"parts": ", ".join(names)})
	result += "\n" + Text.format_text("BP_COMPLEXITY", {"count": checked.stats.complexity, "limit": checked.stats.complexity_limit})
	if prepare.is_valid():
		var ready: Dictionary = prepare.call(package.duplicate(true))
		if ready.ok: result += "\n" + Text.text("BP_AVAILABLE")
		elif ready.get("code", "") == "locked_parts":
			var missing: Array[String] = []
			for id in ready.get("missing_parts", []):
				missing.append(Text.text(str(Package.Parts.get_part(str(id)).get("name", id))))
			result += "\n" + Text.format_text("BP_LOCKED", {"parts": ", ".join(missing)})
		else: result += "\n" + error(ready)
	else: result += "\n" + Text.text("CG_USE_LOCAL")
	return result


static func error(result: Dictionary) -> String:
	var code: String = str(result.get("code", "invalid_package"))
	var key: String = {
		"not_configured": "CG_UNAVAILABLE", "invalid_endpoint": "CG_UNAVAILABLE",
		"network_error": "CG_OFFLINE", "request_failed": "CG_OFFLINE", "timeout": "CG_TIMEOUT",
		"cancelled": "CG_CANCELLED", "invalid_query": "CG_QUERY_LIMIT", "busy": "CG_BUSY",
		"http_error": "CG_HTTP_ERROR", "page_budget": "CG_PAGE_BUDGET",
		"no_next_page": "CG_END", "library_unreadable": "BP_ERROR_LIBRARY",
		"library_full": "BP_ERROR_FULL", "write_failed": "BP_ERROR_WRITE",
		"revision_conflict": "BP_ERROR_CONFLICT", "no_campaign": "BP_ERROR_CAMPAIGN",
		"phase_not_editable": "BP_ERROR_PHASE", "complexity_exceeded": "BP_ERROR_COMPLEXITY",
		"protected_target": "BP_ERROR_TARGET", "unsupported_service_version": "CG_SERVICE_VERSION",
	}.get(code, "CG_INVALID_RESPONSE")
	return Text.format_text(key, {"status": result.get("status", 0)})
