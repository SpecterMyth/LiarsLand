extends SceneTree


const StartMenuScript := preload("res://scripts/ui/start_menu.gd")
const REFERENCE_SIZE := Vector2(1672.0, 941.0)
const START_BUTTON_RECT := Rect2(520.0, 585.0, 636.0, 169.0)
const CHECKS := [
	{
		"window": Vector2i(1600, 900),
		"menu": Vector2(1280, 720)
	},
	{
		"window": Vector2i(960, 720),
		"menu": Vector2(960, 540)
	},
	{
		"window": Vector2i(430, 932),
		"menu": Vector2(430, 932)
	}
]

var frame_count := 0
var check_index := 0
var host: Control
var menu: Control


func _init() -> void:
	_setup_check(0)


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 4:
		return false

	_verify_current_check()
	check_index += 1
	if check_index >= CHECKS.size():
		print("Start menu layout check passed.")
		quit(0)
		return true

	_setup_check(check_index)
	return false


func _setup_check(index: int) -> void:
	if host != null:
		host.queue_free()

	var check: Dictionary = CHECKS[index]
	DisplayServer.window_set_size(check["window"])
	host = Control.new()
	host.size = check["menu"]
	root.add_child(host)

	menu = StartMenuScript.new()
	host.add_child(menu)
	frame_count = 0


func _verify_current_check() -> void:
	var check: Dictionary = CHECKS[check_index]
	var expected_size: Vector2 = check["menu"]
	var start_button := menu.get("start_button") as Button
	var button_visual := menu.get("button_visual") as TextureRect
	_expect(start_button != null, "missing start button")
	_expect(button_visual != null, "missing start button visual")

	var expected_rect := _expected_rect(START_BUTTON_RECT, expected_size)
	var button_rect := start_button.get_global_rect()
	_expect(button_rect.position.distance_to(expected_rect.position) < 1.0, "start button position drifted for menu size %s: got %s expected %s" % [expected_size, button_rect.position, expected_rect.position])
	_expect(button_rect.size.distance_to(expected_rect.size) < 1.0, "start button size drifted for menu size %s: got %s expected %s" % [expected_size, button_rect.size, expected_rect.size])
	_expect(button_visual.get_global_rect().position.distance_to(button_rect.position) < 1.0, "button visual no longer matches hit area")
	_expect(button_visual.get_global_rect().size.distance_to(button_rect.size) < 1.0, "button visual size no longer matches hit area")


func _expected_rect(reference_rect: Rect2, viewport_size: Vector2) -> Rect2:
	var scale := Vector2(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	return Rect2(reference_rect.position * scale, reference_rect.size * scale)


func _expect(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
