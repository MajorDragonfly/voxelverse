extends RefCounted
## Construction control uses the existing project, resident cargo and warehouse.
## Only arrived work returns goods; cancellation never creates a delivery reward.
const Economy = preload("res://world/tribe/village_economy.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const SCHEMA: int = 1

static func state(project: Dictionary) -> String:
	return str(project.get("control", {}).get("state", "active"))

static func assigned(project: Dictionary, member: Dictionary) -> bool:
	return not project.is_empty() and (member.order in ["build", project.kind] or member.get("paused_order", "") in ["build", project.kind] or (member.get("construction_id", "") != "" and member.construction_id == project.get("id", "")))

static func idle(data: Dictionary, member: Dictionary) -> bool:
	return state(data.project) == "paused" and assigned(data.project, member) and member.cargo == "" and member.stage not in ["meal", "drink"] and member.order in ["build", data.project.kind]

static func costs(project: Dictionary) -> Dictionary:
	return Housing.construction_costs(project) if Housing.material_project(project) else Economy.COSTS.get(project.get("kind"), {"tool": {"wood": 3, "stone": 2}, "garden": {"wood": 4, "stone": 1}}.get(project.get("kind"), {}))

static func cancellation_problem(data: Dictionary) -> String:
	if data.project.is_empty(): return "CONSTRUCTION_NONE"
	if state(data.project) == "recovering": return "CONSTRUCTION_RECOVERING"
	# All return cargo receives capacity before the command changes anything.
	for kind: String in costs(data.project):
		if Economy.reserve(data, kind) + int(costs(data.project)[kind]) > int(Economy.Resources.definition(kind).capacity): return "CONSTRUCTION_STORAGE_FULL"
	return ""

static func command(data: Dictionary, action: String) -> Dictionary:
	if data.project.is_empty(): return {"ok": false, "code": "CONSTRUCTION_NONE"}
	var project: Dictionary = data.project
	var current: String = state(project)
	if action not in ["pause", "resume", "cancel"]: return {"ok": false, "code": "CONSTRUCTION_INVALID"}
	if current == "recovering": return {"ok": false, "code": "CONSTRUCTION_RECOVERING"}
	if action == "pause" or action == "resume":
		var wanted: String = "paused" if action == "pause" else "active"
		if current == wanted: return {"ok": false, "code": "CONSTRUCTION_UNCHANGED"}
		project.control = {"schema": SCHEMA, "state": wanted}
		return {"ok": true, "code": "CONSTRUCTION_PAUSED" if wanted == "paused" else "CONSTRUCTION_RESUMED"}
	var problem: String = cancellation_problem(data)
	if not problem.is_empty(): return {"ok": false, "code": problem}
	if not Housing.material_project(project):
		for kind: String in costs(project): data.stock[kind] += costs(project)[kind]
		_finish(data)
		return {"ok": true, "code": "CONSTRUCTION_RECOVERED"}
	var refunded: Dictionary = project.materials.duplicate()
	for kind: String in refunded:
		data.stock[kind] += refunded[kind]
		project.materials[kind] = 0
	project.control = {"schema": SCHEMA, "state": "recovering", "refunded": refunded}
	if _all_returned(project):
		_finish(data)
		return {"ok": true, "code": "CONSTRUCTION_RECOVERED"}
	return {"ok": true, "code": "CONSTRUCTION_RECOVERY_STARTED"}

static func recovery_target(data: Dictionary, member: Dictionary) -> Variant:
	if member.construction_id != "": return data.anchor
	for amount: int in data.project.delivered_materials.values():
		if amount > 0: return data.project.entrance
	return data.anchor

static func recovery_step(data: Dictionary, member: Dictionary, effects: Array) -> void:
	var project: Dictionary = data.project
	if member.construction_id != "":
		if Home.distance(member.position, data.anchor) > 3.0: return
		var kind: String = member.cargo
		data.stock[kind] += 1
		project.control.refunded[kind] += 1
		member.cargo = ""
		member.construction_id = ""
		member.erase("cargo_source_id")
		member.stage = "outbound"
	elif member.cargo == "" and Home.distance(member.position, project.entrance) <= 3.0:
		for kind: String in project.delivered_materials:
			if int(project.delivered_materials[kind]) <= 0: continue
			project.delivered_materials[kind] -= 1
			member.cargo = kind
			member.construction_id = project.id
			member.stage = "return"
			break
	else: return
	effects.append({"kind": "changed"})
	if _all_returned(project):
		_finish(data)
		effects.append({"kind": "construction_recovered", "data": {"kind": project.kind}})

static func _all_returned(project: Dictionary) -> bool:
	for kind: String in costs(project):
		if int(project.control.refunded[kind]) != int(costs(project)[kind]): return false
	return true

static func _finish(data: Dictionary) -> void:
	var kind: String = data.project.kind
	for member: Dictionary in data.members:
		if member.order == kind:
			member.order = Economy.JOB_ORDER[member.profession]
			member.stage = "return" if member.cargo != "" else "outbound"
		if member.get("paused_order", "") == kind: member.paused_order = ""
	data.project = {}

static func unsupported(value: Variant) -> bool:
	if not value is Dictionary or not value.get("project") is Dictionary: return false
	var economy: Variant = value.get("economy")
	if value.project.has("control") or value.project.has("attempt_id"):
		if not economy is Dictionary or not Economy.integer(economy.get("schema"), 4, Economy.SCHEMA): return true
	var control: Variant = value.project.get("control")
	return control is Dictionary and (control.get("schema") != SCHEMA or control.get("state") not in ["active", "paused", "recovering"])

static func validate(data: Dictionary) -> String:
	var project: Dictionary = data.project
	if (project.has("control") or project.has("attempt_id")) and unsupported(data): return "Baustellensteuerung benötigt einen unterstützten Wirtschaftsvertrag."
	if project.has("attempt_id") and not Economy.text_id(project.attempt_id): return "Ungültiger Bauversuch."
	if not project.has("control"): return ""
	if data.get("economy", {}).get("schema", 0) < 4: return "Baustellensteuerung benötigt Wirtschaftsformat 4."
	var control: Variant = project.control
	if not control is Dictionary or control.get("schema") != SCHEMA or control.get("state") not in ["active", "paused", "recovering"]: return "Ungültige Baustellensteuerung."
	if control.state != "recovering":
		return "Unerwartete Materialrückgabe." if control.has("refunded") else ""
	if not Housing.material_project(project) or not control.get("refunded") is Dictionary or not project.get("materials") is Dictionary or not project.get("delivered_materials") is Dictionary or control.refunded.size() != costs(project).size(): return "Ungültiger Rückbauauftrag."
	for kind: String in costs(project):
		if not Economy.integer(control.refunded.get(kind), 0, costs(project)[kind]) or project.materials.get(kind) != 0: return "Ungültige Rückbaumenge."
	return ""

static func summary(data: Dictionary) -> Dictionary:
	if data.project.is_empty(): return {}
	var project: Dictionary = data.project
	var result: Dictionary = {"kind": project.kind, "state": state(project), "workers": 0, "blocked": 0, "materials": {}}
	for member: Dictionary in data.members:
		if assigned(project, member):
			result.workers += 1
			if member.blocked or member.order == "wait": result.blocked += 1
	for kind: String in costs(project):
		var cargo: int = 0
		for member: Dictionary in data.members:
			if member.construction_id != "" and member.cargo == kind: cargo += 1
		result.materials[kind] = {"required": costs(project)[kind], "reserved": project.get("materials", {}).get(kind, 0), "delivered": project.get("delivered_materials", {}).get(kind, costs(project)[kind]), "carried": cargo, "returned": project.get("control", {}).get("refunded", {}).get(kind, 0)}
	return result
