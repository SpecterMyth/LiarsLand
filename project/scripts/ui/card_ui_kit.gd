extends RefCounted
class_name CardUiKit

const UI_ROOT := "res://assets/ui/common/"
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")

const COLOR_TEXT := Color(0.96, 0.93, 0.84, 1.0)
const COLOR_MUTED := Color(0.70, 0.68, 0.62, 1.0)
const COLOR_INK := Color(0.015, 0.018, 0.025, 1.0)
const COLOR_RED := Color(0.76, 0.04, 0.09, 1.0)
const COLOR_PURPLE := Color(0.36, 0.20, 0.55, 1.0)
const COLOR_TEAL := Color(0.00, 0.55, 0.52, 1.0)
const COLOR_YELLOW := Color(0.95, 0.62, 0.06, 1.0)


func make_page(title: String, meta_text: String) -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.z_index = 1000
	page.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _texture("bg_round_start_city.png")
	page.add_child(bg)

	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0, 0, 0, 0.18)
	page.add_child(veil)

	page.add_child(make_title_banner(title, meta_text))
	return page


func make_reference_page(image_name: String) -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.z_index = 1000
	page.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _texture(image_name)
	page.add_child(bg)
	return page


func make_title_banner(title: String, meta_text: String) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 0.16

	var title_bg := TextureRect.new()
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bg.anchor_left = 0.0
	title_bg.anchor_top = 0.0
	title_bg.anchor_right = 0.53
	title_bg.anchor_bottom = 1.0
	title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_bg.texture = _texture("title_banner_red_large.png")
	root.add_child(title_bg)

	var title_label := _label(title, 48, Color.WHITE, true)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.anchor_left = 0.045
	title_label.anchor_top = 0.15
	title_label.anchor_right = 0.42
	title_label.anchor_bottom = 0.82
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	root.add_child(title_label)

	var meta_bg := TextureRect.new()
	meta_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_bg.anchor_left = 0.68
	meta_bg.anchor_top = 0.18
	meta_bg.anchor_right = 0.94
	meta_bg.anchor_bottom = 0.78
	meta_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meta_bg.stretch_mode = TextureRect.STRETCH_SCALE
	meta_bg.texture = _texture("meta_plate_dark_blank.png")
	root.add_child(meta_bg)

	var meta := _label(meta_text, 28, COLOR_TEXT, true)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.anchor_left = 0.70
	meta.anchor_top = 0.20
	meta.anchor_right = 0.92
	meta.anchor_bottom = 0.74
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(meta)
	return root


func make_character_card(title: String, avatar: String, stats: Array, tone := "red") -> PanelContainer:
	var card := _panel("panel_player_red.png", 30, Vector2(320, 550))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 295)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _texture(avatar)
	box.add_child(art)

	var name := make_plate_label(title, "red", 27, Vector2(0, 52))
	box.add_child(name)

	for row in stats:
		box.add_child(make_stat_chip(String(row[0]), String(row[1])))
	return card


