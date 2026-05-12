extends SceneTree

const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1672, 941)
	var screen: Control = AdventureScreenScript.new()
	screen.config = {"game": {"mode": "council", "use_mock_llm": true}}
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	screen.set("running", true)
	screen.state.refresh_npc_choices()
	screen.state.choose_npc(0)
	screen.call("_set_current_npc_assets")
	screen.call("_set_dialogue_visible", true)
	var overlay: Control = screen.get("action_animation_overlay")
	_must(overlay != null, "missing action animation overlay")
	var before_events: int = screen.state.event_log.size()
	print("integration check: direct duel")
	await screen.call("_play_action_animation", "duel", "player", "", ["visual test event"])
	_must(not overlay.visible, "legacy duel overlay did not close")
	_must(screen.state.event_log.size() == before_events, "legacy animation mutated event log")
	screen.call("_set_dialogue_visible", true)
	await process_frame
	print("integration check: council retreat")
	var events: Array[String] = []
	var payload := {"action": "retreat"}
	_must(CouncilRulesEngineScript.apply_member_action(screen.state, "player", "retreat", payload, events), "retreat did not apply")
	var started := Time.get_ticks_msec()
	await screen.call("_play_council_action_animation", "retreat", "player", payload, events)
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	_must(elapsed >= 2.9, "retreat animation ended too early")
	_must(not overlay.visible, "council retreat overlay did not close")
	_must(screen.get("lower_box").visible, "dialogue chrome was not restored")
	var debug_state: Dictionary = overlay.call("debug_actor_state")
	_must(int(debug_state.get("transient_vfx_count", -1)) == 0, "transient VFX leaked")
	print("integration check: manual action wait gate")
	var wait_box := {"done": false, "result": false}
	screen.set("manual_action_in_progress", true)
	screen.set("manual_action_resolved", false)
	var wait_pending = call("_await_manual_gate", screen, wait_box)
	await create_timer(0.35).timeout
	_must(not bool(wait_box.get("done", false)), "manual gate returned before in-progress action finished")
	screen.set("manual_action_resolved", true)
	screen.set("manual_action_in_progress", false)
	var wait_result: bool = await wait_pending
	_must(wait_result, "manual gate did not report resolved action")
	_must(bool(wait_box.get("done", false)), "manual gate helper did not complete")
	print("LiarsLand action animation integration checks passed.")
	quit(0)


func _await_manual_gate(screen: Control, box: Dictionary) -> bool:
	var result: bool = await screen.call("_finish_manual_action_if_needed")
	box["result"] = result
	box["done"] = true
	return result


func _must(condition: bool, message := "integration assertion failed") -> void:
	if condition:
		return
	push_error(message)
	quit(1)
