extends Node
## Blacksmith Kitchen: menus, shop days, the order flow (customer, steps, result) and practice.

const GAMES := {
	"mine": preload("res://scripts/games/mine.gd"),
	"bellows": preload("res://scripts/games/bellows.gd"),
	"lever": preload("res://scripts/games/lever.gd"),
	"tongs": preload("res://scripts/games/tongs.gd"),
	"hammer": preload("res://scripts/games/hammer.gd"),
	"ropes": preload("res://scripts/games/ropes.gd"),
	"quench": preload("res://scripts/games/quench.gd"),
	"grind": preload("res://scripts/games/grind.gd"),
	"wrap": preload("res://scripts/games/wrap.gd"),
	"polish": preload("res://scripts/games/polish.gd"),
	"etch": preload("res://scripts/games/etch.gd"),
	"fit": preload("res://scripts/games/fit.gd"),
	"crush": preload("res://scripts/games/crush.gd"),
	"pour": preload("res://scripts/games/pour.gd"),
	"fold": preload("res://scripts/games/fold.gd"),
	"temper": preload("res://scripts/games/temper.gd"),
	"crack": preload("res://scripts/games/pour.gd"),
}

var ws: Workshop
var hud: Hud
var mode := "menu"          # menu, day, practice, rush
var day := 0
var day_results := []       # medal scores for the day's orders
var game: Game = null
var run_id := 0             # bumps when you quit to the menu, so a running order stops
var showcase: Node3D = null
var rush: Node = null
var shop: Node = null
var autoplay := 0.0         # test: finish each step on its own after this many seconds

func _ready() -> void:
	randomize()
	Save.load_game()
	ws = Workshop.new()
	add_child(ws)
	hud = Hud.new()
	add_child(hud)
	hud.setup(ws)
	hud.menu_pressed.connect(_to_menu)
	Fx.warm_up(ws, ws.cam.global_position + ws.cam.global_transform.basis.z * -1.0)
	var args = OS.get_cmdline_user_args()
	if "--autoplay" in args:
		autoplay = 2.5
	if "--test-order" in args:
		_test_order(args)
		return
	if "--rush" in args:
		start_rush(2)
		return
	title_menu()

func _test_order(args: Array) -> void:
	var i = args.find("--test-order")
	var w = args[i + 1] if args.size() > i + 1 else "sword"
	var tier = int(args[i + 2]) if args.size() > i + 2 else 0
	mode = "practice"
	run_order({"customer": "sir", "weapon": w, "tier": tier})

func coins() -> int:
	return int(Save.data.get("coins", 0))

func _to_menu() -> void:
	run_id += 1
	if game and is_instance_valid(game):
		game.queue_free()
	game = null
	if rush and is_instance_valid(rush):
		rush.queue_free()
		rush = null
	if shop and is_instance_valid(shop):
		shop.over = true
		shop.queue_free()
		shop = null
	ws.clear_props()
	ws.use_lever(false)
	ws.set_trip_flag(-1.0)
	ws.set_fire(0.3)
	if showcase and is_instance_valid(showcase):
		showcase.queue_free()
	ws.customer_leave()
	hud.hush()
	hud.banner.visible = false
	title_menu()

