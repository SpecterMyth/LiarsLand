extends SceneTree

const SHOT_PATH := "res://tmp/council_result_page_runtime.png"
const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")
const CouncilResultPageScript := preload("res://scripts/ui/council_result_page.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var state = GameStateScript.new()
	var data := ChapterLoaderScript.load_chapter("res://data/council_chapter_01.json")
	CouncilRulesEngineScript.setup_state(state, data)
	var events: Array[String] = []
	CouncilRulesEngineScript.cast_vote(state, "player", "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, "test", events)
	CouncilRulesEngineScript.cast_vote(state, "npc_fox", "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, "test", events)

	var page := CouncilResultPageScript.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(page)
	await process_frame
	page.show_result(state, true)
	await process_frame
	await process_frame

	_assert_visual_layout(page)

	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("Failed to read viewport image.")
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(SHOT_PATH)
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Failed to save council result page screenshot: %s" % output_path)
		quit(1)
		return
	print("Council result page screenshot saved: %s" % output_path)
	quit(0)


func _assert_visual_layout(page: Control) -> void:
	var player_card := page.get_node_or_null("MainPanel/ContentMargin/Content/ResultBody/ResultColumns/PlayerPanel/MarginContainer/VBoxContainer/PlayerCardHolder/ResultPlayerInfoCard") as Control
	var member_list := page.get_node_or_null("MainPanel/ContentMargin/Content/ResultBody/ResultColumns/RevealPanel/MarginContainer/VBoxContainer/MemberScroll/MemberList") as VBoxContainer
	var vote_list := page.get_node_or_null("MainPanel/ContentMargin/Content/ResultBody/ResultColumns/VotePanel/MarginContainer/VBoxContainer/CrimeScroll/CrimeVoteList") as VBoxContainer
	_must(player_card != null, "player info card missing")
	_must(member_list != null and member_list.get_child_count() >= 4, "member reveal rows missing")
	_must(vote_list != null and vote_list.get_child_count() >= 5, "crime vote rows missing")

	var page_rect := page.get_global_rect()
	_must(page_rect.size == Vector2(1280, 720), "page should render at 1280x720")
	for node in _collect_controls(page, ["FactionIcon", "CrimeIcon", "AvatarTexture", "VoteAvatar"]):
		var rect := node as TextureRect
		_must(rect.texture != null, "%s texture missing" % rect.name)
		_must(rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "%s should keep aspect centered" % rect.name)
		_must(rect.get_global_rect().size.x >= 20.0 and rect.get_global_rect().size.y >= 20.0, "%s display area too small" % rect.name)
		_must(page_rect.encloses(rect.get_global_rect()), "%s icon is outside page bounds" % rect.name)

	for node in _collect_labels(page):
		var label := node as Label
		if not label.visible:
			continue
		_must(label.get_global_rect().size.y >= min(label.get_minimum_size().y, 42.0) - 1.0, "%s label may be vertically clipped" % label.name)


func _collect_controls(node: Node, names: Array[String]) -> Array:
	var result: Array = []
	if node.name in names:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_controls(child, names))
	return result


func _collect_labels(node: Node) -> Array:
	var result: Array = []
	if node is Label:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_labels(child))
	return result


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
