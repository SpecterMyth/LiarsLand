extends Control

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
const RoundSelectPageScene := preload("res://scenes/ui/round_select_page.tscn")
const ShopPageScene := preload("res://scenes/ui/shop_page.tscn")
const AscensionPageScene := preload("res://scenes/ui/ascension_page.tscn")
const ArtifactSlotScene := preload("res://scenes/ui/artifact_slot.tscn")
const ROUND_UI_ROOT := "res://assets/ui/common/"
const SELECT_CARD_ROOT := "res://assets/ui/characters/cards/"
const SHOP_UI_ROOT := "res://assets/generated/ui/shop_v2/"
const UI_FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"

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
var action_buttons: Dictionary = {}
var auto_decide_check: CheckBox
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
var action_panel: PanelContainer
var action_box: VBoxContainer
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
var action_choice := 0
var selected_action_artifact := ""
var manual_action_resolved := false
var manual_action_in_progress := false

const STATUS_BASE_SIZE := Vector2(1672.0, 941.0)
const STATUS_PANEL_HEIGHT := 52.0
const STATUS_PANEL_TOP := 6.0


func _ready() -> void:
	_build_ui()
	_setup_llm()
	_load_chapter()
	_reset_ui()
	get_viewport().size_changed.connect(_fit_full)


func _fit_full() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fit_status_panel_to_text()


func _set_status_text(text: String) -> void:
	if status_label == null:
		return
	status_label.text = text
	_fit_status_panel_to_text()


func _fit_status_panel_to_text() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var panel := status_label.get_parent() as Control
	if panel == null:
		return
	var text_width: float = _estimate_status_text_width(status_label.text)
	var panel_width: float = clamp(text_width + 360.0, 620.0, 1180.0)
	var x: float = (STATUS_BASE_SIZE.x - panel_width) * 0.5
	panel.anchor_left = x / STATUS_BASE_SIZE.x
	panel.anchor_top = STATUS_PANEL_TOP / STATUS_BASE_SIZE.y
	panel.anchor_right = (x + panel_width) / STATUS_BASE_SIZE.x
	panel.anchor_bottom = (STATUS_PANEL_TOP + STATUS_PANEL_HEIGHT) / STATUS_BASE_SIZE.y
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0


func _estimate_status_text_width(text: String) -> float:
	var font_size := 24.0
	if status_label != null:
		font_size = float(status_label.get_theme_font_size("font_size"))
		var font := status_label.get_theme_font("font")
		if font != null:
			return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(font_size)).x
	var width := 0.0
	for i in range(text.length()):
		var code := text.unicode_at(i)
		width += font_size * (0.58 if code < 128 else 1.02)
	return width


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
	action_buttons = controls.get("action_buttons", {})
	auto_decide_check = controls.get("auto_decide_check")
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
	for action in action_buttons.keys():
		var action_button := action_buttons[action] as Button
		if action_button != null:
			action_button.pressed.connect(Callable(self, "_on_manual_action_pressed").bind(String(action)))
	modal_backdrop.pressed.connect(_close_float_panels)
	continue_button.pressed.connect(_on_continue_pressed)
	_wire_blank_close([intel_panel, drawer, rules_panel, settings_panel, history_dialog])
	_build_upgrade_buttons()
	_build_selection_panel()
	_build_trade_panel()
	_build_action_panel()
	_build_shop_panel()
	_build_ascension_panel()
	_wire_button_feedback([start_button, reset_button, history_button, info_button, bag_button, rules_button, status_button, settings_button, continue_button])
	_wire_button_feedback(action_buttons.values())
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
	selection_panel = _instantiate_flow_page(RoundSelectPageScene)
	selection_panel.visible = false
	add_child(selection_panel)
	selection_box = selection_panel


func _build_shop_panel() -> void:
	shop_panel = _instantiate_flow_page(ShopPageScene)
	shop_panel.visible = false
	add_child(shop_panel)
	shop_box = shop_panel


func _build_ascension_panel() -> void:
	if upgrade_panel != null:
		upgrade_panel.visible = false
	upgrade_panel = _instantiate_flow_page(AscensionPageScene)
	upgrade_panel.visible = false
	add_child(upgrade_panel)
	ascension_box = upgrade_panel


func _build_trade_panel() -> void:
	trade_panel = _make_overlay_panel(Vector2(620, 260))
	trade_panel.visible = false
	trade_panel.z_index = 3000
	trade_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(trade_panel)
	trade_box = VBoxContainer.new()
	trade_box.add_theme_constant_override("separation", 10)
	trade_panel.add_child(trade_box)


func _build_action_panel() -> void:
	action_panel = _make_overlay_panel(Vector2(560, 340))
	action_panel.visible = false
	action_panel.z_index = 3010
	action_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(action_panel)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	action_panel.add_child(action_box)


func _instantiate_flow_page(scene: PackedScene) -> Control:
	var page: Control = scene.instantiate()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.z_index = 1000
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	return page


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
	action_choice = 0
	selected_action_artifact = ""
	manual_action_resolved = false
	manual_action_in_progress = false
	start_button.disabled = false
	rules_edit.editable = true
	upgrade_panel.visible = false
	selection_panel.visible = false
	trade_panel.visible = false
	if action_panel != null:
		action_panel.visible = false
	shop_panel.visible = false
	result_banner.visible = false
	if auto_decide_check != null:
		auto_decide_check.button_pressed = false
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
	dialogue_title.text = "对话"
	dialogue_view.clear()
	state_view.clear()
	_set_status_text("%s：等待开始" % state.chapter.get("title", "骗子大陆"))
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
		_clear_last_final_dialogue()
		_set_current_npc_assets()
	_show_scene_message("已选择和 %s 聊聊。" % [state.current_npc().get("public_name", "NPC")])


func _render_npc_selection_page() -> void:
	_set_dialogue_visible(false)
	if selection_panel != null:
		selection_panel.queue_free()
	selection_panel = _instantiate_flow_page(RoundSelectPageScene)
	add_child(selection_panel)
	selection_box = selection_panel
	_populate_round_select_page()
	selection_panel.visible = true
	_set_status_text("第 %d / %d 回合：%s" % [state.chapter_round + 1, state.max_rounds, _round_select_scene_name()])
	_update_progress()


func _populate_round_select_page() -> void:
	var counter := selection_panel.get_node_or_null("RoundCounter/RoundCounterLabel") as Label
	if counter != null:
		counter.text = "第 %d / %d 回合" % [state.chapter_round + 1, state.max_rounds]
	_apply_round_player_card(selection_panel.get_node_or_null("PlayerCard") as Control)
	var slots := selection_panel.get_node_or_null("NpcCardSlots") as Control
	if slots != null:
		for i in range(3):
			var card := slots.get_node_or_null("NpcCard%d" % [i + 1]) as Button
			if card == null:
				continue
			card.visible = i < state.npc_choices.size()
			if card.visible:
				var npc_index: int = state.npc_choices[i]
				card.visible = npc_index >= 0 and npc_index < state.npcs.size()
				if card.visible:
					_apply_npc_select_card(card, state.npcs[npc_index], i)
	_apply_round_utility_column(selection_panel.get_node_or_null("UtilityColumn") as VBoxContainer)


func _apply_round_player_card(root: Control) -> void:
	if root == null:
		return
	var card := root.get_node_or_null("CardTexture") as TextureRect
	if card != null:
		card.texture = _load_texture_any(SELECT_CARD_ROOT + "player_select_card.png")
	_ensure_select_card_shadow_mask(root)
	var name := root.get_node_or_null("NameLabel") as Label
	if name != null:
		name.text = "玩家角色"
	var stats := root.get_node_or_null("Stats") as Control
	if stats == null:
		return
	_clear_children(stats)
	var rows := _player_stat_rows()
	for i in range(rows.size()):
		var row := _make_select_stat_row(String(rows[i][0]), String(rows[i][1]), i)
		_place_by_ratio(row, Rect2(0.0, i * 0.250, 1.0, 0.220))
		stats.add_child(row)


