extends SceneTree

const OverlayScript := preload("res://scripts/ui/action_animation_overlay.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const ChapterLoaderScript := preload("res://scripts/core/chapter_loader.gd")

const RIG_SCENE := "res://scenes/ui/player_grab_rig.tscn"
const RIG_ASSET_ROOT := "res://assets/generated/rigs/player_grab/"
const RIG_LAYERS := [
	"body_base.png",
	"body_arm_hole_fill.png",
	"head.png",
	"scarf_or_cape.png",
	"near_upper_arm.png",
	"near_forearm.png",
	"near_hand.png",
	"held_cards.png"
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for layer_name in RIG_LAYERS:
		assert(FileAccess.file_exists(RIG_ASSET_ROOT + layer_name))

	var packed := load(RIG_SCENE) as PackedScene
	assert(packed != null)
	var rig := packed.instantiate()
	root.add_child(rig)
	await process_frame
	assert(rig is Node2D)
	assert(rig.get_node_or_null("Skeleton2D") is Skeleton2D)
	assert(rig.get_node_or_null("AnimationPlayer") is AnimationPlayer)
	var player := rig.get_node("AnimationPlayer") as AnimationPlayer
	assert(player.has_animation("grab_forward"))
	for bone_path in [
		"Skeleton2D/root",
		"Skeleton2D/root/body",
		"Skeleton2D/root/body/head",
		"Skeleton2D/root/body/near_upper_arm",
		"Skeleton2D/root/body/near_upper_arm/near_forearm",
		"Skeleton2D/root/body/near_upper_arm/near_forearm/near_hand",
		"Skeleton2D/root/body/scarf_or_cape"
	]:
		assert(rig.get_node_or_null(bone_path) is Bone2D)
	rig.queue_free()

	var state = GameStateScript.new()
	state.load_chapter(ChapterLoaderScript.load_chapter("res://data/chapter_01.json"))
	state.refresh_npc_choices()
	state.choose_npc(0)
	var overlay := OverlayScript.new()
	root.add_child(overlay)
	await process_frame
	overlay.call("_bind_actor_nodes", null, null)
	overlay.call("_use_player_grab_rig")
	var debug_state: Dictionary = overlay.debug_actor_state()
	assert(debug_state.get("player_grab_rig_ready"))
	assert(debug_state.get("player_grab_rig_visible"))
	await overlay.play_action("invite", "player", "", "victory", state)
	assert(not overlay.visible)

	overlay.call("_bind_actor_nodes", null, null)
	debug_state = overlay.debug_actor_state()
	assert(debug_state.get("player_grab_rig_ready"))
	assert(not debug_state.get("player_grab_rig_visible"))
	await overlay.play_action("invite", "npc", "", "victory", state)
	assert(not overlay.visible)

	var external_player := TextureRect.new()
	var external_npc := TextureRect.new()
	root.add_child(external_player)
	root.add_child(external_npc)
	external_player.visible = true
	external_player.modulate = Color(0.8, 0.7, 0.6, 1.0)
	await overlay.play_action("invite", "player", "", "victory", state, external_player, external_npc)
	assert(external_player.visible)
	assert(is_equal_approx(external_player.modulate.a, 1.0))
	print("LiarsLand player grab rig checks passed.")
	quit(0)
