extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for screen_id in ["round_select", "dialogue", "shop", "ascension", "intel", "inventory", "history", "rules", "status", "settings"]:
		await _assert_debug_screen(screen_id)
	print("Debug screen preview checks passed.")
	quit(0)


func _assert_debug_screen(screen_id: String) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	assert(packed != null)
	var main := packed.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame
	var screen := main.get_child(0) as Control
	assert(screen != null)
	screen.call("_show_debug_screen_preview", screen_id)
	await process_frame
	await process_frame
	if screen_id == "shop":
		var shop_panel := screen.get("shop_panel") as Control
		assert(shop_panel != null)
		assert(shop_panel.visible)
	main.queue_free()
	await process_frame
