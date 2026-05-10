extends SceneTree

const DeathPageScene := preload("res://scenes/ui/death_page.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var page: Control = DeathPageScene.instantiate()
	root.add_child(page)
	await process_frame

	page.call("show_death", "邀请敌人失败：对方直接刺杀了玩家。", "邀请是高收益行动：确认友方证据与收益后应主动邀请。")
	await process_frame
	assert(page.visible)
	var reason_label := page.get_node_or_null("Content/ReasonLabel") as Label
	var rule_edit := page.get_node_or_null("Content/RuleEdit") as TextEdit
	var merge_button := page.get_node_or_null("Content/ButtonRow/MergeButton") as Button
	assert(reason_label != null)
	assert(rule_edit != null)
	assert(merge_button != null)
	assert(reason_label.text.contains("邀请敌人失败"))
	assert(rule_edit.text.contains("邀请是高收益行动"))
	assert(rule_edit.editable)
	assert(not merge_button.disabled)

	page.queue_free()
	print("LiarsLand death page flow checks passed.")
	quit(0)
