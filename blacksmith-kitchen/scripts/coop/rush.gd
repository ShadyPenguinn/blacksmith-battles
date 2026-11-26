extends Node
## Rush Hour: up to four smiths on one screen, in the same workshop. Tickets come in at the
## counter. Ore from the rock > furnace (stomp the bellows together) > the hot ingot shoots out
## of the chimney: carry it with tongs (hold USE) > anvil (hit on the beat) > quench tank (pull
## it out in time, refill with the bucket from the well) > grindstone (mash USE) > counter.

const Smith = preload("res://scripts/coop/smith.gd")
const Item = preload("res://scripts/coop/item.gd")

var main: Node
var ws: Workshop
var smiths := []
var items := []
var orders := []           # {weapon, t, max, actor, slot, id}
var time_left := 0.0
var coins := 0
var served := 0
var lost := 0
var order_t := 3.0
var next_id := 0
var over := false
var overlay: Control

# Station state
var heat := 0.0
var last_side := 0
var load := 0              # ore loads in the furnace
var smelt := 0.0
var hot_t := 0.0
var anvil_item: Node3D = null
var anvil_hits := 0
var marker := 0.0
var marker_dir := 1.0
var tank_item: Node3D = null
var tank_t := 0.0
var water := 1.0
var grind_item: Node3D = null
var grind_n := 0
var well := Vector3(-10.4, 0, -1.0)
var obstacles := []        # [center (xz), radius]

const SPOTS := {
	"rock": Workshop.ROCK + Vector3(1.4, 0, 0.6),
	"furnace": Workshop.FURNACE + Vector3(0, 0, 1.7),
	"bellows_l": Workshop.FURNACE + Vector3(-2.05, 0, 1.0),
	"bellows_r": Workshop.FURNACE + Vector3(2.05, 0, 1.0),
	"anvil": Workshop.ANVIL + Vector3(0, 0, 0.9),
	"tank": Workshop.TANK + Vector3(0, 0, 1.2),
	"grind": Workshop.GRIND + Vector3(0, 0, 1.4),
	"counter": Vector3(1.0, 0, Workshop.COUNTER_Z - 0.9),
}

func setup(p_main: Node, n: int) -> void:
	main = p_main
	ws = main.ws
	time_left = BK.RUSH["time"]
	ws.clear_props()
	ws.use_lever(false)
	ws.set_fire(0.0)
	ws.mentor.visible = false
	ws.shots["rush"] = [Vector3(-0.5, 15.5, 11.5), Vector3(-0.5, 0, -0.2), 46.0]
	ws.set_shot("rush", 1.0)
	main.hud.show_top(true)
	main.hud.clear_steps()
	_build_well()
	obstacles = [
		[Vector2(Workshop.FURNACE.x, Workshop.FURNACE.z), 1.3],
		[Vector2(Workshop.FURNACE.x - 2.05, Workshop.FURNACE.z), 1.0],
		[Vector2(Workshop.FURNACE.x + 2.05, Workshop.FURNACE.z), 1.0],
		[Vector2(Workshop.ANVIL.x, Workshop.ANVIL.z), 0.75],
		[Vector2(Workshop.TRIP.x, Workshop.TRIP.z), 1.0],
		[Vector2(Workshop.TANK.x, Workshop.TANK.z), 1.0],
		[Vector2(Workshop.GRIND.x, Workshop.GRIND.z), 1.0],
		[Vector2(Workshop.BENCH.x, Workshop.BENCH.z), 1.1],
		[Vector2(Workshop.ROCK.x, Workshop.ROCK.z), 1.1],
		[Vector2(well.x, well.z), 0.8],
	]
	for i in n:
		var s = Smith.new()
		add_child(s)
		s.setup(self, i, n)
		s.global_position = Vector3(-2.0 + i * 1.2, 0, 1.6)
		smiths.append(s)
	var bucket = spawn("bucket", Workshop.TANK + Vector3(-1.4, 0, 1.0))
	bucket.water = false
	overlay = preload("res://scripts/coop/rush_overlay.gd").new()
	overlay.rush = self
	main.hud.game_layer.add_child(overlay)
	main.hud.big("Rush Hour!", Color(1.0, 0.8, 0.3), 1.6)
	_new_order()

