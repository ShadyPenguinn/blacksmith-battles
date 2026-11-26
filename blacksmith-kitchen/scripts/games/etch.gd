extends BenchGame
## Etch a Rune: hold and trace through the dots in order.

const RUNES := {
	"Bolt": [Vector2(-0.4, -1), Vector2(0.3, -0.2), Vector2(-0.3, 0.2), Vector2(0.4, 1)],
	"Star": [Vector2(0, -1), Vector2(0.6, 0.8), Vector2(-0.95, -0.3), Vector2(0.95, -0.3), Vector2(-0.6, 0.8), Vector2(0, -1)],
	"Eye": [Vector2(-1, 0), Vector2(0, -0.6), Vector2(1, 0), Vector2(0, 0.6), Vector2(-1, 0)],
	"Fang": [Vector2(-1, -0.7), Vector2(-0.5, 0.7), Vector2(0, -0.3), Vector2(0.5, 0.7), Vector2(1, -0.7)],
	"Crown": [Vector2(-1, 0.6), Vector2(-1, -0.6), Vector2(-0.4, 0.1), Vector2(0, -0.8), Vector2(0.4, 0.1), Vector2(1, -0.6), Vector2(1, 0.6), Vector2(-1, 0.6)],
}
var rune_name := ""
var dots := PackedVector2Array()
var reached := 0
var holding := false
var trail := PackedVector2Array()
var dev_sum := 0.0
var dev_n := 0

func prepare() -> void:
	lay_blade()
	limit = BK.ETCH["limit"]
	var names = RUNES.keys()
	rune_name = names[randi() % names.size()]
	var center = along(0.55)
	var sc = 120.0
	for p in RUNES[rune_name]:
		dots.append(center + p * sc)

func on_input(e: InputEvent) -> void:
	if is_press(e):
		if e.position.distance_to(dots[reached]) < 50:
			holding = true
			trail.append(e.position)
	elif is_release(e):
		holding = false
	elif e is InputEventMouseMotion and holding:
		_trace(e.position)

func _trace(p: Vector2) -> void:
	trail.append(p)
	if reached + 1 >= dots.size():
		return
	var a = dots[reached]
	var b = dots[reached + 1]
	var ab = b - a
	var k = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
	var d = p.distance_to(a + ab * k)
	dev_sum += d
	dev_n += 1
	if randf() < 0.3:
		Fx.burst(ws, ws.cam.project_position(p, ws.cam.global_position.distance_to(along3(0.5))), Color(0.6, 0.85, 1.0), 2, 0.3, 1.5, 0.0, 0.3)
	if p.distance_to(b) < 34:
		reached += 1
		Sfx.play("ding", 1.0 + reached * 0.08)
		if reached >= dots.size() - 1:
			_done_etching()

func tick(_delta: float) -> void:
	if t >= limit:
		_done_etching()

func _done_etching() -> void:
	if not active:
		return
	active = false
	holding = false
	var completion = float(reached) / float(dots.size() - 1)
	var dev = dev_sum / maxf(1.0, dev_n)
	var acc = clampf(1.0 - dev / BK.ETCH["tolerance"], 0.0, 1.0)
	var speed = clampf(1.0 - (t - 2.5) / 7.0, 0.0, 1.0)
	var score = 100.0 * completion * (0.65 * acc + 0.35 * speed + 0.1)
	popup(rune_name + " rune!" if completion >= 1.0 else "Unfinished...", Vector2(vsize().x * 0.5, vsize().y * 0.25), Color(0.6, 0.85, 1.0), 40)
	BK.tint(blade, Color(0.5, 0.8, 1.0), 0.35, 0.8, Color(0.4, 0.7, 1.0))
	get_tree().create_timer(0.6).timeout.connect(func(): finish(score))

func draw_game() -> void:
	for i in range(dots.size() - 1):
		draw_line(dots[i], dots[i + 1], Color(1, 1, 1, 0.18), 18)
	for i in range(reached):
		draw_line(dots[i], dots[i + 1], Color(0.5, 0.85, 1.0, 0.9), 8)
	if trail.size() > 1:
		draw_polyline(trail, Color(0.7, 0.9, 1.0, 0.7), 4)
	for i in dots.size():
		if i == dots.size() - 1 and dots[i].distance_to(dots[0]) < 2.0:
			continue
		var col = Color(0.5, 0.85, 1.0) if i <= reached else Color(1, 1, 1, 0.9)
		draw_circle(dots[i], 16, Color(0, 0, 0, 0.6))
		draw_circle(dots[i], 13, col)
		text(dots[i], str(i + 1), 18, Color.BLACK)
	if active and not holding:
		draw_arc(dots[reached], 30 + 6 * sin(t * 9.0), 0, TAU, 30, Color(1.0, 0.85, 0.3), 4)
	text(Vector2(vsize().x * 0.5, 140), "Rune: " + rune_name, 30, Color(0.7, 0.9, 1.0))
