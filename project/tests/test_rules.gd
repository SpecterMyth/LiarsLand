extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const RulesEngineScript := preload("res://scripts/core/rules_engine.gd")
const LlmClientScript := preload("res://scripts/llm/llm_client.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := ChapterLoaderScript.load_chapter("res://data/chapter_01.json")
	assert(not data.is_empty())
	assert(data.get("artifacts", []).size() == 10)

	var state = GameStateScript.new()
	state.load_chapter(data)
	assert(state.world_intel_questions.size() == 6)
	assert(state.world_intel_answers.size() == 6)
	assert(state.player.get("dominion_requirement", []).size() == 3)
	assert(state.player.get("ascension_requirement", []).size() == 1)
	assert(state.npc_choices.size() > 0)

	state.choose_npc(0)
	var npc := state.current_npc()
	var before_player_energy := int(state.player.get("energy", 0))
	var before_npc_energy := int(npc.get("energy", 0))
	RulesEngineScript.apply_dialogue_turn(state, "abcde", "abcdefg")
	npc = state.current_npc()
	assert(int(state.player.get("energy", 0)) == before_player_energy + 7)
	assert(int(npc.get("energy", 0)) == before_npc_energy + 5)
	assert(state.player.get("memory", []).size() > 0)
	assert(npc.get("memory", []).size() > 0)

	var artifact_id := String(state.artifacts[0].get("id", ""))
	state.shop_items = [artifact_id]
	state.player["energy"] = int(state.get_artifact(artifact_id).get("price", 0))
	var events := RulesEngineScript.buy_player_artifact(state, artifact_id)
	assert(not events.is_empty())
	assert(state.has_artifact(state.player, artifact_id))
	assert(artifact_id in state.player.get("artifact_history", []))

	state.player["ascension_requirement"] = [artifact_id]
	var old_level := int(state.player.get("level", 1))
	events = RulesEngineScript.ascend_player(state, {"charm": 2, "hp": 1})
	assert(not events.is_empty())
	assert(int(state.player.get("level", 1)) == old_level + 1)
	assert(not state.has_artifact(state.player, artifact_id))
	assert(artifact_id in state.player.get("artifact_history", []))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	var gift_id := String(state.artifacts[1].get("id", ""))
	state.add_artifact(npc, gift_id)
	npc["affinity"] = 8
	state.set_current_npc(npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "gift", "accept", {"gift_offer": {"artifact_id": gift_id, "affinity_required": 6}})
	assert(state.has_artifact(state.player, gift_id))
	assert(not events.is_empty())

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
	assert(state.has_artifact(state.player, npc_trade_id))
	assert(state.has_artifact(npc, player_trade_id))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	npc["true_stance"] = "friend"
	npc["affinity"] = 10
	var question_id := String(npc.get("intel", [])[0].get("question_id", ""))
	var correct_option := String(state.world_intel_answers.get(question_id, ""))
	state.set_current_npc(npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "hello", "reply")
	assert(state.intel_testimonies.has(question_id))
	assert(state.intel_testimonies[question_id].has(correct_option))

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	npc["true_stance"] = "enemy"
	npc["affinity"] = 10
	question_id = String(npc.get("intel", [])[0].get("question_id", ""))
	var wrong_option := String(npc.get("intel", [])[0].get("wrong_option_id", ""))
	state.set_current_npc(npc)
	events = RulesEngineScript.apply_dialogue_turn(state, "hello", "reply")
	assert(state.intel_testimonies.has(question_id))
	assert(state.intel_testimonies[question_id].has(wrong_option))

	state.load_chapter(data)
	var carried_id := String(state.artifacts[0].get("id", ""))
	state.add_artifact(state.player, carried_id)
	state.player["level"] = 4
	state.player["dominion_requirement"] = [carried_id]
	RulesEngineScript.check_chapter_resolution(state)
	assert(not state.ended)
	assert(not state.victory)
	assert(state.chapter_index == 0)
	assert(state.has_artifact(state.player, carried_id))
	state.player_declared_dominion = true
	RulesEngineScript.check_chapter_resolution(state)
	assert(state.chapter_index == 1)
	assert(not state.ended)

	state.load_chapter(data)
	state.choose_npc(0)
	npc = state.current_npc()
	npc["true_stance"] = "friend"
	npc["stats"]["assassination_defense"] = 0
	state.set_current_npc(npc)
	state.player["stats"]["assassination_attack"] = 99
	events = RulesEngineScript.resolve_player_action(state, "assassinate")
	assert(state.ended)
	assert(not state.victory)

	state.load_chapter(data)
	state.chapter_round = state.max_rounds - 1
	events = RulesEngineScript.finish_round(state)
	assert(state.ended)
	assert(not state.victory)

	state.load_chapter(data)
	var answers: Dictionary = state.world_intel_answers.duplicate(true)
	events = RulesEngineScript.submit_world_intel(state, answers)
	assert(state.ended)
	assert(state.victory)

	state.load_chapter(data)
	answers = state.world_intel_answers.duplicate(true)
	var first_question := String(state.world_intel_questions[0].get("id", ""))
	answers[first_question] = state.first_other_world_intel_option(first_question, String(state.world_intel_answers.get(first_question, "")))
	events = RulesEngineScript.submit_world_intel(state, answers)
	assert(state.ended)
	assert(not state.victory)

	state.load_chapter(data)
	state.max_player_chars = 1
	state.choose_npc(0)
	events = RulesEngineScript.apply_dialogue_turn(state, "too long", "reply")
	assert(state.ended)
	assert(not state.victory)
	assert(state.intel_submitted)

	var client := LlmClientScript.new()
	root.add_child(client)
	var parsed := client.parse_json_response("```json\n{\"thinking\":\"think\",\"speech\":\"hello\",\"action\":\"gift\",\"artifact_id\":\"moon_lantern\",\"end_dialogue\":true}\n```", {})
	assert(parsed.get("thinking") == "think")
	assert(parsed.get("action") == "gift")
	assert(parsed.get("artifact_id") == "moon_lantern")
	assert(parsed.get("end_dialogue") == true)
	client.queue_free()
	await process_frame

	print("LiarsLand world intel and chapter flow rule tests passed.")
	quit(0)
