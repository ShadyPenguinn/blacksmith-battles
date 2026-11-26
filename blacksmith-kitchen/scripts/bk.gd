class_name BK
extends RefCounted
## Blacksmith Kitchen: every tuning number and all game data. Change a number, press F5.

# --- Grades -----------------------------------------------------------------
## Each step scores 0-100. These are the step grades shown after each minigame.
const STEP_GRADES := [
	{"min": 90.0, "name": "PERFECT!", "color": Color(1.0, 0.85, 0.2)},
	{"min": 70.0, "name": "GREAT!", "color": Color(0.45, 0.9, 0.45)},
	{"min": 45.0, "name": "OK", "color": Color(0.55, 0.75, 1.0)},
	{"min": 0.0, "name": "OOPS...", "color": Color(0.95, 0.4, 0.35)},
]
## The finished weapon gets a medal from the average of its steps.
const MEDALS := [
	{"min": 85.0, "id": "gold", "name": "GOLD", "color": Color(1.0, 0.8, 0.2), "pay": 1.5, "stars": 3},
	{"min": 65.0, "id": "silver", "name": "SILVER", "color": Color(0.82, 0.85, 0.9), "pay": 1.0, "stars": 2},
	{"min": 40.0, "id": "bronze", "name": "BRONZE", "color": Color(0.85, 0.5, 0.25), "pay": 0.6, "stars": 1},
	{"min": 0.0, "id": "scrap", "name": "SCRAP", "color": Color(0.5, 0.45, 0.42), "pay": 0.1, "stars": 0},
]

static func step_grade(score: float) -> Dictionary:
	for g in STEP_GRADES:
		if score >= g["min"]:
			return g
	return STEP_GRADES[-1]

static func medal(score: float) -> Dictionary:
	for m in MEDALS:
		if score >= m["min"]:
			return m
	return MEDALS[-1]

static func medal_by_id(id: String) -> Dictionary:
	for m in MEDALS:
		if m["id"] == id:
			return m
	return {}

# --- Materials ----------------------------------------------------------------
## Harder metals make every step a little harder (faster meters, narrower bands, more ropes).
const MATERIALS := [
	{"name": "Copper", "color": Color(0.85, 0.48, 0.25), "band": [30.0, 55.0], "pay": 1.0, "ore": "Copper_Nugget_Large", "bar": "Copper_Bar"},
	{"name": "Bronze", "color": Color(0.80, 0.62, 0.28), "band": [40.0, 62.0], "pay": 1.3, "ore": "Gold_Nugget_Large", "bar": "Gold_Bar"},
	{"name": "Iron", "color": Color(0.55, 0.56, 0.62), "band": [52.0, 72.0], "pay": 1.7, "ore": "Iron_Nugget_Large", "bar": "Iron_Bar"},
	{"name": "Steel", "color": Color(0.78, 0.82, 0.88), "band": [62.0, 80.0], "pay": 2.2, "ore": "Iron_Nugget_Large", "bar": "Iron_Bar"},
	{"name": "Moonsilver", "color": Color(0.6, 0.75, 1.0), "band": [60.0, 76.0], "pay": 3.0, "ore": "Silver_Nugget_Large", "bar": "Silver_Bar"},
	{"name": "Starmetal", "color": Color(1.0, 0.9, 0.4), "band": [74.0, 88.0], "pay": 4.0, "ore": "Gold_Nugget_Large", "bar": "Gold_Bar"},
]

