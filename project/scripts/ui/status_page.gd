extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name StatusPage

const COUNCIL_ICON_ROOT := "res://assets/generated/ui/council_icons/"
const ENERGY_ICON_PATH := COUNCIL_ICON_ROOT + "icon_energy.png"
const CHARACTER_ROOT := "res://assets/ui/characters/"
const CHARACTER_HEADICON_ROOT := CHARACTER_ROOT + "headicon/"
const CHARACTER_PORTRAIT_ROOT := CHARACTER_ROOT + "portrait/"
const RoundCounterPanelScene := preload("res://scenes/ui/round_counter_panel.tscn")
const CommonTitleBarScene := preload("res://scenes/ui/common_title_bar.tscn")

const TEXT_GOLD := Color(1.0, 0.84, 0.38, 1.0)
const TEXT_MAIN := Color(1.0, 0.91, 0.74, 1.0)
const TEXT_SOFT := Color(0.82, 0.76, 0.66, 1.0)
const TEXT_DIM := Color(0.62, 0.58, 0.52, 1.0)

var root_box: VBoxContainer
var round_badge: Control
var scene_body: Control
var scene_empty_label: Label
var scene_threshold_label: Label
var scene_crime_rows: VBoxContainer
var scene_roster_grid: GridContainer
var scene_dossier_box: VBoxContainer
var scene_crime_vote_holder: Control
var scene_right_status_column: Control


func _init() -> void:
	page_title = "议会状态"
	background_path = "res://assets/ui/status/status_page_bg.png"
	panel_color = CommonFrameScript.DARK_TEAL
	main_panel_rect = Rect2(54, 92, 1172, 586)


func _build_page() -> void:
	root_box = content_box
	_bind_status_layout()
	_ensure_round_badge()
	bind_state(null)


func _bind_page() -> void:
	root_box = get_node_or_null("MainPanel/ContentMargin/Content") as VBoxContainer
	_bind_status_layout()
	if title_label != null:
		title_label.text = page_title
	_ensure_round_badge()


func bind_state(state) -> void:
	if root_box == null:
		return
	_bind_status_layout()
	_update_round_badge(state)
	if scene_body != null and scene_empty_label != null:
		if state == null:
			scene_body.visible = false
			scene_empty_label.visible = true
			scene_empty_label.text = "等待议会开始"
			return
		if bool(state.get("council_mode")):
			scene_body.visible = true
			scene_empty_label.visible = false
			_bind_council_scene_state(state)
		else:
			scene_body.visible = false
			scene_empty_label.visible = true
			scene_empty_label.text = "旧版状态暂不可用"
		return
	_clear_children(root_box)
	if state == null:
		root_box.add_child(_make_empty_message("等待议会开始"))
		return
	if bool(state.get("council_mode")):
		_bind_council_state(state)
	else:
		root_box.add_child(_make_empty_message("旧版状态暂不可用"))


func _bind_status_layout() -> void:
	scene_body = get_node_or_null("MainPanel/ContentMargin/Content/StatusBody") as Control
	scene_crime_vote_holder = get_node_or_null("MainPanel/ContentMargin/Content/StatusBody/CrimeVoteHolder") as Control
	scene_right_status_column = get_node_or_null("MainPanel/ContentMargin/Content/StatusBody/RightStatusColumn") as Control
	scene_empty_label = get_node_or_null("MainPanel/ContentMargin/Content/EmptyLabel") as Label
	scene_threshold_label = get_node_or_null("MainPanel/ContentMargin/Content/StatusBody/CrimeVoteHolder/CrimeVotePanel/MarginContainer/VBoxContainer/VoteTitleRow/VoteThresholdLabel") as Label
	scene_crime_rows = get_node_or_null("MainPanel/ContentMargin/Content/StatusBody/CrimeVoteHolder/CrimeVotePanel/MarginContainer/VBoxContainer/CrimeScroll/CrimeRows") as VBoxContainer
	scene_roster_grid = get_node_or_null("MainPanel/ContentMargin/Content/StatusBody/RightStatusColumn/CouncilRosterPanel/MarginContainer/RosterGrid") as GridContainer
	scene_dossier_box = get_node_or_null("MainPanel/ContentMargin/Content/StatusBody/RightStatusColumn/DossierHolder/SecretDossierPanel/MarginContainer/VBoxContainer/DossierContent") as VBoxContainer
	if scene_crime_vote_holder != null:
		scene_crime_vote_holder.size_flags_stretch_ratio = 2.2
	if scene_right_status_column != null:
		scene_right_status_column.size_flags_stretch_ratio = 0.9


