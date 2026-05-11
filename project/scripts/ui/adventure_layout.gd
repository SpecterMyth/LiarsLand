extends RefCounted
class_name AdventureLayout

const CardUiKitScript := preload("res://scripts/ui/card_ui_kit.gd")
const WorldIntelArchiveScene := preload("res://scenes/ui/world_intel_archive.tscn")
const InventoryOverlayScene := preload("res://scenes/ui/inventory_overlay.tscn")
const RightUtilityButtonsScene := preload("res://scenes/ui/right_utility_buttons.tscn")
const LeftActionButtonsScene := preload("res://scenes/ui/left_action_buttons.tscn")
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")
const GuidelinesPageScene := preload("res://scenes/ui/guidelines_page.tscn")
const HistoryPageScene := preload("res://scenes/ui/history_page.tscn")
const StatusPageScene := preload("res://scenes/ui/status_page.tscn")
const SettingsPageScene := preload("res://scenes/ui/settings_page.tscn")
const UI_ROOT := "res://assets/generated/ui/dialogue/"
const COMMON_UI_ROOT := "res://assets/ui/common/"
const DIALOGUE_FONT_PATH := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
const BASE_SIZE := Vector2(1672, 941)
const NINE_MARGIN := 34


func build(owner: Control, default_rules: String) -> Dictionary:
	owner.set_anchors_preset(Control.PRESET_FULL_RECT)

	var background_texture := TextureRect.new()
	background_texture.name = "DialogueBase"
	background_texture.z_index = 0
	background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.texture = _load_texture("dialogue_base.png")
	owner.add_child(background_texture)

	var pulse_overlay := ColorRect.new()
	pulse_overlay.z_index = 70
	pulse_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
	pulse_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(pulse_overlay)

	var ambience := Control.new()
	ambience.name = "Ambience"
	ambience.z_index = 1
	ambience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ambience.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(ambience)

	var hud := Control.new()
	hud.name = "FlatClashHud"
	hud.z_index = 10
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(hud)

	var status_panel := _make_status_panel(Rect2(586, 6, 500, 52))
	status_panel.name = "StatusPanel"
	status_panel.z_index = 40
	hud.add_child(status_panel)

	var status_label := Label.new()
	status_label.text = "赤金夜市：等待开始"
	status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_label.offset_left = 92
	status_label.offset_right = -92
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	status_label.clip_text = true
	status_panel.add_child(status_label)

	var progress_label := Label.new()
	progress_label.visible = false
	hud.add_child(progress_label)

	var upper_box := _make_exact_texture("dialogue_upper_red_full.png", Rect2(395, 584, 953, 127))
	upper_box.z_index = 24
	upper_box.visible = false
	hud.add_child(upper_box)

	var previous_nameplate := _make_nameplate_texture("nameplate_right_exact.png")
	_place_relative(previous_nameplate, Rect2(0.76, -0.29, 0.22, 0.42))
	upper_box.add_child(previous_nameplate)

	var previous_speaker_label := _make_plain_name_label("上一句")
	previous_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_relative(previous_speaker_label, Rect2(0.76, -0.29, 0.22, 0.42))
	upper_box.add_child(previous_speaker_label)

	var dialogue_title := Label.new()
	dialogue_title.visible = false
	hud.add_child(dialogue_title)

	var result_banner := Label.new()
	result_banner.visible = false
	result_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	result_banner.offset_left = 360
	result_banner.offset_top = 92
	result_banner.offset_right = -360
	result_banner.offset_bottom = 136
	result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_banner.add_theme_font_size_override("font_size", 22)
	result_banner.add_theme_color_override("font_color", Color(1.0, 0.87, 0.42, 1.0))
	hud.add_child(result_banner)

	var llm_retry_button := _make_text_button("重试")
	llm_retry_button.name = "LlmRetryButton"
	llm_retry_button.visible = false
	llm_retry_button.z_index = 64
	llm_retry_button.focus_mode = Control.FOCUS_NONE
	_place_by_source_rect(llm_retry_button, Rect2(742, 664, 188, 52))
	hud.add_child(llm_retry_button)

	var recent_view := _make_log(17, Color(0.08, 0.04, 0.03, 1.0), -4)
	recent_view.name = "PreviousDialogue"
	recent_view.scroll_following = false
	_place_relative(recent_view, Rect2(0.08, 0.12, 0.80, 0.78))
	upper_box.add_child(recent_view)

	var lower_box := _make_exact_texture("dialogue_lower_gold_full.png", Rect2(176, 728, 1339, 194))
	lower_box.z_index = 25
	lower_box.visible = false
	hud.add_child(lower_box)

	var current_nameplate := _make_nameplate_texture("nameplate_left_exact.png")
	_place_relative(current_nameplate, Rect2(0.035, -0.21, 0.18, 0.31))
	lower_box.add_child(current_nameplate)

	var current_speaker_label := _make_plain_name_label("玩家角色")
	current_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_relative(current_speaker_label, Rect2(0.035, -0.21, 0.18, 0.31))
	lower_box.add_child(current_speaker_label)

	var player_label := _make_plain_name_label("玩家角色")
	player_label.visible = false
	hud.add_child(player_label)

	var npc_label := _make_plain_name_label("维尾侯爵")
	npc_label.visible = false
	hud.add_child(npc_label)

	var dialogue_view := _make_log(23, Color(0.08, 0.04, 0.03, 1.0))
	dialogue_view.name = "CurrentDialogue"
	_place_relative(dialogue_view, Rect2(0.08, 0.14, 0.82, 0.70))
	lower_box.add_child(dialogue_view)

	var side_buttons := RightUtilityButtonsScene.instantiate() as Control
	side_buttons.name = "RightUtilityButtons"
	side_buttons.z_index = 46
	side_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(side_buttons)

	var info_button := side_buttons.get_node_or_null("InfoButton") as BaseButton
	var bag_button := side_buttons.get_node_or_null("BagButton") as BaseButton
	var history_button := side_buttons.get_node_or_null("HistoryButton") as BaseButton
	var rules_button := side_buttons.get_node_or_null("RulesButton") as BaseButton
	var status_button := side_buttons.get_node_or_null("StatusButton") as BaseButton
	var settings_button := side_buttons.get_node_or_null("SettingsButton") as BaseButton

	var drawer := _make_modal_panel(Vector2(430, 650), "情报")
	var action_buttons_root := Control.new()
	action_buttons_root.z_index = 46
	action_buttons_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_buttons_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(action_buttons_root)

	var left_action_buttons := LeftActionButtonsScene.instantiate() as Control
	left_action_buttons.name = "LeftActionButtons"
	left_action_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	action_buttons_root.add_child(left_action_buttons)
	var action_buttons := {}
	action_buttons["leave"] = left_action_buttons.get_node_or_null("LeaveButton")
	action_buttons["gift"] = left_action_buttons.get_node_or_null("GiftButton")
	action_buttons["cast"] = left_action_buttons.get_node_or_null("CastButton")
	action_buttons["invite"] = left_action_buttons.get_node_or_null("InviteButton")
	action_buttons["duel"] = left_action_buttons.get_node_or_null("DuelButton")
	action_buttons["assassinate"] = left_action_buttons.get_node_or_null("AssassinateButton")

	drawer.visible = false
	owner.add_child(drawer)
	var drawer_box: VBoxContainer = drawer.get_meta("body")

	var stats_label := Label.new()
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_box.add_child(stats_label)

	var state_view := _make_log(16, Color(1.0, 0.91, 0.72, 1.0))
	state_view.visible = false
	drawer_box.add_child(state_view)

	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_box.add_child(card_scroll)

	var card_grid := GridContainer.new()
	card_grid.columns = 1
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("v_separation", 10)
	card_scroll.add_child(card_grid)

	var intel_panel := WorldIntelArchiveScene.instantiate() as Control
	intel_panel.name = "IntelPanel"
	intel_panel.visible = false
	owner.add_child(intel_panel)

	var intel_progress_label := intel_panel.get_node_or_null("ProgressLabel") as Label
	var intel_content_root := intel_panel.get_node_or_null("Scroll/QuestionGrid") as GridContainer
	var intel_footer := intel_panel.get_node_or_null("Footer") as HBoxContainer

	var inventory_controls := _build_inventory_overlay(owner)
	var inventory_overlay := inventory_controls.get("inventory_overlay") as Control
	var inventory_backdrop := inventory_controls.get("inventory_backdrop") as BaseButton
	var inventory_close_button := inventory_controls.get("inventory_close_button") as BaseButton
	var inventory_energy_label := inventory_controls.get("inventory_energy_label") as Label
	var inventory_capacity_label := inventory_controls.get("inventory_capacity_label") as Label
	var inventory_dominion_grid := inventory_controls.get("inventory_dominion_grid") as GridContainer
	var inventory_ascension_grid := inventory_controls.get("inventory_ascension_grid") as GridContainer
	var inventory_item_grid := inventory_controls.get("inventory_item_grid") as GridContainer

	var rules_panel := GuidelinesPageScene.instantiate() as Control
	rules_panel.visible = false
	owner.add_child(rules_panel)
	var guideline_controls: Dictionary = {}
	if rules_panel.has_method("get_controls"):
		guideline_controls = rules_panel.call("get_controls")
	var rules_edit := guideline_controls.get("rules_edit") as TextEdit
	var auto_decide_check := guideline_controls.get("auto_decide_check") as CheckBox
	var auto_growth_check := guideline_controls.get("auto_growth_check") as CheckBox
	if rules_panel.has_method("set_guidelines"):
		rules_panel.call("set_guidelines", "", default_rules, "")

	var settings_panel := SettingsPageScene.instantiate() as Control
	settings_panel.visible = false
	owner.add_child(settings_panel)
	var settings_controls: Dictionary = {}
	if settings_panel.has_method("get_controls"):
		settings_controls = settings_panel.call("get_controls")
	var start_button := settings_controls.get("start_button") as Button
	var reset_button := settings_controls.get("reset_button") as Button
	var settings_auto_decide_check := settings_controls.get("auto_decide_check") as CheckBox
	var settings_auto_growth_check := settings_controls.get("auto_growth_check") as CheckBox

	var history_dialog := HistoryPageScene.instantiate() as Control
	history_dialog.visible = false
	owner.add_child(history_dialog)
	var history_view := history_dialog.get("history_view") as RichTextLabel

	var status_page := StatusPageScene.instantiate() as Control
	status_page.visible = false
	owner.add_child(status_page)

	var upgrade_panel := _make_modal_panel(Vector2(600, 330), "升华")
	upgrade_panel.visible = false
	owner.add_child(upgrade_panel)
	var upgrade_box: VBoxContainer = upgrade_panel.get_meta("body")

	var upgrade_label := Label.new()
	upgrade_label.add_theme_font_size_override("font_size", 22)
	upgrade_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
	upgrade_box.add_child(upgrade_label)

	var upgrade_hint := Label.new()
	upgrade_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_hint.add_theme_font_size_override("font_size", 16)
	upgrade_hint.add_theme_color_override("font_color", Color(1.0, 0.91, 0.74, 1.0))
	upgrade_box.add_child(upgrade_hint)

	var upgrade_buttons := GridContainer.new()
	upgrade_buttons.columns = 2
	upgrade_buttons.add_theme_constant_override("h_separation", 8)
	upgrade_buttons.add_theme_constant_override("v_separation", 8)
	upgrade_box.add_child(upgrade_buttons)

	var continue_button := _make_text_button("继续探索")
	upgrade_box.add_child(continue_button)

	var npc_public_label := Label.new()
	npc_public_label.visible = false
	hud.add_child(npc_public_label)

	var side_shadow_left := _make_side_shadow(false)
	side_shadow_left.z_index = 6
	side_shadow_left.visible = false
	_place_by_source_rect(side_shadow_left, Rect2(0, 0, 860, 941))
	hud.add_child(side_shadow_left)

	var side_shadow_right := _make_side_shadow(true)
	side_shadow_right.z_index = 6
	side_shadow_right.visible = false
	_place_by_source_rect(side_shadow_right, Rect2(812, 0, 860, 941))
	hud.add_child(side_shadow_right)

	var player_portrait := TextureRect.new()
	player_portrait.name = "PlayerPortrait"
	player_portrait.z_index = 8
	player_portrait.visible = false
	player_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_portrait.flip_h = true
	player_portrait.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	player_portrait.offset_left = 10
	player_portrait.offset_top = -620
	player_portrait.offset_right = 540
	player_portrait.offset_bottom = 8
	hud.add_child(player_portrait)

	var npc_portrait := TextureRect.new()
	npc_portrait.name = "NpcPortrait"
	npc_portrait.z_index = 8
	npc_portrait.visible = false
	npc_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	npc_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	npc_portrait.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	npc_portrait.offset_left = -540
	npc_portrait.offset_top = -620
	npc_portrait.offset_right = -10
	npc_portrait.offset_bottom = 8
	hud.add_child(npc_portrait)
	player_portrait.move_to_front()
	npc_portrait.move_to_front()
	upper_box.move_to_front()
	lower_box.move_to_front()
	status_panel.move_to_front()
	side_buttons.move_to_front()
	action_buttons_root.move_to_front()

	var modal_backdrop := Button.new()
	modal_backdrop.name = "ModalBlankClose"
	modal_backdrop.z_index = 80
	modal_backdrop.visible = false
	modal_backdrop.flat = true
	modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	modal_backdrop.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	modal_backdrop.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	owner.add_child(modal_backdrop)
	intel_panel.move_to_front()
	inventory_overlay.move_to_front()
	drawer.move_to_front()
	rules_panel.move_to_front()
	settings_panel.move_to_front()
	history_dialog.move_to_front()
	status_page.move_to_front()
	upgrade_panel.move_to_front()

	return {
		"background_texture": background_texture,
		"upper_box": upper_box,
		"lower_box": lower_box,
		"status_label": status_label,
		"progress_label": progress_label,
		"npc_label": npc_label,
		"player_label": player_label,
		"current_speaker_label": current_speaker_label,
		"current_nameplate": current_nameplate,
		"previous_speaker_label": previous_speaker_label,
		"previous_nameplate": previous_nameplate,
		"recent_view": recent_view,
		"npc_public_label": npc_public_label,
		"stats_label": stats_label,
		"rules_edit": rules_edit,
		"guidelines_panel": rules_panel,
		"guideline_controls": guideline_controls,
		"dialogue_title": dialogue_title,
		"result_banner": result_banner,
		"llm_retry_button": llm_retry_button,
		"dialogue_view": dialogue_view,
		"state_view": state_view,
		"card_grid": card_grid,
		"intel_panel": intel_panel,
		"intel_progress_label": intel_progress_label,
		"intel_content_root": intel_content_root,
		"intel_footer": intel_footer,
		"inventory_overlay": inventory_overlay,
		"inventory_backdrop": inventory_backdrop,
		"inventory_close_button": inventory_close_button,
		"inventory_energy_label": inventory_energy_label,
		"inventory_capacity_label": inventory_capacity_label,
		"inventory_dominion_grid": inventory_dominion_grid,
		"inventory_ascension_grid": inventory_ascension_grid,
		"inventory_item_grid": inventory_item_grid,
		"pulse_overlay": pulse_overlay,
		"ambience": ambience,
		"start_button": start_button,
		"reset_button": reset_button,
		"history_button": history_button,
		"info_button": info_button,
		"bag_button": bag_button,
		"rules_button": rules_button,
		"status_button": status_button,
		"settings_button": settings_button,
		"action_buttons": action_buttons,
		"auto_decide_check": auto_decide_check,
		"auto_growth_check": auto_growth_check,
		"settings_auto_decide_check": settings_auto_decide_check,
		"settings_auto_growth_check": settings_auto_growth_check,
		"drawer": drawer,
		"rules_panel": rules_panel,
		"settings_panel": settings_panel,
		"status_page": status_page,
		"modal_backdrop": modal_backdrop,
		"history_dialog": history_dialog,
		"history_view": history_view,
		"upgrade_panel": upgrade_panel,
		"upgrade_label": upgrade_label,
		"upgrade_hint": upgrade_hint,
		"upgrade_buttons": upgrade_buttons,
		"continue_button": continue_button,
		"side_shadow_left": side_shadow_left,
		"side_shadow_right": side_shadow_right,
		"player_portrait": player_portrait,
		"npc_portrait": npc_portrait
	}


