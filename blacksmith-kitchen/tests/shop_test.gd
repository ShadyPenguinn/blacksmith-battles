extends SceneTree
## Plays a shop day with a bot: it walks to whichever station is marked next and lets every
## minigame finish on its own. Prints what happens and the day's results.
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/shop_test.gd -- DAY [OUTDIR]
var main
var out := ""
var day := 0
var t := 0.0
var next_shot := 3.0
var n := 0
var last_note := ""

func _initialize():
	var a = OS.get_cmdline_user_args()
	day = int(a[0]) if a.size() > 0 else 0
	out = a[1] if a.size() > 1 else ""
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_go.call_deferred()

func _go():
	await create_timer(0.5).timeout
	main.autoplay = 1.2
	main.start_day(day)

func _process(delta: float) -> bool:
	t += delta
	var shop = main.shop
	if shop and is_instance_valid(shop) and not shop.over:
		var note = "busy=%s held=%s next=%s tickets=%d queue=%d furnace=%s mold=%s results=%s" % [shop.busy, shop.smith.held != null, shop.next_station(), shop.tickets.size(), shop.queue.size(), shop.furnace["state"], shop.mold["state"], str(shop.results)]
		if note != last_note:
			print("%6.1f  %s" % [t, note])
			last_note = note
		if not shop.busy and shop.smith.auto_target == null:
			var st = shop.next_station()
			if st == "item":
				var ip = shop.floor_item().global_position
				shop.pending = "floor"
				shop.smith.auto_target = Vector3(ip.x, 0, ip.z)
			elif st != "":
				if shop._station_near(shop.smith) == st:
					shop.interact(shop.smith)
				else:
					shop.pending = st
					shop.smith.auto_target = shop.SPOTS[st]
	if out != "" and t >= next_shot:
		next_shot += 4.0
		root.get_texture().get_image().save_png(out + "/s_%03d.png" % n)
		n += 1
	if main.mode == "day" and main.shop == null and t > 3.0:
		print("DAY OVER results=", main.day_results)
		return true
	if t > 420.0:
		print("TIMEOUT")
		return true
	return false
