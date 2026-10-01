extends RefCounted
## Presentation only; design names, catalogue IDs and placement UIDs stay literal.
const Text = preload("res://core/localization/ui_text.gd")

static func message(key: String, values: Dictionary = {}) -> Dictionary:
	return {"key": key, "values": values}

static func render(copy: Variant) -> String:
	if copy is String:
		return Text.text(copy)
	var values: Dictionary = copy.get("values", {}).duplicate()
	for key: Variant in values:
		if values[key] is Dictionary:
			values[key] = render(values[key])
	return Text.format_text(copy.key, values)

static func bind(control: Control, property: String, copy: Variant) -> void:
	control.set_meta("building_copy_" + property, copy)
	control.set(property, render(copy))

static func part(part_id: String, field: String = "name") -> Variant:
	var definition: Dictionary = load("res://civilization/buildings/building_part_library.gd").get_part(part_id)
	if definition.is_empty():
		return message("BEDITOR_UNKNOWN_PART", {"id": part_id}) if field == "name" else ""
	return message("BEDITOR_PART_" + part_id.to_upper() + "_" + field.to_upper())

static func refresh(node: Node) -> void:
	for property: String in ["text", "tooltip_text", "placeholder_text"]:
		if node.has_meta("building_copy_" + property):
			node.set(property, render(node.get_meta("building_copy_" + property)))
	if node is OptionButton:
		for index in node.item_count:
			var key: String = str(node.get_meta("building_option_%d" % index, ""))
			if not key.is_empty():
				node.set_item_text(index, render(key))
	for child in node.get_children():
		refresh(child)

static func validation(errors: Array[String]) -> String:
	var translated: Array[String] = []
	for error: String in errors:
		match error:
			"Building contains no parts.": translated.append(render("BEDITOR_EMPTY"))
			"Building needs at least one structural mass.": translated.append(render("BEDITOR_NEEDS_STRUCTURE"))
			"Assembly type is missing.": translated.append(render("BEDITOR_TYPE_MISSING"))
			_:
				# Translate the validator's fixed sentences while retaining its literal IDs.
				if error.begins_with("Unknown part '"):
					translated.append(render(message("BEDITOR_UNKNOWN_PART", {"id": error.trim_prefix("Unknown part '").trim_suffix("'.")})))
				elif error.begins_with("Duplicate part UID '"):
					translated.append(render(message("BEDITOR_DUPLICATE_UID", {"id": error.trim_prefix("Duplicate part UID '").trim_suffix("'.")})))
				elif error.begins_with("Part ") and error.ends_with(" is invalid."):
					translated.append(render(message("BEDITOR_INVALID_PART", {"index": error.trim_prefix("Part ").trim_suffix(" is invalid.")})))
				else:
					translated.append(render(message("BEDITOR_VALIDATION_CODE", {"code": error})))
	return "\n• ".join(translated)
