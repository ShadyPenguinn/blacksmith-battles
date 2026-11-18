extends CharacterBody3D
## One smith. Movement comes from in_move/in_sprint/in_dive, which main fills from the
## keyboard (local smith) or from the network (remote smiths). On clients every smith is a
## puppet that just follows the host's snapshots.

var main: Node
var idx = 0
var role: Dictionary
## Hotbar. Slot 0 holds your one tool; slots 1-3 hold anything that isn't a tool.
## held is whatever's in the selected slot: that's what F uses and Q throws.
var slots: Array = []
var sel = 0
var held: RigidBody3D:
	get:
		return slots[sel] if sel < slots.size() else null
	set(v):
		slots[sel] = v
var controlled = false
var stun = 0.0
var burn = 0.0            # holding a hot ingot bare-handed
var dive_t = 0.0
var dive_cd = 0.0
var dive_dir = Vector3.ZERO
var flop = false                    # belly flop in progress (jump, then jump again)
var flop_slide = 0.0
var jumped = false
var coyote_t = 0.0
var jump_buf = 0.0
var land_sq = 0.0                   # extra squash (+) or stretch (-) from jumps and landings
var skidding = false
var skid_t = 0.0
var vis_yaw = 0.0
var turn_speed = 0.0                # how fast the body is turning, for banking
var net_air = false                 # client copy of "in the air"
var was_air = false
var facing = Vector3(0, 0, -1)
var lost_tool: RigidBody3D = null   # for Magnet Gloves
var butter_t = 0.0
var visual: Node3D
var head: Node3D
var ring: MeshInstance3D            # shows who you control
var name_tag: Label3D
var in_move = Vector2.ZERO          # -1..1 on each axis
var in_sprint = false
var in_dive = false                 # one-shot, cleared when used
var puppet = false                  # client side: follow snapshots
var net_pos = Vector3.ZERO
var net_rot = Vector3.ZERO
var anim: AnimationPlayer = null    # set when a rigged model is loaded
var anim_names = {}                 # state -> clip name
var anim_state = ""
var last_pos = Vector3.ZERO
var has_model = false
var skel: Skeleton3D = null
var hand_bone = -1
var act_t = 0.0                     # a one-shot action animation is playing
var act_name = ""                   # last action, sent to clients so puppets play it too
var act_seq = 0
var act_seen = 0
var goofy = null                    # goofy.gd: arms and head on top of the clip
var goof = 0.0                      # how much goofy run is on right now (0-1)
var step_phase = 0.0
static var anim_lib: AnimationLibrary = null

## Every clip from the KayKit animation packs, loaded once and shared by all smiths.
static func _shared_anims() -> AnimationLibrary:
	if anim_lib:
		return anim_lib
	anim_lib = AnimationLibrary.new()
	for path in SF.SMITH_ANIMS:
		if not ResourceLoader.exists(path):
			continue
		var scene = load(path).instantiate()
		for ap in scene.find_children("*", "AnimationPlayer", true, false):
			for n in ap.get_animation_list():
				var clip = String(n).get_file()
				if not anim_lib.has_animation(clip):
					anim_lib.add_animation(clip, ap.get_animation(n))
		scene.free()
	for loop_clip in ["Idle_A", "Walking_A", "Running_A"]:
		if anim_lib.has_animation(loop_clip):
			anim_lib.get_animation(loop_clip).loop_mode = Animation.LOOP_LINEAR
	return anim_lib

