extends Button
class_name StandardButton

const PRIMARY := "primary"
const SECONDARY := "secondary"

const COMMON_UI_ROOT := "res://assets/ui/common/"
const PRIMARY_NORMAL := "button_primary_gold_normal.png"
const PRIMARY_HOVER := "button_primary_gold_hover.png"
const PRIMARY_PRESSED := "button_primary_gold_pressed.png"
const SECONDARY_NORMAL := "button_secondary_blank_normal.png"
const SECONDARY_HOVER := "button_secondary_blank_hover.png"
const SECONDARY_PRESSED := "button_secondary_blank_pressed.png"
const DISABLED := "button_disabled_dark.png"
const STANDARD_FONT := preload("res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf")

@export_enum("primary", "secondary") var button_style := PRIMARY
@export var standard_font_size := 0


func _ready() -> void:
	apply(self, button_style, text, standard_font_size)


static func apply(button: Button, style := PRIMARY, button_text := "", font_size := 0, minimum_size := Vector2.ZERO) -> void:
	if button == null:
		return
	var is_primary := style == PRIMARY
	button.text = button.text if button_text.is_empty() else button_text
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if minimum_size != Vector2.ZERO:
		button.custom_minimum_size = minimum_size
	if font_size > 0:
		button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_font_override("font", STANDARD_FONT)
	var font_color := Color(0.08, 0.035, 0.0, 1.0) if is_primary else Color.WHITE
	var disabled_color := Color(0.0, 0.0, 0.0, 0.55) if is_primary else Color(1.0, 1.0, 1.0, 0.55)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", disabled_color)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	button.add_theme_stylebox_override("normal", _stylebox(PRIMARY_NORMAL if is_primary else SECONDARY_NORMAL))
	button.add_theme_stylebox_override("hover", _stylebox(PRIMARY_HOVER if is_primary else SECONDARY_HOVER))
	button.add_theme_stylebox_override("pressed", _stylebox(PRIMARY_PRESSED if is_primary else SECONDARY_PRESSED))
	button.add_theme_stylebox_override("disabled", _stylebox(DISABLED))


static func _stylebox(asset_name: String, texture_margin := 24, horizontal_margin := 24, vertical_margin := 12) -> StyleBox:
	var texture := _load_texture(COMMON_UI_ROOT + asset_name)
	if texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.18, 0.10, 0.04, 0.95)
		flat.border_color = Color(0.9, 0.58, 0.18, 1.0)
		flat.set_border_width_all(2)
		flat.content_margin_left = horizontal_margin
		flat.content_margin_right = horizontal_margin
		flat.content_margin_top = vertical_margin
		flat.content_margin_bottom = vertical_margin
		return flat
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_bottom = texture_margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null
