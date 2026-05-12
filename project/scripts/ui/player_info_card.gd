@tool
extends Control
class_name PlayerInfoCard

const COUNCIL_ICON_ROOT := "res://assets/generated/ui/council_icons/"
const ENERGY_ICON_PATH := COUNCIL_ICON_ROOT + "icon_energy.png"
const BASE_SIZE := Vector2(326.4, 558.0)


func _ready() -> void:
	_sync_rect_to_source_size()
	_ensure_bottom_shadow()
	_apply_scaled_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_sync_rect_to_source_size()
	if what == NOTIFICATION_RESIZED:
		_apply_scaled_layout()


func _sync_rect_to_source_size() -> void:
	if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	size = custom_minimum_size
	_apply_scaled_layout()


func _apply_scaled_layout() -> void:
	var scale := _card_scale()
	var stack := get_node_or_null("InfoStack") as VBoxContainer
	if stack != null:
		stack.add_theme_constant_override("separation", maxi(6, int(round(12.0 * scale))))

	_scale_label("InfoStack/NameLabel", 29, 4, true)
	_scale_label("InfoStack/ProofRow/ProofNameLabel", 20, 3, false)
	_scale_label("InfoStack/ProofRow/EnergyLabel", 18, 3, false)

	var proof_row := get_node_or_null("InfoStack/ProofRow") as HBoxContainer
	if proof_row != null:
		proof_row.custom_minimum_size = Vector2(0, round(42.0 * scale))
		proof_row.add_theme_constant_override("separation", maxi(4, int(round(8.0 * scale))))

	_set_min_size("InfoStack/ProofRow/ProofIcon", Vector2(36, 36) * scale)
	_set_min_size("InfoStack/ProofRow/ProofNameLabel", Vector2(92, 36) * scale)
	_set_min_size("InfoStack/ProofRow/EnergyIcon", Vector2(30, 30) * scale)
	_set_min_size("InfoStack/ProofRow/EnergyLabel", Vector2(44, 36) * scale)

	var crime_row := get_node_or_null("InfoStack/CrimeRow") as HBoxContainer
	if crime_row != null:
		crime_row.custom_minimum_size = Vector2(0, round(58.0 * scale))
		crime_row.add_theme_constant_override("separation", maxi(6, int(round(12.0 * scale))))
	for i in range(3):
		_set_min_size("InfoStack/CrimeRow/CrimeIcon%d" % (i + 1), Vector2(52, 52) * scale)


func _card_scale() -> float:
	var width := size.x
	if width <= 0.0:
		width = custom_minimum_size.x
	if width <= 0.0:
		width = BASE_SIZE.x
	return clamp(width / BASE_SIZE.x, 0.68, 1.0)


func _scale_label(path: NodePath, base_font_size: int, base_outline: int, center := false) -> void:
	var label := get_node_or_null(path) as Label
	if label == null:
		return
	var scale := _card_scale()
	label.add_theme_font_size_override("font_size", maxi(12, int(round(float(base_font_size) * scale))))
	label.add_theme_constant_override("outline_size", maxi(1, int(round(float(base_outline) * scale))))
	if center:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _set_min_size(path: NodePath, min_size: Vector2) -> void:
	var control := get_node_or_null(path) as Control
	if control != null:
		control.custom_minimum_size = min_size


func _ensure_bottom_shadow() -> void:
	var old_shadow := get_node_or_null("BottomShadow") as Control
	if old_shadow != null:
		old_shadow.queue_free()
	var card_texture := get_node_or_null("CardTexture") as TextureRect
	var shadow := get_node_or_null("BottomShadowMask") as TextureRect
	if shadow == null:
		shadow = TextureRect.new()
		shadow.name = "BottomShadowMask"
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(shadow)
	if card_texture != null:
		shadow.texture = card_texture.texture
		shadow.expand_mode = card_texture.expand_mode
		shadow.stretch_mode = card_texture.stretch_mode
		move_child(shadow, card_texture.get_index() + 1)
	shadow.material = _bottom_shadow_material()


func _bottom_shadow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = smoothstep(0.42, 1.0, UV.y) * 0.78 * tex.a;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func set_player_data(player: Dictionary, state = null) -> void:
	var faction_id := String(player.get("hidden_faction", player.get("public_support", "")))
	var remaining_energy := -1
	if state != null:
		remaining_energy = maxi(0, int(state.max_player_chars) - int(state.player_chars))
	set_card_data(
		String(player.get("public_name", "玩家角色")),
		faction_id,
		_faction_name(state, faction_id),
		_player_crime_ids(player),
		remaining_energy
	)


func set_card_data(player_name: String, faction_id: String, faction_name: String, crime_ids: Array, remaining_energy := -1) -> void:
	_apply_scaled_layout()
	var name_label := get_node_or_null("InfoStack/NameLabel") as Label
	if name_label != null:
		name_label.text = player_name

	var proof_icon := get_node_or_null("InfoStack/ProofRow/ProofIcon") as TextureRect
	if proof_icon != null:
		proof_icon.texture = _load_texture(_faction_icon_path(faction_id))

	var proof_name := get_node_or_null("InfoStack/ProofRow/ProofNameLabel") as Label
	if proof_name != null:
		proof_name.text = faction_name if not faction_name.is_empty() else faction_id

	var energy_icon := get_node_or_null("InfoStack/ProofRow/EnergyIcon") as TextureRect
	if energy_icon != null:
		energy_icon.visible = remaining_energy >= 0
		energy_icon.texture = _load_texture(ENERGY_ICON_PATH)

	var energy_label := get_node_or_null("InfoStack/ProofRow/EnergyLabel") as Label
	if energy_label != null:
		energy_label.visible = remaining_energy >= 0
		energy_label.text = str(maxi(0, int(remaining_energy))) if remaining_energy >= 0 else ""

	for i in range(3):
		var icon := get_node_or_null("InfoStack/CrimeRow/CrimeIcon%d" % (i + 1)) as TextureRect
		if icon == null:
			continue
		icon.visible = i < crime_ids.size()
		if i < crime_ids.size():
			icon.texture = _load_texture(_crime_icon_path(String(crime_ids[i])))


func _player_crime_ids(player: Dictionary) -> Array:
	var result: Array = []
	for crime_id in player.get("hidden_crimes", []):
		result.append(String(crime_id))
	return result.slice(0, 3)


func _faction_name(state, faction_id: String) -> String:
	if state != null:
		for faction in state.council_factions:
			if String(faction.get("id", "")) == faction_id:
				return String(faction.get("name", faction_id))
	return faction_id if not faction_id.is_empty() else "未分配阵营"


func _faction_icon_path(faction_id: String) -> String:
	var path := COUNCIL_ICON_ROOT + "faction_%s.png" % faction_id
	if not faction_id.is_empty() and ResourceLoader.exists(path):
		return path
	return COUNCIL_ICON_ROOT + "faction_blue_tie.png"


func _crime_icon_path(crime_id: String) -> String:
	var path := COUNCIL_ICON_ROOT + "crime_%s.png" % crime_id
	if not crime_id.is_empty() and ResourceLoader.exists(path):
		return path
	return COUNCIL_ICON_ROOT + "crime_hush_money_invoice.png"


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if OS.has_feature("web"):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image != null:
		return ImageTexture.create_from_image(image)
	return null
