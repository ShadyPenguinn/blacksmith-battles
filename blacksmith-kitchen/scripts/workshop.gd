class_name Workshop
extends Node3D
## The forge: every station, the shop counter, the mentor and the camera shots.
## Minigames borrow pieces of it and put their own props under `props`.

const D := 0.75   # KayKit Dungeon props are built for bigger characters: shrink them to fit ours

# Station spots (ground level). The camera shots below point at these.
const FURNACE := Vector3(-5.5, 0, -4.3)
const ANVIL := Vector3(-1.6, 0, -2.6)          # the hand-hammer anvil
const TRIP := Vector3(2.4, 0, -4.0)            # the anvil under the giant rope hammer
const TANK := Vector3(5.8, 0, -3.9)
const GRIND := Vector3(7.6, 0, -0.6)
const BENCH := Vector3(-7.4, 0, 0.6)
const ROCK := Vector3(-7.6, 0, 3.4)
const CRUSH := Vector3(-6.2, 0, 3.9)      # the crushing stone, beside the rock
const COUNTER_Z := 4.2
const CUSTOMER := Vector3(1.0, 0, 5.1)
const MENTOR_SPOT := Vector3(0.6, 0, 1.4)

var cam: Camera3D
var props: Node3D
var furnace_glow: StandardMaterial3D
var furnace_light: OmniLight3D
var furnace_cap_anim: AnimationPlayer
var spout: Node3D
var bellows := []          # [left, right] holders, each with meta "anim"
var lever_arm: Node3D       # the lever pump's handle pivot
var lever: Node3D
var trip_head: Node3D
var trip_rest_y := 0.0
var trip_ropes := []        # rope pieces from the pulley down to each handle
var trip_handles := []
var trip_flag: MeshInstance3D
var pulley_point := Vector3.ZERO
var tank_water: MeshInstance3D
var grind_wheel: Node3D
var grind_pedals := []
var mentor: Actor
var customer: Actor
var cat: Node3D
var anvil_top := 0.0
var trip_anvil_top := 0.0

var shots := {}
var _cam_tw: Tween
var _shake := 0.0

func _ready() -> void:
	_environment()
	_room()
	_furnace()
	_lever()
	_anvil()
	_trip_hammer()
	_tank()
	_grindstone()
	_bench()
	_rock()
	_counter()
	_decor()
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	mentor = Actor.new()
	add_child(mentor)
	mentor.setup(BK.MENTOR["model"])
	mentor.position = MENTOR_SPOT
	mentor.rotation.y = deg_to_rad(20)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	_shots()
	set_shot("title", 0.0)
	set_cat(Save.has_upgrade("cat"))

func _environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.12, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.78, 0.82)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.65
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	add_child(sun)

func _place(path: String, pos: Vector3, yaw_deg := 0.0, s := D) -> Node3D:
	var m = BK.load_model(BK.M + path)
	if m == null:
		return null
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	m.scale = Vector3.ONE * s
	add_child(m)
	return m

func _room() -> void:
	# Floor: KayKit wood tiles (4 m each, shrunk to 3 m).
	for x in range(-4, 4):
		for z in range(-2, 3):
			_place("dungeon/floor_wood_large.gltf", Vector3(x * 3.0 + 1.5, 0, z * 3.0 + 1.5))
	# Street outside the counter.
	var street = Build.box(Vector3(40, 0.1, 14), Color(0.5, 0.47, 0.42))
	street.position = Vector3(0, -0.06, 14)
	add_child(street)
	# Houses across the street, so the counter view isn't empty.
	for x in range(-4, 4):
		_place("dungeon/wall.gltf", Vector3(x * 3.0 + 1.5, 0, 9.5), 0, 1.0)
	# Back and side walls.
	for x in range(-4, 4):
		_place("dungeon/wall.gltf", Vector3(x * 3.0 + 1.5, 0, -6.3))
	for z in range(-2, 2):
		_place("dungeon/wall.gltf", Vector3(-12.3, 0, z * 3.0 + 1.5), 90)
		_place("dungeon/wall.gltf", Vector3(12.3, 0, z * 3.0 + 1.5), 90)

