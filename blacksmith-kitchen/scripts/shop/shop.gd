extends Node
## Shop Day: you walk your smith around the workshop. Customers come in, stand at the counter
## and wait; their tickets sit across the top with a patience bar. Take a job from ore to
## weapon station by station. Hands-on stations zoom in for their minigame; the furnace and
## the cooling molds work on their own, so you can start the next job while they do. While a
## minigame is on, a station camera (Tab) shows how the furnace and molds are doing.

const Smith = preload("res://scripts/coop/smith.gd")
const Item = preload("res://scripts/shop/shop_item.gd")
const Overlay = preload("res://scripts/shop/shop_overlay.gd")

var main: Node
var ws: Workshop
var hud: Hud
var root: Node3D             # shop things that must survive minigames clearing ws.props
var smith: Node3D
var smiths := []
var obstacles := []
var items := []
var tickets := []            # {id, who, name, weapon, tier, t, max, actor, slot, started, bubble}
var queue := []              # orders still to walk in today
var results := []            # one score per order: delivered score, or 0 if they left
var spawn_t := 0.0
var next_id := 0
var busy := false
var over := false
var day := 0
var seen := {}               # step names whose how-to card was shown this day
var pending = null           # station to use when the click-to-walk arrives
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var overlay: Control

# Hands-off stations.
var furnace := {"job": null, "state": "idle", "t": 0.0, "need": 1.0, "over": 0.0, "burn": 0.0}
var mold := {"job": null, "state": "idle", "t": 0.0, "need": 1.0}
var furnace_label: Label3D
var mold_label: Label3D
var mold_prop: Node3D
var marker: MeshInstance3D
var marker_label: Label3D

# Station camera (picture in picture during minigames).
var pip: SubViewportContainer
var pip_cam: Camera3D
var pip_title: Label
var pip_target := "furnace"

const SPOTS := {
	"rock": Workshop.ROCK + Vector3(1.3, 0, -0.5),
	"crush": Workshop.CRUSH + Vector3(0.0, 0, -0.95),
	"furnace": Workshop.FURNACE + Vector3(0, 0, 1.7),
	"cast": Workshop.CAST + Vector3(0, 0, 0.95),
	"trip": Workshop.TRIP + Vector3(0, 0, 1.3),
	"anvil": Workshop.ANVIL + Vector3(0, 0, 0.9),
	"tank": Workshop.TANK + Vector3(0, 0, 1.2),
	"grind": Workshop.GRIND + Vector3(-0.2, 0, 1.4),
	"bench": Workshop.BENCH + Vector3(1.3, 0, 0),
	"counter": Vector3(1.0, 0, Workshop.COUNTER_Z - 0.9),
}
const CENTERS := {
	"rock": Workshop.ROCK, "crush": Workshop.CRUSH, "furnace": Workshop.FURNACE, "cast": Workshop.CAST,
	"trip": Workshop.TRIP, "anvil": Workshop.ANVIL, "tank": Workshop.TANK, "grind": Workshop.GRIND,
	"bench": Workshop.BENCH, "counter": Vector3(1.0, 0, Workshop.COUNTER_Z),
}
## Where the station camera looks from, at each hands-off station.
const PIP_SHOTS := {
	"furnace": [Workshop.FURNACE + Vector3(0.6, 2.6, 5.2), Workshop.FURNACE + Vector3(0, 1.0, 0)],
	"cast": [Workshop.CAST + Vector3(0, 2.6, 2.6), Workshop.CAST + Vector3(0, 1.0, 0)],
	"shop": [Vector3(-0.5, 14.0, 10.6), Vector3(-0.5, 0, -0.4)],
}

