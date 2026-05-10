extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null)
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var screen := main.get_child(0)
	assert(screen.get("action_animation_overlay") != null)
	assert(not screen.get("action_animation_overlay").visible)
	screen.state.refresh_npc_choices()
	screen.state.choose_npc(0)
	screen.call("_set_current_npc_assets")
	var before_events: int = screen.state.event_log.size()
	print("integration check: direct duel")
	await screen.call("_play_action_animation", "duel", "player", "", ["决斗胜利：视觉测试。"])
	assert(not screen.get("action_animation_overlay").visible)
	assert(screen.state.event_log.size() == before_events)
	print("integration check: manual leave")
	screen.set("running", true)
	screen.call("_set_dialogue_visible", true)
	var player_before: TextureRect = screen.get("player_portrait")
	var player_size := player_before.size
	var player_y := player_before.global_position.y
	var started := Time.get_ticks_msec()
	screen.call("_on_manual_action_pressed", "leave")
	await process_frame
	assert(screen.get("manual_action_resolved"))
	assert(screen.get("manual_action_in_progress"))
	assert(screen.get("action_animation_overlay").visible)
	assert(screen.get("player_portrait").visible)
	assert(player_before.size == player_size)
	assert(abs(player_before.global_position.y - player_y) < 96.0)
	assert(not screen.get("lower_box").visible)
	assert(not screen.get("info_button").visible)
	var actor_debug: Dictionary = screen.get("action_animation_overlay").call("debug_actor_state")
	assert(actor_debug.get("using_external_player"))
	assert(actor_debug.get("using_external_npc"))
	assert(not actor_debug.get("fallback_player_visible"))
	assert(not actor_debug.get("fallback_npc_visible"))
	print("integration check: waiting manual animation")
	await screen.call("_finish_manual_action_if_needed")
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	assert(elapsed >= 2.9)
	assert(not screen.get("manual_action_in_progress"))
	assert(not screen.get("action_animation_overlay").visible)
	print("LiarsLand action animation integration checks passed.")
	quit(0)
