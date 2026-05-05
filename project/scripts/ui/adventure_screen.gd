extends Control
class_name AdventureScreen

const CHAPTER_PATH := "res://data/chapter_01.json"
const DEFAULT_RULES := "## 角色基调\n冷静、谨慎、礼貌，不轻易暴露真实目的。\n\n## 对话策略\n优先提升好感度，试探对方如何理解本局世界的隐藏设定。需要统治法器时，可以谈交换、赠送、邀请、施法或撤离。\n\n## 行动策略\n风险不清时优先撤离。确认对方是敌人且收益足够时再暗杀或决斗。不要击杀友方 NPC。最终目标是活过三章并提交 6 条世界设定档案。"

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const RulesEngineScript := preload("res://scripts/core/rules_engine.gd")
const LlmClientScript := preload("res://scripts/llm/llm_client.gd")
const PromptBuilderScript := preload("res://scripts/llm/prompt_builder.gd")
const AdventureLayoutScript := preload("res://scripts/ui/adventure_layout.gd")

var config: Dictionary = {}
var state
var llm_client
var running := false
var streaming_section := ""
var streaming_speaker := ""
var streaming_color := Color.WHITE
var speech_stream_started := false
var streamed_speech := ""
var selected_npc_choice := -1
var trade_choice := 0
var shop_done := false
var selected_upgrade = ""
var pending_stat_points := 0

var background_texture: TextureRect
var status_label: Label
var progress_label: Label
var npc_label: Label
var player_label: Label
var current_speaker_label: Label
var npc_public_label: Label
var stats_label: Label
var rules_edit: TextEdit
var dialogue_title: Label
var result_banner: Label
var dialogue_view: RichTextLabel
var recent_view: RichTextLabel
var state_view: RichTextLabel
var card_grid: GridContainer
var pulse_overlay: ColorRect
var ambience: Control
var start_button: Button
var reset_button: Button
var history_button: Button
var info_button: Button
var bag_button: Button
var rules_button: Button
var status_button: Button
var settings_button: Button
var drawer: PanelContainer
var rules_panel: PanelContainer
var settings_panel: PanelContainer
var history_dialog: AcceptDialog
var history_view: RichTextLabel
var upgrade_panel: PanelContainer
var upgrade_label: Label
var upgrade_hint: Label
var upgrade_buttons: GridContainer
var continue_button: Button
var player_portrait: TextureRect
var npc_portrait: TextureRect
var selection_panel: PanelContainer
var selection_box: VBoxContainer
var trade_panel: PanelContainer
var trade_box: VBoxContainer
var shop_panel: PanelContainer
var shop_box: VBoxContainer
var upgrade_buttons_by_stat: Dictionary = {}
var highlighted_cards: Dictionary = {}
var drawer_mode := "intel"


func _ready() -> void:
	_build_ui()
	_setup_llm()
	_load_chapter()
	_reset_ui()
	get_viewport().size_changed.connect(_fit_full)


func _fit_full() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _setup_llm() -> void:
	llm_client = LlmClientScript.new()
	llm_client.config = config
	llm_client.log_message.connect(_append_system_log)
	llm_client.stream_field_delta.connect(_on_stream_field_delta)
	add_child(llm_client)


func _load_chapter() -> void:
	state = GameStateScript.new()
	var data := ChapterLoaderScript.load_chapter(CHAPTER_PATH)
	state.load_chapter(data)


func _build_ui() -> void:
	var controls: Dictionary = AdventureLayoutScript.new().build(self, DEFAULT_RULES)
	background_texture = controls.get("background_texture")
	status_label = controls.get("status_label")
	progress_label = controls.get("progress_label")
	npc_label = controls.get("npc_label")
	player_label = controls.get("player_label")
	current_speaker_label = controls.get("current_speaker_label")
	recent_view = controls.get("recent_view")
	npc_public_label = controls.get("npc_public_label")
	stats_label = controls.get("stats_label")
	rules_edit = controls.get("rules_edit")
	dialogue_title = controls.get("dialogue_title")
	result_banner = controls.get("result_banner")
	dialogue_view = controls.get("dialogue_view")
	state_view = controls.get("state_view")
	card_grid = controls.get("card_grid")
	pulse_overlay = controls.get("pulse_overlay")
	ambience = controls.get("ambience")
	start_button = controls.get("start_button")
	reset_button = controls.get("reset_button")
	history_button = controls.get("history_button")
	info_button = controls.get("info_button")
	bag_button = controls.get("bag_button")
	rules_button = controls.get("rules_button")
	status_button = controls.get("status_button")
	settings_button = controls.get("settings_button")
	drawer = controls.get("drawer")
	rules_panel = controls.get("rules_panel")
	settings_panel = controls.get("settings_panel")
	history_dialog = controls.get("history_dialog")
	history_view = controls.get("history_view")
	upgrade_panel = controls.get("upgrade_panel")
	upgrade_label = controls.get("upgrade_label")
	upgrade_hint = controls.get("upgrade_hint")
	upgrade_buttons = controls.get("upgrade_buttons")
	continue_button = controls.get("continue_button")
	player_portrait = controls.get("player_portrait")
	npc_portrait = controls.get("npc_portrait")
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	history_button.pressed.connect(_show_history)
	info_button.pressed.connect(func(): _show_drawer("intel"))
	bag_button.pressed.connect(func(): _show_drawer("bag"))
	rules_button.pressed.connect(_toggle_rules)
	status_button.pressed.connect(func(): _show_drawer("status"))
	settings_button.pressed.connect(_toggle_settings)
	continue_button.pressed.connect(_on_continue_pressed)
	_build_upgrade_buttons()
	_build_selection_panel()
	_build_trade_panel()
	_build_shop_panel()
	_wire_button_feedback([start_button, reset_button, history_button, info_button, bag_button, rules_button, status_button, settings_button, continue_button])
	_start_ambience()


