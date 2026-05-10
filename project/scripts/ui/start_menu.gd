extends Control
class_name StartMenu

signal start_requested
signal rules_requested
signal settings_requested
signal debug_screen_requested(screen_id: String)

const UI_ROOT := "res://assets/generated/ui/start_menu/"
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")
const BG_PATH := UI_ROOT + "start_game_reference.png"
const REFERENCE_SIZE := Vector2(1672.0, 941.0)
const START_BUTTON_RECT := Rect2(520.0, 585.0, 636.0, 169.0)
const RULES_BUTTON_RECT := Rect2(560.0, 766.0, 250.0, 72.0)
const SETTINGS_BUTTON_RECT := Rect2(860.0, 766.0, 250.0, 72.0)
const DEBUG_BUTTON_RECT := Rect2(1510.0, 838.0, 118.0, 42.0)
const DEBUG_PANEL_RECT := Rect2(1228.0, 392.0, 380.0, 430.0)
const DEBUG_SCREENS := [
	{"id": "round_select", "label": "对手选择"},
	{"id": "dialogue", "label": "对话主界面"},
	{"id": "shop", "label": "商店"},
	{"id": "ascension", "label": "升华 / 统治"},
	{"id": "intel", "label": "世界设定档案"},
	{"id": "inventory", "label": "背包"},
	{"id": "history", "label": "历史"},
	{"id": "rules", "label": "准则"},
	{"id": "status", "label": "状态"},
	{"id": "settings", "label": "设置"}
]

var start_button: Button
var button_visual: TextureRect
var rules_button: Button
var settings_button: Button
var debug_button: Button
var debug_panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	_build()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _process(_delta: float) -> void:
	_apply_responsive_layout()


func show_menu() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()


func hide_menu() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build() -> void:
	var background := TextureRect.new()
	background.name = "StartMenuBackground"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture = _texture_path(BG_PATH)
	add_child(background)

	button_visual = TextureRect.new()
	button_visual.name = "StartButtonVisual"
	button_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	button_visual.stretch_mode = TextureRect.STRETCH_SCALE
	button_visual.texture = _texture_path(UI_ROOT + "button_start_state_normal.png")
	add_child(button_visual)

	start_button = Button.new()
	start_button.name = "StartGameButton"
	start_button.text = ""
	start_button.tooltip_text = _utf8([229, 188, 128, 229, 167, 139, 230, 184, 184, 230, 136, 143])
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	start_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	start_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	start_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	start_button.mouse_entered.connect(func(): _set_button_state("hover"))
	start_button.mouse_exited.connect(func(): _set_button_state("normal"))
	start_button.button_down.connect(func(): _set_button_state("pressed"))
	start_button.button_up.connect(_on_start_button_up)
	start_button.pressed.connect(func(): start_requested.emit())
	add_child(start_button)

	rules_button = _make_menu_button("MenuRulesButton", "准则")
	rules_button.pressed.connect(func(): rules_requested.emit())
	add_child(rules_button)

	settings_button = _make_menu_button("MenuSettingsButton", "设置")
	settings_button.pressed.connect(func(): settings_requested.emit())
	add_child(settings_button)

	debug_button = Button.new()
	debug_button.name = "DebugScreenButton"
	debug_button.text = "调试"
	debug_button.tooltip_text = "打开界面调试列表"
	debug_button.focus_mode = Control.FOCUS_NONE
	debug_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	debug_button.add_theme_font_size_override("font_size", 16)
	debug_button.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
	debug_button.add_theme_color_override("font_hover_color", Color.WHITE)
	debug_button.add_theme_stylebox_override("normal", _debug_button_style(Color(0.08, 0.06, 0.055, 0.62), Color(0.86, 0.54, 0.18, 0.88)))
	debug_button.add_theme_stylebox_override("hover", _debug_button_style(Color(0.13, 0.09, 0.07, 0.82), Color(1.0, 0.73, 0.25, 1.0)))
	debug_button.add_theme_stylebox_override("pressed", _debug_button_style(Color(0.04, 0.03, 0.028, 0.92), Color(0.72, 0.32, 0.12, 1.0)))
	debug_button.pressed.connect(_toggle_debug_panel)
	add_child(debug_button)

	_build_debug_panel()


