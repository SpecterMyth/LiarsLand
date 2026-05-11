extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name StatusPage

const COUNCIL_ICON_ROOT := "res://assets/generated/ui/council_icons/"

var root_box: VBoxContainer


func _init() -> void:
	page_title = "议会状态"
	background_path = "res://assets/ui/status/status_page_bg.png"
	panel_color = CommonFrameScript.DARK_TEAL
	main_panel_rect = Rect2(54, 92, 1172, 586)


func _build_page() -> void:
	root_box = content_box
	bind_state(null)


func _bind_page() -> void:
	root_box = get_node_or_null("MainPanel/ContentMargin/Content") as VBoxContainer


func bind_state(state) -> void:
	if root_box == null:
		return
	_clear_children(root_box)
	if state == null:
		root_box.add_child(_make_label("等待议会开始", 26, Color(1.0, 0.84, 0.38, 1.0), 2))
		return
	if bool(state.get("council_mode")):
		_bind_council_state(state)
	else:
		root_box.add_child(_make_label("旧版状态", 24, Color(1.0, 0.84, 0.38, 1.0), 2))


func _bind_council_state(state) -> void:
	root_box.add_theme_constant_override("separation", 12)
	root_box.add_child(_make_header_panel(state))
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_box.add_child(body)
	body.add_child(_make_vote_board(state))
	body.add_child(_make_roster_panel(state))


func _make_header_panel(state) -> Control:
	var panel := _make_section_panel("CouncilHeader", CommonFrameScript.DARK_PURPLE)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(0, 132)
	var box := _make_section_content(panel, 20)
	box.add_theme_constant_override("separation", 10)
	var current := "未选择"
	if state.has_method("current_npc") and not state.current_npc().is_empty():
		current = String(state.current_npc().get("public_name", "未选择"))
	var summary := HBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 10)
	box.add_child(summary)
	summary.add_child(_make_meta_tile("章节", "%d / %d" % [int(state.chapter_index) + 1, int(state.max_chapters)]))
	summary.add_child(_make_meta_tile("回合", "%d / %d" % [int(state.chapter_round) + 1, int(state.max_rounds)]))
	summary.add_child(_make_meta_tile("存活", "%d / %d" % [_alive_count(state), _all_members(state).size()]))
	summary.add_child(_make_meta_tile("处决阈值", "%d 票" % _threshold(state)))
	summary.add_child(_make_meta_tile("当前会谈", current, 1.45))

	var dossier := HBoxContainer.new()
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.add_theme_constant_override("separation", 16)
	box.add_child(dossier)
	dossier.add_child(_make_faction_name_line(state, String(state.player.get("hidden_faction", "")), "我的阵营"))
	dossier.add_child(_make_self_crime_line(state))
	return panel


func _make_meta_tile(label_text: String, value_text: String, width_weight := 1.0) -> Control:
	var panel := _make_section_panel("MetaTile", CommonFrameScript.GRAY)
	panel.custom_minimum_size = Vector2(128 * width_weight, 48)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = width_weight
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	margin.add_child(box)
	var label := _make_label(label_text, 12, Color(0.74, 0.70, 0.62, 1.0), 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var value := _make_label(value_text, 18, Color(1.0, 0.84, 0.38, 1.0), 2)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.clip_text = true
	box.add_child(value)
	return panel


func _make_faction_name_line(state, faction_id: String, prefix: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prefix_label := _make_label(prefix + "：", 17, Color(0.92, 0.86, 0.72, 1.0), 2)
	prefix_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(prefix_label)
	row.add_child(_make_icon(_faction_icon_path(faction_id), 28, _faction_name(state, faction_id)))
	var faction_label := _make_label(_faction_name(state, faction_id), 18, Color(1.0, 0.82, 0.50, 1.0), 2)
	faction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	faction_label.clip_text = true
	row.add_child(faction_label)
	return row


func _make_self_crime_line(state) -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 34)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)
	var prefix := _make_label("本章罪行：", 17, Color(0.92, 0.86, 0.72, 1.0), 2)
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(prefix)
	for crime_id in state.player.get("hidden_crimes", []):
		row.add_child(_make_crime_chip(state, String(crime_id)))
	return scroll


