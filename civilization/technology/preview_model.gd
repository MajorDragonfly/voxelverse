extends RefCounted
## Ephemeral view state. It cannot import/save a campaign or award technology.
const Catalog = preload("res://civilization/technology/technology_catalog.gd")
var catalog: Dictionary = Catalog.read_catalog()
var facts: Dictionary = {}
var marks: Array[String] = []
var scenario: int = 0

func select_scenario(index: int) -> void:
	if index not in range(3): return
	scenario = index
	facts.clear()
	marks.clear()
	if index > 0:
		for rule: Dictionary in Catalog.requirements().values():
			if rule["supported"]: facts[rule["id"]] = true
	if index == 2 and Catalog.validate(catalog).is_empty():
		for node: Dictionary in catalog["nodes"]: marks.append(node["id"])

func status(id: String) -> Dictionary:
	return Catalog.describe(catalog, id, facts, marks)

func toggle_mark(id: String) -> bool:
	if id in marks:
		marks.erase(id)
		# Removing a foundation invalidates all transitively dependent marks.
		for iteration: int in range(marks.size() + 1):
			var changed: bool = false
			for marked: String in marks.duplicate():
				if not status(marked)["preview_ready"]:
					marks.erase(marked)
					changed = true
			if not changed: break
		return true
	if not status(id)["preview_ready"]: return false
	marks.append(id)
	return true
