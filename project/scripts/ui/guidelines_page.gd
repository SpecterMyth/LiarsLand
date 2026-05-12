extends Control
class_name GuidelinesPage

signal close_requested
signal save_requested
signal reset_requested(tab_id: String)
signal merge_requested(tab_id: String, base_text: String, append_text: String)

const COMMON_UI_ROOT := "res://assets/ui/common/"
const DIALOGUE_UI_ROOT := "res://assets/generated/ui/dialogue/"
const GUIDELINES_UI_ROOT := "res://assets/ui/guidelines/"
const FONT_PATH := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")
const CommonFrameScript := preload("res://scripts/ui/common_frame.gd")
const CommonBackgroundPanelScene := preload("res://scenes/ui/common_background_panel.tscn")
const ACTION_BUTTON_SIZE := Vector2(144, 40)
const ACTION_BUTTON_SIZE_NARROW := Vector2(126, 36)
const APPEND_EDIT_HEIGHT := 46
const APPEND_EDIT_HEIGHT_NARROW := 40
const TAB_BUTTON_SIZE := Vector2(346, 64)
const MAIN_PANEL_OFFSET_Y := 40.0
const VISIBLE_TABS := ["identity", "behavior"]

var current_tab := "identity"
var guideline_texts := {
	"identity": "",
	"behavior": "",
	"growth": ""
}
var tab_buttons: Dictionary = {}
var tab_icons: Dictionary = {}

var close_button: TextureButton
var identity_tab: Button
var behavior_tab: Button
var growth_tab: Button
var guideline_edit: TextEdit
var append_edit: TextEdit
var merge_button: Button
var save_button: Button
var reset_button: Button
var close_text_button: Button
var auto_action_check: CheckBox
var auto_growth_check: CheckBox
var status_label: Label
var decision_panel: PanelContainer
var decision_title: Label
var decision_body: Label
var decision_countdown: Label
var decision_progress: ProgressBar
var decision_cancel_button: Button
var built := false
var uses_scene_nodes := false
var main_panel: Control
var guideline_edit_shell: Control
var tabs_grid: GridContainer
var footer_bar: Container


func _ready() -> void:
	name = "GuidelinesPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1000
	_ensure_built()
	_select_tab("identity")


func get_controls() -> Dictionary:
	_ensure_built()
	return {
		"rules_edit": guideline_edit,
		"identity_edit": guideline_edit,
		"behavior_edit": guideline_edit,
		"growth_edit": guideline_edit,
		"auto_decide_check": auto_action_check,
		"auto_action_check": auto_action_check,
		"auto_growth_check": auto_growth_check,
		"close_button": close_button,
		"identity_tab": identity_tab,
		"behavior_tab": behavior_tab,
		"growth_tab": growth_tab,
		"append_edit": append_edit,
		"merge_button": merge_button,
		"save_button": save_button,
		"reset_button": reset_button,
		"close_text_button": close_text_button,
		"decision_panel": decision_panel,
		"decision_title": decision_title,
		"decision_body": decision_body,
		"decision_countdown": decision_countdown,
		"decision_progress": decision_progress,
		"decision_cancel_button": decision_cancel_button
	}


func set_guidelines(identity: String, behavior: String, growth: String) -> void:
	_ensure_built()
	guideline_texts["identity"] = identity
	guideline_texts["behavior"] = behavior
	guideline_texts["growth"] = growth
	if guideline_edit != null:
		guideline_edit.text = String(guideline_texts.get(current_tab, ""))


func get_guidelines() -> Dictionary:
	_store_current_tab_text()
	return guideline_texts.duplicate()


func set_status(text: String) -> void:
	_ensure_built()
	if status_label != null:
		status_label.text = text


func set_locked(locked: bool) -> void:
	_ensure_built()
	if guideline_edit != null:
		guideline_edit.editable = not locked
		guideline_edit.modulate = Color(0.55, 0.55, 0.55, 1.0) if locked else Color.WHITE
	if append_edit != null:
		append_edit.editable = not locked
		append_edit.modulate = Color(0.55, 0.55, 0.55, 1.0) if locked else Color.WHITE
	for button in [merge_button, save_button, reset_button]:
		if button != null:
			button.disabled = locked
	if merge_button != null:
		merge_button.text = "融合准则"


