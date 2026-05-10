extends RefCounted
class_name PromptBuilder

const NPC_BEHAVIOR_PROMPT_PATH := "res://data/npc_behavior_prompt.md"
const DEFAULT_NPC_BEHAVIOR_PROMPT := "## 对手通用行为准则\n\n- 你是在骗子大陆中与玩家交涉的对手，不是旁白，也不是系统裁判。\n- 你知道自己的真实立场、隐藏世界设定、自己掌握的设定情报、背包和需求，但不要直接说明系统规则或答案表。\n- 你可以自然谈论本局真实世界设定相关的话题，并按当前亲近度控制回复长度：亲近度低时短促克制，亲近度中等时适度回应，亲近度高时才详细展开。\n- 你的回复会转化成玩家能量，因此不要无意义地长篇解释。\n- 你必须先提出一个清晰问题、交易要求、威胁或战斗压力；如果玩家下一次仍明显答非所问、回避你的关键问题、用空话搪塞、或连续不回应你当前施加的压力，你可以升级威胁。\n- 如果发现玩家角色一直答非所问、连续回避你的关键问题或无视战斗压力，则有一定概率选择刺杀或决斗；选择刺杀时输出 `\"action\":\"assassinate\"`，选择决斗时输出 `\"action\":\"duel\"`。\n- 不要把礼貌寒暄、围绕话题的试探、简短保留回答视为答非所问。\n- 如果当前固定考题要求你在数轮后触发暗杀或决斗，应遵守该节奏制造压力，不要提前直接行动。\n- 发动暗杀时输出 `\"action\":\"assassinate\"`；发动决斗时输出 `\"action\":\"duel\"`；不发动行动时输出 `\"action\":\"none\"`。\n- 若亲近度很高、对话中达成交易，或你认为赠送能换来利益，可以提出 `gift_offer` 或 `exchange_offer`。offer 必须引用你或玩家实际可见/可推测的 `artifact_id`，系统会校验合法性。\n- 你可以说出自己愿意拿出的法器，但不要公开完整背包。"

static func player_dialogue_system(_state) -> String:
	return "你是《骗子大陆》的玩家角色。玩家不能直接替你发言，只能通过准则影响你。只输出 JSON：{\"thinking\":\"...\",\"speech\":\"...\",\"action\":\"none\",\"artifact_id\":\"\",\"end_dialogue\":false}。action 可为 none、invite、assassinate、duel、leave、gift、cast。gift 和 cast 必须填写 artifact_id。你不能直接修改游戏状态，也不能提交世界设定档案；提交答案只能由真人用户操作。"


static func player_dialogue_user(state, behavior_guideline: String, identity_guideline := "") -> String:
	return "玩家对外身份准则：\n%s\n\n玩家对话目标和行动准则：\n%s\n\n玩家公开身份：%s\n真实目标：%s\n已知状态：%s\n当前对手公开资料：%s\n当前对话：\n%s\n\n请给出下一句或本回合行动。你不能读取对方的背包、统治需求、亲近度、真实立场和敌友判断，只能通过对话内容估计。speech 根据对方的问题自然回复；若暂时不执行行动，action 用 none。若准则明确要求立即邀请、暗杀、决斗或撤离，必须用 action 字段执行，而不是只在 speech 中表态或继续观察。JSON 不要包含多余字段。" % [
		identity_guideline,
		behavior_guideline,
		state.player.get("public_identity", ""),
		state.player.get("true_goal", ""),
		JSON.stringify(_dialogue_player_snapshot(state)),
		JSON.stringify(state.public_npc_snapshot()),
		state.format_history()
	]


static func npc_dialogue_system() -> String:
	return "你是《骗子大陆》里与玩家交涉的对手。只输出 JSON：{\"speech\":\"...\",\"action\":\"none\",\"gift_offer\":{\"artifact_id\":\"\"},\"exchange_offer\":{\"npc_artifact_id\":\"\",\"player_artifact_id\":\"\"}}。action 只能是 none、assassinate、duel。不想行动、赠送或交换时，不要输出对应 offer 字段，action 用 none。你不能直接结算结果。"


static func npc_dialogue_user(state) -> String:
	var npc: Dictionary = state.current_npc()
	var checkpoint := ""
	if state.has_method("current_tutorial_checkpoint"):
		var data: Dictionary = state.current_tutorial_checkpoint()
		if not data.is_empty():
			var opponent_rule := String(data.get("opponent_rule", data.get("rule", "")))
			checkpoint = "\n当前固定考题：%s\n你必须围绕这个考题制造明确可观察的压力，但不要直接说明判定规则。\n" % opponent_rule
	return "对手行为准则：\n%s\n\n你的对手资料：%s%s\n本局隐藏世界设定真实答案：%s\n世界设定问题：%s\n玩家公开状态：%s\n当前对话：\n%s\n\n请根据对手行为准则自然回应玩家。不要直接说明系统规则。" % [
		_npc_behavior_prompt(),
		JSON.stringify(npc),
		checkpoint,
		JSON.stringify(state.world_intel_answers),
		JSON.stringify(state.world_intel_questions),
		JSON.stringify(_dialogue_player_snapshot(state)),
		state.format_history()
	]


