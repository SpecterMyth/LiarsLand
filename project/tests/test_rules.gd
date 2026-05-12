extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const RulesEngineScript := preload("res://scripts/core/rules_engine.gd")
const LlmClientScript := preload("res://scripts/llm/llm_client.gd")

var test_failed := false


func _init() -> void:
	_run()


func _run() -> void:
	var data := ChapterLoaderScript.load_chapter("res://data/chapter_01.json")
	_must(not data.is_empty())
	_must(data.get("artifacts", []).size() == 10)

	var state = GameStateScript.new()
	state.load_chapter(data)
	state.choose_npc(0)
	var npc := state.current_npc()
	var before_player_energy := int(state.player.get("energy", 0))
	var before_npc_energy := int(npc.get("energy", 0))
	var events := RulesEngineScript.apply_dialogue_turn(state, "abcde", "abcdefg")
	npc = state.current_npc()
	_must(int(state.player.get("energy", 0)) == before_player_energy + 7)
	_must(int(npc.get("energy", 0)) == before_npc_energy + 5)
	_must(state.player.get("memory", []).size() > 0)
	_must(npc.get("memory", []).size() > 0)

	var artifact_id := String(state.artifacts[0].get("id", ""))
	state.shop_items = [artifact_id]
	state.player["energy"] = int(state.get_artifact(artifact_id).get("price", 0))
	events = RulesEngineScript.buy_player_artifact(state, artifact_id)
	_must(not events.is_empty())
	_must(state.has_artifact(state.player, artifact_id))
	_must(artifact_id in state.player.get("artifact_history", []))

	state.player["ascension_requirement"] = [artifact_id]
	var old_level := int(state.player.get("level", 1))
	events = RulesEngineScript.ascend_player(state, {"charm": 2, "hp": 1})
	_must(not events.is_empty())
	_must(int(state.player.get("level", 1)) == old_level + 1)
	_must(not state.has_artifact(state.player, artifact_id))
	_must(artifact_id in state.player.get("artifact_history", []))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var gift_id := String(state.artifacts[1].get("id", ""))
	state.add_artifact(npc, gift_id)
	npc["affinity"] = 8
	state.set_current_npc(npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "gift", "accept", {"gift_offer": {"artifact_id": gift_id, "affinity_required": 6}})
	_must(state.has_artifact(state.player, gift_id))
	_must(not events.is_empty())

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var npc_trade_id := String(state.artifacts[2].get("id", ""))
	var player_trade_id := String(state.artifacts[3].get("id", ""))
	state.add_artifact(npc, npc_trade_id)
	state.add_artifact(state.player, player_trade_id)
	npc["affinity"] = 6
	state.set_current_npc(npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "trade", "deal", {"exchange_offer": {"npc_artifact_id": npc_trade_id, "player_artifact_id": player_trade_id, "affinity_required": 4}})
	npc = state.current_npc()
	_must(state.has_artifact(state.player, npc_trade_id))
	_must(state.has_artifact(npc, player_trade_id))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	npc["true_stance"] = "friend"
	npc["affinity"] = 10
	var question_id := String(npc.get("intel", [])[0].get("question_id", ""))
	var correct_option := String(state.world_intel_answers.get(question_id, ""))
	state.set_current_npc(npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "hello", "reply")
	_must(state.intel_testimonies.has(question_id))
	_must(state.intel_testimonies[question_id].has(correct_option))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	npc["true_stance"] = "enemy"
	npc["affinity"] = 10
	question_id = String(npc.get("intel", [])[0].get("question_id", ""))
	correct_option = String(state.world_intel_answers.get(question_id, ""))
	var wrong_option := String(npc.get("intel", [])[0].get("wrong_option_id", ""))
	if wrong_option == correct_option or wrong_option.is_empty():
		wrong_option = state.first_other_world_intel_option(question_id, correct_option)
	state.set_current_npc(npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "hello", "reply")
	_must(state.intel_testimonies.has(question_id))
	_must(state.intel_testimonies[question_id].has(wrong_option))

	state.load_chapter(data)
	var carried_id := String(state.artifacts[0].get("id", ""))
	state.add_artifact(state.player, carried_id)
	state.player["level"] = 4
	state.player["dominion_requirement"] = [carried_id]
	RulesEngineScript.check_chapter_resolution(state)
	_must(not state.ended)
	_must(not state.victory)
	_must(state.chapter_index == 0)
	_must(state.has_artifact(state.player, carried_id))
	state.player_declared_dominion = true
	RulesEngineScript.check_chapter_resolution(state)
	_must(state.chapter_index == 1)
	_must(not state.ended)
	_must(state.npc_choices.size() == 3)

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	npc["true_stance"] = "friend"
	npc["stats"]["assassination_defense"] = 0
	state.set_current_npc(npc)
	state.player["stats"]["assassination_attack"] = 99
	events = RulesEngineScript.resolve_player_action(state, "assassinate")
	_must(state.ended)
	_must(not state.victory)

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var duel_win_loot := String(state.artifacts[4].get("id", ""))
	state.add_artifact(npc, duel_win_loot)
	npc["stats"]["hp"] = 1
	npc["stats"]["frontal_attack"] = 1
	npc["stats"]["frontal_defense"] = 0
	question_id = String(npc.get("intel", [])[0].get("question_id", ""))
	state.set_current_npc(npc)
	state.player["stats"]["hp"] = 10
	state.player["stats"]["frontal_attack"] = 99
	state.player["stats"]["frontal_defense"] = 99
	events = RulesEngineScript.resolve_player_action(state, "duel")
	npc = state.current_npc()
	_must(not state.ended)
	_must(bool(npc.get("alive", true)))
	_must(state.has_artifact(state.player, duel_win_loot))
	_must(not state.intel_testimonies.has(question_id))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var duel_loss_loot := String(state.artifacts[5].get("id", ""))
	state.add_artifact(state.player, duel_loss_loot)
	npc["stats"]["hp"] = 10
	npc["stats"]["frontal_attack"] = 99
	npc["stats"]["frontal_defense"] = 99
	state.set_current_npc(npc)
	state.player["stats"]["hp"] = 1
	state.player["stats"]["frontal_attack"] = 1
	state.player["stats"]["frontal_defense"] = 0
	events = RulesEngineScript.resolve_player_action(state, "duel")
	npc = state.current_npc()
	_must(not state.ended)
	_must(state.has_artifact(npc, duel_loss_loot))
	_must(not state.has_artifact(state.player, duel_loss_loot))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var lethal_win_loot := String(state.artifacts[6].get("id", ""))
	var exposed_artifact := String(state.player.get("dominion_requirement", [])[0])
	state.add_artifact(npc, lethal_win_loot)
	npc["true_stance"] = "enemy"
	npc["stats"]["hp"] = 1
	npc["stats"]["frontal_attack"] = 1
	npc["stats"]["frontal_defense"] = 0
	npc["stats"]["assassination_defense"] = 99
	question_id = String(npc.get("intel", [])[0].get("question_id", ""))
	state.set_current_npc(npc)
	state.player["stats"]["hp"] = 10
	state.player["stats"]["frontal_attack"] = 99
	state.player["stats"]["frontal_defense"] = 99
	state.player["stats"]["assassination_attack"] = 0
	events = RulesEngineScript.resolve_player_action(state, "assassinate")
	npc = state.current_npc()
	_must(not state.ended)
	_must(not bool(npc.get("alive", true)))
	_must(state.has_artifact(state.player, lethal_win_loot))
	_must(exposed_artifact in state.exposed_dominion_artifact_ids)
	_must(not state.intel_testimonies.has(question_id))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var lethal_loss_loot := String(state.artifacts[7].get("id", ""))
	exposed_artifact = String(state.player.get("dominion_requirement", [])[0])
	state.add_artifact(state.player, lethal_loss_loot)
	npc["true_stance"] = "enemy"
	npc["stats"]["hp"] = 10
	npc["stats"]["frontal_attack"] = 99
	npc["stats"]["frontal_defense"] = 99
	npc["stats"]["assassination_defense"] = 99
	state.set_current_npc(npc)
	state.player["stats"]["hp"] = 1
	state.player["stats"]["frontal_attack"] = 1
	state.player["stats"]["frontal_defense"] = 0
	state.player["stats"]["assassination_attack"] = 0
	events = RulesEngineScript.resolve_player_action(state, "assassinate")
	npc = state.current_npc()
	_must(state.ended)
	_must(not state.victory)
	_must(state.has_artifact(npc, lethal_loss_loot))
	_must(exposed_artifact in state.exposed_dominion_artifact_ids)

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var player_gift_id := String(state.artifacts[8].get("id", ""))
	state.add_artifact(state.player, player_gift_id)
	npc["affinity"] = 3
	state.set_current_npc(npc)
	events = RulesEngineScript.resolve_player_action(state, "gift", {"artifact_id": player_gift_id})
	npc = state.current_npc()
	_must(int(npc.get("affinity", 0)) == 8)

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	player_gift_id = String(state.artifacts[8].get("id", ""))
	state.add_artifact(state.player, player_gift_id)
	npc["affinity"] = 8
	state.set_current_npc(npc)
	events = RulesEngineScript.resolve_player_action(state, "gift", {"artifact_id": player_gift_id})
	npc = state.current_npc()
	_must(int(npc.get("affinity", 0)) == 10)

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var cast_miss_id := String(state.artifacts[9].get("id", ""))
	state.add_artifact(state.player, cast_miss_id)
	npc["dominion_requirement"] = [String(state.artifacts[0].get("id", ""))]
	state.set_current_npc(npc)
	events = RulesEngineScript.resolve_player_action(state, "cast", {"artifact_id": cast_miss_id})
	npc = state.current_npc()
	_must(state.has_artifact(npc, cast_miss_id))
	_must(not state.has_artifact(state.player, cast_miss_id))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var cast_kill_id := String(state.artifacts[0].get("id", ""))
	state.add_artifact(state.player, cast_kill_id)
	npc["true_stance"] = "friend"
	npc["inventory"] = []
	npc["dominion_requirement"] = [cast_kill_id]
	state.set_current_npc(npc)
	events = RulesEngineScript.resolve_player_action(state, "cast", {"artifact_id": cast_kill_id})
	_must(state.ended)
	_must(not state.victory)

	state.load_chapter(data)
	state.chapter_round = state.max_rounds - 1
	events = RulesEngineScript.finish_round(state)
	_must(state.ended)
	_must(not state.victory)

	state.load_chapter(data)
	var answers: Dictionary = state.world_intel_answers.duplicate(true)
	events = RulesEngineScript.submit_world_intel(state, answers, true)
	_must(state.ended)
	_must(state.victory)

	state.load_chapter(data)
	answers = state.world_intel_answers.duplicate(true)
	var first_question := String(state.world_intel_questions[0].get("id", ""))
	answers[first_question] = state.first_other_world_intel_option(first_question, String(state.world_intel_answers.get(first_question, "")))
	events = RulesEngineScript.submit_world_intel(state, answers, true)
	_must(state.ended)
	_must(not state.victory)

	state.load_chapter(data)
	answers = state.world_intel_answers.duplicate(true)
	events = RulesEngineScript.submit_world_intel(state, answers)
	_must(not state.ended)
	_must(not state.intel_submitted)
	_must(events.size() > 0)

	state.load_chapter(data)
	state.max_player_chars = 1
	state.choose_npc(0)
	events = RulesEngineScript.apply_dialogue_turn(state, "too long", "reply")
	_must(state.ended)
	_must(not state.victory)
	_must(not state.intel_submitted)

	state.load_chapter(data)
	state.chapter_round = 5
	state.refresh_npc_choices()
	state.choose_npc(0)
	var action_npc: Dictionary = state.current_npc()
	var action_stats: Dictionary = action_npc.get("stats", {})
	action_stats["assassination_attack"] = 99
	action_npc["stats"] = action_stats
	state.set_current_npc(action_npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "whatever", "You did not answer my question.", {"action": "assassinate"})
	_must(state.ended)
	_must(not state.victory)

	var client := LlmClientScript.new()
	root.add_child(client)
	var parsed := client.parse_json_response("```json\n{\"thinking\":\"think\",\"speech\":\"hello\",\"action\":\"gift\",\"artifact_id\":\"moon_lantern\",\"end_dialogue\":true}\n```", {})
	_must(parsed.get("thinking") == "think")
	_must(parsed.get("action") == "gift")
	_must(parsed.get("artifact_id") == "moon_lantern")
	_must(parsed.get("end_dialogue") == true)
	client.queue_free()

	if test_failed:
		quit(1)
	else:
		print("LiarsLand world intel and chapter flow rule tests passed.")
		quit(0)


func _must(condition: bool) -> void:
	if condition:
		return
	test_failed = true
	push_error("test_rules assertion failed")

