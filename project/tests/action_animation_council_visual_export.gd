extends SceneTree

const OverlayScript := preload("res://scripts/ui/action_animation_overlay.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")

const OUT_DIR := "res://../ui/visual_tests/action_animation_council"

var _visual_playing := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1672, 941)
	var out_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.035, 0.024, 0.036, 1.0)
	root.add_child(backdrop)
	var state = GameStateScript.new()
	state.load_chapter(ChapterLoaderScript.load_chapter("res://data/chapter_01.json"))
	state.refresh_npc_choices()
	state.choose_npc(0)
	var overlay := OverlayScript.new()
	root.add_child(overlay)
	await process_frame
	await process_frame
	var actions := [
		{"name": "retreat", "role": "player", "outcome": "success", "payload": {"action": "retreat"}},
		{"name": "declare_tendency", "role": "player", "outcome": "success", "payload": {"action": "declare_tendency", "target_crime_id": "duck_house_expense", "vote": "guilty"}},
		{"name": "cast_vote", "role": "player", "outcome": "success", "payload": {"action": "cast_vote", "target_crime_id": "duck_house_expense", "vote": "guilty"}},
		{"name": "offer_trade", "role": "player", "outcome": "success", "payload": {"action": "offer_trade", "target_crime_id": "duck_house_expense", "vote": "guilty"}}
	]
	for item in actions:
		await _play_and_capture(overlay, state, item, out_dir)
	print("Council action animation visual export passed: %s" % out_dir)
	quit(0)


func _play_and_capture(overlay: Control, state, item: Dictionary, out_dir: String) -> void:
	var action := String(item.get("name", ""))
	print("visual export action: %s" % action)
	_visual_playing = true
	call_deferred("_play_overlay_action", overlay, state, item)
	await process_frame
	await create_timer(0.7).timeout
	_must_visible_and_fullscreen(overlay, action, "prepare")
	_save_frame(out_dir, "%s_01_prepare.png" % action)
	await create_timer(1.25).timeout
	_must_visible_and_fullscreen(overlay, action, "burst")
	_save_frame(out_dir, "%s_02_burst.png" % action)
	await create_timer(1.15).timeout
	_must_visible_and_fullscreen(overlay, action, "result")
	_save_frame(out_dir, "%s_03_result.png" % action)
	while _visual_playing:
		await process_frame
	_must(not overlay.visible, "%s did not finish" % action)
	await create_timer(0.18).timeout


func _play_overlay_action(overlay: Control, state, item: Dictionary) -> void:
	await overlay.play_action(
		String(item.get("name", "")),
		String(item.get("role", "player")),
		"",
		String(item.get("outcome", "success")),
		state,
		null,
		null,
		item.get("payload", {})
	)
	_visual_playing = false


func _save_frame(out_dir: String, filename: String) -> void:
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(filename)
	var err := image.save_png(path)
	_must(err == OK, "failed to save %s" % path)


func _must_visible_and_fullscreen(overlay: Control, action: String, phase: String) -> void:
	_must(overlay.visible, "%s overlay not visible during %s" % [action, phase])
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	_must(viewport_rect.encloses(overlay.get_global_rect()), "%s overlay is clipped during %s" % [action, phase])
	var debug_state: Dictionary = overlay.call("debug_actor_state")
	_must(bool(debug_state.get("player_visible", false)), "%s player missing during %s" % [action, phase])


func _must(condition: bool, message := "visual export assertion failed") -> void:
	if condition:
		return
	push_error(message)
	quit(1)