func _build_selection_panel() -> void:
	selection_panel = _make_overlay_panel(Vector2(620, 310))
	selection_panel.visible = false
	add_child(selection_panel)
	selection_box = VBoxContainer.new()
	selection_box.add_theme_constant_override("separation", 10)
	selection_panel.add_child(selection_box)


func _build_shop_panel() -> void:
	shop_panel = _make_overlay_panel(Vector2(680, 360))
	shop_panel.visible = false
	add_child(shop_panel)
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 10)
	shop_panel.add_child(shop_box)


func _build_trade_panel() -> void:
	trade_panel = _make_overlay_panel(Vector2(620, 260))
	trade_panel.visible = false
	add_child(trade_panel)
	trade_box = VBoxContainer.new()
	trade_box.add_theme_constant_override("separation", 10)
	trade_panel.add_child(trade_box)


func _make_overlay_panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = size
	panel.offset_left = -size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_bottom = size.y / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.038, 0.034, 0.96)
	style.border_color = Color(0.95, 0.64, 0.25, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _reset_ui() -> void:
	running = false
	selected_upgrade = ""
	pending_stat_points = 0
	selected_npc_choice = -1
	shop_done = false
	start_button.disabled = false
	rules_edit.editable = true
	upgrade_panel.visible = false
	selection_panel.visible = false
	trade_panel.visible = false
	shop_panel.visible = false
	result_banner.visible = false
	if settings_panel != null:
		settings_panel.visible = true
	if recent_view != null:
		recent_view.clear()
	highlighted_cards.clear()
	dialogue_title.text = "对话"
	dialogue_view.clear()
	state_view.clear()
	status_label.text = "%s：等待开始" % state.chapter.get("title", "骗子大陆")
	npc_label.text = "等待选择"
	player_label.text = _player_short_name()
	if current_speaker_label != null:
		current_speaker_label.text = "等待"
	npc_public_label.text = "开始后从 3 名 NPC 中选择对话对象。"
	_show_scene_message("调整行为文件后点击“开始”。你方角色会自动交涉，玩家负责选择 NPC、购买法器和升华。")
	_update_state_panel()


func _on_start_pressed() -> void:
	_load_chapter()
	state.active = true
	running = true
	start_button.disabled = true
	if settings_panel != null:
		settings_panel.visible = false
	rules_edit.editable = false
	_show_scene_message("章节开始。")
	_update_state_panel()
	await _run_chapter()


func _on_reset_pressed() -> void:
	_load_chapter()
	_reset_ui()


func _run_chapter() -> void:
	while state.active and not state.ended and running:
		state.refresh_npc_choices()
		await _choose_npc_ui()
		if state.ended or not running:
			break
		await _run_current_dialogue()
		if state.ended or not running:
			break
		state.refresh_shop_items()
		await _run_shop_ui()
		if state.ended or not running:
			break
		await _offer_ascension_or_dominion()
		if state.ended or not running:
			break
		for event in RulesEngineScript.finish_round(state):
			_append_system_log(event)
			_mark_event_cards(event)
		_update_state_panel()
	_update_after_end()


func _choose_npc_ui() -> void:
	selected_npc_choice = -1
	selection_panel.visible = true
	_clear_children(selection_box)
	_add_panel_label(selection_box, "选择本回合对话对象")
	for i in range(state.npc_choices.size()):
		var npc: Dictionary = state.npcs[state.npc_choices[i]]
		var button := Button.new()
		button.text = "%s｜%s｜好感未知｜背包不可见" % [npc.get("public_name", "NPC"), npc.get("territory", "未知")]
		button.custom_minimum_size = Vector2(0, 46)
		button.pressed.connect(func(index := i): selected_npc_choice = index)
		selection_box.add_child(button)
		_wire_button_feedback([button])
	status_label.text = "第 %d / %d 回合：选择 NPC" % [state.chapter_round + 1, state.max_rounds]
	_update_progress()
	while selected_npc_choice < 0 and running and not state.ended:
		await get_tree().process_frame
	selection_panel.visible = false
	if selected_npc_choice >= 0:
		state.choose_npc(selected_npc_choice)
		_set_current_npc_assets()
	_show_scene_message("你选择与 %s 对话。" % state.current_npc().get("public_name", "NPC"))


func _run_current_dialogue() -> void:
	for i in range(state.max_dialogue_turns):
		if state.ended:
			return
		state.turn += 1
		status_label.text = "第 %d 回合：你方思考中" % (state.chapter_round + 1)
		_update_progress()
		_set_active_speaker("player")
		var player_response := await _get_player_dialogue()
		if player_response.has("error"):
			_show_error(player_response.get("error", ""))
			return
		var speech := String(player_response.get("speech", "我想先听听你的看法。")).strip_edges()
		var raw_action := String(player_response.get("action", "none")).strip_edges().to_lower()
		state.add_dialogue("player", speech)
		await _finish_speech_stream("你方", speech, Color(0.58, 0.82, 1.0, 1.0))
		if raw_action != "" and raw_action != "none":
			await _resolve_action(raw_action, {"artifact_id": String(player_response.get("artifact_id", ""))}, "即时行动")
			return
		status_label.text = "第 %d 回合：NPC 思考中" % (state.chapter_round + 1)
		_set_active_speaker("npc")
		var npc_response := await _get_npc_dialogue()
		if npc_response.has("error"):
			_show_error(npc_response.get("error", ""))
			return
		var npc_speech := String(npc_response.get("speech", "你的话让我有些兴趣。")).strip_edges()
		state.add_dialogue("npc", npc_speech)
		await _finish_speech_stream("NPC", npc_speech, Color(1.0, 0.61, 0.48, 1.0))
		var accepted_response := await _confirm_npc_offer(npc_response)
		for event in RulesEngineScript.apply_dialogue_turn(state, speech, npc_speech, accepted_response):
			_append_system_log(event)
			_mark_event_cards(event)
		_update_state_panel()
		if bool(player_response.get("end_dialogue", false)):
			break
		await get_tree().create_timer(0.2).timeout
	if not state.ended:
		var response := await _get_post_action()
		await _resolve_action(String(response.get("action", "leave")), {"artifact_id": String(response.get("artifact_id", ""))}, "对话结束行动")


func _resolve_action(action: String, payload: Dictionary, label: String) -> void:
	for event in RulesEngineScript.resolve_player_action(state, action, payload):
		_append_system_log(event)
		_mark_event_cards(event)
	_show_result_banner("%s：%s" % [label, _action_name(action)], _action_color(action))
	_update_state_panel()
	await get_tree().create_timer(0.35).timeout


func _run_shop_ui() -> void:
	shop_done = false
	shop_panel.visible = true
	_render_shop()
	status_label.text = "第 %d 回合：商店" % (state.chapter_round + 1)
	while not shop_done and running and not state.ended:
		await get_tree().process_frame
	shop_panel.visible = false


func _confirm_npc_offer(npc_response: Dictionary) -> Dictionary:
	if not npc_response.has("gift_offer") and not npc_response.has("exchange_offer"):
		return npc_response
	trade_choice = 0
	trade_panel.visible = true
	_clear_children(trade_box)
	_add_panel_label(trade_box, "NPC 提出法器交易")
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", Color(0.92, 0.98, 0.94, 1.0))
	if npc_response.has("gift_offer"):
		var offer: Dictionary = npc_response.get("gift_offer", {})
		detail.text = "%s 愿意赠送：%s" % [state.current_npc().get("public_name", "NPC"), state.artifact_name(String(offer.get("artifact_id", "")))]
	else:
		var offer: Dictionary = npc_response.get("exchange_offer", {})
		detail.text = "%s 想用 %s 交换你的 %s" % [
			state.current_npc().get("public_name", "NPC"),
			state.artifact_name(String(offer.get("npc_artifact_id", ""))),
			state.artifact_name(String(offer.get("player_artifact_id", "")))
		]
	trade_box.add_child(detail)
	var accept := Button.new()
	accept.text = "接受"
	accept.custom_minimum_size = Vector2(0, 42)
	accept.pressed.connect(func(): trade_choice = 1)
	trade_box.add_child(accept)
	var reject := Button.new()
	reject.text = "拒绝"
	reject.custom_minimum_size = Vector2(0, 42)
	reject.pressed.connect(func(): trade_choice = -1)
	trade_box.add_child(reject)
	_wire_button_feedback([accept, reject])
	while trade_choice == 0 and running and not state.ended:
		await get_tree().process_frame
	trade_panel.visible = false
	if trade_choice == 1:
		return npc_response
	var cleaned := npc_response.duplicate(true)
	cleaned.erase("gift_offer")
	cleaned.erase("exchange_offer")
	_append_system_log("玩家拒绝了 NPC 的法器提议。")
	return cleaned


func _render_shop() -> void:
	_clear_children(shop_box)
	_add_panel_label(shop_box, "本回合法器商店")
	var energy_label := Label.new()
	energy_label.text = "能量：%d" % int(state.player.get("energy", 0))
	energy_label.add_theme_font_size_override("font_size", 17)
	energy_label.add_theme_color_override("font_color", Color(0.78, 0.94, 0.86, 1.0))
	shop_box.add_child(energy_label)
	for artifact_id in state.shop_items:
		var artifact: Dictionary = state.get_artifact(String(artifact_id))
		var button := Button.new()
		button.text = "%s｜价格 %d｜%s" % [artifact.get("name", artifact_id), int(artifact.get("price", 0)), artifact.get("story", "")]
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(func(id := String(artifact_id)):
			for event in RulesEngineScript.buy_player_artifact(state, id):
				_append_system_log(event)
			_update_state_panel()
			_render_shop()
		)
		shop_box.add_child(button)
		_wire_button_feedback([button])
	var done := Button.new()
	done.text = "结束商店"
	done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(func(): shop_done = true)
	shop_box.add_child(done)
	_wire_button_feedback([done])


func _offer_ascension_or_dominion() -> void:
	if state.dominion_met(state.player) and not state.chapter_dominion_completed:
		return
	if not state.ascension_met(state.player):
		return
	selected_upgrade = ""
	pending_stat_points = 3
	continue_button.disabled = true
	upgrade_panel.visible = true
	upgrade_label.text = "满足升华条件：分配 3 个属性点"
	_update_upgrade_buttons()
	while pending_stat_points > 0 and running and not state.ended:
		await get_tree().process_frame
	var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
	for event in RulesEngineScript.ascend_player(state, gains):
		_append_system_log(event)
	continue_button.disabled = false
	await continue_button.pressed
	upgrade_panel.visible = false
	_update_state_panel()


func _build_upgrade_buttons() -> void:
	var upgrades := [
		["hp", "生命"],
		["frontal_attack", "正面攻击"],
		["frontal_defense", "正面防御"],
		["assassination_attack", "暗杀攻击"],
		["assassination_defense", "暗杀防御"],
		["charm", "魅力"]
	]
	for item in upgrades:
		var button := Button.new()
		button.text = item[1]
		button.custom_minimum_size = Vector2(210, 42)
		button.pressed.connect(func(stat := String(item[0])): _select_upgrade(stat))
		upgrade_buttons.add_child(button)
		upgrade_buttons_by_stat[item[0]] = button
		_wire_button_feedback([button])


func _select_upgrade(stat: String) -> void:
	if pending_stat_points <= 0:
		return
	var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
	gains[stat] = int(gains.get(stat, 0)) + 1
	selected_upgrade = gains
	pending_stat_points -= 1
	_update_upgrade_buttons()


func _on_continue_pressed() -> void:
	upgrade_panel.visible = false


func _get_player_dialogue() -> Dictionary:
	dialogue_title.text = "思考中"
	dialogue_view.clear()
	_prepare_llm_stream("player_llm", "你方", Color(0.58, 0.82, 1.0, 1.0))
	if llm_client.use_mock_llm():
		var npc: Dictionary = state.current_npc()
		var mock := {
			"thinking": "我会先试探对方法器与立场，不急着动手。",
			"speech": "听说%s附近有些法器换手很快。若我们各有所需，也许能谈一笔交换。" % npc.get("territory", "这里"),
			"action": "none",
			"artifact_id": "",
			"end_dialogue": state.turn >= state.max_dialogue_turns
		}
		await llm_client.chat_json("player_llm", "", "", mock, true)
		streaming_section = ""
		return mock
	var fallback := {"thinking": "先谨慎试探。", "speech": "我想先听听你怎么看最近的传闻。", "action": "none", "artifact_id": "", "end_dialogue": false}
	var result: Dictionary = await llm_client.chat_json(
		"player_llm",
		PromptBuilderScript.player_dialogue_system(state),
		PromptBuilderScript.player_dialogue_user(state, rules_edit.text),
		fallback,
		true
	)
	streaming_section = ""
	return result


func _get_npc_dialogue() -> Dictionary:
	_prepare_llm_stream("npc_llm", "NPC", Color(1.0, 0.61, 0.48, 1.0), false)
	if llm_client.use_mock_llm():
		var npc: Dictionary = state.current_npc()
		var response := {"speech": "你问得很巧。若你懂%s，就该知道礼物和代价常常是一回事。" % npc.get("liked_topics", ["规矩"])[0]}
		if int(npc.get("affinity", 0)) >= 6 and not npc.get("inventory", []).is_empty():
			response["gift_offer"] = {"artifact_id": String(npc.get("inventory", [])[0]), "affinity_required": 6}
		await llm_client.chat_json("npc_llm", "", "", response, true)
		streaming_section = ""
		return response
	var fallback := {"speech": "你的话让我有点兴趣，但我还需要更多诚意。"}
	var result: Dictionary = await llm_client.chat_json(
		"npc_llm",
		PromptBuilderScript.npc_dialogue_system(),
		PromptBuilderScript.npc_dialogue_user(state),
		fallback,
		true
	)
	streaming_section = ""
	return result


func _get_post_action() -> Dictionary:
	dialogue_title.text = "行动决策中"
	dialogue_view.clear()
	_prepare_llm_stream("player_llm", "", Color.WHITE)
	if llm_client.use_mock_llm():
		var mock := {"thinking": "风险不清，先撤离进入商店。", "action": "leave", "artifact_id": ""}
		await llm_client.chat_json("player_llm", "", "", mock, true)
		streaming_section = ""
		return mock
	var fallback := {"thinking": "风险不清，优先离开。", "action": "leave", "artifact_id": ""}
	var result: Dictionary = await llm_client.chat_json(
		"player_llm",
		PromptBuilderScript.post_action_system(),
		PromptBuilderScript.post_action_user(state, rules_edit.text),
		fallback,
		true
	)
	streaming_section = ""
	return result


func _set_current_npc_assets() -> void:
	var npc: Dictionary = state.current_npc()
	if npc.is_empty():
		return
	npc_label.text = String(npc.get("public_name", ""))
	if current_speaker_label != null:
		current_speaker_label.text = String(npc.get("public_name", "NPC"))
	npc_public_label.text = "公开资料：%s\n地盘：%s\n偏好话题：%s\n背包与需求：不可见" % [
		String(npc.get("public_identity", "未知身份")),
		String(npc.get("territory", "未知")),
		"、".join(npc.get("liked_topics", []))
	]
	_update_progress()


func _update_state_panel() -> void:
	if state == null:
		return
	if player_label != null:
		player_label.text = _player_short_name()
	var stats: Dictionary = state.player.get("stats", {})
	stats_label.text = "章节：%d / %d\n回合：%d / %d\n字符：%d / %d\n能量：%d\n等级：%d\n统治：%s\n背包：%s\n升华需求：%s\n生命：%d  魅力：%d\n正面：%d/%d  暗杀：%d/%d" % [
		state.chapter_index + 1,
		state.max_chapters,
		state.chapter_round + 1,
		state.max_rounds,
		state.player_chars,
		state.max_player_chars,
		int(state.player.get("energy", 0)),
		int(state.player.get("level", 1)),
		state.dominion_progress(state.player),
		"、".join(state.describe_inventory(state.player.get("inventory", []))),
		"、".join(state.describe_inventory(state.player.get("ascension_requirement", []))),
		int(stats.get("hp", 0)),
		int(stats.get("charm", 0)),
		int(stats.get("frontal_attack", 0)),
		int(stats.get("frontal_defense", 0)),
		int(stats.get("assassination_attack", 0)),
		int(stats.get("assassination_defense", 0))
	]
	state_view.clear()
	state_view.append_text("[b]统治需求[/b]\n")
	for artifact_id in state.player.get("dominion_requirement", []):
		var mark := "已获" if String(artifact_id) in state.player.get("artifact_history", []) else "未获"
		state_view.append_text("- %s [%s]\n" % [state.artifact_name(String(artifact_id)), mark])
	state_view.append_text("\n[b]近期记忆[/b]\n")
	for item in state.recent_memory(state.player, 8):
		state_view.append_text("- %s\n" % _escape(String(item)))
	state_view.append_text("\n[b]情报卡[/b]\n")
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		var selected := String(state.selected_world_intel.get(question_id, "未选择"))
		state_view.append_text("- %s：%s\n" % [question.get("title", question_id), state.world_intel_option_title(question_id, selected) if selected != "未选择" else selected])
	if state.ended:
		state_view.append_text("\n[b]结算[/b]\n%s\n" % state.end_reason)
	_update_card_grid()
	_update_progress()


func _on_stream_delta(section: String, delta: String) -> void:
	if section == streaming_section:
		dialogue_view.append_text(_escape(delta))


func _on_stream_field_delta(section: String, field_name: String, delta: String) -> void:
	if section != streaming_section:
		return
	if field_name == "speech":
		if not speech_stream_started:
			_begin_speech_stream()
		dialogue_view.append_text(_escape(delta))
		streamed_speech += delta
	elif field_name == "thinking" and not speech_stream_started:
		dialogue_view.append_text(_escape(delta))


func _prepare_llm_stream(section: String, speaker: String, color: Color, clear_for_thinking := true) -> void:
	streaming_section = section
	streaming_speaker = speaker
	streaming_color = color
	speech_stream_started = false
	streamed_speech = ""
	if clear_for_thinking:
		dialogue_view.clear()


func _begin_speech_stream() -> void:
	speech_stream_started = true
	dialogue_title.text = "对话"
	result_banner.visible = false
	dialogue_view.clear()
	if not streaming_speaker.is_empty():
		dialogue_view.append_text("[b][color=#%s]%s[/color][/b]\n" % [streaming_color.to_html(false), streaming_speaker])
	_pop_control(dialogue_view)


func _finish_speech_stream(speaker: String, speech: String, color: Color) -> void:
	if not speech_stream_started:
		await _show_speech_stream(speaker, speech, color)
		_append_recent_dialogue(speaker, speech)
		return
	if speech.length() > streamed_speech.length() and speech.begins_with(streamed_speech):
		dialogue_view.append_text(_escape(speech.substr(streamed_speech.length())))
	elif streamed_speech.strip_edges() != speech.strip_edges():
		await _show_speech_stream(speaker, speech, color)
	_append_recent_dialogue(speaker, speech)
	await get_tree().process_frame


func _show_speech_stream(speaker: String, speech: String, color: Color) -> void:
	dialogue_title.text = "对话"
	result_banner.visible = false
	dialogue_view.clear()
	dialogue_view.append_text("[b][color=#%s]%s[/color][/b]\n" % [color.to_html(false), speaker])
	_pop_control(dialogue_view)
	for i in range(0, speech.length(), 3):
		dialogue_view.append_text(_escape(speech.substr(i, 3)))
		await get_tree().create_timer(0.02).timeout


func _show_scene_message(text: String) -> void:
	dialogue_title.text = "对话"
	dialogue_view.clear()
	dialogue_view.append_text("[color=#f3d28b]%s[/color]" % _escape(text))


func _show_error(text: String) -> void:
	dialogue_title.text = "LLM 调用错误"
	result_banner.visible = false
	dialogue_view.clear()
	dialogue_view.append_text("[color=#ff7a7a]%s[/color]" % _escape(text))
	running = false


func _append_system_log(message: String) -> void:
	dialogue_view.append_text("\n[color=#f3d28b]%s[/color]" % _escape(message))
	if recent_view != null:
		recent_view.append_text("[color=#6b160b]系统：%s[/color]\n" % _escape(message))
	state.event_log.append(message)
	_flash(Color(1.0, 0.42, 0.30, 0.12))


func _set_active_speaker(role: String) -> void:
	if current_speaker_label != null:
		if role == "player":
			current_speaker_label.text = _player_short_name()
		else:
			current_speaker_label.text = String(state.current_npc().get("public_name", "NPC")) if state != null and state.has_method("current_npc") else "NPC"
	player_portrait.modulate = Color(1, 1, 1, 1) if role == "player" else Color(0.42, 0.42, 0.42, 0.82)
	npc_portrait.modulate = Color(1, 1, 1, 1) if role == "npc" else Color(0.42, 0.42, 0.42, 0.82)
	_shake_portrait(player_portrait if role == "player" else npc_portrait)


func _show_history() -> void:
	history_view.clear()
	history_view.append_text("[b]对话历史[/b]\n")
	history_view.append_text(_escape(state.format_full_history()))
	if not state.event_log.is_empty():
		history_view.append_text("\n\n[b]行动与发现[/b]\n")
		for item in state.event_log:
			history_view.append_text("- %s\n" % _escape(String(item)))
	history_dialog.popup_centered()


func _show_drawer(mode: String) -> void:
	drawer_mode = mode
	drawer.visible = true
	rules_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	var title := drawer.get_meta("title_label") as Label
	if title != null:
		match drawer_mode:
			"bag":
				title.text = "背包"
			"status":
				title.text = "状态"
			_:
				title.text = "情报"
	_update_state_panel()
	_slide_in(drawer)


func _toggle_rules() -> void:
	rules_panel.visible = not rules_panel.visible
	if rules_panel.visible:
		drawer.visible = false
		if settings_panel != null:
			settings_panel.visible = false
		_slide_in(rules_panel)


func _toggle_settings() -> void:
	if settings_panel == null:
		return
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible:
		drawer.visible = false
		rules_panel.visible = false
		_slide_in(settings_panel)


func _update_card_grid() -> void:
	if card_grid == null:
		return
	_clear_children(card_grid)
	stats_label.visible = drawer_mode == "status"
	match drawer_mode:
		"bag":
			_add_section_label("统治需求")
			for artifact_id in state.player.get("dominion_requirement", []):
				var known: bool = String(artifact_id) in state.player.get("artifact_history", [])
				_add_info_card(String(artifact_id), state.artifact_name(String(artifact_id)), "已获得" if known else "未获得", "统治需求法器", true, false, known)
			_add_section_label("背包")
			for artifact_id in state.player.get("inventory", []):
				var artifact: Dictionary = state.get_artifact(String(artifact_id))
				_add_info_card(String(artifact_id), String(artifact.get("name", artifact_id)), "持有中", String(artifact.get("story", "")), true, false, false)
			_add_section_label("升华需求")
			for artifact_id in state.player.get("ascension_requirement", []):
				_add_info_card(String(artifact_id), state.artifact_name(String(artifact_id)), "需求", "升华消耗法器", true, false, false)
		"status":
			_add_section_label("当前状态")
			_add_info_card("round", "章节 / 回合", "%d / %d 章" % [state.chapter_index + 1, state.max_chapters], "回合 %d / %d，对话 %d / %d" % [state.chapter_round + 1, state.max_rounds, state.turn, state.max_dialogue_turns], true, false, false)
			_add_info_card("budget", "字符与能量", "%d / %d" % [state.player_chars, state.max_player_chars], "能量：%d  等级：%d" % [int(state.player.get("energy", 0)), int(state.player.get("level", 1))], true, false, false)
			var npc: Dictionary = state.current_npc()
			if not npc.is_empty():
				_add_info_card("npc", String(npc.get("public_name", "NPC")), String(npc.get("friend_judgement", "unknown")), "亲近度：%d  地盘：%s" % [int(npc.get("affinity", 0)), String(npc.get("territory", "未知"))], true, false, false)
		_:
			_add_section_label("当前 NPC")
			if state != null and not state.current_npc().is_empty():
				var npc: Dictionary = state.current_npc()
				_add_info_card("npc_public", String(npc.get("public_name", "NPC")), String(npc.get("territory", "未知")), String(npc.get("public_identity", "未知身份")), true, false, false)
			_add_section_label("世界设定档案")
			for question in state.world_intel_questions:
				_add_world_intel_question(question)
			_add_submit_world_intel_button()


func _add_panel_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45, 1.0))
	parent.add_child(label)


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45, 1.0))
	card_grid.add_child(label)


