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
# Anvil: rope drop hammer
var shape = 0.0          # slam power so far on the ingot
var ham_h = 0.0          # how high the head is (meters above resting)
var ham_v = 0.0          # falling speed
var head: Node3D
var rope_up: MeshInstance3D
var ropes = []           # one rope line per smith, from the pulley to their hands
var handle: MeshInstance3D
var cold_said = 0.0
# Dunk tank
var seat: Node3D         # hinge of the seat over the water
var target: Node3D
var target_x = 0.0
var dunk_t = -1.0        # >= 0 while a sword is dropping in and riding the slide
var fly_t = -1.0         # >= 0 while a sword is flying in from the anvil
var fly_from = Vector3.ZERO
var dead = false         # a station left behind in an earlier area: just scenery now

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
			_trip_tick(delta)
		"trough":
			_dunk_tick(delta)
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
		fire_mat.emission_enabled = false
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
			var ingot = main.spawn_item("ingot", global_position + Vector3(1.4, 1.0, 0.6), {"tier": target})
			ingot.apply_central_impulse(Vector3(1.5, 2.0, 0.5) * ingot.mass)
			main.toast(SF.material_name(target) + " ingot ready! Grab it with tongs.")

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

## Furnace: two big accordion bellows, one each side, that smiths jump on.
func add_bellows() -> void:
	var sz: Vector3 = SF.BELLOWS["size"]
	for side in [-1, 1]:
		var b = StaticBody3D.new()
		b.collision_layer = 1
		var cs = Build.box_shape(sz)
		cs.position.y = sz.y * 0.5
		b.add_child(cs)
		var squish = Node3D.new()
		squish.name = "Squish"
		b.add_child(squish)
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
		b.position = Vector3(side * (size.x * 0.5 + sz.x * 0.5 + 0.35), -size.y * 0.5, 0)
		bellows.append(b)

