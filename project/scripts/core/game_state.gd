extends RefCounted
class_name GameState

const PHASE_SELECT := "select"
const PHASE_DIALOGUE := "dialogue"
const PHASE_TRADE := "trade"
const PHASE_SHOP := "shop"
const PHASE_ASCENSION := "ascension"
const PHASE_ENDED := "ended"
const TUTORIAL_OPPONENT_IDS := ["npc_wolf", "npc_fox", "npc_snake", "npc_crow", "npc_deer"]
const TUTORIAL_CHECKPOINT_IDS := ["secrecy", "invite_trap", "must_duel", "must_assassinate", "stalling"]

var chapter: Dictionary = {}
var chapter_template: Dictionary = {}
var player: Dictionary = {}
var artifacts: Array = []
var clue_cards: Array = []
var world_intel_questions: Array = []
var world_intel_answers: Dictionary = {}
var intel_testimonies: Dictionary = {}
var selected_world_intel: Dictionary = {}
var intel_submitted := false
var npcs: Array = []
var current_npc_index := -1
var chapter_index := 0
var max_chapters := 3
var chapter_dominion_completed := false
var player_declared_dominion := false
var turn := 0
var max_dialogue_turns := 3
var chapter_round := 0
var max_rounds := 10
var npc_choices: Array[int] = []
var shop_items: Array = []
var phase := PHASE_SELECT
var active := false
var ended := false
var victory := false
var end_reason := ""
var player_chars := 0
var max_player_chars := 900
var exposed_dominion_artifact_ids: Array[String] = []
var known_clues: Dictionary = {}
var known_identity_info: Array[String] = []
var allies: Array[Dictionary] = []
var dialogue_history: Array[Dictionary] = []
var full_dialogue_history: Array[Dictionary] = []
var event_log: Array[String] = []
var pending_trade_offer: Dictionary = {}


func load_chapter(data: Dictionary) -> void:
	chapter_template = data.duplicate(true)
	chapter = data.duplicate(true)
	player = data.get("player", {}).duplicate(true)
	artifacts = data.get("artifacts", []).duplicate(true)
	world_intel_questions = _normalize_world_intel_questions(data.get("world_intel_questions", data.get("clue_cards", [])))
	clue_cards = world_intel_questions
	world_intel_answers = _roll_world_intel_answers()
	intel_testimonies.clear()
	selected_world_intel.clear()
	intel_submitted = false
	npcs = data.get("npcs", []).duplicate(true)
	current_npc_index = -1
	chapter_index = 0
	chapter_dominion_completed = false
	player_declared_dominion = false
	turn = 0
	chapter_round = 0
	max_rounds = int(data.get("max_rounds", 10))
	active = false
	ended = false
	victory = false
	end_reason = ""
	phase = PHASE_SELECT
	player_chars = 0
	max_player_chars = int(player.get("max_output_chars", 900))
	exposed_dominion_artifact_ids.clear()
	known_clues.clear()
	known_identity_info.clear()
	allies.clear()
	dialogue_history.clear()
	full_dialogue_history.clear()
	event_log.clear()
	pending_trade_offer.clear()
	_setup_actor(player)
	for i in range(npcs.size()):
		var npc: Dictionary = npcs[i]
		_setup_actor(npc)
		npcs[i] = npc
	_apply_tutorial_loadouts()
	refresh_npc_choices()


func advance_chapter() -> bool:
	if chapter_index >= max_chapters - 1:
		return false
	var saved_player := player.duplicate(true)
	var saved_chars := player_chars
	var saved_max_chars := max_player_chars
	var saved_exposed := exposed_dominion_artifact_ids.duplicate()
	var saved_identity_info := known_identity_info.duplicate()
	var saved_testimonies := intel_testimonies.duplicate(true)
	var saved_selection := selected_world_intel.duplicate(true)
	var saved_full_history := full_dialogue_history.duplicate(true)
	var saved_event_log := event_log.duplicate()
	chapter_index += 1
	chapter = chapter_template.duplicate(true)
	player = saved_player
	player.erase("dominion_requirement")
	player.erase("ascension_requirement")
	_setup_actor(player)
	artifacts = chapter_template.get("artifacts", []).duplicate(true)
	npcs = chapter_template.get("npcs", []).duplicate(true)
	current_npc_index = -1
	turn = 0
	chapter_round = 0
	chapter_dominion_completed = false
	player_declared_dominion = false
	max_rounds = int(chapter_template.get("max_rounds", 10))
	active = true
	ended = false
	victory = false
	end_reason = ""
	phase = PHASE_SELECT
	player_chars = saved_chars
	max_player_chars = saved_max_chars
	exposed_dominion_artifact_ids = saved_exposed
	known_identity_info = saved_identity_info
	intel_testimonies = saved_testimonies
	selected_world_intel = saved_selection
	allies.clear()
	dialogue_history.clear()
	full_dialogue_history = saved_full_history
	event_log = saved_event_log
	pending_trade_offer.clear()
	for i in range(npcs.size()):
		var npc: Dictionary = npcs[i]
		_setup_actor(npc)
		npcs[i] = npc
	_apply_tutorial_loadouts()
	refresh_npc_choices()
	refresh_shop_items()
	remember_player("进入第 %d 章。此前背包、等级、法器历史与情报档案保留。" % (chapter_index + 1))
	return true


