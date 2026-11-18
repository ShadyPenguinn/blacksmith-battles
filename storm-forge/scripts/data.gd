class_name SF
extends RefCounted
## All tuning numbers and game data live here. Change a number, press F5.

# --- Storm and timer ---
const AREA_TIME := 300.0          # seconds per door before the storm peaks
const PEAK_GRACE := 60.0          # seconds of peak storm before the run is lost
const STRIKE_GAP_START := 22.0    # seconds between strikes at the start of an area
const STRIKE_GAP_PEAK := 2.5      # seconds between strikes when the timer hits zero
const STRIKE_GAP_MIN := 0.8       # fastest the storm ever gets during the last stand
const TELEGRAPH := 1.5            # warning time before a strike
const TELEGRAPH_LOCK := 0.4       # the ring stops following you this long before it hits
const STRIKE_RADIUS := 1.6
const STUN_TIME := 2.0
const METAL_WEIGHT := 2.0         # extra strike weight for each metal thing you hold
const NODE_STRIKE_CHANCE := 0.25  # chance a strike targets an ore node instead of a smith
const STARMETAL_FROM_DOOR := 5    # door index (0-based) where struck nodes turn to Starmetal

# --- Movement ---
const MOVE_SPEED := 5.0
const SPRINT_MULT := 1.5
const CARRY_SLOW := 0.6           # speed multiplier while hauling ore, ingots or scrap
const CARRY_SLOW_EXTRA := 0.07    # each extra heavy thing in your pockets slows you this much more
const SLOTS := 4                  # hotbar: slot 1 is the tool slot, the rest hold anything but tools
## How moving feels. Momentum, jump and the belly flop (jump, then jump again in the air).
const MOVE := {
	"accel": 38.0,            # how fast you get up to speed (m/s per second)
	"friction": 16.0,         # how fast you slow down with no input (lower = slidier)
	"skid_decel": 30.0,       # reversing hard: you skid to a stop first
	"air_accel": 14.0,        # steering in the air
	"turn_rate": 13.0,        # how quickly the body swings round to face where you go
	"jump_speed": 7.0,
	"gravity_up": 21.0,
	"gravity_down": 34.0,     # fall faster than you rise, so jumps feel snappy
	"apex_band": 2.2,         # near the top of a jump...
	"apex_float": 0.45,       # ...gravity eases off for a floaty hang
	"jump_stretch": 0.22,
	"coyote": 0.12,           # you can still jump this long after walking off an edge
	"jump_buffer": 0.15,      # a jump pressed this early before landing still happens
	"flop_hop": 3.0,          # little upward pop when you start a belly flop
	"flop_friction": 9.0,     # belly slide along the ground after a flop
	"flop_slide_time": 0.55,
}
const DIVE_SPEED := 11.0
const DIVE_LOAD_PENALTY := 0.22   # each ore, ingot or other heavy thing carried cuts the dive this much (3 = about a third left)
const DIVE_TIME := 0.25
const DIVE_COOLDOWN := 1.0
const REACH := 2.2

