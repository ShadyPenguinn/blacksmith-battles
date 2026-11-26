extends SceneTree
## Headless check of the room minigames: swap bellows, hammer meter and bucket relay (room 1),
## lever pump and four-rope hammer (room 2), two-smith anvil (room 3).
## Run: godot --headless --path storm-forge --script res://tests/minigame_test.gd

var main
var fails = 0

func _initialize() -> void:
	_run()

func check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		print("FAIL  ", what)
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func put(p, pos: Vector3) -> void:
	p.global_position = Vector3(pos.x, 0.1, pos.z)
	p.velocity = Vector3.ZERO

func items_of(kind: String) -> Array:
	return get_nodes_in_group("item").filter(func(i): return i.kind == kind)

## A hot ingot sitting on the anvil.
func hot_ingot(tier: int = 0):
	var ing = main.spawn_item("ingot", main.anvil.global_position + Vector3(0, 1, 0), {"tier": tier})
	main.anvil.accept(ing)
	return ing

## Freeze the hammer meter's marker at m (-1..1) for the next hit.
func marker_at(m: float) -> void:
	var a = main.anvil
	var t = a.slot.tier if a.slot else 0
	a.beat_t = asin(clampf(m, -1.0, 1.0)) / (SF.METER["speed"] + SF.METER["speed_per_tier"] * t)