func _bind_council_scene_state(state) -> void:
	if scene_threshold_label != null:
		scene_threshold_label.text = "%d票处决" % _threshold(state)
	if scene_crime_rows != null:
		_clear_children(scene_crime_rows)
		for crime in state.council_crime_pool:
			scene_crime_rows.add_child(_make_vote_row(state, crime))
	if scene_roster_grid != null:
		_clear_children(scene_roster_grid)
		var members := _all_members(state)
		for i in range(15):
			if i < members.size():
				scene_roster_grid.add_child(_make_roster_slot(state, members[i]))
			else:
				scene_roster_grid.add_child(_make_empty_roster_slot())
	if scene_dossier_box != null:
		_clear_children(scene_dossier_box)
		scene_dossier_box.add_child(_make_faction_energy_line(state))
		for line in _player_dossier_lines(state):
			scene_dossier_box.add_child(_make_dossier_line_from_data(state, line))


func _bind_council_state(state) -> void:
	root_box.add_theme_constant_override("separation", 0)
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_box.add_child(body)

	var vote_panel := _make_vote_panel(state)
	vote_panel.size_flags_stretch_ratio = 2.2
	body.add_child(vote_panel)

	var status_panel := _make_status_panel(state)
	status_panel.size_flags_stretch_ratio = 0.9
	body.add_child(status_panel)


func _make_vote_panel(state) -> Control:
	var panel := _make_section_panel("CrimeVotePanel", CommonFrameScript.GRAY)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _make_section_content(panel, 20)
	box.add_theme_constant_override("separation", 6)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)
	var title_spacer := Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)
	var summary := _make_label("%d票处决" % _threshold(state), 15, TEXT_SOFT, 1)
	summary.custom_minimum_size = Vector2(120, 24)
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_row.add_child(summary)
	var edge_spacer := Control.new()
	edge_spacer.custom_minimum_size = Vector2(100, 1)
	title_row.add_child(edge_spacer)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 26)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	header.add_child(_make_header_cell("有罪", 160, CommonFrameScript.DARK_RED))
	header.add_child(_make_header_cell("罪行", 0, CommonFrameScript.DARK_PURPLE))
	header.add_child(_make_header_cell("无罪", 160, CommonFrameScript.DARK_TEAL))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 1)
	scroll.add_child(rows)

	for crime in state.council_crime_pool:
		rows.add_child(_make_vote_row(state, crime))
	return _make_labeled_panel(panel, "罪行与投票", CommonFrameScript.GRAY, 268)


func _make_status_panel(state) -> Control:
	var panel := _make_section_panel("CouncilStatusPanel", CommonFrameScript.GRAY)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _make_section_content(panel, 26)
	box.add_theme_constant_override("separation", 24)

	var roster := Control.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	roster.custom_minimum_size = Vector2(0, 210)
	var roster_box := VBoxContainer.new()
	roster_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	roster_box.add_theme_constant_override("separation", 8)
	roster.add_child(roster_box)
	var roster_grid := GridContainer.new()
	roster_grid.columns = 5
	roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_grid.add_theme_constant_override("h_separation", 4)
	roster_grid.add_theme_constant_override("v_separation", 4)
	roster_box.add_child(roster_grid)
	var members := _all_members(state)
	for i in range(15):
		if i < members.size():
			roster_grid.add_child(_make_roster_slot(state, members[i]))
		else:
			roster_grid.add_child(_make_empty_roster_slot())
	box.add_child(roster)

	var dossier := _make_section_panel("SecretDossierPanel", CommonFrameScript.GRAY)
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier.custom_minimum_size = Vector2(0, 220)
	var dossier_box := _make_section_content(dossier, 24)
	dossier_box.add_theme_constant_override("separation", 8)
	dossier_box.add_child(_make_faction_energy_line(state))
	for line in _player_dossier_lines(state):
		dossier_box.add_child(_make_dossier_line_from_data(state, line))
	box.add_child(_make_labeled_panel(dossier, "我的档案", CommonFrameScript.GRAY, 220, 24))
	return panel


