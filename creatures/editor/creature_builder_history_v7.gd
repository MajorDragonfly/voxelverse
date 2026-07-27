extends RefCounted
class_name CreatureBuilderHistoryV7

const MAX_HISTORY: int = 64

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _last_label: String = ""


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_last_label = ""


func push_state(blueprint: Dictionary, label: String = "Edit") -> void:
	if blueprint.is_empty():
		return
	_undo_stack.append({
		"label": label,
		"blueprint": blueprint.duplicate(true),
	})
	while _undo_stack.size() > MAX_HISTORY:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_last_label = label


func undo(current_blueprint: Dictionary) -> Dictionary:
	if _undo_stack.is_empty():
		return {}
	_redo_stack.append({
		"label": _last_label,
		"blueprint": current_blueprint.duplicate(true),
	})
	var state: Dictionary = _undo_stack.pop_back()
	_last_label = str(state.get("label", "Undo"))
	return state.get("blueprint", {}).duplicate(true)


func redo(current_blueprint: Dictionary) -> Dictionary:
	if _redo_stack.is_empty():
		return {}
	_undo_stack.append({
		"label": _last_label,
		"blueprint": current_blueprint.duplicate(true),
	})
	var state: Dictionary = _redo_stack.pop_back()
	_last_label = str(state.get("label", "Redo"))
	return state.get("blueprint", {}).duplicate(true)


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func get_undo_label() -> String:
	if _undo_stack.is_empty():
		return ""
	return str(_undo_stack.back().get("label", "Edit"))


func get_redo_label() -> String:
	if _redo_stack.is_empty():
		return ""
	return str(_redo_stack.back().get("label", "Edit"))
