extends RefCounted
## Shared eye-depth hysteresis for the visible atmosphere and audio filter.
## Positive depth is below the local water surface, independent of world Y.
const ENTER_DEPTH: float = 0.04
const EXIT_DEPTH: float = 0.005

static func submerged(water_present: bool, depth: float, was_submerged: bool) -> bool:
	return water_present and is_finite(depth) and depth > (EXIT_DEPTH if was_submerged else ENTER_DEPTH)