func _furnace() -> void:
	var m = BK.load_model(BK.M + "stations/furnace_forge.glb")
	m.position = FURNACE
	add_child(m)
	var glow = m.find_child("Glow", true, false)
	if glow is MeshInstance3D:
		furnace_glow = StandardMaterial3D.new()
		furnace_glow.albedo_color = Color(0.07, 0.05, 0.04)
		furnace_glow.emission_enabled = true
		furnace_glow.emission = Color(1.0, 0.5, 0.1)
		furnace_glow.emission_energy_multiplier = 1.0
		glow.material_override = furnace_glow
	spout = m.find_child("Spout", true, false)
	var aps = m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		furnace_cap_anim = aps[0]
	furnace_light = OmniLight3D.new()
	furnace_light.light_color = Color(1.0, 0.55, 0.2)
	furnace_light.light_energy = 1.5
	furnace_light.omni_range = 7.0
	furnace_light.position = FURNACE + Vector3(0, 1.0, 1.6)
	add_child(furnace_light)
	# Two stomp bellows, nozzles poking into the furnace's side ports.
	for side in [-1, 1]:
		var b = Node3D.new()
		b.position = FURNACE + Vector3(side * 2.05, 0, 0)
		add_child(b)
		var squish = Node3D.new()
		squish.name = "Squish"
		b.add_child(squish)
		var model = BK.fitted(BK.M + "stations/bellows_giant.glb", 2.3, Vector3.ZERO, false)
		model.rotation.y = 0.0 if side < 0 else PI
		squish.add_child(model)
		var aps2 = model.find_children("*", "AnimationPlayer", true, false)
		b.set_meta("anim", aps2[0] if not aps2.is_empty() else null)
		bellows.append(b)

## Heat 0..1 sets how bright and what colour the furnace mouth burns.
func set_fire(h: float, too_hot := false) -> void:
	if furnace_glow == null:
		return
	var c = BK.heat_color(0.25 + h * 0.75)
	if too_hot:
		c = Color(1.0, 0.1, 0.05)
	furnace_glow.emission = c
	furnace_glow.emission_energy_multiplier = 0.4 + h * 3.0
	furnace_light.light_color = c
	furnace_light.light_energy = 0.8 + h * 2.5