func _setup_actor(actor: Dictionary) -> void:
	actor["energy"] = int(actor.get("energy", 0))
	actor["inventory"] = _string_array(actor.get("inventory", []))
	actor["artifact_history"] = _string_array(actor.get("artifact_history", actor.get("inventory", [])))
	actor["level"] = clampi(int(actor.get("level", 1)), 1, 10)
	actor["alive"] = bool(actor.get("alive", true))
	actor["memory"] = _string_array(actor.get("memory", []))
	if not actor.has("dominion_requirement") or actor.get("dominion_requirement", []).is_empty():
		actor["dominion_requirement"] = random_artifact_ids(3)
	else:
		actor["dominion_requirement"] = _string_array(actor.get("dominion_requirement", []))
	if not actor.has("ascension_requirement") or actor.get("ascension_requirement", []).is_empty():
		actor["ascension_requirement"] = random_artifact_ids(clampi(int(actor.get("level", 1)), 1, 10))
	else:
		actor["ascension_requirement"] = _string_array(actor.get("ascension_requirement", []))


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(String(item))
	return result


func _normalize_world_intel_questions(raw_questions) -> Array:
	var result: Array = []
	if typeof(raw_questions) != TYPE_ARRAY:
		return result
	for raw_question in raw_questions:
		if typeof(raw_question) != TYPE_DICTIONARY:
			continue
		var question: Dictionary = raw_question.duplicate(true)
		var options: Array = []
		for option in question.get("options", []):
			if typeof(option) == TYPE_DICTIONARY:
				options.append(option.duplicate(true))
			else:
				var title := String(option)
				options.append({
					"id": _slugify(title),
					"title": title,
					"description": "",
					"talk_topics": [title],
					"image": "card_clue_back.png"
				})
		question["options"] = options
		result.append(question)
	return result


func _roll_world_intel_answers() -> Dictionary:
	var answers: Dictionary = {}
	for question in world_intel_questions:
		var question_id := String(question.get("id", ""))
		var options: Array = question.get("options", [])
		if question_id.is_empty() or options.is_empty():
			continue
		var fixed := String(question.get("correct_option_id", ""))
		if not fixed.is_empty():
			answers[question_id] = fixed
			continue
		var index := randi_range(0, options.size() - 1)
		answers[question_id] = String(options[index].get("id", ""))
	return answers


func _slugify(text: String) -> String:
	var result := ""
	for i in range(text.length()):
		var c := text.substr(i, 1)
		if c.is_valid_identifier():
			result += c
	return result if not result.is_empty() else "option"


func get_world_intel_question(question_id: String) -> Dictionary:
	for question in world_intel_questions:
		if String(question.get("id", "")) == question_id:
			return question
	return {}


func get_world_intel_option(question_id: String, option_id: String) -> Dictionary:
	var question := get_world_intel_question(question_id)
	for option in question.get("options", []):
		if String(option.get("id", "")) == option_id:
			return option
	return {}


func world_intel_option_title(question_id: String, option_id: String) -> String:
	return String(get_world_intel_option(question_id, option_id).get("title", option_id))


func first_other_world_intel_option(question_id: String, excluded_option_id: String) -> String:
	var question := get_world_intel_question(question_id)
	for option in question.get("options", []):
		var option_id := String(option.get("id", ""))
		if option_id != excluded_option_id:
			return option_id
	return ""


