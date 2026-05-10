extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var screen := main.get_child(0)
	screen.state.choose_npc(0)
	screen.call("_set_current_npc_assets")
	var start_menu := screen.get("start_menu") as Control
	if start_menu != null:
		start_menu.visible = false
	screen.call("_set_dialogue_visible", true)

	var two_line_text := "手续放旁边。你的统治法器是什么？请登记三件完成统治所需的法器，没登清楚不能进夜市。"
	screen.call("_store_final_dialogue", "对方", two_line_text)
	screen.call("_show_previous_final_if_ready")
	await create_timer(0.45).timeout
	await process_frame

	var recent := screen.get("recent_view") as RichTextLabel
	assert(recent != null)
	assert(not recent.scroll_following)
	if recent.has_method("get_content_height"):
		assert(float(recent.call("get_content_height")) <= recent.size.y)

	var two_line_image := root.get_texture().get_image()
	var two_line_path := ProjectSettings.globalize_path("res://tmp/previous_dialogue_two_line_check.png")
	var two_line_error := two_line_image.save_png(two_line_path)
	assert(two_line_error == OK)

	var three_line_text := "第一行文字完整显示。\n第二行文字完整显示。\n第三行文字完整显示。"
	screen.call("_store_final_dialogue", "对方", three_line_text)
	screen.call("_show_previous_final_if_ready")
	await create_timer(0.45).timeout
	await process_frame

	assert(recent.get_line_count() == 3)
	assert(not recent.scroll_following)
	if recent.has_method("get_content_height"):
		assert(float(recent.call("get_content_height")) <= recent.size.y)

	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://tmp/previous_dialogue_three_line_check.png")
	var error := image.save_png(path)
	assert(error == OK)

	var four_line_text := "第一行应被隐藏。\n第二行应该显示。\n第三行应该显示。\n第四行应该显示。"
	screen.call("_store_final_dialogue", "对方", four_line_text)
	screen.call("_show_previous_final_if_ready")
	await create_timer(0.45).timeout
	await process_frame

	assert(recent.get_line_count() == 3)
	assert(not recent.scroll_following)
	if recent.has_method("get_content_height"):
		assert(float(recent.call("get_content_height")) <= recent.size.y)

	var four_line_image := root.get_texture().get_image()
	var four_line_path := ProjectSettings.globalize_path("res://tmp/previous_dialogue_four_line_check.png")
	var four_line_error := four_line_image.save_png(four_line_path)
	assert(four_line_error == OK)

	var player_four_line_text := "通融查个账？我确实只是个拿笔杆子的，您要法器我是真拿不出来。不过，我这商队的名单里，若是有不该出现在边门的人，那可是关乎军纪的大事。您若是因为我没交法器就赶我走，反倒会漏掉真正该查的人。"
	screen.call("_store_final_dialogue", "你方", player_four_line_text)
	screen.call("_show_previous_final_if_ready")
	await create_timer(0.45).timeout
	await process_frame

	assert(recent.get_line_count() <= 3)
	assert(not recent.scroll_following)
	if recent.has_method("get_content_height"):
		assert(float(recent.call("get_content_height")) <= recent.size.y)

	var player_four_line_image := root.get_texture().get_image()
	var player_four_line_path := ProjectSettings.globalize_path("res://tmp/previous_dialogue_player_four_line_check.png")
	var player_four_line_error := player_four_line_image.save_png(player_four_line_path)
	assert(player_four_line_error == OK)

	print("Saved previous dialogue two-line visual check: %s" % two_line_path)
	print("Saved previous dialogue three-line visual check: %s" % path)
	print("Saved previous dialogue four-line visual check: %s" % four_line_path)
	print("Saved previous dialogue player four-line visual check: %s" % player_four_line_path)
	quit(0)
