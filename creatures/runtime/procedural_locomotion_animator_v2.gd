extends "res://creatures/runtime/procedural_locomotion_animator.gd"

var _bound_preview_id: int = 0
var _stable_preview_origin: Vector3 = Vector3.ZERO


func _bind_runtime_visual() -> void:
	var candidate := _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D
	if candidate == null:
		return

	var candidate_id: int = candidate.get_instance_id()
	var is_new_preview: bool = candidate_id != _bound_preview_id
	_preview = candidate

	if is_new_preview:
		_bound_preview_id = candidate_id
		_stable_preview_origin = candidate.position
		_base_preview_position = _stable_preview_origin
	else:
		# Rebinding may happen after runtime mesh reconstruction. Never use the
		# currently animated/bobbed position as a new base, otherwise every jump
		# or rebind adds height and the creature drifts into the sky.
		_base_preview_position = _stable_preview_origin
		_preview.position = _stable_preview_origin

	_body_root = _preview.get_node_or_null("BodyV4") as Node3D
	_body_slices.clear()
	_part_roots.clear()

	if _body_root != null:
		_base_body_rotation = _body_root.rotation
		for child in _body_root.get_children():
			var slice := child as Node3D
			if slice == null or not slice.name.begins_with("BodySliceV4_"):
				continue
			_store_base_transform(slice)
			_body_slices.append(slice)

	for child in _preview.get_children():
		var part_root := child as Node3D
		if part_root == null or not part_root.has_meta("creature_part_category"):
			continue
		_store_base_transform(part_root)
		_part_roots.append(part_root)


func _validate_or_rebind() -> void:
	var expected_preview := _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D
	if expected_preview == null:
		return
	if expected_preview != _preview:
		_bind_runtime_visual()
