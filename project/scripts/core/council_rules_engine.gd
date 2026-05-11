extends RefCounted
class_name CouncilRulesEngine

const ACTION_RETREAT := "retreat"
const ACTION_TENDENCY := "declare_tendency"
const ACTION_VOTE := "cast_vote"
const ACTION_TRADE := "offer_trade"
const VOTE_GUILTY := "guilty"
const VOTE_INNOCENT := "innocent"
const VOTE_ABSTAIN := "abstain"


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
	state.phase = state.PHASE_SELECT
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
	state.council_executed_crimes.clear()
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


static func normalize_action(action: String) -> String:
	var cleaned := action.strip_edges().to_lower()
	if cleaned in [ACTION_RETREAT, ACTION_TENDENCY, ACTION_VOTE, ACTION_TRADE]:
		return cleaned
	match cleaned:
		"leave", "withdraw", "exit", "暂时撤退", "撤退":
			return ACTION_RETREAT
		"invite", "tendency", "declare", "lean", "倾向表达", "表达倾向", "表态":
			return ACTION_TENDENCY
		"duel", "assassinate", "vote", "direct_vote", "direct-vote", "投票", "直接投票", "正式投票":
			return ACTION_VOTE
		"gift", "cast", "trade", "political_trade", "deal", "政治交易", "交易":
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
			events.append("%s 暂时撤退，结束本次会谈。" % public_name(state, actor_id))
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
		"crime_id": crime_id,
		"vote": vote
	})
	events.append("%s 表达倾向：认为「%s」%s。" % [public_name(state, actor_id), crime_title(state, crime_id), vote_label(vote)])
	return true


static func cast_vote(state, actor_id: String, crime_id: String, vote: String, source: String, events: Array[String]) -> bool:
	if crime_id.is_empty():
		return false
	if _has_locked_vote(state, actor_id, crime_id):
		events.append("%s 已经对「%s」投过正式票，不能更改。" % [public_name(state, actor_id), crime_title(state, crime_id)])
		return false
	vote = _normalize_vote(vote)
	state.council_vote_records.append({
		"round": state.chapter_round,
		"member_id": actor_id,
		"crime_id": crime_id,
		"vote": vote,
		"source": source,
		"locked": true
	})
	_remove_tendency(state, actor_id, crime_id)
	events.append("%s 正式投票：判定「%s」%s。" % [public_name(state, actor_id), crime_title(state, crime_id), vote_label(vote)])
	check_executions(state, events)
	return true


static func apply_trade_offer(state, actor_id: String, payload: Dictionary, events: Array[String]) -> bool:
	var votes: Array = payload.get("bound_votes", [])
	if votes.is_empty():
		var crime_id := _payload_crime_id(state, payload)
		if crime_id.is_empty():
			return false
		votes = [{"member_id": actor_id, "crime_id": crime_id, "vote": _payload_vote(payload)}]
	events.append("%s 提出政治交易，绑定 %d 张票。" % [public_name(state, actor_id), votes.size()])
	var any := false
	for item in votes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var member_id := String(item.get("member_id", actor_id))
		var crime_id := String(item.get("crime_id", ""))
		var vote := String(item.get("vote", VOTE_GUILTY))
		any = cast_vote(state, member_id, crime_id, vote, "trade", events) or any
	return any


static func apply_follow_votes(state, crime_id: String, preferred_vote := VOTE_GUILTY, events: Array[String] = []) -> void:
	if state.ended or crime_id.is_empty():
		return
	for member in all_members(state):
		if state.ended:
			return
		if not bool(member.get("alive", true)):
			continue
		var member_id := String(member.get("id", ""))
		if _has_locked_vote(state, member_id, crime_id):
			continue
		if member_id == "player":
			continue
		cast_vote(state, member_id, crime_id, preferred_vote, "council_momentum", events)
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


static func check_executions(state, events: Array[String]) -> void:
	var threshold := execution_threshold(state)
	var executed_any := true
	while executed_any and not state.ended:
		executed_any = false
		for crime in state.council_crime_pool:
			var crime_id := String(crime.get("id", ""))
			if _crime_already_executed(state, crime_id):
				continue
			if guilty_count(state, crime_id) >= threshold:
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
		_end_by_public_support(state, events, "回合耗尽，议会强制公开阵营并结算。")
		return
	state.refresh_npc_choices()
	state.phase = state.PHASE_SELECT


static func public_board_text(state) -> String:
	var lines: Array[String] = []
	lines.append("议会：第 %d 回合，存活 %d / %d，处决阈值 %d 票" % [state.chapter_round + 1, alive_count(state), total_members(state), execution_threshold(state)])
	lines.append("")
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		lines.append("【%s】有罪 %d/%d，无罪 %d，倾向 %s" % [
			crime_title(state, crime_id),
			guilty_count(state, crime_id),
			execution_threshold(state),
			innocent_count(state, crime_id),
			_tendency_summary(state, crime_id)
		])
	lines.append("")
	lines.append("我的秘密档案：%s / %s" % [faction_name(state, String(state.player.get("hidden_faction", ""))), ", ".join(crime_titles(state, state.player.get("hidden_crimes", [])))])
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
		"members": _public_members(state),
		"self": _private_member_view(state, viewer_id)
	}


