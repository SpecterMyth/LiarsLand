extends RefCounted
class_name CardUiKit

const UI_ROOT := "res://assets/generated/ui/card/"

const COLOR_BG := Color(0.025, 0.045, 0.060, 1.0)
const COLOR_PANEL := Color(0.035, 0.040, 0.050, 0.96)
const COLOR_RED := Color(0.73, 0.05, 0.10, 1.0)
const COLOR_PURPLE := Color(0.22, 0.13, 0.38, 1.0)
const COLOR_TEAL := Color(0.03, 0.42, 0.40, 1.0)
const COLOR_YELLOW := Color(0.95, 0.62, 0.06, 1.0)
const COLOR_TEXT := Color(0.96, 0.94, 0.90, 1.0)
const COLOR_MUTED := Color(0.72, 0.70, 0.66, 1.0)
const COLOR_INK := Color(0.015, 0.018, 0.025, 1.0)


func make_page(title: String, meta_text: String) -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _texture("bg_card_city.png")
	page.add_child(bg)

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0, 0, 0, 0.20)
	page.add_child(veil)

	var banner := make_title_banner(title, meta_text)
	page.add_child(banner)
	return page


func make_title_banner(title: String, meta_text: String) -> Control:
	var root := Control.new()
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 0.16
	root.offset_left = 0
	root.offset_right = 0
	root.offset_top = 0
	root.offset_bottom = 0

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(680, 0),
		Vector2(620, 108),
		Vector2(0, 150)
	])
	poly.color = COLOR_RED
	root.add_child(poly)

	var title_label := Label.new()
	title_label.text = title
	title_label.anchor_left = 0.045
	title_label.anchor_top = 0.22
	title_label.anchor_right = 0.58
	title_label.anchor_bottom = 0.88
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", COLOR_INK)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	root.add_child(title_label)

	var meta := Label.new()
	meta.text = meta_text
	meta.anchor_left = 0.72
	meta.anchor_top = 0.25
	meta.anchor_right = 0.90
	meta.anchor_bottom = 0.72
	meta.add_theme_font_size_override("font_size", 26)
	meta.add_theme_constant_override("outline_size", 3)
	meta.add_theme_color_override("font_outline_color", COLOR_INK)
	meta.add_theme_color_override("font_color", COLOR_TEXT)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(meta)
	return root


func make_character_card(title: String, avatar: String, stats: Array, tone := "red") -> PanelContainer:
	var card := make_card(tone)
	card.custom_minimum_size = Vector2(390, 610)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 360)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _texture(avatar)
	box.add_child(art)

	var name := _label(title, 30, Color.WHITE, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)

	for row in stats:
		var label := String(row[0])
		var value := String(row[1])
		box.add_child(make_stat_chip(label, value))
	return card


func make_option_card(title: String, avatar: String, tag_text: String, tone := "purple") -> PanelContainer:
	var card := make_card(tone)
	card.custom_minimum_size = Vector2(300, 540)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	card.add_child(box)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 315)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _texture(avatar)
	box.add_child(art)

	var label := _label(title, 29, Color.WHITE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	box.add_child(make_tag(tag_text, _tone_color(tone)))
	return card


func make_item_card(title: String, icon_name: String, price: String, tone := "purple") -> PanelContainer:
	var card := make_card(tone)
	card.custom_minimum_size = Vector2(250, 420)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	card.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(160, 160)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _texture(icon_name)
	box.add_child(icon)

	var name := _label(title, 22, Color.WHITE, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	box.add_child(name)
	box.add_child(make_tag("价格 " + price, COLOR_YELLOW))
	return card


func make_card(tone := "dark") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(_tone_color(tone), Color(0.02, 0.02, 0.03, 1.0), 3, 8, 12))
	panel.add_theme_constant_override("margin_left", 14)
	panel.add_theme_constant_override("margin_right", 14)
	panel.add_theme_constant_override("margin_top", 14)
	panel.add_theme_constant_override("margin_bottom", 14)
	return panel


func make_primary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", COLOR_INK)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color(1, 0.85, 0.25, 0.35))
	button.add_theme_stylebox_override("normal", _style(COLOR_YELLOW, COLOR_INK, 3, 6, 5))
	button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.72, 0.12, 1.0), COLOR_INK, 3, 6, 5))
	button.add_theme_stylebox_override("pressed", _style(Color(0.78, 0.45, 0.03, 1.0), COLOR_INK, 3, 6, 2))
	return button