func set_merging(merging: bool) -> void:
	_ensure_built()
	if guideline_edit != null:
		guideline_edit.editable = not merging
		guideline_edit.modulate = Color(0.48, 0.48, 0.48, 1.0) if merging else Color.WHITE
	if append_edit != null:
		append_edit.editable = not merging
		append_edit.modulate = Color(0.48, 0.48, 0.48, 1.0) if merging else Color.WHITE
	if merge_button != null:
		merge_button.disabled = merging
		merge_button.text = "融合中" if merging else "融合准则"


func replace_current_text(text: String) -> void:
	_ensure_built()
	guideline_texts[current_tab] = text
	if guideline_edit != null:
		guideline_edit.text = text


func get_current_tab() -> String:
	return current_tab


func _ensure_built() -> void:
	if built:
		return
	built = true
	if get_node_or_null("MainPanel") != null:
		uses_scene_nodes = true
		_bind_scene_nodes()
		_style_scene_nodes()
		_apply_responsive_layout()
		return
	_build()
	_apply_responsive_layout()


func _bind_scene_nodes() -> void:
	main_panel = get_node_or_null("MainPanel") as Control
	tabs_grid = get_node_or_null("MainPanel/Content/TabRow") as GridContainer
	footer_bar = get_node_or_null("MainPanel/Content/Footer") as Container
	close_button = get_node_or_null("CloseButton") as TextureButton
	identity_tab = get_node_or_null("MainPanel/Content/TabRow/IdentityTab") as Button
	behavior_tab = get_node_or_null("MainPanel/Content/TabRow/BehaviorTab") as Button
	growth_tab = get_node_or_null("MainPanel/Content/TabRow/GrowthTab") as Button
	guideline_edit_shell = get_node_or_null("MainPanel/Content/GuidelineEditShell") as Control
	guideline_edit = get_node_or_null("MainPanel/Content/GuidelineEditShell/GuidelineEdit") as TextEdit
	if guideline_edit == null:
		guideline_edit = get_node_or_null("MainPanel/Content/GuidelineEdit") as TextEdit
	append_edit = get_node_or_null("MainPanel/Content/AppendRow/AppendEdit") as TextEdit
	status_label = get_node_or_null("MainPanel/Content/Footer/StatusLabel") as Label
	auto_action_check = get_node_or_null("MainPanel/Content/Footer/AutoActionCheck") as CheckBox
	auto_growth_check = get_node_or_null("MainPanel/Content/Footer/AutoGrowthCheck") as CheckBox
	if auto_growth_check != null:
		auto_growth_check.visible = false
		auto_growth_check.disabled = true
	merge_button = get_node_or_null("MainPanel/Content/AppendRow/MergeButton") as Button
	reset_button = get_node_or_null("MainPanel/Content/Footer/ResetButton") as Button
	close_text_button = get_node_or_null("MainPanel/Content/Footer/CloseTextButton") as Button
	save_button = get_node_or_null("MainPanel/Content/Footer/SaveButton") as Button
	decision_panel = get_node_or_null("DecisionPanel") as PanelContainer
	decision_title = get_node_or_null("DecisionPanel/DecisionContent/DecisionTitle") as Label
	decision_body = get_node_or_null("DecisionPanel/DecisionContent/DecisionBody") as Label
	decision_countdown = get_node_or_null("DecisionPanel/DecisionContent/DecisionCountdown") as Label
	decision_progress = get_node_or_null("DecisionPanel/DecisionContent/DecisionProgress") as ProgressBar
	decision_cancel_button = get_node_or_null("DecisionPanel/DecisionContent/DecisionCancelButton") as Button

	tab_buttons.clear()
	if identity_tab != null:
		tab_buttons["identity"] = identity_tab
		_connect_once(identity_tab, "pressed", func(): _select_tab("identity"))
	if behavior_tab != null:
		tab_buttons["behavior"] = behavior_tab
		_connect_once(behavior_tab, "pressed", func(): _select_tab("behavior"))
	if growth_tab != null:
		growth_tab.visible = false
		growth_tab.disabled = true
	if close_button != null:
		_connect_once(close_button, "pressed", func(): close_requested.emit())
	if guideline_edit != null:
		_connect_once(guideline_edit, "text_changed", func(): guideline_texts[current_tab] = guideline_edit.text)
	if merge_button != null:
		_connect_once(merge_button, "pressed", _on_merge_pressed)
	if reset_button != null:
		_connect_once(reset_button, "pressed", func(): reset_requested.emit(current_tab))
	if close_text_button != null:
		_connect_once(close_text_button, "pressed", func(): close_requested.emit())
	if save_button != null:
		_connect_once(save_button, "pressed", func():
			_store_current_tab_text()
			save_requested.emit()
		)


