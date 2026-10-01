extends RefCounted
## Cosmetic commands only. The host owns history, preview and persistence.
const SkinStyle = preload("res://creatures/editor/creature_skin_style.gd")
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Contract = preload("res://assembly/core/blueprint_contract.gd")
const COLORS: Array[String] = ["base_color", "accent_color", "belly_color", "eye_color", "horn_color"]
const FIELDS: Array[String] = ["base_color", "accent_color", "belly_color", "eye_color", "horn_color", "skin_type", "skin_strength", "skin_scale"]

static func can_edit(blueprint: Dictionary) -> bool:
	return not blueprint.has("_protected_design_source") and Contract.version_error(blueprint, "creature").is_empty()

static func read(blueprint: Dictionary) -> Dictionary:
	var colors: Array[Color] = Surface.colors(blueprint)
	var result: Dictionary = {"base_color": colors[0].to_html(false), "accent_color": colors[1].to_html(false)}
	for key: String in ["belly_color", "eye_color", "horn_color"]:
		var fallback: Color = colors[0].lightened(0.26) if key == "belly_color" else (colors[1].lightened(0.15) if key == "eye_color" else Color("e3d5b0"))
		result[key] = SkinStyle.color(blueprint, key, fallback).to_html(false)
	result["pattern_strength"] = Blueprint.get_paint_intensity(blueprint)
	var copy: Dictionary = {"appearance": blueprint.get("appearance", {}).duplicate(true)}
	SkinStyle.normalize(copy)
	for key: String in ["skin_type", "skin_strength", "skin_scale"]:
		result[key] = copy.appearance[key]
	return result

static func apply(blueprint: Dictionary, command: Dictionary) -> Dictionary:
	if not can_edit(blueprint): return {}
	var result: Dictionary = blueprint.get("appearance", {}).duplicate(true)
	var paint: Dictionary = blueprint.get("paint", {}).duplicate(true)
	if command.get("reset", false):
		for key: String in FIELDS: result.erase(key)
		paint["intensity"] = 1.0
	else:
		for key: String in command:
			if key == "pattern_strength":
				if not (command[key] is float or command[key] is int) or not is_finite(float(command[key])): return {}
				paint["intensity"] = clampf(float(command[key]), 0.0, 1.0)
				continue
			if not FIELDS.has(key): return {}
			var value: Variant = command[key]
			if COLORS.has(key):
				var hex: String = str(value).trim_prefix("#")
				if hex.length() != 6 or not hex.is_valid_hex_number(false): return {}
				result[key] = hex.to_lower()
			elif key == "skin_type":
				if not SkinStyle.TYPES.has(value): return {}
				result[key] = value
			else:
				if not (value is float or value is int) or not is_finite(float(value)): return {}
				result[key] = clampf(float(value), 0.0 if key == "skin_strength" else 0.4, 1.0 if key == "skin_strength" else 2.5)
	if result == blueprint.get("appearance", {}) and paint == blueprint.get("paint", {}): return {}
	# Preserve all unknown appearance extensions, every body/part and identity.
	return {"appearance": result, "paint": paint}

static func palette_index(state: Dictionary) -> int:
	for index: int in SkinStyle.PALETTES.size():
		var matches: bool = true
		for key: String in COLORS:
			matches = matches and state[key] == SkinStyle.PALETTES[index][key]
		if matches: return index
	return -1
