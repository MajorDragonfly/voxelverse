extends Node
## Narrow landing island, bent swimmable channel, larger habitat island.
## Height-20 cliffs block every direct line to the destination island.
enum Biome { OCEAN, LAKE, RIVER, PLAINS }
var sealed: bool = false
func get_scenic_spawn() -> Vector3: return Vector3(0, 2, 0)
func get_terrain_height(x: float, z: float) -> float:
	var start: float = Vector2(x, z).length()
	if sealed: return 2.0 if start < 3.0 else 20.0
	var destination: float = Vector2(x - 64, z - 80).length()
	var channel: bool = (x >= -8 and x <= 72 and absf(z) <= 8) or (absf(x - 64) <= 8 and z >= -8 and z <= 80)
	if not channel and start > 16 and destination > 30: return 20.0
	return maxf(-2.0, maxf(clampf((8.0 - start) * 0.25, -2, 2), clampf((22.0 - destination) * 0.25, -2, 2)))
func get_visual_terrain_height(x: float, z: float) -> float: return get_terrain_height(x, z)
func get_water_level(_x: float, _z: float) -> float: return 0.0
func get_terrain_slope(x: float, z: float, delta: float) -> float:
	return maxf(absf(get_terrain_height(x + delta, z) - get_terrain_height(x - delta, z)), absf(get_terrain_height(x, z + delta) - get_terrain_height(x, z - delta))) / (delta * 2)
func get_biome(_x: float, _z: float, height: float) -> int: return Biome.OCEAN if height < 0.0 else Biome.PLAINS
func get_water_info(_x: float, _z: float) -> Dictionary: return {"kind": "ocean", "distance": 0.0}
