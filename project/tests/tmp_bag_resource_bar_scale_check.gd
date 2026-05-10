extends SceneTree

var frame_count := 0
var bar: Control


func _init() -> void:
	var packed := load("res://scenes/ui/bag_resource_bar.tscn") as PackedScene
	assert(packed != null)
	bar = packed.instantiate() as Control
	root.add_child(bar)
	bar.size = Vector2(275, 50)


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count == 2:
		var energy := bar.get_node("EnergyPlate/EnergyValue") as Label
		var capacity := bar.get_node("CapacityPlate/CapacityValue") as Label
		assert(energy.get_theme_font_size("font_size") == 14)
		assert(capacity.get_theme_font_size("font_size") == 14)
		bar.size = Vector2(550, 100)
		return false
	if frame_count < 4:
		return false
	var energy := bar.get_node("EnergyPlate/EnergyValue") as Label
	var capacity := bar.get_node("CapacityPlate/CapacityValue") as Label
	assert(energy.get_theme_font_size("font_size") == 28)
	assert(capacity.get_theme_font_size("font_size") == 28)
	print("Bag resource bar font scale check passed.")
	quit(0)
	return true
