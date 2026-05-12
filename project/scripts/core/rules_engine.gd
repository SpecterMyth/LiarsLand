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
	_detect_dominion_artifact_exposure(state, npc, player_speech, events)
	if state.ended:
		return events
	_reveal_available_intel(state, npc, events)
	state.set_current_npc(npc)
	if typeof(npc_response) == TYPE_DICTIONARY:
		_apply_npc_action(state, npc_response, events)
		if state.ended:
			return events
		_apply_npc_offer(state, npc_response, events)
	if state.player_chars >= state.max_player_chars:
		_force_submit_world_intel(state, events, "Output limit reached; only the human user may submit world intel.")
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
			events.append("Event resolved.")
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
		events.append("Event resolved.")
		return events
	var price := int(artifact.get("price", 0))
	if int(state.player.get("energy", 0)) < price:
		events.append("Event resolved.")
		return events
	state.player["energy"] = int(state.player.get("energy", 0)) - price
	state.add_artifact(state.player, artifact_id)
	events.append("Event resolved.")
	state.remember_player("Event resolved.")
	return events


static func ascend_player(state, stat_gains: Dictionary) -> Array[String]:
	var events: Array[String] = []
	if not state.ascension_met(state.player):
		events.append("Event resolved.")
		return events
	if int(state.player.get("level", 1)) >= 10:
		events.append("Event resolved.")
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
	events.append("Event resolved.")
	state.remember_player("Event resolved.")
	return events


static func finish_round(state) -> Array[String]:
	var events: Array[String] = []
	if state.ended:
		return events
	if bool(state.player_declared_dominion) and state.dominion_met(state.player) and not state.chapter_dominion_completed:
		_resolve_player_dominion(state, events)
		return events
	_auto_npc_shop(state, events)
	_auto_npc_ascension(state, events)
	_check_npc_dominion(state, events)
	if state.ended:
		return events
	state.chapter_round += 1
	if state.chapter_round >= state.max_rounds:
		_end(state, false, "Failure.")
		return events
	state.refresh_npc_choices()
	state.refresh_shop_items()
	state.phase = state.PHASE_SELECT
	return events


static func check_chapter_resolution(state) -> void:
	if bool(state.player_declared_dominion) and state.dominion_met(state.player) and not state.chapter_dominion_completed:
		var events: Array[String] = []
		_resolve_player_dominion(state, events)


static func submit_world_intel(state, answers: Dictionary, submitted_by_human := false) -> Array[String]:
	var events: Array[String] = []
	if state.ended:
		return events
	if not submitted_by_human:
		events.append("Event resolved.")
		return events
	if state.intel_submitted:
		events.append("Event resolved.")
		return events
	state.intel_submitted = true
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		var submitted := String(answers.get(question_id, ""))
		state.select_world_intel_answer(question_id, submitted)
		if submitted.is_empty() or submitted != String(state.world_intel_answers.get(question_id, "")):
			_end(state, false, "Failure.")
			events.append(state.end_reason)
			return events
	_end(state, true, "Victory.")
	events.append(state.end_reason)
	return events


static func _apply_npc_offer(state, npc_response: Dictionary, events: Array[String]) -> void:
	if npc_response.has("gift_offer") and typeof(npc_response.get("gift_offer")) == TYPE_DICTIONARY:
		_resolve_npc_gift(state, state.current_npc(), npc_response.get("gift_offer", {}), events)
	if npc_response.has("exchange_offer") and typeof(npc_response.get("exchange_offer")) == TYPE_DICTIONARY:
		_resolve_npc_exchange(state, state.current_npc(), npc_response.get("exchange_offer", {}), events)


static func _apply_npc_action(state, npc_response: Dictionary, events: Array[String]) -> void:
	var action := String(npc_response.get("action", "none")).strip_edges().to_lower()
	if action == ACTION_ASSASSINATE:
		_resolve_npc_assassinate(state, state.current_npc(), events)
	elif action == ACTION_DUEL:
		pass


static func _resolve_npc_assassinate(state, npc: Dictionary, events: Array[String]) -> void:
	var attack := int(npc.get("stats", {}).get("assassination_attack", 0))
	var defense := int(state.player.get("stats", {}).get("assassination_defense", 0))
	if attack > defense:
		var moved: int = state.transfer_all_artifacts(state.player, npc)
		state.set_current_npc(npc)
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")
		_end(state, false, "Failure.")
		return
	events.append("Event resolved.")
	state.remember_player("Event resolved.")
	state.remember_current_npc("Event resolved.")


