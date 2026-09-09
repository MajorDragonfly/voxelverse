extends RefCounted

# Preserve beaches and every dry landmark. Below the narrow wading shelf, the
# same continuous height field descends into a basin, up to 24 m deeper.
static func deepen(height: float, sea: float) -> float:
	var depth: float = maxf(sea - height, 0.0)
	return height - smoothstep(0.75, 4.5, depth) * 24.0
