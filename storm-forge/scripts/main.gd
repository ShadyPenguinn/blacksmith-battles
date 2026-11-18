extends Node3D
## Storm Forge graybox: builds the area, runs the door loop, routes player actions.

const ItemScript := preload("res://scripts/item.gd")
const StationScript := preload("res://scripts/station.gd")
const PlayerScript := preload("res://scripts/player.gd")
const LightningScript := preload("res://scripts/lightning.gd")
const HudScript := preload("res://scripts/hud.gd")
const NetScript := preload("res://scripts/net.gd")

const TOOL_SPOTS := [Vector3(0, 0.5, 4), Vector3(-4, 0.5, -0.8), Vector3(-2, 0.5, -1.4), Vector3(6.5, 0.5, -1.6)]
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
var start_mode = "menu"     # menu, offline, host, client (tests set this before adding the scene)
var join_ip = "127.0.0.1"
var player_count = 4        # offline: four smiths you switch between; online: one per player
var run_started = false
var net: Node
var next_item_id = 1
var items_by_id = {}
var area_nodes: Array = []
var areas = {}              # door index -> that area's root node (current and previous only)
var layout: Dictionary = {} # where this area's stations and veins are
var next_node_id = 1
var vein_t = 0.0
var rain: GPUParticles3D

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
	net = Node.new()
	net.name = "Net"
	net.set_script(NetScript)
	add_child(net)
	net.main = self
	_choose_start()

## Command line: -- --offline | --host [--autostart N] | --join IP. Otherwise show the menu.
func _choose_start() -> void:
	var args = OS.get_cmdline_user_args()
	if start_mode == "menu":
		if "--offline" in args:
			start_mode = "offline"
		elif "--host" in args:
			start_mode = "host"
		elif "--join" in args:
			start_mode = "client"
			var i = args.find("--join")
			if i + 1 < args.size():
				join_ip = args[i + 1]
	if "--autostart" in args:
		var j = args.find("--autostart")
		if j + 1 < args.size():
			net.autostart = int(args[j + 1])
	match start_mode:
		"offline":
			menu_offline()
		"host":
			menu_host()
		"client":
			menu_join(join_ip)
		_:
			hud.show_menu()

func menu_offline() -> void:
	start_run(4)

func menu_host() -> void:
	var err = net.host()
	if err != OK:
		hud.show_big("Couldn't host", "Port %d may be in use (error %d)." % [net.PORT, err])
		return
	hud.show_lobby("Hosting", net.lobby_text(), true)
	if net.autostart == 1:
		net.host_start()

func menu_join(ip: String) -> void:
	var err = net.join(ip)
	if err != OK:
		hud.show_big("Couldn't connect", "Error %d" % err)
		return
	hud.show_lobby("Joining", "Connecting to %s..." % ip, false)

func is_client() -> bool:
	return net != null and net.mode == "client"

func is_online() -> bool:
	return net != null and net.mode != "offline"

# ---------------------------------------------------------------- setup

