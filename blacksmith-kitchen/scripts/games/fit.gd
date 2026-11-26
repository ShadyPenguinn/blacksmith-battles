extends BenchGame
## Fit the Handle: the handle swings above the socket. Drop it in, then tap it home.

var handle: Node3D
var swing := 0.0
var amp := 0.5
var speed := 2.4
var phase := "swing"      # swing, fall, tap
var align := 0.0
var taps := 0
var tap_need := 5
var tap_t0 := 0.0
var drop_x := 0.0
var fall_y := 0.0
var mallet: Node3D

func prepare() -> void:
	lay_blade()
	BK.tint(blade, mat_color(), 0.45)
	speed = 2.2 + tier * 0.25
	handle = Build.cyl(0.05, 0.7, Color(0.5, 0.32, 0.18))
	handle.rotation_degrees.z = 90
	ws.props.add_child(handle)
	mallet = BK.fitted(BK.M + "tools/hammer.gltf", 0.5)
	ws.props.add_child(mallet)
	mallet.visible = false
	fall_y = 0.7

func _socket() -> Vector3:
	return along3(0.12)

func tick(delta: float) -> void:
	match phase:
		"swing":
			swing += delta * speed
			drop_x = sin(swing) * amp
			handle.global_position = _socket() + Vector3(drop_x, fall_y, 0)
		"fall":
			fall_y = maxf(0.0, fall_y - delta * 4.0)
			handle.global_position = _socket() + Vector3(drop_x, fall_y, 0)
			if fall_y <= 0.0:
				phase = "tap"
				tap_t0 = t
				mallet.visible = true
				ws.shake(0.05)
				var off = absf(drop_x)
				align = clampf(1.0 - off / 0.3, 0.0, 1.0)
				var label = "Perfect fit!" if align > 0.85 else ("Snug!" if align > 0.5 else "Crooked...")
				popup(label, ws.to_screen(_socket()) + Vector2(0, -80), Color(1.0, 0.85, 0.3), 36)
		"tap":
			mallet.global_position = _socket() + Vector3(drop_x - 0.45, 0.35, 0.1)

func on_input(e: InputEvent) -> void:
	if not (is_press(e) or key_down(e, [KEY_SPACE, KEY_ENTER, KEY_F])):
		return
	if phase == "swing":
		phase = "fall"
	elif phase == "tap":
		taps += 1
		Sfx.play("thud", 1.6)
		var tw = create_tween()
		mallet.rotation_degrees.z = 40
		tw.tween_property(mallet, "rotation_degrees:z", -20.0, 0.06)
		tw.tween_property(mallet, "rotation_degrees:z", 40.0, 0.1)
		Fx.burst(ws, _socket() + Vector3(drop_x - 0.35, 0.05, 0), Color(0.9, 0.75, 0.5), 4, 0.5, 2.0, -6.0, 0.3)
		handle.global_position.x = lerpf(handle.global_position.x, _socket().x, 0.3)
		drop_x = handle.global_position.x - _socket().x
		if taps >= tap_need:
			active = false
			var speed_f = clampf(1.0 - (t - tap_t0 - 1.2) / 3.0, 0.0, 1.0)
			get_tree().create_timer(0.4).timeout.connect(func(): finish(100.0 * (0.7 * align + 0.3 * speed_f)))

func draw_game() -> void:
	var sp = ws.to_screen(_socket())
	draw_arc(sp, 26, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.8), 4)
	if phase == "swing":
		text(sp + Vector2(0, 70), "DROP!", 30, Color(1, 0.9, 0.5))
	elif phase == "tap":
		text(sp + Vector2(0, 70), "TAP IT HOME!  %d / %d" % [taps, tap_need], 30, Color(1, 0.9, 0.5))
