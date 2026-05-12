extends Control

const BASE_SIZE := Vector2(1672.0, 941.0)
const ASSET_ROOT := "res://assets/generated/"
const CHARACTER_PORTRAIT_ROOT := "res://assets/ui/characters/portrait/"
const CHARACTER_PORTRAIT_HALF_ROOT := "res://assets/ui/characters/portrait_half/"
const CARD_ASSET_ROOT := "res://assets/generated/ui/card/"
const COMMON_UI_ROOT := "res://assets/ui/common/"
const ACTION_VFX_ROOT := "res://assets/generated/action_vfx/"
const PlayerGrabRigScene := preload("res://scenes/ui/player_grab_rig.tscn")

const ACTION_DURATION := {
	"leave": 3.2,
	"gift": 5.0,
	"cast": 5.0,
	"invite": 5.0,
	"duel": 5.0,
	"assassinate": 5.0
}

var _blocker: ColorRect
var _stage: Control
var _backdrop_layer: Control
var _actor_layer: Control
var _vfx_layer: Control
var _foreground_layer: Control
var _ui_layer: Control
var _title: Label
var _subtitle: Label
var _fallback_player: TextureRect
var _fallback_npc: TextureRect
var _player_grab_slot: Control
var _player_grab_rig: Node2D
var _player: Control
var _npc: Control
var _artifact: TextureRect
var _artifact_frame: TextureRect
var _action_icon: TextureRect
var _veil: ColorRect
var _pulse: ColorRect
var _result_label: Label
var _transient_vfx: Array = []
var _vfx_textures: Dictionary = {}
var _particle_palettes: Dictionary = {}


func _ready() -> void:
	visible = false
	z_index = 4080
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_load_vfx_textures()


func play_action(action: String, actor_role: String, artifact_id: String, outcome: String, state, player_actor: Control = null, npc_actor: Control = null) -> void:
	if state == null:
		return
	var normalized := action.strip_edges().to_lower()
	if normalized.is_empty() or normalized == "none":
		return
	_bind_actor_nodes(player_actor, npc_actor)
	var actor_state := _capture_actor_state()
	if actor_role != "npc":
		_use_player_grab_rig()
	_reset_nodes()
	_configure_text(normalized, actor_role, artifact_id, outcome, state)
	_configure_textures(normalized, artifact_id, state)
	visible = true
	move_to_front()
	if actor_role != "npc":
		await _play_player_grab_intro()
	match normalized:
		"leave":
			await _play_leave(outcome)
		"gift":
			await _play_gift(actor_role, outcome)
		"cast":
			await _play_cast(outcome)
		"invite":
			await _play_invite(outcome)
		"duel":
			await _play_duel(actor_role, outcome)
		"assassinate":
			await _play_assassinate(actor_role, outcome)
		_:
			await get_tree().create_timer(0.35).timeout
	visible = false
	_cleanup_transient_vfx()
	_restore_actor_state(actor_state)


func _build() -> void:
	_blocker = ColorRect.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.color = Color(0.025, 0.018, 0.026, 0.78)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_backdrop_layer = _make_layer("BackdropLayer", 0)
	_actor_layer = _make_layer("ActorLayer", 10)
	_vfx_layer = _make_layer("VfxLayer", 20)
	_foreground_layer = _make_layer("ForegroundLayer", 30)
	_ui_layer = _make_layer("UiLayer", 40)

	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_layer.add_child(_veil)

	_pulse = ColorRect.new()
	_pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pulse.color = Color(1.0, 0.2, 0.12, 0.0)
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground_layer.add_child(_pulse)

	_fallback_player = _make_texture(Rect2(80, 276, 500, 640), true)
	_actor_layer.add_child(_fallback_player)

	_player_grab_slot = Control.new()
	_player_grab_slot.name = "PlayerGrabRigSlot"
	_player_grab_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_grab_slot.visible = false
	_place(_player_grab_slot, Rect2(80, 276, 500, 640))
	_actor_layer.add_child(_player_grab_slot)
	_build_player_grab_rig()

	_fallback_npc = _make_texture(Rect2(1092, 276, 500, 640), false)
	_actor_layer.add_child(_fallback_npc)
	_player = _fallback_player
	_npc = _fallback_npc

	_artifact = _make_texture(Rect2(756, 390, 160, 160), false)
	_vfx_layer.add_child(_artifact)

	_artifact_frame = _make_texture(Rect2(732, 366, 208, 208), false)
	_artifact_frame.visible = false
	_vfx_layer.add_child(_artifact_frame)

	_action_icon = _make_texture(Rect2(760, 178, 152, 152), false)
	_vfx_layer.add_child(_action_icon)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44, 1.0))
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.02, 1.0))
	_place(_title, Rect2(456, 72, 760, 70))
	_ui_layer.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65, 1.0))
	_subtitle.add_theme_constant_override("outline_size", 4)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.02, 1.0))
	_place(_subtitle, Rect2(376, 140, 920, 46))
	_ui_layer.add_child(_subtitle)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 34)
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
	_result_label.add_theme_constant_override("outline_size", 6)
	_result_label.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.02, 1.0))
	_place(_result_label, Rect2(456, 788, 760, 62))
	_ui_layer.add_child(_result_label)


func _make_layer(layer_name: String, layer_z: int) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = layer_z
	_stage.add_child(layer)
	return layer


func _build_player_grab_rig() -> void:
	if _player_grab_slot == null or _player_grab_rig != null:
		return
	var rig := PlayerGrabRigScene.instantiate() as Node2D
	if rig == null:
		return
	_player_grab_slot.add_child(rig)
	var fit_scale: float = min(500.0 / 832.0, 640.0 / 986.0)
	rig.position = Vector2(500.0, (640.0 - 986.0 * fit_scale) * 0.5)
	rig.scale = Vector2(-fit_scale, fit_scale)
	_player_grab_rig = rig


