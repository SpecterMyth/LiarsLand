extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name HistoryPage

const ROW_HEIGHT := 43
const PLAYER_ROW_HEIGHT := 62
const CONTENT_FONT_SIZE := 15
const LINE_HEIGHT := 21
const SPEAKER_AVATAR_SIZE := 24
const VISIBLE_TEXT_LINES := 20
const CHARACTER_ROOT := "res://assets/ui/characters/"
const CHARACTER_HEADICON_ROOT := CHARACTER_ROOT + "headicon/"
const CHARACTER_PORTRAIT_ROOT := CHARACTER_ROOT + "portrait/"
const RoundCounterPanelScene := preload("res://scenes/ui/round_counter_panel.tscn")

var summary_box: VBoxContainer
var history_view: RichTextLabel
var footer_label: Label

var character_scroll: ScrollContainer
var character_list: VBoxContainer
var content_scroll: ScrollContainer
var content_list: VBoxContainer
var round_badge: Control
var round_label: Label

var _members: Array = []
var _entries: Array = []
var _events: Array = []
var _selected_member_id := ""
var _summary := ""


func _init() -> void:
	page_title = "\u5386\u53f2\u5bf9\u8bdd"
	background_path = "res://assets/ui/history/history_page_bg.png"
	panel_color = CommonFrameScript.DARK_PURPLE


func _build_page() -> void:
	_build_history_layout()
	set_history("", [], "\u7b49\u5f85\u5f00\u59cb")


func _bind_page() -> void:
	if title_label != null:
		title_label.text = "\u5386\u53f2\u5bf9\u8bdd"
	if close_button != null:
		close_button.tooltip_text = "\u5173\u95ed"
	_bind_history_layout()
	_build_round_badge()
	set_history("", [], "\u51c6\u5907\u8bb0\u5f55")


func set_history(history_text: String, event_log: Array, summary := "") -> void:
	_summary = summary
	_members = [
		{
			"id": "player",
			"name": "\u73a9\u5bb6",
			"portrait": "player_portrait.png",
			"alive": true
		},
		{
			"id": "opponent",
			"name": "\u5bf9\u624b",
			"portrait": "npc_unknown_portrait.png",
			"alive": true
		}
	]
	_entries.clear()
	for line in history_text.split("\n", false):
		var stripped := String(line).strip_edges()
		if stripped.is_empty():
			continue
		var speaker_id := "player" if stripped.begins_with("\u73a9\u5bb6") else "opponent"
		var speaker_name := "\u73a9\u5bb6" if speaker_id == "player" else "\u5bf9\u624b"
		var content := stripped
		var colon := stripped.find("\uff1a")
		if colon >= 0:
			content = stripped.substr(colon + 1).strip_edges()
		_entries.append({
			"round": _round_from_summary(summary),
			"speaker_id": speaker_id,
			"speaker_name": speaker_name,
			"content": content
		})
	_events = event_log.duplicate()
	_selected_member_id = "opponent"
	_render_all()


func set_council_history(entries: Array, members: Array, event_log: Array, summary := "") -> void:
	_summary = summary
	_entries = entries.duplicate(true)
	_members = members.duplicate(true)
	_events = event_log.duplicate(true)
	_selected_member_id = _first_non_player_member_id()
	_render_all()


func _build_history_layout() -> void:
	content_box.add_theme_constant_override("separation", 0)
	content_margin.add_theme_constant_override("margin_left", 28)
	content_margin.add_theme_constant_override("margin_top", 24)
	content_margin.add_theme_constant_override("margin_right", 28)
	content_margin.add_theme_constant_override("margin_bottom", 24)

	var columns := HBoxContainer.new()
	columns.name = "HistoryColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	content_box.add_child(columns)

	var left_panel := PanelContainer.new()
	left_panel.name = "HistorySummaryPanel"
	left_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	left_panel.custom_minimum_size = Vector2(286, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	columns.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.name = "MarginContainer"
	left_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_margin.add_theme_constant_override("margin_left", 22)
	left_margin.add_theme_constant_override("margin_top", 20)
	left_margin.add_theme_constant_override("margin_right", 22)
	left_margin.add_theme_constant_override("margin_bottom", 18)
	left_panel.add_child(left_margin)

	var left_box := VBoxContainer.new()
	left_box.name = "VBoxContainer"
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_box)
	summary_box = left_box

	character_scroll = ScrollContainer.new()
	character_scroll.name = "CharacterScroll"
	character_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_box.add_child(character_scroll)

	character_list = VBoxContainer.new()
	character_list.name = "CharacterList"
	character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_list.add_theme_constant_override("separation", 0)
	character_scroll.add_child(character_list)

	var right_panel := _make_section_panel("HistoryLogPanel", CommonFrameScript.GRAY)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.name = "MarginContainer"
	right_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_margin.add_theme_constant_override("margin_left", 26)
	right_margin.add_theme_constant_override("margin_top", 20)
	right_margin.add_theme_constant_override("margin_right", 26)
	right_margin.add_theme_constant_override("margin_bottom", 18)
	right_panel.add_child(right_margin)

	content_scroll = ScrollContainer.new()
	content_scroll.name = "DialogueScroll"
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_margin.add_child(content_scroll)

	content_list = VBoxContainer.new()
	content_list.name = "DialogueList"
	content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_list.add_theme_constant_override("separation", 2)
	content_scroll.add_child(content_list)

	history_view = RichTextLabel.new()
	history_view.name = "HistoryView"
	history_view.visible = false
	history_view.bbcode_enabled = true
	content_box.add_child(history_view)

	footer_label = Label.new()
	footer_label.name = "FooterLabel"
	footer_label.visible = false
	content_box.add_child(footer_label)


