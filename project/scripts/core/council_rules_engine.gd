extends RefCounted
class_name CouncilRulesEngine

const ACTION_RETREAT := "retreat"
const ACTION_TENDENCY := "declare_tendency"
const ACTION_VOTE := "cast_vote"
const ACTION_TRADE := "offer_trade"
const VOTE_GUILTY := "guilty"
const VOTE_INNOCENT := "innocent"
const INITIAL_PLAYER_ENERGY := 1000
const ENERGY_REWARD_PER_ALLIED_NPC := 300
const END_REASON_ENERGY_DEPLETED := "energy_depleted"
const ENERGY_DEPLETED_TEXT := "精力耗尽。你的正式发言耗尽了全部政治精力。"


static func setup_state(state, data: Dictionary, options := {}) -> void:
	state.council_mode = true
	state.chapter_template = data.duplicate(true)
	state.chapter = data.duplicate(true)
	state.chapter_index = int(data.get("chapter_index", options.get("chapter_index", 0)))
	state.max_chapters = int(options.get("max_chapters", data.get("max_chapters", 3)))
	state.council_total_chapters = state.max_chapters
	state.max_rounds = int(data.get("max_rounds", 8))
	state.max_dialogue_turns = int(data.get("max_dialogue_turns", 2))
	state.chapter_round = 0
	state.turn = 0
	state.active = false
	state.ended = false
	state.victory = false
	state.end_reason = ""
	state.end_reason_id = ""
	state.phase = state.PHASE_SELECT
	if state.chapter_index == 0 or (int(state.player_chars) == 0 and int(state.max_player_chars) < INITIAL_PLAYER_ENERGY):
		state.player_chars = 0
		state.max_player_chars = INITIAL_PLAYER_ENERGY
	if state.chapter_index == 0:
		state.council_energy_rewarded_chapters.clear()
	state.council_last_energy_rewards.clear()
	state.dialogue_history.clear()
	state.full_dialogue_history.clear()
	state.event_log.clear()
	state.current_npc_index = -1
	state.npc_choices.clear()
	state.council_factions = data.get("factions", []).duplicate(true)
	state.council_crime_pool = data.get("crime_pool", []).duplicate(true)
	state.council_vote_records = []
	state.council_vote_tendencies = []
	state.council_death_wills = []
	state.council_public_support = {}
	state.council_faction_public_crimes = {}
	state.council_executed_crimes.clear()
	state.council_contacted_member_ids.clear()
	state.council_execution_timeline.clear()
	state.council_members = []
	if String(state.council_player_faction).is_empty():
		state.council_player_faction = String(options.get("player_faction", _random_faction_id(data)))
	state.player = _build_member(data.get("player", {}), data, true, state.council_player_faction)
	state.council_members.append(state.player)
	state.npcs = []
	var npc_factions := _balanced_npc_factions(data, String(state.player.get("hidden_faction", "")))
	var npc_index := 0
	for raw_npc in data.get("npcs", []):
		var npc_faction := String(npc_factions[npc_index]) if npc_index < npc_factions.size() else ""
		var npc := _build_member(raw_npc, data, false, npc_faction)
		npc_index += 1
		state.npcs.append(npc)
		state.council_members.append(npc)
	_assign_random_crimes(state, int(data.get("crimes_per_member", 3)))
	state.refresh_npc_choices()


static func remaining_energy(state) -> int:
	return maxi(0, int(state.max_player_chars) - int(state.player_chars))


static func apply_player_speech_energy(state, speech: String, events: Array[String]) -> bool:
	if state.ended:
		return false
	state.player_chars += speech.length()
	if remaining_energy(state) <= 0:
		_end_energy_depleted(state, events)
		return false
	return true


static func award_chapter_energy(state) -> Array:
	if state.ended and not state.victory:
		state.council_last_energy_rewards = []
		return []
	if int(state.chapter_index) in state.council_energy_rewarded_chapters:
		return state.council_last_energy_rewards.duplicate(true)
	if not bool(state.victory):
		state.council_last_energy_rewards = []
		return []
	var rewards: Array = []
	var player_faction := String(state.player.get("hidden_faction", ""))
	for npc in state.npcs:
		if not bool(npc.get("alive", true)):
			continue
		if String(npc.get("hidden_faction", "")) != player_faction:
			continue
		rewards.append({
			"member_id": String(npc.get("id", "")),
			"name": String(npc.get("public_name", npc.get("id", ""))),
			"amount": ENERGY_REWARD_PER_ALLIED_NPC
		})
	if not rewards.is_empty():
		state.max_player_chars += rewards.size() * ENERGY_REWARD_PER_ALLIED_NPC
	state.council_energy_rewarded_chapters.append(int(state.chapter_index))
	state.council_last_energy_rewards = rewards.duplicate(true)
	return rewards


static func normalize_action(action: String) -> String:
	var cleaned := action.strip_edges().to_lower()
	if cleaned in [ACTION_RETREAT, ACTION_TENDENCY, ACTION_VOTE, ACTION_TRADE]:
		return cleaned
	match cleaned:
		"leave", "withdraw", "exit", "retreat":
			return ACTION_RETREAT
		"invite", "tendency", "declare", "lean":
			return ACTION_TENDENCY
		"duel", "assassinate", "vote", "direct_vote", "direct-vote":
			return ACTION_VOTE
		"gift", "cast", "trade", "political_trade", "deal":
			return ACTION_TRADE
	return "none"

