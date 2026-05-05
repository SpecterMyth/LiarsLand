extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	assert(main.get_child_count() > 0)
	var screen := main.get_child(0)
	assert(screen is Control)
	assert(screen.get("rules_edit") != null)
	assert(screen.get("dialogue_view") != null)
	assert(screen.get("state_view") != null)
	print("LiarsLand layout inspection passed.")
	quit(0)
