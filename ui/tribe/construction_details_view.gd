extends RefCounted
## Read-only projection of the existing construction summary. Prepaid projects
## have a cost deduction, but no material pickup/arrival ledger.
const Construction = preload("res://world/tribe/village_construction.gd")

static func read(data: Dictionary) -> Dictionary:
	var view: Dictionary = Construction.summary(data)
	if view.is_empty(): return view
	view["tracks_transport"] = Construction.Housing.material_project(data.project)
	view["project_id"] = str(data.project.get("id", data.project.get("attempt_id", "")))
	view["settlement_id"] = str(data.get("id", ""))
	# No per-unit installed-material counter exists. Do not derive one from
	# delivered stock or work percentage; cancellation returns all paid goods.
	view["installed"] = null
	if not view.tracks_transport:
		for row: Dictionary in view.materials.values():
			row["delivered"] = null
			row["reserved"] = null
			row["carried"] = null
	return view