func _build_well() -> void:
	var w = Node3D.new()
	w.name = "Well"
	ws.props.add_child(w)
	w.global_position = well
	var stone = Build.cyl(0.75, 0.8, Color(0.55, 0.55, 0.58))
	stone.position.y = 0.4
	w.add_child(stone)
	var water_disc = Build.cyl(0.6, 0.05, Color(0.35, 0.65, 1.0), 0.4)
	water_disc.position.y = 0.81
	w.add_child(water_disc)
	for x in [-0.65, 0.65]:
		var post = Build.box(Vector3(0.14, 1.6, 0.14), Color(0.45, 0.3, 0.18))
		post.position = Vector3(x, 1.2, 0)
		w.add_child(post)
	var roof = Build.box(Vector3(1.8, 0.12, 1.1), Color(0.6, 0.25, 0.18))
	roof.position.y = 2.05
	roof.rotation_degrees.x = 0
	w.add_child(roof)
	var l = Build.label("WELL", 40)
	l.position.y = 2.6
	w.add_child(l)

func spawn(kind: String, pos: Vector3, weapon := "") -> Node3D:
	var it = Item.new()
	ws.props.add_child(it)
	it.setup(self, kind, weapon)
	it.global_position = pos
	items.append(it)
	return it

func remove_item(it: Node3D) -> void:
	items.erase(it)
	if is_instance_valid(it):
		it.queue_free()

func tier() -> int:
	return 0

# --- Orders -----------------------------------------------------------------------
func _new_order() -> void:
	if orders.size() >= BK.RUSH["max_orders"]:
		return
	var w = BK.RUSH["weapons"][randi() % BK.RUSH["weapons"].size()]
	var slot = 0
	var used = []
	for o in orders:
		used.append(o["slot"])
	while slot in used:
		slot += 1
	var keys = BK.CUSTOMERS.keys()
	keys.erase("grizzle")
	var c = BK.CUSTOMERS[keys[randi() % keys.size()]]
	var a = Actor.new()
	ws.props.add_child(a)
	a.setup(c["model"])
	var spot = Vector3(-1.4 + slot * 1.6, 0, Workshop.COUNTER_Z + 1.0)
	a.global_position = spot + Vector3(-9, 0, 1.5)
	a.walk_to(spot, 3.5, func():
		if is_instance_valid(a):
			a.face(spot + Vector3(0, 0, -3)))
	orders.append({"weapon": w, "t": BK.RUSH["order_time"], "max": BK.RUSH["order_time"], "actor": a, "slot": slot, "id": next_id, "name": c["name"]})
	next_id += 1

func _deliver(it: Node3D) -> bool:
	for o in orders:
		if o["weapon"] == it.weapon:
			var pay = BK.WEAPONS[o["weapon"]]["pay"] + int(o["t"] / o["max"] * 20.0)
			if it.brittle:
				pay = int(pay * 0.5)
			coins += pay
			Sfx.play("fanfare")
			served += 1
			var a: Actor = o["actor"]
			a.cheer()
			main.hud.float_text("+%d" % pay, ws.to_screen(a.global_position + Vector3(0, 2.2, 0)), Color(1.0, 0.85, 0.3), 40)
			orders.erase(o)
			get_tree().create_timer(0.8).timeout.connect(func():
				if is_instance_valid(a):
					a.walk_to(a.global_position + Vector3(9, 0, 1.5), 3.5, func(): a.queue_free()))
			if orders.is_empty():
				order_t = minf(order_t, 2.0)
			return true
	return false

# --- Smith actions ------------------------------------------------------------------
func near(s: Node3D, spot: Vector3, r := 1.4) -> bool:
	return Vector2(s.global_position.x, s.global_position.z).distance_to(Vector2(spot.x, spot.z)) < r

