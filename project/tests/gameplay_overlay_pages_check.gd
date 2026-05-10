extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var failed := false
	failed = await _assert_page("res://scenes/ui/history_page.tscn", [
		"Background",
		"Veil",
		"TitleBanner",
		"TitleLabel",
		"CloseButton",
		"MainPanel",
		"MainPanel/ContentMargin/Content"
	]) or failed
	failed = await _assert_page("res://scenes/ui/status_page.tscn", [
		"Background",
		"Veil",
		"TitleBanner",
		"TitleLabel",
		"CloseButton",
		"MainPanel",
		"MainPanel/ContentMargin/Content"
	]) or failed
	failed = await _assert_page("res://scenes/ui/settings_page.tscn", [
		"Background",
		"Veil",
		"TitleBanner",
		"TitleLabel",
		"CloseButton",
		"MainPanel",
		"MainPanel/ContentMargin/Content"
	]) or failed
	if failed:
		quit(1)
		return
	failed = await _assert_main_entrypoints() or failed
	if failed:
		quit(1)
		return
	print("Gameplay overlay page checks passed.")
	quit(0)


func _assert_page(path: String, node_paths: Array) -> bool:
	var failed := false
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Missing scene: %s" % path)
		return true
	var page := packed.instantiate() as Control
	if page == null:
		push_error("Cannot instantiate scene: %s" % path)
		return true
	root.add_child(page)
	await process_frame
	for node_path in node_paths:
		if page.get_node_or_null(String(node_path)) == null:
			push_error("Missing node %s in %s" % [String(node_path), path])
			failed = true
	if not page.has_signal("close_requested"):
		push_error("Missing close_requested signal in %s" % path)
		failed = true
	page.queue_free()
	return failed


func _assert_main_entrypoints() -> bool:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Missing main scene")
		return true
	var main := packed.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame
	var screen := main.get_child(0) as Control
	if screen == null:
		push_error("Main scene has no adventure screen child")
		return true
	screen.call("_show_history")
	await process_frame
	var history_page := screen.get("history_dialog") as Control
	if history_page == null or not history_page.visible:
		push_error("History button target did not open the history page")
		return true
	screen.call("_show_status_page")
	await process_frame
	var status_page := screen.get("status_page") as Control
	if status_page == null or not status_page.visible:
		push_error("Status button target did not open the status page")
		return true
	screen.call("_toggle_settings")
	await process_frame
	var settings_page := screen.get("settings_panel") as Control
	if settings_page == null or not settings_page.visible:
		push_error("Settings button target did not open the settings page")
		return true
	main.queue_free()
	return false
