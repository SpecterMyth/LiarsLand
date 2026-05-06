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
const CardUiKitScript := preload("res://scripts/ui/card_ui_kit.gd")
const StartMenuScript := preload("res://scripts/ui/start_menu.gd")

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
var upgrade_done := false
var ascension_skipped := false

var card_kit
var background_texture: TextureRect
var upper_box: TextureRect
var lower_box: TextureRect
var status_label: Label
var progress_label: Label
var npc_label: Label
var player_label: Label
var current_speaker_label: Label
var current_nameplate: TextureRect
var previous_speaker_label: Label
var previous_nameplate: TextureRect
var npc_public_label: Label
var stats_label: Label
var rules_edit: TextEdit
var dialogue_title: Label
var result_banner: Label
var dialogue_view: RichTextLabel
var recent_view: RichTextLabel
var state_view: RichTextLabel
var card_grid: GridContainer
var intel_panel: Control
var intel_progress_label: Label
var intel_content_root: VBoxContainer
var intel_footer: HBoxContainer
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
var history_dialog: Control
var history_view: RichTextLabel
var modal_backdrop: Button
var upgrade_panel: Control
var upgrade_label: Label
var upgrade_hint: Label
var upgrade_buttons: GridContainer
var continue_button: Button
var side_shadow_left: Control
var side_shadow_right: Control
var player_portrait: TextureRect
var npc_portrait: TextureRect
var selection_panel: Control
var selection_box: Control
var trade_panel: PanelContainer
var trade_box: VBoxContainer
var shop_panel: Control
var shop_box: Control
var ascension_box: Control
var start_menu: Control
var upgrade_buttons_by_stat: Dictionary = {}
var highlighted_cards: Dictionary = {}
var drawer_mode := "intel"
var last_final_speaker := ""
var last_final_speech := ""
var last_final_role := "player"
var active_dialogue_role := "player"


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
	card_kit = CardUiKitScript.new()
	var controls: Dictionary = AdventureLayoutScript.new().build(self, DEFAULT_RULES)
	background_texture = controls.get("background_texture")
	upper_box = controls.get("upper_box")
	lower_box = controls.get("lower_box")
	status_label = controls.get("status_label")
	progress_label = controls.get("progress_label")
	npc_label = controls.get("npc_label")
	player_label = controls.get("player_label")
	current_speaker_label = controls.get("current_speaker_label")
	current_nameplate = controls.get("current_nameplate")
	previous_speaker_label = controls.get("previous_speaker_label")
	previous_nameplate = controls.get("previous_nameplate")
	recent_view = controls.get("recent_view")
	npc_public_label = controls.get("npc_public_label")
	stats_label = controls.get("stats_label")
	rules_edit = controls.get("rules_edit")
	dialogue_title = controls.get("dialogue_title")
	result_banner = controls.get("result_banner")
	dialogue_view = controls.get("dialogue_view")
	state_view = controls.get("state_view")
	card_grid = controls.get("card_grid")
	intel_panel = controls.get("intel_panel")
	intel_progress_label = controls.get("intel_progress_label")
	intel_content_root = controls.get("intel_content_root")
	intel_footer = controls.get("intel_footer")
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
	modal_backdrop = controls.get("modal_backdrop")
	history_dialog = controls.get("history_dialog")
	history_view = controls.get("history_view")
	upgrade_panel = controls.get("upgrade_panel")
	upgrade_label = controls.get("upgrade_label")
	upgrade_hint = controls.get("upgrade_hint")
	upgrade_buttons = controls.get("upgrade_buttons")
	continue_button = controls.get("continue_button")
	side_shadow_left = controls.get("side_shadow_left")
	side_shadow_right = controls.get("side_shadow_right")
	player_portrait = controls.get("player_portrait")
	npc_portrait = controls.get("npc_portrait")
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	history_button.pressed.connect(_show_history)
	info_button.pressed.connect(_show_intel_panel)
	bag_button.pressed.connect(func(): _show_drawer("bag"))
	rules_button.pressed.connect(_toggle_rules)
	status_button.pressed.connect(func(): _show_drawer("status"))
	settings_button.pressed.connect(_toggle_settings)
	modal_backdrop.pressed.connect(_close_float_panels)
	continue_button.pressed.connect(_on_continue_pressed)
	_wire_blank_close([intel_panel, drawer, rules_panel, settings_panel, history_dialog])
	_build_upgrade_buttons()
	_build_selection_panel()
	_build_trade_panel()
	_build_shop_panel()
	_build_ascension_panel()
	_wire_button_feedback([start_button, reset_button, history_button, info_button, bag_button, rules_button, status_button, settings_button, continue_button])
	_start_ambience()
	_build_start_menu()


func _build_start_menu() -> void:
	start_menu = StartMenuScript.new()
	start_menu.name = "StartMenu"
	add_child(start_menu)
	start_menu.start_requested.connect(_on_start_pressed)
	start_menu.rules_requested.connect(_toggle_rules)
	start_menu.settings_requested.connect(_toggle_settings)


func _build_selection_panel() -> void:
	selection_panel = card_kit.make_reference_page("page_round_start_v4.png")
	selection_panel.visible = false
	add_child(selection_panel)
	selection_box = Control.new()
	selection_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_panel.add_child(selection_box)


func _build_shop_panel() -> void:
	shop_panel = card_kit.make_reference_page("page_shop_v5.png")
	shop_panel.visible = false
	add_child(shop_panel)
	shop_box = Control.new()
	shop_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_panel.add_child(shop_box)


func _build_ascension_panel() -> void:
	if upgrade_panel != null:
		upgrade_panel.visible = false
	upgrade_panel = card_kit.make_reference_page("page_ascension_v5.png")
	upgrade_panel.visible = false
	add_child(upgrade_panel)
	ascension_box = Control.new()
	ascension_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_panel.add_child(ascension_box)


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
		settings_panel.visible = false
	if modal_backdrop != null:
		modal_backdrop.visible = false
	if recent_view != null:
		recent_view.clear()
	if upper_box != null:
		upper_box.visible = false
	if lower_box != null:
		lower_box.visible = false
	if background_texture != null:
		_set_texture_or_fallback(background_texture, "res://assets/generated/bg_moon_market.png", "res://assets/generated/ui/dialogue/dialogue_base.png")
	if player_portrait != null:
		player_portrait.visible = false
	if npc_portrait != null:
		npc_portrait.visible = false
	if side_shadow_left != null:
		side_shadow_left.visible = false
	if side_shadow_right != null:
		side_shadow_right.visible = false
	if start_menu != null:
		start_menu.call("show_menu")
	last_final_speaker = ""
	last_final_speech = ""
	highlighted_cards.clear()
	dialogue_title.text = "瀵硅瘽"
	dialogue_view.clear()
	state_view.clear()
	status_label.text = "%s：等待开始" % state.chapter.get("title", "骗子大陆")
	npc_label.text = "等待选择"
	player_label.text = _player_short_name()
	if current_speaker_label != null:
		current_speaker_label.text = _player_short_name()
	_set_current_dialogue_role("player")
	npc_public_label.text = "开始后从 3 名 NPC 中选择对话对象。"
	_show_scene_message("调整行为文件后点击“开始”。你方角色会自动交涉，玩家负责选择 NPC、购买法器和升华。")
	_update_state_panel()


