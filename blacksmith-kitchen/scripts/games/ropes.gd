extends Game
## Rope Drop: the giant hammer from Storm Forge. Each rope only lifts so high, so harder
## metals need a second, third or fourth rope. Haul it past the red flag and let go.

var ropes := 1
var L := 0.7
var pulled := [0.0, 0.0, 0.0, 0.0]
var k := 0                   # rope in hand
var state := "ready"         # ready, pull, tied, fall
var need := 1.0
var drops_left := 3
var scores := []
var head_h := 0.0
var fall_v := 0.0
var drop_from := 0.0
var key_hold := false
var mouse_hold := false
var bar: Node3D
var bar_mat: StandardMaterial3D
var tied_t := 0.0

func shot() -> String:
	return "rope"

func prepare() -> void:
	L = BK.ROPES["rope_lift"]
	ropes = clampi(1 + (tier + 1) / 2, 1, 4)
	drops_left = BK.ROPES["drops"]
	bar = make_bar(0.6)
	bar_mat = heat_tint(bar, 0.85)
	bar.global_position = Workshop.TRIP + Vector3(0, ws.trip_anvil_top + 0.08, 0)
	bar.rotation_degrees.y = 90
	_new_drop()

func _new_drop() -> void:
	pulled = [0.0, 0.0, 0.0, 0.0]
	k = 0
	head_h = 0.0
	need = randf_range((ropes - 1) * L + 0.25 * L, ropes * L - 0.4 * L)
	ws.set_trip_flag(need)
	ws.set_trip(0.0, pulled, ropes)
	state = "ready"

func _sum() -> float:
	var s = 0.0
	for v in pulled:
		s += v
	return s

func on_input(e: InputEvent) -> void:
	if is_press(e):
		mouse_hold = true
		_grab()
	elif is_release(e):
		mouse_hold = false
		_let_go()
	elif e is InputEventMouseMotion and mouse_hold and state == "pull":
		pulled[k] = clampf(pulled[k] + e.relative.y / BK.ROPES["pull_px"] * L, 0.0, L)
	elif e is InputEventKey and e.physical_keycode in [KEY_SPACE, KEY_S, KEY_DOWN] and not e.echo:
		if e.pressed:
			key_hold = true
			_grab()
		else:
			key_hold = false
			_let_go()

func _grab() -> void:
	if not active:
		return
	if state == "ready" or state == "tied":
		state = "pull"

func _let_go() -> void:
	if state != "pull":
		return
	if _sum() < 0.05:
		state = "ready" if k == 0 else "tied"
		return
	state = "fall"
	drop_from = _sum()
	fall_v = 0.0

func tick(delta: float) -> void:
	match state:
		"pull":
			if key_hold:
				pulled[k] = minf(L, pulled[k] + BK.ROPES["key_rate"] * delta)
			pulled[k] = maxf(0.0, pulled[k] - (BK.ROPES["slip"] + BK.ROPES["slip_per_tier"] * tier) * delta)
			if pulled[k] >= L - 0.001 and k < ropes - 1:
				k += 1
				state = "tied"
				tied_t = 0.0
				popup("Tied off! Grab rope %d!" % (k + 1), Vector2(vsize().x * 0.5, vsize().y * 0.3), Color(1.0, 0.9, 0.5), 34)
				if key_hold:
					get_tree().create_timer(0.3).timeout.connect(func():
						if state == "tied" and key_hold:
							state = "pull")
			head_h = _sum()
		"tied":
			tied_t += delta
		"fall":
			fall_v += 26.0 * delta
			head_h = maxf(0.0, head_h - fall_v * delta)
			for i in 4:
				pulled[i] = 0.0
			if head_h <= 0.0:
				_slam()
	ws.set_trip(head_h, pulled, ropes)

