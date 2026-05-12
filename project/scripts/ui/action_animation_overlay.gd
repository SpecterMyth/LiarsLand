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
	"retreat": 3.2,
	"declare_tendency": 3.4,
	"cast_vote": 3.8,
	"offer_trade": 4.2,
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
var _action_payload: Dictionary = {}


func _ready() -> void:
	visible = false
	z_index = 4080
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_load_vfx_textures()


func play_action(action: String, actor_role: String, artifact_id: String, outcome: String, state, player_actor: Control = null, npc_actor: Control = null, action_payload: Dictionary = {}) -> void:
	if state == null:
		return
	var normalized := action.strip_edges().to_lower()
	if normalized.is_empty() or normalized == "none":
		return
	_action_payload = action_payload.duplicate(true)
	var actor_state := _capture_prebind_actor_state(player_actor, npc_actor)
	_bind_actor_nodes(player_actor, npc_actor)
	if actor_role != "npc" and _uses_player_grab_intro(normalized):
		_use_player_grab_rig()
	_reset_nodes()
	_configure_text(normalized, actor_role, artifact_id, outcome, state)
	_configure_textures(normalized, artifact_id, state)
	visible = true
	move_to_front()
	if actor_role != "npc" and _uses_player_grab_intro(normalized):
		await _play_player_grab_intro()
	match normalized:
		"leave":
			await _play_leave(outcome)
		"retreat":
			await _play_leave(outcome)
		"declare_tendency":
			await _play_declare_tendency(actor_role, outcome)
		"cast_vote":
			await _play_council_vote(actor_role, outcome)
		"offer_trade":
			await _play_council_trade(actor_role, outcome)
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
	await _finish_text_to_status_icon()
	visible = false
	_cleanup_transient_vfx()
	_restore_actor_state(actor_state)
	_action_payload = {}


func _build() -> void:
	_blocker = ColorRect.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.color = Color(0.0, 0.0, 0.0, 0.5)
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
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44, 1.0))
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.02, 1.0))
	_place(_title, Rect2(680, 54, 900, 70))
	_ui_layer.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65, 1.0))
	_subtitle.add_theme_constant_override("outline_size", 4)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.02, 1.0))
	_place(_subtitle, Rect2(680, 122, 940, 50))
	_ui_layer.add_child(_subtitle)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 34)
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
	_result_label.add_theme_constant_override("outline_size", 6)
	_result_label.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.02, 1.0))
	_place(_result_label, Rect2(680, 180, 900, 62))
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


func _uses_player_grab_intro(action: String) -> bool:
	return action in ["leave", "retreat", "gift", "cast", "invite", "duel", "assassinate"]


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
		"vfx_artifact_frame", "vfx_defense_ring", "vfx_impact_burst", "vfx_result_seal",
		"council_action_symbols", "council_action_effects", "council_ballot_guilty",
		"council_ballot_innocent", "council_ballot_abstain", "council_seal_locked",
		"council_seal_tendency", "council_seal_rejected_broken", "council_wax_stamp",
		"council_crime_dossier", "council_wave_gold", "council_wave_teal",
		"council_vote_burst_red", "council_seal_burst_gold", "council_contract_line",
		"council_contract_line_broken", "council_trade_three_nodes", "council_sparkle_cluster"
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