static func choose_death_will_votes(state, member: Dictionary) -> Array:
	var votes: Array = []
	var own_crimes: Array = member.get("hidden_crimes", [])
	var player_crimes: Array = state.player.get("hidden_crimes", [])
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		var vote := VOTE_ABSTAIN
		if crime_id in own_crimes:
			vote = VOTE_INNOCENT
		elif not crime_id in player_crimes and guilty_count(state, crime_id) >= execution_threshold(state) - 1:
			vote = VOTE_GUILTY
		votes.append({"member_id": String(member.get("id", "")), "crime_id": crime_id, "vote": vote, "source": "death_will"})
	return votes


static func execution_threshold(state) -> int:
	return int(ceil(float(total_members(state)) / 2.0))


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
			return "有罪"
		VOTE_INNOCENT:
			return "无罪"
	return "弃权"


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
	var used := {}
	for member in all_members(state):
		var combo := _random_crime_combo(crime_ids, count)
		var tries := 0
		while used.has(_combo_key(combo)) and tries < 80:
			combo = _random_crime_combo(crime_ids, count)
			tries += 1
		used[_combo_key(combo)] = true
		member["hidden_crimes"] = combo


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


static func _normalize_vote(vote: String) -> String:
	var cleaned := vote.strip_edges().to_lower()
	if cleaned in ["innocent", "not_guilty", "无罪"]:
		return VOTE_INNOCENT
	if cleaned in ["abstain", "弃权"]:
		return VOTE_ABSTAIN
	return VOTE_GUILTY


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
	for member in all_members(state):
		if bool(member.get("alive", true)) and crime_id in member.get("hidden_crimes", []):
			member["alive"] = false
			victims.append(member)
			events.append("%s 因「%s」被处决。" % [member.get("public_name", ""), crime_title(state, crime_id)])
			if String(member.get("id", "")) == "player":
				_end_player_dead(state, events, "玩家因「%s」被处决。" % crime_title(state, crime_id))
				return
			if bool(state.chapter.get("death_will_enabled", true)):
				var will_votes := choose_death_will_votes(state, member)
				state.council_death_wills.append({"member_id": member.get("id", ""), "votes": will_votes})
				events.append("%s 留下遗嘱投票。" % member.get("public_name", ""))
				if bool(state.chapter.get("death_will_effective", false)):
					for will in will_votes:
						if String(will.get("vote", "")) != VOTE_ABSTAIN:
							state.council_vote_records.append(will)
	if victims.is_empty():
		events.append("「%s」被判有罪，但没有存活议员犯过此罪。" % crime_title(state, crime_id))


static func _check_forced_reveal_or_victory(state, events: Array[String]) -> void:
	if state.ended:
		return
	if not bool(state.player.get("alive", true)):
		_end_player_dead(state, events, "玩家已死亡。")
		return
	if alive_count(state) <= int(state.chapter.get("force_reveal_at_alive", 3)):
		_force_reveal(state, events)
		_end_by_public_support(state, events, "存活议员小于等于 %d 人，强制公开阵营并结算。" % int(state.chapter.get("force_reveal_at_alive", 3)))


static func _force_reveal(state, events: Array[String]) -> void:
	for member in all_members(state):
		if bool(member.get("alive", true)):
			member["faction_revealed"] = true
			member["public_support"] = String(member.get("hidden_faction", ""))
	events.append("剩余议员强制公开阵营。")


static func _end_by_public_support(state, events: Array[String], reason: String) -> void:
	if not bool(state.player.get("alive", true)):
		_end_player_dead(state, events, "玩家已死亡。")
		return
	var counts := {}
	for member in all_members(state):
		if bool(member.get("alive", true)):
			var faction := String(member.get("public_support", member.get("hidden_faction", "")))
			counts[faction] = int(counts.get(faction, 0)) + 1
	var player_faction := String(state.player.get("hidden_faction", ""))
	var winner := ""
	var best := -1
	for faction in counts.keys():
		if int(counts[faction]) > best:
			best = int(counts[faction])
			winner = String(faction)
	var alive := alive_count(state)
	state.victory = winner == player_faction and best > alive / 2.0
	if alive > 1 and alive <= 3 and best == 1:
		state.victory = false
		winner = "none"
	state.ended = true
	state.active = false
	state.phase = state.PHASE_ENDED
	state.end_reason = "%s 胜利阵营：%s。玩家阵营：%s。%s" % [
		reason,
		"无人胜利" if winner == "none" else faction_name(state, winner),
		faction_name(state, player_faction),
		"玩家胜利。" if state.victory else "玩家失败。"
	]
	events.append(state.end_reason)


static func _end_player_dead(state, events: Array[String], reason: String) -> void:
	for member in all_members(state):
		member["faction_revealed"] = true
	state.ended = true
	state.active = false
	state.victory = false
	state.phase = state.PHASE_ENDED
	state.end_reason = "%s 玩家死亡，游戏失败。" % reason
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
	return {
		"id": member.get("id", ""),
		"public_name": member.get("public_name", ""),
		"hidden_faction": member.get("hidden_faction", ""),
		"hidden_crimes": member.get("hidden_crimes", []),
		"alive": member.get("alive", true)
	}


static func _tendency_summary(state, crime_id: String) -> String:
	var parts: Array[String] = []
	for item in state.council_vote_tendencies:
		if String(item.get("crime_id", "")) == crime_id:
			parts.append("%s:%s" % [public_name(state, String(item.get("member_id", ""))), vote_label(String(item.get("vote", "")))])
	return "无" if parts.is_empty() else "，".join(parts)
