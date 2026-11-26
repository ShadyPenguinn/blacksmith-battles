extends Game
## Crack the Ore: glowing cracks pop up on the rock. Click each before it fades.

var cracks := []      # {pos (screen), life, max, seed}
var total := 0
var spawned := 0
var hits := 0
var misses := 0
var next_t := 0.0
var rock: Node3D
var pick: Node3D
var nugget: Node3D

func shot() -> String:
	return "mine"

func prepare() -> void:
	total = BK.MINE["cracks"] + BK.MINE["cracks_per_tier"] * tier
	rock = ws.rock()
	BK.tint(rock, mat_color(), 0.35)
	pick = BK.fitted(BK.M + "tools/pickaxe.gltf", 1.2)
	ws.props.add_child(pick)
	pick.global_position = Workshop.ROCK + Vector3(1.4, 1.8, 1.4)
	pick.rotation_degrees = Vector3(0, 0, 30)

func _life() -> float:
	return maxf(0.8, BK.MINE["life"] + BK.MINE["life_per_tier"] * tier)

func tick(delta: float) -> void:
	next_t -= delta
	if next_t <= 0.0 and spawned < total:
		_spawn()
		next_t = BK.MINE["gap"] * randf_range(0.7, 1.3) - tier * 0.03
	for c in cracks.duplicate():
		c["life"] -= delta
		if c["life"] <= 0.0:
			cracks.erase(c)
			misses += 1
			popup("Missed", c["pos"], Color(0.9, 0.5, 0.4), 26)
	if spawned >= total and cracks.is_empty():
		_crack_open()

func _spawn() -> void:
	var center = ws.to_screen(Workshop.ROCK + Vector3(0, 0.6, 0))
	var vs = vsize()
	var spread = Vector2(vs.y * 0.32, vs.y * 0.16)
	for _try in 12:
		var p = center + Vector2(randf_range(-1, 1) * spread.x, randf_range(-1, 0.7) * spread.y)
		var ok = true
		for c in cracks:
			if c["pos"].distance_to(p) < 110:
				ok = false
		if ok:
			cracks.append({"pos": p, "life": _life(), "max": _life(), "seed": randi()})
			spawned += 1
			return

func on_input(e: InputEvent) -> void:
	if is_press(e):
		_hit(e.position)
	elif e is InputEventScreenTouch and e.pressed:
		pass

func _hit(p: Vector2) -> void:
	var best = null
	for c in cracks:
		if c["pos"].distance_to(p) < 70 and (best == null or c["pos"].distance_to(p) < best["pos"].distance_to(p)):
			best = c
	_swing()
	if best == null:
		popup("Clonk", p, Color(0.8, 0.8, 0.8), 22)
		Sfx.play("thud", 1.5)
		misses += 1
		return
	cracks.erase(best)
	Sfx.play("crack")
	hits += 1
	var fresh = best["life"] / best["max"]
	popup("CRACK!" if fresh > 0.5 else "Crack", p, Color(1.0, 0.85, 0.3), 34)
	var world = ws.cam.project_position(p, ws.cam.global_position.distance_to(Workshop.ROCK) - 0.8)
	Fx.burst(ws, world, mat_color(), 10, 1.0, 4.0, -9.0, 0.5, Vector3(0, 1, 1), 60.0, true)
	Fx.burst(ws, world, Color(1.0, 0.8, 0.4), 6, 0.6, 5.0, -6.0, 0.3)
	var tw = create_tween()
	tw.tween_property(rock, "scale", Vector3.ONE * 0.82, 0.04)
	tw.tween_property(rock, "scale", Vector3.ONE * 0.8, 0.12)

func _swing() -> void:
	var tw = create_tween()
	tw.tween_property(pick, "rotation_degrees:z", 75.0, 0.06)
	tw.tween_property(pick, "rotation_degrees:z", 30.0, 0.18)

func _crack_open() -> void:
	active = false
	nugget = BK.fitted(BK.M + "resources/" + BK.MATERIALS[tier]["ore"] + ".gltf", 0.6)
	ws.props.add_child(nugget)
	BK.tint(nugget, mat_color(), 0.4, 0.4, mat_color())
	nugget.global_position = Workshop.ROCK + Vector3(0, 0.8, 0.6)
	var tw = create_tween()
	tw.tween_property(nugget, "global_position", Workshop.ROCK + Vector3(0.3, 1.6, 1.4), 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(nugget, "global_position", Workshop.ROCK + Vector3(0.5, 0.3, 1.8), 0.3).set_ease(Tween.EASE_IN)
	Fx.burst(ws, Workshop.ROCK + Vector3(0, 1.0, 0.5), mat_color(), 24, 1.4, 5.0, -9.0, 0.7, Vector3.UP, 70.0, true)
	ws.shake(0.2)
	var acc = float(hits) / float(maxi(1, hits + misses))
	var got = float(hits) / float(total)
	var score = 100.0 * (0.75 * got + 0.25 * acc)
	get_tree().create_timer(0.7).timeout.connect(func(): finish(score))

func draw_game() -> void:
	for c in cracks:
		var f = c["life"] / c["max"]
		var rng = RandomNumberGenerator.new()
		rng.seed = c["seed"]
		var col = Color(1.0, 0.75 + 0.2 * f, 0.3, 0.4 + 0.6 * f)
		var p0: Vector2 = c["pos"]
		for arm in 3:
			var ang = rng.randf() * TAU
			var p = p0
			for seg in 3:
				var q = p + Vector2.from_angle(ang + rng.randf_range(-0.6, 0.6)) * rng.randf_range(14, 26)
				draw_line(p, q, Color(1, 0.6, 0.2, 0.35 * f), 10)
				draw_line(p, q, col, 4)
				p = q
		draw_circle(p0, 9, col)
		draw_arc(p0, 44, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Color(1, 1, 1, 0.75), 4)
	text(Vector2(vsize().x * 0.5, vsize().y - 60), "%d / %d" % [hits, total], 30)