func _bind_history_layout() -> void:
	summary_box = get_node_or_null("MainPanel/ContentMargin/Content/HistoryColumns/HistorySummaryPanel/MarginContainer/VBoxContainer") as VBoxContainer
	character_scroll = get_node_or_null("MainPanel/ContentMargin/Content/HistoryColumns/HistorySummaryPanel/MarginContainer/VBoxContainer/CharacterScroll") as ScrollContainer
	character_list = get_node_or_null("MainPanel/ContentMargin/Content/HistoryColumns/HistorySummaryPanel/MarginContainer/VBoxContainer/CharacterScroll/CharacterList") as VBoxContainer
	content_scroll = get_node_or_null("MainPanel/ContentMargin/Content/HistoryColumns/HistoryLogPanel/MarginContainer/DialogueScroll") as ScrollContainer
	content_list = get_node_or_null("MainPanel/ContentMargin/Content/HistoryColumns/HistoryLogPanel/MarginContainer/DialogueScroll/DialogueList") as VBoxContainer
	history_view = get_node_or_null("MainPanel/ContentMargin/Content/HistoryView") as RichTextLabel
	footer_label = get_node_or_null("MainPanel/ContentMargin/Content/FooterLabel") as Label
	round_badge = get_node_or_null("RoundBadge") as Control
	round_label = get_node_or_null("RoundBadge/RoundCounterLabel") as Label
	if round_label == null:
		round_label = get_node_or_null("RoundBadge/RoundLabel") as Label
	if character_list == null or content_list == null:
		_clear_children(content_box)
		_build_history_layout()


func _build_round_badge() -> void:
	if round_badge != null and is_instance_valid(round_badge):
		return
	round_badge = RoundCounterPanelScene.instantiate() as Control
	round_badge.name = "RoundBadge"
	round_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(round_badge)
	round_badge.z_index = 1
	round_badge.anchor_left = 1.0
	round_badge.anchor_top = 0.0
	round_badge.anchor_right = 1.0
	round_badge.anchor_bottom = 0.0
	round_badge.offset_left = -480.0
	round_badge.offset_top = 25.0
	round_badge.offset_right = -114.0
	round_badge.offset_bottom = 83.0
	if close_button != null:
		close_button.z_index = 2

	round_label = round_badge.get_node_or_null("RoundCounterLabel") as Label


func _render_all() -> void:
	if character_list == null or content_list == null:
		return
	if _selected_member_id.is_empty():
		_selected_member_id = _first_non_player_member_id()
	_render_round()
	_render_members()
	_render_records()
	_update_history_mirror()


func _render_round() -> void:
	_build_round_badge()
	var round_no: int = max(1, _round_from_summary(_summary))
	if round_badge != null and round_badge.has_method("set_round"):
		round_badge.call("set_round", round_no)
	elif round_label != null:
		round_label.text = "\u7b2c %d \u56de\u5408" % round_no


func _render_members() -> void:
	_clear_children(character_list)
	var player := _member_by_id("player")
	if player.is_empty() and not _members.is_empty():
		player = _members[0]
	character_list.add_child(_make_member_button(player, true))
	character_list.add_child(_make_member_separator())

	for member in _members:
		if String(member.get("id", "")) == String(player.get("id", "player")):
			continue
		character_list.add_child(_make_member_button(member, false))
		character_list.add_child(_make_member_separator())


