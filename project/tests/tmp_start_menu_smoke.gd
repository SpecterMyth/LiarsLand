extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	print("loading")
	var packed: PackedScene = load("res://scenes/main.tscn")
	print("instantiating")
	var main: Control = packed.instantiate()
	print("adding")
	root.add_child(main)
	print("awaiting")
	await process_frame
	await process_frame
	print("checking")
	var screen := main.get_child(0)
	var menu: Control = screen.get("start_menu")
	assert(menu.visible)
	assert(menu.get("start_button") != null)
	print("Main start menu smoke passed.")
	quit(0)
