extends "res://world/surface/surface_creature.gd"
const Suitability = preload("res://world/fauna/domestication/domestication_contract.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
var catalog_species: Dictionary = {}
var habitat: Dictionary = {}
var object_identity: String = ""
var clearance: float = 1.0

func _ready() -> void:
	design = Suitability.decode(catalog_species.blueprint)
	super._ready()
	speed = catalog_species.domestication.movement_speed
	var scale_value: float = catalog_species.visual_scale
	var shape: CapsuleShape3D = get_child(0).shape
	shape.radius = maxf(0.34, scale_value * 0.72)
	shape.height = maxf(1.15, scale_value * 1.95)
	clearance = shape.height * 0.5 + 0.05
	preview.scale = Vector3.ONE * scale_value
	preview.position.y = -shape.height * 0.5 - float(preview.get_meta("ground_y", 0.0)) * scale_value + 0.02
	# No global-Y brain or campaign ownership is introduced here.

func _physics_process(delta: float) -> void:
	if not enabled: return
	var here: Dictionary = adapter.location(self)
	var toward: Vector3 = (adapter.to_local(home if returning else goal) - position).slide(adapter.up_at(here)).normalized()
	var next: Dictionary = adapter.offset(here, toward * maxf(0.7, speed * delta * 2.0))
	if not Planner.dry(adapter.terrain.surface, next):
		returning = not returning
		velocity = Vector3.ZERO
		return
	super._physics_process(delta)

func get_campaign_identity() -> Dictionary:
	return {"object_id": object_identity, "body_id": catalog_species.body_id,
		"species_id": catalog_species.id, "region_id": habitat.region_id}
