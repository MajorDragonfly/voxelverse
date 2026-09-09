extends RefCounted

# Godot's 3D instance buffer is three matrix rows followed by one RGBA
# attribute (instance color OR custom data). One bulk upload per batch avoids
# thousands of RenderingServer setters and retains inspectable CPU payloads.
static func pack(transforms: Array, attributes: Array) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 16)
	for index in range(transforms.size()):
		var transform: Transform3D = transforms[index]
		var data: Color = attributes[index]
		var offset: int = index * 16
		buffer[offset] = transform.basis.x.x
		buffer[offset + 1] = transform.basis.y.x
		buffer[offset + 2] = transform.basis.z.x
		buffer[offset + 3] = transform.origin.x
		buffer[offset + 4] = transform.basis.x.y
		buffer[offset + 5] = transform.basis.y.y
		buffer[offset + 6] = transform.basis.z.y
		buffer[offset + 7] = transform.origin.y
		buffer[offset + 8] = transform.basis.x.z
		buffer[offset + 9] = transform.basis.y.z
		buffer[offset + 10] = transform.basis.z.z
		buffer[offset + 11] = transform.origin.z
		buffer[offset + 12] = data.r
		buffer[offset + 13] = data.g
		buffer[offset + 14] = data.b
		buffer[offset + 15] = data.a
	return buffer
