extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state = GameStateScript.new()
	var data := ChapterLoaderScript.load_chapter("res://data/council_chapter_01.json")
	CouncilRulesEngineScript.setup_state(state, data)
	assert(state.council_mode)
	assert(CouncilRulesEngineScript.total_members(state) == 4)
	assert(CouncilRulesEngineScript.execution_threshold(state) == 2)
	assert(_faction_counts_are_balanced(state))
	var events: Array[String] = []
	CouncilRulesEngineScript.cast_vote(state, "player", "duck_house_expense", "guilty", "test", events)
	assert(not state.ended)
	CouncilRulesEngineScript.cast_vote(state, "npc_fox", "duck_house_expense", "guilty", "test", events)
	assert(state.ended)
	assert(CouncilRulesEngineScript.alive_count(state) <= 3)
	assert(not String(state.end_reason).is_empty())
	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data, {"player_faction": "red_hat"})
	for npc in state.npcs:
		npc["alive"] = false
	state.chapter_round = state.max_rounds - 1
	events.clear()
	CouncilRulesEngineScript.finish_round(state, events)
	assert(state.ended)
	assert(state.victory)
	assert(CouncilRulesEngineScript.alive_count(state) == 1)
	print("Council rules test passed.")
	quit(0)


func _faction_counts_are_balanced(state) -> bool:
	var counts := {}
	for member in CouncilRulesEngineScript.all_members(state):
		var faction := String(member.get("hidden_faction", ""))
		counts[faction] = int(counts.get(faction, 0)) + 1
	var min_count := 999
	var max_count := -999
	for faction in counts.keys():
		var count := int(counts[faction])
		min_count = mini(min_count, count)
		max_count = maxi(max_count, count)
	return max_count - min_count <= 1
