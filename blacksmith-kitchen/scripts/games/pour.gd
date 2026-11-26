extends BenchGame
## Pour the Mold (cast metals only): the crucible of liquid metal hangs over a sand mold on
## the bench. Hold to tip it. Tip too little and nothing comes out, tip too far and it
## splashes. Fill to the line before the metal cools, stop, then click to crack the mold open.

var crucible: Node3D        # pivots on its lip
var stream: MeshInstance3D
var stream_mat: StandardMaterial3D
var mold: MeshInstance3D
var cavity: Node3D
var cast: Node3D
var cast_shader: ShaderMaterial   # hides the cast past the metal's front, so it runs grip to tip
const RUN := """
shader_type spatial;
render_mode unshaded;
uniform float front = -100.0;
uniform vec4 hot : source_color = vec4(1.0, 0.7, 0.3, 1.0);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (wp.x > front) { discard; }
	float edge = clamp((front - wp.x) * 6.0, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0, 0.95, 0.7), hot.rgb, edge);
}
"""
var cast_mat: StandardMaterial3D
var tilt := 0.0
var holding := false
var fill := 0.0
var metal := 1.25
var spilled := 0.0
var overflow := 0.0
var temp := 1.0
var flow := 0.0
var still_t := 0.0
var phase := "pour"         # pour, crack, done
var cracks := 0
var pour_score := 0.0
var lip := Vector3.ZERO
var gate := Vector3.ZERO
var base := Workshop.CAST   # the casting table
var crack_only := false     # shop mode: the mold has cooled, just crack it
var pour_only := false      # shop mode: pour, then the mold cools on its own

func shot() -> String:
	return "cast"

func prepare() -> void:
	limit = 16.0
	crack_only = order.get("crack_only", false)
	pour_only = order.get("pour_only", false)
	metal = BK.POUR["metal"]
	blade_len = minf(BK.WEAPONS[order.get("weapon", "sword")]["len"], 1.6)
	var top = ws.bench_top()
	# Sand mold box on the bench, with the blade's shape pressed into it.
	mold = Build.box(Vector3(blade_len + 0.45, 0.16, 0.75), Color(0.72, 0.6, 0.42))
	ws.props.add_child(mold)
	mold.global_position = base + Vector3(0.35, top + 0.08, 0.05)
	cavity = make_weapon(blade_len)
	BK.tint(cavity, Color(0.12, 0.09, 0.07), 0.92)
	cavity.rotation_degrees = Vector3(90, 0, -90)
	cavity.global_position = base + Vector3(0.35, top + 0.162, 0.05)
	cavity.scale = Vector3(1.0, 1.0, 0.25)
	gate = base + Vector3(0.35 - blade_len * 0.5 - 0.1, top + 0.17, 0.05)
	cast = make_weapon(blade_len)
	cast.rotation_degrees = Vector3(90, 0, -90)
	cast.global_position = base + Vector3(0.35, top + 0.172, 0.05)
	cast.scale = Vector3(1.0, 1.0, 0.3)
	var sh = Shader.new()
	sh.code = RUN
	cast_shader = ShaderMaterial.new()
	cast_shader.shader = sh
	cast_shader.set_shader_parameter("hot", mat_color().lerp(Color(1.0, 0.6, 0.2), 0.6))
	for mi in cast.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = cast_shader
	# The crucible: a clay pot full of glowing metal, pivoting on its pouring lip.
	lip = gate + Vector3(-0.08, 0.5, 0)
	crucible = Node3D.new()
	ws.props.add_child(crucible)
	crucible.global_position = lip
	var pot = Build.cyl(0.2, 0.42, Color(0.45, 0.3, 0.22))
	crucible.add_child(pot)
	pot.position = Vector3(-0.2, -0.21, 0)
	var melt = Build.cyl(0.17, 0.03, mat_color().lerp(Color(1.0, 0.7, 0.3), 0.6), 2.5)
	crucible.add_child(melt)
	melt.position = Vector3(-0.2, -0.02, 0)
	stream = Build.cyl(0.03, 1.0, Color(1.0, 0.6, 0.2), 1.5)
	stream_mat = stream.material_override
	ws.props.add_child(stream)
	stream.visible = false
	if crack_only:
		limit = 0.0
		phase = "crack"
		fill = 1.0
		crucible.visible = false
		cast_shader.set_shader_parameter("front", 100.0)
		cast_shader.set_shader_parameter("hot", Color(0.55, 0.5, 0.45))
		pour_score = 100.0