func _add_world_intel_question(question: Dictionary) -> void:
	var question_id := String(question.get("id", ""))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 270)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/generated/ui/dialogue/scroll_panel_9.png")
	style.texture_margin_left = 28
	style.texture_margin_right = 28
	style.texture_margin_top = 24
	style.texture_margin_bottom = 24
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	card_grid.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = String(question.get("title", question_id))
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	for option in question.get("options", []):
		_add_world_intel_option(box, question_id, option)


func _add_world_intel_option(parent: VBoxContainer, question_id: String, option: Dictionary) -> void:
	var option_id := String(option.get("id", ""))
	var selected := String(state.selected_world_intel.get(question_id, "")) == option_id
	var button := Button.new()
	button.flat = false
	button.custom_minimum_size = Vector2(0, 62)
	button.text = ""
	button.pressed.connect(func():
		state.select_world_intel_answer(question_id, option_id)
		_update_state_panel()
	)
	parent.add_child(button)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 6
	row.offset_right = -8
	row.offset_bottom = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	button.add_child(row)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(50, 50)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_set_texture_or_fallback(image, "res://assets/generated/%s" % String(option.get("image", "card_clue_back.png")), "res://assets/generated/card_clue_back.png")
	row.add_child(image)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)
	var title := Label.new()
	title.text = ("%s  " % ("已选" if selected else "")) + String(option.get("title", option_id))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.86, 1.0) if selected else Color(1.0, 0.91, 0.74, 1.0))
	title.clip_text = true
	text_box.add_child(title)
	var sources := _world_intel_sources(question_id, option_id)
	var source_label := Label.new()
	source_label.text = "证词：%s" % ("暂无" if sources.is_empty() else "、".join(sources))
	source_label.add_theme_font_size_override("font_size", 12)
	source_label.add_theme_color_override("font_color", Color(0.84, 0.80, 0.68, 1.0))
	source_label.clip_text = true
	text_box.add_child(source_label)
	var portraits := HBoxContainer.new()
	portraits.add_theme_constant_override("separation", -8)
	row.add_child(portraits)
	for source in state.intel_testimonies.get(question_id, {}).get(option_id, []):
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(34, 34)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.tooltip_text = "第 %d 章 %s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "NPC"))]
		_set_texture_or_fallback(portrait, "res://assets/generated/%s" % String(source.get("portrait", "")), "res://assets/generated/opponent_portrait.png")
		portraits.add_child(portrait)


