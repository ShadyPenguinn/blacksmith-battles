extends Node3D
## Storm Forge graybox: builds the area, runs the door loop, routes player actions.

const ItemScript := preload("res://scripts/item.gd")
const StationScript := preload("res://scripts/station.gd")
const PlayerScript := preload("res://scripts/player.gd")
const LightningScript := preload("res://scripts/lightning.gd")
const HudScript := preload("res://scripts/hud.gd")

const PLAYER_COUNT := 4  # offline graybox: four smiths, you control one at a time
const NODE_SLOTS := [Vector2(-8, 6), Vector2(8, 6), Vector2(-4.5, 8.5), Vector2(4.5, 8.5),
	Vector2(0, 9.5), Vector2(-9, 2.5), Vector2(9, 2.5), Vector2(-1.5, 6), Vector2(1.5, 6)]

var door_index = 0
var area_time = SF.AREA_TIME
var time_left = SF.AREA_TIME
var peak_time = 0.0
var over = false
var paused_for_roll = false
var mods = {}
var players: Array = []
var controlled = 0
var toasts: Array[String] = []

var lightning: Node3D
var door: StaticBody3D
var furnace: StaticBody3D
var anvil: StaticBody3D
var grindstone: StaticBody3D
var trough: StaticBody3D
var rod: StaticBody3D = null
var items_root: Node3D
var nodes_root: Node3D
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var hud: CanvasLayer
var shake = 0.0
var flash_t = 0.0

func _ready() -> void:
	randomize()
	_setup_input()
	_build_world()
	start_run()

# ---------------------------------------------------------------- setup

func _setup_input() -> void:
	var keys = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT], "dive": [KEY_SPACE], "interact": [KEY_E],
		"use": [KEY_F, KEY_J], "throw": [KEY_Q], "restart": [KEY_R],
		"smith_1": [KEY_1], "smith_2": [KEY_2], "smith_3": [KEY_3], "smith_4": [KEY_4],
		"debug_strike": [KEY_L], "debug_skip": [KEY_N],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mb = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("use", mb)
	var mb2 = InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("interact", mb2)

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.8
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 55
	add_child(cam)

	# Ground and boundary.
	var ground = StaticBody3D.new()
	ground.collision_layer = 1
	ground.add_child(Build.box_shape(Vector3(26, 1, 30)))
	ground.add_child(Build.box(Vector3(26, 1, 30), Color(0.35, 0.4, 0.3)))
	add_child(ground)
	ground.position = Vector3(0, -0.5, -1)
	_wall(Vector3(-13.5, 2, -1), Vector3(1, 4, 30), true)
	_wall(Vector3(13.5, 2, -1), Vector3(1, 4, 30), true)
	_wall(Vector3(0, 2, 14.5), Vector3(28, 4, 1), false)
	_wall(Vector3(-9.5, 4, -12.5), Vector3(7, 8, 2), true)
	_wall(Vector3(9.5, 4, -12.5), Vector3(7, 8, 2), true)

	items_root = Node3D.new()
	add_child(items_root)
	nodes_root = Node3D.new()
	add_child(nodes_root)

	door = _station("door", Vector3(0, 3.5, -12.5), Vector3(12, 7, 1), Color(0.35, 0.22, 0.12))
	furnace = _station("furnace", Vector3(-6, 1.1, -3), Vector3(2.2, 2.2, 2.2), Color(0.45, 0.2, 0.15))
	anvil = _station("anvil", Vector3(-2, 0.45, -3), Vector3(1.3, 0.9, 0.7), Color(0.3, 0.3, 0.34))
	grindstone = _station("grindstone", Vector3(2.5, 0.5, -3), Vector3(1.1, 1.0, 1.1), Color(0.7, 0.62, 0.45))
	trough = _station("trough", Vector3(6.5, 0.35, -3), Vector3(1.8, 0.7, 0.9), Color(0.25, 0.45, 0.75))
	var fire = Build.box(Vector3(1.2, 0.5, 0.1), Color(1.0, 0.45, 0.1), 3.0)
	fire.position = Vector3(0, -0.5, 1.12)
	furnace.add_child(fire)

	lightning = Node3D.new()
	lightning.set_script(LightningScript)
	add_child(lightning)
	lightning.setup(self)

	_rain()

	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	hud.setup(self)

