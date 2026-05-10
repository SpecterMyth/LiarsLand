extends SceneTree

const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")


func _init() -> void:
	var screen := AdventureScreenScript.new()
	var host := Control.new()
	host.size = Vector2(360, 180)
	root.add_child(host)

	_check_grid(screen, host, "DominionRequirementGrid", 300.0, 220.0, 3, 6, false)
	_check_requirement_component(screen)
	_check_grid(screen, host, "InventoryItemGrid", 720.0, 240.0, 8, 40, true)

	print("Inventory grid runtime check passed.")
	root.remove_child(host)
	host.free()
	screen.free()
	quit(0)


func _check_requirement_component(screen: Control) -> void:
	var packed := load("res://scenes/ui/requirement_panel.tscn") as PackedScene
	assert(packed != null)
	var panel := packed.instantiate() as Control
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(360, 520)
	root.add_child(panel)
	var dominion := panel.get_node_or_null("DominionRequirementGrid") as GridContainer
	var ascension := panel.get_node_or_null("AscensionRequirementGrid") as GridContainer
	assert(dominion != null)
	assert(ascension != null)
	var dominion_slot_size: Vector2 = screen.call("_prepare_inventory_grid", dominion, 3, 6)
	var ascension_slot_size: Vector2 = screen.call("_prepare_inventory_grid", ascension, 3, 6)
	assert(dominion_slot_size.x > 0.0)
	assert(ascension_slot_size.x > 0.0)
	panel.queue_free()


func _check_grid(screen: Control, host: Control, grid_name: String, width: float, height: float, columns: int, item_count: int, should_scroll: bool) -> void:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.offset_left = 0.0
	grid.offset_top = 0.0
	grid.offset_right = width
	grid.offset_bottom = height
	host.add_child(grid)

	var slot_size: Vector2 = screen.call("_prepare_inventory_grid", grid, columns, item_count)
	for i in range(item_count):
		var slot := Control.new()
		slot.custom_minimum_size = slot_size
		grid.add_child(slot)
	screen.call("_update_inventory_scroll_mode", grid, item_count, slot_size)

	assert(grid.get_parent() is ScrollContainer)
	var scroll := grid.get_parent() as ScrollContainer
	var expected_edge: float = floor(width / float(columns))
	assert(abs(slot_size.x - expected_edge) <= 0.5)
	assert(abs(slot_size.y - expected_edge) <= 0.5)
	assert(grid.get_child_count() == item_count)
	assert((scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO) == should_scroll)
	host.remove_child(scroll)
	scroll.queue_free()
