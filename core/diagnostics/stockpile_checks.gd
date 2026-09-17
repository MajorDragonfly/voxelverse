extends RefCounted
## Integration assertions against physical work, without asking the view to refresh.
const Inventory = preload("res://world/tribe/village_inventory_view.gd")
const Piles = preload("res://world/tribe/village_stockpiles.gd")

static func verify(tribe: Node) -> Array[String]:
	var failures: Array[String] = []
	if not is_instance_valid(tribe._visuals.stockpiles):
		return ["No village stockpile renderer."]
	var piles: Node = tribe._visuals.stockpiles
	var started: int = Time.get_ticks_msec()
	while piles.snapshot != Inventory.rows(tribe.village()) and Time.get_ticks_msec() - started < 1000:
		await tribe.get_tree().process_frame
	var rows: Dictionary = Inventory.rows(tribe.village())
	if piles.snapshot != rows: failures.append("Stockpile snapshot is stale after a real inventory change.")
	if piles.lots.size() != 7: failures.append("Missing resource storage area.")
	for kind: String in rows:
		var row: Dictionary = rows[kind]
		for field: String in ["stored", "reserved"]:
			var mesh: MultiMesh = piles.lots[kind][field].multimesh
			if mesh.instance_count != 12 or mesh.visible_instance_count != Piles.stage(row[field], row.capacity):
				failures.append("Incorrect or unbounded stockpile: " + kind + "/" + field)
		if int(row.stored) != int(tribe.village().stock[kind]):
			failures.append("Transit or reserved goods counted as free stock: " + kind)
	return failures
