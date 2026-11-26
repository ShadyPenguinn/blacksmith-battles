extends Game
## Temper (forged metals): quenched steel is hard but brittle. Warm it gently on the coals
## and watch the colour run: straw, bronze, purple, blue, grey. Lift it off just before the
## target colour, because the heat inside keeps the colour creeping for a moment.

var blade: Node3D
var mat: StandardMaterial3D
var coals: MeshInstance3D
var p := -0.2               # colour progress: <0 bright steel, 0 straw .. 1 grey
var holding := false
var started := false
var lifted := false
var coast_t := 0.0
var rate := 0.16
var target := 0.0
var lift := 0.0

func shot() -> String:
	return "anvil"

func prepare() -> void:
	rate = BK.TEMPER["rate"] + BK.TEMPER["rate_per_tier"] * maxi(0, tier - 2)
	var idx = int(BK.WEAPONS[order.get("weapon", "sword")].get("temper", 0))
	target = idx / 4.0
	coals = Build.box(Vector3(1.2, 0.08, 0.45), Color(0.3, 0.07, 0.03), 0.5)
	ws.props.add_child(coals)
	coals.global_position = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.06, 0)
	blade = make_weapon(minf(BK.WEAPONS[order.get("weapon", "sword")]["len"], 1.3))
	blade.rotation_degrees = Vector3(90, 0, -90)
	mat = BK.tint(blade, Color(0.9, 0.92, 0.95), 0.6)
	_place()

func _place() -> void:
	blade.global_position = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.16 + lift * 0.35, 0.05)

func _color_at(v: float) -> Color:
	var cols = BK.TEMPER["colors"]
	if v < 0.0:
		return Color(0.9, 0.92, 0.95).lerp(cols[0][1], clampf(1.0 + v / 0.2, 0.0, 1.0))
	var f = clampf(v, 0.0, 1.0) * (cols.size() - 1)
	var i = mini(int(f), cols.size() - 2)
	return cols[i][1].lerp(cols[i + 1][1], f - i)

func on_input(e: InputEvent) -> void:
	if lifted:
		return
	if is_press(e) or key_down(e, [KEY_SPACE, KEY_S, KEY_DOWN]):
		holding = true
		started = true
	elif (is_release(e) or key_up(e, [KEY_SPACE, KEY_S, KEY_DOWN])) and started:
		holding = false
		lifted = true

func tick(delta: float) -> void:
	lift = move_toward(lift, 0.0 if (holding and not lifted) else 1.0, delta * 5.0)
	_place()
	if holding and not lifted:
		p += rate * delta
		coals.material_override.emission_energy_multiplier = 0.9 + 0.3 * sin(t * 9.0)
	else:
		coals.material_override.emission_energy_multiplier = 0.5
	if holding and not lifted:
		if randf() < delta * 4.0:
			Fx.burst(ws, blade.global_position + Vector3(randf_range(-0.4, 0.4), 0.1, 0), Color(0.7, 0.7, 0.7, 0.4), 2, 1.0, 0.8, 1.2, 0.8)
		if p >= 1.05:
			lifted = true
			holding = false
	elif lifted:
		# The heat inside keeps it creeping, slowing to a stop.
		coast_t += delta
		var coast = BK.TEMPER["coast"]
		if coast_t < coast:
			p += rate * delta * (1.0 - coast_t / coast)
		else:
			_judge()
	mat.albedo_color = _color_at(p)
	mat.albedo_color.a = 0.75

func _judge() -> void:
	active = false
	var d = absf(p - target)
	var band = BK.TEMPER["band"]
	var s = 0.0
	var vs = vsize()
	var name = BK.TEMPER["colors"][int(round(clampf(target, 0.0, 1.0) * 4))][0]
	if d <= band:
		s = 100.0 - d / band * 15.0
		popup("Perfect " + name.to_lower() + "!" if s > 92.0 else "Nice " + name.to_lower() + "!", Vector2(vs.x * 0.5, vs.y * 0.3), Color(1.0, 0.85, 0.3), 40)
		Sfx.play("good")
	elif p < target:
		s = maxf(10.0, 85.0 - (d - band) * 260.0)
		popup("Too hard, still brittle!", Vector2(vs.x * 0.5, vs.y * 0.3), Color(0.8, 0.85, 0.95), 38)
	else:
		s = maxf(10.0, 85.0 - (d - band) * 260.0)
		popup("Too soft!", Vector2(vs.x * 0.5, vs.y * 0.3), Color(1.0, 0.6, 0.3), 38)
	get_tree().create_timer(0.7).timeout.connect(func(): finish(s))

func draw_game() -> void:
	var vs = vsize()
	var cols = BK.TEMPER["colors"]
	var r = Rect2(vs.x * 0.5 - 330, vs.y - 150, 660, 40)
	draw_rect(r.grow(6), Color(0.1, 0.07, 0.05, 0.85))
	var n = 66
	for i in n:
		var v = float(i) / (n - 1)
		draw_rect(Rect2(r.position.x + r.size.x * i / n, r.position.y, r.size.x / n + 1, r.size.y), _color_at(v))
	for i in cols.size():
		text(Vector2(r.position.x + r.size.x * i / (cols.size() - 1), r.end.y + 22), cols[i][0], 16, Color(0.95, 0.92, 0.85))
	var tx = r.position.x + r.size.x * target
	var bw = r.size.x * BK.TEMPER["band"]
	draw_rect(Rect2(tx - bw, r.position.y - 8, bw * 2.0, r.size.y + 16), Color(1, 1, 1), false, 3)
	text(Vector2(tx, r.position.y - 30), "TARGET", 22, Color(1.0, 0.9, 0.5))
	if p >= 0.0:
		var mx = r.position.x + r.size.x * clampf(p, 0.0, 1.05)
		draw_rect(Rect2(mx - 4, r.position.y - 12, 8, r.size.y + 24), Color.WHITE)
	if not started:
		text(Vector2(vs.x * 0.5, vs.y - 240), "HOLD TO WARM IT", 32, Color(1.0, 0.8, 0.4))
	elif holding:
		text(Vector2(vs.x * 0.5, vs.y - 240), "Let go a little early!", 30, Color(1.0, 0.8, 0.4))