func stomp(side: int) -> void:
	var b: Node3D = bellows[0 if side < 0 else 1]
	var ap = b.get_meta("anim")
	if ap and ap.has_animation("Stomp"):
		ap.stop()
		ap.play("Stomp")
	var sq = b.get_node("Squish")
	var tw = create_tween()
	tw.tween_property(sq, "scale", Vector3(1.05, 0.85, 1.05), 0.05)
	tw.tween_property(sq, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var noz = FURNACE + Vector3(side * 1.15, 0.35, 0.2)
	Fx.burst(self, noz, Color(0.95, 0.95, 0.9, 0.7), 8, 1.2, 4.0, 0.5, 0.35, Vector3(-side, 0.3, 0.3), 25.0)
	fire_puff()

func fire_puff() -> void:
	Fx.burst(self, FURNACE + Vector3(0, 0.9, 1.2), Color(1.0, 0.55, 0.15), 12, 1.0, 3.0, 3.0, 0.45, Vector3(0, 1, 0.6), 40.0)

func pop_cap() -> void:
	if furnace_cap_anim and furnace_cap_anim.has_animation("Pop"):
		furnace_cap_anim.stop()
		furnace_cap_anim.play("Pop")
	if spout:
		Fx.burst(self, spout.global_position, Color(1.0, 0.6, 0.2), 14, 1.5, 5.0, 3.0, 0.5, Vector3.UP, 35.0)

## A lever pump on the furnace's right: a new prop in the same chunky style.
func _lever() -> void:
	lever = Node3D.new()
	lever.position = FURNACE + Vector3(2.4, 0, 1.2)
	add_child(lever)
	var wood = Color(0.5, 0.33, 0.2)
	var iron = Color(0.25, 0.25, 0.28)
	var base = Build.box(Vector3(0.9, 0.25, 0.9), wood.darkened(0.2))
	base.position.y = 0.125
	lever.add_child(base)
	var post = Build.box(Vector3(0.28, 1.1, 0.28), wood)
	post.position.y = 0.8
	lever.add_child(post)
	var cap = Build.box(Vector3(0.36, 0.14, 0.36), iron)
	cap.position.y = 1.4
	lever.add_child(cap)
	lever_arm = Node3D.new()
	lever_arm.position = Vector3(0, 1.38, 0)
	lever.add_child(lever_arm)
	var arm = Build.box(Vector3(0.14, 0.14, 1.5), wood.lightened(0.1))
	arm.position.z = 0.55
	lever_arm.add_child(arm)
	var grip = Build.cyl(0.1, 0.4, Color(0.75, 0.2, 0.15))
	grip.rotation_degrees.z = 90
	grip.position.z = 1.25
	lever_arm.add_child(grip)
	var pin = Build.cyl(0.08, 0.42, iron)
	pin.rotation_degrees.z = 90
	lever_arm.add_child(pin)
	# Pipe from the pump into the furnace.
	var pipe = Build.box(Vector3(2.1, 0.16, 0.16), iron)
	pipe.position = Vector3(-0.9, 0.35, -0.4)
	lever.add_child(pipe)
	lever.visible = false

func set_lever(angle: float) -> void:
	lever_arm.rotation.x = angle

## Which smelting tool is out: the bellows or the lever pump.
func use_lever(on: bool) -> void:
	lever.visible = on
	bellows[1].visible = not on

func _anvil() -> void:
	var a = BK.load_model(BK.M + "tools/anvil.gltf")
	a.position = ANVIL
	a.scale = Vector3.ONE * 1.2
	add_child(a)
	anvil_top = 0.8 * 1.2
	var stump = Build.cyl(0.55, 0.3, Color(0.42, 0.28, 0.17))
	stump.position = ANVIL + Vector3(0, -0.1, 0)
	add_child(stump)

## The giant rope hammer from Storm Forge, built from its Blender part kit.
func _trip_hammer() -> void:
	var a = BK.load_model(BK.M + "tools/anvil.gltf")
	a.position = TRIP
	a.scale = Vector3.ONE * 1.3
	add_child(a)
	trip_anvil_top = 0.8 * 1.3
	trip_rest_y = trip_anvil_top + 0.75
	var lift_max = BK.ROPES["rope_lift"] * 4.0
	var top = trip_rest_y + lift_max + 0.9
	var px = 0.95
	var pz = -0.6
	for x in [-px, px]:
		var foot = BK.kit_part("trip", "PostFoot")
		var shaft = BK.kit_part("trip", "PostShaft")
		if foot == null:
			var post = Build.box(Vector3(0.25, top, 0.25), Color(0.45, 0.3, 0.18))
			post.position = TRIP + Vector3(x, top * 0.5, pz)
			add_child(post)
			continue
		foot.position = TRIP + Vector3(x, 0, pz)
		shaft.position = TRIP + Vector3(x, 0, pz)
		shaft.scale = Vector3(1, top, 1)
		add_child(foot)
		add_child(shaft)
	var pulley_x = 1.75
	for p in [["Beam", Vector3((pulley_x - px) * 0.5, top, pz)], ["Arm", Vector3(0, top, pz * 0.5)],
			["Bracket", Vector3(pulley_x, top, pz)], ["Pulley", Vector3(pulley_x, top, pz)]]:
		var mi = BK.kit_part("trip", p[0])
		if mi:
			mi.position = TRIP + p[1]
			add_child(mi)
	pulley_point = TRIP + Vector3(pulley_x, top, pz)
	trip_head = Node3D.new()
	trip_head.position = TRIP + Vector3(0, trip_rest_y, 0)
	add_child(trip_head)
	var head = BK.kit_part("trip", "Head")
	if head:
		trip_head.add_child(head)
	else:
		trip_head.add_child(Build.box(Vector3(1.2, 0.7, 0.9), Color(0.22, 0.22, 0.25)))
	var up = BK.kit_part("trip", "RopeY")
	if up == null:
		up = Build.box(Vector3(0.07, 1.0, 0.07), Color(0.78, 0.68, 0.45))
	up.name = "RopeUp"
	add_child(up)
	trip_head.set_meta("rope_up", up)
	# Height marks on the left post, every half meter.
	for i in int(lift_max / 0.5) + 1:
		var tick = Build.box(Vector3(0.32, 0.035, 0.05), Color(0.95, 0.9, 0.75))
		tick.position = TRIP + Vector3(-px, trip_rest_y + i * 0.5, pz + 0.16)
		add_child(tick)
	trip_flag = Build.box(Vector3(0.5, 0.18, 0.05), Color(0.9, 0.12, 0.1), 0.8)
	trip_flag.visible = false
	add_child(trip_flag)
	for i in 4:
		var r = BK.kit_part("trip", "RopeY")
		if r == null:
			r = Build.box(Vector3(0.07, 1.0, 0.07), Color(0.78, 0.68, 0.45))
		add_child(r)
		trip_ropes.append(r)
		var h = BK.kit_part("trip", "Handle")
		if h == null:
			h = Build.box(Vector3(0.45, 0.12, 0.12), Color(0.85, 0.2, 0.15))
		add_child(h)
		trip_handles.append(h)
	set_trip(0.0, [], 0)

func trip_rope_x(i: int) -> Vector3:
	return pulley_point + Vector3(0.0, 0, 0.35 - i * 0.24)

## Head height above rest, how far each rope's handle has been pulled down, how many ropes hang.
func set_trip(h: float, pulled: Array, ropes: int) -> void:
	trip_head.position = TRIP + Vector3(0, trip_rest_y + h, 0)
	var up: Node3D = trip_head.get_meta("rope_up")
	var head_top = trip_head.position.y + 0.45
	up.position = Vector3(TRIP.x, head_top, TRIP.z)
	up.scale = Vector3(1, maxf(0.05, pulley_point.y - head_top), 1)
	for i in 4:
		var on = i < ropes
		trip_ropes[i].visible = on
		trip_handles[i].visible = on
		if not on:
			continue
		var top = trip_rope_x(i)
		var down = top.y - 1.3 + (pulled[i] if i < pulled.size() else 0.0)
		var end = top - Vector3(0, minf(down, top.y - 0.25), 0)
		trip_ropes[i].position = end
		trip_ropes[i].scale = Vector3(1, top.y - end.y, 1)
		trip_handles[i].position = end
		trip_handles[i].rotation_degrees.y = 90

func set_trip_flag(h: float) -> void:
	trip_flag.visible = h >= 0.0
	trip_flag.position = TRIP + Vector3(-0.95 - 0.1, trip_rest_y + h, -0.6 + 0.2)

func _tank() -> void:
	var tank = BK.kit_part("dunk", "Tank")
	if tank:
		tank.position = TANK + Vector3(0, 0.56, 0)
		add_child(tank)
		tank_water = BK.kit_part("dunk", "Water")
		tank_water.position = TANK + Vector3(0, 0.56 + 0.4, 0)
		add_child(tank_water)
	else:
		var t = Build.box(Vector3(1.6, 1.1, 1.3), Color(0.45, 0.3, 0.2))
		t.position = TANK + Vector3(0, 0.55, 0)
		add_child(t)
		tank_water = Build.box(Vector3(1.4, 0.1, 1.1), Color(0.35, 0.65, 1.0), 0.4)
		tank_water.position = TANK + Vector3(0, 1.0, 0)
		add_child(tank_water)
	_place("dungeon/barrel_large.gltf", TANK + Vector3(1.6, 0, 0.3), 0, 0.5)

func water_y() -> float:
	return TANK.y + 1.05

func _grindstone() -> void:
	var g = BK.load_model(BK.M + "tools/grindstone.gltf")
	if g == null:
		return
	g.position = GRIND
	g.rotation_degrees.y = -90
	add_child(g)
	# The model is a frame plus a wheel: put the wheel on a pivot at its own centre so it spins.
	var meshes = g.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		var s = mi.get_aabb().size
		if s.y > 1.2 and s.z < 2.0:
			var c = mi.get_aabb().get_center()
			var pivot = Node3D.new()
			pivot.position = c
			mi.get_parent().add_child(pivot)
			mi.reparent(pivot, false)
			mi.position = -c
			grind_wheel = pivot
	# Two foot pedals (new): you pump these to spin the wheel.
	for side in [-1, 1]:
		var p = Build.box(Vector3(0.32, 0.08, 0.6), Color(0.45, 0.3, 0.18))
		p.position = GRIND + Vector3(0.9, 0.18, side * 0.35)
		add_child(p)
		grind_pedals.append(p)

func _bench() -> void:
	_place("dungeon/table_medium.gltf", BENCH, 0, 1.0)
	_place("dungeon/candle_triple.gltf", BENCH + Vector3(0.7, 1.0, -0.7), 0, 0.5)
	_place("dungeon/stool.gltf", BENCH + Vector3(1.4, 0, 0.6), 0, 1.0)

func bench_top() -> float:
	return 1.0

func _rock() -> void:
	var r = BK.load_model(BK.M + "dungeon/rocks.gltf")
	r.position = ROCK
	r.scale = Vector3.ONE * 0.8
	r.name = "Rock"
	add_child(r)

func rock() -> Node3D:
	return get_node("Rock")

func _counter() -> void:
	for i in 4:
		_place("dungeon/bar_straight_A.gltf", Vector3(-2.0 + i * 2.0 * D, 0, COUNTER_Z), 180)
	_place("dungeon/coin_stack_large.gltf", Vector3(3.0, 0.75, COUNTER_Z), 0, 0.2)
	# A rack of finished weapons behind the counter.
	var rack = Build.box(Vector3(2.6, 0.12, 0.3), Color(0.45, 0.3, 0.18))
	rack.position = Vector3(8.5, 2.2, -6.0)
	add_child(rack)
	var i = 0
	for w in ["sword", "axe", "spear", "dagger", "warhammer"]:
		var m = BK.fitted(BK.WEAPONS[w]["model"], 1.1)
		if m:
			m.position = Vector3(7.5 + i * 0.5, 1.6, -5.9)
			add_child(m)
		i += 1

func _decor() -> void:
	_place("dungeon/shelves_decorated.gltf", Vector3(-1.5, 0, -6.0))
	_place("dungeon/barrel_large.gltf", Vector3(-10.8, 0, -5.0), 0, 0.55)
	_place("dungeon/barrel_large.gltf", Vector3(-9.8, 0, -5.4), 0, 0.5)
	_place("dungeon/keg.gltf", Vector3(10.8, 0, 2.5), 90, 0.5)
	_place("dungeon/crate_large.gltf", Vector3(-10.5, 0, 3.5), 90)
	_place("dungeon/chest.gltf", Vector3(10.5, 0, -3.0), -90)
	_place("dungeon/banner_patternA_red.gltf", Vector3(4.0, 1.2, -5.85), 0, 0.6)
	_place("dungeon/banner_patternA_red.gltf", Vector3(-9.0, 1.2, -5.85), 0, 0.6)
	for p in [Vector3(-3.5, 2.4, -5.8), Vector3(0.5, 2.4, -5.8), Vector3(9.5, 2.4, -5.8)]:
		_place("dungeon/torch_mounted.gltf", p)
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 0.8
		l.omni_range = 5.0
		l.position = p + Vector3(0, 0.5, 0.5)
		add_child(l)
	var fill = OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.7)
	fill.light_energy = 0.7
	fill.omni_range = 9.0
	fill.position = Vector3(1.0, 3.5, 3.0)
	add_child(fill)

