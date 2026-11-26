extends SceneTree
## Plays one sword through the whole Rush Hour pipeline by calling the station actions.
var main
var r
var s
func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func at(spot: Vector3):
	s.global_position = spot

func wait(t): 
	await create_timer(t).timeout

func _run():
	print("run start")
	await wait(0.5)
	print("starting"); main.start_rush(1); print("started")
	r = main.rush
	s = r.smiths[0]
	s.set_process(false)
	r.orders[0]["weapon"] = "sword"
	at(r.SPOTS["rock"]); r.grab(s); print("held ", s.held.kind)
	at(r.SPOTS["furnace"]); r.grab(s); print("load ", r.load)
	var i = 0
	for k in 100:
		if r.heat < 48:
			at(r.SPOTS["bellows_l" if i % 2 == 0 else "bellows_r"]); r.use(s); i += 1
		await wait(0.1)
		var ingots = r.items.filter(func(it): return it.kind == "ingot")
		if not ingots.is_empty(): break
	await wait(1.2)
	var ingot = r.items.filter(func(it): return it.kind == "ingot")[0]
	at(ingot.global_position); s.take(ingot); s.tongs = true
	at(r.SPOTS["anvil"]); r.tongs_release(s, ingot); print("anvil ", r.anvil_item, " weapon ", r.anvil_item.weapon)
	while r.anvil_item.kind == "ingot":
		r.marker = 0.5; r.use(s); await wait(0.05)
	r.grab(s); print("held ", s.held.kind)
	at(r.SPOTS["tank"]); r.grab(s); print("tank ", r.tank_item.kind)
	await wait(1.5); r.grab(s); print("held ", s.held.kind, " brittle ", s.held.brittle)
	at(r.SPOTS["grind"]); r.grab(s)
	for j in 10: r.use(s)
	r.grab(s); print("held ", s.held.kind)
	at(r.SPOTS["counter"]); r.grab(s); print("coins ", r.coins, " served ", r.served)
	# bucket
	var b = r.items.filter(func(it): return it.kind == "bucket")[0]
	at(b.global_position); r.grab(s); at(r.well); r.use(s); at(r.SPOTS["tank"]); r.use(s); print("water ", r.water)
	r.time_left = 0.1
	await wait(0.5)
	print("over ", r.over)
	main._to_menu()
	await wait(0.3)
	print("DONE")
	quit()
