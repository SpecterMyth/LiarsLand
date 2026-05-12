extends SceneTree

const AdventureScreenScript := preload("res://scripts/ui/adventure_screen.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")

const CHAPTER_PATHS := [
	"res://data/council_chapter_01.json",
	"res://data/council_chapter_02.json",
	"res://data/council_chapter_03.json"
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := AdventureScreenScript.new()
	for chapter_path in CHAPTER_PATHS:
		var data := ChapterLoaderScript.load_chapter(chapter_path)
		for npc in data.get("npcs", []):
			var path := String(screen.call("_select_card_path_for_npc", npc))
			_must(_asset_exists(path), "%s:%s select card missing at %s" % [chapter_path, String(npc.get("id", "")), path])
			_must(path.ends_with(String(npc.get("portrait", "")).replace("_portrait.png", "_select_card.png")), "%s:%s select card should derive from portrait, got %s" % [chapter_path, String(npc.get("id", "")), path])
	print("Council select card path checks passed.")
	screen.free()
	quit(0)


func _asset_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path))


func _must(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
