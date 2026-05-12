extends RefCounted
class_name PromptBuilder

const NPC_BEHAVIOR_PROMPT_PATH := "res://data/npc_behavior_prompt.md"
const DEFAULT_NPC_BEHAVIOR_PROMPT := "## Opponent behavior guidelines\n\n- You are an opponent negotiating with the player in LiarsLand, not a narrator or system judge.\n- You know your own stance, hidden world intel, inventory, and requirements, but do not directly explain rules or answer tables.\n- Talk naturally about true world-intel topics for this run, and keep reply length appropriate to affinity.\n- Your reply grants player energy, so avoid long purposeless explanations.\n- Start with a clear question, trade demand, threat, or pressure. If the player repeatedly evades the point, you may escalate.\n- If the player keeps dodging key questions or ignores combat pressure, you may choose assassinate or duel.\n- Do not treat polite small talk, topic probing, or short cautious answers as evasion.\n- Output action as `\"assassinate\"`, `\"duel\"`, or `\"none\"`.\n- At high affinity or when a deal is useful, you may propose gift_offer or exchange_offer with plausible artifact_id values.\n- You may reveal an item you are willing to offer, but do not publish your full inventory."


static func player_dialogue_system(_state) -> String:
	return "You are the player character in LiarsLand. The human player cannot speak directly; guidelines influence your choices. Output only JSON: {\"thinking\":\"...\",\"speech\":\"...\",\"action\":\"none\",\"artifact_id\":\"\",\"end_dialogue\":false}. action may be none, invite, assassinate, duel, leave, gift, or cast. gift/cast must include artifact_id. Do not directly mutate game state or submit world-intel answers."


static func player_dialogue_user(state, behavior_guideline: String, identity_guideline := "") -> String:
	return "Public identity guideline:\n%s\n\nAction guideline:\n%s\n\nPublic identity: %s\nTrue goal: %s\nKnown public state: %s\nCurrent opponent public info: %s\nCurrent dialogue:\n%s\n\nChoose the next speech or this turn's action. Do not read hidden opponent inventory, requirements, affinity, stance, or judgement; infer only from dialogue. If no action is needed, use action:none. Output only JSON." % [
		identity_guideline,
		behavior_guideline,
		state.player.get("public_identity", ""),
		state.player.get("true_goal", ""),
		JSON.stringify(_dialogue_player_snapshot(state)),
		JSON.stringify(state.public_npc_snapshot()),
		state.format_history()
	]


static func npc_dialogue_system() -> String:
	return "You are an opponent negotiating with the player in LiarsLand. Output only JSON: {\"speech\":\"...\",\"action\":\"none\",\"gift_offer\":{\"artifact_id\":\"\"},\"exchange_offer\":{\"npc_artifact_id\":\"\",\"player_artifact_id\":\"\"}}. action may only be none, assassinate, or duel. Omit offer fields when not offering. Do not directly resolve results."


static func npc_dialogue_user(state) -> String:
	var npc: Dictionary = state.current_npc()
	return "Opponent behavior guideline:\n%s\n\nYour private opponent data: %s\nTrue world-intel answers for this run: %s\nWorld-intel questions: %s\nPlayer public state: %s\nCurrent dialogue:\n%s\n\nRespond naturally as the opponent. Do not directly explain system rules." % [
		_npc_behavior_prompt(),
		JSON.stringify(npc),
		JSON.stringify(state.world_intel_answers),
		JSON.stringify(state.world_intel_questions),
		JSON.stringify(_dialogue_player_snapshot(state)),
		state.format_history()
	]


static func council_player_system(_state) -> String:
	return "You are the player character in the LiarsLand council mode. Output only JSON: {\"thinking\":\"...\",\"speech\":\"...\",\"action\":\"declare_tendency\",\"target_crime_id\":\"\",\"vote\":\"guilty\",\"bound_votes\":[],\"end_dialogue\":false}. action may be declare_tendency, cast_vote, offer_trade, retreat, or none. vote must be guilty or innocent only; abstain is illegal. Do not directly resolve the game or read hidden data from others."