static func apply_member_action(state, actor_id: String, raw_action: String, payload: Dictionary, events: Array[String]) -> bool:
	var action := normalize_action(raw_action)
	match action:
		ACTION_TENDENCY:
			return declare_tendency(state, actor_id, _payload_crime_id(state, payload), _payload_vote(payload), events)
		ACTION_VOTE:
			return cast_vote(state, actor_id, _payload_crime_id(state, payload), _payload_vote(payload), String(payload.get("source", "dialogue")), events)
		ACTION_TRADE:
			return apply_trade_offer(state, actor_id, payload, events)
		ACTION_RETREAT:
			if actor_id != "player":
				return false
			events.append("Event resolved.")
			return true
	return false


static func declare_tendency(state, actor_id: String, crime_id: String, vote: String, events: Array[String]) -> bool:
	if crime_id.is_empty():
		return false
	vote = _normalize_vote(vote)
	_remove_tendency(state, actor_id, crime_id)
	state.council_vote_tendencies.append({
		"round": state.chapter_round,
		"member_id": actor_id,
		"counterpart_id": _current_counterpart_id(state, actor_id),
		"crime_id": crime_id,
		"vote": vote
	})
	events.append("Event resolved.")
	return true


static func cast_vote(state, actor_id: String, crime_id: String, vote: String, source: String, events: Array[String]) -> bool:
	if crime_id.is_empty():
		return false
	if not _npc_locked_vote_allowed(state, actor_id, crime_id, vote, source):
		events.append("Event resolved.")
		return false
	if not _record_locked_vote(state, actor_id, crime_id, vote, source):
		events.append("Event resolved.")
		return false
	events.append("Event resolved.")
	check_executions(state, events)
	return true


static func apply_trade_offer(state, actor_id: String, payload: Dictionary, events: Array[String]) -> bool:
	var offer := normalize_trade_offer(state, actor_id, payload)
	var votes: Array = offer.get("bound_votes", [])
	events.append("Event resolved.")
	var any := false
	for item in votes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var member_id := String(item.get("member_id", actor_id))
		var crime_id := String(item.get("crime_id", ""))
		var vote := String(item.get("vote", VOTE_GUILTY))
		any = _record_locked_vote(state, member_id, crime_id, vote, "trade") or any
	if any:
		check_executions(state, events)
	return any


static func normalize_trade_offer(state, actor_id: String, payload: Dictionary) -> Dictionary:
	var counterpart_id := String(payload.get("counterpart_id", ""))
	if counterpart_id.is_empty():
		counterpart_id = _current_counterpart_id(state, actor_id)
	var proposals := _normalize_trade_proposals(state, payload)
	var bound_votes: Array = []
	for proposal in proposals:
		if typeof(proposal) != TYPE_DICTIONARY:
			continue
		var crime_id := String(proposal.get("crime_id", ""))
		if crime_id.is_empty():
			continue
		var vote := _normalize_vote(String(proposal.get("vote", VOTE_GUILTY)))
		if _npc_trade_proposal_is_reckless(state, actor_id, crime_id, vote):
			continue
		bound_votes.append({"member_id": actor_id, "crime_id": crime_id, "vote": vote})
		if not counterpart_id.is_empty() and counterpart_id != actor_id:
			bound_votes.append({"member_id": counterpart_id, "crime_id": crime_id, "vote": vote})
	return {
		"actor_id": actor_id,
		"counterpart_id": counterpart_id,
		"proposals": proposals,
		"bound_votes": bound_votes
	}


static func apply_follow_votes(state, crime_id: String, _preferred_vote := VOTE_GUILTY, events: Array[String] = []) -> void:
	if state.ended or crime_id.is_empty():
		return
	var contacted_member_ids := _contacted_member_ids(state)
	for member in all_members(state):
		if state.ended:
			return
		if not bool(member.get("alive", true)):
			continue
		var member_id := String(member.get("id", ""))
		if not member_id in contacted_member_ids:
			continue
		if _has_locked_vote(state, member_id, crime_id):
			continue
		if member_id == "player":
			continue
		var vote := _latest_tendency_vote(state, member_id, crime_id)
		if vote.is_empty():
			continue
		cast_vote(state, member_id, crime_id, vote, "contact_tendency", events)
		if guilty_count(state, crime_id) >= execution_threshold(state):
			return


static func best_progress_crime(state, prefer_member_id := "") -> String:
	var player_faction := String(state.player.get("hidden_faction", ""))
	var best_crime := ""
	var best_score := -999999
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		if crime_id.is_empty() or _crime_already_executed(state, crime_id):
			continue
		if crime_id in state.player.get("hidden_crimes", []):
			continue
		var score := 0
		for member in all_members(state):
			if not bool(member.get("alive", true)):
				continue
			if not crime_id in member.get("hidden_crimes", []):
				continue
			if String(member.get("id", "")) == prefer_member_id:
				score += 7
			if String(member.get("hidden_faction", "")) == player_faction:
				score -= 24
			else:
				score += 5
		score -= guilty_count(state, crime_id)
		if score > best_score:
			best_score = score
			best_crime = crime_id
	if best_crime.is_empty() and not state.council_crime_pool.is_empty():
		best_crime = String(state.council_crime_pool[0].get("id", ""))
	return best_crime


