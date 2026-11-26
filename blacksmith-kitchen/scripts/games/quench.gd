extends Game
## Quench: hold to plunge the glowing blade into the tank. It cools while it's under.
## Pull it out (let go) while the temper is in the blue zone.

var blade: Node3D
var mat: StandardMaterial3D
var temper := 1.0
var zone := 0.35
var zone_w := 0.12
var depth := 0.0           # 0 above water, 1 fully under
var holding := false
var under_t := 0.0
var rate := 0.2
var rate_t := 0.0
var cur_rate := 0.2

func shot() -> String:
	return "quench"

func prepare() -> void:
	rate = BK.QUENCH["cool_rate"] + BK.QUENCH["rate_per_tier"] * tier
	cur_rate = rate
	zone_w = BK.QUENCH["zone"] + BK.QUENCH["zone_per_tier"] * tier
	zone = randf_range(0.25, 0.5)
	blade = make_weapon()
	mat = heat_tint(blade, 0.8)
	blade.rotation_degrees = Vector3(0, 0, 180)   # point down
	_place()

func _place() -> void:
	var len_w = BK.WEAPONS[order.get("weapon", "sword")]["len"]
	var top = ws.water_y() + len_w * 0.5 + 0.25
	var low = ws.water_y() - len_w * 0.5 + 0.35
	blade.global_position = Workshop.TANK + Vector3(0, lerpf(top, low, depth), 0.1)

func on_input(e: InputEvent) -> void:
	if is_press(e) or key_down(e, [KEY_SPACE, KEY_S, KEY_DOWN]):
		holding = true
	elif is_release(e) or key_up(e, [KEY_SPACE, KEY_S, KEY_DOWN]):
		holding = false
		if under_t > 0.25:
			_pull_out()

func tick(delta: float) -> void:
	depth = move_toward(depth, 1.0 if holding else 0.0, delta * 4.0)
	_place()
	if depth > 0.6:
		if under_t == 0.0:
			Sfx.play("sizzle", 0.9, 0.0)
		under_t += delta
		rate_t -= delta
		if rate_t <= 0.0:
			rate_t = randf_range(0.3, 0.8)
			cur_rate = rate * randf_range(0.6, 1.6)
		temper = maxf(0.0, temper - cur_rate * delta)
		set_heat(mat, temper * 0.8)
		if randf() < delta * 20.0:
			Fx.burst(ws, Workshop.TANK + Vector3(randf_range(-0.3, 0.3), ws.water_y() + 0.1, randf_range(-0.2, 0.3)), Color(0.95, 0.95, 0.95, 0.6), 3, 1.6, 2.5, 1.5, 1.0, Vector3.UP, 20.0)
		if temper <= 0.0:
			_pull_out()

func _pull_out() -> void:
	if not active:
		return
	active = false
	holding = false
	var off = temper - zone
	var s = 0.0
	if absf(off) <= zone_w * 0.5:
		s = 100.0 - absf(off) / (zone_w * 0.5) * 15.0
		popup("Perfect temper!" if s > 92.0 else "Nicely tempered!", Vector2(vsize().x * 0.5, vsize().y * 0.3), Color(0.5, 0.8, 1.0), 40)
	elif off > 0.0:
		s = maxf(10.0, 80.0 - (off - zone_w * 0.5) * 220.0)
		popup("Too soft!", Vector2(vsize().x * 0.5, vsize().y * 0.3), Color(1.0, 0.6, 0.3), 40)
	else:
		s = maxf(10.0, 80.0 - (-off - zone_w * 0.5) * 220.0)
		popup("Brittle!", Vector2(vsize().x * 0.5, vsize().y * 0.3), Color(0.7, 0.7, 0.8), 40)
	var tw = create_tween()
	tw.tween_property(self, "depth", 0.0, 0.3)
	tw.tween_callback(func(): finish(s))

func _process(delta: float) -> void:
	super._process(delta)
	if not active and blade:
		_place()

func draw_game() -> void:
	var vs = vsize()
	var r = Rect2(vs.x - 140, vs.y * 0.2, 46, vs.y * 0.52)
	draw_rect(r.grow(6), Color(0.1, 0.07, 0.05, 0.85))
	var n = 24
	for i in n:
		var f0 = float(i) / n
		var y = r.end.y - r.size.y * (f0 + 1.0 / n)
		draw_rect(Rect2(r.position.x, y, r.size.x, r.size.y / n + 1), BK.heat_color(f0 * 0.9 + 0.05).lerp(Color(0.45, 0.5, 0.6), 1.0 - f0) if f0 < 0.5 else BK.heat_color(f0))
	var z0 = r.end.y - r.size.y * (zone + zone_w * 0.5)
	var z1 = r.end.y - r.size.y * (zone - zone_w * 0.5)
	draw_rect(Rect2(r.position.x - 10, z0, r.size.x + 20, z1 - z0), Color(0.3, 0.6, 1.0, 0.55))
	draw_rect(Rect2(r.position.x - 10, z0, r.size.x + 20, z1 - z0), Color(0.6, 0.85, 1.0), false, 3)
	var vy = r.end.y - r.size.y * temper
	draw_rect(Rect2(r.position.x - 16, vy - 5, r.size.x + 32, 10), Color.WHITE)
	text(Vector2(r.get_center().x, r.position.y - 26), "TEMPER", 24)
	if depth < 0.1 and under_t == 0.0:
		text(Vector2(vs.x * 0.5, vs.y - 70), "HOLD TO DUNK", 34, Color(0.7, 0.9, 1.0))
	elif holding:
		text(Vector2(vs.x * 0.5, vs.y - 70), "Let go to pull it out!", 30, Color(0.7, 0.9, 1.0))