func _apply_npc_select_card(card: Button, npc: Dictionary, choice_index: int) -> void:
	card.text = ""
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	card.pressed.connect(func(): selected_npc_choice = choice_index)
	_ensure_select_card_shadow_mask(card)
	var texture := card.get_node_or_null("CardTexture") as TextureRect
	if texture != null:
		texture.texture = _load_texture_any(_select_card_path_for_npc(npc))
	var name := card.get_node_or_null("NameLabel") as Label
	if name != null:
		name.text = String(npc.get("public_name", "NPC"))
	var tag := card.get_node_or_null("TagLabel") as Label
	if tag != null:
		tag.visible = false
	var choose := card.get_node_or_null("ChooseButton") as Button
	if choose != null:
		_style_primary_button(choose, "选择", 24)
		choose.pressed.connect(func(): selected_npc_choice = choice_index)
		_wire_button_feedback([choose])
	_wire_hold_hover_feedback([card])


func _apply_round_utility_column(box: VBoxContainer) -> void:
	if box == null:
		return
	_clear_children(box)
	var specs := [
		["情报", "icon_info.png", Color(0.02, 0.48, 0.45, 1.0), func(): _show_intel_panel()],
		["背包", "icon_bag.png", Color(0.68, 0.42, 0.03, 1.0), func(): _show_drawer("bag")],
		["历史", "icon_history.png", Color(0.34, 0.22, 0.52, 1.0), _show_history],
		["规则", "icon_rules.png", Color(0.70, 0.07, 0.10, 1.0), _toggle_rules],
		["状态", "icon_status.png", Color(0.10, 0.36, 0.60, 1.0), func(): _show_drawer("status")],
		["设置", "icon_settings.png", Color(0.30, 0.31, 0.33, 1.0), _toggle_settings]
	]
	for spec in specs:
		var button := _make_round_utility_button(String(spec[0]), String(spec[1]), spec[2])
		button.pressed.connect(spec[3])
		box.add_child(button)
		_wire_button_feedback([button])


func _make_round_select_page() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.z_index = 1000
	page.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _round_texture("bg_round_start_city.png")
	page.add_child(bg)

	var darken := ColorRect.new()
	darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darken.set_anchors_preset(Control.PRESET_FULL_RECT)
	darken.color = Color(0.0, 0.0, 0.0, 0.38)
	page.add_child(darken)

	_add_round_select_slashes(page)
	return page


func _build_round_select_content(parent: Control) -> void:
	_add_round_title(parent)
	_add_round_counter(parent)
	_add_player_select_card(parent)
	var card_rects := [
		Rect2(0.300, 0.215, 0.205, 0.700),
		Rect2(0.495, 0.190, 0.205, 0.720),
		Rect2(0.690, 0.225, 0.195, 0.690)
	]
	for i in range(min(state.npc_choices.size(), card_rects.size())):
		var npc_index: int = state.npc_choices[i]
		if npc_index >= 0 and npc_index < state.npcs.size():
			_add_npc_select_card(parent, state.npcs[npc_index], i, card_rects[i])
	_add_round_utility_column(parent)


func _add_round_select_slashes(parent: Control) -> void:
	var specs := [
		[Rect2(-0.04, 0.030, 0.420, 0.120), Color(0.62, 0.02, 0.05, 0.62), -7.0],
		[Rect2(0.470, -0.020, 0.210, 0.190), Color(0.00, 0.42, 0.42, 0.30), 22.0],
		[Rect2(0.640, 0.830, 0.370, 0.170), Color(0.66, 0.02, 0.06, 0.36), -13.0],
		[Rect2(0.310, 0.210, 0.300, 0.700), Color(0.00, 0.45, 0.47, 0.16), -10.0]
	]
	for spec in specs:
		var slash := ColorRect.new()
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slash.color = spec[1]
		slash.rotation_degrees = float(spec[2])
		_place_by_ratio(slash, spec[0])
		parent.add_child(slash)


func _add_round_title(parent: Control) -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_by_ratio(root, Rect2(0.030, 0.025, 0.430, 0.145))
	parent.add_child(root)

	var plate := TextureRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.texture = _round_texture("shop_banner_title_red_large.png")
	plate.rotation_degrees = -4.0
	root.add_child(plate)

	var label := Label.new()
	label.text = "今天和谁聊聊？"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.06
	label.anchor_top = 0.10
	label.anchor_right = 0.74
	label.anchor_bottom = 0.86
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.005, 0.006, 1.0))
	label.clip_text = true
	root.add_child(label)


func _add_round_counter(parent: Control) -> void:
	var panel := TextureRect.new()
	_place_by_ratio(panel, Rect2(0.660, 0.045, 0.270, 0.080))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.texture = _round_texture("title_banner_dark_small.png")
	parent.add_child(panel)

	var label := Label.new()
	label.text = "第 %d / %d 回合" % [state.chapter_round + 1, state.max_rounds]
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.025, 1.0))
	panel.add_child(label)


func _add_player_select_card(parent: Control) -> void:
	var root := Control.new()
	_place_by_ratio(root, Rect2(0.030, 0.165, 0.255, 0.775))
	parent.add_child(root)

	var card := TextureRect.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.texture = _load_texture_any(SELECT_CARD_ROOT + "player_select_card.png")
	root.add_child(card)
	_add_select_card_shadow_mask(root)

	var name := _make_select_label("玩家角色", 30, Color.WHITE)
	_place_by_ratio(name, Rect2(0.18, 0.635, 0.62, 0.105))
	root.add_child(name)

	var rows := _player_stat_rows()
	for i in range(rows.size()):
		var row := _make_select_stat_row(String(rows[i][0]), String(rows[i][1]), i)
		_place_by_ratio(row, Rect2(0.252, 0.735 + i * 0.050, 0.476, 0.044))
		root.add_child(row)


func _add_npc_select_card(parent: Control, npc: Dictionary, choice_index: int, rect: Rect2) -> void:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = false
	_place_by_ratio(button, rect)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.pressed.connect(func(): selected_npc_choice = choice_index)
	parent.add_child(button)

	var texture := TextureRect.new()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture = _load_texture_any(_select_card_path_for_npc(npc))
	button.add_child(texture)
	_add_select_card_shadow_mask(button)

	var name := _make_select_label(String(npc.get("public_name", "NPC")), 28, Color.WHITE)
	_place_by_ratio(name, Rect2(0.16, 0.655, 0.68, 0.100))
	button.add_child(name)

	var choose := _make_select_choose_button()
	_place_by_ratio(choose, Rect2(0.136, 0.735, 0.728, 0.075))
	choose.pressed.connect(func(): selected_npc_choice = choice_index)
	button.add_child(choose)
	_wire_button_feedback([button, choose])


func _add_round_utility_column(parent: Control) -> void:
	var box := VBoxContainer.new()
	_place_by_ratio(box, Rect2(0.898, 0.120, 0.098, 0.780))
	box.add_theme_constant_override("separation", 13)
	parent.add_child(box)
	var specs := [
		["情报", "icon_info.png", Color(0.02, 0.48, 0.45, 1.0), func(): _show_intel_panel()],
		["背包", "icon_bag.png", Color(0.68, 0.42, 0.03, 1.0), func(): _show_drawer("bag")],
		["历史", "icon_history.png", Color(0.34, 0.22, 0.52, 1.0), _show_history],
		["规则", "icon_rules.png", Color(0.70, 0.07, 0.10, 1.0), _toggle_rules],
		["状态", "icon_status.png", Color(0.10, 0.36, 0.60, 1.0), func(): _show_drawer("status")],
		["设置", "icon_settings.png", Color(0.30, 0.31, 0.33, 1.0), _toggle_settings]
	]
	for spec in specs:
		var button := _make_round_utility_button(String(spec[0]), String(spec[1]), spec[2])
		button.pressed.connect(spec[3])
		box.add_child(button)
		_wire_button_feedback([button])