static func _resolve_npc_gift(state, npc: Dictionary, offer: Dictionary, events: Array[String]) -> void:
	var artifact_id := String(offer.get("artifact_id", ""))
	if artifact_id.is_empty():
		return
	if int(npc.get("affinity", 0)) < int(offer.get("affinity_required", 6)):
		events.append("Event resolved.")
		return
	if not state.transfer_artifact(npc, state.player, artifact_id):
		events.append("Event resolved.")
		return
	state.set_current_npc(npc)
	events.append("Event resolved.")
	state.remember_player("Event resolved.")
	state.remember_current_npc("Event resolved.")


static func _resolve_npc_exchange(state, npc: Dictionary, offer: Dictionary, events: Array[String]) -> void:
	var npc_artifact := String(offer.get("npc_artifact_id", ""))
	var player_artifact := String(offer.get("player_artifact_id", ""))
	if npc_artifact.is_empty() or player_artifact.is_empty():
		return
	if int(npc.get("affinity", 0)) < int(offer.get("affinity_required", 4)):
		events.append("Event resolved.")
		return
	if not state.has_artifact(npc, npc_artifact) or not state.has_artifact(state.player, player_artifact):
		events.append("Event resolved.")
		return
	state.transfer_artifact(npc, state.player, npc_artifact)
	state.transfer_artifact(state.player, npc, player_artifact)
	state.set_current_npc(npc)
	events.append("Event resolved.")
	state.remember_player("Event resolved.")
	state.remember_current_npc("Event resolved.")


static func _resolve_player_gift(state, npc: Dictionary, payload, events: Array[String]) -> void:
	var artifact_id := _payload_artifact_id(payload)
	if artifact_id.is_empty() or not state.transfer_artifact(state.player, npc, artifact_id):
		events.append("Event resolved.")
		return
	npc["affinity"] = clampi(int(npc.get("affinity", 0)) + 5, 0, 10)
	events.append("Event resolved.")
	state.remember_player("Event resolved.")
	state.remember_current_npc("Event resolved.")


static func _resolve_cast(state, npc: Dictionary, payload, events: Array[String]) -> void:
	var artifact_id := _payload_artifact_id(payload)
	if artifact_id.is_empty() or not state.has_artifact(state.player, artifact_id):
		events.append("Event resolved.")
		return
	npc["affinity"] = clampi(int(npc.get("affinity", 0)) - 4, 0, 10)
	if artifact_id in npc.get("dominion_requirement", []):
		state.remove_artifact(state.player, artifact_id)
		var moved: int = state.transfer_all_artifacts(npc, state.player)
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")
		if moved == 0:
			_kill_npc(state, npc, events, "cast")
	else:
		state.transfer_artifact(state.player, npc, artifact_id)
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")


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
	if false:
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


static func _detect_dominion_artifact_exposure(state, npc: Dictionary, speech: String, events: Array[String]) -> void:
	if String(npc.get("friend_judgement", "unknown")) == "friend":
		return
	for artifact_id in state.player.get("dominion_requirement", []):
		var id := String(artifact_id)
		if id in state.exposed_dominion_artifact_ids:
			continue
		var name: String = state.artifact_name(id)
		if speech.contains(id) or (not name.is_empty() and speech.contains(name)):
			state.exposed_dominion_artifact_ids.append(id)
			events.append("Event resolved.")


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
		events.append("Event resolved.")


static func _resolve_player_dominion(state, events: Array[String]) -> void:
	state.chapter_dominion_completed = true
	if state.chapter_index < state.max_chapters - 1:
		var old_chapter: int = state.chapter_index + 1
		if state.advance_chapter():
			events.append("Event resolved.")
		return
	events.append("Event resolved.")
	state.remember_player("Event resolved.")


static func _force_submit_world_intel(state, events: Array[String], reason: String) -> void:
	events.append(reason)
	_end(state, false, "Failure.")
	events.append(state.end_reason)