func _player_grab_rig_ready() -> bool:
	if _player_grab_slot == null or _player_grab_rig == null or not is_instance_valid(_player_grab_rig):
		return false
	if not _player_grab_rig.has_method("has_required_assets"):
		return false
	return bool(_player_grab_rig.call("has_required_assets"))


func _use_player_grab_rig() -> void:
	if not _player_grab_rig_ready():
		_player = _fallback_player
		return
	var previous_player := _player
	_player = _player_grab_slot
	_player_grab_slot.visible = true
	_player_grab_slot.z_as_relative = false
	_player_grab_slot.z_index = z_index + 12
	_player_grab_slot.move_to_front()
	_fallback_player.visible = false
	var external_player := previous_player as Control
	if external_player != null and external_player != _fallback_player and external_player != _player_grab_slot:
		external_player.modulate.a = 0.0


func _play_player_grab_intro() -> void:
	if not _player_grab_rig_ready() or _player != _player_grab_slot:
		return
	_player_grab_rig.call("play_grab_forward")
	await get_tree().create_timer(0.75).timeout


func _load_vfx_textures() -> void:
	for name in [
		"vfx_smoke_wisp", "vfx_gold_spark", "vfx_red_spark", "vfx_shadow_slash",
		"vfx_magic_ring", "vfx_contract_knot", "vfx_crack_mark", "leave_speed_streaks",
		"gift_offering_aura", "cast_beam_core", "duel_cross_flash", "assassinate_bloodline",
		"vfx_artifact_frame", "vfx_defense_ring", "vfx_impact_burst", "vfx_result_seal"
	]:
		var path: String = ACTION_VFX_ROOT + name + ".png"
		if ResourceLoader.exists(path):
			_vfx_textures[name] = load(path)
	_load_particle_palette_textures()


func _load_particle_palette_textures() -> void:
	_particle_palettes = {
		"gold_oath": [
			"gold_oath_diamond_01", "gold_oath_diamond_02", "gold_oath_diamond_03",
			"gold_oath_rune_chip_01", "gold_oath_rune_chip_02", "particle_diamond_01",
			"particle_arc_chip_01", "particle_stroke_short_01"
		],
		"red_rupture": [
			"red_rupture_triangle_01", "red_rupture_triangle_02", "red_rupture_triangle_03",
			"red_rupture_crack_chip_01", "red_rupture_crack_chip_02", "particle_triangle_01",
			"particle_stroke_short_01"
		],
		"cyan_escape": [
			"cyan_escape_dash_01", "cyan_escape_dash_02", "cyan_escape_dash_03",
			"cyan_escape_bubble_01", "cyan_escape_bubble_02", "particle_diamond_02",
			"particle_stroke_short_02"
		],
		"violet_shadow": [
			"violet_shadow_arc_01", "violet_shadow_arc_02", "violet_shadow_arc_03",
			"violet_shadow_ink_01", "violet_shadow_ink_02", "particle_arc_chip_02",
			"particle_ink_drop_01"
		],
		"white_clash": [
			"white_clash_star_01", "white_clash_star_02", "white_clash_sliver_01",
			"white_clash_sliver_02", "white_clash_sliver_03", "particle_dot_solid_01",
			"particle_stroke_short_01"
		]
	}
	for palette in _particle_palettes.values():
		for name in palette:
			var key := String(name)
			if _vfx_textures.has(key):
				continue
			var path := ACTION_VFX_ROOT + "particles/" + key + ".png"
			if ResourceLoader.exists(path):
				_vfx_textures[key] = load(path)


func _bind_actor_nodes(player_actor: Control, npc_actor: Control) -> void:
	_player = player_actor if player_actor != null and is_instance_valid(player_actor) else _fallback_player
	_npc = npc_actor if npc_actor != null and is_instance_valid(npc_actor) else _fallback_npc
	_fallback_player.visible = _player == _fallback_player
	_fallback_npc.visible = _npc == _fallback_npc
	if _player_grab_slot != null:
		_player_grab_slot.visible = _player == _player_grab_slot
	for actor in [_player, _npc]:
		var control := actor as Control
		if control == null:
			continue
		control.visible = true
		control.z_as_relative = false
		control.z_index = z_index + 12
		control.move_to_front()


func _capture_actor_state() -> Dictionary:
	return {
		"player": _capture_control_state(_player),
		"npc": _capture_control_state(_npc),
		"stage_position": _stage.position,
		"stage_rotation": _stage.rotation_degrees
	}


func _capture_control_state(node: Control) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {}
	return {
		"node": node,
		"visible": node.visible,
		"position": node.position,
		"scale": node.scale,
		"rotation_degrees": node.rotation_degrees,
		"modulate": node.modulate,
		"z_index": node.z_index,
		"z_as_relative": node.z_as_relative
	}


func _restore_actor_state(actor_state: Dictionary) -> void:
	for key in ["player", "npc"]:
		_restore_control_state(actor_state.get(key, {}))
	_stage.position = actor_state.get("stage_position", Vector2.ZERO)
	_stage.rotation_degrees = float(actor_state.get("stage_rotation", 0.0))
	_fallback_player.visible = _player == _fallback_player
	_fallback_npc.visible = _npc == _fallback_npc
	if _player_grab_slot != null:
		_player_grab_slot.visible = false


func _restore_control_state(state: Dictionary) -> void:
	var node := state.get("node") as Control
	if node == null or not is_instance_valid(node):
		return
	node.visible = bool(state.get("visible", node.visible))
	node.position = state.get("position", node.position)
	node.scale = state.get("scale", node.scale)
	node.rotation_degrees = float(state.get("rotation_degrees", node.rotation_degrees))
	node.modulate = state.get("modulate", node.modulate)
	node.z_index = int(state.get("z_index", node.z_index))
	node.z_as_relative = bool(state.get("z_as_relative", node.z_as_relative))


