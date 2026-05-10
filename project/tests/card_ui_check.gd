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
	_must(screen != null, "screen missing")
	_must(screen.get("selection_panel") != null, "selection panel missing")
	_must(screen.get("shop_panel") != null, "shop panel missing")
	_must(screen.get("upgrade_panel") != null, "upgrade panel missing")

	screen.state.refresh_npc_choices()
	screen.selected_npc_choice = -1
	screen._render_npc_selection_page()
	await process_frame
	await process_frame
	_must(screen.selection_panel.visible, "selection panel should be visible")
	var choose_button := _find_button(screen.selection_panel, "选择")
	_must(choose_button != null, "choose button missing")
	choose_button.emit_signal("pressed")
	_must(screen.selected_npc_choice == 0, "choose button should set selected_npc_choice")
	screen.selection_panel.visible = false

	screen.state.refresh_shop_items()
	screen._render_shop()
	await process_frame
	await process_frame
	_must(screen.shop_panel.visible, "shop panel should be visible")
	_must(_find_button(screen.shop_panel, "购买") != null, "buy button missing")
	_must(_count_nodes(screen.shop_panel, TextureRect) >= 8, "shop should contain texture assets")
	screen.shop_panel.visible = false

	screen.selected_upgrade = {}
	screen.pending_stat_points = 3
	screen._render_ascension_page(true, true)
	await process_frame
	await process_frame
	_must(screen.upgrade_panel.visible, "upgrade panel should be visible")
	_must(_find_button(screen.upgrade_panel, "+") != null, "plus button missing")
	_must(_find_button(screen.upgrade_panel, "−") != null or _find_button(screen.upgrade_panel, "-") != null, "minus button missing")
	_must(_find_button(screen.upgrade_panel, "确认升华") != null, "ascension confirm button missing")
	_must(_find_button(screen.upgrade_panel, "选择统治") != null, "dominion select button missing")

	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	_must(screen.upgrade_panel.visible, "upgrade panel should remain visible on mobile")
	print("LiarsLand card UI checks passed.")
	quit(0)


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


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
