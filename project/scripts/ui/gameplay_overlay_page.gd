@tool
extends Control
class_name GameplayOverlayPage

signal close_requested

const COMMON_UI_ROOT := "res://assets/ui/common/"
const FONT_PATH := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
const CommonFrameScript := preload("res://scripts/ui/common_frame.gd")
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")

@export var page_title := "页面"
@export var background_path := ""
@export_enum("gold", "dark_teal", "dark_red", "dark_purple", "gray") var panel_color := CommonFrameScript.GOLD
@export var main_panel_rect := Rect2(82, 118, 1116, 544)

var main_panel: NinePatchRect
var content_margin: MarginContainer
var content_box: VBoxContainer
var title_label: Label
var close_button: TextureButton
var _built := false
var _uses_scene_layout := false


func _ready() -> void:
	_build_base()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_fixed_layout()


func _build_base() -> void:
	if _built:
		return
	_built = true
	name = name if not name.is_empty() else "GameplayOverlayPage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _bind_scene_base():
		_bind_page()
		_apply_fixed_layout()
		return

	var background := TextureRect.new()
	background.name = "Background"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = _load_texture(background_path)
	add_child(background)

	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.010, 0.012, 0.68)
	add_child(veil)

	var scratches := TextureRect.new()
	scratches.name = "TextureScratches"
	scratches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scratches.set_anchors_preset(Control.PRESET_FULL_RECT)
	scratches.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scratches.stretch_mode = TextureRect.STRETCH_SCALE
	scratches.modulate = Color(1, 1, 1, 0.12)
	scratches.texture = _load_texture(COMMON_UI_ROOT + "shop_texture_scratches_dark.png")
	add_child(scratches)

	var title_banner := TextureRect.new()
	title_banner.name = "TitleBanner"
	title_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_banner.texture = _load_texture(COMMON_UI_ROOT + "title_banner_red.png")
	add_child(title_banner)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = page_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(title_label, 35, Color(0.964706, 0.913725, 0.796078, 1.0), 3)
	add_child(title_label)

	close_button = TextureButton.new()
	close_button.name = "CloseButton"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.tooltip_text = "关闭"
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.texture_normal = _load_texture(COMMON_UI_ROOT + "bag_close_normal.png")
	close_button.texture_hover = _load_texture(COMMON_UI_ROOT + "bag_close_hover.png")
	close_button.texture_pressed = _load_texture(COMMON_UI_ROOT + "bag_close_pressed.png")
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_SCALE
	close_button.pressed.connect(func(): close_requested.emit())
	add_child(close_button)

	main_panel = NinePatchRect.new()
	main_panel.name = "MainPanel"
	main_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CommonFrameScript.apply_background_panel(main_panel, panel_color)
	add_child(main_panel)

	content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 52)
	content_margin.add_theme_constant_override("margin_top", 52)
	content_margin.add_theme_constant_override("margin_right", 52)
	content_margin.add_theme_constant_override("margin_bottom", 52)
	main_panel.add_child(content_margin)

	content_box = VBoxContainer.new()
	content_box.name = "Content"
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 14)
	content_margin.add_child(content_box)

	_apply_fixed_layout()
	_build_page()


func _bind_scene_base() -> bool:
	main_panel = get_node_or_null("MainPanel") as NinePatchRect
	if main_panel == null:
		return false
	content_margin = main_panel.get_node_or_null("ContentMargin") as MarginContainer
	content_box = main_panel.get_node_or_null("ContentMargin/Content") as VBoxContainer
	title_label = get_node_or_null("TitleLabel") as Label
	close_button = get_node_or_null("CloseButton") as TextureButton
	if content_margin == null or content_box == null or title_label == null or close_button == null:
		return false
	_uses_scene_layout = true
	if not close_button.pressed.is_connected(_emit_close_requested):
		close_button.pressed.connect(_emit_close_requested)
	return true


func _build_page() -> void:
	pass


func _bind_page() -> void:
	pass


func _emit_close_requested() -> void:
	close_requested.emit()


func _apply_fixed_layout() -> void:
	if not _built or _uses_scene_layout:
		return
	var scale := _layout_scale()
	_place_absolute(get_node_or_null("TitleBanner") as Control, Rect2(-23.0, 17.333, 419.667, 90.0), scale)
	_place_absolute(title_label, Rect2(36.0, 26.0, 260.0, 54.666), scale)
	_place_absolute(close_button, Rect2(1192.0, 28.0, 57.333, 57.333), scale)
	if main_panel != null:
		_place_absolute(main_panel, main_panel_rect, scale)


func _layout_scale() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)


func _place_absolute(node: Control, rect: Rect2, scale := Vector2.ONE) -> void:
	if node == null:
		return
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = rect.position.x * scale.x
	node.offset_top = rect.position.y * scale.y
	node.offset_right = (rect.position.x + rect.size.x) * scale.x
	node.offset_bottom = (rect.position.y + rect.size.y) * scale.y


func _style_label(label: Label, font_size: int, color: Color, outline := 2) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	var font := _load_font()
	if font != null:
		label.add_theme_font_override("font", font)


func _make_label(text: String, font_size: int, color: Color, outline := 2) -> Label:
	var label := Label.new()
	label.text = text
	_style_label(label, font_size, color, outline)
	return label


func _make_section_panel(node_name: String, color := CommonFrameScript.DARK_PURPLE) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	CommonFrameScript.apply_background_panel(panel, color)
	return panel


func _make_section_content(panel: NinePatchRect, margin := 46) -> VBoxContainer:
	var holder := MarginContainer.new()
	holder.name = "MarginContainer"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_left", margin)
	holder.add_theme_constant_override("margin_top", margin)
	holder.add_theme_constant_override("margin_right", margin)
	holder.add_theme_constant_override("margin_bottom", margin)
	panel.add_child(holder)
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	holder.add_child(box)
	return box


func _make_button(text: String, primary := false, min_size := Vector2(148, 46)) -> Button:
	var button := Button.new()
	StandardButtonScript.apply(button, StandardButtonScript.PRIMARY if primary else StandardButtonScript.SECONDARY, text, 18, min_size)
	return button


func _make_check(text: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.focus_mode = Control.FOCUS_NONE
	check.custom_minimum_size = Vector2(190, 42)
	check.add_theme_font_size_override("font_size", 18)
	check.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0))
	var font := _load_font()
	if font != null:
		check.add_theme_font_override("font", font)
	var unchecked := _load_texture("res://assets/generated/ui/dialogue/checkbox_unchecked.png")
	var checked := _load_texture("res://assets/generated/ui/dialogue/checkbox_checked.png")
	if unchecked != null:
		check.add_theme_icon_override("unchecked", unchecked)
		check.add_theme_icon_override("unchecked_disabled", unchecked)
	if checked != null:
		check.add_theme_icon_override("checked", checked)
		check.add_theme_icon_override("checked_disabled", checked)
	return check


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if OS.has_feature("web"):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH)
	return null