## GRAB: pick up / put down / hand in.
func grab(s: Node3D) -> void:
	var h: Node3D = s.held
	if h:
		_put(s, h)
		return
	# Take something off a station first.
	if anvil_item and near(s, SPOTS["anvil"]) and anvil_item.kind == "blank":
		s.take(anvil_item)
		anvil_item = null
		return
	if tank_item and near(s, SPOTS["tank"], 1.6):
		if tank_t < BK.RUSH["quench_window"][0]:
			main.hud.float_text("Still sizzling!", ws.to_screen(Workshop.TANK + Vector3(0, 2, 0)), Color(1, 0.7, 0.4), 30)
			return
		tank_item.kind = "quenched"
		tank_item.brittle = tank_t > BK.RUSH["quench_window"][1]
		main.hud.float_text("Brittle!" if tank_item.brittle else "Tempered!", ws.to_screen(Workshop.TANK + Vector3(0, 2, 0)), Color(0.6, 0.85, 1.0), 32)
		tank_item.refresh()
		s.take(tank_item)
		tank_item = null
		return
	if grind_item and grind_item.kind == "weapon" and near(s, SPOTS["grind"], 1.6):
		s.take(grind_item)
		grind_item = null
		return
	if near(s, SPOTS["rock"], 1.8):
		var ore = spawn("ore", s.global_position)
		s.take(ore)
		ws.shake(0.03)
		Fx.burst(ws, Workshop.ROCK + Vector3(0, 1, 0), Color(0.85, 0.5, 0.25), 6, 0.8, 3.0, -8.0, 0.4, Vector3.UP, 60.0, true)
		return
	var best = _nearest_item(s)
	if best:
		if best.kind == "ingot":
			s.ouch()
			return
		s.take(best)

func _nearest_item(s: Node3D) -> Node3D:
	var best = null
	var bd = 1.3
	for it in items:
		if it.holder != null or it in [anvil_item, tank_item, grind_item]:
			continue
		var d = Vector2(it.global_position.x, it.global_position.z).distance_to(Vector2(s.global_position.x, s.global_position.z))
		if d < bd:
			bd = d
			best = it
	return best

func _put(s: Node3D, h: Node3D) -> void:
	match h.kind:
		"ore", "cold":
			if near(s, SPOTS["furnace"], 1.8):
				s.drop()
				remove_item(h)
				load += 1
				ws.fire_puff()
				return
		"ingot":
			if anvil_item == null and near(s, SPOTS["anvil"]):
				_place_on_anvil(s, h)
				return
		"blank":
			if tank_item == null and near(s, SPOTS["tank"], 1.6):
				if water < BK.RUSH["water_per_quench"] - 0.01:
					main.hud.float_text("No water! Use the bucket", ws.to_screen(Workshop.TANK + Vector3(0, 2, 0)), Color(1, 0.6, 0.4), 30)
					return
				s.drop()
				tank_item = h
				tank_t = 0.0
				water -= BK.RUSH["water_per_quench"]
				h.global_position = Workshop.TANK + Vector3(0, 0.9, 0)
				Sfx.play("sizzle")
				Fx.burst(ws, Workshop.TANK + Vector3(0, 1.2, 0), Color(0.95, 0.95, 0.95, 0.7), 20, 1.8, 3.0, 1.5, 1.2)
				return
		"quenched":
			if grind_item == null and near(s, SPOTS["grind"], 1.6):
				s.drop()
				grind_item = h
				grind_n = 0
				h.global_position = Workshop.GRIND + Vector3(0.4, 1.4, 0)
				return
		"weapon":
			if near(s, SPOTS["counter"], 3.2) and s.global_position.z > Workshop.COUNTER_Z - 2.0:
				if _deliver(h):
					s.drop()
					remove_item(h)
				else:
					main.hud.float_text("Nobody ordered that!", ws.to_screen(s.global_position + Vector3(0, 2.4, 0)), Color(1, 0.6, 0.4), 30)
				return
	s.drop()

func _place_on_anvil(s: Node3D, h: Node3D) -> void:
	s.drop()
	anvil_item = h
	anvil_hits = 0
	h.global_position = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.08, 0)
	# Shape it for the oldest ticket nobody's working on yet.
	var taken = []
	for it in items:
		if it.weapon != "" and it != h:
			taken.append(it.weapon)
	h.weapon = BK.RUSH["weapons"][0]
	for o in orders:
		if o["weapon"] in taken:
			taken.erase(o["weapon"])
			continue
		h.weapon = o["weapon"]
		break

