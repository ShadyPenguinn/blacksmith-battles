extends Node3D
## The storm: picks targets, shows the warning ring, strikes.

var main: Node
var next_in = 8.0
var target: Node3D = null       # player, ore node or rod
var target_pos = Vector3.ZERO
var warn_t = -1.0              # time left on the current warning, -1 when idle
var ring: MeshInstance3D
var rod_used = false
var strikes = 0

func setup(p_main: Node) -> void:
	main = p_main
	ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = SF.STRIKE_RADIUS - 0.15
	tm.outer_radius = SF.STRIKE_RADIUS
	ring.mesh = tm
	ring.material_override = Build.mat(Color(1.0, 0.95, 0.4), 3.0)
	ring.visible = false
	add_child(ring)

func reset_area() -> void:
	next_in = 8.0
	warn_t = -1.0
	ring.visible = false
	rod_used = false

## Seconds between strikes right now.
func gap() -> float:
	var g: float
	if main.time_left > 0.0:
		var p = 1.0 - main.time_left / main.area_time
		g = lerpf(SF.STRIKE_GAP_START, SF.STRIKE_GAP_PEAK, p * p)
	else:
		g = maxf(SF.STRIKE_GAP_MIN, SF.STRIKE_GAP_PEAK - main.peak_time * 0.03)
	g /= 1.5 ** main.mod("static")
	return g / main.player_scale("lightning")

func _physics_process(delta: float) -> void:
	if main.is_client() or main.over or main.paused_for_roll or not main.run_started:
		return
	if warn_t >= 0.0:
		warn_t -= delta
		if target and is_instance_valid(target) and warn_t > SF.TELEGRAPH_LOCK and target.is_in_group("player"):
			target_pos = target.global_position
		ring.global_position = Vector3(target_pos.x, 0.08, target_pos.z)
		var pulse = 1.0 + 0.15 * sin(warn_t * 30.0)
		ring.scale = Vector3(pulse, 1, pulse)
		if warn_t <= 0.0:
			strike(target_pos)
			warn_t = -1.0
			ring.visible = false
		return
	next_in -= delta
	if next_in <= 0.0:
		begin_warning(pick_target())

func pick_target() -> Node3D:
	if main.mod("rod") > 0 and not rod_used and main.rod:
		rod_used = true
		return main.rod
	var nodes = get_tree().get_nodes_in_group("node")
	if not nodes.is_empty() and randf() < SF.NODE_STRIKE_CHANCE:
		return nodes.pick_random()
	var players = get_tree().get_nodes_in_group("player")
	var total = 0.0
	for p in players:
		total += 1.0 + SF.METAL_WEIGHT * p.metal_count()
	var r = randf() * total
	for p in players:
		r -= 1.0 + SF.METAL_WEIGHT * p.metal_count()
		if r <= 0.0:
			return p
	return players.back()

func begin_warning(t: Node3D) -> void:
	target = t
	target_pos = t.global_position
	warn_t = SF.TELEGRAPH
	ring.visible = true
	next_in = gap()

## Strike a spot now. Public so tests and debug keys can call it.
func strike(pos: Vector3) -> void:
	strikes += 1
	_bolt(pos)
	main.flash()
	main.net.send_event("strike", pos)
	if target == main.rod:
		main.toast("The rod took the hit!")
		return
	for p in get_tree().get_nodes_in_group("player"):
		var d = Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
		if d <= SF.STRIKE_RADIUS:
			p.zap()
			main.toast("ZAP! " + p.role["name"] + " got struck!")
	for n in get_tree().get_nodes_in_group("node"):
		var d2 = Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length()
		if d2 <= SF.STRIKE_RADIUS and main.door_index >= SF.STARMETAL_FROM_DOOR and n.ore != "starmetal":
			n.set_ore("starmetal")
			main.toast("Lightning turned the ore into Starmetal!")

## Just the visual. Clients call this when the host says a strike landed.
func _bolt(pos: Vector3) -> void:
	var bolt = Node3D.new()
	add_child(bolt)
	var p = Vector3(pos.x, 30.0, pos.z)
	var steps = 10
	for i in steps:
		var q = Vector3(pos.x + randf_range(-1.2, 1.2), 30.0 - 30.0 * float(i + 1) / steps, pos.z + randf_range(-1.2, 1.2))
		if i == steps - 1:
			q = Vector3(pos.x, 0.0, pos.z)
		var seg = Build.box(Vector3(0.35, 0.35, p.distance_to(q)), Color(0.85, 0.9, 1.0), 14.0)
		bolt.add_child(seg)
		seg.global_position = (p + q) * 0.5
		seg.look_at_from_position(seg.global_position, q, Vector3.RIGHT)
		p = q
	# No OmniLight here: the first light of its kind makes every nearby material compile a
	# new shader, which froze the game on the first strike. The screen flash lights it instead.
	var scorch = Build.cyl(1.0, 0.02, Color(0.1, 0.1, 0.1))
	add_child(scorch)
	scorch.global_position = Vector3(pos.x, 0.02, pos.z)
	get_tree().create_timer(0.22).timeout.connect(bolt.queue_free)
	get_tree().create_timer(6.0).timeout.connect(scorch.queue_free)
