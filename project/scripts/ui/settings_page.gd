extends "res://scripts/ui/gameplay_overlay_page.gd"
class_name SettingsPage

signal start_requested
signal reset_requested

var start_button: Button
var reset_button: Button
var close_text_button: Button
var auto_action_check: CheckBox
var auto_growth_check: CheckBox
var status_label: Label


func _init() -> void:
	page_title = "设置"
	background_path = "res://assets/ui/settings/settings_page_bg.png"
	panel_color = CommonFrameScript.DARK_PURPLE
	main_panel_rect = Rect2(154, 124, 972, 524)


func _build_page() -> void:
	var game_panel := _make_section_panel("GameControlPanel", CommonFrameScript.GRAY)
	game_panel.custom_minimum_size = Vector2(0, 138)
	game_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content_box.add_child(game_panel)
	var game_box := _make_section_content(game_panel)
	var game_row := HBoxContainer.new()
	game_row.name = "GameControlRow"
	game_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_row.add_theme_constant_override("separation", 14)
	game_box.add_child(game_row)
	var game_text := _make_label("游戏控制", 24, Color(1.0, 0.84, 0.38, 1.0), 2)
	game_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_row.add_child(game_text)
	start_button = _make_button("开始", true, Vector2(148, 52))
	start_button.name = "StartButton"
	start_button.pressed.connect(func(): start_requested.emit())
	game_row.add_child(start_button)
	reset_button = _make_button("重置", false, Vector2(148, 52))
	reset_button.name = "ResetButton"
	reset_button.pressed.connect(func(): reset_requested.emit())
	game_row.add_child(reset_button)

	var lower := HBoxContainer.new()
	lower.name = "SettingsLower"
	lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 18)
	content_box.add_child(lower)

	var auto_panel := _make_section_panel("AutoPanel", CommonFrameScript.GRAY)
	lower.add_child(auto_panel)
	var auto_box := _make_section_content(auto_panel)
	auto_box.add_child(_make_label("自动行为", 24, Color(1.0, 0.84, 0.38, 1.0), 2))
	auto_action_check = _make_check("自动行动")
	auto_action_check.name = "AutoActionCheck"
	auto_box.add_child(auto_action_check)
	auto_growth_check = _make_check("自动成长")
	auto_growth_check.name = "AutoGrowthCheck"
	auto_box.add_child(auto_growth_check)

	var ui_panel := _make_section_panel("InterfacePanel", CommonFrameScript.GRAY)
	lower.add_child(ui_panel)
	var ui_box := _make_section_content(ui_panel)
	ui_box.add_child(_make_label("界面 / 对话", 24, Color(1.0, 0.84, 0.38, 1.0), 2))
	var hint := _make_label("设置会即时生效。当前版本保留已有游戏控制和自动行为入口，不新增尚未接入的系统选项。", 18, Color(0.94, 0.90, 0.78, 1.0), 2)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_box.add_child(hint)
	status_label = _make_label("等待开始", 17, Color(1.0, 0.84, 0.38, 1.0), 2)
	status_label.name = "StatusLabel"
	ui_box.add_child(status_label)
	close_text_button = _make_button("关闭", false, Vector2(148, 46))
	close_text_button.name = "CloseTextButton"
	close_text_button.pressed.connect(func(): close_requested.emit())
	ui_box.add_child(close_text_button)


func _bind_page() -> void:
	start_button = get_node_or_null("MainPanel/ContentMargin/Content/GameControlPanel/MarginContainer/VBoxContainer/GameControlRow/StartButton") as Button
	reset_button = get_node_or_null("MainPanel/ContentMargin/Content/GameControlPanel/MarginContainer/VBoxContainer/GameControlRow/ResetButton") as Button
	auto_action_check = get_node_or_null("MainPanel/ContentMargin/Content/SettingsLower/AutoPanel/MarginContainer/VBoxContainer/AutoActionCheck") as CheckBox
	auto_growth_check = get_node_or_null("MainPanel/ContentMargin/Content/SettingsLower/AutoPanel/MarginContainer/VBoxContainer/AutoGrowthCheck") as CheckBox
	status_label = get_node_or_null("MainPanel/ContentMargin/Content/SettingsLower/InterfacePanel/MarginContainer/VBoxContainer/StatusLabel") as Label
	close_text_button = get_node_or_null("MainPanel/ContentMargin/Content/SettingsLower/InterfacePanel/MarginContainer/VBoxContainer/CloseTextButton") as Button
	if start_button != null and not start_button.pressed.is_connected(_emit_start_requested):
		start_button.pressed.connect(_emit_start_requested)
	if reset_button != null and not reset_button.pressed.is_connected(_emit_reset_requested):
		reset_button.pressed.connect(_emit_reset_requested)
	if close_text_button != null and not close_text_button.pressed.is_connected(_emit_close_requested):
		close_text_button.pressed.connect(_emit_close_requested)


func _emit_start_requested() -> void:
	start_requested.emit()


func _emit_reset_requested() -> void:
	reset_requested.emit()


func get_controls() -> Dictionary:
	return {
		"start_button": start_button,
		"reset_button": reset_button,
		"auto_decide_check": auto_action_check,
		"auto_action_check": auto_action_check,
		"auto_growth_check": auto_growth_check,
		"status_label": status_label
	}


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