func setup(p_main: Node, d: int) -> void:
	main = p_main
	ws = main.ws
	hud = main.hud
	day = d
	root = Node3D.new()
	root.name = "ShopRoot"
	ws.add_child(root)
	ws.clear_props()
	ws.use_lever(false)
	ws.set_fire(0.25)
	# Grizzle watches from the corner by the door, out of the way.
	ws.mentor.position = Vector3(10.3, 0, 2.6)
	ws.mentor.rotation.y = deg_to_rad(-120)
	ws.set_shot("shop", 1.0)
	hud.show_top(true)
	hud.clear_steps()
	hud.set_top("Day %d: %s" % [d + 1, BK.DAYS[d]["name"]], main.coins())
	for o in BK.DAYS[d]["orders"]:
		queue.append(o)
	spawn_t = BK.SHOP["first"]
	obstacles = [
		[Vector2(Workshop.FURNACE.x, Workshop.FURNACE.z), 1.3],
		[Vector2(Workshop.FURNACE.x - 2.05, Workshop.FURNACE.z), 1.0],
		[Vector2(Workshop.FURNACE.x + 2.05, Workshop.FURNACE.z), 1.0],
		[Vector2(Workshop.ANVIL.x, Workshop.ANVIL.z), 0.75],
		[Vector2(Workshop.TRIP.x, Workshop.TRIP.z), 1.0],
		[Vector2(Workshop.TANK.x, Workshop.TANK.z), 1.0],
		[Vector2(Workshop.GRIND.x, Workshop.GRIND.z), 1.0],
		[Vector2(Workshop.BENCH.x, Workshop.BENCH.z), 1.1],
		[Vector2(Workshop.CAST.x, Workshop.CAST.z), 1.0],
		[Vector2(Workshop.ROCK.x, Workshop.ROCK.z), 1.1],
		[Vector2(Workshop.CRUSH.x, Workshop.CRUSH.z), 0.9],
		[Vector2(10.3, 2.6), 0.5],
	]
	smith = Smith.new()
	add_child(smith)
	smith.setup(self, 0, 1)
	smith.global_position = Vector3(-1.0, 0, 1.6)
	smiths = [smith]
	_build_world_bits()
	overlay = Overlay.new()
	overlay.shop = self
	hud.game_layer.add_child(overlay)
	_build_pip()
	hud.big("Day %d" % (d + 1), Color(1.0, 0.85, 0.4), 1.6)
	hud.mentor_say("Customers are coming! Walk to the ore rock to start an order.", 4.0)

func _exit_tree() -> void:
	if is_instance_valid(root):
		root.queue_free()
	if is_instance_valid(overlay):
		overlay.queue_free()
	if is_instance_valid(pip):
		pip.queue_free()
	for tk in tickets:
		if is_instance_valid(tk["actor"]):
			tk["actor"].queue_free()
	if is_instance_valid(ws):
		ws.mentor.position = Workshop.MENTOR_SPOT
		ws.mentor.rotation.y = deg_to_rad(20)

func _build_world_bits() -> void:
	furnace_label = Build.label("", 40)
	root.add_child(furnace_label)
	furnace_label.global_position = Workshop.FURNACE + Vector3(0, 3.9, 0.8)
	mold_label = Build.label("", 40)
	root.add_child(mold_label)
	mold_label.global_position = Workshop.CAST + Vector3(0, 2.4, 0)
	marker = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.7
	marker.mesh = tm
	marker.scale = Vector3(1, 0.3, 1)
	marker.material_override = Build.mat(Color(1.0, 0.8, 0.3), 2.0)
	root.add_child(marker)
	marker_label = Build.label("", 36)
	marker_label.modulate = Color(1.0, 0.85, 0.4)
	root.add_child(marker_label)

func _build_pip() -> void:
	pip = SubViewportContainer.new()
	pip.stretch = true
	pip.position = Vector2(16, 218)
	pip.size = Vector2(336, 189)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp = SubViewport.new()
	vp.size = Vector2i(336, 189)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pip.add_child(vp)
	pip_cam = Camera3D.new()
	pip_cam.fov = 50
	vp.add_child(pip_cam)
	pip_title = Label.new()
	pip_title.position = Vector2(0, -34)
	pip_title.add_theme_font_size_override("font_size", 22)
	pip_title.add_theme_color_override("font_outline_color", Color.BLACK)
	pip_title.add_theme_constant_override("outline_size", 8)
	pip.add_child(pip_title)
	pip.visible = false
	hud.add_child(pip)

