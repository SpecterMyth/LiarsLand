extends SceneTree


class FakeCouncilState:
	var council_mode := true
	var chapter_index := 0
	var max_chapters := 1
	var chapter_round := 0
	var max_rounds := 1
	var max_player_chars := 12
	var player_chars := 4
	var ended := false
	var player := {
		"id": "player",
		"public_name": "玩家",
		"name": "玩家",
		"portrait": "player_portrait.png",
		"alive": true,
		"hidden_faction": "red_hat",
		"hidden_crimes": ["hush_money_invoice"],
		"faction_revealed": true
	}
	var npcs := [
		{
			"id": "npc_fox",
			"public_name": "绯尾侯爵",
			"name": "绯尾侯爵",
			"portrait": "npc_fox_portrait.png",
			"alive": true,
			"hidden_faction": "blue_tie",
			"faction_revealed": true
		}
	]
	var council_factions := [
		{"id": "red_hat", "name": "红帽"},
		{"id": "blue_tie", "name": "蓝领"}
	]
	var council_crime_pool := [
		{"id": "hush_money_invoice", "title": "封口费发票"}
	]
	var council_vote_records := [
		{"member_id": "player", "crime_id": "hush_money_invoice", "vote": "guilty"}
	]
	var council_vote_tendencies := [
		{"member_id": "npc_fox", "crime_id": "hush_money_invoice", "vote": "innocent"}
	]
	var council_faction_public_crimes := {}

	func current_npc() -> Dictionary:
		return npcs[0]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var required_paths := [
		"res://assets/ui/characters/headicon/player_head_avatar.png",
		"res://assets/ui/characters/headicon/npc_fox_head_avatar.png"
	]
	for path in required_paths:
		if not ResourceLoader.exists(path):
			push_error("Missing character head avatar: %s" % path)
			quit(1)
			return

	if not await _check_history_page():
		quit(1)
		return
	if not await _check_status_page():
		quit(1)
		return
	print("Circle avatar page checks passed.")
	quit(0)


func _check_history_page() -> bool:
	var page := load("res://scenes/ui/history_page.tscn").instantiate() as Control
	root.add_child(page)
	await process_frame
	page.set_council_history([
		{"speaker_id": "player", "speaker_name": "玩家", "round": 1, "content": "测试"},
		{"speaker_id": "npc_fox", "speaker_name": "绯尾侯爵", "round": 1, "content": "测试"}
	], [
		{"id": "player", "name": "玩家", "portrait": "player_portrait.png", "alive": true},
		{"id": "npc_fox", "name": "绯尾侯爵", "portrait": "npc_fox_portrait.png", "alive": true}
	], [], "测试")
	await process_frame
	var view := page.get("history_view") as RichTextLabel
	var text := view.get_parsed_text()
	var player_path := String(page.call("_portrait_bbcode_path", "player_portrait.png"))
	var fox_path := String(page.call("_portrait_bbcode_path", "npc_fox_portrait.png"))
	var texture_paths := []
	_collect_texture_paths(page, texture_paths)
	page.queue_free()
	if player_path != "res://assets/ui/characters/headicon/player_head_avatar.png" or fox_path != "res://assets/ui/characters/headicon/npc_fox_head_avatar.png":
		push_error("History page did not resolve head avatar paths.")
		return false
	if not texture_paths.has("res://assets/ui/characters/headicon/player_head_avatar.png") or not texture_paths.has("res://assets/ui/characters/headicon/npc_fox_head_avatar.png"):
		push_error("History summary did not load head avatar textures.")
		return false
	if text.is_empty():
		push_error("History page did not render dialogue text.")
		return false
	return true


func _check_status_page() -> bool:
	var page := load("res://scenes/ui/status_page.tscn").instantiate() as Control
	root.add_child(page)
	await process_frame
	page.bind_state(FakeCouncilState.new())
	await process_frame
	var player_path := String(page.call("_avatar_texture_path", FakeCouncilState.new().player))
	var fox_path := String(page.call("_avatar_texture_path", FakeCouncilState.new().npcs[0]))
	page.queue_free()
	if player_path != "res://assets/ui/characters/headicon/player_head_avatar.png" or fox_path != "res://assets/ui/characters/headicon/npc_fox_head_avatar.png":
		push_error("Status page did not resolve head avatar paths.")
		return false
	return true


func _collect_texture_paths(node: Node, paths: Array) -> void:
	var texture_rect := node as TextureRect
	if texture_rect != null and texture_rect.texture != null:
		paths.append(texture_rect.texture.resource_path)
	for child in node.get_children():
		_collect_texture_paths(child, paths)