static func best_npc_probe_crime(state, npc_id: String) -> String:
	var member := get_member(state, npc_id)
	var own_crimes: Array = member.get("hidden_crimes", [])
	var analysis := npc_player_trust_analysis(state, npc_id)
	if String(analysis.get("trust_level", "")) == "likely_friend":
		var faction_safe := String(faction_public_crimes(state, String(member.get("hidden_faction", ""))).get("safe_crime_id", ""))
		if not faction_safe.is_empty() and not _crime_already_executed(state, faction_safe):
			return faction_safe
	var targeted: Array = analysis.get("targeted_self_crime_ids", [])
	if not targeted.is_empty():
		return String(targeted[0])
	var safe_targets: Array = analysis.get("self_safe_guilty_target_ids", [])
	if not safe_targets.is_empty():
		return String(safe_targets[0])
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		if not crime_id.is_empty() and not crime_id in own_crimes and not _crime_already_executed(state, crime_id):
			return crime_id
	for crime in state.council_crime_pool:
		return String(crime.get("id", ""))
	return ""


static func check_executions(state, events: Array[String]) -> void:
	var executed_any := true
	while executed_any and not state.ended:
		executed_any = false
		for crime in state.council_crime_pool:
			var crime_id := String(crime.get("id", ""))
			if _crime_already_executed(state, crime_id):
				continue
			if guilty_count(state, crime_id) >= execution_threshold(state):
				_execute_crime(state, crime_id, events)
				executed_any = true
				break
	_check_forced_reveal_or_victory(state, events)


static func finish_round(state, events: Array[String]) -> void:
	if state.ended:
		return
	state.chapter_round += 1
	state.turn = 0
	if state.chapter_round >= state.max_rounds:
		_force_reveal(state, events)
		_end_by_public_support(state, events, "round limit")
		return
	state.refresh_npc_choices()
	state.phase = state.PHASE_SELECT


static func public_board_text(state) -> String:
	var lines: Array[String] = []
	lines.append("Council round %d, alive %d / %d, threshold %d, energy %d" % [state.chapter_round + 1, alive_count(state), total_members(state), execution_threshold(state), remaining_energy(state)])
	lines.append("")
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		lines.append("%s guilty %d/%d innocent %d tendency %s" % [
			crime_title(state, crime_id),
			guilty_count(state, crime_id),
			execution_threshold(state),
			innocent_count(state, crime_id),
			_tendency_summary(state, crime_id)
		])
	lines.append("")
	var player_faction := String(state.player.get("hidden_faction", ""))
	var faction_info := faction_public_crimes(state, player_faction)
	lines.append("My secret file: %s / energy %d / faction danger %s / faction safe guilty target %s / personal crimes %s" % [
		faction_name(state, player_faction),
		remaining_energy(state),
		crime_title(state, String(faction_info.get("shared_crime_id", ""))),
		crime_title(state, String(faction_info.get("safe_crime_id", ""))),
		", ".join(crime_titles(state, personal_crime_ids(state, state.player)))
	])
	return "\n".join(lines)

static func public_snapshot(state, viewer_id: String) -> Dictionary:
	return {
		"round": state.chapter_round + 1,
		"execution_threshold": execution_threshold(state),
		"alive": alive_count(state),
		"total": total_members(state),
		"factions": state.council_factions,
		"crime_pool": state.council_crime_pool,
		"vote_records": state.council_vote_records,
		"vote_tendencies": state.council_vote_tendencies,
		"remaining_energy": remaining_energy(state),
		"max_energy": int(state.max_player_chars),
		"members": _public_members(state),
		"self": _private_member_view(state, viewer_id)
	}


static func faction_public_crimes(state, faction_id: String) -> Dictionary:
	if state == null or faction_id.is_empty():
		return {}
	if state.council_faction_public_crimes.has(faction_id):
		var info: Dictionary = state.council_faction_public_crimes[faction_id]
		return info
	return {}


static func personal_crime_ids(state, member: Dictionary) -> Array[String]:
	var faction_id := String(member.get("hidden_faction", ""))
	var faction_shared := String(faction_public_crimes(state, faction_id).get("shared_crime_id", ""))
	var result: Array[String] = []
	for crime_id in member.get("hidden_crimes", []):
		var id := String(crime_id)
		if id.is_empty() or id == faction_shared:
			continue
		result.append(id)
	return result


static func npc_player_trust_analysis(state, npc_id: String) -> Dictionary:
	var npc := get_member(state, npc_id)
	var own_crimes: Array = npc.get("hidden_crimes", [])
	var score := 0
	var protected_self_crimes: Array[String] = []
	var targeted_self_crimes: Array[String] = []
	var self_safe_targets: Array[String] = []
	var contradictions: Array[String] = []
	var seen_player_votes := {}
	_collect_player_vote_signals(state.council_vote_tendencies, own_crimes, seen_player_votes, protected_self_crimes, targeted_self_crimes, self_safe_targets, contradictions, true)
	_collect_player_vote_signals(state.council_vote_records, own_crimes, seen_player_votes, protected_self_crimes, targeted_self_crimes, self_safe_targets, contradictions, false)
	var faction_signal := _player_faction_signal_score(state, String(npc.get("hidden_faction", "")))
	score += int(faction_signal.get("score", 0))
	score += protected_self_crimes.size() * 2
	score -= targeted_self_crimes.size() * 4
	score += mini(self_safe_targets.size(), 3)
	score -= contradictions.size() * 3
	var trust_level := "neutral"
	if score >= 3:
		trust_level = "likely_friend"
	elif score <= -3:
		trust_level = "likely_enemy_or_liar"
	return {
		"npc_id": npc_id,
		"score": score,
		"trust_level": trust_level,
		"protected_self_crime_ids": protected_self_crimes,
		"targeted_self_crime_ids": targeted_self_crimes,
		"self_safe_guilty_target_ids": self_safe_targets,
		"contradictory_player_crime_ids": contradictions,
		"faction_signal": faction_signal,
		"guidance": "Question the player first when trust is low. If likely_friend, prefer concrete political trade proposals that move a decision forward. Protect faction_public_guilty_crime_id with innocent votes. Treat faction_public_innocent_crime_id / faction_safe_guilty_target_crime_id as safe for your faction and push guilty votes there to hit other factions. Use tendencies before locked votes. Do not cast guilty votes on your own hidden crimes."
	}


