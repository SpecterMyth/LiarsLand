extends Control

const BASE_SIZE := Vector2(1672.0, 941.0)
const GENERATED_ROOT := "res://assets/generated/"
const COUNCIL_ICON_ROOT := "res://assets/generated/ui/council_icons/"
const CHARACTER_ROOT := "res://assets/ui/characters/"
const CHARACTER_HEADICON_ROOT := CHARACTER_ROOT + "headicon/"
const CHARACTER_PORTRAIT_ROOT := CHARACTER_ROOT + "portrait/"
const CHARACTER_PORTRAIT_HALF_ROOT := CHARACTER_ROOT + "portrait_half/"
const VFX_ROOT := "res://assets/generated/action_vfx/"

var _blocker: ColorRect
var _stage: Control
var _actor_layer: Control
var _ui_layer: Control
var _vfx_layer: Control
var _player_bust: TextureRect
var _npc_bust: TextureRect
var _player_name: Label
var _npc_name: Label
var _title: Label
var _current_crime_card: Control
var _current_crime_icon: TextureRect
var _current_crime_title: Label
var _current_crime_meta: Label
var _triggered_row: Control
var _triggered_row_icon: TextureRect
var _triggered_row_title: Label
var _triggered_row_meta: Label
var _result_label: Label
var _last_words_label: Label
var _top_heads: Dictionary = {}
var _top_head_row: Control
var _current_npc_id := ""
var _dead_members: Dictionary = {}


func _ready() -> void:
	visible = false
	z_index = 4093
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_sync_full_rects()


func play_timeline(timeline: Array, state) -> void:
	if timeline.is_empty() or state == null:
		return
	_reset()
	_current_npc_id = _current_npc_id_from_state(state)
	visible = true
	move_to_front()
	_configure_actors(state)
	_configure_top_heads(state)
	await get_tree().process_frame
	await _play_intro()
	for raw_step in timeline:
		if typeof(raw_step) != TYPE_DICTIONARY:
			continue
		await _play_execution_step(raw_step, state)
	await _show_result_hold()
	visible = false
	_clear_runtime()


func debug_state() -> Dictionary:
	return {
		"visible": visible,
		"top_head_count": _top_heads.size(),
		"dead_count": _dead_members.size(),
		"has_crime_card": _current_crime_card != null,
		"has_triggered_row": _triggered_row != null
	}


func debug_show_timeline_step(timeline: Array, state, step_index := 0, phase := "execution") -> void:
	if timeline.is_empty() or state == null:
		return
	_reset()
	_sync_full_rects()
	_current_npc_id = _current_npc_id_from_state(state)
	visible = true
	_configure_actors(state)
	_configure_top_heads(state)
	_title.text = "本回合投票正在结算"
	_title.modulate = Color.WHITE
	_player_bust.modulate = Color.WHITE
	_npc_bust.modulate = Color.WHITE
	_player_name.modulate = Color.WHITE
	_npc_name.modulate = Color.WHITE
	for head in _top_heads.values():
		head.modulate = Color.WHITE
	var step: Dictionary = timeline[clampi(step_index, 0, timeline.size() - 1)]
	_configure_crime(step, state)
	_current_crime_card.modulate = Color.WHITE
	_triggered_row.modulate = Color.WHITE
	if phase in ["votes", "execution", "chain"]:
		var votes: Array = step.get("votes", [])
		var crime_center := _triggered_row.get_global_rect().get_center()
		var left_index := 0
		var right_index := 0
		for record in votes:
			if typeof(record) != TYPE_DICTIONARY or String(record.get("vote", "")) != "guilty":
				continue
			var member_id := String(record.get("member_id", ""))
			var pin_pos := crime_center + Vector2(_scale_x(-470 - 42 * left_index), 0) if member_id == "player" else crime_center + Vector2(_scale_x(470 + 42 * right_index), 0)
			if member_id == "player":
				left_index += 1
			else:
				right_index += 1
			var pin := _make_avatar_node(_avatar_path(member_id), 36.0)
			pin.global_position = pin_pos - Vector2(18, 18)
			_vfx_layer.add_child(pin)
	if phase in ["execution", "chain"]:
		var victims: Array = step.get("victims", [])
		var names: Array[String] = []
		for victim in victims:
			if typeof(victim) != TYPE_DICTIONARY:
				continue
			var member_id := String(victim.get("member_id", ""))
			names.append(String(victim.get("name", member_id)))
			_spawn_pinned_crime(String(step.get("crime_id", "")), member_id, _member_anchor(member_id))
			var burst := _make_burst(_member_anchor(member_id), member_id == "player" or member_id == _current_npc_id)
			burst.modulate = Color.WHITE
			burst.scale = Vector2.ONE
			_vfx_layer.add_child(burst)
			_mark_member_dead(member_id)
		_title.text = "“%s” 同时命中：%s" % [String(step.get("crime_title", "")), "、".join(names)]
	if phase == "chain":
		_last_words_label.text = "遗言投票触发下一轮处决，按 step 顺序继续播放"
		_last_words_label.modulate = Color.WHITE