func _run_current_dialogue() -> void:
	_set_dialogue_visible(true)
	manual_action_resolved = false
	manual_action_in_progress = false
	var dialogue_guard := 0
	while dialogue_guard < 20 and running and not state.ended:
		while state.turn < state.max_dialogue_turns and running and not state.ended:
			dialogue_guard += 1
			if dialogue_guard >= 20:
				break
			if manual_action_resolved:
				return
			state.turn += 1
			_set_status_text("第 %d 回合：%s" % [state.chapter_round + 1, _current_dialogue_scene_name()])
			_update_progress()
			_set_active_speaker("player")
			var player_response := await _get_player_dialogue()
			if manual_action_resolved:
				return
			if bool(player_response.get("cancelled", false)):
				return
			if player_response.has("error"):
				_show_error(player_response.get("error", ""))
				return
			var speech := String(player_response.get("speech", "我想先听听你的看法。")).strip_edges()
			var raw_action := String(player_response.get("action", "none")).strip_edges().to_lower()
			state.add_dialogue("player", speech)
			await _finish_speech_stream("你方", speech, Color(0.58, 0.82, 1.0, 1.0))
			if manual_action_resolved:
				return
			if raw_action != "" and raw_action != "none":
				var resolved := await _resolve_decided_action(raw_action, {"artifact_id": String(player_response.get("artifact_id", ""))}, "即时行动")
				if resolved:
					return
			_set_status_text("第 %d 回合：%s" % [state.chapter_round + 1, _current_dialogue_scene_name()])
			_set_active_speaker("npc")
			var npc_response := await _get_npc_dialogue()
			if manual_action_resolved:
				return
			if npc_response.has("error"):
				_show_error(npc_response.get("error", ""))
				return
			var npc_speech := String(npc_response.get("speech", "NPC response.")).strip_edges()
			state.add_dialogue("npc", npc_speech)
			await _finish_speech_stream("NPC", npc_speech, Color(1.0, 0.61, 0.48, 1.0))
			if manual_action_resolved:
				return
			var accepted_response := await _confirm_npc_offer(npc_response)
			for event in RulesEngineScript.apply_dialogue_turn(state, speech, npc_speech, accepted_response):
				_append_system_log(event)
				_mark_event_cards(event)
			_update_state_panel()
			if bool(player_response.get("end_dialogue", false)):
				break
			await get_tree().create_timer(0.2).timeout
		if state.ended:
			return
		if manual_action_resolved:
			return
		var response := await _get_post_action()
		if manual_action_resolved:
			return
		if bool(response.get("cancelled", false)):
			return
		var post_resolved := await _resolve_decided_action(String(response.get("action", "leave")), {"artifact_id": String(response.get("artifact_id", ""))}, "对话结束行动")
		if post_resolved:
			return
		_append_system_log("你取消了行动，角色继续聊天。")
		state.turn = max(0, state.max_dialogue_turns - 1)
	if not state.ended and not manual_action_resolved:
		await _resolve_action("leave", {}, "对话结束行动")


func _resolve_decided_action(action: String, payload: Dictionary, label: String) -> bool:
	var normalized := RulesEngineScript.normalize_action(action)
	if auto_decide_check != null and auto_decide_check.button_pressed:
		await _resolve_action(normalized, payload, label)
		return true
	var confirmed := await _confirm_player_action(normalized, payload, label)
	if not confirmed:
		return false
	await _resolve_action(normalized, payload, label)
	return true


func _on_manual_action_pressed(action: String) -> void:
	if not running or state == null or state.ended:
		return
	if lower_box == null or not lower_box.visible:
		return
	if manual_action_in_progress or manual_action_resolved:
		return
	manual_action_in_progress = true
	if llm_client != null and llm_client.has_method("cancel_section"):
		llm_client.cancel_section("player_llm")
	var normalized := RulesEngineScript.normalize_action(action)
	var payload := {}
	if normalized == "gift" or normalized == "cast":
		var artifact_id := await _choose_action_artifact(normalized)
		if artifact_id.is_empty():
			manual_action_in_progress = false
			return
		payload["artifact_id"] = artifact_id
	await _resolve_action(normalized, payload, "手动行动")
	manual_action_resolved = true
	manual_action_in_progress = false


func _confirm_player_action(action: String, payload: Dictionary, label: String) -> bool:
	action_choice = 0
	action_panel.visible = true
	action_panel.move_to_front()
	_clear_children(action_box)
	_add_panel_label(action_box, "确认%s" % label)
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", Color(0.92, 0.98, 0.94, 1.0))
	_apply_ui_font(detail)
	var artifact_id := String(payload.get("artifact_id", ""))
	var artifact_text := ""
	if not artifact_id.is_empty():
		artifact_text = "\n法器：%s" % state.artifact_name(artifact_id)
	detail.text = "你方角色决定执行：%s%s\n是否允许？" % [_action_name(action), artifact_text]
	action_box.add_child(detail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	action_box.add_child(row)
	var confirm := Button.new()
	confirm.text = "确定"
	confirm.custom_minimum_size = Vector2(0, 44)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_ui_font(confirm)
	confirm.pressed.connect(func(): action_choice = 1)
	row.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_ui_font(cancel)
	cancel.pressed.connect(func(): action_choice = -1)
	row.add_child(cancel)
	_wire_button_feedback([confirm, cancel])
	while action_choice == 0 and running and not state.ended:
		await get_tree().process_frame
	action_panel.visible = false
	return action_choice == 1


func _choose_action_artifact(action: String) -> String:
	var inventory: Array = state.player.get("inventory", [])
	if inventory.is_empty():
		_show_result_banner("%s需要先拥有法器" % _action_name(action), Color(1.0, 0.36, 0.32, 1.0))
		return ""
	action_choice = 0
	selected_action_artifact = ""
	action_panel.visible = true
	action_panel.move_to_front()
	_clear_children(action_box)
	_add_panel_label(action_box, "选择%s法器" % _action_name(action))
	var detail := Label.new()
	detail.text = "选择要用于%s的法器。" % _action_name(action)
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", Color(0.92, 0.98, 0.94, 1.0))
	_apply_ui_font(detail)
	action_box.add_child(detail)
	var counts := _artifact_counts(inventory)
	for artifact_id in counts.keys():
		var id := String(artifact_id)
		var button := Button.new()
		button.text = "%s x%d" % [state.artifact_name(id), int(counts[id])]
		button.custom_minimum_size = Vector2(0, 42)
		_apply_ui_font(button)
		button.pressed.connect(Callable(self, "_select_action_artifact").bind(id))
		action_box.add_child(button)
		_wire_button_feedback([button])
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(0, 42)
	_apply_ui_font(cancel)
	cancel.pressed.connect(func(): action_choice = -1)
	action_box.add_child(cancel)
	_wire_button_feedback([cancel])
	while action_choice == 0 and running and not state.ended:
		await get_tree().process_frame
	action_panel.visible = false
	if action_choice == 1:
		return selected_action_artifact
	return ""


func _select_action_artifact(artifact_id: String) -> void:
	selected_action_artifact = artifact_id
	action_choice = 1


func _resolve_action(action: String, payload: Dictionary, label: String) -> void:
	for event in RulesEngineScript.resolve_player_action(state, action, payload):
		_append_system_log(event)
		_mark_event_cards(event)
	_show_result_banner("%s：%s" % [label, _action_name(action)], _action_color(action))
	_update_state_panel()
	await get_tree().create_timer(0.35).timeout


func _run_shop_ui() -> void:
	_set_dialogue_visible(false)
	shop_done = false
	_render_shop()
	_set_status_text("第 %d 回合：%s" % [state.chapter_round + 1, _shop_scene_name()])
	while not shop_done and running and not state.ended:
		await get_tree().process_frame
	if shop_panel != null:
		shop_panel.visible = false


func _confirm_npc_offer(npc_response: Dictionary) -> Dictionary:
	if not npc_response.has("gift_offer") and not npc_response.has("exchange_offer"):
		return npc_response
	trade_choice = 0
	trade_panel.visible = true
	trade_panel.move_to_front()
	_clear_children(trade_box)
	_add_panel_label(trade_box, "NPC 提出法器交易")
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", Color(0.92, 0.98, 0.94, 1.0))
	_apply_ui_font(detail)
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
	_apply_ui_font(accept)
	accept.pressed.connect(func(): trade_choice = 1)
	trade_box.add_child(accept)
	var reject := Button.new()
	reject.text = "拒绝"
	reject.custom_minimum_size = Vector2(0, 42)
	_apply_ui_font(reject)
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
	_append_system_log("You declined the NPC trade.")
	return cleaned


func _render_shop() -> void:
	_set_dialogue_visible(false)
	if shop_panel != null:
		shop_panel.queue_free()
	shop_panel = _instantiate_flow_page(ShopPageScene)
	add_child(shop_panel)
	shop_box = shop_panel
	_populate_shop_page()
	shop_panel.visible = true


func _populate_shop_page() -> void:
	var bg := shop_panel.get_node_or_null("Background") as TextureRect
	if bg != null:
		bg.texture = _load_texture_any(_current_shop_background_path())
		bg.material = _shop_blur_material()
	var title_banner := shop_panel.get_node_or_null("TitleBanner") as TextureRect
	if title_banner != null:
		title_banner.texture = _shop_texture("shop_title_banner_red.png")
	var title := shop_panel.get_node_or_null("TitleLabel") as Label
	if title != null:
		title.text = _shop_scene_name()
		title.add_theme_color_override("font_color", Color.WHITE)
		title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
		title.add_theme_constant_override("outline_size", 4)
	_apply_shop_status_bar()
	_apply_shop_player_card()
	_apply_shop_requirement_panel(shop_panel.get_node_or_null("AscensionRequirement") as PanelContainer, "升华需求", state.player.get("ascension_requirement", []), state.player.get("inventory", []), "red")
	_apply_shop_requirement_panel(shop_panel.get_node_or_null("DominionRequirement") as PanelContainer, "统治需求", state.player.get("dominion_requirement", []), state.player.get("artifact_history", []), "teal")
	var item_title := shop_panel.get_node_or_null("ShopItemsTitle") as Label
	if item_title != null:
		item_title.text = "可购买法器"
		item_title.add_theme_stylebox_override("normal", _shop_texture_style("shop_section_title_teal.png", 18))
		item_title.add_theme_color_override("font_color", Color.WHITE)
		item_title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
		item_title.add_theme_constant_override("outline_size", 4)
	_apply_shop_items()
	_apply_shop_backpack_panel()


func _apply_shop_status_bar() -> void:
	var panel := shop_panel.get_node_or_null("StatusBar") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", _shop_texture_style("shop_status_bar_dark.png", 26))
	var energy := shop_panel.get_node_or_null("StatusBar/StatusRow/EnergyLabel") as Label
	if energy != null:
		energy.text = "◇ 能量 %d" % int(state.player.get("energy", 0))
		energy.add_theme_color_override("font_color", Color(1.0, 0.30, 0.28, 1.0))
	var inventory := shop_panel.get_node_or_null("StatusBar/StatusRow/InventoryLabel") as Label
	if inventory != null:
		inventory.text = "袋 背包 %d" % state.player.get("inventory", []).size()
		inventory.add_theme_color_override("font_color", Color(1.0, 0.73, 0.16, 1.0))


func _apply_shop_player_card() -> void:
	var panel := shop_panel.get_node_or_null("PlayerCard") as PanelContainer
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _shop_texture_style("shop_player_card_red.png", 34))
	var portrait := panel.get_node_or_null("PlayerContent/Portrait") as TextureRect
	if portrait != null:
		_set_texture_or_fallback(portrait, "res://assets/generated/ui/card/avatar_fox_card.png", "res://assets/generated/player_portrait.png")
	var name := panel.get_node_or_null("PlayerContent/NamePlate") as Label
	if name != null:
		name.text = _player_short_name()
		name.add_theme_stylebox_override("normal", _shop_texture_style("shop_nameplate_red.png", 18))
		name.add_theme_color_override("font_color", Color.WHITE)
	var stats := panel.get_node_or_null("PlayerContent/Stats") as VBoxContainer
	if stats == null:
		return
	_clear_children(stats)
	for row in _player_stat_rows():
		stats.add_child(_make_shop_stat_row(String(row[0]), String(row[1])))