func set_cat(on: bool) -> void:
	if cat:
		cat.visible = on
		return
	if not on:
		return
	# A sleeping cat: a few soft boxes. Purely moral support.
	cat = Node3D.new()
	cat.position = FURNACE + Vector3(-1.2, 0, 1.9)
	add_child(cat)
	var fur = Color(0.95, 0.6, 0.25)
	var body = Build.box(Vector3(0.5, 0.22, 0.3), fur)
	body.position.y = 0.11
	cat.add_child(body)
	var head = Build.box(Vector3(0.22, 0.2, 0.22), fur)
	head.position = Vector3(0.3, 0.12, 0.05)
	cat.add_child(head)
	for ex in [-0.07, 0.07]:
		var ear = Build.box(Vector3(0.06, 0.08, 0.06), fur.darkened(0.2))
		ear.position = Vector3(0.32, 0.25, 0.05 + ex)
		cat.add_child(ear)
	var tail = Build.box(Vector3(0.3, 0.07, 0.07), fur.darkened(0.1))
	tail.position = Vector3(-0.3, 0.05, 0.15)
	tail.rotation_degrees.y = 40
	cat.add_child(tail)

# --- Camera ---------------------------------------------------------------------
func _shots() -> void:
	shots = {
		"title": [Vector3(0.5, 6.5, 11.5), Vector3(0, 1.2, -2.5), 50.0],
		"overview": [Vector3(0, 9.0, 9.0), Vector3(0, 0.5, -1.5), 50.0],
		"counter": [Vector3(1.0, 1.75, 1.8), Vector3(1.0, 1.15, 5.1), 50.0],
		"furnace": [FURNACE + Vector3(0.6, 2.3, 6.2), FURNACE + Vector3(0.6, 1.1, 0), 50.0],
		"floor": [Vector3(-3.3, 8.0, 1.2), Vector3(-3.3, 0, -1.8), 50.0],
		"anvil": [ANVIL + Vector3(0, 2.7, 2.9), ANVIL + Vector3(0, 0.95, 0), 45.0],
		"rope": [TRIP + Vector3(1.3, 2.7, 6.8), TRIP + Vector3(0.6, 2.3, 0), 50.0],
		"quench": [TANK + Vector3(0, 2.4, 2.6), TANK + Vector3(0, 1.1, 0), 50.0],
		"grind": [GRIND + Vector3(3.0, 2.1, 0.3), GRIND + Vector3(0, 1.0, 0), 50.0],
		"bench": [BENCH + Vector3(0, 3.1, 1.2), BENCH + Vector3(0, 1.0, 0.05), 45.0],
		"mine": [ROCK + Vector3(0, 1.8, 3.0), ROCK + Vector3(0, 0.6, 0), 48.0],
		"crush": [CRUSH + Vector3(0.4, 2.3, 1.9), CRUSH + Vector3(0.4, 0.2, 0), 48.0],
	}

