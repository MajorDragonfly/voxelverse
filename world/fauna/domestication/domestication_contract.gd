extends RefCounted
## D1 owns species suitability; ownership, trust and orders belong to D2.
const SCHEMA: int = 1
const GENERATOR_VERSION: String = "domestic_fauna_v1"
const ROLES: Array[String] = ["milk", "draught", "riding", "companion"]
const GROUPS: Array[String] = ["milk", "work", "companion"]
const LIMITS: Dictionary = {
	"trainability": [0.0, 1.0], "sociality": [0.0, 1.0], "bonding": [0.0, 1.0],
	"water_need": [0.0, 100.0], "strength": [0.0, 10000.0], "stamina": [0.0, 3600.0],
	"carry_capacity": [0.0, 1000.0], "milk_yield": [0.0, 100.0], "milk_interval": [0.0, 86400.0],
	"perception_range": [0.0, 100.0], "movement_speed": [0.1, 20.0],
}

static func suitability(group: String) -> Dictionary:
	var work: bool = group == "work"
	var milk: bool = group == "milk"
	return {"schema": SCHEMA, "roles": ["draught", "riding"] if work else [group],
		"tameable": true, "temperament": "calm" if group != "companion" else "social",
		"trainability": 0.9 if group == "companion" else 0.7, "sociality": 0.85, "bonding": 0.9 if group == "companion" else 0.6,
		"diet": ["plant"], "water_need": 8.0 if work else 4.0,
		"strength": 1800.0 if work else 500.0, "stamina": 180.0 if work else 120.0,
		"carry_capacity": 120.0 if work else 0.0,
		"milk_yield": 2.0 if milk else 0.0, "milk_interval": 300.0 if milk else 0.0,
		"perception_range": 18.0 if group == "companion" else 12.0,
		"movement_speed": 3.8 if group == "companion" else 2.8,
		"anatomy": {"locomotion": "ground", "min_support_legs": 4, "lactation": milk,
			"back_clear": work, "attachment_requirements": ["saddle", "harness"] if work else []}}

static func validate(value: Variant) -> String:
	if not value is Dictionary or not integer(value.get("schema"), SCHEMA, SCHEMA):
		return "Unsupported domestication schema."
	if not value.get("roles") is Array or value["roles"].is_empty():
		return "Missing domestication roles."
	var seen: Array = []
	for role in value["roles"]:
		if role not in ROLES or role in seen:
			return "Invalid or duplicate domestication role."
		seen.append(role)
	if value.get("tameable") != true or value.get("temperament") not in ["calm", "social"]:
		return "Invalid domestic temperament."
	if not value.get("diet") is Array or value["diet"].is_empty():
		return "Missing domestic diet."
	for food in value["diet"]:
		if food not in ["plant", "meat"]:
			return "Unsupported food affinity."
	for field in LIMITS:
		if not number(value.get(field), LIMITS[field][0], LIMITS[field][1]):
			return "Invalid domestic value: " + field
	var anatomy: Variant = value.get("anatomy")
	if not anatomy is Dictionary or anatomy.get("locomotion") != "ground" or not integer(anatomy.get("min_support_legs"), 4, 12) or not anatomy.get("attachment_requirements") is Array:
		return "Invalid domestic anatomy."
	if float(value["water_need"]) <= 0.0 or float(value["stamina"]) <= 0.0:
		return "Land animals require water and stamina."
	if "milk" in seen:
		if anatomy.get("lactation") != true or float(value["milk_yield"]) <= 0.0 or float(value["milk_interval"]) < 1.0:
			return "Milk requires lactation and a positive production interval."
	elif float(value["milk_yield"]) != 0.0 or float(value["milk_interval"]) != 0.0:
		return "Non-milk species must not produce milk."
	if "riding" in seen and (float(value["carry_capacity"]) < 100.0 or anatomy.get("back_clear") != true or "saddle" not in anatomy["attachment_requirements"]):
		return "Riding requires a clear back, saddle and carrying capacity."
	if "draught" in seen and (float(value["strength"]) < 1000.0 or "harness" not in anatomy["attachment_requirements"]):
		return "Draught requires strength and a harness."
	if "companion" in seen and (float(value["trainability"]) < 0.75 or float(value["bonding"]) < 0.75 or float(value["sociality"]) < 0.75):
		return "Companion requires learning, bonding and sociality."
	return ""

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return number(value, minimum, maximum) and float(value) == floorf(float(value))

## Lossless JSON snapshot of the complete runtime blueprint, including anchors.
## Unlike editor-file loaders this never normalizes/re-generates a saved design.
static func encode(value: Variant) -> Variant:
	if value is Vector3:
		return {"$vector3": [value.x, value.y, value.z]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = encode(value[key])
		return result
	if value is Array:
		return value.map(encode)
	return value

static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has("$vector3"):
			var v: Array = value["$vector3"]
			return Vector3(v[0], v[1], v[2])
		var result: Dictionary = {}
		for key in value:
			result[key] = decode(value[key])
		return result
	if value is Array:
		return value.map(decode)
	return value
