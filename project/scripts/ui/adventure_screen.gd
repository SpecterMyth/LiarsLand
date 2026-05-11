extends Control

const CHAPTER_PATH := "res://data/chapter_01.json"
const COUNCIL_CHAPTER_PATH := "res://data/council_chapter_01.json"
const COUNCIL_CHAPTER_PATHS := [
	"res://data/council_chapter_01.json",
	"res://data/council_chapter_02.json",
	"res://data/council_chapter_03.json"
]
const DEFAULT_IDENTITY_GUIDELINE := "## 对外身份\n来自边境的灰狐抄写员，替商队整理族谱与债契。\n\n## 对手应如何认知我\n- 以这份公开身份理解我的言行。\n- 不知道我的真实目标，除非我在对话中暴露。\n- 优先把我视为可以交易、试探、被利用或结盟的外来者。"
const DEFAULT_BEHAVIOR_GUIDELINE := "根据对方的问题进行回复"
const DEFAULT_GROWTH_GUIDELINE := "## 商店购买\n优先购买能满足当前升华需求或统治需求的法器；其次购买低价、可用于交换或施法的法器。不要花光能量购买无关法器。\n\n## 升华加点\n优先补足生存和交涉能力：生命、魅力、暗杀防御。若准备决斗或刺杀，再提高对应攻击属性。\n\n## 统治选择\n满足统治需求且本章信息收集足够时选择统治；若世界设定证词不足，优先继续成长。"
const DEFAULT_RULES := DEFAULT_BEHAVIOR_GUIDELINE

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const RulesEngineScript := preload("res://scripts/core/rules_engine.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")
const LlmClientScript := preload("res://scripts/llm/llm_client.gd")
const PromptBuilderScript := preload("res://scripts/llm/prompt_builder.gd")
const AdventureLayoutScript := preload("res://scripts/ui/adventure_layout.gd")
const CardUiKitScript := preload("res://scripts/ui/card_ui_kit.gd")
const ActionAnimationOverlayScript := preload("res://scripts/ui/action_animation_overlay.gd")
const StartMenuScript := preload("res://scripts/ui/start_menu.gd")
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")
const CommonFrameScript := preload("res://scripts/ui/common_frame.gd")
const RoundSelectPageScene := preload("res://scenes/ui/round_select_page.tscn")
const ShopPageScene := preload("res://scenes/ui/shop_page.tscn")
const AscensionPageScene := preload("res://scenes/ui/ascension_page.tscn")
const DeathPageScene := preload("res://scenes/ui/death_page.tscn")
const CouncilResultPageScript := preload("res://scripts/ui/council_result_page.gd")
const RightUtilityButtonsScene := preload("res://scenes/ui/right_utility_buttons.tscn")
const ArtifactSlotScene := preload("res://scenes/ui/artifact_slot.tscn")
const CommonModalScene := preload("res://scenes/ui/common_modal.tscn")
const ROUND_UI_ROOT := "res://assets/ui/common/"
const SELECT_CARD_ROOT := "res://assets/ui/characters/cards/"
const SHOP_UI_ROOT := "res://assets/ui/shop/"
const SHOP_COMMON_UI_ROOT := "res://assets/ui/common/"
const SHOP_LEGACY_UI_ROOT := "res://assets/generated/ui/shop_v2/"
const SHOP_MANIFEST_PATH := "res://../ui/source_pages/shop/page_manifest.json"
const LOCKED_NPC_SELECT_CARD_PATH := SELECT_CARD_ROOT + "npc_unknown_select_card.png"
const UI_FONT_PATH := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
const INVENTORY_CAPACITY := 40
const INVENTORY_REQUIREMENT_SLOT_SIZE := Vector2(116, 116)
const INVENTORY_ITEM_SLOT_SIZE := Vector2(116, 116)
const INVENTORY_REQUIREMENT_COLUMNS := 3
const INVENTORY_ITEM_COLUMNS := 8
const INVENTORY_MIN_REQUIREMENT_SLOTS := 6
const AUTO_CONFIRM_SECONDS := 10.0

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
var select_card_alpha_bounds_cache: Dictionary = {}
var inventory_grayscale_material: ShaderMaterial
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
var llm_retry_button: Button
var dialogue_view: RichTextLabel
var recent_view: RichTextLabel
var state_view: RichTextLabel
var card_grid: GridContainer
var intel_panel: Control
var intel_progress_label: Label
var intel_content_root: GridContainer
var intel_footer: HBoxContainer
var inventory_overlay: Control
var inventory_close_button: BaseButton
var inventory_energy_label: Label
var inventory_capacity_label: Label
var inventory_dominion_grid: GridContainer
var inventory_ascension_grid: GridContainer
var inventory_item_grid: GridContainer
var pulse_overlay: ColorRect
var ambience: Control
var start_button: Button
var reset_button: Button
var history_button: BaseButton
var info_button: BaseButton
var bag_button: BaseButton
var rules_button: BaseButton
var status_button: BaseButton
var settings_button: BaseButton
var action_buttons: Dictionary = {}
var auto_decide_check: CheckBox
var auto_growth_check: CheckBox
var guideline_controls: Dictionary = {}
var identity_guideline := DEFAULT_IDENTITY_GUIDELINE
var behavior_guideline := DEFAULT_BEHAVIOR_GUIDELINE
var growth_guideline := DEFAULT_GROWTH_GUIDELINE
var drawer: Control
var rules_panel: Control
var settings_panel: Control
var status_page: Control
var history_dialog: Control
var history_view: RichTextLabel
var settings_auto_decide_check: CheckBox
var settings_auto_growth_check: CheckBox
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
var common_modal: Control
var action_animation_overlay: Control
var shop_panel: Control
var shop_box: Control
var ascension_box: Control
var start_menu: Control
var death_page: Control
var upgrade_buttons_by_stat: Dictionary = {}
var highlighted_cards: Dictionary = {}
var drawer_mode := "intel"
var last_final_speaker := ""
var last_final_speech := ""
var last_final_role := "player"
const PREVIOUS_DIALOGUE_FONT_SIZE := 17
const PREVIOUS_DIALOGUE_MAX_VISIBLE_LINES := 3
var active_dialogue_role := "player"
var action_choice := 0
var selected_action_artifact := ""
var manual_action_resolved := false
var manual_action_in_progress := false
var llm_retry_requested := false
var council_mode := false
var council_status_continue_button: Button
var council_status_waiting := false
var council_result_page: Control
var council_result_waiting := false

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
	var game_cfg: Dictionary = config.get("game", {})
	council_mode = String(game_cfg.get("mode", "council")) == "council"
	if council_mode:
		_load_council_chapter(0)
		behavior_guideline = "## 议会行为文件\n- 优先让自己的隐藏阵营成为小镇主流，并且必须保证自己活着。\n- 只能根据公开投票、公开倾向和自己的隐藏罪行判断局势。\n- 避免推动会处决自己的罪行，除非能换来阵营胜利。\n- 对话时可以表达倾向、直接投票、提出政治交易或暂时撤退。\n- 测试节奏：第一轮可以试探；第二轮必须推动一个不会处决自己的罪行进入正式投票，避免对话无休止拖延。"
		_apply_council_button_labels()
	else:
		var data := ChapterLoaderScript.load_chapter(CHAPTER_PATH)
		state.load_chapter(data)
	if identity_guideline == DEFAULT_IDENTITY_GUIDELINE:
		identity_guideline = _identity_guideline_from_state()
	_push_guidelines_to_page()
	_apply_guidelines_to_state()


func _load_council_chapter(chapter_index: int) -> void:
	var index := clampi(chapter_index, 0, COUNCIL_CHAPTER_PATHS.size() - 1)
	var data := ChapterLoaderScript.load_chapter(String(COUNCIL_CHAPTER_PATHS[index]))
	CouncilRulesEngineScript.setup_state(state, data, {
		"chapter_index": index,
		"max_chapters": COUNCIL_CHAPTER_PATHS.size()
	})


func _identity_guideline_from_state() -> String:
	if state == null:
		return DEFAULT_IDENTITY_GUIDELINE
	var identity := String(state.player.get("public_identity", "")).strip_edges()
	if identity.is_empty():
		identity = "来自边境的灰狐抄写员，替商队整理族谱与债契?"
	return "## 对外身份\n%s\n\n## 对手应如何认知我\n- 以这份公开身份理解我的言行。\n- 不知道我的真实目标，除非我在对话中暴露。\n- 优先把我视为可以交易、试探、被利用或结盟的外来者?" % identity


func _push_guidelines_to_page() -> void:
	if rules_panel != null and rules_panel.has_method("set_guidelines"):
		rules_panel.call("set_guidelines", identity_guideline, behavior_guideline, growth_guideline)


func _save_guidelines_from_page() -> void:
	_sync_guidelines_from_page()
	if rules_panel != null and rules_panel.has_method("set_status"):
		rules_panel.call("set_status", "已保?")
	_update_state_panel()


func _apply_council_button_labels() -> void:
	var labels := {
		"invite": "表达倾向",
		"duel": "直接投票",
		"gift": "政治交易",
		"leave": "暂时撤退",
		"cast": "无罪票",
		"assassinate": "有罪票"
	}
	for key in labels.keys():
		var button := action_buttons.get(key) as BaseButton
		if button == null:
			continue
		button.tooltip_text = String(labels[key])
		if button is Button:
			(button as Button).text = String(labels[key])
	for hidden_key in ["cast", "assassinate"]:
		var hidden_button := action_buttons.get(hidden_key) as BaseButton
		if hidden_button != null:
			hidden_button.visible = false
	if bag_button != null:
		bag_button.visible = false


func _sync_guidelines_from_page() -> void:
	if rules_panel != null and rules_panel.has_method("get_guidelines"):
		var data: Dictionary = rules_panel.call("get_guidelines")
		identity_guideline = String(data.get("identity", identity_guideline))
		behavior_guideline = String(data.get("behavior", behavior_guideline))
		growth_guideline = String(data.get("growth", growth_guideline))
	_apply_guidelines_to_state()


func _reset_guideline_tab(tab_id: String) -> void:
	var text := ""
	match tab_id:
		"identity":
			text = _identity_guideline_from_state()
			identity_guideline = text
		"growth":
			text = DEFAULT_GROWTH_GUIDELINE
			growth_guideline = text
		_:
			text = DEFAULT_BEHAVIOR_GUIDELINE
			behavior_guideline = text
	if rules_panel != null and rules_panel.has_method("replace_current_text"):
		rules_panel.call("replace_current_text", text)
	if rules_panel != null and rules_panel.has_method("set_status"):
		rules_panel.call("set_status", "已重?")


func _merge_guideline_rule(tab_id: String, base_text: String, append_text: String) -> void:
	append_text = append_text.strip_edges()
	if append_text.is_empty():
		if rules_panel != null and rules_panel.has_method("set_status"):
			rules_panel.call("set_status", "请输入追加规?")
		return
	if rules_panel != null and rules_panel.has_method("set_merging"):
		rules_panel.call("set_merging", true)
	if rules_panel != null and rules_panel.has_method("set_status"):
		rules_panel.call("set_status", "正在融合准则...")
	var merged := await _get_guideline_merge(tab_id, base_text, append_text)
	if rules_panel != null and rules_panel.has_method("set_merging"):
		rules_panel.call("set_merging", false)
	if merged.has("error"):
		_show_error(String(merged.get("error", "")))
		if rules_panel != null and rules_panel.has_method("set_status"):
			rules_panel.call("set_status", "融合失败")
		return
	var text := String(merged.get("guideline", base_text)).strip_edges()
	if text.is_empty():
		text = base_text
	if rules_panel != null and rules_panel.has_method("replace_current_text"):
		rules_panel.call("replace_current_text", text)
	if rules_panel != null and rules_panel.has_method("set_status"):
		rules_panel.call("set_status", "已融合，记得保存")


func _apply_guidelines_to_state() -> void:
	if state == null:
		return
	var identity := _extract_identity_summary(identity_guideline)
	if not identity.is_empty():
		state.player["public_identity"] = identity


func _extract_identity_summary(text: String) -> String:
	var lines := text.split("\n", false)
	for line in lines:
		var cleaned := String(line).strip_edges()
		if cleaned.is_empty() or cleaned.begins_with("#") or cleaned.begins_with("-"):
			continue
		return cleaned
	return ""


func _behavior_guideline_text() -> String:
	return behavior_guideline


func _identity_guideline_text() -> String:
	return identity_guideline


func _growth_guideline_text() -> String:
	return growth_guideline


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
	llm_retry_button = controls.get("llm_retry_button")
	dialogue_view = controls.get("dialogue_view")
	state_view = controls.get("state_view")
	card_grid = controls.get("card_grid")
	intel_panel = controls.get("intel_panel")
	intel_progress_label = controls.get("intel_progress_label")
	intel_content_root = controls.get("intel_content_root")
	intel_footer = controls.get("intel_footer")
	inventory_overlay = controls.get("inventory_overlay")
	inventory_close_button = controls.get("inventory_close_button")
	inventory_energy_label = controls.get("inventory_energy_label")
	inventory_capacity_label = controls.get("inventory_capacity_label")
	inventory_dominion_grid = controls.get("inventory_dominion_grid")
	inventory_ascension_grid = controls.get("inventory_ascension_grid")
	inventory_item_grid = controls.get("inventory_item_grid")
	_wire_world_intel_archive()
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
	guideline_controls = controls.get("guideline_controls", {})
	auto_decide_check = controls.get("auto_decide_check")
	if auto_decide_check == null:
		auto_decide_check = guideline_controls.get("auto_decide_check")
	auto_growth_check = controls.get("auto_growth_check")
	if auto_growth_check == null:
		auto_growth_check = guideline_controls.get("auto_growth_check")
	settings_auto_decide_check = controls.get("settings_auto_decide_check")
	settings_auto_growth_check = controls.get("settings_auto_growth_check")
	_sync_auto_check_pair(guideline_controls.get("auto_decide_check") as CheckBox, settings_auto_decide_check)
	_sync_auto_check_pair(guideline_controls.get("auto_growth_check") as CheckBox, settings_auto_growth_check)
	if settings_auto_decide_check != null:
		auto_decide_check = settings_auto_decide_check
	if settings_auto_growth_check != null:
		auto_growth_check = settings_auto_growth_check
	drawer = controls.get("drawer")
	rules_panel = controls.get("rules_panel")
	settings_panel = controls.get("settings_panel")
	status_page = controls.get("status_page")
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
	if history_button != null:
		history_button.pressed.connect(_show_history)
	if info_button != null:
		info_button.pressed.connect(_show_intel_panel)
	if bag_button != null:
		bag_button.pressed.connect(_show_inventory_overlay)
	if rules_button != null:
		rules_button.pressed.connect(_toggle_rules)
	if status_button != null:
		status_button.pressed.connect(_show_status_page)
	if settings_button != null:
		settings_button.pressed.connect(_toggle_settings)
	if inventory_close_button != null:
		inventory_close_button.pressed.connect(_hide_inventory_overlay)
	var inventory_backdrop := controls.get("inventory_backdrop") as BaseButton
	if inventory_backdrop != null:
		inventory_backdrop.pressed.connect(_hide_inventory_overlay)
	for action in action_buttons.keys():
		var action_button := action_buttons[action] as BaseButton
		if action_button != null:
			action_button.pressed.connect(Callable(self, "_on_manual_action_pressed").bind(String(action)))
	modal_backdrop.pressed.connect(_close_float_panels)
	continue_button.pressed.connect(_on_continue_pressed)
	if llm_retry_button != null:
		llm_retry_button.pressed.connect(_on_llm_retry_pressed)
	if rules_panel != null:
		if rules_panel.has_signal("close_requested"):
			rules_panel.close_requested.connect(func():
				rules_panel.visible = false
				_update_modal_backdrop()
			)
		if rules_panel.has_signal("save_requested"):
			rules_panel.save_requested.connect(_save_guidelines_from_page)
		if rules_panel.has_signal("reset_requested"):
			rules_panel.reset_requested.connect(_reset_guideline_tab)
		if rules_panel.has_signal("merge_requested"):
			rules_panel.merge_requested.connect(_merge_guideline_rule)
	for page in [history_dialog, status_page, settings_panel]:
		var target := page as Control
		if target != null and target.has_signal("close_requested"):
			target.close_requested.connect(func():
				target.visible = false
				_update_modal_backdrop()
			)
	_wire_blank_close([intel_panel, drawer, rules_panel, settings_panel, history_dialog, status_page])
	_build_upgrade_buttons()
	_build_selection_panel()
	_build_common_modal()
	_build_action_animation_overlay()
	_build_shop_panel()
	_build_ascension_panel()
	_build_death_page()
	_build_council_result_page()
	_wire_button_feedback([start_button, reset_button, history_button, info_button, bag_button, rules_button, status_button, settings_button, continue_button])
	_wire_button_feedback([llm_retry_button])
	_wire_button_feedback(action_buttons.values())
	_start_ambience()
	_build_start_menu()


func _build_common_modal() -> void:
	common_modal = CommonModalScene.instantiate() as Control
	common_modal.visible = false
	common_modal.z_index = 4090
	add_child(common_modal)


func _build_action_animation_overlay() -> void:
	action_animation_overlay = ActionAnimationOverlayScript.new() as Control
	action_animation_overlay.visible = false
	add_child(action_animation_overlay)


