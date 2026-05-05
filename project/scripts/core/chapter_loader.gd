extends RefCounted
class_name ChapterLoader


static func load_chapter(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing chapter file: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid chapter JSON: %s" % path)
		return {}
	var errors := validate(parsed)
	for error in errors:
		push_error(error)
	return parsed


static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["player", "npcs", "artifacts"]:
		if not data.has(key):
			errors.append("Chapter is missing '%s'." % key)
	if data.get("world_intel_questions", data.get("clue_cards", [])).size() == 0:
		errors.append("Chapter needs at least one world intel question.")
	if data.get("npcs", []).size() == 0:
		errors.append("Chapter needs at least one NPC.")
	if data.get("artifacts", []).size() < 10:
		errors.append("Chapter needs at least ten artifacts.")
	for question in data.get("world_intel_questions", []):
		if String(question.get("id", "")).is_empty():
			errors.append("World intel question is missing id.")
		if question.get("options", []).size() != 3:
			errors.append("World intel question '%s' must have exactly three options." % question.get("id", ""))
	return errors