# --- The clock: customers, patience, hands-off stations ---------------------------------
func _process(delta: float) -> void:
	if over:
		return
	_customers(delta)
	_furnace(delta)
	_mold(delta)
	_update_marker()
	_update_pip()
	# Click-to-walk: stop when we're close enough to use the station, or when we bump into
	# something and stop moving.
	if smith.auto_target != null and not busy:
		if pending != null and pending != "floor" and _station_near(smith) == pending and smith.global_position.distance_to(SPOTS[pending]) < 0.9:
			smith.auto_target = null
			arrived(smith)
		else:
			var moved = smith.global_position.distance_to(last_pos)
			stuck_t = stuck_t + delta if moved < 0.01 else 0.0
			if stuck_t > 0.3:
				smith.auto_target = null
				stuck_t = 0.0
				arrived(smith)
	last_pos = smith.global_position
	if queue.is_empty() and tickets.is_empty() and not busy:
		_end_day()

func _customers(delta: float) -> void:
	spawn_t -= delta
	if not queue.is_empty() and tickets.size() < 4 and (spawn_t <= 0.0 or tickets.is_empty()):
		_new_customer(queue.pop_front())
		spawn_t = BK.SHOP["gap"]
	for tk in tickets.duplicate():
		tk["t"] -= delta
		if tk["t"] <= 0.0:
			_storm_off(tk)

func _new_customer(o: Array) -> void:
	var used = tickets.map(func(x): return x["slot"])
	var slot = 0
	while slot in used:
		slot += 1
	var c = BK.CUSTOMERS[o[0]]
	var a = Actor.new()
	root.add_child(a)
	a.setup(c["model"])
	var spot = Vector3(-1.6 + slot * 1.5, 0, Workshop.COUNTER_Z + 1.0)
	a.global_position = spot + Vector3(-9, 0, 1.5)
	var stages = BK.shop_stages(o[1], o[2]).size()
	var patience = BK.SHOP["patience"] + BK.SHOP["patience_per_stage"] * stages
	var bubble = Build.label("", 30)
	bubble.position.y = 2.6
	bubble.modulate = Color(1.0, 0.97, 0.88)
	a.add_child(bubble)
	var tk = {"id": next_id, "who": o[0], "name": c["name"], "weapon": o[1], "tier": o[2], "t": patience,
		"max": patience, "actor": a, "slot": slot, "started": false, "bubble": bubble, "stage": 0, "stages": stages}
	next_id += 1
	tickets.append(tk)
	a.walk_to(spot, 3.5, func():
		if is_instance_valid(a):
			a.face(spot + Vector3(0, 0, -3))
			bubble.text = BK.fill(BK.say(c["ask"]), {"weapon": o[1], "tier": o[2]})
			get_tree().create_timer(3.5).timeout.connect(func():
				if is_instance_valid(bubble):
					bubble.text = ""))
	Sfx.play("ding", 0.8)

func _storm_off(tk: Dictionary) -> void:
	tickets.erase(tk)
	results.append(0.0)
	var a: Actor = tk["actor"]
	hud.float_text("%s gave up!" % tk["name"], Vector2(get_viewport().get_visible_rect().size.x * 0.5, 160), Color(1.0, 0.45, 0.35), 34)
	Sfx.play("bad")
	if is_instance_valid(a):
		tk["bubble"].text = "Forget it!"
		a.sulk()
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(a):
				a.walk_to(a.global_position + Vector3(9, 0, 1.5), 3.5, func(): a.queue_free()))

