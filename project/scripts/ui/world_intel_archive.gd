extends Control
class_name WorldIntelArchive

const DefaultOptionCardScene := preload("res://scenes/ui/world_intel_option_card.tscn")
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")

signal close_requested
signal submit_requested
signal answer_selected(question_id: String, option_id: String)

@export_group("Bind Nodes")
@export var progress_label_path: NodePath = ^"ProgressLabel"
@export var question_grid_path: NodePath = ^"Scroll/QuestionGrid"
@export var footer_path: NodePath = ^"Footer"
@export var close_button_path: NodePath = ^"CloseButton"
@export var submit_button_path: NodePath = ^"Footer/SubmitButton"
@export var question_template_path: NodePath = ^"Templates/QuestionTemplate"
@export var option_template_path: NodePath = ^"Templates/QuestionTemplate/Body/OptionsRow/OptionTemplate"

@export_group("Question Template")
@export var question_title_path: NodePath = ^"Body/TitleLabel"
@export var question_options_path: NodePath = ^"Body/OptionsRow"

@export_group("Option Template")
@export var option_card_scene: PackedScene = DefaultOptionCardScene
@export var option_art_path: NodePath = ^"Content/Art"
@export var option_title_path: NodePath = ^"Content/OptionTitle"
@export var option_source_path: NodePath = ^"Content/SourceLabel"
@export var option_portraits_path: NodePath = ^"Content/Portraits"

@export_group("Text")
@export var progress_format := "已选择 %d / %d"

@export_group("Fallback Images")
@export var fallback_option_image: Texture2D
@export var fallback_portrait_image: Texture2D

@export_group("Layout")
@export var min_question_width := 548.0

var _questions: Array = []
var _selected: Dictionary = {}
var _testimonies: Dictionary = {}
var _submitted := false
var _question_min_width := 0.0

@onready var progress_label := get_node_or_null(progress_label_path) as Label
@onready var question_grid := get_node_or_null(question_grid_path) as Container
@onready var close_button := get_node_or_null(close_button_path) as BaseButton
@onready var submit_button := get_node_or_null(submit_button_path) as Button
@onready var question_template := get_node_or_null(question_template_path) as Control
@onready var option_template := get_node_or_null(option_template_path) as Button


func _ready() -> void:
	_apply_layout_defaults()
	_configure_submit_button()
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if submit_button != null and not submit_button.pressed.is_connected(_on_submit_pressed):
		submit_button.pressed.connect(_on_submit_pressed)
	if question_template != null:
		question_template.visible = false
	if option_template != null:
		option_template.visible = false


func bind_world_intel(questions: Array, selected: Dictionary, testimonies: Dictionary, submitted: bool) -> void:
	_questions = questions
	_selected = selected
	_testimonies = testimonies
	_submitted = submitted
	_apply_layout_defaults()
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_defaults()
	if what == NOTIFICATION_THEME_CHANGED:
		_configure_submit_button()


func _apply_layout_defaults() -> void:
	if question_grid != null:
		if question_grid is GridContainer:
			(question_grid as GridContainer).columns = 2
		question_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var available_width := 1120.0 if size.x <= 0.0 else maxf(0.0, size.x * 0.90)
		var gap := float(question_grid.get_theme_constant("h_separation"))
		_question_min_width = maxf(min_question_width, floor((available_width - gap) / 2.0))
	if question_template != null:
		question_template.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question_template.custom_minimum_size.x = _question_min_width
	if option_template != null:
		option_template.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if question_grid != null:
		for child in question_grid.get_children():
			if child == question_template:
				continue
			if child is Control and child.has_meta("generated_world_intel"):
				var question_node := child as Control
				question_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				question_node.custom_minimum_size.x = _question_min_width


func _rebuild() -> void:
	if question_grid == null or question_template == null:
		return
	_clear_generated_questions()
	var selected_count := 0
	for question in _questions:
		if _selected.has(String(question.get("id", ""))):
			selected_count += 1
	if progress_label != null:
		progress_label.text = progress_format % [selected_count, _questions.size()]
	if submit_button != null:
		submit_button.disabled = _submitted
		_configure_submit_button()
	for question in _questions:
		_add_question(question)


func _clear_generated_questions() -> void:
	for child in question_grid.get_children():
		if child == question_template:
			continue
		if child.has_meta("generated_world_intel"):
			child.queue_free()