func _build() -> void:
	_blocker = ColorRect.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.color = Color.BLACK
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_actor_layer = _make_layer("ActorLayer", 10)
	_vfx_layer = _make_layer("VfxLayer", 20)
	_ui_layer = _make_layer("UiLayer", 30)

	_title = _make_label("", 30, Color(1.0, 0.91, 0.70, 1.0), 5)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_title, Rect2(260, 54, 1152, 54))
	_ui_layer.add_child(_title)

	_player_bust = _make_texture_rect(Rect2(42, 318, 470, 620))
	_actor_layer.add_child(_player_bust)
	_player_name = _make_nameplate()
	_place(_player_name, Rect2(156, 884, 260, 42))
	_ui_layer.add_child(_player_name)

	_npc_bust = _make_texture_rect(Rect2(1160, 318, 470, 620))
	_actor_layer.add_child(_npc_bust)
	_npc_name = _make_nameplate()
	_place(_npc_name, Rect2(1256, 884, 260, 42))
	_ui_layer.add_child(_npc_name)

	_top_head_row = Control.new()
	_top_head_row.name = "TopHeadRow"
	_top_head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_top_head_row)

	_current_crime_card = _make_panel(Color(0.06, 0.04, 0.045, 0.90), Color(0.95, 0.68, 0.22, 0.52), 4)
	_place(_current_crime_card, Rect2(526, 250, 620, 150))
	_ui_layer.add_child(_current_crime_card)
	_current_crime_icon = _make_texture_rect(Rect2(278, 40, 64, 64), false)
	_current_crime_card.add_child(_current_crime_icon)
	_current_crime_meta = _make_label("最新触发罪行", 18, Color(0.70, 0.63, 0.48, 1.0), 2)
	_current_crime_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_current_crime_meta, Rect2(70, 12, 480, 24), false)
	_current_crime_card.add_child(_current_crime_meta)
	_current_crime_title = _make_label("", 26, Color(1.0, 0.88, 0.50, 1.0), 4)
	_current_crime_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_current_crime_title, Rect2(40, 108, 540, 34), false)
	_current_crime_card.add_child(_current_crime_title)

	_triggered_row = _make_panel(Color(0.05, 0.035, 0.04, 0.90), Color(0.95, 0.68, 0.22, 0.30), 3)
	_place(_triggered_row, Rect2(466, 622, 740, 78))
	_ui_layer.add_child(_triggered_row)
	_triggered_row_icon = _make_texture_rect(Rect2(14, 10, 52, 52), false)
	_triggered_row.add_child(_triggered_row_icon)
	_triggered_row_title = _make_label("", 20, Color(1.0, 0.88, 0.58, 1.0), 3)
	_place(_triggered_row_title, Rect2(86, 8, 560, 30), false)
	_triggered_row.add_child(_triggered_row_title)
	_triggered_row_meta = _make_label("", 15, Color(0.72, 0.64, 0.48, 1.0), 2)
	_place(_triggered_row_meta, Rect2(86, 40, 590, 24), false)
	_triggered_row.add_child(_triggered_row_meta)

	_last_words_label = _make_label("", 19, Color(1.0, 0.88, 0.62, 1.0), 3)
	_last_words_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_last_words_label, Rect2(558, 720, 556, 54))
	_ui_layer.add_child(_last_words_label)

	_result_label = _make_label("", 24, Color(1.0, 0.91, 0.70, 1.0), 4)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_result_label, Rect2(520, 794, 632, 56))
	_ui_layer.add_child(_result_label)


func _make_layer(layer_name: String, z: int) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	_stage.add_child(layer)
	return layer


func _sync_full_rects() -> void:
	_stretch_to_parent(self)
	if _blocker != null:
		_stretch_to_parent(_blocker)
	if _stage != null:
		_stretch_to_parent(_stage)
	for layer in [_actor_layer, _vfx_layer, _ui_layer]:
		if layer != null:
			_stretch_to_parent(layer)