# --- Steps (the minigames) ----------------------------------------------------
## title, the one-line how-to (click is swapped for tap on touch screens), and the script.
const STEPS := {
	"mine": {"title": "Crack the Ore", "how": "{Click} the glowing cracks before they fade!", "script": "mine"},
	"bellows": {"title": "Stomp the Bellows", "how": "Stomp LEFT, then RIGHT (A / D or {click} each side). Keep the heat in the gold band!", "script": "bellows"},
	"lever": {"title": "Pump the Lever", "how": "Pull UP, push DOWN (W / S, or {click} top and bottom). Keep the heat in the gold band!", "script": "lever"},
	"tongs": {"title": "Tong Carry", "how": "Grab the hot ingot and hold. Drag it along the chalk path to the anvil!", "script": "tongs"},
	"hammer": {"title": "Hammer Time", "how": "{Click} or SPACE when the marker is in the middle!", "script": "hammer"},
	"ropes": {"title": "Rope Drop", "how": "Hold and drag DOWN to haul the hammer (or hold SPACE). Let go above the red flag!", "script": "ropes"},
	"quench": {"title": "Quench", "how": "Hold to dunk the blade (or hold SPACE). Pull it out when the glow hits the blue zone!", "script": "quench"},
	"grind": {"title": "Sharpen", "how": "Pump the pedals: A, D, A, D (or {click} left, right). Keep the wheel in the green!", "script": "grind"},
	"wrap": {"title": "Wrap the Grip", "how": "Over, under! W and S (or {click} top, bottom) on the beat when the ring closes.", "script": "wrap"},
	"polish": {"title": "Polish", "how": "Hold and scrub the grime off the blade!", "script": "polish"},
	"etch": {"title": "Etch a Rune", "how": "Hold and trace through the dots in order, 1 to the end!", "script": "etch"},
	"fit": {"title": "Fit the Handle", "how": "{Click} or SPACE to drop the handle into the socket, then tap it home!", "script": "fit"},
}

# --- Weapons (the recipes) ----------------------------------------------------
const M := "res://assets/models/"
const WEAPONS := {
	"dagger": {"name": "Dagger", "model": M + "weapons/dagger_A.gltf", "len": 1.0, "pay": 20,
		"steps": ["bellows", "tongs", "hammer", "quench", "grind"]},
	"sword": {"name": "Arming Sword", "model": M + "weapons/sword_A.gltf", "len": 1.5, "pay": 35,
		"steps": ["mine", "bellows", "tongs", "hammer", "quench", "grind", "wrap"]},
	"spear": {"name": "Spear", "model": M + "weapons/spear_A.gltf", "len": 2.2, "pay": 35,
		"steps": ["bellows", "tongs", "hammer", "quench", "grind", "fit"]},
	"axe": {"name": "Hand Axe", "model": M + "weapons/axe_A.gltf", "len": 1.3, "pay": 40,
		"steps": ["mine", "lever", "tongs", "ropes", "quench", "grind", "fit"]},
	"warhammer": {"name": "War Hammer", "model": M + "weapons/hammer_A.gltf", "len": 1.4, "pay": 45,
		"steps": ["mine", "lever", "tongs", "ropes", "quench", "polish"]},
	"staff": {"name": "Rune Staff", "model": M + "weapons/staff_A.gltf", "len": 2.0, "pay": 50,
		"steps": ["bellows", "tongs", "hammer", "quench", "polish", "etch"]},
	"shield": {"name": "Round Shield", "model": M + "weapons/shield_A.gltf", "len": 1.1, "pay": 50,
		"steps": ["mine", "bellows", "tongs", "ropes", "hammer", "polish", "etch"]},
	"greatsword": {"name": "Greatsword", "model": M + "weapons/sword_E.gltf", "len": 2.0, "pay": 80,
		"steps": ["mine", "bellows", "tongs", "ropes", "hammer", "quench", "grind", "wrap", "polish"]},
	"halberd": {"name": "Halberd", "model": M + "weapons/halberd.gltf", "len": 2.4, "pay": 90,
		"steps": ["mine", "lever", "tongs", "ropes", "hammer", "quench", "grind", "fit", "etch"]},
}
const WEAPON_ORDER := ["dagger", "sword", "spear", "axe", "warhammer", "staff", "shield", "greatsword", "halberd"]

