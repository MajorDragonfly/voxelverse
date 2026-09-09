extends RefCounted
## Visual gait derived from actual leg reach and footprint, not skill values.


static func build(legs: Array[Dictionary]) -> Dictionary:
	var lengths: Array[float] = []
	var minimum := Vector3(INF, INF, INF)
	var maximum := -minimum
	for leg in legs:
		if not bool(leg.get("sculpt_rig", false)):
			continue
		var root: Node3D = leg["root"]
		lengths.append((float(leg["upper_length"]) + float(leg["lower_length"])) * root.scale.x)
		var point: Vector3 = leg["rest_ankle_preview"]
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	lengths.sort()
	var reach: float = lengths[lengths.size() / 2] if not lengths.is_empty() else 0.75
	var footprint: Vector3 = maximum - minimum if not lengths.is_empty() else Vector3.ONE
	var stride: float = clampf(reach * 0.26 + footprint.z * 0.025, 0.09, 0.65)
	return {"count": legs.size(), "reach": reach, "stride": stride,
		"lift": clampf(reach * 0.15, 0.06, 0.25),
		"cadence": clampf(4.6 / sqrt(maxf(reach / 0.8, 0.1)), 2.6, 8.0),
		"sway": clampf(footprint.x * 0.028, 0.008, 0.045) / (1.0 if legs.size() <= 2 else 1.8),
		"bob": clampf(reach * 0.028, 0.01, 0.06),
		"name": "Zweibeinig" if legs.size() == 2 else ("Vierbeinig" if legs.size() == 4 else ("Dreipunktgang" if legs.size() >= 6 else "Freier Körperbau"))}


static func phase_offset(count: int, rank: int, side: float) -> float:
	if count == 4:
		# Four-beat walk; the diagonal pair shares support during faster motion.
		return TAU * fposmod(float(rank) * 0.75 + (0.5 if side < 0 else 0.0), 1.0)
	return PI * float((rank + (1 if side < 0 else 0)) % 2)


static func parameters(profile: Dictionary, running: bool) -> Dictionary:
	return blended_parameters(profile, 1.0 if running else 0.0)


static func blended_parameters(profile: Dictionary, run_blend: float) -> Dictionary:
	var run: float = clampf(run_blend, 0.0, 1.0)
	var count: int = int(profile.get("count", 2))
	var duty: float = lerpf(0.72 if count == 4 else 0.66, 0.56, run)
	var stride: float = float(profile.get("stride", 0.2)) * lerpf(1.0, 1.35, run)
	var cadence: float = float(profile.get("cadence", 4.6)) * lerpf(1.0, 1.65, run)
	return {"duty": duty, "stride": stride, "cadence": cadence, "run_blend": run,
		"lift": float(profile.get("lift", 0.12)) * lerpf(1.0, 1.25, run),
		"speed": 2.0 * stride * cadence / (TAU * duty)}


static func sample(parameters_value: Dictionary, phase: float, blend: float = 1.0) -> Dictionary:
	var u: float = fposmod(phase / TAU, 1.0)
	var duty: float = parameters_value["duty"]
	var swing: bool = u >= duty
	var travel: float
	var lift: float = 0.0
	if swing:
		var t: float = (u - duty) / (1.0 - duty)
		# Match the stance velocity at both ends of the swing. The small
		# follow-through replaces the instantaneous reversal of the old curve.
		var tangent: float = 2.0 * (1.0 - duty) / duty
		travel = 1.0 + tangent * t - (6.0 + 3.0 * tangent) * t * t + (4.0 + 2.0 * tangent) * t * t * t
		# Zero vertical velocity on lift-off and landing.
		lift = pow(sin(PI * t), 2.0)
	else:
		travel = lerpf(-1.0, 1.0, u / duty)
	return {"u": u, "swing": swing, "lift": lift * blend,
		"offset": Vector3(0, lift * float(parameters_value["lift"]), travel * float(parameters_value["stride"])) * blend}