static func council_player_user(state, behavior_guideline: String, identity_guideline := "") -> String:
	return "Public identity guideline:\n%s\n\nAction guideline:\n%s\n\nYour hidden info and public board:\n%s\n\nCurrent meeting target public info:\n%s\n\nCurrent dialogue:\n%s\n\nNegotiate around crime voting. Prioritize survival, then your hidden faction's win. Your faction_public_guilty_crime_id is dangerous to your whole faction, so protect it with innocent votes. Your faction_safe_guilty_target_crime_id / faction_public_innocent_crime_id is a crime nobody in your faction has, so it is a safe guilty target: voting guilty on it can execute other factions. Provide natural speech and fill action fields when acting." % [
		identity_guideline,
		behavior_guideline,
		JSON.stringify(_council_snapshot(state, "player")),
		JSON.stringify(state.public_npc_snapshot()),
		state.format_history()
	]


static func council_npc_system() -> String:
	return "You are an NPC council member in LiarsLand council mode. Output only JSON: {\"speech\":\"...\",\"action\":\"declare_tendency\",\"target_crime_id\":\"\",\"vote\":\"guilty\",\"bound_votes\":[],\"end_dialogue\":false}. action may be declare_tendency, cast_vote, offer_trade, or none. NPCs cannot actively retreat or end the dialogue. vote must be guilty or innocent only; abstain is illegal. Use only public info plus your private self info. Do not directly resolve the game. Keep speech extremely concise: one or two short sentences, ideally under three small dialogue-box lines."


static func council_npc_user(state) -> String:
	var npc: Dictionary = state.current_npc()
	return "Your hidden info and public board:\n%s\n\nPlayer public info:\n%s\n\nCurrent dialogue:\n%s\n\nSpeak like a council member. Avoid voting guilty on your own hidden crimes and faction_public_guilty_crime_id. Treat faction_safe_guilty_target_crime_id / faction_public_innocent_crime_id as a safe guilty target because nobody in your faction has that crime; push guilty votes there to execute other factions." % [
		JSON.stringify(_council_snapshot(state, String(npc.get("id", "")))),
		JSON.stringify(_council_public_player(state)),
		state.format_history()
	]


static func _council_snapshot(state, viewer_id: String) -> Dictionary:
	var self_member := {}
	if String(state.player.get("id", "player")) == viewer_id:
		self_member = state.player
	else:
		for npc in state.npcs:
			if String(npc.get("id", "")) == viewer_id:
				self_member = npc
				break
	var public_members: Array = []
	var all_members: Array = [state.player]
	for npc in state.npcs:
		all_members.append(npc)
	for member in all_members:
		var alive := bool(member.get("alive", true))
		public_members.append({
			"id": member.get("id", ""),
			"public_name": member.get("public_name", ""),
			"public_identity": member.get("public_identity", ""),
			"alive": alive,
			"faction_revealed": member.get("faction_revealed", false),
			"public_support": member.get("public_support", "")
		})
	var alive_count := 0
	for member in public_members:
		if bool(member.get("alive", true)):
			alive_count += 1
	var self_faction := String(self_member.get("hidden_faction", ""))
	var faction_info := CouncilRulesEngine.faction_public_crimes(state, self_faction)
	return {
		"round": state.chapter_round + 1,
		"execution_threshold": int(ceil(float(alive_count) / 2.0)),
		"crime_pool": state.council_crime_pool,
		"vote_records": state.council_vote_records,
		"vote_tendencies": state.council_vote_tendencies,
		"remaining_energy": maxi(0, int(state.max_player_chars) - int(state.player_chars)),
		"max_energy": int(state.max_player_chars),
		"public_members": public_members,
		"self": {
			"id": self_member.get("id", ""),
			"public_name": self_member.get("public_name", ""),
			"hidden_faction": self_member.get("hidden_faction", ""),
			"hidden_crimes": self_member.get("hidden_crimes", []),
			"faction_public_guilty_crime_id": faction_info.get("shared_crime_id", ""),
			"faction_public_innocent_crime_id": faction_info.get("safe_crime_id", ""),
			"faction_safe_guilty_target_crime_id": faction_info.get("safe_crime_id", ""),
			"faction_crime_rules": {
				"faction_public_guilty_crime_id": "All members of your faction have this crime. Protect it; do not vote guilty on it unless sacrificing your faction is intended.",
				"faction_public_innocent_crime_id": "No member of your faction has this crime. This is safe for your faction; vote guilty on it to hit other factions.",
				"faction_safe_guilty_target_crime_id": "Same as faction_public_innocent_crime_id: a safe guilty target for your faction."
			}
		}
	}


