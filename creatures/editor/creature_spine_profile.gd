extends RefCounted

const Store = preload("res://core/persistence/design_store.gd")

const SEGMENT_COUNT: int = 7
const SAVE_VERSION: int = 2

const MIN_WIDTH_SCALE: float = 0.22
const MAX_WIDTH_SCALE: float = 2.60

const MIN_HEIGHT_SCALE: float = 0.22
const MAX_HEIGHT_SCALE: float = 2.60

const MIN_Y_OFFSET: float = -1.80
const MAX_Y_OFFSET: float = 1.80

const MIN_BODY_LENGTH_SCALE: float = 0.45
const MAX_BODY_LENGTH_SCALE: float = 3.0

const MIN_KNOT_GAP: float = 0.035

const SAVE_PATH: String = (
	"user://creature_editor_spine_v4.json"
)


static func create_default() -> Array:
	var segments: Array = []

	for index in range(SEGMENT_COUNT):
		segments.append({
			"t": float(index) / float(SEGMENT_COUNT - 1),
			"width_scale": 1.0,
			"height_scale": 1.0,
			"y_offset": 0.0,
		})

	return segments


static func ensure_profile(
	blueprint: Dictionary
) -> void:
	var body: Dictionary = blueprint.get("body", {})
	var source: Variant = body.get("spine", [])
	var cleaned: Array = []

	for index in range(SEGMENT_COUNT):
		var value: Variant = {}

		if source is Array and index < source.size():
			value = source[index]

		var segment: Dictionary = _sanitize_segment(value)
		var fallback: float = float(index) / float(SEGMENT_COUNT - 1)
		var knot: float = float(segment.get("t", fallback))
		if not is_finite(knot):
			knot = fallback
		var low: float = 0.0 if index == 0 else float(cleaned[index - 1]["t"]) + MIN_KNOT_GAP
		segment["t"] = clampf(knot, low, 1.0 - float(SEGMENT_COUNT - 1 - index) * MIN_KNOT_GAP)
		if index == 0 or index == SEGMENT_COUNT - 1:
			segment["t"] = fallback
		cleaned.append(segment)

	body["spine"] = cleaned

	body["spine_length_scale"] = clampf(
		float(
			body.get(
				"spine_length_scale",
				1.0
			)
		),
		MIN_BODY_LENGTH_SCALE,
		MAX_BODY_LENGTH_SCALE
	)

	blueprint["body"] = body


static func get_segments(
	blueprint: Dictionary
) -> Array:
	ensure_profile(blueprint)

	var body: Dictionary = blueprint.get("body", {})
	var segments: Variant = body.get(
		"spine",
		create_default()
	)

	if segments is Array:
		return segments

	return create_default()


static func get_segment(
	blueprint: Dictionary,
	segment_index: int
) -> Dictionary:
	var segments: Array = get_segments(blueprint)

	if (
		segment_index < 0
		or segment_index >= segments.size()
	):
		return {
			"width_scale": 1.0,
			"height_scale": 1.0,
			"y_offset": 0.0,
		}

	var segment: Variant = segments[segment_index]

	if segment is Dictionary:
		return segment.duplicate(true)

	return {
		"width_scale": 1.0,
		"height_scale": 1.0,
		"y_offset": 0.0,
	}


static func set_segment(
	blueprint: Dictionary,
	segment_index: int,
	segment: Dictionary
) -> void:
	if (
		segment_index < 0
		or segment_index >= SEGMENT_COUNT
	):
		return

	var segments: Array = get_segments(blueprint)

	if not segment.has("t"):
		segment["t"] = segments[segment_index].get("t", float(segment_index) / 6.0)
	segments[segment_index] = _sanitize_segment(segment)

	var body: Dictionary = blueprint.get("body", {})
	body["spine"] = segments
	blueprint["body"] = body
	ensure_profile(blueprint)


static func adjust_segment(
	blueprint: Dictionary,
	segment_index: int,
	width_delta: float,
	height_delta: float,
	y_delta: float
) -> void:
	var segment: Dictionary = get_segment(
		blueprint,
		segment_index
	)

	segment["width_scale"] = (
		float(
			segment.get(
				"width_scale",
				1.0
			)
		)
		+ width_delta
	)

	segment["height_scale"] = (
		float(
			segment.get(
				"height_scale",
				1.0
			)
		)
		+ height_delta
	)

	segment["y_offset"] = (
		float(
			segment.get(
				"y_offset",
				0.0
			)
		)
		+ y_delta
	)

	set_segment(
		blueprint,
		segment_index,
		segment
	)


static func reset_segment(
	blueprint: Dictionary,
	segment_index: int
) -> void:
	set_segment(
		blueprint,
		segment_index,
		{
			"width_scale": 1.0,
			"height_scale": 1.0,
			"y_offset": 0.0,
		}
	)


static func get_body_length_scale(
	blueprint: Dictionary
) -> float:
	ensure_profile(blueprint)

	var body: Dictionary = blueprint.get("body", {})

	return clampf(
		float(
			body.get(
				"spine_length_scale",
				1.0
			)
		),
		MIN_BODY_LENGTH_SCALE,
		MAX_BODY_LENGTH_SCALE
	)


static func set_body_length_scale(
	blueprint: Dictionary,
	new_length_scale: float
) -> void:
	var body: Dictionary = blueprint.get("body", {})

	body["spine_length_scale"] = clampf(
		new_length_scale,
		MIN_BODY_LENGTH_SCALE,
		MAX_BODY_LENGTH_SCALE
	)

	blueprint["body"] = body


