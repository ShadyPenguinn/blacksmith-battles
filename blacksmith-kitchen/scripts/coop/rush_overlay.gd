extends Control
## Rush Hour's on-screen bits: tickets, furnace heat, the anvil beat, tank water, grinding.

var rush: Node

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _t(pos: Vector2, s: String, size := 22, color := Color.WHITE) -> void:
	var f = ThemeDB.fallback_font
	var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p = pos - Vector2(w * 0.5, -size * 0.35)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0, 0, 0, 0.85))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _bar(c: Vector2, w: float, frac: float, col: Color, lo := -1.0, hi := -1.0) -> void:
	var r = Rect2(c.x - w * 0.5, c.y - 9, w, 18)
	draw_rect(r.grow(3), Color(0.1, 0.07, 0.05, 0.9))
	draw_rect(r, Color(0.28, 0.22, 0.2))
	if lo >= 0.0:
		draw_rect(Rect2(r.position.x + r.size.x * lo, r.position.y, r.size.x * (hi - lo), r.size.y), Color(1.0, 0.8, 0.2, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), col)

func _draw() -> void:
	if rush == null or rush.over:
		return
	var ws: Workshop = rush.ws
	# Tickets, top left.
	var x = 20.0
	for o in rush.orders:
		var r = Rect2(x, 96, 190, 74)
		draw_rect(r, Color(0.98, 0.93, 0.82))
		draw_rect(r, Color(0.22, 0.14, 0.1), false, 3)
		var f = o["t"] / o["max"]
		draw_rect(Rect2(r.position.x + 8, r.end.y - 18, (r.size.x - 16) * f, 10), Color(0.4, 0.8, 0.4) if f > 0.35 else Color(0.95, 0.35, 0.25))
		var font = ThemeDB.fallback_font
		draw_string(font, r.position + Vector2(10, 32), BK.WEAPONS[o["weapon"]]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.22, 0.14, 0.1))
		draw_string(font, r.position + Vector2(10, 52), o["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.35, 0.25))
		x += 200
	# Furnace heat and smelting.
	var fp = ws.to_screen(Workshop.FURNACE + Vector3(0, 4.3, 0))
	var band = BK.RUSH["heat_band"]
	_bar(fp, 170, rush.heat / 100.0, BK.heat_color(rush.heat / 100.0), band[0] / 100.0, band[1] / 100.0)
	_t(fp + Vector2(0, -26), "ore in: %d" % rush.load if rush.load > 0 else "needs ore", 20)
	if rush.load > 0:
		_bar(fp + Vector2(0, 26), 120, rush.smelt / BK.RUSH["smelt_need"], Color(1.0, 0.6, 0.2))
	for side in [-1, 1]:
		var bp = ws.to_screen(Workshop.FURNACE + Vector3(side * 2.05, 1.2, 0.5))
		var want = rush.last_side != side
		_t(bp, "STOMP" if want else "...", 20, Color(1, 0.85, 0.4) if want else Color(0.7, 0.7, 0.7))
	# Anvil beat.
	if rush.anvil_item and rush.anvil_item.kind == "ingot":
		var ap = ws.to_screen(Workshop.ANVIL + Vector3(0, 2.2, 0))
		var r2 = Rect2(ap.x - 100, ap.y - 10, 200, 20)
		draw_rect(r2.grow(3), Color(0.1, 0.07, 0.05, 0.9))
		draw_rect(r2, Color(0.28, 0.22, 0.2))
		draw_rect(Rect2(r2.get_center().x - 30, r2.position.y, 60, 20), Color(1.0, 0.8, 0.2))
		draw_rect(Rect2(r2.position.x + 200 * rush.marker - 4, r2.position.y - 8, 8, 36), Color.WHITE)
		_t(ap + Vector2(0, -30), "%s  %d / %d" % [BK.WEAPONS[rush.anvil_item.weapon]["name"], rush.anvil_hits, BK.RUSH["hits"].get(rush.anvil_item.weapon, 4)], 20)
	# Quench tank.
	var tp = ws.to_screen(Workshop.TANK + Vector3(0, 2.3, 0))
	_bar(tp, 120, rush.water, Color(0.35, 0.65, 1.0))
	_t(tp + Vector2(0, -26), "water" if rush.water >= BK.RUSH["water_per_quench"] else "EMPTY! bucket > well", 20, Color.WHITE if rush.water >= 0.3 else Color(1, 0.5, 0.4))
	if rush.tank_item:
		var w = BK.RUSH["quench_window"]
		var tt = rush.tank_t
		var col = Color(0.8, 0.8, 0.8) if tt < w[0] else (Color(0.4, 1.0, 0.5) if tt <= w[1] else Color(1, 0.4, 0.3))
		_t(tp + Vector2(0, 30), "WAIT..." if tt < w[0] else ("GRAB IT NOW!" if tt <= w[1] else "brittle..."), 24, col)
	if rush.grind_item and rush.grind_item.kind == "quenched":
		var gp = ws.to_screen(Workshop.GRIND + Vector3(0, 2.3, 0))
		_bar(gp, 120, float(rush.grind_n) / BK.RUSH["grinds"].get(rush.grind_item.weapon, 7), Color(0.75, 0.9, 1.0))
		_t(gp + Vector2(0, -26), "mash USE", 20)
	# Keys reminder.
	_t(Vector2(size.x * 0.5, size.y - 24), "GRAB: E / .  /  pad A      USE: F / /  /  pad X  (hold USE by a hot ingot = tongs)", 20, Color(1, 1, 1, 0.85))
