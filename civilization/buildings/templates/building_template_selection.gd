extends RefCounted
## Optional narrow BuildingBuilder adapter. The editor still owns history/save/UI.
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
const Templates = preload("res://civilization/buildings/templates/building_templates.gd")


static func apply_to_editor(editor: Node, copy: Dictionary) -> bool:
	if not Blueprint.Contract.inspect(copy, "building").ok or not Blueprint.validate(copy).is_empty():
		return false
	var origin: Dictionary = copy.get("metadata", {}).get("source_template", {})
	var source: Dictionary = Templates.load_template(str(origin.get("template_id", "")))
	if source.is_empty() or str(copy.get("design_id", "")) == str(source.design_id) or int(copy.get("revision", -1)) != 0:
		return false
	editor.call("_record", "Use building template copy")
	editor.set("blueprint", copy.duplicate(true))
	editor.set("selected_part_index", -1)
	(editor.get("_name_edit") as LineEdit).text = str(copy.name)
	editor.call("_refresh_all")
	return true
