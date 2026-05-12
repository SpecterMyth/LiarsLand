@tool
extends TextureRect
class_name RoundCounterPanel

const FONT_PATH := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
const TEXTURE_PATH := "res://assets/ui/common/title_banner_dark_small.png"

@export var round_text := "第 1 回合":
	set(value):
		round_text = value
		_apply_text()

@onready var label := get_node_or_null("RoundCounterLabel") as Label


func _ready() -> void:
	if texture == null and ResourceLoader.exists(TEXTURE_PATH):
		texture = load(TEXTURE_PATH)
	_apply_text()


func set_round(current: int, _total: int = 0) -> void:
	round_text = "第 %d 回合" % [current]
	_apply_text()


func set_text(value: String) -> void:
	round_text = value
	_apply_text()


func _apply_text() -> void:
	if label == null:
		label = get_node_or_null("RoundCounterLabel") as Label
	if label == null:
		return
	label.text = round_text
	var font := _load_font()
	if font != null:
		label.add_theme_font_override("font", font)


func _load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH)
	return null
