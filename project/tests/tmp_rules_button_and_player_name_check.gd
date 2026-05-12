extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var screen: Control = main.get_child(0)
	screen.state.choose_npc(0)
	screen.call("_set_current_npc_assets")
	screen.call("_set_dialogue_visible", true)
	var rules_button: Control = screen.get("rules_button")
	_must(rules_button != null, "rules_button missing")
	_must(rules_button.visible, "rules_button hidden in dialogue")
	screen.call("_set_current_dialogue_role", "player")
	await process_frame
	var current_speaker_label: Label = screen.get("current_speaker_label")
	_must(current_speaker_label != null, "current_speaker_label missing")
	_must(current_speaker_label.text == "灰狐代笔员", "player short name should use public_name")
	print("LiarsLand rules button and player name check passed.")
	quit(0)


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
