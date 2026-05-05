extends RefCounted
class_name RulesEngine

const ACTION_INVITE := "invite"
const ACTION_ASSASSINATE := "assassinate"
const ACTION_DUEL := "duel"
const ACTION_LEAVE := "leave"
const ACTION_GIFT := "gift"
const ACTION_CAST := "cast"
const VALID_ACTIONS := [ACTION_INVITE, ACTION_ASSASSINATE, ACTION_DUEL, ACTION_LEAVE, ACTION_GIFT, ACTION_CAST]


static func normalize_action(action: String) -> String:
	var cleaned := action.strip_edges().to_lower()
	if cleaned in VALID_ACTIONS:
		return cleaned
	return ACTION_LEAVE


static func apply_dialogue_turn(state, player_speech: String, npc_speech: String, npc_response := {}) -> Array[String]:
	var events: Array[String] = []
	var npc: Dictionary = state.current_npc()
	if npc.is_empty() or state.ended:
		return events
	state.player_chars += player_speech.length()
	npc["energy"] = int(npc.get("energy", 0)) + player_speech.length()
	state.player["energy"] = int(state.player.get("energy", 0)) + npc_speech.length()
	npc["affinity"] = clampi(int(npc.get("affinity", 0)) + _affinity_delta(npc, player_speech), 0, 10)
	npc["friend_judgement"] = _judge_player(npc)
	_detect_identity_exposure(state, npc, player_speech, events)
	_reveal_available_intel(state, npc, events)
	state.set_current_npc(npc)
	if typeof(npc_response) == TYPE_DICTIONARY:
		_apply_npc_offer(state, npc_response, events)
	if state.player_chars >= state.max_player_chars:
		_force_submit_world_intel(state, events, "输出字符耗尽，强制提交世界设定档案。")
	return events


static func resolve_player_action(state, raw_action: String, payload := {}) -> Array[String]:
	var action := normalize_action(raw_action)
	var events: Array[String] = []
	var npc: Dictionary = state.current_npc()
	if npc.is_empty() or state.ended:
		return events
	match action:
		ACTION_INVITE:
			_resolve_invite(state, npc, events)
		ACTION_ASSASSINATE:
			_resolve_assassinate(state, npc, events)
		ACTION_DUEL:
			_resolve_duel(state, npc, events)
		ACTION_GIFT:
			_resolve_player_gift(state, npc, payload, events)
		ACTION_CAST:
			_resolve_cast(state, npc, payload, events)
		_:
			events.append("玩家角色选择撤离，结束本回合对话。")
	if not state.ended:
		state.set_current_npc(npc)
	return events


static func resolve_post_action(state, raw_action: String, advance_after := true) -> Array[String]:
	var events := resolve_player_action(state, raw_action)
	if not state.ended and advance_after:
		events.append_array(finish_round(state))
	return events


static func buy_player_artifact(state, artifact_id: String) -> Array[String]:
	var events: Array[String] = []
	var artifact: Dictionary = state.get_artifact(artifact_id)
	if artifact.is_empty() or not artifact_id in state.shop_items:
		events.append("购买失败：本回合商店没有该法器。")
		return events
	var price := int(artifact.get("price", 0))
	if int(state.player.get("energy", 0)) < price:
		events.append("购买失败：能量不足。")
		return events
	state.player["energy"] = int(state.player.get("energy", 0)) - price
	state.add_artifact(state.player, artifact_id)
	events.append("购买法器：%s。" % state.artifact_name(artifact_id))
	state.remember_player("第 %d 回合，在商店购买了法器「%s」。" % [state.chapter_round + 1, state.artifact_name(artifact_id)])
	return events