func setup(p_main: Node, p_idx: int) -> void:
	main = p_main
	idx = p_idx
	role = SF.ROLES[idx]
	slots.resize(SF.SLOTS)
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	visual = Node3D.new()
	visual.position.y = 0.85
	add_child(visual)
	var model = SF.try_model("smith_" + String(role["name"]).to_lower())
	if model == null:
		model = SF.try_model("smith")
	if model:
		has_model = true
		model.position.y = -0.85
		model.rotation.y = SF.SMITH_MODEL_YAW
		model.scale = Vector3.ONE * SF.SMITH_MODEL_SCALE
		visual.add_child(model)
		var skels = model.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			skel = skels[0]
			hand_bone = skel.find_bone("handslot.r")
			goofy = preload("res://scripts/goofy.gd").new()
			goofy.setup(skel)
		var players_found = model.find_children("*", "AnimationPlayer", true, false)
		if players_found.is_empty() and skel:
			var ap = AnimationPlayer.new()
			model.add_child(ap)
			ap.add_animation_library("", _shared_anims())
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			players_found = [ap]
		if not players_found.is_empty():
			anim = players_found[0]
			var clips = anim.get_animation_list()
			for state in SF.ANIM_WORDS:
				for word in SF.ANIM_WORDS[state]:
					if anim_names.has(state):
						break
					for c in clips:
						if word in String(c).to_lower():
							anim_names[state] = c
							break
			for loop_state in ["idle", "walk", "run"]:
				if anim_names.has(loop_state):
					var a = anim.get_animation(anim_names[loop_state])
					if a:
						a.loop_mode = Animation.LOOP_LINEAR
	else:
		visual.add_child(Build.box(Vector3(0.7, 1.0, 0.45), role["color"]))
		head = Build.box(Vector3(0.45, 0.45, 0.45), Color(0.95, 0.8, 0.65))
		head.position.y = 0.75
		visual.add_child(head)
		var nose = Build.box(Vector3(0.12, 0.12, 0.2), Color(0.9, 0.7, 0.55))
		nose.position = Vector3(0, 0.75, -0.3)
		visual.add_child(nose)
	ring = Build.cyl(0.6, 0.04, Color(1, 1, 1), 1.0)
	ring.position.y = 0.03
	add_child(ring)
	name_tag = Build.label(role["name"], 36)
	name_tag.position.y = 2.3
	add_child(name_tag)

func set_big_head(scale_factor: float) -> void:
	if head:
		head.scale = Vector3.ONE * scale_factor
		head.position.y = 0.75 + 0.22 * (scale_factor - 1.0)

func metal_count() -> int:
	var n = 0
	for it in items():
		if it.is_metal():
			n += 1
		if it.tongs_load:
			n += 1
	return n

## Everything you carry, selected or not.
func items() -> Array:
	return slots.filter(func(it): return it != null and is_instance_valid(it))

func heavy_count() -> int:
	var n = 0
	for it in items():
		if it.is_heavy() or (it.tongs_load and it.tongs_load.is_heavy()):
			n += 1
	return n

## Which slot an item would go in, or -1 if there's no room. Tools only fit slot 0.
func slot_for(item: RigidBody3D) -> int:
	if item.kind == "tool":
		return 0 if slots[0] == null else -1
	if sel > 0 and slots[sel] == null:
		return sel
	for i in range(1, slots.size()):
		if slots[i] == null:
			return i
	return -1

## The slot an item would need: 0 for a tool, else the selected pocket (or slot 1).
func blocking_slot(item: RigidBody3D) -> int:
	if item.kind == "tool":
		return 0
	return sel if sel > 0 else 1

func select(i: int) -> void:
	sel = clampi(i, 0, slots.size() - 1)
	burn = 0.0

func cycle(step: int) -> void:
	select(posmod(sel + step, slots.size()))

## Take an item out of whichever slot it's in, without dropping it.
func take(it: RigidBody3D) -> void:
	var i = slots.find(it)
	if i >= 0:
		slots[i] = null
	if it and it.holder == self:
		it.holder = null

func clear_slots() -> void:
	for i in slots.size():
		slots[i] = null
	sel = 0

func hand_position() -> Vector3:
	if skel and hand_bone >= 0:
		return (skel.global_transform * skel.get_bone_global_pose(hand_bone)).origin
	return global_position + Vector3(0, 1.1, 0) + facing * 0.65

## Pick the animation for what the smith is doing right now.
func _animate(delta: float) -> void:
	var moved = Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length() / maxf(delta, 0.001)
	last_pos = global_position
	_goof(delta, moved)
	if anim == null:
		return
	if act_seq != act_seen:
		act_seen = act_seq
		var clip = SF.ACTION_ANIMS.get(act_name, "")
		if anim.has_animation(clip) and stun <= 0.0:
			anim.play(clip, 0.08, 1.4)
			act_t = anim.get_animation(clip).length / 1.4
			anim_state = "act"
	if act_t > 0.0 and stun <= 0.0:
		act_t -= delta
		if act_t > 0.0 and not flop:
			return
	var state = "idle"
	if stun > 0.0:
		state = "stun"
	elif flop:
		state = "flop"
	elif airborne():
		state = "air"
	elif moved > SF.MOVE_SPEED * 1.15:
		state = "run"
	elif moved > 0.4:
		state = "walk"
	if not anim_names.has(state):
		state = "walk" if state == "run" and anim_names.has("walk") else "idle"
	if state != anim_state and anim_names.has(state):
		anim_state = state
		anim.play(anim_names[state], 0.12, SF.GOOFY["clip_speed"] if state in ["walk", "run"] else 1.0)

