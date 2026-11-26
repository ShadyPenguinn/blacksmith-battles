class_name Actor
extends Node3D
## A KayKit adventurer: the mentor, a customer or a co-op smith. Plays the shared
## Rig_Medium clips and can walk to a spot.

var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var hand_bone := -1
var held: Node3D = null
var _loop := "Idle_A"
var _walk_tw: Tween

func setup(path: String) -> Actor:
	model = BK.load_model(path)
	if model == null:
		var b = Build.box(Vector3(0.7, 1.6, 0.5), Color(0.6, 0.5, 0.4))
		b.position.y = 0.8
		add_child(b)
		return self
	model.scale = Vector3.ONE * BK.CHAR_SCALE
	add_child(model)
	var skels = model.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		skel = skels[0]
		hand_bone = skel.find_bone("handslot.r")
	var aps = model.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		anim = AnimationPlayer.new()
		model.add_child(anim)
	else:
		anim = aps[0]
	if not anim.has_animation_library(""):
		anim.add_animation_library("", BK.shared_anims())
	elif not anim.has_animation("Idle_A"):
		anim.add_animation_library("rig", BK.shared_anims())
	loop("Idle_A")
	return self

func _clip(name: String) -> String:
	if anim == null:
		return ""
	if anim.has_animation(name):
		return name
	if anim.has_animation("rig/" + name):
		return "rig/" + name
	return ""

## A looping clip (idle, walking, hammering...).
func loop(name: String, speed := 1.0) -> void:
	_loop = name
	var c = _clip(name)
	if c != "":
		var a = anim.get_animation(c)
		a.loop_mode = Animation.LOOP_LINEAR
		anim.play(c, 0.2, speed)

## A one-shot clip, then back to the loop.
func once(name: String, speed := 1.0) -> void:
	var c = _clip(name)
	if c == "":
		return
	anim.play(c, 0.12, speed)
	var a = anim.get_animation(c)
	var t = a.length / maxf(0.1, speed)
	get_tree().create_timer(maxf(0.1, t - 0.1)).timeout.connect(func():
		if is_instance_valid(self) and anim.current_animation == c:
			loop(_loop))

## A happy little hop with arms up (KayKit has no cheer clip, so we make one).
func cheer() -> void:
	once("Interact", 1.4)
	var tw = create_tween()
	tw.tween_property(self, "position:y", position.y + 0.35, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y + 0.2, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y, 0.14).set_ease(Tween.EASE_IN)

func sulk() -> void:
	once("Hit_B", 0.8)

func face(p: Vector3) -> void:
	var d = p - global_position
	d.y = 0
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)

## Walk to a point at a steady pace, then call done.
func walk_to(p: Vector3, speed := 2.2, done := Callable()) -> void:
	if _walk_tw:
		_walk_tw.kill()
	face(p)
	var t = global_position.distance_to(p) / speed
	loop("Walking_A", 1.2)
	_walk_tw = create_tween()
	_walk_tw.tween_property(self, "global_position", p, t)
	_walk_tw.tween_callback(func():
		loop("Idle_A")
		if done.is_valid():
			done.call())

## Put a model in the right hand (or clear it with null).
func hold(n: Node3D) -> void:
	if held and is_instance_valid(held):
		held.queue_free()
	held = n
	if n == null or skel == null or hand_bone < 0:
		return
	var att = BoneAttachment3D.new()
	att.bone_idx = hand_bone
	skel.add_child(att)
	att.add_child(n)
	held = att

func head_position() -> Vector3:
	if skel:
		var b = skel.find_bone("head")
		if b >= 0:
			return skel.global_transform * skel.get_bone_global_pose(b).origin + Vector3(0, 0.25, 0)
	return global_position + Vector3(0, 1.6, 0)
