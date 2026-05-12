extends SceneTree

const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")
const OUTPUT_PATH := "res://../ui/visual_tests/common_modal/desktop_council_trade_proposal.png"

var test_viewport: SubViewport
var screen: Control
var modal: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	await process_frame

	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	test_viewport.add_child(main)
	await process_frame
	await process_frame

	screen = main.get_child(0) as Control
	modal = screen.get("common_modal") as Control
	if screen.get("start_menu") != null:
		screen.get("start_menu").hide()
	screen.state.current_npc_index = 0
	screen.state.choose_npc(0)
	screen.set("running", true)
	screen.call("_set_current_npc_assets")
	screen.call("_set_dialogue_visible", true)

	var state = screen.get("state")
	var npc_id := String(state.current_npc().get("id", ""))
	var own_crime := String(state.player.get("hidden_crimes", [])[0])
	var sample_crimes := []
	for candidate in ["duck_house_expense", "hush_money_invoice", "gold_bar_favors"]:
		if String(candidate) != own_crime:
			sample_crimes.append(candidate)
	var payload := {
		"counterpart_id": "player",
		"proposals": [
			{"crime_id": own_crime, "vote": CouncilRulesEngineScript.VOTE_GUILTY},
			{"crime_id": String(sample_crimes[0]), "vote": CouncilRulesEngineScript.VOTE_INNOCENT},
			{"crime_id": String(sample_crimes[1]), "vote": CouncilRulesEngineScript.VOTE_GUILTY}
		]
	}
	var content := screen.call("_make_council_trade_content", npc_id, "player", payload, "对手提出政治交易") as Control
	_run_modal(content)
	await _wait_for_modal()
	await process_frame
	await process_frame
	await _save_screenshot()
	modal.call("cancel")
	print("Council trade proposal screenshot saved: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	quit(0)


func _run_modal(content: Control) -> void:
	await modal.call("show_countdown_with_content", "政治交易提案", content, 10.0, "拒绝", "接受并执行", false)


func _wait_for_modal() -> void:
	for i in range(40):
		await process_frame
		if modal != null and modal.visible:
			await create_timer(0.25).timeout
			return
	push_error("Modal did not become visible.")
	quit(1)


func _save_screenshot() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var texture := test_viewport.get_texture()
	if texture == null:
		push_error("Cannot capture viewport texture.")
		quit(1)
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Cannot capture viewport image.")
		quit(1)
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Failed to save screenshot: %s" % output_path)
		quit(1)