func _wall(pos: Vector3, size: Vector3, visible_wall: bool) -> void:
	var w = StaticBody3D.new()
	w.collision_layer = 1
	w.add_child(Build.box_shape(size))
	if visible_wall:
		w.add_child(Build.box(size, Color(0.4, 0.38, 0.36)))
	add_child(w)
	w.position = pos

func _station(kind: String, pos: Vector3, size: Vector3, color: Color, opts: Dictionary = {}) -> StaticBody3D:
	var s = StaticBody3D.new()
	s.set_script(StationScript)
	s.setup(self, kind, size, color, opts)
	(nodes_root if kind == "node" else self).add_child(s)
	s.global_position = pos
	return s

func _rain() -> void:
	var rain = GPUParticles3D.new()
	rain.amount = 1500
	rain.lifetime = 1.0
	rain.visibility_aabb = AABB(Vector3(-16, -20, -18), Vector3(32, 24, 36))
	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 0.5, 16)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -10, 0)
	rain.process_material = pm
	var drop = BoxMesh.new()
	drop.size = Vector3(0.02, 0.5, 0.02)
	var dm = StandardMaterial3D.new()
	dm.albedo_color = Color(0.7, 0.8, 1.0, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	rain.draw_pass_1 = drop
	add_child(rain)
	rain.position = Vector3(0, 16, -1)

# ---------------------------------------------------------------- run flow

func start_run() -> void:
	over = false
	paused_for_roll = false
	door_index = 0
	mods = {}
	if rod:
		rod.queue_free()
		rod = null
	for it in get_tree().get_nodes_in_group("item"):
		despawn(it)
	if players.is_empty():
		for i in PLAYER_COUNT:
			var p = CharacterBody3D.new()
			p.set_script(PlayerScript)
			p.setup(self, i)
			add_child(p)
			players.append(p)
	for i in players.size():
		var p = players[i]
		p.held = null
		p.stun = 0.0
		p.set_big_head(1.0)
		p.global_position = Vector3(-3.0 + 2.0 * i, 0.1, 2.0)
		p.velocity = Vector3.ZERO
		var t = spawn_item("tool", p.global_position + Vector3.UP, {"tool": SF.ROLES[i]["tool"]})
		t.owner_idx = i
		p.pick_up(t)
	furnace.contents.clear()
	furnace.heat = 0.0
	set_controlled(0)
	hud.hide_big()
	start_area()

func start_area() -> void:
	var cfg: Dictionary = SF.DOORS[door_index]
	door.max_hp = cfg["hp"] * player_scale("door")
	door.hp = door.max_hp
	door.tier = cfg["tier"]
	area_time = maxf(60.0, SF.AREA_TIME + 30.0 * (mod("long_fuse") - mod("short_fuse")))
	time_left = area_time
	peak_time = 0.0
	for n in get_tree().get_nodes_in_group("node"):
		n.remove_from_group("node")
		n.remove_from_group("station")
		n.queue_free()
	var slot = 0
	for ore in cfg["nodes"]:
		for k in cfg["nodes"][ore]:
			if slot >= NODE_SLOTS.size():
				break
			var s: Vector2 = NODE_SLOTS[slot]
			_station("node", Vector3(s.x, 0.6, s.y), Vector3(1.4, 1.2, 1.4), SF.ORE_COLORS[ore], {"ore": ore})
			slot += 1
	if mod("rod") > 0 and rod == null:
		rod = _station("rod", Vector3(0, 2, 4.5), Vector3(0.25, 4, 0.25), Color(0.75, 0.75, 0.8))
	lightning.reset_area()
	env.background_color = cfg["sky"]
	toast("Door %d: %s. Break it before the storm peaks!" % [door_index + 1, cfg["area"]])

func door_broken() -> void:
	if paused_for_roll or over:
		return
	door_index += 1
	if door_index >= SF.DOORS.size():
		door_index = SF.DOORS.size() - 1
		over = true
		hud.show_big("You broke the Storm Gate!", "All 8 doors down. Press R to play again.")
		return
	paused_for_roll = true
	var buff: Dictionary = SF.BUFFS.pick_random()
	var debuff: Dictionary = SF.DEBUFFS.pick_random()
	hud.show_roll(buff, debuff)
	get_tree().create_timer(3.0).timeout.connect(_finish_roll.bind(buff, debuff))

func _finish_roll(buff: Dictionary, debuff: Dictionary) -> void:
	mods[buff["id"]] = mod(buff["id"]) + 1
	mods[debuff["id"]] = mod(debuff["id"]) + 1
	if debuff["id"] == "role_swap":
		_role_swap()
	if debuff["id"] == "big_heads":
		for p in players:
			p.set_big_head(1.0 + 1.0 * mod("big_heads"))
	paused_for_roll = false
	hud.hide_big()
	start_area()

func _role_swap() -> void:
	var tools = []
	for p in players:
		tools.append(p.held if p.held and p.held.kind == "tool" else null)
	for i in players.size():
		var incoming = tools[(i - 1 + players.size()) % players.size()]
		var p = players[i]
		if p.held and p.held.kind == "tool":
			p.held = null
		if incoming:
			incoming.holder = null
			p.pick_up(incoming)

func game_over() -> void:
	over = true
	hud.show_big("The storm took the forge", "Doors broken: %d. Press R to try again." % door_index)

func mod(id: String) -> int:
	return mods.get(id, 0)

## Scales door HP and lightning for smaller groups. Offline graybox always has 4.
func player_scale(what: String) -> float:
	var n = PLAYER_COUNT
	if what == "door":
		return {1: 0.45, 2: 0.6, 3: 0.8, 4: 1.0}.get(n, 1.0)
	return {1: 0.6, 2: 0.7, 3: 0.85, 4: 1.0}.get(n, 1.0)

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart") and over:
		start_run()
	if not over and not paused_for_roll:
		if time_left > 0.0:
			time_left -= delta
		else:
			peak_time += delta
			if peak_time >= SF.PEAK_GRACE:
				game_over()
		_handle_input()
	_update_camera(delta)
	flash_t = maxf(0.0, flash_t - delta)
	env.ambient_light_energy = 0.6 + flash_t * 16.0
	sun.light_energy = (0.8 - 0.5 * _storm_progress()) + flash_t * 10.0
	var sky: Color = SF.DOORS[door_index]["sky"]
	env.background_color = sky.lerp(Color(0.08, 0.08, 0.12), _storm_progress()).lerp(Color(0.9, 0.92, 1.0), clampf(flash_t * 3.0, 0.0, 1.0))
	hud.refresh()

func _storm_progress() -> float:
	return clampf(1.0 - time_left / area_time, 0.0, 1.0)

func _handle_input() -> void:
	for i in 4:
		if Input.is_action_just_pressed("smith_%d" % (i + 1)):
			set_controlled(i)
	var p = players[controlled]
	if p.stun > 0.0:
		return
	if Input.is_action_just_pressed("interact"):
		interact(p)
	if Input.is_action_just_pressed("use"):
		use(p)
	if Input.is_action_just_pressed("throw") and p.held:
		p.drop(p.facing * 7.0 + Vector3.UP * 3.5)
	if Input.is_action_just_pressed("debug_strike"):
		lightning.begin_warning(p)
	if Input.is_action_just_pressed("debug_skip"):
		door_broken()

func set_controlled(i: int) -> void:
	controlled = i
	for j in players.size():
		players[j].controlled = (j == i)

func _update_camera(delta: float) -> void:
	if players.is_empty():
		return
	var p = players[controlled]
	var focus: Vector3 = p.global_position.lerp(Vector3(0, 0, -2), 0.35)
	var want = focus + Vector3(0, 13, 11)
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0)) if cam.global_position != Vector3.ZERO else want
	shake = maxf(0.0, shake - delta)
	cam.look_at(focus + Vector3(0, 0.5, -1), Vector3.UP)
	if shake > 0.0:
		cam.rotation += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.04

