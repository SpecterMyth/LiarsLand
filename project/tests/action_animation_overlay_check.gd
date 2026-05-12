extends SceneTree

const OverlayScript := preload("res://scripts/ui/action_animation_overlay.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state = GameStateScript.new()
	state.load_chapter(ChapterLoaderScript.load_chapter("res://data/chapter_01.json"))
	state.refresh_npc_choices()
	state.choose_npc(0)
	var overlay := OverlayScript.new()
	root.add_child(overlay)
	await process_frame
	var artifact_id := String(state.artifacts[0].get("id", ""))
	var started := Time.get_ticks_msec()
	print("action animation check: leave")
	await overlay.play_action("leave", "player", "", "success", state)
	print("action animation check: council retreat")
	await overlay.play_action("retreat", "player", "", "success", state, null, null, {"action": "retreat"})
	print("action animation check: council tendency")
	await overlay.play_action("declare_tendency", "player", "", "success", state, null, null, {"action": "declare_tendency", "target_crime_id": "duck_house_expense", "vote": "guilty"})
	print("action animation check: council vote")
	await overlay.play_action("cast_vote", "player", "", "success", state, null, null, {"action": "cast_vote", "target_crime_id": "duck_house_expense", "vote": "guilty"})
	print("action animation check: council trade")
	await overlay.play_action("offer_trade", "player", "", "success", state, null, null, {"action": "offer_trade", "target_crime_id": "duck_house_expense", "vote": "guilty"})
	print("action animation check: gift")
	await overlay.play_action("gift", "player", artifact_id, "victory", state)
	print("action animation check: cast")
	await overlay.play_action("cast", "player", artifact_id, "failure", state)
	print("action animation check: invite")
	await overlay.play_action("invite", "player", "", "victory", state)
	print("action animation check: duel")
	await overlay.play_action("duel", "player", "", "failure", state)
	print("action animation check: assassinate")
	await overlay.play_action("assassinate", "npc", "", "death", state)
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	assert(elapsed >= 40.0)
	assert(not overlay.visible)
	var debug_state: Dictionary = overlay.debug_actor_state()
	assert(int(debug_state.get("transient_vfx_count", -1)) == 0)
	print("LiarsLand action animation overlay checks passed in %.2fs." % elapsed)
	quit(0)
