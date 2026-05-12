extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _capture_full_app(Vector2i(1280, 720), "res://../tmp/guidelines_visual_1280.png")
	await _capture_page_scene(Vector2i(390, 844), "res://../tmp/guidelines_visual_390.png")
	print("LiarsLand guidelines visual exports passed.")
	quit(0)


func _capture_full_app(viewport_size: Vector2i, output_path: String) -> void:
	root.size = viewport_size
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var screen := main.get_child(0)
	var start_menu: Control = screen.get("start_menu")
	var rules_button: Button = start_menu.get("rules_button")
	rules_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var rules_panel: Control = screen.get("rules_panel")
	assert(rules_panel.visible)
	assert(rules_panel.get_node_or_null("MainPanel/Content/GuidelineEdit") != null)
	assert(rules_panel.get_node_or_null("MainPanel/Content/Footer/AutoActionCheck") != null)
	var growth_tab := rules_panel.get_node_or_null("MainPanel/Content/TabRow/GrowthTab") as Button
	assert(growth_tab == null or not growth_tab.visible)
	var texture := root.get_texture()
	if texture == null:
		push_error("Cannot capture guidelines screenshot because the root viewport has no texture. Run without --headless so Godot uses a drawable display driver.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Cannot capture guidelines screenshot because the root viewport image is empty.")
		quit(1)
		return
	assert(image.get_width() > 0)
	assert(image.get_height() > 0)
	assert(_has_visible_content(image))
	var err := image.save_png(output_path)
	assert(err == OK)
	main.queue_free()
	await process_frame


func _capture_page_scene(viewport_size: Vector2i, output_path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var packed: PackedScene = load("res://scenes/ui/guidelines_page.tscn")
	var page: Control = packed.instantiate()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(page)
	if page.has_method("set_guidelines"):
		page.call(
			"set_guidelines",
			"## 对外身份\n来自边境的灰狐代笔员，被临时推上议会席位。",
			"## 行动准则\n围绕罪名、票数和阵营利益谈判；先保命，再帮隐藏阵营赢下本章。",
			""
		)
	await process_frame
	await process_frame
	assert(page.get_node_or_null("MainPanel/Content/GuidelineEdit") != null)
	assert(page.get_node_or_null("MainPanel/Content/Footer/AutoActionCheck") != null)
	var growth_tab := page.get_node_or_null("MainPanel/Content/TabRow/GrowthTab") as Button
	assert(growth_tab == null or not growth_tab.visible)
	var texture := viewport.get_texture()
	assert(texture != null)
	var image := texture.get_image()
	assert(image != null and not image.is_empty())
	assert(_has_visible_content(image))
	var err := image.save_png(output_path)
	assert(err == OK)
	viewport.queue_free()
	await process_frame


func _has_visible_content(image: Image) -> bool:
	var samples := 0
	var varied := 0
	var first := image.get_pixel(0, 0)
	for y in range(0, image.get_height(), max(1, image.get_height() / 16)):
		for x in range(0, image.get_width(), max(1, image.get_width() / 16)):
			samples += 1
			var color := image.get_pixel(x, y)
			var diff: float = abs(color.r - first.r) + abs(color.g - first.g) + abs(color.b - first.b) + abs(color.a - first.a)
			if diff > 0.04:
				varied += 1
	return samples > 0 and varied > samples / 4
