extends Game
## Fold and Weld (steel and up): grab the right end of the hot bar and drag it over onto the
## left end. Line the ends up, then hammer the fold shut before it cools. Repeat per fold.

const LEN := 0.9
var left_half: Node3D
var flap: Node3D             # pivots on the middle of the bar
var flap_bar: Node3D
var mats := []
var hammer: Node3D
var folds := 1
var fold_i := 0
var phase := "grab"          # grab, drag, weld, wait
var angle := 0.0             # 0 flat .. 1 folded over
var align_scores := []
var weld_scores := []
var welds := 0
var weld_t := 0.0
var swing := 0.0

func shot() -> String:
	return "anvil"

func _mid() -> Vector3:
	return Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.08, 0)

func prepare() -> void:
	folds = maxi(1, BK.MATERIALS[tier]["folds"])
	left_half = make_bar(LEN * 0.5)
	left_half.rotation_degrees.y = 90
	left_half.global_position = _mid() + Vector3(-LEN * 0.25, 0, 0)
	mats.append(heat_tint(left_half, 0.9))
	flap = Node3D.new()
	ws.props.add_child(flap)
	flap.global_position = _pivot()
	flap_bar = make_bar(LEN * 0.5)
	flap_bar.reparent(flap, false)
	flap_bar.rotation_degrees.y = 90
	flap_bar.position = Vector3(LEN * 0.25, -0.06, 0)
	mats.append(heat_tint(flap_bar, 0.9))
	hammer = BK.fitted(BK.M + "tools/hammer.gltf", 0.9)
	ws.props.add_child(hammer)
	_hammer_pose(0.0)

## The fold hinge sits a little above the bar so the folded half lands on top.
func _pivot() -> Vector3:
	return _mid() + Vector3(0, 0.06, 0)

func _hammer_pose(k: float) -> void:
	var top = _mid() + Vector3(0.6, 0.75, 0.35)
	var low = _mid() + Vector3(-0.05, 0.35, 0.1)
	hammer.global_position = top.lerp(low, k)
	hammer.rotation_degrees = Vector3(0, 0, lerpf(-35.0, 70.0, k))

func _end_screen(side: float) -> Vector2:
	return ws.to_screen(_mid() + Vector3(side * LEN * 0.5, 0, 0))

func on_input(e: InputEvent) -> void:
	match phase:
		"grab":
			if is_press(e) and e.position.distance_to(_end_screen(1.0)) < 90.0:
				phase = "drag"
			elif key_down(e, [KEY_A, KEY_LEFT, KEY_SPACE]):
				phase = "drag"   # keyboard: hold A / SPACE to fold, let go to drop
		"drag":
			if e is InputEventMouseMotion:
				var r = _end_screen(1.0)
				var l = _end_screen(-1.0)
				angle = clampf((r.x - e.position.x) / maxf(1.0, r.x - l.x), 0.0, 1.15)
			elif is_release(e) or key_up(e, [KEY_A, KEY_LEFT, KEY_SPACE]):
				_drop()
		"weld":
			if is_press(e) or key_down(e, [KEY_SPACE, KEY_ENTER, KEY_F]):
				_weld_hit()

func tick(delta: float) -> void:
	if phase == "drag" and (Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)):
		angle = minf(1.15, angle + delta * (0.9 + tier * 0.08))
	flap.rotation.z = angle * PI
	if phase == "weld":
		weld_t += delta
		var cool = clampf(1.0 - weld_t / _weld_time(), 0.0, 1.0)
		for m in mats:
			set_heat(m, 0.4 + 0.5 * cool)
		if weld_t >= _weld_time():
			_weld_done()
	if swing > 0.0:
		swing = maxf(0.0, swing - delta * 6.0)
	_hammer_pose(sin(swing * PI) if swing > 0.0 else 0.0)

func _weld_time() -> float:
	return BK.FOLD["weld_time"] + BK.FOLD["weld_time_per_tier"] * maxi(0, tier - 3)