func _furnace(delta: float) -> void:
	match furnace["state"]:
		"idle":
			furnace_label.text = ""
		"smelting":
			furnace["t"] += delta
			var f = furnace["t"] / furnace["need"]
			furnace_label.text = "%s %d%%" % ["Melting" if BK.route(furnace["job"]["tier"]) == "cast" else "Blooming", int(f * 100)]
			furnace_label.modulate = Color(1.0, 0.75, 0.4)
			if not busy:
				ws.set_fire(0.45 + 0.1 * sin(Time.get_ticks_msec() * 0.006))
			if f >= 1.0:
				furnace["state"] = "ready"
				furnace["over"] = 0.0
				Sfx.play("ding", 1.2)
				_alert("Furnace is ready!", "furnace")
		"ready", "burning":
			furnace["over"] += delta
			if furnace["over"] > BK.SHOP["ready_window"]:
				if furnace["state"] != "burning":
					_alert("The furnace is BURNING it!", "furnace")
				furnace["state"] = "burning"
				furnace["burn"] = minf(BK.SHOP["burn_max"], furnace["burn"] + BK.SHOP["burn_per_sec"] * delta)
				if randf() < delta * 5.0:
					Fx.burst(ws, Workshop.FURNACE + Vector3(0, 2.6, 0.4), Color(0.2, 0.18, 0.17, 0.8), 6, 1.6, 2.0, 1.5, 1.2)
				furnace_label.text = "BURNING! -%d" % int(furnace["burn"])
				furnace_label.modulate = Color(1.0, 0.35, 0.25) if fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5 else Color(1, 1, 1)
			else:
				var left = BK.SHOP["ready_window"] - furnace["over"]
				furnace_label.text = "READY! (%ds)" % int(ceil(left))
				furnace_label.modulate = Color(0.5, 1.0, 0.5)
			if not busy:
				ws.set_fire(0.8, furnace["state"] == "burning")

func _mold(delta: float) -> void:
	match mold["state"]:
		"idle":
			mold_label.text = ""
		"cooling":
			mold["t"] += delta
			var f = mold["t"] / mold["need"]
			mold_label.text = "Cooling %d%%" % int(f * 100)
			mold_label.modulate = Color(0.6, 0.85, 1.0)
			if mold_prop:
				var m: StandardMaterial3D = mold_prop.get_meta("mat")
				if m:
					var h = 0.8 * (1.0 - f)
					m.emission = BK.heat_color(h)
					m.emission_energy_multiplier = h * 1.4
			if f >= 1.0:
				mold["state"] = "ready"
				Sfx.play("ding", 1.4)
				_alert("A mold has cooled!", "cast")
		"ready":
			mold_label.text = "Crack me!"
			mold_label.modulate = Color(0.5, 1.0, 0.5)

func _alert(s: String, station: String) -> void:
	hud.float_text(s, Vector2(get_viewport().get_visible_rect().size.x * 0.5, 200), Color(1.0, 0.9, 0.5), 34)
	pip_target = station

# --- Doing things ------------------------------------------------------------------------
func _station_near(s: Node3D) -> String:
	var best = ""
	var bd = BK.SHOP["reach"]
	var p = Vector2(s.global_position.x, s.global_position.z)
	for k in SPOTS:
		var q = SPOTS[k]
		var d = p.distance_to(Vector2(q.x, q.z))
		if k == "counter":
			# The whole counter works.
			d = 0.0 if (absf(p.x - 0.4) < 2.6 and p.y > Workshop.COUNTER_Z - 1.9) else 99.0
		if d < bd:
			bd = d
			best = k
	return best

func _say(s: String, at: Vector3, color := Color(1.0, 0.85, 0.5)) -> void:
	hud.float_text(s, ws.to_screen(at + Vector3(0, 2.4, 0)), color, 30)

## E / Space / F, a gamepad button, or arriving at a clicked station.
func grab(s: Node3D) -> void:
	interact(s)

func use(s: Node3D) -> void:
	interact(s)

func tongs_target(_s: Node3D):
	return null

func tongs_release(_s: Node3D, _it: Node3D) -> void:
	pass

func arrived(s: Node3D) -> void:
	if pending != null:
		var st = pending
		pending = null
		_face(st)
		if _station_near(s) == st or st == "floor":
			interact(s)

