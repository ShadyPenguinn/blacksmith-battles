extends SceneTree
## Frames of a smith running past the camera, to judge the run.
## -- <out dir> [count] [side|front] [--empty] [--p0..--p3 which smith]

func _initialize() -> void:
	_run()

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var out: String = args[0]
	var count = int(args[1]) if args.size() > 1 else 8
	var view: String = args[2] if args.size() > 2 else "side"
	root.size = Vector2i(900, 700)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await create_timer(0.5).timeout
	main.lightning.next_in = 9999.0
	var who = 0
	for a in args:
		if a.begins_with("--p"):
			who = int(a.substr(3))
	main.set_controlled(3 if who != 3 else 0)
	var p = main.players[who]
	for o in main.players:
		if o != p:
			o.global_position = Vector3(10 + o.idx, 0.1, -8)
	main.hud.visible = false
	if "--empty" in args:
		p.drop()
	p.global_position = Vector3(-9, 0.1, 11) if view == "side" else Vector3(-2, 0.1, -2)
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	p.in_move = Vector2(1, 0) if view == "side" else Vector2(0, 1)
	p.in_sprint = true
	for i in 40:
		await physics_frame
	for f in count:
		for i in 3:
			await physics_frame
			var off = Vector3(0.0, 1.2, 4.5) if view == "side" else Vector3(1.5, 1.4, 4.5)
			cam.global_position = p.global_position + off
			cam.look_at(p.global_position + Vector3(0, 0.9, 0))
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join("run_%02d.png" % f))
	quit(0)
