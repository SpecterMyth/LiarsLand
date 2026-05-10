@tool
extends NinePatchRect
class_name CommonFrame

const TITLE_BAR := "title_bar"
const BACKGROUND_PANEL := "background_panel"

const GOLD := "gold"
const DARK_TEAL := "dark_teal"
const DARK_RED := "dark_red"
const DARK_PURPLE := "dark_purple"
const GRAY := "gray"

const COMMON_UI_ROOT := "res://assets/ui/common/"
const DEFAULT_TITLE_BAR_SIZE := Vector2(420, 88)
const DEFAULT_BACKGROUND_PANEL_SIZE := Vector2(520, 260)

const _TITLE_MARGIN := {
	"left": 100,
	"right": 100,
	"top": 0,
	"bottom": 0,
}
const _PANEL_MARGIN := {
	"left": 70,
	"right": 70,
	"top": 70,
	"bottom": 70,
}

@export_enum("title_bar", "background_panel") var frame_kind := TITLE_BAR:
	set(value):
		frame_kind = value
		_apply_exported_style()

@export_enum("gold", "dark_teal", "dark_red", "dark_purple", "gray") var frame_color := GOLD:
	set(value):
		frame_color = value
		_apply_exported_style()

@export var apply_default_size := true:
	set(value):
		apply_default_size = value
		_apply_exported_style()


func _ready() -> void:
	_apply_exported_style()


static func make_title_bar(color := GOLD, minimum_size := DEFAULT_TITLE_BAR_SIZE) -> CommonFrame:
	var frame := CommonFrame.new()
	frame.frame_kind = TITLE_BAR
	frame.frame_color = _normalize_color(color)
	apply_title_bar(frame, color, minimum_size)
	return frame


static func make_background_panel(color := GOLD, minimum_size := DEFAULT_BACKGROUND_PANEL_SIZE) -> CommonFrame:
	var frame := CommonFrame.new()
	frame.frame_kind = BACKGROUND_PANEL
	frame.frame_color = _normalize_color(color)
	apply_background_panel(frame, color, minimum_size)
	return frame


static func apply_title_bar(frame: NinePatchRect, color := GOLD, minimum_size := Vector2.ZERO) -> void:
	_apply(frame, TITLE_BAR, color, minimum_size)


static func apply_background_panel(frame: NinePatchRect, color := GOLD, minimum_size := Vector2.ZERO) -> void:
	_apply(frame, BACKGROUND_PANEL, color, minimum_size)


static func asset_path(kind := TITLE_BAR, color := GOLD) -> String:
	var prefix := "common_title_bar" if kind == TITLE_BAR else "common_background_panel"
	return COMMON_UI_ROOT + "%s_%s.png" % [prefix, _normalize_color(color)]


func _apply_exported_style() -> void:
	if not is_inside_tree() and texture == null:
		return
	var default_size := DEFAULT_TITLE_BAR_SIZE if frame_kind == TITLE_BAR else DEFAULT_BACKGROUND_PANEL_SIZE
	_apply(self, frame_kind, frame_color, default_size if apply_default_size else Vector2.ZERO)
	if not apply_default_size:
		custom_minimum_size = Vector2.ZERO


static func _apply(frame: NinePatchRect, kind := TITLE_BAR, color := GOLD, minimum_size := Vector2.ZERO) -> void:
	if frame == null:
		return
	var normalized_kind := TITLE_BAR if kind == TITLE_BAR else BACKGROUND_PANEL
	frame.texture = _load_texture(asset_path(normalized_kind, color))
	frame.draw_center = true
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if minimum_size != Vector2.ZERO:
		frame.custom_minimum_size = minimum_size
	var margins := _TITLE_MARGIN if normalized_kind == TITLE_BAR else _PANEL_MARGIN
	frame.patch_margin_left = margins["left"]
	frame.patch_margin_right = margins["right"]
	frame.patch_margin_top = margins["top"]
	frame.patch_margin_bottom = margins["bottom"]


static func _normalize_color(color: String) -> String:
	match color:
		GOLD, DARK_TEAL, DARK_RED, DARK_PURPLE, GRAY:
			return color
		_:
			return GOLD


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null
