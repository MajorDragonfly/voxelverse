extends RefCounted
## Read-only comparisons; package validation and adoption remain with their owners.
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Text = preload("res://core/localization/ui_text.gd")
const EditorText = preload("res://creatures/editor/creature_editor_text.gd")


static func identity(package: Dictionary) -> String:
	return Text.format_text("BP_DESIGN_REVISION", {"id": package.design_id, "revision": int(package.revision)})


static func part_name(id: String) -> String:
	var definition: Dictionary = Package.Parts.get_part(id)
	return EditorText.part(definition) if not definition.is_empty() else id


static func origin(entry: Dictionary) -> String:
	var package: Dictionary = entry.package
	var lines: Array[String] = [Text.text("BP_BUILTIN" if entry.builtin else "BP_LOCAL"), identity(package)]
	lines.append(Text.format_text("BP_AUTHOR", {"author": package.author}) if not str(package.author).is_empty() else Text.text("BP_AUTHOR_UNKNOWN"))
	if not str(package.description).is_empty(): lines.append(package.description)
	if not package.tags.is_empty(): lines.append(Text.format_text("BP_TAGS", {"tags": ", ".join(package.tags)}))
	if not package.provenance.is_empty():
		lines.append(Text.format_text("BP_SOURCES", {"count": package.provenance.size()}))
		for source: Dictionary in package.provenance:
			var author: String = source.author if not str(source.author).is_empty() else Text.text("BP_AUTHOR_UNKNOWN")
			lines.append("• " + identity(source) + " · " + author)
	return "\n".join(lines)


static func compare(current: Dictionary, candidate: Dictionary) -> String:
	if current.is_empty() or not Package.Creature.Contract.inspect(current, "creature").ok:
		return Text.text("BP_COMPARE_UNAVAILABLE")
	var before: Dictionary = Package.Creature.serialize_snapshot(current)
	var after: Dictionary = Package.Creature.serialize_snapshot(candidate)
	if before.is_empty() or after.is_empty(): return Text.text("BP_COMPARE_UNAVAILABLE")
	Package.Creature.Contract.PartRevisions.pin_legacy(before)
	Package.Creature.Contract.PartRevisions.pin_legacy(after)
	var lines: Array[String] = []
	if before.body != after.body:
		lines.append(Text.text("BP_CHANGE_BODY"))
		lines.append(Text.format_text("BP_BODY_DIMENSIONS", {"before": _dimensions(current), "after": _dimensions(candidate)}))
	var old_parts: Dictionary = _counts(before.parts)
	var new_parts: Dictionary = _counts(after.parts)
	var ids: Array = old_parts.keys()
	for id: String in new_parts:
		if not id in ids: ids.append(id)
	ids.sort()
	for id: String in ids:
		var old_count: int = old_parts.get(id, 0)
		var new_count: int = new_parts.get(id, 0)
		if old_count != new_count:
			lines.append(Text.format_text("BP_CHANGE_PART", {"part": part_name(id), "before": old_count, "after": new_count}))
	if before.parts != after.parts or before.assembly.body_attachments != after.assembly.body_attachments:
		lines.append(Text.text("BP_CHANGE_PLACEMENT"))
	if before.paint != after.paint or before.appearance != after.appearance:
		lines.append(Text.text("BP_CHANGE_APPEARANCE"))
	var old_stats: Dictionary = Package.Creature.BaseBlueprint.calculate_stats(current)
	var new_stats: Dictionary = Package.Creature.BaseBlueprint.calculate_stats(candidate)
	for field: String in ["health", "speed", "attack", "defense", "perception", "grip", "diet_plant", "diet_meat", "swim", "flight", "hunger_drain", "complexity"]:
		var old_value: float = old_stats.get(field, 0)
		var new_value: float = new_stats.get(field, 0)
		if not is_equal_approx(old_value, new_value):
			lines.append(Text.format_text("BP_CHANGE_STAT", {"stat": Text.text("BP_METRIC_" + field.to_upper()), "before": Text.number(old_value, 2), "after": Text.number(new_value, 2)}))
	return Text.text("BP_COMPARE_CURRENT") + "\n" + (Text.text("BP_CHANGE_NONE") if lines.is_empty() else "\n".join(lines))


static func _counts(parts: Array) -> Dictionary:
	var result: Dictionary = {}
	for part: Dictionary in parts:
		for id: String in [part.part_id, part.end_part_id]:
			if not id.is_empty(): result[id] = int(result.get(id, 0)) + 1
	return result


static func _dimensions(blueprint: Dictionary) -> String:
	var shape: Vector3 = Package.Creature.BaseBlueprint.get_body_shape(blueprint) * Package.Creature.BaseBlueprint.get_body_scale(blueprint)
	return "%s / %s / %s" % [Text.number(shape.x, 2), Text.number(shape.y, 2), Text.number(shape.z, 2)]
