extends Game
## Tong Carry: the hot ingot pops out of the furnace. Grab it with the tongs (hold) and drag
## it along the chalk path to the anvil. Stray off the path or let go and you drop it.

const Y := 0.95             # carrying height
var path := PackedVector3Array()
var lengths := PackedFloat32Array()   # running length at each point
var total_len := 0.0
var width := 0.7            # half width of the safe corridor (meters)
var ingot: Node3D
var heat_mat: StandardMaterial3D
var tong: Node3D
var pos := Vector3.ZERO
var holding := false
var progress := 0.0         # meters along the path reached
var drops := 0
var state := "wait"         # wait, carry, dropped, done
var key_dir := Vector2.ZERO
var key_hold := false
var cool := 1.0

func shot() -> String:
	return "floor"

func prepare() -> void:
	width = BK.TONGS["width"] + BK.TONGS["width_per_tier"] * tier
	if up("tongs"):
		width += 0.18
	limit = BK.TONGS["limit"]
	var a = Workshop.FURNACE + Vector3(0, 0, 1.6)
	var b = Workshop.ANVIL
	var pts = [Vector2(a.x, a.z), Vector2(-5.1, -0.3), Vector2(-4.1, 0.9), Vector2(-3.2, -0.5),
		Vector2(-2.5, 1.0), Vector2(-1.5, 0.6), Vector2(b.x, b.z + 0.1)]
	var jitter = 0.25 + 0.05 * tier
	for i in range(1, pts.size() - 1):
		pts[i] += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	# Smooth it into a gentle curve.
	var c = Curve2D.new()
	for i in pts.size():
		var tan_v = Vector2.ZERO
		if i > 0 and i < pts.size() - 1:
			tan_v = (pts[i + 1] - pts[i - 1]) * 0.25
		c.add_point(pts[i], -tan_v, tan_v)
	var baked = c.get_baked_points()
	var run = 0.0
	for i in baked.size():
		var p = Vector3(baked[i].x, Y, baked[i].y)
		if i > 0:
			run += p.distance_to(path[i - 1])
		path.append(p)
		lengths.append(run)
	total_len = run
	# Chalk dashes on the floor along the path.
	var dash_mat = Build.mat(Color(0.95, 0.93, 0.85), 0.25)
	var step_i = maxi(1, int(baked.size() / 40.0))
	for i in range(0, path.size() - step_i, step_i * 2):
		var p0 = path[i]
		var p1 = path[mini(i + step_i, path.size() - 1)]
		var d = Build.box(Vector3(0.08, 0.02, p0.distance_to(p1)), Color.WHITE)
		d.material_override = dash_mat
		ws.props.add_child(d)
		d.global_position = (p0 + p1) * 0.5 * Vector3(1, 0, 1) + Vector3(0, 0.02, 0)
		d.look_at(Vector3(p1.x, 0.02, p1.z), Vector3.UP)
	var x = Build.box(Vector3(0.9, 0.02, 0.9), Color(1.0, 0.85, 0.3), 0.6)
	ws.props.add_child(x)
	x.global_position = Vector3(b.x, 0.03, b.z + 0.1)
	ingot = make_bar(0.55)
	heat_mat = heat_tint(ingot, 1.0)
	pos = path[0]
	ingot.global_position = pos
	tong = BK.fitted(BK.M + "tools/tongs.gltf", 1.1)
	ws.props.add_child(tong)
	tong.visible = false
	# The ingot flies out of the chimney and lands at the start.
	ws.pop_cap()
	var top = ws.spout.global_position if ws.spout else Workshop.FURNACE + Vector3(0, 3.5, 0)
	ingot.global_position = top
	var tw = create_tween()
	tw.tween_property(ingot, "global_position", (top + pos) * 0.5 + Vector3(0, 1.2, 0), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(ingot, "global_position", Vector3(pos.x, 0.15, pos.z), 0.3).set_ease(Tween.EASE_IN)

func _nearest(p: Vector3) -> Array:
	# [distance, length along the path] of the closest point on the path (xz).
	var best_d = 1e9
	var best_l = 0.0
	var q = Vector2(p.x, p.z)
	for i in range(path.size() - 1):
		var a = Vector2(path[i].x, path[i].z)
		var b = Vector2(path[i + 1].x, path[i + 1].z)
		var ab = b - a
		var k = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d = q.distance_to(a + ab * k)
		if d < best_d:
			best_d = d
			best_l = lengths[i] + ab.length() * k
	return [best_d, best_l]

func _point_at(l: float) -> Vector3:
	for i in range(path.size() - 1):
		if lengths[i + 1] >= l:
			var k = (l - lengths[i]) / maxf(lengths[i + 1] - lengths[i], 1e-6)
			return path[i].lerp(path[i + 1], k)
	return path[path.size() - 1]

func on_input(e: InputEvent) -> void:
	if is_press(e) and state == "wait":
		var sp = ws.to_screen(Vector3(pos.x, 0.15, pos.z))
		if e.position.distance_to(sp) < 110:
			_grab()
	elif is_release(e) and state == "carry" and not key_hold:
		_drop("Let go!")
	elif e is InputEventKey and e.physical_keycode == KEY_SPACE and not e.echo:
		if e.pressed and state == "wait":
			key_hold = true
			_grab()
		elif not e.pressed and key_hold:
			key_hold = false
			if state == "carry":
				_drop("Let go!")

func _grab() -> void:
	state = "carry"
	Sfx.play("tick", 0.7)
	holding = true
	tong.visible = true
	pos.y = Y

func _drop(why: String) -> void:
	state = "dropped"
	drops += 1
	tong.visible = false
	popup(why + " Hssss!", ws.to_screen(pos), Color(0.95, 0.45, 0.3), 34)
	var tw = create_tween()
	tw.tween_property(ingot, "global_position", Vector3(pos.x, 0.12, pos.z), 0.2).set_ease(Tween.EASE_IN)
	Fx.burst(ws, Vector3(pos.x, 0.2, pos.z), Color(0.9, 0.9, 0.9, 0.7), 14, 1.6, 2.5, 2.0, 0.9)
	Fx.burst(ws, Vector3(pos.x, 0.2, pos.z), Color(1.0, 0.6, 0.2), 10, 0.6, 4.0, -8.0, 0.4)
	ws.shake(0.1)
	Sfx.play("sizzle")
	get_tree().create_timer(0.6).timeout.connect(func():
		if state != "dropped":
			return
		pos = _point_at(maxf(0.0, progress - 0.4))
		var tw2 = create_tween()
		tw2.tween_property(ingot, "global_position", Vector3(pos.x, 0.15, pos.z), 0.25)
		state = "wait")

func tick(delta: float) -> void:
	cool = clampf(1.0 - t / BK.TONGS["cool_time"] * 0.7, 0.25, 1.0)
	set_heat(heat_mat, cool)
	if t >= limit and state != "done":
		_finish_carry(false)
		return
	if state != "carry":
		return
	var target = pos
	if key_hold:
		var kd = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
		kd += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		target = pos + Vector3(kd.x, 0, kd.y).limit_length(1.0) * 2.6 * delta
	else:
		var hit = ws.pointer_on_plane(get_viewport().get_mouse_position(), Y)
		if hit != null:
			target = hit
	var step_v = (target - pos).limit_length(3.2 * delta)
	pos += step_v
	pos.y = Y
	ingot.global_position = pos + Vector3(0, sin(t * 20.0) * 0.015, 0)
	ingot.rotation.y = lerp_angle(ingot.rotation.y, atan2(step_v.x, step_v.z), minf(1.0, delta * 8.0)) if step_v.length() > 0.001 else ingot.rotation.y
	tong.global_position = pos + Vector3(0, 0.55, 0.25)
	tong.rotation_degrees = Vector3(-60, 0, 0)
	if randf() < delta * 8.0:
		Fx.burst(ws, pos, Color(1.0, 0.6, 0.2), 1, 0.4, 1.0, -3.0, 0.4)
	var near = _nearest(pos)
	if near[0] > width:
		_drop("Off the path!")
		return
	progress = maxf(progress, near[1]) if near[1] <= progress + 0.8 else progress
	if Vector2(pos.x, pos.z).distance_to(Vector2(path[path.size() - 1].x, path[path.size() - 1].z)) < 0.45 and progress > total_len - 1.0:
		_finish_carry(true)

func _finish_carry(made_it: bool) -> void:
	state = "done"
	active = false
	tong.visible = false
	var top = Workshop.ANVIL + Vector3(0, ws.anvil_top + 0.08, 0)
	var tw = create_tween()
	tw.tween_property(ingot, "global_position", top, 0.25)
	var par = total_len / 2.0
	var score = 100.0 - drops * 22.0 - maxf(0.0, t - par) * 5.0
	if not made_it:
		score = minf(score, 100.0 * progress / total_len * 0.6)
	get_tree().create_timer(0.5).timeout.connect(func(): finish(score))

func draw_game() -> void:
	# The safe corridor, drawn over the floor.
	var pts = PackedVector2Array()
	var step_i = maxi(1, int(path.size() / 60.0))
	for i in range(0, path.size(), step_i):
		pts.append(ws.to_screen(Vector3(path[i].x, 0.0, path[i].z)))
	pts.append(ws.to_screen(Vector3(path[path.size() - 1].x, 0.0, path[path.size() - 1].z)))
	var px_per_m = ws.to_screen(Vector3(path[0].x + 1.0, 0, path[0].z)).x - ws.to_screen(Vector3(path[0].x, 0, path[0].z)).x
	if pts.size() > 1:
		draw_polyline(pts, Color(1.0, 0.9, 0.5, 0.28), width * 2.0 * absf(px_per_m), true)
	if state == "wait":
		var sp = ws.to_screen(Vector3(pos.x, 0.15, pos.z))
		draw_arc(sp, 60 + 8 * sin(t * 8.0), 0, TAU, 40, Color(1, 0.85, 0.3), 5)
		text(sp + Vector2(0, -90), "GRAB!", 32, Color(1, 0.9, 0.5))
	hbar(Rect2(vsize().x * 0.5 - 150, vsize().y - 60, 300, 18), cool, BK.heat_color(cool), "HEAT")
	if drops > 0:
		text(Vector2(140, vsize().y - 60), "Drops: %d" % drops, 26, Color(1, 0.6, 0.5))