func _style_scene_nodes() -> void:
	var background := get_node_or_null("Background") as TextureRect
	if background != null:
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var scratches := get_node_or_null("TextureScratches") as TextureRect
	if scratches != null:
		scratches.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scratches.stretch_mode = TextureRect.STRETCH_SCALE
	var title_banner := get_node_or_null("TitleBanner") as TextureRect
	if title_banner != null:
		title_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var title := get_node_or_null("TitleLabel") as Label
	if title != null:
		_style_label(title, 35, Color(0.964706, 0.913725, 0.796078, 1.0), 3)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if close_button != null:
		close_button.texture_normal = _load_texture(COMMON_UI_ROOT + "bag_close_normal.png")
		close_button.texture_hover = _load_texture(COMMON_UI_ROOT + "bag_close_hover.png")
		close_button.texture_pressed = _load_texture(COMMON_UI_ROOT + "bag_close_pressed.png")
		close_button.ignore_texture_size = true
		close_button.stretch_mode = TextureButton.STRETCH_SCALE
	if main_panel != null:
		if main_panel is PanelContainer:
			(main_panel as PanelContainer).add_theme_stylebox_override("panel", _transparent_style())
		_ensure_sibling_background(main_panel, "MainPanelBack", CommonFrameScript.DARK_TEAL, 50.0)
	if guideline_edit != null:
		_ensure_common_background(guideline_edit, "GuidelineEditBack", CommonFrameScript.GRAY)
	if identity_tab != null:
		_style_tab_button(identity_tab, Color(0.18, 0.52, 0.52, 1.0))
	if behavior_tab != null:
		_style_tab_button(behavior_tab, Color(0.48, 0.10, 0.18, 1.0))
	if growth_tab != null:
		growth_tab.visible = false
		growth_tab.disabled = true
	if status_label != null:
		_style_label(status_label, 17, Color(1.0, 0.85, 0.50, 1.0), 2)
	if guideline_edit != null:
		guideline_edit.add_theme_font_size_override("font_size", 17)
		guideline_edit.add_theme_color_override("font_color", Color(0.035, 0.030, 0.030, 1.0))
		guideline_edit.add_theme_color_override("font_placeholder_color", Color(0.28, 0.25, 0.22, 1.0))
		_apply_transparent_text_edit_style(guideline_edit)
	if append_edit != null:
		append_edit.add_theme_font_size_override("font_size", 16)
		append_edit.add_theme_color_override("font_color", Color(0.94, 0.98, 0.92, 1.0))
		append_edit.add_theme_color_override("font_placeholder_color", Color(0.52, 0.68, 0.64, 1.0))
		append_edit.add_theme_stylebox_override("normal", _panel_style(Color(0.018, 0.030, 0.030, 0.98), Color(0.12, 0.72, 0.72, 0.58), 2))
	for check in [auto_action_check]:
		if check != null:
			_style_check(check)
	if auto_growth_check != null:
		auto_growth_check.visible = false
		auto_growth_check.disabled = true
	if merge_button != null:
		_style_primary_button(merge_button)
	if reset_button != null:
		_style_secondary_button(reset_button)
	if close_text_button != null:
		_style_secondary_button(close_text_button)
	if save_button != null:
		_style_primary_button(save_button)
	if decision_panel != null:
		decision_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.028, 0.022, 0.030, 0.985), Color(1.0, 0.65, 0.20, 0.95), 3))
	if decision_title != null:
		_style_label(decision_title, 28, Color(1.0, 0.84, 0.38, 1.0), 2)
	if decision_body != null:
		_style_label(decision_body, 18, Color(0.94, 0.98, 0.90, 1.0), 2)
	if decision_countdown != null:
		_style_label(decision_countdown, 20, Color(1.0, 0.88, 0.52, 1.0), 2)
	if decision_cancel_button != null:
		_style_secondary_button(decision_cancel_button)


