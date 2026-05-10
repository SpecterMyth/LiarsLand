extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const RulesEngineScript := preload("res://scripts/core/rules_engine.gd")
const LlmClientScript := preload("res://scripts/llm/llm_client.gd")
const PromptBuilderScript := preload("res://scripts/llm/prompt_builder.gd")

const IDENTITY_GUIDELINE := "## 对外身份\n来自边境的灰狐抄写员，替商队整理族谱与债契。\n\n## 对手应如何认知我\n- 以这份公开身份理解我的言行。\n- 不知道我的真实目标，除非我在对话中暴露。\n- 优先把我视为可以交易、试探、被利用或结盟的外来者。"
const BASE_BEHAVIOR := "根据对方的问题进行回复"

var client
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var round_index := int(OS.get_environment("LLM_PROBE_ROUND"))
	var fused := OS.get_environment("LLM_PROBE_FUSED") == "1"
	if round_index <= 0:
		round_index = 3
	var data := ChapterLoaderScript.load_chapter("res://data/chapter_01.json")
	client = LlmClientScript.new()
	client.config = LlmClientScript.load_config()
	root.add_child(client)
	await process_frame
	await _probe(data, round_index - 1, fused)
	client.queue_free()
	quit(1 if failed else 0)


func _probe(data: Dictionary, round_index: int, fused: bool) -> void:
	var state = GameStateScript.new()
	state.load_chapter(data)
	state.chapter_round = round_index
	state.refresh_npc_choices()
	state.choose_npc(0)
	var behavior := BASE_BEHAVIOR
	if fused:
		behavior += "\n\n" + _fused_rule(round_index)
	print("ROUND=%d fused=%s npc=%s mock=%s" % [round_index + 1, str(fused), state.current_npc().get("public_name", "对方"), str(client.use_mock_llm())])
	for _i in range(3):
		state.turn += 1
		var player := await _call_player(state, behavior)
		print("P%d thinking=%s" % [state.turn, String(player.get("thinking", "")).left(180)])
		print("P%d speech=%s action=%s" % [state.turn, String(player.get("speech", "")), String(player.get("action", "none"))])
		var action := String(player.get("action", "none")).strip_edges().to_lower()
		if action != "" and action != "none":
			var events := RulesEngineScript.resolve_player_action(state, action, {"artifact_id": String(player.get("artifact_id", ""))})
			_print_events(events)
			print("RESULT ended=%s passed=%s reason=%s" % [str(state.ended), str(_passed(round_index, action, state)), state.end_reason])
			return
		state.add_dialogue("player", String(player.get("speech", "")))
		var npc := await _call_npc(state)
		print("N%d speech=%s action=%s" % [state.turn, String(npc.get("speech", "")), String(npc.get("action", "none"))])
		state.add_dialogue("npc", String(npc.get("speech", "")))
		var events := RulesEngineScript.apply_dialogue_turn(state, String(player.get("speech", "")), String(npc.get("speech", "")), npc)
		_print_events(events)
		if state.ended:
			print("RESULT ended=true passed=false reason=%s" % state.end_reason)
			return
	var post := await _call_post_action(state, behavior)
	print("POST thinking=%s action=%s" % [String(post.get("thinking", "")).left(180), String(post.get("action", "leave"))])
	var post_action := String(post.get("action", "leave"))
	var post_events := RulesEngineScript.resolve_player_action(state, post_action, {"artifact_id": String(post.get("artifact_id", ""))})
	_print_events(post_events)
	print("RESULT ended=%s passed=%s reason=%s" % [str(state.ended), str(_passed(round_index, post_action, state)), state.end_reason])


func _fused_rule(round_index: int) -> String:
	match round_index:
		2:
			return "当对方出现贴近、拖延、封路、毒刃、观察弱点等暗杀前兆时，不继续交易、解释或等待更多证据，应立即主动决斗（action=duel）打断暗杀节奏。"
		3:
			return "当对方正面战力压制我、持续逼迫公开决斗或展示重甲强武器时，不要接受决斗、不继续解释，应立即主动暗杀（action=assassinate），不接受对方设定的战斗方式。"
		4:
			return "对未知对手使用短句试探；当对方连续追问身份、目的、法器或情报来源时，不继续解释，应立即撤离。"
	return ""


func _call_player(state, behavior: String) -> Dictionary:
	return await client.chat_json("player_llm", PromptBuilderScript.player_dialogue_system(state), PromptBuilderScript.player_dialogue_user(state, behavior, IDENTITY_GUIDELINE), {"thinking": "fallback", "speech": "我先听你说。", "action": "none", "artifact_id": "", "end_dialogue": false}, false)


func _call_npc(state) -> Dictionary:
	return await client.chat_json("npc_llm", PromptBuilderScript.npc_dialogue_system(), PromptBuilderScript.npc_dialogue_user(state), {"speech": "你还没有回答我的问题。", "action": "none"}, false)


func _call_post_action(state, behavior: String) -> Dictionary:
	return await client.chat_json("player_llm", PromptBuilderScript.post_action_system(), PromptBuilderScript.post_action_user(state, behavior), {"thinking": "fallback", "action": "leave", "artifact_id": ""}, false)


func _passed(round_index: int, action: String, state) -> bool:
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
