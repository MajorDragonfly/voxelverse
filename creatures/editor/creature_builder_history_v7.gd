extends "res://assembly/core/modular_assembly_history.gd"
class_name CreatureBuilderHistoryV7

# Compatibility wrapper: the live Creature Builder now uses the shared
# ModularAssemblyHistory implementation, while preserving the historical
# empty-dictionary return used by creature_editor_v7.gd when no action exists.


func undo(current_blueprint: Dictionary) -> Dictionary:
	if not can_undo():
		return {}
	return super.undo(current_blueprint)


func redo(current_blueprint: Dictionary) -> Dictionary:
	if not can_redo():
		return {}
	return super.redo(current_blueprint)