## USE: stomp a bellows, swing the hammer, pedal the grindstone, fill/pour the bucket.
## Tongs are "hold USE" and are handled by the smith.
func use(s: Node3D) -> void:
	var h: Node3D = s.held
	if h and h.kind == "bucket":
		if near(s, well, 1.8):
			h.water = true
			h.refresh()
			main.hud.float_text("Filled!", ws.to_screen(well + Vector3(0, 2, 0)), Color(0.6, 0.85, 1.0), 30)
		elif h.water and near(s, SPOTS["tank"], 1.8):
			h.water = false
			h.refresh()
			water = minf(1.0, water + 0.7)
			Fx.burst(ws, Workshop.TANK + Vector3(0, 1.3, 0), Color(0.4, 0.7, 1.0), 16, 0.8, 3.0, -8.0, 0.6)
		return
	for side in [-1, 1]:
		if near(s, SPOTS["bellows_l" if side < 0 else "bellows_r"], 1.3):
			s.hop()
			ws.stomp(side)
			Sfx.play("puff")
			var gain = BK.RUSH["heat_per_stomp"] * (0.25 if side == last_side else 1.0)
			last_side = side
			heat = minf(110.0, heat + gain)
			return
	if anvil_item and anvil_item.kind == "ingot" and near(s, SPOTS["anvil"]):
		s.act("Hammer")
		var off = absf(marker - 0.5)
		if off < 0.15:
			anvil_hits += 1
			Sfx.play("clang")
			Fx.burst(ws, Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.2, 0), Color(1.0, 0.8, 0.3), 14, 0.5, 5.0, -10.0, 0.4)
			main.hud.float_text("CLANG!", ws.to_screen(Workshop.ANVIL + Vector3(0, 2.0, 0)), Color(1.0, 0.85, 0.3), 30)
			if anvil_hits >= BK.RUSH["hits"].get(anvil_item.weapon, 4):
				anvil_item.kind = "blank"
				anvil_item.refresh()
		else:
			Sfx.play("thud", 1.4)
			main.hud.float_text("clunk", ws.to_screen(Workshop.ANVIL + Vector3(0, 2.0, 0)), Color(0.8, 0.8, 0.8), 24)
		return
	if grind_item and grind_item.kind == "quenched" and near(s, SPOTS["grind"], 1.6):
		s.act("Interact")
		grind_n += 1
		Sfx.play("tick", 0.8)
		if ws.grind_wheel:
			ws.grind_wheel.rotate_object_local(Vector3.RIGHT, 0.8)
		Fx.burst(ws, Workshop.GRIND + Vector3(0.1, 1.3, 0), Color(1.0, 0.8, 0.35), 6, 0.35, 5.0, -9.0, 0.35, Vector3(1, 0.6, 0), 30.0)
		if grind_n >= BK.RUSH["grinds"].get(grind_item.weapon, 7):
			grind_item.kind = "weapon"
			grind_item.refresh()
			main.hud.float_text("Done! To the counter!", ws.to_screen(Workshop.GRIND + Vector3(0, 2.2, 0)), Color(0.5, 1.0, 0.5), 30)
		return

## Called when a smith with tongs lets go of a hot ingot.
func tongs_release(s: Node3D, it: Node3D) -> void:
	if anvil_item == null and near(s, SPOTS["anvil"]):
		_place_on_anvil(s, it)
	else:
		s.drop()

func tongs_target(s: Node3D) -> Node3D:
	var best = null
	var bd = 1.4
	for it in items:
		if it.kind != "ingot" or it.holder != null or it == anvil_item:
			continue
		var d = Vector2(it.global_position.x, it.global_position.z).distance_to(Vector2(s.global_position.x, s.global_position.z))
		if d < bd:
			bd = d
			best = it
	return best

