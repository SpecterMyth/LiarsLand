extends Control

signal resolved(confirmed: bool, value)

const COMMON_UI_ROOT := "res://assets/ui/common/"
const DIALOGUE_UI_ROOT := "res://assets/generated/ui/dialogue/"
const UI_FONT_PATH := "res://assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf"
const StandardButtonScript := preload("res://scripts/ui/standard_button.gd")

var _backdrop: Button
var _panel: PanelContainer
var _title_wrap: Control
var _title_back: Control
var _title_label: Label
var _body_label: Label
var _content_holder: VBoxContainer
var _scroll: ScrollContainer
var _countdown_footer: VBoxContainer
var _cancel_button: Button
var _confirm_button: Button
var _buttons_row: HBoxContainer
var _font: Font
var _pending_value = null
var _selected_choice = null
var _selected_button: Button = null
var _is_waiting := false
var _last_confirmed := false
var _design_panel_size := Vector2(880, 430)
var _design_title_anchor_right := 0.56
var _design_title_font_size := 30
var _design_cancel_button_size := Vector2(192, 58)
var _design_confirm_button_size := Vector2(192, 58)
var _design_button_separation := 18
var _compact_countdown_layout := false
var _preferred_panel_size := Vector2.ZERO
var _countdown_scroll_height := 118.0


func _ready() -> void:
	_font = load(UI_FONT_PATH) if ResourceLoader.exists(UI_FONT_PATH) else null
	_build()
	hide()


func show_message(title: String, body: String, confirm_text := "确定", cancel_text := "取消") -> bool:
	var result = await show_with_content(title, _make_body_label(body), confirm_text, cancel_text)
	return bool(result)


func show_countdown_message(title: String, body: String, seconds := 10.0, cancel_text := "取消", confirm_text := "确认") -> bool:
	_prepare(title, "", cancel_text)
	_compact_countdown_layout = true
	_clear_content()
	_confirm_button.text = confirm_text
	_confirm_button.visible = true
	_confirm_button.disabled = false
	_update_button_labels()
	var body_label := _make_body_label(body)
	_content_holder.add_child(body_label)
	var footer := _ensure_countdown_footer()
	footer.visible = true
	_countdown_scroll_height = _measure_countdown_content_height(body_label)
	_update_layout_for_viewport()
	var countdown := _make_body_label("%d 秒后执行" % int(ceil(seconds)))
	countdown.name = "CountdownLabel"
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(countdown)
	var progress := ProgressBar.new()
	progress.name = "CountdownProgress"
	progress.min_value = 0.0
	progress.max_value = max(seconds, 0.01)
	progress.value = seconds
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 24)
	footer.add_child(progress)
	_update_layout_for_viewport()
	_show_modal()
	var elapsed := 0.0
	while _is_waiting and elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var left: float = max(0.0, seconds - elapsed)
		progress.value = left
		countdown.text = "%d 秒后执行" % int(ceil(left))
	if _is_waiting:
		_finish(true, null)
		return true
	return _last_confirmed


func show_countdown_with_content(title: String, content: Control, seconds := 10.0, cancel_text := "取消", confirm_text := "确认", auto_confirm := true) -> bool:
	_prepare(title, confirm_text, cancel_text)
	_compact_countdown_layout = true
	_clear_content()
	if content != null:
		if content.has_meta("modal_panel_size"):
			var preferred_size = content.get_meta("modal_panel_size")
			if preferred_size is Vector2:
				_preferred_panel_size = preferred_size
		if content.get_parent() != null:
			content.get_parent().remove_child(content)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not bool(content.get_meta("preserve_content_theme", false)):
			_apply_black_text_theme(content)
		_content_holder.add_child(content)
	var footer := _ensure_countdown_footer()
	footer.visible = true
	_countdown_scroll_height = _measure_countdown_content_height(content)
	_update_layout_for_viewport()
	var countdown := _make_body_label("%d 秒后%s" % [int(ceil(seconds)), "自动确认" if auto_confirm else "自动拒绝"])
	countdown.name = "CountdownLabel"
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(countdown)
	var progress := ProgressBar.new()
	progress.name = "CountdownProgress"
	progress.min_value = 0.0
	progress.max_value = max(seconds, 0.01)
	progress.value = seconds
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 24)
	footer.add_child(progress)
	_update_layout_for_viewport()
	_show_modal()
	var elapsed := 0.0
	while _is_waiting and elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var left: float = max(0.0, seconds - elapsed)
		progress.value = left
		countdown.text = "%d 秒后%s" % [int(ceil(left)), "自动确认" if auto_confirm else "自动拒绝"]
	if _is_waiting:
		_finish(auto_confirm, null)
		return auto_confirm
	return _last_confirmed


