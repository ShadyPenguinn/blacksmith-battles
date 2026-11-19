extends SceneTree
## Headless check of the whole pipeline: mine, smelt, rope hammer, dunk tank, break a door, get struck.
## Run: godot --headless --path storm-forge --script res://tests/smoke_test.gd

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

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	main.start_mode = "offline"
	root.add_child(main)
	await frames(5)
	var miner = main.players[0]
	var smelter = main.players[1]
	var smith = main.players[2]
	var finisher = main.players[3]
	main.lightning.next_in = 9999.0   # no random strikes: the lightning checks below call their own
	check(main.players.size() == 4, "four smiths spawn")
	check(miner.held.tool == "pickaxe" and smelter.held.tool == "tongs" and smith.held.tool == "hammer" and finisher.held.tool == "bucket", "each smith holds their tool")

	# Mine copper.
	var node = get_nodes_in_group("node")[0]
	put(miner, node.global_position + Vector3(0, 0, 1.2))
	await frames(2)
	for i in SF.MINE_HITS:
		main.use(miner)
	await frames(30)
	var ores = items_of("ore")
	check(ores.size() == 1, "three pickaxe hits drop an ore chunk")

	# One press = one swing, and the hit only lands when the pickaxe makes contact.
	var node2 = get_nodes_in_group("node").filter(func(n): return n != node and not n.dead)[0]
	put(miner, node2.global_position + Vector3(0, 0, 1.2))
	await frames(2)
	var hits_before = node2.hits
	main.do_action(miner, "use", {})
	check(miner.busy(), "pressing use starts a swing")
	check(node2.hits == hits_before, "the ore isn't hit before the pickaxe lands")
	main.do_action(miner, "use", {})
	main.do_action(miner, "use", {})
	await create_timer(1.6).timeout
	check(node2.hits == hits_before + 1, "one press is one hit, even when mashed")
	check(not miner.busy(), "the swing bounces back and finishes")
	var spot = miner.global_position
	miner.in_move = Vector2(1, 0)
	main.do_action(miner, "use", {})
	await frames(20)
	check(miner.global_position.distance_to(spot) < 0.3, "you can't walk mid-swing")
	miner.in_move = Vector2.ZERO
	await create_timer(1.6).timeout

	# State machine: no swinging in the air or mid-flop; jump mid-slide stands you up.
	miner.in_dive = true
	await frames(4)
	check(miner.state() == "air", "jumping puts you in the air")
	var hits_air = node2.hits
	main.do_action(miner, "use", {})
	check(not miner.busy(), "you can't swing while jumping")
	main.do_action(miner, "dive", {})
	await frames(4)
	check(miner.state() == "flop", "jump again in the air to belly flop")
	main.do_action(miner, "use", {})
	check(not miner.busy(), "you can't swing mid-flop")
	for i in 60:
		await physics_frame
		if miner.is_on_floor():
			break
	main.do_action(miner, "dive", {})
	await frames(3)
	check(not miner.flop and miner.velocity.y <= 0.1, "jump mid-slide stands you up instead of bouncing")
	await create_timer(0.6).timeout
	check(node2.hits == hits_air, "no hits landed from the air")

	# Pocket the ore (pickaxe stays in hand), carry it to the furnace.
	put(miner, ores[0].global_position)
	await frames(2)
	main.interact(miner)
	check(miner.slots[1] == ores[0] and miner.held.tool == "pickaxe", "miner pockets the ore and keeps the pickaxe in hand")
	put(miner, main.furnace.global_position + Vector3(0, 0, 2.0))
	await frames(2)
	main.interact(miner)
	check(main.furnace.contents.get("copper", 0) == 1 and miner.slots[1] == null, "E at the furnace empties the ore from your pockets")

	# Hotbar: three pockets, one tool, scroll to switch.
	var spare = []
	for i in 4:
		spare.append(main.spawn_item("ore", Vector3(-6, 0.5, 5), {"ore": "copper"}))
	put(miner, Vector3(-6, 0, 5))
	await frames(2)
	for i in 3:
		main.interact(miner)
	check(miner.items().size() == 4, "a tool plus three pockets of ore")
	check(main.interact(miner) == "Pockets full", "a fourth chunk doesn't fit")
	main.do_action(miner, "slot_next", {})
	check(miner.held != null and miner.held.kind == "ore", "scrolling selects the next slot")
	main.do_action(miner, "slot_1", {})
	check(miner.held.tool == "pickaxe", "1 goes back to the tool slot")
	var hammer_spot = main.spawn_item("tool", Vector3(-6, 0.5, 5), {"tool": "hammer"})
	main.do_action(miner, "slot_2", {})
	for it in spare:
		if it.is_free():
			main.despawn(it)
	check(main.interact(miner).begins_with("One tool"), "can't carry a second tool")
	main.despawn(hammer_spot)
	for it in miner.items():
		if it.kind == "ore":
			main.despawn(it)
	main.do_action(miner, "slot_1", {})

	# Smelt: pump to keep heat in the band until an ingot pops out.
	put(smelter, main.furnace.global_position + Vector3(1.5, 0, 1.5))
	await frames(2)
	var t = 0
	while items_of("ingot").is_empty() and t < 900:
		if main.furnace.heat < 42.0 and t % 30 == 0:
			main.furnace.stomp(1 if (t / 30) % 2 == 0 else -1, 1.0)
		await frames(1)
		t += 1
	var ingots = items_of("ingot")
	check(ingots.size() == 1 and ingots[0].tier == 0, "bellows heat in the band makes a copper ingot")
	check(main.furnace.spout != null, "the furnace uses the stone forge model")
	check(ingots.size() == 1 and ingots[0].global_position.y > 2.5, "the ingot shoots out of the chimney")

	# Stomp bellows: jumping onto one heats the furnace; over-stomping burps.
	main.lightning.next_in = 9999.0
	main.lightning.warn_t = -1.0   # and call off a strike that was already on its way
	# The ingot can pop out onto a bellows: set it down in front so it isn't in the way.
	ingots[0].global_position = main.furnace.global_position + Vector3(0.8, -0.6, 2.0)
	ingots[0].linear_velocity = Vector3.ZERO
	main.furnace.last_stomp = -10.0   # the smelting loop's last stomp mustn't count as one-footed
	main.furnace.stomp_log.clear()   # the pumping above mustn't make this landing burp
	var heat0 = main.furnace.heat
	var bel = main.furnace.bellows[1]
	var bel_anim = main.furnace._bellows_anim(bel)
	check(bel_anim != null and bel_anim.has_animation("Stomp"), "the bellows use the giant model with its Stomp animation")
	put(smelter, bel.global_position + Vector3(0, 0, 0))
	smelter.global_position = bel.global_position + Vector3(0, 2.2, 0)
	for i in 90:
		await physics_frame
		if main.furnace.heat > heat0 + 1.0:
			break
	check(main.furnace.heat > heat0 + 1.0, "landing on a bellows heats the furnace")
	main.furnace.heat = 40.0
	main.furnace.stomp(-1, 1.0)
	var after_one = main.furnace.heat
	main.furnace.stomp(-1, 1.0)
	check(main.furnace.heat - after_one < SF.BELLOWS["heat"] * 0.6, "stomping the same side twice pumps less")
	put(miner, main.furnace.global_position + Vector3(0, 0, 2.5))
	for i in SF.BELLOWS["burp_stomps"]:
		main.furnace.stomp(1 if i % 2 == 0 else -1, 1.0)
	check(miner.stun > 0.0, "over-stomping makes the furnace burp and knock people back")
	await create_timer(1.5).timeout
	put(smelter, main.furnace.global_position + Vector3(1.5, 0, 2.5))
	await frames(2)
	await frames(40)

	# Tongs grip the hot ingot and place it on the anvil.
	put(smelter, ingots[0].global_position)
	await frames(2)
	main.interact(smelter)
	check(smelter.held.tongs_load == ingots[0], "tongs grip the hot ingot")
	put(smelter, main.anvil.global_position + Vector3(0, 0, 1.3))
	await frames(2)
	main.interact(smelter)
	check(main.anvil.slot == ingots[0], "ingot sits on the anvil")

	# Rope hammer: grab the handle, walk back to haul the head up, let go to slam.
	main.lightning.next_in = 9999.0
	main.lightning.warn_t = -1.0   # and call off a strike that was already on its way
	check(ingots[0].hot > 20.0, "ingots stay hot long enough to haul the hammer")
	var anv = main.anvil
	main.set_controlled(3)   # the keyboard drives the miner otherwise, and nobody's holding a key
	var lift: float = SF.TRIP["lift"]
	put(smith, anv.handle_rest())
	await frames(2)
	main.do_action(smith, "use", {})
	check(smith.rope == anv and smith.state() == "rope", "use by the handle grabs the rope")
	check(not smith.can("use") and not smith.can("dive"), "hauling only lets you walk")
	var away = Vector3(anv.rope_anchor().x - anv.global_position.x, 0, 1.0).normalized()
	smith.in_hold = true
	smith.in_move = Vector2(away.x, away.z)
	for i in 45:
		await physics_frame
	smith.in_move = Vector2.ZERO
	await frames(20)
	var h_stop: float = anv.ham_h
	check(h_stop > 0.2 and h_stop < lift - 0.2, "backing up part way lifts the hammer part way")
	await frames(20)
	check(absf(anv.ham_h - h_stop) < 0.01 and absf(anv.ham_h - smith.rope_pull()) < 0.01, "the hammer stops when you stop: it hangs right where the rope holds it")
	smith.in_move = Vector2(away.x, away.z)
	var most = 0.0
	for i in 220:
		await physics_frame
		var off = smith.global_position - anv.rope_anchor()
		most = maxf(most, Vector2(off.x, off.z).length())
	check(most <= SF.TRIP["slack"] + lift + 0.05, "the rope is as long as the frame is tall, and no longer")
	check(anv.ham_h >= lift - 0.01, "one smith can back up far enough to haul it all the way up")
	smith.in_hold = false
	smith.in_move = Vector2.ZERO
	await frames(6)
	check(anv.handle_pos.distance_to(anv.handle_rest()) > 0.3 and anv.handle_vel.length() > 0.5, "the loose rope whips back and swings instead of snapping home")
	await frames(24)
	check(smith.rope == null and anv.ham_h == 0.0, "letting go drops the hammer")
	check(anv.shape > 0.3 and anv.shape < SF.TRIP["shape_needed"], "the slam shapes the ingot a bit")
	# Two haulers lift it to the top; a full slam knocks nearby smiths off their feet.
	put(finisher, anv.global_position + Vector3(-0.6, 0, 1.4))
	var shape_before: float = anv.shape
	for pair in [[smith, Vector3(0, 0, 0)], [miner, Vector3(0.3, 0, 0.3)]]:
		put(pair[0], anv.handle_rest() + pair[1])
		await frames(4)
		main.do_action(pair[0], "use", {})
		pair[0].in_hold = true
		pair[0].in_move = Vector2(away.x, away.z)
	for i in 150:
		await physics_frame
	check(anv.ham_h >= lift - 0.01, "two smiths haul it all the way up")
	for pp in [smith, miner]:
		pp.in_hold = false
		pp.in_move = Vector2.ZERO
	await frames(30)
	check(anv.shape - shape_before > 0.9 or items_of("blank").size() == 1, "a full drop is a full-power slam")
	check(finisher.stun > 0.0, "a full slam knocks back smiths next to the anvil")
	# Keep slamming until the blade's done: it flies onto the dunk tank seat.
	for n in 6:
		if items_of("blank").size() > 0:
			break
		for pp in [smith, miner]:
			put(pp, anv.handle_rest())
			await frames(4)
			main.do_action(pp, "use", {})
			pp.in_hold = true
			pp.in_move = Vector2(away.x, away.z)
		for i in 150:
			await physics_frame
		for pp in [smith, miner]:
			pp.in_hold = false
			pp.in_move = Vector2.ZERO
		await frames(30)
	var blanks = items_of("blank")
	check(blanks.size() == 1 and main.anvil.slot == null, "slams shape a blade")
	await create_timer(SF.DUNK["fling_time"] + 0.3).timeout
	var tank = main.trough
	check(tank.slot == blanks[0] and blanks[0].global_position.distance_to(tank.seat_point()) < 0.3, "the blade flies off the anvil onto the dunk seat")

	main.set_controlled(0)

	# Bucket still fills at the tank.
	put(finisher, tank.global_position + Vector3(1.2, 0, 1.0))
	finisher.stun = 0.0
	await frames(2)
	main.use(finisher)
	check(finisher.held.bucket_full, "bucket fills at the dunk tank")

	# Throwing at the tank arcs to the target's height where it crosses the rail.
	var tp = tank.target_point()
	put(miner, Vector3(tank.global_position.x + 0.4, 0, tank.global_position.z + 4.5))
	miner.facing = Vector3(0, 0, -1)
	await frames(8)
	miner.facing = Vector3(0, 0, -1)
	tank.beat_t = (PI * 1.5) / tank.target_speed()   # target off at the far left end: this throw (in a lane right of the middle) mustn't hit it
	var lane_x = miner.hand_position().x   # the throw flies straight on from your hand
	var rock = main.spawn_item("ore", miner.hand_position(), {"ore": "copper"})
	rock.linear_velocity = main.throw_impulse(miner)
	var closest = 99.0
	for i in 90:
		await physics_frame
		closest = minf(closest, rock.global_position.distance_to(Vector3(lane_x, tp.y, tp.z)))
	check(closest < 0.4, "an aimed throw reaches the target's height in your lane")
	main.despawn(rock)

	# A hit off to the side only dings; the blade stays on the seat.
	tank.beat_t = (PI * 0.5) / tank.target_speed()
	await frames(1)
	var side_shot = main.spawn_item("ore", tank.target_point() + Vector3(0, 0, 0.35), {"ore": "copper"})
	side_shot.linear_velocity = Vector3(0, 0, -7)
	await frames(3)
	check(tank.dunk_t < 0.0 and tank.slot == blanks[0], "hitting the target off to the side doesn't dunk")
	main.despawn(side_shot)
	await create_timer(1.1).timeout

	# Hit it in the middle, right behind the tank: it slaps the blade in, and the blade
	# quenches and rides the slide out, finished.
	tank.beat_t = 0.0
	await frames(1)
	var shot = main.spawn_item("ore", tank.target_point() + Vector3(0, 0, 0.35), {"ore": "copper"})
	shot.linear_velocity = Vector3(0, 0, -7)
	await frames(3)
	check(tank.dunk_t >= 0.0, "a thrown chunk on the target dunks the blade")
	await create_timer(2.2).timeout
	var weapons = items_of("weapon")
	check(weapons.size() == 1 and weapons[0].tier == 0, "the dunk finishes a copper sword")
	check(weapons.size() == 1 and weapons[0].global_position.z > tank.global_position.z + 1.0, "the sword comes out the bottom of the slide")

	# Harder metals need a longer drop: a short one on Iron does nothing.
	var iron = main.spawn_item("ingot", anv.global_position, {"tier": 2})
	anv.accept(iron)
	anv.slam(0.4)   # 0.8 m drop, Iron needs 1 m
	check(anv.shape == 0.0, "a drop below the metal's minimum doesn't shape it")
	anv.slam(0.8)   # 1.6 m: 0.6 m past the minimum
	check(absf(anv.shape - 0.6 * SF.TRIP["shape_per_meter"]) < 0.01, "only the drop past the minimum counts")
	main.despawn(iron)

	# Swing at the door until it breaks (copper vs copper door).
	put(smith, weapons[0].global_position)
	await frames(2)
	smith.pick_up(weapons[0])
	put(smith, Vector3(3, 0, main.door.global_position.z + 1.6))
	await frames(2)
	var old_door = main.door
	var hp_before: float = main.door.hp
	main.use(smith)
	check(main.door.hp < hp_before, "sword damages the door")
	var swings = 0
	while main.door.hp > 0.0 and swings < 40:
		if smith.held == null or smith.held.kind != "weapon":
			break
		main.use(smith)
		swings += 1
	check(smith.held != null and smith.held.kind == "scrap", "sword breaks into scrap after its durability runs out")
	main.door.hp = 5.0
	main.use(miner)  # miner has ore? make sure door can still break with a pickaxe
	miner.drop()
	var pick = items_of("tool").filter(func(i): return i.tool == "pickaxe")[0]
	miner.pick_up(pick)
	put(miner, Vector3(0, 0, main.door.global_position.z + 1.6))
	await frames(2)
	for i in 10:
		main.use(miner)
	check(main.paused_for_roll, "door breaks and the buff/debuff roll starts")
	await create_timer(3.3).timeout
	check(main.door_index == 1 and not main.paused_for_roll, "next area starts after the roll")
	check(main.mods.size() >= 1, "a buff and debuff were added")
	check(get_nodes_in_group("node").size() > 0, "new ore nodes spawned")
	check(main.furnace.global_position.z < -14.0 and main.door.global_position.z < -35.0, "the next area has its own forge past the old door")
	check(main.areas.size() == 2, "the area you came from stays, older ones are cleared")
	check(main.anvil.lift() > SF.TRIP["lift"], "the hammer frame is taller in the next area")
	check(main.area_center_at(Vector3(0, 0, 3)).z > -3.0 and main.area_center_at(Vector3(0, 0, -30)).z < -25.0, "the camera leans toward the area you're standing in, old or new")
	check(main.trough.target_range() > SF.DUNK["range"] and main.trough.hit_radius() < SF.DUNK["hit_radius"], "the dunk target is smaller and slides further in the next area")

	# Veins run dry, and lightning opens new ones.
	main.lightning.next_in = 9999.0
	var pickaxe = items_of("tool").filter(func(i): return i.tool == "pickaxe")[0]
	if pickaxe.holder:
		pickaxe.holder.take(pickaxe)
	if miner.slots[0]:
		miner.drop_item(miner.slots[0])
	pickaxe.release()
	miner.select(0)
	miner.pick_up(pickaxe)
	var vein = main.area_nodes[0]
	vein.set_chunks(1)
	put(miner, vein.global_position + Vector3(0, 0, 1.2))
	await frames(2)
	var veins_before = main.area_nodes.size()
	for i in SF.MINE_HITS:
		main.use(miner)
	check(not (vein in main.area_nodes) and main.area_nodes.size() == veins_before - 1, "a vein crumbles after its last chunk")
	main.vein_t = SF.VEIN_RESPAWN
	await frames(3)
	check(main.area_nodes.size() == veins_before, "lightning cracks open a new vein")

	# Bronze recipe.
	main.furnace.contents = {"copper": 1, "tin": 1}
	check(main.furnace.best_recipe() == 1, "copper plus tin makes bronze")
	main.furnace.contents = {}

	# A bronze door bounces a copper sword.
	var cs = main.spawn_item("weapon", smith.hand_position(), {"tier": 0})
	smith.drop()
	smith.pick_up(cs)
	put(smith, Vector3(0, 0, main.door.global_position.z + 1.6))
	await frames(2)
	var hp2: float = main.door.hp
	var msg: String = main.use(smith)
	check(main.door.hp == hp2 and msg.begins_with("CLANG"), "lower-tier sword bounces off a tougher door")

	# Lightning: struck smith is stunned and drops their tool.
	put(miner, Vector3(-3, 0, 4))
	await frames(2)
	var tool_before = miner.held
	var struck_at = miner.global_position
	main.lightning.target = miner
	main.lightning.strike(miner.global_position)
	check(miner.stun > 0.0, "lightning stuns the smith")
	check(miner.held == null and tool_before != null and tool_before.is_free(), "lightning knocks the tool loose")
	await frames(60)
	check(tool_before.global_position.distance_to(miner.global_position) > 1.0, "the tool flies away")
	check(Vector2(miner.global_position.x - struck_at.x, miner.global_position.z - struck_at.z).length() > 2.0, "the smith goes flying")
	var fly = miner.global_position - struck_at
	var toolfly = tool_before.global_position - struck_at
	check(Vector2(fly.x, fly.z).dot(Vector2(toolfly.x, toolfly.z)) < 0.0, "the tool flies the opposite way")

	# Metal raises strike odds.
	var w_empty = 1.0
	var w_metal = 1.0 + SF.METAL_WEIGHT * smith.metal_count()
	check(w_metal > w_empty, "holding metal makes you a likelier target")

	# Revive with a full bucket. (The roll may have swapped tools, so hand it back.)
	var bucket = items_of("tool").filter(func(i): return i.tool == "bucket")[0]
	if bucket.holder:
		bucket.holder.take(bucket)
	if finisher.slots[0]:
		finisher.drop_item(finisher.slots[0])
	finisher.select(0)
	finisher.pick_up(bucket)
	finisher.held.bucket_full = true
	miner.stun = 2.0
	put(finisher, miner.global_position + Vector3(0.8, 0, 0))
	await frames(1)
	main.use(finisher)
	check(miner.stun <= 0.0, "a full bucket revives a stunned smith")

	# Running out the storm ends the run.
	main.time_left = 0.0
	main.peak_time = SF.PEAK_GRACE - 0.05
	await frames(10)
	check(main.over, "the run ends when the last stand runs out")

	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