# --- Forge pipeline ---
const MINE_HITS := 3
const VEIN_CHUNKS := 4            # chunks in a vein before it's tapped out (each vein gets 3-5)
const VEIN_RESPAWN := 30.0        # seconds between lightning cracking open a new vein
const VEIN_EXTRA := 2             # new veins can push an area this far past its starting count
const AREA_STEP := 27.0           # each new area sits this far past the last one
const HEAT_PER_PUMP := 9.0
## Stomp bellows: jump on the accordions either side of the furnace to blow air in.
const BELLOWS := {
	"size": Vector3(2.4, 0.8, 1.2),  # the model (MODELS["bellows"]) is fitted to this box
	"nozzle_in": 0.3,         # the nozzle tip pokes this far into the furnace's side
	"heat": 11.0,             # heat per stomp (a belly flop counts 1.5x)
	"min_fall": 3.5,          # you have to land on it (walking on doesn't pump)
	"boing": 2.5,             # it springs you back up a little
	"same_side_window": 0.9,  # the same bellows again this soon...
	"same_side_mult": 0.4,    # ...only pumps this much: alternate sides
	"burp_window": 1.8,       # this many stomps in this many seconds...
	"burp_stomps": 5,         # ...and the furnace burps a fireball
	"burp_heat_loss": 25.0,
	"burp_radius": 4.0,
	"burp_push": 7.0,
	"burp_stun": 0.8,
}
const HEAT_DECAY := 6.0           # heat lost per second
const SMELT_TIME := 3.0           # seconds in the heat band to make an ingot
const OVERHEAT_MARGIN := 12.0     # this far above the band = slag
const ANVIL_HITS := 4
const ANVIL_MISSES_TO_RUIN := 3
const BEAT_TIME := 1.2            # seconds for the beat marker to sweep across and back
const ANVIL_ZONE := 0.18          # share of the sweep that counts as on-beat
const INGOT_HOT_TIME := 14.0      # seconds an ingot stays hot enough to hammer
const GRIND_HITS := 3
const GRIND_ZONE := 0.22
const WEAPON_DURABILITY := 10
const WEAPON_DAMAGE := 10.0
const TIER_BONUS := 0.5           # extra damage per tier above the door's armor
const TOOL_DOOR_DAMAGE := 1.0     # pickaxe or hammer on the door
const WEAK_SPOT_MULT := 2.0
const WEAK_SPOT_WIDTH := 1.3
const BOUNCE_DURABILITY_COST := 2
const BURN_TIME := 0.6            # grabbing a hot ingot bare-handed: you drop it after this

const MATERIALS := [
	{"name": "Copper", "color": Color(0.85, 0.48, 0.25), "recipe": {"copper": 1}, "band": [30.0, 60.0]},
	{"name": "Bronze", "color": Color(0.80, 0.62, 0.28), "recipe": {"copper": 1, "tin": 1}, "band": [40.0, 70.0]},
	{"name": "Iron", "color": Color(0.50, 0.52, 0.58), "recipe": {"iron": 1, "coal": 1}, "band": [55.0, 80.0]},
	{"name": "Steel", "color": Color(0.78, 0.82, 0.88), "recipe": {"iron": 1, "coal": 2}, "band": [65.0, 88.0]},
	{"name": "Moonsilver", "color": Color(0.65, 0.78, 1.0), "recipe": {"moonsilver": 1}, "band": [60.0, 85.0]},
	{"name": "Starmetal", "color": Color(1.0, 0.88, 0.35), "recipe": {"starmetal": 1}, "band": [75.0, 95.0]},
]

const ORE_COLORS := {
	"copper": Color(0.85, 0.45, 0.2),
	"tin": Color(0.75, 0.78, 0.8),
	"iron": Color(0.45, 0.3, 0.25),
	"coal": Color(0.12, 0.12, 0.12),
	"moonsilver": Color(0.6, 0.75, 1.0),
	"starmetal": Color(1.0, 0.85, 0.2),
}

const DOORS := [
	{"area": "Quarry", "hp": 100.0, "tier": 0, "nodes": {"copper": 4}, "sky": Color(0.45, 0.5, 0.6)},
	{"area": "Riverbank", "hp": 150.0, "tier": 1, "nodes": {"copper": 3, "tin": 3}, "sky": Color(0.4, 0.5, 0.55)},
	{"area": "Coal pits", "hp": 200.0, "tier": 2, "nodes": {"iron": 3, "coal": 3, "copper": 1}, "sky": Color(0.4, 0.38, 0.38)},
	{"area": "Ruined keep", "hp": 260.0, "tier": 3, "nodes": {"iron": 3, "coal": 4}, "sky": Color(0.35, 0.36, 0.42)},
	{"area": "Moonlit cliffs", "hp": 320.0, "tier": 4, "nodes": {"moonsilver": 3, "iron": 2, "coal": 2}, "sky": Color(0.25, 0.3, 0.45)},
	{"area": "Storm ridge", "hp": 380.0, "tier": 5, "nodes": {"iron": 3, "coal": 3, "moonsilver": 2}, "sky": Color(0.25, 0.25, 0.32)},
	{"area": "Sky bridge", "hp": 440.0, "tier": 4, "nodes": {"moonsilver": 3, "iron": 2, "coal": 2}, "sky": Color(0.3, 0.32, 0.4)},
	{"area": "The Storm Gate", "hp": 520.0, "tier": 5, "nodes": {"iron": 2, "coal": 2, "moonsilver": 3}, "sky": Color(0.18, 0.18, 0.25)},
]

