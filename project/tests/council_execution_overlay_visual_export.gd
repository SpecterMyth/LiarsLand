extends SceneTree

const OverlayScript := preload("res://scripts/ui/council_execution_overlay.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")
const CouncilRulesEngineScript := preload("res://scripts/core/council_rules_engine.gd")

const OUT_DIR := "res://../ui/visual_tests/council_execution_overlay"

var _out_dir := ""
var _state
var _timeline: Array = []
var _overlay: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1672, 941)
	_out_dir = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_state = GameStateScript.new()
	CouncilRulesEngineScript.setup_state(_state, ChapterLoaderScript.load_chapter("res://data/council_chapter_01.json"))
	_state.current_npc_index = 0
	_timeline = _make_timeline(_state)
	_overlay = OverlayScript.new()
	root.add_child(_overlay)
	_overlay.call("debug_show_timeline_step", _timeline, _state, 0, "votes")
	process_frame.connect(_wait_votes_frame, CONNECT_ONE_SHOT)


func _wait_votes_frame() -> void:
	process_frame.connect(_capture_votes, CONNECT_ONE_SHOT)


func _capture_votes() -> void:
	_save_frame("01_intro_votes.png")
	_overlay.call("debug_show_timeline_step", _timeline, _state, 0, "execution")
	process_frame.connect(_capture_execution, CONNECT_ONE_SHOT)


func _capture_execution() -> void:
	_save_frame("02_multi_execution.png")
	_overlay.call("debug_show_timeline_step", _timeline, _state, 1, "chain")
	process_frame.connect(_capture_chain, CONNECT_ONE_SHOT)


func _capture_chain() -> void:
	_save_frame("03_chain_execution.png")
	print("Council execution overlay visual export passed: %s" % _out_dir)
	quit(0)


func _make_timeline(state) -> Array:
	var fox_id := String(state.npcs[0].get("id", "npc_fox"))
	var crow_id := String(state.npcs[1].get("id", "npc_crow"))
	var deer_id := String(state.npcs[2].get("id", "npc_deer"))
	return [
		{
			"round": 0,
			"crime_id": "hush_money_invoice",
			"crime_title": CouncilRulesEngineScript.crime_title(state, "hush_money_invoice"),
			"guilty_count": 3,
			"innocent_count": 1,
			"threshold": 3,
			"votes": [
				{"member_id": "player", "crime_id": "hush_money_invoice", "vote": "guilty"},
				{"member_id": fox_id, "crime_id": "hush_money_invoice", "vote": "guilty"},
				{"member_id": crow_id, "crime_id": "hush_money_invoice", "vote": "guilty"}
			],
			"victims": [
				{"member_id": fox_id, "name": String(state.npcs[0].get("public_name", fox_id)), "portrait": String(state.npcs[0].get("portrait", "")), "portrait_half": String(state.npcs[0].get("portrait_half", ""))},
				{"member_id": crow_id, "name": String(state.npcs[1].get("public_name", crow_id)), "portrait": String(state.npcs[1].get("portrait", "")), "portrait_half": String(state.npcs[1].get("portrait_half", ""))}
			],
			"death_wills": [
				{"member_id": fox_id, "votes": [
					{"member_id": fox_id, "crime_id": "gold_bar_favors", "vote": "guilty", "source": "death_will"},
					{"member_id": fox_id, "crime_id": "gold_bar_favors", "vote": "guilty", "source": "death_will"}
				]}
			]
		},
		{
			"round": 0,
			"crime_id": "gold_bar_favors",
			"crime_title": CouncilRulesEngineScript.crime_title(state, "gold_bar_favors"),
			"guilty_count": 2,
			"innocent_count": 0,
			"threshold": 2,
			"votes": [
				{"member_id": fox_id, "crime_id": "gold_bar_favors", "vote": "guilty", "source": "death_will"},
				{"member_id": crow_id, "crime_id": "gold_bar_favors", "vote": "guilty", "source": "death_will"}
			],
			"victims": [
				{"member_id": deer_id, "name": String(state.npcs[2].get("public_name", deer_id)), "portrait": String(state.npcs[2].get("portrait", "")), "portrait_half": String(state.npcs[2].get("portrait_half", ""))}
			],
			"death_wills": []
		}
	]


func _save_frame(filename: String) -> void:
	var image := root.get_texture().get_image()
	_assert_frame_has_content(image, filename)
	var path := _out_dir.path_join(filename)
	var err := image.save_png(path)
	_must(err == OK, "failed to save %s" % path)


func _assert_frame_has_content(image: Image, filename: String) -> void:
	_must(image.get_width() > 0 and image.get_height() > 0, "%s image is empty" % filename)
	var corner := image.get_pixel(8, 8)
	_must(corner.r < 0.02 and corner.g < 0.02 and corner.b < 0.02, "%s background is not black" % filename)
	var lit_pixels := 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var pixel := image.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b > 0.16:
				lit_pixels += 1
	_must(lit_pixels > 90, "%s appears blank" % filename)


func _must(condition: bool, message := "visual export assertion failed") -> void:
	if condition:
		return
	push_error(message)
	quit(1)
