extends Node3D
## One co-op smith. Keyboard sets for players 1-2, gamepads for 3-4 (and 1-2 if plugged in).
## GRAB picks up / puts down. USE stomps, hammers, pedals and pours. Hold USE by a hot
## ingot to grip it with the tongs; keep holding while you walk, let go to drop it.

const KEYS := [
	{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "grab": KEY_E, "use": KEY_F, "use2": KEY_SPACE},
	{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "grab": KEY_PERIOD, "use": KEY_SLASH, "use2": KEY_SHIFT},
]

var rush: Node
var idx := 0
var actor: Actor
var vel := Vector3.ZERO
var held: Node3D = null
var tongs := false
var stun := 0.0
var knock_v := Vector3.ZERO
var pad := -1
var prev := {"grab": false, "use": false}
var act_t := 0.0
var moving := false
var ring: MeshInstance3D
var auto_target = null      # shop mode: click-to-walk destination (Vector3) or null

func setup(p_rush: Node, p_idx: int, n: int) -> void:
	rush = p_rush
	idx = p_idx
	if idx >= 2:
		pad = idx - 2
	elif n <= 2:
		pad = idx
	actor = Actor.new()
	add_child(actor)
	actor.setup(BK.M + BK.PLAYER_MODELS[idx])
	ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	ring.mesh = tm
	ring.scale = Vector3(1, 0.3, 1)
	ring.position.y = 0.04
	ring.material_override = Build.mat(BK.PLAYER_COLORS[idx], 1.2)
	add_child(ring)
	var tag = Build.label("P%d" % (idx + 1), 44)
	tag.modulate = BK.PLAYER_COLORS[idx]
	tag.position.y = 2.4
	add_child(tag)

func _pressed(action: String) -> bool:
	var down = false
	if idx < 2:
		var k = KEYS[idx]
		down = Input.is_physical_key_pressed(k[action])
		if action == "use" and Input.is_physical_key_pressed(k["use2"]):
			down = true
	if pad >= 0 and pad in Input.get_connected_joypads():
		if action == "grab":
			down = down or Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
		elif action == "use":
			down = down or Input.is_joy_button_pressed(pad, JOY_BUTTON_X) or Input.is_joy_button_pressed(pad, JOY_BUTTON_B)
	return down

func _move_input() -> Vector2:
	var v = Vector2.ZERO
	if idx < 2:
		var k = KEYS[idx]
		v.x = float(Input.is_physical_key_pressed(k["right"])) - float(Input.is_physical_key_pressed(k["left"]))
		v.y = float(Input.is_physical_key_pressed(k["down"])) - float(Input.is_physical_key_pressed(k["up"]))
	if pad >= 0 and pad in Input.get_connected_joypads():
		var j = Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if j.length() > 0.2:
			v += j
		v.x += float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT))
		v.y += float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP))
	return v.limit_length(1.0)

func _process(delta: float) -> void:
	act_t = maxf(0.0, act_t - delta)
	var grab_now = _pressed("grab")
	var use_now = _pressed("use")
	var grab_edge = grab_now and not prev["grab"]
	var use_edge = use_now and not prev["use"]
	prev["grab"] = grab_now
	prev["use"] = use_now
	if stun > 0.0:
		stun -= delta
		knock_v = knock_v.move_toward(Vector3.ZERO, 12.0 * delta)
		_slide(knock_v * delta)
		return
	# Tongs: hold USE by a hot ingot to grip it.
	if tongs:
		if not use_now or held == null:
			tongs = false
			if held:
				rush.tongs_release(self, held)
	elif use_now and held == null:
		var hot = rush.tongs_target(self)
		if hot:
			take(hot)
			tongs = true
			use_edge = false
	if grab_edge and act_t <= 0.0 and not tongs:
		rush.grab(self)
	elif use_edge and act_t <= 0.0 and not tongs:
		rush.use(self)
	var mv = _move_input()
	if mv.length() > 0.1:
		auto_target = null
	elif auto_target != null:
		var d = Vector2(auto_target.x - global_position.x, auto_target.z - global_position.z)
		if d.length() < 0.25:
			auto_target = null
			if rush.has_method("arrived"):
				rush.arrived(self)
		else:
			mv = d.normalized() * minf(1.0, d.length() * 2.0 + 0.3)
	var speed = BK.RUSH["speed"] if held == null else BK.RUSH["carry_speed"]
	if act_t > 0.0:
		speed *= 0.2
	var want = Vector3(mv.x, 0, mv.y) * speed
	vel = vel.move_toward(want, 40.0 * delta)
	_slide(vel * delta)
	var is_moving = vel.length() > 0.3
	if is_moving:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(vel.x, vel.z), minf(1.0, delta * 14.0))
	if is_moving != moving and act_t <= 0.0:
		moving = is_moving
		actor.loop("Running_A" if moving else "Idle_A", 1.2)
	if held:
		var fwd = Vector3(sin(actor.rotation.y), 0, cos(actor.rotation.y))
		held.global_position = global_position + fwd * 0.55 + Vector3(0, 1.05, 0)
		held.rotation.y = actor.rotation.y

func _slide(step: Vector3) -> void:
	var p = global_position + step
	p.x = clampf(p.x, -11.2, 11.2)
	p.z = clampf(p.z, -5.4, Workshop.COUNTER_Z - 0.7)
	var q = Vector2(p.x, p.z)
	for o in rush.obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1] + 0.35
		var d = q - c
		if d.length() < r:
			q = c + d.normalized() * r
	for s in rush.smiths:
		if s == self:
			continue
		var d2 = q - Vector2(s.global_position.x, s.global_position.z)
		if d2.length() < 0.7 and d2.length() > 0.001:
			q += d2.normalized() * (0.7 - d2.length()) * 0.5
	global_position = Vector3(q.x, 0, q.y)

func take(it: Node3D) -> void:
	held = it
	it.holder = self
	actor.once("PickUp", 2.2)

func drop() -> void:
	if held == null:
		return
	var it = held
	held = null
	tongs = false
	it.holder = null
	var fwd = Vector3(sin(actor.rotation.y), 0, cos(actor.rotation.y))
	it.global_position = global_position + fwd * 0.7 + Vector3(0, 0.15, 0)

func ouch() -> void:
	rush.main.hud.float_text("OUCH! Use the tongs (hold USE)", rush.ws.to_screen(global_position + Vector3(0, 2.4, 0)), Color(1, 0.5, 0.3), 28)
	stun = 0.6
	Sfx.play("sizzle")
	actor.once("Hit_A", 1.2)

func knock(v: Vector3) -> void:
	drop()
	knock_v = v
	stun = 0.9
	actor.once("Hit_B", 1.0)

func hop() -> void:
	act_t = 0.25
	var tw = actor.create_tween()
	tw.tween_property(actor, "position:y", 0.45, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(actor, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)

func act(clip: String) -> void:
	act_t = 0.3
	actor.once(clip, 2.0)
