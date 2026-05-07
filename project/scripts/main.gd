extends Control

const CONFIG_LOCAL_PATH := "res://config.local.json"
const CONFIG_EXAMPLE_PATH := "res://config.example.json"
const ADVENTURE_SCREEN := preload("res://scripts/ui/adventure_screen.gd")
const DEBUG_KEYWORD_MODE := preload("res://scripts/ui/debug_keyword_mode.gd")


func _ready() -> void:
	var config := _load_config()
	_install_theme()
	_fill_control(self)
	var use_debug := bool(config.get("game", {}).get("debug_keyword_mode", false))
	var screen: Control = DEBUG_KEYWORD_MODE.new() if use_debug else ADVENTURE_SCREEN.new()
	screen.set("config", config)
	_fill_control(screen)
	add_child(screen)


func _fill_control(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _install_theme() -> void:
	var font_path := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
	if not ResourceLoader.exists(font_path):
		return
	var ui_theme := Theme.new()
	ui_theme.default_font = load(font_path)
	ui_theme.default_font_size = 16
	theme = ui_theme


func _load_config() -> Dictionary:
	if OS.has_feature("web"):
		return {}
	var path := CONFIG_LOCAL_PATH if FileAccess.file_exists(CONFIG_LOCAL_PATH) else CONFIG_EXAMPLE_PATH
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
