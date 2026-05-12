extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name CouncilResultPage

signal continue_requested
signal restart_requested

const PlayerInfoCardScene := preload("res://scenes/ui/player_info_card.tscn")
const CommonTitleBarScene := preload("res://scenes/ui/common_title_bar.tscn")
const CommonBackgroundPanelScene := preload("res://scenes/ui/common_background_panel.tscn")
const COUNCIL_ICON_ROOT := "res://assets/generated/ui/council_icons/"
const ENERGY_ICON_PATH := COUNCIL_ICON_ROOT + "icon_energy.png"
const GENERATED_ROOT := "res://assets/generated/"
const CHARACTER_ROOT := "res://assets/ui/characters/"
const CHARACTER_HEADICON_ROOT := CHARACTER_ROOT + "headicon/"
const CHARACTER_PORTRAIT_ROOT := CHARACTER_ROOT + "portrait/"
const VOTE_GUILTY := "guilty"
const VOTE_INNOCENT := "innocent"
const TEXT_MAIN := Color(1.0, 0.91, 0.74, 1.0)
const PANEL_TEXT := Color(0.06, 0.045, 0.035, 1.0)
const KEY_GREEN := Color(0.02, 0.30, 0.18, 1.0)
const KEY_RED := Color(0.48, 0.05, 0.04, 1.0)

var body_box: VBoxContainer
var continue_button: Button
var restart_button: Button


func _init() -> void:
	page_title = "议会结算"
	background_path = "res://assets/ui/status/status_page_bg.png"
	panel_color = CommonFrameScript.DARK_RED
	main_panel_rect = Rect2(60, 94, 1160, 574)


func _build_page() -> void:
	_configure_scene_backdrop_only()

	if content_margin != null:
		content_margin.add_theme_constant_override("margin_left", 18)
		content_margin.add_theme_constant_override("margin_top", 10)
		content_margin.add_theme_constant_override("margin_right", 18)
		content_margin.add_theme_constant_override("margin_bottom", 14)

	body_box = VBoxContainer.new()
	body_box.name = "ResultBody"
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_theme_constant_override("separation", 6)
	content_box.add_child(body_box)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 14)
	content_box.add_child(buttons)

	restart_button = StandardButtonScript.new()
	restart_button.name = "RestartButton"
	StandardButtonScript.apply(restart_button, StandardButtonScript.SECONDARY, "重新开始", 20, Vector2(150, 46))
	restart_button.pressed.connect(func(): restart_requested.emit())
	buttons.add_child(restart_button)

	continue_button = StandardButtonScript.new()
	continue_button.name = "ContinueButton"
	StandardButtonScript.apply(continue_button, StandardButtonScript.PRIMARY, "继续", 20, Vector2(174, 46))
	continue_button.pressed.connect(func(): continue_requested.emit())
	buttons.add_child(continue_button)


func _bind_page() -> void:
	body_box = get_node_or_null("MainPanel/ContentMargin/Content/ResultBody") as VBoxContainer
	continue_button = get_node_or_null("MainPanel/ContentMargin/Content/Buttons/ContinueButton") as Button
	restart_button = get_node_or_null("MainPanel/ContentMargin/Content/Buttons/RestartButton") as Button


func show_result(state, final_game := false) -> void:
	if body_box == null:
		_build_base()
	if body_box == null:
		push_error("CouncilResultPage body was not built.")
		return
	_clear_children(body_box)

	body_box.add_child(_make_result_banner(state, final_game))

	var columns := HBoxContainer.new()
	columns.name = "ResultColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	body_box.add_child(columns)

	columns.add_child(_make_player_panel(state))
	columns.add_child(_make_reveal_panel(state))
	columns.add_child(_make_vote_panel(state))

	if continue_button != null:
		continue_button.text = "完成" if final_game or not bool(state.victory) else "进入下一章"
		continue_button.visible = bool(state.victory)
	if restart_button != null:
		restart_button.visible = not bool(state.victory)
	visible = true


