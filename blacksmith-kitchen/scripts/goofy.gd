extends RefCounted
## Goofy run: flings the arms out to the sides and flaps them, and wobbles the head,
## on top of whatever clip is playing. The player sets amount (0 = off, 1 = full run)
## and phase (steps so far), then calls apply() right after the animation has advanced.

var amount = 0.0
var phase = 0.0
var arm_l = -1
var arm_r = -1
var head = -1
var fore_l = -1
var fore_r = -1

var skel: Skeleton3D

func setup(s: Skeleton3D) -> void:
	skel = s
	if s:
		arm_l = s.find_bone("upperarm.l")
		arm_r = s.find_bone("upperarm.r")
		head = s.find_bone("head")
		fore_l = s.find_bone("lowerarm.l")
		fore_r = s.find_bone("lowerarm.r")

func apply() -> void:
	var s = skel
	if s == null or amount <= 0.001:
		return
	var g: Dictionary = BK.GOOFY
	var flap = sin(phase * PI) * deg_to_rad(g["arm_flap_deg"])
	var droop = deg_to_rad(90.0 - g["arms_out_deg"])
	# Arms swing out to the sides: blend toward the rest pose (arms straight out, T-pose)
	# tipped down by droop, flapping with each step. The model faces +Z; its left is +X.
	_arm_out(s, arm_l, Basis(Vector3(0, 0, 1), -(droop + flap)))
	_arm_out(s, arm_r, Basis(Vector3(0, 0, 1), droop - flap))
	# Mostly straighten the elbows so the arms read as flung wide, not pumping.
	_straighten(s, fore_l, g["elbow_straighten"])
	_straighten(s, fore_r, g["elbow_straighten"])
	_turn(s, head, Vector3(0, 0, 1), sin(phase * PI) * deg_to_rad(g["head_wobble_deg"]) * amount)

func _arm_out(s: Skeleton3D, bone: int, tip: Basis) -> void:
	if bone < 0:
		return
	var pose = s.get_bone_global_pose(bone)
	var target = tip * s.get_bone_global_rest(bone).basis
	pose.basis = pose.basis.orthonormalized().slerp(target.orthonormalized(), clampf(amount, 0.0, 1.0))
	_set_global(s, bone, pose)

## Ease a bone's local rotation back toward its rest (straight) rotation.
func _straighten(s: Skeleton3D, bone: int, how_much: float) -> void:
	if bone < 0:
		return
	var now = s.get_bone_pose_rotation(bone)
	var rest = s.get_bone_rest(bone).basis.get_rotation_quaternion()
	s.set_bone_pose_rotation(bone, now.slerp(rest, clampf(amount * how_much, 0.0, 1.0)))

## Rotate a bone about an axis given in skeleton space, around its own joint.
func _turn(s: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0001:
		return
	var pose = s.get_bone_global_pose(bone)
	pose.basis = Basis(axis, angle) * pose.basis
	_set_global(s, bone, pose)

## Write a skeleton-space pose back as the bone's local rotation.
func _set_global(s: Skeleton3D, bone: int, pose: Transform3D) -> void:
	var parent = s.get_bone_parent(bone)
	var local = pose
	if parent >= 0:
		local = s.get_bone_global_pose(parent).affine_inverse() * pose
	s.set_bone_pose_rotation(bone, local.basis.orthonormalized().get_rotation_quaternion())