## In the air? The host knows from physics; clients get it in the snapshot.
func airborne() -> bool:
	return net_air if puppet else not is_on_floor()

## Bounce, waddle, lean, bank and squash; arms and head go to goofy.gd.
func _goof(delta: float, moved: float) -> void:
	var g: Dictionary = SF.GOOFY
	var air = airborne()
	if puppet and was_air and not air:
		land_sq = 0.3
		puff(6, 1.0)
	was_air = air
	var want = 0.0
	if stun <= 0.0 and act_t <= 0.0 and (moved > 0.4 or air or flop):
		want = 1.0 if (air or flop) else clampf(moved / SF.MOVE_SPEED, 0.0, 1.3)
	goof = move_toward(goof, want, delta * 6.0)
	var before = floorf(step_phase)
	if not air and not flop:
		step_phase += moved * delta * g["steps_per_meter"]
		if floorf(step_phase) != before and moved > SF.MOVE_SPEED * 1.15:
			puff(2, 0.5)
	land_sq = move_toward(land_sq, 0.0, delta * 2.5)
	if goofy:
		goofy.amount = minf(goof, 1.0)
		# In the air the arms flap fast like little wings; in a flop they spread wide.
		goofy.phase = step_phase if not air else goofy.phase + delta * (2.0 if flop else 7.0)
	if stun > 0.0:
		return
	var bounce = 0.0 if (air or flop) else absf(sin(step_phase * PI))   # 0 at each footfall
	visual.position.y = 0.85 + bounce * g["hop"] * goof
	var sq = (bounce - 0.5) * 2.0 * g["squash"] * goof * (0.0 if air else 1.0) - land_sq
	if air and not flop:
		sq += clampf(velocity.y / 30.0, -0.1, 0.15)   # stretch going up
	visual.scale = Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5)
	if puppet:
		return
	var bank = clampf(-turn_speed * g["bank"], -0.5, 0.5)
	visual.rotation.z = sin(step_phase * PI) * deg_to_rad(g["waddle_deg"]) * goof * (0.0 if air else 1.0) + bank
	var pitch = -deg_to_rad(g["lean_deg"]) * minf(goof, 1.0)
	if flop:
		pitch = -deg_to_rad(g["flop_deg"])
	elif skidding:
		pitch = deg_to_rad(g["skid_lean_deg"])     # lean back, heels dug in
	visual.rotation.x = lerp_angle(visual.rotation.x, pitch, clampf(delta * 14.0, 0.0, 1.0))

## A little puff of dust at the feet (purely visual).
func puff(count: int, size: float) -> void:
	if not is_inside_tree():
		return
	var pa = CPUParticles3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.09 * size
	mesh.height = 0.18 * size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.9, 0.85, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	pa.mesh = mesh
	pa.one_shot = true
	pa.emitting = true
	pa.amount = maxi(count, 1)
	pa.lifetime = 0.45
	pa.explosiveness = 1.0
	pa.direction = Vector3(0, 1, 0)
	pa.spread = 80.0
	pa.initial_velocity_min = 0.8 * size
	pa.initial_velocity_max = 2.0 * size
	pa.gravity = Vector3(0, 0.6, 0)
	pa.damping_min = 3.0
	pa.damping_max = 5.0
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	pa.scale_amount_curve = curve
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0))
	pa.color_ramp = grad
	main.add_child(pa)
	pa.global_position = global_position + Vector3(0, 0.1, 0)
	pa.finished.connect(pa.queue_free)

## Advance the animation ourselves so the goofy arms go on after it, every frame.
func _process(delta: float) -> void:
	if anim and anim.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		anim.advance(delta)
		if goofy:
			goofy.apply()
	# Snap the held item to the hand after the final pose, so it never lags or drifts.
	_place_in_hand()

## The selected item goes in the model's right-hand slot (tongs carry their load along).
func _place_in_hand() -> void:
	if not has_model or sel < 0 or sel >= slots.size():
		return
	var it = slots[sel]
	if it == null or not is_instance_valid(it) or not it.has_model:
		return
	it.global_transform = hand_transform() * it.grip.affine_inverse()
	if it.tongs_load and is_instance_valid(it.tongs_load):
		it.tongs_load.global_position = it.global_position - it.global_transform.basis.z * 0.55

## Play a one-shot action (mining swing, hammer blow, throw...). Host side; clients copy it.
func act(what: String) -> void:
	act_name = what
	act_seq += 1