func _make_result_banner(state, final_game: bool) -> Control:
	var panel := MarginContainer.new()
	panel.name = "ResultBanner"
	panel.custom_minimum_size = Vector2(0, 56)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("margin_left", 8)
	panel.add_theme_constant_override("margin_top", 0)
	panel.add_theme_constant_override("margin_right", 8)
	panel.add_theme_constant_override("margin_bottom", 0)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var title := "最终通关" if final_game and bool(state.victory) else ("章节胜利" if bool(state.victory) else "游戏失败")
	var title_label := _make_label(title, 25, Color(1.0, 0.87, 0.46, 1.0), 3)
	title_label.custom_minimum_size = Vector2(118, 0)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)

	var detail := HBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.alignment = BoxContainer.ALIGNMENT_BEGIN
	detail.add_theme_constant_override("separation", 8)
	row.add_child(detail)

	detail.add_child(_make_icon_rect(_faction_icon_path(_winning_faction_id(state)), Vector2(34, 34), "WinningFactionIcon"))
	var reason := _make_label(_result_reason(state), 18, TEXT_MAIN, 2)
	reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.add_child(reason)

	return panel


func _make_player_panel(state) -> Control:
	var panel := MarginContainer.new()
	panel.name = "PlayerPanel"
	panel.custom_minimum_size = Vector2(292, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("margin_left", 2)
	panel.add_theme_constant_override("margin_top", 30)
	panel.add_theme_constant_override("margin_right", 2)
	panel.add_theme_constant_override("margin_bottom", 2)

	var card_holder := CenterContainer.new()
	card_holder.name = "PlayerCardHolder"
	card_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(card_holder)

	var card := PlayerInfoCardScene.instantiate() as Control
	card.name = "ResultPlayerInfoCard"
	card.custom_minimum_size = Vector2(263, 450)
	card.size = card.custom_minimum_size
	card_holder.add_child(card)
	if card.has_method("set_player_data"):
		card.call("set_player_data", state.player, state)
	return panel


func _make_reveal_panel(state) -> Control:
	var panel := _make_common_background_panel("RevealPanel", CommonFrameScript.GRAY)
	panel.custom_minimum_size = Vector2(430, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := _make_section_content(panel, 50)
	box.add_theme_constant_override("separation", 0)
	box.add_child(_make_score_row(state))

	var list_title := _make_panel_label("角色揭示列表", 12)
	box.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.name = "MemberScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "MemberList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	for member in _all_members(state):
		list.add_child(_make_member_row(state, member))
	return _make_labeled_panel(panel, "阵营比分", CommonFrameScript.GRAY, 210, 24)


func _make_score_row(state) -> Control:
	var row := HBoxContainer.new()
	row.name = "FactionScoreRow"
	row.custom_minimum_size = Vector2(0, 64)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)

	var shown := 0
	for faction in state.council_factions:
		if shown >= 3:
			break
		row.add_child(_make_faction_score_card(state, faction))
		shown += 1
	return row


func _make_faction_score_card(state, faction: Dictionary) -> Control:
	var faction_id := String(faction.get("id", ""))
	var color := Color.html(String(faction.get("color", "#73563a"))) if String(faction.get("color", "")).begins_with("#") else Color(0.35, 0.28, 0.20, 1.0)
	var panel := _make_flat_panel("FactionScore", color.lightened(0.68), color.darkened(0.25), 7)
	panel.custom_minimum_size = Vector2(0, 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := _make_margin(panel, 8, 5, 8, 5)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	row.add_child(_make_icon_rect(_faction_icon_path(faction_id), Vector2(42, 42), "FactionIcon"))

	var count_box := VBoxContainer.new()
	count_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(count_box)

	var count := _alive_faction_count(state, faction_id)
	var count_label := _make_panel_label(str(count), 25)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_box.add_child(count_label)
	var sub := _make_panel_label("剩余", 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_box.add_child(sub)
	return panel


func _make_member_row(state, member: Dictionary) -> Control:
	var alive := bool(member.get("alive", true))
	var panel := Control.new()
	panel.name = "MemberRow"
	panel.custom_minimum_size = Vector2(0, 48 if alive else 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := _make_margin(panel, 0, 2, 0, 4)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	row.add_child(_make_member_avatar(state, member, Vector2(40, 40), "AvatarTexture"))
	row.add_child(_make_icon_rect(_faction_icon_path(_member_faction_id(member)), Vector2(32, 32), "FactionIcon"))

	var text_box := VBoxContainer.new()
	text_box.custom_minimum_size = Vector2(0, 40 if alive else 50)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var name_row := HBoxContainer.new()
	name_row.custom_minimum_size = Vector2(0, 22)
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_row.add_theme_constant_override("separation", 8)
	text_box.add_child(name_row)

	var name_label := _make_panel_label(_member_display_name(member), 13)
	name_label.custom_minimum_size = Vector2(0, 22)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)

	var reward_amount := _energy_reward_for_member(state, String(member.get("id", ""))) if alive else 0
	if reward_amount > 0:
		var reward_row := HBoxContainer.new()
		reward_row.size_flags_horizontal = Control.SIZE_SHRINK_END
		reward_row.add_theme_constant_override("separation", 5)
		name_row.add_child(reward_row)
		reward_row.add_child(_make_icon_rect(ENERGY_ICON_PATH, Vector2(16, 16), "EnergyRewardIcon"))
		var reward_label := _make_panel_label("精力 +%d" % reward_amount, 10, KEY_GREEN)
		reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reward_row.add_child(reward_label)

	if alive:
		var status_label := _make_panel_label("存活", 10, KEY_GREEN)
		status_label.custom_minimum_size = Vector2(0, 14)
		text_box.add_child(status_label)
	else:
		var death_row := HBoxContainer.new()
		death_row.add_theme_constant_override("separation", 5)
		text_box.add_child(death_row)
		death_row.add_child(_make_death_icon())
		var death_text := _make_panel_label(_death_reason_text(state, member), 10, KEY_RED)
		death_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		death_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		death_row.add_child(death_text)

	panel.add_child(_make_row_divider())
	return panel


func _make_vote_panel(state) -> Control:
	var panel := _make_common_background_panel("VotePanel", CommonFrameScript.GRAY)
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := _make_section_content(panel, 50)
	box.add_theme_constant_override("separation", 0)

	var scroll := ScrollContainer.new()
	scroll.name = "CrimeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "CrimeVoteList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	for crime in _state_crimes(state):
		list.add_child(_make_crime_vote_row(state, crime))
	return _make_labeled_panel(panel, "罪行投票", CommonFrameScript.GRAY, 190, 24)


func _make_crime_vote_row(state, crime: Dictionary) -> Control:
	var crime_id := String(crime.get("id", ""))
	var executed := _crime_is_executed(state, crime_id)
	var panel := Control.new()
	panel.name = "CrimeVoteRow"
	panel.custom_minimum_size = Vector2(0, 56)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := _make_margin(panel, 0, 3, 0, 5)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	row.add_child(_make_icon_rect(_crime_icon_path(crime_id), Vector2(40, 40), "CrimeIcon"))

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 3)
	row.add_child(detail)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(title_row)

	var title := _make_panel_label(String(crime.get("title", crime_id)), 12)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = false
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	if executed:
		var badge := _make_panel_label("处决", 10, KEY_RED)
		badge.custom_minimum_size = Vector2(32, 0)
		title_row.add_child(badge)

	var vote_row := HBoxContainer.new()
	vote_row.name = "VoteResultRow"
	vote_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vote_row.add_theme_constant_override("separation", 8)
	detail.add_child(vote_row)
	vote_row.add_child(_make_vote_avatar_line(state, crime_id, VOTE_GUILTY, "有罪", HORIZONTAL_ALIGNMENT_LEFT))
	vote_row.add_child(_make_vote_avatar_line(state, crime_id, VOTE_INNOCENT, "无罪", HORIZONTAL_ALIGNMENT_RIGHT))
	panel.add_child(_make_row_divider())
	return panel


func _make_vote_avatar_line(state, crime_id: String, vote: String, label_text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Control:
	var row := HBoxContainer.new()
	row.name = "%sVoteLine" % vote.capitalize()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if alignment == HORIZONTAL_ALIGNMENT_RIGHT else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 5)

	var label_color := KEY_RED if vote == VOTE_GUILTY else KEY_GREEN
	var label := _make_panel_label(label_text, 10, label_color)
	label.custom_minimum_size = Vector2(28, 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if alignment == HORIZONTAL_ALIGNMENT_LEFT:
		row.add_child(label)

	var voters := _vote_members(state, crime_id, vote)
	if voters.is_empty():
		var none := _make_panel_label("-", 10, PANEL_TEXT)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none.horizontal_alignment = alignment
		none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(none)
		if alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			row.add_child(label)
		return row

	for member in voters:
		row.add_child(_make_member_avatar(state, member, Vector2(22, 22), "VoteAvatar"))
	if alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		row.add_child(label)
	return row


func _make_common_background_panel(node_name: String, color := CommonFrameScript.GRAY) -> NinePatchRect:
	var panel := CommonBackgroundPanelScene.instantiate() as NinePatchRect
	panel.name = node_name
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.frame_color = color
	panel.apply_default_size = false
	CommonFrameScript.apply_background_panel(panel, color, Vector2.ZERO)
	return panel


func _configure_scene_backdrop_only() -> void:
	var background := get_node_or_null("Background") as CanvasItem
	if background != null:
		background.visible = false
	var scratches := get_node_or_null("TextureScratches") as CanvasItem
	if scratches != null:
		scratches.visible = false
	var veil := get_node_or_null("Veil") as ColorRect
	if veil != null:
		veil.visible = true
		veil.color = Color(0.0, 0.0, 0.0, 0.82)
	if main_panel != null:
		CommonFrameScript.apply_background_panel(main_panel, panel_color)
		main_panel.draw_center = true


func _make_labeled_panel(panel: Control, title: String, color: String, title_width := 210, top_gap := 24) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = panel.size_flags_horizontal
	holder.size_flags_vertical = panel.size_flags_vertical
	holder.size_flags_stretch_ratio = panel.size_flags_stretch_ratio
	holder.custom_minimum_size = panel.custom_minimum_size

	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = top_gap
	holder.add_child(panel)

	var title_bar := _make_title_label_bar(title, color, title_width)
	title_bar.anchor_left = 0.0
	title_bar.anchor_top = 0.0
	title_bar.anchor_right = 0.0
	title_bar.anchor_bottom = 0.0
	title_bar.offset_left = 18.0
	title_bar.offset_top = 0.0
	title_bar.offset_right = 18.0 + float(title_width)
	title_bar.offset_bottom = 42.0
	holder.add_child(title_bar)
	return holder


func _make_row_divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.name = "RowDivider"
	divider.anchor_left = 0.0
	divider.anchor_top = 1.0
	divider.anchor_right = 1.0
	divider.anchor_bottom = 1.0
	divider.offset_left = 8.0
	divider.offset_top = -1.0
	divider.offset_right = -8.0
	divider.offset_bottom = 0.0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color(0.78, 0.62, 0.35, 0.34)
	return divider


func _make_title_label_bar(text: String, color: String, width := 210) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 42)
	var frame := CommonTitleBarScene.instantiate() as NinePatchRect
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.frame_color = color
	frame.apply_default_size = false
	CommonFrameScript.apply_title_bar(frame, color, Vector2.ZERO)
	holder.add_child(frame)
	var label := _make_panel_label(text, 19, PANEL_TEXT)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 20
	label.offset_right = -20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(label)
	return holder


func _make_panel_label(text: String, font_size: int, color := PANEL_TEXT) -> Label:
	var label := _make_label(text, font_size, color, 0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("outline_size", 0)
	return label


func _member_display_name(member: Dictionary) -> String:
	for key in ["public_name", "name", "display_name", "id"]:
		var value := String(member.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return "议员"


func _make_member_avatar(state, member: Dictionary, min_size: Vector2, node_name := "Avatar") -> Control:
	var holder := PanelContainer.new()
	holder.name = node_name
	holder.custom_minimum_size = min_size
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.tooltip_text = _member_display_name(member)

	var radius := int(min(min_size.x, min_size.y) * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.014, 0.01, 1.0)
	style.border_color = _faction_color(state, _member_faction_id(member))
	style.set_border_width_all(maxi(2, int(radius * 0.10)))
	style.set_corner_radius_all(radius)
	holder.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := maxi(2, int(radius * 0.10))
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_top", inset)
	margin.add_theme_constant_override("margin_right", inset)
	margin.add_theme_constant_override("margin_bottom", inset)
	holder.add_child(margin)

	var avatar := TextureRect.new()
	avatar.name = "AvatarTexture"
	avatar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.texture = _load_texture(_avatar_texture_path(member))
	if not bool(member.get("alive", true)):
		avatar.modulate = Color(0.42, 0.42, 0.42, 0.84)
	margin.add_child(avatar)
	return holder


func _make_flat_panel(node_name: String, fill: Color, border: Color, radius := 6) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _make_icon_rect(path: String, min_size: Vector2, node_name := "Icon") -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	_config_icon(icon, min_size)
	icon.texture = _load_texture(path)
	return icon


func _config_icon(icon: TextureRect, min_size: Vector2) -> void:
	icon.custom_minimum_size = min_size
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_death_icon() -> Control:
	var icon := Control.new()
	icon.name = "DeathIcon"
	icon.custom_minimum_size = Vector2(22, 22)
	icon.draw.connect(func():
		icon.draw_circle(Vector2(11, 11), 10, Color(0.48, 0.18, 0.16, 1.0))
		icon.draw_line(Vector2(6, 6), Vector2(16, 16), Color(0.96, 0.84, 0.68, 1.0), 2.0)
		icon.draw_line(Vector2(16, 6), Vector2(6, 16), Color(0.96, 0.84, 0.68, 1.0), 2.0)
	)
	return icon


func _vote_members(state, crime_id: String, vote: String) -> Array:
	var result: Array = []
	for record in state.council_vote_records:
		if String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			var member := _member_by_id(state, String(record.get("member_id", "")))
			if not member.is_empty():
				result.append(member)
	return result


func _death_reason_text(state, member: Dictionary) -> String:
	var crimes := _executed_crimes_for_member(state, member)
	if crimes.is_empty():
		return "死亡原因未知"
	return "处决：" + "、".join(_crime_titles(state, crimes))


func _executed_crimes_for_member(state, member: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var member_crimes: Array = member.get("hidden_crimes", [])
	for crime_id in state.council_executed_crimes:
		var id := String(crime_id)
		if id in member_crimes:
			result.append(id)
	return result


func _crime_is_executed(state, crime_id: String) -> bool:
	for item in state.council_executed_crimes:
		if String(item) == crime_id:
			return true
	return false


func _state_crimes(state) -> Array:
	if state.council_crime_pool is Array:
		return state.council_crime_pool
	return []


func _energy_reward_for_member(state, member_id: String) -> int:
	if state == null or member_id.is_empty():
		return 0
	for reward in state.council_last_energy_rewards:
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		if String(reward.get("member_id", "")) == member_id:
			return int(reward.get("amount", 0))
	return 0


func _all_members(state) -> Array:
	if state.council_members is Array and not state.council_members.is_empty():
		return state.council_members
	var result: Array = [state.player]
	for npc in state.npcs:
		result.append(npc)
	return result


func _member_by_id(state, member_id: String) -> Dictionary:
	for member in _all_members(state):
		if String(member.get("id", "")) == member_id:
			return member
	return {}


func _member_faction_id(member: Dictionary) -> String:
	var public_support := String(member.get("public_support", ""))
	if not public_support.is_empty():
		return public_support
	return String(member.get("hidden_faction", ""))


func _alive_faction_count(state, faction_id: String) -> int:
	var count := 0
	for member in _all_members(state):
		if bool(member.get("alive", true)) and _member_faction_id(member) == faction_id:
			count += 1
	return count


func _alive_member_count(state) -> int:
	var count := 0
	for member in _all_members(state):
		if bool(member.get("alive", true)):
			count += 1
	return count


func _avatar_texture_path(member: Dictionary) -> String:
	var portrait := String(member.get("portrait", "player_portrait.png"))
	if portrait.begins_with("res://"):
		var head_res := portrait.replace("_portrait.png", "_head_avatar.png")
		if ResourceLoader.exists(head_res):
			return head_res
		return portrait
	var head_avatar := portrait.replace("_portrait.png", "_head_avatar.png")
	var head_path := CHARACTER_HEADICON_ROOT + head_avatar
	if ResourceLoader.exists(head_path):
		return head_path
	var fallback_path := CHARACTER_PORTRAIT_ROOT + portrait
	if ResourceLoader.exists(fallback_path):
		return fallback_path
	var player_head := CHARACTER_HEADICON_ROOT + "player_head_avatar.png"
	if ResourceLoader.exists(player_head):
		return player_head
	return CHARACTER_HEADICON_ROOT + "player_head_avatar.png"


func _faction_icon_path(faction_id: String) -> String:
	var path := COUNCIL_ICON_ROOT + "faction_%s.png" % faction_id
	if not faction_id.is_empty() and ResourceLoader.exists(path):
		return path
	return COUNCIL_ICON_ROOT + "faction_blue_tie.png"


func _faction_color(state, faction_id: String) -> Color:
	for faction in state.council_factions:
		if String(faction.get("id", "")) == faction_id:
			var raw := String(faction.get("color", ""))
			if raw.begins_with("#"):
				return Color.html(raw)
			break
	return Color(1.0, 0.78, 0.22, 1.0)


func _crime_icon_path(crime_id: String) -> String:
	var path := COUNCIL_ICON_ROOT + "crime_%s.png" % crime_id
	if not crime_id.is_empty() and ResourceLoader.exists(path):
		return path
	return COUNCIL_ICON_ROOT + "crime_hush_money_invoice.png"


func _crime_title(state, crime_id: String) -> String:
	for crime in _state_crimes(state):
		if String(crime.get("id", "")) == crime_id:
			return String(crime.get("title", crime_id))
	return crime_id if not crime_id.is_empty() else "无"


func _result_reason(state) -> String:
	var winner_id := _winning_faction_id(state)
	if winner_id.is_empty():
		return "无人胜利"
	return "%s胜利" % _faction_name(state, winner_id)


func _winning_faction_id(state) -> String:
	var counts := {}
	for member in _all_members(state):
		if bool(member.get("alive", true)):
			var faction_id := _member_faction_id(member)
			counts[faction_id] = int(counts.get(faction_id, 0)) + 1
	var winner := ""
	var best := 0
	var tied := false
	for faction_id in counts.keys():
		var count := int(counts[faction_id])
		if count > best:
			best = count
			winner = String(faction_id)
			tied = false
		elif count == best:
			tied = true
	return "" if tied or best <= 0 else winner


func _crime_titles(state, ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id in ids:
		var title := String(id)
		for crime in _state_crimes(state):
			if String(crime.get("id", "")) == String(id):
				title = String(crime.get("title", id))
				break
		result.append(title)
	if result.is_empty():
		result.append("无")
	return result


func _faction_name(state, faction_id: String) -> String:
	for faction in state.council_factions:
		if String(faction.get("id", "")) == faction_id:
			return String(faction.get("name", faction_id))
	return faction_id
