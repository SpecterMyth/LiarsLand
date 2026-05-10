@tool
extends PanelContainer
class_name ArtifactSlot


func _ready() -> void:
	_sync_rect_to_source_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_sync_rect_to_source_size()


func _sync_rect_to_source_size() -> void:
	if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	size = custom_minimum_size
	var root := get_node_or_null("Root") as Control
	if root != null:
		root.custom_minimum_size = custom_minimum_size
		root.set_anchors_preset(Control.PRESET_FULL_RECT, false)