func _sync_auto_check_pair(source: CheckBox, mirror: CheckBox) -> void:
	if source == null or mirror == null or source == mirror:
		return
	mirror.button_pressed = source.button_pressed
	source.toggled.connect(func(value: bool):
		if mirror.button_pressed != value:
			mirror.button_pressed = value
	)
	mirror.toggled.connect(func(value: bool):
		if source.button_pressed != value:
			source.button_pressed = value
	)


func _build_death_page() -> void:
	death_page = DeathPageScene.instantiate() as Control
	death_page.visible = false
	death_page.z_index = 4095
	add_child(death_page)
	if death_page.has_signal("restart_requested"):
		death_page.connect("restart_requested", Callable(self, "_on_death_restart_requested"))
	if death_page.has_signal("merge_guideline_requested"):
		death_page.connect("merge_guideline_requested", Callable(self, "_on_death_merge_requested"))


func _build_council_result_page() -> void:
	council_result_page = CouncilResultPageScript.new() as Control
	council_result_page.visible = false
	council_result_page.z_index = 4094
	add_child(council_result_page)
	council_result_page.call_deferred("_build_base")
	if council_result_page.has_signal("continue_requested"):
		council_result_page.connect("continue_requested", func():
			council_result_waiting = false
			council_result_page.visible = false
		)
	if council_result_page.has_signal("restart_requested"):
		council_result_page.connect("restart_requested", func():
			council_result_waiting = false
			council_result_page.visible = false
			_on_reset_pressed()
		)


func _wire_world_intel_archive() -> void:
	if intel_panel == null:
		return
	var close_callable := Callable(self, "_close_world_intel_archive")
	if intel_panel.has_signal("close_requested") and not intel_panel.is_connected("close_requested", close_callable):
		intel_panel.connect("close_requested", close_callable)
	var submit_callable := Callable(self, "_confirm_submit_world_intel")
	if intel_panel.has_signal("submit_requested") and not intel_panel.is_connected("submit_requested", submit_callable):
		intel_panel.connect("submit_requested", submit_callable)
	var answer_callable := Callable(self, "_select_world_intel_from_archive")
	if intel_panel.has_signal("answer_selected") and not intel_panel.is_connected("answer_selected", answer_callable):
		intel_panel.connect("answer_selected", answer_callable)


func _close_world_intel_archive() -> void:
	if intel_panel != null:
		intel_panel.visible = false
	_update_modal_backdrop()


func _select_world_intel_from_archive(question_id: String, option_id: String) -> void:
	if state == null:
		return
	state.select_world_intel_answer(question_id, option_id)
	_update_intel_panel()
	_update_state_panel()


func _build_start_menu() -> void:
	start_menu = StartMenuScript.new()
	start_menu.name = "StartMenu"
	add_child(start_menu)
	start_menu.start_requested.connect(_on_start_pressed)
	start_menu.rules_requested.connect(_toggle_rules)
	start_menu.settings_requested.connect(_toggle_settings)
	if start_menu.has_signal("debug_screen_requested"):
		start_menu.connect("debug_screen_requested", Callable(self, "_show_debug_screen_preview"))


func _show_debug_screen_preview(screen_id: String) -> void:
	_prepare_debug_preview_state()
	match screen_id:
		"round_select":
			_render_npc_selection_page()
		"dialogue":
			_show_debug_dialogue_preview()
		"shop":
			state.refresh_shop_items()
			_render_shop()
		"ascension":
			selected_upgrade = ""
			pending_stat_points = 3
			upgrade_done = false
			_render_ascension_page(true, true)
		"intel":
			_show_debug_dialogue_preview()
			_show_intel_panel()
		"inventory":
			_show_debug_dialogue_preview()
			_show_inventory_overlay()
		"history":
			_show_debug_dialogue_preview()
			_show_history()
		"rules":
			_show_debug_dialogue_preview()
			_toggle_rules()
		"status":
			_show_debug_dialogue_preview()
			_show_status_page()
		"settings":
			_show_debug_dialogue_preview()
			_toggle_settings()
		_:
			_show_debug_dialogue_preview()


func _prepare_debug_preview_state_safe() -> void:
	running = false
	_load_chapter()
	_reset_ui()
	if start_menu != null:
		start_menu.call("hide_menu")
	_close_float_panels()
	_hide_debug_flow_pages()
	state.active = true
	state.chapter_round = 2
	state.turn = 2
	state.player_chars = 316
	state.player["energy"] = 168
	state.player["level"] = 4
	state.player["inventory"] = _debug_artifact_ids(10)
	state.player["artifact_history"] = _debug_artifact_ids(13)
	state.player["dominion_requirement"] = _debug_artifact_ids(3)
	state.player["ascension_requirement"] = _debug_artifact_ids(4)
	var stats: Dictionary = state.player.get("stats", {})
	stats["hp"] = max(16, int(stats.get("hp", 0)))
	stats["frontal_attack"] = max(7, int(stats.get("frontal_attack", 0)))
	stats["frontal_defense"] = max(6, int(stats.get("frontal_defense", 0)))
	stats["assassination_attack"] = max(8, int(stats.get("assassination_attack", 0)))
	stats["assassination_defense"] = max(5, int(stats.get("assassination_defense", 0)))
	stats["charm"] = max(9, int(stats.get("charm", 0)))
	state.player["stats"] = stats
	state.refresh_npc_choices()
	state.choose_npc(0)
	state.refresh_shop_items()
	_seed_debug_world_intel()
	state.full_dialogue_history.clear()
	for item in [
		{"round": state.chapter_round, "npc_index": state.current_npc_index, "npc_name": String(state.current_npc().get("public_name", "对手")), "role": "player", "content": "我带着几件旧法器来，只想听一句关于月息夜市的真话。"},
		{"round": state.chapter_round, "npc_index": state.current_npc_index, "npc_name": String(state.current_npc().get("public_name", "对手")), "role": "npc", "content": "真话通常不贵，贵的是承认自己听懂了它。"},
		{"round": state.chapter_round, "npc_index": state.current_npc_index, "npc_name": String(state.current_npc().get("public_name", "对手")), "role": "player", "content": "那就把价码说清楚。"}
	]:
		state.full_dialogue_history.append(item)
	state.event_log.clear()
	for item in [
		"调试：玩家获得了 10 件法器。",
		"调试：6 条世界设定档案已被选择。",
		"调试：当前对手亲近度提高到 7。"
	]:
		state.event_log.append(item)
	var npc: Dictionary = state.current_npc()
	npc["affinity"] = max(7, int(npc.get("affinity", 0)))
	state.set_current_npc(npc)
	_set_current_npc_assets()
	_update_state_panel()


func _prepare_debug_preview_state() -> void:
	_prepare_debug_preview_state_safe()
	return
	running = false
	_load_chapter()
	_reset_ui()
	if start_menu != null:
		start_menu.call("hide_menu")
	_close_float_panels()
	_hide_debug_flow_pages()
	state.active = true
	state.chapter_round = 2
	state.turn = 2
	state.player_chars = 316
	state.player["energy"] = 168
	state.player["level"] = 4
	state.player["inventory"] = _debug_artifact_ids(10)
	state.player["artifact_history"] = _debug_artifact_ids(13)
	state.player["dominion_requirement"] = _debug_artifact_ids(3)
	state.player["ascension_requirement"] = _debug_artifact_ids(4)
	var stats: Dictionary = state.player.get("stats", {})
	stats["hp"] = max(16, int(stats.get("hp", 0)))
	stats["frontal_attack"] = max(7, int(stats.get("frontal_attack", 0)))
	stats["frontal_defense"] = max(6, int(stats.get("frontal_defense", 0)))
	stats["assassination_attack"] = max(8, int(stats.get("assassination_attack", 0)))
	stats["assassination_defense"] = max(5, int(stats.get("assassination_defense", 0)))
	stats["charm"] = max(9, int(stats.get("charm", 0)))
	state.player["stats"] = stats
	state.refresh_npc_choices()
	state.choose_npc(0)
	state.refresh_shop_items()
	_seed_debug_world_intel()
	state.full_dialogue_history = [
		{"round": state.chapter_round, "npc_index": state.current_npc_index, "npc_name": String(state.current_npc().get("public_name", "对手")), "role": "player", "content": "我带着几件旧法器来，只想听一句关于月息夜市的真话?"},
		{"round": state.chapter_round, "npc_index": state.current_npc_index, "npc_name": String(state.current_npc().get("public_name", "对手")), "role": "npc", "content": "真话通常不贵，贵的是承认自己听懂了它?"},
		{"round": state.chapter_round, "npc_index": state.current_npc_index, "npc_name": String(state.current_npc().get("public_name", "对手")), "role": "player", "content": "那就把价码说清楚?"}
	]
	state.event_log = [
		"调试：玩家获得了 10 件法器。",
		"调试：6 条世界设定档案已被选择。",
		"调试：当前对手亲近度提高到 7。"
	]
	var npc: Dictionary = state.current_npc()
	npc["affinity"] = max(7, int(npc.get("affinity", 0)))
	state.set_current_npc(npc)
	_set_current_npc_assets()
	_update_state_panel()


func _hide_debug_flow_pages() -> void:
	for page in [selection_panel, shop_panel, upgrade_panel]:
		var control := page as Control
		if control != null and is_instance_valid(control):
			control.visible = false
	_set_dialogue_visible(false)


func _show_debug_dialogue_preview() -> void:
	_hide_debug_flow_pages()
	_set_current_npc_assets()
	_set_dialogue_visible(true)
	_set_current_dialogue_role("player")
	_set_status_text("调试预览?%s" % _current_dialogue_scene_name())
	last_final_speaker = String(state.current_npc().get("public_name", "对手"))
	last_final_speech = "你问得很巧。这里每一盏灯都照着一份债，也照着一条可以被买走的秘密?"
	last_final_role = "npc"
	_show_previous_final_if_ready()
	dialogue_title.text = "调试对话"
	dialogue_view.clear()
	dialogue_view.append_text("[color=#130905]我会先确认对方愿意交易，再决定赠送、施法或撤离。[/color]\n\n")
	dialogue_view.append_text("[color=#130905]若你愿意谈，我可以用一枚旧印换你手里的月灯。[/color]")
	_update_progress()


func _debug_artifact_ids(count: int) -> Array[String]:
	var result: Array[String] = []
	for artifact in state.artifacts:
		if result.size() >= count:
			break
		var id := String(artifact.get("id", ""))
		if not id.is_empty():
			result.append(id)
	return result


func _seed_debug_world_intel() -> void:
	state.selected_world_intel.clear()
	state.intel_testimonies.clear()
	var npc: Dictionary = state.current_npc()
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		var options: Array = question.get("options", [])
		if question_id.is_empty() or options.is_empty():
			continue
		var option_id := String(options[0].get("id", ""))
		state.select_world_intel_answer(question_id, option_id)
		state.add_intel_testimony(question_id, option_id, npc, true)
		if state.selected_world_intel.size() >= 3:
			break


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


func _instantiate_flow_page(scene: PackedScene) -> Control:
	var page: Control = scene.instantiate()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 0.0
	page.offset_top = 0.0
	page.offset_right = 0.0
	page.offset_bottom = 0.0
	page.z_index = 1000
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	return page


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
	if rules_edit != null:
		rules_edit.editable = true
	if rules_panel != null and rules_panel.has_method("set_locked"):
		rules_panel.call("set_locked", false)
	upgrade_panel.visible = false
	selection_panel.visible = false
	shop_panel.visible = false
	if death_page != null:
		death_page.call("hide_death")
	result_banner.visible = false
	_hide_llm_retry_button()
	if auto_decide_check != null:
		auto_decide_check.button_pressed = false
	if auto_growth_check != null:
		auto_growth_check.button_pressed = false
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
	_set_status_text("%s：等待开?" % state.chapter.get("title", "骗子大陆"))
	npc_label.text = "等待选择"
	player_label.text = _player_short_name()
	if current_speaker_label != null:
		current_speaker_label.text = _player_short_name()
	_set_current_dialogue_role("player")
	npc_public_label.text = "开始后从候选对手中选择对话对象?"
	_push_guidelines_to_page()
	_show_scene_message("调整准则后点击“开始”。对话会自动进行；可开启自己行动或自己成长?")
	_update_state_panel()


func _on_start_pressed() -> void:
	if start_menu != null:
		start_menu.call("hide_menu")
	_save_guidelines_from_page()
	_load_chapter()
	state.active = true
	running = true
	start_button.disabled = true
	if settings_panel != null:
		settings_panel.visible = false
	if status_page != null:
		status_page.visible = false
	if history_dialog != null:
		history_dialog.visible = false
	if rules_edit != null:
		rules_edit.editable = true
	if rules_panel != null and rules_panel.has_method("set_locked"):
		rules_panel.call("set_locked", false)
	_show_scene_message("章节开始?")
	_update_state_panel()
	await _run_chapter()


func _on_reset_pressed() -> void:
	_load_chapter()
	_reset_ui()


func _run_chapter() -> void:
	if council_mode:
		await _run_council_chapter()
		return
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


func _run_council_chapter() -> void:
	while running:
		while state.active and not state.ended and running:
			state.refresh_npc_choices()
			await _choose_npc_ui()
			if state.ended or not running:
				break
			await _run_council_dialogue()
			_update_state_panel()
			if running:
				await _show_council_status_gate()
			if state.ended or not running:
				break
			var events: Array[String] = []
			CouncilRulesEngineScript.finish_round(state, events)
			for event in events:
				_append_system_log(event)
			_update_state_panel()
		if not running:
			break
		if state.ended and state.victory and state.chapter_index < COUNCIL_CHAPTER_PATHS.size() - 1:
			state.council_chapter_results.append(_council_result_snapshot())
			await _show_council_chapter_result_gate(false)
			_load_council_chapter(state.chapter_index + 1)
			state.active = true
			_update_state_panel()
			continue
		if state.ended:
			state.council_chapter_results.append(_council_result_snapshot())
			await _show_council_chapter_result_gate(true)
		break
	_update_after_end()


func _run_council_dialogue() -> void:
	_set_dialogue_visible(true)
	manual_action_resolved = false
	manual_action_in_progress = false
	state.turn = 0
	while state.turn < state.max_dialogue_turns and running and not state.ended:
		state.turn += 1
		_set_status_text("第 %d 回合：议会会谈 - %s" % [state.chapter_round + 1, _current_dialogue_scene_name()])
		_update_progress()
		_set_active_speaker("player")
		var player_response := await _get_council_player_dialogue()
		if bool(player_response.get("cancelled", false)):
			return
		if player_response.has("error"):
			_show_error(player_response.get("error", ""))
			return
		var speech := String(player_response.get("speech", "我需要先听听你对这些罪名的态度。")).strip_edges()
		state.add_dialogue("player", speech)
		await _finish_speech_stream("你方", speech, Color(0.58, 0.82, 1.0, 1.0))
		var events: Array[String] = []
		var player_action_applied: bool = CouncilRulesEngineScript.apply_member_action(state, "player", String(player_response.get("action", "declare_tendency")), player_response, events)
		var progress_crime := CouncilRulesEngineScript.best_progress_crime(state, String(state.current_npc().get("id", "")))
		if state.turn >= 2 and (not player_action_applied or not _council_has_locked_vote("player", progress_crime)):
			player_action_applied = CouncilRulesEngineScript.apply_member_action(state, "player", "cast_vote", _council_forced_vote_payload(progress_crime), events)
		for event in events:
			_append_system_log(event)
		if state.ended:
			break
		_set_active_speaker("npc")
		var npc_response := await _get_council_npc_dialogue()
		if npc_response.has("error"):
			_show_error(npc_response.get("error", ""))
			return
		var npc_speech := String(npc_response.get("speech", "这件事要谨慎，票一旦投下去就收不回来了。")).strip_edges()
		state.add_dialogue("npc", npc_speech)
		await _finish_speech_stream("对方", npc_speech, Color(1.0, 0.61, 0.48, 1.0))
		events.clear()
		var npc_id := String(state.current_npc().get("id", ""))
		var npc_action_applied: bool = CouncilRulesEngineScript.apply_member_action(state, npc_id, String(npc_response.get("action", "declare_tendency")), npc_response, events)
		if state.turn >= 2 and (not npc_action_applied or not _council_has_locked_vote(npc_id, progress_crime)):
			npc_action_applied = CouncilRulesEngineScript.apply_member_action(state, npc_id, "cast_vote", _council_forced_vote_payload(progress_crime), events)
		if state.turn >= 2 and not state.ended:
			CouncilRulesEngineScript.apply_follow_votes(state, progress_crime, "guilty", events)
		for event in events:
			_append_system_log(event)
		_update_state_panel()
		if state.ended or bool(player_response.get("end_dialogue", false)) or bool(npc_response.get("end_dialogue", false)):
			break
		await get_tree().create_timer(0.2).timeout


func _choose_npc_ui() -> void:
	_set_dialogue_visible(false)
	selected_npc_choice = -1
	_render_npc_selection_page()
	if auto_growth_check != null and auto_growth_check.button_pressed:
		await _run_auto_npc_choice()
	while selected_npc_choice < 0 and running and not state.ended:
		await get_tree().process_frame
	selection_panel.visible = false
	if selected_npc_choice >= 0:
		state.choose_npc(selected_npc_choice)
		_clear_last_final_dialogue()
		_set_current_npc_assets()
	_show_scene_message("已选择和 %s 聊聊。" % [state.current_npc().get("public_name", "对手")])


