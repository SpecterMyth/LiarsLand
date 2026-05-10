extends SceneTree

const VIEWPORT_SIZE := Vector2(1280, 720)
const SCENE_PATH := "res://scenes/ui/inventory_overlay.tscn"
const SCREENSHOT_PATH := "res://../tmp/inventory_overlay_visual_check.png"

var _failures: Array[String] = []
var _frame_count := 0
var _overlay: Control


func _init() -> void:
	print("inventory visual: init")
	root.size = VIEWPORT_SIZE
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Failed to load %s" % SCENE_PATH)
		quit(1)
		return

	_overlay = scene.instantiate() as Control
	if _overlay == null:
		push_error("Scene root is not a Control")
		quit(1)
		return

	root.add_child(_overlay)
	_overlay.visible = true
	print("inventory visual: scene added")


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count == 1:
		print("inventory visual: first frame")
	if _frame_count < 6:
		return false

	print("inventory visual: checking")
	_check_controls(_overlay)
	if not DisplayServer.get_name().contains("headless"):
		var texture := root.get_texture()
		var image := texture.get_image()
		if image != null:
			image.save_png(SCREENSHOT_PATH)

	if _failures.is_empty():
		print("PASS inventory overlay fits %sx%s" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y])
		print("SCREENSHOT %s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _check_controls(root_control: Control) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, VIEWPORT_SIZE)
	for node in root_control.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.visible:
			continue
		var rect := control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			_failures.append("%s has non-positive size: %s" % [control.get_path(), rect])
			continue
		if not viewport_rect.encloses(rect):
			_failures.append("%s out of bounds: %s" % [control.get_path(), rect])
