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

	var state = screen.get("state")
	state.current_npc_index = 0
	var npc_id := String(state.current_npc().get("id", ""))
	var own_crime := String(state.player.get("hidden_crimes", [])[0])
	var payload := {
		"counterpart_id": "player",
		"proposals": [
			{"crime_id": own_crime, "vote": CouncilRulesEngineScript.VOTE_GUILTY},
			{"crime_id": "duck_house_expense", "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": "hush_money_invoice", "vote": "abstain"}
		]
	}

	var pending = screen.call("_confirm_npc_council_trade", npc_id, payload)
	await process_frame
	await process_frame
	await create_timer(0.1).timeout

	var modal := screen.get("common_modal") as Control
	_must(modal != null and modal.visible, "npc trade modal should be visible")
	var reject := _find_button_text(modal, "拒绝")
	var accept := _find_button_text(modal, "接受并执行")
	_must(reject != null and reject.visible and not reject.disabled, "reject button should be visible and enabled")
	_must(accept != null and accept.visible and not accept.disabled, "accept button should be visible and enabled")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	_must(viewport_rect.encloses(reject.get_global_rect()), "reject button should be inside viewport")
	_must(viewport_rect.encloses(accept.get_global_rect()), "accept button should be inside viewport")
	modal.call("cancel")
	var accepted: bool = await pending
	_must(not accepted, "cancel should reject npc trade")
	print("NPC trade buttons check passed.")
	quit(0)


func _find_button_text(node: Node, needle: String) -> Button:
	if node is Button and String((node as Button).text).contains(needle):
		return node as Button
	for child in node.get_children():
		var found := _find_button_text(child, needle)
		if found != null:
			return found
	return null


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
