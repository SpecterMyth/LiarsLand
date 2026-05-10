extends SceneTree


const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")

const PATHS := [
	"Root",
	"Root/Background",
	"Root/Icon",
	"Root/Badge",
	"Root/Badge/CountLabel",
]


func _init() -> void:
	var scene := load("res://scenes/ui/artifact_slot.tscn") as PackedScene
	assert(scene != null)

	var standalone := scene.instantiate() as Control
	var screen := AdventureScreenScript.new()
	var embedded := screen._make_artifact_slot("", false, 0) as Control
	root.add_child(standalone)
	root.add_child(embedded)
	await process_frame
	await process_frame

	assert(standalone.size.is_equal_approx(Vector2(58, 58)))
	assert(embedded.size.is_equal_approx(standalone.size))
	assert(embedded.custom_minimum_size.is_equal_approx(standalone.custom_minimum_size))
	for path in PATHS:
		var a := standalone.get_node(path) as Control
		var b := embedded.get_node(path) as Control
		assert(a.position.is_equal_approx(b.position))
		assert(a.size.is_equal_approx(b.size))
		assert(a.custom_minimum_size.is_equal_approx(b.custom_minimum_size))

	var standalone_background := standalone.get_node("Root/Background") as TextureRect
	var embedded_background := embedded.get_node("Root/Background") as TextureRect
	assert(embedded_background.texture == standalone_background.texture)
	assert(not embedded.has_theme_stylebox_override("panel"))

	print("Artifact slot rect compare passed.")
	root.remove_child(standalone)
	root.remove_child(embedded)
	standalone.free()
	embedded.free()
	screen.free()
	quit(0)
