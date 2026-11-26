extends Control
## Shop Day on screen: the customers' tickets across the top (weapon, metal, how far along,
## patience) and a reminder of the controls.

var shop: Node

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _t(pos: Vector2, s: String, size := 20, color := Color.WHITE, center := true) -> void:
	var f = ThemeDB.fallback_font
	var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p = pos - Vector2(w * 0.5 if center else 0.0, -size * 0.35)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0, 0, 0, 0.85))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if shop == null or shop.over:
		return
	var font = ThemeDB.fallback_font
	var ink = Color(0.22, 0.14, 0.1)
	var x = 16.0
	for tk in shop.tickets:
		var r = Rect2(x, 72, 140, 104)
		var f = tk["t"] / tk["max"]
		var urgent = f < 0.3 and fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5
		draw_rect(r, Color(1.0, 0.85, 0.8) if urgent else Color(0.98, 0.93, 0.82))
		draw_rect(r, Color(0.85, 0.25, 0.15) if f < 0.3 else ink, false, 3)
		var mat: Dictionary = BK.MATERIALS[tk["tier"]]
		draw_string(font, r.position + Vector2(8, 24), BK.WEAPONS[tk["weapon"]]["name"], HORIZONTAL_ALIGNMENT_LEFT, 126, 19, ink)
		draw_rect(Rect2(r.position + Vector2(8, 32), Vector2(14, 14)), mat["color"])
		draw_string(font, r.position + Vector2(28, 45), mat["name"] + (" cast" if mat["route"] == "cast" else " forged"), HORIZONTAL_ALIGNMENT_LEFT, 112, 13, ink.lightened(0.15))
		draw_string(font, r.position + Vector2(8, 66), tk["name"], HORIZONTAL_ALIGNMENT_LEFT, 126, 14, Color(0.5, 0.35, 0.25))
		# Progress pips: one per station on the way.
		var n = int(tk["stages"])
		var pw = (r.size.x - 16) / maxf(1, n)
		for i in n:
			var done = i < int(tk["stage"])
			draw_rect(Rect2(r.position.x + 8 + i * pw, r.position.y + 74, pw - 2, 6), Color(0.95, 0.6, 0.2) if done else Color(0.8, 0.75, 0.68))
		draw_rect(Rect2(r.position.x + 8, r.end.y - 16, (r.size.x - 16) * clampf(f, 0, 1), 10), Color(0.4, 0.8, 0.4) if f > 0.3 else Color(0.95, 0.35, 0.25))
		x += 148
	if shop.queue.size() > 0:
		_t(Vector2(x + 4, 96), "+%d coming" % shop.queue.size(), 18, Color(1, 1, 1, 0.8), false)
	if not shop.busy:
		var held = shop.smith.held
		if held:
			_t(Vector2(size.x * 0.5, size.y - 64), "Carrying: %s  >  take it to the %s" % [BK.WEAPONS[held.job["weapon"]]["name"], BK.STATION_NAMES[held.stage()["at"]]], 24, Color(1.0, 0.9, 0.6))
		_t(Vector2(size.x * 0.5, size.y - 26), Hud.words("Move: WASD or {click} the floor     Use / pick up / put down: E or SPACE, or {click} a station"), 18, Color(1, 1, 1, 0.85))
	else:
		_t(Vector2(184.0, 428), "TAB: station camera" if shop.pip.visible else "", 16, Color(1, 1, 1, 0.75))