const ROLES := [
	{"name": "Miner", "tool": "pickaxe", "color": Color(0.85, 0.35, 0.3)},
	{"name": "Smelter", "tool": "tongs", "color": Color(0.95, 0.65, 0.2)},
	{"name": "Smith", "tool": "hammer", "color": Color(0.35, 0.55, 0.9)},
	{"name": "Finisher", "tool": "bucket", "color": Color(0.35, 0.75, 0.45)},
]

const BUFFS := [
	{"id": "rod", "name": "Lightning Rod", "desc": "First strike each area hits the rod"},
	{"id": "hot_coals", "name": "Hot Coals", "desc": "Bellows pumps 30% more heat"},
	{"id": "long_fuse", "name": "Long Fuse", "desc": "+30s on the storm timer"},
	{"id": "featherweight", "name": "Featherweight", "desc": "Hauling barely slows you"},
	{"id": "magnet", "name": "Magnet Gloves", "desc": "Your tool flies back after a strike"},
	{"id": "sharp", "name": "Sharp Edges", "desc": "Weapons deal +25% door damage"},
	{"id": "spare_handle", "name": "Spare Handle", "desc": "New weapons survive one break"},
	{"id": "second_wind", "name": "Second Wind", "desc": "Strikes stun for half as long"},
]

const DEBUFFS := [
	{"id": "static", "name": "Static Cling", "desc": "Lightning 50% more often"},
	{"id": "wet_coal", "name": "Wet Coal", "desc": "Bellows pumps 30% less heat"},
	{"id": "short_fuse", "name": "Short Fuse", "desc": "-30s on the storm timer"},
	{"id": "butterfingers", "name": "Butterfingers", "desc": "Sprinting can make you drop things"},
	{"id": "brittle", "name": "Brittle Batch", "desc": "Weapons wear 40% faster"},
	{"id": "tiny_anvil", "name": "Tiny Anvil", "desc": "Anvil beat window is half as wide"},
	{"id": "role_swap", "name": "Role Swap", "desc": "Everyone's tools rotate one smith"},
	{"id": "big_heads", "name": "Big Heads", "desc": "Purely cosmetic. Very big heads"},
]

## Drop-in models. Put a .glb/.gltf path here (for example a KayKit file you copied into
## res://assets/kaykit/) and that object uses the model instead of the placeholder shape.
## Leave a value empty to keep the placeholder.
## Models. A path, or {"path", "rot"} where rot (degrees) turns the model before it's
## scaled and centered to fit the thing's collision box. Empty keeps the placeholder.
## Characters: one per role, or "smith" for all four. They use the KayKit Rig_Medium
## animations in SMITH_ANIMS. All of these are KayKit (CC0), in assets/models/.
const M := "res://assets/models/"
const MODELS := {
	"smith": "",
	"smith_miner": M + "characters/Barbarian.glb",
	"smith_smelter": M + "characters/Engineer.glb",
	"smith_smith": M + "characters/Knight.glb",
	"smith_finisher": M + "characters/Druid.glb",
	"pickaxe": {"path": M + "tools/pickaxe.gltf", "rot": Vector3(-90, 0, 0)},
	"tongs": {"path": M + "tools/tongs.gltf", "rot": Vector3(-90, 0, 0)},
	"hammer": {"path": M + "tools/hammer.gltf", "rot": Vector3(-90, 0, 0)},
	"bucket": M + "tools/bucket_metal.gltf",
	"weapon": {"path": M + "weapons/sword_A.gltf", "rot": Vector3(-90, 0, 0)},
	"blank": {"path": M + "weapons/sword_A.gltf", "rot": Vector3(-90, 0, 0)},
	"ingot": {"path": M + "resources/Copper_Bar.gltf", "rot": Vector3(0, 90, 0)},
	"ore_chunk": M + "resources/Copper_Nugget_Large.gltf",
	"ore_node": M + "dungeon/rocks.gltf",
	"furnace": "",
	"bellows": M + "stations/bellows_giant.glb",  # nozzle +X, lid hinged at the nozzle, "Stomp" anim
	"anvil": M + "tools/anvil.gltf",
	"grindstone": M + "tools/grindstone.gltf",
	"trough": "",
	"door": "",
}
const SMITH_ANIMS := [M + "anims/Rig_Medium_MovementBasic.glb", M + "anims/Rig_Medium_General.glb",
	M + "anims/Rig_Medium_Tools.glb", M + "anims/Rig_Medium_MovementAdvanced.glb"]