func _stretch_to_parent(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _reset() -> void:
	_clear_runtime()
	_sync_full_rects()
	_dead_members.clear()
	_title.text = "本回合投票正在结算"
	_title.modulate = Color(1, 1, 1, 0)
	_current_crime_card.modulate = Color(1, 1, 1, 0)
	_triggered_row.modulate = Color(1, 1, 1, 0)
	_last_words_label.text = ""
	_last_words_label.modulate = Color(1, 1, 1, 0)
	_result_label.text = ""
	_result_label.modulate = Color(1, 1, 1, 0)
	_player_bust.modulate = Color(1, 1, 1, 0)
	_npc_bust.modulate = Color(1, 1, 1, 0)
	_player_name.modulate = Color(1, 1, 1, 0)
	_npc_name.modulate = Color(1, 1, 1, 0)


func _clear_runtime() -> void:
	for child in _vfx_layer.get_children():
		child.queue_free()
	for child in _top_head_row.get_children():
		child.queue_free()
	_top_heads.clear()


func _configure_actors(state) -> void:
	_player_bust.texture = _load_texture(_half_portrait_path(state.player, true))
	_player_name.text = String(state.player.get("public_name", "你"))
	var npc := _member_by_id(state, _current_npc_id)
	if npc.is_empty() and state.has_method("current_npc"):
		npc = state.current_npc()
	_npc_bust.texture = _load_texture(_half_portrait_path(npc, false))
	_npc_name.text = String(npc.get("public_name", "对方"))


func _configure_top_heads(state) -> void:
	var members := _all_members(state)
	var heads: Array = []
	for member in members:
		var member_id := String(member.get("id", ""))
		if member_id.is_empty() or member_id == "player" or member_id == _current_npc_id:
			continue
		heads.append(member)
	var head_size := 58.0
	var gap := 12.0
	var total_width: float = float(heads.size()) * head_size + float(max(0, heads.size() - 1)) * gap
	var start_x: float = BASE_SIZE.x * 0.5 - total_width * 0.5
	for i in range(heads.size()):
		var member: Dictionary = heads[i]
		var head := _make_avatar_node(_avatar_path(String(member.get("id", ""))), head_size)
		var rect := Rect2(start_x + float(i) * (head_size + gap), 122, head_size, head_size)
		_place(head, rect)
		head.modulate = Color(1, 1, 1, 0)
		_top_head_row.add_child(head)
		_top_heads[String(member.get("id", ""))] = head


func _play_intro() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_title, "modulate:a", 1.0, 0.28)
	_player_bust.position.x -= _scale_x(80)
	_npc_bust.position.x += _scale_x(80)
	tween.tween_property(_player_bust, "modulate:a", 1.0, 0.35)
	tween.tween_property(_player_bust, "position:x", _rect(Rect2(42, 318, 470, 620)).position.x, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_npc_bust, "modulate:a", 1.0, 0.35)
	tween.tween_property(_npc_bust, "position:x", _rect(Rect2(1160, 318, 470, 620)).position.x, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player_name, "modulate:a", 1.0, 0.3)
	tween.tween_property(_npc_name, "modulate:a", 1.0, 0.3)
	for head in _top_heads.values():
		tween.tween_property(head, "modulate:a", 1.0, 0.3).set_delay(0.08)
	await tween.finished


func _play_execution_step(step: Dictionary, state) -> void:
	var crime_id := String(step.get("crime_id", ""))
	if crime_id.is_empty():
		return
	_configure_crime(step, state)
	await _show_crime_cards()
	await _play_vote_flights(step, state)
	await _play_victim_hits(step, state)
	await _play_last_words(step, state)
	await get_tree().create_timer(0.45).timeout


func _configure_crime(step: Dictionary, state) -> void:
	var crime_id := String(step.get("crime_id", ""))
	var crime_title := String(step.get("crime_title", ""))
	if crime_title.is_empty():
		crime_title = _crime_title(state, crime_id)
	var texture := _load_texture(_crime_icon_path(crime_id))
	var victims: Array = step.get("victims", [])
	_current_crime_icon.texture = texture
	_current_crime_title.text = crime_title
	_triggered_row_icon.texture = texture
	_triggered_row_title.text = crime_title
	_triggered_row_meta.text = "赞成 %d / %d，反对 %d，命中 %d 名角色" % [
		int(step.get("guilty_count", 0)),
		int(step.get("threshold", 0)),
		int(step.get("innocent_count", 0)),
		victims.size()
	]


