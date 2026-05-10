extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name HistoryPage

var summary_box: VBoxContainer
var history_view: RichTextLabel
var footer_label: Label


func _init() -> void:
	page_title = "历史对话"
	background_path = "res://assets/ui/history/history_page_bg.png"
	panel_color = CommonFrameScript.DARK_PURPLE


func _build_page() -> void:
	var columns := HBoxContainer.new()
	columns.name = "HistoryColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	content_box.add_child(columns)

	var left_panel := _make_section_panel("HistorySummaryPanel", CommonFrameScript.GRAY)
	left_panel.custom_minimum_size = Vector2(270, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	columns.add_child(left_panel)
	summary_box = _make_section_content(left_panel)
	summary_box.add_child(_make_label("章节与筛选", 22, Color(1.0, 0.84, 0.38, 1.0), 2))

	var right_panel := _make_section_panel("HistoryLogPanel", CommonFrameScript.GRAY)
	columns.add_child(right_panel)
	var right_box := _make_section_content(right_panel)
	var title := _make_label("完整记录", 22, Color(1.0, 0.84, 0.38, 1.0), 2)
	right_box.add_child(title)

	history_view = RichTextLabel.new()
	history_view.name = "HistoryView"
	history_view.bbcode_enabled = true
	history_view.fit_content = false
	history_view.scroll_following = false
	history_view.selection_enabled = true
	history_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_view.add_theme_font_size_override("normal_font_size", 17)
	history_view.add_theme_color_override("default_color", Color(1.0, 0.91, 0.74, 1.0))
	var font := _load_font()
	if font != null:
		history_view.add_theme_font_override("normal_font", font)
	right_box.add_child(history_view)

	footer_label = _make_label("暂无历史记录", 16, Color(1.0, 0.84, 0.38, 1.0), 2)
	footer_label.name = "FooterLabel"
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_box.add_child(footer_label)
	set_history("", [], "等待开始")


func _bind_page() -> void:
	summary_box = get_node_or_null("MainPanel/ContentMargin/Content/HistoryColumns/HistorySummaryPanel/MarginContainer/VBoxContainer") as VBoxContainer
	history_view = get_node_or_null("MainPanel/ContentMargin/Content/HistoryColumns/HistoryLogPanel/MarginContainer/VBoxContainer/HistoryView") as RichTextLabel
	footer_label = get_node_or_null("MainPanel/ContentMargin/Content/FooterLabel") as Label


func set_history(history_text: String, event_log: Array, summary := "") -> void:
	if history_view == null:
		return
	_clear_children(summary_box)
	summary_box.add_child(_make_label("章节与筛选", 22, Color(1.0, 0.84, 0.38, 1.0), 2))
	for item in _summary_items(summary, history_text, event_log):
		var label := _make_label(String(item), 17, Color(0.94, 0.90, 0.78, 1.0), 2)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_box.add_child(label)

	history_view.clear()
	if history_text.strip_edges().is_empty():
		history_view.append_text("[color=#f5d889]暂无对话记录。[/color]")
	else:
		history_view.append_text("[color=#ffd77a][b]对话历史[/b][/color]\n")
		history_view.append_text(_escape(history_text))
	if not event_log.is_empty():
		history_view.append_text("\n\n[color=#e99755][b]行动与发现[/b][/color]\n")
		for item in event_log:
			history_view.append_text("[color=#f0c0a0]- %s[/color]\n" % _escape(String(item)))
	var count := _count_history_lines(history_text) + event_log.size()
	footer_label.text = "共 %d 条记录 / %s" % [count, summary if not summary.is_empty() else "当前进度"]


func _summary_items(summary: String, history_text: String, event_log: Array) -> Array[String]:
	var items: Array[String] = []
	items.append(summary if not summary.is_empty() else "当前章节：等待开始")
	items.append("对话条目：%d" % _count_history_lines(history_text))
	items.append("行动发现：%d" % event_log.size())
	items.append("显示：玩家 / 对手 / 系统事件")
	return items


func _count_history_lines(text: String) -> int:
	var count := 0
	for line in text.split("\n", false):
		if not String(line).strip_edges().is_empty():
			count += 1
	return count


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
