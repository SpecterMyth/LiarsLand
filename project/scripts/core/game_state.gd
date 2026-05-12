extends RefCounted
class_name GameState

const PHASE_SELECT := "select"
const PHASE_DIALOGUE := "dialogue"
const PHASE_TRADE := "trade"
const PHASE_SHOP := "shop"
const PHASE_ASCENSION := "ascension"
const PHASE_ENDED := "ended"

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
var end_reason_id := ""
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
var council_mode := false
var council_members: Array = []
var council_factions: Array = []
var council_crime_pool: Array = []
var council_vote_records: Array = []
var council_vote_tendencies: Array = []
var council_death_wills: Array = []
var council_public_support: Dictionary = {}
var council_faction_public_crimes: Dictionary = {}
var council_executed_crimes: Array[String] = []
var council_contacted_member_ids: Array[String] = []
var council_execution_timeline: Array = []
var council_player_faction := ""
var council_chapter_results: Array = []
var council_total_chapters := 3
var council_energy_rewarded_chapters: Array[int] = []
var council_last_energy_rewards: Array = []


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
	end_reason_id = ""
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
	council_mode = bool(data.get("mode", "") == "council")
	council_members.clear()
	council_factions.clear()
	council_crime_pool.clear()
	council_vote_records.clear()
	council_vote_tendencies.clear()
	council_death_wills.clear()
	council_public_support.clear()
	council_faction_public_crimes.clear()
	council_executed_crimes.clear()
	council_contacted_member_ids.clear()
	council_execution_timeline.clear()
	_setup_actor(player)
	for i in range(npcs.size()):
		var npc: Dictionary = npcs[i]
		_setup_actor(npc)
		npcs[i] = npc
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
	end_reason_id = ""
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
	refresh_npc_choices()
	refresh_shop_items()
	remember_player("Entered chapter %d. Inventory, level, artifact history, and intel archive are preserved." % (chapter_index + 1))
	return true


func _setup_actor(actor: Dictionary) -> void:
	if not actor.has("background") and actor.has("scene"):
		actor["background"] = String(actor.get("scene", ""))
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
	var source_id := "%d:%s" % [chapter_index + 1, String(npc.get("id", npc.get("public_name", "opponent")))]
	for source in sources:
		if String(source.get("source_id", "")) == source_id:
			return false
	sources.append({
		"source_id": source_id,
		"npc_id": String(npc.get("id", "")),
		"npc_name": String(npc.get("public_name", "opponent")),
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
		if council_mode:
			var npc_id := String(npc.get("id", ""))
			if not npc_id.is_empty() and not npc_id in council_contacted_member_ids:
				council_contacted_member_ids.append(npc_id)
		var text := "Round %d: started dialogue with %s." % [chapter_round + 1, npc.get("public_name", "unknown opponent")]
		event_log.append(text)
		remember_player(text)
		remember_current_npc("Round %d: player initiated dialogue." % (chapter_round + 1))

func refresh_shop_items() -> void:
	shop_items = random_artifact_ids(3)
	phase = PHASE_SHOP


func add_dialogue(role: String, content: String) -> void:
	dialogue_history.append({"role": role, "content": content})
	full_dialogue_history.append({
		"round": chapter_round,
		"npc_index": current_npc_index,
		"npc_name": current_npc().get("public_name", "opponent"),
		"role": role,
		"content": content
	})
	var npc := current_npc()
	if npc.is_empty():
		return
	var speaker := "player" if role == "player" else String(npc.get("public_name", "opponent"))
	var listener := String(npc.get("public_name", "opponent")) if role == "player" else "player"
	remember_player("Round %d dialogue: %s to %s: %s" % [chapter_round + 1, speaker, listener, content])
	remember_current_npc("Round %d dialogue: %s to %s: %s" % [chapter_round + 1, speaker, listener, content])

func format_history() -> String:
	if dialogue_history.is_empty():
		return "No dialogue yet."
	var lines: Array[String] = []
	for item in dialogue_history:
		var role := "player" if item.get("role") == "player" else "opponent"
		lines.append("%s: %s" % [role, item.get("content", "")])
	return "\n".join(lines)

func format_full_history() -> String:
	if full_dialogue_history.is_empty():
		return "No dialogue history."
	var lines: Array[String] = []
	for item in full_dialogue_history:
		var role := "player" if item.get("role") == "player" else "opponent"
		lines.append("[Round %s %s] %s: %s" % [item.get("round", 0), item.get("npc_name", "opponent"), role, item.get("content", "")])
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
		"remaining_energy": maxi(0, max_player_chars - player_chars),
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
	var hidden := ["true_stance", "affinity", "friend_judgement", "intel", "identity_info", "join_threshold", "stats", "inventory", "artifact_history", "dominion_requirement", "ascension_requirement", "hidden_faction", "hidden_crimes"]
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
		result.append(String(item))
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


func npc_index_by_id(npc_id: String) -> int:
	for i in range(npcs.size()):
		if String(npcs[i].get("id", "")) == npc_id:
			return i
	return -1
