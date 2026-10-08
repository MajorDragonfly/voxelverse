extends RefCounted
## Synchronous owner adapter. Never retain a village/member/actor across a load.
const Model = preload("res://world/tribe/resident_equipment_model.gd")

static func command(controller: Node, request: Dictionary) -> Dictionary:
	if not controller.is_active(): return {"ok": false, "code": "EQUIPMENT_INACTIVE"}
	if controller.selected != [request.get("resident_id", "")]: return {"ok": false, "code": "EQUIPMENT_STALE"}
	if controller.SiteTransport.bound(controller.body(), str(request.resident_id)):
		return {"ok": false, "code": "EQUIPMENT_BUSY"}
	var data: Dictionary = controller.village()
	var before: Dictionary = data.duplicate(true)
	var result: Dictionary = Model.command(data, request)
	if result.ok:
		# The existing host owns SaveGameService and restores the canonical
		# village (including stock, IDs and both owners) on an atomic write error.
		if not controller._save_economy(before): result = {"ok": false, "code": "EQUIPMENT_SAVE_FAILED"}
	controller.status = str(result.code)
	controller.panel.refresh()
	return result