static func ascend_player(state, stat_gains: Dictionary) -> Array[String]:
	var events: Array[String] = []
	if not state.ascension_met(state.player):
		events.append("升华失败：法器不足。")
		return events
	if int(state.player.get("level", 1)) >= 10:
		events.append("升华失败：已达最高等级。")
		return events
	for artifact_id in state.player.get("ascension_requirement", []):
		state.remove_artifact(state.player, String(artifact_id))
	state.player["level"] = int(state.player.get("level", 1)) + 1
	var stats: Dictionary = state.player.get("stats", {})
	var spent := 0
	for stat in stat_gains.keys():
		var value := int(stat_gains.get(stat, 0))
		if value <= 0:
			continue
		stats[stat] = int(stats.get(stat, 0)) + value
		spent += value
	state.player["stats"] = stats
	state.regenerate_ascension_requirement(state.player)
	events.append("升华成功：等级提升到 %d，分配 %d 个属性点。" % [int(state.player.get("level", 1)), spent])
	state.remember_player("第 %d 回合，完成升华，等级提升到 %d。" % [state.chapter_round + 1, int(state.player.get("level", 1))])
	return events


static func finish_round(state) -> Array[String]:
	var events: Array[String] = []
	if state.ended:
		return events
	if state.dominion_met(state.player) and not state.chapter_dominion_completed:
		_resolve_player_dominion(state, events)
		return events
	_auto_npc_shop(state, events)
	_auto_npc_ascension(state, events)
	_check_npc_dominion(state, events)
	if state.ended:
		return events
	state.chapter_round += 1
	if state.chapter_round >= state.max_rounds:
		_end(state, false, "10 回合结束，玩家尚未达成统治。")
		return events
	state.refresh_npc_choices()
	state.refresh_shop_items()
	state.phase = state.PHASE_SELECT
	return events


static func check_chapter_resolution(state) -> void:
	if state.dominion_met(state.player) and not state.chapter_dominion_completed:
		var events: Array[String] = []
		_resolve_player_dominion(state, events)


static func submit_world_intel(state, answers: Dictionary) -> Array[String]:
	var events: Array[String] = []
	if state.ended:
		return events
	if state.intel_submitted:
		events.append("世界设定档案已经提交过，不能再次提交。")
		return events
	state.intel_submitted = true
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		var submitted := String(answers.get(question_id, ""))
		state.select_world_intel_answer(question_id, submitted)
		if submitted.is_empty() or submitted != String(state.world_intel_answers.get(question_id, "")):
			_end(state, false, "世界设定档案提交错误：%s。" % String(question.get("title", question_id)))
			events.append(state.end_reason)
			return events
	_end(state, true, "世界设定档案全部正确，本局胜利。")
	events.append(state.end_reason)
	return events


static func _apply_npc_offer(state, npc_response: Dictionary, events: Array[String]) -> void:
	if npc_response.has("gift_offer") and typeof(npc_response.get("gift_offer")) == TYPE_DICTIONARY:
		_resolve_npc_gift(state, state.current_npc(), npc_response.get("gift_offer", {}), events)
	if npc_response.has("exchange_offer") and typeof(npc_response.get("exchange_offer")) == TYPE_DICTIONARY:
		_resolve_npc_exchange(state, state.current_npc(), npc_response.get("exchange_offer", {}), events)


static func _resolve_npc_gift(state, npc: Dictionary, offer: Dictionary, events: Array[String]) -> void:
	var artifact_id := String(offer.get("artifact_id", ""))
	if artifact_id.is_empty():
		return
	if int(npc.get("affinity", 0)) < int(offer.get("affinity_required", 6)):
		events.append("%s 提到了赠礼，但好感度不足，谈判未成。" % npc.get("public_name", "NPC"))
		return
	if not state.transfer_artifact(npc, state.player, artifact_id):
		events.append("%s 提议赠送 %s，但并未持有它。" % [npc.get("public_name", "NPC"), state.artifact_name(artifact_id)])
		return
	state.set_current_npc(npc)
	events.append("%s 赠送了法器：%s。" % [npc.get("public_name", "NPC"), state.artifact_name(artifact_id)])
	state.remember_player("第 %d 回合，%s 赠送了法器「%s」。" % [state.chapter_round + 1, npc.get("public_name", "NPC"), state.artifact_name(artifact_id)])
	state.remember_current_npc("第 %d 回合，向玩家赠送了法器「%s」。" % [state.chapter_round + 1, state.artifact_name(artifact_id)])