func _add_question(question: Dictionary) -> void:
	var question_id := String(question.get("id", ""))
	var question_node := question_template.duplicate(DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_USE_INSTANTIATION)
	question_node.name = "Question_%s" % question_id
	question_node.visible = true
	question_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_node.custom_minimum_size.x = _question_min_width
	if question_node is PanelContainer:
		(question_node as PanelContainer).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	question_node.set_meta("generated_world_intel", true)
	question_grid.add_child(question_node)

	var title_label := question_node.get_node_or_null(question_title_path) as Label
	if title_label != null:
		title_label.text = String(question.get("title", question_id))

	var options_root := question_node.get_node_or_null(question_options_path) as Container
	if options_root == null:
		return
	for child in options_root.get_children():
		if child == option_template:
			continue
		if child.has_meta("generated_world_intel"):
			child.queue_free()
	for option in question.get("options", []):
		_add_option(options_root, question_id, option)


func _add_option(parent: Container, question_id: String, option: Dictionary) -> void:
	var option_id := String(option.get("id", ""))
	var selected := String(_selected.get(question_id, "")) == option_id
	var option_node := _make_option_card()
	if option_node == null:
		return
	option_node.name = "Option_%s" % option_id
	option_node.visible = true
	option_node.set_meta("generated_world_intel", true)
	option_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option_node)

	var source_entries: Array = _testimonies.get(question_id, {}).get(option_id, [])
	if option_node.has_method("bind_option"):
		if option_node.has_signal("selected_requested"):
			option_node.connect("selected_requested", func(selected_question_id: String, selected_option_id: String):
				answer_selected.emit(selected_question_id, selected_option_id)
			)
		option_node.call("bind_option", question_id, option, selected, source_entries)
		return

	if option_node is Button:
		var option_button := option_node as Button
		option_button.toggle_mode = true
		option_button.button_pressed = selected
		option_button.pressed.connect(func(): answer_selected.emit(question_id, option_id))

	var art := option_node.get_node_or_null(option_art_path) as TextureRect
	if art != null:
		art.texture = _load_texture(_intel_image_path(String(option.get("image", ""))), fallback_option_image)

	var title_label := option_node.get_node_or_null(option_title_path) as Label
	if title_label != null:
		title_label.text = String(option.get("title", option_id))

	var source_label := option_node.get_node_or_null(option_source_path) as Label
	if source_label != null:
		source_label.visible = false
		source_label.text = ""

	var portraits := option_node.get_node_or_null(option_portraits_path) as Container
	if portraits != null:
		_clear_children(portraits)
		for source in source_entries:
			var portrait := TextureRect.new()
			portrait.custom_minimum_size = Vector2(30, 30)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			portrait.tooltip_text = "第%d章%s" % [int(source.get("chapter", 1)), String(source.get("npc_name", "对手"))]
			portrait.texture = _load_texture(_portrait_image_path(String(source.get("portrait", ""))), fallback_portrait_image)
			portraits.add_child(portrait)


func _make_option_card() -> Control:
	if option_card_scene != null:
		var instance := option_card_scene.instantiate() as Control
		if instance != null:
			return instance
	if option_template != null:
		return option_template.duplicate(DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_USE_INSTANTIATION) as Control
	return null


func _intel_image_path(image_name: String) -> String:
	if image_name.begins_with("res://"):
		return image_name
	if image_name.begins_with("ui/intel/"):
		return "res://assets/generated/%s" % image_name
	if not image_name.is_empty():
		return "res://assets/generated/%s" % image_name
	return "res://assets/generated/card_clue_back.png"


func _load_texture(path: String, fallback: Texture2D) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if OS.has_feature("web"):
		return fallback
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return fallback


func _portrait_image_path(portrait_name: String) -> String:
	if portrait_name.begins_with("res://"):
		return portrait_name
	if portrait_name.is_empty():
		return "res://assets/ui/characters/headicon/opponent_head_avatar.png"
	var head_name := portrait_name.replace("_portrait.png", "_head_avatar.png")
	var head_path := "res://assets/ui/characters/headicon/%s" % head_name
	if ResourceLoader.exists(head_path) or FileAccess.file_exists(ProjectSettings.globalize_path(head_path)):
		return head_path
	return "res://assets/ui/characters/portrait/%s" % portrait_name


func _configure_submit_button() -> void:
	if submit_button == null:
		return
	StandardButtonScript.apply(submit_button, StandardButtonScript.PRIMARY, "提交世界设定档案", 24, Vector2(300, 72))


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_submit_pressed() -> void:
	submit_requested.emit()
