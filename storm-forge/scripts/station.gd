extends StaticBody3D
## Fixed things in the area: ore nodes, furnace, anvil (with its rope hammer), dunk tank
## (kind "trough"), door, lightning rod.

var main: Node
var kind = ""
var ore = ""             # node: which ore it gives
var hits = 0             # node: pickaxe hits so far
var heat = 0.0           # furnace
var contents = {}        # furnace: {"copper": 1, "scrap:2": 1}
var smelt = 0.0          # furnace: seconds spent in band
var slot: RigidBody3D = null  # anvil: ingot on it; dunk tank: sword on the seat
var hp = 0.0             # door
var max_hp = 0.0
var tier = 0             # door armor tier
var beat_t = 0.0         # door weak spot and dunk target clock
var weak: MeshInstance3D  # door weak spot
var weak_x = 0.0
var label: Label3D
var size = Vector3.ONE
var node_id = 0          # node: id for online sync
var chunks = 0           # node: chunks left before the vein is tapped out
var max_chunks = 0
var jiggling = false
var bellows = []         # furnace: the two stomp bellows, left (-1) and right (+1)
var stomp_log = []       # furnace: recent stomp times, to catch over-stomping
var last_side = 0
var last_stomp = -10.0
var mouth: MeshInstance3D  # furnace: the glowing mouth, flares on each puff
var fire_mat: StandardMaterial3D
var spout: Node3D           # furnace model: top of the chimney, where ingots fly out
var mouth_flares = true     # the placeholder mouth box squashes on each puff
# Anvil: rope drop hammer
var shape = 0.0          # slam power so far on the ingot
var ham_h = 0.0          # how high the head is (meters above resting)
var ham_v = 0.0          # falling speed
var head: Node3D
var rope_up: MeshInstance3D
var ropes = []           # one rope line per smith, from the pulley to their hands
var handle: MeshInstance3D      # rope 0's handle (rope 1's is a copy of it)
var handles = []                # one handle per rope
var handle_pos = [Vector3.ZERO, Vector3.ZERO]   # each loose rope end swings under the pulley
var handle_vel = [Vector3.ZERO, Vector3.ZERO]
var rope_count = 2              # ropes on the hammer (the four-rope game has 4)
var game = ""                   # which minigame this station plays this room (SF.GAME_ROOMS)
var full_side = -1              # swap bellows: the one that's full (-1 left, +1 right)
var bellows_y = []              # swap bellows: each one's height when full
var flat_said = 0.0
var swap_tween: Tween = null
var levers = []                 # lever pump: [pivot, base] per lever, left then right
var lever_up = [false, false]
var meter: Node3D               # hammer meter: the bar over the anvil
var meter_mark: Node3D
var meter_text: Label3D
var spots = []                  # two-smith anvil: the ring on each side
var duo_hits = [-10.0, -10.0]   # two-smith anvil: when each spot last hit, and how well
var duo_grade = [0, 0]
var cool = 0                    # bucket relay: splashes the blade on the block has had
var water: MeshInstance3D       # pool: the water surface
var cold_said = 0.0
var weak_said = 0.0
var need_flag: MeshInstance3D
# Dunk tank
var seat: Node3D         # hinge of the seat over the water
var target: Node3D
var target_x = 0.0
var dunk_t = -1.0        # >= 0 while a sword is dropping in and riding the slide
var fly_t = -1.0         # >= 0 while a sword is flying in from the anvil
var fly_from = Vector3.ZERO
var dead = false         # a station left behind in an earlier area: just scenery now
var area = 0             # which area this station is in (deeper areas are harder)

func setup(p_main: Node, p_kind: String, p_size: Vector3, color: Color, opts: Dictionary = {}) -> void:
	main = p_main
	kind = p_kind
	size = p_size
	ore = opts.get("ore", "")
	node_id = opts.get("node_id", 0)
	chunks = opts.get("chunks", SF.VEIN_CHUNKS)
	max_chunks = maxi(chunks, 1)
	add_to_group("station")
	if kind == "node":
		add_to_group("node")
	collision_layer = 1
	collision_mask = 0
	add_child(Build.box_shape(size))
	var model_key = "ore_node" if kind == "node" else kind
	var visual = SF.fitted_model(model_key, size)
	if visual and kind == "node":
		SF.tint(visual, SF.ORE_COLORS.get(ore, Color.GRAY), 0.55, 0.6 if ore == "starmetal" else 0.0)
	if visual == null:
		visual = Build.box(size, color, 0.5 if ore == "starmetal" else 0.0)
	visual.name = "Visual"
	visual.position.y = 0.0
	add_child(visual)
	label = Build.label("", 30)
	label.position = Vector3(0, size.y * 0.5 + 0.6, 0)
	add_child(label)
	if kind == "door":
		weak = Build.box(Vector3(SF.WEAK_SPOT_WIDTH, 1.0, 0.1), Color(1.0, 0.9, 0.3), 2.0)
		weak.position = Vector3(0, -size.y * 0.5 + 1.2, size.z * 0.5 + 0.06)
		add_child(weak)

## Door: the storm gate from the kit, with its stone lintel on top.
func dress_gate() -> void:
	if SF.skin(get_node("Visual"), "gate", "Gate"):
		var lintel = SF.kit_part("gate", "Lintel")
		lintel.position.y = size.y * 0.5
		add_child(lintel)

func set_ore(o: String) -> void:
	ore = o
	var v = get_node_or_null("Visual")
	if v is MeshInstance3D:
		(v as MeshInstance3D).material_override = Build.mat(SF.ORE_COLORS.get(o, Color.GRAY), 0.6 if o == "starmetal" else 0.0)
	elif v:
		SF.tint(v, SF.ORE_COLORS.get(o, Color.GRAY), 0.55, 0.6 if o == "starmetal" else 0.0)

## Leave this station behind in an old area: it stops working and drops what's on it.
func retire() -> void:
	dead = true
	remove_from_group("station")
	remove_from_group("node")
	label.text = ""
	if slot and is_instance_valid(slot):
		var it = slot
		clear_slot(it)
		it.station = null
		it.release()

## Squash and spring back when something hits it.
func jiggle() -> void:
	var v = get_node_or_null("Visual")
	if v == null:
		return
	if not has_meta("base_scale") or not jiggling:
		set_meta("base_scale", v.scale)
	var base: Vector3 = get_meta("base_scale")
	jiggling = true
	var tw = create_tween()
	tw.tween_property(v, "scale", base * Vector3(1.18, 0.78, 1.18), 0.05)
	tw.tween_property(v, "scale", base, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func(): jiggling = false)

func set_chunks(n: int) -> void:
	chunks = n
	var v = get_node_or_null("Visual")
	if v:
		var k = lerpf(0.45, 1.0, float(chunks) / max_chunks)
		v.scale = Vector3(k, k, k)
		v.position.y = -size.y * 0.5 * (1.0 - k)

func _physics_process(delta: float) -> void:
	if dead:
		return
	beat_t += delta
	match kind:
		"node":
			label.text = "%s  %d left%s" % [ore.capitalize(), chunks, ("  " + "*".repeat(hits) if hits > 0 else "")]
		"furnace":
			_furnace_tick(delta)
		"anvil":
			if game in ["meter", "duo"]:
				_meter_tick(delta)
			else:
				_trip_tick(delta)
		"trough":
			if game == "bucket":
				_cool_tick(delta)
			else:
				_dunk_tick(delta)
		"pool":
			label.text = "Water pool\nfill a bucket here"
			if water:
				water.position.y = size.y * 0.5 + 0.02 + sin(beat_t * 2.0) * 0.015
		"door":
			weak_x = sin(beat_t * 0.6) * (size.x * 0.5 - 1.0)
			weak.position.x = weak_x
			label.text = "%s door  %d/%d HP\nNeeds %s or better" % [SF.DOORS[main.door_index]["area"], int(ceil(hp)), int(max_hp), SF.material_name(tier)]
		"rod":
			label.text = "Lightning rod"

func _follow_slot(offset: Vector3) -> void:
	if main.is_client():
		return
	if slot and is_instance_valid(slot):
		slot.global_position = global_position + offset
		slot.global_rotation = Vector3(0, PI * 0.5, 0)

func clear_slot(item: RigidBody3D) -> void:
	if slot == item:
		slot = null
		shape = 0.0
		fly_t = -1.0
		dunk_t = -1.0

# --- Furnace ---

