extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name StatusPage

var card_grid: GridContainer
var detail_view: RichTextLabel


func _init() -> void:
	page_title = "状态"
	background_path = "res://assets/ui/status/status_page_bg.png"
	panel_color = CommonFrameScript.DARK_TEAL


func _build_page() -> void:
	card_grid = GridContainer.new()
	card_grid.name = "StatusCardGrid"
	card_grid.columns = 3
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 16)
	card_grid.add_theme_constant_override("v_separation", 16)
	content_box.add_child(card_grid)

	var lower := HBoxContainer.new()
	lower.name = "StatusLower"
	lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 18)
	content_box.add_child(lower)

	var relation_panel := _make_section_panel("RelationPanel", CommonFrameScript.GRAY)
	lower.add_child(relation_panel)
	var relation_box := _make_section_content(relation_panel)
	relation_box.add_child(_make_label("关系与风险", 22, Color(1.0, 0.84, 0.38, 1.0), 2))
	detail_view = RichTextLabel.new()
	detail_view.name = "StatusDetailView"
	detail_view.bbcode_enabled = true
	detail_view.fit_content = false
	detail_view.selection_enabled = true
	detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_view.add_theme_font_size_override("normal_font_size", 17)
	detail_view.add_theme_color_override("default_color", Color(1.0, 0.91, 0.74, 1.0))
	var font := _load_font()
	if font != null:
		detail_view.add_theme_font_override("normal_font", font)
	relation_box.add_child(detail_view)
	bind_state(null)


func _bind_page() -> void:
	card_grid = get_node_or_null("MainPanel/ContentMargin/Content/StatusCardGrid") as GridContainer
	detail_view = get_node_or_null("MainPanel/ContentMargin/Content/StatusLower/RelationPanel/MarginContainer/VBoxContainer/StatusDetailView") as RichTextLabel


func bind_state(state) -> void:
	if card_grid == null:
		return
	_clear_children(card_grid)
	if state == null:
		_add_card("章节 / 回合", "等待开始", "点击开始后进入章节", CommonFrameScript.GRAY)
		_add_card("字符与能量", "0 / 0", "能量：0  等级：1", CommonFrameScript.GRAY)
		_add_card("当前对手", "未选择", "等待候选对手", CommonFrameScript.GRAY)
		if detail_view != null:
			detail_view.clear()
			detail_view.append_text("[color=#ffd77a]暂无状态。[/color]")
		return
	_add_card(
		"章节 / 回合",
		"%d / %d 章" % [int(state.chapter_index) + 1, int(state.max_chapters)],
		"回合 %d / %d，对话 %d / %d" % [int(state.chapter_round) + 1, int(state.max_rounds), int(state.turn), int(state.max_dialogue_turns)],
		CommonFrameScript.GRAY
	)
	_add_card(
		"字符与能量",
		"%d / %d" % [int(state.player_chars), int(state.max_player_chars)],
		"能量：%d  等级：%d" % [int(state.player.get("energy", 0)), int(state.player.get("level", 1))],
		CommonFrameScript.GRAY
	)
	var npc: Dictionary = state.current_npc() if state.has_method("current_npc") else {}
	_add_card(
		"当前对手",
		String(npc.get("public_name", "未选择")),
		"判断：%s" % String(npc.get("friend_judgement", "unknown")),
		CommonFrameScript.GRAY
	)
	if detail_view != null:
		detail_view.clear()
		detail_view.append_text("[color=#ffd77a][b]公开信息[/b][/color]\n")
		if npc.is_empty():
			detail_view.append_text("尚未选择当前对手。")
		else:
			detail_view.append_text("亲近度：%d\n" % int(npc.get("affinity", 0)))
			detail_view.append_text("地盘：%s\n" % _escape(String(npc.get("territory", "未知"))))
			detail_view.append_text("身份：%s\n" % _escape(String(npc.get("public_identity", "未知身份"))))
			detail_view.append_text("阶段：第 %d 章，第 %d 回合" % [int(state.chapter_index) + 1, int(state.chapter_round) + 1])


func _add_card(title: String, value: String, detail: String, color: String) -> void:
	var panel := _make_section_panel("StatusCard", color)
	panel.custom_minimum_size = Vector2(0, 156)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := _make_section_content(panel, 42)
	box.add_child(_make_label(title, 18, Color(0.94, 0.90, 0.78, 1.0), 2))
	var value_label := _make_label(value, 28, Color(1.0, 0.84, 0.38, 1.0), 2)
	value_label.clip_text = true
	box.add_child(value_label)
	var detail_label := _make_label(detail, 16, Color(0.92, 0.86, 0.72, 1.0), 2)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail_label)
	card_grid.add_child(panel)


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