func _connect_once(object: Object, signal_name: StringName, callable: Callable) -> void:
	var meta_name := "_guidelines_connected_%s" % signal_name
	if object.has_meta(meta_name):
		return
	object.connect(signal_name, callable)
	object.set_meta(meta_name, true)


func _build() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _load_texture(COMMON_UI_ROOT + "bg_round_start_city.png")
	add_child(bg)

	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.010, 0.012, 0.78)
	add_child(veil)

	var scratches := TextureRect.new()
	scratches.name = "TextureScratches"
	scratches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scratches.set_anchors_preset(Control.PRESET_FULL_RECT)
	scratches.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scratches.stretch_mode = TextureRect.STRETCH_SCALE
	scratches.modulate = Color(1, 1, 1, 0.18)
	scratches.texture = _load_texture(COMMON_UI_ROOT + "shop_texture_scratches_dark.png")
	add_child(scratches)

	var title_banner := TextureRect.new()
	title_banner.name = "TitleBanner"
	_place_absolute(title_banner, Rect2(-23.0, 17.333, 419.667, 90.0))
	title_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_banner.texture = _load_texture(COMMON_UI_ROOT + "title_banner_red.png")
	add_child(title_banner)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "准则"
	_place_absolute(title, Rect2(36.0, 26.0, 200.0, 54.666))
	_style_label(title, 35, Color(0.964706, 0.913725, 0.796078, 1.0), 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	close_button = TextureButton.new()
	close_button.name = "CloseButton"
	_place_absolute(close_button, Rect2(1192.0, 28.0, 57.333, 57.333))
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.texture_normal = _load_texture(COMMON_UI_ROOT + "bag_close_normal.png")
	close_button.texture_hover = _load_texture(COMMON_UI_ROOT + "bag_close_hover.png")
	close_button.texture_pressed = _load_texture(COMMON_UI_ROOT + "bag_close_pressed.png")
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_SCALE
	close_button.tooltip_text = "关闭"
	close_button.pressed.connect(func(): close_requested.emit())
	add_child(close_button)

	main_panel = Control.new()
	main_panel.name = "MainPanel"
	_place(main_panel, Rect2(0.070, 0.165, 0.855, 0.750))
	_apply_main_panel_offset()
	add_child(main_panel)
	_ensure_sibling_background(main_panel, "MainPanelBack", CommonFrameScript.DARK_TEAL, 50.0)

	var root := VBoxContainer.new()
	root.name = "Content"
	root.add_theme_constant_override("separation", 8)
	_place_inset(root, 42, 44, 42, 38)
	main_panel.add_child(root)

	tabs_grid = GridContainer.new()
	tabs_grid.name = "TabRow"
	tabs_grid.columns = 2
	tabs_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tabs_grid.add_theme_constant_override("h_separation", 10)
	tabs_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(tabs_grid)
	identity_tab = _make_tab_button("IdentityTab", "对外身份", "identity", Color(0.18, 0.52, 0.52, 1.0))
	behavior_tab = _make_tab_button("BehaviorTab", "行动准则", "behavior", Color(0.48, 0.10, 0.18, 1.0))
	tabs_grid.add_child(identity_tab)
	tabs_grid.add_child(behavior_tab)

	var mode_row := HBoxContainer.new()
	mode_row.name = "ModeRow"
	mode_row.add_theme_constant_override("separation", 10)
	root.add_child(mode_row)
	var direct_chip := _make_chip("直接编辑", Color(0.47, 0.08, 0.10, 1.0))
	mode_row.add_child(direct_chip)
	var append_chip := _make_chip("追加规则", Color(0.00, 0.36, 0.38, 1.0))
	mode_row.add_child(append_chip)
	status_label = _make_small_label("未保存", 17, Color(1.0, 0.85, 0.50, 1.0))
	status_label.name = "StatusLabel"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_row.add_child(status_label)

	guideline_edit = TextEdit.new()
	guideline_edit.name = "GuidelineEdit"
	guideline_edit.custom_minimum_size = Vector2(0, 250)
	guideline_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guideline_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	guideline_edit.placeholder_text = "编辑当前准则..."
	guideline_edit.add_theme_font_size_override("font_size", 17)
	guideline_edit.add_theme_color_override("font_color", Color(0.035, 0.030, 0.030, 1.0))
	guideline_edit.add_theme_color_override("font_placeholder_color", Color(0.28, 0.25, 0.22, 1.0))
	_apply_transparent_text_edit_style(guideline_edit)
	_ensure_common_background(guideline_edit, "GuidelineEditBack", CommonFrameScript.GRAY)
	guideline_edit.text_changed.connect(func(): guideline_texts[current_tab] = guideline_edit.text)
	root.add_child(guideline_edit)

	append_edit = TextEdit.new()
	append_edit.name = "AppendEdit"
	append_edit.custom_minimum_size = Vector2(0, 64)
	append_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	append_edit.placeholder_text = "输入要追加的新规则..."
	append_edit.add_theme_font_size_override("font_size", 16)
	append_edit.add_theme_color_override("font_color", Color(0.94, 0.98, 0.92, 1.0))
	append_edit.add_theme_color_override("font_placeholder_color", Color(0.52, 0.68, 0.64, 1.0))
	append_edit.add_theme_stylebox_override("normal", _panel_style(Color(0.018, 0.030, 0.030, 0.98), Color(0.12, 0.72, 0.72, 0.58), 2))
	root.add_child(append_edit)

	var append_row := HBoxContainer.new()
	append_row.name = "AppendRow"
	append_row.add_theme_constant_override("separation", 10)
	root.add_child(append_row)
	append_row.add_child(append_edit)
	merge_button = _make_secondary_button("MergeButton", "融合准则")
	_style_primary_button(merge_button)
	merge_button.custom_minimum_size = Vector2(124, 64)
	merge_button.pressed.connect(_on_merge_pressed)
	append_row.add_child(merge_button)

	footer_bar = HBoxContainer.new()
	footer_bar.name = "Footer"
	footer_bar.add_theme_constant_override("separation", 10)
	root.add_child(footer_bar)
	auto_action_check = _make_check("AutoActionCheck", "自己行动")
	auto_growth_check = _make_check("AutoGrowthCheck", "自己成长")
	auto_growth_check.visible = false
	auto_growth_check.disabled = true
	footer_bar.add_child(auto_action_check)
	footer_bar.add_child(auto_growth_check)
	status_label = _make_small_label("正在编辑：对外身份", 17, Color(1.0, 0.85, 0.50, 1.0))
	status_label.name = "StatusLabel"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_bar.add_child(status_label)
	reset_button = _make_secondary_button("ResetButton", "重置当前")
	reset_button.pressed.connect(func(): reset_requested.emit(current_tab))
	footer_bar.add_child(reset_button)
	save_button = _make_primary_button("SaveButton", "保存")
	save_button.pressed.connect(func():
		_store_current_tab_text()
		save_requested.emit()
	)
	footer_bar.add_child(save_button)

	_build_decision_panel()
	_apply_responsive_layout()


func _build_decision_panel() -> void:
	decision_panel = PanelContainer.new()
	decision_panel.name = "DecisionPanel"
	decision_panel.visible = false
	decision_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	decision_panel.z_index = 100
	_place(decision_panel, Rect2(0.225, 0.245, 0.550, 0.430))
	decision_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.028, 0.022, 0.030, 0.985), Color(1.0, 0.65, 0.20, 0.95), 3))
	add_child(decision_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	decision_panel.add_child(box)
	decision_title = _make_small_label("角色决策", 28, Color(1.0, 0.84, 0.38, 1.0))
	decision_title.name = "DecisionTitle"
	decision_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(decision_title)
	decision_body = _make_small_label("", 18, Color(0.94, 0.98, 0.90, 1.0))
	decision_body.name = "DecisionBody"
	decision_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decision_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(decision_body)
	decision_countdown = _make_small_label("5 秒后执行", 20, Color(1.0, 0.88, 0.52, 1.0))
	decision_countdown.name = "DecisionCountdown"
	decision_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(decision_countdown)
	decision_progress = ProgressBar.new()
	decision_progress.name = "DecisionProgress"
	decision_progress.min_value = 0
	decision_progress.max_value = 5
	decision_progress.value = 5
	decision_progress.show_percentage = false
	decision_progress.custom_minimum_size = Vector2(0, 22)
	box.add_child(decision_progress)
	decision_cancel_button = _make_secondary_button("DecisionCancelButton", "取消")
	decision_cancel_button.custom_minimum_size = Vector2(180, 44)
	box.add_child(decision_cancel_button)


func _make_tab_button(node_name: String, label: String, tab_id: String, tone: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = TAB_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_tab_button(button, tone)
	button.pressed.connect(func(): _select_tab(tab_id))
	tab_buttons[tab_id] = button
	return button


func _style_tab_button(button: Button, tone: Color) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.62, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55, 1.0))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	var tab_style := _tab_texture_style(button.name)
	if tab_style != null:
		button.add_theme_stylebox_override("normal", tab_style)
		button.add_theme_stylebox_override("hover", tab_style.duplicate())
		button.add_theme_stylebox_override("pressed", tab_style.duplicate())
		button.add_theme_stylebox_override("disabled", tab_style.duplicate())


