extends Node2D

const RIG_ROOT := "res://assets/generated/rigs/player_grab/"
const SOURCE_SIZE := Vector2(832.0, 986.0)

var animation_player: AnimationPlayer
var skeleton: Skeleton2D
var _required_layers := [
	"body_base.png",
	"body_arm_hole_fill.png",
	"head.png",
	"scarf_or_cape.png",
	"near_upper_arm.png",
	"near_forearm.png",
	"near_hand.png",
	"held_cards.png"
]


func _ready() -> void:
	if skeleton != null:
		return
	_build_rig()
	_build_animation()


func has_required_assets() -> bool:
	for layer_name in _required_layers:
		if not FileAccess.file_exists(RIG_ROOT + layer_name):
			return false
	return true


func play_grab_forward() -> void:
	if animation_player == null or not animation_player.has_animation("grab_forward"):
		return
	animation_player.stop()
	animation_player.play("grab_forward")


func _build_rig() -> void:
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	add_child(skeleton)

	var root_bone := _make_bone("root", Vector2.ZERO, skeleton)
	var body := _make_bone("body", Vector2(360.0, 548.0), root_bone)
	var head := _make_bone("head", Vector2(-6.0, -304.0), body)
	var upper_arm := _make_bone("near_upper_arm", Vector2(-226.0, -176.0), body)
	var forearm := _make_bone("near_forearm", Vector2(-72.0, 108.0), upper_arm)
	var hand := _make_bone("near_hand", Vector2(-28.0, 132.0), forearm)
	var scarf := _make_bone("scarf_or_cape", Vector2(-42.0, -118.0), body)

	_add_layer(root_bone, "body_arm_hole_fill.png", Vector2.ZERO, -2)
	_add_layer(body, "body_base.png", _joint_global(body), 0)
	_add_layer(head, "head.png", _joint_global(head), 2)
	_add_layer(upper_arm, "near_upper_arm.png", _joint_global(upper_arm), 4)
	_add_layer(forearm, "near_forearm.png", _joint_global(forearm), 5)
	_add_layer(hand, "near_hand.png", _joint_global(hand), 6)
	_add_layer(hand, "held_cards.png", _joint_global(hand), 7)
	_add_layer(scarf, "scarf_or_cape.png", _joint_global(scarf), 8)


func _build_animation() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	add_child(animation_player)

	var animation := Animation.new()
	animation.length = 0.75
	animation.loop_mode = Animation.LOOP_NONE

	_add_vector_track(animation, "Skeleton2D/root/body:position", [
		[0.0, Vector2(360.0, 548.0)],
		[0.12, Vector2(350.0, 550.0)],
		[0.40, Vector2(390.0, 536.0)],
		[0.52, Vector2(404.0, 532.0)],
		[0.75, Vector2(360.0, 548.0)]
	])
	_add_float_track(animation, "Skeleton2D/root/body:rotation_degrees", [
		[0.0, 0.0],
		[0.12, -2.5],
		[0.40, 7.5],
		[0.52, 8.5],
		[0.75, 0.0]
	])
	_add_float_track(animation, "Skeleton2D/root/body/head:rotation_degrees", [
		[0.0, 0.0],
		[0.12, -1.5],
		[0.40, 3.0],
		[0.52, 3.8],
		[0.75, 0.0]
	])
	_add_float_track(animation, "Skeleton2D/root/body/near_upper_arm:rotation_degrees", [
		[0.0, 0.0],
		[0.12, -10.0],
		[0.40, 32.0],
		[0.52, 38.0],
		[0.75, 0.0]
	])
	_add_vector_track(animation, "Skeleton2D/root/body/near_upper_arm:position", [
		[0.0, Vector2(-226.0, -176.0)],
		[0.12, Vector2(-232.0, -172.0)],
		[0.40, Vector2(-198.0, -182.0)],
		[0.52, Vector2(-184.0, -188.0)],
		[0.75, Vector2(-226.0, -176.0)]
	])
	_add_float_track(animation, "Skeleton2D/root/body/near_upper_arm/near_forearm:rotation_degrees", [
		[0.0, 0.0],
		[0.12, -18.0],
		[0.40, 58.0],
		[0.52, 64.0],
		[0.75, 0.0]
	])
	_add_vector_track(animation, "Skeleton2D/root/body/near_upper_arm/near_forearm/near_hand:scale", [
		[0.0, Vector2.ONE],
		[0.40, Vector2(1.08, 1.08)],
		[0.52, Vector2(1.12, 1.12)],
		[0.75, Vector2.ONE]
	])
	_add_float_track(animation, "Skeleton2D/root/body/scarf_or_cape:rotation_degrees", [
		[0.0, 0.0],
		[0.12, -3.0],
		[0.40, 8.0],
		[0.52, 10.0],
		[0.75, 0.0]
	])

	var library := AnimationLibrary.new()
	library.add_animation("grab_forward", animation)
	animation_player.add_animation_library("", library)


func _make_bone(bone_name: String, bone_position: Vector2, parent: Node) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = bone_name
	bone.position = bone_position
	bone.length = 96.0
	bone.rest = Transform2D(0.0, bone_position)
	parent.add_child(bone)
	return bone


func _add_layer(parent: Node2D, file_name: String, joint_global: Vector2, z: int) -> void:
	var sprite := Sprite2D.new()
	sprite.name = file_name.get_basename().capitalize().replace(" ", "")
	sprite.texture = _load_layer_texture(file_name)
	sprite.centered = false
	sprite.position = -joint_global
	sprite.z_index = z
	parent.add_child(sprite)


func _load_layer_texture(file_name: String) -> Texture2D:
	var image := Image.load_from_file(RIG_ROOT + file_name)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _joint_global(node: Node2D) -> Vector2:
	var point := Vector2.ZERO
	var current: Node = node
	while current != null and current != skeleton:
		var node_2d := current as Node2D
		if node_2d != null:
			point += node_2d.position
		current = current.get_parent()
	return point


func _add_float_track(animation: Animation, path: String, keys: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for key in keys:
		animation.track_insert_key(track, float(key[0]), float(key[1]))


func _add_vector_track(animation: Animation, path: String, keys: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for key in keys:
		animation.track_insert_key(track, float(key[0]), key[1])
