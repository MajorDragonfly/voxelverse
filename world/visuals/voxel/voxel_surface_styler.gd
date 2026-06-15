extends MeshInstance3D
class_name VoxelSurfaceStyler


const VOXEL_SURFACE_MATERIAL = preload(
	"res://world/visuals/voxel/voxel_surface_material.tres"
)


@export_category("Voxel Surface")

@export_range(0, 20, 1)
var initial_delay_frames: int = 4

@export
var keep_monitoring: bool = false

@export_range(0.1, 5.0, 0.1)
var monitoring_interval: float = 0.5


var _voxel_material: ShaderMaterial = null

var _remaining_delay_frames: int = 0
var _monitor_timer: float = 0.0
var _initial_style_applied: bool = false


func _ready() -> void:
	_remaining_delay_frames = maxi(
		initial_delay_frames,
		0
	)

	_voxel_material = (
		VOXEL_SURFACE_MATERIAL.duplicate()
		as ShaderMaterial
	)

	if _voxel_material == null:
		push_error(
			"Voxel surface material could not be duplicated."
		)

		set_process(false)
		return

	set_process(true)


func _process(
	delta: float
) -> void:
	if _remaining_delay_frames > 0:
		_remaining_delay_frames -= 1
		return

	if not _initial_style_applied:
		if _apply_voxel_surface_material():
			_initial_style_applied = true

			if not keep_monitoring:
				set_process(false)

		return

	if not keep_monitoring:
		set_process(false)
		return

	_monitor_timer += delta

	if (
		_monitor_timer
		< maxf(
			monitoring_interval,
			0.1
		)
	):
		return

	_monitor_timer = 0.0

	if material_override != _voxel_material:
		_apply_voxel_surface_material()


func _apply_voxel_surface_material() -> bool:
	if mesh == null:
		return false

	if _voxel_material == null:
		return false

	if material_override == _voxel_material:
		return true

	var source_tint: Color = Color.WHITE

	# Der Grazer setzt beim Tod ein eigenes Material
	# mit einer Leichenfärbung. Der Beerenbusch erzeugt
	# beim Abernten ebenfalls sein Material erneut.
	#
	# Diese bereits gesetzte Färbung wird übernommen,
	# bevor das gemeinsame Voxelmaterial aktiviert wird.
	if material_override is StandardMaterial3D:
		var source_material := (
			material_override
			as StandardMaterial3D
		)

		source_tint = (
			source_material.albedo_color
		)

	_voxel_material.set_shader_parameter(
		&"object_tint",
		source_tint
	)

	material_override = _voxel_material

	return true
