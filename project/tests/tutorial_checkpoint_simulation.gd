extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const RulesEngineScript := preload("res://scripts/core/rules_engine.gd")

var failed := false


func _init() -> void:
	var data := ChapterLoaderScript.load_chapter("res://data/chapter_01.json")
	_simulate_round_3(data)
	_simulate_round_4(data)
	_simulate_round_5(data)
	if failed:
		quit(1)
	else:
		print("Tutorial checkpoint simulations passed.")
		quit(0)


func _simulate_round_3(data: Dictionary) -> void:
	var state = _setup_round(data, 2)
	var events := RulesEngineScript.apply_dialogue_turn(
		state,
		"我先回答你的问题，再看看你想做什么。",
		"你一直绕开位置和距离，我已经贴得足够近了。"
	)
	_must(state.ended, "round 3 without duel should fail")
	_must(state.end_reason.contains("暗杀玩家"), "round 3 failure should be assassination")
	print("[第3关/无关键规则] 玩家继续对话 -> %s" % state.end_reason)

	state = _setup_round(data, 2)
	var loot: Array = state.current_npc().get("inventory", []).duplicate()
	events = RulesEngineScript.resolve_player_action(state, "duel")
	_must(not state.ended, "round 3 with duel should survive")
	for artifact_id in loot:
		_must(state.has_artifact(state.player, String(artifact_id)), "round 3 duel should loot artifact")
	print("[第3关/融合后] 玩家主动决斗 -> 获得 %d 个法器" % loot.size())


func _simulate_round_4(data: Dictionary) -> void:
	var state = _setup_round(data, 3)
	var events := RulesEngineScript.resolve_player_action(state, "duel")
	_must(state.ended, "round 4 duel should fail")
	_must(state.end_reason.contains("决斗"), "round 4 duel failure should be duel")
	print("[第4关/无关键规则] 玩家接受决斗 -> %s" % state.end_reason)

	state = _setup_round(data, 3)
	var loot: Array = state.current_npc().get("inventory", []).duplicate()
	events = RulesEngineScript.resolve_player_action(state, "assassinate")
	_must(not state.ended, "round 4 with assassinate should survive")
	for artifact_id in loot:
		_must(state.has_artifact(state.player, String(artifact_id)), "round 4 assassinate should loot artifact")
	print("[第4关/融合后] 玩家主动暗杀 -> 获得 %d 个法器" % loot.size())


func _simulate_round_5(data: Dictionary) -> void:
	var state = _setup_round(data, 4)
	state.add_dialogue("player", "我的身份、目的、法器需求和情报来源都可以慢慢解释。我来到这里是为了核验许多复杂线索，也希望你理解我的处境。")
	var events := RulesEngineScript.apply_dialogue_turn(state, "我还可以继续补充更多细节。", "请继续。")
	_must(state.ended, "round 5 over-explaining should fail")
	_must(state.end_reason.contains("拖延失败") or state.end_reason.contains("撤离时机失败"), "round 5 failure should be stalling")
	print("[第5关/无关键规则] 玩家长篇解释 -> %s" % state.end_reason)

	state = _setup_round(data, 4)
	events = RulesEngineScript.resolve_player_action(state, "leave")
	_must(not state.ended, "round 5 leave should survive")
	_must(events.size() > 0, "round 5 leave should produce event")
	print("[第5关/融合后] 玩家及时撤离 -> %s" % events[0])


func _setup_round(data: Dictionary, round_index: int):
	var state = GameStateScript.new()
	state.load_chapter(data)
	state.chapter_round = round_index
	state.refresh_npc_choices()
	state.choose_npc(0)
	state.turn = 3
	return state


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