func show_with_content(title: String, content: Control, confirm_text := "确定", cancel_text := "取消") -> bool:
	_prepare(title, confirm_text, cancel_text)
	_clear_content()
	if content != null:
		if content.get_parent() != null:
			content.get_parent().remove_child(content)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not bool(content.get_meta("preserve_content_theme", false)):
			_apply_black_text_theme(content)
		_content_holder.add_child(content)
	_show_modal()
	var response: Array = await resolved
	return bool(response[0])


func show_choice_list(title: String, body: String, choices: Array, cancel_text := "取消"):
	_prepare(title, "确定", cancel_text)
	_clear_content()
	_selected_choice = null
	_selected_button = null
	_confirm_button.disabled = true
	if not body.is_empty():
		_content_holder.add_child(_make_body_label(body))
	var list := VBoxContainer.new()
	list.name = "ChoiceList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	for choice in choices:
		var choice_data := _normalize_choice(choice)
		var button := _make_choice_button(choice_data.get("label", ""), choice_data.get("icon", null))
		button.pressed.connect(func(data := choice_data, target := button): _select_choice(data.get("value", null), target))
		list.add_child(button)
	_content_holder.add_child(list)
	_show_modal()
	var response: Array = await resolved
	if bool(response[0]):
		return response[1]
	return null


func cancel() -> void:
	_finish(false, null)


func confirm() -> void:
	_finish(true, _pending_value)


func _build() -> void:
	if _bind_scene_nodes():
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4000

	_backdrop = Button.new()
	_backdrop.name = "Backdrop"
	_backdrop.flat = true
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_backdrop.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_backdrop.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_backdrop.pressed.connect(cancel)
	add_child(_backdrop)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.008, 0.01, 0.70)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "DialogueModalPanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := _texture_style(DIALOGUE_UI_ROOT + "modal_frame_9.png", 34, Color(0.13, 0.055, 0.065, 0.98))
	panel_style.content_margin_top = 86
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 14)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(stack)

	var title_wrap := Control.new()
	title_wrap.name = "TitleWrap"
	title_wrap.custom_minimum_size = Vector2(0, 66)
	title_wrap.offset_left = 26
	title_wrap.offset_top = 13
	title_wrap.offset_right = 519
	title_wrap.offset_bottom = 79
	_panel.add_child(title_wrap)
	_title_wrap = title_wrap

	_title_back = PanelContainer.new()
	_title_back.name = "TitleNameplate"
	var title_style := _texture_style(DIALOGUE_UI_ROOT + "panel_gold_9.png", 32)
	if title_style is StyleBoxTexture:
		var title_texture_style := title_style as StyleBoxTexture
		title_texture_style.texture_margin_left = 32
		title_texture_style.texture_margin_top = 24
		title_texture_style.texture_margin_right = 32
		title_texture_style.texture_margin_bottom = 24
	_title_back.add_theme_stylebox_override("panel", title_style)
	_title_back.anchor_left = 0.0
	_title_back.anchor_top = 0.0
	_title_back.anchor_right = 1.0
	_title_back.anchor_bottom = 1.0
	_title_back.offset_left = -8
	_title_back.offset_top = -4
	_title_back.offset_right = 0
	_title_back.offset_bottom = 4
	title_wrap.add_child(_title_back)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.offset_left = 28
	_title_label.offset_right = -30
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_apply_label_theme(_title_label, 30, Color.BLACK, false)
	_title_back.add_child(_title_label)

	_scroll = ScrollContainer.new()
	_scroll.name = "ContentScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_scroll)

	_content_holder = VBoxContainer.new()
	_content_holder.name = "Content"
	_content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_holder.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content_holder)

	_countdown_footer = VBoxContainer.new()
	_countdown_footer.name = "CountdownFooter"
	_countdown_footer.visible = false
	_countdown_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_countdown_footer.add_theme_constant_override("separation", 8)
	stack.add_child(_countdown_footer)

	_buttons_row = HBoxContainer.new()
	_buttons_row.name = "Buttons"
	_buttons_row.alignment = BoxContainer.ALIGNMENT_END
	_buttons_row.add_theme_constant_override("separation", 18)
	stack.add_child(_buttons_row)

	_cancel_button = _make_modal_button("取消", false)
	_cancel_button.name = "CancelButton"
	_cancel_button.pressed.connect(cancel)
	_buttons_row.add_child(_cancel_button)

	_confirm_button = _make_modal_button("确定", true)
	_confirm_button.name = "ConfirmButton"
	_confirm_button.pressed.connect(confirm)
	_buttons_row.add_child(_confirm_button)
	_capture_design_metrics()