static func choose_death_will_votes(state, member: Dictionary) -> Array:
	var votes: Array = []
	var own_crimes: Array = member.get("hidden_crimes", [])
	var player_crimes: Array = state.player.get("hidden_crimes", [])
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		var vote := VOTE_INNOCENT
		if crime_id in own_crimes:
			vote = VOTE_INNOCENT
		elif not crime_id in player_crimes and guilty_count(state, crime_id) >= execution_threshold(state) - 1:
			vote = VOTE_GUILTY
		votes.append({"member_id": String(member.get("id", "")), "crime_id": crime_id, "vote": vote, "source": "death_will"})
	return votes


static func execution_threshold(state) -> int:
	return int(ceil(float(alive_count(state)) / 2.0))


static func total_members(state) -> int:
	return all_members(state).size()


static func alive_count(state) -> int:
	var count := 0
	for member in all_members(state):
		if bool(member.get("alive", true)):
			count += 1
	return count


static func all_members(state) -> Array:
	var result: Array = []
	result.append(state.player)
	for npc in state.npcs:
		result.append(npc)
	return result


static func get_member(state, member_id: String) -> Dictionary:
	if String(state.player.get("id", "player")) == member_id:
		return state.player
	for npc in state.npcs:
		if String(npc.get("id", "")) == member_id:
			return npc
	return {}


static func public_name(state, member_id: String) -> String:
	return String(get_member(state, member_id).get("public_name", member_id))


static func crime_title(state, crime_id: String) -> String:
	for crime in state.council_crime_pool:
		if String(crime.get("id", "")) == crime_id:
			return String(crime.get("title", crime_id))
	return crime_id


