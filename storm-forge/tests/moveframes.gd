extends SceneTree
## Frames of a smith doing a movement routine: run, skid and reverse, jump, belly flop.
## -- <out dir> [--p0..--p3 which smith]   Saves move_XXX.png, one every 3 physics frames.

func _initialize() -> void:
	_run()

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var out: String = args[0]
	var who = 0
	for a in args:
		if a.begins_with("--p"):
			who = int(a.substr(3))
	root.size = Vector2i(900, 700)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await create_timer(0.5).timeout
	main.lightning.next_in = 9999.0
	main.set_controlled(3 if who != 3 else 0)
	var p = main.players[who]
	for o in main.players:
		if o != p:
			o.global_position = Vector3(10 + o.idx, 0.1, -8)
	main.hud.visible = false
	var c = main.area_center()
	p.global_position = c + Vector3(-5, 0.1, 4)
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 50
	# [frames, move, sprint, press jump at start]
	var script = [[20, Vector2.ZERO, false, false], [45, Vector2(1, 0), true, false],
		[30, Vector2(-1, 0), true, false], [12, Vector2(-1, 0), false, true],
		[30, Vector2(-1, 0), false, false], [10, Vector2(1, 0), true, true],
		[8, Vector2(1, 0), true, true], [45, Vector2(1, 0), false, false], [20, Vector2.ZERO, false, false]]
	var n = 0
	var t = 0
	for step in script:
		p.in_move = step[1]
		p.in_sprint = step[2]
		if step[3]:
			p.in_dive = true
		for i in step[0]:
			await physics_frame
			var f = Vector3(lerpf(c.x, p.global_position.x, 0.7), 0.9, p.global_position.z)
			cam.global_position = f + Vector3(0, 1.4, 5.5)
			cam.look_at(f)
			t += 1
			if t % 3 == 0:
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(out.path_join("move_%03d.png" % n))
				n += 1
	quit(0)
