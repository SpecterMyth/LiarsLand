extends Control
class_name DeathPage

signal merge_guideline_requested(rule_text: String)
signal restart_requested

const COMMON_UI_ROOT := "res://assets/ui/common/"
const DEATH_UI_ROOT := "res://assets/ui/death/"
const FONT_PATH := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")

var background: TextureRect
var veil: ColorRect
var content: VBoxContainer
var title_label: Label
var reason_label: Label
var hint_label: Label
var rule_edit: TextEdit
var merge_button: Button
var restart_button: Button
var built := false


func _ready() -> void:
	_build()
	hide_death()


func show_death(reason: String, rule_text: String) -> void:
	_build()
	var cleaned_rule := rule_text.strip_edges()
	reason_label.text = reason.strip_edges() if not reason.strip_edges().is_empty() else "冒险失败。"
	rule_edit.text = cleaned_rule if not cleaned_rule.is_empty() else "这次失败没有形成明确准则。重新出发前，先回顾最近一次高风险选择的敌友证据、攻防优势和行动收益。"
	rule_edit.editable = true
	merge_button.disabled = cleaned_rule.is_empty()
	merge_button.text = "已无可融合准则" if cleaned_rule.is_empty() else "融合准则"
	visible = true
	move_to_front()


func hide_death() -> void:
	visible = false


func set_merging(merging: bool) -> void:
	_build()
	var has_rule := not rule_edit.text.strip_edges().is_empty()
	merge_button.disabled = merging or not has_rule
	merge_button.text = "融合中" if merging else ("融合准则" if has_rule else "已无可融合准则")
	rule_edit.editable = not merging


func set_merge_done() -> void:
	_build()
	merge_button.disabled = true
	merge_button.text = "已融合"
	rule_edit.editable = true


func _build() -> void:
	if built:
		return
	built = true
	name = "DeathPage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 4095

	background = TextureRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = _load_texture(DEATH_UI_ROOT + "death_scene_bg.png")
	if background.texture == null:
		background.texture = _load_texture(COMMON_UI_ROOT + "bg_round_start_city.png")
	add_child(background)

	veil = ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.010, 0.014, 0.48)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	content = VBoxContainer.new()
	content.name = "Content"
	content.anchor_left = 0.24
	content.anchor_top = 0.13
	content.anchor_right = 0.76
	content.anchor_bottom = 0.91
	content.offset_left = 0.0
	content.offset_top = 0.0
	content.offset_right = 0.0
	content.offset_bottom = 0.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	add_child(content)

	title_label = _make_label("冒险终止", 58, Color(1.0, 0.82, 0.38, 1.0), 5)
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	reason_label = _make_label("", 28, Color(1.0, 0.90, 0.70, 1.0), 4)
	reason_label.name = "ReasonLabel"
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.custom_minimum_size = Vector2(0, 92)
	content.add_child(reason_label)

	hint_label = _make_label("建议将以下规则融合进行为准则", 22, Color(0.78, 1.0, 0.92, 1.0), 3)
	hint_label.name = "HintLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint_label)

	rule_edit = TextEdit.new()
	rule_edit.name = "RuleEdit"
	rule_edit.custom_minimum_size = Vector2(0, 154)
	rule_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rule_edit.scroll_fit_content_height = false
	rule_edit.add_theme_font_override("font", _load_font(FONT_PATH))
	rule_edit.add_theme_font_size_override("font_size", 22)
	rule_edit.add_theme_color_override("font_color", Color(0.96, 0.89, 0.76, 1.0))
	rule_edit.add_theme_color_override("font_placeholder_color", Color(0.70, 0.58, 0.45, 1.0))
	rule_edit.add_theme_color_override("caret_color", Color(1.0, 0.82, 0.38, 1.0))
	rule_edit.add_theme_color_override("selection_color", Color(0.14, 0.56, 0.52, 0.45))
	rule_edit.add_theme_stylebox_override("normal", _edit_stylebox(false))
	rule_edit.add_theme_stylebox_override("focus", _edit_stylebox(true))
	content.add_child(rule_edit)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 26)
	content.add_child(button_row)

	merge_button = Button.new()
	merge_button.name = "MergeButton"
	StandardButtonScript.apply(merge_button, StandardButtonScript.SECONDARY, "融合准则", 24, Vector2(244, 58))
	merge_button.pressed.connect(func(): merge_guideline_requested.emit(rule_edit.text.strip_edges()))
	button_row.add_child(merge_button)

	restart_button = Button.new()
	restart_button.name = "RestartButton"
	StandardButtonScript.apply(restart_button, StandardButtonScript.PRIMARY, "重新出发", 26, Vector2(264, 62))
	restart_button.pressed.connect(func(): restart_requested.emit())
	button_row.add_child(restart_button)

	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var size := get_viewport_rect().size
	var narrow := size.x < 980
	content.anchor_left = 0.08 if narrow else 0.24
	content.anchor_right = 0.92 if narrow else 0.76
	content.anchor_top = 0.08 if narrow else 0.13
	content.anchor_bottom = 0.94 if narrow else 0.91
	title_label.add_theme_font_size_override("font_size", 42 if narrow else 58)
	reason_label.add_theme_font_size_override("font_size", 22 if narrow else 28)
	hint_label.add_theme_font_size_override("font_size", 18 if narrow else 22)
	rule_edit.add_theme_font_size_override("font_size", 18 if narrow else 22)
	rule_edit.custom_minimum_size = Vector2(0, 128 if narrow else 154)


func _make_label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.96))
	var font := _load_font(FONT_PATH)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


func _edit_stylebox(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.014, 0.018, 0.74)
	style.border_color = Color(0.86, 0.54, 0.18, 0.86) if focused else Color(0.60, 0.38, 0.16, 0.66)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null
