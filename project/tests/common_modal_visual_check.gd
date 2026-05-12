extends SceneTree

const SHOT_DIR := "res://../ui/visual_tests/common_modal/"

var screen: Control
var modal: Control
var test_viewport: SubViewport


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--modal-narrow"):
		await _setup_screen(Vector2i(390, 844))
		await _capture_modal_cases("narrow")
	elif args.has("--modal-desktop"):
		await _setup_screen(Vector2i(1280, 720))
		await _capture_modal_cases("desktop")
	else:
		await _setup_screen(Vector2i(1280, 720))
		await _capture_modal_cases("desktop")
		await _setup_screen(Vector2i(390, 844))
		await _capture_modal_cases("narrow")
	print("Common modal visual checks passed.")
	quit(0)


func _setup_screen(size: Vector2i) -> void:
	await _setup_viewport(size)
	if test_viewport != null:
		test_viewport.queue_free()
		await process_frame
	test_viewport = SubViewport.new()
	test_viewport.size = size
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	test_viewport.add_child(main)
	await process_frame
	await process_frame
	screen = main.get_child(0)
	modal = screen.get("common_modal")
	_expect(modal != null, "missing common modal")
	if screen.get("start_menu") != null:
		screen.get("start_menu").hide()
	screen.state.choose_npc(0)
	screen.state.player["inventory"] = ["moon_lantern", "silver_needle", "hidden_map", "moon_lantern"]
	screen.call("_set_current_npc_assets")
	screen.call("_set_dialogue_visible", true)
	await process_frame


func _setup_viewport(size: Vector2i) -> void:
	root.size = size
	DisplayServer.window_set_size(size)
	await process_frame
	await process_frame


func _capture_modal_cases(prefix: String) -> void:
	await _capture_message(prefix, "player_action", "确认玩家行动", "你方角色准备执行：决斗\n法器：月灯\n允许后会立即结算本次行动。", "确定", "取消")
	await _capture_countdown(prefix, "countdown_action")
	await _capture_choice(prefix, "artifact_select")
	await _capture_message(prefix, "npc_gift", "对方提出交易", "绯尾侯爵愿意赠送：银针\n接受后该法器会加入你的背包。", "接受", "拒绝")
	await _capture_message(prefix, "npc_exchange", "对方提出交易", "绯尾侯爵想用 隐秘地图 交换你的 月灯。\n接受后交易会立即完成。", "接受", "拒绝")
	await _capture_message(prefix, "submit_world_intel", "提交世界设定档案", "提交后无法修改。全部 6 条设定正确才会胜利，任意错误都会失败。", "提交", "返回检查")


func _capture_message(prefix: String, name: String, title: String, body: String, confirm_text: String, cancel_text: String) -> void:
	var box := {}
	_run_message(box, title, body, confirm_text, cancel_text)
	await _wait_for_modal()
	_assert_modal_clean()
	await _save_screenshot("%s_%s.png" % [prefix, name])
	_press_modal_button("CancelButton")
	await _wait_for_result(box)
	_expect(box.get("result", true) == false, "cancel should resolve false for %s" % name)


func _capture_countdown(prefix: String, name: String) -> void:
	var box := {}
	_run_countdown(box, "确认玩家行动", "行动：直接投票；投票：有罪\n罪名：收金条后替金主办事")
	await _wait_for_modal()
	_assert_modal_clean()
	_assert_countdown_footer_clean()
	await _save_screenshot("%s_%s.png" % [prefix, name])
	_press_modal_button("ConfirmButton")
	await _wait_for_result(box)
	_expect(box.get("result", false) == true, "confirm should immediately accept countdown modal")


func _capture_choice(prefix: String, name: String) -> void:
	var box := {}
	var choices := [
		{"label": "月灯 x2", "value": "moon_lantern"},
		{"label": "银针 x1", "value": "silver_needle"},
		{"label": "隐秘地图 x1", "value": "hidden_map"}
	]
	_run_choice(box, "选择法器", "选择一个当前持有的法器，用于本次施法。", choices)
	await _wait_for_modal()
	_assert_modal_clean()
	await _save_screenshot("%s_%s.png" % [prefix, name])
	var choice_button := modal.find_child("ChoiceButton", true, false) as Button
	_expect(choice_button != null, "choice button missing")
	choice_button.emit_signal("pressed")
	await process_frame
	_press_modal_button("ConfirmButton")
	await _wait_for_result(box)
	_expect(String(box.get("result", "")) == "moon_lantern", "choice should resolve selected artifact")


func _run_message(box: Dictionary, title: String, body: String, confirm_text: String, cancel_text: String) -> void:
	box["result"] = await modal.call("show_message", title, body, confirm_text, cancel_text)


func _run_choice(box: Dictionary, title: String, body: String, choices: Array) -> void:
	box["result"] = await modal.call("show_choice_list", title, body, choices, "取消")


func _run_countdown(box: Dictionary, title: String, body: String) -> void:
	box["result"] = await modal.call("show_countdown_message", title, body, 10.0, "取消")


