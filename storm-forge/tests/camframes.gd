extends SceneTree
## Frames from the game camera as a smith walks through an open door into the next
## area and back, to judge the camera glide. -- <out dir>   Saves c_XXX.png.

func _initialize() -> void:
	_run()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(800, 450)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await create_timer(0.5).timeout
	main.lightning.next_in = 9999.0
	main.door_broken()
	await create_timer(3.5).timeout
	main.lightning.next_in = 9999.0
	var p = main.players[0]
	p.global_position = Vector3(0, 0.1, -6)
	for i in 60:
		await physics_frame
	var n = 0
	for t in 330:
		p.in_move = Vector2(0, -1) if t < 170 else Vector2(0, 1)
		main.players[0].in_sprint = false
		await physics_frame
		if t % 3 == 0:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out.path_join("c_%03d.png" % n))
			n += 1
	quit(0)