func _on_start_pressed() -> void:
	if start_menu != null:
		start_menu.call("hide_menu")
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
	_set_dialogue_visible(false)
	selected_npc_choice = -1
	_render_npc_selection_page()
	while selected_npc_choice < 0 and running and not state.ended:
		await get_tree().process_frame
	selection_panel.visible = false
	if selected_npc_choice >= 0:
		state.choose_npc(selected_npc_choice)
		_set_current_npc_assets()
	_show_scene_message("已选择和 %s 聊聊。" % [state.current_npc().get("public_name", "NPC")])


func _render_npc_selection_page() -> void:
	_set_dialogue_visible(false)
	if selection_panel != null:
		selection_panel.queue_free()
	selection_panel = card_kit.make_reference_page("page_round_start_v4.png")
	add_child(selection_panel)
	selection_box = Control.new()
	selection_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_panel.add_child(selection_box)
	_add_hotspot_button(selection_box, "选择", Rect2(0.325, 0.790, 0.130, 0.085), func(): selected_npc_choice = 0)
	_add_hotspot_button(selection_box, "选择", Rect2(0.515, 0.790, 0.130, 0.085), func(): selected_npc_choice = 1)
	_add_hotspot_button(selection_box, "选择", Rect2(0.725, 0.790, 0.130, 0.085), func(): selected_npc_choice = 2)
	_add_final_reference_utility_hotspots(selection_box)
	selection_panel.visible = true
	status_label.text = "第 %d / %d 回合：选择 NPC" % [state.chapter_round + 1, state.max_rounds]
	_update_progress()

func _run_current_dialogue() -> void:
	_set_dialogue_visible(true)
	for i in range(state.max_dialogue_turns):
		if state.ended:
			return
		state.turn += 1
		status_label.text = "第 %d 回合：月市商店" % (state.chapter_round + 1)
		_update_progress()
		_set_active_speaker("player")
		var player_response := await _get_player_dialogue()
		if player_response.has("error"):
			_show_error(player_response.get("error", ""))
			return
		var speech := String(player_response.get("speech", "我想先听听你的看法。")).strip_edges()
		var raw_action := String(player_response.get("action", "none")).strip_edges().to_lower()
		state.add_dialogue("player", speech)
		await _finish_speech_stream("浣犳柟", speech, Color(0.58, 0.82, 1.0, 1.0))
		if raw_action != "" and raw_action != "none":
			await _resolve_action(raw_action, {"artifact_id": String(player_response.get("artifact_id", ""))}, "鍗虫椂琛屽姩")
			return
		status_label.text = "第 %d 回合：月市商店" % (state.chapter_round + 1)
		_set_active_speaker("npc")
		var npc_response := await _get_npc_dialogue()
		if npc_response.has("error"):
			_show_error(npc_response.get("error", ""))
			return
		var npc_speech := String(npc_response.get("speech", "NPC response.")).strip_edges()
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
		await _resolve_action(String(response.get("action", "leave")), {"artifact_id": String(response.get("artifact_id", ""))}, "瀵硅瘽缁撴潫琛屽姩")


func _resolve_action(action: String, payload: Dictionary, label: String) -> void:
	for event in RulesEngineScript.resolve_player_action(state, action, payload):
		_append_system_log(event)
		_mark_event_cards(event)
	_show_result_banner("%s锛?s" % [label, _action_name(action)], _action_color(action))
	_update_state_panel()
	await get_tree().create_timer(0.35).timeout


func _run_shop_ui() -> void:
	_set_dialogue_visible(false)
	shop_done = false
	shop_panel.visible = true
	_render_shop()
	status_label.text = "绗?%d 鍥炲悎锛氭湀甯傚晢搴? % (state.chapter_round + 1)
	while not shop_done and running and not state.ended:
		await get_tree().process_frame
	shop_panel.visible = false