func _furnace_tick(delta: float) -> void:
	if not main.is_client():
		_furnace_logic(delta)
	_fire_glow()
	var line = "Furnace  heat %d" % int(heat)
	if contents.is_empty():
		label.text = line + "\nempty"
		return
	var stuff = []
	for k in contents.keys():
		stuff.append("%s x%d" % [_content_name(k), contents[k]])
	line += "\n" + ", ".join(stuff)
	var target = best_recipe()
	if target < 0:
		label.text = line + "\nno recipe yet"
		return
	var band: Array = SF.MATERIALS[target]["band"]
	line += "\n%s: keep heat %d-%d  %s" % [SF.material_name(target), int(band[0]), int(band[1]), Build.meter(heat / 100.0, band[0] / 100.0, band[1] / 100.0)]
	label.text = line + ("  %d%%" % int(100.0 * smelt / SF.SMELT_TIME))

## The mouth shows the fire: dark when cold, orange warming up, yellow when it's the
## right heat for what's inside, red and pulsing when it's about to turn to slag.
func _fire_glow() -> void:
	if mouth == null:
		return
	if fire_mat == null:
		fire_mat = mouth.material_override
	var f: Dictionary = SF.FIRE
	if heat < 1.0:
		fire_mat.albedo_color = Color(0.07, 0.05, 0.04)
		fire_mat.emission_energy_multiplier = 0.0
		return
	var c: Color
	var e: float
	var target = best_recipe()
	if target >= 0:
		var band: Array = SF.MATERIALS[target]["band"]
		if heat < band[0]:
			c = f["warming"]
			e = lerpf(0.25, 0.9, heat / band[0])
		elif heat <= band[1]:
			c = f["ready"]
			e = 1.3
		else:
			var k = clampf((heat - band[1]) / SF.OVERHEAT_MARGIN, 0.0, 1.0)
			c = f["too_hot"]
			e = 1.2 + 1.2 * k + sin(Time.get_ticks_msec() / 1000.0 * (8.0 + 14.0 * k)) * 0.8 * k
	else:
		c = f["warming"] if heat < 90.0 else f["too_hot"]
		e = lerpf(0.25, 1.0, clampf(heat / 100.0, 0.0, 1.0))
	fire_mat.albedo_color = c.darkened(0.2)
	fire_mat.emission_enabled = true
	fire_mat.emission = c
	fire_mat.emission_energy_multiplier = maxf(e, 0.2)

func _furnace_logic(delta: float) -> void:
	heat = maxf(0.0, heat - SF.HEAT_DECAY * delta)
	var target = best_recipe()
	if contents.is_empty() or target < 0:
		smelt = 0.0
		return
	var band: Array = SF.MATERIALS[target]["band"]
	if heat > band[1] + SF.OVERHEAT_MARGIN:
		contents.clear()
		smelt = 0.0
		main.toast("Too hot! The batch turned to slag.")
		return
	if heat >= band[0] and heat <= band[1]:
		smelt += delta
		if smelt >= SF.SMELT_TIME:
			_consume(target)
			smelt = 0.0
			if spout:
				_launch_ingot(target)
			else:
				var ingot = main.spawn_item("ingot", global_position + Vector3(1.4, 1.0, 0.6), {"tier": target})
				ingot.apply_central_impulse(Vector3(1.5, 2.0, 0.5) * ingot.mass)
			main.toast(SF.material_name(target) + " ingot ready! Grab it with tongs.")

## The chimney cap pops and the hot ingot shoots out, tumbling, to land somewhere random.
func _launch_ingot(target: int) -> void:
	var c: Dictionary = SF.CHIMNEY
	var ingot = main.spawn_item("ingot", spout.global_position, {"tier": target})
	var a = randf() * TAU
	var sp = randf_range(c["min_speed"], c["max_speed"])
	ingot.apply_central_impulse(Vector3(cos(a) * sp, c["up"], sin(a) * sp) * ingot.mass)
	var t = c["spin"]
	ingot.apply_torque_impulse(Vector3(randf_range(-t, t), randf_range(-t, t), randf_range(-t, t)) * ingot.mass)
	pop_cap()
	main.net_event("chimney", 0)

## The cap flips open with a burst of sparks and smoke.
func pop_cap() -> void:
	if spout == null:
		return
	var found = find_children("*", "AnimationPlayer", true, false)
	for ap in found:
		if ap.has_animation("Pop"):
			ap.stop()
			ap.play("Pop")
	Fx.burst(main, spout.global_position, Color(1.0, 0.6, 0.2), 14, 1.5, 5.0, 3.0, 0.5, Vector3(0, 1, 0), 35.0)
	Fx.burst(main, spout.global_position, Color(0.35, 0.33, 0.32, 0.8), 10, 1.0, 2.5, 0.0, 0.9, Vector3(0, 1, 0), 30.0)

## Swap the placeholder box for the stone forge model. Returns false if it's missing.
func use_furnace_model() -> bool:
	var m = SF.try_model("furnace_model")
	if m == null:
		return false
	var vis = get_node_or_null("Visual")
	if vis:
		vis.visible = false
	m.name = "Model"
	m.position.y = -size.y * 0.5
	add_child(m)
	var glow = m.find_child("Glow", true, false)
	if glow is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.07, 0.05, 0.04)
		mat.emission_enabled = true   # always on (energy 0 when cold): flipping it compiles a shader
		mat.emission_energy_multiplier = 0.0
		glow.material_override = mat
		mouth = glow
		mouth_flares = false
	spout = m.find_child("Spout", true, false)
	label.position.y = 2.95   # above the chimney
	return true

func _content_name(k: String) -> String:
	if k.begins_with("scrap:"):
		return SF.material_name(int(k.substr(6))) + " scrap"
	return k

## Highest material the contents can make right now, or -1.
func best_recipe() -> int:
	for i in range(SF.MATERIALS.size() - 1, -1, -1):
		if contents.get("scrap:%d" % i, 0) > 0:
			return i
		var recipe: Dictionary = SF.MATERIALS[i]["recipe"]
		var ok = true
		for k in recipe:
			if contents.get(k, 0) < recipe[k]:
				ok = false
				break
		if ok:
			return i
	return -1

func _consume(i: int) -> void:
	var sk = "scrap:%d" % i
	if contents.get(sk, 0) > 0:
		_take(sk, 1)
		return
	var recipe: Dictionary = SF.MATERIALS[i]["recipe"]
	for k in recipe:
		_take(k, recipe[k])

func _take(k: String, n: int) -> void:
	contents[k] = contents.get(k, 0) - n
	if contents[k] <= 0:
		contents.erase(k)

## Put an item in. Returns true if the station took it.
func accept(item: RigidBody3D) -> bool:
	match kind:
		"furnace":
			if item.kind == "ore":
				contents[item.ore] = contents.get(item.ore, 0) + 1
			elif item.kind in ["scrap", "ingot", "blank"]:
				var k = "scrap:%d" % item.tier
				contents[k] = contents.get(k, 0) + 1
			else:
				return false
			main.despawn(item)
			return true
		"anvil":
			if slot == null and item.kind == "ingot":
				_seat(item)
				return true
		"trough":
			if slot == null and item.kind == "blank":
				_seat(item)
				return true
	return false

func _seat(item: RigidBody3D) -> void:
	slot = item
	shape = 0.0
	item.holder = null
	item.gripped_by = null
	item.station = self
	item.attach()

# --- Tool use ---

## Furnace: two big hinged bellows, one each side, nozzles into the fire, that smiths jump on.
## Uses MODELS["bellows"] (its lid slams shut on "Stomp"); falls back to stacked boxes.
func add_bellows() -> void:
	var sz: Vector3 = SF.BELLOWS["size"]
	for side in [-1, 1]:
		var b = StaticBody3D.new()
		b.collision_layer = 1
		var squish = Node3D.new()
		squish.name = "Squish"
		b.add_child(squish)
		var model = SF.fitted_model("bellows", sz)
		if model:
			model.position.y = sz.y * 0.5
			# the model's nozzle points +X: turn the right-hand one to face the furnace
			model.rotation.y = PI if side > 0 else 0.0
			squish.add_child(model)
		else:
			var cs = Build.box_shape(sz)
			cs.position.y = sz.y * 0.5
			b.add_child(cs)
			var leather = Color(0.42, 0.26, 0.16)
			for i in 3:
				var w = sz.x * (0.92 if i % 2 == 0 else 0.78)
				var pleat = Build.box(Vector3(w, sz.y * 0.28, w), leather.darkened(0.12 * (i % 2)))
				pleat.position.y = sz.y * (0.14 + 0.28 * i)
				squish.add_child(pleat)
			var top = Build.box(Vector3(sz.x * 1.05, 0.1, sz.z * 1.05), Color(0.55, 0.38, 0.2))
			top.position.y = sz.y - 0.02
			squish.add_child(top)
			var nozzle = Build.box(Vector3(0.6, 0.16, 0.16), Color(0.35, 0.33, 0.32))
			nozzle.position = Vector3(-side * (sz.x * 0.5 + 0.2), 0.25, 0)
			b.add_child(nozzle)
		b.set_meta("bellows", self)
		b.set_meta("side", side)
		add_child(b)
		var gap = -SF.BELLOWS["nozzle_in"] if model else 0.35
		b.position = Vector3(side * (size.x * 0.5 + sz.x * 0.5 + gap), -size.y * 0.5, 0)
		if model:
			_bellows_collision(b, model)
		bellows.append(b)
		bellows_y.append(b.position.y)
	if game == "swap":
		_swap_pose(false)