# --- Tick ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if over:
		return
	time_left -= delta
	main.hud.set_top("Rush Hour  %d:%02d" % [int(maxf(0, time_left)) / 60, int(maxf(0, time_left)) % 60], coins)
	if time_left <= 0.0:
		_end()
		return
	order_t -= delta
	if order_t <= 0.0:
		_new_order()
		order_t = BK.RUSH["order_gap"] * randf_range(0.8, 1.2)
	for o in orders.duplicate():
		o["t"] -= delta
		if o["t"] <= 0.0:
			lost += 1
			var a: Actor = o["actor"]
			a.sulk()
			Sfx.play("bad")
			main.hud.float_text("Stormed off!", ws.to_screen(a.global_position + Vector3(0, 2.2, 0)), Color(1, 0.45, 0.35), 32)
			orders.erase(o)
			get_tree().create_timer(0.8).timeout.connect(func():
				if is_instance_valid(a):
					a.walk_to(a.global_position + Vector3(9, 0, 1.5), 4.0, func(): a.queue_free()))
	_furnace(delta)
	marker += marker_dir * 1.3 * delta
	if marker > 1.0 or marker < 0.0:
		marker_dir *= -1.0
		marker = clampf(marker, 0.0, 1.0)
	if tank_item:
		tank_t += delta
		if randf() < delta * 10.0:
			Fx.burst(ws, Workshop.TANK + Vector3(0, 1.2, 0), Color(0.95, 0.95, 0.95, 0.6), 2, 1.4, 2.0, 1.5, 0.9)
	for it in items.duplicate():
		if it.kind == "ingot" and it != anvil_item:
			it.hot -= delta
			if it.hot <= 0.0:
				if it.holder:
					it.holder.drop()
				it.kind = "cold"
				it.refresh()

func _furnace(delta: float) -> void:
	heat = maxf(0.0, heat - 7.0 * delta)
	var band = BK.RUSH["heat_band"]
	var too_hot = heat > band[1] + 15.0
	ws.set_fire(heat / 100.0, too_hot)
	if too_hot:
		hot_t += delta
		if hot_t > 1.2:
			_burp()
	else:
		hot_t = 0.0
	if load > 0 and heat >= band[0] and heat <= band[1]:
		smelt += delta
		if smelt >= BK.RUSH["smelt_need"]:
			smelt = 0.0
			load -= 1
			_launch_ingot()

func _launch_ingot() -> void:
	ws.pop_cap()
	var top = ws.spout.global_position if ws.spout else Workshop.FURNACE + Vector3(0, 3.5, 0)
	var land = Vector3(randf_range(-6.0, -1.0), 0.15, randf_range(-1.6, 1.5))
	var it = spawn("ingot", top)
	var tw = it.create_tween()
	tw.tween_property(it, "global_position", (top + land) * 0.5 + Vector3(0, 2.0, 0), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(it, "global_position", land, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Fx.dust(ws, land, 8, 1.0))

func _burp() -> void:
	hot_t = 0.0
	heat = 20.0
	if load > 0:
		load -= 1
		main.hud.float_text("SLAG! The batch burned!", ws.to_screen(Workshop.FURNACE + Vector3(0, 3, 0)), Color(1, 0.4, 0.3), 36)
	ws.shake(0.3)
	Sfx.play("thud", 0.6, 2.0)
	Fx.burst(ws, Workshop.FURNACE + Vector3(0, 1.0, 1.4), Color(1.0, 0.45, 0.1), 40, 2.0, 7.0, 2.0, 0.7, Vector3(0, 0.5, 1), 70.0)
	for s in smiths:
		var d = s.global_position - (Workshop.FURNACE + Vector3(0, 0, 1.2))
		d.y = 0
		if d.length() < 4.5:
			s.knock(d.normalized() * 7.0)

func _end() -> void:
	over = true
	for s in smiths:
		s.set_process(false)
	main.rush_over(coins)
	var stars = 0
	for need in BK.RUSH["stars"]:
		if coins >= need:
			stars += 1
	var v = main.hud.panel("Shift over!", 560)
	var l = main.hud.label("Coins: %d   Served: %d   Stormed off: %d\nStars: %s (%d / 3)" % [coins, served, lost, "*".repeat(stars), stars], 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	main.hud.button(v, "Again!", func():
		var n = smiths.size()
		main._to_menu()
		main.start_rush(n))
	main.hud.button(v, "Main menu", main._to_menu)

func _exit_tree() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	if ws and is_instance_valid(ws):
		ws.mentor.visible = true
		ws.clear_props()
		ws.set_fire(0.3)