func _render_records() -> void:
	_clear_children(content_list)
	var visible_entries := _filtered_entries()
	var visible_events := _filtered_events()
	if visible_entries.is_empty() and visible_events.is_empty():
		content_list.add_child(_make_empty_label("\u6682\u65e0\u5bf9\u8bdd\u8bb0\u5f55\u3002"))
		return
	for entry in visible_entries:
		content_list.add_child(_make_record_block(entry, false))
	for index in range(visible_events.size()):
		content_list.add_child(_make_event_block(index, visible_events[index]))


func _make_member_button(member: Dictionary, is_player: bool) -> Button:
	var button := Button.new()
	button.name = "PlayerEntry" if is_player else "MemberEntry"
	button.custom_minimum_size = Vector2(0, PLAYER_ROW_HEIGHT if is_player else ROW_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = ""
	button.flat = true
	_apply_member_button_style(button, is_player, String(member.get("id", "")) == _selected_member_id)
	if not is_player:
		button.pressed.connect(func():
			_selected_member_id = String(member.get("id", ""))
			_render_all()
		)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 2
	row.offset_right = -10
	row.offset_bottom = -2
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	button.add_child(row)

	var avatar_size := int((PLAYER_ROW_HEIGHT if is_player else ROW_HEIGHT) - 4)
	var avatar := _make_avatar(String(member.get("portrait", "")), avatar_size)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)

	var selected := String(member.get("id", "")) == _selected_member_id
	var name_color := Color(0.18, 0.10, 0.03, 1.0) if selected else Color(1.0, 0.94, 0.76, 1.0)
	var outline_color := Color(1.0, 0.86, 0.36, 0.0) if selected else Color(0.0, 0.0, 0.0, 1.0)
	var label := _make_label(_member_name(member), 18, name_color, 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_outline_color", outline_color)
	row.add_child(label)
	return button


func _apply_member_button_style(button: Button, is_player: bool, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.78, 0.22, 0.92) if selected else (Color(0.48, 0.10, 0.16, 0.18) if is_player else Color(0.0, 0.0, 0.0, 0.0))
	normal.border_color = Color(0.18, 0.10, 0.03, 0.72) if selected else Color(1.0, 0.82, 0.28, 0.0)
	normal.border_width_left = 2 if selected else 0
	normal.border_width_top = 2 if selected else 0
	normal.border_width_right = 2 if selected else 0
	normal.border_width_bottom = 2 if selected else 0
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_member_separator() -> ColorRect:
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = Color(1.0, 0.82, 0.28, 0.26)
	return separator


func _make_record_block(entry: Dictionary, is_event := false) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "RecordBlock"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 2)
	block.add_child(_make_speaker_line(entry, is_event))

	var body := RichTextLabel.new()
	body.name = "RecordText"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", CONTENT_FONT_SIZE)
	body.add_theme_color_override("default_color", Color(0.10, 0.07, 0.09, 1.0))
	var font := _load_font()
	if font != null:
		body.add_theme_font_override("normal_font", font)
	body.append_text(_escape(String(entry.get("content", ""))))
	block.add_child(body)

	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = Color(0.10, 0.07, 0.09, 0.18)
	block.add_child(separator)
	return block


func _make_event_block(index: int, item) -> VBoxContainer:
	var member := _member_by_id(_selected_member_id)
	if member.is_empty():
		member = _member_by_id("player")
	var title := _event_title(index, item)
	var content := _event_content(item)
	return _make_record_block({
		"speaker_id": String(member.get("id", "player")),
		"speaker_name": title,
		"portrait": String(member.get("portrait", "player_portrait.png")),
		"content": content
	}, true)