static func _resolve_npc_exchange(state, npc: Dictionary, offer: Dictionary, events: Array[String]) -> void:
	var npc_artifact := String(offer.get("npc_artifact_id", ""))
	var player_artifact := String(offer.get("player_artifact_id", ""))
	if npc_artifact.is_empty() or player_artifact.is_empty():
		return
	if int(npc.get("affinity", 0)) < int(offer.get("affinity_required", 4)):
		events.append("%s 提出了交换，但好感度不足，谈判未成。" % npc.get("public_name", "NPC"))
		return
	if not state.has_artifact(npc, npc_artifact) or not state.has_artifact(state.player, player_artifact):
		events.append("交换失败：双方并未持有所需法器。")
		return
	state.transfer_artifact(npc, state.player, npc_artifact)
	state.transfer_artifact(state.player, npc, player_artifact)
	state.set_current_npc(npc)
	events.append("交换完成：获得 %s，交出 %s。" % [state.artifact_name(npc_artifact), state.artifact_name(player_artifact)])
	state.remember_player("第 %d 回合，与 %s 交换：获得「%s」，交出「%s」。" % [state.chapter_round + 1, npc.get("public_name", "NPC"), state.artifact_name(npc_artifact), state.artifact_name(player_artifact)])
	state.remember_current_npc("第 %d 回合，与玩家交换：交出「%s」，获得「%s」。" % [state.chapter_round + 1, state.artifact_name(npc_artifact), state.artifact_name(player_artifact)])


static func _resolve_player_gift(state, npc: Dictionary, payload, events: Array[String]) -> void:
	var artifact_id := _payload_artifact_id(payload)
	if artifact_id.is_empty() or not state.transfer_artifact(state.player, npc, artifact_id):
		events.append("赠送失败：玩家没有指定法器。")
		return
	npc["affinity"] = clampi(int(npc.get("affinity", 0)) + 2, 0, 10)
	events.append("赠送成功：把 %s 交给了 %s。" % [state.artifact_name(artifact_id), npc.get("public_name", "NPC")])
	state.remember_player("第 %d 回合，向 %s 赠送了法器「%s」。" % [state.chapter_round + 1, npc.get("public_name", "NPC"), state.artifact_name(artifact_id)])
	state.remember_current_npc("第 %d 回合，收到玩家赠送的法器「%s」。" % [state.chapter_round + 1, state.artifact_name(artifact_id)])


static func _resolve_cast(state, npc: Dictionary, payload, events: Array[String]) -> void:
	var artifact_id := _payload_artifact_id(payload)
	if artifact_id.is_empty() or not state.remove_artifact(state.player, artifact_id):
		events.append("施法失败：玩家没有指定法器。")
		return
	npc["affinity"] = clampi(int(npc.get("affinity", 0)) - 4, 0, 10)
	if artifact_id in npc.get("dominion_requirement", []):
		var moved: int = state.transfer_all_artifacts(npc, state.player)
		events.append("施法成功：%s 正是对方统治所需，夺得 %d 个法器。" % [state.artifact_name(artifact_id), moved])
		state.remember_player("第 %d 回合，对 %s 施法成功，使用「%s」夺得 %d 个法器。" % [state.chapter_round + 1, npc.get("public_name", "NPC"), state.artifact_name(artifact_id), moved])
		state.remember_current_npc("第 %d 回合，玩家用「%s」施法命中我的统治需求，夺走了我的背包。" % [state.chapter_round + 1, state.artifact_name(artifact_id)])
		if moved == 0:
			_kill_npc(state, npc, events, "施法击杀")
	else:
		events.append("施法失败：%s 不是对方统治所需。" % state.artifact_name(artifact_id))
		state.remember_player("第 %d 回合，对 %s 施法失败，消耗「%s」。" % [state.chapter_round + 1, npc.get("public_name", "NPC"), state.artifact_name(artifact_id)])
		state.remember_current_npc("第 %d 回合，玩家用「%s」对我施法但没有命中。" % [state.chapter_round + 1, state.artifact_name(artifact_id)])


