extends RefCounted
## Declarative resource delivery; no stock or ownership state lives here.
const Resources = preload("res://world/tribe/resource_catalog.gd")
const Production = preload("res://world/tribe/production_catalog.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const SCHEMA: int = 2
const LEGACY_FIELDS: Array[String] = ["schema", "source_id", "body_id", "faction_id", "sequence", "amount", "position"]
const FIELDS: Array[String] = ["resource_id", "resource_revision", "recipe_id", "recipe_revision", "receipt_id"]

static func create(data: Dictionary, source: String, sequence: int, amount: int, position: Variant, recipe_id: String) -> Dictionary:
	var recipe: Dictionary = Production.definition(recipe_id)
	if recipe.is_empty(): return {}
	return {"schema": SCHEMA, "source_id": source, "body_id": data.body_id, "faction_id": data.faction_id,
		"sequence": sequence, "amount": amount, "position": position.duplicate(true),
		"resource_id": recipe.resource_id, "resource_revision": Resources.REVISION,
		"recipe_id": recipe_id, "recipe_revision": recipe.revision,
		"receipt_id": Ids.scoped("resource_batch", data.body_id, source + ":" + str(sequence))}

static func canonical(data: Dictionary, value: Variant) -> Dictionary:
	# Pure checked migration of schema-1 milk into a schema-2 view. Never mutate
	# old saves/receipts, round unfinished output, or normalize future schemas.
	if not value is Dictionary or (value.get("schema") != 1 and value.get("schema") != SCHEMA): return {}
	if value.get("body_id") != data.body_id or value.get("faction_id") != data.faction_id or not text_id(value.get("source_id")) or not integer(value.get("sequence"), 1, 1000000000) or not integer(value.get("amount"), 1, 48) or not Home.local_place(value.get("position"), data.anchor): return {}
	for field: Variant in value:
		if field not in LEGACY_FIELDS and field != "remaining" and (value.schema == 1 or field not in FIELDS): return {}
	var result: Dictionary
	if value.schema == 1:
		result = create(data, value.source_id, int(value.sequence), int(value.amount), value.position, Production.MILK)
	else:
		var recipe: Dictionary = Production.definition(str(value.get("recipe_id", "")))
		if recipe.is_empty() or value.get("recipe_revision") != recipe.revision or value.get("resource_id") != recipe.resource_id or value.get("resource_revision") != Resources.REVISION: return {}
		result = create(data, value.source_id, int(value.sequence), int(value.amount), value.position, value.recipe_id)
		if value.get("receipt_id") != result.receipt_id: return {}
	return JSON.parse_string(JSON.stringify(result))

static func resource_id(value: Dictionary) -> String:
	# Hot-path read of already validated state; no JSON or receipt hash per tick.
	return "milk" if value.schema == 1 else str(value.resource_id)

static func unsupported(value: Variant) -> bool:
	if not value is Dictionary: return false
	if (value.get("schema") != 1 and value.get("schema") != SCHEMA): return true
	if value.schema == 1: return false
	var recipe: Dictionary = Production.definition(str(value.get("recipe_id", "")))
	return recipe.is_empty() or value.get("recipe_revision") != recipe.revision or value.get("resource_revision") != Resources.REVISION or value.get("resource_id") != recipe.resource_id

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func text_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 200
