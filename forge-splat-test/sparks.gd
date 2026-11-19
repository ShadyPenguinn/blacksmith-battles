## Pixel sparks drawn over the splat picture: squares one art pixel wide that fly, fall and fade.
extends Control

const COLOURS: Array[Color] = [Color("fff0a0"), Color("ffb838"), Color("ff6a20")]

var pixel: float = 3.0
var _sparks: Array[Dictionary] = []


func burst(at: Vector2, count: int) -> void:
	for i: int in count:
		var a: float = randf_range(-PI * 0.95, -PI * 0.05)
		var speed: float = randf_range(40.0, 130.0) * pixel / 3.0
		_sparks.append({
			"p": at, "v": Vector2(cos(a), sin(a)) * speed, "life": randf_range(0.25, 0.6),
			"age": 0.0, "c": COLOURS[randi() % COLOURS.size()]
		})


func _process(delta: float) -> void:
	for s: Dictionary in _sparks:
		s.age += delta
		s.v.y += 380.0 * pixel / 3.0 * delta
		s.p += s.v * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.age < s.life)
	queue_redraw()


func _draw() -> void:
	for s: Dictionary in _sparks:
		var snapped_p: Vector2 = (s.p / pixel).floor() * pixel
		var c: Color = s.c
		c.a = clampf(1.0 - s.age / s.life, 0.0, 1.0) * 1.5
		draw_rect(Rect2(snapped_p, Vector2(pixel, pixel)), c)
