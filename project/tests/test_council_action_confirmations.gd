extends SceneTree

const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen: Control = AdventureScreenScript.new()
	screen.config = {"game": {"mode": "council", "use_mock_llm": true}}
	root.add_child(screen)
	await process_frame
	await process_frame
	var state = screen.get("state")
	state.current_npc_index = 0
	var own_crime := String(state.player.get("hidden_crimes", [])[0])
	var npc_id := String(state.current_npc().get("id", ""))
	var safe_payload := {"counterpart_id": "player", "proposals": [{"crime_id": own_crime, "vote": CouncilRulesEngineScript.VOTE_INNOCENT}]}
	var harmful_payload := {"counterpart_id": "player", "proposals": [{"crime_id": own_crime, "vote": CouncilRulesEngineScript.VOTE_GUILTY}]}
	_must(screen.call("_player_auto_accepts_council_trade", npc_id, safe_payload))
	_must(not screen.call("_player_auto_accepts_council_trade", npc_id, harmful_payload))
	var content := screen.call("_make_council_trade_content", npc_id, "player", harmful_payload, "对手提出政治交易") as Control
	_must(content != null)
	_must(_find_label_text(content, "损害我"))
	var tendency_events: Array[String] = []
	var tendency_applied: bool = await screen.call("_confirm_and_apply_council_action", "player", CouncilRulesEngineScript.ACTION_TENDENCY, {
		"target_crime_id": own_crime,
		"vote": CouncilRulesEngineScript.VOTE_INNOCENT
	}, tendency_events, true)
	var common_modal := screen.get("common_modal") as Control
	_must(tendency_applied)
	_must(common_modal != null and not common_modal.visible)
	_must(_has_tendency(state, "player", own_crime, CouncilRulesEngineScript.VOTE_INNOCENT))
	var events: Array[String] = []
	var trade_pending = screen.call("_confirm_and_apply_council_action", "player", CouncilRulesEngineScript.ACTION_TRADE, {
		"counterpart_id": npc_id,
		"proposals": [{"crime_id": own_crime, "vote": CouncilRulesEngineScript.VOTE_INNOCENT}]
	}, events, true)
	await process_frame
	await process_frame
	_must(common_modal != null and common_modal.visible)
	_must(_find_label_text(common_modal, "你的角色提出政治交易"))
	common_modal.call("cancel")
	var trade_applied: bool = await trade_pending
	_must(not trade_applied)
	var pending = screen.call("_confirm_and_apply_council_action", "player", CouncilRulesEngineScript.ACTION_VOTE, {
		"target_crime_id": own_crime,
		"vote": CouncilRulesEngineScript.VOTE_INNOCENT
	}, events, true)
	await process_frame
	await process_frame
	_must(common_modal != null and common_modal.visible)
	common_modal.call("confirm")
	var applied: bool = await pending
	_must(applied)
	_must(_has_vote(state, "player", own_crime, CouncilRulesEngineScript.VOTE_INNOCENT))
	print("Council action confirmation test passed.")
	quit(0)


func _find_label_text(node: Node, needle: String) -> bool:
	if node is Label and String((node as Label).text).contains(needle):
		return true
	for child in node.get_children():
		if _find_label_text(child, needle):
			return true
	return false


func _has_vote(state, member_id: String, crime_id: String, vote: String) -> bool:
	for record in state.council_vote_records:
		if String(record.get("member_id", "")) == member_id and String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			return true
	return false


func _has_tendency(state, member_id: String, crime_id: String, vote: String) -> bool:
	for record in state.council_vote_tendencies:
		if String(record.get("member_id", "")) == member_id and String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			return true
	return false


func _must(condition: bool) -> void:
	if condition:
		return
	push_error("Council action confirmation assertion failed.")
	quit(1)