static func _payload_artifact_id(payload) -> String:
	if typeof(payload) == TYPE_DICTIONARY:
		return String(payload.get("artifact_id", ""))
	return ""


static func _affinity_delta(npc: Dictionary, speech: String) -> int:
	var delta := 1
	for topic in npc.get("liked_topics", []):
		if speech.contains(String(topic)):
			delta += 1
	if speech.length() <= 45:
		delta += 1
	if speech.contains("身份") or speech.contains("阵营"):
		delta -= 1
	return clampi(delta, -2, 3)


static func _judge_player(npc: Dictionary) -> String:
	var affinity := int(npc.get("affinity", 0))
	var stance := String(npc.get("true_stance", "neutral"))
	if stance == "friend" and affinity >= 4:
		return "friend"
	if stance == "enemy" and affinity >= 3:
		return "enemy"
	if stance == "neutral" and affinity >= 6:
		return "friend"
	return "unknown"


static func _detect_identity_exposure(state, npc: Dictionary, speech: String, events: Array[String]) -> void:
	if String(npc.get("friend_judgement", "unknown")) == "friend":
		return
	for card in state.player.get("identity_cards", []):
		var card_id := String(card.get("id", ""))
		if card_id in state.exposed_identity_ids:
			continue
		var title := String(card.get("title", ""))
		if not title.is_empty() and speech.contains(title):
			state.exposed_identity_ids.append(card_id)
			events.append("身份卡暴露：%s。" % title)


static func _reveal_available_intel(state, npc: Dictionary, events: Array[String]) -> void:
	var judgement := String(npc.get("friend_judgement", "unknown"))
	if judgement == "unknown":
		return
	for intel in npc.get("intel", []):
		var question_id := String(intel.get("question_id", intel.get("clue_id", "")))
		if int(npc.get("affinity", 0)) < int(intel.get("affinity_required", 0)):
			continue
		var correct_option := String(intel.get("correct_option_id", state.world_intel_answers.get(question_id, intel.get("correct", ""))))
		var wrong_option := String(intel.get("wrong_option_id", intel.get("wrong", "")))
		if wrong_option == correct_option or wrong_option.is_empty():
			wrong_option = state.first_other_world_intel_option(question_id, correct_option)
		var option_id := correct_option if judgement == "friend" else wrong_option
		if not state.add_intel_testimony(question_id, option_id, npc, judgement == "friend"):
			continue
		events.append("%s 透露了%s情报：%s。" % [
			npc.get("public_name", "NPC"),
			"可信" if judgement == "friend" else "可疑",
			state.world_intel_option_title(question_id, option_id)
		])


static func _resolve_player_dominion(state, events: Array[String]) -> void:
	state.chapter_dominion_completed = true
	if state.chapter_index < state.max_chapters - 1:
		var old_chapter: int = state.chapter_index + 1
		if state.advance_chapter():
			events.append("第 %d 章统治达成，进入第 %d 章。" % [old_chapter, state.chapter_index + 1])
		return
	events.append("第三章统治完成。世界设定档案仍需提交。")
	state.remember_player("第 3 章统治完成，但最终胜利仍需提交世界设定档案。")


static func _force_submit_world_intel(state, events: Array[String], reason: String) -> void:
	events.append(reason)
	events.append_array(submit_world_intel(state, state.selected_world_intel.duplicate(true)))


