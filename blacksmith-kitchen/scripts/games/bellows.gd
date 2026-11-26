extends Smelt
## Stomp the Bellows: left, right, left, right. The bellows either side of the furnace.

func prepare() -> void:
	super.prepare()
	ws.use_lever(false)

func on_input(e: InputEvent) -> void:
	if key_down(e, [KEY_A, KEY_LEFT]):
		_stomp(-1)
	elif key_down(e, [KEY_D, KEY_RIGHT]):
		_stomp(1)
	elif is_press(e):
		_stomp(-1 if e.position.x < vsize().x * 0.5 else 1)

func _stomp(side: int) -> void:
	if not active:
		return
	ws.stomp(side)
	pump(side)

func draw_game() -> void:
	super.draw_game()
	var vs = vsize()
	var want = -last if last != 0 else 0
	for side in [-1, 1]:
		var p = Vector2(vs.x * (0.5 + side * 0.3), vs.y * 0.78)
		var glow = want == side or want == 0
		var pulse = 1.0 + (0.1 * sin(t * 12.0) if glow else 0.0)
		draw_circle(p, 46 * pulse, Color(1.0, 0.7, 0.25, 0.9) if glow else Color(0.3, 0.25, 0.2, 0.7))
		text(p, "A" if side < 0 else "D", 40, Color.WHITE if glow else Color(0.7, 0.7, 0.7))
		text(p + Vector2(0, 66), "STOMP", 22)