func _wait_for_modal() -> void:
	for i in range(20):
		await process_frame
		if modal.visible:
			await create_timer(0.25).timeout
			return
	_expect(false, "modal did not become visible")


func _wait_for_result(box: Dictionary) -> void:
	for i in range(20):
		await process_frame
		if box.has("result"):
			return
	_expect(false, "modal did not resolve")


func _press_modal_button(name: String) -> void:
	var button := modal.find_child(name, true, false) as Button
	_expect(button != null, "missing modal button %s" % name)
	button.emit_signal("pressed")


func _assert_modal_clean() -> void:
	var panel := modal.find_child("DialogueModalPanel", true, false) as Control
	var title_wrap := modal.find_child("TitleWrap", true, false) as Control
	var title := modal.find_child("TitleLabel", true, false) as Label
	var content := modal.find_child("ContentScroll", true, false) as Control
	var cancel := modal.find_child("CancelButton", true, false) as Button
	var confirm := modal.find_child("ConfirmButton", true, false) as Button
	_expect(panel != null, "missing modal panel")
	_expect(title_wrap != null and title != null and not title.text.is_empty(), "missing modal title")
	_expect(content != null, "missing modal content")
	_expect(cancel != null and confirm != null, "missing modal actions")
	_expect(cancel.global_position.x < confirm.global_position.x, "cancel must be left of confirm")
	var viewport_size := Vector2(test_viewport.size)
	_expect(_title_is_half_raised(panel, title_wrap, viewport_size), "title should sit half above panel")
	_expect(_inside(panel, content), "content outside panel")
	_expect(_inside(panel, cancel), "cancel outside panel")
	_expect(_inside(panel, confirm), "confirm outside panel")
	_expect(panel.global_position.x >= 8.0, "panel exceeds left viewport")
	_expect(panel.global_position.y >= 8.0, "panel exceeds top viewport")
	_expect(panel.global_position.x + panel.size.x <= viewport_size.x - 8.0, "panel exceeds right viewport: pos=%s size=%s root=%s" % [panel.global_position, panel.size, viewport_size])
	_expect(panel.global_position.y + panel.size.y <= viewport_size.y - 8.0, "panel exceeds bottom viewport")


func _assert_countdown_footer_clean() -> void:
	var countdown := modal.find_child("CountdownLabel", true, false) as Label
	var progress := modal.find_child("CountdownProgress", true, false) as ProgressBar
	var content := modal.find_child("ContentScroll", true, false) as Control
	var cancel := modal.find_child("CancelButton", true, false) as Button
	var confirm := modal.find_child("ConfirmButton", true, false) as Button
	_expect(countdown != null and countdown.visible, "countdown label should be visible")
	_expect(progress != null and progress.visible, "countdown progress should be visible")
	_expect(confirm != null and confirm.visible and not confirm.disabled, "countdown confirm should be visible and enabled")
	_expect(content.global_position.y + content.size.y <= countdown.global_position.y + 4.0, "countdown should sit below body content")
	_expect(countdown.global_position.y + countdown.size.y <= cancel.global_position.y + 4.0, "countdown label should sit above buttons")
	_expect(progress.global_position.y + progress.size.y <= cancel.global_position.y + 4.0, "countdown progress should sit above buttons")
	_expect(cancel.global_position.y - (progress.global_position.y + progress.size.y) <= 48.0, "buttons should stay directly below countdown progress")
	_expect(cancel.global_position.x < confirm.global_position.x, "cancel must remain left of confirm")


func _inside(parent: Control, child: Control) -> bool:
	var parent_rect := parent.get_global_rect().grow(4.0)
	var child_rect := child.get_global_rect()
	return parent_rect.encloses(child_rect)


func _title_is_half_raised(panel: Control, title: Control, viewport_size: Vector2) -> bool:
	var panel_rect := panel.get_global_rect()
	var title_rect := title.get_global_rect()
	var expected_top: float = max(8.0, panel_rect.position.y - 33.0)
	return abs(title_rect.position.y - expected_top) <= 5.0 \
		and title_rect.position.x >= 8.0 \
		and title_rect.position.x + title_rect.size.x <= viewport_size.x - 8.0 \
		and title_rect.position.y >= 8.0 \
		and title_rect.position.y < panel_rect.position.y \
		and title_rect.position.y + title_rect.size.y > panel_rect.position.y


func _save_screenshot(file_name: String) -> void:
	await process_frame
	var output_path := ProjectSettings.globalize_path(SHOT_DIR + file_name)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if DisplayServer.get_name() == "headless":
		print("Skipped screenshot in non-drawable display mode: ", output_path)
		return
	var texture := test_viewport.get_texture()
	if texture == null:
		print("Skipped screenshot in non-drawable display mode: ", output_path)
		return
	var image := texture.get_image()
	if image == null:
		print("Skipped screenshot in non-drawable display mode: ", output_path)
		return
	_expect(not image.is_empty(), "empty screenshot")
	var err := image.save_png(output_path)
	_expect(err == OK, "failed to save screenshot %s" % output_path)
	print("Saved modal screenshot: ", output_path)


func _expect(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
