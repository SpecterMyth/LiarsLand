extends RefCounted
class_name AdventureLayout

const UI_ROOT := "res://assets/generated/ui/dialogue/"
const BASE_SIZE := Vector2(1672, 941)
const NINE_MARGIN := 34


func build(owner: Control, default_rules: String) -> Dictionary:
	owner.set_anchors_preset(Control.PRESET_FULL_RECT)

	var background_texture := TextureRect.new()
	background_texture.name = "DialogueBase"
	background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.texture = _load_texture("dialogue_base.png")
	owner.add_child(background_texture)

	var pulse_overlay := ColorRect.new()
	pulse_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
	pulse_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(pulse_overlay)

	var ambience := Control.new()
	ambience.name = "Ambience"
	ambience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ambience.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(ambience)

	var hud := Control.new()
	hud.name = "FlatClashHud"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(hud)

	var status_panel := _make_exact_texture("top_status_full.png", Rect2(6, 6, 1660, 52))
	hud.add_child(status_panel)

	var status_label := Label.new()
	status_label.text = "赤金夜市：等待开始"
	status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_label.offset_left = 0
	status_label.offset_right = 0
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	status_label.clip_text = true
	status_panel.add_child(status_label)

	var progress_label := Label.new()
	progress_label.visible = false
	hud.add_child(progress_label)

	var upper_box := _make_exact_texture("dialogue_red_blank.png", Rect2(395, 584, 953, 127))
	upper_box.visible = false
	hud.add_child(upper_box)

	var previous_speaker_label := _make_plain_name_label("上一句")
	_place_relative(previous_speaker_label, Rect2(0.07, -0.28, 0.18, 0.40))
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

	var recent_view := _make_log(17, Color(0.08, 0.04, 0.03, 1.0))
	recent_view.name = "PreviousDialogue"
	_place_relative(recent_view, Rect2(0.08, 0.24, 0.76, 0.48))
	upper_box.add_child(recent_view)

	var lower_box := _make_exact_texture("dialogue_gold_blank.png", Rect2(176, 728, 1339, 194))
	hud.add_child(lower_box)

	var current_speaker_label := _make_plain_name_label("玩家角色")
	_place_relative(current_speaker_label, Rect2(0.095, -0.17, 0.13, 0.26))
	lower_box.add_child(current_speaker_label)

	var player_label := _make_plain_name_label("玩家角色")
	player_label.visible = false
	hud.add_child(player_label)

	var npc_label := _make_plain_name_label("绯尾侯爵")
	npc_label.visible = false
	hud.add_child(npc_label)

	var dialogue_view := _make_log(19, Color(0.08, 0.04, 0.03, 1.0))
	dialogue_view.name = "CurrentDialogue"
	_place_relative(dialogue_view, Rect2(0.09, 0.30, 0.82, 0.52))
	lower_box.add_child(dialogue_view)

	var side_strip := _make_exact_texture("right_button_strip.png", Rect2(1558, 86, 104, 726))
	hud.add_child(side_strip)

	var side_buttons := Control.new()
	side_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(side_buttons)

	var info_button := _make_icon_button("情报", "icon_info.png")
	var bag_button := _make_icon_button("背包", "icon_bag.png")
	var history_button := _make_icon_button("历史", "icon_history.png")
	var rules_button := _make_icon_button("规则", "icon_rules.png")
	var status_button := _make_icon_button("状态", "icon_status.png")
	var settings_button := _make_icon_button("设置", "icon_settings.png")
	var hot_zones := [
		Rect2(1563, 91, 94, 95),
		Rect2(1563, 213, 94, 96),
		Rect2(1563, 339, 94, 96),
		Rect2(1563, 462, 94, 96),
		Rect2(1563, 586, 94, 96),
		Rect2(1563, 710, 94, 96)
	]
	var side_button_list := [info_button, bag_button, history_button, rules_button, status_button, settings_button]
	for i in range(side_button_list.size()):
		var button: Button = side_button_list[i]
		_place_by_source_rect(button, hot_zones[i])
		side_buttons.add_child(button)

	var drawer := _make_modal_panel(Vector2(430, 650), "情报")
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

	var rules_panel := _make_modal_panel(Vector2(560, 650), "行为文件")
	rules_panel.visible = false
	owner.add_child(rules_panel)
	var rules_box: VBoxContainer = rules_panel.get_meta("body")

	var rules_edit := TextEdit.new()
	rules_edit.text = default_rules
	rules_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rules_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_edit.add_theme_font_size_override("font_size", 16)
	rules_edit.add_theme_color_override("font_color", Color(1.0, 0.91, 0.74, 1.0))
	rules_edit.add_theme_color_override("font_placeholder_color", Color(0.72, 0.58, 0.42, 1.0))
	rules_box.add_child(rules_edit)

	var settings_panel := _make_modal_panel(Vector2(340, 270), "设置")
	settings_panel.visible = false
	owner.add_child(settings_panel)
	var settings_box: VBoxContainer = settings_panel.get_meta("body")

	var start_button := _make_text_button("开始")
	var reset_button := _make_text_button("重置")
	var close_settings_button := _make_text_button("关闭")
	settings_box.add_child(start_button)
	settings_box.add_child(reset_button)
	settings_box.add_child(close_settings_button)
	close_settings_button.pressed.connect(func(): settings_panel.visible = false)

	var history_dialog := AcceptDialog.new()
	history_dialog.title = "历史对话"
	history_dialog.size = Vector2i(880, 620)
	history_dialog.add_theme_stylebox_override("panel", _make_stylebox("modal_frame_9.png", 34, Color.TRANSPARENT))
	owner.add_child(history_dialog)
	var history_view := _make_log(17, Color(1.0, 0.91, 0.72, 1.0))
	history_view.custom_minimum_size = Vector2(820, 520)
	history_dialog.add_child(history_view)

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

	var player_portrait := TextureRect.new()
	player_portrait.visible = false
	hud.add_child(player_portrait)

	var npc_portrait := TextureRect.new()
	npc_portrait.visible = false
	hud.add_child(npc_portrait)

	var modal_backdrop := Button.new()
	modal_backdrop.name = "ModalBlankClose"
	modal_backdrop.visible = false
	modal_backdrop.flat = true
	modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	modal_backdrop.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	modal_backdrop.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	owner.add_child(modal_backdrop)
	drawer.move_to_front()
	rules_panel.move_to_front()
	settings_panel.move_to_front()
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
		"previous_speaker_label": previous_speaker_label,
		"recent_view": recent_view,
		"npc_public_label": npc_public_label,
		"stats_label": stats_label,
		"rules_edit": rules_edit,
		"dialogue_title": dialogue_title,
		"result_banner": result_banner,
		"dialogue_view": dialogue_view,
		"state_view": state_view,
		"card_grid": card_grid,
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
		"drawer": drawer,
		"rules_panel": rules_panel,
		"settings_panel": settings_panel,
		"modal_backdrop": modal_backdrop,
		"history_dialog": history_dialog,
		"history_view": history_view,
		"upgrade_panel": upgrade_panel,
		"upgrade_label": upgrade_label,
		"upgrade_hint": upgrade_hint,
		"upgrade_buttons": upgrade_buttons,
		"continue_button": continue_button,
		"player_portrait": player_portrait,
		"npc_portrait": npc_portrait
	}


