extends BenchGame
## Polish: hold and scrub the grime spots off the blade.

var spots := []      # {f (along blade), off (px), dirt 0..1}
var holding := false
var last_pos := Vector2.ZERO
var total := 0
var shine_mat: StandardMaterial3D

func prepare() -> void:
	lay_blade()
	limit = BK.POLISH["limit"]
	total = BK.POLISH["spots"] + BK.POLISH["spots_per_tier"] * tier
	for i in total:
		spots.append({"f": randf_range(0.2, 0.95), "off": Vector2(0, randf_range(-28, 28)), "dirt": 1.0, "seed": randi()})

func on_input(e: InputEvent) -> void:
	if is_press(e):
		holding = true
		last_pos = e.position
	elif is_release(e):
		holding = false
	elif e is InputEventMouseMotion and holding:
		_rub(e.position, e.position.distance_to(last_pos))
		last_pos = e.position

func _rub(p: Vector2, amount: float) -> void:
	for s in spots:
		if s["dirt"] <= 0.0:
			continue
		var sp = along(s["f"]) + s["off"]
		if sp.distance_to(p) < 60.0:
			s["dirt"] = maxf(0.0, s["dirt"] - amount / BK.POLISH["rub_needed"] * total * 0.5)
			if randf() < 0.3:
				Fx.burst(ws, along3(s["f"]), Color(0.9, 0.9, 1.0, 0.8), 2, 0.4, 1.5, 0.5, 0.4)
			if s["dirt"] <= 0.0:
				popup("Shiny!", sp + Vector2(0, -50), Color(0.85, 0.95, 1.0), 28)
				Sfx.play("ding", 1.3)
				Fx.burst(ws, along3(s["f"]), Color(1, 1, 1), 10, 0.5, 2.5, 0.0, 0.5)

func tick(_delta: float) -> void:
	var left = 0.0
	for s in spots:
		left += s["dirt"]
	if left <= 0.0 or t >= limit:
		active = false
		var clean = 1.0 - left / total
		var speed = clampf(1.0 - (t - 3.0) / (limit - 3.0), 0.0, 1.0)
		var score = 100.0 * clean * (0.75 + 0.25 * speed)
		shine_mat = BK.tint(blade, Color(1, 1, 1), 0.3, 1.2, Color(1, 1, 1))
		var tw = create_tween()
		tw.tween_property(shine_mat, "emission_energy_multiplier", 0.0, 0.6)
		get_tree().create_timer(0.6).timeout.connect(func(): finish(score))

func draw_game() -> void:
	for s in spots:
		if s["dirt"] <= 0.0:
			continue
		var c = along(s["f"]) + s["off"]
		var rng = RandomNumberGenerator.new()
		rng.seed = s["seed"]
		for i in 6:
			var o = Vector2(rng.randf_range(-22, 22), rng.randf_range(-14, 14))
			draw_circle(c + o, rng.randf_range(10, 20), Color(0.22, 0.17, 0.12, 0.85 * s["dirt"]))
	if holding:
		draw_circle(get_viewport().get_mouse_position(), 30, Color(1, 1, 1, 0.25))
	var left = 0
	for s in spots:
		if s["dirt"] > 0.0:
			left += 1
	text(Vector2(vsize().x * 0.5, vsize().y - 50), "Grime left: %d" % left, 28)
