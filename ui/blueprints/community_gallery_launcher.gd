extends Node
## Optional library opening port. The host remains owned by INT30-12.
const Gallery = preload("res://ui/blueprints/community_gallery_panel.gd")
const Style = Gallery.Style
const Text = Gallery.Text
const Symbols = preload("res://ui/design/game_symbols.gd")
var _host: Control
var _button: Button
var _gallery: Gallery
var _endpoint: String = ""
var _restore_input: bool = true


func attach(host: Control, tools: Control, endpoint: String) -> void:
	_host = host
	_endpoint = endpoint
	var check := Gallery.Client.new()
	var valid: bool = not endpoint.is_empty() and check.configure(endpoint).ok
	check.free()
	if not valid: return
	_button = Style.button(tools, Text.text("CG_TITLE"), _open, "OpenCommunityGallery")
	_button.custom_minimum_size.y = 48
	_button.add_theme_font_size_override("font_size", 20)
	Symbols.apply(_button, "gallery", 24)
	get_node("/root/LocaleManager").language_changed.connect(func(_locale: String):
		_button.text = Text.text("CG_TITLE"))


func _open() -> void:
	if is_instance_valid(_gallery): return
	var gallery := Gallery.new()
	gallery.library_path = _host.library_path
	gallery.prepare_template = _host.prepare_template
	if not gallery.configure(_endpoint).ok:
		gallery.free()
		return
	_restore_input = _host.is_processing_input()
	_host.set_process_input(false)
	_gallery = gallery
	gallery.imported.connect(func(key: String): _host.reload(key))
	gallery.closed.connect(func():
		_gallery = null
		_host.set_process_input(_restore_input))
	_host.add_child(gallery)
