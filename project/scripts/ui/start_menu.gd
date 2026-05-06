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
var button_row: HBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	_build()


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

	var content := VBoxContainer.new()
	content.name = "StartMenuContent"
	content.anchor_left = 0.10
	content.anchor_top = 0.07
	content.anchor_right = 0.90
	content.anchor_bottom = 0.93
	content.add_theme_constant_override("separation", 18)
	add_child(content)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 18)
	content.add_child(top_spacer)

	var logo := TextureRect.new()
	logo.name = "LogoLiarsLand"
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.custom_minimum_size = Vector2(0, 230)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = _texture("logo_liars_land.png")
	content.add_child(logo)

	var subtitle := Label.new()
	subtitle.name = "StartMenuSubtitle"
	subtitle.text = _utf8([229, 156, 168, 230, 156, 136, 229, 184, 130, 231, 154, 132, 231, 129, 175, 228, 184, 139, 239, 188, 140, 233, 128, 137, 230, 139, 169, 231, 172, 172, 228, 184, 128, 229, 143, 165, 231, 156, 159, 232, 175, 157])
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_constant_override("outline_size", 4)
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.76, 0.54, 1.0))
	subtitle.add_theme_color_override("font_outline_color", Color(0.04, 0.015, 0.015, 1.0))
	content.add_child(subtitle)

	var middle_spacer := Control.new()
	middle_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(middle_spacer)

	var start_wrap := CenterContainer.new()
	start_wrap.custom_minimum_size = Vector2(0, 144)
	content.add_child(start_wrap)

	start_button = _make_button(_utf8([229, 188, 128, 229, 167, 139, 230, 184, 184, 230, 136, 143]), true)
	start_button.name = "StartGameButton"
	start_button.custom_minimum_size = Vector2(620, 144)
	start_button.pressed.connect(func(): start_requested.emit())
	start_wrap.add_child(start_button)

	button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0, 92)
	button_row.add_theme_constant_override("separation", 44)
	content.add_child(button_row)

	rules_button = _make_button(_utf8([232, 161, 140, 228, 184, 186, 229, 135, 134, 229, 136, 153]), false)
	rules_button.name = "MenuRulesButton"
	rules_button.custom_minimum_size = Vector2(288, 92)
	rules_button.pressed.connect(func(): rules_requested.emit())
	button_row.add_child(rules_button)

	settings_button = _make_button(_utf8([231, 179, 187, 231, 187, 159, 232, 174, 190, 231, 189, 174]), false)
	settings_button.name = "MenuSettingsButton"
	settings_button.custom_minimum_size = Vector2(288, 92)
	settings_button.pressed.connect(func(): settings_requested.emit())
	button_row.add_child(settings_button)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bottom_spacer)

	var hint := Label.new()
	hint.name = "StartMenuHint"
	hint.text = _utf8([228, 184, 187, 232, 143, 156, 229, 141, 149, 230, 166, 130, 229, 191, 181, 32, 118, 49, 239, 188, 154, 230, 156, 128, 229, 164, 167, 230, 140, 137, 233, 146, 174, 232, 191, 155, 229, 133, 165, 230, 184, 184, 230, 136, 143, 239, 188, 140, 229, 176, 143, 230, 140, 137, 233, 146, 174, 230, 137, 191, 232, 189, 189, 232, 167, 132, 229, 136, 153, 228, 184, 142, 232, 174, 190, 231, 189, 174])
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.76, 0.66, 0.47, 1.0))
	content.add_child(hint)

	var border := TextureRect.new()
	border.name = "StartMenuBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.texture = _texture("menu_border.png")
	add_child(border)


func _make_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


func _utf8(bytes: Array) -> String:
	return PackedByteArray(bytes).get_string_from_utf8()
