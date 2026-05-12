extends SceneTree

const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen: Control = AdventureScreenScript.new()
	screen.config = {"game": {"mode": "council", "use_mock_llm": true}}
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var start_menu := screen.get("start_menu") as Control
	if start_menu != null:
		start_menu.visible = false
	var state = screen.get("state")
	state.current_npc_index = 0
	screen.set("running", true)
	var npc_id := String(state.current_npc().get("id", ""))
	var own_crime := String(state.player.get("hidden_crimes", [])[0])
	var sample_crimes := []
	for candidate in ["duck_house_expense", "hush_money_invoice", "gold_bar_favors"]:
		if String(candidate) != own_crime:
			sample_crimes.append(candidate)
	var payload := {
		"counterpart_id": "player",
		"proposals": [
			{"crime_id": own_crime, "vote": CouncilRulesEngineScript.VOTE_GUILTY},
			{"crime_id": String(sample_crimes[0]), "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": String(sample_crimes[1]), "vote": CouncilRulesEngineScript.VOTE_GUILTY}
		]
	}
	var content := screen.call("_make_council_trade_content", npc_id, "player", payload, "对手提出政治交易") as Control
	var common_modal := screen.get("common_modal") as Control
	var pending = common_modal.call("show_countdown_with_content", "政治交易提案", content, 10.0, "拒绝", "接受并执行", false)
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	_must(common_modal != null and common_modal.visible)
	_must(_find_label_text(common_modal, "对手提出政治交易"))
	_must(_find_label_text(common_modal, "接受后，双方将立即按下列议案锁定正式票"))
	_must(_find_label_text(common_modal, "正式票向：有罪"))
	_must(_find_label_text(common_modal, "正式票向：无罪"))
	_must(_find_label_text(common_modal, "10 秒后自动拒绝"))
	_must(_find_button_text(common_modal, "拒绝"))
	_must(_find_button_text(common_modal, "接受并执行"))
	var reject := _find_button_node(common_modal, "拒绝")
	var accept := _find_button_node(common_modal, "接受并执行")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	_must(reject != null and viewport_rect.encloses(reject.get_global_rect()))
	_must(accept != null and viewport_rect.encloses(accept.get_global_rect()))
	common_modal.call("cancel")
	await pending
	print("Council trade popup visual check passed.")
	quit(0)


func _find_label_text(node: Node, needle: String) -> bool:
	if node is Label and String((node as Label).text).contains(needle):
		return true
	for child in node.get_children():
		if _find_label_text(child, needle):
			return true
	return false


func _find_button_text(node: Node, needle: String) -> bool:
	if node is Button and String((node as Button).text).contains(needle):
		return true
	for child in node.get_children():
		if _find_button_text(child, needle):
			return true
	return false


func _find_button_node(node: Node, needle: String) -> Button:
	if node is Button and String((node as Button).text).contains(needle):
		return node as Button
	for child in node.get_children():
		var found := _find_button_node(child, needle)
		if found != null:
			return found
	return null


func _must(condition: bool) -> void:
	if condition:
		return
	push_error("Council trade popup visual assertion failed.")
	quit(1)
