extends RefCounted
## Screen-space overlap of the drawn scan disc with a projected capsule axis.
## The returned pixel lies inside both shapes and is confirmed by a world ray.

static func contact(circle_center: Vector2, circle_radius: float, start: Vector2, finish: Vector2,
		start_radius: float, finish_radius: float) -> Dictionary:
	if circle_radius <= 0.0 or start_radius <= 0.0 or finish_radius <= 0.0: return {}
	var segment: Vector2 = finish - start
	var factor: float = clampf((circle_center - start).dot(segment) / segment.length_squared(), 0.0, 1.0) if segment.length_squared() > 0.0001 else 0.0
	var axis: Vector2 = start.lerp(finish, factor)
	var radius: float = lerpf(start_radius, finish_radius, factor)
	var delta: Vector2 = circle_center - axis
	var distance: float = delta.length()
	var overlap: float = circle_radius + radius - distance
	# Half a screen pixel can still make a visible edge. The confirming ray
	# rejects broad-phase false positives and objects behind the terrain.
	if overlap < -0.5: return {}
	var inset: float = minf(0.35, maxf(overlap * 0.4, 0.0))
	var pixel: Vector2 = axis + delta.normalized() * minf(distance, maxf(radius - inset, 0.0)) if distance > 0.0001 else axis
	return {"pixel": pixel, "axis": axis, "overlap": overlap,
		"score": maxf(0.0, distance - radius) / circle_radius}