func _face(st: String) -> void:
	if CENTERS.has(st):
		var c: Vector3 = CENTERS[st]
		smith.actor.rotation.y = atan2(c.x - smith.global_position.x, c.z - smith.global_position.z)

func interact(s: Node3D) -> void:
	if busy or over:
		return
	var st = _station_near(s)
	var h: Node3D = s.held
	# A finished furnace or mold comes first: set down what you carry and take it out.
	if h and ((st == "furnace" and furnace["state"] in ["ready", "burning"]) or (st == "cast" and mold["state"] == "ready")):
		s.drop()
		h = null
		if st == "furnace":
			_take_from_furnace()
		else:
			_face(st)
			_crack_mold()
		return
	if h:
		var want = h.stage()["at"]
		if st == want:
			_face(st)
			if st == "counter":
				_deliver(h)
			else:
				_work(st, h)
		elif st == "counter":
			_say("Not finished yet! Next: " + BK.STATION_NAMES[want], s.global_position)
		elif st != "":
			_say("That goes to the " + BK.STATION_NAMES[want], s.global_position)
		else:
			s.drop()
		return
	# Empty hands: pick up something nearby first.
	var it = _nearest_item(s)
	if it:
		s.take(it)
		return
	match st:
		"rock":
			_face(st)
			_start_job()
		"furnace":
			if furnace["state"] in ["ready", "burning"]:
				_take_from_furnace()
			elif furnace["state"] == "smelting":
				_say("Still working... %d%%" % int(furnace["t"] / furnace["need"] * 100), Workshop.FURNACE)
			else:
				_say("Bring crushed ore here", Workshop.FURNACE)
		"cast":
			if mold["state"] == "ready":
				_face(st)
				_crack_mold()
			elif mold["state"] == "cooling":
				_say("Still cooling...", Workshop.CAST)
			else:
				_say("Bring a crucible of melted metal here", Workshop.CAST)
		"":
			pass
		_:
			_say("Bring something to work on", CENTERS[st])

func _nearest_item(s: Node3D) -> Node3D:
	var best = null
	var bd = 1.2
	for it in items:
		if not is_instance_valid(it) or it.holder != null:
			continue
		var d = Vector2(it.global_position.x, it.global_position.z).distance_to(Vector2(s.global_position.x, s.global_position.z))
		if d < bd:
			bd = d
			best = it
	return best

func _spawn_item(job: Dictionary) -> Node3D:
	var it = Item.new()
	root.add_child(it)
	it.setup(job)
	items.append(it)
	return it

func _start_job() -> void:
	var tk = null
	for t in tickets:
		if not t["started"]:
			tk = t
			break
	if tk == null:
		_say("Nobody's waiting on new ore" if not tickets.is_empty() else "No orders yet!", Workshop.ROCK)
		return
	tk["started"] = true
	var job = {"id": tk["id"], "ticket": tk["id"], "weapon": tk["weapon"], "tier": tk["tier"],
		"stages": BK.shop_stages(tk["weapon"], tk["tier"]), "si": 0, "scores": []}
	var sc = await _play(job["stages"][0]["games"], job)
	if over:
		return
	job["scores"].append_array(sc)
	job["si"] = 1
	tk["stage"] = 1
	var it = _spawn_item(job)
	smith.take(it)

func _work(st: String, h: Node3D) -> void:
	var job: Dictionary = h.job
	var stage: Dictionary = h.stage()
	if st == "furnace" and furnace["state"] != "idle":
		_say("The furnace is full!", Workshop.FURNACE)
		return
	if st == "cast" and mold["state"] != "idle":
		_say("The mold is still in use!", Workshop.CAST)
		return
	var sc = await _play(stage["games"], job)
	if over or not is_instance_valid(h):
		return
	job["scores"].append_array(sc)
	_ticket_stage(job)
	if stage.has("wait"):
		# The station keeps it and works on it by itself.
		smith.held = null
		h.holder = null
		items.erase(h)
		h.queue_free()
		if stage["wait"] == "smelt":
			furnace = {"job": job, "state": "smelting", "t": 0.0, "need": BK.SHOP["smelt"] + BK.SHOP["smelt_per_tier"] * job["tier"], "over": 0.0, "burn": 0.0}
			ws.fire_puff()
		else:
			mold = {"job": job, "state": "cooling", "t": 0.0, "need": BK.SHOP["cool"] + BK.SHOP["cool_per_tier"] * job["tier"]}
			_show_mold(job)
		return
	job["si"] += 1
	_ticket_stage(job)
	h.refresh()