static func adjust_body_length(
	blueprint: Dictionary,
	length_delta: float
) -> void:
	set_body_length_scale(
		blueprint,
		get_body_length_scale(blueprint)
		+ length_delta
	)


static func reset_body_length(
	blueprint: Dictionary
) -> void:
	set_body_length_scale(
		blueprint,
		1.0
	)


static func reset_all(
	blueprint: Dictionary
) -> void:
	var body: Dictionary = blueprint.get("body", {})

	body["spine"] = create_default()
	body["spine_length_scale"] = 1.0

	blueprint["body"] = body


static func sample(
	blueprint: Dictionary,
	normalized_position: float
) -> Dictionary:
	var segments: Array = get_segments(blueprint)

	var safe_position: float = clampf(
		normalized_position,
		0.0,
		1.0
	)

	var left_index: int = 0
	for index in range(SEGMENT_COUNT - 1):
		if safe_position >= float(segments[index]["t"]):
			left_index = index
	var right_index: int = left_index + 1
	var blend: float = inverse_lerp(float(segments[left_index]["t"]), float(segments[right_index]["t"]), safe_position)
	var result: Dictionary = {}
	var interval: float = float(segments[right_index]["t"]) - float(segments[left_index]["t"])
	for field: String in ["width_scale", "height_scale", "y_offset"]:
		var left: float = float(segments[left_index][field])
		var right: float = float(segments[right_index][field])
		var slope_left: float = _knot_slope(segments, left_index, field) * interval
		var slope_right: float = _knot_slope(segments, right_index, field) * interval
		var u2: float = blend * blend
		var u3: float = u2 * blend
		result[field] = clampf((2.0 * u3 - 3.0 * u2 + 1.0) * left
			+ (u3 - 2.0 * u2 + blend) * slope_left
			+ (-2.0 * u3 + 3.0 * u2) * right
			+ (u3 - u2) * slope_right, minf(left, right), maxf(left, right))
	return result


static func _knot_slope(segments: Array, index: int, field: String) -> float:
	var before: int = maxi(0, index - 1)
	var after: int = mini(SEGMENT_COUNT - 1, index + 1)
	var h0: float = maxf(float(segments[index]["t"]) - float(segments[before]["t"]), MIN_KNOT_GAP)
	var h1: float = maxf(float(segments[after]["t"]) - float(segments[index]["t"]), MIN_KNOT_GAP)
	var d0: float = (float(segments[index][field]) - float(segments[before][field])) / h0
	var d1: float = (float(segments[after][field]) - float(segments[index][field])) / h1
	if index == 0:
		return d1
	if index == SEGMENT_COUNT - 1:
		return d0
	if d0 * d1 <= 0.0:
		return 0.0
	# Monotone cubic interpolation keeps tangents continuous without negative
	# radii or overshoot when adjacent handles are dragged close together.
	var w0: float = 2.0 * h1 + h0
	var w1: float = h1 + 2.0 * h0
	return (w0 + w1) / (w0 / d0 + w1 / d1)


static func save_profile(
	blueprint: Dictionary,
	save_path: String = SAVE_PATH
) -> Error:
	ensure_profile(blueprint)

	var file := FileAccess.open(
		save_path,
		FileAccess.WRITE
	)

	if file == null:
		return FileAccess.get_open_error()

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"creature_name": str(
			blueprint.get(
				"name",
				"New Creature"
			)
		),
		"body_length_scale": get_body_length_scale(
			blueprint
		),
		"spine": get_segments(
			blueprint
		).duplicate(true),
	}

	file.store_string(
		JSON.stringify(
			save_data,
			"\t"
		)
	)

	file.close()
	return OK


static func load_profile(
	blueprint: Dictionary,
	save_path: String = SAVE_PATH
) -> bool:
	if Store.read_text(save_path).is_empty():
		ensure_profile(blueprint)
		return false

	var parsed: Variant = JSON.parse_string(Store.read_text(save_path))

	if not (parsed is Dictionary):
		ensure_profile(blueprint)
		return false

	var spine_value: Variant = parsed.get(
		"spine",
		[]
	)

	if not (spine_value is Array):
		ensure_profile(blueprint)
		return false

	var body: Dictionary = blueprint.get("body", {})

	body["spine"] = spine_value
	body["spine_length_scale"] = float(
		parsed.get(
			"body_length_scale",
			1.0
		)
	)

	blueprint["body"] = body

	ensure_profile(blueprint)
	return true


static func _sanitize_segment(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result: Dictionary = {}
	for key in ["width_scale", "height_scale", "y_offset"]:
		var fallback: float = 0.0 if key == "y_offset" else 1.0
		var number: float = float(source.get(key, fallback))
		if not is_finite(number):
			number = fallback
		var low: float = MIN_Y_OFFSET if key == "y_offset" else MIN_WIDTH_SCALE
		var high: float = MAX_Y_OFFSET if key == "y_offset" else MAX_WIDTH_SCALE
		result[key] = clampf(number, low, high)
	if source.has("t"):
		result["t"] = source["t"]
	return result


static func move_knot(blueprint: Dictionary, index: int, t_delta: float, y_delta: float) -> void:
	if index < 0 or index >= SEGMENT_COUNT:
		return
	var segments: Array = get_segments(blueprint)
	var segment: Dictionary = segments[index].duplicate(true)
	if index > 0 and index < SEGMENT_COUNT - 1:
		segment["t"] = clampf(float(segment["t"]) + t_delta,
			float(segments[index - 1]["t"]) + MIN_KNOT_GAP,
			float(segments[index + 1]["t"]) - MIN_KNOT_GAP)
	segment["y_offset"] = float(segment["y_offset"]) + y_delta
	set_segment(blueprint, index, segment)
