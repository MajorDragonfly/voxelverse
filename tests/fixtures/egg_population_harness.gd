extends "res://world/surface/campaign_population.gd"
var captured: Array[String] = []
class ActorStub extends Node:
	var catalog_species: Dictionary = {}

func _spawn_animal(record: Dictionary) -> bool:
	var actor := ActorStub.new()
	actor.catalog_species = {"id": record.get("catalog_species_id", "")}
	animals[record.id] = actor
	return true

func _capture_one(id: String) -> void: captured.append(id)
func _remove(collection: Dictionary, id: String) -> void:
	collection[id].free()
	collection.erase(id)