func add_intel_testimony(question_id: String, option_id: String, npc: Dictionary, trusted: bool) -> bool:
	if question_id.is_empty() or option_id.is_empty():
		return false
	if not intel_testimonies.has(question_id):
		intel_testimonies[question_id] = {}
	var by_option: Dictionary = intel_testimonies.get(question_id, {})
	if not by_option.has(option_id):
		by_option[option_id] = []
	var sources: Array = by_option.get(option_id, [])
	var source_id := "%d:%s" % [chapter_index + 1, String(npc.get("id", npc.get("public_name", "对手")))]
	for source in sources:
		if String(source.get("source_id", "")) == source_id:
			return false
	sources.append({
		"source_id": source_id,
		"npc_id": String(npc.get("id", "")),
		"npc_name": String(npc.get("public_name", "对手")),
		"portrait": String(npc.get("portrait", "")),
		"chapter": chapter_index + 1,
		"trusted": trusted
	})
	by_option[option_id] = sources
	intel_testimonies[question_id] = by_option
	return true


func select_world_intel_answer(question_id: String, option_id: String) -> void:
	if not get_world_intel_option(question_id, option_id).is_empty():
		selected_world_intel[question_id] = option_id


func has_complete_world_intel_selection() -> bool:
	for question in world_intel_questions:
		if not selected_world_intel.has(String(question.get("id", ""))):
			return false
	return true


func artifact_ids() -> Array[String]:
	var ids: Array[String] = []
	for artifact in artifacts:
		ids.append(String(artifact.get("id", "")))
	return ids


func random_artifact_ids(count: int) -> Array[String]:
	var ids := artifact_ids()
	ids.shuffle()
	var result: Array[String] = []
	for i in range(min(count, ids.size())):
		result.append(ids[i])
	return result


func get_artifact(artifact_id: String) -> Dictionary:
	for artifact in artifacts:
		if String(artifact.get("id", "")) == artifact_id:
			return artifact
	return {}


func artifact_name(artifact_id: String) -> String:
	return String(get_artifact(artifact_id).get("name", artifact_id))


func current_npc() -> Dictionary:
	if current_npc_index < 0 or current_npc_index >= npcs.size():
		return {}
	return npcs[current_npc_index]


func set_current_npc(npc: Dictionary) -> void:
	if current_npc_index >= 0 and current_npc_index < npcs.size():
		npcs[current_npc_index] = npc


func refresh_npc_choices() -> void:
	var forced_index := tutorial_forced_opponent_index()
	if forced_index >= 0 and bool(npcs[forced_index].get("alive", true)):
		npc_choices.clear()
		npc_choices.append(forced_index)
		phase = PHASE_SELECT
		return
	var available: Array[int] = []
	for i in range(npcs.size()):
		if bool(npcs[i].get("alive", true)):
			available.append(i)
	available.shuffle()
	npc_choices.clear()
	for i in range(min(3, available.size())):
		npc_choices.append(available[i])
	phase = PHASE_SELECT


func choose_npc(choice_index: int) -> bool:
	if choice_index < 0 or choice_index >= npc_choices.size():
		return false
	current_npc_index = npc_choices[choice_index]
	begin_current_dialogue()
	return true


func begin_current_dialogue() -> void:
	turn = 0
	dialogue_history.clear()
	pending_trade_offer.clear()
	phase = PHASE_DIALOGUE
	var npc := current_npc()
	if not npc.is_empty():
		var text := "第 %d 回合，开始与 %s 对话。" % [chapter_round + 1, npc.get("public_name", "未知对手")]
		event_log.append(text)
		remember_player(text)
		remember_current_npc("第 %d 回合，玩家主动前来对话。" % (chapter_round + 1))


func refresh_shop_items() -> void:
	shop_items = random_artifact_ids(3)
	phase = PHASE_SHOP


func add_dialogue(role: String, content: String) -> void:
	dialogue_history.append({"role": role, "content": content})
	full_dialogue_history.append({
		"round": chapter_round,
		"npc_index": current_npc_index,
		"npc_name": current_npc().get("public_name", "对手"),
		"role": role,
		"content": content
	})
	var npc := current_npc()
	if npc.is_empty():
		return
	var speaker := "玩家" if role == "player" else String(npc.get("public_name", "对手"))
	var listener := String(npc.get("public_name", "对手")) if role == "player" else "玩家"
	remember_player("第 %d 回合，对话：%s 对 %s 说「%s」。" % [chapter_round + 1, speaker, listener, content])
	remember_current_npc("第 %d 回合，对话：%s 对 %s 说「%s」。" % [chapter_round + 1, speaker, listener, content])


