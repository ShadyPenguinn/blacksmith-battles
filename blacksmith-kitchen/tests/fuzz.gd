extends SceneTree
## Runs every minigame with random clicks, drags and keys to catch script errors.
var main
func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func _run():
	await create_timer(0.3).timeout
	for step in main.GAMES.keys():
		for tier in [0, 5]:
			main.ws.clear_props()
			var g = main.GAMES[step].new()
			g.init(main, main.ws, {"weapon": "halberd" if tier == 5 else "dagger", "tier": tier}, step)
			main.hud.game_layer.add_child(g)
			main.ws.set_shot(g.shot(), 0.0)
			g.prepare()
			g.start()
			var got = [false]
			g.finished.connect(func(s): got[0] = true; print(step, " t", tier, " score ", int(s)))
			var held = false
			for i in 120:
				var r = randf()
				var pos = Vector2(randf_range(200, 1400), randf_range(150, 800))
				if step in ["tongs", "etch", "polish"] and i % 30 == 0:
					pos = main.ws.to_screen(g.pos) if step == "tongs" else (g.dots[g.reached] if step == "etch" else pos)
				if r < 0.25:
					var e = InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = not held; e.position = pos
					held = not held
					Input.parse_input_event(e)
				elif r < 0.7:
					var m = InputEventMouseMotion.new(); m.position = pos; m.relative = Vector2(randf_range(-30, 30), randf_range(-10, 60))
					Input.parse_input_event(m)
				else:
					var k = InputEventKey.new(); k.physical_keycode = [KEY_A, KEY_D, KEY_W, KEY_S, KEY_SPACE][randi() % 5]; k.pressed = randf() < 0.6
					Input.parse_input_event(k)
				await process_frame
				await process_frame
				if got[0]: break
			if not got[0]:
				g.finish(50)
				print(step, " t", tier, " forced")
			await create_timer(0.8).timeout
			g.queue_free()
	print("FUZZ DONE")
	quit()