func _bind_scene_nodes() -> bool:
	_backdrop = get_node_or_null("Backdrop") as Button
	_panel = get_node_or_null("DialogueModalPanel") as PanelContainer
	_title_wrap = get_node_or_null("TitleWrap") as Control
	if _title_wrap == null:
		_title_wrap = get_node_or_null("DialogueModalPanel/TitleWrap") as Control
	_title_back = _title_wrap.get_node_or_null("TitleNameplate") as Control if _title_wrap != null else null
	_title_label = _title_back.get_node_or_null("TitleLabel") as Label if _title_back != null else null
	_scroll = get_node_or_null("DialogueModalPanel/Stack/ContentScroll") as ScrollContainer
	_content_holder = get_node_or_null("DialogueModalPanel/Stack/ContentScroll/Content") as VBoxContainer
	_countdown_footer = get_node_or_null("DialogueModalPanel/Stack/CountdownFooter") as VBoxContainer
	_buttons_row = get_node_or_null("DialogueModalPanel/Stack/Buttons") as HBoxContainer
	_cancel_button = get_node_or_null("DialogueModalPanel/Stack/Buttons/CancelButton") as Button
	_confirm_button = get_node_or_null("DialogueModalPanel/Stack/Buttons/ConfirmButton") as Button
	if _backdrop == null or _panel == null or _title_wrap == null or _title_back == null or _title_label == null or _scroll == null or _content_holder == null or _buttons_row == null or _cancel_button == null or _confirm_button == null:
		return false

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4000
	_backdrop.flat = true
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_backdrop.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_backdrop.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	if not _backdrop.pressed.is_connected(cancel):
		_backdrop.pressed.connect(cancel)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_normalize_title_layout()
	if _title_back is TextureRect:
		(_title_back as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		(_title_back as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	_title_label.clip_text = true
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_theme(_title_label, 30, Color.BLACK, false)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_holder.add_theme_constant_override("separation", 12)
	_ensure_countdown_footer()
	_buttons_row.alignment = BoxContainer.ALIGNMENT_END
	_buttons_row.add_theme_constant_override("separation", 18)
	_setup_scene_button(_cancel_button, false, cancel)
	_setup_scene_button(_confirm_button, true, confirm)
	_capture_design_metrics()
	return true


func _normalize_title_layout() -> void:
	if _panel == null or _title_wrap == null or _title_back == null:
		return
	if _title_wrap.get_parent() != self:
		_title_wrap.get_parent().remove_child(_title_wrap)
		add_child(_title_wrap)
	_title_wrap.move_to_front()
	_title_wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_title_wrap.custom_minimum_size = Vector2(0, 66)
	_title_back.anchor_left = 0.0
	_title_back.anchor_top = 0.0
	_title_back.anchor_right = 1.0
	_title_back.anchor_bottom = 1.0
	_title_back.offset_left = -8
	_title_back.offset_top = -4
	_title_back.offset_right = 0
	_title_back.offset_bottom = 4
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_label.offset_left = 28
	_title_label.offset_right = -30


func _capture_design_metrics() -> void:
	if _panel != null:
		_design_panel_size = _panel.custom_minimum_size
		if _design_panel_size.x <= 0.0 or _design_panel_size.y <= 0.0:
			_design_panel_size = _panel.size
		if _design_panel_size.x <= 0.0:
			_design_panel_size.x = 880.0
		if _design_panel_size.y <= 0.0:
			_design_panel_size.y = 430.0
	if _title_back != null:
		_design_title_anchor_right = _title_back.anchor_right
	if _title_label != null:
		_design_title_font_size = int(_title_label.get_theme_font_size("font_size"))
		if _design_title_font_size <= 0:
			_design_title_font_size = 30
	if _cancel_button != null:
		_design_cancel_button_size = _cancel_button.custom_minimum_size
	if _confirm_button != null:
		_design_confirm_button_size = _confirm_button.custom_minimum_size
	if _buttons_row != null:
		_design_button_separation = _buttons_row.get_theme_constant("separation")


func _setup_scene_button(button: Button, primary: bool, pressed_callable: Callable) -> void:
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 24)
	if _font != null:
		button.add_theme_font_override("font", _font)
	_apply_button_style(button, primary, false)
	if not button.pressed.is_connected(pressed_callable):
		button.pressed.connect(pressed_callable)
	if not button.has_meta("common_modal_pulse_wired"):
		button.set_meta("common_modal_pulse_wired", true)
		button.mouse_entered.connect(func(target := button): _pulse(target, Vector2(1.025, 1.025)))
		button.pressed.connect(func(target := button): _pulse(target, Vector2(0.965, 0.965)))


func _prepare(title: String, confirm_text: String, cancel_text: String) -> void:
	_pending_value = null
	_is_waiting = true
	_last_confirmed = false
	_compact_countdown_layout = false
	_preferred_panel_size = Vector2.ZERO
	_countdown_scroll_height = 118.0
	_title_label.text = title
	_cancel_button.text = cancel_text
	_confirm_button.text = confirm_text
	_confirm_button.visible = true
	_confirm_button.disabled = false
	_clear_countdown_footer()
	_update_layout_for_viewport()
	_update_button_labels()


func _show_modal() -> void:
	show()
	move_to_front()
	_panel.scale = Vector2(0.965, 0.965)
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.10)