func _make_crime_chip(state, crime_id: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(168, 30)
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon(_crime_icon_path(crime_id), 26, _crime_title(state, crime_id)))
	var label := _make_label(_crime_title(state, crime_id), 14, Color(1.0, 0.91, 0.74, 1.0), 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	row.add_child(label)
	return row


func _make_vote_board(state) -> Control:
	var panel := _make_section_panel("VoteBoard", CommonFrameScript.DARK_TEAL)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _make_section_content(panel, 20)
	box.add_theme_constant_override("separation", 10)
	box.add_child(_make_label("投票卷宗", 22, Color(1.0, 0.84, 0.38, 1.0), 2))
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 28)
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	header.add_child(_make_column_title("有罪", 142, HORIZONTAL_ALIGNMENT_LEFT))
	header.add_child(_make_column_title("罪行与票数", 0, HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_make_column_title("无罪", 142, HORIZONTAL_ALIGNMENT_RIGHT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 7)
	scroll.add_child(rows)
	for crime in state.council_crime_pool:
		rows.add_child(_make_vote_row(state, crime))
	return panel


func _make_column_title(text: String, width: int, align: HorizontalAlignment) -> Label:
	var label := _make_label(text, 21, Color(1.0, 0.84, 0.38, 1.0), 2)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if width > 0:
		label.custom_minimum_size = Vector2(width, 0)
	return label


func _make_vote_row(state, crime: Dictionary) -> Control:
	var crime_id := String(crime.get("id", ""))
	var row_panel := _make_section_panel("VoteRow", CommonFrameScript.GRAY)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row_panel.custom_minimum_size = Vector2(0, 72)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	row_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	row.add_child(_make_avatar_row(state, _vote_member_ids(state, crime_id, "guilty"), _tendency_member_ids(state, crime_id, "guilty"), 142))
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(center)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 8)
	center.add_child(title_row)
	title_row.add_child(_make_icon(_crime_icon_path(crime_id), 30, String(crime.get("title", crime_id))))
	var title := _make_label(String(crime.get("title", crime_id)), 16, Color(1.0, 0.91, 0.74, 1.0), 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var count := _make_label("有罪 %d / %d    无罪 %d    倾向 %d" % [
		_vote_member_ids(state, crime_id, "guilty").size(),
		_threshold(state),
		_vote_member_ids(state, crime_id, "innocent").size(),
		_tendency_member_ids(state, crime_id, "guilty").size() + _tendency_member_ids(state, crime_id, "innocent").size()
	], 13, Color(0.82, 0.76, 0.66, 1.0), 1)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(count)
	row.add_child(_make_avatar_row(state, _vote_member_ids(state, crime_id, "innocent"), _tendency_member_ids(state, crime_id, "innocent"), 142))
	return row_panel


func _make_roster_panel(state) -> Control:
	var panel := _make_section_panel("RosterPanel", CommonFrameScript.GRAY)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _make_section_content(panel, 20)
	box.add_theme_constant_override("separation", 10)
	box.add_child(_make_label("全体议员", 22, Color(1.0, 0.84, 0.38, 1.0), 2))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for member in _all_members(state):
		grid.add_child(_make_avatar_tile(member, true, not bool(member.get("alive", true)), String(member.get("id", "")) == "player", state))
	return panel


func _make_avatar_row(state, locked_ids: Array[String], tendency_ids: Array[String], width := 0) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(width, 42)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	for member_id in locked_ids:
		row.add_child(_make_avatar_tile(_member_by_id(state, member_id), false, false, member_id == "player", state))
	for member_id in tendency_ids:
		if member_id in locked_ids:
			continue
		row.add_child(_make_avatar_tile(_member_by_id(state, member_id), false, false, member_id == "player", state, true))
	if locked_ids.is_empty() and tendency_ids.is_empty():
		var none := _make_label("无", 13, Color(0.65, 0.60, 0.56, 1.0), 1)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(none)
	return row


func _make_avatar_tile(member: Dictionary, with_name: bool, dead: bool, is_self: bool, state, tendency := false) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(118 if with_name else 50, 82 if with_name else 36)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	var avatar := TextureRect.new()
	var avatar_size := 42 if with_name else 32
	avatar.custom_minimum_size = Vector2(avatar_size, avatar_size)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path := _avatar_texture_path(member)
	if ResourceLoader.exists(path):
		avatar.texture = load(path)
	avatar.material = _avatar_material(dead, tendency)
	avatar.tooltip_text = "%s%s" % [String(member.get("public_name", "")), " / " + _faction_name(state, String(member.get("hidden_faction", ""))) if bool(member.get("faction_revealed", false)) or state.ended else ""]
	box.add_child(avatar)
	if with_name:
		var name := "我" if is_self else String(member.get("public_name", ""))
		if name.length() > 5:
			name = name.substr(0, 5)
		var name_row := HBoxContainer.new()
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.add_theme_constant_override("separation", 3)
		box.add_child(name_row)
		var faction_id := String(member.get("hidden_faction", ""))
		if bool(member.get("faction_revealed", false)) or state.ended:
			name_row.add_child(_make_icon(_faction_icon_path(faction_id), 16, _faction_name(state, faction_id)))
		var label := _make_label(name + ("×" if dead else ""), 12, Color(1.0, 0.91, 0.74, 1.0), 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		name_row.add_child(label)
	return box


func _make_icon(path: String, size: int, tooltip := "") -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = tooltip
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	return icon


func _crime_icon_path(crime_id: String) -> String:
	return COUNCIL_ICON_ROOT + "crime_%s.png" % crime_id


func _faction_icon_path(faction_id: String) -> String:
	return COUNCIL_ICON_ROOT + "faction_%s.png" % faction_id


func _avatar_texture_path(member: Dictionary) -> String:
	var portrait := String(member.get("portrait", "player_portrait.png"))
	var circle_avatar := portrait.replace("_portrait.png", "_circle_avatar.png")
	var circle_path := "res://assets/generated/%s" % circle_avatar
	if ResourceLoader.exists(circle_path):
		return circle_path
	var head_avatar := portrait.replace("_portrait.png", "_head_avatar.png")
	var head_path := "res://assets/generated/%s" % head_avatar
	if ResourceLoader.exists(head_path):
		return head_path
	return "res://assets/generated/%s" % portrait


func _avatar_material(dead: bool, tendency: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float fade = 0.0;\nuniform float gray = 0.0;\nvoid fragment(){ vec2 p = UV - vec2(0.5); if(length(p) > 0.5){ discard; } vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.299,0.587,0.114)); c.rgb = mix(c.rgb, vec3(g), gray); c.a *= 1.0 - fade; COLOR = c; }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fade", 0.52 if dead else (0.35 if tendency else 0.0))
	mat.set_shader_parameter("gray", 1.0 if dead or tendency else 0.0)
	return mat


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


func _alive_count(state) -> int:
	var count := 0
	for member in _all_members(state):
		if bool(member.get("alive", true)):
			count += 1
	return count


func _threshold(state) -> int:
	return int(ceil(float(_all_members(state).size()) / 2.0))


func _crime_titles(state, ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id in ids:
		result.append(_crime_title(state, String(id)))
	return result


func _crime_title(state, crime_id: String) -> String:
	for crime in state.council_crime_pool:
		if String(crime.get("id", "")) == crime_id:
			return String(crime.get("title", crime_id))
	return crime_id


func _faction_name(state, faction_id: String) -> String:
	for faction in state.council_factions:
		if String(faction.get("id", "")) == faction_id:
			return String(faction.get("name", faction_id))
	return faction_id