const CAM_OFFSET := Vector3(0, 11, 9.5)  # camera sits this far above and behind the smith you play
const SMITH_MODEL_SCALE := 0.75  # KayKit characters are ~2.4 m; this fits the 1.7 m capsule
const SMITH_MODEL_YAW := PI       # KayKit models face +Z; Godot's forward is -Z
## Animation picked for each state: the first clip whose name contains one of these words.
const ANIM_WORDS := {
	"idle": ["idle_a", "idle"],
	"walk": ["walking_a", "walk"],
	"run": ["running_a", "run"],
	"dive": ["dodge_forward", "dodge", "roll"],
	"air": ["jump_idle", "jump"],
	"flop": ["jump_idle", "jump"],
	"stun": ["death_a", "hit", "death"],
}
## The goofy run laid over the walk and run clips. Tune freely.
const GOOFY := {
	"hop": 0.22,              # meters each step bounces you up
	"squash": 0.12,           # how much you squash on landing and stretch in the air
	"waddle_deg": 10.0,       # side-to-side rock
	"lean_deg": 10.0,         # lean into the run
	"arms_out_deg": 72.0,     # arms flung out to the sides
	"arm_flap_deg": 30.0,     # arms flap up and down each step
	"elbow_straighten": 0.75, # 0 = elbows bend like the clip, 1 = arms stick straight out
	"head_wobble_deg": 12.0,
	"bank": 0.06,             # lean into turns (per radian/second of turning)
	"flop_deg": 75.0,         # belly flop: how far forward you tip
	"skid_lean_deg": 14.0,    # lean back when you skid to reverse
	"steps_per_meter": 1.3,   # higher = quicker little steps
	"clip_speed": 1.35,       # walk and run clips play this much faster
}

## One-shot animations for actions (clip names in the KayKit Rig_Medium packs).
## One-shot actions. Each plays ONE swing of a KayKit clip: wind up, and at "impact"
## (seconds into the clip, where the tool meets its target) the effect happens, the
## tool bounces back (the clip plays backwards for "recoil" seconds), then you settle
## back to neutral. You can't move or act again until it's done.
##   clip, impact, speed (clip playback rate), recoil (seconds of bounce-back),
##   settle (seconds to blend back to idle), squash (goofy body squash on impact),
##   fx (hit effect: chips, sparks, splash, puff, stars, none)
const ACTIONS := {
	"pickaxe": {"clip": "Pickaxe", "impact": 0.88, "speed": 1.6, "recoil": 0.28, "settle": 0.22, "squash": 0.22},
	"hammer": {"clip": "Hammer", "impact": 0.55, "speed": 1.3, "recoil": 0.26, "settle": 0.2, "squash": 0.25},
	"weapon": {"clip": "Chop", "impact": 0.76, "speed": 1.5, "recoil": 0.3, "settle": 0.22, "squash": 0.2},
	"tongs": {"clip": "Work_A", "impact": 0.75, "speed": 2.2, "recoil": 0.22, "settle": 0.18, "squash": 0.18},
	"bucket": {"clip": "Use_Item", "impact": 0.68, "speed": 1.7, "recoil": 0.25, "settle": 0.2, "squash": 0.15},
	"grab": {"clip": "PickUp", "impact": 0.5, "speed": 2.2, "recoil": 0.0, "settle": 0.15, "squash": 0.12},
	"place": {"clip": "Interact", "impact": 0.45, "speed": 2.2, "recoil": 0.0, "settle": 0.15, "squash": 0.1},
	"throw": {"clip": "Throw", "impact": 0.72, "speed": 1.6, "recoil": 0.0, "settle": 0.2, "squash": 0.12},
}

