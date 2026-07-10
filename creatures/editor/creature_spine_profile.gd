extends RefCounted

const SEGMENT_COUNT: int = 7

const MIN_WIDTH_SCALE: float = 0.55
const MAX_WIDTH_SCALE: float = 1.65

const MIN_HEIGHT_SCALE: float = 0.55
const MAX_HEIGHT_SCALE: float = 1.65

const MIN_Y_OFFSET: float = -0.90
const MAX_Y_OFFSET: float = 0.90

const SAVE_PATH: String = (
	"user://creature_editor_spine_v4.json"
)


static func create_default() -> Array:
	var segments: Array = []

	for _index in range(SEGMENT_COUNT):
		segments.append({
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

		cleaned.append(
			_sanitize_segment(value)
		)

	body["spine"] = cleaned
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

	segments[segment_index] = _sanitize_segment(
		segment
	)

	var body: Dictionary = blueprint.get("body", {})
	body["spine"] = segments
	blueprint["body"] = body


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
		float(segment.get("width_scale", 1.0))
		+ width_delta
	)

	segment["height_scale"] = (
		float(segment.get("height_scale", 1.0))
		+ height_delta
	)

	segment["y_offset"] = (
		float(segment.get("y_offset", 0.0))
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


static func reset_all(
	blueprint: Dictionary
) -> void:
	var body: Dictionary = blueprint.get("body", {})
	body["spine"] = create_default()
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

	var scaled_position: float = (
		safe_position
		* float(SEGMENT_COUNT - 1)
	)

	var left_index: int = clampi(
		floori(scaled_position),
		0,
		SEGMENT_COUNT - 1
	)

	var right_index: int = mini(
		left_index + 1,
		SEGMENT_COUNT - 1
	)

	var blend: float = (
		scaled_position
		- float(left_index)
	)

	blend = smoothstep(
		0.0,
		1.0,
		blend
	)

	var left: Dictionary = segments[left_index]
	var right: Dictionary = segments[right_index]

	return {
		"width_scale": lerpf(
			float(left.get("width_scale", 1.0)),
			float(right.get("width_scale", 1.0)),
			blend
		),
		"height_scale": lerpf(
			float(left.get("height_scale", 1.0)),
			float(right.get("height_scale", 1.0)),
			blend
		),
		"y_offset": lerpf(
			float(left.get("y_offset", 0.0)),
			float(right.get("y_offset", 0.0)),
			blend
		),
	}


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
		"version": 1,
		"creature_name": str(
			blueprint.get("name", "New Creature")
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
	if not FileAccess.file_exists(save_path):
		ensure_profile(blueprint)
		return false

	var file := FileAccess.open(
		save_path,
		FileAccess.READ
	)

	if file == null:
		ensure_profile(blueprint)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)

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
	blueprint["body"] = body

	ensure_profile(blueprint)
	return true


static func _sanitize_segment(
	value: Variant
) -> Dictionary:
	var source: Dictionary = {}

	if value is Dictionary:
		source = value

	return {
		"width_scale": clampf(
			float(
				source.get(
					"width_scale",
					1.0
				)
			),
			MIN_WIDTH_SCALE,
			MAX_WIDTH_SCALE
		),
		"height_scale": clampf(
			float(
				source.get(
					"height_scale",
					1.0
				)
			),
			MIN_HEIGHT_SCALE,
			MAX_HEIGHT_SCALE
		),
		"y_offset": clampf(
			float(
				source.get(
					"y_offset",
					0.0
				)
			),
			MIN_Y_OFFSET,
			MAX_Y_OFFSET
		),
	}