func set_shot(name: String, time := 0.8) -> void:
	var s = shots.get(name, shots["overview"])
	var target_xf = Transform3D(Basis(), s[0]).looking_at(s[1], Vector3.UP)
	if _cam_tw:
		_cam_tw.kill()
	if time <= 0.0:
		cam.global_transform = target_xf
		cam.fov = s[2]
		return
	_cam_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tw.tween_property(cam, "global_transform", target_xf, time)
	_cam_tw.tween_property(cam, "fov", s[2], time)

func shake(amount := 0.15) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 0.6)
		cam.h_offset = randf_range(-_shake, _shake) * 0.5
		cam.v_offset = randf_range(-_shake, _shake) * 0.5
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

## Where a screen point hits a horizontal plane at height y.
func pointer_on_plane(screen: Vector2, y: float) -> Variant:
	var o = cam.project_ray_origin(screen)
	var d = cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t = (y - o.y) / d.y
	if t < 0.0:
		return null
	return o + d * t

func to_screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p)

func clear_props() -> void:
	for c in props.get_children():
		c.queue_free()

# --- Customers --------------------------------------------------------------------
func new_customer(path: String) -> Actor:
	if customer and is_instance_valid(customer):
		customer.queue_free()
	customer = Actor.new()
	add_child(customer)
	customer.setup(path)
	customer.position = CUSTOMER + Vector3(-7.0, 0, 1.2)
	return customer

func customer_arrive(done := Callable()) -> void:
	customer.walk_to(CUSTOMER, 2.6, func():
		customer.face(CUSTOMER + Vector3(0, 0, -5))
		if done.is_valid():
			done.call())

func customer_leave() -> void:
	if customer and is_instance_valid(customer):
		var c = customer
		c.walk_to(CUSTOMER + Vector3(8.0, 0, 1.2), 2.8, func(): c.queue_free())
		customer = null