func flash() -> void:
	flash_t = 0.25
	shake = 0.4

func toast(msg: String) -> void:
	toasts.append(msg)
	if toasts.size() > 60:
		toasts.pop_front()
	if hud:
		hud.toast(msg)

# ---------------------------------------------------------------- items

func spawn_item(kind: String, pos: Vector3, opts: Dictionary = {}) -> RigidBody3D:
	var it = RigidBody3D.new()
	it.set_script(ItemScript)
	it.setup(kind, opts)
	items_root.add_child(it)
	it.global_position = pos
	return it

func despawn(it: RigidBody3D) -> void:
	if not is_instance_valid(it):
		return
	if it.holder and it.holder.held == it:
		it.holder.held = null
	if it.gripped_by and it.gripped_by.tongs_load == it:
		it.gripped_by.tongs_load = null
	if it.tongs_load:
		it.tongs_load.release()
		it.tongs_load = null
	if it.station:
		it.station.clear_slot(it)
	it.remove_from_group("item")
	it.queue_free()

func check_weapon(w: RigidBody3D, p) -> void:
	if w.durability > 0.0:
		return
	if w.spare_handle:
		w.spare_handle = false
		w.durability = SF.WEAPON_DURABILITY * 0.5
		toast("Spare handle saved it!")
		return
	var t: int = w.tier
	despawn(w)
	var scrap = spawn_item("scrap", p.hand_position(), {"tier": t})
	p.pick_up(scrap)
	toast("The sword broke. Take the scrap to the furnace.")