func _confirm_npc_offer(npc_response: Dictionary) -> Dictionary:
	if not npc_response.has("gift_offer") and not npc_response.has("exchange_offer"):
		return npc_response
	trade_choice = 0
	trade_panel.visible = true
	_clear_children(trade_box)
	_add_panel_label(trade_box, "NPC 鎻愬嚭娉曞櫒浜ゆ槗")
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", Color(0.92, 0.98, 0.94, 1.0))
	if npc_response.has("gift_offer"):
		var offer: Dictionary = npc_response.get("gift_offer", {})
		detail.text = "%s 鎰挎剰璧犻€侊細%s" % [state.current_npc().get("public_name", "NPC"), state.artifact_name(String(offer.get("artifact_id", "")))]
	else:
		var offer: Dictionary = npc_response.get("exchange_offer", {})
		detail.text = "%s 鎯崇敤 %s 浜ゆ崲浣犵殑 %s" % [
			state.current_npc().get("public_name", "NPC"),
			state.artifact_name(String(offer.get("npc_artifact_id", ""))),
			state.artifact_name(String(offer.get("player_artifact_id", "")))
		]
	trade_box.add_child(detail)
	var accept := Button.new()
	accept.text = "鎺ュ彈"
	accept.custom_minimum_size = Vector2(0, 42)
	accept.pressed.connect(func(): trade_choice = 1)
	trade_box.add_child(accept)
	var reject := Button.new()
	reject.text = "鎷掔粷"
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
	_append_system_log("浣犳嫆缁濅簡 NPC 鐨勪氦鏄撱€?)
	return cleaned


func _render_shop() -> void:
	_set_dialogue_visible(false)
	if shop_panel != null:
		shop_panel.queue_free()
	shop_panel = card_kit.make_reference_page("page_shop_v5.png")
	add_child(shop_panel)
	shop_box = Control.new()
	shop_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_panel.add_child(shop_box)
	var buy_rects := [
		Rect2(0.290, 0.855, 0.118, 0.065),
		Rect2(0.450, 0.855, 0.118, 0.065),
		Rect2(0.610, 0.855, 0.118, 0.065)
	]
	for i in range(min(3, state.shop_items.size())):
		var id := String(state.shop_items[i])
		_add_hotspot_button(shop_box, "购买", buy_rects[i], func(item_id := id):
			for event in RulesEngineScript.buy_player_artifact(state, item_id):
				_append_system_log(event)
			_update_state_panel()
			_render_shop()
		)
	_add_hotspot_button(shop_box, "结束商店", Rect2(0.680, 0.055, 0.300, 0.085), func(): shop_done = true)
	shop_panel.visible = true

func _offer_ascension_or_dominion() -> void:
	var can_ascend: bool = state.ascension_met(state.player) and int(state.player.get("level", 1)) < 10
	var can_dominate: bool = state.dominion_met(state.player) and not state.chapter_dominion_completed
	if not can_ascend and not can_dominate:
		return
	selected_upgrade = {}
	pending_stat_points = 3 if can_ascend else 0
	upgrade_done = false
	ascension_skipped = false
	_render_ascension_page(can_ascend, can_dominate)
	while not upgrade_done and running and not state.ended:
		await get_tree().process_frame
	upgrade_panel.visible = false
	_update_state_panel()


func _render_ascension_page(can_ascend: bool, can_dominate: bool) -> void:
	_set_dialogue_visible(false)
	if upgrade_panel != null:
		upgrade_panel.queue_free()
	upgrade_panel = card_kit.make_reference_page("page_ascension_v5.png")
	add_child(upgrade_panel)
	ascension_box = Control.new()
	ascension_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_panel.add_child(ascension_box)
	for row_index in range(_stat_defs().size()):
		var item = _stat_defs()[row_index]
		var stat := String(item[0])
		var y := 0.250 + float(row_index) * 0.088
		_add_hotspot_button(ascension_box, "−", Rect2(0.335, y, 0.040, 0.070), func(s := stat): _change_pending_stat(s, -1, can_ascend, can_dominate))
		_add_hotspot_button(ascension_box, "+", Rect2(0.595, y, 0.040, 0.070), func(s := stat): _change_pending_stat(s, 1, can_ascend, can_dominate))
	var confirm: Button = _add_hotspot_button(ascension_box, "确认升华", Rect2(0.342, 0.790, 0.292, 0.105), func():
		var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
		for event in RulesEngineScript.ascend_player(state, gains):
			_append_system_log(event)
		upgrade_done = true
	)
	confirm.disabled = not can_ascend or pending_stat_points > 0
	var dominion: Button = _add_hotspot_button(ascension_box, "选择统治", Rect2(0.696, 0.805, 0.255, 0.095), func():
		state.player_declared_dominion = true
		for event in RulesEngineScript.finish_round(state):
			_append_system_log(event)
			_mark_event_cards(event)
		upgrade_done = true
	)
	dominion.disabled = not can_dominate
	upgrade_panel.visible = true

func _change_pending_stat(stat: String, delta: int, can_ascend: bool, can_dominate: bool) -> void:
	var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
	var current := int(gains.get(stat, 0))
	if delta > 0:
		if pending_stat_points <= 0:
			return
		gains[stat] = current + 1
		pending_stat_points -= 1
	elif current > 0:
		gains[stat] = current - 1
		pending_stat_points += 1
	selected_upgrade = gains
	_render_ascension_page(can_ascend, can_dominate)


func _stat_preview_value(stat: String) -> int:
	var stats: Dictionary = state.player.get("stats", {})
	var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
	return int(stats.get(stat, 0)) + int(gains.get(stat, 0))


func _player_stat_rows() -> Array:
	return [
		["鑳介噺", str(int(state.player.get("energy", 0)))],
		["绛夌骇", str(int(state.player.get("level", 1)))],
		["缁熸不", state.dominion_progress(state.player)],
		["鑳屽寘", str(state.player.get("inventory", []).size())]
	]


func _stat_defs() -> Array:
	return [
		["hp", "鐢熷懡"],
		["frontal_attack", "姝ｆ敾"],
		["frontal_defense", "姝ｉ槻"],
		["assassination_attack", "鏆楁敾"],
		["assassination_defense", "鏆楅槻"],
		["charm", "榄呭姏"]
	]


func _add_hotspot_button(parent: Control, text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = rect.position.x
	button.anchor_top = rect.position.y
	button.anchor_right = rect.position.x + rect.size.x
	button.anchor_bottom = rect.position.y + rect.size.y
	button.offset_left = 0
	button.offset_top = 0
	button.offset_right = 0
	button.offset_bottom = 0
	button.focus_mode = Control.FOCUS_NONE
	button.modulate.a = 0.0
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_final_reference_utility_hotspots(parent: Control) -> void:
	var specs := [
		["情报", Rect2(0.898, 0.120, 0.084, 0.105), func(): _show_drawer("intel")],
		["背包", Rect2(0.898, 0.250, 0.084, 0.105), func(): _show_drawer("bag")],
		["历史", Rect2(0.898, 0.385, 0.084, 0.105), _show_history],
		["规则", Rect2(0.898, 0.515, 0.084, 0.105), _toggle_rules],
		["状态", Rect2(0.898, 0.645, 0.084, 0.105), func(): _show_drawer("status")],
		["设置", Rect2(0.898, 0.775, 0.084, 0.105), _toggle_settings]
	]
	for spec in specs:
		_add_hotspot_button(parent, String(spec[0]), spec[1], spec[2])

func _make_section_title(text: String) -> Label:
	var tone := "teal"
	if text.contains("缁熸不"):
		tone = "purple"
	elif text.contains("鍗囧崕") or text.contains("璐拱"):
		tone = "red"
	return card_kit.make_plate_label(text, tone, 26, Vector2(0, 58))


func _make_requirement_panel(title: String, requirements: Array, owned_source: Array) -> PanelContainer:
	var panel: PanelContainer = card_kit.make_requirement_panel(title, "purple" if title.contains("缁熸不") else "red")
	panel.custom_minimum_size = Vector2(280, 145)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_section_title(title))
	var grid := GridContainer.new()
	grid.columns = max(3, requirements.size())
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for artifact_id in requirements:
		var id := String(artifact_id)
		grid.add_child(card_kit.make_item_tile(card_kit.artifact_icon_name(id), 1, id in owned_source, state.artifact_name(id)))
	return panel


func _make_backpack_panel() -> PanelContainer:
	var panel: PanelContainer = card_kit.make_backpack_panel()
	panel.custom_minimum_size = Vector2(220, 560)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(card_kit.make_plate_label("鎴戠殑鑳屽寘", "purple", 28, Vector2(0, 62)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	var counts := _artifact_counts(state.player.get("inventory", []))
	for artifact_id in counts.keys():
		var id := String(artifact_id)
		grid.add_child(card_kit.make_item_tile(card_kit.artifact_icon_name(id), int(counts[id]), true, state.artifact_name(id)))
	if counts.is_empty():
		var empty := Label.new()
		empty.text = "鏆傛棤娉曞櫒"
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.72, 0.70, 0.66, 1.0))
		box.add_child(empty)
	return panel


func _artifact_counts(items: Array) -> Dictionary:
	var counts := {}
	for artifact_id in items:
		var id := String(artifact_id)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _avatar_for_npc(npc: Dictionary) -> String:
	var id := String(npc.get("id", ""))
	var species := String(npc.get("animal_species", ""))
	if id.contains("wolf") or species.contains("鐙?):
		return "avatar_wolf_card.png"
	return "avatar_fox_card.png"


func _npc_card_tag(npc: Dictionary, index: int) -> String:
	if index == 0:
		return "楂橀闄?
	if index == 1:
		return "鎯呮姤"
	return "鍚屾棌"


func _make_card_utility_column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.anchor_left = 0.91
	box.anchor_top = 0.13
	box.anchor_right = 0.99
	box.anchor_bottom = 0.96
	box.add_theme_constant_override("separation", 12)
	var specs := [
		["鎯呮姤", "icon_info.png", Color(0.02, 0.42, 0.38, 1.0), func(): _show_drawer("intel")],
		["鑳屽寘", "icon_bag.png", Color(0.62, 0.38, 0.02, 1.0), func(): _show_drawer("bag")],
		["鍘嗗彶", "icon_history.png", Color(0.27, 0.16, 0.43, 1.0), _show_history],
		["瑙勫垯", "icon_rules.png", Color(0.58, 0.08, 0.10, 1.0), _toggle_rules],
		["鐘舵€?, "icon_status.png", Color(0.08, 0.30, 0.50, 1.0), func(): _show_drawer("status")],
		["璁剧疆", "icon_settings.png", Color(0.26, 0.27, 0.28, 1.0), _toggle_settings]
	]
	for spec in specs:
		var button: Button = card_kit.make_utility_button(String(spec[0]), String(spec[1]), spec[2])
		button.pressed.connect(spec[3])
		box.add_child(button)
		_wire_button_feedback([button])
	return box

func _build_upgrade_buttons() -> void:
	var upgrades := [
		["hp", "鐢熷懡"],
		["frontal_attack", "姝ｉ潰鏀诲嚮"],
		["frontal_defense", "姝ｉ潰闃插尽"],
		["assassination_attack", "鏆楁潃鏀诲嚮"],
		["assassination_defense", "鏆楁潃闃插尽"],
		["charm", "姒勫懎濮?]
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
	dialogue_title.text = "鎬濊€冧腑"
	dialogue_view.clear()
	_prepare_llm_stream("player_llm", "浣犳柟", Color(0.58, 0.82, 1.0, 1.0))
	if llm_client.use_mock_llm():
		var npc: Dictionary = state.current_npc()
		var mock := {}
		mock["thinking"] = "鎴戜細鍏堣瘯鎺㈠鏂瑰涓栫晫璁惧畾鍜屾硶鍣ㄧ殑鐞嗚В锛屼笉鎬ョ潃鍔ㄦ墜銆?
		mock["speech"] = "鍚%s闄勮繎鏈変簺娉曞櫒鎹㈡墜寰堝揩銆傝嫢鎴戜滑鍚勬湁鎵€闇€锛屼篃璁歌兘璋堜竴绗斾氦鎹€? % npc.get("territory", "杩欓噷")
		mock["action"] = "none"
		mock["artifact_id"] = ""
		mock["end_dialogue"] = state.turn >= state.max_dialogue_turns
		await llm_client.chat_json("player_llm", "", "", mock, true)
		streaming_section = ""
		return mock
	var fallback := {"thinking": "鍏堣皑鎱庤瘯鎺€?, "speech": "鎴戞兂鍏堝惉鍚綘鎬庝箞鐪嬫渶杩戠殑浼犻椈銆?, "action": "none", "artifact_id": "", "end_dialogue": false}
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
		var response := {"speech": "浣犻棶寰楀緢宸с€傝嫢浣犳噦%s锛屽氨璇ョ煡閬撶ぜ鐗╁拰浠ｄ环甯稿父鏄竴鍥炰簨銆? % npc.get("liked_topics", ["瑙勭煩"])[0]}
		if int(npc.get("affinity", 0)) >= 6 and not npc.get("inventory", []).is_empty():
			response["gift_offer"] = {"artifact_id": String(npc.get("inventory", [])[0]), "affinity_required": 6}
		await llm_client.chat_json("npc_llm", "", "", response, true)
		streaming_section = ""
		return response
	var fallback := {"speech": "浣犵殑璇濊鎴戞湁鐐瑰叴瓒ｏ紝浣嗘垜杩橀渶瑕佹洿澶氳瘹鎰忋€?}
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
	dialogue_title.text = "琛屽姩鍐崇瓥涓?
	dialogue_view.clear()
	_prepare_llm_stream("player_llm", "", Color.WHITE)
	if llm_client.use_mock_llm():
		var mock := {"thinking": "椋庨櫓涓嶆竻锛屽厛鎾ょ杩涘叆鍟嗗簵銆?, "action": "leave", "artifact_id": ""}
		await llm_client.chat_json("player_llm", "", "", mock, true)
		streaming_section = ""
		return mock
	var fallback := {"thinking": "椋庨櫓涓嶆竻锛屼紭鍏堢寮€銆?, "action": "leave", "artifact_id": ""}
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
	var background_name := String(npc.get("background", ""))
	if not background_name.is_empty():
		_set_texture_or_fallback(background_texture, "res://assets/generated/%s" % background_name, "res://assets/generated/bg_moon_market.png")
	_set_texture_or_fallback(player_portrait, "res://assets/generated/player_portrait_half.png", "res://assets/generated/player_portrait.png")
	var portrait_name := String(npc.get("portrait", ""))
	if not portrait_name.is_empty():
		var half_portrait := portrait_name.replace(".png", "_half.png")
		_set_texture_or_fallback(npc_portrait, "res://assets/generated/%s" % half_portrait, "res://assets/generated/%s" % portrait_name)
	_update_dialogue_scene_visibility()
	npc_label.text = String(npc.get("public_name", ""))
	if current_speaker_label != null:
		current_speaker_label.text = String(npc.get("public_name", "NPC"))
	npc_public_label.text = "鍏紑璧勬枡锛?s\n鍦扮洏锛?s\n鍋忓ソ璇濋锛?s\n鑳屽寘涓庨渶姹傦細涓嶅彲瑙? % [
		String(npc.get("public_identity", "鏈煡韬唤")),
		String(npc.get("territory", "鏈煡")),
		"銆?.join(npc.get("liked_topics", []))
	]
	_update_progress()


func _update_state_panel() -> void:
	if state == null:
		return
	if player_label != null:
		player_label.text = _player_short_name()
	var stats: Dictionary = state.player.get("stats", {})
	var inventory_text := "銆?.join(state.describe_inventory(state.player.get("inventory", [])))
	var ascension_text := "銆?.join(state.describe_inventory(state.player.get("ascension_requirement", [])))
	stats_label.text = "绔犺妭锛?d / %d\n鍥炲悎锛?d / %d\n瀛楃锛?d / %d\n鑳介噺锛?d\n绛夌骇锛?d\n缁熸不锛?s\n鑳屽寘锛?s\n鍗囧崕闇€姹傦細%s\n鐢熷懡锛?d  榄呭姏锛?d\n姝ｉ潰锛?d/%d  鏆楁潃锛?d/%d" % [
		state.chapter_index + 1, state.max_chapters,
		state.chapter_round + 1, state.max_rounds,
		state.player_chars, state.max_player_chars,
		int(state.player.get("energy", 0)),
		int(state.player.get("level", 1)),
		state.dominion_progress(state.player),
		inventory_text,
		ascension_text,
		int(stats.get("hp", 0)), int(stats.get("charm", 0)),
		int(stats.get("frontal_attack", 0)), int(stats.get("frontal_defense", 0)),
		int(stats.get("assassination_attack", 0)), int(stats.get("assassination_defense", 0))
	]
	state_view.clear()
	state_view.append_text("[b]缁熸不闇€姹俒/b]\n")
	for artifact_id in state.player.get("dominion_requirement", []):
		var mark := "宸茶幏" if String(artifact_id) in state.player.get("artifact_history", []) else "鏈幏"
		state_view.append_text("- %s [%s]\n" % [state.artifact_name(String(artifact_id)), mark])
	state_view.append_text("\n[b]杩戞湡璁板繂[/b]\n")
	for item in state.recent_memory(state.player, 8):
		state_view.append_text("- %s\n" % _escape(String(item)))
	state_view.append_text("\n[b]鎯呮姤鍗/b]\n")
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		var selected := String(state.selected_world_intel.get(question_id, "鏈€夋嫨"))
		var answer_title: String = state.world_intel_option_title(question_id, selected) if selected != "鏈€夋嫨" else selected
		state_view.append_text("- %s锛?s\n" % [String(question.get("title", question_id)), answer_title])
	if state.ended:
		state_view.append_text("\n[b]缁撶畻[/b]\n%s\n" % state.end_reason)
	_update_card_grid()
	if intel_panel != null and intel_panel.visible:
		_update_intel_panel()
	_update_progress()


func _on_stream_delta(section: String, delta: String) -> void:
	if section == streaming_section:
		dialogue_view.append_text(_escape(delta))
		_follow_dialogue_view(dialogue_view)


func _on_stream_field_delta(section: String, field_name: String, delta: String) -> void:
	if section != streaming_section:
		return
	if field_name == "speech":
		if not speech_stream_started:
			_begin_speech_stream()
		dialogue_view.append_text(_escape(delta))
		streamed_speech += delta
		_follow_dialogue_view(dialogue_view)
	elif field_name == "thinking" and not speech_stream_started:
		dialogue_view.append_text("[font_size=11][color=#130905]%s[/color][/font_size]" % _escape(delta))
		_follow_dialogue_view(dialogue_view)


func _prepare_llm_stream(section: String, speaker: String, color: Color, clear_for_thinking := true) -> void:
	_show_previous_final_if_ready()
	streaming_section = section
	streaming_speaker = speaker
	streaming_color = color
	active_dialogue_role = "npc" if section == "npc_llm" else "player"
	_set_current_dialogue_role(active_dialogue_role)
	speech_stream_started = false
	streamed_speech = ""
	if clear_for_thinking:
		dialogue_view.clear()


func _begin_speech_stream() -> void:
	speech_stream_started = true
	dialogue_title.text = "鐎电鐦?
	result_banner.visible = false
	dialogue_view.clear()
	_pop_control(dialogue_view)


func _finish_speech_stream(speaker: String, speech: String, color: Color) -> void:
	if not speech_stream_started:
		await _show_speech_stream(speaker, speech, color)
		_store_final_dialogue(speaker, speech)
		return
	if speech.length() > streamed_speech.length() and speech.begins_with(streamed_speech):
		dialogue_view.append_text(_escape(speech.substr(streamed_speech.length())))
		_follow_dialogue_view(dialogue_view)
	elif streamed_speech.strip_edges() != speech.strip_edges():
		await _show_speech_stream(speaker, speech, color)
	_store_final_dialogue(speaker, speech)
	await get_tree().process_frame


func _show_speech_stream(speaker: String, speech: String, color: Color) -> void:
	dialogue_title.text = "鐎电鐦?
	result_banner.visible = false
	dialogue_view.clear()
	_pop_control(dialogue_view)
	for i in range(0, speech.length(), 3):
		dialogue_view.append_text(_escape(speech.substr(i, 3)))
		_follow_dialogue_view(dialogue_view)
		await get_tree().create_timer(0.02).timeout


func _show_scene_message(text: String) -> void:
	dialogue_title.text = "鐎电鐦?
	dialogue_view.clear()
	dialogue_view.append_text("[color=#f3d28b]%s[/color]" % _escape(text))
	_follow_dialogue_view(dialogue_view)


func _show_error(text: String) -> void:
	dialogue_title.text = "LLM 璋冪敤閿欒"
	result_banner.visible = false
	dialogue_view.clear()
	dialogue_view.append_text("[color=#ff7a7a]%s[/color]" % _escape(text))
	_follow_dialogue_view(dialogue_view)
	running = false


func _append_system_log(message: String) -> void:
	dialogue_view.append_text("\n[color=#f3d28b]%s[/color]" % _escape(message))
	_follow_dialogue_view(dialogue_view)
	state.event_log.append(message)
	_flash(Color(1.0, 0.42, 0.30, 0.12))


func _set_active_speaker(role: String) -> void:
	if current_speaker_label != null:
		if role == "player":
			current_speaker_label.text = _player_short_name()
		else:
			current_speaker_label.text = String(state.current_npc().get("public_name", "NPC")) if state != null and state.has_method("current_npc") else "NPC"
	player_portrait.modulate = Color(1, 1, 1, 1) if role == "player" else Color(0.38, 0.38, 0.38, 1.0)
	npc_portrait.modulate = Color(1, 1, 1, 1) if role == "npc" else Color(0.38, 0.38, 0.38, 1.0)
	_shake_portrait(player_portrait if role == "player" else npc_portrait)


func _show_history() -> void:
	history_view.clear()
	history_view.append_text("[b]瀵硅瘽鍘嗗彶[/b]\n")
	history_view.append_text(_escape(state.format_full_history()))
	if not state.event_log.is_empty():
		history_view.append_text("\n\n[b]琛屽姩涓庡彂鐜癧/b]\n")
		for item in state.event_log:
			history_view.append_text("- %s\n" % _escape(String(item)))
	if intel_panel != null:
		intel_panel.visible = false
	history_dialog.visible = true
	_show_modal_backdrop()
	_slide_in(history_dialog)


func _show_intel_panel() -> void:
	if intel_panel == null:
		_show_drawer("intel")
		return
	intel_panel.visible = true
	drawer.visible = false
	rules_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if history_dialog != null:
		history_dialog.visible = false
	_update_intel_panel()
	_show_modal_backdrop()
	_slide_in(intel_panel)


func _show_drawer(mode: String) -> void:
	drawer_mode = mode
	drawer.visible = true
	if intel_panel != null:
		intel_panel.visible = false
	rules_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if history_dialog != null:
		history_dialog.visible = false
	var title := drawer.get_meta("title_label") as Label
	if title != null:
		match drawer_mode:
			"bag":
				title.text = "鑳屽寘"
			"status":
				title.text = "鐘舵€?
			_:
				title.text = "鎯呮姤"
	_update_state_panel()
	_show_modal_backdrop()
	_slide_in(drawer)


func _toggle_rules() -> void:
	rules_panel.visible = not rules_panel.visible
	if rules_panel.visible:
		drawer.visible = false
		if intel_panel != null:
			intel_panel.visible = false
		if settings_panel != null:
			settings_panel.visible = false
		if history_dialog != null:
			history_dialog.visible = false
		_show_modal_backdrop()
		_slide_in(rules_panel)
	else:
		_update_modal_backdrop()


func _toggle_settings() -> void:
	if settings_panel == null:
		return
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible:
		drawer.visible = false
		if intel_panel != null:
			intel_panel.visible = false
		rules_panel.visible = false
		if history_dialog != null:
			history_dialog.visible = false
		_show_modal_backdrop()
		_slide_in(settings_panel)
	else:
		_update_modal_backdrop()


func _show_modal_backdrop() -> void:
	if modal_backdrop != null:
		modal_backdrop.visible = true
		modal_backdrop.move_to_front()
	for panel in [intel_panel, drawer, rules_panel, settings_panel, history_dialog, upgrade_panel]:
		if panel != null and panel.visible:
			panel.z_index = 90
			panel.move_to_front()


func _update_modal_backdrop() -> void:
	if modal_backdrop == null:
		return
	modal_backdrop.visible = (
		(intel_panel != null and intel_panel.visible)
		or (drawer != null and drawer.visible)
		or (rules_panel != null and rules_panel.visible)
		or (settings_panel != null and settings_panel.visible)
		or (history_dialog != null and history_dialog.visible)
	)


func _close_float_panels() -> void:
	if intel_panel != null:
		intel_panel.visible = false
	if drawer != null:
		drawer.visible = false
	if rules_panel != null:
		rules_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if history_dialog != null:
		history_dialog.visible = false
	_update_modal_backdrop()


func _wire_blank_close(panels: Array) -> void:
	for panel in panels:
		var control := panel as Control
		if control == null:
			continue
		control.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mouse_event := event as InputEventMouseButton
				if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
					_close_float_panels()
					get_viewport().set_input_as_handled()
		)


func _update_card_grid() -> void:
	if card_grid == null:
		return
	_clear_children(card_grid)
	stats_label.visible = drawer_mode == "status"
	match drawer_mode:
		"bag":
			_add_section_label("缁熸不闇€姹?)
			for artifact_id in state.player.get("dominion_requirement", []):
				var known: bool = String(artifact_id) in state.player.get("artifact_history", [])
				_add_info_card(String(artifact_id), state.artifact_name(String(artifact_id)), "宸茶幏寰? if known else "鏈幏寰?, "缁熸不闇€姹傛硶鍣?, true, false, known)
			_add_section_label("鑳屽寘")
			for artifact_id in state.player.get("inventory", []):
				var artifact: Dictionary = state.get_artifact(String(artifact_id))
				_add_info_card(String(artifact_id), String(artifact.get("name", artifact_id)), "鎸佹湁涓?, String(artifact.get("story", "")), true, false, false)
			_add_section_label("鍗囧崕闇€姹?)
			for artifact_id in state.player.get("ascension_requirement", []):
				_add_info_card(String(artifact_id), state.artifact_name(String(artifact_id)), "闇€姹?, "鍗囧崕娑堣€楁硶鍣?, true, false, false)
		"status":
			_add_section_label("褰撳墠鐘舵€?)
			_add_info_card("round", "绔犺妭 / 鍥炲悎", "%d / %d 绔? % [state.chapter_index + 1, state.max_chapters], "鍥炲悎 %d / %d锛屽璇?%d / %d" % [state.chapter_round + 1, state.max_rounds, state.turn, state.max_dialogue_turns], true, false, false)
			_add_info_card("budget", "瀛楃涓庤兘閲?, "%d / %d" % [state.player_chars, state.max_player_chars], "鑳介噺锛?d  绛夌骇锛?d" % [int(state.player.get("energy", 0)), int(state.player.get("level", 1))], true, false, false)
			var npc: Dictionary = state.current_npc()
			if not npc.is_empty():
				_add_info_card("npc", String(npc.get("public_name", "NPC")), String(npc.get("friend_judgement", "unknown")), "浜茶繎搴︼細%d  鍦扮洏锛?s" % [int(npc.get("affinity", 0)), String(npc.get("territory", "鏈煡"))], true, false, false)
		_:
			_add_section_label("瑜版挸澧?NPC")
			if state != null and not state.current_npc().is_empty():
				var npc: Dictionary = state.current_npc()
				_add_info_card("npc_public", String(npc.get("public_name", "NPC")), String(npc.get("territory", "鏈煡")), String(npc.get("public_identity", "鏈煡韬唤")), true, false, false)
			_add_section_label("涓栫晫璁惧畾妗ｆ")
			for question in state.world_intel_questions:
				_add_world_intel_question(question)
			_add_submit_world_intel_button()


func _update_intel_panel() -> void:
	if intel_content_root == null or intel_footer == null or state == null:
		return
	_clear_children(intel_content_root)
	_clear_children(intel_footer)
	var total: int = state.world_intel_questions.size()
	var selected_count := 0
	for question in state.world_intel_questions:
		if state.selected_world_intel.has(String(question.get("id", ""))):
			selected_count += 1
	if intel_progress_label != null:
		intel_progress_label.text = "宸查€夋嫨 %d / %d" % [selected_count, total]
	for question in state.world_intel_questions:
		_add_intel_question_section(question)
	var close_button: Button = card_kit.make_secondary_button("杩斿洖")
	close_button.custom_minimum_size = Vector2(180, 52)
	close_button.pressed.connect(func():
		if intel_panel != null:
			intel_panel.visible = false
		_update_modal_backdrop()
	)
	intel_footer.add_child(close_button)
	var submit_button: Button = card_kit.make_primary_button("鎻愪氦涓栫晫璁惧畾妗ｆ")
	submit_button.custom_minimum_size = Vector2(320, 58)
	submit_button.disabled = state.intel_submitted
	submit_button.pressed.connect(_confirm_submit_world_intel)
	intel_footer.add_child(submit_button)
	_wire_button_feedback([close_button, submit_button])


func _add_intel_question_section(question: Dictionary) -> void:
	var question_id := String(question.get("id", ""))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _intel_panel_style())
	intel_content_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = String(question.get("title", question_id))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0.015, 0.018, 0.025, 1.0))
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	title.clip_text = true
	box.add_child(title)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var option_index := 0
	for option in question.get("options", []):
		_add_intel_answer_card(row, question_id, option, option_index)
		option_index += 1


func _add_intel_answer_card(parent: HBoxContainer, question_id: String, option: Dictionary, option_index: int) -> void:
	var option_id := String(option.get("id", ""))
	var selected := String(state.selected_world_intel.get(question_id, "")) == option_id
	var button := Button.new()
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = Vector2(0, 350)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _intel_card_style(question_id, option_id, selected, false))
	button.add_theme_stylebox_override("hover", _intel_card_style(question_id, option_id, selected, true))
	button.add_theme_stylebox_override("pressed", _intel_card_style(question_id, option_id, true, false))
	button.pressed.connect(func():
		state.select_world_intel_answer(question_id, option_id)
		_update_intel_panel()
		_update_state_panel()
	)
	parent.add_child(button)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 12
	box.offset_right = -12
	box.offset_bottom = -12
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	button.add_child(box)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 185)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_texture_or_fallback(art, _intel_image_path(String(option.get("image", ""))), "res://assets/generated/card_clue_back.png")
	box.add_child(art)
	var title := Label.new()
	title.text = ("宸查€? " if selected else "") + String(option.get("title", option_id))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0.015, 0.018, 0.025, 1.0))
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.20, 1.0) if selected else Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var sources := _world_intel_sources(question_id, option_id)
	var source_label := Label.new()
	source_label.text = "璇佽瘝锛?s" % ("鏆傛棤" if sources.is_empty() else " / ".join(sources))
	source_label.add_theme_font_size_override("font_size", 15)
	source_label.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68, 1.0))
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_label.clip_text = true
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(source_label)
	var portrait_row := HBoxContainer.new()
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_row.add_theme_constant_override("separation", -9)
	portrait_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait_row)
	_add_intel_testimony_portraits(portrait_row, question_id, option_id)


func _add_intel_testimony_portraits(parent: HBoxContainer, question_id: String, option_id: String) -> void:
	for source in state.intel_testimonies.get(question_id, {}).get(option_id, []):
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(42, 42)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.tooltip_text = "绗?%d 绔?%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "NPC"))]
		_set_texture_or_fallback(portrait, "res://assets/generated/%s" % String(source.get("portrait", "")), "res://assets/generated/opponent_portrait.png")
		parent.add_child(portrait)


func _intel_image_path(image_name: String) -> String:
	if image_name.begins_with("res://"):
		return image_name
	if image_name.begins_with("ui/intel/"):
		return "res://assets/generated/%s" % image_name
	if not image_name.is_empty():
		return "res://assets/generated/%s" % image_name
	return "res://assets/generated/card_clue_back.png"


func _intel_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.030, 0.040, 0.92)
	style.border_color = Color(0.70, 0.05, 0.08, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.60)
	style.shadow_size = 10
	style.shadow_offset = Vector2(8, 8)
	return style


func _intel_card_style(question_id: String, option_id: String, selected: bool, hover: bool) -> StyleBoxFlat:
	var tone := _intel_tone_color(question_id, option_id)
	var bg := Color(0.018, 0.020, 0.026, 0.96)
	if hover:
		bg = bg.lightened(0.05)
	if selected:
		bg = Color(0.12, 0.08, 0.018, 0.98)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(1.0, 0.67, 0.08, 1.0) if selected else tone
	style.set_border_width_all(4 if selected else 3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 8
	style.shadow_offset = Vector2(7, 7)
	return style


func _intel_tone_color(question_id: String, option_id: String) -> Color:
	match option_id:
		"moon", "threshold_truth", "memory_vessel", "ritual", "kept_secrets":
			return Color(0.02, 0.58, 0.55, 1.0)
		"name", "betrayed", "beautiful_lies", "identity_disguise", "purge":
			return Color(0.82, 0.04, 0.12, 1.0)
		"debt", "first_gift", "fair_trade", "living_creditor":
			return Color(0.95, 0.62, 0.06, 1.0)
		"devoured_by_artifacts", "mistaken_identity":
			return Color(0.36, 0.16, 0.74, 1.0)
		"hidden_royals", "dead_relic":
			return Color(0.78, 0.82, 0.68, 1.0)
		_:
			return Color(0.72, 0.05, 0.10, 1.0)


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
	title.text = ("%s  " % ("宸查€? if selected else "")) + String(option.get("title", option_id))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.86, 1.0) if selected else Color(1.0, 0.91, 0.74, 1.0))
	title.clip_text = true
	text_box.add_child(title)
	var sources := _world_intel_sources(question_id, option_id)
	var source_label := Label.new()
	source_label.text = "璇佽瘝锛?s" % ("鏆傛棤" if sources.is_empty() else "銆?.join(sources))
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
		portrait.tooltip_text = "绗?%d 绔?%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "NPC"))]
		_set_texture_or_fallback(portrait, "res://assets/generated/%s" % String(source.get("portrait", "")), "res://assets/generated/opponent_portrait.png")
		portraits.add_child(portrait)


func _world_intel_sources(question_id: String, option_id: String) -> Array[String]:
	var result: Array[String] = []
	for source in state.intel_testimonies.get(question_id, {}).get(option_id, []):
		result.append("绗?d绔?s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "NPC"))])
	return result


func _add_submit_world_intel_button() -> void:
	var button := Button.new()
	button.text = "鎻愪氦涓栫晫璁惧畾妗ｆ"
	button.custom_minimum_size = Vector2(0, 48)
	button.disabled = state.intel_submitted
	button.pressed.connect(_confirm_submit_world_intel)
	card_grid.add_child(button)
	_wire_button_feedback([button])


func _confirm_submit_world_intel() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "鎻愪氦涓栫晫璁惧畾妗ｆ"
	dialog.dialog_text = "鎻愪氦鍚庢棤娉曚慨鏀广€? 鏉¤瀹氬叏閮ㄦ纭墠浼氳儨鍒╋紝浠绘剰閿欒閮戒細澶辫触銆?
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
			return "閭€璇?
		"assassinate":
			return "鏆楁潃"
		"duel":
			return "鍐虫枟"
		"gift":
			return "璧犻€?
		"cast":
			return "鏂芥硶"
		_:
			return "鎾ょ"


func _update_progress() -> void:
	if progress_label == null or state == null:
		return
	progress_label.text = "绗?%d / %d 绔? 鍥炲悎 %d / %d  瀵硅瘽 %d / %d" % [state.chapter_index + 1, state.max_chapters, min(state.chapter_round + 1, state.max_rounds), state.max_rounds, state.turn, state.max_dialogue_turns]


func _update_upgrade_buttons() -> void:
	var stats: Dictionary = state.player.get("stats", {})
	var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
	for stat in upgrade_buttons_by_stat.keys():
		var button: Button = upgrade_buttons_by_stat[stat]
		var value := int(stats.get(stat, 0))
		button.text = "%s %d -> %d" % [_stat_name(stat), value, value + int(gains.get(stat, 0))]
		button.disabled = pending_stat_points <= 0
	if upgrade_hint != null:
		upgrade_hint.text = "鍓╀綑灞炴€х偣锛?d" % pending_stat_points


func _stat_name(stat: String) -> String:
	match stat:
		"hp":
			return "鐢熷懡"
		"frontal_attack":
			return "姝ｉ潰鏀诲嚮"
		"frontal_defense":
			return "姝ｉ潰闃插尽"
		"assassination_attack":
			return "鏆楁潃鏀诲嚮"
		"assassination_defense":
			return "鏆楁潃闃插尽"
		"charm":
			return "姒勫懎濮?
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


func _store_final_dialogue(speaker: String, speech: String) -> void:
	var npc_name := "NPC"
	if state != null and state.has_method("current_npc") and not state.current_npc().is_empty():
		npc_name = String(state.current_npc().get("public_name", "NPC"))
	var is_player := speaker == "浣犳柟" or speaker == _player_short_name()
	last_final_speaker = _player_short_name() if is_player else npc_name
	last_final_speech = speech
	last_final_role = "player" if is_player else "npc"


func _show_previous_final_if_ready() -> void:
	if upper_box == null or recent_view == null or last_final_speech.strip_edges().is_empty():
		return
	if lower_box != null and not lower_box.visible:
		return
	upper_box.visible = true
	upper_box.move_to_front()
	if last_final_role == "player":
		upper_box.texture = load("res://assets/generated/ui/dialogue/dialogue_gold_blank.png")
	else:
		upper_box.texture = load("res://assets/generated/ui/dialogue/dialogue_red_blank.png")
	if previous_nameplate != null:
		previous_nameplate.texture = load("res://assets/generated/ui/dialogue/nameplate_left_exact.png") if last_final_role == "player" else load("res://assets/generated/ui/dialogue/nameplate_right_exact.png")
		_place_label_relative(previous_nameplate, Rect2(0.045, -0.30, 0.20, 0.42) if last_final_role == "player" else Rect2(0.76, -0.29, 0.22, 0.42))
	if previous_speaker_label != null:
		previous_speaker_label.text = last_final_speaker
		_place_label_relative(previous_speaker_label, Rect2(0.045, -0.30, 0.20, 0.42) if last_final_role == "player" else Rect2(0.76, -0.29, 0.22, 0.42))
	recent_view.clear()
	recent_view.append_text("[font_size=18][color=#130905]%s[/color][/font_size]" % _escape(last_final_speech))
	_follow_dialogue_view(recent_view)
	_animate_previous_dialogue()


func _set_current_dialogue_role(role: String) -> void:
	if lower_box != null:
		lower_box.texture = load("res://assets/generated/ui/dialogue/dialogue_gold_blank.png") if role == "player" else load("res://assets/generated/ui/dialogue/dialogue_red_blank.png")
		lower_box.move_to_front()
	if current_nameplate != null:
		current_nameplate.texture = load("res://assets/generated/ui/dialogue/nameplate_left_exact.png") if role == "player" else load("res://assets/generated/ui/dialogue/nameplate_right_exact.png")
		_place_label_relative(current_nameplate, Rect2(0.035, -0.21, 0.18, 0.31) if role == "player" else Rect2(0.77, -0.20, 0.18, 0.31))
	if current_speaker_label != null:
		current_speaker_label.text = _player_short_name() if role == "player" else String(state.current_npc().get("public_name", "NPC")) if state != null and not state.current_npc().is_empty() else "NPC"
		_place_label_relative(current_speaker_label, Rect2(0.035, -0.21, 0.18, 0.31) if role == "player" else Rect2(0.77, -0.20, 0.18, 0.31))
	if dialogue_view != null:
		dialogue_view.clear()
	_animate_current_dialogue_pop()


func _set_dialogue_visible(visible: bool) -> void:
	if lower_box != null:
		lower_box.visible = visible
	if side_shadow_left != null:
		side_shadow_left.visible = visible
	if side_shadow_right != null:
		side_shadow_right.visible = visible
	_update_dialogue_scene_visibility()
	for node in [status_label, progress_label, info_button, bag_button, history_button, rules_button, status_button, settings_button]:
		if node != null:
			node.visible = visible
	if not visible:
		if upper_box != null:
			upper_box.visible = false
		if dialogue_view != null:
			dialogue_view.clear()
		if recent_view != null:
			recent_view.clear()


func _update_dialogue_scene_visibility() -> void:
	var show_scene_characters := lower_box != null and lower_box.visible
	if player_portrait != null:
		player_portrait.flip_h = true
		player_portrait.visible = show_scene_characters and player_portrait.texture != null
	if npc_portrait != null:
		npc_portrait.visible = show_scene_characters and npc_portrait.texture != null


func _animate_previous_dialogue() -> void:
	if upper_box == null:
		return
	upper_box.pivot_offset = upper_box.size * 0.5
	var target_y: float = float(upper_box.get_meta("target_y", upper_box.position.y))
	upper_box.set_meta("target_y", target_y)
	upper_box.position.y = target_y + 44
	upper_box.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(upper_box, "position:y", target_y, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(upper_box, "modulate:a", 1.0, 0.18)


func _animate_current_dialogue_pop() -> void:
	if lower_box == null:
		return
	lower_box.pivot_offset = lower_box.size * 0.5
	lower_box.scale = Vector2(0.96, 0.96)
	lower_box.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lower_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lower_box, "modulate:a", 1.0, 0.12)


func _place_label_relative(label: Control, rect: Rect2) -> void:
	label.anchor_left = rect.position.x
	label.anchor_top = rect.position.y
	label.anchor_right = rect.position.x + rect.size.x
	label.anchor_bottom = rect.position.y + rect.size.y
	label.offset_left = 0
	label.offset_top = 0
	label.offset_right = 0
	label.offset_bottom = 0


func _follow_dialogue_view(view: RichTextLabel) -> void:
	if view == null:
		return
	view.scroll_following = true
	if view.has_method("scroll_to_line"):
		view.call_deferred("scroll_to_line", max(0, view.get_line_count() - 1))


func _player_short_name() -> String:
	if state == null:
		return "鐜╁瑙掕壊"
	var identity := String(state.player.get("public_identity", "")).strip_edges()
	if identity.is_empty():
		return "鐜╁瑙掕壊"
	var first_clause := identity.split("锛?, false)[0].strip_edges()
	if first_clause.is_empty():
		first_clause = identity.split(",", false)[0].strip_edges()
	var marker := first_clause.rfind("鐨?)
	if marker >= 0 and marker < first_clause.length() - 1:
		first_clause = first_clause.substr(marker + 1).strip_edges()
	for token in ["鏉ヨ嚜", "涓€鍚?, "涓€涓?, "鐨?]:
		first_clause = first_clause.replace(token, "")
	first_clause = first_clause.strip_edges()
	if first_clause.length() > 8:
		first_clause = first_clause.substr(0, 8)
	return first_clause if not first_clause.is_empty() else "鐜╁瑙掕壊"


func _escape(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")

