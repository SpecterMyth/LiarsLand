extends SceneTree


const StartMenuScript := preload("res://scripts/ui/start_menu.gd")
const SHOT_PATH := "res://../ui/visual_tests/start_menu_runtime.png"
const REFERENCE_SIZE := Vector2(1672.0, 941.0)
const START_BUTTON_RECT := Rect2(520.0, 585.0, 636.0, 169.0)

var frame_count := 0
var menu: Control
var host: Control
var expected_viewport_size := Vector2(1280, 720)


func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	host = Control.new()
	host.size = expected_viewport_size
	root.add_child(host)

	menu = StartMenuScript.new()
	host.add_child(menu)


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 8:
		return false

	var buttons := _collect_buttons(menu)
	var start_buttons := buttons.filter(func(button: Button) -> bool: return button.name == "StartGameButton")
	_expect(start_buttons.size() == 1, "expected one StartGameButton")
	var expected_start_rect := _expected_rect(START_BUTTON_RECT, expected_viewport_size)
	_expect(start_buttons[0].get_global_rect().position.distance_to(expected_start_rect.position) < 1.0, "start button position follows root window size instead of menu size")
	_expect(start_buttons[0].get_global_rect().size.distance_to(expected_start_rect.size) < 1.0, "start button size follows root window size instead of menu size")
	_expect(menu.find_child("MenuRulesButton", true, false) != null, "missing rules button")
	_expect(menu.find_child("MenuSettingsButton", true, false) != null, "missing settings button")
	_expect(menu.find_child("StartButtonVisual", true, false) != null, "missing state visual")

	var background := menu.get_node("StartMenuBackground") as TextureRect
	_expect(background != null, "missing background")
	_expect(background.texture != null, "missing background texture")
	_expect(background.get_global_rect().size == expected_viewport_size, "background does not fill menu viewport")
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


func _expected_rect(reference_rect: Rect2, viewport_size: Vector2) -> Rect2:
	var scale := Vector2(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	return Rect2(reference_rect.position * scale, reference_rect.size * scale)


func _expect(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
