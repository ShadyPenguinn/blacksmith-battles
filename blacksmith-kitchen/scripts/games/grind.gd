extends Game
## Sharpen: pump the grindstone's two pedals in turn to spin the wheel. Keep its speed in
## the green while the edge sharpens. Too fast and the blade overheats.

var spin := 0.0           # 0..1
var edge := 0.0           # seconds sharpening in the green
var burn := 0.0
var last := 0
var blade: Node3D
var band := [0.45, 0.75]
var need := 4.0
var rate_mult := 1.0

func shot() -> String:
	return "grind"

func prepare() -> void:
	band = BK.GRIND["band"]
	need = BK.GRIND["need"]
	limit = BK.GRIND["limit"]
	if up("stone"):
		rate_mult = 1.25
	blade = make_weapon()
	BK.tint(blade, mat_color(), 0.45)
	blade.global_position = Workshop.GRIND + Vector3(0.35, 1.45, 0.0)
	blade.rotation_degrees = Vector3(0, 0, -70)

func on_input(e: InputEvent) -> void:
	if key_down(e, [KEY_A, KEY_LEFT]):
		_push(-1)
	elif key_down(e, [KEY_D, KEY_RIGHT]):
		_push(1)
	elif is_press(e):
		_push(-1 if e.position.x < vsize().x * 0.5 else 1)

func _push(side: int) -> void:
	if not active:
		return
	var gain = BK.GRIND["spin_per_push"] * (0.2 if side == last else 1.0)
	last = side
	Sfx.play("tick", 0.6 + spin * 0.5)
	spin = minf(1.2, spin + gain * (1.0 - spin * 0.4))
	var p: Node3D = ws.grind_pedals[0 if side < 0 else 1]
	var tw = create_tween()
	tw.tween_property(p, "position:y", 0.08, 0.06)
	tw.tween_property(p, "position:y", 0.18, 0.2)

func tick(delta: float) -> void:
	spin = maxf(0.0, spin - BK.GRIND["drag"] * delta * (0.5 + spin))
	if ws.grind_wheel:
		ws.grind_wheel.rotate_object_local(Vector3.RIGHT, spin * 18.0 * delta)
	var touch = Workshop.GRIND + Vector3(0.1, 1.3, 0)
	if spin >= band[0] and spin <= band[1]:
		edge += delta * rate_mult
		if randf() < delta * 30.0:
			Fx.burst(ws, touch, Color(1.0, 0.8, 0.35), 3, 0.35, 5.0, -9.0, 0.35, Vector3(1, 0.6, 0), 30.0)
	elif spin > band[1]:
		burn += delta
		if randf() < delta * 30.0:
			Fx.burst(ws, touch, Color(1.0, 0.35, 0.15), 5, 0.5, 6.0, -9.0, 0.4, Vector3(1, 0.8, 0), 50.0)
	blade.position.x = Workshop.GRIND.x + 0.35 + sin(t * 30.0) * 0.01 * spin
	if edge >= need or t >= limit:
		active = false
		var progress = clampf(edge / need, 0.0, 1.0)
		var speed = clampf(1.0 - (t - need * 1.6) / 8.0, 0.0, 1.0)
		var s = 100.0 * progress * (0.6 + 0.4 * speed) - burn * 15.0
		popup("Sharp!" if progress >= 1.0 else "Dull...", Vector2(vsize().x * 0.5, vsize().y * 0.3), Color(0.8, 0.95, 1.0), 40)
		get_tree().create_timer(0.5).timeout.connect(func(): finish(s))

func draw_game() -> void:
	var vs = vsize()
	var r = Rect2(vs.x - 140, vs.y * 0.2, 46, vs.y * 0.52)
	vgauge(r, spin, band[0], band[1], Color(0.35, 0.85, 0.4), "SPEED")
	hbar(Rect2(vs.x * 0.5 - 180, vs.y - 70, 360, 22), edge / need, Color(0.75, 0.9, 1.0), "EDGE")
	for side in [-1, 1]:
		var p = Vector2(vs.x * (0.5 + side * 0.3), vs.y * 0.78)
		var glow = last != side
		draw_circle(p, 42, Color(0.4, 0.85, 0.45, 0.9) if glow else Color(0.3, 0.25, 0.2, 0.7))
		text(p, "A" if side < 0 else "D", 36)
		text(p + Vector2(0, 60), "PEDAL", 22)