## The smith's states, and which buttons work in each. One state at a time:
##   ground: on your feet, free to move and work
##   air: jumping or falling (press jump again to belly flop)
##   flop: belly flop and slide (press jump to stand back up)
##   act: mid-swing, planted until it settles
##   stunned: struck by lightning, flying or flat on your back
const STATE_ALLOWS := {
	"ground": ["move", "dive", "slot", "interact", "use", "throw"],
	"air": ["move", "dive", "slot"],
	"flop": ["dive"],
	"act": [],
	"stunned": [],
}

## Lightning launch: the struck smith goes flying, limp and buzzing.
const ZAP := {
	"launch_up": 8.5,         # up speed when struck
	"launch_out": 5.0,        # sideways speed, away from where the tools fly
	"gravity": 22.0,          # floatier than normal while flying
	"spin": 9.0,              # tumble speed (radians/second) in the air
	"bounce": 0.35,           # how much of the fall speed bounces back on the first landing
	"buzz_time": 0.7,         # electrocuted jitter
	"buzz": 0.07,             # jitter size (meters)
}

static func material_name(tier: int) -> String:
	if tier < 0 or tier >= MATERIALS.size():
		return "?"
	return MATERIALS[tier]["name"]

static func material_color(tier: int) -> Color:
	if tier < 0 or tier >= MATERIALS.size():
		return Color.GRAY
	return MATERIALS[tier]["color"]

## Tries to load a drop-in model. Returns null when none is set or the file is missing.
static func model_path(key: String) -> String:
	var v = MODELS.get(key, "")
	if v is Dictionary:
		return v.get("path", "")
	return v

static func try_model(key: String) -> Node3D:
	var path = model_path(key)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is PackedScene:
		return res.instantiate()
	return null

## A model turned, scaled and centered to fill a box of this size, or null if the key is empty.
## The holder's "grip" meta is where the model's own origin ended up (for hand slots).
## by_length: scale so the longest side matches (tools); otherwise fit inside the box.
static func fitted_model(key: String, size: Vector3, by_length: bool = false) -> Node3D:
	var model = try_model(key)
	if model == null:
		return null
	var v = MODELS.get(key, "")
	var rot: Vector3 = v.get("rot", Vector3.ZERO) if v is Dictionary else Vector3.ZERO
	var holder = Node3D.new()
	holder.rotation_degrees = rot
	holder.add_child(model)
	var box = mesh_aabb(model, holder.transform)
	var k = 1.0
	if box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0:
		k = minf(size.x / box.size.x, minf(size.y / box.size.y, size.z / box.size.z))
		if by_length:
			k = maxf(size.x, maxf(size.y, size.z)) / maxf(box.size.x, maxf(box.size.y, box.size.z))
	var center = (box.position + box.size * 0.5) * k
	var outer = Node3D.new()
	outer.add_child(holder)
	holder.scale = Vector3.ONE * k
	holder.position = -center
	outer.set_meta("grip", Transform3D(Basis.from_euler(rot * PI / 180.0), -center))
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

## A see-through color laid over a textured model, to tell ores and metals apart.
static func tint(n: Node, c: Color, strength: float = 0.5, glow: float = 0.0) -> void:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, strength)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = m
	if n is MeshInstance3D:
		n.material_overlay = m
