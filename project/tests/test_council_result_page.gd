extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")
const CouncilResultPageScript := preload("res://scripts/ui/council_result_page.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state = GameStateScript.new()
	var data := ChapterLoaderScript.load_chapter("res://data/council_chapter_01.json")
	CouncilRulesEngineScript.setup_state(state, data)

	var events: Array[String] = []
	CouncilRulesEngineScript.cast_vote(state, "player", "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, "test", events)
	CouncilRulesEngineScript.cast_vote(state, "npc_fox", "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, "test", events)
	assert(state.ended)

	var page := CouncilResultPageScript.new()
	root.add_child(page)
	await process_frame
	page.show_result(state, true)
	await process_frame

	var text := _collect_label_text(page)
	assert(text.contains("游戏失败") or text.contains("章节胜利") or text.contains("最终通关"))
	assert(text.contains("胜利阵营："))
	assert(text.contains("玩家阵营："))
	assert(text.contains("阵营比分"))
	assert(text.contains("角色揭示列表"))
	assert(text.contains("罪行投票"))
	for member in state.council_members:
		assert(text.contains(String(member.get("public_name", ""))))
	assert(_count_named_texture_rects(page, "FactionIcon") >= state.council_members.size())
	assert(_count_named_texture_rects(page, "CrimeIcon") >= state.council_crime_pool.size())
	print("Council result page test passed.")
	quit(0)


func _collect_label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


func _count_named_texture_rects(node: Node, node_name: String) -> int:
	var count := 0
	if node is TextureRect and node.name == node_name:
		var texture_rect := node as TextureRect
		assert(texture_rect.texture != null)
		assert(texture_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		count += 1
	for child in node.get_children():
		count += _count_named_texture_rects(child, node_name)
	return count