func _show_crime_cards() -> void:
	_current_crime_card.modulate = Color(1, 1, 1, 0)
	_triggered_row.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_current_crime_card, "modulate:a", 1.0, 0.22)
	tween.tween_property(_triggered_row, "modulate:a", 1.0, 0.22).set_delay(0.08)
	await tween.finished


func _play_vote_flights(step: Dictionary, state) -> void:
	var votes: Array = step.get("votes", [])
	var crime_center := _triggered_row.get_global_rect().get_center()
	var left_index := 0
	var right_index := 0
	for record in votes:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		if String(record.get("vote", "")) != "guilty":
			continue
		var member_id := String(record.get("member_id", ""))
		var from_pos := _member_anchor(member_id)
		var target_pos: Vector2
		if member_id == "player":
			target_pos = crime_center + Vector2(_scale_x(-470 - 42 * left_index), 0)
			left_index += 1
		else:
			target_pos = crime_center + Vector2(_scale_x(470 + 42 * right_index), 0)
			right_index += 1
		await _fly_avatar(member_id, from_pos, target_pos, 0.36, state, true)
	if votes.is_empty():
		await get_tree().create_timer(0.12).timeout


func _play_victim_hits(step: Dictionary, state) -> void:
	var victims: Array = step.get("victims", [])
	if victims.is_empty():
		return
	var crime_id := String(step.get("crime_id", ""))
	var title := String(step.get("crime_title", _crime_title(state, crime_id)))
	var names: Array[String] = []
	for victim in victims:
		if typeof(victim) == TYPE_DICTIONARY:
			names.append(String(victim.get("name", victim.get("member_id", ""))))
	_title.text = "“%s” 同时命中：%s" % [title, "、".join(names)]
	var projectiles: Array = []
	for victim in victims:
		if typeof(victim) != TYPE_DICTIONARY:
			continue
		projectiles.append(_spawn_crime_projectile(crime_id, String(victim.get("member_id", ""))))
	var tween := create_tween()
	tween.set_parallel(true)
	for item in projectiles:
		var node := item.get("node") as Control
		if node == null:
			continue
		tween.tween_property(node, "modulate:a", 1.0, 0.12)
		tween.tween_property(node, "global_position", item.get("target", Vector2.ZERO), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(node, "scale", Vector2(0.72, 0.72), 0.58)
	await tween.finished
	for item in projectiles:
		var member_id := String(item.get("member_id", ""))
		var node := item.get("node") as Control
		if node != null:
			_spawn_pinned_crime(crime_id, member_id, node.get_global_rect().get_center())
			node.queue_free()
	for victim in victims:
		if typeof(victim) == TYPE_DICTIONARY:
			_play_execution_burst(String(victim.get("member_id", "")))
	await get_tree().create_timer(0.24).timeout
	for victim in victims:
		if typeof(victim) == TYPE_DICTIONARY:
			_mark_member_dead(String(victim.get("member_id", "")))
	await get_tree().create_timer(0.64).timeout


func _play_last_words(step: Dictionary, state) -> void:
	var wills: Array = step.get("death_wills", [])
	if wills.is_empty():
		_last_words_label.text = ""
		_last_words_label.modulate.a = 0.0
		return
	for will in wills:
		if typeof(will) != TYPE_DICTIONARY:
			continue
		var member_id := String(will.get("member_id", ""))
		var member_name := _member_name(state, member_id)
		var votes: Array = will.get("votes", [])
		_last_words_label.text = "%s 的遗言留下 %d 张后续投票" % [member_name, votes.size()]
		var tween := create_tween()
		tween.tween_property(_last_words_label, "modulate:a", 1.0, 0.18)
		await tween.finished
		var origin := _member_anchor(member_id)
		var index := 0
		for record in votes:
			if typeof(record) != TYPE_DICTIONARY:
				continue
			var crime_id := String(record.get("crime_id", ""))
			var target := _triggered_row.get_global_rect().get_center() + Vector2(_scale_x(-110 + index * 34), _scale_y(74))
			await _fly_avatar(member_id, origin, target, 0.18, state, false, _crime_title(state, crime_id))
			index += 1
		var fade := create_tween()
		fade.tween_property(_last_words_label, "modulate:a", 0.0, 0.22).set_delay(0.45)
		await fade.finished


func _show_result_hold() -> void:
	_result_label.text = "所有处决与遗言投票已完成，5 秒后打开议会结算页"
	var tween := create_tween()
	tween.tween_property(_result_label, "modulate:a", 1.0, 0.25)
	await tween.finished
	await get_tree().create_timer(5.0).timeout
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(self, "modulate:a", 0.0, 0.35)
	await fade.finished
	modulate = Color.WHITE


func _spawn_crime_projectile(crime_id: String, member_id: String) -> Dictionary:
	var node := _make_texture_rect(Rect2(0, 0, 70, 70), false)
	node.texture = _load_texture(_crime_icon_path(crime_id))
	node.modulate = Color(1, 1, 1, 0)
	node.scale = Vector2(1.0, 1.0)
	_vfx_layer.add_child(node)
	var start := _current_crime_card.get_global_rect().get_center() - node.size * 0.5
	var target := _member_anchor(member_id) - node.size * 0.36
	node.global_position = start
	return {"node": node, "member_id": member_id, "target": target}


func _spawn_pinned_crime(crime_id: String, member_id: String, center: Vector2) -> void:
	var size := 78.0 if member_id == "player" or member_id == _current_npc_id else 42.0
	var pin := _make_texture_rect(Rect2(0, 0, size, size), false)
	pin.texture = _load_texture(_crime_icon_path(crime_id))
	pin.global_position = center - Vector2(size, size) * 0.5
	pin.modulate = Color(1, 1, 1, 0.96)
	_vfx_layer.add_child(pin)
	var tween := create_tween()
	tween.tween_property(pin, "modulate:a", 0.62, 0.32).set_delay(0.6)


func _play_execution_burst(member_id: String) -> void:
	var anchor := _member_anchor(member_id)
	var burst := _make_burst(anchor, member_id == "player" or member_id == _current_npc_id)
	_vfx_layer.add_child(burst)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "modulate:a", 0.95, 0.14)
	tween.tween_property(burst, "scale", Vector2(1.55, 1.55), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.28).set_delay(0.18)


