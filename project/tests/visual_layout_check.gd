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
	assert(screen.get("dialogue_view") != null)
	assert(screen.get("recent_view") != null)
	assert(screen.get("info_button") != null)
	assert(screen.get("bag_button") != null)
	assert(screen.get("history_button") != null)
	assert(screen.get("rules_button") != null)
	assert(screen.get("status_button") != null)
	assert(screen.get("settings_button") != null)
	assert(screen.get("drawer") != null)
	assert(screen.get("rules_panel") != null)
	assert(screen.get("upgrade_panel") != null)
	assert(screen.get("progress_label") != null)
	assert(screen.get("npc_public_label") != null)
	assert(screen.get("card_grid") != null)
	var dialogue: Control = screen.get("dialogue_view")
	var recent: Control = screen.get("recent_view")
	var info_button: Control = screen.get("info_button")
	var settings_button: Control = screen.get("settings_button")
	var drawer: Control = screen.get("drawer")
	var rules_panel: Control = screen.get("rules_panel")
	var upgrade_panel: Control = screen.get("upgrade_panel")
	var card_grid: Control = screen.get("card_grid")
	assert(dialogue.size.x > 480)
	assert(dialogue.size.y >= 45)
	assert(dialogue.global_position.y + dialogue.size.y <= 720)
	assert(recent.size.x > 700)
	assert(recent.size.y >= 75)
	assert(info_button.size.x >= 60)
	assert(info_button.global_position.x > 1160)
	assert(settings_button.global_position.x > 1160)
	assert(not drawer.visible)
	assert(not rules_panel.visible)
	assert(not upgrade_panel.visible)
	assert(card_grid.get_child_count() >= 2)
	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	assert(dialogue.size.x > 240)
	assert(dialogue.size.y >= 35)
	assert(dialogue.global_position.y + dialogue.size.y <= 844)
	print("LiarsLand visual layout checks passed.")
	quit(0)