func on_input(e: InputEvent) -> void:
	if phase == "pour":
		if is_press(e) or key_down(e, [KEY_SPACE, KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT]):
			holding = true
		elif is_release(e) or key_up(e, [KEY_SPACE, KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT]):
			holding = false
	elif phase == "crack":
		if is_press(e) or key_down(e, [KEY_SPACE]):
			_crack()

func tick(delta: float) -> void:
	if phase != "pour":
		return
	tilt = clampf(tilt + (0.75 if holding else -1.3) * delta, 0.0, 1.0)
	crucible.rotation.z = -deg_to_rad(tilt * 105.0)
	var start_t = BK.POUR["start_tilt"]
	var rate = BK.POUR["flow"] + BK.POUR["flow_per_tier"] * tier
	flow = 0.0
	if tilt > start_t and metal > 0.0:
		flow = pow((tilt - start_t) / (1.0 - start_t), 1.4) * rate
	var splash = BK.POUR["splash_tilt"] + BK.POUR["splash_per_tier"] * tier
	var amount = minf(flow * delta, metal)
	metal -= amount
	if tilt > splash and amount > 0.0:
		# Glugging out too fast: some of it splashes on the bench.
		spilled += amount * 0.45
		amount *= 0.55
		if randf() < delta * 14.0:
			Fx.burst(ws, gate + Vector3(randf_range(-0.2, 0.2), 0.05, randf_range(-0.2, 0.3)), Color(1.0, 0.55, 0.15), 6, 0.6, 3.0, -9.0, 0.5, Vector3.UP, 70.0)
			if randf() < 0.3:
				Sfx.play("sizzle", 1.4, -6.0)
	fill += amount
	if fill > 1.0:
		overflow += fill - 1.0
		fill = 1.0
		if amount > 0.0 and randf() < delta * 10.0:
			Fx.burst(ws, cast.global_position + Vector3(randf_range(-0.3, 0.3), 0.05, 0.3), Color(1.0, 0.5, 0.15), 4, 0.5, 2.0, -9.0, 0.5)
	# The metal cools in the crucible the whole time.
	temp = maxf(0.0, temp - (BK.POUR["cool"] + BK.POUR["cool_per_tier"] * tier) * delta)
	_show_stream()
	cast_shader.set_shader_parameter("front", gate.x + 0.08 + fill * (blade_len + 0.05))
	if flow == 0.0 and fill > 0.0:
		still_t += delta
	else:
		still_t = 0.0
	if (fill >= 0.97 and still_t > 0.35) or metal <= 0.0 or temp <= 0.0 or t >= limit:
		_end_pour()

func _show_stream() -> void:
	stream.visible = flow > 0.0
	if not stream.visible:
		return
	var a = crucible.global_position
	var b = gate
	stream.global_position = (a + b) * 0.5
	stream.scale = Vector3(0.4 + flow * 1.5, a.distance_to(b), 0.4 + flow * 1.5)
	if randf() < 0.3:
		Fx.burst(ws, b, Color(1.0, 0.7, 0.3), 2, 0.4, 1.5, -6.0, 0.3)

func _end_pour() -> void:
	phase = "crack"
	holding = false
	flow = 0.0
	stream.visible = false
	var tw = create_tween()
	tw.tween_property(self, "tilt", 0.0, 0.3)
	tw.parallel().tween_property(crucible, "rotation:z", 0.0, 0.3)
	var fill_term = 100.0 - maxf(0.0, 1.0 - fill) * 260.0
	pour_score = fill_term - spilled * 90.0 - overflow * 140.0
	var vs = vsize()
	if temp <= 0.0 and fill < 0.97:
		pour_score -= 10.0
		popup("It froze in the pot!", Vector2(vs.x * 0.5, vs.y * 0.3), Color(0.7, 0.75, 0.85), 38)
	elif fill < 0.85:
		popup("Not full...", Vector2(vs.x * 0.5, vs.y * 0.3), Color(1.0, 0.6, 0.3), 38)
	elif overflow > 0.08 or spilled > 0.08:
		popup("Messy pour!", Vector2(vs.x * 0.5, vs.y * 0.3), Color(1.0, 0.6, 0.3), 38)
	else:
		popup("Clean pour!", Vector2(vs.x * 0.5, vs.y * 0.3), Color(1.0, 0.85, 0.3), 40)
		Sfx.play("good")
	if pour_only:
		phase = "done"
		get_tree().create_timer(0.9).timeout.connect(func(): finish(pour_score))