func _take_from_furnace() -> void:
	var job: Dictionary = furnace["job"]
	if furnace["burn"] > 0.0 and not job["scores"].is_empty():
		job["scores"][-1] = maxf(0.0, job["scores"][-1] - furnace["burn"])
		_say("Scorched! -%d" % int(furnace["burn"]), Workshop.FURNACE, Color(1.0, 0.5, 0.3))
	furnace = {"job": null, "state": "idle", "t": 0.0, "need": 1.0, "over": 0.0, "burn": 0.0}
	ws.pop_cap()
	ws.set_fire(0.25)
	job["si"] += 1
	_ticket_stage(job)
	var it = _spawn_item(job)
	smith.take(it)

func _show_mold(job: Dictionary) -> void:
	if mold_prop:
		mold_prop.queue_free()
	mold_prop = Node3D.new()
	root.add_child(mold_prop)
	var box = Build.box(Vector3(1.4, 0.16, 0.7), Color(0.72, 0.6, 0.42))
	mold_prop.add_child(box)
	var w = BK.fitted(BK.WEAPONS[job["weapon"]]["model"], minf(BK.WEAPONS[job["weapon"]]["len"], 1.2))
	if w:
		w.rotation_degrees = Vector3(90, 0, -90)
		w.position = Vector3(0, 0.09, 0)
		w.scale = Vector3(1, 1, 0.3)
		mold_prop.add_child(w)
		mold_prop.set_meta("mat", BK.tint(w, BK.heat_color(0.8), 0.8, 1.2, BK.heat_color(0.8)))
	mold_prop.global_position = Workshop.CAST + Vector3(0.2, 1.1, 0.05)

func _crack_mold() -> void:
	var job: Dictionary = mold["job"]
	job["si"] += 1   # past the pour: now the crack stage
	if mold_prop:
		mold_prop.visible = false
	var sc = await _play(job["stages"][job["si"]]["games"], job)
	if over:
		return
	job["scores"].append_array(sc)
	mold = {"job": null, "state": "idle", "t": 0.0, "need": 1.0}
	if mold_prop:
		mold_prop.queue_free()
		mold_prop = null
	job["si"] += 1
	_ticket_stage(job)
	var it = _spawn_item(job)
	smith.take(it)

func _ticket_stage(job: Dictionary) -> void:
	for tk in tickets:
		if tk["id"] == job["ticket"]:
			tk["stage"] = job["si"]