func _apply_shop_requirement_panel(panel: PanelContainer, title: String, required: Array, owned: Array, tone: String) -> void:
	if panel == null:
		return
	var panel_asset := "shop_requirement_panel_red.png" if tone == "red" else "shop_requirement_panel_teal.png"
	panel.add_theme_stylebox_override("panel", _shop_texture_style(panel_asset, 24))
	var title_label := panel.get_node_or_null("Box/Title") as Label
	if title_label != null:
		title_label.text = title
		title_label.add_theme_stylebox_override("normal", _shop_texture_style("shop_requirement_title_red.png" if tone == "red" else "shop_requirement_title_teal.png", 18))
		title_label.add_theme_color_override("font_color", Color.WHITE)
	var slots := panel.get_node_or_null("Box/Slots") as HBoxContainer
	if slots == null:
		return
	_clear_children(slots)
	for i in range(4):
		if i < required.size():
			var artifact_id := String(required[i])
			slots.add_child(_make_artifact_slot(artifact_id, artifact_id in owned, _artifact_count(owned, artifact_id)))
		else:
			slots.add_child(_make_artifact_slot("", false, 0))


func _apply_shop_items() -> void:
	var slots := shop_panel.get_node_or_null("ShopItemSlots") as Control
	if slots == null:
		return
	for i in range(3):
		var card := slots.get_node_or_null("ShopItem%d" % [i + 1]) as PanelContainer
		if card == null:
			continue
		card.visible = i < state.shop_items.size()
		if card.visible:
			_apply_shop_item_card(card, String(state.shop_items[i]), i)


func _apply_shop_item_card(card: PanelContainer, artifact_id: String, index: int) -> void:
	var tones := ["red", "teal", "purple"]
	var tone: String = String(tones[index % tones.size()])
	var artifact: Dictionary = state.get_artifact(artifact_id)
	card.add_theme_stylebox_override("panel", _shop_texture_style("shop_item_card_%s.png" % tone, 20))
	var card_texture := card.get_node_or_null("CardTexture") as TextureRect
	if card_texture != null:
		card_texture.visible = false
	var frame := card.get_node_or_null("Content/ArtifactFrame") as PanelContainer
	if frame != null:
		frame.add_theme_stylebox_override("panel", _shop_texture_style("shop_artifact_frame_%s.png" % tone, 18))
	var icon := card.get_node_or_null("Content/ArtifactFrame/ArtifactIcon") as TextureRect
	if icon != null:
		_set_texture_or_fallback(icon, _artifact_icon_path(artifact_id), "res://assets/generated/ui/card/artifact_moon_lantern.png")
	var title := card.get_node_or_null("Content/NameLabel") as Label
	if title != null:
		title.text = String(artifact.get("name", artifact_id))
	var price := int(artifact.get("price", 0))
	var can_afford := int(state.player.get("energy", 0)) >= price
	var price_label := card.get_node_or_null("Content/PriceLabel") as Label
	if price_label != null:
		price_label.text = "◇ %d" % price
		price_label.add_theme_stylebox_override("normal", _shop_texture_style("shop_price_plate_dark.png", 18))
		price_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.18, 1.0) if can_afford else Color(1.0, 0.40, 0.34, 1.0))
	var button := card.get_node_or_null("Content/BuyButton") as Button
	if button != null:
		_style_shop_button(button, "购买", can_afford)
		button.tooltip_text = String(artifact.get("story", ""))
		button.disabled = not can_afford
		button.pressed.connect(func(item_id := artifact_id):
			for event in RulesEngineScript.buy_player_artifact(state, item_id):
				_append_system_log(event)
			_update_state_panel()
			_render_shop()
		)
		_wire_button_feedback([button])


func _apply_shop_backpack_panel() -> void:
	var panel := shop_panel.get_node_or_null("BackpackPanel") as PanelContainer
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _shop_texture_style("shop_backpack_panel_purple.png", 24))
	var title := panel.get_node_or_null("BackpackContent/BackpackTitle") as Label
	if title != null:
		title.text = "我的背包"
		title.add_theme_stylebox_override("normal", _shop_texture_style("shop_backpack_title_purple.png", 18))
		title.add_theme_color_override("font_color", Color.WHITE)
	var grid := panel.get_node_or_null("BackpackContent/BackpackGrid") as GridContainer
	if grid != null:
		_clear_children(grid)
		var counts := _artifact_counts(state.player.get("inventory", []))
		var shown := 0
		for artifact_id in counts.keys():
			grid.add_child(_make_artifact_slot(String(artifact_id), true, int(counts[artifact_id])))
			shown += 1
		while shown < 6:
			grid.add_child(_make_artifact_slot("", false, 0))
			shown += 1
	var leave := panel.get_node_or_null("BackpackContent/LeaveButton") as Button
	if leave != null:
		_style_shop_button(leave, "离开商店", true)
		leave.pressed.connect(func(): shop_done = true)
		_wire_button_feedback([leave])


func _build_shop_status_bar() -> void:
	var player_energy := int(state.player.get("energy", 0))
	var inventory: Array = state.player.get("inventory", [])
	var panel := _make_shop_panel("shop_status_bar_dark.png", 26)
	_place_ratio(panel, Rect2(0.695, 0.070, 0.265, 0.060))
	shop_box.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_make_shop_resource_label("◇ 能量", str(player_energy), Color(1.0, 0.30, 0.28, 1.0)))
	row.add_child(_make_shop_resource_label("袋 背包", str(inventory.size()), Color(1.0, 0.73, 0.16, 1.0)))


