extends "res://world/surface/campaign_population.gd"
var captured: Array[String] = []
func _capture_one(id: String) -> void: captured.append(id)
func _remove(collection: Dictionary, id: String) -> void:
	collection[id].free()
	collection.erase(id)