func _make_chip(text: String, tone: Color) -> Label:
	var label := _make_small_label(text, 17, Color.WHITE)
	label.custom_minimum_size = Vector2(120, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _panel_style(tone.darkened(0.18), tone.lightened(0.20), 1))
	return label


func _make_check(node_name: String, text: String) -> CheckBox:
	var check := CheckBox.new()
	check.name = node_name
	check.text = text
	_style_check(check)
	return check


func _style_check(check: CheckBox) -> void:
	check.focus_mode = Control.FOCUS_NONE
	check.custom_minimum_size = Vector2(130, 44)
	check.add_theme_font_size_override("font_size", 18)
	check.add_theme_color_override("font_color", Color(1.0, 0.84, 0.44, 1.0))
	var unchecked := _load_texture(DIALOGUE_UI_ROOT + "checkbox_unchecked.png")
	var checked := _load_texture(DIALOGUE_UI_ROOT + "checkbox_checked.png")
	if unchecked != null:
		check.add_theme_icon_override("unchecked", unchecked)
		check.add_theme_icon_override("unchecked_disabled", unchecked)
	if checked != null:
		check.add_theme_icon_override("checked", checked)
		check.add_theme_icon_override("checked_disabled", checked)


func _make_primary_button(node_name: String, text: String) -> Button:
	var button := _make_textured_button(node_name, text, Color(0.08, 0.035, 0.0, 1.0))
	_style_primary_button(button)
	return button