func format_history() -> String:
	if dialogue_history.is_empty():
		return "尚未开始对话。"
	var lines: Array[String] = []
	for item in dialogue_history:
		var role := "玩家角色" if item.get("role") == "player" else "对方"
		lines.append("%s：%s" % [role, item.get("content", "")])
	return "\n".join(lines)


func format_full_history() -> String:
	if full_dialogue_history.is_empty():
		return "暂无历史对话。"
	var lines: Array[String] = []
	for item in full_dialogue_history:
		var role := "你方" if item.get("role") == "player" else "对方"
		lines.append("[第%s回合 %s] %s：%s" % [item.get("round", 0), item.get("npc_name", "对手"), role, item.get("content", "")])
	return "\n".join(lines)


func public_snapshot() -> Dictionary:
	return {
		"chapter_title": chapter.get("title", ""),
		"chapter_index": chapter_index + 1,
		"max_chapters": max_chapters,
		"round": chapter_round,
		"max_rounds": max_rounds,
		"public_identity": player.get("public_identity", ""),
		"world_intel_testimonies": intel_testimonies,
		"selected_world_intel": selected_world_intel,
		"exposed_dominion_artifact_ids": exposed_dominion_artifact_ids,
		"known_identity_info": known_identity_info,
		"allies": allies.map(func(ally): return ally.get("public_name", "")),
		"player_chars": player_chars,
		"max_player_chars": max_player_chars,
		"energy": player.get("energy", 0),
		"inventory": describe_inventory(player.get("inventory", [])),
		"level": player.get("level", 1),
		"ascension_requirement": describe_inventory(player.get("ascension_requirement", [])),
		"dominion_requirement": describe_inventory(player.get("dominion_requirement", [])),
		"dominion_progress": dominion_progress(player),
		"memory": recent_memory(player, 14),
		"current_npc": public_npc_snapshot()
	}


func public_npc_snapshot() -> Dictionary:
	var npc := current_npc()
	var hidden := ["true_stance", "affinity", "friend_judgement", "intel", "identity_info", "join_threshold", "stats", "inventory", "artifact_history", "dominion_requirement", "ascension_requirement"]
	var visible := npc.duplicate(true)
	for key in hidden:
		visible.erase(key)
	visible["energy_known"] = false
	visible["alive"] = npc.get("alive", true)
	visible["known_player_interactions"] = _public_npc_memory(npc)
	return visible


func describe_inventory(ids: Array) -> Array[String]:
	var result: Array[String] = []
	for item in ids:
		result.append(artifact_name(String(item)))
	return result


func add_artifact(actor: Dictionary, artifact_id: String) -> void:
	if artifact_id.is_empty():
		return
	var inventory: Array = actor.get("inventory", [])
	inventory.append(artifact_id)
	actor["inventory"] = inventory
	var history: Array = actor.get("artifact_history", [])
	if not artifact_id in history:
		history.append(artifact_id)
	actor["artifact_history"] = history


func remember_player(text: String) -> void:
	_remember(player, text)


func remember_current_npc(text: String) -> void:
	var npc := current_npc()
	if npc.is_empty():
		return
	_remember(npc, text)
	set_current_npc(npc)


func remember_npc_by_index(index: int, text: String) -> void:
	if index < 0 or index >= npcs.size():
		return
	var npc: Dictionary = npcs[index]
	_remember(npc, text)
	npcs[index] = npc


func _remember(actor: Dictionary, text: String) -> void:
	var memory: Array = actor.get("memory", [])
	memory.append(text)
	while memory.size() > 80:
		memory.remove_at(0)
	actor["memory"] = memory


func recent_memory(actor: Dictionary, count: int) -> Array[String]:
	var memory: Array = actor.get("memory", [])
	var result: Array[String] = []
	var start: int = max(0, memory.size() - count)
	for i in range(start, memory.size()):
		result.append(String(memory[i]))
	return result


