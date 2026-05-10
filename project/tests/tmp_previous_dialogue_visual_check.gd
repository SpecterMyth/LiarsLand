extends SceneTree

const SHOT_PATH := "res://../tmp/previous_player_dialogue_visual_check.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	await process_frame

	var test_viewport := SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate() as Control
	test_viewport.add_child(main)
	await process_frame
	await process_frame

	var screen: Control = main.get_child(0)
	var start_menu := screen.get("start_menu") as Control
	if start_menu != null:
		start_menu.hide()
	screen.state.choose_npc(0)
	screen.call("_set_current_npc_assets")
	screen.call("_set_dialogue_visible", true)
	var sample_text := ""
	for i in range(45):
		sample_text += "测试"
	screen.call("_store_final_dialogue", "你方", sample_text)
	screen.call("_show_previous_final_if_ready")
	await create_timer(0.45).timeout

	var upper_box := screen.get("upper_box") as TextureRect
	var recent_view := screen.get("recent_view") as RichTextLabel
	if upper_box == null or not upper_box.visible or recent_view == null:
		push_error("Previous dialogue did not become visible.")
		quit(1)
		return
	print("upper_box=", upper_box.global_position, " ", upper_box.size)
	print("recent_view=", recent_view.global_position, " ", recent_view.size)
	if recent_view.size.y < 64.0:
		push_error("Previous dialogue text area is too short.")
		quit(1)
		return
	if recent_view.global_position.y <= upper_box.global_position.y + 14.0:
		push_error("Previous dialogue text area is too close to the top border.")
		quit(1)
		return
	if recent_view.global_position.y + recent_view.size.y >= upper_box.global_position.y + upper_box.size.y - 12.0:
		push_error("Previous dialogue text area is too close to the bottom border.")
		quit(1)
		return

	await process_frame
	await process_frame
	var image := test_viewport.get_texture().get_image()
	var error := image.save_png(SHOT_PATH)
	if error != OK:
		push_error("Failed to save previous dialogue screenshot.")
		quit(1)
		return
	print("Previous dialogue visual check saved: %s" % ProjectSettings.globalize_path(SHOT_PATH))
	quit(0)