func _build_shop_scene_background(parent: Control) -> void:
	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _load_texture_any(_current_shop_background_path())
	bg.material = _shop_blur_material()
	parent.add_child(bg)
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.0, 0.0, 0.0, 0.56)
	parent.add_child(veil)


func _build_shop_title_banner() -> void:
	var banner := TextureRect.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_ratio(banner, Rect2(0.000, 0.055, 0.475, 0.150))
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	banner.texture = _shop_texture("shop_title_banner_red.png")
	shop_box.add_child(banner)
	var title := _make_shop_text_label(_shop_scene_name(), 48, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place_ratio(title, Rect2(0.040, 0.083, 0.300, 0.080))
	shop_box.add_child(title)


func _build_shop_player_card() -> void:
	var panel := _make_shop_panel("shop_player_card_red.png", 34)
	_place_ratio(panel, Rect2(0.030, 0.220, 0.220, 0.720))
	shop_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 235)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_set_texture_or_fallback(portrait, "res://assets/generated/ui/card/avatar_fox_card.png", "res://assets/generated/player_portrait.png")
	box.add_child(portrait)
	var name_plate := _make_shop_plate_label(_player_short_name(), "shop_nameplate_red.png", 24, Vector2(0, 46))
	box.add_child(name_plate)
	for row in _player_stat_rows():
		box.add_child(_make_shop_stat_row(String(row[0]), String(row[1])))


func _build_shop_requirement_panel(title: String, required: Array, owned: Array, rect: Rect2, tone: String) -> void:
	var panel_asset := "shop_requirement_panel_red.png" if tone == "red" else "shop_requirement_panel_teal.png"
	var panel := _make_shop_panel(panel_asset, 24)
	_place_ratio(panel, rect)
	shop_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_shop_plate_label(title, "shop_requirement_title_red.png" if tone == "red" else "shop_requirement_title_teal.png", 20, Vector2(0, 36)))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 5)
	box.add_child(slots)
	for i in range(4):
		if i < required.size():
			var artifact_id := String(required[i])
			slots.add_child(_make_artifact_slot(artifact_id, artifact_id in owned, _artifact_count(owned, artifact_id)))
		else:
			slots.add_child(_make_artifact_slot("", false, 0))


func _build_shop_item_card(artifact_id: String, rect: Rect2, index: int) -> void:
	var artifact: Dictionary = state.get_artifact(artifact_id)
	var tones := ["red", "teal", "purple"]
	var tone: String = String(tones[index % tones.size()])
	var asset := "shop_item_card_%s.png" % tone
	var panel := _make_shop_panel(asset, 20)
	_place_ratio(panel, rect)
	shop_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_make_shop_artifact_icon(artifact_id, "shop_artifact_frame_%s.png" % tone, Vector2(0, 106)))
	var title := _make_shop_text_label(String(artifact.get("name", artifact_id)), 21, Color.WHITE)
	title.custom_minimum_size = Vector2(0, 34)
	box.add_child(title)
	var price := int(artifact.get("price", 0))
	var can_afford := int(state.player.get("energy", 0)) >= price
	var price_label := _make_shop_plate_label("◇ %d" % price, "shop_price_plate_dark.png", 23, Vector2(0, 40))
	price_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.18, 1.0) if can_afford else Color(1.0, 0.40, 0.34, 1.0))
	box.add_child(price_label)
	var button: Button = _make_shop_button("购买", can_afford)
	button.custom_minimum_size = Vector2(0, 44)
	button.tooltip_text = String(artifact.get("story", ""))
	button.disabled = not can_afford
	button.pressed.connect(func(item_id := artifact_id):
		for event in RulesEngineScript.buy_player_artifact(state, item_id):
			_append_system_log(event)
		_update_state_panel()
		_render_shop()
	)
	box.add_child(button)
	_wire_button_feedback([button])


func _build_shop_backpack_panel() -> void:
	var panel := _make_shop_panel("shop_backpack_panel_purple.png", 24)
	_place_ratio(panel, Rect2(0.805, 0.240, 0.165, 0.665))
	shop_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_shop_plate_label("我的背包", "shop_backpack_title_purple.png", 22, Vector2(0, 42)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var counts := _artifact_counts(state.player.get("inventory", []))
	var shown := 0
	for artifact_id in counts.keys():
		grid.add_child(_make_artifact_slot(String(artifact_id), true, int(counts[artifact_id])))
		shown += 1
	while shown < 6:
		grid.add_child(_make_artifact_slot("", false, 0))
		shown += 1
	var leave: Button = _make_shop_button("离开商店", true)
	leave.custom_minimum_size = Vector2(0, 46)
	leave.pressed.connect(func(): shop_done = true)
	box.add_child(leave)
	_wire_button_feedback([leave])


func _add_shop_icon(parent: Control, rect: Rect2, path: String) -> void:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.anchor_left = rect.position.x
	icon.anchor_top = rect.position.y
	icon.anchor_right = rect.position.x + rect.size.x
	icon.anchor_bottom = rect.position.y + rect.size.y
	icon.offset_left = 0
	icon.offset_top = 0
	icon.offset_right = 0
	icon.offset_bottom = 0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture_or_fallback(icon, path, "res://assets/generated/ui/card/artifact_moon_lantern.png")
	parent.add_child(icon)


func _add_shop_plate(parent: Control, rect: Rect2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = rect.position.x
	label.anchor_top = rect.position.y
	label.anchor_right = rect.position.x + rect.size.x
	label.anchor_bottom = rect.position.y + rect.size.y
	label.offset_left = 0
	label.offset_top = 0
	label.offset_right = 0
	label.offset_bottom = 0
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	parent.add_child(label)
	return label


func _make_shop_panel(asset: String, margin: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _shop_texture_style(asset, margin))
	return panel


func _make_shop_plate_label(text: String, asset: String, font_size: int, min_size := Vector2.ZERO) -> Label:
	var label := _make_shop_text_label(text, font_size, Color.WHITE)
	label.custom_minimum_size = min_size
	label.add_theme_stylebox_override("normal", _shop_texture_style(asset, 18))
	return label


func _make_shop_stat_row(label_text: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_constant_override("separation", 8)
	row.add_theme_stylebox_override("panel", _shop_texture_style("shop_stat_row_dark.png", 16))
	var label := _make_shop_text_label(label_text, 18, Color(1.0, 0.93, 0.78, 1.0))
	label.custom_minimum_size = Vector2(92, 0)
	row.add_child(label)
	var value_label := _make_shop_text_label(value, 22, Color.WHITE)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	return row


func _make_shop_artifact_icon(artifact_id: String, frame_asset: String, min_size: Vector2) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = min_size
	frame.add_theme_stylebox_override("panel", _shop_texture_style(frame_asset, 18))
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture_or_fallback(icon, _artifact_icon_path(artifact_id), "res://assets/generated/ui/card/artifact_moon_lantern.png")
	frame.add_child(icon)
	return frame


func _make_shop_button(text: String, enabled: bool) -> Button:
	var button := Button.new()
	_style_shop_button(button, text, enabled)
	return button


func _style_shop_button(button: Button, text: String, enabled: bool) -> void:
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color(0.08, 0.035, 0.0, 1.0) if enabled else Color(0.70, 0.66, 0.58, 1.0))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.30, 0.38) if enabled else Color(0.0, 0.0, 0.0, 0.4))
	button.add_theme_stylebox_override("normal", _shop_texture_style("shop_button_gold.png" if enabled else "shop_button_disabled.png", 24))
	button.add_theme_stylebox_override("hover", _shop_texture_style("shop_button_gold.png" if enabled else "shop_button_disabled.png", 24))
	button.add_theme_stylebox_override("pressed", _shop_texture_style("shop_button_gold.png" if enabled else "shop_button_disabled.png", 24))
	button.add_theme_stylebox_override("disabled", _shop_texture_style("shop_button_disabled.png", 24))


func _style_primary_button(button: Button, text: String, font_size: int) -> void:
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.06, 0.025, 0.0, 1.0))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(1.0, 0.86, 0.25, 0.35))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	_apply_primary_button_texture(button, text, font_size)