## Swap bellows: the full one stands tall, the flat one sinks into the floor (its top too,
## so you can't land on air). anim: slide there instead of jumping.
func _swap_pose(anim: bool) -> void:
	for i in bellows.size():
		var side = -1 if i == 0 else 1
		var y: float = bellows_y[i] - (0.0 if side == full_side else SF.SWAP["sink"])
		var sq = bellows[i].get_node("Squish")
		var squash = Vector3.ONE if side == full_side else Vector3(1.06, 0.7, 1.06)
		if anim:
			if i == 0 and swap_tween and swap_tween.is_valid():
				swap_tween.kill()   # a quick second stomp: start from where it is now
			if i == 0:
				swap_tween = create_tween().set_parallel()
			var tw = swap_tween
			var t = 0.12 if side != full_side else 0.45
			tw.tween_property(bellows[i], "position:y", y, t).set_trans(Tween.TRANS_BACK if side == full_side else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(sq, "scale", squash, t).set_trans(Tween.TRANS_ELASTIC if side == full_side else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			bellows[i].position.y = y
			sq.scale = squash

## Collision that follows the model: one convex hull per part, in the open pose (the lid is a
## slope you land on). Built once; the lid's slam is only visual.
func _bellows_collision(b: StaticBody3D, model: Node3D) -> void:
	var inv = b.global_transform.affine_inverse()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		# bake the model's scale into the points: physics doesn't like scaled shapes
		var xf = inv * mi.global_transform
		var pts = PackedVector3Array()
		for v in mi.mesh.get_faces():
			pts.append(xf * v)
		var hull = ConvexPolygonShape3D.new()
		hull.points = pts
		var cs = CollisionShape3D.new()
		cs.shape = hull
		b.add_child(cs)

## The model's AnimationPlayer, if the bellows has one.
func _bellows_anim(b: Node3D) -> AnimationPlayer:
	var found = b.find_children("*", "AnimationPlayer", true, false)
	return found[0] if not found.is_empty() else null

## Someone landed on a bellows. power ~1 for a normal jump, more for a belly flop.
## Host side. Alternating sides pumps best; stomping too fast makes the furnace burp.
func stomp(side: int, power: float) -> void:
	if dead:
		return
	var g: Dictionary = SF.BELLOWS
	var now = Time.get_ticks_msec() / 1000.0
	var gain = g["heat"] * power
	if game == "swap":
		if side != full_side:
			if now - flat_said > 2.0:
				flat_said = now
				main.toast("That bellows is flat! Stomp the full one.")
			return
		gain = SF.SWAP["heat"] * power
		last_side = 0   # no one-footed penalty: the flat one can't be stomped anyway
	if side == last_side and now - last_stomp < g["same_side_window"]:
		gain *= g["same_side_mult"]   # one-footed: the bellows hasn't refilled yet
	last_side = side
	last_stomp = now
	heat = minf(110.0, heat + gain * (1.3 ** main.mod("hot_coals")) * (0.7 ** main.mod("wet_coal")))
	squish(side)
	main.net_event("stomp", side)
	stomp_log.append(now)
	while not stomp_log.is_empty() and now - stomp_log[0] > g["burp_window"]:
		stomp_log.pop_front()
	if stomp_log.size() >= g["burp_stomps"]:
		stomp_log.clear()
		burp()

## The bellows squashes flat and springs back, and a puff of air hits the fire.
## Swap bellows: the stomped one stays flat and the other one fills back up.
func squish(side: int) -> void:
	var b = bellows[0] if side < 0 else bellows[1]
	if game == "swap":
		full_side = -side
		_swap_pose(true)
	var sq = b.get_node("Squish")
	var anim = _bellows_anim(b)
	if game == "swap":
		pass   # the pose tween squashes it
	elif anim and anim.has_animation("Stomp"):
		anim.stop()
		anim.play("Stomp")   # the lid slams shut and springs back open
		var tw = create_tween()   # plus a little squash of the whole thing
		tw.tween_property(sq, "scale", Vector3(1.04, 0.9, 1.04), 0.05)
		tw.tween_property(sq, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		var tw = create_tween()
		tw.tween_property(sq, "scale", Vector3(1.12, 0.45, 1.12), 0.06)
		tw.tween_property(sq, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var noz = b.global_position + Vector3(-side * (SF.BELLOWS["size"].x * 0.5 + 0.4), 0.25, 0)
	if anim:   # the model's nozzle is tucked into the furnace: puff where it goes in
		noz = b.global_position + Vector3(-side * (SF.BELLOWS["size"].x * 0.5 - SF.BELLOWS["nozzle_in"] - 0.05), 0.3, 0)
	Fx.burst(main, noz, Color(0.95, 0.95, 0.9, 0.7), 8, 1.2, 4.0, 0.5, 0.35, Vector3(-side, 0.2, 0), 25.0)
	if mouth and not mouth_flares:
		Fx.burst(main, global_position + Vector3(0, -0.45, 1.15), Color(1.0, 0.55, 0.15), 10, 1.0, 3.0, 3.0, 0.45, Vector3(0, 1, 0.6), 40.0)
	elif mouth:
		Fx.burst(main, mouth.global_position + Vector3(0, 0.2, 0.15), Color(1.0, 0.55, 0.15), 10, 1.0, 3.0, 3.0, 0.45, Vector3(0, 1, 0.6), 40.0)
		var tw2 = create_tween()
		tw2.tween_property(mouth, "scale", Vector3(1.25, 1.8, 1.0), 0.06)
		tw2.tween_property(mouth, "scale", Vector3.ONE, 0.35)

## Over-stomped: the furnace burps a fireball that knocks everyone nearby back.
func burp() -> void:
	var g: Dictionary = SF.BELLOWS
	heat = maxf(0.0, heat - g["burp_heat_loss"])
	burp_fx()
	main.net_event("burp", null)
	main.toast("BURP! Too much air. Easy on the bellows.")
	for p in main.players:
		var d = p.global_position - global_position
		d.y = 0
		if d.length() < g["burp_radius"] and p.stun <= 0.0:
			var away = d.normalized() if d.length() > 0.1 else Vector3(0, 0, 1)
			p.stun = g["burp_stun"]
			p.velocity = away * g["burp_push"] + Vector3.UP * 6.0

func burp_fx() -> void:
	var at = global_position + Vector3(0, 0, size.z * 0.5 + 0.3)
	Fx.burst(main, at, Color(1.0, 0.5, 0.1), 40, 2.5, 7.0, 2.0, 0.7, Vector3(0, 0.6, 1), 70.0)
	Fx.burst(main, at + Vector3(0, 0.8, 0), Color(0.25, 0.22, 0.2, 0.8), 20, 2.5, 3.0, 2.5, 1.0, Vector3.UP, 50.0)
	if main.has_method("flash"):
		main.shake = maxf(main.shake, 0.35)

func pump() -> void:
	heat = minf(110.0, heat + SF.HEAT_PER_PUMP * (1.3 ** main.mod("hot_coals")) * (0.7 ** main.mod("wet_coal")))

func mine() -> String:
	hits += 1
	if hits >= SF.MINE_HITS:
		hits = 0
		var chunk = main.spawn_item("ore", global_position + Vector3(0, size.y * 0.5 + 0.5, 0), {"ore": ore})
		chunk.apply_central_impulse(Vector3(randf_range(-1.5, 1.5), 3.0, randf_range(0.5, 2.0)) * chunk.mass)
		set_chunks(chunks - 1)
		if chunks <= 0:
			var name = ore.capitalize()
			main.remove_node(self)
			return name + " ore! The vein is tapped out."
		return ore.capitalize() + " ore!"
	return "Tink"

## Hit the door. Returns a message.
func door_hit(player: Node3D, item: RigidBody3D) -> String:
	var weak_hit = absf(player.global_position.x - (global_position.x + weak_x)) <= SF.WEAK_SPOT_WIDTH * 0.5 + 0.3
	var mult = SF.WEAK_SPOT_MULT if weak_hit else 1.0
	if item.kind == "tool":
		_damage(SF.TOOL_DOOR_DAMAGE * mult)
		return "Chip"
	var wear = 1.0 * (1.4 ** main.mod("brittle"))
	if item.tier < tier:
		item.durability -= SF.BOUNCE_DURABILITY_COST * wear
		main.check_weapon(item, player)
		return "CLANG! Bounced off. Needs %s or better" % SF.material_name(tier)
	var dmg = SF.WEAPON_DAMAGE * (1.0 + SF.TIER_BONUS * (item.tier - tier)) * mult * (1.25 ** main.mod("sharp"))
	item.durability -= wear
	_damage(dmg)
	main.check_weapon(item, player)
	return ("WEAK SPOT! " if weak_hit else "") + "-%d" % int(dmg)

func _damage(d: float) -> void:
	hp -= d
	var v = get_node_or_null("Visual")
	if v:
		v.position.x = randf_range(-0.08, 0.08)
	if hp <= 0.0:
		main.door_broken()

# --- Anvil: rope drop hammer ---

const POST_X := 0.85
const POST_Z := -0.55
const PULLEY_X := 1.55

## How far the head rises at full pull. The frame grows taller each area.
func lift() -> float:
	return SF.TRIP["lift"] + SF.TRIP["lift_per_area"] * area

func _top_y() -> float:
	return -size.y * 0.5 + lift() + 1.9

## How far the head must drop before it shapes this metal at all.
func min_drop(tier: int) -> float:
	var m: Array = SF.TRIP["min_drop"]
	return m[clampi(tier, 0, m.size() - 1)]

func _head_rest_y() -> float:
	return size.y * 0.5 + 0.62

## A tall frame over the anvil with a giant hammer head on a rope. The rope runs over a
## pulley to a handle at the side: grab it and walk away to haul the head up.
func add_trip_hammer(count: int = 2) -> void:
	rope_count = count
	handle_pos = []
	handle_vel = []
	for i in count:
		handle_pos.append(Vector3.ZERO)
		handle_vel.append(Vector3.ZERO)
	var gy = -size.y * 0.5
	var wood = Color(0.45, 0.3, 0.18)
	var tall = _top_y() - gy
	for x in [-POST_X, POST_X]:
		var post = Build.box(Vector3(0.25, tall, 0.25), wood)
		post.position = Vector3(x, gy + tall * 0.5, POST_Z)
		add_child(post)
		var cs = Build.box_shape(Vector3(0.25, tall, 0.25))
		cs.position = post.position
		add_child(cs)
	# Height marks every half meter, and a red flag at the drop this metal needs.
	for i in int(lift() / 0.5) + 1:
		var tick = Build.box(Vector3(0.3, 0.03, 0.04), Color(0.9, 0.85, 0.7))
		tick.position = Vector3(-POST_X, _head_rest_y() - 0.35 + i * 0.5, POST_Z + 0.14)
		add_child(tick)
	need_flag = Build.box(Vector3(0.45, 0.16, 0.05), Color(0.9, 0.12, 0.1), 0.6)
	need_flag.visible = false
	add_child(need_flag)
	var beam = Build.box(Vector3(PULLEY_X + POST_X + 0.3, 0.25, 0.3), wood.darkened(0.15))
	beam.position = Vector3((PULLEY_X - POST_X) * 0.5, _top_y(), POST_Z)
	add_child(beam)
	var arm = Build.box(Vector3(0.22, 0.2, -POST_Z + 0.15), wood.darkened(0.15))
	arm.position = Vector3(0, _top_y(), POST_Z * 0.5)
	add_child(arm)
	var pulley = Build.cyl(0.22, 0.12, Color(0.3, 0.3, 0.32))
	pulley.rotation_degrees = Vector3(90, 0, 0)
	pulley.position = Vector3(PULLEY_X, _top_y(), POST_Z)
	add_child(pulley)
	head = Node3D.new()
	add_child(head)
	var iron = Build.box(Vector3(1.3, 0.7, 0.95), Color(0.22, 0.22, 0.25))
	head.add_child(iron)
	var band = Build.box(Vector3(1.34, 0.16, 0.99), Color(0.75, 0.55, 0.2))
	band.position.y = 0.12
	head.add_child(band)
	var face = Build.box(Vector3(1.15, 0.08, 0.8), Color(0.4, 0.4, 0.44))
	face.position.y = -0.37
	head.add_child(face)
	head.position = Vector3(0, _head_rest_y(), 0)
	var rope_col = Color(0.78, 0.68, 0.45)
	rope_up = Build.box(Vector3(0.07, 1.0, 0.07), rope_col)
	add_child(rope_up)
	for i in 4:
		var r = Build.box(Vector3(0.07, 0.07, 1.0), rope_col)
		r.visible = false
		add_child(r)
		ropes.append(r)
	handle = Build.box(Vector3(0.45, 0.12, 0.12), Color(0.85, 0.2, 0.15))
	add_child(handle)
	_dress_trip_hammer()
	# A rope per smith, so they can haul at once. The others are dressed the same as rope 0.
	handles = [handle]
	for i in range(1, count):
		var h2 = handle.duplicate()
		add_child(h2)
		handles.append(h2)
	_trip_visuals()

## Swap the rig's placeholder boxes for the KayKit-style kit (if it's there). Same nodes,
## same anchor points: the rope pieces only change mesh, so stretching them still works.
func _dress_trip_hammer() -> void:
	if SF.kit_mesh("trip", "PostShaft") == null:
		return
	var keep = [need_flag, rope_up, handle, head] + ropes
	for c in get_children():
		if not c is MeshInstance3D or c in keep or c.name == "Visual":
			continue
		var bm = c.mesh as BoxMesh
		if bm and bm.size.y < 0.05:
			continue   # height marks stay
		c.visible = false
	var gy = -size.y * 0.5
	var top = _top_y()
	var parts = []
	for x in [-POST_X, POST_X]:
		parts.append(["PostFoot", Vector3(x, gy, POST_Z), Vector3.ONE])
		parts.append(["PostShaft", Vector3(x, gy, POST_Z), Vector3(1, top - gy, 1)])
	parts.append(["Beam", Vector3((PULLEY_X - POST_X) * 0.5, top, POST_Z), Vector3.ONE])
	parts.append(["Arm", Vector3(0, top, POST_Z * 0.5), Vector3.ONE])
	parts.append(["Bracket", Vector3(PULLEY_X, top, POST_Z), Vector3.ONE])
	parts.append(["Pulley", Vector3(PULLEY_X, top, POST_Z), Vector3.ONE])
	for p in parts:
		var mi = SF.kit_part("trip", p[0])
		mi.position = p[1]
		mi.scale = p[2]
		add_child(mi)
	for c in head.get_children():
		c.visible = false
	head.add_child(SF.kit_part("trip", "Head"))
	SF.skin(rope_up, "trip", "RopeY")
	for r in ropes:
		SF.skin(r, "trip", "RopeZ")
	SF.skin(handle, "trip", "Handle")

## Where rope i comes down from the pulley, at ground level: pull away from here.
func rope_anchor(i: int = 0) -> Vector3:
	return to_global(Vector3(PULLEY_X, -size.y * 0.5, POST_Z + rope_z(i)))

func handle_rest(i: int = 0) -> Vector3:
	return to_global(Vector3(PULLEY_X, -size.y * 0.5 + 1.0, POST_Z + rope_z(i)))

func _pulley_point(i: int) -> Vector3:
	return to_global(Vector3(PULLEY_X, _top_y(), POST_Z + rope_z(i) * 0.3))

## The ropes hang side by side off the pulley, 0.4 m apart (2 ropes: -0.3 and +0.3).
func rope_z(i: int) -> float:
	if rope_count <= 2:
		return -0.3 + 0.6 * i
	return (i - (rope_count - 1) * 0.5) * 0.4

## Who's holding rope i, or null.
func holder(i: int) -> Node3D:
	for p in main.players:
		if p.rope == self and p.rope_slot == i:
			return p
	return null

## The closest rope nobody's holding whose handle is in reach of p, or -1.
func free_rope_for(p: Node3D) -> int:
	if dead or head == null:
		return -1
	var best = -1
	var bd = SF.TRIP["grab_reach"]
	for i in rope_count:
		if holder(i) != null:
			continue
		var at: Vector3 = handle_pos[i] if handle_pos[i] != Vector3.ZERO else handle_rest(i)
		var d = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if d <= bd:
			bd = d
			best = i
	return best

func near_handle(p: Node3D) -> bool:
	return free_rope_for(p) >= 0

func pullers() -> Array:
	return main.players.filter(func(p): return p.rope == self)

## Host: the head rises toward where the ropes hold it, and drops when they let go.
func _trip_tick(delta: float) -> void:
	if not main.is_client() and head:
		var g: Dictionary = SF.TRIP
		# The head hangs on the rope: it's as high as the furthest hauler has pulled.
		var want = 0.0
		for p in pullers():
			want = maxf(want, p.rope_pull())
		if game == "ropes":
			# Each rope only lifts so high: more smiths on more ropes, more height.
			want = minf(want, SF.ROPES["per_rope"] * pullers().size())
		if want >= ham_h:
			ham_h = want
			ham_v = 0.0
		elif ham_h > want:
			ham_v += g["gravity"] * delta
			ham_h -= ham_v * delta
			if ham_h <= want:
				if want <= 0.001:
					var power = ham_v * ham_v / (2.0 * g["gravity"] * lift())
					ham_h = 0.0
					ham_v = 0.0
					if power >= g["min_power"]:
						slam(minf(power, 1.0))
				else:
					ham_h = want   # the rope catches it
					ham_v = 0.0
		_follow_slot(Vector3(0, size.y * 0.5 + 0.15, 0))
	if head:
		_trip_visuals(delta)
	if need_flag:
		need_flag.visible = slot != null and slot.kind == "ingot" and min_drop(slot.tier) > 0.0
		if need_flag.visible:
			need_flag.position = Vector3(-POST_X - 0.1, _head_rest_y() - 0.35 + min_drop(slot.tier), POST_Z + 0.16)
	if slot == null:
		label.text = "Anvil\nbring a hot ingot"
	elif slot.kind == "ingot" and slot.hot > 0.0:
		var need = _shape_needed()
		var hint = "pull the rope back!"
		if game == "ropes":
			hint = "each rope lifts %.1f m: more smiths on ropes, more height!" % SF.ROPES["per_rope"]
		elif min_drop(slot.tier) > 0.0:
			hint = "drop it from above the red flag!"
		label.text = "%s  %d%%\n%s" % [slot.display_name(), int(100.0 * minf(shape / need, 1.0)), hint]
	else:
		label.text = slot.display_name() + "\ntoo cold: reheat in the furnace"

func _shape_needed() -> float:
	return SF.TRIP["shape_needed"] * (1.5 ** main.mod("tiny_anvil"))

## Head, the rope above it, the handle, and a rope from the pulley to each puller's hands.
func _trip_visuals(delta: float = 0.0) -> void:
	head.position.y = _head_rest_y() + ham_h
	var head_top = head.position.y + 0.35
	rope_up.position = Vector3(0, (head_top + _top_y()) * 0.5, 0)
	rope_up.scale.y = maxf(_top_y() - head_top, 0.05)
	for i in ropes.size():
		ropes[i].visible = i < rope_count
	for i in rope_count:
		var pulley = _pulley_point(i)
		var h: MeshInstance3D = handles[i] if i < handles.size() else handle
		var who = holder(i)
		if who == null:
			_swing_handle(i, pulley, delta)
			h.visible = true
			h.global_position = handle_pos[i]
			_stretch(ropes[i], pulley, handle_pos[i])
		else:
			h.visible = false
			# Follow the hands, so letting go starts the swing from there, moving.
			var at = who.hand_position()
			if delta > 0.0 and handle_pos[i] != Vector3.ZERO:
				handle_vel[i] = (at - handle_pos[i]) / delta
			handle_pos[i] = at
			_stretch(ropes[i], pulley, at)

## The loose rope end is a weight on a string from the pulley. The string is as long as
## the rope that's out: the rest length plus however high the head still is, so as the
## hammer drops the rope whips back up through the pulley, then swings and settles.
func _swing_handle(i: int, pulley: Vector3, delta: float) -> void:
	if handle_pos[i] == Vector3.ZERO or delta <= 0.0:
		handle_pos[i] = handle_rest(i)
		handle_vel[i] = Vector3.ZERO
		return
	var g: Dictionary = SF.TRIP
	var pos: Vector3 = handle_pos[i]
	var vel: Vector3 = handle_vel[i]
	vel.y -= g["rope_gravity"] * delta
	vel *= maxf(0.0, 1.0 - g["rope_damping"] * delta)
	pos += vel * delta
	# Both ropes are tied to the head, so the higher it is, the more loose rope hangs out.
	var length = (pulley.y - handle_rest(i).y) + ham_h
	var d = pos - pulley
	if d.length() > length:
		var dir = d.normalized()
		pos = pulley + dir * length
		var out = vel.dot(dir)
		if out > 0.0:
			vel -= dir * out   # the rope goes taut: only the swing is left
	pos.y = maxf(pos.y, global_position.y - size.y * 0.5 + 0.1)
	handle_pos[i] = pos
	handle_vel[i] = vel

func _stretch(r: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mid = (a + b) * 0.5
	var d = b - a
	var len = maxf(d.length(), 0.05)
	var up = Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis = Basis.looking_at(d, up)
	basis.z *= len
	r.global_transform = Transform3D(basis, mid)

## Host: the head hit the anvil. power 0..1 (1 = dropped from the very top of the frame).
func slam(power: float) -> void:
	var g: Dictionary = SF.TRIP
	slam_fx(power)
	main.net_event("slam", power)
	if power >= g["big_power"]:
		for p in main.players:
			if p.rope != null or p.stun > 0.0:
				continue
			var d = p.global_position - global_position
			d.y = 0
			if d.length() < g["quake_radius"]:
				var away = d.normalized() if d.length() > 0.1 else Vector3(0, 0, 1)
				p.stun = g["quake_stun"]
				p.velocity = away * g["quake_push"] + Vector3.UP * 5.0
	if slot == null:
		return
	if slot.kind != "ingot" or slot.hot <= 0.0:
		var now = Time.get_ticks_msec() / 1000.0
		if now - cold_said > 3.0:
			cold_said = now
			main.toast("CLANG! Too cold to shape. Reheat it in the furnace.")
		return
	var past = power * lift() - min_drop(slot.tier)
	if past <= 0.0:
		var now2 = Time.get_ticks_msec() / 1000.0
		if now2 - weak_said > 3.0:
			weak_said = now2
			main.toast("Clank. %s is too hard: drop the hammer from above the red flag." % SF.material_name(slot.tier))
		return
	shape += past * g["shape_per_meter"]
	if shape < _shape_needed():
		return
	_blade_done()

func slam_fx(power: float) -> void:
	var top = global_position + Vector3(0, size.y * 0.5 + 0.2, 0)
	Fx.burst(main, top, Color(1.0, 0.75, 0.3), int(10 + 30 * power), 0.9 + power, 4.0 + 6.0 * power, -10.0, 0.45, Vector3.UP, 85.0)
	Fx.dust(main, global_position + Vector3(0, -size.y * 0.5 + 0.1, 0), int(6 + 14 * power), 0.8 + power)
	jiggle()
	if head:
		var tw = create_tween()
		tw.tween_property(head, "scale", Vector3(1.15, 0.8, 1.15), 0.05)
		tw.tween_property(head, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	main.shake = maxf(main.shake, 0.1 + 0.35 * power)

# --- Dunk tank ---

func _seat_y() -> float:
	return -size.y * 0.5 + 1.55

## A target on a rail over the tank, a tipping seat over the water, and a water slide
## running out of the front of the tank.
func add_dunk_tank() -> void:
	var gy = -size.y * 0.5
	var wood = Color(0.5, 0.34, 0.2)
	var kit = SF.kit_mesh("dunk", "Tank") != null
	if kit:
		SF.skin(get_node("Visual"), "dunk", "Tank")
	var water = Build.box(Vector3(size.x * 0.92, 0.08, size.z * 0.92), Color(0.35, 0.65, 1.0), 0.6)
	water.position.y = size.y * 0.5 + 0.01
	if SF.skin(water, "dunk", "Water"):
		water.position.y = size.y * 0.5 - 0.08
	add_child(water)
	var ty = gy + SF.DUNK["target_height"]
	var rz = -size.z * 0.5 - 0.15
	for x in [-target_range() - 0.6, target_range() + 0.6]:
		if kit:
			var top = ty + 0.5
			for part in [["PoleFoot", 1.0], ["Pole", top - 0.36 - gy], ["PoleCap", 0.0]]:
				var mi = SF.kit_part("dunk", part[0])
				mi.position = Vector3(x, top if part[0] == "PoleCap" else gy, rz - 0.15)
				if part[0] == "Pole":
					mi.scale.y = part[1]
				add_child(mi)
			continue
		var post = Build.box(Vector3(0.18, ty - gy + 0.3, 0.18), wood)
		post.position = Vector3(x, (gy + ty + 0.3) * 0.5, rz - 0.15)
		add_child(post)
	var rail = Build.box(Vector3(target_range() * 2.0 + 1.4, 0.1, 0.1), Color(0.3, 0.3, 0.32))
	rail.position = Vector3(0, ty + 0.5, rz - 0.15)
	if SF.skin(rail, "dunk", "Rail"):
		rail.scale.x = target_range() * 2.0 + 1.2
	add_child(rail)
	# The sweet spot: the stretch of rail right behind the tank, painted yellow.
	var sweet = Build.box(Vector3(SF.DUNK["sweet_spot"] * 2.0, 0.13, 0.13), Color(1.0, 0.85, 0.2), 0.8)
	sweet.position = rail.position
	if SF.skin(sweet, "dunk", "Sweet"):
		sweet.scale.x = SF.DUNK["sweet_spot"] / 0.4
	add_child(sweet)
	target = Node3D.new()
	add_child(target)
	target.position = Vector3(0, ty, rz)
	if kit:
		target.add_child(SF.kit_part("dunk", "Target"))
	else:
		var rings = [[0.5, Color(0.9, 0.15, 0.12)], [0.36, Color(0.95, 0.95, 0.9)], [0.2, Color(0.9, 0.15, 0.12)]]
		for i in rings.size():
			var disc = Build.cyl(rings[i][0], 0.06, rings[i][1])
			disc.rotation_degrees = Vector3(90, 0, 0)
			disc.position.z = 0.03 * i
			target.add_child(disc)
		var hanger = Build.box(Vector3(0.06, 0.5, 0.06), Color(0.3, 0.3, 0.32))
		hanger.position.y = 0.5
		target.add_child(hanger)
	var k = hit_radius() / SF.DUNK["hit_radius"]
	target.scale = Vector3(k, k, 1.0)
	seat = Node3D.new()
	add_child(seat)
	seat.position = Vector3(0, _seat_y(), -size.z * 0.5 + 0.05)
	if kit:
		seat.add_child(SF.kit_part("dunk", "Seat"))
		var bz = -size.z * 0.5 - 0.18
		var foot = SF.kit_part("dunk", "PoleFoot")
		foot.position = Vector3(0, gy, bz)
		add_child(foot)
		var pole = SF.kit_part("dunk", "Pole")
		pole.position = Vector3(0, gy, bz)
		pole.scale.y = _seat_y() - gy - 0.05
		add_child(pole)
	else:
		var plank = Build.box(Vector3(1.0, 0.08, 0.75), wood.lightened(0.15))
		plank.position.z = 0.37
		seat.add_child(plank)
		var back = Build.box(Vector3(0.12, _seat_y() - gy, 0.12), wood)
		back.position = Vector3(0, gy + (_seat_y() - gy) * 0.5, -size.z * 0.5 + 0.05)
		add_child(back)
	# Water slide: a blue chute from the front of the tank down to the ground.
	var a = Vector3(0, size.y * 0.5 - 0.1, size.z * 0.5)
	var b = Vector3(0, gy + 0.08, size.z * 0.5 + 1.6)
	var chute = Build.box(Vector3(0.6, 0.06, 1.0), Color(0.3, 0.55, 0.95))
	add_child(chute)
	_stretch(chute, to_global(a), to_global(b))
	if SF.skin(chute, "dunk", "Chute"):
		return   # the kit's chute has its own rails
	for side in [-0.32, 0.32]:
		var lip = Build.box(Vector3(0.06, 0.16, 1.0), Color(0.95, 0.85, 0.3))
		add_child(lip)
		_stretch(lip, to_global(a + Vector3(side, 0.08, 0)), to_global(b + Vector3(side, 0.08, 0)))

func seat_point() -> Vector3:
	return seat.to_global(Vector3(0, 0.1, 0.37))

func target_point() -> Vector3:
	return target.global_position

func target_range() -> float:
	return SF.DUNK["range"] + SF.DUNK["range_per_area"] * area

func hit_radius() -> float:
	var d: Dictionary = SF.DUNK
	return maxf(d["min_hit_radius"], d["hit_radius"] - d["hit_radius_per_area"] * area)

## Sweep rate: it slides through the middle at the same speed in every area, so the
## wider the poles, the longer you wait for it to come round again.
func target_speed() -> float:
	return SF.DUNK["slide_speed"] / target_range()

func in_sweet_spot() -> bool:
	return absf(target_x) <= SF.DUNK["sweet_spot"]

## Host: a freshly shaped blade arcs from the anvil onto the seat.
func catch_flying(blade: RigidBody3D, from: Vector3) -> void:
	_seat(blade)
	fly_t = 0.0
	fly_from = from

func _dunk_tick(delta: float) -> void:
	if target == null:
		label.text = "Dunk tank"
		return
	var d: Dictionary = SF.DUNK
	target_x = sin(beat_t * target_speed()) * target_range()
	target.position.x = target_x
	if slot == null:
		label.text = "Dunk tank"
	elif dunk_t >= 0.0:
		label.text = "SPLASH!"
	else:
		label.text = slot.display_name() + "\nhit the target behind the tank!"
	if main.is_client():
		return
	if slot and is_instance_valid(slot):
		if fly_t >= 0.0:
			fly_t += delta
			var k = clampf(fly_t / d["fling_time"], 0.0, 1.0)
			var to = seat_point()
			var at = fly_from.lerp(to, k) + Vector3.UP * (4.0 * k * (1.0 - k) * 3.0)
			slot.global_position = at
			slot.global_rotation = Vector3(fly_t * 14.0, PI * 0.5, 0)
			if k >= 1.0:
				fly_t = -1.0
				Fx.dust(main, to, 6, 0.6)
				jiggle()
		elif dunk_t >= 0.0:
			_dunk_ride(delta)
		else:
			slot.global_position = seat_point()
			slot.global_rotation = Vector3(0, PI * 0.5, 0)
	# A thrown chunk hits the target.
	for it in main.get_tree().get_nodes_in_group("item"):
		if not (it.kind in ["ore", "scrap"]) or not it.is_free() or it.station != null:
			continue
		if it.linear_velocity.length() < d["min_speed"]:
			continue
		if it.global_position.distance_to(target_point()) > hit_radius():
			continue
		var now = Time.get_ticks_msec() / 1000.0
		if now - float(it.get_meta("dunk_hit", -10.0)) < 1.0:
			continue
		it.set_meta("dunk_hit", now)
		var v: Vector3 = it.linear_velocity
		it.linear_velocity = Vector3(-v.x * 0.3, 2.5, -v.z * 0.35)   # bonk, bounce back
		_target_hit()

func _target_hit() -> void:
	var ready = slot != null and is_instance_valid(slot) and dunk_t < 0.0 and fly_t < 0.0
	var dunk = ready and in_sweet_spot()
	ding_fx(dunk)
	main.net_event("dunk", dunk)
	if dunk:
		dunk_t = 0.0
		main.toast("WHAP! It spun over and slapped the sword in!")
	elif ready:
		main.toast("Ding! Hit it when it's right behind the tank.")
	else:
		main.toast("Ding! Nobody's on the seat.")

## Host: the sword drops off the seat into the water, then rides the slide out the front.
const SLAP_DELAY := 0.25   # the target takes this long to spin round and slap the seat

func _dunk_ride(delta: float) -> void:
	dunk_t += delta
	if dunk_t < SLAP_DELAY:
		return
	var t = dunk_t - SLAP_DELAY
	var gy = -size.y * 0.5
	var water = to_global(Vector3(0, size.y * 0.5 - 0.25, 0))
	var top = to_global(Vector3(0, size.y * 0.5 - 0.05, size.z * 0.5))
	var bottom = to_global(Vector3(0, gy + 0.15, size.z * 0.5 + 1.6))
	var at: Vector3
	if t < 0.35:
		var k = t / 0.35
		at = seat_point().lerp(water, k * k)
	elif t < 1.0:
		at = water + Vector3(sin(t * 20.0) * 0.05, 0, 0)
	elif t < 1.7:
		var k = (t - 1.0) / 0.7
		at = water.lerp(top, minf(k * 3.0, 1.0)) if k < 0.33 else top.lerp(bottom, (k - 0.33) / 0.67)
	else:
		_finish_dunk(bottom)
		return
	slot.global_position = at
	slot.global_rotation = Vector3(0, 0, 0)

func _finish_dunk(at: Vector3) -> void:
	var t: int = slot.tier
	main.despawn(slot)
	slot = null
	dunk_t = -1.0
	var w = main.spawn_item("weapon", at + Vector3(0, 0.2, 0), {"tier": t})
	w.spare_handle = main.mod("spare_handle") > 0
	w.apply_central_impulse(global_basis.z * 2.5 * w.mass + Vector3.UP * 1.5 * w.mass)
	Fx.burst(main, at, Color(0.45, 0.7, 1.0, 0.9), 14, 1.0, 3.5, -9.0, 0.5, Vector3(0, 1, 1), 50.0)
	main.toast(SF.material_name(t) + " sword finished! Grab it off the slide.")

## Every screen: the target clangs and spins; on a dunk the seat tips and the tank splashes.
func ding_fx(dunk: bool) -> void:
	if target == null:
		return
	Fx.burst(main, target_point(), Color(1.0, 0.95, 0.5), 12, 0.8, 4.0, 0.0, 0.35, Vector3(0, 0, 1), 80.0)
	var tw = create_tween()
	if not dunk:
		tw.tween_property(target, "rotation:x", -1.2, 0.08)
		tw.tween_property(target, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		return
	# The whole target spins over on its rail and slaps down onto the seat.
	target.rotation.x = 0.0
	tw.tween_property(target, "rotation:x", TAU + 1.3, 0.28).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.25)
	tw.tween_property(target, "rotation:x", TAU, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): target.rotation.x = 0.0)
	var tw2 = create_tween()
	tw2.tween_interval(SLAP_DELAY)
	tw2.tween_property(seat, "rotation:x", deg_to_rad(70.0), 0.12)
	tw2.tween_interval(0.8)
	tw2.tween_property(seat, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var surface = global_position + Vector3(0, size.y * 0.5 + 0.1, 0)
	var tw3 = create_tween()
	tw3.tween_interval(SLAP_DELAY + 0.3)
	tw3.tween_callback(func():
		Fx.burst(main, surface, Color(0.45, 0.7, 1.0, 0.9), 40, 1.6, 6.0, -10.0, 0.8, Vector3.UP, 55.0)
		Fx.burst(main, surface + Vector3(0, 0.3, 0), Color(0.92, 0.92, 0.95, 0.7), 18, 2.2, 1.6, 1.5, 1.2, Vector3.UP, 30.0)
		jiggle()
		main.shake = maxf(main.shake, 0.15))
	tw3.tween_interval(0.75)
	tw3.tween_callback(func():
		var bottom = to_global(Vector3(0, -size.y * 0.5 + 0.2, size.z * 0.5 + 1.0))
		Fx.burst(main, bottom, Color(0.45, 0.7, 1.0, 0.9), 20, 1.0, 3.0, -9.0, 0.7, Vector3(0, 0.6, 1), 40.0))

# --- Lever pump ---

## Lever pump: a lever on each side of the furnace where the bellows would be.
func add_levers() -> void:
	for side in [-1, 1]:
		var base = StaticBody3D.new()
		base.collision_layer = 1
		var box = Build.box(Vector3(0.6, 0.5, 0.6), Color(0.35, 0.33, 0.32))
		box.position.y = 0.25
		base.add_child(box)
		var cs = Build.box_shape(Vector3(0.6, 0.5, 0.6))
		cs.position.y = 0.25
		base.add_child(cs)
		var pipe = Build.box(Vector3(0.9, 0.14, 0.14), Color(0.55, 0.4, 0.25))
		pipe.position = Vector3(-side * 0.6, 0.3, 0)
		base.add_child(pipe)
		var pivot = Node3D.new()
		pivot.position = Vector3(0, 0.5, 0)
		base.add_child(pivot)
		var arm = Build.box(Vector3(0.12, 1.3, 0.12), Color(0.5, 0.34, 0.2))
		arm.position.y = 0.65
		pivot.add_child(arm)
		var knob = Build.box(Vector3(0.24, 0.24, 0.24), Color(0.85, 0.2, 0.15))
		knob.position.y = 1.3
		pivot.add_child(knob)
		add_child(base)
		base.position = Vector3(side * (size.x * 0.5 + 1.0), -size.y * 0.5, 0.4)
		levers.append([pivot, base])
	lever_up = [false, false]
	_lever_pose(0, false)
	_lever_pose(1, false)

## Which lever p can reach, or -1.
func lever_near(p: Node3D) -> int:
	if dead or game != "lever":
		return -1
	var best = -1
	var bd: float = SF.LEVER["reach"]
	for i in levers.size():
		var at: Vector3 = levers[i][1].global_position
		var d = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if d <= bd:
			bd = d
			best = i
	return best

## Host: work lever i. up = pull it up (use), else push it down (grab). Returns what happened.
func lever_stroke(i: int, up: bool) -> String:
	if lever_up[i] == up:
		return "Push it down! (right click / E)" if up else "Pull it up! (left click / F)"
	lever_up[i] = up
	heat = minf(110.0, heat + SF.LEVER["heat"] * (1.3 ** main.mod("hot_coals")) * (0.7 ** main.mod("wet_coal")))
	_lever_pose(i, true)
	main.net_event("lever", [i, up])
	return "Whoosh!"

func _lever_pose(i: int, anim: bool) -> void:
	var side = -1 if i == 0 else 1
	var rot = deg_to_rad(-side * (10.0 if lever_up[i] else 70.0))
	var pivot: Node3D = levers[i][0]
	if anim:
		var tw = create_tween()
		tw.tween_property(pivot, "rotation:z", rot, 0.08)
		var noz = levers[i][1].global_position + Vector3(-side * 1.0, 0.3, 0)
		Fx.burst(main, noz, Color(0.95, 0.95, 0.9, 0.7), 5, 0.9, 3.0, 0.5, 0.3, Vector3(-side, 0.2, 0), 25.0)
		if mouth:
			Fx.burst(main, global_position + Vector3(0, -0.45, 1.15), Color(1.0, 0.55, 0.15), 5, 0.8, 2.5, 3.0, 0.35, Vector3(0, 1, 0.6), 40.0)
	else:
		pivot.rotation.z = rot

## Client: show a lever the host moved.
func lever_set(i: int, up: bool) -> void:
	if i < levers.size() and lever_up[i] != up:
		lever_up[i] = up
		_lever_pose(i, true)

# --- Hammer meter and the two-smith anvil ---

## A bar over the anvil with a marker sweeping across it: swing your hammer when it's in
## the green middle. The two-smith anvil also gets a ring on each side to stand in.
func add_meter() -> void:
	meter = Node3D.new()
	add_child(meter)
	meter.position = Vector3(0, size.y * 0.5 + 1.7, 0)
	var w = 2.4 if game == "duo" else 1.8
	meter.set_meta("w", w)
	var bg = Build.box(Vector3(w + 0.1, 0.26, 0.05), Color(0.1, 0.1, 0.12))
	meter.add_child(bg)
	var good = Build.box(Vector3(w * SF.METER["good"], 0.2, 0.06), Color(1.0, 0.8, 0.2), 0.4)
	meter.add_child(good)
	var perfect = Build.box(Vector3(w * SF.METER["perfect"], 0.22, 0.07), Color(0.3, 1.0, 0.4), 0.6)
	meter.add_child(perfect)
	meter_mark = Build.box(Vector3(0.07, 0.4, 0.09), Color(1, 1, 1), 1.0)
	meter.add_child(meter_mark)
	meter_text = Build.label("", 40)
	meter_text.position = Vector3(0, 0.45, 0)
	meter.add_child(meter_text)
	meter.visible = false
	if game == "duo":
		for side in [-1, 1]:
			var ring = MeshInstance3D.new()
			var tm = TorusMesh.new()
			tm.inner_radius = SF.DUO["spot_radius"] - 0.1
			tm.outer_radius = SF.DUO["spot_radius"]
			ring.mesh = tm
			ring.material_override = Build.mat(Color(0.6, 0.6, 0.6), 0.5)
			add_child(ring)
			ring.position = Vector3(side * SF.DUO["spot_x"], -size.y * 0.5 + 0.05, 0.9)
			spots.append(ring)

## Where the marker is right now: -1 (left end) to 1 (right end). Everyone sees the same.
func meter_pos() -> float:
	var t = slot.tier if slot and is_instance_valid(slot) else 0
	return sin(beat_t * (SF.METER["speed"] + SF.METER["speed_per_tier"] * t))

## 2 Perfect, 1 Good, 0 miss, for a hit right now.
func meter_grade() -> int:
	var m = absf(meter_pos())
	if m <= SF.METER["perfect"]:
		return 2
	if m <= SF.METER["good"]:
		return 1
	return 0

## Two-smith anvil: which spot p stands in (0 left, 1 right), or -1.
func duo_spot(p: Node3D) -> int:
	for i in spots.size():
		var at: Vector3 = spots[i].global_position
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= SF.DUO["spot_radius"] + 0.15:
			return i
	return -1

func _hot_ingot() -> bool:
	return slot != null and is_instance_valid(slot) and slot.kind == "ingot" and slot.hot > 0.0

## Host: p's hammer lands on the anvil. Returns what to tell them.
func hammer_hit(p: Node3D) -> String:
	if slot == null:
		return "Bring a hot ingot first"
	if not _hot_ingot():
		return "Too cold: reheat it in the furnace"
	var g = meter_grade()
	if game == "duo":
		var s = duo_spot(p)
		if s < 0:
			return "Stand in a ring by the big anvil"
		var now = Time.get_ticks_msec() / 1000.0
		duo_hits[s] = now
		duo_grade[s] = g
		meter_fx(g)
		main.net_event("meter", g)
		if g == 0:
			slot.hot = maxf(0.0, slot.hot - SF.METER["miss_cool"])
			return "Miss! Hit it in the middle"
		var o = 1 - s
		if now - duo_hits[o] <= SF.DUO["window"] and duo_grade[o] > 0:
			duo_hits = [-10.0, -10.0]
			var k = 1.5 if g == 2 and duo_grade[o] == 2 else 1.0
			return _shape_by(SF.DUO["shape"] * k, "BOOM! Together!")
		return "Now your partner! Hit together"
	meter_fx(g)
	main.net_event("meter", g)
	if g == 0:
		slot.hot = maxf(0.0, slot.hot - SF.METER["miss_cool"])
		return "Miss! It cooled a little"
	return _shape_by(SF.METER["perfect_shape"] if g == 2 else SF.METER["good_shape"], "PERFECT!" if g == 2 else "Good!")

func _shape_by(amount: float, said: String) -> String:
	shape += amount
	if shape >= _shape_needed():
		_blade_done()
		return said + " Blade shaped!"
	return said

## Every screen: the anvil rings with sparks, bigger for a better hit.
func meter_fx(grade: int) -> void:
	var top = global_position + Vector3(0, size.y * 0.5 + 0.2, 0)
	if grade == 0:
		Fx.dust(main, top, 5, 0.6)
	else:
		Fx.burst(main, top, Color(1.0, 0.75, 0.3), 10 + 12 * grade, 0.9 + 0.3 * grade, 5.0 + 2.0 * grade, -10.0, 0.4, Vector3.UP, 80.0)
	jiggle()
	if meter_text:
		meter_text.text = ["Miss", "Good!", "PERFECT!"][grade]
		meter_text.modulate = [Color(1, 0.4, 0.3), Color(1, 0.85, 0.3), Color(0.4, 1, 0.5)][grade]
		meter_text.set_meta("t", 0.8)

func _meter_tick(delta: float) -> void:
	_follow_slot(Vector3(0, size.y * 0.5 + 0.15, 0))
	var hot = _hot_ingot()
	meter.visible = hot
	var w: float = meter.get_meta("w")
	meter_mark.position.x = meter_pos() * w * 0.5
	var t: float = meter_text.get_meta("t", 0.0)
	if t > 0.0:
		meter_text.set_meta("t", t - delta)
	else:
		meter_text.text = ""
	if game == "duo":
		var now = Time.get_ticks_msec() / 1000.0
		for i in spots.size():
			var c = Color(0.6, 0.6, 0.6)
			for p in main.players:
				if duo_spot(p) == i and p.held and p.held.kind == "tool" and p.held.tool == "hammer":
					c = Color(0.3, 0.9, 1.0)
			if now - duo_hits[i] <= SF.DUO["window"] and duo_grade[i] > 0:
				c = Color(1.0, 0.85, 0.2)   # this side hit: the other side swing NOW
			(spots[i].material_override as StandardMaterial3D).albedo_color = c
			(spots[i].material_override as StandardMaterial3D).emission = c
	if slot == null:
		label.text = "Big anvil: two smiths\nbring a hot ingot" if game == "duo" else "Anvil\nbring a hot ingot"
	elif hot:
		var need = _shape_needed()
		var hint = "both rings: hammers out, hit together in the middle!" if game == "duo" else "hammer out: hit when it's in the middle!"
		label.text = "%s  %d%%\n%s" % [slot.display_name(), int(100.0 * minf(shape / need, 1.0)), hint]
	else:
		label.text = slot.display_name() + "\ntoo cold: reheat in the furnace"

## Shaped: the blade springs off the anvil to wherever this room cools blades.
func _blade_done() -> void:
	var t: int = slot.tier
	var pos = slot.global_position
	main.despawn(slot)
	slot = null
	shape = 0.0
	var blade = main.spawn_item("blank", pos + Vector3(0, 0.4, 0), {"tier": t})
	var tank = main.trough
	if tank and not tank.dead and tank.slot == null:
		tank.catch_flying(blade, pos + Vector3(0, 0.4, 0))
		var where = "the cooling block" if tank.game == "bucket" else "the dunk tank"
		main.toast(SF.material_name(t) + " blade shaped! It flew onto " + where + ".")
	else:
		blade.apply_central_impulse(Vector3(1.0, 4.0, 1.5) * blade.mass)
		main.toast(SF.material_name(t) + " blade shaped! The cooling spot is taken, so it's on the floor.")

# --- Bucket relay ---

## The cooling block: a stone block the hot blade lands on. Splash it with buckets of water.
func add_cool_block() -> void:
	seat = Node3D.new()
	add_child(seat)
	seat.position = Vector3(0, size.y * 0.5, -0.37)
	var steam = Build.box(Vector3(size.x * 0.9, 0.04, size.z * 0.9), Color(0.25, 0.22, 0.2))
	steam.position.y = size.y * 0.5 + 0.02
	add_child(steam)

## The water pool for the bucket relay.
func add_pool() -> void:
	water = Build.box(Vector3(size.x * 0.85, 0.06, size.z * 0.85), Color(0.35, 0.65, 1.0), 0.6)
	water.position.y = size.y * 0.5 + 0.02
	add_child(water)

## Host: splash the blade with a full bucket. Returns what happened.
func splash(b: RigidBody3D) -> String:
	if slot == null or fly_t >= 0.0:
		return "No blade on the block yet"
	b.bucket_full = false
	cool += 1
	splash_fx()
	main.net_event("splash", cool)
	if cool >= SF.BUCKET["splashes"]:
		var at = global_position + Vector3(0, size.y * 0.5 + 0.3, 0.8)
		var t: int = slot.tier
		main.despawn(slot)
		slot = null
		cool = 0
		var w = main.spawn_item("weapon", at, {"tier": t})
		w.spare_handle = main.mod("spare_handle") > 0
		w.apply_central_impulse(Vector3(0, 3.0, 1.5) * w.mass)
		main.toast(SF.material_name(t) + " sword cooled and finished!")
		return "Hiss! Sword done"
	return "Hiss! %d more bucket%s" % [SF.BUCKET["splashes"] - cool, "" if SF.BUCKET["splashes"] - cool == 1 else "s"]

func splash_fx() -> void:
	var top = global_position + Vector3(0, size.y * 0.5 + 0.2, 0)
	Fx.burst(main, top, Color(0.45, 0.7, 1.0, 0.9), 20, 1.2, 4.0, -9.0, 0.5, Vector3.UP, 60.0)
	Fx.burst(main, top + Vector3(0, 0.3, 0), Color(0.92, 0.92, 0.95, 0.7), 16, 2.0, 1.6, 1.5, 1.2, Vector3.UP, 30.0)
	jiggle()

func _cool_tick(delta: float) -> void:
	if slot == null:
		cool = 0
		label.text = "Cooling block\nwaiting for a blade"
	else:
		label.text = "%s  %d/%d\nsplash it with buckets from the pool!" % [slot.display_name(), cool, SF.BUCKET["splashes"]]
	if main.is_client() or slot == null or not is_instance_valid(slot):
		return
	if fly_t >= 0.0:
		fly_t += delta
		var k = clampf(fly_t / SF.DUNK["fling_time"], 0.0, 1.0)
		var to = seat_point()
		slot.global_position = fly_from.lerp(to, k) + Vector3.UP * (4.0 * k * (1.0 - k) * 3.0)
		slot.global_rotation = Vector3(fly_t * 14.0, PI * 0.5, 0)
		if k >= 1.0:
			fly_t = -1.0
			Fx.dust(main, to, 6, 0.6)
			jiggle()
	else:
		slot.global_position = seat_point()
		slot.global_rotation = Vector3(0, PI * 0.5, 0)
