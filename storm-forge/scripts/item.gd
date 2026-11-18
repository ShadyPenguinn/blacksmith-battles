extends RigidBody3D
## Anything you can pick up: tools, ore, ingots, blanks, weapons, scrap.

var kind = ""        # "tool", "ore", "ingot", "blank", "weapon", "scrap"
var tool = ""        # pickaxe, tongs, hammer, bucket
var ore = ""         # copper, tin, iron, coal, moonsilver, starmetal
var tier = -1        # material index for ingot, blank, weapon, scrap
var hot = 0.0        # seconds of heat left on ingots
var durability = 0.0
var spare_handle = false
var bucket_full = false
var quenched = false
var tongs_load: RigidBody3D = null   # what the tongs are gripping
var holder: Node3D = null            # player holding this
var gripped_by: RigidBody3D = null   # tongs gripping this
var station: Node3D = null           # station this sits on
var owner_idx = -1                  # which smith spawned with this tool
var visual: Node3D
var tag: Label3D
var net_id = 0                       # same id on host and clients
var puppet = false                   # client side: follow snapshots
var net_pos = Vector3.ZERO
var net_rot = Vector3.ZERO
var net_loose = true

func setup(p_kind: String, opts: Dictionary = {}) -> void:
	kind = p_kind
	tool = opts.get("tool", "")
	ore = opts.get("ore", "")
	tier = opts.get("tier", -1)
	add_to_group("item")
	mass = 2.0 if kind == "tool" else 3.0
	continuous_cd = true
	collision_layer = 2
	collision_mask = 1 | 2
	var size = _size()
	add_child(Build.box_shape(size))
	visual = SF.try_model(_model_key())
	if visual == null:
		visual = _placeholder(size)
	add_child(visual)
	tag = Build.label("", 32)
	tag.position = Vector3(0, size.y * 0.5 + 0.35, 0)
	add_child(tag)
	if kind == "ingot":
		hot = SF.INGOT_HOT_TIME
	if kind == "weapon":
		durability = SF.WEAPON_DURABILITY

func _model_key() -> String:
	match kind:
		"tool": return tool
		"ore", "scrap": return "ore_chunk"
		"ingot", "blank": return "ingot"
		"weapon": return "weapon"
	return ""

func _size() -> Vector3:
	match kind:
		"tool":
			match tool:
				"bucket": return Vector3(0.5, 0.5, 0.5)
				"tongs": return Vector3(0.2, 0.2, 1.0)
				_: return Vector3(0.25, 0.25, 1.1)
		"ore", "scrap": return Vector3(0.55, 0.45, 0.55)
		"ingot": return Vector3(0.5, 0.2, 0.25)
		"blank": return Vector3(0.18, 0.08, 1.0)
		"weapon": return Vector3(0.2, 0.12, 1.3)
	return Vector3.ONE * 0.4

func _placeholder(size: Vector3) -> Node3D:
	var root = Node3D.new()
	match kind:
		"tool":
			var c: Color = {"pickaxe": Color(0.85, 0.35, 0.3), "tongs": Color(0.95, 0.65, 0.2),
				"hammer": Color(0.35, 0.55, 0.9), "bucket": Color(0.35, 0.75, 0.45)}.get(tool, Color.WHITE)
			if tool == "bucket":
				root.add_child(Build.cyl(0.25, 0.5, c))
			else:
				root.add_child(Build.box(Vector3(0.08, 0.08, size.z), Color(0.45, 0.3, 0.2)))
				var head = Build.box(Vector3(0.45 if tool == "pickaxe" else 0.25, 0.2, 0.2), c)
				head.position.z = -size.z * 0.45
				root.add_child(head)
		"ore":
			root.add_child(Build.box(size, SF.ORE_COLORS.get(ore, Color.GRAY), 0.4 if ore == "starmetal" else 0.0))
		"scrap":
			root.add_child(Build.box(size * 0.8, SF.material_color(tier).darkened(0.4)))
		"ingot", "blank":
			root.add_child(Build.box(size, SF.material_color(tier)))
		"weapon":
			var blade = Build.box(Vector3(0.12, 0.06, 0.95), SF.material_color(tier), 0.15)
			blade.position.z = -0.2
			root.add_child(blade)
			var grip = Build.box(Vector3(0.1, 0.1, 0.35), Color(0.4, 0.25, 0.15))
			grip.position.z = 0.45
			root.add_child(grip)
	return root

func is_metal() -> bool:
	if kind in ["ingot", "blank", "weapon", "scrap"]:
		return true
	if kind == "ore":
		return ore != "coal"
	if kind == "tool":
		return tool != "bucket"
	return false

func is_heavy() -> bool:
	return kind in ["ore", "ingot", "scrap"]

func display_name() -> String:
	match kind:
		"tool":
			if tool == "bucket":
				return "Bucket (" + ("full" if bucket_full else "empty") + ")"
			if tool == "tongs" and tongs_load:
				return "Tongs holding " + tongs_load.display_name()
			return tool.capitalize()
		"ore": return ore.capitalize() + " ore"
		"ingot": return ("Hot " if hot > 0.0 else "Cold ") + SF.material_name(tier) + " ingot"
		"blank": return SF.material_name(tier) + " blade" + (" (quenched)" if quenched else "")
		"weapon": return SF.material_name(tier) + " sword (" + str(int(ceil(durability))) + ")"
		"scrap": return SF.material_name(tier) + " scrap"
	return kind

func is_free() -> bool:
	return holder == null and gripped_by == null

func _physics_process(delta: float) -> void:
	if puppet:
		global_position = global_position.lerp(net_pos, clampf(delta * 15.0, 0.0, 1.0))
		global_rotation = net_rot
	elif kind == "ingot" and hot > 0.0:
		hot = maxf(0.0, hot - delta)
	# Glow while hot.
	if kind == "ingot" and visual.get_child_count() > 0 and visual.get_child(0) is MeshInstance3D:
		var m: StandardMaterial3D = (visual.get_child(0) as MeshInstance3D).material_override
		if m:
			m.emission_enabled = hot > 0.0
			m.emission = Color(1.0, 0.45, 0.1)
			m.emission_energy_multiplier = 1.5 * hot / SF.INGOT_HOT_TIME
	tag.text = ""
	if kind in ["weapon", "ingot"] or (kind == "tool" and tool == "bucket"):
		if (puppet and net_loose) or (not puppet and holder == null and station == null and gripped_by == null):
			tag.text = display_name()

## Freeze in place and follow a transform each frame (held, gripped, or on a station).
func attach() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func release(impulse: Vector3 = Vector3.ZERO) -> void:
	holder = null
	gripped_by = null
	if station:
		station.clear_slot(self)
		station = null
	freeze = false
	collision_layer = 2
	collision_mask = 1 | 2
	sleeping = false
	if impulse != Vector3.ZERO:
		apply_central_impulse(impulse * mass)
		apply_torque_impulse(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 2.0)
