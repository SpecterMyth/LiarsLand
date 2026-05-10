extends SceneTree


const PATHS := [
	"DominionPanel",
	"DominionHeader",
	"DominionRequirementGrid",
	"AscensionPanel",
	"AscensionHeader",
	"AscensionRequirementGrid",
]


func _init() -> void:
	var standalone_scene := load("res://scenes/ui/requirement_panel.tscn") as PackedScene
	var overlay_scene := load("res://scenes/ui/inventory_overlay.tscn") as PackedScene
	assert(standalone_scene != null)
	assert(overlay_scene != null)

	var standalone := standalone_scene.instantiate() as Control
	var overlay := overlay_scene.instantiate() as Control
	root.add_child(standalone)
	root.add_child(overlay)
	await process_frame
	await process_frame

	var embedded := overlay.get_node("RequirementPanel") as Control
	_print_panel("standalone", standalone)
	_print_panel("inventory", embedded)

	root.remove_child(standalone)
	root.remove_child(overlay)
	standalone.free()
	overlay.free()
	quit(0)


func _print_panel(label: String, panel: Control) -> void:
	print("--- %s panel pos=%s size=%s min=%s" % [label, panel.position, panel.size, panel.custom_minimum_size])
	for path in PATHS:
		var node := panel.get_node(path) as Control
		print("%s %s pos=%s size=%s min=%s anchors=(%.3f, %.3f, %.3f, %.3f) offsets=(%.3f, %.3f, %.3f, %.3f)" % [
			label,
			path,
			node.position,
			node.size,
			node.custom_minimum_size,
			node.anchor_left,
			node.anchor_top,
			node.anchor_right,
			node.anchor_bottom,
			node.offset_left,
			node.offset_top,
			node.offset_right,
			node.offset_bottom,
		])