func _slam() -> void:
	var h = drop_from
	var band = BK.ROPES["band"]
	var s = 0.0
	var label = ""
	var col = Color.WHITE
	if h < need:
		s = 45.0 * h / need
		label = "Too low! Barely a dent."
		col = Color(0.95, 0.45, 0.35)
	elif h <= need + band:
		s = 100.0 - absf(h - (need + band * 0.5)) / (band * 0.5) * 12.0
		label = "SLAM! PERFECT!" if s >= 92.0 else "SLAM! Great!"
		col = Color(1.0, 0.85, 0.2)
	else:
		s = maxf(35.0, 85.0 - (h - need - band) * 70.0)
		label = "Whoa, a bit too hard!"
		col = Color(0.6, 0.8, 1.0)
	scores.append(s)
	popup(label, Vector2(vsize().x * 0.5, vsize().y * 0.3), col, 40)
	ws.shake(0.12 + h * 0.08)
	Sfx.play("thud")
	Sfx.play("clang", 0.7)
	var p = Workshop.TRIP + Vector3(0, ws.trip_anvil_top + 0.15, 0)
	Fx.burst(ws, p, Color(1.0, 0.8, 0.3), 24, 0.7, 7.0, -10.0, 0.5, Vector3.UP, 85.0)
	Fx.dust(ws, Workshop.TRIP + Vector3(0, 0.1, 0.6), 12, 1.5)
	if is_bloom():
		# Slag squirts out of the bloom: dark, glowing drops flying sideways.
		Fx.burst(ws, p, Color(0.35, 0.12, 0.05), 18, 0.8, 6.0, -12.0, 0.6, Vector3(1, 0.4, 0.4), 60.0, true)
		Fx.burst(ws, p, Color(0.35, 0.12, 0.05), 18, 0.8, 6.0, -12.0, 0.6, Vector3(-1, 0.4, 0.4), 60.0, true)
		if drops_left == 1:
			popup("Slag's out!", Vector2(vsize().x * 0.5, vsize().y * 0.42), Color(1.0, 0.6, 0.3), 30)
	drops_left -= 1
	var f = 1.0 - float(drops_left) / float(BK.ROPES["drops"])
	bar.scale = Vector3(1.0 + f * 0.35, 1.0 - f * 0.5, 1.0 + f * 0.5)
	state = "wait"
	if drops_left <= 0:
		active = false
		ws.set_trip_flag(-1.0)
		var avg = 0.0
		for v in scores:
			avg += v
		get_tree().create_timer(0.8).timeout.connect(func(): finish(avg / scores.size()))
	else:
		get_tree().create_timer(0.7).timeout.connect(_new_drop)

func draw_game() -> void:
	var vs = vsize()
	# Height gauge: each rope's share, the flag and the head.
	var r = Rect2(vs.x - 140, vs.y * 0.2, 46, vs.y * 0.52)
	var full = L * ropes + 0.3
	vgauge(r, head_h / full, need / full, (need + BK.ROPES["band"]) / full, Color(1.0, 0.8, 0.2), "HEIGHT")
	for i in range(1, ropes):
		var y = r.end.y - r.size.y * (i * L / full)
		draw_line(Vector2(r.position.x - 8, y), Vector2(r.end.x + 8, y), Color(0.9, 0.8, 0.6), 2)
	var flag_y = r.end.y - r.size.y * (need / full)
	draw_rect(Rect2(r.position.x - 40, flag_y - 10, 26, 20), Color(0.9, 0.15, 0.1))
	# Which rope to grab.
	var hp = ws.to_screen(ws.trip_handles[k].global_position)
	if state == "ready" or state == "tied":
		draw_arc(hp, 40 + 6 * sin(t * 9.0), 0, TAU, 32, Color(1, 0.85, 0.3), 5)
		text(hp + Vector2(0, 70), "HOLD + DRAG DOWN", 26, Color(1, 0.9, 0.5))
	for i in ropes:
		var p = ws.to_screen(ws.trip_handles[i].global_position)
		var done = i < k
		text(p + Vector2(-46, 0), str(i + 1), 26, Color(0.6, 1.0, 0.6) if done else Color.WHITE)
	text(Vector2(vs.x * 0.5, vs.y - 50), "Drops left: %d" % drops_left, 28)