## Someone landed on a bellows. power ~1 for a normal jump, more for a belly flop.
## Host side. Alternating sides pumps best; stomping too fast makes the furnace burp.
func stomp(side: int, power: float) -> void:
	if dead:
		return
	var g: Dictionary = SF.BELLOWS
	var now = Time.get_ticks_msec() / 1000.0
	var gain = g["heat"] * power
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
func squish(side: int) -> void:
	var b = bellows[0] if side < 0 else bellows[1]
	var sq = b.get_node("Squish")
	var tw = create_tween()
	tw.tween_property(sq, "scale", Vector3(1.12, 0.45, 1.12), 0.06)
	tw.tween_property(sq, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var noz = b.global_position + Vector3(-side * (SF.BELLOWS["size"].x * 0.5 + 0.4), 0.25, 0)
	Fx.burst(main, noz, Color(0.95, 0.95, 0.9, 0.7), 8, 1.2, 4.0, 0.5, 0.35, Vector3(-side, 0.2, 0), 25.0)
	if mouth:
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

func _top_y() -> float:
	return -size.y * 0.5 + 3.9

func _head_rest_y() -> float:
	return size.y * 0.5 + 0.62

## A tall frame over the anvil with a giant hammer head on a rope. The rope runs over a
## pulley to a handle at the side: grab it and walk away to haul the head up.
func add_trip_hammer() -> void:
	var gy = -size.y * 0.5
	var wood = Color(0.45, 0.3, 0.18)
	for x in [-POST_X, POST_X]:
		var post = Build.box(Vector3(0.25, 3.9, 0.25), wood)
		post.position = Vector3(x, gy + 1.95, POST_Z)
		add_child(post)
		var cs = Build.box_shape(Vector3(0.25, 3.9, 0.25))
		cs.position = post.position
		add_child(cs)
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
	_trip_visuals()

## Where the rope comes down from the pulley, at ground level: pull away from here.
func rope_anchor() -> Vector3:
	return to_global(Vector3(PULLEY_X, -size.y * 0.5, POST_Z))

func handle_rest() -> Vector3:
	return to_global(Vector3(PULLEY_X, -size.y * 0.5 + 1.0, POST_Z))

func near_handle(p: Node3D) -> bool:
	if dead or head == null:
		return false
	var d = p.global_position - handle_rest()
	return Vector2(d.x, d.z).length() <= SF.TRIP["grab_reach"]

func pullers() -> Array:
	return main.players.filter(func(p): return p.rope == self)

## Host: the head rises toward where the ropes hold it, and drops when they let go.
func _trip_tick(delta: float) -> void:
	if not main.is_client() and head:
		var g: Dictionary = SF.TRIP
		var pull = 0.0
		for p in pullers():
			pull += p.rope_pull()
		var want = g["lift"] * minf(1.0, pull * g["solo"])
		if want > ham_h + 0.005:
			ham_h = move_toward(ham_h, want, g["raise_speed"] * delta)
			ham_v = 0.0
		elif ham_h > want:
			ham_v += g["gravity"] * delta
			ham_h -= ham_v * delta
			if ham_h <= want:
				if want <= 0.001:
					var power = ham_v * ham_v / (2.0 * g["gravity"] * g["lift"])
					ham_h = 0.0
					ham_v = 0.0
					if power >= g["min_power"]:
						slam(minf(power, 1.0))
				else:
					ham_h = want   # the rope catches it
					ham_v = 0.0
		_follow_slot(Vector3(0, size.y * 0.5 + 0.15, 0))
	if head:
		_trip_visuals()
	if slot == null:
		label.text = "Anvil\nbring a hot ingot"
	elif slot.kind == "ingot" and slot.hot > 0.0:
		var need = _shape_needed()
		label.text = "%s  %d%%\npull the rope back!" % [slot.display_name(), int(100.0 * minf(shape / need, 1.0))]
	else:
		label.text = slot.display_name() + "\ntoo cold: reheat in the furnace"

func _shape_needed() -> float:
	return SF.TRIP["shape_needed"] * (1.5 ** main.mod("tiny_anvil"))

## Head, the rope above it, the handle, and a rope from the pulley to each puller's hands.
func _trip_visuals() -> void:
	head.position.y = _head_rest_y() + ham_h
	var head_top = head.position.y + 0.35
	rope_up.position = Vector3(0, (head_top + _top_y()) * 0.5, 0)
	rope_up.scale.y = maxf(_top_y() - head_top, 0.05)
	var pulley = to_global(Vector3(PULLEY_X, _top_y(), POST_Z))
	var pulling = pullers()
	for i in ropes.size():
		var r: MeshInstance3D = ropes[i]
		var p = main.players[i] if i < main.players.size() else null
		if p == null or p.rope != self:
			r.visible = false
			continue
		r.visible = true
		_stretch(r, pulley, p.hand_position())
	if pulling.is_empty():
		handle.visible = true
		handle.global_position = handle_rest()
		ropes[0].visible = true
		_stretch(ropes[0], pulley, handle_rest())
	else:
		handle.visible = false

func _stretch(r: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mid = (a + b) * 0.5
	var d = b - a
	var len = maxf(d.length(), 0.05)
	var up = Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis = Basis.looking_at(d, up)
	basis.z *= len
	r.global_transform = Transform3D(basis, mid)

## Host: the head hit the anvil. power 0..1 (1 = dropped from the very top).
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
	shape += power
	if shape < _shape_needed():
		return
	# Shaped: the blade springs off the anvil and flies onto the dunk tank seat.
	var t: int = slot.tier
	var pos = slot.global_position
	main.despawn(slot)
	slot = null
	shape = 0.0
	var blade = main.spawn_item("blank", pos + Vector3(0, 0.4, 0), {"tier": t})
	var tank = main.trough
	if tank and not tank.dead and tank.slot == null:
		tank.catch_flying(blade, pos + Vector3(0, 0.4, 0))
		main.toast(SF.material_name(t) + " blade shaped! It flew onto the dunk tank.")
	else:
		blade.apply_central_impulse(Vector3(1.0, 4.0, 1.5) * blade.mass)
		main.toast(SF.material_name(t) + " blade shaped! The dunk seat is taken, so it's on the floor.")

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
	var water = Build.box(Vector3(size.x * 0.92, 0.08, size.z * 0.92), Color(0.35, 0.65, 1.0), 0.6)
	water.position.y = size.y * 0.5 + 0.01
	add_child(water)
	var ty = gy + SF.DUNK["target_height"]
	var rz = -size.z * 0.5 - 0.15
	for x in [-SF.DUNK["range"] - 0.6, SF.DUNK["range"] + 0.6]:
		var post = Build.box(Vector3(0.18, ty - gy + 0.3, 0.18), wood)
		post.position = Vector3(x, (gy + ty + 0.3) * 0.5, rz - 0.15)
		add_child(post)
	var rail = Build.box(Vector3(SF.DUNK["range"] * 2.0 + 1.4, 0.1, 0.1), Color(0.3, 0.3, 0.32))
	rail.position = Vector3(0, ty + 0.5, rz - 0.15)
	add_child(rail)
	target = Node3D.new()
	add_child(target)
	target.position = Vector3(0, ty, rz)
	var rings = [[0.5, Color(0.9, 0.15, 0.12)], [0.36, Color(0.95, 0.95, 0.9)], [0.2, Color(0.9, 0.15, 0.12)]]
	for i in rings.size():
		var disc = Build.cyl(rings[i][0], 0.06, rings[i][1])
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position.z = 0.03 * i
		target.add_child(disc)
	var hanger = Build.box(Vector3(0.06, 0.5, 0.06), Color(0.3, 0.3, 0.32))
	hanger.position.y = 0.5
	target.add_child(hanger)
	seat = Node3D.new()
	add_child(seat)
	seat.position = Vector3(0, _seat_y(), -size.z * 0.5 + 0.05)
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
	for side in [-0.32, 0.32]:
		var lip = Build.box(Vector3(0.06, 0.16, 1.0), Color(0.95, 0.85, 0.3))
		add_child(lip)
		_stretch(lip, to_global(a + Vector3(side, 0.08, 0)), to_global(b + Vector3(side, 0.08, 0)))

func seat_point() -> Vector3:
	return seat.to_global(Vector3(0, 0.1, 0.37))

func target_point() -> Vector3:
	return target.global_position

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
	var spd = d["speed"] * (1.0 + d["speed_per_area"] * main.door_index)
	target_x = sin(beat_t * spd) * d["range"]
	target.position.x = target_x
	if slot == null:
		label.text = "Dunk tank"
	elif dunk_t >= 0.0:
		label.text = "SPLASH!"
	else:
		label.text = slot.display_name() + "\nthrow ore at the target!"
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
		if it.global_position.distance_to(target_point()) > d["hit_radius"]:
			continue
		var now = Time.get_ticks_msec() / 1000.0
		if now - float(it.get_meta("dunk_hit", -10.0)) < 1.0:
			continue
		it.set_meta("dunk_hit", now)
		var v: Vector3 = it.linear_velocity
		it.linear_velocity = Vector3(-v.x * 0.3, 2.5, -v.z * 0.35)   # bonk, bounce back
		_target_hit()

func _target_hit() -> void:
	var dunk = slot != null and is_instance_valid(slot) and dunk_t < 0.0 and fly_t < 0.0
	ding_fx(dunk)
	main.net_event("dunk", dunk)
	if dunk:
		dunk_t = 0.0
		main.toast("DING! Down it goes!")
	else:
		main.toast("Ding! Nobody's on the seat.")

## Host: the sword drops off the seat into the water, then rides the slide out the front.
func _dunk_ride(delta: float) -> void:
	dunk_t += delta
	var gy = -size.y * 0.5
	var water = to_global(Vector3(0, size.y * 0.5 - 0.25, 0))
	var top = to_global(Vector3(0, size.y * 0.5 - 0.05, size.z * 0.5))
	var bottom = to_global(Vector3(0, gy + 0.15, size.z * 0.5 + 1.6))
	var at: Vector3
	if dunk_t < 0.35:
		var k = dunk_t / 0.35
		at = seat_point().lerp(water, k * k)
	elif dunk_t < 1.0:
		at = water + Vector3(sin(dunk_t * 20.0) * 0.05, 0, 0)
	elif dunk_t < 1.7:
		var k = (dunk_t - 1.0) / 0.7
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
	tw.tween_property(target, "rotation:x", -1.2, 0.08)
	tw.tween_property(target, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if not dunk:
		return
	var tw2 = create_tween()
	tw2.tween_property(seat, "rotation:x", deg_to_rad(70.0), 0.12)
	tw2.tween_interval(0.8)
	tw2.tween_property(seat, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var surface = global_position + Vector3(0, size.y * 0.5 + 0.1, 0)
	var tw3 = create_tween()
	tw3.tween_interval(0.3)
	tw3.tween_callback(func():
		Fx.burst(main, surface, Color(0.45, 0.7, 1.0, 0.9), 40, 1.6, 6.0, -10.0, 0.8, Vector3.UP, 55.0)
		Fx.burst(main, surface + Vector3(0, 0.3, 0), Color(0.92, 0.92, 0.95, 0.7), 18, 2.2, 1.6, 1.5, 1.2, Vector3.UP, 30.0)
		jiggle()
		main.shake = maxf(main.shake, 0.15))
	tw3.tween_interval(0.75)
	tw3.tween_callback(func():
		var bottom = to_global(Vector3(0, -size.y * 0.5 + 0.2, size.z * 0.5 + 1.0))
		Fx.burst(main, bottom, Color(0.45, 0.7, 1.0, 0.9), 20, 1.0, 3.0, -9.0, 0.7, Vector3(0, 0.6, 1), 40.0))