func _make_shop_resource_label(label_text: String, value: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var label := _make_shop_text_label(label_text, 19, Color(1.0, 0.93, 0.78, 1.0))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := _make_shop_text_label(value, 27, color)
	value_label.custom_minimum_size = Vector2(48, 0)
	row.add_child(value_label)
	return row


func _add_shop_title_plate(text: String, rect: Rect2, tone: String) -> void:
	var label := _make_shop_plate_label(text, "shop_section_title_teal.png", 26, Vector2(0, 54))
	_place_ratio(label, rect)
	shop_box.add_child(label)


func _make_shop_text_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	return label


func _shop_texture_style(asset: String, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _shop_texture(asset)
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = max(8, margin / 2)
	style.content_margin_right = max(8, margin / 2)
	style.content_margin_top = max(8, margin / 2)
	style.content_margin_bottom = max(8, margin / 2)
	return style


func _shop_texture(asset: String) -> Texture2D:
	return _load_texture_any(SHOP_UI_ROOT + asset)


func _current_shop_background_path() -> String:
	var npc: Dictionary = state.current_npc() if state != null else {}
	var background_name := String(npc.get("background", "bg_moon_market.png"))
	if background_name.is_empty():
		background_name = "bg_moon_market.png"
	return "res://assets/generated/%s" % background_name


func _current_dialogue_scene_name() -> String:
	var npc: Dictionary = state.current_npc() if state != null else {}
	var background_name := String(npc.get("background", "bg_moon_market.png"))
	return _scene_name_from_background(background_name)


func _round_select_scene_name() -> String:
	return "赤金街口"


func _shop_scene_name() -> String:
	return "夜市法器铺"


func _ascension_scene_name() -> String:
	return "升华祭坛"


func _scene_name_from_background(background_name: String) -> String:
	match background_name:
		"bg_archive_hall.png":
			return "旧档案馆"
		"bg_embassy_garden.png":
			return "使节花园"
		"bg_duel_alley.png":
			return "暗巷药铺"
		"bg_border_gate.png":
			return "边境关门"
		"bg_moon_market.png":
			return "月息夜市"
		_:
			return "赤金夜市"


func _shop_blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float blur_amount = 1.6;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 c = texture(TEXTURE, UV) * 0.30;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.12;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.12;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.12;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.12;
	c += texture(TEXTURE, UV + px) * 0.11;
	c += texture(TEXTURE, UV - px) * 0.11;
	COLOR = vec4(c.rgb * 0.72, c.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _make_artifact_slot(artifact_id: String, satisfied: bool, count: int) -> Control:
	var slot := ArtifactSlotScene.instantiate() as PanelContainer
	slot.custom_minimum_size = Vector2(58, 58)
	var slot_asset := "shop_slot_filled_red.png" if satisfied else "shop_slot_missing_dark.png"
	if artifact_id.is_empty():
		slot_asset = "shop_slot_empty.png"
	slot.add_theme_stylebox_override("panel", _shop_texture_style(slot_asset, 16))
	var icon := slot.get_node_or_null("Root/Icon") as TextureRect
	if icon != null:
		icon.visible = not artifact_id.is_empty()
	if not artifact_id.is_empty() and icon != null:
		icon.modulate.a = 1.0 if satisfied else 0.34
		_set_texture_or_fallback(icon, _artifact_icon_path(artifact_id), "res://assets/generated/ui/card/artifact_moon_lantern.png")
		slot.tooltip_text = state.artifact_name(artifact_id)
	var badge_panel := slot.get_node_or_null("Root/Badge") as PanelContainer
	if badge_panel != null:
		badge_panel.visible = count > 1 and not artifact_id.is_empty()
		badge_panel.add_theme_stylebox_override("panel", _shop_texture_style("shop_count_badge_dark.png", 10))
	var badge := slot.get_node_or_null("Root/Badge/CountLabel") as Label
	if badge != null:
		badge.text = str(count)
	return slot


func _artifact_icon_path(artifact_id: String) -> String:
	return "res://assets/generated/ui/card/artifact_%s.png" % artifact_id


func _artifact_count(items: Array, artifact_id: String) -> int:
	var total := 0
	for item in items:
		if String(item) == artifact_id:
			total += 1
	return total


func _place_ratio(node: Control, rect: Rect2) -> void:
	node.anchor_left = rect.position.x
	node.anchor_top = rect.position.y
	node.anchor_right = rect.position.x + rect.size.x
	node.anchor_bottom = rect.position.y + rect.size.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0

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
	upgrade_panel = _instantiate_flow_page(AscensionPageScene)
	add_child(upgrade_panel)
	ascension_box = upgrade_panel
	_populate_ascension_page(can_ascend, can_dominate)
	upgrade_panel.visible = true
	_set_status_text("第 %d 回合：%s" % [state.chapter_round + 1, _ascension_scene_name()])


func _populate_ascension_page(can_ascend: bool, can_dominate: bool) -> void:
	var stat_buttons := {
		"hp": ["HpMinusButton", "HpPlusButton"],
		"frontal_attack": ["FrontalAttackMinusButton", "FrontalAttackPlusButton"],
		"frontal_defense": ["FrontalDefenseMinusButton", "FrontalDefensePlusButton"],
		"assassination_attack": ["AssassinationAttackMinusButton", "AssassinationAttackPlusButton"],
		"assassination_defense": ["AssassinationDefenseMinusButton", "AssassinationDefensePlusButton"],
		"charm": ["CharmMinusButton", "CharmPlusButton"]
	}
	for stat in stat_buttons.keys():
		var paths: Array = stat_buttons[stat]
		var minus := upgrade_panel.get_node_or_null("StatControls/%s" % String(paths[0])) as Button
		var plus := upgrade_panel.get_node_or_null("StatControls/%s" % String(paths[1])) as Button
		if minus != null:
			_style_primary_button(minus, "−", 22)
			minus.pressed.connect(func(s := String(stat)): _change_pending_stat(s, -1, can_ascend, can_dominate))
			_wire_button_feedback([minus])
		if plus != null:
			_style_primary_button(plus, "+", 22)
			plus.pressed.connect(func(s := String(stat)): _change_pending_stat(s, 1, can_ascend, can_dominate))
			_wire_button_feedback([plus])
	var confirm := upgrade_panel.get_node_or_null("AscendConfirmButton") as Button
	if confirm != null:
		_style_primary_button(confirm, "确认升华", 24)
		confirm.pressed.connect(func():
			var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
			for event in RulesEngineScript.ascend_player(state, gains):
				_append_system_log(event)
			upgrade_done = true
		)
		confirm.disabled = not can_ascend or pending_stat_points > 0
		_wire_button_feedback([confirm])
	var dominion := upgrade_panel.get_node_or_null("DominionButton") as Button
	if dominion != null:
		_style_primary_button(dominion, "选择统治", 24)
		dominion.pressed.connect(func():
			state.player_declared_dominion = true
			for event in RulesEngineScript.finish_round(state):
				_append_system_log(event)
				_mark_event_cards(event)
			upgrade_done = true
		)
		dominion.disabled = not can_dominate
		_wire_button_feedback([dominion])

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
		["能量", str(int(state.player.get("energy", 0)))],
		["等级", str(int(state.player.get("level", 1)))],
		["统治", state.dominion_progress(state.player)],
		["背包", str(state.player.get("inventory", []).size())]
	]


func _stat_defs() -> Array:
	return [
		["hp", "生命"],
		["frontal_attack", "正攻"],
		["frontal_defense", "正防"],
		["assassination_attack", "暗攻"],
		["assassination_defense", "暗防"],
		["charm", "魅力"]
	]


func _place_by_ratio(node: Control, rect: Rect2) -> void:
	node.anchor_left = rect.position.x
	node.anchor_top = rect.position.y
	node.anchor_right = rect.position.x + rect.size.x
	node.anchor_bottom = rect.position.y + rect.size.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0


func _load_texture_any(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _round_texture(name: String) -> Texture2D:
	return _load_texture_any(ROUND_UI_ROOT + name)


func _round_texture_style(name: String, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _round_texture(name)
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = max(6, margin / 2)
	style.content_margin_right = max(6, margin / 2)
	style.content_margin_top = max(4, margin / 3)
	style.content_margin_bottom = max(4, margin / 3)
	return style


func _icon_tile_name(icon_name: String) -> String:
	return "icon_tile_%s" % icon_name.trim_prefix("icon_")


func _apply_primary_button_texture(button: Button, text: String, font_size: int) -> void:
	var bg := button.get_node_or_null("PrimaryButtonBackground") as TextureRect
	if bg == null:
		bg = TextureRect.new()
		bg.name = "PrimaryButtonBackground"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		button.add_child(bg)
		button.move_child(bg, 0)
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0
	bg.texture = _round_texture("button_primary_gold_normal.png")

	var label := button.get_node_or_null("PrimaryButtonLabel") as Label
	if label == null:
		label = Label.new()
		label.name = "PrimaryButtonLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(label)
	label.offset_left = 0
	label.offset_top = 0
	label.offset_right = 0
	label.offset_bottom = 0
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.06, 0.025, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.86, 0.25, 0.35))

	button.set_meta("primary_button_normal", "button_primary_gold_normal.png")
	button.set_meta("primary_button_hover", "button_primary_gold_hover.png")
	button.set_meta("primary_button_pressed", "button_primary_gold_pressed.png")
	button.set_meta("primary_button_disabled", "button_disabled_dark.png")
	if not button.has_meta("primary_button_texture_wired"):
		button.set_meta("primary_button_texture_wired", true)
		button.mouse_entered.connect(func(): _update_primary_button_texture(button))
		button.mouse_exited.connect(func(): _update_primary_button_texture(button))
		button.button_down.connect(func(): _update_primary_button_texture(button))
		button.button_up.connect(func(): _update_primary_button_texture(button))
		button.toggled.connect(func(_pressed: bool): _update_primary_button_texture(button))
	_update_primary_button_texture(button)


func _update_primary_button_texture(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var bg := button.get_node_or_null("PrimaryButtonBackground") as TextureRect
	if bg == null:
		return
	var asset := String(button.get_meta("primary_button_normal", "button_primary_gold_normal.png"))
	if button.disabled:
		asset = String(button.get_meta("primary_button_disabled", "button_disabled_dark.png"))
	elif button.button_pressed:
		asset = String(button.get_meta("primary_button_pressed", "button_primary_gold_pressed.png"))
	elif button.is_hovered():
		asset = String(button.get_meta("primary_button_hover", "button_primary_gold_hover.png"))
	bg.texture = _round_texture(asset)


func _select_card_shadow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = smoothstep(0.40, 1.0, UV.y) * 0.80;
	COLOR = vec4(0.0, 0.0, 0.0, alpha * tex.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _add_select_card_shadow_mask(parent: Control) -> TextureRect:
	var mask := TextureRect.new()
	mask.name = "BottomShadowMask"
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mask.material = _select_card_shadow_material()
	var card_texture := parent.get_node_or_null("CardTexture") as TextureRect
	if card_texture != null:
		mask.texture = card_texture.texture
		mask.stretch_mode = card_texture.stretch_mode
		mask.expand_mode = card_texture.expand_mode
	parent.add_child(mask)
	return mask


func _ensure_select_card_shadow_mask(parent: Control) -> void:
	if parent == null:
		return
	var mask := parent.get_node_or_null("BottomShadowMask") as TextureRect
	if mask == null:
		mask = _add_select_card_shadow_mask(parent)
	var card_texture := parent.get_node_or_null("CardTexture") as TextureRect
	if card_texture != null:
		mask.texture = card_texture.texture
		mask.stretch_mode = card_texture.stretch_mode
		mask.expand_mode = card_texture.expand_mode
		parent.move_child(mask, card_texture.get_index() + 1)


func _make_select_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.012, 0.014, 1.0))
	label.clip_text = true
	return label


func _make_select_stat_row(label_text: String, value_text: String, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _round_texture_style("button_secondary_blank.png", 0))
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	var name := Label.new()
	name.text = label_text
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82, 1.0))
	box.add_child(name)
	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_constant_override("outline_size", 2)
	value.add_theme_color_override("font_color", Color.WHITE)
	value.add_theme_color_override("font_outline_color", Color(0.015, 0.012, 0.014, 1.0))
	box.add_child(value)
	return row