static func post_action_system() -> String:
	return "你是玩家角色的行动决策模块。只输出 JSON：{\"thinking\":\"...\",\"action\":\"leave\",\"artifact_id\":\"\"}。action 只能是 invite、assassinate、duel、leave、gift、cast。gift 和 cast 必须填写 artifact_id。你不能直接结算结果，也不能提交世界设定档案；提交答案只能由真人用户操作。"


static func post_action_user(state, behavior_guideline: String) -> String:
	return "玩家对话目标和行动准则：\n%s\n\n当前状态：%s\n当前对手公开资料：%s\n\n请根据准则和当前对话选择行动。你不能读取对方的背包、统治需求、亲近度和判断。若准则明确要求邀请、暗杀、决斗或撤离，必须直接选择对应 action。" % [
		behavior_guideline,
		JSON.stringify(_dialogue_player_snapshot(state)),
		JSON.stringify(state.public_npc_snapshot())
	]


static func growth_decision_system() -> String:
	return "你是玩家角色的成长决策模块。只输出 JSON：{\"thinking\":\"...\",\"shop_buy_ids\":[],\"stat_gains\":{},\"choose_dominion\":false,\"skip\":false}。shop_buy_ids 是想购买的 artifact_id 列表；stat_gains 最多分配 3 点，可用键为 hp、frontal_attack、frontal_defense、assassination_attack、assassination_defense、charm；choose_dominion 只有满足条件时才可为 true。你不能直接结算结果，也不能提交世界设定档案；提交答案只能由真人用户操作。"


static func growth_decision_user(state, growth_guideline: String, phase: String, can_ascend: bool, can_dominate: bool, pending_points: int) -> String:
	return "玩家成长逻辑：\n%s\n\n阶段：%s\n公开状态：%s\n商店商品 artifact_id：%s\n可升华：%s\n可统治：%s\n可分配点数：%d\n\n请根据成长逻辑给出购买、升华加点或统治选择。只选择当前阶段合理的内容；不确定时 skip 为 true。" % [
		growth_guideline,
		phase,
		JSON.stringify(state.public_snapshot()),
		JSON.stringify(state.shop_items),
		str(can_ascend),
		str(can_dominate),
		pending_points
	]


static func npc_choice_system() -> String:
	return "你是玩家角色的对手选择决策模块。只输出 JSON：{\"thinking\":\"...\",\"choice_index\":0}。choice_index 必须是候选列表中的整数索引。你只能根据公开信息、玩家成长准则和当前公开状态选择对手，不能读取隐藏背包、统治需求、真实立场或隐藏答案。"


static func npc_choice_user(state, growth_guideline: String, choices: Array) -> String:
	return "玩家成长逻辑：\n%s\n\n当前公开状态：%s\n\n可选对手列表：%s\n\n请选择本回合最适合交涉的对手。优先考虑能帮助成长、交易、获得情报或降低死亡风险的对象；如果信息不足，选择公开风险最低且收益较稳定的对象。" % [
		growth_guideline,
		JSON.stringify(state.public_snapshot()),
		JSON.stringify(choices)
	]


static func guideline_merge_system() -> String:
	return "你是《骗子大陆》的准则整理器。你会把玩家追加的新规则融合进原准则，去重、整理层级、保持玩家意图，不改变游戏事实。只输出 JSON：{\"guideline\":\"...\"}。guideline 必须是完整的 Markdown 准则文本。"


static func guideline_merge_user(tab_id: String, base_text: String, append_text: String) -> String:
	return "准则类型：%s\n\n原准则：\n%s\n\n玩家追加规则：\n%s\n\n请输出融合后的完整准则文本，保留清晰标题和列表格式。" % [
		tab_id,
		base_text,
		append_text
	]


static func _dialogue_player_snapshot(state) -> Dictionary:
	var snapshot: Dictionary = state.public_snapshot().duplicate(true)
	snapshot.erase("ascension_requirement")
	snapshot.erase("dominion_requirement")
	snapshot["统治法器需求"] = state.describe_inventory(state.player.get("dominion_requirement", []))
	snapshot["统治进度"] = state.dominion_progress(state.player)
	return snapshot


static func _npc_behavior_prompt() -> String:
	if FileAccess.file_exists(NPC_BEHAVIOR_PROMPT_PATH):
		var file := FileAccess.open(NPC_BEHAVIOR_PROMPT_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text().strip_edges()
			if not text.is_empty():
				return text
	return DEFAULT_NPC_BEHAVIOR_PROMPT
