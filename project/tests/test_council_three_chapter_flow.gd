extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")

const CHAPTERS := [
	"res://data/council_chapter_01.json",
	"res://data/council_chapter_02.json",
	"res://data/council_chapter_03.json"
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260511)
	var state = GameStateScript.new()
	var player_faction := ""
	var previous_player_crimes: Array = []
	for chapter_index in CHAPTERS.size():
		var data := ChapterLoaderScript.load_chapter(String(CHAPTERS[chapter_index]))
		CouncilRulesEngineScript.setup_state(state, data, {
			"chapter_index": chapter_index,
			"max_chapters": CHAPTERS.size()
		})
		state.active = true
		var current_faction := String(state.player.get("hidden_faction", ""))
		if chapter_index == 0:
			player_faction = current_faction
		assert(current_faction == player_faction)
		assert(_faction_counts_are_balanced(state))
		assert(_all_member_crime_sets_are_distinct(state))
		assert(_faction_crime_links_hold(state))
		assert(state.player.get("hidden_crimes", []).size() == 3)
		if not previous_player_crimes.is_empty():
			assert(_sorted_key(state.player.get("hidden_crimes", [])) != _sorted_key(previous_player_crimes))
		previous_player_crimes = state.player.get("hidden_crimes", []).duplicate()
		var events: Array[String] = []
		var guard := 0
		while not state.ended and guard < 40:
			guard += 1
			var crime_id := _best_executable_enemy_crime(state)
			assert(not crime_id.is_empty())
			assert(not crime_id in state.player.get("hidden_crimes", []))
			_seed_contacted_tendencies(state, crime_id, CouncilRulesEngineScript.execution_threshold(state) - 1, events)
			CouncilRulesEngineScript.cast_vote(state, "player", crime_id, CouncilRulesEngineScript.VOTE_GUILTY, "test_player", events)
			if not state.ended:
				CouncilRulesEngineScript.apply_follow_votes(state, crime_id, CouncilRulesEngineScript.VOTE_GUILTY, events)
			if not state.ended:
				CouncilRulesEngineScript.finish_round(state, events)
		assert(state.ended)
		if not state.victory:
			print("Chapter %d failed: %s" % [chapter_index + 1, state.end_reason])
			for member in CouncilRulesEngineScript.all_members(state):
				print("%s faction=%s alive=%s crimes=%s" % [
					String(member.get("id", "")),
					String(member.get("hidden_faction", "")),
					str(member.get("alive", true)),
					str(member.get("hidden_crimes", []))
				])
		assert(state.victory)
		assert(bool(state.player.get("alive", true)))
	print("Council three-chapter flow test passed.")
	quit(0)


func _all_member_crime_sets_are_distinct(state) -> bool:
	var seen := {}
	for member in CouncilRulesEngineScript.all_members(state):
		var key := _sorted_key(member.get("hidden_crimes", []))
		if seen.has(key):
			return false
		seen[key] = true
	return true


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


func _sorted_key(items: Array) -> String:
	var values: Array[String] = []
	for item in items:
		values.append(String(item))
	values.sort()
	return "|".join(values)


func _seed_contacted_tendencies(state, crime_id: String, count: int, events: Array[String]) -> void:
	var seeded := 0
	for member in CouncilRulesEngineScript.all_members(state):
		if seeded >= count:
			return
		var member_id := String(member.get("id", ""))
		if member_id == "player" or not bool(member.get("alive", true)):
			continue
		if crime_id in member.get("hidden_crimes", []):
			continue
		if not member_id in state.council_contacted_member_ids:
			state.council_contacted_member_ids.append(member_id)
		CouncilRulesEngineScript.declare_tendency(state, member_id, crime_id, CouncilRulesEngineScript.VOTE_GUILTY, events)
		seeded += 1


func _best_executable_enemy_crime(state) -> String:
	var player_faction := String(state.player.get("hidden_faction", ""))
	var best_crime := ""
	var best_score := -999
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		if crime_id.is_empty() or crime_id in state.player.get("hidden_crimes", []):
			continue
		var safe_npc_voters := 0
		var enemy_victims := 0
		var friend_victims := 0
		for member in CouncilRulesEngineScript.all_members(state):
			if not bool(member.get("alive", true)):
				continue
			var member_id := String(member.get("id", ""))
			var has_crime: bool = crime_id in member.get("hidden_crimes", [])
			if member_id != "player" and not has_crime:
				safe_npc_voters += 1
			if member_id != "player" and has_crime:
				if String(member.get("hidden_faction", "")) == player_faction:
					friend_victims += 1
				else:
					enemy_victims += 1
		if safe_npc_voters < CouncilRulesEngineScript.execution_threshold(state) - 1:
			continue
		if enemy_victims <= 0:
			continue
		var score := enemy_victims * 10 - friend_victims * 30
		if score > best_score:
			best_score = score
			best_crime = crime_id
	if not best_crime.is_empty():
		return best_crime
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		if not crime_id in state.player.get("hidden_crimes", []):
			return crime_id
	return ""