func _apply_responsive_layout() -> void:
	if start_button == null or button_visual == null:
		return
	var viewport_size := _get_layout_size()

	var scale := Vector2(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	start_button.position = START_BUTTON_RECT.position * scale
	start_button.size = START_BUTTON_RECT.size * scale
	button_visual.position = start_button.position
	button_visual.size = start_button.size
	if rules_button != null:
		rules_button.position = RULES_BUTTON_RECT.position * scale
		rules_button.size = RULES_BUTTON_RECT.size * scale
	if settings_button != null:
		settings_button.position = SETTINGS_BUTTON_RECT.position * scale
		settings_button.size = SETTINGS_BUTTON_RECT.size * scale
	if viewport_size.x < 520.0 and rules_button != null and settings_button != null:
		var button_width: float = min(viewport_size.x - 32.0, 260.0)
		var button_height: float = maxf(48.0, maxf(rules_button.get_combined_minimum_size().y, settings_button.get_combined_minimum_size().y))
		rules_button.position = Vector2((viewport_size.x - button_width) * 0.5, min(viewport_size.y - 126.0, start_button.position.y + start_button.size.y + 12.0))
		rules_button.size = Vector2(button_width, button_height)
		settings_button.position = Vector2(rules_button.position.x, rules_button.position.y + button_height + 8.0)
		settings_button.size = Vector2(button_width, button_height)
	if debug_button != null:
		debug_button.position = DEBUG_BUTTON_RECT.position * scale
		debug_button.size = DEBUG_BUTTON_RECT.size * scale
	if debug_panel != null:
		debug_panel.position = DEBUG_PANEL_RECT.position * scale
		debug_panel.size = DEBUG_PANEL_RECT.size * scale


func _get_layout_size() -> Vector2:
	var layout_size := size
	if layout_size.x > 0.0 and layout_size.y > 0.0:
		return layout_size

	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return parent_control.size

	return get_viewport_rect().size


func _on_start_button_up() -> void:
	if start_button.get_global_rect().has_point(get_global_mouse_position()):
		_set_button_state("hover")
	else:
		_set_button_state("normal")


func _set_button_state(state: String) -> void:
	if button_visual == null:
		return
	button_visual.texture = _texture_path(UI_ROOT + "button_start_state_%s.png" % state)


func _build_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugScreenPanel"
	debug_panel.visible = false
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_panel.add_theme_stylebox_override("panel", _debug_panel_style())
	add_child(debug_panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	debug_panel.add_child(list)

	var title := Label.new()
	title.text = "界面调试"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	list.add_child(title)

	for screen in DEBUG_SCREENS:
		var button := Button.new()
		button.text = String(screen.get("label", "界面"))
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.62, 1.0))
		button.add_theme_stylebox_override("normal", _debug_list_button_style(Color(0.14, 0.10, 0.08, 0.88)))
		button.add_theme_stylebox_override("hover", _debug_list_button_style(Color(0.30, 0.14, 0.09, 0.96)))
		button.add_theme_stylebox_override("pressed", _debug_list_button_style(Color(0.08, 0.05, 0.04, 1.0)))
		button.pressed.connect(func(id := String(screen.get("id", ""))):
			debug_panel.visible = false
			debug_screen_requested.emit(id)
		)
		list.add_child(button)


func _make_menu_button(node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	StandardButtonScript.apply(button, StandardButtonScript.SECONDARY, label, 24)
	return button


func _toggle_debug_panel() -> void:
	if debug_panel != null:
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			debug_panel.move_to_front()
			debug_button.move_to_front()


func _debug_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _debug_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.035, 0.032, 0.94)
	style.border_color = Color(0.92, 0.54, 0.16, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	return style


func _debug_list_button_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.94, 0.58, 0.20, 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _texture_path(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _utf8(bytes: Array) -> String:
	return PackedByteArray(bytes).get_string_from_utf8()