# --- People ---------------------------------------------------------------------
## The mentor who runs the forge. All lines are original.
const MENTOR := {
	"name": "Old Grizzle", "model": M + "characters/Barbarian.glb",
	"hello": ["Fire's lit, kid. Customers are coming!", "Morning, apprentice. Sleeves up!", "Smell that? That's a good forge day."],
	"start": ["Show me what you've got!", "Steady hands now.", "Easy does it.", "Mind your fingers!"],
	"PERFECT!": ["HOT STUFF!", "Now THAT'S smithing!", "Perfect! I'm almost jealous.", "Sparks and stars, kid!"],
	"GREAT!": ["Good hit!", "That'll do nicely.", "Solid work!", "Ha! Nice one."],
	"OK": ["Bit wobbly, but it'll hold.", "Hm. We'll sand that out.", "Not bad, not great."],
	"OOPS...": ["Yikes. Keep going, kid!", "We don't talk about that one.", "Bah! Shake it off!", "That's why we wear gloves."],
	"gold": ["A masterpiece! Hang that one on the wall!", "That's going in the legends!"],
	"silver": ["Fine blade. The customer's lucky.", "Good honest work."],
	"bronze": ["It's a weapon. Technically.", "It'll survive a goblin or two."],
	"scrap": ["...Maybe sell it as a doorstop.", "Back to the anvil tomorrow, eh?"],
}

## Customers. Each is a KayKit adventurer with their own way of talking.
const CUSTOMERS := {
	"pip": {"name": "Pip Quickfingers", "model": M + "characters/Rogue.glb",
		"ask": ["Psst. I need a {mat} {weapon}. No questions.", "One {mat} {weapon}, quick and quiet!"],
		"gold": "Ooh, shiny! I'll treasure it. Honestly!", "ok": "Good enough to pick a lock with.", "bad": "Hey, this is worse than my old one!"},
	"sir": {"name": "Sir Pennywhistle", "model": M + "characters/Knight.glb",
		"ask": ["Hail, smith! A {mat} {weapon}, fit for a hero!", "My quest requires a {mat} {weapon}. Chop chop!"],
		"gold": "Magnificent! Bards shall sing of this!", "ok": "It shall serve, I suppose.", "bad": "I cannot be seen with this!"},
	"bryn": {"name": "Bryn Thornhollow", "model": M + "characters/Ranger.glb",
		"ask": ["{mat} {weapon}. Light. Balanced.", "Need a {mat} {weapon} before the hunt."],
		"gold": "...Perfect.", "ok": "Fine.", "bad": "Hmph."},
	"mags": {"name": "Mags Emberly", "model": M + "characters/Mage.glb",
		"ask": ["Darling! A {mat} {weapon}, and make it sparkle!", "I'd like a {mat} {weapon}. My spells keep melting the old one."],
		"gold": "It's GORGEOUS! I could kiss your anvil!", "ok": "Sweet! A little spell will fix the rest.", "bad": "Oh dear. Oh dear oh dear."},
	"fennick": {"name": "Fennick Mossbeard", "model": M + "characters/Druid.glb",
		"ask": ["Greetings, young flame. A {mat} {weapon}, if the forest allows.", "The trees whisper... {mat} {weapon}."],
		"gold": "The forest itself approves!", "ok": "Balanced, as all things should be.", "bad": "The squirrels are laughing at me."},
	"tinka": {"name": "Tinka Gearwhistle", "model": M + "characters/Engineer.glb",
		"ask": ["Spec sheet says: one {mat} {weapon}. Tolerances tight!", "Order up: {mat} {weapon}. I'll be checking the welds!"],
		"gold": "Flawless tolerances! You're hired! Well, you're already hired.", "ok": "Within spec. Barely.", "bad": "Did you hammer this with a sandwich?"},
	"hood": {"name": "The Hooded One", "model": M + "characters/Rogue_Hooded.glb",
		"ask": ["...{mat} {weapon}. Double pay. Don't ask.", "They told me you're the best. One {mat} {weapon}."],
		"gold": "...Impressive. We will meet again.", "ok": "...Acceptable.", "bad": "...You will regret this. Kidding. Mostly."},
	"grizzle": {"name": "Old Grizzle", "model": M + "characters/Barbarian.glb",
		"ask": ["Final test, kid. Make ME a {mat} {weapon}. Better than mine."],
		"gold": "...You did it. The forge is yours, smith.", "ok": "Close. Very close. Again tomorrow.", "bad": "Ha! Not yet, kid. Not yet."},
}