func _select_card_path_for_npc(npc: Dictionary) -> String:
	var id := String(npc.get("id", ""))
	return "%s%s_select_card.png" % [SELECT_CARD_ROOT, id]


func _make_select_choose_button() -> Button:
	var button := Button.new()
	_style_primary_button(button, "选择", 24)
	return button


func _make_round_utility_button(label_text: String, icon_name: String, color: Color) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = label_text
	button.custom_minimum_size = Vector2(82, 82)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.custom_minimum_size = Vector2(82, 82)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _round_texture(_icon_tile_name(icon_name))
	button.add_child(icon)
	return button


func _round_utility_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


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


func _add_visible_hotspot_button(parent: Control, text: String, rect: Rect2, callback: Callable) -> Button:
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
	_style_primary_button(button, text, 24)
	button.pressed.connect(callback)
	parent.add_child(button)
	_wire_button_feedback([button])
	return button


func _add_final_reference_utility_hotspots(parent: Control) -> void:
	var specs := [
		[Rect2(0.916, 0.190, 0.050, 0.070), func(): _show_drawer("intel")],
		[Rect2(0.916, 0.285, 0.050, 0.070), func(): _show_drawer("bag")],
		[Rect2(0.916, 0.380, 0.050, 0.070), _show_history],
		[Rect2(0.916, 0.475, 0.050, 0.070), _toggle_rules],
		[Rect2(0.916, 0.570, 0.050, 0.070), func(): _show_drawer("status")],
		[Rect2(0.916, 0.665, 0.050, 0.070), _toggle_settings]
	]
	for i in range(specs.size()):
		var spec: Array = specs[i]
		_add_hotspot_button(parent, "工具", spec[0], spec[1])

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
	box.add_child(card_kit.make_plate_label("我的背包", "purple", 28, Vector2(0, 62)))
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
		empty.text = "暂无法器"
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
	if id.contains("wolf") or species.contains("狼"):
		return "avatar_wolf_card.png"
	return "avatar_fox_card.png"


func _npc_card_tag(npc: Dictionary, index: int) -> String:
	if index == 0:
		return "高风险"
	if index == 1:
		return "情报"
	return "同族"
