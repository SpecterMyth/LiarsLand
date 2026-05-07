extends Control
class_name StartMenu

signal start_requested
signal rules_requested
signal settings_requested

const UI_ROOT := "res://assets/generated/ui/start_menu/"
const BG_PATH := UI_ROOT + "start_game_reference.png"

var start_button: Button


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

	start_button = Button.new()
	start_button.name = "StartGameButton"
	start_button.text = ""
	start_button.tooltip_text = _utf8([229, 188, 128, 229, 167, 139, 230, 184, 184, 230, 136, 143])
	start_button.flat = true
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	start_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	start_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	start_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	start_button.pressed.connect(func(): start_requested.emit())
	add_child(start_button)


func _apply_responsive_layout() -> void:
	if start_button == null:
		return
	var viewport_size: Vector2 = size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = get_viewport_rect().size

	start_button.size = Vector2(viewport_size.x * 0.35, viewport_size.y * 0.15)
	start_button.position = Vector2(viewport_size.x * 0.34, viewport_size.y * 0.64)


func _texture_path(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _utf8(bytes: Array) -> String:
	return PackedByteArray(bytes).get_string_from_utf8()
