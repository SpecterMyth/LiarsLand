extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := ChapterLoaderScript.load_chapter("res://data/council_chapter_01.json")
	var state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	var npc_id := String(state.current_npc().get("id", ""))
	var events: Array[String] = []
	var payload := {
		"counterpart_id": npc_id,
		"proposals": [
			{"crime_id": "duck_house_expense", "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": "hush_money_invoice", "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": "gold_bar_favors", "vote": CouncilRulesEngineScript.VOTE_INNOCENT}
		]
	}
	_must(CouncilRulesEngineScript.apply_trade_offer(state, "player", payload, events))
	_must(_count_trade_votes(state, "duck_house_expense") == 2)
	_must(_count_trade_votes(state, "hush_money_invoice") == 2)
	_must(_count_trade_votes(state, "gold_bar_favors") == 2)
	_must(_has_vote(state, "player", "duck_house_expense", CouncilRulesEngineScript.VOTE_INNOCENT))
	_must(_has_vote(state, npc_id, "hush_money_invoice", CouncilRulesEngineScript.VOTE_INNOCENT))
	_must(_has_vote(state, npc_id, "gold_bar_favors", CouncilRulesEngineScript.VOTE_INNOCENT))

	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	npc_id = String(state.current_npc().get("id", ""))
	events.clear()
	payload = {
		"counterpart_id": "player",
		"proposals": [
			{"crime_id": "duck_house_expense", "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": "hush_money_invoice", "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": "gold_bar_favors", "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": "lockdown_party", "vote": CouncilRulesEngineScript.VOTE_INNOCENT}
		]
	}
	CouncilRulesEngineScript.apply_trade_offer(state, "player", payload, events)
	_must(_count_trade_votes(state, "lockdown_party") == 0)

	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	npc_id = String(state.current_npc().get("id", ""))
	events.clear()
	CouncilRulesEngineScript.cast_vote(state, "player", "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, "test", events)
	payload = {
		"counterpart_id": "player",
		"proposals": [
			{"crime_id": "duck_house_expense", "vote": CouncilRulesEngineScript.VOTE_GUILTY},
			{"crime_id": "hush_money_invoice", "vote": CouncilRulesEngineScript.VOTE_INNOCENT}
		]
	}
	CouncilRulesEngineScript.apply_trade_offer(state, npc_id, payload, events)
	_must(_has_vote(state, "player", "hush_money_invoice", CouncilRulesEngineScript.VOTE_INNOCENT))
	_must(_has_vote(state, npc_id, "hush_money_invoice", CouncilRulesEngineScript.VOTE_INNOCENT))
	print("Council trade flow test passed.")
	quit(0)


func _count_trade_votes(state, crime_id: String) -> int:
	var count := 0
	for record in state.council_vote_records:
		if String(record.get("crime_id", "")) == crime_id and String(record.get("source", "")) == "trade":
			count += 1
	return count


func _has_vote(state, member_id: String, crime_id: String, vote: String) -> bool:
	for record in state.council_vote_records:
		if String(record.get("member_id", "")) == member_id and String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			return true
	return false


func _must(condition: bool) -> void:
	if condition:
		return
	push_error("Council trade flow assertion failed.")
	quit(1)
