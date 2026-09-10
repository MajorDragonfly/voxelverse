extends "res://world/surface/campaign_population.gd"
var attempts: Array[String] = []
var successes: Array[String] = []
func _spawn_animal(record: Dictionary) -> bool:
	attempts.append(record.id)
	if not record.get("blocked", false): successes.append(record.id); return true
	return false
func _spawn_plant(record: Dictionary) -> bool:
	attempts.append(record.id)
	if not record.get("blocked", false): successes.append(record.id); return true
	return false