func make_option_card(title: String, avatar: String, tag_text: String, tone := "purple") -> PanelContainer:
	var card := _panel(_option_asset(tone), 28, Vector2(210, 500))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 255)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _texture(avatar)
	box.add_child(art)

	var label := _label(title, 23, Color.WHITE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	box.add_child(label)
	box.add_child(make_plate_label(tag_text, tone, 18, Vector2(0, 46)))
	return card


func make_item_card(title: String, icon_name: String, price: String, tone := "purple") -> PanelContainer:
	var card := _panel(_item_card_asset(tone), 24, Vector2(180, 360))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(115, 125)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _texture(icon_name)
	box.add_child(icon)

	var name := _label(title, 19, Color.WHITE, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	box.add_child(name)
	box.add_child(make_price_plate(price))
	return card


func make_card(tone := "dark") -> PanelContainer:
	var asset := "panel_large_teal.png" if tone == "teal" else "panel_large_dark.png"
	return _panel(asset, 30, Vector2(380, 560))


func make_requirement_panel(title: String, tone := "red") -> PanelContainer:
	return _panel("panel_requirement_purple.png" if tone == "purple" else "panel_requirement_red.png", 26, Vector2(260, 145))


func make_backpack_panel() -> PanelContainer:
	return _panel("panel_option_purple.png", 26, Vector2(220, 560))


func make_primary_button(text: String) -> Button:
	return _button(text, true)


func make_secondary_button(text: String) -> Button:
	return _button(text, false)


func make_utility_button(label: String, icon_name: String, color: Color) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(96, 74)
	button.add_theme_stylebox_override("normal", _texture_style("meta_plate_dark_blank.png", 24))
	button.add_theme_stylebox_override("hover", _texture_style("label_teal.png", 22))
	button.add_theme_stylebox_override("pressed", _texture_style("label_red.png", 22))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	button.add_child(row)

	var icon_slot := TextureRect.new()
	icon_slot.custom_minimum_size = Vector2(46, 0)
	icon_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_slot.texture = _texture(icon_name)
	row.add_child(icon_slot)

	var text := _label(label, 17, Color.WHITE, true)
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
	label.add_theme_stylebox_override("normal", _texture_style("label_teal.png", 20))
	return label


func make_plate_label(text: String, tone: String, size: int, min_size := Vector2.ZERO) -> Label:
	var label := _label(text, size, Color.WHITE, true)
	label.custom_minimum_size = min_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _texture_style(_label_asset(tone), 22))
	return label


func make_price_plate(price: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 64)
	row.add_theme_constant_override("separation", 8)
	row.add_theme_stylebox_override("panel", _texture_style("item_row_dark.png", 18))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _texture("artifact_moon_lantern.png")
	row.add_child(icon)
	var amount := _label(price, 33, COLOR_YELLOW, true)
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(amount)
	return row


func make_stat_chip(label: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 48)
	row.add_theme_constant_override("separation", 8)
	row.add_theme_stylebox_override("panel", _texture_style("item_row_dark.png", 18))
	var icon_label := _label(_stat_icon(label), 20, COLOR_YELLOW, true)
	icon_label.custom_minimum_size = Vector2(56, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)
	var name := _label(label, 19, COLOR_TEXT, true)
	name.custom_minimum_size = Vector2(94, 0)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var value_label := _label(value, 24, Color.WHITE, true)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	return row


func make_item_tile(icon_name: String, count: int, satisfied := true, label := "") -> PanelContainer:
	var tone_asset := "shop_slot_requirement_unmet_dark.png"
	if satisfied:
		tone_asset = "shop_slot_requirement_fulfilled_gold.png"
	var panel := _panel(tone_asset, 18, Vector2(86, 86))
	var root := Control.new()
	root.custom_minimum_size = Vector2(86, 86)
	panel.add_child(root)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate.a = 1.0 if satisfied else 0.34
	icon.texture = _texture(icon_name)
	root.add_child(icon)
	var badge := _label(str(count), 17, Color.WHITE, true)
	badge.anchor_left = 0.62
	badge.anchor_top = 0.62
	badge.anchor_right = 1.02
	badge.anchor_bottom = 1.02
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _texture_style("meta_plate_dark_blank.png", 18))
	root.add_child(badge)
	if not label.is_empty():
		panel.tooltip_text = label
	return panel


func make_stat_stepper(text: String, minus: Callable, plus: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 66)
	var minus_button := make_secondary_button("−")
	minus_button.custom_minimum_size = Vector2(64, 64)
	minus_button.pressed.connect(minus)
	row.add_child(minus_button)
	var label := _label(text, 24, Color.WHITE, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _texture_style("item_row_dark.png", 22))
	row.add_child(label)
	var plus_button := make_secondary_button("+")
	plus_button.custom_minimum_size = Vector2(64, 64)
	plus_button.pressed.connect(plus)
	row.add_child(plus_button)
	return row


func artifact_icon_name(artifact_id: String) -> String:
	return "artifact_%s.png" % artifact_id


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58 if primary else 50)
	var style := StandardButtonScript.PRIMARY if primary else StandardButtonScript.SECONDARY
	StandardButtonScript.apply(button, style, text, 26 if primary else 20, button.custom_minimum_size)
	return button


func _panel(asset: String, margin: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _texture_style(asset, margin))
	panel.add_theme_constant_override("margin_left", margin)
	panel.add_theme_constant_override("margin_right", margin)
	panel.add_theme_constant_override("margin_top", margin)
	panel.add_theme_constant_override("margin_bottom", margin)
	return panel


func _label(text: String, size: int, color: Color, outlined: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", COLOR_INK)
	return label


func _texture_style(name: String, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _texture(name)
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = max(8, margin / 2)
	style.content_margin_right = max(8, margin / 2)
	style.content_margin_top = max(8, margin / 2)
	style.content_margin_bottom = max(8, margin / 2)
	return style


func _option_asset(tone: String) -> String:
	match tone:
		"red":
			return "panel_option_red.png"
		"teal":
			return "panel_option_teal.png"
		_:
			return "panel_option_purple.png"


func _item_card_asset(tone: String) -> String:
	match tone:
		"red":
			return "shop_card_item_red.png"
		"teal":
			return "shop_card_item_teal.png"
		_:
			return "shop_card_item_purple.png"


func _label_asset(tone: String) -> String:
	match tone:
		"red":
			return "label_red.png"
		"teal":
			return "label_teal.png"
		"purple":
			return "label_purple.png"
		_:
			return "meta_plate_dark_blank.png"


func _stat_icon(label: String) -> String:
	match label:
		"能量":
			return "♦"
		"等级":
			return "★"
		"统治":
			return "♛"
		"背包":
			return "●"
		_:
			return "■"


func _texture(name: String) -> Texture2D:
	for root in [UI_ROOT, "res://assets/generated/"]:
		var path: String = String(root) + name
		if ResourceLoader.exists(path):
			return load(path)
		if OS.has_feature("web"):
			continue
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			var image := Image.load_from_file(absolute_path)
			if image != null:
				return ImageTexture.create_from_image(image)
	return null
