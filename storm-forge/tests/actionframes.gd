extends SceneTree
## Frames of the work swings and a lightning launch, to judge them.
## -- <out dir> [mine|hammer|zap]   Saves act_XXX.png, one every 2 physics frames.

func _initialize() -> void:
	_run()

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var out: String = args[0]
	var what: String = args[1] if args.size() > 1 else "mine"
	root.size = Vector2i(900, 700)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await create_timer(0.5).timeout
	main.lightning.next_in = 9999.0
	main.hud.visible = false
	var p = main.players[0]
	var target: Node3D
	match what:
		"mine":
			target = get_nodes_in_group("node")[0]
			p.global_position = target.global_position + Vector3(1.4, 0.1, 0.3)
		"hammer":
			p = main.players[2]
			target = main.anvil
			p.global_position = target.global_position + Vector3(0, 0.1, 1.3)
		"zap":
			target = p
			p.global_position = main.area_center() + Vector3(0, 0.1, 3)
	main.set_controlled(p.idx)
	for o in main.players:
		if o != p:
			o.global_position = Vector3(10 + o.idx, 0.1, -8)
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 45
	var focus = (p.global_position + target.global_position) * 0.5 + Vector3(0, 0.8, 0)
	cam.global_position = focus + Vector3(1.2, 2.4, 4.2)
	cam.look_at(focus)
	for i in 10:
		await physics_frame
	var n = 0
	var presses = [0, 50] if what != "zap" else []
	for t in (100 if what != "zap" else 110):
		if t in presses:
			main.do_action(p, "use", {})
		if what == "zap" and t == 5:
			main.lightning.target = p
			main.lightning.strike(p.global_position)
		await physics_frame
		if what == "zap":
			var f = cam.global_position.lerp(p.global_position + Vector3(0, 4.0, 7.0), 0.15)
			cam.global_position = f
			cam.look_at(p.global_position + Vector3(0, 0.8, 0))
		if t % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out.path_join("act_%03d.png" % n))
			n += 1
	quit(0)
