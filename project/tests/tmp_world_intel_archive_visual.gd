extends SceneTree

const OUTPUT_PATH := "res://../tmp/world_intel_archive_godot_visual.png"
const ARCHIVE_SCENE := "res://scenes/ui/world_intel_archive.tscn"
const CHAPTER_DATA := "res://data/chapter_01.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var archive_scene: PackedScene = load(ARCHIVE_SCENE)
	_must(archive_scene != null, "world intel archive scene missing")
	var archive: Control = archive_scene.instantiate()
	root.add_child(archive)
	await process_frame
	await process_frame

	var data := _load_json(CHAPTER_DATA)
	var questions: Array = data.get("world_intel_questions", [])
	var testimonies := _make_testimonies()
	var selected := {"lie_origin": "moon", "old_dynasty_fate": "betrayed"}
	archive.call("bind_world_intel", questions, selected, testimonies, false)
	await process_frame
	await process_frame

	var scroll := archive.get_node("Scroll") as ScrollContainer
	var submit := archive.get_node("Footer/SubmitButton") as Button
	var submit_bg := archive.get_node_or_null("Footer/SubmitButton/Background") as TextureRect
	var question_grid := archive.get_node("Scroll/QuestionGrid") as GridContainer
	var right_edge := scroll.global_position.x + scroll.size.x
	var max_card_right := 0.0
	var card_count := 0
	for question in question_grid.get_children():
		if not question.has_meta("generated_world_intel"):
			continue
		var options := question.get_node_or_null("Body/OptionsRow")
		if options == null:
			continue
		for card in options.get_children():
			if card.has_meta("generated_world_intel") and card is Control:
				var control := card as Control
				max_card_right = maxf(max_card_right, control.global_position.x + control.size.x)
				card_count += 1

	_must(submit.visible, "submit button should be visible")
	_must(submit.text == "提交世界设定档案", "submit button text mismatch")
	if submit_bg != null:
		_must(submit_bg.visible, "submit background should be visible")
		_must(submit_bg.texture != null, "submit background texture missing")
	_must(card_count >= 18, "world intel cards missing")
	_must(max_card_right <= right_edge + 1.0, "world intel cards overflow scroll area")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tmp"))
	_save_screenshot(OUTPUT_PATH)
	print("World intel visual screenshot saved: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	print("World intel layout: card_count=%d max_card_right=%.1f scroll_right=%.1f" % [card_count, max_card_right, right_edge])
	if submit_bg != null and submit_bg.texture != null:
		print("Submit button TextureRect background: %s" % submit_bg.texture.resource_path)
	else:
		print("Submit button uses current StandardButton styling.")
	quit(0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_must(file != null, "cannot open chapter data")
	var parsed = JSON.parse_string(file.get_as_text())
	_must(typeof(parsed) == TYPE_DICTIONARY, "chapter data should parse as dictionary")
	return parsed


func _make_testimonies() -> Dictionary:
	var npcs := [
		{"npc_id": "npc_fox", "npc_name": "绯尾侯爵", "portrait": "npc_fox_portrait.png"},
		{"npc_id": "npc_crow", "npc_name": "墨羽书记官", "portrait": "npc_crow_portrait.png"},
		{"npc_id": "npc_deer", "npc_name": "白杖使节", "portrait": "npc_deer_portrait.png"},
		{"npc_id": "npc_snake", "npc_name": "青鳞药师", "portrait": "npc_snake_portrait.png"},
		{"npc_id": "npc_wolf", "npc_name": "铁颈军官", "portrait": "npc_wolf_portrait.png"},
	]
	var result := {}
	var questions := ["lie_origin", "old_dynasty_fate", "common_taboo", "market_respect", "artifact_nature", "betrayal_shape"]
	var options := [
		["moon", "name", "debt"],
		["betrayed", "devoured_by_artifacts", "hidden_royals"],
		["first_gift", "threshold_truth", "dead_relic"],
		["fair_trade", "beautiful_lies", "kept_secrets"],
		["memory_vessel", "living_creditor", "identity_disguise"],
		["purge", "ritual", "mistaken_identity"],
	]
	for qi in range(questions.size()):
		var by_option := {}
		for oi in range(options[qi].size()):
			var source: Dictionary = npcs[(qi + oi) % npcs.size()].duplicate(true)
			source["source_id"] = "%d:%s" % [1, source["npc_id"]]
			source["chapter"] = 1
			source["trusted"] = true
			by_option[options[qi][oi]] = [source]
		result[questions[qi]] = by_option
	return result


func _save_screenshot(path: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		push_error("No viewport texture available.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image is empty.")
		quit(1)
		return
	var result := image.save_png(ProjectSettings.globalize_path(path))
	if result != OK:
		push_error("Failed to save screenshot: %s" % path)
		quit(1)


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
