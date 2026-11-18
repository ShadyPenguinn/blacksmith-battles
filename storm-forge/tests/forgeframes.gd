extends SceneTree
## Frames of the furnace glow, the rope hammer and the dunk tank, to judge them.
## -- <out dir> [fire|hammer|dunk]   Saves f_XXX.png (fire: one still per heat level).

func _initialize() -> void:
	_run()

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var out: String = args[0]
	var what: String = args[1] if args.size() > 1 else "hammer"
	root.size = Vector2i(900, 640)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await create_timer(0.5).timeout
	main.lightning.next_in = 9999.0
	main.hud.visible = false
	main.set_controlled(3)
	var miner = main.players[0]
	var smelter = main.players[1]
	var smith = main.players[2]
	var finisher = main.players[3]
	for o in main.players:
		o.global_position = Vector3(10 + o.idx, 0.1, 6)
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 45
	var n = 0
	match what:
		"fire":
			var f = main.furnace
			cam.global_position = f.global_position + Vector3(0, 1.2, 5.5)
			cam.look_at(f.global_position + Vector3(0, -0.3, 0))
			f.contents = {"copper": 1}
			for h in [0.0, 18.0, 45.0, 64.0, 70.0]:
				for i in 20:
					f.heat = h
					f.smelt = 0.0
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(out.path_join("f_%03d.png" % n))
				n += 1
			quit(0)
			return
		"hammer":
			var anv = main.anvil
			var ingot = main.spawn_item("ingot", anv.global_position, {"tier": 0})
			anv.accept(ingot)
			anv.shape = 2.2
			smelter.global_position = anv.global_position + Vector3(-0.9, 0.1, 1.2)
			for p in [smith, miner]:
				p.global_position = anv.handle_rest() + Vector3(0.25 * p.idx - 0.25, -0.9, 0.3)
			var focus = Vector3(1.4, 1.2, -3.0)
			cam.global_position = focus + Vector3(0, 4.2, 9.5)
			cam.look_at(focus)
			for i in 10:
				await physics_frame
			for t in 230:
				if t == 8:
					main.do_action(smith, "use", {})
					smith.in_hold = true
					smith.in_move = Vector2(0.35, 1).normalized()
				if t == 20:
					main.do_action(miner, "use", {})
					miner.in_hold = true
					miner.in_move = Vector2(0.8, 0.6).normalized()
				if t == 120:
					for p in [smith, miner]:
						p.in_hold = false
						p.in_move = Vector2.ZERO
				await physics_frame
				if t % 2 == 0:
					await RenderingServer.frame_post_draw
					root.get_viewport().get_texture().get_image().save_png(out.path_join("f_%03d.png" % n))
					n += 1
		"dunk":
			var tank = main.trough
			var blade = main.spawn_item("blank", tank.global_position, {"tier": 0})
			tank.accept(blade)
			miner.global_position = Vector3(tank.global_position.x, 0.1, tank.global_position.z + 4.5)
			miner.facing = Vector3(0, 0, -1)
			miner.vis_yaw = 0.0
			var rock = main.spawn_item("ore", miner.hand_position(), {"ore": "copper"})
			miner.pick_up(rock)
			miner.select(1)
			var focus = tank.global_position + Vector3(0, 0.9, 1.6)
			cam.global_position = focus + Vector3(3.2, 2.6, 6.2)
			cam.look_at(focus)
			for i in 10:
				await physics_frame
			var spd = SF.DUNK["speed"] * (1.0 + SF.DUNK["speed_per_area"] * main.door_index)
			for t in 220:
				if t == 30:
					# Time the throw so the target slides into the lane as the chunk arrives.
					tank.beat_t = (TAU - 0.98 * spd) / spd
					main.do_action(miner, "throw", {})
				await physics_frame
				if t % 2 == 0:
					await RenderingServer.frame_post_draw
					root.get_viewport().get_texture().get_image().save_png(out.path_join("f_%03d.png" % n))
					n += 1
			print("WEAPONS ", get_nodes_in_group("item").filter(func(i): return i.kind == "weapon").size())
	quit(0)
