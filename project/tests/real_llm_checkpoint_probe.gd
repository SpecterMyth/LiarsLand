extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const RulesEngineScript := preload("res://scripts/core/rules_engine.gd")
const LlmClientScript := preload("res://scripts/llm/llm_client.gd")
const PromptBuilderScript := preload("res://scripts/llm/prompt_builder.gd")

const IDENTITY_GUIDELINE := "## 对外身份\n来自边境的灰狐抄写员，替商队整理族谱与债契。\n\n## 对手应如何认知我\n- 以这份公开身份理解我的言行。\n- 不知道我的真实目标，除非我在对话中暴露。\n- 优先把我视为可以交易、试探、被利用或结盟的外来者。"
const BASE_BEHAVIOR := "根据对方的问题进行回复"

var client
var data: Dictionary
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	data = ChapterLoaderScript.load_chapter("res://data/chapter_01.json")
	client = LlmClientScript.new()
	client.config = LlmClientScript.load_config()
	root.add_child(client)
	await process_frame
	print("use_mock_llm=%s" % str(client.use_mock_llm()))
	await _probe(2, "第3关", BASE_BEHAVIOR, false)
	await _probe(2, "第3关+融合", BASE_BEHAVIOR + "\n\n当对方出现贴近、拖延、封路、观察武器等暗杀前兆，且我正面决斗能力明显占优时，应主动决斗打断暗杀节奏。", true)
	await _probe(3, "第4关", BASE_BEHAVIOR, false)
	await _probe(3, "第4关+融合", BASE_BEHAVIOR + "\n\n当对方正面战力明显压制我、持续逼迫公开决斗，但暗杀防御很低时，应优先暗杀，不接受对方设定的战斗方式。", true)
	await _probe(4, "第5关", BASE_BEHAVIOR, false)
	await _probe(4, "第5关+融合", BASE_BEHAVIOR + "\n\n对未知对手使用短句试探；当对方连续追问身份、目的、法器或情报来源时，不继续解释，优先撤离。", true)
	client.queue_free()
	if failed:
		quit(1)
	else:
		quit(0)


func _probe(round_index: int, label: String, behavior: String, expect_pass: bool) -> void:
	var state = GameStateScript.new()
	state.load_chapter(data)
	state.chapter_round = round_index
	state.refresh_npc_choices()
	state.choose_npc(0)
	print("\n=== %s / %s ===" % [label, state.current_npc().get("public_name", "对方")])
	var passed := false
	for _i in range(3):
		state.turn += 1
		var player := await _call_player(state, behavior)
		print("P%d thinking=%s" % [state.turn, String(player.get("thinking", "")).left(140)])
		print("P%d speech=%s action=%s" % [state.turn, String(player.get("speech", "")), String(player.get("action", "none"))])
		var action := String(player.get("action", "none")).strip_edges().to_lower()
		if action != "" and action != "none":
			var events := RulesEngineScript.resolve_player_action(state, action, {"artifact_id": String(player.get("artifact_id", ""))})
			_print_events(events)
			passed = _is_checkpoint_pass(round_index, action, state)
			break
		state.add_dialogue("player", String(player.get("speech", "")))
		var npc := await _call_npc(state)
		print("N%d speech=%s action=%s" % [state.turn, String(npc.get("speech", "")), String(npc.get("action", "none"))])
		state.add_dialogue("npc", String(npc.get("speech", "")))
		var events := RulesEngineScript.apply_dialogue_turn(state, String(player.get("speech", "")), String(npc.get("speech", "")), npc)
		_print_events(events)
		if state.ended:
			break
	if not state.ended and not passed:
		var post := await _call_post_action(state, behavior)
		print("POST thinking=%s action=%s" % [String(post.get("thinking", "")).left(140), String(post.get("action", "leave"))])
		var events := RulesEngineScript.resolve_player_action(state, String(post.get("action", "leave")), {"artifact_id": String(post.get("artifact_id", ""))})
		_print_events(events)
		passed = _is_checkpoint_pass(round_index, String(post.get("action", "")), state)
	print("RESULT ended=%s victory=%s passed=%s reason=%s" % [str(state.ended), str(state.victory), str(passed), state.end_reason])
	if expect_pass and not passed:
		failed = true
		push_error("%s expected pass but did not pass" % label)
	if not expect_pass and not state.ended:
		failed = true
		push_error("%s expected checkpoint failure but did not end" % label)


func _call_player(state, behavior: String) -> Dictionary:
	return await client.chat_json(
		"player_llm",
		PromptBuilderScript.player_dialogue_system(state),
		PromptBuilderScript.player_dialogue_user(state, behavior, IDENTITY_GUIDELINE),
		{"thinking": "fallback", "speech": "我先听你说。", "action": "none", "artifact_id": "", "end_dialogue": false},
		false
	)


func _call_npc(state) -> Dictionary:
	return await client.chat_json(
		"npc_llm",
		PromptBuilderScript.npc_dialogue_system(),
		PromptBuilderScript.npc_dialogue_user(state),
		{"speech": "你还没有回答我的问题。", "action": "none"},
		false
	)


func _call_post_action(state, behavior: String) -> Dictionary:
	return await client.chat_json(
		"player_llm",
		PromptBuilderScript.post_action_system(),
		PromptBuilderScript.post_action_user(state, behavior),
		{"thinking": "fallback", "action": "leave", "artifact_id": ""},
		false
	)


func _is_checkpoint_pass(round_index: int, action: String, state) -> bool:
	if state.ended:
		return false
	if round_index == 2:
		return action == "duel"
	if round_index == 3:
		return action == "assassinate"
	if round_index == 4:
		return action == "leave"
	return false


func _print_events(events: Array) -> void:
	for event in events:
		print("EVENT %s" % String(event))