func _drop() -> void:
	if angle < 0.5:
		# Not even halfway: it flops back. Try again.
		popup("Flop!", _end_screen(1.0) + Vector2(0, -60), Color(0.8, 0.8, 0.8), 30)
		create_tween().tween_property(self, "angle", 0.0, 0.2)
		phase = "grab"
		return
	var err = absf(angle - 1.0)
	var s = clampf(100.0 - err * 260.0, 10.0, 100.0)
	align_scores.append(s)
	var label = "Lined up!" if s >= 90.0 else ("Close!" if s >= 65.0 else "Wonky fold!")
	popup(label, Vector2(vsize().x * 0.5, vsize().y * 0.3), Color(1.0, 0.85, 0.3) if s >= 65.0 else Color(1.0, 0.6, 0.3), 40)
	# The flap settles where it landed, showing any overhang.
	var tw = create_tween()
	tw.tween_property(self, "angle", 1.0, 0.12)
	tw.parallel().tween_property(flap, "global_position", _pivot() + Vector3((angle - 1.0) * -LEN * 0.5, 0, 0), 0.12)
	Sfx.play("thud", 1.3)
	phase = "weld"
	welds = 0
	weld_t = 0.0

func _weld_hit() -> void:
	if swing > 0.4:
		return
	swing = 1.0
	welds += 1
	get_tree().create_timer(0.08).timeout.connect(func():
		Sfx.play("clang", 1.0 + welds * 0.05)
		Fx.burst(ws, _mid() + Vector3(-LEN * 0.2, 0.12, 0), Color(1.0, 0.8, 0.3), 12, 0.5, 5.0, -10.0, 0.45, Vector3.UP, 85.0)
		ws.shake(0.04))
	if welds >= BK.FOLD["welds"]:
		_weld_done()

func _weld_done() -> void:
	if phase != "weld":
		return
	phase = "wait"
	var s = 100.0 * clampf(float(welds) / BK.FOLD["welds"], 0.0, 1.0)
	weld_scores.append(s)
	popup("Welded!" if s >= 99.0 else "Half stuck...", Vector2(vsize().x * 0.5, vsize().y * 0.38), Color(1.0, 0.85, 0.3) if s >= 99.0 else Color(1.0, 0.6, 0.3), 36)
	fold_i += 1
	get_tree().create_timer(0.6).timeout.connect(func():
		if fold_i >= folds:
			_finish_all()
			return
		# Draw it back out to full length for the next fold.
		angle = 0.0
		flap.global_position = _pivot()
		for m in mats:
			set_heat(m, 0.9)
		Fx.burst(ws, _mid() + Vector3(0, 0.15, 0), Color(1.0, 0.7, 0.3), 14, 0.6, 3.0, -6.0, 0.4)
		phase = "grab")

func _finish_all() -> void:
	active = false
	var total = 0.0
	for i in align_scores.size():
		total += 0.6 * align_scores[i] + 0.4 * weld_scores[i]
	finish(total / maxf(1.0, align_scores.size()))

func draw_game() -> void:
	var vs = vsize()
	text(Vector2(vs.x * 0.5, 140), "Fold %d / %d" % [mini(fold_i + 1, folds), folds], 30)
	if phase == "grab" or phase == "drag":
		var r = _end_screen(1.0)
		var l = _end_screen(-1.0)
		draw_arc(l, 34, 0, TAU, 32, Color(0.5, 0.95, 0.5, 0.9), 4)
		text(l + Vector2(0, 54), "HERE", 22, Color(0.6, 1.0, 0.6))
		if phase == "grab":
			draw_arc(r, 44 + 5 * sin(t * 10.0), 0, TAU, 32, Color(1.0, 0.85, 0.3), 4)
			text(Vector2(vs.x * 0.5, vs.y - 70), Hud.words("Grab the right end and drag it over! (or hold A)"), 30, Color(1.0, 0.85, 0.4))
	elif phase == "weld":
		hbar(Rect2(vs.x * 0.5 - 180, vs.y - 120, 360, 20), 1.0 - weld_t / _weld_time(), Color(1.0, 0.55, 0.2), "HEAT")
		text(Vector2(vs.x * 0.5, vs.y - 70), Hud.words("{Click} fast to hammer it shut! %d / %d" % [welds, BK.FOLD["welds"]]), 30, Color(1.0, 0.85, 0.4))
