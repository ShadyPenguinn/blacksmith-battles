extends Game
## Hammer Time: the marker swings across the meter. Hit when it's in the middle.

var hits_needed := 5
var hits := 0
var scores := []
var marker := 0.0
var dir := 1.0
var speed := 1.0
var bar: Node3D
var bar_mat: StandardMaterial3D
var hammer: Node3D
var swinging := 0.0
var flat := 0.0

func shot() -> String:
	return "anvil"

func prepare() -> void:
	hits_needed = BK.HAMMER["hits"] + BK.HAMMER["hits_per_2_tiers"] * (tier / 2)
	speed = BK.HAMMER["speed"] + BK.HAMMER["speed_per_tier"] * tier
	if up("hammer"):
		speed *= 0.85
	bar = make_bar(0.6)
	bar_mat = heat_tint(bar, 0.9)
	bar.global_position = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.08, 0)
	bar.rotation_degrees.y = 90
	hammer = BK.fitted(BK.M + "tools/hammer.gltf", 0.9)
	ws.props.add_child(hammer)
	_hammer_pose(0.0)
	marker = randf()

func _hammer_pose(k: float) -> void:
	# k = 0 raised, 1 striking
	var top = Workshop.ANVIL + Vector3(0.6, ws.anvil_top + 0.75, 0.35)
	var low = Workshop.ANVIL + Vector3(0.22, ws.anvil_top + 0.35, 0.1)
	hammer.global_position = top.lerp(low, k)
	hammer.rotation_degrees = Vector3(0, 0, lerpf(-35.0, 70.0, k))

func tick(delta: float) -> void:
	marker += dir * speed * delta
	if marker > 1.0:
		marker = 2.0 - marker
		dir = -1.0
	elif marker < 0.0:
		marker = -marker
		dir = 1.0
	if swinging > 0.0:
		swinging = maxf(0.0, swinging - delta * 5.0)
	_hammer_pose(sin(swinging * PI) if swinging > 0.0 else 0.0)

func on_input(e: InputEvent) -> void:
	if is_press(e) or key_down(e, [KEY_SPACE, KEY_ENTER, KEY_F]):
		_strike()

func _strike() -> void:
	if not active or swinging > 0.35:
		return
	swinging = 1.0
	var off = absf(marker - 0.5)
	var s = 0.0
	var label = "Miss!"
	var col = Color(0.95, 0.4, 0.35)
	if off <= BK.HAMMER["perfect"]:
		s = 100.0
		label = "PERFECT!"
		col = Color(1.0, 0.85, 0.2)
	elif off <= BK.HAMMER["great"]:
		s = 80.0
		label = "Great!"
		col = Color(0.5, 0.95, 0.5)
	elif off <= BK.HAMMER["ok"]:
		s = 50.0
		label = "OK"
		col = Color(0.6, 0.8, 1.0)
	else:
		s = 10.0
	scores.append(s)
	hits += 1
	get_tree().create_timer(0.1).timeout.connect(func(): _impact(s))
	popup(label, Vector2(vsize().x * 0.5, vsize().y * 0.35), col, 44)
	if hits >= hits_needed:
		active = false
		get_tree().create_timer(0.6).timeout.connect(_forge_blank)

func _impact(s: float) -> void:
	Sfx.play("clang", 0.9 + s / 400.0)
	var p = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.15, 0)
	Fx.burst(ws, p, Color(1.0, 0.8, 0.3), int(6 + s / 8.0), 0.5, 5.0 + s / 30.0, -10.0, 0.45, Vector3.UP, 85.0)
	ws.shake(0.04 + s / 1500.0)
	flat = float(hits) / float(hits_needed)
	bar.scale = Vector3(1.0 + flat * 0.3, 1.0 - flat * 0.5, 1.0 + flat * 0.6)
	set_heat(bar_mat, 0.9 - flat * 0.2)

func _forge_blank() -> void:
	bar.visible = false
	var w = make_weapon()
	w.global_position = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.1, 0)
	w.rotation_degrees = Vector3(90, 0, -90)
	heat_tint(w, 0.75)
	w.scale = Vector3.ONE * 0.4
	var tw = create_tween()
	tw.tween_property(w, "scale", Vector3.ONE * 0.7, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(ws, w.global_position + Vector3(0, 0.2, 0), Color(1.0, 0.9, 0.5), 20, 0.6, 4.0, -6.0, 0.5)
	var avg = 0.0
	for s in scores:
		avg += s
	avg /= maxf(1.0, scores.size())
	get_tree().create_timer(0.7).timeout.connect(func(): finish(avg))

func draw_game() -> void:
	var vs = vsize()
	var r = Rect2(vs.x * 0.5 - 300, vs.y - 120, 600, 40)
	draw_rect(r.grow(6), Color(0.1, 0.07, 0.05, 0.85))
	draw_rect(r, Color(0.3, 0.22, 0.2))
	var zones = [[BK.HAMMER["ok"], Color(0.35, 0.5, 0.75)], [BK.HAMMER["great"], Color(0.35, 0.75, 0.35)], [BK.HAMMER["perfect"], Color(1.0, 0.8, 0.2)]]
	for z in zones:
		var w = r.size.x * z[0] * 2.0
		draw_rect(Rect2(r.get_center().x - w * 0.5, r.position.y, w, r.size.y), z[1])
	var mx = r.position.x + r.size.x * marker
	draw_rect(Rect2(mx - 5, r.position.y - 14, 10, r.size.y + 28), Color.WHITE)
	text(Vector2(vs.x * 0.5, r.position.y - 40), "Hits %d / %d" % [hits, hits_needed], 28)
