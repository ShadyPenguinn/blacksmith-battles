extends Game
## Crush the Ore: real ore is broken into small pieces and roasted before it goes in the
## furnace. Click a big chunk to split it in two; once a piece is gravel it slides into the
## roasting pan. Hit the gravel before it slides off and it turns to dust (wasted ore).

const SIZES := [0.0, 0.17, 0.28, 0.4]    # model length by size (1 gravel .. 3 big)
var chunks := []      # {node, size, pos (world), gravel_t}
var dust := 0
var splits_needed := 0
var splits := 0
var slab_top := 0.3
var pan: Node3D
var pan_pos := Vector3.ZERO
var sledge: Node3D
var roasted := 0

func shot() -> String:
	return "crush"

func _slab_center() -> Vector3:
	return Workshop.CRUSH

func prepare() -> void:
	limit = BK.CRUSH["limit"]
	var slab = Build.box(Vector3(1.7, slab_top, 0.9), Color(0.42, 0.4, 0.38))
	ws.props.add_child(slab)
	slab.global_position = _slab_center() + Vector3(0, slab_top * 0.5, 0)
	# The roasting pan: a shallow tray over coals on the right.
	pan_pos = _slab_center() + Vector3(1.25, 0.25, 0.1)
	pan = Node3D.new()
	ws.props.add_child(pan)
	pan.global_position = pan_pos
	var coals = Build.box(Vector3(0.6, 0.2, 0.6), Color(1.0, 0.4, 0.1), 1.6)
	pan.add_child(coals)
	coals.position = Vector3(0, -0.12, 0)
	var tray = Build.box(Vector3(0.7, 0.06, 0.7), Color(0.25, 0.23, 0.22))
	pan.add_child(tray)
	sledge = BK.fitted(BK.M + "tools/hammer.gltf", 0.55)
	ws.props.add_child(sledge)
	_sledge_pose(0.0)
	var n = BK.CRUSH["chunks"] + BK.CRUSH["chunks_per_2_tiers"] * (tier / 2)
	for i in n:
		var x = lerpf(-0.55, 0.45, (i + 0.5) / n) + randf_range(-0.08, 0.08)
		_add_chunk(BK.CRUSH["size"], _slab_center() + Vector3(x, slab_top, randf_range(-0.15, 0.2)))
	# Each big chunk takes (2^(size-1) - 1) splits to become gravel.
	splits_needed = n * (int(pow(2, BK.CRUSH["size"] - 1)) - 1)

func _add_chunk(size: int, pos: Vector3) -> Dictionary:
	var node = BK.fitted(BK.M + "resources/" + BK.MATERIALS[tier]["ore"] + ".gltf", SIZES[size])
	if node == null:
		node = Build.sphere(SIZES[size] * 0.5, mat_color())
	ws.props.add_child(node)
	BK.tint(node, mat_color().darkened(0.25), 0.5)
	node.rotation_degrees.y = randf_range(0, 360)
	pos.y = slab_top + SIZES[size] * 0.4
	node.global_position = pos
	var c = {"node": node, "size": size, "pos": pos, "gravel_t": 0.0}
	chunks.append(c)
	return c

func _sledge_pose(k: float) -> void:
	var c = _slab_center()
	sledge.global_position = c + Vector3(0.75, 0.85, -0.1).lerp(Vector3(0.35, 0.5, -0.1), k)
	sledge.rotation_degrees = Vector3(0, 0, lerpf(-20.0, 60.0, k))

func on_input(e: InputEvent) -> void:
	if is_press(e):
		_hit(e.position)

func _hit(p: Vector2) -> void:
	var best = null
	var best_d = 1e9
	for c in chunks:
		var d = ws.to_screen(c["pos"]).distance_to(p)
		if d < 50.0 + c["size"] * 22.0 and d < best_d:
			best = c
			best_d = d
	var tw = create_tween()
	tw.tween_method(_sledge_pose, 0.0, 1.0, 0.05)
	tw.tween_method(_sledge_pose, 1.0, 0.0, 0.15)
	if best == null:
		Sfx.play("thud", 1.4)
		popup("Clonk", p, Color(0.8, 0.8, 0.8), 22)
		return
	chunks.erase(best)
	best["node"].queue_free()
	if best["size"] <= 1:
		dust += 1
		Sfx.play("bad", 1.2)
		popup("Dust!", p, Color(0.85, 0.6, 0.5), 32)
		Fx.burst(ws, best["pos"], Color(0.6, 0.55, 0.5, 0.8), 14, 1.4, 1.5, 0.4, 0.8)
		return
	splits += 1
	Sfx.play("crack", 1.1 + (3 - best["size"]) * 0.15)
	ws.shake(0.05)
	Fx.burst(ws, best["pos"], mat_color(), 10, 0.8, 3.5, -9.0, 0.5, Vector3.UP, 70.0, true)
	popup("SMASH!" if best["size"] == 3 else "Crack!", p, Color(1.0, 0.85, 0.35), 32)
	for side in [-1, 1]:
		var off = Vector3(side * randf_range(0.1, 0.18), 0, randf_range(-0.12, 0.12))
		var to = best["pos"] + off
		to.x = clampf(to.x, _slab_center().x - 0.75, _slab_center().x + 0.7)
		to.z = clampf(to.z, _slab_center().z - 0.35, _slab_center().z + 0.35)
		var c = _add_chunk(best["size"] - 1, best["pos"])
		c["pos"] = Vector3(to.x, c["pos"].y, to.z)
		var hop = create_tween()
		hop.tween_property(c["node"], "global_position", c["pos"] + Vector3(0, 0.25, 0), 0.1)
		hop.tween_property(c["node"], "global_position", c["pos"], 0.12)

func tick(delta: float) -> void:
	# Gravel waits a moment, then slides into the roasting pan.
	for c in chunks.duplicate():
		if c["size"] != 1:
			continue
		c["gravel_t"] += delta
		if c["gravel_t"] > 0.8:
			chunks.erase(c)
			roasted += 1
			var n: Node3D = c["node"]
			var tw = create_tween()
			tw.tween_property(n, "global_position", pan_pos + Vector3(randf_range(-0.2, 0.2), 0.08, randf_range(-0.2, 0.2)), 0.35).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func():
				BK.tint(n, Color(0.35, 0.15, 0.08), 0.6, 0.6, Color(1.0, 0.4, 0.1))
				Fx.burst(ws, pan_pos + Vector3(0, 0.2, 0), Color(0.5, 0.5, 0.5, 0.6), 4, 1.2, 1.2, 1.5, 0.8))
	if chunks.is_empty() or t >= limit:
		active = false
		var done = float(splits) / float(maxi(1, splits_needed))
		var speed = clampf(1.0 - (t - 4.0) / (limit - 4.0), 0.0, 1.0)
		var score = 100.0 * done * (0.7 + 0.3 * speed) - dust * BK.CRUSH["dust"]
		if chunks.is_empty():
			popup("Roasting!", ws.to_screen(pan_pos) + Vector2(0, -70), Color(1.0, 0.6, 0.3), 36)
			Sfx.play("sizzle", 0.8)
		get_tree().create_timer(0.9).timeout.connect(func(): finish(score))

func draw_game() -> void:
	for c in chunks:
		if c["size"] >= 2:
			var p = ws.to_screen(c["pos"])
			draw_arc(p, 40.0 + c["size"] * 12.0, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.5 + 0.3 * sin(t * 6.0)), 3)
	text(Vector2(vsize().x * 0.5, vsize().y - 60), "Roasting pan: %d   Dust: %d" % [roasted, dust], 28)
