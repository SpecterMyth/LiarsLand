extends Control

const CONFIG_LOCAL_PATH := "res://config.local.json"
const CONFIG_EXAMPLE_PATH := "res://config.example.json"
const ADVENTURE_SCREEN := preload("res://scripts/ui/adventure_screen.gd")
const DEBUG_KEYWORD_MODE := preload("res://scripts/ui/debug_keyword_mode.gd")
const ACTION_ANIMATION_OVERLAY := preload("res://scripts/ui/action_animation_overlay.gd")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const CHAPTER_LOADER := preload("res://scripts/core/chapter_loader.gd")


func _ready() -> void:
	var config := _load_config()
	_install_theme()
	_fill_control(self)
	if _is_action_animation_test_mode():
		_run_action_animation_visual_harness(_visual_test_action_from_query())
		return
	var use_debug := bool(config.get("game", {}).get("debug_keyword_mode", false))
	var screen: Control = DEBUG_KEYWORD_MODE.new() if use_debug else ADVENTURE_SCREEN.new()
	screen.set("config", config)
	_fill_control(screen)
	add_child(screen)


func _is_action_animation_test_mode() -> bool:
	if not OS.has_feature("web"):
		return false
	if not ClassDB.class_exists("JavaScriptBridge"):
		return false
	var query = JavaScriptBridge.eval("window.location.search", true)
	return String(query).contains("action_animation_test=1")


func _visual_test_action_from_query() -> String:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var action = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('action') || ''", true)
	return String(action).strip_edges().to_lower()


func _run_action_animation_visual_harness(single_action := "") -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.035, 0.024, 0.036, 1.0)
	add_child(backdrop)

	var state = GAME_STATE.new()
	state.load_chapter(CHAPTER_LOADER.load_chapter("res://data/chapter_01.json"))
	state.refresh_npc_choices()
	state.choose_npc(0)

	var overlay := ACTION_ANIMATION_OVERLAY.new()
	_fill_control(overlay)
	add_child(overlay)
	call_deferred("_play_action_animation_visual_sequence", overlay, state, single_action)


func _play_action_animation_visual_sequence(overlay: Control, state, single_action: String) -> void:
	await get_tree().process_frame
	var artifact_id := ""
	if state.artifacts.size() > 0:
		artifact_id = String(state.artifacts[0].get("id", ""))
	var sequence := [
		["leave", "player", "", "success"],
		["gift", "player", artifact_id, "victory"],
		["cast", "player", artifact_id, "failure"],
		["invite", "player", "", "victory"],
		["duel", "player", "", "failure"],
		["assassinate", "npc", "", "death"],
	]
	if not single_action.is_empty():
		for item in sequence:
			if item[0] == single_action:
				await get_tree().create_timer(0.6).timeout
				print("VISUAL_ACTION_START:%s" % single_action)
				await overlay.call("play_action", item[0], item[1], item[2], item[3], state)
				print("VISUAL_ACTION_DONE:%s" % single_action)
				return
	while true:
		for item in sequence:
			print("VISUAL_ACTION_START:%s" % item[0])
			await overlay.call("play_action", item[0], item[1], item[2], item[3], state)
			print("VISUAL_ACTION_DONE:%s" % item[0])
			await get_tree().create_timer(0.45).timeout


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