func make_secondary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _style(COLOR_PANEL, Color(0.16, 0.18, 0.22, 1.0), 2, 5, 4))
	button.add_theme_stylebox_override("hover", _style(Color(0.09, 0.10, 0.13, 1.0), Color(0.28, 0.32, 0.38, 1.0), 2, 5, 4))
	button.add_theme_stylebox_override("pressed", _style(Color(0.02, 0.025, 0.035, 1.0), Color(0.16, 0.18, 0.22, 1.0), 2, 5, 1))
	return button


func make_utility_button(label: String, icon_name: String, color: Color) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(128, 86)
	button.add_theme_stylebox_override("normal", _style(Color(0.02, 0.025, 0.030, 0.96), Color(0.11, 0.13, 0.15, 1.0), 2, 0, 8))
	button.add_theme_stylebox_override("hover", _style(Color(0.04, 0.05, 0.06, 0.96), color, 2, 0, 8))
	button.add_theme_stylebox_override("pressed", _style(Color(0.01, 0.012, 0.016, 0.96), color, 2, 0, 2))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var tile := ColorRect.new()
	tile.custom_minimum_size = Vector2(62, 0)
	tile.color = color
	row.add_child(tile)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _texture(icon_name)
	tile.add_child(icon)
	var text := _label(label, 20, Color.WHITE, true)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)
	return button


func make_tag(text: String, color: Color) -> Label:
	var label := _label(text, 17, COLOR_TEXT, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 38)
	label.add_theme_stylebox_override("normal", _style(color.darkened(0.18), Color.TRANSPARENT, 0, 4, 0))
	return label


func make_stat_chip(label: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 8)
	var name := _label(label, 18, COLOR_TEXT, false)
	name.custom_minimum_size = Vector2(110, 0)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var value_label := _label(value, 21, Color.WHITE, true)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	row.add_theme_stylebox_override("panel", _style(Color(0.03, 0.035, 0.045, 0.90), Color(0.16, 0.17, 0.18, 1.0), 2, 4, 0))
	return row


func make_item_tile(icon_name: String, count: int, satisfied := true, label := "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(92, 92)
	var base := Color(0.08, 0.09, 0.11, 1.0) if not satisfied else Color(0.15, 0.12, 0.06, 1.0)
	panel.add_theme_stylebox_override("panel", _style(base, COLOR_INK, 3, 6, 4))
	var root := Control.new()
	panel.add_child(root)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 9
	icon.offset_top = 9
	icon.offset_right = -9
	icon.offset_bottom = -9
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate.a = 1.0 if satisfied else 0.45
	icon.texture = _texture(icon_name)
	root.add_child(icon)
	var badge := Label.new()
	badge.text = str(count)
	badge.anchor_left = 0.60
	badge.anchor_top = 0.62
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_constant_override("outline_size", 3)
	badge.add_theme_color_override("font_outline_color", COLOR_INK)
	root.add_child(badge)
	if not label.is_empty():
		panel.tooltip_text = label
	return panel


func make_stat_stepper(text: String, minus: Callable, plus: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 54)
	var minus_button := make_secondary_button("−")
	minus_button.custom_minimum_size = Vector2(54, 54)
	minus_button.pressed.connect(minus)
	row.add_child(minus_button)
	var label := _label(text, 20, Color.WHITE, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _style(Color(0.03, 0.035, 0.045, 0.96), Color(0.14, 0.15, 0.18, 1.0), 2, 5, 0))
	row.add_child(label)
	var plus_button := make_secondary_button("+")
	plus_button.custom_minimum_size = Vector2(54, 54)
	plus_button.pressed.connect(plus)
	row.add_child(plus_button)
	return row


func artifact_icon_name(artifact_id: String) -> String:
	return "artifact_%s.png" % artifact_id


func _label(text: String, size: int, color: Color, outlined: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", COLOR_INK)
	return label


func _tone_color(tone: String) -> Color:
	match tone:
		"red":
			return Color(0.42, 0.035, 0.055, 0.96)
		"purple":
			return COLOR_PURPLE
		"teal":
			return COLOR_TEAL
		"yellow":
			return COLOR_YELLOW
		_:
			return COLOR_PANEL


func _style(bg: Color, border: Color, border_width: int, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if shadow_size > 0:
		style.shadow_color = Color(0, 0, 0, 0.58)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(8, 8)
	return style


func _texture(name: String) -> Texture2D:
	var path := UI_ROOT + name
	if ResourceLoader.exists(path):
		return load(path)
	return null
