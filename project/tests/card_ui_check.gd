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
	assert(screen != null)
	assert(screen.get("selection_panel") != null)
	assert(screen.get("shop_panel") != null)
	assert(screen.get("upgrade_panel") != null)

	screen.state.refresh_npc_choices()
	screen.selected_npc_choice = -1
	screen._render_npc_selection_page()
	await process_frame
	await process_frame
	assert(screen.selection_panel.visible)
	var choose_button := _find_button(screen.selection_panel, "选择")
	assert(choose_button != null)
	choose_button.emit_signal("pressed")
	assert(screen.selected_npc_choice == 0)
	screen.selection_panel.visible = false

	screen.state.refresh_shop_items()
	screen._render_shop()
	await process_frame
	await process_frame
	assert(screen.shop_panel.visible)
	assert(_find_button(screen.shop_panel, "购买") != null)
	assert(_count_nodes(screen.shop_panel, TextureRect) >= 8)
	screen.shop_panel.visible = false

	screen.selected_upgrade = {}
	screen.pending_stat_points = 3
	screen._render_ascension_page(true, true)
	await process_frame
	await process_frame
	assert(screen.upgrade_panel.visible)
	assert(_find_button(screen.upgrade_panel, "+") != null)
	assert(_find_button(screen.upgrade_panel, "−") != null)
	assert(_find_button(screen.upgrade_panel, "确认升华") != null)
	assert(_find_button(screen.upgrade_panel, "选择统治") != null)

	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	assert(screen.upgrade_panel.visible)
	print("LiarsLand card UI checks passed.")
	quit(0)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and String(node.text) == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _count_nodes(node: Node, type) -> int:
	var count := 1 if is_instance_of(node, type) else 0
	for child in node.get_children():
		count += _count_nodes(child, type)
	return count