## Where held things go: the model's right-hand slot, or a spot in front of the body.
func hand_transform() -> Transform3D:
	if skel and hand_bone >= 0:
		var t = skel.global_transform * skel.get_bone_global_pose(hand_bone)
		return Transform3D(t.basis.orthonormalized(), t.origin)
	return Transform3D(Basis.from_euler(Vector3(0, visual.rotation.y, 0)), hand_position())

func _physics_process(delta: float) -> void:
	ring.visible = controlled
	_animate(delta)
	if puppet:
		global_position = global_position.lerp(net_pos, clampf(delta * 15.0, 0.0, 1.0))
		visual.rotation = net_rot
		return
	if not is_on_floor() and stun > 0.0:
		velocity.y -= SF.MOVE["gravity_down"] * delta
	dive_cd = maxf(0.0, dive_cd - delta)
	_update_held(delta)

	if stun > 0.0:
		stun -= delta
		if not has_model:
			visual.rotation.z += delta * 14.0
			visual.rotation.x = 1.2
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		if stun <= 0.0:
			_recover()
		return

	var dir = Vector3.ZERO
	var sprint = false
	var grounded = is_on_floor()
	var m: Dictionary = SF.MOVE
	if not main.paused_for_roll:
		dir = Vector3(in_move.x, 0, in_move.y).limit_length(1.0)
		sprint = in_sprint
	# Coyote time and jump buffer: forgiving, so jumps never feel eaten.
	coyote_t = m["coyote"] if grounded else maxf(0.0, coyote_t - delta)
	if in_dive:
		jump_buf = m["jump_buffer"]
	in_dive = false
	jump_buf = maxf(0.0, jump_buf - delta)
	if jump_buf > 0.0:
		if coyote_t > 0.0 and dive_t <= 0.0:
			velocity.y = m["jump_speed"]
			coyote_t = 0.0
			jump_buf = 0.0
			jumped = true
			land_sq = -m["jump_stretch"]
			puff(6, 0.8)
		elif not grounded and jumped and dive_t <= 0.0 and dive_cd <= 0.0:
			# Second press in the air: belly flop forward.
			dive_t = SF.DIVE_TIME
			dive_cd = SF.DIVE_COOLDOWN
			flop = true
			dive_dir = dir.normalized() if dir.length() > 0.1 else facing
			velocity.x = dive_dir.x * SF.DIVE_SPEED
			velocity.z = dive_dir.z * SF.DIVE_SPEED
			velocity.y = maxf(velocity.y, m["flop_hop"])
			jump_buf = 0.0
	# Gravity: floaty at the top of the jump, quick on the way down.
	if not grounded:
		var g = m["gravity_up"] if velocity.y > 0.0 else m["gravity_down"]
		if absf(velocity.y) < m["apex_band"] and not flop:
			g *= m["apex_float"]
		velocity.y -= g * delta

	var speed = SF.MOVE_SPEED * (SF.SPRINT_MULT if sprint else 1.0)
	var heavy = heavy_count()
	if heavy > 0:
		var slow = SF.CARRY_SLOW - SF.CARRY_SLOW_EXTRA * (heavy - 1)
		speed *= slow if main.mod("featherweight") == 0 else 0.9
	var flat = Vector3(velocity.x, 0, velocity.z)
	if flop:
		dive_t -= delta
		if grounded and dive_t <= 0.0:
			# Belly slide, then pop back up.
			flat = flat.move_toward(Vector3.ZERO, m["flop_friction"] * delta)
			flop_slide += delta
			if flop_slide >= m["flop_slide_time"] or flat.length() < 0.5:
				flop = false
				flop_slide = 0.0
				land_sq = 0.35
				puff(8, 1.0)
	else:
		var target = dir * speed
		var rate: float
		skidding = false
		if not grounded:
			rate = m["air_accel"]
		elif dir.length() < 0.1:
			rate = m["friction"]
		elif flat.length() > speed * 0.5 and flat.normalized().dot(dir) < -0.2:
			rate = m["skid_decel"]
			skidding = true
		else:
			rate = m["accel"]
		flat = flat.move_toward(target, rate * delta)
		if skidding:
			skid_t += delta
			if skid_t > 0.08:
				skid_t = 0.0
				puff(2, 0.6)
	velocity.x = flat.x
	velocity.z = flat.z
	if dir.length() > 0.1 and not flop:
		facing = dir.normalized()
	elif flop:
		facing = dive_dir
	# Turn smoothly toward where you're heading and bank into the corner.
	var want_yaw = atan2(-facing.x, -facing.z)
	var before = vis_yaw
	vis_yaw = lerp_angle(vis_yaw, want_yaw, clampf(delta * m["turn_rate"], 0.0, 1.0))
	turn_speed = lerpf(turn_speed, angle_difference(before, vis_yaw) / maxf(delta, 0.001), clampf(delta * 10.0, 0.0, 1.0))
	visual.rotation.y = vis_yaw
	var fall = velocity.y
	move_and_slide()
	if is_on_floor() and not grounded and fall < -1.0:
		# Landing: squash and a puff of dust, bigger the harder you land.
		land_sq = clampf(-fall / 12.0, 0.15, 0.5)
		puff(int(clampf(-fall, 4.0, 12.0)), 1.0)
		jumped = false
	if is_on_floor() and not flop:
		jumped = false

	# Butterfingers: sprinting with something in hand can make you drop it.
	if sprint and held and dir.length() > 0.1 and main.mod("butterfingers") > 0:
		butter_t += delta
		if butter_t >= 1.0:
			butter_t = 0.0
			if randf() < 0.15 * main.mod("butterfingers"):
				main.toast(role["name"] + " fumbled!")
				drop(facing * 2.0 + Vector3.UP * 2.0)