func _make_secondary_button(node_name: String, text: String) -> Button:
	var button := _make_textured_button(node_name, text, Color.WHITE)
	_style_secondary_button(button)
	return button


func _style_primary_button(button: Button) -> void:
	_style_textured_button(button, Color(0.08, 0.035, 0.0, 1.0))
	StandardButtonScript.apply(button, StandardButtonScript.PRIMARY, button.text, 18)
	_style_guidelines_action_button(button)


func _style_secondary_button(button: Button) -> void:
	_style_textured_button(button, Color.WHITE)
	StandardButtonScript.apply(button, StandardButtonScript.SECONDARY, button.text, 18)
	_style_guidelines_action_button(button)


func _make_textured_button(node_name: String, text: String, color: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	_style_textured_button(button, color)
	return button


func _style_textured_button(button: Button, color: Color) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", color)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))


func _ensure_common_background(parent: Control, node_name: String, color: String, bleed := 0.0) -> NinePatchRect:
	var panel := parent.get_node_or_null(node_name) as NinePatchRect
	if panel == null:
		panel = CommonBackgroundPanelScene.instantiate() as NinePatchRect
		panel.name = node_name
		parent.add_child(panel)
		parent.move_child(panel, 0)
	_place_inset(panel, -bleed, -bleed, -bleed, -bleed)
	panel.custom_minimum_size = Vector2.ZERO
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = parent is TextEdit
	panel.frame_color = color
	panel.apply_default_size = false
	CommonFrameScript.apply_background_panel(panel, color, Vector2.ZERO)
	return panel


func _ensure_sibling_background(target: Control, node_name: String, color: String, bleed := 0.0) -> NinePatchRect:
	var parent := target.get_parent() as Control
	if parent == null:
		return _ensure_common_background(target, node_name, color, bleed)
	var panel := parent.get_node_or_null(node_name) as NinePatchRect
	if panel == null:
		panel = CommonBackgroundPanelScene.instantiate() as NinePatchRect
		panel.name = node_name
		parent.add_child(panel)
		parent.move_child(panel, target.get_index())
	panel.anchor_left = target.anchor_left
	panel.anchor_top = target.anchor_top
	panel.anchor_right = target.anchor_right
	panel.anchor_bottom = target.anchor_bottom
	panel.offset_left = target.offset_left - bleed
	panel.offset_top = target.offset_top - bleed
	panel.offset_right = target.offset_right + bleed
	panel.offset_bottom = target.offset_bottom + bleed
	panel.custom_minimum_size = Vector2.ZERO
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = false
	panel.frame_color = color
	panel.apply_default_size = false
	CommonFrameScript.apply_background_panel(panel, color, Vector2.ZERO)
	return panel


func _ensure_guideline_edit_shell(edit: TextEdit) -> Control:
	if guideline_edit_shell != null:
		_place_inset(edit, 30, 24, 30, 24)
		return guideline_edit_shell
	var parent := edit.get_parent() as Control
	if parent == null:
		return edit
	var index := edit.get_index()
	guideline_edit_shell = Control.new()
	guideline_edit_shell.name = "GuidelineEditShell"
	guideline_edit_shell.custom_minimum_size = edit.custom_minimum_size
	guideline_edit_shell.size_flags_horizontal = edit.size_flags_horizontal
	guideline_edit_shell.size_flags_vertical = edit.size_flags_vertical
	parent.add_child(guideline_edit_shell)
	parent.move_child(guideline_edit_shell, index)
	edit.reparent(guideline_edit_shell)
	_place_inset(edit, 30, 24, 30, 24)
	return guideline_edit_shell


func _apply_transparent_text_edit_style(edit: TextEdit) -> void:
	var style := _transparent_style(50.0)
	edit.add_theme_stylebox_override("normal", style)
	edit.add_theme_stylebox_override("focus", style.duplicate())
	edit.add_theme_stylebox_override("read_only", style.duplicate())


func _style_guidelines_action_button(button: Button) -> void:
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.48, 0.48, 1.0))
	button.add_theme_stylebox_override("disabled", _texture_style("button_secondary_blank_normal.png", 24))