func _finish(confirmed: bool, value) -> void:
	if not _is_waiting:
		return
	_is_waiting = false
	_last_confirmed = confirmed
	hide()
	resolved.emit(confirmed, value)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _is_waiting:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept") and not _confirm_button.disabled:
		get_viewport().set_input_as_handled()
		confirm()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _panel != null:
		_update_layout_for_viewport()


func _update_layout_for_viewport() -> void:
	var viewport_size := _get_layout_size()
	var target_size := _preferred_panel_size if _preferred_panel_size.x > 0.0 and _preferred_panel_size.y > 0.0 else _design_panel_size
	var width: float = min(target_size.x, max(320.0, viewport_size.x - 32.0))
	var height: float = min(target_size.y, max(280.0, viewport_size.y - 64.0))
	var footer_visible := _countdown_footer != null and _countdown_footer.visible
	if footer_visible or _compact_countdown_layout:
		var countdown_height := _countdown_panel_height(width)
		height = min(height, max(280.0, min(countdown_height, viewport_size.y - 64.0)))
	_apply_panel_margins(width)
	_panel.custom_minimum_size = Vector2(width, height)
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = floor((viewport_size.x - width) * 0.5)
	_panel.offset_top = floor((viewport_size.y - height) * 0.5)
	_panel.offset_right = _panel.offset_left + width
	_panel.offset_bottom = _panel.offset_top + height
	_title_wrap.offset_left = _panel.offset_left + 26
	_title_wrap.offset_top = max(8.0, _panel.offset_top - 33.0)
	_title_wrap.offset_right = _title_wrap.offset_left + min(493.0, width - 52.0)
	_title_wrap.offset_bottom = _title_wrap.offset_top + 66
	var scroll_height: float
	if footer_visible:
		scroll_height = max(72.0, height - _countdown_footer_reserved_height(width))
	else:
		scroll_height = max(118.0, height - 178.0)
	_scroll.custom_minimum_size = Vector2(0, scroll_height)
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if footer_visible else Control.SIZE_EXPAND_FILL
	if _countdown_footer != null:
		_countdown_footer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_buttons_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_title_label.add_theme_font_size_override("font_size", 22 if width < 520.0 else _design_title_font_size)
	if width < 520.0:
		var available_button_width := (width - 92.0) * 0.5
		var button_width := clampf(available_button_width, 112.0, 136.0)
		_cancel_button.custom_minimum_size = Vector2(button_width, min(_design_cancel_button_size.y, 54.0))
		_confirm_button.custom_minimum_size = Vector2(button_width, min(_design_confirm_button_size.y, 54.0))
		_buttons_row.add_theme_constant_override("separation", 10)
	else:
		_cancel_button.custom_minimum_size = _design_cancel_button_size
		_confirm_button.custom_minimum_size = _design_confirm_button_size
		_buttons_row.add_theme_constant_override("separation", _design_button_separation)


