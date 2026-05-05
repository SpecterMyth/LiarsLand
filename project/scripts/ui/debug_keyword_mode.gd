extends Control
class_name DebugKeywordMode

const KEYWORD_SETS := {
	"水果": ["苹果", "香蕉", "橙子", "葡萄"],
	"动物": ["狐狸", "乌鸦", "猫", "狼"]
}

var config: Dictionary = {}
var category := ""
var player_keyword := ""
var opponent_keyword := ""
var max_player_chars := 1000
var player_chars := 0
var turn := 0
var rng := RandomNumberGenerator.new()
var log_view: RichTextLabel
var status_label: Label
var start_button: Button


func _ready() -> void:
	rng.randomize()
	_build_ui()
	_reset()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	status_label = Label.new()
	status_label.text = "Debug：关键词诱导"
	root.add_child(status_label)
	start_button = Button.new()
	start_button.text = "运行 Mock 调试局"
	start_button.pressed.connect(_run_mock)
	root.add_child(start_button)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(log_view)


func _reset() -> void:
	player_chars = 0
	turn = 0
	log_view.clear()


func _run_mock() -> void:
	_reset()
	var categories := KEYWORD_SETS.keys()
	category = categories[rng.randi_range(0, categories.size() - 1)]
	var words: Array = KEYWORD_SETS[category].duplicate()
	words.shuffle()
	player_keyword = words[0]
	opponent_keyword = words[1]
	for i in range(2):
		turn += 1
		var player_speech := "请描述一个和%s有关的场景。" % category
		player_chars += player_speech.length()
		log_view.append_text("玩家：%s\n" % player_speech)
		var npc_speech := "也许是%s，但我不会说太多。\n" % player_keyword
		log_view.append_text("对手：%s" % npc_speech)
	status_label.text = "Debug 完成：%s / %s，字符 %d" % [player_keyword, opponent_keyword, player_chars]


func _contains_keyword(text: String, keyword: String) -> bool:
	return text.strip_edges().to_lower().contains(keyword.strip_edges().to_lower())
