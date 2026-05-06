extends SceneTree

const OUTPUT_DIR := "res://../ui/concepts/runtime_card_v2"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var screen := main.get_child(0)
	screen.state.refresh_npc_choices()
	screen._render_npc_selection_page()
	await process_frame
	await process_frame
	_save("round_start_runtime_card_v2.png")
	screen.selection_panel.visible = false
	screen.state.refresh_shop_items()
	screen._render_shop()
	await process_frame
	await process_frame
	_save("shop_runtime_card_v2.png")
	screen.shop_panel.visible = false
	screen.selected_upgrade = {}
	screen.pending_stat_points = 3
	screen._render_ascension_page(true, true)
	await process_frame
	await process_frame
	_save("ascension_runtime_card_v2.png")
	print("LiarsLand card UI runtime screenshots exported.")
	quit(0)


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var result := image.save_png(path)
	assert(result == OK)
