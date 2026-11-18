extends SceneTree
## Close-up frames of a smith: idle, walking, mining, struck. -- <out dir>
func _initialize() -> void:
	_run()
func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1200, 800)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await create_timer(0.5).timeout
	main.lightning.next_in = 9999.0
	var p = main.players[0]
	main.set_controlled(1)
	p.global_position = Vector3(0, 0.1, 6)
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var shots = [["idle", Vector2.ZERO, ""], ["walk", Vector2(1, 0), ""], ["away", Vector2(0, -1), ""], ["mine", Vector2.ZERO, "pickaxe"], ["stun", Vector2.ZERO, "stun"]]
	for s in shots:
		p.in_move = s[1]
		if s[2] == "pickaxe":
			p.act("pickaxe")
		if s[2] == "stun":
			p.zap()
		for i in 25:
			await physics_frame
			cam.global_position = p.global_position + Vector3(2.2, 2.2, 3.2)
			cam.look_at(p.global_position + Vector3(0, 0.9, 0))
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join("close_%s.png" % s[0]))
		print(s[0], " anim=", p.anim.current_animation if p.anim else "none", " state=", p.anim_state)
		p.in_move = Vector2.ZERO
		print("  held=", p.held.display_name() if p.held else "none", " at ", p.held.global_position if p.held else Vector3.ZERO, " hand ", p.hand_position(), " body ", p.global_position)
	quit(0)
