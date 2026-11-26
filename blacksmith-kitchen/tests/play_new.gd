extends SceneTree
## Plays the route steps (crush, pour, fold, temper) the way a person would and prints scores.
## Optional screenshots: xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/play_new.gd -- OUTDIR
var main
var out := ""
var shot_n := 0

func _initialize():
	var a = OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func _snap(tag: String) -> void:
	if out == "":
		return
	await process_frame
	root.get_texture().get_image().save_png(out + "/%02d_%s.png" % [shot_n, tag])
	shot_n += 1

func _click(p: Vector2, down := true) -> void:
	var e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	Input.parse_input_event(e)

func _move(p: Vector2) -> void:
	var m = InputEventMouseMotion.new()
	m.position = p
	Input.parse_input_event(m)

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _start(step: String, weapon: String, tier: int):
	main.hud.clear_menu()
	main.ws.clear_props()
	var g = main.GAMES[step].new()
	g.init(main, main.ws, {"weapon": weapon, "tier": tier}, step)
	main.hud.game_layer.add_child(g)
	main.ws.set_shot(g.shot(), 0.0)
	g.prepare()
	g.start()
	return g

func _run():
	await _wait(0.5)
	print("cast sword:", BK.steps_for("sword", 0))
	print("forge halberd starmetal:", BK.steps_for("halberd", 5))
	for tier in [0, 5]:
		# Crush: click every chunk that is not gravel.
		var g = _start("crush", "sword", tier)
		var res = [-1.0]
		g.finished.connect(func(s): res[0] = s)
		await _wait(0.3)
		await _snap("crush_t%d" % tier)
		while res[0] < 0.0:
			for c in g.chunks:
				if c["size"] >= 2:
					_click(main.ws.to_screen(c["pos"]))
					_click(main.ws.to_screen(c["pos"]), false)
					break
			await _wait(0.25)
		print("crush t", tier, " score ", int(res[0]), " dust ", g.dust)
		g.queue_free()
		# Temper: hold until a little before the target.
		g = _start("temper", "sword", tier)
		res = [-1.0]
		g.finished.connect(func(s): res[0] = s)
		_click(Vector2(800, 450))
		while g.p < g.target - 0.06:
			await process_frame
		await _snap("temper_t%d" % tier)
		_click(Vector2(800, 450), false)
		while res[0] < 0.0:
			await process_frame
		print("temper t", tier, " score ", int(res[0]), " p ", snappedf(g.p, 0.01), " target ", g.target)
		g.queue_free()
		# Fold: drag the right end onto the left end, then mash welds.
		g = _start("fold", "sword", 3 if tier == 0 else 5)
		res = [-1.0]
		g.finished.connect(func(s): res[0] = s)
		while res[0] < 0.0:
			if g.phase == "grab":
				var r = g._end_screen(1.0)
				var l = g._end_screen(-1.0)
				_click(r)
				for i in 10:
					_move(r.lerp(l, (i + 1) / 10.0))
					await process_frame
				await _snap("fold")
				_click(l, false)
			elif g.phase == "weld":
				_click(Vector2(800, 450))
				_click(Vector2(800, 450), false)
				await _wait(0.12)
			await process_frame
		print("fold score ", int(res[0]))
		g.queue_free()
	# Pour: hold, steady near the middle of the green, stop at full, crack.
	for tier in [0, 4]:
		var g = _start("pour", "sword", tier)
		var res = [-1.0]
		g.finished.connect(func(s): res[0] = s)
		var snapped_pour = false
		while g.phase == "pour":
			var want = g.fill < 0.97
			var steady = g.tilt < BK.POUR["splash_tilt"] - 0.12
			if want and steady and not g.holding:
				_click(Vector2(800, 450))
			elif (not want or not steady) and g.holding:
				_click(Vector2(800, 450), false)
			if g.fill > 0.4 and not snapped_pour:
				snapped_pour = true
				await _snap("pour_t%d" % tier)
			await process_frame
		await _snap("crack_t%d" % tier)
		while res[0] < 0.0:
			_click(Vector2(800, 450))
			_click(Vector2(800, 450), false)
			await _wait(0.15)
		print("pour t", tier, " score ", int(res[0]), " fill ", snappedf(g.fill, 0.01), " spilled ", snappedf(g.spilled, 0.01), " over ", snappedf(g.overflow, 0.01), " temp ", snappedf(g.temp, 0.01))
		g.queue_free()
	print("PLAY DONE")
	quit()
