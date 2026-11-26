class_name Smelt
extends Game
## Shared heat game for the bellows and the lever pump: keep the furnace in the gold band
## until the bar is smelted. Same side (or same direction) twice in a row only wheezes.

var heat := 0.0            # 0..100
var smelted := 0.0         # seconds in band
var scorch := 0.0          # seconds too hot
var last := 0
var band := [0.0, 0.0]
var pump_mult := 1.0
var finished_at := -1.0

func shot() -> String:
	return "furnace"

func prepare() -> void:
	band = BK.MATERIALS[tier]["band"]
	limit = BK.SMELT["limit"]
	if up("bellows"):
		pump_mult *= 1.2
	ws.set_fire(0.0)

func pump(side: int) -> void:
	if not active:
		return
	var gain = BK.SMELT["heat_per_pump"] * pump_mult
	if side == last:
		gain *= BK.SMELT["wheeze_mult"]
		popup("wheeze...", _side_pos(side), Color(0.8, 0.8, 0.8), 26)
	last = side
	heat = minf(110.0, heat + gain)
	ws.fire_puff()
	Sfx.play("puff", 1.3 if side == last else 1.0)

func _side_pos(side: int) -> Vector2:
	return Vector2(vsize().x * (0.5 + side * 0.28), vsize().y * 0.55)

func tick(delta: float) -> void:
	heat = maxf(0.0, heat - (BK.SMELT["decay"] + BK.SMELT["decay_per_tier"] * tier) * delta)
	var hot = heat > band[1] + BK.SMELT["scorch_margin"]
	if heat >= band[0] and heat <= band[1]:
		smelted += delta
	elif hot:
		scorch += delta
		if randf() < delta * 6.0:
			Fx.burst(ws, Workshop.FURNACE + Vector3(0, 1.0, 1.2), Color(0.25, 0.22, 0.2, 0.8), 6, 1.4, 2.0, 1.0, 0.8)
	ws.set_fire(heat / 100.0, hot)
	if smelted >= BK.SMELT["need"]:
		_done_smelting()
	elif t >= limit:
		_done_smelting()

func _done_smelting() -> void:
	active = false
	ws.pop_cap()
	var speed = clampf(1.0 - (t - BK.SMELT["need"] - 1.0) / 9.0, 0.0, 1.0)
	var progress = clampf(smelted / BK.SMELT["need"], 0.0, 1.0)
	var score = 100.0 * (0.55 * progress + 0.45 * speed * progress) - scorch * 22.0
	get_tree().create_timer(0.6).timeout.connect(func():
		ws.set_fire(0.3)
		finish(score))

func draw_game() -> void:
	var vs = vsize()
	var r = Rect2(vs.x - 130, vs.y * 0.22, 46, vs.y * 0.5)
	vgauge(r, heat / 100.0, band[0] / 100.0, band[1] / 100.0, Color(1.0, 0.8, 0.2), "HEAT")
	var too = (band[1] + BK.SMELT["scorch_margin"]) / 100.0
	var ty = r.end.y - r.size.y * too
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, ty - r.position.y), Color(0.9, 0.15, 0.1, 0.35))
	hbar(Rect2(vs.x * 0.5 - 180, vs.y - 70, 360, 22), smelted / BK.SMELT["need"], Color(1.0, 0.6, 0.2), "MELTING" if route() == "cast" else "COOKING THE BLOOM")
