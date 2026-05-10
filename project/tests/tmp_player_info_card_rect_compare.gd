extends SceneTree


const PATHS := [
	"CardTexture",
	"NameLabel",
	"Stats",
	"Stats/StatRow1",
	"Stats/StatRow2",
	"Stats/StatRow3",
	"Stats/StatRow4",
]


func _init() -> void:
	var standalone_scene := load("res://scenes/ui/player_info_card.tscn") as PackedScene
	var shop_scene := load("res://scenes/ui/shop_page.tscn") as PackedScene
	assert(standalone_scene != null)
	assert(shop_scene != null)

	var standalone := standalone_scene.instantiate() as Control
	var shop := shop_scene.instantiate() as Control
	root.add_child(standalone)
	root.add_child(shop)
	await process_frame
	await process_frame

	var embedded := shop.get_node("PlayerCard") as Control
	assert(standalone.size.is_equal_approx(embedded.size))
	for path in PATHS:
		var a := standalone.get_node(path) as Control
		var b := embedded.get_node(path) as Control
		assert(a.position.is_equal_approx(b.position))
		assert(a.size.is_equal_approx(b.size))
		assert(a.custom_minimum_size.is_equal_approx(b.custom_minimum_size))

	print("Player info card rect compare passed.")
	root.remove_child(standalone)
	root.remove_child(shop)
	standalone.free()
	shop.free()
	quit(0)