func _make_vote_row(state, crime: Dictionary) -> Control:
	var crime_id := String(crime.get("id", ""))
	var row_panel := ColorRect.new()
	row_panel.name = "VoteRow"
	row_panel.color = Color(0.05, 0.055, 0.052, 0.16)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row_panel.custom_minimum_size = Vector2(0, 46)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	row_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	row.add_child(_make_vote_member_cell(state, crime_id, "guilty"))
	row.add_child(_make_crime_cell(state, crime))
	row.add_child(_make_vote_member_cell(state, crime_id, "innocent"))
	return row_panel


func _make_crime_cell(state, crime: Dictionary) -> Control:
	var crime_id := String(crime.get("id", ""))
	var title_text := String(crime.get("title", crime_id))
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	box.add_child(_make_icon(_crime_icon_path(crime_id), 34, title_text))

	var title := _make_label(title_text, 18, TEXT_MAIN, 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(title)
	return box


func _make_vote_member_cell(state, crime_id: String, vote: String) -> Control:
	var wrap := HFlowContainer.new()
	wrap.custom_minimum_size = Vector2(160, 38)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.alignment = FlowContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("h_separation", -7)
	wrap.add_theme_constant_override("v_separation", 0)

	var locked_ids := _vote_member_ids(state, crime_id, vote)
	var tendency_ids := _tendency_member_ids(state, crime_id, vote)
	for member_id in locked_ids:
		wrap.add_child(_make_vote_avatar(state, _member_by_id(state, member_id), false))
	for member_id in tendency_ids:
		if member_id in locked_ids:
			continue
		wrap.add_child(_make_vote_avatar(state, _member_by_id(state, member_id), true))
	if locked_ids.is_empty() and tendency_ids.is_empty():
		var none := _make_label("无票", 13, TEXT_DIM, 1)
		none.custom_minimum_size = Vector2(150, 36)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wrap.add_child(none)
	return wrap


func _make_vote_avatar(state, member: Dictionary, tendency := false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(34, 34)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.tooltip_text = _member_tooltip(state, member, tendency)
	var avatar := TextureRect.new()
	avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture = _load_texture(_avatar_texture_path(member))
	avatar.modulate = Color(1, 1, 1, 0.45) if tendency else Color.WHITE
	holder.add_child(avatar)
	return holder


func _make_roster_slot(state, member: Dictionary) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(60, 66)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.tooltip_text = _member_tooltip(state, member)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(66, 66)
	icon_holder.anchor_left = 0.5
	icon_holder.anchor_top = 0.5
	icon_holder.anchor_right = 0.5
	icon_holder.anchor_bottom = 0.5
	icon_holder.offset_left = -33
	icon_holder.offset_top = -33
	icon_holder.offset_right = 33
	icon_holder.offset_bottom = 33
	slot.add_child(icon_holder)

	var avatar := TextureRect.new()
	avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture = _load_texture(_avatar_texture_path(member))
	if not bool(member.get("alive", true)):
		avatar.modulate = Color(0.35, 0.35, 0.35, 0.76)
	icon_holder.add_child(avatar)

	if bool(member.get("faction_revealed", false)) or bool(state.ended):
		var faction_icon := _make_icon(_faction_icon_path(String(member.get("hidden_faction", ""))), 17, _faction_name(state, String(member.get("hidden_faction", ""))))
		faction_icon.anchor_left = 1.0
		faction_icon.anchor_top = 1.0
		faction_icon.anchor_right = 1.0
		faction_icon.anchor_bottom = 1.0
		faction_icon.offset_left = -22
		faction_icon.offset_top = -22
		faction_icon.offset_right = 0
		faction_icon.offset_bottom = 0
		icon_holder.add_child(faction_icon)
	return slot


func _make_empty_roster_slot() -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(60, 66)
	slot.tooltip_text = "预留议员头像位"

	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(66, 66)
	holder.anchor_left = 0.5
	holder.anchor_top = 0.5
	holder.anchor_right = 0.5
	holder.anchor_bottom = 0.5
	holder.offset_left = -33
	holder.offset_top = -33
	holder.offset_right = 33
	holder.offset_bottom = 33
	var holder_style := StyleBoxFlat.new()
	holder_style.bg_color = Color(0.018, 0.014, 0.01, 1.0)
	holder_style.border_color = Color(1.0, 0.78, 0.22, 1.0)
	holder_style.set_border_width_all(3)
	holder_style.set_corner_radius_all(33)
	holder.add_theme_stylebox_override("panel", holder_style)
	slot.add_child(holder)
	return slot


func _make_dossier_line(icon_path: String, text: String, icon_size := 30) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_icon(icon_path, icon_size, text))
	var label := _make_label(text, 15, TEXT_MAIN, 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	return row


func _make_dossier_line_from_data(state, line: Dictionary) -> Control:
	var crime_id := String(line.get("crime_id", ""))
	var text := _crime_title(state, crime_id)
	var tag := String(line.get("tag", ""))
	var color = line.get("color", TEXT_MAIN)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon(_crime_icon_path(crime_id) if not crime_id.is_empty() else "", 30, text))
	var display_text := text + tag
	var name_label := _make_label(display_text, 14, color, 1)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	return row


func _make_faction_energy_line(state) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var faction_id := String(state.player.get("hidden_faction", ""))
	row.add_child(_make_icon(_faction_icon_path(faction_id), 34, _faction_name(state, faction_id)))
	var label := _make_label(_faction_name(state, faction_id), 15, TEXT_MAIN, 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = 3
	row.add_child(label)
	row.add_child(_make_icon(ENERGY_ICON_PATH, 28, "剩余精力"))
	var energy := _make_label(str(_remaining_energy(state)), 15, Color(0.45, 0.95, 1.0, 1.0), 1)
	energy.custom_minimum_size = Vector2(46, 30)
	energy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	energy.clip_text = true
	row.add_child(energy)
	return row


func _make_labeled_panel(panel: Control, title: String, color: String, title_width := 240, top_gap := 26) -> Control:
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
	title_bar.offset_left = 22.0
	title_bar.offset_top = 0.0
	title_bar.offset_right = 22.0 + float(title_width)
	title_bar.offset_bottom = 42.0
	holder.add_child(title_bar)
	return holder


func _make_title_label_bar(text: String, color: String, width := 240) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 42)
	var frame := CommonTitleBarScene.instantiate() as NinePatchRect
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.frame_color = color
	frame.apply_default_size = false
	CommonFrameScript.apply_title_bar(frame, color, Vector2.ZERO)
	holder.add_child(frame)
	var label := _make_label(text, 20, TEXT_GOLD, 2)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 24
	label.offset_right = -24
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(label)
	return holder


func _make_header_cell(text: String, width: int, color: String) -> Control:
	var panel := ColorRect.new()
	panel.name = "HeaderCell"
	panel.color = _header_color(color)
	panel.custom_minimum_size = Vector2(width, 26) if width > 0 else Vector2(0, 26)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if width > 0:
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	panel.add_child(margin)
	var label := _make_label(text, 15, TEXT_GOLD, 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return panel


func _header_color(color: String) -> Color:
	match color:
		CommonFrameScript.DARK_RED:
			return Color(0.32, 0.08, 0.09, 0.88)
		CommonFrameScript.DARK_TEAL:
			return Color(0.04, 0.28, 0.26, 0.88)
		CommonFrameScript.DARK_PURPLE:
			return Color(0.22, 0.10, 0.28, 0.88)
		_:
			return Color(0.08, 0.08, 0.08, 0.82)


func _make_empty_message(text: String) -> Control:
	var label := _make_label(text, 26, TEXT_GOLD, 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _ensure_round_badge() -> void:
	if round_badge != null and is_instance_valid(round_badge):
		return
	round_badge = get_node_or_null("RoundBadge") as Control
	if round_badge != null:
		return
	round_badge = RoundCounterPanelScene.instantiate() as Control
	round_badge.name = "RoundBadge"
	round_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_badge.anchor_left = 1.0
	round_badge.anchor_right = 1.0
	round_badge.anchor_top = 0.0
	round_badge.anchor_bottom = 0.0
	round_badge.offset_left = -388.0
	round_badge.offset_right = -88.0
	round_badge.offset_top = 36.0
	round_badge.offset_bottom = 90.0
	add_child(round_badge)
	round_badge.move_to_front()


func _update_round_badge(state) -> void:
	_ensure_round_badge()
	if round_badge == null:
		return
	if state == null or not bool(state.get("council_mode")):
		round_badge.visible = false
		return
	round_badge.visible = true
	round_badge.move_to_front()
	if round_badge.has_method("set_round"):
		round_badge.call("set_round", int(state.chapter_round) + 1, int(state.max_rounds))


func _make_icon(path: String, size: int, tooltip := "") -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = tooltip
	icon.texture = _load_texture(path)
	return icon


func _crime_icon_path(crime_id: String) -> String:
	if crime_id.is_empty():
		return ""
	var path := COUNCIL_ICON_ROOT + "crime_%s.png" % crime_id
	if ResourceLoader.exists(path):
		return path
	return COUNCIL_ICON_ROOT + "crime_hush_money_invoice.png"


func _faction_icon_path(faction_id: String) -> String:
	return COUNCIL_ICON_ROOT + "faction_%s.png" % faction_id


func _avatar_texture_path(member: Dictionary) -> String:
	var portrait := String(member.get("portrait", "player_portrait.png"))
	var head_avatar := portrait.replace("_portrait.png", "_head_avatar.png")
	var head_path := CHARACTER_HEADICON_ROOT + head_avatar
	if ResourceLoader.exists(head_path):
		return head_path
	return CHARACTER_PORTRAIT_ROOT + portrait


func _vote_member_ids(state, crime_id: String, vote: String) -> Array[String]:
	var result: Array[String] = []
	for record in state.council_vote_records:
		if String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			result.append(String(record.get("member_id", "")))
	return result


func _tendency_member_ids(state, crime_id: String, vote: String) -> Array[String]:
	var result: Array[String] = []
	for record in state.council_vote_tendencies:
		if String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			result.append(String(record.get("member_id", "")))
	return result


func _all_members(state) -> Array:
	var result: Array = [state.player]
	for npc in state.npcs:
		result.append(npc)
	return result


func _member_by_id(state, member_id: String) -> Dictionary:
	for member in _all_members(state):
		if String(member.get("id", "")) == member_id:
			return member
	return {}


func _threshold(state) -> int:
	return int(ceil(float(_all_members(state).size()) / 2.0))


func _player_crime_ids(state) -> Array[String]:
	var result: Array[String] = []
	for crime_id in state.player.get("hidden_crimes", []):
		result.append(String(crime_id))
	while result.size() < 3:
		result.append("")
	return result.slice(0, 3)


func _player_dossier_lines(state) -> Array[Dictionary]:
	var faction_id := String(state.player.get("hidden_faction", ""))
	var faction_info := CouncilRulesEngine.faction_public_crimes(state, faction_id)
	var faction_crime := String(faction_info.get("shared_crime_id", ""))
	var faction_safe := String(faction_info.get("safe_crime_id", ""))
	var result: Array[Dictionary] = []
	if not faction_crime.is_empty():
		result.append({
			"crime_id": faction_crime,
			"tag": "-阵营罪行",
			"color": TEXT_MAIN,
			"tag_color": Color(1.0, 0.30, 0.24, 1.0)
		})
	for crime_id in state.player.get("hidden_crimes", []):
		var id := String(crime_id)
		if id.is_empty() or id == faction_crime:
			continue
		result.append({
			"crime_id": id,
			"tag": "-个人罪行",
			"color": TEXT_MAIN,
			"tag_color": Color(1.0, 0.30, 0.24, 1.0)
		})
	while result.size() < 3:
		result.append({
			"crime_id": "",
			"tag": "-个人罪行",
			"color": TEXT_DIM,
			"tag_color": Color(1.0, 0.30, 0.24, 1.0)
		})
	if not faction_safe.is_empty():
		result.append({
			"crime_id": faction_safe,
			"tag": "-阵营无罪",
			"color": Color(0.48, 1.0, 0.68, 1.0),
			"tag_color": Color(0.48, 1.0, 0.68, 1.0)
		})
	return result

func _crime_title(state, crime_id: String) -> String:
	if crime_id.is_empty():
		return "未分配"
	for crime in state.council_crime_pool:
		if String(crime.get("id", "")) == crime_id:
			return String(crime.get("title", crime_id))
	return crime_id


func _faction_name(state, faction_id: String) -> String:
	for faction in state.council_factions:
		if String(faction.get("id", "")) == faction_id:
			return String(faction.get("name", faction_id))
	return faction_id if not faction_id.is_empty() else "未分配阵营"


func _remaining_energy(state) -> int:
	if state == null:
		return 0
	return maxi(0, int(state.max_player_chars) - int(state.player_chars))


func _member_tooltip(state, member: Dictionary, tendency := false) -> String:
	var parts: Array[String] = []
	parts.append(String(member.get("public_name", "议员")))
	parts.append("倾向票" if tendency else ("存活" if bool(member.get("alive", true)) else "已处决"))
	if bool(member.get("faction_revealed", false)) or bool(state.ended):
		parts.append(_faction_name(state, String(member.get("hidden_faction", ""))))
	return " / ".join(parts)