func _make_burst(anchor: Vector2, large: bool) -> Control:
	var size := 190.0 if large else 96.0
	var burst := Control.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.size = Vector2(size, size)
	burst.global_position = anchor - burst.size * 0.5
	burst.scale = Vector2(0.24, 0.24)
	burst.modulate = Color(1, 1, 1, 0)
	burst.draw.connect(func():
		var center := burst.size * 0.5
		burst.draw_circle(center, size * 0.42, Color(1.0, 0.10, 0.04, 0.58))
		burst.draw_circle(center, size * 0.24, Color(1.0, 0.84, 0.38, 0.80))
		for i in range(12):
			var angle := TAU * float(i) / 12.0
			var from := center + Vector2(cos(angle), sin(angle)) * size * 0.18
			var to := center + Vector2(cos(angle), sin(angle)) * size * 0.48
			burst.draw_line(from, to, Color(1.0, 0.22, 0.08, 0.86), 5.0)
	)
	return burst


func _mark_member_dead(member_id: String) -> void:
	if member_id.is_empty():
		return
	_dead_members[member_id] = true
	var target := _visual_for_member(member_id)
	if target == null:
		return
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(0.36, 0.36, 0.36, 0.78), 0.28)


func _fly_avatar(member_id: String, from_center: Vector2, to_center: Vector2, duration: float, state, leave_pin := true, label_text := "") -> void:
	var size := 48.0
	var avatar := _make_avatar_node(_avatar_path(member_id), size)
	avatar.global_position = from_center - Vector2(size, size) * 0.5
	avatar.modulate = Color(1, 1, 1, 0)
	_vfx_layer.add_child(avatar)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(avatar, "modulate:a", 1.0, min(0.12, duration * 0.5))
	tween.tween_property(avatar, "global_position", to_center - Vector2(size, size) * 0.5, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(avatar, "scale", Vector2(0.72, 0.72), duration)
	await tween.finished
	if leave_pin:
		var pin := _make_avatar_node(_avatar_path(member_id), 36.0)
		pin.global_position = to_center - Vector2(18, 18)
		pin.modulate = Color(1, 1, 1, 0.94)
		_vfx_layer.add_child(pin)
	if not label_text.is_empty():
		var label := _make_label(label_text, 14, Color(1.0, 0.86, 0.55, 1.0), 2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(180, 24)
		label.global_position = to_center + Vector2(-90, 18)
		_vfx_layer.add_child(label)
		var fade := create_tween()
		fade.tween_property(label, "modulate:a", 0.0, 0.28).set_delay(0.42)
	var fade_avatar := create_tween()
	fade_avatar.tween_property(avatar, "modulate:a", 0.0, 0.16)
	await fade_avatar.finished
	avatar.queue_free()


func _member_anchor(member_id: String) -> Vector2:
	var visual := _visual_for_member(member_id)
	if visual != null:
		var rect := visual.get_global_rect()
		if member_id == "player" or member_id == _current_npc_id:
			return rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.43)
		return rect.get_center()
	return get_global_rect().get_center()


func _visual_for_member(member_id: String) -> Control:
	if member_id == "player":
		return _player_bust
	if member_id == _current_npc_id:
		return _npc_bust
	if _top_heads.has(member_id):
		return _top_heads[member_id]
	return null


func _make_texture_rect(rect: Rect2, place_scaled := true) -> TextureRect:
	var node := TextureRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if place_scaled:
		_place(node, rect)
	else:
		node.position = rect.position
		node.size = rect.size
	return node


func _make_avatar_node(path: String, size: float) -> TextureRect:
	var avatar := _make_texture_rect(Rect2(0, 0, size, size), false)
	avatar.texture = _load_texture(path)
	return avatar


func _make_label(text: String, font_size: int, color: Color, outline := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	return label


func _make_nameplate() -> Label:
	var label := _make_label("", 19, Color(1.0, 0.90, 0.70, 1.0), 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_panel(fill: Color, border: Color, radius := 4) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _place(node: Control, rect: Rect2, scaled := true) -> void:
	var r := _rect(rect) if scaled else rect
	node.position = r.position
	node.size = r.size


func _rect(rect: Rect2) -> Rect2:
	var s := _scale()
	return Rect2(Vector2(rect.position.x * s.x, rect.position.y * s.y), Vector2(rect.size.x * s.x, rect.size.y * s.y))


func _scale() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return Vector2.ONE
	return Vector2(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)


func _scale_x(value: float) -> float:
	return value * _scale().x


func _scale_y(value: float) -> float:
	return value * _scale().y


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if OS.has_feature("web"):
		return null
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _crime_icon_path(crime_id: String) -> String:
	var path := COUNCIL_ICON_ROOT + "crime_" + crime_id + ".png"
	if ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return path
	return COUNCIL_ICON_ROOT + "crime_hush_money_invoice.png"


func _avatar_path(member_id: String) -> String:
	if member_id == "player":
		return CHARACTER_HEADICON_ROOT + "player_head_avatar.png"
	var path := CHARACTER_HEADICON_ROOT + member_id + "_head_avatar.png"
	if ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return path
	return CHARACTER_HEADICON_ROOT + "opponent_head_avatar.png"


func _half_portrait_path(member: Dictionary, is_player: bool) -> String:
	if is_player:
		return GENERATED_ROOT + "player_portrait_half.png"
	var half := String(member.get("portrait_half", ""))
	if half.is_empty():
		var portrait := String(member.get("portrait", ""))
		if portrait.ends_with(".png"):
			half = portrait.replace(".png", "_half.png")
	if not half.is_empty():
		var half_path := CHARACTER_PORTRAIT_HALF_ROOT + half
		if ResourceLoader.exists(half_path) or FileAccess.file_exists(ProjectSettings.globalize_path(half_path)):
			return half_path
	var portrait_path := CHARACTER_PORTRAIT_ROOT + String(member.get("portrait", ""))
	if ResourceLoader.exists(portrait_path) or FileAccess.file_exists(ProjectSettings.globalize_path(portrait_path)):
		return portrait_path
	return GENERATED_ROOT + "player_portrait_half.png"


func _current_npc_id_from_state(state) -> String:
	if state.current_npc_index >= 0 and state.current_npc_index < state.npcs.size():
		return String(state.npcs[state.current_npc_index].get("id", ""))
	return ""


func _all_members(state) -> Array:
	var result: Array = [state.player]
	for npc in state.npcs:
		result.append(npc)
	return result


func _member_by_id(state, member_id: String) -> Dictionary:
	if String(state.player.get("id", "player")) == member_id:
		return state.player
	for npc in state.npcs:
		if String(npc.get("id", "")) == member_id:
			return npc
	return {}


func _member_name(state, member_id: String) -> String:
	return String(_member_by_id(state, member_id).get("public_name", member_id))


func _crime_title(state, crime_id: String) -> String:
	for crime in state.council_crime_pool:
		if String(crime.get("id", "")) == crime_id:
			return String(crime.get("title", crime_id))
	return crime_id