func _crack() -> void:
	cracks += 1
	Sfx.play("crack", 0.9 + cracks * 0.1)
	ws.shake(0.06)
	Fx.burst(ws, mold.global_position + Vector3(randf_range(-0.4, 0.4), 0.1, 0.2), Color(0.72, 0.6, 0.42), 14, 1.0, 3.0, -8.0, 0.6, Vector3.UP, 70.0, true)
	var tw = create_tween()
	tw.tween_property(mold, "scale", Vector3(1.04, 0.9, 1.04), 0.04)
	tw.tween_property(mold, "scale", Vector3.ONE * (1.0 - cracks * 0.04), 0.1)
	if cracks >= BK.POUR["cracks"]:
		phase = "done"
		mold.visible = false
		cavity.visible = false
		# Out of the mold: back to the real model, glowing and cooling.
		for mi in cast.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = null
		cast_mat = heat_tint(cast, 0.35 if crack_only else 0.9)
		Fx.burst(ws, cast.global_position, Color(0.72, 0.6, 0.42), 30, 1.4, 4.0, -9.0, 0.8, Vector3.UP, 80.0, true)
		popup("Fresh from the mold!", Vector2(vsize().x * 0.5, vsize().y * 0.3), Color(1.0, 0.85, 0.3), 36)
		var cool = create_tween()
		cool.tween_method(func(h): set_heat(cast_mat, h), 0.35 if crack_only else 0.9, 0.25, 0.8)
		get_tree().create_timer(0.9).timeout.connect(func(): finish(pour_score))

func draw_game() -> void:
	var vs = vsize()
	# Fill gauge with the FULL line.
	var r = Rect2(vs.x - 140, vs.y * 0.22, 46, vs.y * 0.48)
	if not crack_only:
		vgauge(r, fill / 1.1, 0.97 / 1.1, 1.0 / 1.1, Color(1.0, 0.8, 0.2), "MOLD")
	# Metal heat left: when it runs out the metal freezes in the pot.
	if not crack_only:
		hbar(Rect2(vs.x * 0.5 - 180, vs.y - 120, 360, 18), temp, BK.heat_color(0.3 + temp * 0.7), "METAL HEAT")
	if phase == "pour":
		var splash = BK.POUR["splash_tilt"] + BK.POUR["splash_per_tier"] * tier
		var tr = Rect2(vs.x - 250, vs.y * 0.22, 40, vs.y * 0.48)
		vgauge(tr, tilt, BK.POUR["start_tilt"] + 0.15, splash, Color(0.5, 0.85, 0.45), "TIP")
		var sy = tr.end.y - tr.size.y * splash
		draw_rect(Rect2(tr.position.x, tr.position.y, tr.size.x, sy - tr.position.y), Color(0.9, 0.2, 0.1, 0.35))
		if fill == 0.0 and not holding:
			text(Vector2(vs.x * 0.5, vs.y - 70), "HOLD TO POUR", 34, Color(1.0, 0.8, 0.4))
		elif fill >= 0.97:
			text(Vector2(vs.x * 0.5, vs.y - 70), "FULL! Let go!", 34, Color(1.0, 0.9, 0.4))
	elif phase == "crack":
		var p = ws.to_screen(mold.global_position)
		draw_arc(p, 70 + 6 * sin(t * 10.0), 0, TAU, 40, Color(1.0, 0.85, 0.3, 0.8), 4)
		text(Vector2(vs.x * 0.5, vs.y - 70), Hud.words("{Click} to crack the mold! %d / %d" % [cracks, BK.POUR["cracks"]]), 32, Color(1.0, 0.85, 0.4))