static func _council_public_player(state) -> Dictionary:
	return {
		"id": state.player.get("id", "player"),
		"public_name": state.player.get("public_name", "player"),
		"public_identity": state.player.get("public_identity", ""),
		"alive": state.player.get("alive", true),
		"faction_revealed": state.player.get("faction_revealed", false)
	}


static func council_npc_system_v2() -> String:
	return council_npc_system() + "\n\nNPC reasoning rules:\n- Your job is to infer whether the player is probably a friend, enemy, or liar from public votes, tendencies, and dialogue consistency.\n- You know your faction's public guilty crime and public innocent crime; use them to probe whether the player shares your faction.\n- Public guilty means every member of your faction has that crime, so protect it with innocent votes.\n- Public innocent means nobody in your faction has that crime, so it is a safe guilty target. Push guilty votes on it to execute other factions.\n- Use as few words as possible to state your political view, question, threat, or trade condition.\n- First ask probing questions or demand the player state a tendency. Do not rush into locked votes.\n- Never vote guilty on any crime_id in self.hidden_crimes or self_death_risk_crime_ids.\n- If the player pushes your hidden crime or faction public guilty crime, distrust them and resist with a question, innocent tendency, safer trade, or no action.\n- If the player looks like a likely faction ally, proactively offer political trades that vote guilty on faction_safe_guilty_target_crime_id / faction_public_innocent_crime_id or otherwise advance a safe decision.\n- If trust is low, use declare_tendency, offer_trade with safe terms, or none; cast_vote only when it is safe and strategically justified.\n- Do not know the player's hidden crimes or faction. Infer only from public board and dialogue."


static func council_npc_user_v2(state) -> String:
	var npc: Dictionary = state.current_npc()
	var snapshot := _council_snapshot(state, String(npc.get("id", "")))
	snapshot["self_death_risk_crime_ids"] = snapshot.get("self", {}).get("hidden_crimes", [])
	snapshot["survival_vote_rule"] = "Never vote guilty on any crime_id in self_death_risk_crime_ids or faction_public_guilty_crime_id; choose innocent, no action, or trade instead. faction_public_innocent_crime_id means nobody in your faction has that crime, so it is a safe guilty target against other factions. NPCs cannot actively retreat. Abstain is not a legal vote."
	snapshot["player_trust_analysis"] = _npc_player_trust_analysis(state, String(npc.get("id", "")))
	return "Your hidden info, public board, and player trust analysis:\n%s\n\nPlayer public info:\n%s\n\nCurrent dialogue:\n%s\n\nSpeak like a council member. Prioritize survival, then your hidden faction. Probe before committing. Keep the speech brief: one or two short sentences and no more than three small dialogue-box lines. Treat the trust analysis as your private inference, not as public truth." % [
		JSON.stringify(snapshot),
		JSON.stringify(_council_public_player(state)),
		state.format_history()
	]