func _apply_panel_margins(width: float) -> void:
	var style := _panel.get_theme_stylebox("panel")
	if style == null:
		return
	var margin_style := style.duplicate() as StyleBox
	if margin_style == null:
		return
	var side_margin := 28.0 if width < 520.0 else (44.0 if _preferred_panel_size.x > 0.0 else 60.0)
	margin_style.content_margin_left = side_margin
	margin_style.content_margin_right = side_margin
	margin_style.content_margin_top = 56.0 if _preferred_panel_size.x > 0.0 else 70.0
	margin_style.content_margin_bottom = 0.0
	_panel.add_theme_stylebox_override("panel", margin_style)


func _get_layout_size() -> Vector2:
	var layout_size := size
	if layout_size.x > 0.0 and layout_size.y > 0.0:
		return layout_size

	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return parent_control.size

	return get_viewport_rect().size


func _countdown_panel_height(width: float) -> float:
	if _preferred_panel_size.y > 0.0:
		return _preferred_panel_size.y
	var chrome_height := 196.0
	var max_height := 348.0 if width >= 720.0 else 332.0
	return min(max_height, chrome_height + _countdown_scroll_height)


func _countdown_footer_reserved_height(width: float) -> float:
	var button_height: float = min(_design_cancel_button_size.y, 54.0) if width < 520.0 else _design_cancel_button_size.y
	var countdown_height := 34.0
	var progress_height := 24.0
	var footer_gap := 8.0
	var stack_gaps := 28.0
	var top_margin: float = 56.0 if _preferred_panel_size.x > 0.0 else 70.0
	var safety := 10.0
	return top_margin + countdown_height + progress_height + footer_gap + button_height + stack_gaps + safety


func _measure_countdown_content_height(content: Control) -> float:
	if content == null:
		return 96.0
	var measured := content.get_combined_minimum_size().y
	if measured <= 0.0:
		measured = content.custom_minimum_size.y
	if content is Label:
		var label := content as Label
		var lines: int = maxi(1, label.text.count("\n") + 1)
		measured = max(measured, float(lines) * 34.0)
	return clampf(measured + 8.0, 72.0, 156.0)


func _clear_content() -> void:
	for child in _content_holder.get_children():
		_content_holder.remove_child(child)
		child.queue_free()


func _ensure_countdown_footer() -> VBoxContainer:
	if _countdown_footer == null:
		_countdown_footer = VBoxContainer.new()
		_countdown_footer.name = "CountdownFooter"
		_countdown_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_countdown_footer.add_theme_constant_override("separation", 8)
		var stack := _buttons_row.get_parent()
		stack.add_child(_countdown_footer)
		stack.move_child(_countdown_footer, _buttons_row.get_index())
	else:
		_countdown_footer.add_theme_constant_override("separation", 8)
		if _buttons_row != null and _countdown_footer.get_parent() == _buttons_row.get_parent():
			if _countdown_footer.get_index() > _buttons_row.get_index():
				_countdown_footer.get_parent().move_child(_countdown_footer, _buttons_row.get_index())
	_clear_countdown_footer()
	return _countdown_footer


