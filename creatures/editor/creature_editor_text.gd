extends RefCounted
## Presentation only: catalog IDs and player-authored names remain untouched.
const Text = preload("res://core/localization/ui_text.gd")
const LEGACY_STATUS := {
	"Nothing to undo.": "EDITOR_STATUS_UNDO_EMPTY",
	"Nothing to redo.": "EDITOR_STATUS_REDO_EMPTY",
	"Undo applied.": "EDITOR_STATUS_UNDO",
	"Redo applied.": "EDITOR_STATUS_REDO",
	"Surface snap: ON": "EDITOR_STATUS_SNAP_ON",
	"Surface snap: OFF": "EDITOR_STATUS_SNAP_OFF",
	"Select a modular part first.": "EDITOR_STATUS_ATTACH_SELECT",
	"Selected part attached to the body surface.": "EDITOR_STATUS_ATTACHED",
	"This part has not been discovered yet.": "EDITOR_STATUS_LOCKED",
	"Part placed. Drag it directly on the creature surface.": "EDITOR_STATUS_ADDED",
}

static func text(key: String) -> String:
	return Text.text(key)

static func format_text(key: String, values: Dictionary) -> String:
	return Text.format_text(key, values)

static func part(definition: Dictionary, field: String = "name") -> String:
	if definition.is_empty():
		return text("EDITOR_PART") if field == "name" else ""
	var key := "EDITOR_PART_" + str(definition.get("id", "")).to_upper() + "_" + field.to_upper()
	var translated := text(key)
	return str(definition.get(field, "")) if translated == key else translated

static func formatted(key: String, arguments: Array) -> Dictionary:
	return {"key": key, "arguments": arguments}

static func render(message: Variant) -> String:
	if message is String:
		return text(message)
	if message.has("arguments"):
		var arguments: Array = []
		for value: Variant in message.arguments:
			arguments.append(render(value) if value is Dictionary or (value is String and value.begins_with("EDITOR_")) else value)
		return text(message.key) % arguments
	return format_text(message.key, message.get("values", {}))

static func bind(control: Control, property: String, message: Variant) -> void:
	control.set_meta("editor_copy_" + property, [message])
	control.set(property, render(message))

static func append(control: Control, message: Variant) -> void:
	var messages: Array = control.get_meta("editor_copy_text", [])
	messages.append(message)
	control.set_meta("editor_copy_text", messages)
	control.text = "".join(messages.map(render))

static func add_option(control: OptionButton, key: String) -> void:
	control.add_item(text(key))
	control.set_item_metadata(control.item_count - 1, key)

static func refresh(node: Node) -> void:
	# No scene/control rebuilding: focus, gestures, selection and scroll survive.
	for property: String in ["text", "tooltip_text", "placeholder_text"]:
		var meta := "editor_copy_" + property
		if node.has_meta(meta):
			node.set(property, "".join(node.get_meta(meta).map(render)))
	if node is OptionButton:
		for index in node.item_count:
			if node.get_item_metadata(index) is String:
				node.set_item_text(index, text(node.get_item_metadata(index)))
	if node.has_method("refresh_translation"):
		node.call("refresh_translation")
	for child in node.get_children():
		refresh(child)
