extends StaticBody3D


@export_category("Interaction")
@export var required_ability: StringName = &"chop"
@export var damage_per_interaction: float = 1.0

@export_category("Tree")
@export var maximum_health: float = 5.0

var current_health: float


func _ready() -> void:
	current_health = maximum_health


func interact(actor: Node) -> void:
	if actor == null:
		return

	if not actor.has_method("can_perform_action"):
		return

	var action_allowed := bool(
		actor.call(
			"can_perform_action",
			required_ability
		)
	)

	if not action_allowed:
		print(
			"Tree interaction blocked. Missing ability: ",
			required_ability
		)
		return

	receive_hit(damage_per_interaction)


func receive_hit(damage: float) -> void:
	current_health -= damage

	print(
		"Tree hit. Remaining health: ",
		current_health
	)

	if current_health <= 0.0:
		harvest()


func harvest() -> void:
	print("Tree harvested.")
	queue_free()