static func _resolve_invite(state, npc: Dictionary, events: Array[String]) -> void:
	if npc.get("friend_judgement", "unknown") == "enemy" or npc.get("true_stance", "neutral") == "enemy":
		_end(state, false, "邀请敌人失败：%s 直接刺杀了玩家。" % npc.get("public_name", "NPC"))
		return
	if npc.get("friend_judgement", "unknown") != "friend":
		events.append("邀请失败：%s 尚未信任玩家。" % npc.get("public_name", "NPC"))
		return
	var score := int(state.player.get("stats", {}).get("charm", 0)) + int(npc.get("affinity", 0))
	if score >= int(npc.get("join_threshold", 8)):
		var moved: int = state.transfer_all_artifacts(npc, state.player)
		state.allies.append(npc.duplicate(true))
		state.max_player_chars += int(npc.get("ally_bonus_chars", 80))
		events.append("邀请成功：%s 加入队伍，并交出 %d 个法器。" % [npc.get("public_name", "NPC"), moved])
		state.remember_player("第 %d 回合，成功邀请 %s 加入队伍，并获得其 %d 个法器。" % [state.chapter_round + 1, npc.get("public_name", "NPC"), moved])
		state.remember_current_npc("第 %d 回合，接受玩家邀请加入队伍。" % (state.chapter_round + 1))
	else:
		events.append("邀请失败：魅力与好感度不足。")


static func _resolve_assassinate(state, npc: Dictionary, events: Array[String]) -> void:
	var attack := int(state.player.get("stats", {}).get("assassination_attack", 0))
	var defense := int(npc.get("stats", {}).get("assassination_defense", 0))
	if attack > defense:
		_collect_all_npc_info(state, npc, events)
		_kill_npc(state, npc, events, "暗杀成功")
		return
	_expose_random_identity(state, events)
	events.append("暗杀失败，进入决斗。")
	_resolve_duel(state, npc, events)


static func _resolve_duel(state, npc: Dictionary, events: Array[String]) -> void:
	var player_hp := int(state.player.get("stats", {}).get("hp", 1))
	var npc_hp := int(npc.get("stats", {}).get("hp", 1))
	var player_attack := int(state.player.get("stats", {}).get("frontal_attack", 1))
	var player_defense := int(state.player.get("stats", {}).get("frontal_defense", 0))
	var npc_attack := int(npc.get("stats", {}).get("frontal_attack", 1))
	var npc_defense := int(npc.get("stats", {}).get("frontal_defense", 0))
	while player_hp > 0 and npc_hp > 0:
		player_hp -= max(1, npc_attack - player_defense)
		if player_hp <= 0:
			break
		npc_hp -= max(1, player_attack - npc_defense)
	if player_hp <= 0:
		_end(state, false, "决斗失败：玩家死亡。")
	else:
		_collect_all_npc_info(state, npc, events)
		_kill_npc(state, npc, events, "决斗胜利")


static func _kill_npc(state, npc: Dictionary, events: Array[String], reason: String) -> void:
	if String(npc.get("true_stance", "neutral")) == "friend":
		_end(state, false, "天谴：击杀友方 NPC，游戏失败。")
		return
	var moved: int = state.transfer_all_artifacts(npc, state.player)
	npc["alive"] = false
	state.set_current_npc(npc)
	events.append("%s：%s 死亡，获得 %d 个法器。" % [reason, npc.get("public_name", "NPC"), moved])
	state.remember_player("第 %d 回合，%s 导致 %s 死亡，并获得 %d 个法器。" % [state.chapter_round + 1, reason, npc.get("public_name", "NPC"), moved])
	state.remember_current_npc("第 %d 回合，因%s而死亡。" % [state.chapter_round + 1, reason])


