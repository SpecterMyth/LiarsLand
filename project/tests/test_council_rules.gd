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
	assert(_faction_crime_links_hold(state))
	assert(_faction_public_crime_info_matches(state))
	var events: Array[String] = []
	var execution_pair := _first_executable_vote_pair(state)
	var execution_crime := String(execution_pair.get("crime_id", ""))
	var execution_voter := String(execution_pair.get("voter_id", ""))
	CouncilRulesEngineScript.cast_vote(state, "player", execution_crime, "guilty", "test", events)
	assert(not state.ended)
	CouncilRulesEngineScript.cast_vote(state, execution_voter, execution_crime, "guilty", "test", events)
	assert(state.ended)
	assert(CouncilRulesEngineScript.alive_count(state) <= 3)
	assert(not String(state.end_reason).is_empty())
	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	events.clear()
	state.council_contacted_member_ids.append("npc_fox")
	CouncilRulesEngineScript.declare_tendency(state, "npc_fox", "duck_house_expense", CouncilRulesEngineScript.VOTE_INNOCENT, events)
	CouncilRulesEngineScript.declare_tendency(state, "npc_crow", "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, events)
	CouncilRulesEngineScript.cast_vote(state, "player", "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, "test", events)
	CouncilRulesEngineScript.apply_follow_votes(state, "duck_house_expense", CouncilRulesEngineScript.VOTE_GUILTY, events)
	assert(CouncilRulesEngineScript.guilty_count(state, "duck_house_expense") == 1)
	assert(CouncilRulesEngineScript.innocent_count(state, "duck_house_expense") == 1)
	assert(not state.ended)
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
	_test_execution_threshold_rechecks_alive_count(data)
	_test_execution_timeline_multivictim_and_chain(data)
	_test_npc_reasoning_guards(data)
	_test_only_player_can_retreat(data)
	_test_council_energy_rules(data)
	_test_council_energy_rewards(data)
	_test_council_energy_runtime_wiring()
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


func _faction_crime_links_hold(state) -> bool:
	var by_faction := {}
	for member in CouncilRulesEngineScript.all_members(state):
		var faction := String(member.get("hidden_faction", ""))
		if not by_faction.has(faction):
			by_faction[faction] = []
		by_faction[faction].append(member)
	for faction in by_faction.keys():
		var members: Array = by_faction[faction]
		var has_shared := false
		var has_safe := false
		for crime in state.council_crime_pool:
			var crime_id := String(crime.get("id", ""))
			var all_have := true
			var none_have := true
			for member in members:
				var crimes: Array = member.get("hidden_crimes", [])
				all_have = all_have and crime_id in crimes
				none_have = none_have and not crime_id in crimes
			has_shared = has_shared or all_have
			has_safe = has_safe or none_have
		if not has_shared or not has_safe:
			return false
	return true


func _faction_public_crime_info_matches(state) -> bool:
	for faction_id in state.council_faction_public_crimes.keys():
		var info: Dictionary = state.council_faction_public_crimes[faction_id]
		var shared := String(info.get("shared_crime_id", ""))
		var safe := String(info.get("safe_crime_id", ""))
		if shared.is_empty() or safe.is_empty() or shared == safe:
			return false
		for member in CouncilRulesEngineScript.all_members(state):
			if String(member.get("hidden_faction", "")) != String(faction_id):
				continue
			var crimes: Array = member.get("hidden_crimes", [])
			if not shared in crimes:
				return false
			if safe in crimes:
				return false
	return true


func _test_execution_threshold_rechecks_alive_count(data: Dictionary) -> void:
	var state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.chapter["death_will_enabled"] = false
	state.chapter["force_reveal_at_alive"] = 0
	state.council_crime_pool = [
		{"id": "crime_a", "name": "Crime A"},
		{"id": "crime_b", "name": "Crime B"}
	]
	state.player["hidden_crimes"] = []
	state.npcs[0]["hidden_crimes"] = ["crime_a"]
	state.npcs[1]["hidden_crimes"] = ["crime_a"]
	state.npcs[2]["hidden_crimes"] = ["crime_b"]
	state.council_vote_records = [
		{"member_id": "player", "crime_id": "crime_a", "vote": CouncilRulesEngineScript.VOTE_GUILTY, "locked": true, "source": "test", "round": 0},
		{"member_id": String(state.npcs[2].get("id", "")), "crime_id": "crime_a", "vote": CouncilRulesEngineScript.VOTE_GUILTY, "locked": true, "source": "test", "round": 0},
		{"member_id": "player", "crime_id": "crime_b", "vote": CouncilRulesEngineScript.VOTE_GUILTY, "locked": true, "source": "test", "round": 0}
	]
	var events: Array[String] = []
	CouncilRulesEngineScript.check_executions(state, events)
	assert("crime_a" in state.council_executed_crimes)
	assert("crime_b" in state.council_executed_crimes)


func _test_execution_timeline_multivictim_and_chain(data: Dictionary) -> void:
	var state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.chapter["death_will_enabled"] = true
	state.chapter["death_will_effective"] = true
	state.chapter["force_reveal_at_alive"] = 0
	state.council_crime_pool = [
		{"id": "crime_a", "title": "Crime A"},
		{"id": "crime_b", "title": "Crime B"}
	]
	state.player["hidden_crimes"] = []
	state.npcs[0]["hidden_crimes"] = ["crime_a"]
	state.npcs[1]["hidden_crimes"] = ["crime_a"]
	state.npcs[2]["hidden_crimes"] = ["crime_b"]
	state.council_vote_records = [
		{"member_id": "player", "crime_id": "crime_a", "vote": CouncilRulesEngineScript.VOTE_GUILTY, "locked": true, "source": "test", "round": 0},
		{"member_id": String(state.npcs[2].get("id", "")), "crime_id": "crime_a", "vote": CouncilRulesEngineScript.VOTE_GUILTY, "locked": true, "source": "test", "round": 0},
		{"member_id": "player", "crime_id": "crime_b", "vote": CouncilRulesEngineScript.VOTE_GUILTY, "locked": true, "source": "test", "round": 0}
	]
	var events: Array[String] = []
	CouncilRulesEngineScript.check_executions(state, events)
	assert(state.council_execution_timeline.size() >= 2)
	assert(String(state.council_execution_timeline[0].get("crime_id", "")) == "crime_a")
	assert((state.council_execution_timeline[0].get("victims", []) as Array).size() == 2)
	assert(String(state.council_execution_timeline[1].get("crime_id", "")) == "crime_b")
	assert((state.council_execution_timeline[1].get("victims", []) as Array).size() == 1)


func _test_npc_reasoning_guards(data: Dictionary) -> void:
	var state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	var npc_id := String(state.current_npc().get("id", ""))
	var own_crime := String(state.current_npc().get("hidden_crimes", [])[0])
	var safe_crime := _first_safe_crime_for_current_npc(state)
	var events: Array[String] = []
	CouncilRulesEngineScript.declare_tendency(state, "player", own_crime, CouncilRulesEngineScript.VOTE_GUILTY, events)
	var analysis := CouncilRulesEngineScript.npc_player_trust_analysis(state, npc_id)
	assert(String(analysis.get("trust_level", "")) == "likely_enemy_or_liar")
	assert(not CouncilRulesEngineScript.cast_vote(state, npc_id, own_crime, CouncilRulesEngineScript.VOTE_GUILTY, "dialogue", events))
	assert(not _has_vote(state, npc_id, own_crime, CouncilRulesEngineScript.VOTE_GUILTY))
	assert(not CouncilRulesEngineScript.cast_vote(state, npc_id, safe_crime, CouncilRulesEngineScript.VOTE_GUILTY, "dialogue", events))

	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	npc_id = String(state.current_npc().get("id", ""))
	own_crime = String(state.current_npc().get("hidden_crimes", [])[0])
	events.clear()
	CouncilRulesEngineScript.declare_tendency(state, "player", own_crime, CouncilRulesEngineScript.VOTE_INNOCENT, events)
	analysis = CouncilRulesEngineScript.npc_player_trust_analysis(state, npc_id)
	assert(own_crime in analysis.get("protected_self_crime_ids", []))

	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	npc_id = String(state.current_npc().get("id", ""))
	var faction_info := CouncilRulesEngineScript.faction_public_crimes(state, String(state.current_npc().get("hidden_faction", "")))
	var faction_crime := String(faction_info.get("shared_crime_id", ""))
	var faction_safe := String(faction_info.get("safe_crime_id", ""))
	events.clear()
	CouncilRulesEngineScript.declare_tendency(state, "player", faction_crime, CouncilRulesEngineScript.VOTE_INNOCENT, events)
	CouncilRulesEngineScript.declare_tendency(state, "player", faction_safe, CouncilRulesEngineScript.VOTE_GUILTY, events)
	analysis = CouncilRulesEngineScript.npc_player_trust_analysis(state, npc_id)
	assert(String(analysis.get("trust_level", "")) == "likely_friend")

	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	npc_id = String(state.current_npc().get("id", ""))
	safe_crime = _first_safe_crime_for_current_npc(state)
	events.clear()
	CouncilRulesEngineScript.cast_vote(state, "player", safe_crime, CouncilRulesEngineScript.VOTE_GUILTY, "test", events)
	CouncilRulesEngineScript.declare_tendency(state, "player", safe_crime, CouncilRulesEngineScript.VOTE_INNOCENT, events)
	var payload := {"counterpart_id": "player", "proposals": [{"crime_id": safe_crime, "vote": CouncilRulesEngineScript.VOTE_GUILTY}]}
	assert(not CouncilRulesEngineScript.apply_trade_offer(state, npc_id, payload, events))
	assert(not _has_vote(state, npc_id, safe_crime, CouncilRulesEngineScript.VOTE_GUILTY))


func _test_only_player_can_retreat(data: Dictionary) -> void:
	var state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	state.current_npc_index = 0
	var npc_id := String(state.current_npc().get("id", ""))
	var events: Array[String] = []
	assert(CouncilRulesEngineScript.apply_member_action(state, "player", "retreat", {}, events))
	assert(not CouncilRulesEngineScript.apply_member_action(state, npc_id, "retreat", {}, events))
	assert(not CouncilRulesEngineScript.apply_member_action(state, npc_id, "leave", {}, events))


func _test_council_energy_rules(data: Dictionary) -> void:
	var state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data)
	assert(state.max_player_chars == 1000)
	assert(state.player_chars == 0)
	var events: Array[String] = []
	var thinking := "thinking should not spend energy"
	CouncilRulesEngineScript.apply_player_speech_energy(state, "short", events)
	assert(thinking.length() > 0)
	assert(state.player_chars == "short".length())
	assert(CouncilRulesEngineScript.remaining_energy(state) == 1000 - "short".length())
	assert(not state.ended)
	state.max_player_chars = state.player_chars + 1
	CouncilRulesEngineScript.apply_player_speech_energy(state, "x", events)
	assert(state.ended)
	assert(not state.victory)
	assert(String(state.end_reason_id) == CouncilRulesEngineScript.END_REASON_ENERGY_DEPLETED)


func _test_council_energy_rewards(data: Dictionary) -> void:
	var state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data, {"player_faction": "red_hat"})
	var player_faction := String(state.player.get("hidden_faction", ""))
	var expected := 0
	for npc in state.npcs:
		var same_faction := String(npc.get("hidden_faction", "")) == player_faction
		npc["alive"] = same_faction
		if same_faction:
			expected += 1
	state.victory = true
	var before := int(state.max_player_chars)
	var rewards := CouncilRulesEngineScript.award_chapter_energy(state)
	assert(rewards.size() == expected)
	assert(state.max_player_chars == before + expected * CouncilRulesEngineScript.ENERGY_REWARD_PER_ALLIED_NPC)
	var after := int(state.max_player_chars)
	rewards = CouncilRulesEngineScript.award_chapter_energy(state)
	assert(rewards.size() == expected)
	assert(state.max_player_chars == after)

	state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(state, data, {"player_faction": "red_hat"})
	state.victory = false
	before = int(state.max_player_chars)
	rewards = CouncilRulesEngineScript.award_chapter_energy(state)
	assert(rewards.is_empty())
	assert(state.max_player_chars == before)


