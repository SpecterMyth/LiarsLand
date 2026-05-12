extends Button
class_name WorldIntelOptionCard

signal selected_requested(question_id: String, option_id: String)

@export_group("Bind Nodes")
@export var art_path: NodePath = ^"Content/Art"
@export var title_path: NodePath = ^"Content/OptionTitle"
@export var source_path: NodePath = ^"Content/SourceLabel"
@export var portraits_path: NodePath = ^"Content/Portraits"
@export var selected_outline_path: NodePath = ^"SelectedOutline"
@export var background_path: NodePath = ^"Background"

@export_group("Fallback Images")
@export var fallback_option_image: Texture2D
@export var fallback_portrait_image: Texture2D

@export_group("Motion")
@export var hover_scale := 1.035
@export var hover_in_seconds := 0.08
@export var hover_out_seconds := 0.14

var _question_id := ""
var _option_id := ""
var _feedback_tween: Tween

@onready var art := get_node_or_null(art_path) as TextureRect
@onready var title_label := get_node_or_null(title_path) as Label
@onready var source_label := get_node_or_null(source_path) as Label
@onready var portraits := get_node_or_null(portraits_path) as Container
@onready var selected_outline := get_node_or_null(selected_outline_path) as CanvasItem
@onready var background := get_node_or_null(background_path) as CanvasItem

var _selected_background_material: ShaderMaterial


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	pivot_offset = size * 0.5
	clip_contents = false
	_apply_empty_button_styles()
	if background != null:
		background.visible = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_update_selected_state(button_pressed)


func bind_option(question_id: String, option: Dictionary, selected: bool, source_entries: Array) -> void:
	_question_id = question_id
	_option_id = String(option.get("id", ""))
	toggle_mode = true
	button_pressed = selected
	text = ""
	_update_selected_state(selected)
	if art != null:
		art.texture = _load_texture(_intel_image_path(String(option.get("image", ""))), fallback_option_image)
	if title_label != null:
		var option_title := String(option.get("title", _option_id))
		title_label.text = option_title
		title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22, 1.0) if selected else Color(1.0, 0.91, 0.74, 1.0))
	if source_label != null:
		source_label.visible = false
		source_label.text = ""
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


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _on_pressed() -> void:
	selected_requested.emit(_question_id, _option_id)


func _on_toggled(toggled_on: bool) -> void:
	_update_selected_state(toggled_on)


func _update_selected_state(selected: bool) -> void:
	if selected_outline != null:
		selected_outline.visible = false
	if background != null:
		background.material = _selected_highlight_material() if selected else null
		background.modulate = Color(1.08, 1.04, 0.86, 1.0) if selected else Color.WHITE
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22, 1.0) if selected else Color(1.0, 0.91, 0.74, 1.0))


func _apply_empty_button_styles() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("focus", empty)


func _selected_highlight_material() -> ShaderMaterial:
	if _selected_background_material != null:
		return _selected_background_material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 highlight_color : source_color = vec4(1.0, 0.70, 0.16, 1.0);
uniform float highlight_strength = 0.34;
uniform float brighten = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 color = mix(tex.rgb, highlight_color.rgb, highlight_strength * tex.a);
	color += brighten * tex.a;
	COLOR = vec4(color, tex.a);
}
"""
	_selected_background_material = ShaderMaterial.new()
	_selected_background_material.shader = shader
	return _selected_background_material


func _on_mouse_entered() -> void:
	_tween_scale(Vector2(hover_scale, hover_scale), hover_in_seconds, Tween.TRANS_QUAD)


func _on_mouse_exited() -> void:
	_tween_scale(Vector2.ONE, hover_out_seconds, Tween.TRANS_BACK)


func _tween_scale(target_scale: Vector2, duration: float, transition) -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", target_scale, duration).set_trans(transition)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