## Shop days. Each order is [customer, weapon, material tier]. Clear a day (every order at
## bronze or better) to open the next one. A day's first new weapon is unlocked in practice.
const DAYS := [
	{"name": "Grand Opening", "orders": [["pip", "dagger", 0], ["sir", "dagger", 0], ["bryn", "sword", 0]]},
	{"name": "Word Gets Around", "orders": [["fennick", "spear", 0], ["mags", "dagger", 1], ["sir", "sword", 1]]},
	{"name": "Axe Day", "orders": [["tinka", "axe", 0], ["bryn", "spear", 1], ["pip", "dagger", 2]]},
	{"name": "Heavy Hitters", "orders": [["sir", "warhammer", 1], ["fennick", "axe", 1], ["mags", "sword", 2]]},
	{"name": "Magic Hour", "orders": [["mags", "staff", 0], ["tinka", "warhammer", 2], ["bryn", "axe", 2]]},
	{"name": "Shield Wall", "orders": [["sir", "shield", 2], ["pip", "spear", 3], ["hood", "dagger", 4]]},
	{"name": "Busy Bees", "orders": [["fennick", "staff", 1], ["bryn", "sword", 3], ["tinka", "shield", 3], ["pip", "axe", 3]]},
	{"name": "Big Blades", "orders": [["sir", "greatsword", 2], ["mags", "staff", 4], ["hood", "warhammer", 3]]},
	{"name": "The Long Reach", "orders": [["hood", "halberd", 3], ["fennick", "shield", 4], ["bryn", "greatsword", 3]]},
	{"name": "Moon Market", "orders": [["sir", "greatsword", 4], ["tinka", "halberd", 4], ["mags", "shield", 4], ["pip", "dagger", 5]]},
	{"name": "Starfall", "orders": [["mags", "greatsword", 5], ["hood", "halberd", 5], ["fennick", "staff", 5]]},
	{"name": "Grizzle's Test", "orders": [["grizzle", "greatsword", 5]]},
]

# --- Shop upgrades: spend coins to make steps a little easier -----------------------
const UPGRADES := [
	{"id": "bellows", "name": "Patched Bellows", "desc": "Bellows and lever pump 20% more heat", "cost": 120},
	{"id": "tongs", "name": "Long Tongs", "desc": "The chalk path is wider", "cost": 160},
	{"id": "hammer", "name": "Balanced Hammer", "desc": "The hammer marker moves 15% slower", "cost": 220},
	{"id": "stone", "name": "Fine Whetstone", "desc": "Sharpening fills 25% faster", "cost": 260},
	{"id": "cat", "name": "Forge Cat", "desc": "A cat. It sleeps by the furnace. Purely moral support.", "cost": 400},
]

# --- Minigame tuning ------------------------------------------------------------
const SMELT := {
	"heat_per_pump": 9.0,      # heat each good stomp or pump adds
	"wheeze_mult": 0.15,       # same side twice in a row barely does anything
	"decay": 7.0,              # heat lost per second
	"decay_per_tier": 0.8,
	"need": 4.0,               # seconds in the gold band to finish smelting
	"limit": 16.0,             # seconds before the batch is pulled out anyway
	"scorch_margin": 10.0,     # this far above the band scorches the batch
	"lever_mult": 0.7,         # each lever stroke is smaller (but you pump faster)
}
const HAMMER := {"hits": 5, "hits_per_2_tiers": 1, "speed": 1.1, "speed_per_tier": 0.18,
	"perfect": 0.06, "great": 0.15, "ok": 0.3}