func _load_texture(name: String) -> Texture2D:
	return load(UI_ROOT + name)


func _make_exact_texture(texture_name: String, source_rect: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _load_texture(texture_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	_place_by_source_rect(rect, source_rect)
	return rect


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


func _make_plain_name_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.18, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 1.0))
	label.clip_text = true
	return label


func _make_log(size: int, color: Color) -> RichTextLabel:
	var view := RichTextLabel.new()
	view.bbcode_enabled = true
	view.scroll_following = true
	view.fit_content = false
	view.add_theme_font_size_override("normal_font_size", size)
	view.add_theme_color_override("default_color", color)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return view


func _make_icon_button(label: String, icon_name: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.flat = true
	button.tooltip_text = label
	button.modulate.a = 0.02
	return button


func _make_text_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
	button.add_theme_stylebox_override("normal", _make_stylebox("button_square.png", 18, Color(0.06, 0.05, 0.06, 1.0)))
	button.add_theme_stylebox_override("hover", _make_stylebox("button_square_hover.png", 18, Color(0.10, 0.05, 0.12, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_stylebox("button_square_pressed.png", 18, Color(0.03, 0.02, 0.03, 1.0)))
	return button


func _make_modal_panel(size: Vector2, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = size
	panel.offset_left = -size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_bottom = size.y / 2.0
	panel.add_theme_stylebox_override("panel", _make_stylebox("modal_frame_9.png", 36, Color(0.05, 0.04, 0.05, 0.96)))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.79, 0.25, 1.0))
	outer.add_child(title_label)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	outer.add_child(body)
	panel.set_meta("body", body)
	panel.set_meta("title_label", title_label)
	return panel
