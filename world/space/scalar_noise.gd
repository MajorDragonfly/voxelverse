extends RefCounted

## Smooth value noise with double scalar coordinates. Integer lattice hashes
## are stable; only the final mesh/normal is converted to a float32 vector.
static func sample(p: Array, spacing: float, seed_value: int) -> float:
	var x: float = float(p[0]) / spacing
	var y: float = float(p[1]) / spacing
	var z: float = float(p[2]) / spacing
	var ix: int = floori(x)
	var iy: int = floori(y)
	var iz: int = floori(z)
	var tx: float = _fade(x - ix)
	var ty: float = _fade(y - iy)
	var tz: float = _fade(z - iz)
	return lerpf(lerpf(lerpf(_hash(ix, iy, iz, seed_value), _hash(ix + 1, iy, iz, seed_value), tx),
		lerpf(_hash(ix, iy + 1, iz, seed_value), _hash(ix + 1, iy + 1, iz, seed_value), tx), ty),
		lerpf(lerpf(_hash(ix, iy, iz + 1, seed_value), _hash(ix + 1, iy, iz + 1, seed_value), tx),
		lerpf(_hash(ix, iy + 1, iz + 1, seed_value), _hash(ix + 1, iy + 1, iz + 1, seed_value), tx), ty), tz)


static func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _hash(x: int, y: int, z: int, seed_value: int) -> float:
	var h: int = (x * 73856093 ^ y * 19349663 ^ z * 83492791 ^ seed_value * 374761393) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / 1073741823.5 - 1.0
