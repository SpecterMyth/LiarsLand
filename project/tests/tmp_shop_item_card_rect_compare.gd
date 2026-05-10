extends SceneTree


const PATHS := [
	"RuntimeBackgroundPanel",
	"CardTexture",
	"Content",
	"Content/ArtifactFrame",
	"Content/ArtifactFrame/RuntimeArtifactPanel",
	"Content/ArtifactFrame/Background",
	"Content/ArtifactFrame/ArtifactIcon",
	"Content/NameLabel",
	"Content/NameLabel/NameBack",
	"Content/PriceLabel",
	"Content/PriceLabel/PriceBack",
	"Content/PriceLabel/EnergyIcon",
	"Content/BuyButton",
]


func _init() -> void:
	var standalone_scene := load("res://scenes/ui/shop_item_card.tscn") as PackedScene
	var shop_scene := load("res://scenes/ui/shop_page.tscn") as PackedScene
	assert(standalone_scene != null)
	assert(shop_scene != null)

	var standalone := standalone_scene.instantiate() as Control
	var shop := shop_scene.instantiate() as Control
	root.add_child(standalone)
	root.add_child(shop)
	await process_frame
	await process_frame

	var embedded := shop.get_node("ShopItemSlots/ShopItem1") as Control
	assert(standalone.size.is_equal_approx(embedded.size))
	for path in PATHS:
		var a := standalone.get_node(path) as Control
		var b := embedded.get_node(path) as Control
		assert(a.position.is_equal_approx(b.position))
		assert(a.size.is_equal_approx(b.size))
		assert(a.custom_minimum_size.is_equal_approx(b.custom_minimum_size))

	print("Shop item card rect compare passed.")
	root.remove_child(standalone)
	root.remove_child(shop)
	standalone.free()
	shop.free()
	quit(0)