func next_room() -> void:
	main.door_broken()
	await create_timer(3.3).timeout
	main.lightning.next_in = 9999.0
	main.lightning.warn_t = -1.0

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await frames(5)
	main.lightning.next_in = 9999.0
	var a = main.players[0]
	var b = main.players[1]
	var c = main.players[2]
	main.set_controlled(3)   # the keyboard drives this one; the test drives the others

	# ---- Room 1: swap bellows, hammer meter, bucket relay.
	check(main.furnace.game == "swap" and main.anvil.game == "meter" and main.trough.game == "bucket", "room 1 plays swap bellows, hammer meter and bucket relay")
	check(main.pool != null and main.pool.global_position.distance_to(main.trough.global_position) > 8.0, "the water pool is far from the cooling block")
	check(items_of("tool").filter(func(i): return i.tool == "bucket").size() == 3, "buckets wait by the pool (plus the starting one)")

	var f = main.furnace
	f.heat = 20.0
	check(f.full_side == -1 and f.bellows[1].position.y < f.bellows[0].position.y, "the right bellows starts flat and sunk, the left one full")
	f.stomp(1, 1.0)
	check(f.heat == 20.0, "stomping the flat bellows does nothing")
	f.stomp(-1, 1.0)
	check(f.heat > 20.0 and f.full_side == 1, "stomping the full one heats the furnace and fills the other one")
	var h1 = f.heat
	f.stomp(-1, 1.0)
	check(f.heat == h1, "the one you just flattened can't be stomped again")
	f.stomp(1, 1.0)
	check(f.heat > h1 and f.full_side == -1, "taking turns keeps it pumping")
	await frames(30)
	check(f.bellows[1].position.y < f.bellows[0].position.y - 0.2, "the flattened one sinks down")
	# Landing a real jump on the full bellows works too.
	f.heat = 20.0
	var full = f.bellows[0]
	b.global_position = full.global_position + Vector3(0, 2.4, 0)
	b.velocity = Vector3.ZERO
	for i in 90:
		await physics_frame
		if f.heat > 20.0:
			break
	check(f.heat > 20.0, "jumping onto the full bellows pumps")
	put(b, Vector3(-3, 0, 4))

	# Hammer meter.
	var ing = hot_ingot()
	var an = main.anvil
	check(an.meter.visible == false, "the meter only shows with a hot ingot on the anvil")
	await frames(2)
	check(an.meter.visible, "a hot ingot brings up the meter")
	marker_at(0.0)
	check(an.hammer_hit(a).begins_with("PERFECT"), "a hit with the marker in the middle is Perfect")
	check(absf(an.shape - SF.METER["perfect_shape"]) < 0.01, "a Perfect shapes the ingot")
	marker_at(0.25)
	an.hammer_hit(a)
	check(absf(an.shape - SF.METER["perfect_shape"] - SF.METER["good_shape"]) < 0.01, "a hit near the middle is Good and shapes less")
	var hot0 = ing.hot
	marker_at(0.95)
	check(an.hammer_hit(a).begins_with("Miss") and ing.hot < hot0, "a hit at the edge misses and cools the ingot")
	# A real swing with the hammer reaches the meter.
	a.select(1)
	put(a, an.global_position + Vector3(0, 0, 1.1))
	await frames(2)
	var shape_before = an.shape
	main.do_action(a, "use", {})
	check(a.busy(), "use with the hammer out swings it")
	for i in 120:
		await physics_frame
		if not a.busy():
			break
	check(an.meter_text.text != "" or an.shape != shape_before, "the swing lands on the meter")
	marker_at(0.0)
	an.hammer_hit(a)
	marker_at(0.0)
	an.hammer_hit(a)
	marker_at(0.0)
	an.hammer_hit(a)
	check(an.slot == null and items_of("blank").size() == 1, "enough hits shape a blade")
	await create_timer(SF.DUNK["fling_time"] + 0.3).timeout
	var blade = items_of("blank")[0]
	var tr = main.trough
	check(tr.slot == blade and blade.global_position.distance_to(tr.seat_point()) < 0.3, "the blade flies onto the cooling block")

	# Bucket relay.
	var bk = items_of("tool").filter(func(i): return i.tool == "bucket" and i.is_free())[0]
	b.pick_up(bk)
	b.select(b.slots.find(bk))
	put(b, tr.global_position + Vector3(0, 0, 1.4))
	await frames(2)
	check(main.use(b).begins_with("Empty bucket"), "an empty bucket does nothing to the blade")
	for n in SF.BUCKET["splashes"]:
		put(b, main.pool.global_position + Vector3(0, 0, 2.0))
		await frames(2)
		main.use(b)
		check(bk.bucket_full, "bucket %d fills at the pool" % (n + 1))
		put(b, tr.global_position + Vector3(0, 0, 1.4))
		await frames(2)
		main.use(b)
		check(not bk.bucket_full, "bucket %d splashes the blade" % (n + 1))
	await frames(5)
	check(tr.slot == null and items_of("weapon").size() == 1, "three buckets cool the blade into a finished sword")
	b.drop_item(bk)

	# ---- Room 2: lever pump, four-rope hammer, dunk tank.
	await next_room()
	f = main.furnace
	an = main.anvil
	check(f.game == "lever" and an.game == "ropes" and main.trough.game == "dunk", "room 2 plays lever pump, four-rope hammer and dunk tank")
	check(f.levers.size() == 2 and f.bellows.is_empty(), "the furnace has two levers instead of bellows")
	var lv = f.levers[1][1].global_position
	put(a, lv + Vector3(0, 0, 0.9))
	await frames(2)
	check(f.lever_near(a) == 1, "standing by a lever lets you work it")
	f.heat = 10.0
	main.do_action(a, "use", {})
	check(f.lever_up[1] and f.heat > 10.0, "use pulls the lever up and blows air in")
	await create_timer(0.8).timeout
	var h2 = f.heat
	main.do_action(a, "use", {})
	await frames(2)
	check(f.lever_up[1] and f.heat <= h2, "pulling it up again does nothing")
	await create_timer(0.8).timeout
	var h3 = f.heat
	main.do_action(a, "interact", {})
	check(not f.lever_up[1] and f.heat > h3, "grab pushes it back down and blows air in")
	await create_timer(0.8).timeout

	check(an.rope_count == 4 and an.handles.size() == 4, "the four-rope hammer has four ropes")
	var ing2 = hot_ingot(0)
	var away = Vector3(an.rope_anchor().x - an.global_position.x, 0, 1.0).normalized()
	var per: float = SF.ROPES["per_rope"]
	for p in [a, b]:
		put(p, an.handle_rest(0 if p == a else 3))
		await frames(3)
	main.do_action(a, "use", {})
	a.in_hold = true
	a.in_move = Vector2(away.x, away.z)
	for i in 200:
		await physics_frame
	check(a.rope == an and an.ham_h <= per + 0.01 and an.ham_h > per - 0.1, "one smith alone only lifts it one rope's height")
	main.do_action(b, "use", {})
	b.in_hold = true
	b.in_move = Vector2(away.x, away.z)
	for i in 200:
		await physics_frame
	check(b.rope == an and an.ham_h > per + 0.2 and an.ham_h <= per * 2.0 + 0.01, "a second smith on another rope lifts it higher")
	# Offline parking: switch away from a smith on a rope and they keep holding it.
	a.in_move = Vector2.ZERO
	b.in_move = Vector2.ZERO
	main.set_controlled(0)
	main.set_controlled(3)
	check(b.in_hold and b.rope == an, "a smith you switch away from keeps holding their rope")
	# The smith you control lets go: everyone parked on the ropes lets go too, and it drops.
	a.rope = an
	a.in_hold = true
	a.controlled = true
	await frames(2)
	a.in_hold = false
	var shape0 = an.shape
	for i in 40:
		await physics_frame
	a.controlled = false
	check(a.rope == null and b.rope == null, "when you let go, the smiths you parked let go too")
	check(an.ham_h == 0.0 and an.shape > shape0, "the hammer drops and shapes the ingot")
	if is_instance_valid(ing2):
		main.despawn(ing2)

	# ---- Room 3: classic bellows, two-smith anvil, bucket relay.
	await next_room()
	an = main.anvil
	check(main.furnace.game == "stomp" and an.game == "duo" and main.trough.game == "bucket", "room 3 plays stomp bellows, two-smith anvil and bucket relay")
	check(an.size.x > 2.0 and an.spots.size() == 2, "the big anvil has a ring on each side")
	hot_ingot(0)
	await frames(2)
	put(a, an.spots[0].global_position)
	put(b, an.spots[1].global_position)
	await frames(2)
	check(an.duo_spot(a) == 0 and an.duo_spot(b) == 1, "each smith stands in a ring")
	marker_at(0.0)
	check(an.hammer_hit(a).begins_with("Now your partner") and an.shape == 0.0, "one smith alone doesn't shape it")
	marker_at(0.0)
	an.hammer_hit(b)
	check(absf(an.shape - SF.DUO["shape"] * 1.5) < 0.01, "both hitting the middle together shapes it")
	an.duo_hits = [-10.0, -10.0]
	marker_at(0.0)
	an.hammer_hit(a)
	await create_timer(SF.DUO["window"] + 0.2).timeout
	var s1 = an.shape
	marker_at(0.0)
	an.hammer_hit(b)
	check(an.shape == s1, "hits too far apart don't count")
	# Offline helper: swing in one ring and the smith parked in the other ring swings too.
	a.select(1)
	b.select(0)
	main.do_action(a, "use", {})
	check(a.busy() and b.busy() and b.held.tool == "hammer", "the smith parked in the other ring swings with you")

	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
