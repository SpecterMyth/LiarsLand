extends SceneTree

const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := AdventureScreenScript.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.shop_done = false
	screen._render_shop()
	await process_frame
	var close_button := screen.shop_panel.get_node_or_null("CloseButton") as TextureButton
	assert(close_button != null)
	close_button.emit_signal("pressed")
	assert(screen.shop_done)
	screen.shop_done = false
	screen._render_shop()
	await process_frame
	var continue_button := screen.shop_panel.get_node_or_null("ContinueButton") as Button
	assert(continue_button != null)
	continue_button.emit_signal("pressed")
	assert(screen.shop_done)
	var buy_button := screen.shop_panel.get_node_or_null("ShopItemSlots/ShopItem1/Content/BuyButton") as Button
	assert(buy_button != null)
	assert(buy_button.get_node_or_null("PrimaryButtonBackground") == null)
	print("Shop button flow check passed.")
	quit(0)
