extends RefCounted
## Read-only presentation of the existing ledgers. Never part of a save.
const Economy = preload("res://world/tribe/village_economy.gd")
const Construction = preload("res://world/tribe/village_construction.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")

static func rows(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var construction: Dictionary = Construction.summary(data).get("materials", {})
	for kind: String in Economy.Resources.IDS:
		var material: Dictionary = construction.get(kind, {})
		var carried: int = 0
		for member: Dictionary in data.members:
			if member.cargo == kind: carried += 1
		result[kind] = {"resource": Presentation.resource_title(kind),
			"stored": int(data.stock.get(kind, 0)), "capacity": int(Economy.Resources.definition(kind).capacity),
			"reserved": int(material.get("reserved", 0)), "carried": carried,
			"delivered": int(material.get("delivered", 0)), "pending": Economy.pending(data, kind),
			# This is capacity held at BOTH endpoints, not extra stored goods.
			"freight_capacity": Economy.Freight.amount(data, "held", kind)}
	return result

static func detail(row: Dictionary) -> String:
	var lines := PackedStringArray([Text.format_text("TRIBE_STORAGE_AMOUNT", row)])
	for field: String in ["reserved", "carried", "delivered", "pending", "freight_capacity"]:
		if int(row[field]) > 0:
			lines.append(Text.format_text("TRIBE_STORAGE_" + field.to_upper(), {"amount": row[field]}))
	return "\n".join(lines)

static func tooltip(data: Dictionary) -> String:
	var lines := PackedStringArray([Text.text("TRIBE_STORAGE_TITLE")])
	for row: Dictionary in rows(data).values():
		lines.append(Text.format_text("TRIBE_STORAGE_COMPACT", row))
	lines.append(Text.text("TRIBE_STORAGE_HINT"))
	return "\n".join(lines)