func _world_intel_sources(question_id: String, option_id: String) -> Array[String]:
	var result: Array[String] = []
	for source in state.intel_testimonies.get(question_id, {}).get(option_id, []):
		result.append("第%d章%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "NPC"))])
	return result


func _add_submit_world_intel_button() -> void:
	var button := Button.new()
	button.text = "提交世界设定档案"
	button.custom_minimum_size = Vector2(0, 48)
	button.disabled = state.intel_submitted
	button.pressed.connect(_confirm_submit_world_intel)
	card_grid.add_child(button)
	_wire_button_feedback([button])


func _confirm_submit_world_intel() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "提交世界设定档案"
	dialog.dialog_text = "提交后无法修改。6 条设定全部正确才会胜利，任意错误都会失败。"
	add_child(dialog)
	dialog.confirmed.connect(func():
		for event in RulesEngineScript.submit_world_intel(state, state.selected_world_intel.duplicate(true)):
			_append_system_log(event)
		_update_state_panel()
		_update_after_end()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()


func _add_info_card(card_id: String, title: String, subtitle: String, detail: String, revealed: bool, danger: bool, fresh: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 112)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/generated/ui/dialogue/scroll_panel_9.png")
	style.texture_margin_left = 28
	style.texture_margin_right = 28
	style.texture_margin_top = 24
	style.texture_margin_bottom = 24
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	card_grid.add_child(panel)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 3)
	panel.add_child(text_box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	title_label.clip_text = true
	text_box.add_child(title_label)
	var sub_label := Label.new()
	sub_label.text = subtitle
	sub_label.add_theme_font_size_override("font_size", 15)
	sub_label.add_theme_color_override("font_color", Color(0.74, 0.98, 0.90, 1.0) if revealed else Color(0.68, 0.64, 0.58, 1.0))
	text_box.add_child(sub_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78, 1.0))
	text_box.add_child(detail_label)


func _wire_button_feedback(buttons: Array) -> void:
	for button in buttons:
		if button == null:
			continue
		button.mouse_entered.connect(func(): _hover_control(button))
		button.pressed.connect(func(): _press_control(button))


func _hover_control(node: Control) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.035, 1.035), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)


