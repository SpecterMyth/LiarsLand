extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_scene_nodes("res://scenes/ui/round_select_page.tscn", [
		"RoundCounter/RoundCounterLabel",
		"PlayerCard",
		"PlayerCard/Stats",
		"NpcCardSlots/NpcCard1",
		"NpcCardSlots/NpcCard2",
		"NpcCardSlots/NpcCard3",
		"UtilityColumn"
	])
	_assert_scene_nodes("res://scenes/ui/shop_page.tscn", [
		"Background",
		"StatusBar/StatusRow/EnergyLabel",
		"StatusBar/StatusRow/InventoryLabel",
		"PlayerCard/PlayerContent/Stats",
		"AscensionRequirement/Box/Slots",
		"DominionRequirement/Box/Slots",
		"ShopItemSlots/ShopItem1",
		"ShopItemSlots/ShopItem2",
		"ShopItemSlots/ShopItem3",
		"BackpackPanel/BackpackContent/BackpackGrid",
		"BackpackPanel/BackpackContent/LeaveButton"
	])
	_assert_scene_nodes("res://scenes/ui/ascension_page.tscn", [
		"StatControls/HpMinusButton",
		"StatControls/HpPlusButton",
		"StatControls/CharmMinusButton",
		"StatControls/CharmPlusButton",
		"AscendConfirmButton",
		"DominionButton"
	])
	print("LiarsLand flow scene interface checks passed.")
	quit(0)


func _assert_scene_nodes(path: String, node_paths: Array) -> void:
	var packed: PackedScene = load(path)
	assert(packed != null)
	var scene := packed.instantiate()
	root.add_child(scene)
	for node_path in node_paths:
		assert(scene.get_node_or_null(String(node_path)) != null)
	scene.queue_free()