# ---------------------------------------------------------------- actions

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func station_dist(p: Node3D, st: Node3D) -> float:
	var local: Vector3 = p.global_position - st.global_position
	var dx = maxf(absf(local.x) - st.size.x * 0.5, 0.0)
	var dz = maxf(absf(local.z) - st.size.z * 0.5, 0.0)
	return Vector2(dx, dz).length()

func nearest_station(p: Node3D, kinds: Array) -> Node3D:
	var best: Node3D = null
	var bd = SF.REACH
	for st in get_tree().get_nodes_in_group("station"):
		if not (st.kind in kinds):
			continue
		var d = station_dist(p, st)
		if d <= bd:
			bd = d
			best = st
	return best

func nearest_item(p: Node3D, kinds: Array = []) -> RigidBody3D:
	var best: RigidBody3D = null
	var bd = SF.REACH
	for it in get_tree().get_nodes_in_group("item"):
		if it.holder != null or it.gripped_by != null or it == p.held:
			continue
		if not kinds.is_empty() and not (it.kind in kinds):
			continue
		var d = _flat_dist(p.global_position, it.global_position)
		if d <= bd:
			bd = d
			best = it
	return best

func can_accept(st: Node3D, it: RigidBody3D) -> bool:
	match st.kind:
		"furnace": return it.kind in ["ore", "scrap", "ingot", "blank"] and not (it.kind == "ingot" and it.hot > 0.0)
		"anvil": return st.slot == null and it.kind == "ingot"
		"grindstone": return st.slot == null and it.kind == "blank"
	return false

