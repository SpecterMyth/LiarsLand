extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_set_viewport_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var screen := main.get_child(0)
	_must(screen.get("dialogue_view") != null, "dialogue_view missing")
	_must(screen.get("recent_view") != null, "recent_view missing")
	_must(screen.get("info_button") != null, "info_button missing")
	_must(screen.get("bag_button") != null, "bag_button missing")
	_must(screen.get("history_button") != null, "history_button missing")
	_must(screen.get("rules_button") != null, "rules_button missing")
	_must(screen.get("status_button") != null, "status_button missing")
	_must(screen.get("settings_button") != null, "settings_button missing")
	_must(screen.get("start_menu") != null, "start_menu missing")
	_must(screen.get("common_modal") != null, "common_modal missing")
	_must(screen.get("drawer") != null, "drawer missing")
	_must(screen.get("rules_panel") != null, "rules_panel missing")
	_must(screen.get("auto_decide_check") != null, "auto_decide_check missing")
	_must(screen.get("auto_growth_check") != null, "auto_growth_check missing")
	_must(screen.get("upgrade_panel") != null, "upgrade_panel missing")
	_must(screen.get("progress_label") != null, "progress_label missing")
	_must(screen.get("npc_public_label") != null, "npc_public_label missing")
	_must(screen.get("card_grid") != null, "card_grid missing")
	_must(screen.get("background_texture") != null, "background_texture missing")
	_must(screen.get("player_portrait") != null, "player_portrait missing")
	_must(screen.get("npc_portrait") != null, "npc_portrait missing")
	screen.state.choose_npc(0)
	screen.call("_set_current_npc_assets")
	var dialogue: Control = screen.get("dialogue_view")
	var recent: Control = screen.get("recent_view")
	var info_button: Control = screen.get("info_button")
	var settings_button: Control = screen.get("settings_button")
	var start_menu: Control = screen.get("start_menu")
	var drawer: Control = screen.get("drawer")
	var rules_panel: Control = screen.get("rules_panel")
	var settings_panel: Control = screen.get("settings_panel")
	var upgrade_panel: Control = screen.get("upgrade_panel")
	var modal_backdrop: Button = screen.get("modal_backdrop")
	var card_grid: Control = screen.get("card_grid")
	var background: TextureRect = screen.get("background_texture")
	var player_portrait: TextureRect = screen.get("player_portrait")
	var npc_portrait: TextureRect = screen.get("npc_portrait")
	var lower_box: TextureRect = screen.get("lower_box")
	var upper_box: TextureRect = screen.get("upper_box")
	var current_nameplate: TextureRect = screen.get("current_nameplate")
	var previous_nameplate: TextureRect = screen.get("previous_nameplate")
	var side_shadow_left: Control = screen.get("side_shadow_left")
	var side_shadow_right: Control = screen.get("side_shadow_right")
	_must(background.texture != null, "background texture missing")
	_must(not background.texture.resource_path.ends_with("dialogue_base.png"), "background should not use dialogue_base fallback")
	_must(player_portrait.texture != null, "player portrait missing")
	_must(npc_portrait.texture != null, "npc portrait missing")
	_must(not player_portrait.visible, "player portrait should start hidden")
	_must(not npc_portrait.visible, "npc portrait should start hidden")
	_must(player_portrait.flip_h, "player portrait should be flipped")
	_must(lower_box != null, "lower dialogue box missing")
	_must(upper_box != null, "upper dialogue box missing")
	_must(current_nameplate != null, "current nameplate missing")
	_must(previous_nameplate != null, "previous nameplate missing")
	_must(settings_panel != null, "settings panel missing")
	_must(side_shadow_left != null, "left side shadow missing")
	_must(side_shadow_right != null, "right side shadow missing")
	_must(modal_backdrop != null, "modal backdrop missing")
	_must(not side_shadow_left.visible, "left side shadow should start hidden")
	_must(not side_shadow_right.visible, "right side shadow should start hidden")
	_must(not lower_box.visible, "lower box should start hidden")
	_must(not upper_box.visible, "upper box should start hidden")
	_must(lower_box.z_index > player_portrait.z_index, "lower box should render above player portrait")
	_must(upper_box.z_index > npc_portrait.z_index, "upper box should render above npc portrait")
	_must(not dialogue.scroll_active, "dialogue scroll should be inactive")
	_must(not recent.scroll_active, "recent scroll should be inactive")
	_must(dialogue.size.x > 480, "desktop dialogue too narrow")
	_must(dialogue.size.y >= 45, "desktop dialogue too short")
	_must(dialogue.global_position.y + dialogue.size.y <= 720, "desktop dialogue overflows")
	_must(recent.size.x > 500, "recent dialogue too narrow")
	_must(recent.size.y >= 40, "recent dialogue too short")
	_must(info_button.size.x >= 60, "info button too narrow")
	_must(info_button.global_position.x > 1160, "info button misplaced")
	_must(settings_button.global_position.x > 1160, "settings button misplaced")
	_must(start_menu.visible, "start menu should be visible")
	_must(start_menu.get("start_button") != null, "start menu start button missing")
	_must(start_menu.get("rules_button") != null, "start menu rules button missing")
	_must(start_menu.get("settings_button") != null, "start menu settings button missing")
	var menu_start_button: Button = start_menu.get("start_button")
	var menu_rules_button: Button = start_menu.get("rules_button")
	var menu_settings_button: Button = start_menu.get("settings_button")
	_must(menu_start_button.size.x > menu_rules_button.size.x, "start button should be wider than rules button")
	menu_rules_button.emit_signal("pressed")
	await process_frame
	assert(rules_panel.visible)
	assert(rules_panel.get_node_or_null("MainPanel/Content/TabRow/IdentityTab") != null)
	assert(rules_panel.get_node_or_null("MainPanel/Content/GuidelineEdit") != null)
	var behavior_tab := rules_panel.get_node_or_null("MainPanel/Content/TabRow/BehaviorTab") as Button
	assert(behavior_tab != null)
	behavior_tab.emit_signal("pressed")
	await process_frame
	var growth_tab := rules_panel.get_node_or_null("MainPanel/Content/TabRow/GrowthTab") as Button
	assert(growth_tab != null)
	growth_tab.emit_signal("pressed")
	await process_frame
	var guideline_edit := rules_panel.get_node_or_null("MainPanel/Content/GuidelineEdit") as TextEdit
	assert(guideline_edit != null)
	assert(guideline_edit.size.x > 400)
	assert(guideline_edit.size.y > 200)
	modal_backdrop.emit_signal("pressed")
	await process_frame
	menu_settings_button.emit_signal("pressed")
	await process_frame
	assert(settings_panel.visible)
	modal_backdrop.emit_signal("pressed")
	await process_frame
	assert(not drawer.visible)
	assert(not rules_panel.visible)
	assert(not upgrade_panel.visible)
	assert(card_grid.get_child_count() >= 2)
	screen._set_active_speaker("player")
	assert(is_equal_approx(npc_portrait.modulate.a, 1.0))
	assert(npc_portrait.modulate.r < 0.5)
	screen._set_active_speaker("npc")
	assert(is_equal_approx(player_portrait.modulate.a, 1.0))
	assert(player_portrait.modulate.r < 0.5)
	screen._set_dialogue_visible(true)
	assert(lower_box.visible)
	assert(player_portrait.visible)
	assert(npc_portrait.visible)
	assert(side_shadow_left.visible)
	assert(side_shadow_right.visible)
	screen._store_final_dialogue("对方", "previous line")
	screen._show_previous_final_if_ready()
	await create_timer(0.35).timeout
	assert(upper_box.visible)
	assert(is_equal_approx(upper_box.modulate.a, 1.0))
	var wrapped_two_line_previous := "手续放旁边。你的统治法器是什么？请登记三件完成统治所需的法器，没登清楚不能进夜市。"
	screen._store_final_dialogue("对方", wrapped_two_line_previous)
	screen._show_previous_final_if_ready()
	await create_timer(0.35).timeout
	assert(not recent.scroll_following)
	assert(recent.size.y >= 72)
	if recent.has_method("get_content_height"):
		assert(float(recent.call("get_content_height")) <= recent.size.y)
	var three_line_previous := "第一行文字完整显示。\n第二行文字完整显示。\n第三行文字完整显示。"
	screen._store_final_dialogue("对方", three_line_previous)
	screen._show_previous_final_if_ready()
	await create_timer(0.35).timeout
	assert(recent.size.y >= 72)
	assert(not recent.scroll_following)
	assert(recent.get_line_count() == 3)
	if recent.has_method("get_content_height"):
		assert(float(recent.call("get_content_height")) <= recent.size.y)
	var four_line_previous := "第一行应被隐藏。\n第二行应该显示。\n第三行应该显示。\n第四行应该显示。"
	screen._store_final_dialogue("对方", four_line_previous)
	screen._show_previous_final_if_ready()
	await create_timer(0.35).timeout
	assert(not recent.scroll_following)
	assert(recent.get_line_count() == 3)
	if recent.has_method("get_content_height"):
		assert(float(recent.call("get_content_height")) <= recent.size.y)
	screen._set_current_dialogue_role("player")
	await create_timer(0.25).timeout
	assert(is_equal_approx(lower_box.scale.x, 1.0))
	info_button.emit_signal("pressed")
	await process_frame
	var intel_panel: Control = screen.get("intel_panel")
	assert(intel_panel != null)
	assert(intel_panel.visible)
	assert(modal_backdrop.visible)
	modal_backdrop.emit_signal("pressed")
	await process_frame
	assert(not intel_panel.visible)
	assert(not modal_backdrop.visible)
	_set_viewport_size(Vector2i(390, 844))
	await process_frame
	await process_frame
	_must(menu_start_button.size.x <= 390, "mobile start button wider than viewport")
	_must(menu_rules_button.size.x <= 390, "mobile rules button wider than viewport")
	_must(menu_rules_button.global_position.y + menu_rules_button.size.y <= menu_settings_button.global_position.y, "mobile menu buttons overlap")
	_must(dialogue.size.x > 240, "mobile dialogue too narrow")
	_must(dialogue.size.y >= 35, "mobile dialogue too short")
	_must(dialogue.global_position.y + dialogue.size.y <= 844, "mobile dialogue overflows viewport")
	screen.call_deferred("_on_start_pressed")
	await process_frame
	await process_frame
	_must(not start_menu.visible, "start menu should hide after start")
	_must(screen.get("running"), "screen should be running after start")
	_must(screen.get("selection_panel").visible, "selection panel should be visible after start")
	print("LiarsLand visual layout checks passed.")
	quit(0)


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _set_viewport_size(size: Vector2i) -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = size
	DisplayServer.window_set_size(size)
	root.size = size
