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
	var actions := [
		{"action": "retreat", "payload": {"action": "retreat"}, "minimum": 2.9},
		{"action": "declare_tendency", "payload": {"action": "declare_tendency", "target_crime_id": "duck_house_expense", "vote": "guilty"}, "minimum": 3.0},
		{"action": "cast_vote", "payload": {"action": "cast_vote", "target_crime_id": "duck_house_expense", "vote": "guilty", "source": "test"}, "minimum": 3.4},
		{"action": "offer_trade", "payload": {"action": "offer_trade", "target_crime_id": "gold_bar_favors", "vote": "innocent", "counterpart_id": String(screen.state.current_npc().get("id", ""))}, "minimum": 3.8}
	]
	for item in actions:
		await _apply_and_play(screen, overlay, item)
	print("LiarsLand council action animation integration checks passed.")
	quit(0)


func _apply_and_play(screen: Control, overlay: Control, item: Dictionary) -> void:
	var events: Array[String] = []
	var payload: Dictionary = item.get("payload", {}).duplicate(true)
	var action := String(item.get("action", ""))
	var applied := CouncilRulesEngineScript.apply_member_action(screen.state, "player", action, payload, events)
	_must(applied, "council action was not applied: %s" % action)
	var started := Time.get_ticks_msec()
	await screen.call("_play_council_action_animation", action, "player", payload, events)
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	_must(elapsed >= float(item.get("minimum", 0.0)), "%s animation ended too early: %.2fs" % [action, elapsed])
	_must(not overlay.visible, "%s overlay stayed visible after completion" % action)
	_must(screen.get("lower_box").visible, "%s dialogue chrome was not restored" % action)
	var debug_state: Dictionary = overlay.call("debug_actor_state")
	_must(int(debug_state.get("transient_vfx_count", -1)) == 0, "%s left transient VFX behind" % action)


func _must(condition: bool, message := "integration assertion failed") -> void:
	if condition:
		return
	push_error(message)
	quit(1)
