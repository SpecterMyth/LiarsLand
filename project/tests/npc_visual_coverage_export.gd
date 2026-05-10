extends SceneTree

const OUTPUT_DIR := "res://../tmp/npc_visual_coverage"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_set_viewport_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var screen: Control = main.get_child(0)
	assert(screen != null)
	assert(screen.state != null)
	assert(screen.state.npcs.size() == 20)

	for i in range(screen.state.npcs.size()):
		var npc: Dictionary = screen.state.npcs[i]
		var npc_id := String(npc.get("id", "npc"))
		_render_selection(screen, i)
		await _settle()
		_save("select_%02d_%s_desktop.png" % [i + 1, npc_id])

		_render_dialogue(screen, i, Vector2i(1280, 720))
		await _settle()
		_assert_dialogue_assets(screen, npc)
		_save("dialogue_%02d_%s_desktop.png" % [i + 1, npc_id])

		_render_shop(screen, i, Vector2i(1280, 720))
		await _settle()
		_save("shop_%02d_%s_desktop.png" % [i + 1, npc_id])

		_render_dialogue(screen, i, Vector2i(390, 844))
		await _settle()
		_assert_dialogue_assets(screen, npc)
		_save("dialogue_%02d_%s_mobile.png" % [i + 1, npc_id])

	print("NPC visual coverage screenshots saved: %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _render_selection(screen: Control, npc_index: int) -> void:
	_set_viewport_size(Vector2i(1280, 720))
	if screen.has_method("_hide_debug_flow_pages"):
		screen.call("_hide_debug_flow_pages")
	if screen.start_menu != null:
		screen.start_menu.visible = false
	var count: int = screen.state.npcs.size()
	screen.state.npc_choices.clear()
	screen.state.npc_choices.append(npc_index)
	screen.state.npc_choices.append((npc_index + 1) % count)
	screen.state.npc_choices.append((npc_index + 2) % count)
	screen.call("_render_npc_selection_page")


func _render_dialogue(screen: Control, npc_index: int, viewport_size: Vector2i) -> void:
	_set_viewport_size(viewport_size)
	_hide_flow_panels(screen)
	screen.state.current_npc_index = npc_index
	screen.call("_set_current_npc_assets")
	screen.call("_set_dialogue_visible", true)
	screen.call("_set_current_dialogue_role", "npc")
	var dialogue := screen.get("dialogue_view") as RichTextLabel
	if dialogue != null:
		dialogue.clear()
		dialogue.append_text("[font_size=20][color=#130905]视觉测试：当前 NPC 背景、半身立绘与姓名牌应清晰可见。[/color][/font_size]")


func _render_shop(screen: Control, npc_index: int, viewport_size: Vector2i) -> void:
	_set_viewport_size(viewport_size)
	_hide_flow_panels(screen)
	screen.state.current_npc_index = npc_index
	screen.state.refresh_shop_items()
	screen.call("_render_shop")


func _hide_flow_panels(screen: Control) -> void:
	for name in ["selection_panel", "shop_panel", "ascension_box", "intel_panel", "drawer", "rules_panel", "settings_panel"]:
		var node = screen.get(name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
	if screen.start_menu != null:
		screen.start_menu.visible = false


func _assert_dialogue_assets(screen: Control, npc: Dictionary) -> void:
	var background := screen.get("background_texture") as TextureRect
	var npc_portrait := screen.get("npc_portrait") as TextureRect
	var player_portrait := screen.get("player_portrait") as TextureRect
	assert(background != null and background.texture != null)
	assert(npc_portrait != null and npc_portrait.texture != null)
	assert(player_portrait != null and player_portrait.texture != null)
	assert(String(npc.get("background", "")) in background.texture.resource_path)
	assert(String(npc.get("portrait", "")).replace(".png", "_half.png") in npc_portrait.texture.resource_path)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _set_viewport_size(size: Vector2i) -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = size
	DisplayServer.window_set_size(size)
	root.size = size


func _save(file_name: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		push_error("Cannot capture viewport texture.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image is empty.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var result := image.save_png(path)
	if result != OK:
		push_error("Failed to save screenshot: %s" % path)
		quit(1)
