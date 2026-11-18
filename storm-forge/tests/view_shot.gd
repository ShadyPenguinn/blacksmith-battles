extends SceneTree
## Screenshot of the menu (-- menu <dir>) or of a client's view (-- client <dir>, with a host running).

func _initialize() -> void:
	_run()

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var which: String = args[0]
	var out: String = args[1]
	root.size = Vector2i(1600, 900)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "menu" if which == "menu" else "client"
	root.add_child(main)
	if which == "client":
		while not main.run_started:
			await create_timer(0.2).timeout
		await create_timer(3.0).timeout
	else:
		await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join("storm-forge-%s.png" % which))
	print("saved ", which)
	quit(0)
