class_name Game
extends Control
## One minigame step. It sets up props in the workshop, takes input while active,
## draws its own overlay, and calls finish(score 0-100) once.

signal finished(score: float)

var main: Node
var ws: Workshop
var order := {}
var tier := 0
var step := ""
var active := false
var t := 0.0
var limit := 0.0          # seconds; shows a timer bar when above 0
var _done := false
var font: Font

func init(p_main: Node, p_ws: Workshop, p_order: Dictionary, p_step: String) -> void:
	main = p_main
	ws = p_ws
	order = p_order
	tier = int(order.get("tier", 0))
	step = p_step
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

## The camera shot this step uses.
func shot() -> String:
	return "overview"

## Build props before the countdown.
func prepare() -> void:
	pass

func start() -> void:
	active = true

func tick(_delta: float) -> void:
	pass

func on_input(_e: InputEvent) -> void:
	pass

func _process(delta: float) -> void:
	if active:
		t += delta
		tick(delta)
	queue_redraw()

func _input(e: InputEvent) -> void:
	if active:
		on_input(e)

func finish(score: float) -> void:
	if _done:
		return
	_done = true
	active = false
	finished.emit(clampf(score, 0.0, 100.0))

func mat_color() -> Color:
	return BK.MATERIALS[tier]["color"]

func up(id: String) -> bool:
	return Save.has_upgrade(id)

func popup(text: String, pos: Vector2, color := Color.WHITE, size := 40) -> void:
	main.hud.float_text(text, pos, color, size)

func is_press(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT

func is_release(e: InputEvent) -> bool:
	return e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT

func key_down(e: InputEvent, keys: Array) -> bool:
	return e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in keys

func key_up(e: InputEvent, keys: Array) -> bool:
	return e is InputEventKey and not e.pressed and e.physical_keycode in keys

# --- Drawing helpers --------------------------------------------------------------
func text(pos: Vector2, s: String, size := 28, color := Color.WHITE, center := true) -> void:
	var w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p = pos - Vector2(w * 0.5 if center else 0.0, -size * 0.35)
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0, 0, 0, 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## A vertical gauge with a gold target band. value/lo/hi are 0..1.
func vgauge(r: Rect2, value: float, lo: float, hi: float, band_color := Color(1.0, 0.8, 0.2), label := "") -> void:
	draw_rect(r.grow(6), Color(0.1, 0.07, 0.05, 0.85))
	draw_rect(r, Color(0.25, 0.2, 0.18))
	var by0 = r.end.y - r.size.y * hi
	var by1 = r.end.y - r.size.y * lo
	draw_rect(Rect2(r.position.x, by0, r.size.x, by1 - by0), band_color.darkened(0.15))
	var vy = r.end.y - r.size.y * clampf(value, 0.0, 1.0)
	draw_rect(Rect2(r.position.x, vy, r.size.x, r.end.y - vy), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(r.position.x - 14, vy - 5, r.size.x + 28, 10), Color.WHITE)
	if label != "":
		text(Vector2(r.get_center().x, r.position.y - 26), label, 24)

## A horizontal fill bar.
func hbar(r: Rect2, frac: float, color: Color, label := "") -> void:
	draw_rect(r.grow(4), Color(0.1, 0.07, 0.05, 0.85))
	draw_rect(r, Color(0.25, 0.2, 0.18))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), color)
	if label != "":
		text(Vector2(r.get_center().x, r.get_center().y), label, 22)

func _draw() -> void:
	if limit > 0.0 and active:
		var vs = get_viewport_rect().size
		var r = Rect2(vs.x * 0.5 - 200, 96, 400, 14)
		var left = clampf(1.0 - t / limit, 0.0, 1.0)
		hbar(r, left, Color(0.95, 0.75, 0.3) if left > 0.25 else Color(0.95, 0.3, 0.2))
	draw_game()

func draw_game() -> void:
	pass

func vsize() -> Vector2:
	return get_viewport_rect().size

# --- The piece being forged ---------------------------------------------------------
## Material tint plus hot glow (h: 0 cold .. 1 white hot).
func heat_tint(n: Node, h: float) -> StandardMaterial3D:
	var c = mat_color().lerp(BK.heat_color(h * 0.85), clampf(h, 0.0, 1.0))
	return BK.tint(n, c, 0.45 + 0.35 * h, h * 1.3, BK.heat_color(h * 0.85))

func set_heat(m: StandardMaterial3D, h: float) -> void:
	var c = mat_color().lerp(BK.heat_color(h * 0.85), clampf(h, 0.0, 1.0))
	m.albedo_color = Color(c.r, c.g, c.b, 0.45 + 0.35 * h)
	m.emission = BK.heat_color(h * 0.85)
	m.emission_energy_multiplier = h * 1.3

func route() -> String:
	return BK.route(tier)

## True while the forged metal is still a lumpy bloom (before it is squeezed into a bar).
func is_bloom() -> bool:
	return route() == "forge" and step in ["tongs", "ropes"]

func make_bar(length := 0.7) -> Node3D:
	var p = BK.M + "resources/" + BK.MATERIALS[tier]["bar"] + ".gltf"
	if is_bloom():
		p = BK.M + "resources/" + BK.MATERIALS[tier]["ore"] + ".gltf"
		length *= 0.75
	var m = BK.fitted(p, length)
	if m == null:
		m = Build.box(Vector3(0.25, 0.15, length), mat_color())
	ws.props.add_child(m)
	return m

func make_weapon(length := -1.0) -> Node3D:
	var w = BK.WEAPONS[order.get("weapon", "sword")]
	var m = BK.fitted(w["model"], w["len"] if length < 0.0 else length)
	if m == null:
		m = Build.box(Vector3(0.2, w["len"], 0.05), mat_color())
	ws.props.add_child(m)
	return m
