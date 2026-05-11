extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name CouncilResultPage

signal continue_requested
signal restart_requested

var body_box: VBoxContainer
var continue_button: Button
var restart_button: Button


func _init() -> void:
	page_title = "议会结算"
	background_path = "res://assets/ui/status/status_page_bg.png"
	panel_color = CommonFrameScript.DARK_RED
	main_panel_rect = Rect2(74, 92, 1132, 586)


func _build_page() -> void:
	body_box = VBoxContainer.new()
	body_box.name = "ResultBody"
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_theme_constant_override("separation", 14)
	content_box.add_child(body_box)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	content_box.add_child(buttons)

	restart_button = StandardButtonScript.new()
	StandardButtonScript.apply(restart_button, StandardButtonScript.SECONDARY, "重开", 22, Vector2(160, 56))
	restart_button.pressed.connect(func(): restart_requested.emit())
	buttons.add_child(restart_button)

	continue_button = StandardButtonScript.new()
	StandardButtonScript.apply(continue_button, StandardButtonScript.PRIMARY, "继续", 22, Vector2(190, 56))
	continue_button.pressed.connect(func(): continue_requested.emit())
	buttons.add_child(continue_button)


func _bind_page() -> void:
	body_box = get_node_or_null("MainPanel/ContentMargin/Content/ResultBody") as VBoxContainer


func show_result(state, final_game := false) -> void:
	if body_box == null:
		_build_base()
	if body_box == null:
		push_error("CouncilResultPage body was not built.")
		return
	_clear_children(body_box)
	var title := "最终通关" if final_game and state.victory else ("章节胜利" if state.victory else "游戏失败")
	body_box.add_child(_make_label(title, 34, Color(1.0, 0.84, 0.38, 1.0), 3))
	var reason := _make_label(String(state.end_reason), 18, Color(1.0, 0.91, 0.74, 1.0), 2)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_box.add_child(reason)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	body_box.add_child(columns)
	columns.add_child(_make_summary_panel("玩家档案", _player_lines(state)))
	columns.add_child(_make_summary_panel("全员揭示", _member_lines(state)))
	columns.add_child(_make_summary_panel("关键投票", _vote_lines(state)))
	if continue_button != null:
		continue_button.text = "完成" if final_game or not state.victory else "进入下一章"
		continue_button.visible = state.victory
	if restart_button != null:
		restart_button.visible = not state.victory
	visible = true


func _make_summary_panel(title: String, lines: Array[String]) -> Control:
	var panel := _make_section_panel("ResultPanel", CommonFrameScript.GRAY)
	var box := _make_section_content(panel, 34)
	box.add_child(_make_label(title, 21, Color(1.0, 0.84, 0.38, 1.0), 2))
	var label := _make_label("\n".join(lines), 15, Color(0.94, 0.90, 0.78, 1.0), 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return panel


func _player_lines(state) -> Array[String]:
	return [
		"阵营：%s" % _faction_name(state, String(state.player.get("hidden_faction", ""))),
		"状态：%s" % ("存活" if bool(state.player.get("alive", true)) else "已处决"),
		"本章罪行：",
		"- " + "\n- ".join(_crime_titles(state, state.player.get("hidden_crimes", [])))
	]


func _member_lines(state) -> Array[String]:
	var lines: Array[String] = []
	for member in _all_members(state):
		lines.append("%s / %s / %s" % [
			String(member.get("public_name", "")),
			_faction_name(state, String(member.get("hidden_faction", ""))),
			"存活" if bool(member.get("alive", true)) else "已处决"
		])
	return lines


func _vote_lines(state) -> Array[String]:
	var lines: Array[String] = []
	for crime in state.council_crime_pool:
		var crime_id := String(crime.get("id", ""))
		var guilty := _vote_names(state, crime_id, "guilty")
		if not guilty.is_empty():
			lines.append("%s：%s" % [String(crime.get("title", crime_id)), "、".join(guilty)])
	if lines.is_empty():
		lines.append("暂无关键投票。")
	return lines


func _vote_names(state, crime_id: String, vote: String) -> Array[String]:
	var names: Array[String] = []
	for record in state.council_vote_records:
		if String(record.get("crime_id", "")) == crime_id and String(record.get("vote", "")) == vote:
			names.append(_member_name(state, String(record.get("member_id", ""))))
	return names


func _all_members(state) -> Array:
	var result: Array = [state.player]
	for npc in state.npcs:
		result.append(npc)
	return result


func _member_name(state, member_id: String) -> String:
	for member in _all_members(state):
		if String(member.get("id", "")) == member_id:
			return String(member.get("public_name", member_id))
	return member_id


func _crime_titles(state, ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id in ids:
		var title := String(id)
		for crime in state.council_crime_pool:
			if String(crime.get("id", "")) == String(id):
				title = String(crime.get("title", id))
				break
		result.append(title)
	return result


func _faction_name(state, faction_id: String) -> String:
	for faction in state.council_factions:
		if String(faction.get("id", "")) == faction_id:
			return String(faction.get("name", faction_id))
	return faction_id
