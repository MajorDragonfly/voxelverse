extends RefCounted
## Overlay applied after locomotion resets parts and BEFORE feet are planted.
## Uses authored local frames; no meshes, colliders, sockets or blueprints change.


static func apply(preview: Node3D, parts: Array[Dictionary], pose: Dictionary) -> void:
	if pose.is_empty(): return
	preview.position.y -= float(pose.get("body_drop", 0.0)) * preview.scale.y
	preview.position.y += float(pose.get("breath", 0.0)) * preview.scale.y
	preview.rotation.x += float(pose.get("body_pitch", 0.0))
	var pivot := Vector3.ZERO
	var count: int = 0
	for part: Dictionary in parts:
		if is_instance_valid(part.node) and str(part.node.get_meta("creature_part_category", "")) in ["head", "mouth", "eyes"]:
			pivot += part.position
			count += 1
	if count > 0: pivot = pivot / float(count) + Vector3(0, 0, 0.12)
	var face := Basis.from_euler(Vector3(pose.get("head_pitch", 0.0), pose.get("look_yaw", 0.0), pose.get("head_roll", 0.0)))
	for part: Dictionary in parts:
		var node: Node3D = part.node
		if not is_instance_valid(node): continue
		var category: String = str(node.get_meta("creature_part_category", ""))
		if category in ["head", "mouth", "eyes"]:
			# The sculpted skin has no independent head: moving these roots
			# around a shared face centroid pulls their bases off the skin.
			# Pose each attachment at its socket; jaws/pupils articulate below.
			if not bool(preview.get("sculpted_surface")):
				node.position = pivot + face * (node.position - pivot)
			node.basis = face * node.basis
		elif category == "tail":
			# Replace the generic idle wag instead of adding a second oscillator.
			node.rotation = part.rotation + Vector3(pose.get("tail_pitch", 0.0), pose.get("tail_yaw", 0.0), 0)
		elif category == "arms":
			node.rotation.x += float(pose.get("arm_pitch", 0.0))
