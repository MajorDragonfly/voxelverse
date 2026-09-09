extends RefCounted
class_name ModularAssemblyHistory

const DEFAULT_LIMIT: int = 64

var limit: int = DEFAULT_LIMIT
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func push_state(blueprint: Dictionary, label: String = "Edit") -> void:
	_undo_stack.append({
		"label": label,
		"blueprint": blueprint.duplicate(true),
	})
	while _undo_stack.size() > maxi(limit, 1):
		_undo_stack.pop_front()
	_redo_stack.clear()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo(current: Dictionary) -> Dictionary:
	if _undo_stack.is_empty():
		return current
	_redo_stack.append({
		"label": "Redo",
		"blueprint": current.duplicate(true),
	})
	var state: Dictionary = _undo_stack.pop_back()
	return state.get("blueprint", current).duplicate(true)


func redo(current: Dictionary) -> Dictionary:
	if _redo_stack.is_empty():
		return current
	_undo_stack.append({
		"label": "Undo",
		"blueprint": current.duplicate(true),
	})
	var state: Dictionary = _redo_stack.pop_back()
	return state.get("blueprint", current).duplicate(true)


func get_undo_label() -> String:
	if _undo_stack.is_empty():
		return ""
	return str(_undo_stack.back().get("label", "Edit"))


func get_redo_label() -> String:
	if _redo_stack.is_empty():
		return ""
	return str(_redo_stack.back().get("label", "Edit"))
