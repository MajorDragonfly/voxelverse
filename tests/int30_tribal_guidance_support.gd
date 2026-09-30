extends RefCounted
## Pending catalog entries are installed only in the isolated fixture.
static func install_copy() -> void:
	var appendix: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/int30-19-tribal-guidance/patches/localization-append.json"))
	for locale: String in ["de", "en"]:
		var translation := Translation.new()
		translation.locale = locale
		for message: Dictionary in appendix.messages:
			translation.add_message(message.key, message[locale])
		TranslationServer.add_translation(translation)