static func _resolve_invite(state, npc: Dictionary, events: Array[String]) -> void:
	if npc.get("friend_judgement", "unknown") == "enemy" or npc.get("true_stance", "neutral") == "enemy":
		_end(state, false, "Failure.")
		return
	if npc.get("friend_judgement", "unknown") != "friend":
		events.append("Event resolved.")
		return
	var score := int(state.player.get("stats", {}).get("charm", 0)) + int(npc.get("affinity", 0))
	if score >= int(npc.get("join_threshold", 8)):
		var moved: int = state.transfer_all_artifacts(npc, state.player)
		state.allies.append(npc.duplicate(true))
		state.max_player_chars += int(npc.get("ally_bonus_chars", 80))
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")
	else:
		events.append("Event resolved.")


static func _resolve_assassinate(state, npc: Dictionary, events: Array[String]) -> void:
	var attack := int(state.player.get("stats", {}).get("assassination_attack", 0))
	var defense := int(npc.get("stats", {}).get("assassination_defense", 0))
	if attack > defense:
		_collect_all_npc_info(state, npc, events)
		_kill_npc(state, npc, events, "cast")
		return
	_expose_dominion_artifact(state, events)
	events.append("Event resolved.")
	_resolve_lethal_duel(state, npc, events, "failed assassination")


static func _resolve_duel(state, npc: Dictionary, events: Array[String]) -> void:
	if _simulate_duel_player_wins(state, npc):
		var moved: int = state.transfer_all_artifacts(npc, state.player)
		state.set_current_npc(npc)
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")
	else:
		var moved: int = state.transfer_all_artifacts(state.player, npc)
		state.set_current_npc(npc)
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")


static func _resolve_lethal_duel(state, npc: Dictionary, events: Array[String], reason: String) -> void:
	if _simulate_duel_player_wins(state, npc):
		if String(npc.get("true_stance", "neutral")) == "friend":
			_end(state, false, "Failure.")
			return
		var moved: int = state.transfer_all_artifacts(npc, state.player)
		npc["alive"] = false
		state.set_current_npc(npc)
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")
	else:
		var moved: int = state.transfer_all_artifacts(state.player, npc)
		state.set_current_npc(npc)
		events.append("Event resolved.")
		state.remember_player("Event resolved.")
		state.remember_current_npc("Event resolved.")
		_end(state, false, "Failure.")


static func _simulate_duel_player_wins(state, npc: Dictionary) -> bool:
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
	return player_hp > 0


static func _kill_npc(state, npc: Dictionary, events: Array[String], reason: String) -> void:
	if String(npc.get("true_stance", "neutral")) == "friend":
		_end(state, false, "Failure.")
		return
	var moved: int = state.transfer_all_artifacts(npc, state.player)
	npc["alive"] = false
	state.set_current_npc(npc)
	events.append("Event resolved.")
	state.remember_player("Event resolved.")
	state.remember_current_npc("Event resolved.")


static func _collect_all_npc_info(state, npc: Dictionary, events: Array[String]) -> void:
	for item in npc.get("identity_info", []):
		var text := String(item)
		if not text in state.known_identity_info:
			state.known_identity_info.append(text)
	for intel in npc.get("intel", []):
		var question_id := String(intel.get("question_id", intel.get("clue_id", "")))
		var option_id := String(intel.get("correct_option_id", state.world_intel_answers.get(question_id, intel.get("correct", ""))))
		state.add_intel_testimony(question_id, option_id, npc, true)
	events.append("Event resolved.")


static func _expose_dominion_artifact(state, events: Array[String]) -> void:
	for artifact_id in state.player.get("dominion_requirement", []):
		var id := String(artifact_id)
		if not id in state.exposed_dominion_artifact_ids:
			state.exposed_dominion_artifact_ids.append(id)
			events.append("Event resolved.")
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
				events.append("Event resolved.")
				state.npcs[i] = npc
				state.remember_npc_by_index(i, "Event resolved.")
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
		events.append("Event resolved.")
		state.npcs[i] = npc
		state.remember_npc_by_index(i, "Event resolved.")


static func _check_npc_dominion(state, events: Array[String]) -> void:
	for npc in state.npcs:
		if not bool(npc.get("alive", true)):
			continue
		if not state.dominion_met(npc):
			continue
		events.append("Event resolved.")
		return


static func _end(state, is_victory: bool, reason: String) -> void:
	state.active = false
	state.ended = true
	state.victory = is_victory
	state.end_reason = reason
	state.end_reason_id = ""
	state.phase = state.PHASE_ENDED