func debug_actor_state() -> Dictionary:
	return {
		"using_external_player": _player != _fallback_player,
		"using_external_npc": _npc != _fallback_npc,
		"fallback_player_visible": _fallback_player.visible,
		"fallback_npc_visible": _fallback_npc.visible,
		"player_grab_rig_visible": _player_grab_slot.visible if _player_grab_slot != null else false,
		"player_grab_rig_ready": _player_grab_rig_ready(),
		"player_visible": _player.visible if _player != null else false,
		"npc_visible": _npc.visible if _npc != null else false,
		"transient_vfx_count": _transient_vfx.size()
	}


func _reset_nodes() -> void:
	_cleanup_transient_vfx()
	_stage.position = Vector2.ZERO
	_stage.rotation_degrees = 0.0
	for node in [_fallback_player, _fallback_npc, _player_grab_slot, _artifact, _artifact_frame, _action_icon, _result_label]:
		if node == null:
			continue
		var canvas := node as CanvasItem
		if canvas != null:
			canvas.modulate = Color.WHITE
		var control := node as Control
		if control != null:
			control.visible = true
			control.scale = Vector2.ONE
			control.rotation_degrees = 0.0
	for actor in [_player, _npc]:
		var control := actor as Control
		if control != null:
			control.visible = true
			control.scale = Vector2.ONE
			control.rotation_degrees = 0.0
			control.modulate = Color.WHITE
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	_pulse.color = Color(1.0, 0.2, 0.12, 0.0)
	_place(_fallback_player, Rect2(80, 276, 500, 640))
	if _player_grab_slot != null:
		_place(_player_grab_slot, Rect2(80, 276, 500, 640))
	_place(_fallback_npc, Rect2(1092, 276, 500, 640))
	_place(_artifact, Rect2(756, 390, 160, 160))
	_place(_artifact_frame, Rect2(732, 366, 208, 208))
	_artifact_frame.visible = false
	_place(_action_icon, Rect2(760, 178, 152, 152))
	_fallback_player.visible = _player == _fallback_player
	_fallback_npc.visible = _npc == _fallback_npc
	if _player_grab_slot != null:
		_player_grab_slot.visible = _player == _player_grab_slot


func _configure_text(action: String, actor_role: String, artifact_id: String, outcome: String, state) -> void:
	var actor_name := "玩家" if actor_role != "npc" else String(state.current_npc().get("public_name", "对方"))
	_title.text = "%s：%s" % [actor_name, _action_name(action)]
	var artifact_text := ""
	if not artifact_id.is_empty():
		artifact_text = " · %s" % state.artifact_name(artifact_id)
	_subtitle.text = _subtitle_for_action(action) + artifact_text
	_result_label.text = _result_text(action, outcome)
	_result_label.modulate = Color(1, 1, 1, 0)


func _configure_textures(action: String, artifact_id: String, state) -> void:
	if _player == _fallback_player:
		_set_texture(_fallback_player, ASSET_ROOT + "player_portrait_half.png", ASSET_ROOT + "player_portrait.png")
	var npc: Dictionary = state.current_npc()
	var portrait_name := String(npc.get("portrait", ""))
	if _npc == _fallback_npc and not portrait_name.is_empty():
		_set_texture(_fallback_npc, CHARACTER_PORTRAIT_HALF_ROOT + portrait_name.replace(".png", "_half.png"), CHARACTER_PORTRAIT_ROOT + portrait_name)
	_set_texture(_action_icon, COMMON_UI_ROOT + "icon_tile_action_%s.png" % action, COMMON_UI_ROOT + "icon_tile_action_leave.png")
	if artifact_id.is_empty():
		_artifact.texture = _action_icon.texture
	else:
		_set_texture(_artifact, CARD_ASSET_ROOT + "artifact_%s.png" % artifact_id, ASSET_ROOT + "artifact_%s.png" % artifact_id)