func _on_merge_pressed() -> void:
	_store_current_tab_text()
	merge_requested.emit(current_tab, String(guideline_texts.get(current_tab, "")), append_edit.text)


func _select_tab(tab_id: String) -> void:
	if not VISIBLE_TABS.has(tab_id):
		tab_id = "behavior"
	if tab_id == current_tab and guideline_edit != null:
		return
	_store_current_tab_text()
	current_tab = tab_id
	if guideline_edit != null:
		guideline_edit.text = String(guideline_texts.get(current_tab, ""))
	if append_edit != null:
		append_edit.text = ""
	for key in tab_buttons.keys():
		var button := tab_buttons[key] as Button
		if button == null:
			continue
		var selected := String(key) == current_tab
		button.modulate = Color(1.0, 0.92, 0.58, 1.0) if selected else Color.WHITE
		button.button_pressed = selected
	if status_label != null:
		status_label.text = _tab_title(current_tab)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if not built:
		return
	var viewport_width := get_viewport_rect().size.x
	var narrow := viewport_width > 0.0 and viewport_width < 620.0
	if main_panel != null and not uses_scene_nodes:
		_place(main_panel, Rect2(0.070, 0.165, 0.855, 0.750) if not narrow else Rect2(0.070, 0.165, 0.860, 0.750))
	if main_panel != null:
		_apply_main_panel_offset()
		_ensure_sibling_background(main_panel, "MainPanelBack", CommonFrameScript.DARK_TEAL, 50.0)
	if tabs_grid != null:
		tabs_grid.columns = 2 if not narrow else 1
		tabs_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for button in [identity_tab, behavior_tab]:
		if button != null:
			button.custom_minimum_size = TAB_BUTTON_SIZE
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.add_theme_font_size_override("font_size", 21 if not narrow else 18)
	if status_label != null:
		status_label.visible = not narrow
	if guideline_edit != null:
		if guideline_edit_shell != null:
			guideline_edit_shell.custom_minimum_size = Vector2(0, 250 if not narrow else 230)
		else:
			guideline_edit.custom_minimum_size = Vector2(0, 250 if not narrow else 230)
		guideline_edit.add_theme_font_size_override("font_size", 17 if not narrow else 15)
	if append_edit != null:
		append_edit.custom_minimum_size = Vector2(0, APPEND_EDIT_HEIGHT if not narrow else APPEND_EDIT_HEIGHT_NARROW)
		append_edit.add_theme_font_size_override("font_size", 16 if not narrow else 14)
	if footer_bar is GridContainer:
		(footer_bar as GridContainer).columns = 4 if not narrow else 2
	for check in [auto_action_check]:
		if check != null:
			check.custom_minimum_size = Vector2(130 if not narrow else 116, 44 if not narrow else 36)
			check.add_theme_font_size_override("font_size", 18 if not narrow else 15)
	if auto_growth_check != null:
		auto_growth_check.visible = false
		auto_growth_check.disabled = true
	if merge_button != null:
		merge_button.custom_minimum_size = ACTION_BUTTON_SIZE if not narrow else ACTION_BUTTON_SIZE_NARROW
		merge_button.add_theme_font_size_override("font_size", 18 if not narrow else 15)
	for button in [reset_button, close_text_button, save_button]:
		if button != null:
			button.custom_minimum_size = ACTION_BUTTON_SIZE if not narrow else ACTION_BUTTON_SIZE_NARROW
			button.add_theme_font_size_override("font_size", 18 if not narrow else 15)