func _clear_countdown_footer() -> void:
	if _countdown_footer == null:
		return
	for child in _countdown_footer.get_children():
		_countdown_footer.remove_child(child)
		child.queue_free()
	_countdown_footer.visible = false


func _make_body_label(text: String) -> Label:
	var label := Label.new()
	label.name = "BodyLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_apply_label_theme(label, 23, Color.BLACK, false)
	return label


func _make_choice_button(text: String, icon: Texture2D = null) -> Button:
	var button := _make_modal_button(text, false)
	button.name = "ChoiceButton"
	button.custom_minimum_size = Vector2(0, 58)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "   %s" % text
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.name = "ChoiceIcon"
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.5
		icon_rect.anchor_right = 0.0
		icon_rect.anchor_bottom = 0.5
		icon_rect.offset_left = 12
		icon_rect.offset_top = -19
		icon_rect.offset_right = 50
		icon_rect.offset_bottom = 19
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon_rect)
	return button


func _select_choice(value, button: Button) -> void:
	_selected_choice = value
	_pending_value = value
	_selected_button = button
	_confirm_button.disabled = false
	for child in _content_holder.find_children("ChoiceButton", "Button", true, false):
		if child is Button:
			_apply_button_style(child, false, child == _selected_button)


func _normalize_choice(choice) -> Dictionary:
	if typeof(choice) == TYPE_DICTIONARY:
		return {
			"label": String(choice.get("label", choice.get("text", ""))),
			"value": choice.get("value", choice),
			"icon": choice.get("icon", null)
		}
	return {"label": str(choice), "value": choice, "icon": null}


func _make_modal_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(192, 58)
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 24)
	if _font != null:
		button.add_theme_font_override("font", _font)
	_apply_button_style(button, primary, false)
	button.mouse_entered.connect(func(target := button): _pulse(target, Vector2(1.025, 1.025)))
	button.pressed.connect(func(target := button): _pulse(target, Vector2(0.965, 0.965)))
	return button


func _apply_button_style(button: Button, primary: bool, selected: bool) -> void:
	var style := StandardButtonScript.PRIMARY if primary or selected else StandardButtonScript.SECONDARY
	StandardButtonScript.apply(button, style, button.text, 24)
	if _font != null:
		button.add_theme_font_override("font", _font)


func _update_button_labels() -> void:
	for button in [_cancel_button, _confirm_button]:
		button.tooltip_text = button.text


func _apply_label_theme(label: Label, size: int, color: Color, outlined: bool) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if _font != null:
		label.add_theme_font_override("font", _font)
	if outlined:
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	else:
		label.add_theme_constant_override("outline_size", 0)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))


func _apply_black_text_theme(root: Control) -> void:
	if root is Label:
		var label := root as Label
		if _font != null:
			label.add_theme_font_override("font", _font)
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 0)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	elif root is Button:
		var button := root as Button
		if _font != null:
			button.add_theme_font_override("font", _font)
		button.add_theme_color_override("font_color", Color.BLACK)
		button.add_theme_color_override("font_hover_color", Color.BLACK)
		button.add_theme_color_override("font_pressed_color", Color.BLACK)
		button.add_theme_color_override("font_disabled_color", Color(0.0, 0.0, 0.0, 0.55))
		button.add_theme_constant_override("outline_size", 0)
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	for child in root.get_children():
		if child is Control:
			_apply_black_text_theme(child)


func _texture_style(path: String, margin: int, fallback_color := Color(0.12, 0.06, 0.06, 0.96)) -> StyleBox:
	var texture := _load_texture(path)
	if texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fallback_color
		flat.border_color = Color(0.86, 0.58, 0.22, 1.0)
		flat.set_border_width_all(3)
		flat.set_corner_radius_all(8)
		flat.content_margin_left = margin
		flat.content_margin_right = margin
		flat.content_margin_top = max(8, margin / 2)
		flat.content_margin_bottom = max(8, margin / 2)
		return flat
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = max(8, margin / 2)
	style.content_margin_bottom = max(8, margin / 2)
	return style


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if OS.has_feature("web"):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _pulse(node: Control, target_scale: Vector2) -> void:
	if node == null:
		return
	var tween := create_tween()
	tween.tween_property(node, "scale", target_scale, 0.05)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
