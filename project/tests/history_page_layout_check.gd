extends SceneTree

const SHOT_PATH := "res://../ui/visual_tests/history_page_runtime.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("history_layout_check: start")
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	print("history_layout_check: instantiate page")
	var page := load("res://scenes/ui/history_page.tscn").instantiate() as Control
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(page)
	await process_frame
	await process_frame

	print("history_layout_check: set sample data")
	page.set_council_history(_sample_entries(), _sample_members(), _sample_events(), "第 1 / 3 章，第 2 回合")
	await process_frame
	await process_frame

	print("history_layout_check: assert layout")
	_assert_history_layout(page)

	var image := viewport.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(SHOT_PATH)
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Failed to save history page screenshot: %s" % output_path)
		quit(1)
		return
	print("History page layout check saved: %s" % output_path)
	quit(0)


func _assert_history_layout(page: Control) -> void:
	var character_list := page.get("character_list") as VBoxContainer
	var character_scroll := page.get("character_scroll") as ScrollContainer
	var content_scroll := page.get("content_scroll") as ScrollContainer
	var history_view := page.get("history_view") as RichTextLabel
	var round_label := page.get("round_label") as Label
	_must(character_list != null, "character list missing")
	_must(character_scroll != null, "character scroll missing")
	_must(content_scroll != null, "content scroll missing")
	_must(history_view != null, "history text mirror missing")
	_must(round_label != null and round_label.text == "第 2 回合", "round badge text incorrect")
	_must(character_list.get_child_count() >= 9, "left rail should contain player plus eight visible characters")

	var scroll_rect := character_scroll.get_global_rect()
	var visible_rows := 0
	for child in character_list.get_children():
		var control := child as Control
		if control == null:
			continue
		var rect := control.get_global_rect()
		if rect.position.y >= scroll_rect.position.y and rect.end.y <= scroll_rect.end.y + 1.0:
			visible_rows += 1
	_must(visible_rows >= 9, "left rail should show player plus eight characters without scrolling")

	var text_capacity := int(floor(content_scroll.size.y / 21.0))
	_must(text_capacity >= 20, "right log should fit at least twenty text rows")
	_must(history_view.get_parsed_text().find("灰狐代笔员") >= 0, "history text did not render Chinese names")
	_must(history_view.get_parsed_text().find("�") == -1, "history text contains replacement characters")

	var avatar_textures: Array = []
	_collect_avatar_textures(page, avatar_textures)
	_must(avatar_textures.size() >= 14, "expected avatar textures in left rail and log")
	for texture_rect in avatar_textures:
		var rect := texture_rect as TextureRect
		_must(rect.texture != null, "avatar texture missing")
		_must(rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "avatar should keep aspect instead of cropping")
		_must(rect.size.x >= 20.0 and rect.size.y >= 20.0, "avatar display area too small")


func _collect_avatar_textures(node: Node, result: Array) -> void:
	var texture_rect := node as TextureRect
	if texture_rect != null and texture_rect.name == "AvatarTexture":
		result.append(texture_rect)
	for child in node.get_children():
		_collect_avatar_textures(child, result)


func _sample_members() -> Array:
	return [
		{"id": "player", "name": "灰狐代笔员", "portrait": "player_portrait.png", "alive": true},
		{"id": "npc_fox", "name": "绯尾侯爵", "portrait": "npc_fox_portrait.png", "alive": true},
		{"id": "npc_crow", "name": "墨羽书记官", "portrait": "npc_crow_portrait.png", "alive": true},
		{"id": "npc_deer", "name": "白枞使节", "portrait": "npc_deer_portrait.png", "alive": true},
		{"id": "npc_wolf", "name": "狼誓刀客", "portrait": "npc_wolf_portrait.png", "alive": true},
		{"id": "npc_snake", "name": "蛇药商", "portrait": "npc_snake_portrait.png", "alive": true},
		{"id": "npc_badger", "name": "獾须公证人", "portrait": "npc_badger_oath_notary_portrait.png", "alive": true},
		{"id": "npc_owl", "name": "猫头鹰星占师", "portrait": "npc_owl_court_astrologer_portrait.png", "alive": true},
		{"id": "npc_panther", "name": "黑豹静卫", "portrait": "npc_panther_silent_guard_portrait.png", "alive": true}
	]


func _sample_entries() -> Array:
	return [
		{"round": 2, "speaker_id": "player", "speaker_name": "灰狐代笔员", "content": "我们从哪一份债契开始？\n我只关心谁在撒谎。\n如果你愿意交换投票，我会先听你的条件。"},
		{"round": 2, "speaker_id": "npc_fox", "speaker_name": "绯尾侯爵", "content": "你问债契，就像问谁的尾巴先碰到了火盆。\n我可以支持“金条关照案”有罪，但你得保证不提旧仓库。\n议会里没有干净的人，只有擦得更亮的靴子。"},
		{"round": 2, "speaker_id": "player", "speaker_name": "灰狐代笔员", "content": "那我们先把火盆搬到桌面上。\n你保护旧仓库，我要你在清算时站到明处。"},
		{"round": 2, "speaker_id": "npc_fox", "speaker_name": "绯尾侯爵", "content": "成交，但别把承诺说得像誓言，誓言最容易被书记官听见。"}
	]


func _sample_events() -> Array:
	return [
		{"title": "议会事件：墨羽补录", "content": "墨羽书记官公开记录：绯尾侯爵倾向支持“金条关照案”有罪。\n两名旁听员要求把这条倾向写入本回合记录。"}
	]


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
