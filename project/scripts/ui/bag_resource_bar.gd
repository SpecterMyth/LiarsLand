@tool
extends Control
class_name BagResourceBar

@onready var energy_value: Label = get_node_or_null("EnergyPlate/EnergyValue")
@onready var capacity_value: Label = get_node_or_null("CapacityPlate/CapacityValue")

var _design_fonts: Dictionary = {}
var _design_outlines: Dictionary = {}


func _ready() -> void:
	_sync_rect_to_source_size()
	_capture_design_label_values()
	_apply_design_label_values()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_sync_rect_to_source_size()
	if what == NOTIFICATION_RESIZED:
		_apply_design_label_values()


func _sync_rect_to_source_size() -> void:
	if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	size = custom_minimum_size


func _capture_design_label_values() -> void:
	for label in [energy_value, capacity_value]:
		if label == null:
			continue
		var id: int = label.get_instance_id()
		_design_fonts[id] = label.get_theme_font_size("font_size")
		_design_outlines[id] = label.get_theme_constant("outline_size")


func _apply_design_label_values() -> void:
	if _design_fonts.is_empty():
		return
	for label in [energy_value, capacity_value]:
		if label == null:
			continue
		var id: int = label.get_instance_id()
		var font_size := int(_design_fonts.get(id, label.get_theme_font_size("font_size")))
		var outline_size := int(_design_outlines.get(id, label.get_theme_constant("outline_size")))
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", outline_size)
