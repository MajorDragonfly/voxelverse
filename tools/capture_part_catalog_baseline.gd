extends SceneTree
## Explicit source and output arguments prevent replacing fixtures accidentally.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var library: Script = load(args[0])
	var entries: Array = []
	for section: Dictionary in library.get_categories():
		for definition: Dictionary in library.get_parts_for_category(section.id):
			entries.append({"category": section.id, "definition": var_to_str(definition)})
	for definition: Dictionary in library.get_terminal_parts():
		entries.append({"category": definition.category, "definition": var_to_str(definition)})
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(entries, "\t") + "\n")
	output.close()
	quit()