func _setup_input() -> void:
	var keys = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT], "dive": [KEY_SPACE], "interact": [KEY_E],
		"use": [KEY_F, KEY_J], "throw": [KEY_Q], "restart": [KEY_R],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4],
		"next_smith": [KEY_TAB],
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
	for pair in [["slot_prev", MOUSE_BUTTON_WHEEL_UP], ["slot_next", MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var wheel = InputEventMouseButton.new()
		wheel.button_index = pair[1]
		InputMap.action_add_event(pair[0], wheel)

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

	items_root = Node3D.new()
	add_child(items_root)
	nodes_root = Node3D.new()
	add_child(nodes_root)
	build_area(make_layout(0))

	lightning = Node3D.new()
	lightning.set_script(LightningScript)
	add_child(lightning)
	lightning.setup(self)

	_rain()

	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	hud.setup(self)

func _wall(parent: Node3D, pos: Vector3, size: Vector3, visible_wall: bool) -> void:
	var w = StaticBody3D.new()
	w.collision_layer = 1
	w.add_child(Build.box_shape(size))
	if visible_wall:
		w.add_child(Build.box(size, Color(0.4, 0.38, 0.36)))
	parent.add_child(w)
	w.global_position = pos

func _station(kind: String, pos: Vector3, size: Vector3, color: Color, opts: Dictionary = {}, parent: Node = null) -> StaticBody3D:
	var s = StaticBody3D.new()
	s.set_script(StationScript)
	s.setup(self, kind, size, color, opts)
	if parent == null:
		parent = nodes_root if kind == "node" else self
	parent.add_child(s)
	s.global_position = pos
	return s

# ---------------------------------------------------------------- areas

## Areas run in a line: area i sits AREA_STEP further back than area i-1, and its back
## edge is the doorway of the area before it, so breaking a door opens the way forward.
func area_origin(i: int) -> Vector3:
	return Vector3(0, 0, -SF.AREA_STEP * i)

func area_center() -> Vector3:
	return area_origin(door_index) + Vector3(0, 0, -2)

const STATION_SIZES := {
	"furnace": Vector3(2.2, 2.2, 2.2), "anvil": Vector3(1.3, 0.9, 0.7),
	"grindstone": Vector3(1.4, 1.1, 1.6), "trough": Vector3(1.8, 0.7, 0.9),
}
const STATION_COLORS := {
	"furnace": Color(0.45, 0.2, 0.15), "anvil": Color(0.3, 0.3, 0.34),
	"grindstone": Color(0.7, 0.62, 0.45), "trough": Color(0.25, 0.45, 0.75),
}

## Host: pick where everything goes in area i. Area 1 uses the classic layout; later
## areas shuffle the stations and veins (furnace and anvil stay close for hot ingots).
func make_layout(i: int) -> Dictionary:
	var o = area_origin(i)
	var st = {}
	var spots = []
	if i == 0:
		st = {"furnace": Vector2(-6, -3), "anvil": Vector2(-2, -3), "grindstone": Vector2(2.5, -3), "trough": Vector2(6.5, -3)}
		for k in st:
			spots.append(st[k])
	else:
		var tries = 0
		while tries < 200:
			tries += 1
			st.clear()
			spots.clear()
			var ok = true
			for k in ["furnace", "anvil", "grindstone", "trough"]:
				var pt = _free_spot(spots, Rect2(-10, -8, 20, 14), 4.0)
				if pt == null:
					ok = false
					break
				st[k] = pt
				spots.append(pt)
			if ok and st["furnace"].distance_to(st["anvil"]) <= 8.0 and st["anvil"].distance_to(st["grindstone"]) <= 11.0:
				break
	for k in st:
		st[k] = Vector2(st[k].x + o.x, st[k].y + o.z)
	var nodes = []
	var cfg: Dictionary = SF.DOORS[i]
	var slot = 0
	for ore in cfg["nodes"]:
		for n in cfg["nodes"][ore]:
			var pt
			if i == 0 and slot < NODE_SLOTS.size():
				pt = NODE_SLOTS[slot]
			else:
				pt = _free_spot(spots, Rect2(-11, -8, 22, 19), 3.2)
			slot += 1
			if pt == null:
				continue
			spots.append(pt)
			nodes.append([next_node_id, ore, pt.x + o.x, pt.y + o.z, randi_range(SF.VEIN_CHUNKS - 1, SF.VEIN_CHUNKS + 1)])
			next_node_id += 1
	return {"door": i, "stations": st, "nodes": nodes}

## A random point in rect (area-local x, z) at least gap from every taken point, or null.
func _free_spot(taken: Array, rect: Rect2, gap: float):
	for t in 80:
		var pt = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
		var ok = true
		for q in taken:
			if pt.distance_to(q) < gap:
				ok = false
				break
		if ok:
			return pt
	return null

## Build area layout["door"] from a layout (host makes it, clients get it in the "area" event).
## The new stations become the live ones; the previous area's stations turn into scenery.
func build_area(lay: Dictionary) -> void:
	var i: int = lay["door"]
	layout = lay
	var o = area_origin(i)
	for k in areas.keys():
		if k < i - 1 or k >= i:
			_free_area(k)
	for st in [furnace, anvil, grindstone, trough]:
		if st and is_instance_valid(st):
			st.retire()
	if door and is_instance_valid(door):
		door.retire()
		door.queue_free()
	_clear_nodes()
	if rod and is_instance_valid(rod):
		rod.queue_free()
	rod = null
	var root = Node3D.new()
	root.name = "Area%d" % i
	add_child(root)
	areas[i] = root
	var ground = StaticBody3D.new()
	ground.collision_layer = 1
	ground.add_child(Build.box_shape(Vector3(26, 1, 27)))
	ground.add_child(Build.box(Vector3(26, 1, 27), Color(0.35, 0.4, 0.3).lerp(Color(0.3, 0.3, 0.33), i / 8.0)))
	root.add_child(ground)
	ground.global_position = o + Vector3(0, -0.5, 1)
	_wall(root, o + Vector3(-13.5, 2, 1), Vector3(1, 4, 27), true)
	_wall(root, o + Vector3(13.5, 2, 1), Vector3(1, 4, 27), true)
	if i == 0:
		_wall(root, o + Vector3(0, 2, 14.5), Vector3(28, 4, 1), false)
	_wall(root, o + Vector3(-9.5, 4, -12.5), Vector3(7, 8, 2), true)
	_wall(root, o + Vector3(9.5, 4, -12.5), Vector3(7, 8, 2), true)
	door = _station("door", o + Vector3(0, 3.5, -12.5), Vector3(12, 7, 1), Color(0.35, 0.22, 0.12), {}, root)
	var st: Dictionary = lay["stations"]
	var made = {}
	for k in ["furnace", "anvil", "grindstone", "trough"]:
		var sz: Vector3 = STATION_SIZES[k]
		made[k] = _station(k, Vector3(st[k].x, sz.y * 0.5, st[k].y), sz, STATION_COLORS[k], {}, root)
	furnace = made["furnace"]
	anvil = made["anvil"]
	grindstone = made["grindstone"]
	trough = made["trough"]
	var fire = Build.box(Vector3(1.2, 0.5, 0.1), Color(1.0, 0.45, 0.1), 3.0)
	fire.position = Vector3(0, -0.5, 1.12)
	furnace.add_child(fire)
	for n in lay["nodes"]:
		_add_node(n)
	if mod("rod") > 0:
		rod = _station("rod", o + Vector3(0, 2, 4.5), Vector3(0.25, 4, 0.25), Color(0.75, 0.75, 0.8), {}, root)
	# Loose things left two areas back are gone for good.
	for it in get_tree().get_nodes_in_group("item"):
		if it.is_free() and it.station == null and it.global_position.z > o.z + SF.AREA_STEP + 14.5:
			despawn(it)
	if rain:
		rain.global_position = o + Vector3(0, 16, -1)

func _free_area(k: int) -> void:
	if areas.has(k):
		var root = areas[k]
		areas.erase(k)
		if is_instance_valid(root):
			for c in root.get_children():
				if c.has_method("retire"):
					c.retire()
			root.queue_free()

## [id, ore, x, z, chunks]
func _add_node(n: Array) -> StaticBody3D:
	var node = _station("node", Vector3(n[2], 0.6, n[3]), Vector3(1.4, 1.2, 1.4), SF.ORE_COLORS[n[1]], {"ore": n[1], "node_id": n[0], "chunks": n[4]})
	area_nodes.append(node)
	next_node_id = maxi(next_node_id, n[0] + 1)
	return node

## A vein ran dry: it crumbles away.
func remove_node(n: Node3D) -> void:
	area_nodes.erase(n)
	n.retire()
	n.queue_free()

## Host: every so often lightning cracks open a fresh vein somewhere in the area.
func _vein_tick(delta: float) -> void:
	vein_t += delta
	if vein_t < SF.VEIN_RESPAWN:
		return
	vein_t = 0.0
	var cfg: Dictionary = SF.DOORS[door_index]
	var start_count = 0
	for ore in cfg["nodes"]:
		start_count += cfg["nodes"][ore]
	if area_nodes.size() >= start_count + SF.VEIN_EXTRA:
		return
	var taken = []
	var o = area_origin(door_index)
	for st in get_tree().get_nodes_in_group("station"):
		taken.append(Vector2(st.global_position.x - o.x, st.global_position.z - o.z))
	for p in players:
		taken.append(Vector2(p.global_position.x - o.x, p.global_position.z - o.z))
	var pt = _free_spot(taken, Rect2(-11, -8, 22, 19), 3.2)
	if pt == null:
		return
	var ore = cfg["nodes"].keys().pick_random()
	var pos = Vector3(pt.x + o.x, 0, pt.y + o.z)
	lightning._bolt(pos)
	flash()
	net.send_event("strike", pos)
	_add_node([next_node_id, ore, pos.x, pos.z, randi_range(SF.VEIN_CHUNKS - 1, SF.VEIN_CHUNKS + 1)])
	toast("Lightning cracked open a new %s vein!" % ore)

func _rain() -> void:
	rain = GPUParticles3D.new()
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

func start_run(n: int = -1) -> void:
	if n > 0:
		player_count = n
	run_started = true
	over = false
	paused_for_roll = false
	door_index = 0
	mods = {}
	for it in get_tree().get_nodes_in_group("item"):
		despawn(it)
	for k in areas.keys():
		_free_area(k)
	door = null
	build_area(make_layout(0))
	_make_players(player_count)
	for i in SF.ROLES.size():
		var t = spawn_item("tool", TOOL_SPOTS[i], {"tool": SF.ROLES[i]["tool"]})
		t.owner_idx = i
		if i < players.size():
			var p = players[i]
			p.clear_slots()
			p.stun = 0.0
			p.set_big_head(1.0)
			p.global_position = Vector3(-3.0 + 2.0 * i, 0.1, 2.0)
			p.velocity = Vector3.ZERO
			p.pick_up(t)
	set_controlled(net.my_smith if is_online() else 0)
	hud.hide_big()
	net.send_event("restart")
	start_area()

func _make_players(n: int) -> void:
	while players.size() > n:
		players.pop_back().queue_free()
	while players.size() < n:
		var p = CharacterBody3D.new()
		p.set_script(PlayerScript)
		p.setup(self, players.size())
		add_child(p)
		p.puppet = is_client()
		players.append(p)

func start_area() -> void:
	var cfg: Dictionary = SF.DOORS[door_index]
	door.max_hp = cfg["hp"] * player_scale("door")
	door.hp = door.max_hp
	door.tier = cfg["tier"]
	area_time = maxf(60.0, SF.AREA_TIME + 30.0 * (mod("long_fuse") - mod("short_fuse")))
	time_left = area_time
	peak_time = 0.0
	vein_t = 0.0
	if mod("rod") > 0 and rod == null:
		rod = _station("rod", area_origin(door_index) + Vector3(0, 2, 4.5), Vector3(0.25, 4, 0.25), Color(0.75, 0.75, 0.8), {}, areas.get(door_index))
	lightning.reset_area()
	env.background_color = cfg["sky"]
	send_area()
	toast("Door %d: %s. Break it before the storm peaks!" % [door_index + 1, cfg["area"]])

func _clear_nodes() -> void:
	for n in area_nodes:
		if is_instance_valid(n):
			n.retire()
			n.queue_free()
	area_nodes.clear()

## Host: tell clients the layout of the current area.
func send_area() -> void:
	var lay = layout.duplicate(true)
	lay["rod"] = rod != null
	net.send_event("area", lay)

func door_broken() -> void:
	if paused_for_roll or over:
		return
	door_index += 1
	if door_index >= SF.DOORS.size():
		door_index = SF.DOORS.size() - 1
		over = true
		show_big("You broke the Storm Gate!", "All 8 doors down. The host presses R to play again.")
		return
	paused_for_roll = true
	build_area(make_layout(door_index))
	send_area()
	var buff: Dictionary = SF.BUFFS.pick_random()
	var debuff: Dictionary = SF.DEBUFFS.pick_random()
	hud.show_roll(buff, debuff)
	net.send_event("roll", [buff, debuff])
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
	net.send_event("hide_big")
	start_area()

func _role_swap() -> void:
	var tools = []
	for p in players:
		tools.append(p.slots[0])
	for i in players.size():
		var incoming = tools[(i - 1 + players.size()) % players.size()]
		var p = players[i]
		p.slots[0] = null
		if incoming:
			incoming.holder = null
			p.pick_up(incoming)

func game_over() -> void:
	over = true
	show_big("The storm took the forge", "Doors broken: %d. The host presses R to try again." % door_index)

func show_big(title: String, sub: String) -> void:
	hud.show_big(title, sub)
	net.send_event("big", [title, sub])

func mod(id: String) -> int:
	return mods.get(id, 0)

## Scales door HP and lightning for smaller groups. Offline graybox always has 4.
func player_scale(what: String) -> float:
	var n = player_count
	if what == "door":
		return {1: 0.45, 2: 0.6, 3: 0.8, 4: 1.0}.get(n, 1.0)
	return {1: 0.6, 2: 0.7, 3: 0.85, 4: 1.0}.get(n, 1.0)

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if not run_started:
		return
	if is_client():
		_client_input()
	else:
		_host_process(delta)
	_update_camera(delta)
	flash_t = maxf(0.0, flash_t - delta)
	env.ambient_light_energy = 0.6 + flash_t * 16.0
	sun.light_energy = (0.8 - 0.5 * _storm_progress()) + flash_t * 10.0
	var sky: Color = SF.DOORS[door_index]["sky"]
	env.background_color = sky.lerp(Color(0.08, 0.08, 0.12), _storm_progress()).lerp(Color(0.9, 0.92, 1.0), clampf(flash_t * 3.0, 0.0, 1.0))
	hud.refresh()

func _host_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart") and over:
		start_run()
		return
	if not over and not paused_for_roll:
		_vein_tick(delta)
		if time_left > 0.0:
			time_left -= delta
		else:
			peak_time += delta
			if peak_time >= SF.PEAK_GRACE:
				game_over()
		_handle_input()

func _storm_progress() -> float:
	return clampf(1.0 - time_left / area_time, 0.0, 1.0)

## Local keyboard for the smith you control (host or offline).
func _handle_input() -> void:
	if not is_online() and Input.is_action_just_pressed("next_smith"):
		set_controlled((controlled + 1) % players.size())
	var p = players[controlled]
	p.in_move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	p.in_sprint = Input.is_action_pressed("sprint")
	for a in _pressed_actions():
		do_action(p, a, {})

const ACTIONS := ["interact", "use", "throw", "dive", "debug_strike", "debug_skip",
	"slot_1", "slot_2", "slot_3", "slot_4", "slot_prev", "slot_next"]

func _pressed_actions() -> Array:
	var out = []
	for a in ACTIONS:
		if Input.is_action_just_pressed(a):
			out.append(a)
	return out

## Client: send movement every physics tick (net.gd) and button presses as they happen.
func _client_input() -> void:
	if not net.scripted_input:
		net.last_move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		net.last_sprint = Input.is_action_pressed("sprint")
	if over:
		return
	for a in _pressed_actions():
		var extra = {}
		if a == "use":
			# Judge the beat on this screen so lag doesn't eat good hits.
			extra = {"anvil": anvil.on_beat(anvil.zone()), "grind": grindstone.on_beat(SF.GRIND_ZONE)}
		net.send_action(a, extra)

## Runs a button press for a smith. Host and offline only.
func do_action(p, action_name: String, extra: Dictionary) -> void:
	if over or paused_for_roll:
		return
	if action_name == "dive":
		p.in_dive = true
		return
	if action_name.begins_with("slot_"):
		match action_name:
			"slot_prev": p.cycle(-1)
			"slot_next": p.cycle(1)
			_: p.select(int(action_name.substr(5)) - 1)
		return
	if p.stun > 0.0:
		return
	match action_name:
		"interact":
			var said = interact(p)
			if said.begins_with("Picked") or said.begins_with("Swapped") or said.begins_with("Tongs"):
				p.act("grab")
			elif said.begins_with("Put") or said.begins_with("Placed"):
				p.act("place")
		"use":
			anvil.beat_override = (1 if extra["anvil"] else 0) if extra.has("anvil") else -1
			grindstone.beat_override = (1 if extra["grind"] else 0) if extra.has("grind") else -1
			var h = p.held
			if h:
				p.act(h.tool if h.kind == "tool" else ("weapon" if h.kind == "weapon" else "place"))
			use(p)
			anvil.beat_override = -1
			grindstone.beat_override = -1
		"throw":
			if p.held:
				p.act("throw")
				p.drop(p.facing * 7.0 + Vector3.UP * 3.5)
		"debug_strike":
			lightning.begin_warning(p)
		"debug_skip":
			door_broken()

func set_controlled(i: int) -> void:
	controlled = i
	for j in players.size():
		players[j].controlled = (j == i)
		players[j].in_move = Vector2.ZERO
		players[j].in_sprint = false

func _update_camera(delta: float) -> void:
	if players.is_empty():
		return
	var p = players[controlled]
	var focus: Vector3 = p.global_position.lerp(area_center(), 0.35)
	var want = focus + SF.CAM_OFFSET
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
	if net:
		net.send_event("toast", msg)

# ---------------------------------------------------------------- items

func spawn_item(kind: String, pos: Vector3, opts: Dictionary = {}) -> RigidBody3D:
	var it = RigidBody3D.new()
	it.set_script(ItemScript)
	it.setup(kind, opts)
	it.net_id = opts.get("net_id", next_item_id)
	next_item_id = maxi(next_item_id, it.net_id) + 1
	items_by_id[it.net_id] = it
	items_root.add_child(it)
	it.global_position = pos
	return it

func despawn(it: RigidBody3D) -> void:
	if not is_instance_valid(it):
		return
	if it.holder:
		it.holder.take(it)
	if it.gripped_by and it.gripped_by.tongs_load == it:
		it.gripped_by.tongs_load = null
	if it.tongs_load:
		it.tongs_load.release()
		it.tongs_load = null
	if it.station:
		it.station.clear_slot(it)
	it.remove_from_group("item")
	items_by_id.erase(it.net_id)
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

## E: place on a station (from your hand or pockets), pick up, grip with tongs, or drop.
func interact(p) -> String:
	var h: RigidBody3D = p.held
	if h and h.kind == "tool" and h.tool == "tongs":
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
		var grab = nearest_item(p, ["ingot", "blank"])
		if grab:
			if grab.station:
				grab.station.clear_slot(grab)
				grab.station = null
			h.tongs_load = grab
			grab.gripped_by = h
			grab.attach()
			return _say(p, "Tongs grip " + grab.display_name())
	# At a station: put in what fits, the thing in your hand first. The furnace takes it all.
	var st2 = nearest_station(p, ["anvil", "grindstone", "furnace"])
	if st2:
		var order = p.items()
		if h:
			order.erase(h)
			order.push_front(h)
		var placed = []
		for it in order:
			if can_accept(st2, it):
				p.take(it)
				st2.accept(it)
				placed.append(it.display_name())
				if st2.kind != "furnace":
					break
		if not placed.is_empty():
			return _say(p, "Put %s in the %s" % [", ".join(placed), st2.kind])
	var near = nearest_item(p)
	if near:
		if p.pick_up(near):
			return _say(p, "Picked up " + near.display_name())
		# No room: swap if the full slot is the one in your hand.
		var blocked = p.blocking_slot(near)
		if blocked == p.sel and h:
			p.drop(p.facing * 1.5 + Vector3.UP * 1.0)
			p.pick_up(near)
			return _say(p, "Swapped for " + near.display_name())
		if near.kind == "tool":
			return _say(p, "One tool at a time. Select it and press E to swap.")
		return _say(p, "Pockets full")
	if h == null:
		return _say(p, "Nothing to grab")
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
	elif is_online():
		net.say_to(p.idx, msg)
	return msg

## One-line hint for what E and F do right now.
func hint(p) -> String:
	var parts = []
	var near = nearest_station(p, ["node", "furnace", "anvil", "grindstone", "trough"])
	if near:
		parts.append("Near: " + (near.ore.capitalize() + " node" if near.kind == "node" else near.kind.capitalize()))
	elif _near_door(p):
		parts.append("Near: the door")
	return "   ".join(parts)

# ---------------------------------------------------------------- online sync

## Host: everything a client needs to draw this moment.
func make_snapshot() -> Dictionary:
	var ps = []
	for p in players:
		ps.append([p.global_position, p.visual.rotation, p.stun, p.slots.map(func(it): return it.net_id if it else 0), p.facing, p.sel, p.act_name, p.act_seq])
	var its = {}
	for it in get_tree().get_nodes_in_group("item"):
		its[it.net_id] = [it.kind, it.tool, it.ore, it.tier, it.global_position, it.global_rotation,
			it.hot, it.durability, it.bucket_full, it.quenched, it.tongs_load.net_id if it.tongs_load else 0,
			it.is_free() and it.station == null]
	var nodes = []
	for n in area_nodes:
		nodes.append([n.node_id, n.ore, n.hits, n.chunks, n.global_position.x, n.global_position.z])
	return {
		"p": ps, "i": its, "n": nodes,
		"g": [door_index, time_left, area_time, peak_time, over, paused_for_roll, mods],
		"f": [furnace.heat, furnace.contents, furnace.smelt],
		"a": [anvil.slot.net_id if anvil.slot else 0, anvil.hits, anvil.misses, anvil.beat_t],
		"s": [grindstone.slot.net_id if grindstone.slot else 0, grindstone.hits, grindstone.beat_t],
		"d": [door.hp, door.max_hp, door.tier, door.beat_t],
		"l": [lightning.ring.visible, lightning.target_pos],
	}

## Client: start the run with the host's player count, controlling our own smith.
func start_client(count: int, smith: int) -> void:
	run_started = true
	over = false
	player_count = count
	_make_players(count)
	for p in players:
		p.puppet = true
	set_controlled(smith)
	hud.hide_big()

func apply_snapshot(s: Dictionary) -> void:
	if not run_started:
		return
	var g: Array = s["g"]
	door_index = g[0]
	time_left = g[1]
	area_time = g[2]
	peak_time = g[3]
	over = g[4]
	paused_for_roll = g[5]
	var heads_before = mod("big_heads")
	mods = g[6]
	# Items: create new ones, update the rest, remove the ones the host no longer has.
	var seen = {}
	var its: Dictionary = s["i"]
	for id in its:
		var d: Array = its[id]
		seen[id] = true
		var it = items_by_id.get(id)
		if it == null or not is_instance_valid(it):
			it = spawn_item(d[0], d[4], {"tool": d[1], "ore": d[2], "tier": d[3], "net_id": id})
			it.puppet = true
			it.attach()
			it.global_position = d[4]
		it.net_pos = d[4]
		it.net_rot = d[5]
		it.hot = d[6]
		it.durability = d[7]
		it.bucket_full = d[8]
		it.quenched = d[9]
		it.net_loose = d[11]
	for id in its:
		var tl = its[id][10]
		items_by_id[id].tongs_load = items_by_id.get(tl) if tl != 0 else null
	for id in items_by_id.keys():
		if not seen.has(id):
			var gone = items_by_id[id]
			items_by_id.erase(id)
			if is_instance_valid(gone):
				gone.remove_from_group("item")
				gone.queue_free()
	var ps: Array = s["p"]
	for i in mini(ps.size(), players.size()):
		var p = players[i]
		var d: Array = ps[i]
		p.net_pos = d[0]
		p.net_rot = d[1]
		p.stun = d[2]
		for k in p.slots.size():
			var sid: int = d[3][k]
			p.slots[k] = items_by_id.get(sid) if sid != 0 else null
		p.facing = d[4]
		p.sel = d[5]
		p.act_name = d[6]
		p.act_seq = d[7]
		if mod("big_heads") != heads_before:
			p.set_big_head(1.0 + 1.0 * mod("big_heads"))
	# Veins: match by id, add new ones, crumble the ones the host no longer has.
	var by_id = {}
	for n in area_nodes:
		by_id[n.node_id] = n
	var keep = {}
	for nd in s["n"]:
		var n = by_id.get(nd[0])
		if n == null:
			n = _add_node([nd[0], nd[1], nd[4], nd[5], nd[3]])
		keep[nd[0]] = true
		if n.ore != nd[1]:
			n.set_ore(nd[1])
		n.hits = nd[2]
		if n.chunks != nd[3]:
			n.set_chunks(nd[3])
	for n in area_nodes.duplicate():
		if not keep.has(n.node_id):
			remove_node(n)
	var f: Array = s["f"]
	furnace.heat = f[0]
	furnace.contents = f[1]
	furnace.smelt = f[2]
	var a: Array = s["a"]
	anvil.slot = items_by_id.get(a[0]) if a[0] != 0 else null
	anvil.hits = a[1]
	anvil.misses = a[2]
	if absf(anvil.beat_t - a[3]) > 0.25:
		anvil.beat_t = a[3]
	var gs: Array = s["s"]
	grindstone.slot = items_by_id.get(gs[0]) if gs[0] != 0 else null
	grindstone.hits = gs[1]
	if absf(grindstone.beat_t - gs[2]) > 0.25:
		grindstone.beat_t = gs[2]
	var d2: Array = s["d"]
	door.hp = d2[0]
	door.max_hp = d2[1]
	door.tier = d2[2]
	if absf(door.beat_t - d2[3]) > 0.25:
		door.beat_t = d2[3]
	var l: Array = s["l"]
	lightning.ring.visible = l[0]
	lightning.ring.global_position = Vector3(l[1].x, 0.08, l[1].z)

## Client: one-off things the host tells us about.
func apply_event(kind: String, data) -> void:
	match kind:
		"toast":
			toasts.append(data)
			hud.toast(data)
		"say":
			hud.action(data)
		"roll":
			hud.show_roll(data[0], data[1])
		"hide_big", "restart":
			hud.hide_big()
		"big":
			hud.show_big(data[0], data[1])
		"strike":
			lightning._bolt(data)
			flash()
		"area":
			if data["door"] == 0:
				for k in areas.keys():
					_free_area(k)
				door = null
			if not areas.has(data["door"]) or data["door"] == 0:
				build_area(data)
			door_index = data["door"]
			if data["rod"] and rod == null:
				rod = _station("rod", area_origin(door_index) + Vector3(0, 2, 4.5), Vector3(0.25, 4, 0.25), Color(0.75, 0.75, 0.8), {}, areas.get(door_index))
