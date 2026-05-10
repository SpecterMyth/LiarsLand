extends SceneTree

const OUTPUT_DIR := "res://../ui/concepts/runtime_card_v2"
const SHOP_ROOTS := [
	"res://assets/ui/shop/",
	"res://assets/ui/common/",
	"res://assets/generated/ui/shop_v2/"
]


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
	_prepare_shop_visual_fixture(screen)
	screen._render_shop()
	await process_frame
	await process_frame
	_apply_shop_visual_fixture_overrides(screen)
	assert(screen.shop_panel != null)
	assert(_shop_asset_exists("shop_title_banner_red.png"))
	assert(_shop_asset_exists("shop_player_card_red.png"))
	assert(_shop_asset_exists("shop_item_card_red.png"))
	assert(_shop_asset_exists("shop_button_gold_normal.png") or _shop_asset_exists("shop_button_gold.png"))
	assert(_shop_asset_exists("shop_button_gold_hover.png") or _shop_asset_exists("shop_button_gold.png"))
	assert(_shop_asset_exists("shop_button_gold_pressed.png") or _shop_asset_exists("shop_button_gold.png"))
	assert(_shop_asset_exists("shop_button_disabled.png") or _shop_asset_exists("shop_button_disabled_dark.png"))
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
	var texture := root.get_texture()
	if texture == null:
		push_error("Cannot capture runtime screenshot because the root viewport has no texture. Run without --headless so Godot uses a drawable display driver.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Cannot capture runtime screenshot because the root viewport image is empty.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var result := image.save_png(path)
	if result != OK:
		push_error("Failed to save runtime screenshot: %s" % path)
		quit(1)


func _shop_asset_exists(file_name: String) -> bool:
	for root_path in SHOP_ROOTS:
		var res_path := String(root_path) + file_name
		if ResourceLoader.exists(res_path):
			return true
		if FileAccess.file_exists(ProjectSettings.globalize_path(res_path)):
			return true
	return false


func _prepare_shop_visual_fixture(screen: Control) -> void:
	var player: Dictionary = screen.state.player.duplicate(true)
	player["energy"] = 128
	player["level"] = 4
	player["inventory"] = ["silent_coin", "deer_bell", "wolf_oath_blade", "debt_silk"]
	player["artifact_history"] = ["snake_marrow_vial"]
	player["ascension_requirement"] = ["snake_marrow_vial", "deer_bell", "cracked_gold_seal"]
	player["dominion_requirement"] = ["snake_marrow_vial", "deer_bell", "ash_map"]
	screen.state.player = player
	screen.state.shop_items = ["silent_coin", "debt_silk", "wolf_oath_blade"]
	assert(int(screen.state.player.get("energy", 0)) == 128)
	assert(screen.state.player.get("inventory", []).size() == 4)


func _apply_shop_visual_fixture_overrides(screen: Control) -> void:
	var shop: Control = screen.shop_panel
	if shop == null:
		return
	var energy := shop.get_node_or_null("StatusBar/StatusRow/EnergyLabel") as Label
	if energy != null:
		energy.text = "◇ 能量 128"
	var inventory := shop.get_node_or_null("StatusBar/StatusRow/InventoryLabel") as Label
	if inventory != null:
		inventory.text = "袋 背包 4"
	var stats := shop.get_node_or_null("PlayerCard/Stats") as Control
	if stats != null:
		var values := ["128", "4", "1/3", "4"]
		for i in range(min(values.size(), stats.get_child_count())):
			var row := stats.get_child(i)
			var value_label := row.get_node_or_null("ValueLabel") as Label
			if value_label != null:
				value_label.text = values[i]