func _capture_prebind_actor_state(player_actor: Control, npc_actor: Control) -> Dictionary:
	var player_node := player_actor if player_actor != null and is_instance_valid(player_actor) else _fallback_player
	var npc_node := npc_actor if npc_actor != null and is_instance_valid(npc_actor) else _fallback_npc
	return {
		"player": _capture_control_state(player_node),
		"npc": _capture_control_state(npc_node),
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
	for node in [_fallback_player, _fallback_npc, _player_grab_slot, _artifact, _artifact_frame, _action_icon, _title, _subtitle, _result_label]:
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
	_place(_title, Rect2(680, 54, 900, 70))
	_place(_subtitle, Rect2(680, 122, 940, 50))
	_place(_result_label, Rect2(680, 180, 900, 62))
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
	var display_actor_name := "我方" if actor_role != "npc" else String(state.current_npc().get("public_name", "对方"))
	_title.text = "%s：%s" % [display_actor_name, _action_name(action)]
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


func _play_declare_tendency(actor_role: String, outcome: String) -> void:
	_artifact.visible = false
	_artifact_frame.visible = false
	_action_icon.visible = false
	var speaker := _player if actor_role != "npc" else _npc
	var start := _actor_center(speaker) + Vector2(92.0 if actor_role != "npc" else -92.0, -46.0)
	var anchor := _actor_effect_anchor(actor_role, -78.0)
	var wave_name := "council_wave_teal" if _payload_vote() == "innocent" else "council_wave_gold"
	var wave_rect := Rect2(anchor.x - 158.0, anchor.y - 120.0, 316.0, 240.0)
	var wave := _spawn_sprite_vfx(wave_name, wave_rect, Color(1, 1, 1, 0.0), 2.2, _foreground_layer, false)
	var seal := _spawn_sprite_vfx("council_seal_tendency", Rect2(anchor.x - 116.0, anchor.y - 116.0, 232.0, 232.0), _vote_tint(0.0), 2.7, _foreground_layer, false)
	var crime_icon := _spawn_crime_icon(Rect2(anchor.x - 48.0, anchor.y + 58.0, 96.0, 96.0), 2.6, Color(1, 1, 1, 0.94))
	_pose_actor(speaker, -4.0 if actor_role == "npc" else 4.0, Vector2(1.01, 0.99), _vote_tint(1.0), 0.65)
	_spawn_particle_trail("gold_oath", start, anchor, 16, 32.0, _vote_tint(0.78), _vfx_layer)
	if wave != null:
		if wave is TextureRect:
			(wave as TextureRect).flip_h = actor_role == "npc"
		var wave_tween := create_tween().set_parallel(true)
		wave_tween.tween_property(wave, "modulate:a", 0.92, 0.24)
		wave_tween.tween_property(wave, "position", wave.position + Vector2(54.0 if actor_role != "npc" else -54.0, -8.0), 1.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		wave_tween.tween_property(wave, "scale", Vector2(1.08, 1.08), 1.12).set_trans(Tween.TRANS_SINE)
	if seal != null:
		seal.scale = Vector2(0.72, 0.72)
		var seal_tween := create_tween().set_parallel(true)
		seal_tween.tween_property(seal, "modulate:a", 0.66, 0.38).set_delay(0.72)
		seal_tween.tween_property(seal, "scale", Vector2(1.0, 1.0), 0.58).set_delay(0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		seal_tween.tween_property(seal, "rotation_degrees", 18.0, 1.55).set_delay(0.72)
	if crime_icon != null:
		var icon_tween := create_tween().set_parallel(true)
		icon_tween.tween_property(crime_icon, "position:y", crime_icon.position.y - 24.0, 0.76).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		icon_tween.tween_property(crime_icon, "scale", Vector2(1.28, 1.28), 0.5).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.45).timeout
	_spawn_particle_ring("gold_oath", anchor, 112.0, 24, _vote_tint(0.82), _foreground_layer)
	_spawn_sprite_vfx("council_sparkle_cluster", Rect2(anchor.x - 85.0, anchor.y - 92.0, 170.0, 138.0), _vote_tint(0.9), 1.4, _foreground_layer, false)
	_finish_reveal(outcome, 0.55)
	await get_tree().create_timer(float(ACTION_DURATION["declare_tendency"]) - 1.45).timeout


func _play_council_vote(actor_role: String, outcome: String) -> void:
	_artifact.visible = false
	_artifact_frame.visible = false
	_action_icon.visible = false
	var speaker := _player if actor_role != "npc" else _npc
	var start := _actor_center(speaker) + Vector2(78.0 if actor_role != "npc" else -78.0, -22.0)
	var anchor := _actor_effect_anchor(actor_role, -58.0)
	var vote := _payload_vote()
	var ballot_name := "council_ballot_innocent" if vote == "innocent" else "council_ballot_abstain" if vote == "abstain" else "council_ballot_guilty"
	var ballot := _spawn_sprite_vfx(ballot_name, Rect2(start.x - 72.0, start.y - 86.0, 144.0, 174.0), Color(1, 1, 1, 1), 3.0, _foreground_layer, false)
	var dossier := _spawn_sprite_vfx("council_crime_dossier", Rect2(anchor.x - 130.0, anchor.y - 124.0, 260.0, 304.0), Color(1, 1, 1, 0.0), 3.2, _vfx_layer, false)
	var crime_icon := _spawn_crime_icon(Rect2(anchor.x - 48.0, anchor.y + 54.0, 96.0, 96.0), 3.1, Color(1, 1, 1, 0.98))
	_pose_actor(speaker, 5.0 if actor_role != "npc" else -5.0, Vector2(1.02, 0.985), _vote_tint(1.0), 0.72)
	if dossier != null:
		var dossier_tween := create_tween().set_parallel(true)
		dossier_tween.tween_property(dossier, "modulate:a", 0.72, 0.42)
		dossier_tween.tween_property(dossier, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
	if ballot != null:
		ballot.rotation_degrees = -9.0 if actor_role != "npc" else 9.0
		var ballot_tween := create_tween().set_parallel(true)
		ballot_tween.tween_property(ballot, "position", Vector2(anchor.x - 72.0, anchor.y - 112.0), 1.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ballot_tween.tween_property(ballot, "rotation_degrees", 0.0, 1.08)
		ballot_tween.tween_property(ballot, "scale", Vector2(1.18, 1.18), 1.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if crime_icon != null:
		var crime_tween := create_tween().set_parallel(true)
		crime_tween.tween_property(crime_icon, "position:y", crime_icon.position.y - 18.0, 0.56).set_delay(0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		crime_tween.tween_property(crime_icon, "rotation_degrees", -8.0 if actor_role != "npc" else 8.0, 0.64).set_delay(0.48)
	_spawn_particle_trail("gold_oath", start, anchor, 18, 30.0, _vote_tint(0.82), _vfx_layer)
	await get_tree().create_timer(1.2).timeout
	var stamp := _spawn_sprite_vfx("council_wax_stamp", Rect2(anchor.x - 54.0, anchor.y - 208.0, 108.0, 112.0), Color(1, 1, 1, 0.0), 1.25, _foreground_layer, false)
	if stamp != null:
		var stamp_tween := create_tween().set_parallel(true)
		stamp_tween.tween_property(stamp, "modulate:a", 1.0, 0.12)
		stamp_tween.tween_property(stamp, "position:y", anchor.y - 74.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		stamp_tween.tween_property(stamp, "scale", Vector2(1.18, 0.86), 0.16).set_delay(0.34)
	await get_tree().create_timer(0.36).timeout
	_camera_shake(10.0 if outcome != "death" else 16.0, 0.32)
	_spawn_sprite_vfx("council_seal_locked", Rect2(anchor.x - 120.0, anchor.y - 120.0, 240.0, 248.0), _vote_tint(0.96), 2.1, _foreground_layer, false)
	_spawn_sprite_vfx("council_seal_burst_gold", Rect2(anchor.x - 162.0, anchor.y - 158.0, 324.0, 318.0), Color(1.0, 0.86, 0.42, 0.86), 1.45, _foreground_layer, false)
	if outcome == "death":
		_spawn_sprite_vfx("council_vote_burst_red", Rect2(anchor.x - 186.0, anchor.y - 190.0, 372.0, 382.0), Color(1, 0.2, 0.1, 0.9), 1.6, _foreground_layer, false)
		_spawn_particle_burst_sized("red_rupture", anchor, 30, 170.0, 210.0, 0.9, Color(1.0, 0.14, 0.06, 0.88), _foreground_layer, Vector2(18.0, 42.0))
	else:
		_spawn_particle_ring("gold_oath", anchor, 120.0, 24, _vote_tint(0.86), _foreground_layer)
	_finish_reveal(outcome, 0.5)
	await get_tree().create_timer(float(ACTION_DURATION["cast_vote"]) - 1.56).timeout


func _play_council_trade(actor_role: String, outcome: String) -> void:
	_artifact.visible = false
	_artifact_frame.visible = false
	_action_icon.visible = false
	var proposer := _player if actor_role != "npc" else _npc
	var counterpart := _npc if actor_role != "npc" else _player
	var proposer_start := _actor_center(proposer) + Vector2(80.0 if actor_role != "npc" else -80.0, -12.0)
	var counterpart_start := _actor_center(counterpart) + Vector2(-80.0 if actor_role != "npc" else 80.0, -12.0)
	var proposal_center := Vector2(836, 456)
	_pose_actor(proposer, 4.5 if actor_role != "npc" else -4.5, Vector2(1.02, 0.99), Color(1.0, 0.82, 0.48, 1.0), 0.7)
	_pose_actor(counterpart, -3.0 if actor_role != "npc" else 3.0, Vector2(1.01, 0.995), Color(0.72, 1.0, 0.94, 1.0), 0.7)
	var left_ballot := _spawn_sprite_vfx(_ballot_texture_name(), Rect2(proposer_start.x - 64.0, proposer_start.y - 78.0, 128.0, 156.0), Color(1, 1, 1, 1), 3.2, _foreground_layer, false)
	var right_ballot := _spawn_sprite_vfx(_ballot_texture_name(), Rect2(counterpart_start.x - 64.0, counterpart_start.y - 78.0, 128.0, 156.0), Color(1, 1, 1, 1), 3.2, _foreground_layer, false)
	var crime_icon := _spawn_crime_icon(Rect2(proposal_center.x - 52.0, proposal_center.y - 126.0, 104.0, 104.0), 3.7, Color(1, 1, 1, 0.98))
	_spawn_particle_trail("gold_oath", proposer_start, Vector2(730, 460), 12, 28.0, Color(1.0, 0.78, 0.28, 0.82), _vfx_layer)
	_spawn_particle_trail("cyan_escape", counterpart_start, Vector2(942, 460), 12, 28.0, Color(0.45, 0.95, 0.94, 0.72), _vfx_layer)
	var fly := create_tween().set_parallel(true)
	if left_ballot != null:
		fly.tween_property(left_ballot, "position", Vector2(654, 352), 1.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(left_ballot, "rotation_degrees", -7.0, 1.04)
	if right_ballot != null:
		fly.tween_property(right_ballot, "position", Vector2(890, 352), 1.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(right_ballot, "rotation_degrees", 7.0, 1.04)
	if crime_icon != null:
		fly.tween_property(crime_icon, "position", Vector2(proposal_center.x - 52.0, proposal_center.y - 146.0), 1.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fly.tween_property(crime_icon, "scale", Vector2(1.24, 1.24), 1.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.12).timeout
	var line_name := "council_contract_line_broken" if outcome == "failure" else "council_contract_line"
	var line := _spawn_sprite_vfx(line_name, Rect2(650, 458, 372, 112), Color(1, 1, 1, 0.0), 2.4, _foreground_layer, false)
	var nodes := _spawn_sprite_vfx("council_trade_three_nodes", Rect2(642, 382, 388, 160), Color(1, 1, 1, 0.0), 2.6, _foreground_layer, false)
	if line != null:
		var line_tween := create_tween().set_parallel(true)
		line_tween.tween_property(line, "modulate:a", 1.0, 0.22)
		line_tween.tween_property(line, "scale:x", 1.04, 1.0).set_trans(Tween.TRANS_SINE)
	if nodes != null:
		var node_tween := create_tween().set_parallel(true)
		node_tween.tween_property(nodes, "modulate:a", 1.0, 0.38).set_delay(0.22)
		node_tween.tween_property(nodes, "scale", Vector2(1.08, 1.08), 0.72).set_delay(0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.92).timeout
	if outcome == "failure":
		_spawn_sprite_vfx("council_seal_rejected_broken", Rect2(722, 284, 228, 236), Color(1, 0.34, 0.24, 0.9), 1.5, _foreground_layer, false)
		_spawn_particle_burst("red_rupture", Vector2(836, 456), 24, 150.0, 160.0, 0.86, Color(1.0, 0.18, 0.08, 0.88), _foreground_layer)
		_camera_shake(7.0, 0.28)
	else:
		_spawn_sprite_vfx("council_seal_burst_gold", Rect2(708, 274, 256, 250), Color(1.0, 0.86, 0.42, 0.88), 1.5, _foreground_layer, false)
		_spawn_particle_ring("gold_oath", Vector2(836, 456), 128.0, 30, Color(1.0, 0.82, 0.28, 0.9), _foreground_layer)
		_camera_shake(8.0, 0.24)
	_finish_reveal(outcome, 0.55)
	await get_tree().create_timer(float(ACTION_DURATION["offer_trade"]) - 2.04).timeout


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


func _finish_text_to_status_icon() -> void:
	var target := _action_payload.get("status_icon_target", Vector2(BASE_SIZE.x - 86.0, BASE_SIZE.y - 94.0)) as Vector2
	var tween := create_tween().set_parallel(true)
	for node in [_title, _subtitle, _result_label]:
		if node == null:
			continue
		var control := node as Control
		if control == null:
			continue
		control.pivot_offset = control.size * 0.5
		tween.tween_property(control, "position", target - control.size * 0.5, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(control, "scale", Vector2(0.06, 0.06), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(control, "modulate:a", 0.0, 0.26).set_delay(0.16)
	await get_tree().create_timer(0.46).timeout


func _actor_center(actor: Control) -> Vector2:
	if actor == null or not is_instance_valid(actor):
		return Vector2(836, 470)
	return actor.position + actor.size * 0.5


func _actor_effect_anchor(actor_role: String, y_offset := -62.0) -> Vector2:
	var actor := _player if actor_role != "npc" else _npc
	var direction := 1.0 if actor_role != "npc" else -1.0
	var center := _actor_center(actor)
	var anchor := center + Vector2(156.0 * direction, y_offset)
	anchor.x = clamp(anchor.x, 300.0, BASE_SIZE.x - 300.0)
	anchor.y = clamp(anchor.y, 210.0, BASE_SIZE.y - 250.0)
	return anchor


func _payload_crime_id() -> String:
	var crime_id := String(_action_payload.get("target_crime_id", _action_payload.get("crime_id", ""))).strip_edges()
	if crime_id.is_empty():
		for key in ["bound_votes", "proposal_votes", "votes"]:
			var records = _action_payload.get(key, [])
			if typeof(records) != TYPE_ARRAY:
				continue
			for record in records:
				if typeof(record) != TYPE_DICTIONARY:
					continue
				crime_id = String(record.get("target_crime_id", record.get("crime_id", ""))).strip_edges()
				if not crime_id.is_empty():
					return crime_id
	return crime_id


func _crime_icon_texture() -> Texture2D:
	var crime_id := _payload_crime_id()
	if not crime_id.is_empty():
		var path := "res://assets/generated/ui/council_icons/crime_%s.png" % crime_id
		if ResourceLoader.exists(path):
			return load(path)
	return _vfx_textures.get("council_crime_dossier") as Texture2D


func _spawn_crime_icon(rect: Rect2, lifetime: float, color := Color(1, 1, 1, 1)) -> Control:
	var texture := _crime_icon_texture()
	if texture == null:
		return _spawn_sprite_vfx("council_crime_dossier", rect, color, lifetime, _foreground_layer, false)
	var node := TextureRect.new()
	node.texture = texture
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.modulate = color
	_place(node, rect)
	_foreground_layer.add_child(node)
	_register_transient(node)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2(1.16, 1.16), min(0.5, lifetime * 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation_degrees", 8.0, min(0.62, lifetime * 0.34)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", 0.0, lifetime * 0.3).set_delay(lifetime * 0.64)
	_queue_transient_free(node, lifetime)
	return node


func _payload_vote() -> String:
	var vote := String(_action_payload.get("vote", "guilty")).strip_edges().to_lower()
	if vote in ["innocent", "abstain"]:
		return vote
	return "guilty"


func _ballot_texture_name() -> String:
	match _payload_vote():
		"innocent":
			return "council_ballot_innocent"
		"abstain":
			return "council_ballot_abstain"
		_:
			return "council_ballot_guilty"


func _vote_tint(alpha := 1.0) -> Color:
	match _payload_vote():
		"innocent":
			return Color(0.48, 1.0, 0.94, alpha)
		"abstain":
			return Color(0.82, 0.78, 0.68, alpha)
		_:
			return Color(1.0, 0.34, 0.22, alpha)


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
		"retreat":
			return "暂时撤退"
		"declare_tendency":
			return "公开倾向"
		"cast_vote":
			return "正式投票"
		"offer_trade":
			return "政治交易"
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
		"retreat":
			return "撤离会场，动画完成后再进入下一阶段"
		"declare_tendency":
			return "公开表达立场，记录倾向但不锁定投票"
		"cast_vote":
			return "正式投下选票，罪行议案同步入档"
		"offer_trade":
			return "提出政治交易，把相关票意绑定成协议"
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
