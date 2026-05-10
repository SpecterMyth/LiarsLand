extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/ui/guidelines_page.tscn")
	assert(packed != null)
	var page: Control = packed.instantiate()
	root.add_child(page)
	await process_frame
	await process_frame

	var edit := page.get_node_or_null("MainPanel/Content/GuidelineEdit") as TextEdit
	var append := page.get_node_or_null("MainPanel/Content/AppendRow/AppendEdit") as TextEdit
	var merge := page.get_node_or_null("MainPanel/Content/AppendRow/MergeButton") as Button
	assert(edit != null)
	assert(append != null)
	assert(merge != null)

	page.call("set_guidelines", "原身份准则", "原行动准则", "原成长准则")
	append.text = "新增：优先维持伪装。"
	var captured := {}
	page.merge_requested.connect(func(tab_id: String, base_text: String, append_text: String) -> void:
		captured["tab_id"] = tab_id
		captured["base_text"] = base_text
		captured["append_text"] = append_text
	)
	merge.emit_signal("pressed")
	await process_frame

	assert(captured.get("tab_id", "") == "identity")
	assert(String(captured.get("base_text", "")).contains("原身份准则"))
	assert(captured.get("append_text", "") == "新增：优先维持伪装。")

	page.call("set_merging", true)
	assert(not edit.editable)
	assert(not append.editable)
	assert(merge.disabled)
	page.call("set_merging", false)
	assert(edit.editable)
	assert(append.editable)
	assert(not merge.disabled)

	page.queue_free()
	print("LiarsLand guidelines merge click checks passed.")
	quit(0)