func _deliver(h: Node3D) -> void:
	var job: Dictionary = h.job
	var tk = null
	for t in tickets:
		if t["id"] == job["ticket"]:
			tk = t
	if tk == null:
		for t in tickets:
			if t["weapon"] == job["weapon"] and t["tier"] == job["tier"]:
				tk = t
				break
	var score = 0.0
	for v in job["scores"]:
		score += v
	score /= maxf(1.0, job["scores"].size())
	var m = BK.medal(score)
	smith.held = null
	items.erase(h)
	h.queue_free()
	var base = BK.WEAPONS[job["weapon"]]["pay"] * BK.MATERIALS[job["tier"]]["pay"] * m["pay"]
	if tk == null:
		# Their customer gave up: it goes on the rack for a quarter of the price.
		var sale = int(round(base * 0.25))
		Save.data["coins"] = main.coins() + sale
		Save.save_game()
		_say("Sold off the rack: +%d" % sale, SPOTS["counter"], Color(1.0, 0.85, 0.3))
		hud.set_top("Day %d: %s" % [day + 1, BK.DAYS[day]["name"]], main.coins())
		return
	var patience = clampf(tk["t"] / tk["max"], 0.0, 1.0)
	var pay = int(round(base * (1.0 - BK.SHOP["patience_pay"] + BK.SHOP["patience_pay"] * patience)))
	if tk["who"] == "hood":
		pay *= 2
	Save.data["coins"] = main.coins() + pay
	Save.record(job["weapon"], job["tier"], score)
	Save.save_game()
	results.append(score)
	tickets.erase(tk)
	hud.set_top("Day %d: %s" % [day + 1, BK.DAYS[day]["name"]], main.coins())
	var c = BK.CUSTOMERS[tk["who"]]
	var a: Actor = tk["actor"]
	hud.big(m["name"], m["color"], 1.6, 90)
	Sfx.play("fanfare" if m["id"] in ["gold", "silver"] else "bad")
	hud.float_text("+%d coins" % pay, ws.to_screen(a.global_position + Vector3(0, 2.0, 0)), Color(1.0, 0.85, 0.3), 36)
	hud.mentor_say(BK.say(BK.MENTOR[m["id"]]), 2.5)
	var line = c["gold"] if m["id"] == "gold" else (c["ok"] if m["id"] != "scrap" else c["bad"])
	tk["bubble"].text = line
	var show = BK.fitted(BK.WEAPONS[job["weapon"]]["model"], 1.0)
	if show:
		a.hold(show)
		BK.tint(show, BK.MATERIALS[job["tier"]]["color"], 0.45)
	if m["id"] in ["gold", "silver"]:
		a.cheer()
	elif m["id"] == "scrap":
		a.sulk()
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(a):
			a.walk_to(a.global_position + Vector3(9, 0, 1.5), 3.5, func(): a.queue_free()))
	if tickets.is_empty():
		spawn_t = minf(spawn_t, 3.0)

# --- Minigames ----------------------------------------------------------------------------
## Zoom in and play these minigames one after another. The shop keeps running meanwhile.
func _play(games: Array, job: Dictionary) -> Array:
	busy = true
	smith.auto_target = null
	smith.visible = false
	smith.set_process(false)
	if smith.held:
		smith.held.visible = false
	var out = []
	for g in games:
		var order = {"customer": "", "weapon": job["weapon"], "tier": job["tier"], "crack_only": g == "crack", "pour_only": g == "pour"}
		var game: Game = main.GAMES[g].new()
		game.init(main, ws, order, g)
		hud.game_layer.add_child(game)
		hud.game_layer.move_child(game, 0)
		main.game = game
		ws.set_shot(game.shot(), 0.6)
		game.prepare()
		var info = BK.step_info(g, job["tier"])
		if not seen.has(g):
			seen[g] = true
			await hud.intro(info["title"], info["how"])
		else:
			hud.big(info["title"], Color(1.0, 0.85, 0.4), 0.9, 60)
			await get_tree().create_timer(0.8).timeout
		if over or not is_instance_valid(game):
			return out
		Sfx.play("tick", 1.2)
		game.start()
		if main.autoplay > 0.0:
			get_tree().create_timer(main.autoplay).timeout.connect(func():
				if is_instance_valid(game):
					game.finish(randf_range(55.0, 100.0)))
		var score: float = await game.finished
		if over:
			return out
		var gr = BK.step_grade(score)
		Sfx.play("bad" if gr["name"] == "OOPS..." else "good")
		hud.big(gr["name"], gr["color"], 1.0)
		if randf() < 0.6:
			hud.mentor_say(BK.say(BK.MENTOR[gr["name"]]), 1.8)
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(game):
			game.queue_free()
		main.game = null
		ws.clear_props()
		ws.set_trip_flag(-1.0)
		out.append(score)
		if over:
			return out
	ws.set_shot("shop", 0.6)
	smith.visible = true
	smith.set_process(true)
	if smith.held:
		smith.held.visible = true
	busy = false
	return out

