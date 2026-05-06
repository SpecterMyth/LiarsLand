extends Control
class_name StartMenu

signal start_requested
signal rules_requested
signal settings_requested

const UI_ROOT := "res://assets/generated/ui/start_menu/"
const BG_PATH := "res://assets/generated/bg_moon_market.png"

var start_button: Button
var rules_button: Button
var settings_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	_build()
	resized.connect(_fit_layout)
	_fit_layout()


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
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = _texture_path(BG_PATH)
	add_child(background)

	var darken := ColorRect.new()
	darken.name = "StartMenuDarken"
	darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darken.set_anchors_preset(Control.PRESET_FULL_RECT)
	darken.color = Color(0.02, 0.01, 0.015, 0.38)
	add_child(darken)

	var vignette := TextureRect.new()
	vignette.name = "StartMenuVignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.texture = _texture("menu_panel_vignette.png")
	add_child(vignette)

	var logo := TextureRect.new()
	logo.name = "LogoLiarsLand"
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.anchor_left = 0.18
	logo.anchor_top = 0.12
	logo.anchor_right = 0.82
	logo.anchor_bottom = 0.36
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = _texture("logo_liars_land.png")
	add_child(logo)

	var subtitle := Label.new()
	subtitle.name = "StartMenuSubtitle"
	subtitle.text = "在月市的灯下，选择第一句真话"
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.anchor_left = 0.24
	subtitle.anchor_top = 0.335
	subtitle.anchor_right = 0.76
	subtitle.anchor_bottom = 0.395
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_constant_override("outline_size", 4)
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.76, 0.54, 1.0))
	subtitle.add_theme_color_override("font_outline_color", Color(0.04, 0.015, 0.015, 1.0))
	add_child(subtitle)

	start_button = _make_button("开始游戏", true)
	start_button.name = "StartGameButton"
	start_button.pressed.connect(func(): start_requested.emit())
	add_child(start_button)

	rules_button = _make_button("行为准则", false)
	rules_button.name = "MenuRulesButton"
	rules_button.pressed.connect(func(): rules_requested.emit())
	add_child(rules_button)

	settings_button = _make_button("系统设置", false)
	settings_button.name = "MenuSettingsButton"
	settings_button.pressed.connect(func(): settings_requested.emit())
	add_child(settings_button)

	var hint := Label.new()
	hint.name = "StartMenuHint"
	hint.text = "主菜单概念 v1：最大按钮进入游戏，小按钮承载规则与设置"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.anchor_left = 0.20
	hint.anchor_top = 0.88
	hint.anchor_right = 0.80
	hint.anchor_bottom = 0.93
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.76, 0.66, 0.47, 1.0))
	add_child(hint)

	var border := TextureRect.new()
	border.name = "StartMenuBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.texture = _texture("menu_border.png")
	add_child(border)


func _fit_layout() -> void:
	if start_button == null or rules_button == null or settings_button == null:
		return
	var compact := size.x < 700.0
	_place_centered(start_button, 0.535 if not compact else 0.55, min(620.0, size.x * 0.82), 144.0 if not compact else 116.0)
	if compact:
		_place_centered(rules_button, 0.73, min(288.0, size.x * 0.76), 82.0)
		_place_centered(settings_button, 0.84, min(288.0, size.x * 0.76), 82.0)
	else:
		_place_centered(rules_button, 0.755, 288.0, 92.0, -150.0)
		_place_centered(settings_button, 0.755, 288.0, 92.0, 150.0)


func _place_centered(node: Control, center_y: float, width: float, height: float, center_offset_x := 0.0) -> void:
	node.anchor_left = 0.5
	node.anchor_top = center_y
	node.anchor_right = 0.5
	node.anchor_bottom = center_y
	node.offset_left = -width / 2.0 + center_offset_x
	node.offset_top = -height / 2.0
	node.offset_right = width / 2.0 + center_offset_x
	node.offset_bottom = height / 2.0


func _make_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = text
	button.add_theme_font_size_override("font_size", 40 if primary else 24)
	button.add_theme_color_override("font_color", Color(0.13, 0.03, 0.02, 1.0) if primary else Color(0.96, 0.84, 0.55, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.09, 0.02, 0.015, 1.0) if primary else Color(1.0, 0.91, 0.66, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.09, 0.02, 0.015, 1.0) if primary else Color(0.88, 0.67, 0.34, 1.0))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.35, 0.35) if primary else Color(0.02, 0.01, 0.01, 1.0))
	var prefix := "button_start_" if primary else "button_small_"
	button.add_theme_stylebox_override("normal", _style(prefix + "normal.png", 28 if primary else 20))
	button.add_theme_stylebox_override("hover", _style(prefix + "hover.png", 28 if primary else 20))
	button.add_theme_stylebox_override("pressed", _style(prefix + "pressed.png", 28 if primary else 20))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _style(name: String, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _texture(name)
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = max(12, margin / 2)
	style.content_margin_right = max(12, margin / 2)
	style.content_margin_top = max(10, margin / 2)
	style.content_margin_bottom = max(10, margin / 2)
	return style


func _texture(name: String) -> Texture2D:
	return _texture_path(UI_ROOT + name)


func _texture_path(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null
