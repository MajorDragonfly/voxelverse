extends RefCounted
## Pure next-action advice; only OnboardingProgress decides the chapter/step.
const Model = preload("res://world/tribe/tribe_state.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Construction = preload("res://world/tribe/village_construction.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
const Work = preload("res://world/tribe/village_work.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Copy = preload("res://ui/frontend/guidance_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")

static func resolve(progress: RefCounted, context: Dictionary) -> Dictionary:
	var step: String = progress.tribal_step()
	if step.is_empty() or not context.get("active", false): return {}
	var data: Dictionary = context.get("village", {})
	# JSON restores integral values as floats; scalar comparison supports both
	# without rounding fractional/future versions into a known contract.
	var version: Variant = data.get("schema")
	if (version != Model.SCHEMA and version != Model.LEGACY_SCHEMA) or not data.get("members") is Array or not data.get("stock") is Dictionary or not data.get("project") is Dictionary:
		return {}
	if data.get("economy", {}).get("schema") != Economy.SCHEMA: return {}
	var selection: Array = context.get("selected", [])
	var selected: Array[Dictionary] = []
	for member: Dictionary in data.members:
		if member.id in selection: selected.append(member)
	if step == "tribe_camera": return _view(step, "camera")
	if step == "tribe_single":
		return _view(step, "single", {"count": selected.size()})
	if step == "tribe_group":
		return _view(step, "group", {"count": selected.size()})
	var project: Dictionary = data.project
	var observing_work: bool = step == "tribe_delivery" or (step in ["tribe_tool", "tribe_place", "tribe_finish"] and not project.is_empty())
	if not observing_work and selected.is_empty(): return _view(step, "selection")
	if not observing_work and selected.size() != selection.size(): return _view(step, "stale_selection")
	if context.get("navigation_pending", false): return _view(step, "paths")
	var relevant: Array[Dictionary] = []
	for member: Dictionary in data.members:
		if step in ["tribe_tool", "tribe_place", "tribe_finish"] and Construction.assigned(project, member):
			relevant.append(member)
		elif step == "tribe_delivery" and (member.order in Economy.RESOURCES + ["supply", "provision"] or _warehouse_cargo(member)):
			relevant.append(member)
		elif member.id in selection:
			relevant.append(member)
	for member: Dictionary in relevant:
		if member.get("blocked", false): return _view(step, "blocked", {"name": member.name})
	var rejection: Dictionary = context.get("rejection", {})
	if not rejection.is_empty():
		return _view(step, "order_rejected", {"reason": Presentation.legacy_status(str(rejection.reason))})
	if step in ["tribe_tool", "tribe_place", "tribe_finish"] and not project.is_empty():
		var state: String = Construction.state(project)
		if state == "paused": return _view(step, "build_paused")
		if state == "recovering": return _view(step, "build_recovering")
		var summary: Dictionary = Construction.summary(data)
		if int(summary.workers) == 0: return _view(step, "build_workers", {"order": Presentation.order_title(project.kind)})
		for resource: String in summary.materials:
			var material: Dictionary = summary.materials[resource]
			if int(material.delivered) < int(material.required):
				return _view(step, "build_materials", {"resource": Presentation.resource_title(resource),
					"delivered": material.delivered, "required": material.required, "carried": material.carried, "reserved": material.reserved})
		return _view(step, "build_working")
	if step in ["tribe_tool", "tribe_place", "tribe_finish"]:
		var kind: String = str(context.get("placement", ""))
		if kind.is_empty(): kind = "tool" if int(data.tools) == 0 else "forester"
		var costs: Dictionary = Model.COSTS.merged(Economy.COSTS).get(kind, {})
		for resource: String in costs:
			var deficit: int = int(costs[resource]) - int(data.stock.get(resource, 0))
			if deficit > 0:
				var carried: int = 0
				for member: Dictionary in data.members:
					if _warehouse_cargo(member) and member.cargo == resource: carried += 1
				if carried >= deficit:
					return _view(step, "materials_in_transit", {"count": deficit, "resource": Presentation.resource_title(resource)})
				var prerequisite: Dictionary = _resource(step, data, resource)
				if prerequisite.code != "gather": return prerequisite
				return _view(step, "materials", {"count": deficit, "carried": carried,
					"resource": Presentation.resource_title(resource), "order": Presentation.order_title(resource)})
		# Live preflight provides the actual site reason; never run navigation here.
		# Inventory is checked first, so a stale ghost cannot hide missing materials.
		if not str(context.get("placement", "")).is_empty():
			var preview: Dictionary = context.get("preview", {})
			if preview.is_empty(): return _view(step, "place_target")
			if not preview.get("ok", false):
				return _view(step, "placement_rejected", {"reason": Presentation.legacy_status(str(preview.get("reason", "")))})
			return _view(step, "place")
		return _view(step, "tool" if kind == "tool" else "choose_build")
	if step == "tribe_delivery":
		for member: Dictionary in data.members:
			if _warehouse_cargo(member): return _view(step, "cargo", {"name": member.name, "resource": Presentation.resource_title(member.cargo)})
		for member: Dictionary in data.members:
			if member.order in Economy.RESOURCES + ["supply", "provision"]: return _gathering(step, data, member)
		return _view(step, "order")
	if step == "tribe_supply":
		for member: Dictionary in selected:
			if float(member.hunger) < 95.0:
				if Economy.has_food(data): return _view(step, "feed")
				return _resource(step, data, "food")
			if float(member.hydration) < 95.0:
				if int(data.stock.water) > 0: return _view(step, "drink")
				return _resource(step, data, "water")
		return _view(step, "satisfied")
	if step == "tribe_order": return _resource(step, data, "wood")
	if step == "tribe_profession": return _view(step, "profession")
	if step == "tribe_workplace":
		return _view(step, "workplace" if not data.economy.stations.is_empty() else "no_workplace")
	return _view(step, "default")

static func _warehouse_cargo(member: Dictionary) -> bool:
	return not str(member.get("cargo", "")).is_empty() and str(member.get("construction_id", "")).is_empty() and str(member.get("care_pen_id", "")).is_empty()

static func _gathering(step: String, data: Dictionary, member: Dictionary) -> Dictionary:
	# gather_kind assigns task in its argument; supply a copy to remain read-only.
	var resource: String = Economy.gather_kind(data, member.duplicate(true))
	if resource.is_empty(): return _view(step, "gathering")
	if resource in data.deposits and int(Economy.source(data, member, resource).remaining) == 0:
		return _view(step, "assigned_source_empty", {"resource": Presentation.resource_title(resource)})
	return _resource(step, data, resource, true)

static func _resource(step: String, data: Dictionary, resource: String, working: bool = false) -> Dictionary:
	var values := {"resource": Presentation.resource_title(resource), "order": Presentation.order_title(resource)}
	if resource in ["water", "fiber"]:
		var station: String = "well" if resource == "water" else "fiberbed"
		if not data.economy.stations.keys().any(func(key: String) -> bool: return Economy.station_kind(key) == station):
			values["order"] = Presentation.order_title(station)
			return _view(step, "source_required", values)
	if resource in data.deposits and Economy.remaining(data, resource) == 0:
		return _view(step, "source_empty", values)
	return _view(step, "gathering" if working else "gather", values)

static func _view(step: String, code: String, values: Dictionary = {}) -> Dictionary:
	return {"step": step, "code": code, "values": values.duplicate(true)}

static func render(view: Dictionary) -> Dictionary:
	if view.is_empty(): return {}
	var step: String = view.step
	var prefix: String = "TG_" + str(view.code).to_upper()
	var reason: String = Text.format_text(prefix + "_REASON", view.values)
	var next: String = Text.format_text(prefix + "_NEXT", view.values)
	if view.code == "default":
		reason = Copy.title(step)
		next = Copy.hint(step)
	return {"title": Copy.title(step), "reason": reason, "next": next,
		"detail": Copy.hint(step, true), "step": step, "code": view.code}