# --- Station camera -------------------------------------------------------------------------
func _running() -> Array:
	var r = []
	if furnace["state"] != "idle":
		r.append("furnace")
	if mold["state"] != "idle":
		r.append("cast")
	return r

func _update_pip() -> void:
	var run = _running()
	pip.visible = busy and not run.is_empty()
	if not pip.visible:
		return
	if not pip_target in run:
		pip_target = run[0]
	var sh = PIP_SHOTS[pip_target]
	pip_cam.global_transform = Transform3D(Basis(), sh[0]).looking_at(sh[1], Vector3.UP)
	var lab = furnace_label if pip_target == "furnace" else mold_label
	pip_title.text = "%s: %s%s" % [BK.STATION_NAMES[pip_target], lab.text, "   (Tab: next)" if run.size() > 1 else ""]
	pip_title.add_theme_color_override("font_color", lab.modulate)

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_TAB:
		var run = _running()
		if not run.is_empty():
			var i = run.find(pip_target)
			pip_target = run[(i + 1) % run.size()]
		get_viewport().set_input_as_handled()

## Click (or tap) the floor to walk there, or a station to walk over and use it.
func _unhandled_input(e: InputEvent) -> void:
	if busy or over:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p = ws.pointer_on_plane(e.position, 0.0)
		if p == null:
			return
		var best = ""
		var bd = 1.6
		for k in CENTERS:
			var c: Vector3 = CENTERS[k]
			var d = Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z))
			if k == "counter":
				d = 0.0 if (absf(p.x - 0.4) < 2.6 and absf(p.z - Workshop.COUNTER_Z) < 0.9) else 99.0
			if d < bd:
				bd = d
				best = k
		if best != "":
			var spot: Vector3 = SPOTS[best]
			if best == "counter":
				spot = Vector3(clampf(p.x, -1.8, 2.6), 0, SPOTS["counter"].z)
			pending = best
			smith.auto_target = spot
		else:
			pending = "floor" if _item_at(p) else null
			smith.auto_target = Vector3(p.x, 0, p.z)
		stuck_t = 0.0

func _item_at(p: Vector3) -> bool:
	for it in items:
		if is_instance_valid(it) and it.holder == null and Vector2(it.global_position.x, it.global_position.z).distance_to(Vector2(p.x, p.z)) < 0.8:
			return true
	return false

# --- Where to go next ---------------------------------------------------------------------
func next_station() -> String:
	if smith.held:
		return smith.held.stage()["at"]
	if furnace["state"] in ["ready", "burning"]:
		return "furnace"
	if mold["state"] == "ready":
		return "cast"
	if floor_item():
		return "item"
	for t in tickets:
		if not t["started"]:
			return "rock"
	return ""

## Something set down on the floor, waiting to be picked up again.
func floor_item() -> Node3D:
	for it in items:
		if is_instance_valid(it) and it.holder == null:
			return it
	return null

func _update_marker() -> void:
	var st = "" if busy else next_station()
	marker.visible = st != ""
	marker_label.visible = st != ""
	if st == "":
		return
	var bob = sin(Time.get_ticks_msec() * 0.006)
	var p: Vector3
	var top: Vector3
	var name: String
	if st == "item":
		p = floor_item().global_position
		p.y = 0.0
		top = p + Vector3(0, 1.6, 0)
		name = "Pick up"
	else:
		p = SPOTS[st]
		top = CENTERS[st] + Vector3(0, 3.0, 0.3)
		name = BK.STATION_NAMES[st]
	marker.global_position = p + Vector3(0, 0.05, 0)
	marker.scale = Vector3(1.0 + 0.08 * bob, 0.3, 1.0 + 0.08 * bob)
	marker_label.global_position = top + Vector3(0, 0.15 * bob, 0)
	marker_label.text = "v " + name + " v"

func _end_day() -> void:
	over = true
	smith.set_process(false)
	await get_tree().create_timer(1.2).timeout
	main.shop_day_done(results)