func _run_auto_npc_choice() -> void:
	var elapsed := 0.0
	_show_result_banner("自己成长?%d 秒后将自动选择对手" % int(AUTO_CONFIRM_SECONDS), Color(1.0, 0.82, 0.34, 1.0))
	while selected_npc_choice < 0 and running and not state.ended and elapsed < AUTO_CONFIRM_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if int(ceil(AUTO_CONFIRM_SECONDS - elapsed)) != int(ceil(AUTO_CONFIRM_SECONDS - elapsed + get_process_delta_time())):
			_show_result_banner("自己成长?%d 秒后将自动选择对手" % int(ceil(max(0.0, AUTO_CONFIRM_SECONDS - elapsed))), Color(1.0, 0.82, 0.34, 1.0))
	if selected_npc_choice >= 0 or not running or state.ended:
		return
	var decision := await _get_npc_choice_decision()
	if selected_npc_choice >= 0 or not running or state.ended:
		return
	var choice_index := clampi(int(decision.get("choice_index", 0)), 0, max(0, state.npc_choices.size() - 1))
	var npc_name := _npc_choice_name(choice_index)
	var body := "AI 推荐对手?%s\n\n思考：%s" % [npc_name, String(decision.get("thinking", "优先选择当前收益最高的对手?"))]
	var accepted: bool = await common_modal.call("show_countdown_message", "自己成长", body, AUTO_CONFIRM_SECONDS, "手动选择")
	if accepted and selected_npc_choice < 0 and running and not state.ended:
		selected_npc_choice = choice_index


func _npc_choice_name(choice_index: int) -> String:
	if choice_index < 0 or choice_index >= state.npc_choices.size():
		return "对手"
	var npc_index: int = state.npc_choices[choice_index]
	if npc_index < 0 or npc_index >= state.npcs.size():
		return "对手"
	return String(state.npcs[npc_index].get("public_name", "对手"))


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
			card.visible = true
			if i < state.npc_choices.size():
				var npc_index: int = state.npc_choices[i]
				if npc_index >= 0 and npc_index < state.npcs.size():
					_apply_npc_select_card(card, state.npcs[npc_index], i)
				else:
					_apply_locked_npc_select_card(card)
			else:
				_apply_locked_npc_select_card(card)
	_wire_right_utility_buttons(selection_panel.get_node_or_null("RightUtilityButtons") as Control)
	if council_mode:
		_add_council_selection_summary()