func _press_control(node: Control) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(0.94, 0.94), 0.05)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	_flash(Color(1.0, 0.76, 0.36, 0.08))


func _pop_control(node: Control) -> void:
	node.scale = Vector2(0.98, 0.98)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.015, 1.015), 0.10).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2.ONE, 0.10)


func _slide_in(node: Control) -> void:
	var original := node.position
	node.modulate.a = 0.0
	node.position = original + Vector2(24, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position", original, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.18)


func _shake_portrait(node: TextureRect) -> void:
	var original := node.position
	var tween := create_tween()
	tween.tween_property(node, "position", original + Vector2(8, -3), 0.045)
	tween.tween_property(node, "position", original + Vector2(-6, 2), 0.055)
	tween.tween_property(node, "position", original, 0.07).set_trans(Tween.TRANS_BACK)


func _flash(color: Color) -> void:
	if pulse_overlay == null:
		return
	pulse_overlay.color = color
	var end_color := color
	end_color.a = 0.0
	var tween := create_tween()
	tween.tween_property(pulse_overlay, "color", end_color, 0.28)


func _start_ambience() -> void:
	if ambience == null:
		return
	for child in ambience.get_children():
		var mote := child as Control
		if mote == null:
			continue
		_float_mote(mote)


func _float_mote(mote: Control) -> void:
	var start := mote.position
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(mote, "position", start + Vector2(0, -18), 1.8 + randf() * 1.2)
	tween.tween_property(mote, "position", start, 1.8 + randf() * 1.2)


func _set_texture(node: TextureRect, path: String) -> void:
	if ResourceLoader.exists(path):
		node.texture = load(path)


func _set_texture_or_fallback(node: TextureRect, path: String, fallback: String) -> void:
	if ResourceLoader.exists(path):
		node.texture = load(path)
	elif ResourceLoader.exists(fallback):
		node.texture = load(fallback)


func _show_result_banner(text: String, color: Color) -> void:
	result_banner.visible = true
	result_banner.text = text
	result_banner.modulate = color
	_pop_control(result_banner)


func _action_color(action: String) -> Color:
	match RulesEngineScript.normalize_action(action):
		"invite":
			return Color(0.62, 1.0, 0.78, 1.0)
		"assassinate", "cast":
			return Color(1.0, 0.36, 0.32, 1.0)
		"duel":
			return Color(1.0, 0.70, 0.36, 1.0)
		"gift":
			return Color(0.78, 0.66, 1.0, 1.0)
		_:
			return Color(0.82, 0.90, 1.0, 1.0)


func _action_name(action: String) -> String:
	match RulesEngineScript.normalize_action(action):
		"invite":
			return "邀请"
		"assassinate":
			return "暗杀"
		"duel":
			return "决斗"
		"gift":
			return "赠送"
		"cast":
			return "施法"
		_:
			return "撤离"


func _update_progress() -> void:
	if progress_label == null or state == null:
		return
	progress_label.text = "第 %d / %d 章  回合 %d / %d  对话 %d / %d" % [state.chapter_index + 1, state.max_chapters, min(state.chapter_round + 1, state.max_rounds), state.max_rounds, state.turn, state.max_dialogue_turns]


func _update_upgrade_buttons() -> void:
	var stats: Dictionary = state.player.get("stats", {})
	var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
	for stat in upgrade_buttons_by_stat.keys():
		var button: Button = upgrade_buttons_by_stat[stat]
		var value := int(stats.get(stat, 0))
		button.text = "%s %d -> %d" % [_stat_name(stat), value, value + int(gains.get(stat, 0))]
		button.disabled = pending_stat_points <= 0
	if upgrade_hint != null:
		upgrade_hint.text = "剩余属性点：%d" % pending_stat_points


func _stat_name(stat: String) -> String:
	match stat:
		"hp":
			return "生命"
		"frontal_attack":
			return "正面攻击"
		"frontal_defense":
			return "正面防御"
		"assassination_attack":
			return "暗杀攻击"
		"assassination_defense":
			return "暗杀防御"
		"charm":
			return "魅力"
		_:
			return stat


func _mark_event_cards(event: String) -> void:
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		if event.contains(String(question.get("title", ""))):
			highlighted_cards[question_id] = true
			continue
		for option in question.get("options", []):
			if event.contains(String(option.get("title", ""))):
				highlighted_cards[question_id] = true


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _update_after_end() -> void:
	if state.ended:
		status_label.text = state.end_reason
		_show_result_banner(state.end_reason, Color(0.62, 1.0, 0.78, 1.0) if state.victory else Color(1.0, 0.36, 0.32, 1.0))
	start_button.disabled = false
	rules_edit.editable = true
	running = false


func _append_recent_dialogue(speaker: String, speech: String) -> void:
	if recent_view == null:
		return
	var color := "#6b160b" if speaker == "你方" or speaker == _player_short_name() else "#2a1118"
	recent_view.append_text("[b][color=%s]%s[/color][/b]：%s\n" % [color, _escape(speaker), _escape(speech)])
	var lines := recent_view.get_parsed_text().split("\n")
	if lines.size() > 5:
		recent_view.clear()
		for i in range(max(0, lines.size() - 5), lines.size()):
			if String(lines[i]).strip_edges() != "":
				recent_view.append_text("%s\n" % _escape(String(lines[i])))


func _player_short_name() -> String:
	if state == null:
		return "玩家角色"
	var identity := String(state.player.get("public_identity", "")).strip_edges()
	if identity.is_empty():
		return "玩家角色"
	var first_clause := identity.split("，", false)[0].strip_edges()
	if first_clause.is_empty():
		first_clause = identity.split(",", false)[0].strip_edges()
	var marker := first_clause.rfind("的")
	if marker >= 0 and marker < first_clause.length() - 1:
		first_clause = first_clause.substr(marker + 1).strip_edges()
	for token in ["来自", "一名", "一个", "的"]:
		first_clause = first_clause.replace(token, "")
	first_clause = first_clause.strip_edges()
	if first_clause.length() > 8:
		first_clause = first_clause.substr(0, 8)
	return first_clause if not first_clause.is_empty() else "玩家角色"


func _escape(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")