## Selected item in hand, the rest stacked on your back where friends can see them.
func _update_held(delta: float) -> void:
	for i in slots.size():
		if slots[i] != null and not is_instance_valid(slots[i]):
			slots[i] = null
	var back = 0
	var yaw = Vector3(0, visual.rotation.y, 0)
	for i in slots.size():
		var it = slots[i]
		if it == null:
			continue
		if i == sel and has_model and it.has_model:
			it.global_transform = hand_transform() * it.grip.affine_inverse()
		elif i == sel:
			it.global_position = hand_position()
			it.global_rotation = yaw
		else:
			it.global_position = global_position + Vector3(0, 0.9 + 0.38 * back, 0) - facing * 0.5
			it.global_rotation = yaw
			back += 1
		if it.tongs_load and is_instance_valid(it.tongs_load):
			it.tongs_load.global_position = it.global_position - it.global_transform.basis.z * 0.55
			it.tongs_load.global_rotation = yaw
	# Bare hands (or pockets) on a hot ingot: ow.
	var hot_one = null
	for it in items():
		if it.kind == "ingot" and it.hot > 0.0:
			hot_one = it
	if hot_one:
		burn += delta
		if burn >= SF.BURN_TIME:
			burn = 0.0
			main.toast("Ow, hot! Use the tongs.")
			drop_item(hot_one, facing * 1.5 + Vector3.UP * 1.5)
	else:
		burn = 0.0

## Put an item in its slot. Returns false if there's no room for it.
func pick_up(item: RigidBody3D) -> bool:
	var i = slot_for(item)
	if i < 0:
		return false
	if item.station:
		item.station.clear_slot(item)
		item.station = null
	var hands_empty = held == null
	item.holder = self
	item.attach()
	slots[i] = item
	# Grab into empty hands, and always draw a sword so you can swing it.
	if hands_empty or item.kind == "weapon":
		select(i)
	return true

## Drop what's in your hand.
func drop(impulse: Vector3 = Vector3.ZERO) -> RigidBody3D:
	if held == null:
		return null
	return drop_item(held, impulse)

func drop_item(it: RigidBody3D, impulse: Vector3 = Vector3.ZERO) -> RigidBody3D:
	take(it)
	if it.tongs_load:
		var gripped = it.tongs_load
		it.tongs_load = null
		gripped.release(impulse)
	it.release(impulse)
	return it

func zap() -> void:
	var stun_time = SF.STUN_TIME * (0.5 ** main.mod("second_wind"))
	stun = stun_time
	flop = false
	velocity = Vector3(randf_range(-4, 4), 7.0, randf_range(-4, 4))
	# Everything you carry goes flying.
	for it in items():
		var fling = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(5.0, 8.0) + Vector3.UP * 6.0
		drop_item(it, fling)
		if it.kind == "tool":
			lost_tool = it

func _recover() -> void:
	stun = 0.0
	visual.rotation = Vector3(0, atan2(-facing.x, -facing.z), 0)
	if lost_tool and is_instance_valid(lost_tool) and main.mod("magnet") > 0 and lost_tool.is_free() and slots[0] == null:
		pick_up(lost_tool)
		main.toast("Magnet Gloves: tool snapped back")
	lost_tool = null

func revive() -> void:
	if stun > 0.0:
		_recover()