func _play_leave(outcome: String) -> void:
	_npc.visible = false
	_artifact.visible = false
	_artifact_frame.visible = false
	_action_icon.visible = false
	_pose_actor(_player, -5.0, Vector2(0.98, 1.04), Color(0.66, 0.86, 1.0, 1.0), 0.35)
	_spawn_escape_smoke(Vector2(168, 640))
	_spawn_sprite_vfx("leave_speed_streaks", Rect2(122, 390, 430, 190), Color(0.58, 0.94, 0.96, 0.86), 1.6, _backdrop_layer, false)
	_spawn_particle_trail("cyan_escape", Vector2(420, 608), Vector2(144, 646), 24, 24.0, Color(0.42, 0.86, 0.9, 0.88), _vfx_layer)
	_spawn_particle_burst("cyan_escape", Vector2(248, 676), 18, 130.0, 150.0, 0.8, Color(0.44, 0.88, 0.9, 0.88), _vfx_layer)
	await get_tree().create_timer(0.35).timeout
	_make_afterimage(_player, 5, Color(0.32, 0.82, 1.0, 0.22), Vector2(86, 0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_veil, "color", Color(0.0, 0.08, 0.12, 0.36), 0.9)
	tween.tween_property(_player, "position:x", -460.0, 1.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_player, "modulate:a", 0.0, 1.45).set_delay(0.55)
	tween.tween_property(_pulse, "color", _pulse_color(outcome), 0.24).set_delay(2.35)
	tween.tween_property(_pulse, "color:a", 0.0, 0.75).set_delay(2.62)
	tween.tween_property(_result_label, "modulate:a", 1.0, 0.35).set_delay(2.62)
	await get_tree().create_timer(float(ACTION_DURATION["leave"])).timeout


func _play_gift(actor_role: String, outcome: String) -> void:
	var giver := _player if actor_role != "npc" else _npc
	var receiver := _npc if actor_role != "npc" else _player
	var start_x := 356.0 if actor_role != "npc" else 1186.0
	var end_x := 1158.0 if actor_role != "npc" else 356.0
	var arc_mid := Vector2(760, 320)
	var frame_size := Vector2(190, 190)
	var start_frame := Rect2(start_x - 30, 434, frame_size.x, frame_size.y)
	_show_artifact_frame(start_frame, 0.0)
	_center_artifact_in_frame(start_frame, 42.0)
	_action_icon.visible = false
	_artifact.modulate.a = 0.0
	_pose_actor(giver, 4.5 if actor_role != "npc" else -4.5, Vector2(1.02, 0.99), Color(1.0, 0.88, 0.58, 1.0), 0.6)
	_spawn_sprite_vfx("gift_offering_aura", Rect2(start_x - 78, 408, 286, 190), Color(1.0, 0.78, 0.25, 0.86), 2.3, _vfx_layer, false)
	_spawn_particle_burst("gold_oath", Vector2(start_x + 64, 510), 16, 140.0, 112.0, 0.8, Color(1.0, 0.76, 0.28, 0.9))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_artifact, "modulate:a", 1.0, 0.28)
	tween.tween_property(_artifact, "scale", Vector2(1.25, 1.25), 0.8).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_artifact, "position", arc_mid - _artifact.size * 0.5, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_artifact, "rotation_degrees", 24.0, 1.2)
	tween.tween_property(_artifact_frame, "modulate:a", 1.0, 0.25)
	tween.tween_property(_artifact_frame, "scale", Vector2(1.16, 1.16), 0.8).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_artifact_frame, "position", arc_mid - _artifact_frame.size * 0.5, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_artifact_frame, "rotation_degrees", 24.0, 1.2)
	await get_tree().create_timer(1.25).timeout
	_spawn_sprite_vfx("vfx_contract_knot", Rect2(720, 300, 230, 230), Color(1.0, 0.78, 0.28, 0.9), 1.8, _foreground_layer, false)
	_spawn_particle_ring("gold_oath", arc_mid, 78.0, 22, Color(1.0, 0.9, 0.42, 0.9))
	tween = create_tween().set_parallel(true)
	var final_x: float = end_x if outcome != "failure" else lerp(arc_mid.x, end_x, 0.6)
	var final_frame := Rect2(final_x - 30, 434, frame_size.x, frame_size.y)
	tween.tween_property(_artifact, "position", _artifact_rect_for_frame(final_frame, 42.0).position, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_artifact, "scale", Vector2(0.88, 0.88), 1.1)
	tween.tween_property(_artifact_frame, "position", final_frame.position, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_artifact_frame, "scale", Vector2(0.95, 0.95), 1.1)
	tween.tween_property(receiver, "modulate", Color(1.0, 0.92, 0.66, 1.0) if outcome != "failure" else Color(1.0, 0.36, 0.3, 1.0), 0.28).set_delay(1.05)
	await get_tree().create_timer(1.45).timeout
	if outcome == "failure":
		_spawn_sprite_vfx("vfx_crack_mark", Rect2(final_x - 56, 392, 240, 220), Color(1.0, 0.18, 0.08, 0.95), 1.5, _foreground_layer)
		_camera_shake(8.0, 0.32)
		var reject := create_tween().set_parallel(true)
		reject.tween_property(_artifact, "position:x", _artifact_rect_for_frame(final_frame, 42.0).position.x + (-96.0 if actor_role != "npc" else 96.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reject.tween_property(_artifact_frame, "position:x", final_frame.position.x + (-96.0 if actor_role != "npc" else 96.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_spawn_sprite_vfx("gift_offering_aura", Rect2(end_x - 78, 408, 286, 190), Color(1.0, 0.72, 0.26, 0.78), 1.6, _foreground_layer, false)
	_spawn_particle_burst("gold_oath" if outcome != "failure" else "red_rupture", Vector2(end_x + 60, 510), 22, 170.0, 160.0, 0.85, Color(1.0, 0.84, 0.35, 0.9) if outcome != "failure" else Color(1.0, 0.18, 0.08, 0.9))
	_finish_reveal(outcome, 0.85)
	await get_tree().create_timer(2.3).timeout


func _play_cast(outcome: String) -> void:
	_action_icon.visible = false
	_artifact.modulate.a = 1.0
	var cast_frame := Rect2(716, 350, 240, 240)
	_show_artifact_frame(cast_frame, 0.95)
	_center_artifact_in_frame(cast_frame, 52.0)
	_pose_actor(_player, 5.5, Vector2(1.02, 0.98), Color(1.0, 0.78, 0.55, 1.0), 0.7)
	_spawn_magic_rings(Vector2(836, 470), outcome)
	_spawn_particle_trail("gold_oath", Vector2(430, 520), Vector2(812, 470), 24, 42.0, Color(1.0, 0.62, 0.24, 0.86))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_veil, "color", Color(0.14, 0.0, 0.02, 0.42), 1.1)
	tween.tween_property(_artifact, "scale", Vector2(1.32, 1.32), 1.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_artifact, "rotation_degrees", 360.0, 2.5)
	tween.tween_property(_artifact_frame, "scale", Vector2(1.22, 1.22), 1.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_artifact_frame, "rotation_degrees", 360.0, 2.5)
	await get_tree().create_timer(2.0).timeout
	var target := Vector2(1096, 430) if outcome != "failure" else Vector2(1180, 542)
	_spawn_beam(Vector2(830, 470), target, outcome)
	_camera_shake(11.0, 0.48)
	await get_tree().create_timer(0.25).timeout
	_spawn_particle_burst_sized("red_rupture", target, 32, 180.0, 245.0, 0.85, Color(1.0, 0.18, 0.08, 0.9), _foreground_layer, Vector2(22.0, 44.0))
	if outcome == "failure":
		_spawn_sprite_vfx("vfx_crack_mark", Rect2(704, 328, 280, 250), Color(1.0, 0.1, 0.04, 0.82), 1.6, _foreground_layer)
		_pose_actor(_npc, -3.0, Vector2(1.0, 1.0), Color(0.72, 1.0, 0.95, 1.0), 0.35)
	else:
		_pose_actor(_npc, 7.0, Vector2(0.98, 1.04), Color(1.0, 0.36, 0.28, 0.82), 0.45)
	_finish_reveal(outcome, 0.9)
	await get_tree().create_timer(2.75).timeout


func _play_invite(outcome: String) -> void:
	_artifact.visible = false
	_artifact_frame.visible = false
	_action_icon.visible = false
	_pose_actor(_player, 3.0, Vector2(1.01, 0.995), Color(1.0, 0.82, 0.48, 1.0), 0.7)
	_pose_actor(_npc, -3.0, Vector2(1.01, 0.995), Color(1.0, 0.82, 0.48, 1.0), 0.7)
	var left := Vector2(514, 520)
	var center := Vector2(836, 454)
	var right := Vector2(1152, 520)
	_spawn_energy_line(left, center, Color(0.08, 0.58, 0.58, 0.0), Color(1.0, 0.76, 0.26, 0.95), 1.15, 7.0)
	_spawn_energy_line(right, center, Color(0.08, 0.58, 0.58, 0.0), Color(1.0, 0.76, 0.26, 0.95), 1.15, 7.0)
	_spawn_particle_burst("gold_oath", left, 12, 95.0, 105.0, 0.7, Color(1.0, 0.72, 0.28, 0.78))
	_spawn_particle_burst("gold_oath", right, 12, 95.0, 105.0, 0.7, Color(1.0, 0.72, 0.28, 0.78))
	await get_tree().create_timer(1.2).timeout
	_spawn_sprite_vfx("vfx_contract_knot", Rect2(716, 312, 240, 240), Color(1.0, 0.78, 0.28, 0.94), 2.1, _foreground_layer, false)
	await get_tree().create_timer(1.4).timeout
	if outcome == "failure":
		_spawn_sprite_vfx("vfx_crack_mark", Rect2(706, 310, 260, 250), Color(1.0, 0.1, 0.05, 0.95), 1.7, _foreground_layer)
		_spawn_energy_line(center, Vector2(480, 430), Color(1.0, 0.08, 0.04, 0.95), Color(1.0, 0.08, 0.04, 0.0), 0.75, 10.0)
		_spawn_energy_line(center, Vector2(1198, 430), Color(1.0, 0.08, 0.04, 0.95), Color(1.0, 0.08, 0.04, 0.0), 0.75, 10.0)
		_camera_shake(7.0, 0.3)
	else:
		_spawn_magic_rings(center, "victory", 0.78)
		_spawn_particle_ring("gold_oath", center, 112.0, 28, Color(1.0, 0.78, 0.28, 0.9))
	_finish_reveal(outcome, 0.8)
	await get_tree().create_timer(2.15).timeout


func _play_duel(actor_role: String, outcome: String) -> void:
	_artifact.visible = false
	_artifact_frame.visible = false
	_action_icon.visible = false
	var player_wins := outcome != "failure" and outcome != "death"
	var winner := _player if player_wins else _npc
	var loser := _npc if player_wins else _player
	_pose_actor(_player, 6.0, Vector2(1.04, 0.96), Color(1.0, 0.86, 0.62, 1.0), 0.65)
	_pose_actor(_npc, -6.0, Vector2(1.04, 0.96), Color(1.0, 0.86, 0.62, 1.0), 0.65)
	_spawn_energy_line(Vector2(462, 514), Vector2(1210, 514), Color(1.0, 0.8, 0.28, 0.0), Color(1.0, 0.76, 0.22, 0.8), 0.75, 5.0)
	await get_tree().create_timer(0.85).timeout
	_make_afterimage(_player, 3, Color(1.0, 0.82, 0.35, 0.18), Vector2(-42, 0))
	_make_afterimage(_npc, 3, Color(1.0, 0.22, 0.16, 0.18), Vector2(42, 0))
	_spawn_duel_flash(0)
	_camera_shake(8.0, 0.24)
	await get_tree().create_timer(0.85).timeout
	_spawn_duel_flash(1)
	_camera_shake(13.0, 0.35)
	await get_tree().create_timer(0.55).timeout
	var tween := create_tween().set_parallel(true)
	tween.tween_property(winner, "position:x", winner.position.x + (92.0 if winner == _player else -92.0), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(loser, "position:x", loser.position.x + (-150.0 if loser == _player else 150.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(loser, "rotation_degrees", -12.0 if loser == _player else 12.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(loser, "scale", Vector2(0.96, 1.04), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(loser, "modulate", Color(1.0, 0.28, 0.22, 0.58), 0.32)
	if outcome == "death":
		tween.tween_property(_veil, "color", Color(0.08, 0.0, 0.0, 0.54), 0.45)
	_spawn_particle_burst_sized("red_rupture", loser.position + Vector2(250, 235), 36, 170.0, 260.0, 1.05, Color(1.0, 0.12, 0.05, 0.92), _foreground_layer, Vector2(24.0, 48.0))
	_finish_reveal(outcome, 0.92)
	await get_tree().create_timer(2.75).timeout


func _play_assassinate(actor_role: String, outcome: String) -> void:
	_artifact.visible = false
	_artifact_frame.visible = false
	_action_icon.visible = false
	var attacker := _npc if actor_role == "npc" else _player
	var target := _player if actor_role == "npc" else _npc
	var target_x := 426.0 if actor_role == "npc" else 930.0
	var retreat := 126.0 if actor_role == "npc" else -126.0
	var tint := create_tween().set_parallel(true)
	tint.tween_property(_veil, "color", Color(0.0, 0.0, 0.0, 0.68), 0.9)
	tint.tween_property(attacker, "modulate:a", 0.28, 0.65)
	_spawn_sprite_vfx("vfx_smoke_wisp", Rect2(attacker.position.x + 72, 478, 260, 170), Color(0.22, 0.08, 0.34, 0.76), 2.0, _foreground_layer, false)
	await get_tree().create_timer(1.0).timeout
	_make_afterimage(attacker, 5, Color(0.35, 0.04, 0.62, 0.22), Vector2(-42 if actor_role != "npc" else 42, 0))
	_spawn_sprite_vfx("vfx_shadow_slash", Rect2(target_x - 178, 362, 330, 205), Color(0.58, 0.14, 0.88, 0.92), 1.2, _foreground_layer, false)
	_spawn_particle_trail("violet_shadow", Vector2(attacker.position.x + 170, 500), Vector2(target_x + 30, 476), 18, 34.0, Color(0.62, 0.14, 1.0, 0.72), _foreground_layer)
	var dash := create_tween().set_parallel(true)
	dash.tween_property(attacker, "position:x", target_x, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	dash.tween_property(attacker, "modulate:a", 0.92, 0.35).set_delay(0.42)
	await get_tree().create_timer(0.78).timeout
	if outcome == "failure":
		_spawn_sprite_vfx("vfx_magic_ring", Rect2(target_x - 110, 346, 260, 260), Color(0.48, 1.0, 0.94, 0.86), 1.35, _foreground_layer)
		_spawn_particle_ring("white_clash", Vector2(target_x, 476), 92.0, 22, Color(0.52, 1.0, 0.95, 0.8))
		_camera_shake(9.0, 0.28)
		var fail := create_tween().set_parallel(true)
		fail.tween_property(attacker, "position:x", attacker.position.x + retreat, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fail.tween_property(attacker, "modulate:a", 1.0, 0.35)
	else:
		_spawn_sprite_vfx("assassinate_bloodline", Rect2(target_x - 110, 390, 430, 170), Color(1.0, 0.02, 0.02, 0.95), 0.9, _foreground_layer)
		await get_tree().create_timer(0.12).timeout
		_spawn_particle_burst("red_rupture", Vector2(target_x + 80, 486), 30, 160.0, 240.0, 0.82, Color(1.0, 0.02, 0.0, 0.92), _foreground_layer)
		_pose_actor(target, 6.0 if actor_role != "npc" else -6.0, Vector2(0.98, 1.04), Color(1.0, 0.22, 0.16, 0.72), 0.35)
		_camera_shake(13.0, 0.4)
	_finish_reveal(outcome, 0.82)
	await get_tree().create_timer(2.72).timeout


func _finish_reveal(outcome: String, delay := 0.0) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_pulse, "color", _pulse_color(outcome), 0.18).set_delay(delay)
	tween.tween_property(_pulse, "color:a", 0.0, 0.85).set_delay(delay + 0.28)
	tween.tween_property(_result_label, "modulate:a", 1.0, 0.35).set_delay(delay + 0.32)


func _spawn_magic_rings(center: Vector2, outcome: String, alpha_scale := 1.0) -> void:
	for i in range(2):
		var size := 236.0 + float(i) * 58.0
		var node := _spawn_sprite_vfx("vfx_magic_ring", Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size), Color(1.0, 0.72, 0.18, 0.84 * alpha_scale), 2.7, _vfx_layer, false)
		if node != null:
			node.rotation_degrees = float(i) * 17.0
			var tween := create_tween().set_parallel(true)
			tween.tween_property(node, "rotation_degrees", 360.0 + float(i) * 17.0, 2.7)
			tween.tween_property(node, "scale", Vector2(1.04, 1.04), 1.4).set_trans(Tween.TRANS_SINE)
	if outcome == "failure":
		_spawn_sprite_vfx("vfx_crack_mark", Rect2(center.x - 118, center.y - 100, 250, 220), Color(1.0, 0.12, 0.04, 0.82), 1.4, _foreground_layer, false)


func _spawn_beam(from_point: Vector2, to_point: Vector2, outcome: String) -> void:
	var delta := to_point - from_point
	var length := delta.length()
	var angle := delta.angle()
	var beam := _spawn_sprite_vfx("cast_beam_core", Rect2(from_point.x, from_point.y - 46, length, 92), Color(1.0, 0.34, 0.08, 0.95), 0.95, _foreground_layer, false)
	if beam != null:
		beam.pivot_offset = Vector2(0, 46)
		beam.rotation = angle
		beam.scale.x = 0.05
		var tween := create_tween().set_parallel(true)
		tween.tween_property(beam, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(beam, "modulate:a", 0.0, 0.58).set_delay(0.3)
	_spawn_energy_line(from_point, to_point, Color(1.0, 0.9, 0.34, 0.0), Color(1.0, 0.9, 0.34, 0.95), 0.55, 9.0)


func _show_artifact_frame(rect: Rect2, alpha := 1.0) -> void:
	var texture := _vfx_textures.get("vfx_artifact_frame") as Texture2D
	if texture != null:
		_artifact_frame.texture = texture
	else:
		_artifact_frame.texture = _vfx_textures.get("vfx_magic_ring") as Texture2D
	_place(_artifact_frame, rect)
	_artifact_frame.visible = true
	_artifact_frame.modulate = Color(1.0, 0.86, 0.34, alpha)
	_artifact_frame.scale = Vector2.ONE
	_artifact_frame.rotation_degrees = 0.0


func _center_artifact_in_frame(frame_rect: Rect2, inset: float) -> void:
	_place(_artifact, _artifact_rect_for_frame(frame_rect, inset))


func _artifact_rect_for_frame(frame_rect: Rect2, inset: float) -> Rect2:
	var side: float = max(24.0, min(frame_rect.size.x, frame_rect.size.y) - inset * 2.0)
	return Rect2(frame_rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


func _spawn_escape_smoke(origin: Vector2) -> void:
	var offsets := [Vector2(-62, 12), Vector2(24, -4), Vector2(102, 18)]
	var sizes := [Vector2(210, 132), Vector2(250, 152), Vector2(190, 120)]
	for i in range(offsets.size()):
		var rect := Rect2(origin + offsets[i], sizes[i])
		var node := _spawn_sprite_vfx("vfx_smoke_wisp", rect, Color(0.18, 0.72, 0.74, 0.76 - float(i) * 0.08), 2.1 + float(i) * 0.16, _vfx_layer, false)
		if node != null:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(node, "position", node.position + Vector2(-88.0 - float(i) * 26.0, -8.0 + float(i) * 7.0), 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "scale", Vector2(1.06, 1.02), 1.2)


func _spawn_duel_flash(pass_index: int) -> void:
	var rect := Rect2(530, 328, 660, 320) if pass_index == 0 else Rect2(470, 300, 760, 360)
	var flash := _spawn_sprite_vfx("duel_cross_flash", rect, Color(1.0, 0.86, 0.42, 0.96), 0.72, _foreground_layer, false)
	if flash != null:
		flash.rotation_degrees = -14.0 if pass_index == 0 else 18.0
	_spawn_energy_line(Vector2(470, 620 if pass_index == 0 else 360), Vector2(1210, 330 if pass_index == 0 else 646), Color(1.0, 0.9, 0.56, 0.95), Color(1.0, 0.12, 0.08, 0.0), 0.5, 14.0)
	_spawn_particle_burst("white_clash", Vector2(835, 492), 14, 85.0, 210.0, 0.55, Color(1.0, 0.92, 0.58, 0.88), _foreground_layer)


func _spawn_energy_line(from_point: Vector2, to_point: Vector2, start_color: Color, end_color: Color, lifetime: float, width: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = start_color
	line.points = PackedVector2Array([from_point, to_point])
	line.texture_mode = Line2D.LINE_TEXTURE_NONE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_vfx_layer.add_child(line)
	_register_transient(line)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(line, "default_color", end_color, min(0.18, lifetime * 0.45))
	tween.tween_property(line, "width", width * 1.9, lifetime * 0.52)
	tween.tween_property(line, "modulate:a", 0.0, lifetime * 0.56).set_delay(lifetime * 0.44)
	_queue_transient_free(line, lifetime)
	return line


func _spawn_sprite_vfx(texture_name: String, rect: Rect2, color: Color, lifetime: float, parent: Control = null, auto_expand := false) -> Control:
	var texture := _vfx_textures.get(texture_name) as Texture2D
	if texture == null:
		return _spawn_fallback_vfx(rect, color, lifetime, parent)
	var node := TextureRect.new()
	node.texture = texture
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.modulate = color
	_place(node, rect)
	(parent if parent != null else _vfx_layer).add_child(node)
	_register_transient(node)
	var tween := create_tween().set_parallel(true)
	if auto_expand:
		tween.tween_property(node, "scale", Vector2(1.08, 1.08), lifetime * 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", 0.0, lifetime * 0.45).set_delay(lifetime * 0.55)
	_queue_transient_free(node, lifetime)
	return node


func _spawn_fallback_vfx(rect: Rect2, color: Color, lifetime: float, parent: Control = null) -> ColorRect:
	var node := ColorRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.color = color
	_place(node, rect)
	(parent if parent != null else _vfx_layer).add_child(node)
	_register_transient(node)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2(1.2, 1.2), lifetime * 0.45)
	tween.tween_property(node, "color:a", 0.0, lifetime * 0.45).set_delay(lifetime * 0.55)
	_queue_transient_free(node, lifetime)
	return node


func _spawn_particle_burst(palette_name: String, origin: Vector2, amount: int, spread: float, speed: float, lifetime: float, color_base: Color, parent: Control = null) -> void:
	_spawn_particle_burst_sized(palette_name, origin, amount, spread, speed, lifetime, color_base, parent, Vector2(16.0, 36.0))


func _spawn_particle_burst_sized(palette_name: String, origin: Vector2, amount: int, spread: float, speed: float, lifetime: float, color_base: Color, parent: Control = null, size_range := Vector2(16.0, 36.0)) -> void:
	var palette: Array = _particle_palettes.get(palette_name, [])
	if palette.is_empty():
		return
	for i in range(amount):
		var angle := randf_range(-spread, spread) * PI / 180.0 + randf_range(0.0, TAU)
		var distance := randf_range(speed * 0.25, speed) * lifetime
		var start := origin + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		var end := start + Vector2(cos(angle), sin(angle)) * distance
		var life := lifetime * randf_range(0.72, 1.18)
		var size := randf_range(size_range.x, size_range.y)
		_spawn_particle_sprite(_random_palette_key(palette), start, end, size, randf_range(-220.0, 220.0), _jitter_color(color_base), life, parent)


func _spawn_particle_trail(palette_name: String, from_point: Vector2, to_point: Vector2, count: int, jitter: float, color_base: Color, parent: Control = null) -> void:
	var palette: Array = _particle_palettes.get(palette_name, [])
	if palette.is_empty():
		return
	for i in range(count):
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		var base := from_point.lerp(to_point, t)
		var start := base + Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		var drift := Vector2(randf_range(-24.0, 24.0), randf_range(-28.0, 18.0))
		var size := randf_range(14.0, 30.0)
		_spawn_particle_sprite(_random_palette_key(palette), start, start + drift, size, randf_range(-160.0, 160.0), _jitter_color(color_base), randf_range(0.42, 0.92), parent)


func _spawn_particle_ring(palette_name: String, center: Vector2, radius: float, amount: int, color_base: Color, parent: Control = null) -> void:
	var palette: Array = _particle_palettes.get(palette_name, [])
	if palette.is_empty():
		return
	for i in range(amount):
		var angle := TAU * float(i) / float(amount) + randf_range(-0.14, 0.14)
		var direction := Vector2(cos(angle), sin(angle))
		var start := center + direction * randf_range(radius * 0.25, radius * 0.52)
		var end := center + direction * randf_range(radius * 0.72, radius)
		var size := randf_range(14.0, 32.0)
		_spawn_particle_sprite(_random_palette_key(palette), start, end, size, randf_range(-180.0, 180.0), _jitter_color(color_base), randf_range(0.52, 0.95), parent)


func _spawn_particle_sprite(texture_name: String, start: Vector2, end: Vector2, particle_size: float, spin: float, color: Color, lifetime: float, parent: Control = null) -> TextureRect:
	var texture := _vfx_textures.get(texture_name) as Texture2D
	if texture == null:
		return null
	var node := TextureRect.new()
	node.texture = texture
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.modulate = color
	_place(node, Rect2(start.x - particle_size * 0.5, start.y - particle_size * 0.5, particle_size, particle_size))
	node.rotation_degrees = randf_range(0.0, 360.0)
	(parent if parent != null else _vfx_layer).add_child(node)
	_register_transient(node)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "position", end - Vector2(particle_size * 0.5, particle_size * 0.5), lifetime).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation_degrees", node.rotation_degrees + spin, lifetime)
	tween.tween_property(node, "scale", Vector2(randf_range(0.62, 1.16), randf_range(0.62, 1.16)), lifetime * 0.42)
	tween.tween_property(node, "modulate:a", 0.0, lifetime * 0.38).set_delay(lifetime * 0.62)
	_queue_transient_free(node, lifetime + 0.12)
	return node


func _random_palette_key(palette: Array) -> String:
	return String(palette[randi() % palette.size()])


func _jitter_color(color: Color) -> Color:
	var value := randf_range(0.88, 1.08)
	return Color(
		clamp(color.r * value, 0.0, 1.0),
		clamp(color.g * value, 0.0, 1.0),
		clamp(color.b * value, 0.0, 1.0),
		color.a * randf_range(0.72, 1.0)
	)


func _make_afterimage(actor: Control, count: int, color: Color, spacing: Vector2) -> void:
	var texture_actor := actor as TextureRect
	if texture_actor == null or texture_actor.texture == null:
		return
	for i in range(count):
		var ghost := TextureRect.new()
		ghost.texture = texture_actor.texture
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = texture_actor.stretch_mode
		ghost.flip_h = texture_actor.flip_h
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.global_position = texture_actor.global_position + spacing * float(i + 1)
		ghost.size = texture_actor.size
		ghost.scale = texture_actor.scale
		ghost.rotation_degrees = texture_actor.rotation_degrees
		ghost.pivot_offset = texture_actor.pivot_offset
		ghost.modulate = Color(color.r, color.g, color.b, color.a * (1.0 - float(i) / float(count + 1)))
		_foreground_layer.add_child(ghost)
		_register_transient(ghost)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.75).set_delay(float(i) * 0.04)
		tween.tween_property(ghost, "position", ghost.position + spacing * 0.18, 0.75).set_delay(float(i) * 0.04)
		_queue_transient_free(ghost, 0.95 + float(i) * 0.04)


func _pose_actor(actor: Control, lean: float, squash: Vector2, tint: Color, duration: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(actor, "rotation_degrees", lean, duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "scale", squash, duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "modulate", tint, duration * 0.35)
	tween.tween_property(actor, "rotation_degrees", 0.0, duration * 0.55).set_delay(duration * 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(actor, "scale", Vector2.ONE, duration * 0.55).set_delay(duration * 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(actor, "modulate", Color.WHITE, duration * 0.45).set_delay(duration * 0.55)


func _camera_shake(strength: float, duration: float) -> void:
	var steps: int = max(3, int(duration / 0.035))
	var tween := create_tween()
	for i in range(steps):
		var phase := float(i)
		var offset := Vector2(sin(phase * 2.7), cos(phase * 4.1)) * strength * (1.0 - phase / float(steps))
		tween.tween_property(_stage, "position", offset, duration / float(steps))
	tween.tween_property(_stage, "position", Vector2.ZERO, 0.04)


func _cleanup_transient_vfx() -> void:
	for node in _transient_vfx:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_transient_vfx.clear()


func _register_transient(node: Node) -> void:
	_transient_vfx.append(node)


func _queue_transient_free(node: Node, delay: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(delay).timeout.connect(Callable(self, "_free_transient_vfx").bind(node))


func _free_transient_vfx(node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		_transient_vfx.erase(node)


func _action_name(action: String) -> String:
	match action:
		"invite":
			return "邀请"
		"assassinate":
			return "暗杀"
		"duel":
			return "决斗"
		"gift":
			return "赠送"
		"cast":
			return "施法"
		_:
			return "撤离"


func _subtitle_for_action(action: String) -> String:
	match action:
		"invite":
			return "盟约在中线编织，回应将在光环合拢时揭晓"
		"assassinate":
			return "低光压近，最后一瞬才知道刀锋是否命中"
		"duel":
			return "双方压向中线，胜负在交错斩击后定格"
		"gift":
			return "法器越过中线，关系在献礼与拒绝之间改写"
		"cast":
			return "符文驱动法器，命中或偏转即将揭示"
		_:
			return "烟幕遮住退路，角色离场后进入下一阶段"


func _result_text(action: String, outcome: String) -> String:
	if outcome == "death":
		return "致命结局"
	if outcome == "failure":
		return "%s失败" % _action_name(action)
	if outcome == "victory":
		return "胜利"
	return "%s完成" % _action_name(action)


func _pulse_color(outcome: String) -> Color:
	match outcome:
		"failure", "death":
			return Color(1.0, 0.05, 0.02, 0.32)
		"victory":
			return Color(0.56, 1.0, 0.58, 0.26)
		_:
			return Color(0.3, 0.88, 1.0, 0.24)


func _make_texture(source_rect: Rect2, flipped: bool) -> TextureRect:
	var node := TextureRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.flip_h = flipped
	_place(node, source_rect)
	return node


func _place(node: Control, source_rect: Rect2) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = source_rect.position.x
	node.offset_top = source_rect.position.y
	node.offset_right = source_rect.position.x + source_rect.size.x
	node.offset_bottom = source_rect.position.y + source_rect.size.y
	node.pivot_offset = source_rect.size * 0.5


func _set_texture(node: TextureRect, path: String, fallback: String) -> void:
	if ResourceLoader.exists(path):
		node.texture = load(path)
	elif ResourceLoader.exists(fallback):
		node.texture = load(fallback)
	else:
		node.texture = null
