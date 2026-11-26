extends Smelt
## Pump the Lever: pull it up, push it down. Each stroke blows a little air into the fire.

var angle := 0.0
var target := 0.0

func prepare() -> void:
	super.prepare()
	pump_mult *= BK.SMELT["lever_mult"]
	ws.use_lever(true)
	ws.set_lever(0.0)

func on_input(e: InputEvent) -> void:
	if key_down(e, [KEY_W, KEY_UP]):
		_stroke(-1)
	elif key_down(e, [KEY_S, KEY_DOWN]):
		_stroke(1)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			_stroke(1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_stroke(-1 if e.position.y < vsize().y * 0.5 else 1)

func _stroke(dir: int) -> void:
	if not active:
		return
	target = 0.55 * dir
	if dir != last:
		Fx.burst(ws, Workshop.FURNACE + Vector3(1.2, 0.4, 0.9), Color(0.95, 0.95, 0.9, 0.6), 5, 1.0, 3.0, 0.5, 0.3, Vector3(-1, 0.2, 0), 25.0)
	pump(dir)

func tick(delta: float) -> void:
	super.tick(delta)
	angle = lerpf(angle, target, minf(1.0, delta * 18.0))
	ws.set_lever(angle)

func finish(score: float) -> void:
	super.finish(score)
	ws.use_lever(false)

func draw_game() -> void:
	super.draw_game()
	var vs = vsize()
	var want = -last
	for dir in [-1, 1]:
		var p = Vector2(vs.x * 0.2, vs.y * (0.5 + dir * 0.2))
		var glow = want == dir or last == 0
		var pulse = 1.0 + (0.1 * sin(t * 12.0) if glow else 0.0)
		draw_circle(p, 42 * pulse, Color(1.0, 0.7, 0.25, 0.9) if glow else Color(0.3, 0.25, 0.2, 0.7))
		text(p, "W" if dir < 0 else "S", 36)
		text(p + Vector2(80, 0), "UP" if dir < 0 else "DOWN", 24, Color.WHITE, false)