# --- Menus -------------------------------------------------------------------------
func title_menu() -> void:
	mode = "menu"
	ws.set_shot("title", 1.0)
	hud.show_top(false)
	hud.clear_steps()
	var v = hud.panel("Blacksmith Kitchen")
	var sub = hud.label("Customers want weapons. Make them by hand!", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	hud.button(v, "Open the Shop", day_menu)
	hud.button(v, "Recipe Book (practice)", recipe_menu)
	hud.button(v, "Rush Hour (co-op, 1-4 players)", rush_menu)
	hud.button(v, "Shop Upgrades", upgrade_menu)
	var info = hud.label("%d coins   ·   %d weapons forged" % [coins(), int(Save.data.get("forged", 0))], 22)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	hud.mentor_say(BK.say(BK.MENTOR["hello"]), 4.0)

func day_menu() -> void:
	var v = hud.panel("Shop Days", 720)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var stars: Dictionary = Save.data.get("day_stars", {})
	for d in BK.DAYS.size():
		var open = d <= Save.open_day()
		var s = int(stars.get(str(d), -1))
		var star_txt = "" if s < 0 else "  " + "*".repeat(s) + " / " + str(BK.DAYS[d]["orders"].size() * 3)
		var b = hud.button(grid, "Day %d: %s%s" % [d + 1, BK.DAYS[d]["name"] if open else "???", star_txt], start_day.bind(d), open)
		b.custom_minimum_size = Vector2(330, 0)
		b.add_theme_font_size_override("font_size", 22)
	hud.button(v, "Back", title_menu)

func recipe_menu() -> void:
	var v = hud.panel("Recipe Book", 860)
	var hint = hud.label("Practice any weapon you've unlocked. Best medal shown per weapon.", 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var unlocked = Save.unlocked_weapons()
	for w in BK.WEAPON_ORDER:
		var best = Save.best_score(w)
		var m = BK.medal(best) if best >= 0.0 else {}
		var txt = BK.WEAPONS[w]["name"] if w in unlocked else "Locked"
		if not m.is_empty():
			txt += "\n" + m["name"]
		else:
			txt += "\n" + ("%d-%d steps" % [BK.steps_for(w, 0).size(), BK.steps_for(w, 5).size()] if w in unlocked else "")
		var b = hud.button(grid, txt, _pick_metal.bind(w), w in unlocked)
		b.custom_minimum_size = Vector2(260, 84)
		b.add_theme_font_size_override("font_size", 22)
		if not m.is_empty():
			b.add_theme_color_override("font_color", m["color"].lightened(0.3))
	hud.button(v, "Back", title_menu)

func _pick_metal(w: String) -> void:
	var v = hud.panel(BK.WEAPONS[w]["name"], 620)
	# One line per route: cast metals are poured, forged metals are hammered.
	for r in [["cast", 0, "Cast (Copper, Bronze, Moonsilver)"], ["forge", 3, "Forged (Iron, Steel, Starmetal)"]]:
		var steps = []
		for s in BK.steps_for(w, r[1]):
			steps.append(BK.step_info(s, r[1])["title"])
		var l = hud.label(r[2] + ":  " + " > ".join(steps), 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	for tier in Save.max_tier() + 1:
		var best = Save.best_score(w, tier)
		var tag = "" if best < 0.0 else "   (" + BK.medal(best)["name"] + ")"
		hud.button(v, BK.MATERIALS[tier]["name"] + tag, func():
			mode = "practice"
			hud.clear_menu()
			run_order({"customer": "", "weapon": w, "tier": tier}))
	hud.button(v, "Back", recipe_menu)

func upgrade_menu() -> void:
	var v = hud.panel("Shop Upgrades", 700)
	var have = hud.label("You have %d coins" % coins(), 26)
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(have)
	for u in BK.UPGRADES:
		var owned = Save.has_upgrade(u["id"])
		var txt = "%s: %s   %s" % [u["name"], u["desc"], "(owned)" if owned else "- %d coins" % u["cost"]]
		var b = hud.button(v, txt, _buy.bind(u), not owned and coins() >= u["cost"])
		b.add_theme_font_size_override("font_size", 20)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.button(v, "Back", title_menu)

func _buy(u: Dictionary) -> void:
	Save.data["coins"] = coins() - int(u["cost"])
	var ups: Array = Save.data.get("upgrades", [])
	ups.append(u["id"])
	Save.data["upgrades"] = ups
	Save.save_game()
	ws.set_cat(Save.has_upgrade("cat"))
	hud.mentor_say("Ooh, %s! Fancy." % u["name"], 3.0)
	upgrade_menu()

func rush_menu() -> void:
	var v = hud.panel("Rush Hour", 760)
	var l = hud.label("Co-op chaos on one screen. Fill tickets before the customers storm off. Stomp the bellows together, carry hot ingots with tongs (hold), hammer on the beat, refill the quench barrel with the bucket.", 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var keys = hud.label("P1: WASD + E grab + F use     P2: arrows + . grab + / use\nP3, P4: gamepads (A grab, X use). Gamepads can also be P1 and P2.", 20)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keys)
	for n in [1, 2, 3, 4]:
		hud.button(v, "%d smith%s" % [n, "" if n == 1 else "s"], start_rush.bind(n))
	var best = hud.label("Best shift: %d coins" % int(Save.data.get("rush_best", 0)), 22)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(best)
	hud.button(v, "Back", title_menu)

func start_rush(n: int) -> void:
	hud.clear_menu()
	mode = "rush"
	run_id += 1
	rush = preload("res://scripts/coop/rush.gd").new()
	add_child(rush)
	rush.setup(self, n)

func rush_over(earned: int) -> void:
	Save.data["rush_best"] = maxi(int(Save.data.get("rush_best", 0)), earned)
	Save.data["coins"] = coins() + earned / 4
	Save.save_game()

# --- Shop days -------------------------------------------------------------------------
func start_day(d: int) -> void:
	hud.clear_menu()
	mode = "day"
	run_id += 1
	day = d
	day_results = []
	if shop and is_instance_valid(shop):
		shop.queue_free()
	shop = preload("res://scripts/shop/shop.gd").new()
	add_child(shop)
	shop.setup(self, d)

## The shop day is over: one score per order (0 for customers who gave up).
func shop_day_done(results: Array) -> void:
	day_results = results
	if shop and is_instance_valid(shop):
		shop.queue_free()
		shop = null
	ws.clear_props()
	_day_summary()

func _day_summary() -> void:
	var stars = 0
	var cleared = true
	for s in day_results:
		var m = BK.medal(s)
		stars += int(m["stars"])
		if m["id"] == "scrap":
			cleared = false
	var ds: Dictionary = Save.data.get("day_stars", {})
	ds[str(day)] = maxi(int(ds.get(str(day), 0)), stars)
	Save.data["day_stars"] = ds
	if cleared and day >= Save.open_day():
		Save.data["day"] = mini(day + 1, BK.DAYS.size() - 1)
	Save.save_game()
	ws.set_shot("overview", 1.0)
	var title = "Day cleared!" if cleared else "Rough day..."
	var v = hud.panel(title, 600)
	var l = hud.label("Stars: %s  (%d / %d)" % ["*".repeat(stars), stars, day_results.size() * 3], 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if not cleared:
		var l2 = hud.label("Every order needs at least Bronze to open the next day.", 22)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l2)
	if day == BK.DAYS.size() - 1 and cleared:
		var l3 = hud.label("Old Grizzle hands you the keys. The forge is yours!", 24)
		l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l3)
	if cleared and day + 1 < BK.DAYS.size():
		hud.button(v, "Next day", start_day.bind(day + 1))
	hud.button(v, "Play this day again", start_day.bind(day))
	hud.button(v, "Main menu", _to_menu)
	hud.mentor_say(BK.say(BK.MENTOR["gold" if cleared else "scrap"]), 4.0)

# --- One order: customer, steps, result ---------------------------------------------
## Runs a whole order and returns its score (0-100).
func run_order(order: Dictionary) -> float:
	var my_run = run_id
	var who = order.get("customer", "")
	var c = BK.CUSTOMERS.get(who, {})
	hud.show_top(true)
	hud.set_top(("Day %d" % (day + 1)) if mode == "day" else "Practice", coins())
	if not c.is_empty():
		ws.set_shot("counter", 0.9)
		ws.new_customer(c["model"])
		await _wait(0.4)
		ws.customer_arrive()
		await _wait(2.2)
		if my_run != run_id:
			return 0.0
		ws.customer.once("Interact")
		hud.say(c["name"], BK.fill(BK.say(c["ask"]), order))
		await _wait(2.8)
		hud.hush()
	if my_run != run_id:
		return 0.0
	var steps: Array = BK.steps_for(order["weapon"], order["tier"])
	var titles = steps.map(func(st): return BK.step_info(st, order["tier"])["title"])
	var scores = []
	for i in steps.size():
		hud.set_steps(titles, i, scores)
		var s = await _run_step(order, steps[i])
		if my_run != run_id:
			return 0.0
		scores.append(s)
		hud.set_steps(titles, i + 1, scores)
	var total = 0.0
	for s in scores:
		total += s
	total /= maxf(1.0, scores.size())
	await _reveal(order, total, c)
	return total

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _run_step(order: Dictionary, step: String) -> float:
	var my_run = run_id
	ws.clear_props()
	game = GAMES[step].new()
	game.init(self, ws, order, step)
	hud.game_layer.add_child(game)
	ws.set_shot(game.shot(), 0.9)
	game.prepare()
	if randf() < 0.5:
		hud.mentor_say(BK.say(BK.MENTOR["start"]), 2.5)
	var info = BK.step_info(step, order.get("tier", 0))
	await hud.intro(info["title"], info["how"])
	Sfx.play("tick", 1.2)
	if my_run != run_id:
		return 0.0
	game.start()
	if autoplay > 0.0:
		get_tree().create_timer(autoplay).timeout.connect(func():
			if game and is_instance_valid(game):
				game.finish(randf_range(55.0, 100.0)))
	var score: float = await game.finished
	if my_run != run_id:
		return 0.0
	var g = BK.step_grade(score)
	Sfx.play("bad" if g["name"] == "OOPS..." else "good")
	hud.big(g["name"], g["color"])
	hud.mentor_say(BK.say(BK.MENTOR[g["name"]]), 2.0)
	if g["name"] == "PERFECT!":
		ws.mentor.cheer()
	elif g["name"] == "OOPS...":
		ws.mentor.sulk()
	await _wait(1.5)
	game.queue_free()
	game = null
	return score

func _reveal(order: Dictionary, score: float, c: Dictionary) -> void:
	var my_run = run_id
	ws.clear_props()
	hud.clear_steps()
	var m = BK.medal(score)
	ws.set_shot("counter" if not c.is_empty() else "anvil", 0.9)
	showcase = BK.fitted(BK.WEAPONS[order["weapon"]]["model"], 1.1)
	ws.add_child(showcase)
	var tint_strength = 0.45
	BK.tint(showcase, BK.MATERIALS[order["tier"]]["color"], tint_strength, 0.25 if m["id"] == "gold" else 0.0, Color(1, 0.9, 0.5))
	if c.is_empty():
		showcase.global_position = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.75, 0.2)
	else:
		showcase.global_position = Vector3(0.0, 1.35, 3.6)
	var spin = create_tween().set_loops()
	spin.tween_property(showcase, "rotation:y", TAU, 3.0).as_relative()
	Fx.burst(ws, showcase.global_position, m["color"], 30, 0.8, 4.0, -3.0, 0.8, Vector3.UP, 180.0)
	await _wait(0.6)
	hud.big(m["name"], m["color"], 2.2, 130)
	Sfx.play("fanfare" if m["id"] in ["gold", "silver"] else "bad")
	var pay = int(round(BK.WEAPONS[order["weapon"]]["pay"] * BK.MATERIALS[order["tier"]]["pay"] * m["pay"]))
	if mode != "day":
		pay = int(pay * 0.25)
	if order.get("customer", "") == "hood":
		pay *= 2
	Save.data["coins"] = coins() + pay
	Save.record(order["weapon"], order["tier"], score)
	Save.save_game()
	await _wait(1.0)
	if my_run != run_id:
		spin.kill()
		return
	if not c.is_empty():
		var line = c["gold"] if m["id"] == "gold" else (c["ok"] if m["id"] != "scrap" else c["bad"])
		hud.say(c["name"], line + "   (+%d coins)" % pay)
		if m["id"] in ["gold", "silver"]:
			ws.customer.cheer()
		elif m["id"] == "scrap":
			ws.customer.sulk()
	else:
		hud.float_text("+%d coins" % pay, get_viewport().get_visible_rect().size * Vector2(0.5, 0.65), Color(1.0, 0.85, 0.3), 40)
	hud.mentor_say(BK.say(BK.MENTOR[m["id"]]), 3.0)
	hud.set_top(("Day %d" % (day + 1)) if mode == "day" else "Practice", coins())
	await _wait(1.2)
	var v = hud.panel("", 380)
	var done_sig = [false]
	var l = hud.label("%s %s: %d%%" % [BK.MATERIALS[order["tier"]]["name"], BK.WEAPONS[order["weapon"]]["name"], int(score)], 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var b = hud.button(v, "Next", func(): done_sig[0] = true)
	b.grab_focus()
	if autoplay > 0.0:
		get_tree().create_timer(2.0).timeout.connect(func(): done_sig[0] = true)
	var center = hud.menu_root.get_child(0)
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -170
	while not done_sig[0]:
		if my_run != run_id:
			spin.kill()
			return
		await get_tree().process_frame
	hud.clear_menu()
	hud.hush()
	spin.kill()
	if showcase and is_instance_valid(showcase):
		showcase.queue_free()
	if not c.is_empty():
		ws.customer_leave()
		await _wait(0.8)
	if mode == "practice":
		recipe_menu()
