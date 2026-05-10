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
		"RightUtilityButtons/InfoButton",
		"RightUtilityButtons/BagButton",
		"RightUtilityButtons/HistoryButton",
		"RightUtilityButtons/RulesButton",
		"RightUtilityButtons/StatusButton",
		"RightUtilityButtons/SettingsButton"
	])
	_assert_scene_nodes("res://scenes/ui/shop_page.tscn", [
		"Background",
		"TitleBanner",
		"TitleLabel",
		"CloseButton",
		"BagResourceBar/EnergyPlate/EnergyValue",
		"BagResourceBar/CapacityPlate/CapacityValue",
		"PlayerCard",
		"PlayerCard/Stats",
		"RequirementPanel/DominionRequirementGrid",
		"RequirementPanel/AscensionRequirementGrid",
		"ShopItemSlots/ShopItem1",
		"ShopItemSlots/ShopItem2",
		"ShopItemSlots/ShopItem3",
		"RightUtilityButtons/InfoButton",
		"RightUtilityButtons/BagButton",
		"RightUtilityButtons/HistoryButton",
		"RightUtilityButtons/RulesButton",
		"RightUtilityButtons/StatusButton",
		"RightUtilityButtons/SettingsButton"
	])
	_assert_scene_nodes("res://scenes/ui/inventory_overlay.tscn", [
		"TitleBanner",
		"TitleLabel",
		"CloseButton",
		"BagResourceBar/EnergyPlate/EnergyValue",
		"BagResourceBar/CapacityPlate/CapacityValue",
		"RequirementPanel/DominionRequirementGrid",
		"RequirementPanel/AscensionRequirementGrid",
		"InventoryItemGrid"
	])
	_assert_scene_nodes("res://scenes/ui/ascension_page.tscn", [
		"StatControls/HpMinusButton",
		"StatControls/HpPlusButton",
		"StatControls/CharmMinusButton",
		"StatControls/CharmPlusButton",
		"AscendConfirmButton",
		"DominionButton",
		"RightUtilityButtons/InfoButton",
		"RightUtilityButtons/BagButton"
	])
	_assert_scene_nodes("res://scenes/ui/guidelines_page.tscn", [
		"TitleBanner",
		"TitleLabel",
		"CloseButton",
		"MainPanel/Content/TabRow/IdentityTab",
		"MainPanel/Content/TabRow/BehaviorTab",
		"MainPanel/Content/TabRow/GrowthTab",
		"MainPanel/Content/GuidelineEdit",
		"MainPanel/Content/AppendRow/AppendEdit",
		"MainPanel/Content/AppendRow/MergeButton",
		"MainPanel/Content/Footer/AutoActionCheck",
		"MainPanel/Content/Footer/AutoGrowthCheck",
		"MainPanel/Content/Footer/SaveButton",
		"MainPanel/Content/Footer/ResetButton",
		"DecisionPanel"
	])
	_assert_scene_nodes("res://scenes/ui/death_page.tscn", [
		"Background",
		"Veil",
		"Content",
		"Content/RuleEdit",
		"Content/ButtonRow/MergeButton",
		"Content/ButtonRow/RestartButton"
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
