extends SceneTree


const StartMenuScript := preload("res://scripts/ui/start_menu.gd")
const OUT_DIR := "res://../ui/visual_tests/"

var frame_count := 0
var menu: Control
var button: Button
var saved_normal: Image
var saved_hover: Image


func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)

	menu = StartMenuScript.new()
	host.add_child(menu)


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count == 8:
		button = menu.get("start_button")
		_expect(button != null, "missing start button")
		saved_normal = _save("start_menu_button_normal.png")
		menu.call("_set_button_state", "hover")
	elif frame_count == 10:
		saved_hover = _save("start_menu_button_hover.png")
		menu.call("_set_button_state", "pressed")
	elif frame_count == 12:
		var pressed := _save("start_menu_button_pressed.png")
		_expect(_sample_luma(saved_hover) > _sample_luma(saved_normal) + 0.01, "hover state is not brighter than normal")
		_expect(_sample_luma(pressed) < _sample_luma(saved_hover) - 0.03, "pressed state is not darker than hover")
		print("Start menu button state visual test passed.")
		quit(0)
	return false


func _save(name: String) -> Image:
	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(OUT_DIR + name)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	image.save_png(output_path)
	return image


func _sample_luma(image: Image) -> float:
	var sample_rect := button.get_global_rect()
	var image_scale := Vector2(float(image.get_width()) / 1280.0, float(image.get_height()) / 720.0)
	var x0 := int((sample_rect.position.x + sample_rect.size.x * 0.16) * image_scale.x)
	var x1 := int((sample_rect.position.x + sample_rect.size.x * 0.28) * image_scale.x)
	var y0 := int((sample_rect.position.y + sample_rect.size.y * 0.44) * image_scale.y)
	var y1 := int((sample_rect.position.y + sample_rect.size.y * 0.56) * image_scale.y)
	var total := 0.0
	var count := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var color := image.get_pixel(x, y)
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			count += 1
	return total / max(1, count)


func _expect(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