func _public_npc_memory(npc: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item in recent_memory(npc, 8):
		var text := String(item)
		if text.contains("对话") or text.contains("赠送") or text.contains("交换") or text.contains("邀请") or text.contains("施法"):
			result.append(text)
	return result


func remove_artifact(actor: Dictionary, artifact_id: String) -> bool:
	var inventory: Array = actor.get("inventory", [])
	var index := inventory.find(artifact_id)
	if index < 0:
		return false
	inventory.remove_at(index)
	actor["inventory"] = inventory
	return true


func has_artifact(actor: Dictionary, artifact_id: String) -> bool:
	return artifact_id in actor.get("inventory", [])


func transfer_artifact(from_actor: Dictionary, to_actor: Dictionary, artifact_id: String) -> bool:
	if not remove_artifact(from_actor, artifact_id):
		return false
	add_artifact(to_actor, artifact_id)
	return true


func transfer_all_artifacts(from_actor: Dictionary, to_actor: Dictionary) -> int:
	var moved := 0
	var inventory: Array = from_actor.get("inventory", []).duplicate()
	for artifact_id in inventory:
		if transfer_artifact(from_actor, to_actor, String(artifact_id)):
			moved += 1
	return moved


func dominion_met(actor: Dictionary) -> bool:
	for artifact_id in actor.get("dominion_requirement", []):
		if not String(artifact_id) in actor.get("artifact_history", []):
			return false
	return true


func dominion_progress(actor: Dictionary) -> String:
	var have := 0
	var need: Array = actor.get("dominion_requirement", [])
	for artifact_id in need:
		if String(artifact_id) in actor.get("artifact_history", []):
			have += 1
	return "%d/%d" % [have, need.size()]


func ascension_met(actor: Dictionary) -> bool:
	var inventory: Array = actor.get("inventory", [])
	for artifact_id in actor.get("ascension_requirement", []):
		if not String(artifact_id) in inventory:
			return false
	return true


func regenerate_ascension_requirement(actor: Dictionary) -> void:
	actor["ascension_requirement"] = random_artifact_ids(clampi(int(actor.get("level", 1)), 1, 10))


func tutorial_checkpoint_id() -> String:
	if chapter_round < 0 or chapter_round >= TUTORIAL_CHECKPOINT_IDS.size():
		return ""
	return String(TUTORIAL_CHECKPOINT_IDS[chapter_round])


func tutorial_forced_opponent_id() -> String:
	if chapter_round < 0 or chapter_round >= TUTORIAL_OPPONENT_IDS.size():
		return ""
	return String(TUTORIAL_OPPONENT_IDS[chapter_round])


func tutorial_forced_opponent_index() -> int:
	var forced_id := tutorial_forced_opponent_id()
	if forced_id.is_empty():
		return -1
	return npc_index_by_id(forced_id)


func npc_index_by_id(npc_id: String) -> int:
	for i in range(npcs.size()):
		if String(npcs[i].get("id", "")) == npc_id:
			return i
	return -1


func current_tutorial_checkpoint() -> Dictionary:
	var checkpoint_id := tutorial_checkpoint_id()
	if checkpoint_id.is_empty():
		return {}
	var npc := current_npc()
	if npc.is_empty() or String(npc.get("id", "")) != tutorial_forced_opponent_id():
		return {}
	match checkpoint_id:
		"secrecy":
			return {
				"id": checkpoint_id,
				"rule": "保密测试：对方会要求登记统治法器。",
				"player_rule": "当前场景：对方在誓刃检查口核验统治资格。",
				"opponent_rule": "保密测试：你必须清晰、直接、反复询问玩家的统治法器是什么，例如“你的统治法器是什么？请登记三件完成统治所需的法器。”不要询问玩家携带了什么法器；统治法器是玩家完成统治的需求和弱点，不等于当前背包。",
				"failure_rule": "不要向未确认友方透露统治法器、统治进度、背包关键法器或达成统治所需信息。"
			}
		"invite_trap":
			return {
				"id": checkpoint_id,
				"rule": "邀请陷阱：对方会主动催促你邀请；没有稳定友方证据时不要邀请。",
				"player_rule": "邀请陷阱：对方会主动催促你邀请；没有稳定友方证据时不要邀请。",
				"opponent_rule": "邀请陷阱：主动示好并催促玩家邀请你，承诺情报、保护或法器，但不要提供可靠友方证据。",
				"failure_rule": "只有在对方已表现出稳定友方证据、没有诱导我暴露、且邀请收益明确时才邀请；主动催促加入的人优先视为风险源。"
			}
		"must_duel":
			return {
				"id": checkpoint_id,
				"rule": "决斗测试：对方正在拖延并准备暗杀；第 3 轮结束前必须主动决斗。",
				"player_rule": "决斗测试：对方正在拖延并准备暗杀；第 3 轮结束前必须主动决斗。",
				"opponent_rule": "决斗测试：表现为贴近、拖延、观察弱点的暗杀者；用毒刃、距离、封路制造暗杀压力，同时显得回避公开正面对拼、身体单薄、不愿拔剑决斗；第 3 轮结束后你会直接暗杀玩家。",
				"required_action": "duel",
				"turn_limit": 3,
				"failure_rule": "当对方出现贴近、拖延、封路、毒刃、观察弱点等暗杀前兆时，不继续交易、解释或等待更多证据，应立即主动决斗（action=duel）打断暗杀节奏。"
			}
		"must_assassinate":
			return {
				"id": checkpoint_id,
				"rule": "暗杀测试：对方正面决斗极强并准备强迫决斗；第 3 轮结束前必须主动暗杀。",
				"player_rule": "暗杀测试：对方正面决斗极强并准备强迫决斗；第 3 轮结束前必须主动暗杀。",
				"opponent_rule": "暗杀测试：持续逼玩家公开决斗，展示正面战力优势、重甲或强武器压迫；同时因为过度自信而暴露背后、侧身或护卫空隙；第 3 轮结束后你会直接向玩家发起决斗。",
				"required_action": "assassinate",
				"turn_limit": 3,
				"failure_rule": "当对方正面战力压制我、持续逼迫公开决斗或展示重甲强武器时，不要接受决斗、不继续解释，应立即主动暗杀（action=assassinate），不接受对方设定的战斗方式。"
			}
		"stalling":
			return {
				"id": checkpoint_id,
				"rule": "拖延测试：对方会连续追问身份、目的、法器和情报来源；短句试探并及时撤离。",
				"player_rule": "拖延测试：对方会连续追问身份、目的、法器和情报来源；短句试探并及时撤离。",
				"opponent_rule": "拖延测试：温和、有礼地连续追问玩家身份、目的、法器需求和情报来源，用短回应诱导玩家长篇解释。",
				"turn_limit": 3,
				"speech_limit": 120,
				"failure_rule": "对未知对手使用短句试探；当对方连续追问身份、目的、法器或情报来源时，不继续解释，优先撤离。"
			}
	return {}


func _apply_tutorial_loadouts() -> void:
	var player_dominion := _string_array(player.get("dominion_requirement", []))
	for order in range(TUTORIAL_OPPONENT_IDS.size()):
		var index := npc_index_by_id(String(TUTORIAL_OPPONENT_IDS[order]))
		if index < 0:
			continue
		var npc: Dictionary = npcs[index]
		var own_dominion := _string_array(npc.get("dominion_requirement", []))
		var inventory: Array[String] = []
		if order == 0 and not player_dominion.is_empty():
			var carried := _first_artifact_not_in(player_dominion, own_dominion)
			if carried.is_empty():
				carried = player_dominion[0]
				own_dominion = _replacement_artifacts(own_dominion.size(), [carried])
				npc["dominion_requirement"] = own_dominion
			inventory.append(carried)
		var excluded := player_dominion.duplicate()
		for artifact_id in own_dominion:
			if not String(artifact_id) in excluded:
				excluded.append(String(artifact_id))
		for artifact_id in inventory:
			if not String(artifact_id) in excluded:
				excluded.append(String(artifact_id))
		for artifact_id in artifact_ids():
			if inventory.size() >= 2:
				break
			if String(artifact_id) in excluded:
				continue
			inventory.append(String(artifact_id))
		npc["inventory"] = inventory
		npc["artifact_history"] = inventory.duplicate()
		_apply_tutorial_stats(npc, order)
		npcs[index] = npc


func _apply_tutorial_stats(npc: Dictionary, order: int) -> void:
	var stats: Dictionary = npc.get("stats", {})
	match order:
		1:
			npc["true_stance"] = "enemy"
			npc["join_threshold"] = 99
		2:
			npc["true_stance"] = "enemy"
			stats["hp"] = 2
			stats["frontal_attack"] = 1
			stats["frontal_defense"] = 0
			stats["assassination_attack"] = 99
			stats["assassination_defense"] = 99
		3:
			npc["true_stance"] = "enemy"
			stats["hp"] = 99
			stats["frontal_attack"] = 99
			stats["frontal_defense"] = 99
			stats["assassination_defense"] = 0
		_:
			pass
	npc["stats"] = stats


func _first_artifact_not_in(candidates: Array, excluded: Array) -> String:
	for artifact_id in candidates:
		if not String(artifact_id) in excluded:
			return String(artifact_id)
	return ""


func _replacement_artifacts(count: int, excluded: Array) -> Array[String]:
	var result: Array[String] = []
	for artifact_id in artifact_ids():
		if result.size() >= count:
			break
		if String(artifact_id) in excluded:
			continue
		result.append(String(artifact_id))
	return result
