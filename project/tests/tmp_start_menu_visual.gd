extends SceneTree


const StartMenuScript := preload("res://scripts/ui/start_menu.gd")
const SHOT_PATH := "res://../ui/visual_tests/start_menu_runtime.png"

var frame_count := 0
var menu: Control


func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var viewport_size := Vector2(1280, 720)
	var host := Control.new()
	host.size = viewport_size
	root.add_child(host)

	menu = StartMenuScript.new()
	host.add_child(menu)


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 8:
		return false

	var buttons := _collect_buttons(menu)
	_expect(buttons.size() == 1, "expected exactly one button")
	_expect(buttons[0].name == "StartGameButton", "expected StartGameButton")
	_expect(buttons[0].get_global_rect().size.x > 400.0, "button is too narrow")
	_expect(buttons[0].get_global_rect().size.y > 100.0, "button is too short")

	var background := menu.get_node("StartMenuBackground") as TextureRect
	_expect(background != null, "missing background")
	_expect(background.texture != null, "missing background texture")
	_expect(background.get_global_rect().size == Vector2(1280, 720), "background does not fill viewport")
	var output_path := ProjectSettings.globalize_path(SHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	root.get_texture().get_image().save_png(output_path)
	print("Start menu visual test passed: ", output_path)
	quit(0)
	return true


func _collect_buttons(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons


func _expect(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