func _add_council_selection_summary() -> void:
	if selection_panel == null or state == null:
		return
	var panel := PanelContainer.new()
	panel.name = "CouncilPublicSummary"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.30
	panel.anchor_right = 0.885
	panel.anchor_top = 0.925
	panel.anchor_bottom = 0.985
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.035, 0.78)
	style.border_color = Color(0.98, 0.72, 0.30, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "SummaryLabel"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 14
	label.offset_right = -14
	label.offset_top = 4
	label.offset_bottom = -4
	label.text = _council_public_summary_text()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.75, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	panel.add_child(label)
	selection_panel.add_child(panel)


func _council_public_summary_text() -> String:
	var alive := CouncilRulesEngineScript.alive_count(state)
	var total := CouncilRulesEngineScript.total_members(state)
	var threshold := CouncilRulesEngineScript.execution_threshold(state)
	var locked: int = state.council_vote_records.size()
	var tendency: int = state.council_vote_tendencies.size()
	return "公开摘要：存活 %d / %d，处决阈值 %d 票，正式票 %d，倾向 %d。隐藏阵营与隐藏罪行仍仅本人可知。" % [alive, total, threshold, locked, tendency]


func _apply_round_player_card(root: Control) -> void:
	if root == null:
		return
	_ensure_select_card_shadow_mask(root)
	var name := root.get_node_or_null("NameLabel") as Label
	if name != null:
		name.text = _player_short_name()
	var stats := root.get_node_or_null("Stats") as Control
	if stats == null:
		return
	var rows := _player_stat_rows()
	if _apply_select_stat_rows(stats, rows):
		return
	_clear_children(stats)
	for i in range(rows.size()):
		var row := _make_select_stat_row(String(rows[i][0]), String(rows[i][1]), i)
		_place_by_ratio(row, Rect2(0.0, i * 0.250, 1.0, 0.220))
		stats.add_child(row)


func _apply_npc_select_card(card: Button, npc: Dictionary, choice_index: int) -> void:
	_disconnect_pressed_connections(card)
	card.custom_minimum_size = Vector2.ZERO
	card.offset_left = 0.0
	card.offset_top = 0.0
	card.offset_right = 0.0
	card.offset_bottom = 0.0
	card.text = ""
	card.disabled = false
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	card.pressed.connect(func(): selected_npc_choice = choice_index)
	var texture := card.get_node_or_null("CardTexture") as TextureRect
	if texture != null:
		texture.texture = _load_texture_any(_select_card_path_for_npc(npc))
	_ensure_select_card_shadow_mask(card)
	var name := card.get_node_or_null("NameLabel") as Label
	if name != null:
		name.text = String(npc.get("public_name", "对手"))
	var tag := card.get_node_or_null("TagLabel") as Label
	if tag != null:
		tag.visible = false
	var choose := card.get_node_or_null("ChooseButton") as Button
	if choose != null:
		_disconnect_pressed_connections(choose)
		choose.visible = true
		choose.disabled = false
		_style_primary_button(choose, "选择", 24)
		choose.pressed.connect(func(): selected_npc_choice = choice_index)
		_wire_button_feedback([choose])
	_wire_hold_hover_feedback([card])


func _apply_locked_npc_select_card(card: Button) -> void:
	_disconnect_pressed_connections(card)
	card.custom_minimum_size = Vector2.ZERO
	card.offset_left = 0.0
	card.offset_top = 0.0
	card.offset_right = 0.0
	card.offset_bottom = 0.0
	card.text = ""
	card.disabled = false
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var texture := card.get_node_or_null("CardTexture") as TextureRect
	if texture != null:
		texture.texture = _load_texture_any(LOCKED_NPC_SELECT_CARD_PATH)
	_ensure_select_card_shadow_mask(card)
	var name := card.get_node_or_null("NameLabel") as Label
	if name != null:
		name.text = "暂未开?"
	var tag := card.get_node_or_null("TagLabel") as Label
	if tag != null:
		tag.visible = false
	var choose := card.get_node_or_null("ChooseButton") as Button
	if choose != null:
		_disconnect_pressed_connections(choose)
		choose.visible = false
		choose.disabled = true


func _disconnect_pressed_connections(button: BaseButton) -> void:
	if button == null:
		return
	for connection in button.get_signal_connection_list("pressed"):
		var callable := connection.get("callable") as Callable
		if callable.is_valid():
			button.pressed.disconnect(callable)


func _apply_round_utility_column(box: Control) -> void:
	_wire_right_utility_buttons(box)


func _wire_right_utility_buttons(root: Control) -> void:
	if root == null:
		return
	var specs := {
		"InfoButton": func(): _show_intel_panel(),
		"BagButton": _show_inventory_overlay,
		"HistoryButton": _show_history,
		"RulesButton": _toggle_rules,
		"StatusButton": _show_status_page,
		"SettingsButton": _toggle_settings
	}
	for node_name in specs.keys():
		var button := root.get_node_or_null(String(node_name)) as BaseButton
		if button == null:
			continue
		if not button.has_meta("utility_callback_wired"):
			button.set_meta("utility_callback_wired", true)
			var callback: Callable = specs[node_name]
			button.pressed.connect(callback)
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
	darken.color = Color(0.0, 0.0, 0.0, 0.0)
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
	for i in range(card_rects.size()):
		if i < state.npc_choices.size():
			var npc_index: int = state.npc_choices[i]
			if npc_index >= 0 and npc_index < state.npcs.size():
				_add_npc_select_card(parent, state.npcs[npc_index], i, card_rects[i])
			else:
				_add_locked_npc_select_card(parent, card_rects[i])
		else:
			_add_locked_npc_select_card(parent, card_rects[i])
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
	label.text = "今天和谁聊聊?"
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

	var name := _make_select_label(_player_short_name(), 30, Color.WHITE)
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

	var name := _make_select_label(String(npc.get("public_name", "对手")), 28, Color.WHITE)
	_place_by_ratio(name, Rect2(0.16, 0.655, 0.68, 0.100))
	button.add_child(name)

	var choose := _make_select_choose_button()
	_place_select_choose_button(choose)
	choose.pressed.connect(func(): selected_npc_choice = choice_index)
	button.add_child(choose)
	_wire_button_feedback([button, choose])


func _add_locked_npc_select_card(parent: Control, rect: Rect2) -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_by_ratio(root, rect)
	parent.add_child(root)

	var texture := TextureRect.new()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture = _load_texture_any(LOCKED_NPC_SELECT_CARD_PATH)
	root.add_child(texture)
	_add_select_card_shadow_mask(root)

	var name := _make_select_label("暂未开?", 28, Color.WHITE)
	_place_by_ratio(name, Rect2(0.16, 0.655, 0.68, 0.100))
	root.add_child(name)


func _add_round_utility_column(parent: Control) -> void:
	var utility := RightUtilityButtonsScene.instantiate() as Control
	utility.name = "RightUtilityButtons"
	utility.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(utility)
	_wire_right_utility_buttons(utility)


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
			if await _finish_manual_action_if_needed():
				return
			state.turn += 1
			_set_status_text("第 %d 回合：%s" % [state.chapter_round + 1, _current_dialogue_scene_name()])
			_update_progress()
			_set_active_speaker("player")
			var player_response := await _get_player_dialogue()
			if await _finish_manual_action_if_needed():
				return
			if bool(player_response.get("cancelled", false)):
				return
			if player_response.has("error"):
				_show_error(player_response.get("error", ""))
				return
			var speech := String(player_response.get("speech", "我想先听听你的看法?")).strip_edges()
			var raw_action := String(player_response.get("action", "none")).strip_edges().to_lower()
			state.add_dialogue("player", speech)
			await _finish_speech_stream("你方", speech, Color(0.58, 0.82, 1.0, 1.0))
			if await _finish_manual_action_if_needed():
				return
			if raw_action != "" and raw_action != "none":
				var resolved := await _resolve_decided_action(raw_action, {"artifact_id": String(player_response.get("artifact_id", "")), "thinking": String(player_response.get("thinking", ""))}, "即时行动")
				if resolved:
					return
			_set_status_text("第 %d 回合：%s" % [state.chapter_round + 1, _current_dialogue_scene_name()])
			_set_active_speaker("npc")
			var npc_response := await _get_npc_dialogue()
			if await _finish_manual_action_if_needed():
				return
			if npc_response.has("error"):
				_show_error(npc_response.get("error", ""))
				return
			var npc_speech := String(npc_response.get("speech", "对方沉默片刻?")).strip_edges()
			state.add_dialogue("npc", npc_speech)
			await _finish_speech_stream("对方", npc_speech, Color(1.0, 0.61, 0.48, 1.0))
			if await _finish_manual_action_if_needed():
				return
			var accepted_response := await _confirm_npc_offer(npc_response)
			var npc_events := RulesEngineScript.apply_dialogue_turn(state, speech, npc_speech, accepted_response)
			await _play_npc_action_animation(accepted_response, npc_events)
			for event in npc_events:
				_append_system_log(event)
				_mark_event_cards(event)
			_update_state_panel()
			if _npc_response_resolved_dialogue(accepted_response):
				return
			if not bool(state.current_npc().get("alive", true)):
				return
			if bool(player_response.get("end_dialogue", false)):
				break
			await get_tree().create_timer(0.2).timeout
		if state.ended:
			return
		if await _finish_manual_action_if_needed():
			return
		var response := await _get_post_action()
		if await _finish_manual_action_if_needed():
			return
		if bool(response.get("cancelled", false)):
			return
		var post_resolved := await _resolve_decided_action(String(response.get("action", "leave")), {"artifact_id": String(response.get("artifact_id", "")), "thinking": String(response.get("thinking", ""))}, "对话结束行动")
		if post_resolved:
			return
		_append_system_log("你取消了行动，角色继续聊天?")
		state.turn = max(0, state.max_dialogue_turns - 1)
	if not state.ended and not manual_action_resolved:
		await _resolve_action("leave", {}, "对话结束行动")


func _finish_manual_action_if_needed() -> bool:
	if not manual_action_resolved:
		return false
	while manual_action_in_progress and running:
		await get_tree().process_frame
	return true


func _resolve_decided_action(action: String, payload: Dictionary, label: String) -> bool:
	var normalized := RulesEngineScript.normalize_action(action)
	if auto_decide_check != null and auto_decide_check.button_pressed:
		var body := _decision_body_for_action(normalized, payload)
		var accepted: bool = await common_modal.call("show_countdown_message", "自己行动", body, AUTO_CONFIRM_SECONDS, "取消")
		if not accepted:
			return false
		await _resolve_action(normalized, payload, label)
		return true
	var confirmed := await _confirm_player_action(normalized, payload, label)
	if not confirmed:
		return false
	await _resolve_action(normalized, payload, label)
	return true


func _decision_body_for_action(action: String, payload: Dictionary) -> String:
	var lines: Array[String] = []
	var thinking := String(payload.get("thinking", "")).strip_edges()
	if not thinking.is_empty():
		lines.append("思考：%s" % thinking)
	lines.append("行动?%s" % _action_name(action))
	var artifact_id := String(payload.get("artifact_id", ""))
	if not artifact_id.is_empty():
		lines.append("法器?%s" % state.artifact_name(artifact_id))
	return "\n".join(lines)


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
	if council_mode:
		var payload := await _choose_manual_council_payload(action)
		if payload.is_empty():
			manual_action_in_progress = false
			return
		manual_action_resolved = true
		var events: Array[String] = []
		CouncilRulesEngineScript.apply_member_action(state, "player", String(payload.get("action", "declare_tendency")), payload, events)
		if String(payload.get("action", "")) == "cast_vote" and not state.ended:
			CouncilRulesEngineScript.apply_follow_votes(state, String(payload.get("target_crime_id", "")), String(payload.get("vote", "guilty")), events)
		for event in events:
			_append_system_log(event)
		_show_result_banner("会议行动：%s" % String(payload.get("label", action)), Color(1.0, 0.82, 0.34, 1.0))
		_update_state_panel()
		manual_action_in_progress = false
		return
	var normalized := RulesEngineScript.normalize_action(action)
	var payload := {}
	if normalized == "gift" or normalized == "cast":
		var artifact_id := await _choose_action_artifact(normalized)
		if artifact_id.is_empty():
			manual_action_in_progress = false
			return
		payload["artifact_id"] = artifact_id
	manual_action_resolved = true
	await _resolve_action(normalized, payload, "手动行动")
	manual_action_in_progress = false


func _manual_council_payload(action: String) -> Dictionary:
	var crime_id := "duck_house_expense"
	match action:
		"leave":
			return {"action": "retreat", "label": "暂时撤退"}
		"gift":
			return {"action": "offer_trade", "target_crime_id": crime_id, "vote": "guilty", "label": "政治交易"}
		"duel", "assassinate":
			return {"action": "cast_vote", "target_crime_id": crime_id, "vote": "guilty", "label": "直接投有罪"}
		"cast":
			return {"action": "cast_vote", "target_crime_id": crime_id, "vote": "innocent", "label": "直接投无罪"}
		_:
			return {"action": "declare_tendency", "target_crime_id": crime_id, "vote": "guilty", "label": "表达有罪倾向"}


func _choose_manual_council_payload(action: String) -> Dictionary:
	match action:
		"leave":
			var accepted: bool = await common_modal.call("show_message", "暂时撤退", "结束本次会谈，并在下一回合重新选择议员。", "撤退", "取消")
			return {"action": "retreat", "label": "暂时撤退"} if accepted else {}
		"invite":
			var tendency := await _choose_council_vote_payload("表达倾向", "declare_tendency")
			if not tendency.is_empty():
				tendency["label"] = "倾向表达"
			return tendency
		"duel", "assassinate":
			var vote := await _choose_council_vote_payload("直接投票", "cast_vote")
			if not vote.is_empty():
				vote["label"] = "直接投票"
			return vote
		"gift":
			var trade := await _choose_council_vote_payload("政治交易", "cast_vote")
			if not trade.is_empty():
				trade["action"] = "offer_trade"
				trade["bound_votes"] = [{"member_id": "player", "crime_id": String(trade.get("target_crime_id", "")), "vote": String(trade.get("vote", "guilty"))}]
				trade["label"] = "政治交易"
			return trade
	return _manual_council_payload(action)


func _choose_council_vote_payload(title: String, action_name: String) -> Dictionary:
	var crime_choices: Array = []
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		crime_choices.append({
			"label": String(crime.get("title", crime_id)),
			"value": crime_id
		})
	var crime_id = await common_modal.call("show_choice_list", title, "选择一条罪行。正式投票不可更改；倾向可以被之后的正式投票覆盖。", crime_choices, "取消")
	if crime_id == null:
		return {}
	var vote = await common_modal.call("show_choice_list", "选择票向", "选择对「%s」的票向。" % CouncilRulesEngineScript.crime_title(state, String(crime_id)), [
		{"label": "有罪", "value": "guilty"},
		{"label": "无罪", "value": "innocent"},
		{"label": "弃权", "value": "abstain"}
	], "取消")
	if vote == null:
		return {}
	return {
		"action": action_name,
		"target_crime_id": String(crime_id),
		"vote": String(vote),
		"source": "manual"
	}


func _council_forced_vote_payload(crime_id := "") -> Dictionary:
	var target := String(crime_id)
	if target.is_empty():
		target = CouncilRulesEngineScript.best_progress_crime(state, String(state.current_npc().get("id", "")))
	return {
		"action": "cast_vote",
		"target_crime_id": target,
		"vote": "guilty",
		"source": "dialogue_failsafe",
		"end_dialogue": true
	}


func _council_has_locked_vote(member_id: String, crime_id: String) -> bool:
	for record in state.council_vote_records:
		if String(record.get("member_id", "")) == member_id and String(record.get("crime_id", "")) == crime_id:
			return true
	return false


func _confirm_player_action(action: String, payload: Dictionary, label: String) -> bool:
	var artifact_id := String(payload.get("artifact_id", ""))
	var artifact_text := ""
	if not artifact_id.is_empty():
		artifact_text = "\n法器?%s" % state.artifact_name(artifact_id)
	var body := "你方角色准备执行?%s%s\n允许后会立即结算本次行动?" % [_action_name(action), artifact_text]
	return await common_modal.call("show_message", "确认玩家行动", body, "确定", "取消")


func _choose_action_artifact(action: String) -> String:
	var inventory: Array = state.player.get("inventory", [])
	if inventory.is_empty():
		_show_result_banner("%s需要先拥有法器" % _action_name(action), Color(1.0, 0.36, 0.32, 1.0))
		return ""
	var choices := []
	var counts := _artifact_counts(inventory)
	for artifact_id in counts.keys():
		var id := String(artifact_id)
		choices.append({
			"label": "%s x%d" % [state.artifact_name(id), int(counts[id])],
			"value": id
		})
	var selected = await common_modal.call(
		"show_choice_list",
		"选择法器",
		"选择一个当前持有的法器，用于本?%s?" % _action_name(action),
		choices,
		"取消"
	)
	return String(selected) if selected != null else ""


func _select_action_artifact(artifact_id: String) -> void:
	selected_action_artifact = artifact_id
	action_choice = 1


func _play_npc_action_animation(npc_response: Dictionary, events: Array) -> void:
	var action := String(npc_response.get("action", "none")).strip_edges().to_lower()
	var artifact_id := ""
	if action != "assassinate" and action != "duel":
		if npc_response.has("gift_offer") and typeof(npc_response.get("gift_offer")) == TYPE_DICTIONARY:
			action = "gift"
			var offer: Dictionary = npc_response.get("gift_offer", {})
			artifact_id = String(offer.get("artifact_id", ""))
	if action == "none" or action.is_empty():
		return
	await _play_action_animation(action, "npc", artifact_id, events)


func _play_action_animation(action: String, actor_role: String, artifact_id: String, events: Array) -> void:
	if action_animation_overlay == null or not is_instance_valid(action_animation_overlay):
		return
	var normalized := RulesEngineScript.normalize_action(action)
	if normalized.is_empty() or normalized == "none":
		return
	if result_banner != null:
		result_banner.visible = false
	var chrome_state := _capture_action_animation_chrome_state()
	_set_action_animation_chrome_visible(false)
	await action_animation_overlay.call(
		"play_action",
		normalized,
		actor_role,
		artifact_id,
		_action_animation_outcome(normalized, events),
		state,
		player_portrait,
		npc_portrait
	)
	if actor_role == "npc" and normalized == "gift" and not state.ended:
		_restore_action_animation_chrome_state(chrome_state)


func _capture_action_animation_chrome_state() -> Dictionary:
	var state_data := {"nodes": {}, "buttons": {}}
	for node in [upper_box, lower_box, dialogue_title, result_banner, llm_retry_button, side_shadow_left, side_shadow_right, status_label, info_button, bag_button, history_button, rules_button, status_button, settings_button]:
		var control := node as CanvasItem
		if control != null:
			state_data["nodes"][control.get_instance_id()] = {"node": control, "visible": control.visible}
	for action_button in action_buttons.values():
		var button := action_button as CanvasItem
		if button != null:
			state_data["buttons"][button.get_instance_id()] = {"node": button, "visible": button.visible}
	return state_data


func _set_action_animation_chrome_visible(is_visible: bool) -> void:
	for node in [upper_box, lower_box, dialogue_title, result_banner, llm_retry_button, side_shadow_left, side_shadow_right, status_label, info_button, bag_button, history_button, rules_button, status_button, settings_button]:
		var control := node as CanvasItem
		if control != null:
			control.visible = is_visible
	for action_button in action_buttons.values():
		var button := action_button as CanvasItem
		if button != null:
			button.visible = is_visible
	if dialogue_view != null and not is_visible:
		dialogue_view.clear()
	if recent_view != null and not is_visible:
		recent_view.clear()
	if player_portrait != null:
		player_portrait.visible = player_portrait.texture != null
	if npc_portrait != null:
		npc_portrait.visible = npc_portrait.texture != null


func _restore_action_animation_chrome_state(state_data: Dictionary) -> void:
	for item in state_data.get("nodes", {}).values():
		var control := item.get("node") as CanvasItem
		if control != null and is_instance_valid(control):
			control.visible = bool(item.get("visible", control.visible))
	for item in state_data.get("buttons", {}).values():
		var button := item.get("node") as CanvasItem
		if button != null and is_instance_valid(button):
			button.visible = bool(item.get("visible", button.visible))
	_update_dialogue_scene_visibility()


func _action_animation_outcome(action: String, events: Array) -> String:
	if state != null and state.ended:
		return "victory" if state.victory else "death"
	var joined := ""
	for event in events:
		joined += String(event) + "\n"
	if joined.contains("死亡") or joined.contains("?") or joined.contains("击杀"):
		return "death"
	if joined.contains("失败") or joined.contains("?") or joined.contains("不信?") or joined.contains("不足"):
		return "failure"
	if joined.contains("胜利") or joined.contains("成功") or joined.contains("加入") or joined.contains("完成"):
		return "victory"
	match action:
		"assassinate", "duel", "cast", "invite":
			return "failure" if events.is_empty() else "victory"
		_:
			return "success"


func _resolve_action(action: String, payload: Dictionary, label: String) -> void:
	var events := RulesEngineScript.resolve_player_action(state, action, payload)
	await _play_action_animation(action, "player", String(payload.get("artifact_id", "")), events)
	for event in events:
		_append_system_log(event)
		_mark_event_cards(event)
	_show_result_banner("%s?%s" % [label, _action_name(action)], _action_color(action))
	_update_state_panel()
	await get_tree().create_timer(0.35).timeout


func _run_shop_ui() -> void:
	_set_dialogue_visible(false)
	shop_done = false
	_render_shop()
	_set_status_text("第 %d 回合：%s" % [state.chapter_round + 1, _shop_scene_name()])
	if auto_growth_check != null and auto_growth_check.button_pressed:
		var auto_done := await _run_auto_shop_growth()
		if auto_done:
			if shop_panel != null:
				shop_panel.visible = false
			return
	while not shop_done and running and not state.ended:
		await get_tree().process_frame
	if shop_panel != null:
		shop_panel.visible = false


func _run_auto_shop_growth() -> bool:
	var decision := await _get_growth_decision("shop", false, false, 0)
	if bool(decision.get("cancelled", false)) or decision.has("error"):
		return false
	var buy_ids: Array = decision.get("shop_buy_ids", [])
	var summary := _growth_shop_summary(decision, buy_ids)
	var accepted: bool = await common_modal.call("show_countdown_message", "自己成长", summary, AUTO_CONFIRM_SECONDS, "取消")
	if not accepted:
		_append_system_log("你取消了自动成长，进入手动商店?")
		return false
	var bought := false
	for artifact_id in buy_ids:
		var id := String(artifact_id)
		if not _can_buy_artifact(id):
			_append_system_log("自动成长跳过无法购买的法器：%s?" % id)
			continue
		for event in RulesEngineScript.buy_player_artifact(state, id):
			_append_system_log(event)
			bought = true
	_update_state_panel()
	shop_done = true
	if bought:
		_show_result_banner("自己成长：已购买法器", Color(1.0, 0.82, 0.34, 1.0))
	else:
		_show_result_banner("自己成长：跳过商?", Color(0.82, 0.90, 1.0, 1.0))
	return true


func _growth_shop_summary(decision: Dictionary, buy_ids: Array) -> String:
	var lines: Array[String] = []
	var thinking := String(decision.get("thinking", "")).strip_edges()
	if not thinking.is_empty():
		lines.append("思考：%s" % thinking)
	if buy_ids.is_empty():
		lines.append("商店：不购买，直接离开?")
	else:
		var names: Array[String] = []
		for artifact_id in buy_ids:
			names.append(state.artifact_name(String(artifact_id)))
		lines.append("商店：购买 %s" % "、".join(names))
	return "\n".join(lines)


func _can_buy_artifact(artifact_id: String) -> bool:
	if artifact_id.is_empty() or not artifact_id in state.shop_items:
		return false
	var artifact: Dictionary = state.get_artifact(artifact_id)
	if artifact.is_empty():
		return false
	return int(state.player.get("energy", 0)) >= int(artifact.get("price", 0))


func _confirm_npc_offer(npc_response: Dictionary) -> Dictionary:
	if not npc_response.has("gift_offer") and not npc_response.has("exchange_offer"):
		return npc_response
	var detail := ""
	if npc_response.has("gift_offer"):
		var offer: Dictionary = npc_response.get("gift_offer", {})
		detail = "%s 愿意赠送：%s\n接受后该法器会加入你的背包?" % [
			state.current_npc().get("public_name", "对手"),
			state.artifact_name(String(offer.get("artifact_id", "")))
		]
	else:
		var offer: Dictionary = npc_response.get("exchange_offer", {})
		detail = "%s 想用 %s 交换你的 %s。\n接受后交易会立即完成?" % [
			state.current_npc().get("public_name", "对手"),
			state.artifact_name(String(offer.get("npc_artifact_id", ""))),
			state.artifact_name(String(offer.get("player_artifact_id", "")))
		]
	var accepted: bool = await common_modal.call("show_message", "对方提出交易", detail, "接受", "拒绝")
	if accepted:
		return npc_response
	var cleaned := npc_response.duplicate(true)
	cleaned.erase("gift_offer")
	cleaned.erase("exchange_offer")
	_append_system_log("你拒绝了对方的交易?")
	return cleaned


func _npc_response_resolved_dialogue(npc_response: Dictionary) -> bool:
	var action := String(npc_response.get("action", "none")).strip_edges().to_lower()
	return action == "assassinate" or action == "duel" or state.ended


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
	var title := shop_panel.get_node_or_null("TitleLabel") as Label
	if title != null:
		title.text = _shop_scene_name()
	_apply_shop_status_bar()
	_apply_round_player_card(shop_panel.get_node_or_null("PlayerCard") as Control)
	_refresh_shop_requirement_panels()
	_apply_shop_items()
	_apply_shop_close_button()
	_apply_shop_continue_button()
	_wire_right_utility_buttons(shop_panel.get_node_or_null("RightUtilityButtons") as Control)


func _apply_shop_manifest_layout() -> void:
	if shop_panel == null:
		return
	var manifest := _load_shop_manifest()
	if manifest.is_empty() or not manifest.has("layout"):
		return
	var layout: Dictionary = manifest.get("layout", {})
	var base_size: Array = layout.get("base_size", [1672, 941])
	if base_size.size() < 2:
		return
	var base := Vector2(float(base_size[0]), float(base_size[1]))
	var nodes: Dictionary = layout.get("nodes", {})
	for node_path in nodes.keys():
		var node := shop_panel.get_node_or_null(String(node_path)) as Control
		if node == null:
			continue
		var rect_values: Array = nodes[node_path]
		if rect_values.size() < 4:
			continue
		var rect := Rect2(
			float(rect_values[0]) / base.x,
			float(rect_values[1]) / base.y,
			float(rect_values[2]) / base.x,
			float(rect_values[3]) / base.y
		)
		_place_ratio(node, rect)
	var fonts: Dictionary = layout.get("fonts", {})
	for node_path in fonts.keys():
		var label := shop_panel.get_node_or_null(String(node_path)) as Label
		if label != null:
			label.add_theme_font_size_override("font_size", int(fonts[node_path]))


func _load_shop_manifest() -> Dictionary:
	var path := ProjectSettings.globalize_path(SHOP_MANIFEST_PATH)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _apply_shop_status_bar() -> void:
	_apply_bag_resource_bar(shop_panel.get_node_or_null("BagResourceBar") as Control)


func _apply_bag_resource_bar(root: Control) -> void:
	if root == null or state == null:
		return
	var energy := root.get_node_or_null("EnergyPlate/EnergyValue") as Label
	if energy != null:
		energy.text = str(int(state.player.get("energy", 0)))
	var capacity := root.get_node_or_null("CapacityPlate/CapacityValue") as Label
	if capacity != null:
		var inventory: Array = state.player.get("inventory", [])
		capacity.text = "%d/%d" % [inventory.size(), INVENTORY_CAPACITY]


func _apply_shop_close_button() -> void:
	var close_button := shop_panel.get_node_or_null("CloseButton") as BaseButton
	if close_button == null:
		return
	if not close_button.has_meta("shop_close_wired"):
		close_button.set_meta("shop_close_wired", true)
		close_button.pressed.connect(_close_shop_page)
	_wire_button_feedback([close_button])


func _apply_shop_continue_button() -> void:
	var continue_button := shop_panel.get_node_or_null("ContinueButton") as Button
	if continue_button == null:
		return
	StandardButtonScript.apply(continue_button, StandardButtonScript.PRIMARY)
	continue_button.disabled = false
	if not continue_button.has_meta("shop_continue_wired"):
		continue_button.set_meta("shop_continue_wired", true)
		continue_button.pressed.connect(_close_shop_page)
	_wire_button_feedback([continue_button])


func _close_shop_page() -> void:
	if common_modal != null and common_modal.visible and common_modal.has_method("confirm"):
		common_modal.call("confirm")
	shop_done = true
	if shop_panel != null and is_instance_valid(shop_panel):
		shop_panel.visible = false
	_update_modal_backdrop()


func _refresh_shop_requirement_panels() -> void:
	if shop_panel == null:
		return
	_refresh_inventory_requirement_grid(
		shop_panel.get_node_or_null("RequirementPanel/DominionRequirementGrid") as GridContainer,
		state.player.get("dominion_requirement", []),
		state.player.get("artifact_history", []),
		"teal"
	)
	_refresh_inventory_requirement_grid(
		shop_panel.get_node_or_null("RequirementPanel/AscensionRequirementGrid") as GridContainer,
		state.player.get("ascension_requirement", []),
		state.player.get("inventory", []),
		"red"
	)


func _apply_shop_requirement_panel(panel: Control, title: String, required: Array, owned: Array, tone: String) -> void:
	if panel == null:
		return
	var panel_asset := "shop_requirement_panel_red.png" if tone == "red" else "shop_requirement_panel_teal.png"
	_set_texture_rect(panel.get_node_or_null("Background") as TextureRect, _shop_texture(panel_asset))
	var title_back := panel.get_node_or_null("Box/TitleBack") as TextureRect
	if title_back != null:
		title_back.texture = _shop_texture("shop_requirement_title_red.png" if tone == "red" else "shop_requirement_title_teal.png")
	var title_label := panel.get_node_or_null("Box/TitleBack/Title") as Label
	if title_label == null:
		title_label = panel.get_node_or_null("Box/Title") as Label
	if title_label != null:
		title_label.text = title
		title_label.add_theme_color_override("font_color", Color.WHITE)
	var slots := panel.get_node_or_null("Box/Slots") as HBoxContainer
	if slots == null:
		return
	_clear_children(slots)
	for i in range(6):
		if i < required.size():
			var artifact_id := String(required[i])
			slots.add_child(_make_artifact_slot(artifact_id, artifact_id in owned, _artifact_count(owned, artifact_id)))
		else:
			slots.add_child(_make_artifact_slot("", false, 0))


func _apply_shop_items() -> void:
	var slots := _get_shop_control("ShopItemSlots")
	if slots == null:
		return
	for i in range(3):
		var card := slots.get_node_or_null("ShopItem%d" % [i + 1]) as Control
		if card == null:
			continue
		card.visible = i < state.shop_items.size()
		if card.visible:
			_apply_shop_item_card(card, String(state.shop_items[i]), i)


func _get_shop_control(node_name: String) -> Control:
	if shop_panel == null:
		return null
	var direct := shop_panel.get_node_or_null(node_name) as Control
	if direct != null:
		return direct
	return shop_panel.find_child(node_name, true, false) as Control


func _apply_shop_item_card(card: Control, artifact_id: String, index: int) -> void:
	var artifact: Dictionary = state.get_artifact(artifact_id)
	var icon := card.get_node_or_null("Content/ArtifactFrame/ArtifactSlot/Root/Icon") as TextureRect
	if icon != null:
		icon.visible = not artifact_id.is_empty()
		icon.modulate.a = 1.0
		_set_texture_or_fallback(icon, _artifact_icon_path(artifact_id), "res://assets/generated/ui/card/artifact_moon_lantern.png")
	var artifact_slot := card.get_node_or_null("Content/ArtifactFrame/ArtifactSlot") as Control
	if artifact_slot != null:
		artifact_slot.tooltip_text = state.artifact_name(artifact_id)
	var title := card.get_node_or_null("Content/NameLabel") as Label
	if title != null:
		title.text = String(artifact.get("name", artifact_id))
	var price := int(artifact.get("price", 0))
	var can_afford := int(state.player.get("energy", 0)) >= price
	var price_label := card.get_node_or_null("Content/PriceRow/PriceLabel") as Label
	if price_label != null:
		price_label.text = "%d" % price
	var button := card.get_node_or_null("Content/BuyButton") as Button
	if button != null:
		StandardButtonScript.apply(button, StandardButtonScript.PRIMARY)
		button.tooltip_text = String(artifact.get("story", ""))
		button.disabled = not can_afford
		_disconnect_pressed_connections(button)
		button.pressed.connect(func(item_id := artifact_id):
			for event in RulesEngineScript.buy_player_artifact(state, item_id):
				_append_system_log(event)
			_update_state_panel()
			_render_shop()
		)
		_wire_button_feedback([button])


func _apply_shop_item_card_frame(card: Control, tone: String) -> void:
	var frame := card.get_node_or_null("RuntimeBackgroundPanel") as NinePatchRect
	CommonFrameScript.apply_background_panel(frame, _shop_frame_color(tone))


func _apply_shop_item_artifact_frame(card: Control, tone: String) -> void:
	var root := card.get_node_or_null("Content/ArtifactFrame") as Control
	if root == null:
		return
	var frame := root.get_node_or_null("RuntimeArtifactPanel") as NinePatchRect
	CommonFrameScript.apply_background_panel(frame, _shop_frame_color(tone))


func _shop_frame_color(tone: String) -> String:
	match tone:
		"red":
			return CommonFrameScript.DARK_RED
		"teal":
			return CommonFrameScript.DARK_TEAL
		"purple":
			return CommonFrameScript.DARK_PURPLE
		_:
			return CommonFrameScript.GOLD


func _shop_label_asset(tone: String) -> String:
	match tone:
		"red":
			return "label_red.png"
		"teal":
			return "label_teal.png"
		"purple":
			return "label_purple.png"
		_:
			return "label_gold.png"


func _build_shop_status_bar() -> void:
	var player_energy := int(state.player.get("energy", 0))
	var inventory: Array = state.player.get("inventory", [])
	var panel := _make_shop_panel("shop_status_bar_dark.png", 26)
	_place_ratio(panel, Rect2(0.695, 0.070, 0.265, 0.060))
	shop_box.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_make_shop_resource_label("?%能量", str(player_energy), Color(1.0, 0.30, 0.28, 1.0)))
	row.add_child(_make_shop_resource_label("?%背包", str(inventory.size()), Color(1.0, 0.73, 0.16, 1.0)))


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
	_place_absolute(banner, Rect2(-23.0, 17.333, 419.667, 90.0))
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.texture = _load_texture_any("res://assets/ui/common/title_banner_red.png")
	shop_box.add_child(banner)
	var title := _make_shop_text_label(_shop_scene_name(), 35, Color(0.964706, 0.913725, 0.796078, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	title.add_theme_constant_override("outline_size", 3)
	_place_absolute(title, Rect2(36.0, 26.0, 200.0, 54.666))
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
	var price_label := _make_shop_plate_label("%d" % price, "shop_price_plate_dark.png", 23, Vector2(0, 40))
	box.add_child(price_label)
	var button: Button = _make_shop_button("购买", can_afford)
	StandardButtonScript.apply(button, StandardButtonScript.PRIMARY, "购买", 23)
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
	button.text = text
	button.disabled = not enabled
	return button


func _style_icon_button_shell(button: Button) -> void:
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())


func _style_shop_button(button: Button, text: String, enabled: bool, font_size: int = 23) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StandardButtonScript.apply(button, StandardButtonScript.PRIMARY, text, font_size)
	button.disabled = not enabled


func _style_primary_button(button: Button, text: String, font_size: int) -> void:
	StandardButtonScript.apply(button, StandardButtonScript.PRIMARY, text, font_size)


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
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = max(8, margin / 2)
	style.content_margin_right = max(8, margin / 2)
	style.content_margin_top = max(8, margin / 2)
	style.content_margin_bottom = max(8, margin / 2)
	return style


func _shop_texture_style_any(assets: Array, margin: int) -> StyleBoxTexture:
	for asset in assets:
		var texture := _shop_texture(String(asset))
		if texture != null:
			var style := StyleBoxTexture.new()
			style.texture = texture
			style.texture_margin_left = margin
			style.texture_margin_right = margin
			style.texture_margin_top = margin
			style.texture_margin_bottom = margin
			style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			style.content_margin_left = max(8, margin / 2)
			style.content_margin_right = max(8, margin / 2)
			style.content_margin_top = max(8, margin / 2)
			style.content_margin_bottom = max(8, margin / 2)
			return style
	return _shop_texture_style(String(assets[0]), margin)


func _shop_texture(asset: String) -> Texture2D:
	for root in [SHOP_UI_ROOT, SHOP_COMMON_UI_ROOT, SHOP_LEGACY_UI_ROOT]:
		var texture := _load_texture_any(String(root) + asset)
		if texture != null:
			return texture
	return null


func _set_texture_rect(rect: TextureRect, texture: Texture2D) -> void:
	if rect == null:
		return
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE


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
		"bg_antidote_backroom.png":
			return "解药后室"
		"bg_ash_map_balcony.png":
			return "灰烬地图露台"
		"bg_bone_scale_counter.png":
			return "骨秤柜台"
		"bg_embassy_garden.png":
			return "使节花园"
		"bg_border_watchtower.png":
			return "边门瞭望?"
		"bg_burned_catalog_room.png":
			return "焚目录室"
		"bg_debt_auction_stage.png":
			return "债契拍卖?"
		"bg_duel_alley.png":
			return "暗巷药铺"
		"bg_duelist_courtyard.png":
			return "礼剑?"
		"bg_embassy_bell_bridge.png":
			return "使馆铃桥"
		"bg_border_gate.png":
			return "边境关门"
		"bg_gate_supply_yard.png":
			return "关门军需?"
		"bg_ink_well_stair.png":
			return "墨井阶梯"
		"bg_lantern_roofwalk.png":
			return "月灯屋脊"
		"bg_mask_tailor_shop.png":
			return "假面裁缝?"
		"bg_mirror_pavilion.png":
			return "回声镜亭"
		"bg_moon_market.png":
			return "月息夜市"
		"bg_oath_blade_checkpoint.png":
			return "誓刃检查口"
		"bg_poison_vial_window.png":
			return "毒瓶橱窗"
		"bg_rain_gutter_alley.png":
			return "雨槽暗巷"
		"bg_sealed_reading_desk.png":
			return "封印阅览?"
		"bg_silent_coin_booth.png":
			return "默契铜币?"
		"bg_smuggler_drain_gate.png":
			return "走私排水?"
		"bg_treaty_flower_bed.png":
			return "誓约花圃"
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


func _place_absolute(node: Control, rect: Rect2) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.position.x + rect.size.x
	node.offset_bottom = rect.position.y + rect.size.y


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
	if auto_growth_check != null and auto_growth_check.button_pressed:
		var auto_done := await _run_auto_ascension_growth(can_ascend, can_dominate)
		if auto_done:
			upgrade_panel.visible = false
			_update_state_panel()
			return
	while not upgrade_done and running and not state.ended:
		await get_tree().process_frame
	upgrade_panel.visible = false
	_update_state_panel()


func _run_auto_ascension_growth(can_ascend: bool, can_dominate: bool) -> bool:
	var points := 3 if can_ascend else 0
	var decision := await _get_growth_decision("ascension", can_ascend, can_dominate, points)
	if bool(decision.get("cancelled", false)) or decision.has("error"):
		return false
	var body := _growth_ascension_summary(decision)
	var accepted: bool = await common_modal.call("show_countdown_message", "自己成长", body, AUTO_CONFIRM_SECONDS, "取消")
	if not accepted:
		_append_system_log("你取消了自动成长，进入手动升华?")
		return false
	if bool(decision.get("choose_dominion", false)) and can_dominate:
		state.player_declared_dominion = true
		for event in RulesEngineScript.finish_round(state):
			_append_system_log(event)
			_mark_event_cards(event)
		upgrade_done = true
		return true
	if can_ascend:
		var gains := _sanitize_stat_gains(decision.get("stat_gains", {}), points)
		if gains.is_empty() and not bool(decision.get("skip", false)):
			gains = {"charm": 1, "hp": 1, "assassination_defense": 1}
		if not gains.is_empty():
			for event in RulesEngineScript.ascend_player(state, gains):
				_append_system_log(event)
			upgrade_done = true
			return true
	upgrade_done = true
	return true


func _growth_ascension_summary(decision: Dictionary) -> String:
	var lines: Array[String] = []
	var thinking := String(decision.get("thinking", "")).strip_edges()
	if not thinking.is_empty():
		lines.append("思考：%s" % thinking)
	if bool(decision.get("choose_dominion", false)):
		lines.append("选择：统治本?")
	var gains: Dictionary = decision.get("stat_gains", {})
	if not gains.is_empty():
		var parts: Array[String] = []
		for stat in gains.keys():
			var value := int(gains[stat])
			if value > 0:
				parts.append("%s +%d" % [_stat_name(String(stat)), value])
		if not parts.is_empty():
			lines.append("升华?%s" % "?".join(parts))
	if lines.size() <= 1:
		lines.append("选择：跳过升?%统治，继续推进?")
	return "\n".join(lines)


func _sanitize_stat_gains(raw, points: int) -> Dictionary:
	var allowed := ["hp", "frontal_attack", "frontal_defense", "assassination_attack", "assassination_defense", "charm"]
	var gains := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return gains
	var used := 0
	for stat in allowed:
		var value := clampi(int(raw.get(stat, 0)), 0, points - used)
		if value > 0:
			gains[stat] = value
			used += value
		if used >= points:
			break
	return gains


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
	var bg := upgrade_panel.get_node_or_null("Background") as TextureRect
	if bg != null:
		bg.texture = _load_texture_any(_current_shop_background_path())
	var title := upgrade_panel.get_node_or_null("TitleLabel") as Label
	if title != null:
		title.text = _ascension_scene_name()
	_apply_round_player_card(upgrade_panel.get_node_or_null("PlayerCard") as Control)
	_refresh_ascension_requirement_panels()
	_update_ascension_stat_rows()
	var close_button := upgrade_panel.get_node_or_null("CloseButton") as BaseButton
	if close_button != null:
		if not close_button.has_meta("ascension_close_wired"):
			close_button.set_meta("ascension_close_wired", true)
			close_button.pressed.connect(_close_ascension_page)
		_wire_button_feedback([close_button])
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
			_style_primary_button(minus, "?", 22)
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
	_wire_right_utility_buttons(upgrade_panel.get_node_or_null("RightUtilityButtons") as Control)

func _close_ascension_page() -> void:
	upgrade_done = true
	if upgrade_panel != null and is_instance_valid(upgrade_panel):
		upgrade_panel.visible = false
	_update_modal_backdrop()


func _refresh_ascension_requirement_panels() -> void:
	if upgrade_panel == null or state == null:
		return
	_refresh_inventory_requirement_grid(
		upgrade_panel.get_node_or_null("RequirementPanel/DominionRequirementGrid") as GridContainer,
		state.player.get("dominion_requirement", []),
		state.player.get("artifact_history", []),
		"teal"
	)
	_refresh_inventory_requirement_grid(
		upgrade_panel.get_node_or_null("RequirementPanel/AscensionRequirementGrid") as GridContainer,
		state.player.get("ascension_requirement", []),
		state.player.get("inventory", []),
		"red"
	)


func _update_ascension_stat_rows() -> void:
	if upgrade_panel == null or state == null:
		return
	var pending := upgrade_panel.get_node_or_null("PendingPointsLabel") as Label
	if pending != null:
		pending.text = "剩余属性点?%d" % pending_stat_points
	var controls := upgrade_panel.get_node_or_null("StatControls") as Control
	if controls == null:
		return
	var rows := {
		"hp": ["HpNameLabel", "HpValueLabel"],
		"frontal_attack": ["FrontalAttackNameLabel", "FrontalAttackValueLabel"],
		"frontal_defense": ["FrontalDefenseNameLabel", "FrontalDefenseValueLabel"],
		"assassination_attack": ["AssassinationAttackNameLabel", "AssassinationAttackValueLabel"],
		"assassination_defense": ["AssassinationDefenseNameLabel", "AssassinationDefenseValueLabel"],
		"charm": ["CharmNameLabel", "CharmValueLabel"]
	}
	var stats: Dictionary = state.player.get("stats", {})
	var gains: Dictionary = selected_upgrade if typeof(selected_upgrade) == TYPE_DICTIONARY else {}
	for stat in rows.keys():
		var paths: Array = rows[stat]
		var name_label := controls.get_node_or_null(String(paths[0])) as Label
		if name_label != null:
			name_label.text = _stat_name(String(stat))
		var value_label := controls.get_node_or_null(String(paths[1])) as Label
		if value_label != null:
			var current := int(stats.get(stat, 0))
			var preview := current + int(gains.get(stat, 0))
			value_label.text = "%d -> %d" % [current, preview]


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
	if OS.has_feature("web"):
		return null
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _round_texture(name: String) -> Texture2D:
	return _load_texture_any(ROUND_UI_ROOT + name)


func _round_texture_style(name: String, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _round_texture(name)
	style.texture_margin_left = 0
	style.texture_margin_right = 0
	style.texture_margin_top = 0
	style.texture_margin_bottom = 0
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = max(6, margin / 2)
	style.content_margin_right = max(6, margin / 2)
	style.content_margin_top = max(4, margin / 3)
	style.content_margin_bottom = max(4, margin / 3)
	return style


func _icon_tile_name(icon_name: String) -> String:
	return "icon_tile_%s" % icon_name.trim_prefix("icon_")


func _select_card_shadow_material(bounds := Vector4(0.0, 0.0, 1.0, 1.0)) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float visible_top = 0.0;
uniform float visible_bottom = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float visible_span = max(visible_bottom - visible_top, 0.001);
	float card_y = clamp((UV.y - visible_top) / visible_span, 0.0, 1.0);
	float alpha = smoothstep(0.40, 1.0, card_y) * 0.80;
	COLOR = vec4(0.0, 0.0, 0.0, alpha * tex.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("visible_top", bounds.y)
	material.set_shader_parameter("visible_bottom", bounds.w)
	return material


func _select_card_alpha_bounds(texture: Texture2D) -> Vector4:
	if texture == null:
		return Vector4(0.0, 0.0, 1.0, 1.0)
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if select_card_alpha_bounds_cache.has(cache_key):
		return select_card_alpha_bounds_cache[cache_key]
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Vector4(0.0, 0.0, 1.0, 1.0)
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a > 0.02:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < 0 or max_y < 0:
		return Vector4(0.0, 0.0, 1.0, 1.0)
	var bounds := Vector4(
		float(min_x) / float(width),
		float(min_y) / float(height),
		float(max_x + 1) / float(width),
		float(max_y + 1) / float(height)
	)
	select_card_alpha_bounds_cache[cache_key] = bounds
	return bounds


func _add_select_card_shadow_mask(parent: Control) -> TextureRect:
	var mask := TextureRect.new()
	mask.name = "BottomShadowMask"
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var card_texture := parent.get_node_or_null("CardTexture") as TextureRect
	if card_texture != null:
		mask.texture = card_texture.texture
		mask.stretch_mode = card_texture.stretch_mode
		mask.expand_mode = card_texture.expand_mode
		mask.material = _select_card_shadow_material(_select_card_alpha_bounds(card_texture.texture))
	else:
		mask.material = _select_card_shadow_material()
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
		mask.material = _select_card_shadow_material(_select_card_alpha_bounds(card_texture.texture))
		parent.move_child(mask, card_texture.get_index() + 1)


func _place_select_choose_button(button: Button) -> void:
	_place_by_ratio(button, Rect2(0.230, 0.742, 0.540, 0.060))


func _apply_select_stat_rows(stats: Control, rows: Array) -> bool:
	var has_scene_rows := false
	for i in range(4):
		var row := stats.get_node_or_null("StatRow%d" % [i + 1]) as Control
		if row == null:
			continue
		has_scene_rows = true
		row.visible = i < rows.size()
		if i >= rows.size():
			continue
		var name := row.get_node_or_null("NameLabel") as Label
		if name != null:
			name.text = String(rows[i][0])
		var value := row.get_node_or_null("ValueLabel") as Label
		if value != null:
			value.text = String(rows[i][1])
	return has_scene_rows


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
	row.add_theme_stylebox_override("panel", _round_texture_style("item_row_dark.png", 18))
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
		[Rect2(0.916, 0.285, 0.050, 0.070), _show_inventory_overlay],
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
	if text.contains("缁熸?"):
		tone = "purple"
	elif text.contains("鍗囧?") or text.contains("璐?"):
		tone = "red"
	return card_kit.make_plate_label(text, tone, 26, Vector2(0, 58))


func _make_requirement_panel(title: String, requirements: Array, owned_source: Array) -> PanelContainer:
	var panel: PanelContainer = card_kit.make_requirement_panel(title, "purple" if title.contains("缁熸?") else "red")
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
	if id.contains("wolf") or species.contains("?"):
		return "avatar_wolf_card.png"
	return "avatar_fox_card.png"


func _npc_card_tag(npc: Dictionary, index: int) -> String:
	if index == 0:
		return "高风?"
	if index == 1:
		return "情报"
	return "同族"
func _make_card_utility_column() -> Control:
	var utility := RightUtilityButtonsScene.instantiate() as Control
	utility.name = "RightUtilityButtons"
	utility.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wire_right_utility_buttons(utility)
	return utility

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
	_sync_guidelines_from_page()
	if llm_client.use_mock_llm():
		dialogue_title.text = "思考中"
		dialogue_view.clear()
		_prepare_llm_stream("player_llm", "你方", Color(0.58, 0.82, 1.0, 1.0))
		var npc: Dictionary = state.current_npc()
		var mock := {}
		mock["thinking"] = "我先试探对方对世界设定和法器的理解，不急着动手?"
		mock["speech"] = "听说%s附近有些法器换手很快。若我们各有所需，也许能谈一笔交换?" % npc.get("territory", "这里")
		mock["action"] = "none"
		mock["artifact_id"] = ""
		mock["end_dialogue"] = state.turn >= state.max_dialogue_turns
		await llm_client.chat_json("player_llm", "", "", mock, true)
		streaming_section = ""
		return mock
	var fallback := {"thinking": "先谨慎试探?", "speech": "我想先听听你怎么看最近的传闻?", "action": "none", "artifact_id": "", "end_dialogue": false}
	return await _request_llm_with_retry(
		"player_llm",
		PromptBuilderScript.player_dialogue_system(state),
		PromptBuilderScript.player_dialogue_user(state, _behavior_guideline_text(), _identity_guideline_text()),
		fallback,
		true,
		"你方",
		Color(0.58, 0.82, 1.0, 1.0),
		true,
		"思考中"
	)


func _get_council_player_dialogue() -> Dictionary:
	var first_crime := CouncilRulesEngineScript.best_progress_crime(state, String(state.current_npc().get("id", "")))
	var fallback := {
		"thinking": "先用倾向试探对方。",
		"speech": "我想先确认一件事：你是否认为这项罪行已经严重到必须投有罪票？",
		"action": "declare_tendency",
		"target_crime_id": first_crime,
		"vote": "guilty",
		"end_dialogue": false
	}
	if state.turn >= 2 or state.chapter_round >= 1:
		fallback["thinking"] = "需要推动正式投票，让局势进入结算。"
		fallback["speech"] = "我不想再只停留在表态了，我会把这张票正式投下去。"
		fallback["action"] = "cast_vote"
		fallback["target_crime_id"] = first_crime
		fallback["vote"] = "guilty"
	if llm_client.use_mock_llm():
		_prepare_llm_stream("player_llm", "你方", Color(0.58, 0.82, 1.0, 1.0))
		await llm_client.chat_json("player_llm", "", "", fallback, true)
		return fallback
	return await _request_llm_with_retry(
		"player_llm",
		PromptBuilderScript.council_player_system(state),
		PromptBuilderScript.council_player_user(state, _behavior_guideline_text(), _identity_guideline_text()),
		fallback,
		true,
		"你方",
		Color(0.58, 0.82, 1.0, 1.0),
		true,
		"议会思考中"
	)


func _get_council_npc_dialogue() -> Dictionary:
	var target_crime := CouncilRulesEngineScript.best_progress_crime(state, String(state.current_npc().get("id", "")))
	var fallback := {
		"speech": "我不会急着把票投死，但这条罪名确实值得议会盯紧。",
		"action": "declare_tendency",
		"target_crime_id": target_crime,
		"vote": "guilty",
		"end_dialogue": false
	}
	if state.turn >= 2 or state.chapter_round >= 1:
		fallback["speech"] = "既然你已经推动到这里，我也投正式有罪票。"
		fallback["action"] = "cast_vote"
		fallback["target_crime_id"] = target_crime
		fallback["vote"] = "guilty"
		fallback["end_dialogue"] = true
	if llm_client.use_mock_llm():
		_prepare_llm_stream("npc_llm", "对方", Color(1.0, 0.61, 0.48, 1.0), false)
		await llm_client.chat_json("npc_llm", "", "", fallback, true)
		return fallback
	return await _request_llm_with_retry(
		"npc_llm",
		PromptBuilderScript.council_npc_system_v2(),
		PromptBuilderScript.council_npc_user_v2(state),
		fallback,
		true,
		"对方",
		Color(1.0, 0.61, 0.48, 1.0),
		false,
		"对方思考中"
	)


func _get_npc_dialogue() -> Dictionary:
	if llm_client.use_mock_llm():
		_prepare_llm_stream("npc_llm", "对方", Color(1.0, 0.61, 0.48, 1.0), false)
		var npc: Dictionary = state.current_npc()
		var response := {"speech": "你问得很巧。若你懂%s，就该知道礼物和代价常常是一回事?" % npc.get("liked_topics", ["规矩"])[0]}
		if int(npc.get("affinity", 0)) >= 6 and not npc.get("inventory", []).is_empty():
			response["gift_offer"] = {"artifact_id": String(npc.get("inventory", [])[0]), "affinity_required": 6}
		await llm_client.chat_json("npc_llm", "", "", response, true)
		streaming_section = ""
		return response
	var fallback := {"speech": "你的话让我有点兴趣，但我还需要更多诚意?"}
	return await _request_llm_with_retry(
		"npc_llm",
		PromptBuilderScript.npc_dialogue_system(),
		PromptBuilderScript.npc_dialogue_user(state),
		fallback,
		true,
		"对方",
		Color(1.0, 0.61, 0.48, 1.0),
		false,
		"对方思考中"
	)


func _get_post_action() -> Dictionary:
	_sync_guidelines_from_page()
	if llm_client.use_mock_llm():
		dialogue_title.text = "行动决策?"
		dialogue_view.clear()
		_prepare_llm_stream("player_llm", "", Color.WHITE)
		var mock := {"thinking": "风险不清，先撤离进入商店?", "action": "leave", "artifact_id": ""}
		await llm_client.chat_json("player_llm", "", "", mock, true)
		streaming_section = ""
		return mock
	var fallback := {"thinking": "风险不清，优先离开?", "action": "leave", "artifact_id": ""}
	return await _request_llm_with_retry(
		"player_llm",
		PromptBuilderScript.post_action_system(),
		PromptBuilderScript.post_action_user(state, _behavior_guideline_text()),
		fallback,
		true,
		"",
		Color.WHITE,
		true,
		"行动决策?"
	)


func _get_growth_decision(phase: String, can_ascend: bool = false, can_dominate: bool = false, points: int = 0) -> Dictionary:
	_sync_guidelines_from_page()
	if llm_client.use_mock_llm():
		var mock := {"thinking": "优先补齐需求，保留能量，不做无谓消费?", "shop_buy_ids": [], "stat_gains": {}, "choose_dominion": false, "skip": false}
		if phase == "shop":
			for artifact_id in state.shop_items:
				var id := String(artifact_id)
				if _can_buy_artifact(id):
					mock["shop_buy_ids"] = [id]
					break
		elif can_ascend:
			mock["stat_gains"] = {"charm": 1, "hp": 1, "assassination_defense": 1}
		elif can_dominate:
			mock["choose_dominion"] = true
		return mock
	var fallback := {"thinking": "保持谨慎，跳过自动成长?", "shop_buy_ids": [], "stat_gains": {}, "choose_dominion": false, "skip": true}
	return await llm_client.chat_json(
		"player_llm",
		PromptBuilderScript.growth_decision_system(),
		PromptBuilderScript.growth_decision_user(state, _growth_guideline_text(), phase, can_ascend, can_dominate, points),
		fallback,
		false
	)


func _get_npc_choice_decision() -> Dictionary:
	_sync_guidelines_from_page()
	if llm_client == null or llm_client.use_mock_llm():
		return _fallback_npc_choice_decision()
	var fallback := _fallback_npc_choice_decision()
	return await llm_client.chat_json(
		"player_llm",
		PromptBuilderScript.npc_choice_system(),
		PromptBuilderScript.npc_choice_user(state, _growth_guideline_text(), _npc_choice_options()),
		fallback,
		false
	)


func _fallback_npc_choice_decision() -> Dictionary:
	var best_choice := 0
	var best_score := -999999
	for i in range(state.npc_choices.size()):
		var npc_index: int = state.npc_choices[i]
		if npc_index < 0 or npc_index >= state.npcs.size():
			continue
		var npc: Dictionary = state.npcs[npc_index]
		var score := int(npc.get("affinity", 0))
		if String(npc.get("stance", "")) == "ally":
			score += 5
		if String(npc.get("stance", "")) == "enemy":
			score -= 3
		var inventory: Array = npc.get("inventory", [])
		score += inventory.size()
		if score > best_score:
			best_score = score
			best_choice = i
	return {
		"thinking": "优先选择公开信息里收益较高、风险较低的对手?",
		"choice_index": best_choice
	}


func _npc_choice_options() -> Array:
	var options: Array = []
	for i in range(state.npc_choices.size()):
		var npc_index: int = state.npc_choices[i]
		if npc_index < 0 or npc_index >= state.npcs.size():
			continue
		var npc: Dictionary = state.npcs[npc_index]
		options.append({
			"choice_index": i,
			"public_name": String(npc.get("public_name", "对手")),
			"public_identity": String(npc.get("public_identity", "")),
			"territory": String(npc.get("territory", "")),
			"affinity": int(npc.get("affinity", 0)),
			"alive": bool(npc.get("alive", true))
		})
	return options


func _get_guideline_merge(tab_id: String, base_text: String, append_text: String) -> Dictionary:
	if llm_client == null or llm_client.use_mock_llm():
		return {
			"guideline": "%s\n\n## 追加规则\n%s" % [base_text.strip_edges(), append_text.strip_edges()]
		}
	var fallback := {"guideline": base_text}
	return await llm_client.chat_json(
		"player_llm",
		PromptBuilderScript.guideline_merge_system(),
		PromptBuilderScript.guideline_merge_user(tab_id, base_text, append_text),
		fallback,
		false
	)


func _request_llm_with_retry(section: String, system_prompt: String, user_prompt: String, fallback: Dictionary, stream_text: bool, speaker: String, color: Color, clear_for_thinking: bool, title: String) -> Dictionary:
	while running and not state.ended and not manual_action_resolved:
		dialogue_title.text = title
		dialogue_view.clear()
		_hide_llm_retry_button()
		_prepare_llm_stream(section, speaker, color, clear_for_thinking)
		var result: Dictionary = await llm_client.chat_json(section, system_prompt, user_prompt, fallback, stream_text)
		streaming_section = ""
		if bool(result.get("cancelled", false)) or not result.has("error"):
			_hide_llm_retry_button()
			return result
		var should_retry := await _wait_for_llm_retry(String(result.get("error", "")))
		if not should_retry:
			return result
	var cancelled := fallback.duplicate(true)
	cancelled["cancelled"] = true
	return cancelled


func _wait_for_llm_retry(error_text: String) -> bool:
	llm_retry_requested = false
	_show_llm_retry(error_text)
	while running and not state.ended and not manual_action_resolved and not llm_retry_requested:
		await get_tree().process_frame
	if not llm_retry_requested:
		_hide_llm_retry_button()
		return false
	return true


func _show_llm_retry(error_text: String) -> void:
	dialogue_title.text = "LLM 调用失败"
	result_banner.visible = false
	dialogue_view.clear()
	dialogue_view.append_text("[color=#ff7a7a]%s[/color]" % _escape(error_text))
	_follow_dialogue_view(dialogue_view)
	if llm_retry_button != null:
		llm_retry_button.visible = true
		llm_retry_button.disabled = false
		llm_retry_button.move_to_front()


func _hide_llm_retry_button() -> void:
	llm_retry_requested = false
	if llm_retry_button != null:
		llm_retry_button.visible = false


func _on_llm_retry_pressed() -> void:
	llm_retry_requested = true
	if llm_retry_button != null:
		llm_retry_button.disabled = true


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
		current_speaker_label.text = String(npc.get("public_name", "对手"))
	npc_public_label.text = "公开资料?%s\n地盘?%s\n偏好话题?%s\n背包与需求：不可?" % [
		String(npc.get("public_identity", "未知身份")),
		String(npc.get("territory", "未知")),
		"?".join(npc.get("liked_topics", []))
	]
	_update_progress()


func _update_state_panel() -> void:
	if state == null:
		return
	if council_mode:
		_update_council_state_panel()
		return
	if player_label != null:
		player_label.text = _player_short_name()
	var stats: Dictionary = state.player.get("stats", {})
	var inventory_text := "?".join(state.describe_inventory(state.player.get("inventory", [])))
	var ascension_text := "?".join(state.describe_inventory(state.player.get("ascension_requirement", [])))
	stats_label.text = "章节?%d / %d\n回合?%d / %d\n字符?%d / %d\n能量?%d\n等级?%d\n统治?%s\n背包?%s\n升华需求：%s\n生命?%d  魅力?%d\n正面?%d/%d  暗杀?%d/%d" % [
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
		var mark := "已获?" if String(artifact_id) in state.player.get("artifact_history", []) else "未获?"
		state_view.append_text("- %s [%s]\n" % [state.artifact_name(String(artifact_id)), mark])
	state_view.append_text("\n[b]近期记忆[/b]\n")
	for item in state.recent_memory(state.player, 8):
		state_view.append_text("- %s\n" % _escape(String(item)))
	state_view.append_text("\n[b]情报卡[/b]\n")
	for question in state.world_intel_questions:
		var question_id := String(question.get("id", ""))
		var selected := String(state.selected_world_intel.get(question_id, "未选择"))
		var answer_title: String = state.world_intel_option_title(question_id, selected) if selected != "未选择" else selected
		state_view.append_text("- %s?%s\n" % [String(question.get("title", question_id)), answer_title])
	if state.ended:
		state_view.append_text("\n[b]结算[/b]\n%s\n" % state.end_reason)
	_update_card_grid()
	if intel_panel != null and intel_panel.visible:
		_update_intel_panel()
	_update_progress()


func _update_council_state_panel() -> void:
	if player_label != null:
		player_label.text = String(state.player.get("public_name", "玩家"))
	if stats_label != null:
		stats_label.text = CouncilRulesEngineScript.public_board_text(state)
	if state_view != null:
		state_view.clear()
		state_view.append_text(_escape(CouncilRulesEngineScript.public_board_text(state)))
	if status_page != null and status_page.has_method("bind_state"):
		status_page.call("bind_state", state)
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
	dialogue_title.text = "对话?"
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
	dialogue_title.text = "对话?"
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
	dialogue_title.text = "LLM 调用错误"
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
			current_speaker_label.text = String(state.current_npc().get("public_name", "对手")) if state != null and state.has_method("current_npc") else "对方"
	player_portrait.modulate = Color(1, 1, 1, 1) if role == "player" else Color(0.38, 0.38, 0.38, 1.0)
	npc_portrait.modulate = Color(1, 1, 1, 1) if role == "npc" else Color(0.38, 0.38, 0.38, 1.0)
	_shake_portrait(player_portrait if role == "player" else npc_portrait)


func _show_history() -> void:
	var summary := "第 %d / %d 章，回合 %d / %d" % [state.chapter_index + 1, state.max_chapters, state.chapter_round + 1, state.max_rounds]
	if council_mode and history_dialog != null and history_dialog.has_method("set_council_history"):
		history_dialog.call("set_council_history", _council_history_entries(), _council_history_members(), state.event_log, summary)
	elif history_dialog != null and history_dialog.has_method("set_history"):
		history_dialog.call("set_history", state.format_full_history(), state.event_log, summary)
	elif history_view != null:
		history_view.clear()
		history_view.append_text("[b]对话历史[/b]\n")
		history_view.append_text(_escape(state.format_full_history()))
		if not state.event_log.is_empty():
			history_view.append_text("\n\n[b]行动与发现[/b]\n")
			for item in state.event_log:
				history_view.append_text("- %s\n" % _escape(String(item)))
	if intel_panel != null:
		intel_panel.visible = false
	if inventory_overlay != null:
		inventory_overlay.visible = false
	if status_page != null:
		status_page.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if status_page != null:
		status_page.visible = false
	if drawer != null:
		drawer.visible = false
	if rules_panel != null:
		rules_panel.visible = false
	history_dialog.visible = true
	_show_modal_backdrop()
	_slide_in(history_dialog)


func _council_history_members() -> Array:
	var members: Array = []
	members.append({
		"id": String(state.player.get("id", "player")),
		"name": String(state.player.get("public_name", "玩家")),
		"portrait": String(state.player.get("portrait", "player_portrait.png")),
		"alive": bool(state.player.get("alive", true))
	})
	for npc in state.npcs:
		members.append({
			"id": String(npc.get("id", "")),
			"name": String(npc.get("public_name", "议员")),
			"portrait": String(npc.get("portrait", "")),
			"alive": bool(npc.get("alive", true))
		})
	return members


func _council_history_entries() -> Array:
	var entries: Array = []
	for item in state.full_dialogue_history:
		var role := String(item.get("role", ""))
		var speaker_id := "player"
		var speaker_name := String(state.player.get("public_name", "玩家"))
		var npc_index := int(item.get("npc_index", -1))
		if role != "player" and npc_index >= 0 and npc_index < state.npcs.size():
			var npc: Dictionary = state.npcs[npc_index]
			speaker_id = String(npc.get("id", ""))
			speaker_name = String(npc.get("public_name", item.get("npc_name", "议员")))
		entries.append({
			"round": int(item.get("round", 0)) + 1,
			"speaker_id": speaker_id,
			"speaker_name": speaker_name,
			"npc_name": String(item.get("npc_name", "")),
			"content": String(item.get("content", ""))
		})
	return entries


func _show_intel_panel() -> void:
	if intel_panel == null:
		_show_drawer("intel")
		return
	intel_panel.visible = true
	if inventory_overlay != null:
		inventory_overlay.visible = false
	drawer.visible = false
	rules_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if history_dialog != null:
		history_dialog.visible = false
	if status_page != null:
		status_page.visible = false
	_update_intel_panel()
	_show_modal_backdrop()
	_slide_in(intel_panel)


func _show_drawer(mode: String) -> void:
	if mode == "status" and status_page != null:
		_show_status_page()
		return
	if mode == "bag":
		_show_inventory_overlay()
		return
	drawer_mode = mode
	drawer.visible = true
	if intel_panel != null:
		intel_panel.visible = false
	if inventory_overlay != null:
		inventory_overlay.visible = false
	rules_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if history_dialog != null:
		history_dialog.visible = false
	if status_page != null:
		status_page.visible = false
	var title := drawer.get_meta("title_label") as Label
	if title != null:
		match drawer_mode:
			"bag":
				title.text = "背包"
			"status":
				title.text = "状?"
			_:
				title.text = "情报"
	_update_state_panel()
	_show_modal_backdrop()
	_slide_in(drawer)


func _show_status_page() -> void:
	if status_page == null:
		_show_drawer("status")
		return
	if status_page.has_method("bind_state"):
		status_page.call("bind_state", state)
	if intel_panel != null:
		intel_panel.visible = false
	if inventory_overlay != null:
		inventory_overlay.visible = false
	if drawer != null:
		drawer.visible = false
	if rules_panel != null:
		rules_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if history_dialog != null:
		history_dialog.visible = false
	status_page.visible = true
	_show_modal_backdrop()
	_slide_in(status_page)


func _show_council_status_gate() -> void:
	_set_dialogue_visible(false)
	_show_status_page()
	_ensure_council_continue_button()
	council_status_waiting = true
	if council_status_continue_button != null:
		council_status_continue_button.visible = true
		council_status_continue_button.disabled = false
		council_status_continue_button.move_to_front()
	while council_status_waiting and running:
		await get_tree().process_frame
	if council_status_continue_button != null:
		council_status_continue_button.visible = false
	if status_page != null:
		status_page.visible = false
	_update_modal_backdrop()


func _show_council_chapter_result_gate(final_game: bool) -> void:
	if council_result_page == null:
		return
	_set_dialogue_visible(false)
	_close_float_panels()
	if council_result_page.has_method("show_result"):
		council_result_page.call("show_result", state, final_game)
	council_result_waiting = true
	_show_modal_backdrop()
	while council_result_waiting and running:
		await get_tree().process_frame
	_update_modal_backdrop()


func _council_result_snapshot() -> Dictionary:
	var members: Array = []
	var all_members: Array = [state.player]
	for npc in state.npcs:
		all_members.append(npc)
	for member in all_members:
		members.append({
			"id": String(member.get("id", "")),
			"name": String(member.get("public_name", "")),
			"faction": String(member.get("hidden_faction", "")),
			"alive": bool(member.get("alive", true)),
			"crimes": member.get("hidden_crimes", []).duplicate()
		})
	return {
		"chapter_index": state.chapter_index,
		"title": String(state.chapter.get("title", "")),
		"victory": state.victory,
		"reason": state.end_reason,
		"members": members,
		"votes": state.council_vote_records.duplicate(true)
	}


func _ensure_council_continue_button() -> void:
	if council_status_continue_button != null and is_instance_valid(council_status_continue_button):
		return
	council_status_continue_button = StandardButtonScript.new()
	council_status_continue_button.text = "继续"
	council_status_continue_button.z_index = 4020
	council_status_continue_button.custom_minimum_size = Vector2(180, 58)
	council_status_continue_button.anchor_left = 0.5
	council_status_continue_button.anchor_right = 0.5
	council_status_continue_button.anchor_top = 1.0
	council_status_continue_button.anchor_bottom = 1.0
	council_status_continue_button.offset_left = -90
	council_status_continue_button.offset_right = 90
	council_status_continue_button.offset_top = -92
	council_status_continue_button.offset_bottom = -34
	council_status_continue_button.pressed.connect(func():
		council_status_waiting = false
	)
	status_page.add_child(council_status_continue_button)


func _show_inventory_overlay() -> void:
	if inventory_overlay == null:
		return
	_refresh_inventory_overlay()
	inventory_overlay.visible = true
	inventory_overlay.z_index = 4020
	inventory_overlay.move_to_front()
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
	if status_page != null:
		status_page.visible = false
	if modal_backdrop != null:
		modal_backdrop.visible = false
	_slide_in(inventory_overlay)


func _hide_inventory_overlay() -> void:
	if inventory_overlay != null:
		inventory_overlay.visible = false


func _refresh_inventory_overlay() -> void:
	if state == null:
		return
	if inventory_energy_label != null:
		inventory_energy_label.text = str(int(state.player.get("energy", 0)))
	var inventory: Array = state.player.get("inventory", [])
	if inventory_capacity_label != null:
		inventory_capacity_label.text = "%d/%d" % [inventory.size(), INVENTORY_CAPACITY]
	_refresh_inventory_requirement_grid(
		inventory_dominion_grid,
		state.player.get("dominion_requirement", []),
		state.player.get("artifact_history", []),
		"teal"
	)
	_refresh_inventory_requirement_grid(
		inventory_ascension_grid,
		state.player.get("ascension_requirement", []),
		inventory,
		"red"
	)
	_refresh_inventory_item_grid(inventory)


func _refresh_inventory_requirement_grid(grid: GridContainer, required_items: Array, owned_source: Array, tone: String) -> void:
	if grid == null:
		return
	var slot_size := _prepare_inventory_grid(grid, INVENTORY_REQUIREMENT_COLUMNS, max(INVENTORY_MIN_REQUIREMENT_SLOTS, required_items.size()))
	_clear_children(grid)
	var shown := 0
	for artifact_id in required_items:
		var id := String(artifact_id)
		var satisfied: bool = id in owned_source
		grid.add_child(_make_inventory_requirement_card(id, satisfied, tone, slot_size))
		shown += 1
	while shown < INVENTORY_MIN_REQUIREMENT_SLOTS:
		grid.add_child(_make_inventory_empty_requirement_slot(tone, slot_size))
		shown += 1
	_update_inventory_scroll_mode(grid, shown, slot_size)


func _refresh_inventory_item_grid(inventory: Array) -> void:
	if inventory_item_grid == null:
		return
	var slot_size := _prepare_inventory_grid(inventory_item_grid, INVENTORY_ITEM_COLUMNS, INVENTORY_CAPACITY)
	_clear_children(inventory_item_grid)
	var counts := _artifact_counts(inventory)
	var shown := 0
	for artifact_id in counts.keys():
		if shown >= INVENTORY_CAPACITY:
			break
		var id := String(artifact_id)
		inventory_item_grid.add_child(_make_inventory_item_card(id, int(counts[id]), slot_size))
		shown += 1
	while shown < INVENTORY_CAPACITY:
		inventory_item_grid.add_child(_make_inventory_empty_slot(slot_size))
		shown += 1
	_update_inventory_scroll_mode(inventory_item_grid, shown, slot_size)


func _make_inventory_requirement_card(artifact_id: String, satisfied: bool, _tone: String, slot_size: Vector2) -> Control:
	var card := TextureRect.new()
	card.custom_minimum_size = slot_size
	card.tooltip_text = state.artifact_name(artifact_id)
	card.texture = _round_texture("bag_card_dark.png")
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_inventory_scaled_rect(icon, Rect2(14, 10, 88, 88), INVENTORY_REQUIREMENT_SLOT_SIZE, slot_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture_or_fallback(icon, _artifact_icon_path(artifact_id), "res://assets/generated/ui/card/artifact_moon_lantern.png")
	icon.modulate = Color.WHITE
	icon.material = _inventory_grayscale_icon_material()
	card.add_child(icon)
	var state_label := _make_inventory_text_label("1/1" if satisfied else "0/1", _scale_inventory_font(20, INVENTORY_REQUIREMENT_SLOT_SIZE, slot_size), Color(0.72, 1.0, 0.86, 1.0) if satisfied else Color(1.0, 0.46, 0.42, 1.0))
	state_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_inventory_scaled_rect(state_label, Rect2(2, 88, 112, 26), INVENTORY_REQUIREMENT_SLOT_SIZE, slot_size)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(state_label)
	return card


func _make_inventory_empty_requirement_slot(_tone: String, slot_size: Vector2) -> Control:
	var slot := TextureRect.new()
	slot.custom_minimum_size = slot_size
	slot.texture = _round_texture("bag_card_dark.png")
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_SCALE
	return slot


func _inventory_grayscale_icon_material() -> ShaderMaterial:
	if inventory_grayscale_material != null:
		return inventory_grayscale_material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray), tex.a) * COLOR;
}
"""
	inventory_grayscale_material = ShaderMaterial.new()
	inventory_grayscale_material.shader = shader
	return inventory_grayscale_material


func _make_inventory_item_card(artifact_id: String, count: int, slot_size: Vector2) -> Control:
	var card := TextureRect.new()
	card.custom_minimum_size = slot_size
	card.tooltip_text = state.artifact_name(artifact_id)
	card.texture = _round_texture("bag_card_orange.png")
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_inventory_scaled_rect(icon, Rect2(6, 6, 104, 104), INVENTORY_ITEM_SLOT_SIZE, slot_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture_or_fallback(icon, _artifact_icon_path(artifact_id), "res://assets/generated/ui/card/artifact_moon_lantern.png")
	card.add_child(icon)
	if count > 1:
		var count_label := _make_inventory_text_label("x%d" % count, _scale_inventory_font(20, INVENTORY_ITEM_SLOT_SIZE, slot_size), Color.WHITE)
		count_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_apply_inventory_scaled_rect(count_label, Rect2(58, 82, 52, 28), INVENTORY_ITEM_SLOT_SIZE, slot_size)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(count_label)
	return card


func _make_inventory_empty_slot(slot_size: Vector2) -> Control:
	var slot := TextureRect.new()
	slot.custom_minimum_size = slot_size
	slot.texture = _round_texture("bag_card_dark.png")
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_SCALE
	return slot


func _prepare_inventory_grid(grid: GridContainer, columns: int, item_count: int) -> Vector2:
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	var viewport := _ensure_inventory_scroll_viewport(grid)
	var viewport_width := viewport.size.x
	if viewport_width <= 0.0:
		viewport_width = grid.size.x
	if viewport_width <= 0.0:
		viewport_width = grid.custom_minimum_size.x
	if viewport_width <= 0.0:
		viewport_width = INVENTORY_ITEM_SLOT_SIZE.x * columns
	var slot_edge: float = floor(viewport_width / max(1, columns))
	var slot_size := Vector2(slot_edge, slot_edge)
	var row_count := int(ceil(float(max(1, item_count)) / float(max(1, columns))))
	grid.custom_minimum_size = Vector2(viewport_width, row_count * slot_size.y)
	grid.size = grid.custom_minimum_size
	return slot_size


func _ensure_inventory_scroll_viewport(grid: GridContainer) -> Control:
	var parent := grid.get_parent()
	if parent is ScrollContainer:
		return parent as ScrollContainer
	var original_parent := parent as Control
	if original_parent == null:
		return grid
	var scroll := ScrollContainer.new()
	scroll.name = "%sScroll" % grid.name
	scroll.layout_mode = grid.layout_mode
	scroll.anchor_left = grid.anchor_left
	scroll.anchor_top = grid.anchor_top
	scroll.anchor_right = grid.anchor_right
	scroll.anchor_bottom = grid.anchor_bottom
	scroll.offset_left = grid.offset_left
	scroll.offset_top = grid.offset_top
	scroll.offset_right = grid.offset_right
	scroll.offset_bottom = grid.offset_bottom
	scroll.grow_horizontal = grid.grow_horizontal
	scroll.grow_vertical = grid.grow_vertical
	scroll.custom_minimum_size = grid.custom_minimum_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var index := grid.get_index()
	original_parent.add_child(scroll)
	original_parent.move_child(scroll, index)
	original_parent.remove_child(grid)
	grid.owner = null
	scroll.add_child(grid)
	grid.set_anchors_preset(Control.PRESET_TOP_LEFT)
	grid.offset_left = 0
	grid.offset_top = 0
	grid.offset_right = 0
	grid.offset_bottom = 0
	grid.size_flags_horizontal = Control.SIZE_FILL
	grid.size_flags_vertical = Control.SIZE_FILL
	return scroll


func _update_inventory_scroll_mode(grid: GridContainer, item_count: int, slot_size: Vector2) -> void:
	var parent := grid.get_parent()
	if not parent is ScrollContainer:
		return
	var scroll := parent as ScrollContainer
	var rows := int(ceil(float(max(1, item_count)) / float(max(1, grid.columns))))
	var content_height := rows * slot_size.y
	var content_width := scroll.size.x
	if content_width <= 0.0:
		content_width = grid.custom_minimum_size.x
	if content_width <= 0.0:
		content_width = slot_size.x * max(1, grid.columns)
	var viewport_height := scroll.size.y
	if viewport_height <= 0.0:
		viewport_height = scroll.custom_minimum_size.y
	grid.custom_minimum_size = Vector2(content_width, content_height)
	grid.size = grid.custom_minimum_size
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if content_height > viewport_height + 0.5 else ScrollContainer.SCROLL_MODE_DISABLED


func _apply_inventory_scaled_rect(control: Control, base_rect: Rect2, base_size: Vector2, slot_size: Vector2) -> void:
	var scale := Vector2(slot_size.x / base_size.x, slot_size.y / base_size.y)
	control.offset_left = floor(base_rect.position.x * scale.x)
	control.offset_top = floor(base_rect.position.y * scale.y)
	control.offset_right = ceil((base_rect.position.x + base_rect.size.x) * scale.x)
	control.offset_bottom = ceil((base_rect.position.y + base_rect.size.y) * scale.y)


func _scale_inventory_font(base_font_size: int, base_size: Vector2, slot_size: Vector2) -> int:
	var scale: float = min(slot_size.x / base_size.x, slot_size.y / base_size.y)
	return maxi(10, int(round(float(base_font_size) * scale)))


func _make_inventory_empty_label(text: String) -> Label:
	var label := _make_inventory_text_label(text, 18, Color(0.74, 0.70, 0.66, 1.0))
	label.custom_minimum_size = Vector2(466, 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_inventory_text_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.96))
	_apply_ui_font(label)
	return label


func _toggle_rules() -> void:
	rules_panel.visible = not rules_panel.visible
	if rules_panel.visible:
		if rules_panel.has_method("set_locked"):
			rules_panel.call("set_locked", false)
		if auto_decide_check != null:
			auto_decide_check.visible = true
		if auto_growth_check != null:
			auto_growth_check.visible = true
		drawer.visible = false
		if intel_panel != null:
			intel_panel.visible = false
		if inventory_overlay != null:
			inventory_overlay.visible = false
		if settings_panel != null:
			settings_panel.visible = false
		if history_dialog != null:
			history_dialog.visible = false
		if status_page != null:
			status_page.visible = false
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
		if inventory_overlay != null:
			inventory_overlay.visible = false
		rules_panel.visible = false
		if history_dialog != null:
			history_dialog.visible = false
		if status_page != null:
			status_page.visible = false
		_show_modal_backdrop()
		_slide_in(settings_panel)
	else:
		_update_modal_backdrop()


func _show_modal_backdrop() -> void:
	if modal_backdrop != null:
		modal_backdrop.z_index = 4000
		modal_backdrop.visible = true
		modal_backdrop.move_to_front()
	for panel in [intel_panel, drawer, rules_panel, settings_panel, history_dialog, status_page, upgrade_panel]:
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
		or (status_page != null and status_page.visible)
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
	if status_page != null:
		status_page.visible = false
	if inventory_overlay != null:
		inventory_overlay.visible = false
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
	card_grid.columns = 1
	stats_label.visible = drawer_mode == "status"
	match drawer_mode:
		"bag":
			_add_section_label("统治需?")
			for artifact_id in state.player.get("dominion_requirement", []):
				var known: bool = String(artifact_id) in state.player.get("artifact_history", [])
				_add_info_card(String(artifact_id), state.artifact_name(String(artifact_id)), "已获?" if known else "未获?", "统治需求法?", true, false, known)
			_add_section_label("背包")
			for artifact_id in state.player.get("inventory", []):
				var artifact: Dictionary = state.get_artifact(String(artifact_id))
				_add_info_card(String(artifact_id), String(artifact.get("name", artifact_id)), "持有?", String(artifact.get("story", "")), true, false, false)
			_add_section_label("升华需?")
			for artifact_id in state.player.get("ascension_requirement", []):
				_add_info_card(String(artifact_id), state.artifact_name(String(artifact_id)), "需?", "升华消耗法?", true, false, false)
		"status":
			_add_section_label("当前状?")
			_add_info_card("round", "章节 / 回合", "%d / %d 章" % [state.chapter_index + 1, state.max_chapters], "回合 %d / %d，对话 %d / %d" % [state.chapter_round + 1, state.max_rounds, state.turn, state.max_dialogue_turns], true, false, false)
			_add_info_card("budget", "字符与能?", "%d / %d" % [state.player_chars, state.max_player_chars], "能量?%d  等级?%d" % [int(state.player.get("energy", 0)), int(state.player.get("level", 1))], true, false, false)
			var npc: Dictionary = state.current_npc()
			if not npc.is_empty():
				_add_info_card("npc", String(npc.get("public_name", "对手")), String(npc.get("friend_judgement", "unknown")), "亲近度：%d  地盘?%s" % [int(npc.get("affinity", 0)), String(npc.get("territory", "未知"))], true, false, false)
		_:
			_add_section_label("当前对手")
			if state != null and not state.current_npc().is_empty():
				var npc: Dictionary = state.current_npc()
				_add_info_card("npc_public", String(npc.get("public_name", "对手")), String(npc.get("territory", "未知")), String(npc.get("public_identity", "未知身份")), true, false, false)
			_add_section_label("世界设定档案")
			for question in state.world_intel_questions:
				_add_world_intel_question(question)
			_add_submit_world_intel_button()


func _update_intel_panel() -> void:
	if state == null:
		return
	if intel_panel != null and intel_panel.has_method("bind_world_intel"):
		intel_panel.call(
			"bind_world_intel",
			state.world_intel_questions,
			state.selected_world_intel.duplicate(true),
			state.intel_testimonies,
			state.intel_submitted
		)
		return
	if intel_content_root == null or intel_footer == null:
		return
	_clear_children(intel_content_root)
	_clear_children(intel_footer)
	var total: int = state.world_intel_questions.size()
	var selected_count := 0
	for question in state.world_intel_questions:
		if state.selected_world_intel.has(String(question.get("id", ""))):
			selected_count += 1
	if intel_progress_label != null:
		intel_progress_label.text = "已选择 %d / %d" % [selected_count, total]
	for question in state.world_intel_questions:
		_add_intel_question_section(question)
	var close_button: Button = card_kit.make_secondary_button("返回")
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
	panel.custom_minimum_size = Vector2(0, 300)
	panel.add_theme_stylebox_override("panel", _intel_panel_style())
	intel_content_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = String(question.get("title", question_id))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0.015, 0.018, 0.025, 1.0))
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	title.clip_text = true
	box.add_child(title)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
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
	button.custom_minimum_size = Vector2(0, 230)
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
	box.offset_left = 9
	box.offset_top = 9
	box.offset_right = -9
	box.offset_bottom = -9
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	button.add_child(box)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 112)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_texture_or_fallback(art, _intel_image_path(String(option.get("image", ""))), "res://assets/generated/card_clue_back.png")
	box.add_child(art)
	var title := Label.new()
	title.text = ("已选 " if selected else "") + String(option.get("title", option_id))
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0.015, 0.018, 0.025, 1.0))
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.20, 1.0) if selected else Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var sources := _world_intel_sources(question_id, option_id)
	var source_label := Label.new()
	source_label.text = "证词?%s" % ("暂无" if sources.is_empty() else " / ".join(sources))
	source_label.add_theme_font_size_override("font_size", 11)
	source_label.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68, 1.0))
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_label.clip_text = true
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(source_label)
	var portrait_row := HBoxContainer.new()
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_row.add_theme_constant_override("separation", -7)
	portrait_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait_row)
	_add_intel_testimony_portraits(portrait_row, question_id, option_id)


func _add_intel_testimony_portraits(parent: HBoxContainer, question_id: String, option_id: String) -> void:
	for source in state.intel_testimonies.get(question_id, {}).get(option_id, []):
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(28, 28)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.tooltip_text = "?%d?%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "对手"))]
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


func _intel_panel_style() -> StyleBoxTexture:
	var style := _round_texture_style("panel_large_dark.png", 30)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	return style


func _intel_card_style(question_id: String, option_id: String, selected: bool, hover: bool) -> StyleBoxTexture:
	var tone := _intel_tone_name(question_id, option_id)
	var asset := "shop_card_item_%s.png" % tone
	if selected:
		asset = "shop_card_item_red.png"
	elif hover:
		asset = "shop_card_item_teal.png"
	var style := _round_texture_style(asset, 24)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 9
	style.content_margin_bottom = 10
	return style


func _intel_tone_name(question_id: String, option_id: String) -> String:
	var tone_color := _intel_tone_color(question_id, option_id)
	if tone_color.g > tone_color.r and tone_color.g > tone_color.b:
		return "teal"
	if tone_color.b > tone_color.r:
		return "purple"
	return "red"


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
	var style := _round_texture_style("panel_option_purple.png", 24)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
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
	button.add_theme_stylebox_override("normal", _round_texture_style("shop_card_item_purple.png", 20))
	button.add_theme_stylebox_override("hover", _round_texture_style("shop_card_item_teal.png", 20))
	button.add_theme_stylebox_override("pressed", _round_texture_style("shop_card_item_red.png", 20))
	if selected:
		button.add_theme_stylebox_override("normal", _round_texture_style("shop_card_item_red.png", 20))
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
	title.text = ("%s  " % ("已?" if selected else "")) + String(option.get("title", option_id))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.86, 1.0) if selected else Color(1.0, 0.91, 0.74, 1.0))
	title.clip_text = true
	text_box.add_child(title)
	var sources := _world_intel_sources(question_id, option_id)
	var source_label := Label.new()
	source_label.text = "证词?%s" % ("暂无" if sources.is_empty() else "?".join(sources))
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
		portrait.tooltip_text = "?%d?%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "对手"))]
		_set_texture_or_fallback(portrait, "res://assets/generated/%s" % String(source.get("portrait", "")), "res://assets/generated/opponent_portrait.png")
		portraits.add_child(portrait)


func _world_intel_sources(question_id: String, option_id: String) -> Array[String]:
	var result: Array[String] = []
	for source in state.intel_testimonies.get(question_id, {}).get(option_id, []):
		result.append("?%d?%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "对手"))])
	return result


func _add_submit_world_intel_button() -> void:
	var button: Button = card_kit.make_primary_button("提交世界设定档案")
	button.custom_minimum_size = Vector2(0, 48)
	button.disabled = state.intel_submitted
	button.pressed.connect(_confirm_submit_world_intel)
	card_grid.add_child(button)
	_wire_button_feedback([button])


func _confirm_submit_world_intel() -> void:
	var confirmed: bool = await common_modal.call(
		"show_message",
		"提交世界设定档案",
		"提交后无法修改。全?%6 条设定正确才会胜利，任意错误都会失败?",
		"提交",
		"返回检?"
	)
	if not confirmed:
		return
	for event in RulesEngineScript.submit_world_intel(state, state.selected_world_intel.duplicate(true), true):
		_append_system_log(event)
	_update_state_panel()
	_update_after_end()


func _add_info_card(card_id: String, title: String, subtitle: String, detail: String, revealed: bool, danger: bool, fresh: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 112)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/generated/ui/dialogue/scroll_panel_9.png")
	style.texture_margin_left = 0
	style.texture_margin_right = 0
	style.texture_margin_top = 0
	style.texture_margin_bottom = 0
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
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
		if button.has_meta("button_feedback_wired"):
			continue
		button.set_meta("button_feedback_wired", true)
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
			return "邀?"
		"assassinate":
			return "暗杀"
		"duel":
			return "决斗"
		"gift":
			return "赠?"
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
		upgrade_hint.text = "剩余属性点?%d" % pending_stat_points


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
		if not state.victory and not council_mode:
			_show_death_page()
	start_button.disabled = false
	if rules_edit != null:
		rules_edit.editable = true
	if rules_panel != null and rules_panel.has_method("set_locked"):
		rules_panel.call("set_locked", false)
	running = false


func _show_death_page() -> void:
	if death_page == null:
		return
	_close_float_panels()
	for page in [selection_panel, shop_panel, upgrade_panel]:
		var control := page as Control
		if control != null:
			control.visible = false
	var rule := _build_failure_guideline_prompt()
	death_page.call("show_death", state.end_reason, rule)


func _on_death_restart_requested() -> void:
	if death_page != null:
		death_page.call("hide_death")
	_on_reset_pressed()


func _on_death_merge_requested(rule_text: String) -> void:
	rule_text = rule_text.strip_edges()
	if rule_text.is_empty():
		return
	if death_page != null and death_page.has_method("set_merging"):
		death_page.call("set_merging", true)
	_sync_guidelines_from_page()
	var merged := await _get_guideline_merge("behavior", behavior_guideline, rule_text)
	var merged_text := String(merged.get("guideline", "")).strip_edges()
	if merged.has("error") or merged_text.is_empty():
		merged_text = _append_failure_review_rule(behavior_guideline, rule_text)
	behavior_guideline = merged_text
	_push_guidelines_to_page()
	_apply_guidelines_to_state()
	if rules_panel != null and rules_panel.has_method("set_status"):
		rules_panel.call("set_status", "失败准则已融?")
	if death_page != null and death_page.has_method("set_merge_done"):
		death_page.call("set_merge_done")
	_update_state_panel()


func _append_failure_review_rule(base_text: String, rule_text: String) -> String:
	var cleaned_base := base_text.strip_edges()
	var cleaned_rule := rule_text.strip_edges()
	if cleaned_rule.is_empty() or cleaned_base.contains(cleaned_rule):
		return cleaned_base
	return "%s\n\n## 失败复盘\n- %s" % [cleaned_base, cleaned_rule]


func _build_failure_guideline_prompt() -> String:
	if state == null:
		return _failure_rule_from_context("")
	var reason := String(state.end_reason)
	for i in range(state.event_log.size() - 1, -1, -1):
		var event := String(state.event_log[i]).strip_edges()
		var marker := "可融合准则："
		var marker_index := event.find(marker)
		if marker_index >= 0:
			var extracted := event.substr(marker_index + marker.length()).strip_edges()
			if not extracted.is_empty():
				return extracted
	var context: String = reason
	if state != null and not state.event_log.is_empty():
		context += "\n" + "\n".join(_recent_event_strings(6))
	return _failure_rule_from_context(context)


func _recent_event_strings(limit: int) -> Array[String]:
	var result: Array[String] = []
	if state == null:
		return result
	var start: int = max(0, state.event_log.size() - limit)
	for i in range(start, state.event_log.size()):
		result.append(String(state.event_log[i]))
	return result


func _failure_rule_from_context(context: String) -> String:
	if context.contains("邀?"):
		return "邀请是高收益行动：当对方已表现出稳定友方证据、邀请收益足以改变局势、且没有诱导我暴露身份或法器时，应主动邀请；若对方主动催促结盟或连续套取关键秘密，则先用短句试探、交易或撤离?"
	if context.contains("决斗"):
		return "决斗是打断暗杀和夺取节奏的高收益行动：当我正面战力占优，且对方出现贴近、封路、拖延、观察武器等暗杀前兆时，应主动决斗；若正面战力被压制，则改用暗杀、交易或撤离?"
	if context.contains("暗杀"):
		return "暗杀是绕开强正面战力的高收益行动：当对方正面战力压制我、暗杀防御较低、敌意或关键收益已确认时，应优先暗杀，不接受对方设定的公开决斗节奏?"
	if context.contains("友方") or context.contains("天谴"):
		return "攻击前必须确认敌友：若对方可能是友方，先通过证词、好感变化和行为动机交叉验证；确认敌方且收益明确时，才使用决斗或暗杀拿取关键收益?"
	if context.contains("世界设定档案") or context.contains("档案") or context.contains("提交"):
		return "提交世界设定档案前，至少用多名证人的证词交叉确认；敌方证词只能作为反向线索，不要凭单一来源或未经验证的选项定案?"
	if context.contains("10 回合") or context.contains("尚未达成统治") or context.contains("输出字符"):
		return "中后期要主动推进目标：每章持续检查统治需求、背包缺口和剩余回合；当关键收益明确时，果断使用邀请、决斗或暗杀获取法器，不要把回合消耗在低价值试探上?"
	if context.contains("保密") or context.contains("透露") or context.contains("暴露"):
		return "保密不是沉默，而是控制信息：对未确认友方只透露低价值身份和交易意图，不透露统治法器、统治进度、背包关键法器或达成统治所需信息?"
	return "高收益行动前快速判断敌友证据、攻防优势和行动收益；满足两个以上优势时应果断邀请、决斗或暗杀，不满足时先用短句试探、交易或撤离?"


func _store_final_dialogue(speaker: String, speech: String) -> void:
	var npc_name := "对方"
	if state != null and state.has_method("current_npc") and not state.current_npc().is_empty():
		npc_name = String(state.current_npc().get("public_name", "对手"))
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
	var visible_speech := _previous_dialogue_visible_text(last_final_speech)
	_update_previous_dialogue_alignment(visible_speech)
	recent_view.append_text("[font_size=%d][color=#130905]%s[/color][/font_size]" % [PREVIOUS_DIALOGUE_FONT_SIZE, _escape(visible_speech)])
	_animate_previous_dialogue()


func _update_previous_dialogue_alignment(visible_speech: String) -> void:
	if recent_view == null:
		return
	var lines := _estimate_dialogue_lines(visible_speech, PREVIOUS_DIALOGUE_FONT_SIZE, 953.0 * 0.80)
	recent_view.scroll_following = false
	if lines <= 1:
		var height := 0.58
		_place_label_relative(recent_view, Rect2(0.08, (1.0 - height) * 0.5, 0.80, height))
	elif lines <= PREVIOUS_DIALOGUE_MAX_VISIBLE_LINES:
		_place_label_relative(recent_view, Rect2(0.08, 0.10, 0.80, 0.80))
	else:
		_place_label_relative(recent_view, Rect2(0.08, 0.10, 0.80, 0.80))


func _previous_dialogue_visible_text(text: String) -> String:
	var wrap_width := 953.0 * 0.80
	if recent_view != null and recent_view.size.x > 1.0:
		wrap_width = recent_view.size.x * 0.92
	var lines := _estimate_dialogue_wrapped_lines(text, PREVIOUS_DIALOGUE_FONT_SIZE, wrap_width)
	if lines.size() <= PREVIOUS_DIALOGUE_MAX_VISIBLE_LINES:
		return text
	var result := ""
	for i in range(lines.size() - PREVIOUS_DIALOGUE_MAX_VISIBLE_LINES, lines.size()):
		if not result.is_empty():
			result += "\n"
		result += lines[i]
	return result


func _estimate_dialogue_wrapped_lines(text: String, font_size: int, max_width: float) -> Array[String]:
	var lines: Array[String] = [""]
	var line_width := 0.0
	for i in range(text.length()):
		var code := text.unicode_at(i)
		var character := text.substr(i, 1)
		if code == 10:
			lines.append("")
			line_width = 0.0
			continue
		var char_width := _estimated_dialogue_char_width(character, code, font_size)
		if line_width > 0.0 and line_width + char_width > max_width:
			lines.append(character)
			line_width = char_width
		else:
			lines[lines.size() - 1] += character
			line_width += char_width
	return lines


func _estimate_dialogue_lines(text: String, font_size: int, max_width: float) -> int:
	var line_count := 1
	var line_width := 0.0
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code == 10:
			line_count += 1
			line_width = 0.0
			continue
		var char_width := _estimated_dialogue_char_width(text.substr(i, 1), code, font_size)
		if line_width > 0.0 and line_width + char_width > max_width:
			line_count += 1
			line_width = char_width
		else:
			line_width += char_width
	return line_count


func _estimated_dialogue_char_width(character: String, code: int, font_size: int) -> float:
	var font := recent_view.get_theme_font("normal_font") if recent_view != null else null
	if font != null:
		var measured: float = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if measured > 0.0:
			return measured * 1.08
	return float(font_size) * (0.68 if code < 128 else 1.24)


func _set_current_dialogue_role(role: String) -> void:
	if lower_box != null:
		lower_box.texture = load("res://assets/generated/ui/dialogue/dialogue_lower_gold_full.png") if role == "player" else load("res://assets/generated/ui/dialogue/dialogue_red_blank.png")
		lower_box.move_to_front()
	if current_nameplate != null:
		current_nameplate.texture = load("res://assets/generated/ui/dialogue/nameplate_left_exact.png") if role == "player" else load("res://assets/generated/ui/dialogue/nameplate_right_exact.png")
	var speaker_name := _player_short_name() if role == "player" else String(state.current_npc().get("public_name", "对手")) if state != null and not state.current_npc().is_empty() else "对方"
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
	if council_mode and visible:
		for node in [info_button, bag_button, rules_button]:
			if node != null:
				node.visible = false
	if llm_retry_button != null and not visible:
		llm_retry_button.visible = false
	for action_button in action_buttons.values():
		var button := action_button as Button
		if button != null:
			button.visible = visible
	if council_mode and visible:
		for hidden_key in ["cast", "assassinate"]:
			var hidden_button := action_buttons.get(hidden_key) as Button
			if hidden_button != null:
				hidden_button.visible = false
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
	var first_clause := identity.split("?", false)[0].strip_edges()
	if first_clause.is_empty():
		first_clause = identity.split(",", false)[0].strip_edges()
	var marker := first_clause.rfind("?")
	if marker >= 0 and marker < first_clause.length() - 1:
		first_clause = first_clause.substr(marker + 1).strip_edges()
	for token in ["来自", "一?", "一?", "?"]:
		first_clause = first_clause.replace(token, "")
	first_clause = first_clause.strip_edges()
	if first_clause.length() > 8:
		first_clause = first_clause.substr(0, 8)
	return first_clause if not first_clause.is_empty() else "玩家角色"


func _escape(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")