func _build_inventory_overlay(owner: Control) -> Dictionary:
	var overlay := InventoryOverlayScene.instantiate() as Control
	owner.add_child(overlay)
	overlay.visible = false
	if overlay.has_method("get_controls"):
		return overlay.call("get_controls")
	return {
		"inventory_overlay": overlay,
		"inventory_close_button": overlay.get_node_or_null("CloseButton"),
		"inventory_backdrop": overlay.get_node_or_null("Backdrop"),
		"inventory_energy_label": overlay.get_node_or_null("BagResourceBar/EnergyPlate/EnergyValue"),
		"inventory_capacity_label": overlay.get_node_or_null("BagResourceBar/CapacityPlate/CapacityValue"),
		"inventory_dominion_grid": overlay.get_node_or_null("RequirementPanel/DominionRequirementGrid"),
		"inventory_ascension_grid": overlay.get_node_or_null("RequirementPanel/AscensionRequirementGrid"),
		"inventory_item_grid": overlay.get_node_or_null("InventoryItemGrid")
	}



func _make_common_exact_texture(texture_name: String, source_rect: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _load_common_texture(texture_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_by_source_rect(rect, source_rect)
	return rect


func _add_inventory_resource(parent: Control, source_rect: Rect2, icon_name: String, value: String, tone: String) -> Label:
	var backplate := _make_common_exact_texture("bag_resource_backplate_%s.png" % tone, source_rect)
	parent.add_child(backplate)
	var icon := TextureRect.new()
	icon.texture = _load_common_texture(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_relative(icon, Rect2(0.04, 0.06, 0.29, 0.88))
	backplate.add_child(icon)
	var label := _make_inventory_label(value, 29, Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place_relative(label, Rect2(0.31, 0.08, 0.64, 0.84))
	backplate.add_child(label)
	return label


func _make_inventory_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	var font := _load_dialogue_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.96))
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _load_texture(name: String) -> Texture2D:
	return load(UI_ROOT + name)


func _make_exact_texture(texture_name: String, source_rect: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _load_texture(texture_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_by_source_rect(rect, source_rect)
	return rect


func _make_status_panel(source_rect: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _load_texture("top_status_full.png")
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_by_source_rect(rect, source_rect)
	return rect


func _make_nameplate_texture(texture_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _load_texture(texture_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_side_shadow(reverse: bool) -> Control:
	var root := ColorRect.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.color = Color.WHITE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform bool reverse = false;
uniform float max_alpha = 0.76;

void fragment() {
	float t = reverse ? UV.x : 1.0 - UV.x;
	t = pow(clamp(t, 0.0, 1.0), 0.72);
	float alpha = smoothstep(0.0, 1.0, t) * max_alpha;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("reverse", reverse)
	root.material = material
	return root


func _make_checkbox_icon(checked: bool) -> Texture2D:
	var name := "checkbox_checked.png" if checked else "checkbox_unchecked.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(UI_ROOT + name))
	if image != null:
		return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(UI_ROOT + name):
		return load(UI_ROOT + name)
	return null


func _place_by_source_rect(node: Control, source_rect: Rect2) -> void:
	node.anchor_left = source_rect.position.x / BASE_SIZE.x
	node.anchor_top = source_rect.position.y / BASE_SIZE.y
	node.anchor_right = (source_rect.position.x + source_rect.size.x) / BASE_SIZE.x
	node.anchor_bottom = (source_rect.position.y + source_rect.size.y) / BASE_SIZE.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0


func _place_relative(node: Control, rect: Rect2) -> void:
	node.anchor_left = rect.position.x
	node.anchor_top = rect.position.y
	node.anchor_right = rect.position.x + rect.size.x
	node.anchor_bottom = rect.position.y + rect.size.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0


func _set_patch(node: NinePatchRect) -> void:
	node.patch_margin_left = NINE_MARGIN
	node.patch_margin_right = NINE_MARGIN
	node.patch_margin_top = NINE_MARGIN
	node.patch_margin_bottom = NINE_MARGIN


func _make_stylebox(texture_name: String, margin: int, fallback: Color) -> StyleBox:
	var texture := _load_texture(texture_name)
	if texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fallback
		return flat
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _make_common_stylebox(texture_name: String, margin: int, fallback: Color) -> StyleBox:
	var texture := _load_common_texture(texture_name)
	if texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fallback
		return flat
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = max(10, margin / 2)
	style.content_margin_right = max(10, margin / 2)
	style.content_margin_top = max(8, margin / 3)
	style.content_margin_bottom = max(8, margin / 3)
	return style


func _make_plain_name_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	var font := _load_dialogue_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.18, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 1.0))
	label.clip_text = true
	return label


func _make_log(size: int, color: Color, line_separation: int = 0) -> RichTextLabel:
	var view := RichTextLabel.new()
	view.bbcode_enabled = true
	view.scroll_active = false
	view.scroll_following = true
	view.fit_content = false
	view.selection_enabled = false
	view.add_theme_font_size_override("normal_font_size", size)
	view.add_theme_font_size_override("bold_font_size", size)
	view.add_theme_font_size_override("italics_font_size", size)
	view.add_theme_constant_override("line_separation", line_separation)
	var font := _load_dialogue_font()
	if font != null:
		view.add_theme_font_override("normal_font", font)
		view.add_theme_font_override("bold_font", font)
		view.add_theme_font_override("italics_font", font)
		view.add_theme_font_override("bold_italics_font", font)
	view.add_theme_color_override("default_color", color)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return view


func _load_dialogue_font() -> Font:
	if ResourceLoader.exists(DIALOGUE_FONT_PATH):
		return load(DIALOGUE_FONT_PATH)
	return null


func _make_icon_button(label: String, icon_name: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.flat = true
	button.tooltip_text = label
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_common_texture(_icon_tile_name(icon_name))
	button.add_child(icon)
	return button


func _load_common_texture(name: String) -> Texture2D:
	if ResourceLoader.exists(COMMON_UI_ROOT + name):
		return load(COMMON_UI_ROOT + name)
	if OS.has_feature("web"):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(COMMON_UI_ROOT + name))
	if image != null:
		return ImageTexture.create_from_image(image)
	var fallback := name.replace("icon_tile_", "icon_")
	return _load_texture(fallback)


func _icon_tile_name(icon_name: String) -> String:
	return "icon_tile_%s" % icon_name.trim_prefix("icon_")


func _make_text_button(text: String) -> Button:
	var button := Button.new()
	StandardButtonScript.apply(button, StandardButtonScript.PRIMARY, text, 18, Vector2(0, 46))
	return button


func _make_modal_panel(size: Vector2, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = size
	panel.offset_left = -size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_bottom = size.y / 2.0
	panel.add_theme_stylebox_override("panel", _make_common_stylebox("panel_large_dark.png", 36, Color(0.05, 0.04, 0.05, 0.96)))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.79, 0.25, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(0, 42)
	title_label.add_theme_stylebox_override("normal", _make_common_stylebox("title_banner_dark_small.png", 24, Color(0.08, 0.05, 0.05, 0.92)))
	outer.add_child(title_label)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	outer.add_child(body)
	panel.set_meta("body", body)
	panel.set_meta("title_label", title_label)
	return panel