func _make_speaker_line(entry: Dictionary, is_event := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SpeakerLine"
	row.custom_minimum_size = Vector2(0, LINE_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var portrait_name := String(entry.get("portrait", ""))
	if portrait_name.is_empty():
		var member := _member_by_id(String(entry.get("speaker_id", "")))
		portrait_name = String(member.get("portrait", ""))
	var avatar := _make_avatar(portrait_name, SPEAKER_AVATAR_SIZE)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)

	var name := _make_label(String(entry.get("speaker_name", "\u8bae\u5458")), 17, Color(0.10, 0.07, 0.09, 1.0), 1)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_event:
		name.add_theme_color_override("font_color", Color(0.18, 0.09, 0.06, 1.0))
	row.add_child(name)
	return row


func _make_avatar(portrait_name: String, size: int) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(size, size)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.06, 1.0)
	style.border_color = Color(1.0, 0.82, 0.28, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = size / 2
	style.corner_radius_top_right = size / 2
	style.corner_radius_bottom_left = size / 2
	style.corner_radius_bottom_right = size / 2
	holder.add_theme_stylebox_override("panel", style)

	var texture := TextureRect.new()
	texture.name = "AvatarTexture"
	texture.custom_minimum_size = Vector2(size - 4, size - 4)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var avatar_path := _portrait_avatar_path(portrait_name)
	if ResourceLoader.exists(avatar_path):
		texture.texture = load(avatar_path)
	holder.add_child(texture)
	return holder


func _make_empty_label(text: String) -> Label:
	var label := _make_label(text, 18, Color(0.10, 0.07, 0.09, 1.0), 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _filtered_entries() -> Array:
	var filtered: Array = []
	for entry in _entries:
		var speaker_id := String(entry.get("speaker_id", ""))
		var counterpart_id := String(entry.get("counterpart_id", ""))
		if not counterpart_id.is_empty():
			if counterpart_id == _selected_member_id:
				filtered.append(entry)
		elif speaker_id == "player" or speaker_id == _selected_member_id:
			filtered.append(entry)
	return filtered


func _filtered_events() -> Array:
	var filtered: Array = []
	for item in _events:
		if _event_matches_selected_member(item):
			filtered.append(item)
	return filtered


func _event_matches_selected_member(item) -> bool:
	if _selected_member_id.is_empty() or _selected_member_id == "player":
		return true
	if item is Dictionary:
		var member_id := String(item.get("member_id", ""))
		var actor_id := String(item.get("actor_id", ""))
		var target_id := String(item.get("target_id", ""))
		var counterpart_id := String(item.get("counterpart_id", ""))
		var related: Array = item.get("related_member_ids", [])
		return member_id == _selected_member_id \
			or actor_id == _selected_member_id \
			or target_id == _selected_member_id \
			or counterpart_id == _selected_member_id \
			or _selected_member_id in related
	var text := String(item)
	var selected_member := _member_by_id(_selected_member_id)
	return not selected_member.is_empty() and text.contains(_member_name(selected_member))


func _update_history_mirror() -> void:
	if history_view == null:
		return
	history_view.clear()
	for entry in _filtered_entries():
		history_view.append_text("%s\n%s\n" % [
			_escape(String(entry.get("speaker_name", ""))),
			_escape(String(entry.get("content", "")))
		])
	var visible_events := _filtered_events()
	for index in range(visible_events.size()):
		history_view.append_text("%s\n%s\n" % [_event_title(index, visible_events[index]), _event_content(visible_events[index])])
	if footer_label != null:
		footer_label.text = "%d" % (_filtered_entries().size() + visible_events.size())


func _member_by_id(id: String) -> Dictionary:
	for member in _members:
		if String(member.get("id", "")) == id:
			return member
	return {}


func _first_non_player_member_id() -> String:
	for member in _members:
		var id := String(member.get("id", ""))
		if id != "player":
			return id
	return "player"


func _member_name(member: Dictionary) -> String:
	var name := String(member.get("name", member.get("public_name", "\u8bae\u5458")))
	if not bool(member.get("alive", true)):
		name += "\uff08\u5df2\u5904\u51b3\uff09"
	return name


func _event_title(index: int, item) -> String:
	if item is Dictionary:
		return String(item.get("title", "\u8bae\u4f1a\u4e8b\u4ef6 %02d" % [index + 1]))
	return "\u8bae\u4f1a\u4e8b\u4ef6 %02d" % [index + 1]


func _event_content(item) -> String:
	if item is Dictionary:
		return String(item.get("content", item.get("text", item.get("message", ""))))
	return String(item)


func _round_from_summary(summary: String) -> int:
	var regex := RegEx.new()
	if regex.compile("(?:\u56de\u5408\\s*(\\d+)|\u7b2c\\s*(\\d+)\\s*\u56de\u5408)") != OK:
		return 1
	var result := regex.search(summary)
	if result == null:
		return 1
	var legacy := result.get_string(1)
	if not legacy.is_empty():
		return int(legacy)
	return int(result.get_string(2))


func _portrait_bbcode_path(portrait_name: String) -> String:
	return _portrait_avatar_path(portrait_name)


func _portrait_avatar_path(portrait_name: String) -> String:
	if portrait_name.is_empty():
		portrait_name = "player_portrait.png"
	var head_name := portrait_name.replace("_portrait.png", "_head_avatar.png")
	var head_path := CHARACTER_HEADICON_ROOT + head_name
	if ResourceLoader.exists(head_path):
		return head_path
	return CHARACTER_PORTRAIT_ROOT + portrait_name


func _count_history_lines(text: String) -> int:
	var count := 0
	for line in text.split("\n", false):
		if not String(line).strip_edges().is_empty():
			count += 1
	return count


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
