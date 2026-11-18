extends SceneTree
## Two-process online test over localhost. Run the host and the client at the same time:
##   godot --headless --path storm-forge --script res://tests/net_test.gd -- host --autostart 2
##   godot --headless --path storm-forge --script res://tests/net_test.gd -- client
## The client presses buttons and moves; the host checks it saw them, then strikes the
## client's smith with lightning and the client checks it saw that.

var main
var fails = 0
var who = ""

func _initialize() -> void:
	_run()

func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + who + ": " + what)
	if not cond:
		fails += 1

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func wait_until(cond: Callable, timeout: float) -> bool:
	var t = 0.0
	while not cond.call() and t < timeout:
		await process_frame
		t += 0.016
		await create_timer(0.016).timeout
	return cond.call()

func finish() -> void:
	print("RESULT ", who, " ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	who = args[0] if args.size() > 0 else "host"
	main = load("res://main.tscn").instantiate()
	main.start_mode = "host" if who == "host" else "client"
	main.join_ip = "127.0.0.1"
	root.add_child(main)
	if who == "host":
		await _host()
	else:
		await _client()
	finish()

func _host() -> void:
	check(await wait_until(func(): return main.run_started, 20.0), "run starts when the second player joins")
	check(main.players.size() == 2, "two smiths in a two-player game")
	main.lightning.next_in = 9999.0
	var p1 = main.players[1]
	p1.global_position = main.furnace.global_position + Vector3(1.5, 0, 1.6)
	check(await wait_until(func(): return main.furnace.heat > 0.0, 15.0), "client's Use pumped the bellows on the host")
	var x0 = p1.global_position.x
	check(await wait_until(func(): return p1.global_position.x > x0 + 0.8, 15.0), "client's movement moved its smith on the host")
	await wait(1.0)
	main.lightning.target = p1
	main.lightning.strike(p1.global_position)
	check(p1.stun > 0.0, "host strikes the client's smith")
	await wait(1.5)
	var ingot = main.spawn_item("ingot", Vector3(0, 1, 0), {"tier": 0})
	await wait(1.5)
	main.despawn(ingot)
	await wait(1.5)
	main.door_broken()
	check(main.paused_for_roll, "host breaks the door")
	await wait_until(func(): return main.net.lobby_peers.size() == 1, 20.0)
	check(main.net.lobby_peers.size() == 1, "client disconnected cleanly")

func _client() -> void:
	check(await wait_until(func(): return main.run_started, 20.0), "client gets the start message")
	check(main.controlled == 1, "client controls smith 2 (Smelter)")
	await wait(1.0)
	var me = main.players[1]
	check(me.held != null and me.held.tool == "tongs", "client sees its own tongs in hand")
	check(main.items_by_id.size() == 4, "client sees all four tools")
	check(main.area_nodes.size() > 0, "client built the ore nodes")
	main.net.send_action("slot_next", {})
	check(await wait_until(func(): return me.sel == 1 and me.held == null, 5.0), "client's scroll changes its hotbar slot")
	main.net.send_action("slot_1", {})
	check(await wait_until(func(): return me.sel == 0 and me.held != null, 5.0), "client switches back to its tool")
	await wait(1.0)
	for i in 6:
		main.net.send_action("use", {})
		await wait(0.1)
	check(await wait_until(func(): return main.furnace.heat > 0.0, 5.0), "furnace heat came back to the client")
	var x0 = me.global_position.x
	main.net.scripted_input = true
	main.net.last_move = Vector2(1, 0)
	await wait(0.6)
	main.net.last_move = Vector2.ZERO
	check(await wait_until(func(): return me.global_position.x > x0 + 0.8, 5.0), "client sees its smith move")
	check(await wait_until(func(): return me.stun > 0.0, 15.0), "client sees its smith get struck")
	check(main.toasts.any(func(t): return t.begins_with("ZAP!")), "client got the ZAP message")
	await wait(0.5)
	check(me.held == null, "client sees the tongs knocked loose")
	check(await wait_until(func(): return main.items_by_id.size() == 5, 6.0), "client sees a new ingot appear")
	check(await wait_until(func(): return main.items_by_id.size() == 4, 6.0), "client sees it disappear")
	check(await wait_until(func(): return main.paused_for_roll, 6.0), "client sees the buff/debuff roll")
	check(await wait_until(func(): return main.door_index == 1 and not main.paused_for_roll, 8.0), "client moves on to door 2")
	check(main.furnace.global_position.z < -14.0 and main.area_nodes.size() > 0, "client built the second area past the old door")