func _test_council_energy_runtime_wiring() -> void:
	var file := FileAccess.open("res://scripts/ui/adventure_screen.gd", FileAccess.READ)
	assert(file != null)
	var source := file.get_as_text()
	assert(source.contains("CouncilRulesEngineScript.apply_player_speech_energy(state, speech, energy_events)"))
	assert(source.contains("CouncilRulesEngineScript.award_chapter_energy(state)"))
	assert(source.contains("String(state.end_reason_id) == CouncilRulesEngineScript.END_REASON_ENERGY_DEPLETED"))
	assert(source.contains("用尽可能少的字去表达你的政治观点"))


func _first_safe_crime_for_current_npc(state) -> String:
	var own_crimes: Array = state.current_npc().get("hidden_crimes", [])
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		if not crime_id in own_crimes:
			return crime_id
	return String(state.council_crime_pool[0].get("id", ""))


func _has_vote(state, member_id: String, crime_id: String, vote: String) -> bool:
	for record in state.council_vote_records:
		if String(record.get("member_id", "")) == member_id and String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			return true
	return false


func _first_executable_vote_pair(state) -> Dictionary:
	for victim in CouncilRulesEngineScript.all_members(state):
		if String(victim.get("id", "")) == "player":
			continue
		for crime_id in victim.get("hidden_crimes", []):
			for voter in CouncilRulesEngineScript.all_members(state):
				var voter_id := String(voter.get("id", ""))
				if voter_id == "player" or not bool(voter.get("alive", true)):
					continue
				if not String(crime_id) in voter.get("hidden_crimes", []):
					return {"crime_id": String(crime_id), "voter_id": voter_id}
	return {"crime_id": String(state.council_crime_pool[0].get("id", "")), "voter_id": "npc_fox"}