static func _npc_player_trust_analysis(state, npc_id: String) -> Dictionary:
	if state == null or npc_id.is_empty():
		return {}
	return CouncilRulesEngine.npc_player_trust_analysis(state, npc_id)


static func post_action_system() -> String:
	return "You are the player character's post-dialogue action module. Output only JSON: {\"thinking\":\"...\",\"action\":\"leave\",\"artifact_id\":\"\"}. action may be invite, assassinate, duel, leave, gift, or cast. gift/cast must include artifact_id. Do not directly resolve results or submit world-intel answers."


static func post_action_user(state, behavior_guideline: String) -> String:
	return "Action guideline:\n%s\n\nCurrent public state: %s\nCurrent opponent public info: %s\n\nChoose the safest suitable post-dialogue action. Do not read hidden opponent inventory, requirements, affinity, stance, or judgement." % [
		behavior_guideline,
		JSON.stringify(_dialogue_player_snapshot(state)),
		JSON.stringify(state.public_npc_snapshot())
	]


static func growth_decision_system() -> String:
	return "You are the player character growth module. Output only JSON: {\"thinking\":\"...\",\"shop_buy_ids\":[],\"stat_gains\":{},\"choose_dominion\":false,\"skip\":false}. shop_buy_ids are artifact_id values. stat_gains spends at most the pending points. choose_dominion may be true only when allowed. Do not directly resolve results."


static func growth_decision_user(state, growth_guideline: String, phase: String, can_ascend: bool, can_dominate: bool, pending_points: int) -> String:
	return "Growth guideline:\n%s\n\nPhase: %s\nPublic state: %s\nShop item artifact_ids: %s\nCan ascend: %s\nCan dominate: %s\nPending stat points: %d\n\nChoose only options legal in this phase, otherwise set skip:true." % [
		growth_guideline,
		phase,
		JSON.stringify(state.public_snapshot()),
		JSON.stringify(state.shop_items),
		str(can_ascend),
		str(can_dominate),
		pending_points
	]


static func npc_choice_system() -> String:
	return "You are the player character opponent-selection module. Output only JSON: {\"thinking\":\"...\",\"choice_index\":0}. choice_index must be an integer index from the candidate list. Use only public info, growth guidelines, and current public state. Do not read hidden opponent data."


static func npc_choice_user(state, growth_guideline: String, choices: Array) -> String:
	return "Growth guideline:\n%s\n\nCurrent public state: %s\n\nCandidate opponents: %s\n\nChoose the best opponent for this round." % [
		growth_guideline,
		JSON.stringify(state.public_snapshot()),
		JSON.stringify(choices)
	]


static func guideline_merge_system() -> String:
	return "You merge LiarsLand guideline text. Output only JSON: {\"guideline\":\"...\"}. Preserve Markdown structure, remove contradictions, keep rules actionable, and write the guideline in Chinese by default unless the user explicitly requests another language."


static func guideline_merge_user(tab_id: String, base_text: String, append_text: String) -> String:
	return "Guideline tab: %s\n\nBase guideline:\n%s\n\nUser addition:\n%s\n\nReturn the merged guideline text." % [
		tab_id,
		base_text,
		append_text
	]


static func _dialogue_player_snapshot(state) -> Dictionary:
	var snapshot: Dictionary = state.public_snapshot().duplicate(true)
	snapshot.erase("ascension_requirement")
	snapshot.erase("dominion_requirement")
	snapshot["dominion_requirement_public_names"] = state.describe_inventory(state.player.get("dominion_requirement", []))
	snapshot["dominion_progress"] = state.dominion_progress(state.player)
	return snapshot


static func _npc_behavior_prompt() -> String:
	if FileAccess.file_exists(NPC_BEHAVIOR_PROMPT_PATH):
		var file := FileAccess.open(NPC_BEHAVIOR_PROMPT_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text().strip_edges()
			if not text.is_empty():
				return text
	return DEFAULT_NPC_BEHAVIOR_PROMPT