func _store_current_tab_text() -> void:
	if guideline_edit != null:
		guideline_texts[current_tab] = guideline_edit.text


func _tab_title(tab_id: String) -> String:
	match tab_id:
		"identity":
			return "正在编辑：对外身份"
		"behavior":
			return "正在编辑：行动准则"
		_:
			return "正在编辑：准则"


func _style_label(label: Label, font_size: int, color: Color, outline: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	var font := _load_font()
	if font != null:
		label.add_theme_font_override("font", font)


func _make_small_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	_style_label(label, font_size, color, 2)
	return label


func _panel_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _transparent_style(content_margin := 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


func _texture_style(asset: String, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _load_texture(COMMON_UI_ROOT + asset)
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = max(8, margin / 2)
	style.content_margin_bottom = max(8, margin / 2)
	return style


func _tab_texture_style(node_name: String) -> StyleBoxTexture:
	var asset := ""
	match node_name:
		"IdentityTab":
			asset = GUIDELINES_UI_ROOT + "guideline_tab_identity.png"
		"BehaviorTab":
			asset = GUIDELINES_UI_ROOT + "guideline_tab_behavior.png"
		"GrowthTab":
			asset = GUIDELINES_UI_ROOT + "guideline_tab_growth.png"
		_:
			return null
	if not ResourceLoader.exists(asset):
		return null
	var style := StyleBoxTexture.new()
	style.texture = load(asset)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 64
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _place(node: Control, rect: Rect2) -> void:
	node.anchor_left = rect.position.x
	node.anchor_top = rect.position.y
	node.anchor_right = rect.position.x + rect.size.x
	node.anchor_bottom = rect.position.y + rect.size.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0


func _apply_main_panel_offset() -> void:
	if main_panel == null:
		return
	main_panel.offset_top = MAIN_PANEL_OFFSET_Y
	main_panel.offset_bottom = MAIN_PANEL_OFFSET_Y


func _place_absolute(node: Control, rect: Rect2) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.position.x + rect.size.x
	node.offset_bottom = rect.position.y + rect.size.y


func _place_inset(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = left
	node.offset_top = top
	node.offset_right = -right
	node.offset_bottom = -bottom


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH)
	return null