## E: pick up, place, grip with tongs, or drop.
func interact(p) -> String:
	var h: RigidBody3D = p.held
	if h == null:
		var it = nearest_item(p)
		if it == null:
			return _say(p, "Nothing to grab")
		p.pick_up(it)
		return _say(p, "Picked up " + it.display_name())
	if h.kind == "tool" and h.tool == "tongs":
		if h.tongs_load:
			var load_item = h.tongs_load
			var st = nearest_station(p, ["anvil", "grindstone", "furnace"])
			if st and can_accept(st, load_item):
				h.tongs_load = null
				load_item.gripped_by = null
				st.accept(load_item)
				return _say(p, "Placed it on the " + st.kind)
			h.tongs_load = null
			load_item.release(p.facing * 1.5 + Vector3.UP * 1.0)
			return _say(p, "Set it down")
		var grab = nearest_item(p, ["ingot", "blank", "scrap", "ore"])
		if grab:
			if grab.station:
				grab.station.clear_slot(grab)
				grab.station = null
			h.tongs_load = grab
			grab.gripped_by = h
			grab.attach()
			return _say(p, "Tongs grip " + grab.display_name())
	var st2 = nearest_station(p, ["anvil", "grindstone", "furnace"])
	if st2 and can_accept(st2, h):
		p.held = null
		h.holder = null
		st2.accept(h)
		return _say(p, "Put it in the " + st2.kind)
	p.drop(p.facing * 1.5 + Vector3.UP * 1.0)
	return _say(p, "Dropped " + h.display_name())

func _near_door(p: Node3D) -> bool:
	var front = door.global_position.z + door.size.z * 0.5
	return absf(p.global_position.z - front) <= SF.REACH and absf(p.global_position.x - door.global_position.x) <= door.size.x * 0.5 + 0.5

## F or click: use what you're holding.
func use(p) -> String:
	var h: RigidBody3D = p.held
	if h == null:
		return _say(p, "Hands empty")
	if h.kind == "weapon":
		if _near_door(p):
			return _say(p, door.door_hit(p, h))
		return _say(p, "Swing it at the door")
	if h.kind != "tool":
		return _say(p, "Carry it somewhere (E to place)")
	match h.tool:
		"pickaxe":
			var n = nearest_station(p, ["node"])
			if n:
				return _say(p, n.mine())
			if _near_door(p):
				return _say(p, door.door_hit(p, h))
		"tongs":
			if nearest_station(p, ["furnace"]):
				furnace.pump()
				return _say(p, "Whoosh")
		"hammer":
			if nearest_station(p, ["anvil"]):
				return _say(p, anvil.hammer())
			if _near_door(p):
				return _say(p, door.door_hit(p, h))
			for o in players:
				if o != p and o.stun <= 0.0 and _flat_dist(o.global_position, p.global_position + p.facing) < 1.3:
					o.stun = 0.7
					o.velocity = p.facing * 6.0 + Vector3.UP * 4.0
					return _say(p, "BONK! Sorry, " + o.role["name"])
		"bucket":
			if h.bucket_full:
				for o in players:
					if o != p and o.stun > 0.0 and _flat_dist(o.global_position, p.global_position) < SF.REACH:
						o.revive()
						h.bucket_full = false
						return _say(p, "Splash! " + o.role["name"] + " is back up")
			var spot = nearest_station(p, ["trough", "grindstone"])
			if spot and spot.kind == "trough":
				h.bucket_full = true
				return _say(p, "Bucket filled")
			if spot and spot.kind == "grindstone":
				return _say(p, grindstone.grind(h))
	return _say(p, "Nothing to use the " + h.tool + " on here")

func _say(p, msg: String) -> String:
	if p.controlled:
		hud.action(msg)
	return msg

## One-line hint for what E and F do right now.
func hint(p) -> String:
	var parts = []
	var h: RigidBody3D = p.held
	parts.append("Holding: " + (h.display_name() if h else "nothing"))
	var near = nearest_station(p, ["node", "furnace", "anvil", "grindstone", "trough"])
	if near:
		parts.append("Near: " + (near.ore.capitalize() + " node" if near.kind == "node" else near.kind.capitalize()))
	elif _near_door(p):
		parts.append("Near: the door")
	return "   ".join(parts)
