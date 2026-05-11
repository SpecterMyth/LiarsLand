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
		assert(state.player.get("hidden_crimes", []).size() == 3)
		if not previous_player_crimes.is_empty():
			assert(_sorted_key(state.player.get("hidden_crimes", [])) != _sorted_key(previous_player_crimes))
		previous_player_crimes = state.player.get("hidden_crimes", []).duplicate()
		var events: Array[String] = []
		var guard := 0
		while not state.ended and guard < 40:
			guard += 1
			var target_id := _best_enemy_target(state)
			var crime_id := CouncilRulesEngineScript.best_progress_crime(state, target_id)
			assert(not crime_id.is_empty())
			assert(not crime_id in state.player.get("hidden_crimes", []))
			CouncilRulesEngineScript.cast_vote(state, "player", crime_id, CouncilRulesEngineScript.VOTE_GUILTY, "test_player", events)
			if not target_id.is_empty() and not state.ended:
				CouncilRulesEngineScript.cast_vote(state, target_id, crime_id, CouncilRulesEngineScript.VOTE_GUILTY, "test_partner", events)
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


func _sorted_key(items: Array) -> String:
	var values: Array[String] = []
	for item in items:
		values.append(String(item))
	values.sort()
	return "|".join(values)


func _best_enemy_target(state) -> String:
	var player_faction := String(state.player.get("hidden_faction", ""))
	for member in CouncilRulesEngineScript.all_members(state):
		if String(member.get("id", "")) == "player":
			continue
		if not bool(member.get("alive", true)):
			continue
		if String(member.get("hidden_faction", "")) != player_faction:
			return String(member.get("id", ""))
	for member in CouncilRulesEngineScript.all_members(state):
		if String(member.get("id", "")) != "player" and bool(member.get("alive", true)):
			return String(member.get("id", ""))
	return ""