func _make_card_utility_column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.anchor_left = 0.91
	box.anchor_top = 0.13
	box.anchor_right = 0.99
	box.anchor_bottom = 0.96
	box.add_theme_constant_override("separation", 12)
	var specs := [
		["情报", "icon_info.png", Color(0.02, 0.42, 0.38, 1.0), func(): _show_drawer("intel")],
		["背包", "icon_bag.png", Color(0.62, 0.38, 0.02, 1.0), func(): _show_drawer("bag")],
		["历史", "icon_history.png", Color(0.27, 0.16, 0.43, 1.0), _show_history],
		["规则", "icon_rules.png", Color(0.58, 0.08, 0.10, 1.0), _toggle_rules],
		["状态", "icon_status.png", Color(0.08, 0.30, 0.50, 1.0), func(): _show_drawer("status")],
		["设置", "icon_settings.png", Color(0.26, 0.27, 0.28, 1.0), _toggle_settings]
	]
	for spec in specs:
		var button: Button = card_kit.make_utility_button(String(spec[0]), String(spec[1]), spec[2])
		button.pressed.connect(spec[3])
		box.add_child(button)
		_wire_button_feedback([button])
	return box

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
	dialogue_title.text = "鎬濊€冧腑"
	dialogue_view.clear()
	_prepare_llm_stream("player_llm", "你方", Color(0.58, 0.82, 1.0, 1.0))
	if llm_client.use_mock_llm():
		var npc: Dictionary = state.current_npc()
		var mock := {}
		mock["thinking"] = "我先试探对方对世界设定和法器的理解，不急着动手。"
		mock["speech"] = "听说%s附近有些法器换手很快。若我们各有所需，也许能谈一笔交换。" % npc.get("territory", "这里")
		mock["action"] = "none"
		mock["artifact_id"] = ""
		mock["end_dialogue"] = state.turn >= state.max_dialogue_turns
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
	var inventory_text := "、".join(state.describe_inventory(state.player.get("inventory", [])))
	var ascension_text := "、".join(state.describe_inventory(state.player.get("ascension_requirement", [])))
	stats_label.text = "章节：%d / %d\n回合：%d / %d\n字符：%d / %d\n能量：%d\n等级：%d\n统治：%s\n背包：%s\n升华需求：%s\n生命：%d  魅力：%d\n正面：%d/%d  暗杀：%d/%d" % [
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
	state_view.append_text("[b]统治需求[/b]\n")
	for artifact_id in state.player.get("dominion_requirement", []):
		var mark := "已获得" if String(artifact_id) in state.player.get("artifact_history", []) else "未获得"
		state_view.append_text("- %s [%s]\n" % [state.artifact_name(String(artifact_id)), mark])
	state_view.append_text("\n[b]近期记忆[/b]\n")
	for item in state.recent_memory(state.player, 8):
		state_view.append_text("- %s\n" % _escape(String(item)))
	state_view.append_text("\n[b]情报卡[/b]\n")
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		var selected := String(state.selected_world_intel.get(question_id, "未选择"))
		var answer_title: String = state.world_intel_option_title(question_id, selected) if selected != "未选择" else selected
		state_view.append_text("- %s：%s\n" % [String(question.get("title", question_id)), answer_title])
	if state.ended:
		state_view.append_text("\n[b]结算[/b]\n%s\n" % state.end_reason)
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
	dialogue_title.text = "对话中"
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
	dialogue_title.text = "对话中"
	result_banner.visible = false
	dialogue_view.clear()
	_pop_control(dialogue_view)
	for i in range(0, speech.length(), 3):
		dialogue_view.append_text(_escape(speech.substr(i, 3)))
		_follow_dialogue_view(dialogue_view)
		await get_tree().create_timer(0.02).timeout


func _show_scene_message(text: String) -> void:
	dialogue_title.text = "场景"
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
	history_view.append_text("[b]对话历史[/b]\n")
	history_view.append_text(_escape(state.format_full_history()))
	if not state.event_log.is_empty():
		history_view.append_text("\n\n[b]行动与发现[/b]\n")
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
				title.text = "背包"
			"status":
				title.text = "状态"
			_:
				title.text = "情报"
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
		modal_backdrop.z_index = 4000
		modal_backdrop.visible = true
		modal_backdrop.move_to_front()
	for panel in [intel_panel, drawer, rules_panel, settings_panel, history_dialog, upgrade_panel]:
		if panel != null and panel.visible:
			panel.z_index = 4010
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
	var submit_button: Button = card_kit.make_primary_button("提交世界设定档案")
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
	source_label.text = "证词：%s" % ("暂无" if sources.is_empty() else " / ".join(sources))
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
		portrait.tooltip_text = "第%d章%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "NPC"))]
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
	_apply_ui_font(label)
	parent.add_child(label)


func _apply_ui_font(control: Control) -> void:
	var font := _load_ui_font()
	if font != null:
		control.add_theme_font_override("font", font)


func _load_ui_font() -> Font:
	if ResourceLoader.exists(UI_FONT_PATH):
		return load(UI_FONT_PATH)
	return null


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
		portrait.tooltip_text = "第%d章%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "NPC"))]
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
	dialog.dialog_text = "提交后无法修改。全部设定正确才会胜利，任意错误都会失败。"
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


func _wire_hold_hover_feedback(buttons: Array) -> void:
	for button in buttons:
		if button == null:
			continue
		if button.has_meta("hold_hover_feedback_wired"):
			continue
		button.set_meta("hold_hover_feedback_wired", true)
		button.mouse_entered.connect(func(): _hold_hover_enter(button))
		button.mouse_exited.connect(func(): _hold_hover_exit(button))
		button.pressed.connect(func(): _press_control(button))


func _hold_hover_enter(node: Control) -> void:
	_kill_feedback_tween(node)
	var tween := create_tween()
	node.set_meta("feedback_tween", tween)
	tween.tween_property(node, "scale", Vector2(1.035, 1.035), 0.08).set_trans(Tween.TRANS_QUAD)


func _hold_hover_exit(node: Control) -> void:
	_kill_feedback_tween(node)
	var tween := create_tween()
	node.set_meta("feedback_tween", tween)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)


func _kill_feedback_tween(node: Control) -> void:
	if node == null or not node.has_meta("feedback_tween"):
		return
	var tween = node.get_meta("feedback_tween")
	if tween is Tween and tween.is_valid():
		tween.kill()


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
		_set_status_text(state.end_reason)
		_show_result_banner(state.end_reason, Color(0.62, 1.0, 0.78, 1.0) if state.victory else Color(1.0, 0.36, 0.32, 1.0))
	start_button.disabled = false
	rules_edit.editable = true
	running = false


func _store_final_dialogue(speaker: String, speech: String) -> void:
	var npc_name := "NPC"
	if state != null and state.has_method("current_npc") and not state.current_npc().is_empty():
		npc_name = String(state.current_npc().get("public_name", "NPC"))
	var is_player := speaker == "你方" or speaker == _player_short_name()
	last_final_speaker = _player_short_name() if is_player else npc_name
	last_final_speech = speech
	last_final_role = "player" if is_player else "npc"


func _clear_last_final_dialogue() -> void:
	last_final_speaker = ""
	last_final_speech = ""
	last_final_role = "player"
	if upper_box != null:
		upper_box.visible = false
	if recent_view != null:
		recent_view.clear()


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
		upper_box.texture = load("res://assets/generated/ui/dialogue/dialogue_upper_red_full.png")
	if previous_nameplate != null:
		previous_nameplate.texture = load("res://assets/generated/ui/dialogue/nameplate_left_exact.png") if last_final_role == "player" else load("res://assets/generated/ui/dialogue/nameplate_right_exact.png")
		_place_dialogue_nameplate(previous_nameplate, last_final_role, last_final_speaker, true)
	if previous_speaker_label != null:
		previous_speaker_label.text = last_final_speaker
		_style_dialogue_name_label(previous_speaker_label, last_final_role)
		_place_dialogue_nameplate(previous_speaker_label, last_final_role, last_final_speaker, true)
	recent_view.clear()
	recent_view.append_text("[font_size=17][color=#130905]%s[/color][/font_size]" % _escape(last_final_speech))
	_follow_dialogue_view(recent_view)
	_animate_previous_dialogue()


func _set_current_dialogue_role(role: String) -> void:
	if lower_box != null:
		lower_box.texture = load("res://assets/generated/ui/dialogue/dialogue_lower_gold_full.png") if role == "player" else load("res://assets/generated/ui/dialogue/dialogue_red_blank.png")
		lower_box.move_to_front()
	if current_nameplate != null:
		current_nameplate.texture = load("res://assets/generated/ui/dialogue/nameplate_left_exact.png") if role == "player" else load("res://assets/generated/ui/dialogue/nameplate_right_exact.png")
	var speaker_name := _player_short_name() if role == "player" else String(state.current_npc().get("public_name", "NPC")) if state != null and not state.current_npc().is_empty() else "NPC"
	if current_speaker_label != null:
		current_speaker_label.text = speaker_name
		_style_dialogue_name_label(current_speaker_label, role)
	if current_nameplate != null:
		_place_dialogue_nameplate(current_nameplate, role, speaker_name, false)
	if current_speaker_label != null:
		_place_dialogue_nameplate(current_speaker_label, role, speaker_name, false)
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
	if progress_label != null:
		progress_label.visible = false
	for node in [status_label, info_button, bag_button, history_button, rules_button, status_button, settings_button]:
		if node != null:
			node.visible = visible
	if auto_decide_check != null:
		auto_decide_check.visible = visible
	for action_button in action_buttons.values():
		var button := action_button as Button
		if button != null:
			button.visible = visible
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


func _place_dialogue_nameplate(label: Control, role: String, speaker_name: String, is_previous: bool) -> void:
	var box_width := 953.0 if is_previous else 1339.0
	var min_texture_width := 184.0 if role == "player" else 209.0
	var char_width := 28.0
	var content_width: float = max(min_texture_width, float(speaker_name.length() + 3) * char_width)
	var width: float = clamp(content_width / box_width, 0.16 if is_previous else 0.18, 0.42 if is_previous else 0.36)
	var rect := Rect2()
	if is_previous:
		rect.position.y = -0.30 if role == "player" else -0.29
		rect.size.y = 0.42
		rect.position.x = 0.045 if role == "player" else 0.98 - width
	else:
		rect.position.y = -0.21 if role == "player" else -0.20
		rect.size.y = 0.31
		rect.position.x = 0.035 if role == "player" else 0.95 - width
	rect.size.x = width
	_place_label_relative(label, rect)


func _style_dialogue_name_label(label: Label, role: String) -> void:
	if role == "npc":
		label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.16, 1.0))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.22, 1.0))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))


func _follow_dialogue_view(view: RichTextLabel) -> void:
	if view == null:
		return
	view.scroll_following = true
	if view.has_method("scroll_to_line"):
		view.call_deferred("scroll_to_line", max(0, view.get_line_count() - 1))


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

