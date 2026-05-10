extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_check_round_select_layout()
	_check_inventory_layout()
	_check_shop_layout()
	print("Shop and inventory layout check passed.")
	quit(0)


func _check_round_select_layout() -> void:
	var scene := _instance_scene("res://scenes/ui/round_select_page.tscn")
	var player := scene.get_node_or_null("PlayerCard") as Control
	assert(player != null)
	await process_frame
	var rect := player.get_global_rect()
	_assert_rect_inside(rect, Rect2(Vector2.ZERO, Vector2(1280, 720)), "round player card")
	assert(rect.size.x <= 340.0)
	assert(rect.size.y <= 570.0)
	scene.queue_free()


func _check_inventory_layout() -> void:
	var scene := _instance_scene("res://scenes/ui/inventory_overlay.tscn")
	await process_frame
	assert(scene.get_node_or_null("RequirementPanel/OuterPanel") == null)
	_assert_scale_texture(scene, "MainPanel")
	_assert_scale_texture(scene, "TitleBanner")
	_assert_scale_texture(scene, "BagPanel")
	_assert_scale_texture(scene, "BagHeader")
	var requirement := scene.get_node_or_null("RequirementPanel") as Control
	var bag := scene.get_node_or_null("BagPanel") as Control
	assert(requirement != null)
	assert(bag != null)
	assert(abs(requirement.position.x - 32.0) <= 0.5)
	assert(abs(requirement.position.y - 100.667) <= 0.5)
	assert(abs(requirement.size.x - 400.0) <= 0.5)
	assert(abs(requirement.size.y - 582.0) <= 1.0)
	assert(abs(bag.position.x - 434.0) <= 0.5)
	assert(abs(bag.size.x - 814.0) <= 1.0)
	scene.queue_free()


func _check_shop_layout() -> void:
	var scene := _instance_scene("res://scenes/ui/shop_page.tscn")
	await process_frame
	assert(scene.get_node_or_null("RequirementPanel/OuterPanel") == null)
	for path in ["TitleBanner", "ShopItemsTitleBack", "PlaceholderPanel"]:
		_assert_scale_texture(scene, path)
	for path in ["PlayerCard", "ShopItemSlots/ShopItem1", "ShopItemSlots/ShopItem2", "ShopItemSlots/ShopItem3", "RequirementPanel", "ContinueButton"]:
		var node := scene.get_node_or_null(path) as Control
		assert(node != null)
		_assert_rect_inside(node.get_global_rect(), Rect2(Vector2.ZERO, Vector2(1280, 720)), path)
	var requirement := scene.get_node_or_null("RequirementPanel") as Control
	var utility := scene.get_node_or_null("RightUtilityButtons/InfoButton") as Control
	assert(abs(requirement.get_global_rect().size.x - 400.0) <= 1.0)
	assert(requirement.get_global_rect().end.x <= 1191.0)
	assert(utility == null or requirement.get_global_rect().end.x < utility.get_global_rect().position.x)
	for path in ["ShopItemSlots/ShopItem1", "ShopItemSlots/ShopItem2", "ShopItemSlots/ShopItem3"]:
		var card := scene.get_node_or_null(path) as Control
		assert(card.get_node_or_null("Content/BuyButton/PrimaryButtonBackground") == null)
	scene.queue_free()


func _instance_scene(path: String) -> Control:
	var packed := load(path) as PackedScene
	assert(packed != null)
	var scene := packed.instantiate() as Control
	root.add_child(scene)
	return scene


func _assert_scale_texture(root_node: Node, path: String) -> void:
	var texture_rect := root_node.get_node_or_null(path) as TextureRect
	assert(texture_rect != null)
	assert(texture_rect.stretch_mode == TextureRect.STRETCH_SCALE)


func _assert_rect_inside(rect: Rect2, bounds: Rect2, label: String) -> void:
	assert(rect.position.x >= bounds.position.x - 0.5)
	assert(rect.position.y >= bounds.position.y - 0.5)
	assert(rect.end.x <= bounds.end.x + 0.5)
	assert(rect.end.y <= bounds.end.y + 0.5)