const ROPES := {"rope_lift": 0.7, "drops": 3, "pull_px": 260.0, "key_rate": 1.2, "slip": 0.12,
	"slip_per_tier": 0.05, "band": 0.3, "rest_y": 1.25}
const TONGS := {"width": 0.75, "width_per_tier": -0.05, "limit": 14.0, "cool_time": 12.0}
const QUENCH := {"cool_rate": 0.22, "rate_per_tier": 0.03, "zone": 0.12, "zone_per_tier": -0.012}
const GRIND := {"spin_per_push": 0.22, "drag": 0.55, "band": [0.45, 0.75], "need": 4.0, "limit": 14.0}
const WRAP := {"wraps": 8, "beat": 0.75, "beat_per_tier": -0.04}
const POLISH := {"spots": 6, "spots_per_tier": 1, "limit": 9.0, "rub_needed": 900.0}
const ETCH := {"limit": 9.0, "tolerance": 38.0}
const MINE := {"cracks": 8, "cracks_per_tier": 1, "life": 1.7, "life_per_tier": -0.12, "gap": 0.55}

# --- Co-op Rush Hour ----------------------------------------------------------------
const RUSH := {
	"time": 210.0,             # seconds in a shift
	"order_gap": 22.0,         # a new ticket every this many seconds (sooner when the board is empty)
	"max_orders": 4,
	"order_time": 90.0,        # seconds before a ticket's customer storms off
	"weapons": ["dagger", "sword", "axe"],
	"hits": {"dagger": 3, "sword": 5, "axe": 4},
	"grinds": {"dagger": 6, "sword": 8, "axe": 7},
	"heat_band": [40.0, 65.0],
	"heat_per_stomp": 12.0,
	"smelt_need": 2.5,
	"ingot_cool": 25.0,        # seconds before a hot ingot goes cold and has to be reheated
	"water_per_quench": 0.34,  # quench barrel water used per dunk; refill with the bucket at the well
	"quench_window": [1.2, 3.2],
	"stars": [60, 180, 320],   # coins for 1, 2, 3 stars
	"speed": 5.2,
	"carry_speed": 4.0,
}
const PLAYER_COLORS := [Color(0.95, 0.35, 0.3), Color(0.35, 0.6, 1.0), Color(0.4, 0.85, 0.4), Color(1.0, 0.8, 0.25)]
const PLAYER_MODELS := ["characters/Knight.glb", "characters/Engineer.glb", "characters/Druid.glb", "characters/Ranger.glb"]

# --- Characters and animation -----------------------------------------------------
const ANIMS := [M + "anims/Rig_Medium_MovementBasic.glb", M + "anims/Rig_Medium_General.glb",
	M + "anims/Rig_Medium_Tools.glb", M + "anims/Rig_Medium_MovementAdvanced.glb"]
const CHAR_SCALE := 0.75
const GOOFY := {
	"hop": 0.2, "squash": 0.1, "waddle_deg": 10.0, "lean_deg": 10.0, "arms_out_deg": 72.0,
	"arm_flap_deg": 30.0, "elbow_straighten": 0.75, "head_wobble_deg": 12.0, "bank": 0.06,
	"steps_per_meter": 1.3, "clip_speed": 1.35,
}

static var anim_lib: AnimationLibrary = null

## Every clip from the KayKit animation packs, loaded once and shared.
static func shared_anims() -> AnimationLibrary:
	if anim_lib:
		return anim_lib
	anim_lib = AnimationLibrary.new()
	for path in ANIMS:
		if not ResourceLoader.exists(path):
			continue
		var scene = load(path).instantiate()
		for ap in scene.find_children("*", "AnimationPlayer", true, false):
			for n in ap.get_animation_list():
				var clip = String(n).get_file()
				if not anim_lib.has_animation(clip):
					anim_lib.add_animation(clip, ap.get_animation(n))
		scene.free()
	for loop_clip in ["Idle_A", "Idle_B", "Walking_A", "Running_A", "Hammering", "Working_A", "Holding_A", "Sawing"]:
		if anim_lib.has_animation(loop_clip):
			anim_lib.get_animation(loop_clip).loop_mode = Animation.LOOP_LINEAR
	return anim_lib