static func _collect_all_npc_info(state, npc: Dictionary, events: Array[String]) -> void:
	for item in npc.get("identity_info", []):
		var text := String(item)
		if not text in state.known_identity_info:
			state.known_identity_info.append(text)
	for intel in npc.get("intel", []):
		var question_id := String(intel.get("question_id", intel.get("clue_id", "")))
		var option_id := String(intel.get("correct_option_id", state.world_intel_answers.get(question_id, intel.get("correct", ""))))
		state.add_intel_testimony(question_id, option_id, npc, true)
	events.append("获得 %s 的全部身份与情报。" % npc.get("public_name", "NPC"))


static func _expose_random_identity(state, events: Array[String]) -> void:
	for card in state.player.get("identity_cards", []):
		var card_id := String(card.get("id", ""))
		if not card_id in state.exposed_identity_ids:
			state.exposed_identity_ids.append(card_id)
			events.append("随机暴露身份卡：%s。" % card.get("title", card_id))
			return


static func _auto_npc_shop(state, events: Array[String]) -> void:
	for i in range(state.npcs.size()):
		var npc: Dictionary = state.npcs[i]
		if not bool(npc.get("alive", true)):
			continue
		for artifact_id in _npc_purchase_priority(npc):
			if not String(artifact_id) in state.shop_items:
				continue
			var artifact: Dictionary = state.get_artifact(String(artifact_id))
			var price := int(artifact.get("price", 0))
			if int(npc.get("energy", 0)) >= price:
				npc["energy"] = int(npc.get("energy", 0)) - price
				state.add_artifact(npc, String(artifact_id))
				events.append("%s 在商店购入了某件法器。" % npc.get("public_name", "NPC"))
				state.npcs[i] = npc
				state.remember_npc_by_index(i, "第 %d 回合，在商店购买了法器「%s」。" % [state.chapter_round + 1, state.artifact_name(String(artifact_id))])
				npc = state.npcs[i]
				break
		state.npcs[i] = npc


static func _npc_purchase_priority(npc: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for artifact_id in npc.get("dominion_requirement", []):
		if not String(artifact_id) in npc.get("artifact_history", []):
			result.append(String(artifact_id))
	for artifact_id in npc.get("ascension_requirement", []):
		if not String(artifact_id) in npc.get("inventory", []):
			result.append(String(artifact_id))
	return result


static func _auto_npc_ascension(state, events: Array[String]) -> void:
	for i in range(state.npcs.size()):
		var npc: Dictionary = state.npcs[i]
		if not bool(npc.get("alive", true)):
			continue
		if int(npc.get("level", 1)) >= 10:
			continue
		if not state.ascension_met(npc):
			continue
		for artifact_id in npc.get("ascension_requirement", []):
			state.remove_artifact(npc, String(artifact_id))
		npc["level"] = int(npc.get("level", 1)) + 1
		var stats: Dictionary = npc.get("stats", {})
		stats["hp"] = int(stats.get("hp", 0)) + 1
		stats["charm"] = int(stats.get("charm", 0)) + 1
		stats["frontal_attack"] = int(stats.get("frontal_attack", 0)) + 1
		npc["stats"] = stats
		state.regenerate_ascension_requirement(npc)
		events.append("%s 完成了一次升华。" % npc.get("public_name", "NPC"))
		state.npcs[i] = npc
		state.remember_npc_by_index(i, "第 %d 回合，完成升华，等级提升到 %d。" % [state.chapter_round + 1, int(npc.get("level", 1))])


static func _check_npc_dominion(state, events: Array[String]) -> void:
	for npc in state.npcs:
		if not bool(npc.get("alive", true)):
			continue
		if not state.dominion_met(npc):
			continue
		events.append("%s 达成了自己的统治需求，局势压力上升。" % npc.get("public_name", "NPC"))
		return


static func _end(state, is_victory: bool, reason: String) -> void:
	state.active = false
	state.ended = true
	state.victory = is_victory
	state.end_reason = reason
	state.phase = state.PHASE_ENDED
