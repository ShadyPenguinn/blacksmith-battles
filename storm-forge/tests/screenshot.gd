extends SceneTree
## Renders a few staged frames to PNG. Needs a display (use xvfb-run on a server).
## Run: godot --path storm-forge --script res://tests/screenshot.gd -- <output dir>

func _initialize() -> void:
	_run()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	print("saved ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	root.size = Vector2i(1600, 900)
	var main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await frames(10)
	var miner = main.players[0]
	var smelter = main.players[1]
	var smith = main.players[2]
	var finisher = main.players[3]
	# Stage a busy forge.
	miner.global_position = Vector3(-3.0, 0.1, 2.2)
	smelter.global_position = Vector3(-4.2, 0.1, -1.2)
	smith.global_position = Vector3(-1.2, 0.1, -1.6)
	finisher.global_position = Vector3(3.2, 0.1, -1.6)
	main.furnace.contents = {"copper": 2}
	main.furnace.heat = 48.0
	var ingot = main.spawn_item("ingot", main.anvil.global_position, {"tier": 0})
	main.anvil.accept(ingot)
	main.anvil.hits = 2
	var blank = main.spawn_item("blank", main.grindstone.global_position, {"tier": 0})
	main.grindstone.accept(blank)
	blank.quenched = true
	for i in 3:
		main.spawn_item("ore", Vector3(-6.5 + i * 0.7, 0.5, 1.0), {"ore": "copper"})
	for i in 2:
		miner.pick_up(main.spawn_item("ore", miner.hand_position(), {"ore": "copper"}))
	main.set_controlled(0)
	main.time_left = 95.0
	main.lightning.next_in = 9999.0
	await frames(90)
	main.lightning.begin_warning(miner)
	main.lightning.warn_t = 1000.0  # hold the warning ring on screen
	await frames(30)
	main.furnace.heat = 48.0
	ingot.hot = SF.INGOT_HOT_TIME
	await shot(out, "storm-forge-forge.png")
	main.lightning.warn_t = -1.0
	main.lightning.ring.visible = false
	main.lightning.target = miner
	main.lightning.strike(miner.global_position)
	await frames(1)
	await shot(out, "storm-forge-strike.png")
	await frames(30)
	await shot(out, "storm-forge-zapped.png")
	quit(0)