# --- Model helpers ----------------------------------------------------------------
static func load_model(path: String) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is PackedScene:
		return res.instantiate()
	return null

## A model scaled so its longest side is `length`, centered on its origin, optionally
## turned first. KayKit weapons stand along +Y with the grip at the origin.
static func fitted(path: String, length: float, rot_deg := Vector3.ZERO, center := true) -> Node3D:
	var model = load_model(path)
	if model == null:
		return null
	var holder = Node3D.new()
	holder.rotation_degrees = rot_deg
	holder.add_child(model)
	var box = mesh_aabb(model, holder.transform)
	var k = length / maxf(0.001, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	var outer = Node3D.new()
	outer.add_child(holder)
	holder.scale = Vector3.ONE * k
	if center:
		holder.position = -(box.position + box.size * 0.5) * k
	else:
		holder.position = Vector3(-(box.position.x + box.size.x * 0.5) * k, -box.position.y * k, -(box.position.z + box.size.z * 0.5) * k)
	return outer

## Bounding box of every mesh under n, with n placed at xf.
static func mesh_aabb(n: Node, xf: Transform3D) -> AABB:
	var box = AABB()
	var first = true
	var stack = [[n, xf]]
	while not stack.is_empty():
		var top = stack.pop_back()
		var node: Node = top[0]
		var t: Transform3D = top[1]
		if node is MeshInstance3D and node.mesh:
			var b = t * node.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for c in node.get_children():
			var ct = t * c.transform if c is Node3D else t
			stack.append([c, ct])
	return box

## A see-through colour laid over a textured model (metal type), with an optional glow
## (hot metal). Returns the material so the glow can be changed later.
static func tint(n: Node, c: Color, strength: float = 0.5, glow: float = 0.0, glow_color := Color(1.0, 0.45, 0.1)) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, strength)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true   # always on, so changing the glow never compiles a new shader
	m.emission = glow_color
	m.emission_energy_multiplier = glow
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = m
	if n is MeshInstance3D:
		n.material_overlay = m
	return m

## Hot-metal colour: 1 = white-yellow hot, 0.5 = orange, 0 = cold (no glow).
static func heat_color(h: float) -> Color:
	h = clampf(h, 0.0, 1.0)
	if h > 0.66:
		return Color(1.0, 0.55, 0.15).lerp(Color(1.0, 0.95, 0.6), (h - 0.66) / 0.34)
	if h > 0.33:
		return Color(0.8, 0.15, 0.05).lerp(Color(1.0, 0.55, 0.15), (h - 0.33) / 0.33)
	return Color(0.2, 0.02, 0.0).lerp(Color(0.8, 0.15, 0.05), h / 0.33)

## KayKit-style part kits made in Blender for Storm Forge.
const KITS := {
	"trip": M + "stations/trip_hammer_parts.glb",
	"dunk": M + "stations/dunk_tank_parts.glb",
	"gate": M + "stations/gate_walls_parts.glb",
}
static var _kit_meshes := {}

static func kit_part(kit: String, part: String) -> MeshInstance3D:
	var key = kit + "/" + part
	if not _kit_meshes.has(key):
		var path: String = KITS.get(kit, "")
		if path != "" and ResourceLoader.exists(path):
			var inst: Node = load(path).instantiate()
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				_kit_meshes[kit + "/" + String(mi.name)] = mi.mesh
			inst.free()
	var m = _kit_meshes.get(key)
	if m == null:
		return null
	var mi = MeshInstance3D.new()
	mi.mesh = m
	return mi

static func say(lines) -> String:
	if lines is Array:
		return lines[randi() % lines.size()]
	return str(lines)

static func fill(text: String, order: Dictionary) -> String:
	return text.replace("{mat}", MATERIALS[order["tier"]]["name"]).replace("{weapon}", WEAPONS[order["weapon"]]["name"])
