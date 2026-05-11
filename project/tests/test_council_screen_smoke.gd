extends SceneTree

const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen: Control = AdventureScreenScript.new()
	screen.config = {
		"game": {
			"mode": "council",
			"use_mock_llm": true
		}
	}
	root.add_child(screen)
	await process_frame
	await process_frame
	assert(screen.get("council_mode") == true)
	assert(screen.get("state") != null)
	assert(screen.get("state").get("council_mode") == true)
	print("Council screen smoke test passed.")
	quit(0)
