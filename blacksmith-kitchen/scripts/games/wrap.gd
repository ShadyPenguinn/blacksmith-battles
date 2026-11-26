extends BenchGame
## Wrap the Grip: over, under, over, under. Press on the beat as the ring closes.

var beat := 0.75
var count := 8
var start_t := 0.8
var results := []          # score per wrap (index = wrap)
var bands := []
var next_i := 0

func prepare() -> void:
	lay_blade()
	beat = BK.WRAP["beat"] + BK.WRAP["beat_per_tier"] * tier
	count = BK.WRAP["wraps"]

func _beat_t(i: int) -> float:
	return start_t + i * beat

func on_input(e: InputEvent) -> void:
	var dir = 0
	if key_down(e, [KEY_W, KEY_UP]):
		dir = -1
	elif key_down(e, [KEY_S, KEY_DOWN]):
		dir = 1
	elif is_press(e):
		dir = -1 if e.position.y < along(0.15).y else 1
	if dir != 0:
		_press(dir)

func _want(i: int) -> int:
	return -1 if i % 2 == 0 else 1

func _press(dir: int) -> void:
	if next_i >= count:
		return
	var err = absf(t - _beat_t(next_i))
	if err > beat * 0.5:
		popup("Too early!", along(0.15) + Vector2(0, -90), Color(0.9, 0.6, 0.4), 26)
		return
	var s = 0.0
	var label = "Miss"
	var col = Color(0.95, 0.4, 0.35)
	if dir != _want(next_i):
		label = "Tangled!"
	elif err < 0.07:
		s = 100.0
		label = "PERFECT"
		col = Color(1.0, 0.85, 0.2)
	elif err < 0.15:
		s = 80.0
		label = "Great"
		col = Color(0.5, 0.95, 0.5)
	elif err < 0.26:
		s = 50.0
		label = "OK"
		col = Color(0.6, 0.8, 1.0)
	_resolve(s, label, col)

func _resolve(s: float, label: String, col: Color) -> void:
	results.append(s)
	Sfx.play("tick" if s > 0.0 else "bad", 1.0)
	popup(label, along(0.15) + Vector2(0, -90), col, 30)
	if s > 0.0:
		var band = Build.cyl(0.07, 0.06, Color(0.35, 0.2, 0.12).lerp(Color(0.55, 0.32, 0.18), s / 100.0))
		band.rotation_degrees.z = 90
		ws.props.add_child(band)
		var f = 0.04 + 0.22 * float(next_i) / count
		band.global_position = along3(f) + Vector3(0, 0.01, 0)
	next_i += 1
	if next_i >= count:
		active = false
		var avg = 0.0
		for v in results:
			avg += v
		get_tree().create_timer(0.5).timeout.connect(func(): finish(avg / count))

func tick(_delta: float) -> void:
	if next_i < count and t > _beat_t(next_i) + 0.3:
		_resolve(0.0, "Miss", Color(0.95, 0.4, 0.35))

func draw_game() -> void:
	if next_i >= count:
		return
	var c = along(0.15)
	var until = _beat_t(next_i) - t
	var r = 40.0 + maxf(0.0, until) * 160.0
	var want = _want(next_i)
	draw_arc(c, 40, 0, TAU, 40, Color(1, 1, 1, 0.6), 4)
	draw_arc(c, r, 0, TAU, 48, Color(1.0, 0.8, 0.3), 6)
	text(c + Vector2(0, -150 if want < 0 else 150), "OVER (W)" if want < 0 else "UNDER (S)", 34, Color(1.0, 0.9, 0.5))
	text(Vector2(vsize().x * 0.5, vsize().y - 50), "Wraps %d / %d" % [next_i, count], 28)
