extends SceneTree

const PAGES := [
	{
		"scene": "res://scenes/ui/history_page.tscn",
		"output": "res://../ui/visual_tests/history_page_runtime.png",
		"method": "set_history",
		"args": ["玩家：我们从哪一份债契开始？\n对手：从被烧掉的那份开始。\n玩家：那就先谈谁点的火。", ["发现：对手避开了钟楼证词", "行动：玩家保留最后一件法器"], "第 1 / 3 章，回合 2 / 3"]
	},
	{
		"scene": "res://scenes/ui/status_page.tscn",
		"output": "res://../ui/visual_tests/status_page_runtime.png"
	},
	{
		"scene": "res://scenes/ui/settings_page.tscn",
		"output": "res://../ui/visual_tests/settings_page_runtime.png"
	}
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for spec in PAGES:
		await _capture_page(spec)
	print("Gameplay overlay visual exports passed.")
	quit(0)


func _capture_page(spec: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var packed := load(String(spec.get("scene", ""))) as PackedScene
	assert(packed != null)
	var page := packed.instantiate() as Control
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(page)
	if spec.has("method") and page.has_method(String(spec["method"])):
		page.callv(String(spec["method"]), spec.get("args", []))
	await process_frame
	await process_frame
	var texture := viewport.get_texture()
	assert(texture != null)
	var image := texture.get_image()
	assert(image != null and not image.is_empty())
	assert(_has_visible_content(image))
	var err := image.save_png(String(spec.get("output", "")))
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