static func crime_titles(state, crime_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for crime_id in crime_ids:
		result.append(crime_title(state, String(crime_id)))
	return result


static func faction_name(state, faction_id: String) -> String:
	for faction in state.council_factions:
		if String(faction.get("id", "")) == faction_id:
			return String(faction.get("name", faction_id))
	return faction_id


static func vote_label(vote: String) -> String:
	match _normalize_vote(vote):
		VOTE_GUILTY:
			return "guilty"
		VOTE_INNOCENT:
			return "innocent"
	return "guilty"

static func guilty_count(state, crime_id: String) -> int:
	return _vote_count(state, crime_id, VOTE_GUILTY)


static func innocent_count(state, crime_id: String) -> int:
	return _vote_count(state, crime_id, VOTE_INNOCENT)


static func _build_member(raw: Dictionary, data: Dictionary, is_player: bool, fixed_faction: String) -> Dictionary:
	var member := raw.duplicate(true)
	if not member.has("id"):
		member["id"] = "player" if is_player else "npc_%d" % randi()
	member["alive"] = true
	member["faction_revealed"] = false
	member["public_support"] = ""
	member["hidden_faction"] = fixed_faction if not fixed_faction.is_empty() else String(member.get("faction", _random_faction_id(data)))
	member["hidden_crimes"] = []
	member["memory"] = []
	return member


static func _balanced_npc_factions(data: Dictionary, player_faction: String) -> Array[String]:
	var faction_ids: Array[String] = []
	for faction in data.get("factions", []):
		var id := String(faction.get("id", ""))
		if not id.is_empty():
			faction_ids.append(id)
	var npcs: Array = data.get("npcs", [])
	if faction_ids.is_empty() or npcs.is_empty():
		return []
	var total := npcs.size() + 1
	var targets := {}
	var base := int(total / faction_ids.size())
	var remainder := total % faction_ids.size()
	for i in faction_ids.size():
		var faction_id := faction_ids[i]
		targets[faction_id] = base + (1 if i < remainder else 0)
	if not player_faction.is_empty():
		targets[player_faction] = max(0, int(targets.get(player_faction, 0)) - 1)
	var result: Array[String] = []
	for raw_npc in npcs:
		var preferred := String(raw_npc.get("faction", ""))
		if int(targets.get(preferred, 0)) > 0:
			result.append(preferred)
			targets[preferred] = int(targets[preferred]) - 1
			continue
		var fallback := _take_remaining_faction(targets, faction_ids)
		result.append(fallback if not fallback.is_empty() else preferred)
	return result


static func _take_remaining_faction(targets: Dictionary, faction_ids: Array[String]) -> String:
	var available: Array[String] = []
	for faction_id in faction_ids:
		for _i in range(int(targets.get(faction_id, 0))):
			available.append(faction_id)
	if available.is_empty():
		return ""
	var picked := String(available[randi_range(0, available.size() - 1)])
	targets[picked] = int(targets[picked]) - 1
	return picked


static func _assign_random_crimes(state, count: int) -> void:
	var crime_ids: Array[String] = []
	for crime in state.council_crime_pool:
		var id := String(crime.get("id", ""))
		if not id.is_empty():
			crime_ids.append(id)
	if _assign_faction_linked_random_crimes(state, crime_ids, count):
		return
	var used := {}
	for member in all_members(state):
		var combo := _random_crime_combo(crime_ids, count)
		var tries := 0
		while used.has(_combo_key(combo)) and tries < 80:
			combo = _random_crime_combo(crime_ids, count)
			tries += 1
		used[_combo_key(combo)] = true
		member["hidden_crimes"] = combo
	state.council_faction_public_crimes = _derive_faction_public_crimes(state, crime_ids)


static func _assign_faction_linked_random_crimes(state, crime_ids: Array[String], count: int) -> bool:
	if crime_ids.size() <= count or count <= 0:
		return false
	var faction_members := _members_by_faction(state)
	for _attempt in range(240):
		var used := {}
		var assigned := {}
		var failed := false
		var constraints := _random_faction_crime_constraints(faction_members.keys(), crime_ids)
		for faction_id in faction_members.keys():
			var members: Array = faction_members[faction_id]
			var constraint: Dictionary = constraints.get(faction_id, {})
			var shared_crime := String(constraint.get("shared", ""))
			var safe_crime := String(constraint.get("safe", ""))
			var excluded: Array[String] = constraint.get("excluded", [])
			for member in members:
				var combo := _random_faction_crime_combo(crime_ids, count, shared_crime, safe_crime, excluded)
				var tries := 0
				while (combo.is_empty() or used.has(_combo_key(combo))) and tries < 120:
					combo = _random_faction_crime_combo(crime_ids, count, shared_crime, safe_crime, excluded)
					tries += 1
				if combo.is_empty() or used.has(_combo_key(combo)):
					failed = true
					break
				used[_combo_key(combo)] = true
				assigned[String(member.get("id", ""))] = combo
			if failed:
				break
		if failed:
			continue
		for member in all_members(state):
			var member_id := String(member.get("id", ""))
			member["hidden_crimes"] = assigned.get(member_id, [])
		state.council_faction_public_crimes = constraints.duplicate(true)
		if _faction_crime_constraints_hold(state, crime_ids) and _player_avoids_enemy_shared_crimes(state, constraints) and _player_has_executable_enemy_crime(state):
			return true
		state.council_faction_public_crimes = {}
	return false


static func _random_faction_crime_constraints(faction_ids: Array, crime_ids: Array[String]) -> Dictionary:
	var shuffled := crime_ids.duplicate()
	shuffled.shuffle()
	var shared_by_faction := {}
	for i in range(faction_ids.size()):
		shared_by_faction[faction_ids[i]] = String(shuffled[i % shuffled.size()])
	shuffled.shuffle()
	var result := {}
	for faction_id in faction_ids:
		var shared := String(shared_by_faction[faction_id])
		var safe := ""
		for crime_id in shuffled:
			if crime_id != shared:
				safe = crime_id
				break
		var excluded: Array[String] = []
		for other_faction_id in faction_ids:
			if other_faction_id != faction_id:
				excluded.append(String(shared_by_faction[other_faction_id]))
		result[faction_id] = {
			"shared": shared,
			"safe": safe,
			"shared_crime_id": shared,
			"safe_crime_id": safe,
			"excluded": excluded
		}
	return result


static func _random_faction_crime_combo(crime_ids: Array[String], count: int, shared_crime: String, safe_crime: String, excluded_crimes: Array[String]) -> Array[String]:
	if shared_crime.is_empty() or shared_crime == safe_crime:
		return []
	var candidates: Array[String] = []
	for crime_id in crime_ids:
		if crime_id != shared_crime and crime_id != safe_crime and not crime_id in excluded_crimes:
			candidates.append(crime_id)
	if _combination_capacity(candidates.size(), count - 1) < 2:
		candidates.clear()
		for crime_id in crime_ids:
			if crime_id != shared_crime and crime_id != safe_crime:
				candidates.append(crime_id)
	if candidates.size() < count - 1:
		return []
	candidates.shuffle()
	var result: Array[String] = [shared_crime]
	for i in range(count - 1):
		result.append(candidates[i])
	result.sort()
	return result


static func _combination_capacity(pool_size: int, pick_count: int) -> int:
	if pick_count < 0 or pool_size < pick_count:
		return 0
	if pick_count == 0:
		return 1
	var result := 1
	for i in range(pick_count):
		result = int(result * (pool_size - i) / (i + 1))
	return result


static func _members_by_faction(state) -> Dictionary:
	var result := {}
	for member in all_members(state):
		var faction_id := String(member.get("hidden_faction", ""))
		if not result.has(faction_id):
			result[faction_id] = []
		result[faction_id].append(member)
	return result


static func _derive_faction_public_crimes(state, crime_ids: Array[String]) -> Dictionary:
	var result := {}
	var by_faction := _members_by_faction(state)
	for faction_id in by_faction.keys():
		var members: Array = by_faction[faction_id]
		var shared := ""
		var safe := ""
		for crime_id in crime_ids:
			var all_have := true
			var none_have := true
			for member in members:
				var crimes: Array = member.get("hidden_crimes", [])
				all_have = all_have and crime_id in crimes
				none_have = none_have and not crime_id in crimes
			if shared.is_empty() and all_have:
				shared = crime_id
			if safe.is_empty() and none_have:
				safe = crime_id
		result[faction_id] = {
			"shared": shared,
			"safe": safe,
			"shared_crime_id": shared,
			"safe_crime_id": safe,
			"excluded": []
		}
	return result


static func _faction_crime_constraints_hold(state, crime_ids: Array[String]) -> bool:
	var used := {}
	for member in all_members(state):
		var crimes: Array = member.get("hidden_crimes", [])
		if crimes.is_empty():
			return false
		var key := _combo_key(crimes)
		if used.has(key):
			return false
		used[key] = true
	for faction_id in _members_by_faction(state).keys():
		var members: Array = _members_by_faction(state)[faction_id]
		var has_shared := false
		var has_safe := false
		for crime_id in crime_ids:
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


static func _player_avoids_enemy_shared_crimes(state, constraints: Dictionary) -> bool:
	var player_faction := String(state.player.get("hidden_faction", ""))
	var player_crimes: Array = state.player.get("hidden_crimes", [])
	for faction_id in constraints.keys():
		if String(faction_id) == player_faction:
			continue
		var shared := String(Dictionary(constraints[faction_id]).get("shared", ""))
		if not shared.is_empty() and shared in player_crimes:
			return false
	return true


static func _player_has_executable_enemy_crime(state) -> bool:
	var player_faction := String(state.player.get("hidden_faction", ""))
	var threshold := execution_threshold(state)
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		if crime_id.is_empty() or crime_id in state.player.get("hidden_crimes", []):
			continue
		var enemy_victims := 0
		var safe_npc_voters := 0
		for member in all_members(state):
			if not bool(member.get("alive", true)):
				continue
			var member_id := String(member.get("id", ""))
			var has_crime: bool = crime_id in member.get("hidden_crimes", [])
			if member_id != "player" and has_crime and String(member.get("hidden_faction", "")) != player_faction:
				enemy_victims += 1
			if member_id != "player" and not has_crime:
				safe_npc_voters += 1
		if enemy_victims > 0 and safe_npc_voters >= threshold - 1:
			return true
	return false


static func _random_crime_combo(crime_ids: Array[String], count: int) -> Array[String]:
	var ids := crime_ids.duplicate()
	ids.shuffle()
	var result: Array[String] = []
	for i in range(min(count, ids.size())):
		result.append(ids[i])
	result.sort()
	return result


static func _combo_key(combo: Array) -> String:
	var ids: Array[String] = []
	for item in combo:
		ids.append(String(item))
	ids.sort()
	return "|".join(ids)


static func _random_faction_id(data: Dictionary) -> String:
	var factions: Array = data.get("factions", [])
	if factions.is_empty():
		return ""
	return String(factions[randi_range(0, factions.size() - 1)].get("id", ""))


static func _payload_crime_id(state, payload: Dictionary) -> String:
	var crime_id := String(payload.get("crime_id", payload.get("target_crime_id", "")))
	if not crime_id.is_empty():
		return crime_id
	for crime in state.council_crime_pool:
		return String(crime.get("id", ""))
	return ""


static func _payload_vote(payload: Dictionary) -> String:
	return _normalize_vote(String(payload.get("vote", payload.get("tendency", VOTE_GUILTY))))


static func _normalize_trade_proposals(state, payload: Dictionary) -> Array:
	var raw_proposals: Array = payload.get("proposals", [])
	if raw_proposals.is_empty():
		raw_proposals = payload.get("bound_votes", [])
	if raw_proposals.is_empty():
		var crime_id := _payload_crime_id(state, payload)
		if not crime_id.is_empty():
			raw_proposals = [{"crime_id": crime_id, "vote": _payload_vote(payload)}]
	var proposals: Array = []
	var seen := {}
	for item in raw_proposals:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var crime_id := String(item.get("crime_id", item.get("target_crime_id", "")))
		if crime_id.is_empty() or seen.has(crime_id):
			continue
		seen[crime_id] = true
		proposals.append({
			"crime_id": crime_id,
			"vote": _normalize_vote(String(item.get("vote", VOTE_GUILTY)))
		})
		if proposals.size() >= 3:
			break
	return proposals


static func _normalize_vote(vote: String) -> String:
	var cleaned := vote.strip_edges().to_lower()
	if cleaned in ["innocent", "not_guilty"]:
		return VOTE_INNOCENT
	return VOTE_GUILTY

static func _record_locked_vote(state, actor_id: String, crime_id: String, vote: String, source: String) -> bool:
	if crime_id.is_empty() or _has_locked_vote(state, actor_id, crime_id):
		return false
	vote = _normalize_vote(vote)
	state.council_vote_records.append({
		"round": state.chapter_round,
		"member_id": actor_id,
		"counterpart_id": _current_counterpart_id(state, actor_id),
		"crime_id": crime_id,
		"vote": vote,
		"source": source,
		"locked": true
	})
	_remove_tendency(state, actor_id, crime_id)
	return true


static func _npc_locked_vote_allowed(state, actor_id: String, crime_id: String, vote: String, source: String) -> bool:
	if actor_id == "player":
		return true
	var member := get_member(state, actor_id)
	if member.is_empty():
		return true
	var normalized := _normalize_vote(vote)
	if normalized == VOTE_GUILTY and crime_id in member.get("hidden_crimes", []):
		return false
	if normalized == VOTE_GUILTY and source == "dialogue":
		var analysis := npc_player_trust_analysis(state, actor_id)
		if int(analysis.get("score", 0)) < 1 and guilty_count(state, crime_id) < execution_threshold(state) - 1:
			return false
	return true


static func _npc_trade_proposal_is_reckless(state, actor_id: String, crime_id: String, vote: String) -> bool:
	if actor_id == "player":
		return false
	var member := get_member(state, actor_id)
	if member.is_empty():
		return false
	var normalized := _normalize_vote(vote)
	if normalized == VOTE_GUILTY and crime_id in member.get("hidden_crimes", []):
		return true
	var analysis := npc_player_trust_analysis(state, actor_id)
	if normalized == VOTE_GUILTY and int(analysis.get("score", 0)) < 1 and crime_id in analysis.get("contradictory_player_crime_ids", []):
		return true
	return false


static func _collect_player_vote_signals(records: Array, own_crimes: Array, seen_player_votes: Dictionary, protected_self_crimes: Array[String], targeted_self_crimes: Array[String], self_safe_targets: Array[String], contradictions: Array[String], tendency: bool) -> void:
	for item in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if String(item.get("member_id", "")) != "player":
			continue
		var crime_id := String(item.get("crime_id", ""))
		var vote := _normalize_vote(String(item.get("vote", "")))
		if crime_id.is_empty():
			continue
		var previous := String(seen_player_votes.get(crime_id, ""))
		if not previous.is_empty() and previous != vote and not crime_id in contradictions:
			contradictions.append(crime_id)
		seen_player_votes[crime_id] = vote
		if crime_id in own_crimes:
			if vote == VOTE_GUILTY and not crime_id in targeted_self_crimes:
				targeted_self_crimes.append(crime_id)
			elif vote != VOTE_GUILTY and not crime_id in protected_self_crimes:
				protected_self_crimes.append(crime_id)
		elif vote == VOTE_GUILTY and not tendency and not crime_id in self_safe_targets:
			self_safe_targets.append(crime_id)


static func _player_faction_signal_score(state, faction_id: String) -> Dictionary:
	var info := faction_public_crimes(state, faction_id)
	var shared := String(info.get("shared_crime_id", ""))
	var safe := String(info.get("safe_crime_id", ""))
	var score := 0
	var signals: Array[String] = []
	for records in [state.council_vote_tendencies, state.council_vote_records]:
		for item in records:
			if typeof(item) != TYPE_DICTIONARY or String(item.get("member_id", "")) != "player":
				continue
			var crime_id := String(item.get("crime_id", ""))
			var vote := _normalize_vote(String(item.get("vote", "")))
			if not shared.is_empty() and crime_id == shared:
				if vote == VOTE_INNOCENT:
					score += 4
					signals.append("protected_faction_crime")
				else:
					score -= 5
					signals.append("targeted_faction_crime")
			elif not safe.is_empty() and crime_id == safe:
				if vote == VOTE_GUILTY:
					score += 3
					signals.append("pushed_faction_safe_target")
				else:
					score -= 1
					signals.append("softened_faction_safe_target")
	return {
		"score": score,
		"shared_crime_id": shared,
		"safe_crime_id": safe,
		"signals": signals
	}


static func _has_locked_vote(state, actor_id: String, crime_id: String) -> bool:
	for record in state.council_vote_records:
		if String(record.get("member_id", "")) == actor_id and String(record.get("crime_id", "")) == crime_id:
			return true
	return false


static func _remove_tendency(state, actor_id: String, crime_id: String) -> void:
	for i in range(state.council_vote_tendencies.size() - 1, -1, -1):
		var record: Dictionary = state.council_vote_tendencies[i]
		if String(record.get("member_id", "")) == actor_id and String(record.get("crime_id", "")) == crime_id:
			state.council_vote_tendencies.remove_at(i)


static func _contacted_member_ids(state) -> Array[String]:
	var result: Array[String] = []
	for item in state.council_contacted_member_ids:
		var member_id := String(item)
		if not member_id.is_empty() and not member_id in result:
			result.append(member_id)
	if state.current_npc_index >= 0 and state.current_npc_index < state.npcs.size():
		var current_id := String(state.npcs[state.current_npc_index].get("id", ""))
		if not current_id.is_empty() and not current_id in result:
			result.append(current_id)
	return result


static func _current_counterpart_id(state, actor_id: String) -> String:
	if actor_id == "player":
		if state.current_npc_index >= 0 and state.current_npc_index < state.npcs.size():
			return String(state.npcs[state.current_npc_index].get("id", ""))
		return ""
	return "player"


static func _latest_tendency_vote(state, member_id: String, crime_id: String) -> String:
	for i in range(state.council_vote_tendencies.size() - 1, -1, -1):
		var record: Dictionary = state.council_vote_tendencies[i]
		if String(record.get("member_id", "")) == member_id and String(record.get("crime_id", "")) == crime_id:
			return _normalize_vote(String(record.get("vote", "")))
	return ""


static func _vote_count(state, crime_id: String, vote: String) -> int:
	var count := 0
	for record in state.council_vote_records:
		if String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			count += 1
	return count


static func _crime_already_executed(state, crime_id: String) -> bool:
	for item in state.council_executed_crimes:
		if String(item) == crime_id:
			return true
	return false


static func _execute_crime(state, crime_id: String, events: Array[String]) -> void:
	state.council_executed_crimes.append(crime_id)
	var victims: Array = []
	var death_will_records: Array = []
	for member in all_members(state):
		if bool(member.get("alive", true)) and crime_id in member.get("hidden_crimes", []):
			member["alive"] = false
			victims.append(member)
			events.append("Event resolved.")
			if String(member.get("id", "")) == "player":
				_record_execution_timeline_step(state, crime_id, victims, death_will_records)
				_end_player_dead(state, events, "player executed")
				return
			if bool(state.chapter.get("death_will_enabled", true)):
				var will_votes := choose_death_will_votes(state, member)
				var death_will := {"member_id": member.get("id", ""), "votes": will_votes}
				state.council_death_wills.append(death_will)
				death_will_records.append(death_will)
				events.append("Event resolved.")
				if bool(state.chapter.get("death_will_effective", false)):
					for will in will_votes:
						state.council_vote_records.append(will)
	_record_execution_timeline_step(state, crime_id, victims, death_will_records)
	if victims.is_empty():
		events.append("Event resolved.")


static func _record_execution_timeline_step(state, crime_id: String, victims: Array, death_will_records: Array) -> void:
	if victims.is_empty():
		return
	var step := {
		"round": state.chapter_round,
		"crime_id": crime_id,
		"crime_title": crime_title(state, crime_id),
		"guilty_count": guilty_count(state, crime_id),
		"innocent_count": innocent_count(state, crime_id),
		"threshold": execution_threshold(state),
		"votes": _votes_for_crime_snapshot(state, crime_id),
		"victims": [],
		"death_wills": death_will_records.duplicate(true)
	}
	var step_victims: Array = step["victims"]
	var victim_ids: Array[String] = []
	for member in victims:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var member_id := String(member.get("id", ""))
		if member_id.is_empty() or member_id in victim_ids:
			continue
		victim_ids.append(member_id)
		step_victims.append({
			"member_id": member_id,
			"name": String(member.get("public_name", member_id)),
			"portrait": String(member.get("portrait", "")),
			"portrait_half": String(member.get("portrait_half", "")),
			"hidden_crimes": member.get("hidden_crimes", []).duplicate()
		})
	step["victims"] = step_victims
	state.council_execution_timeline.append(step)


static func _votes_for_crime_snapshot(state, crime_id: String) -> Array:
	var votes: Array = []
	for record in state.council_vote_records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		if String(record.get("crime_id", "")) != crime_id:
			continue
		votes.append(record.duplicate(true))
	return votes


static func _check_forced_reveal_or_victory(state, events: Array[String]) -> void:
	if state.ended:
		return
	if not bool(state.player.get("alive", true)):
		_end_player_dead(state, events, "player executed")
		return
	if alive_count(state) <= int(state.chapter.get("force_reveal_at_alive", 3)):
		_force_reveal(state, events)
		_end_by_public_support(state, events, "round limit")


static func _force_reveal(state, events: Array[String]) -> void:
	for member in all_members(state):
		if bool(member.get("alive", true)):
			member["faction_revealed"] = true
			member["public_support"] = String(member.get("hidden_faction", ""))
	events.append("Event resolved.")


static func _end_player_dead(state, events: Array[String], reason: String) -> void:
	state.victory = false
	state.ended = true
	state.active = false
	state.phase = state.PHASE_ENDED
	state.end_reason_id = "player_dead"
	state.end_reason = reason
	events.append(reason)


static func _end_energy_depleted(state, events: Array[String]) -> void:
	state.victory = false
	state.ended = true
	state.active = false
	state.phase = state.PHASE_ENDED
	state.end_reason_id = END_REASON_ENERGY_DEPLETED
	state.end_reason = ENERGY_DEPLETED_TEXT
	events.append(state.end_reason)


static func _end_by_public_support(state, events: Array[String], reason: String) -> void:
	var player_faction := String(state.player.get("hidden_faction", ""))
	var counts := {}
	for member in all_members(state):
		if not bool(member.get("alive", true)):
			continue
		var faction := String(member.get("hidden_faction", ""))
		counts[faction] = int(counts.get(faction, 0)) + 1
	var winner := "none"
	var best := -1
	var tied := false
	for faction in counts.keys():
		var count := int(counts[faction])
		if count > best:
			best = count
			winner = String(faction)
			tied = false
		elif count == best:
			tied = true
	if tied:
		winner = "none"
	state.victory = winner == player_faction and not player_faction.is_empty()
	state.ended = true
	state.active = false
	state.phase = state.PHASE_ENDED
	state.end_reason_id = "council_result"
	state.end_reason = "%s Winner: %s. Player faction: %s." % [reason, winner, player_faction]
	events.append(state.end_reason)

static func _public_members(state) -> Array:
	var result := []
	for member in all_members(state):
		result.append({
			"id": member.get("id", ""),
			"public_name": member.get("public_name", ""),
			"public_identity": member.get("public_identity", ""),
			"alive": member.get("alive", true),
			"faction_revealed": member.get("faction_revealed", false),
			"public_support": member.get("public_support", "")
		})
	return result


static func _private_member_view(state, viewer_id: String) -> Dictionary:
	var member := get_member(state, viewer_id)
	var faction_info := faction_public_crimes(state, String(member.get("hidden_faction", "")))
	return {
		"id": member.get("id", ""),
		"public_name": member.get("public_name", ""),
		"hidden_faction": member.get("hidden_faction", ""),
		"hidden_crimes": member.get("hidden_crimes", []),
		"faction_public_guilty_crime_id": faction_info.get("shared_crime_id", ""),
		"faction_public_innocent_crime_id": faction_info.get("safe_crime_id", ""),
		"faction_safe_guilty_target_crime_id": faction_info.get("safe_crime_id", ""),
		"faction_crime_rules": {
			"faction_public_guilty_crime_id": "All members of this faction have this crime. Protect it with innocent votes.",
			"faction_public_innocent_crime_id": "No member of this faction has this crime. It is safe to vote guilty on it to execute other factions.",
			"faction_safe_guilty_target_crime_id": "Same as faction_public_innocent_crime_id."
		},
		"alive": member.get("alive", true)
	}


static func _tendency_summary(state, crime_id: String) -> String:
	var parts: Array[String] = []
	for item in state.council_vote_tendencies:
		if String(item.get("crime_id", "")) == crime_id:
			parts.append("%s:%s" % [public_name(state, String(item.get("member_id", ""))), vote_label(String(item.get("vote", "")))])
	return "none" if parts.is_empty() else ", ".join(parts)
