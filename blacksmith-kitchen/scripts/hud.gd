class_name Hud
extends CanvasLayer
## Everything on screen: the top bar, banners, grade pops, the mentor's portrait and
## speech, the customer's speech bubble, menus, and the layer minigames draw on.

var game_layer: Control
var menu_root: Control
var top: Control
var top_left: Label
var top_right: Label
var steps_box: HBoxContainer
var banner: PanelContainer
var banner_title: Label
var banner_how: Label
var banner_go: Label
var mentor_box: PanelContainer
var mentor_text: Label
var mentor_cam: Camera3D
var mentor_vp: SubViewport
var bubble: PanelContainer
var bubble_name: Label
var bubble_text: Label
var menu_btn: Button
var ws: Workshop
var theme_res: Theme

const PAPER := Color(0.98, 0.93, 0.82)
const INK := Color(0.22, 0.14, 0.1)
const EMBER := Color(0.93, 0.45, 0.16)

signal menu_pressed

func setup(p_ws: Workshop) -> void:
	ws = p_ws
	theme_res = _make_theme()
	game_layer = Control.new()
	game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_layer)
	_top_bar()
	_mentor()
	_bubble()
	_banner()
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.theme = theme_res
	add_child(menu_root)

static func touch() -> bool:
	return DisplayServer.is_touchscreen_available()

static func words(s: String) -> String:
	return s.replace("{Click}", "Tap" if touch() else "Click").replace("{click}", "tap" if touch() else "click")

func _make_theme() -> Theme:
	var t = Theme.new()
	t.default_font_size = 26
	var sb = StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	t.set_stylebox("panel", "PanelContainer", sb)
	var b = StyleBoxFlat.new()
	b.bg_color = EMBER
	b.border_color = INK
	b.set_border_width_all(3)
	b.set_corner_radius_all(12)
	b.set_content_margin_all(12)
	b.content_margin_left = 22
	b.content_margin_right = 22
	var bh = b.duplicate()
	bh.bg_color = EMBER.lightened(0.2)
	var bp = b.duplicate()
	bp.bg_color = EMBER.darkened(0.2)
	var bd = b.duplicate()
	bd.bg_color = Color(0.6, 0.55, 0.5)
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.9, 0.9, 0.9))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 6)
	t.set_font_size("font_size", "Button", 28)
	t.set_color("font_color", "Label", INK)
	return t

func label(s: String, size := 26, color := INK, outline := 0) -> Label:
	var l = Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l

func _top_bar() -> void:
	top = Control.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 80)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.theme = theme_res
	add_child(top)
	menu_btn = Button.new()
	menu_btn.text = "Menu"
	menu_btn.position = Vector2(16, 14)
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	top.add_child(menu_btn)
	top_left = label("", 28, Color.WHITE, 8)
	top_left.position = Vector2(140, 20)
	top.add_child(top_left)
	top_right = label("", 30, Color(1.0, 0.85, 0.3), 8)
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.position = Vector2(-320, 20)
	top_right.size = Vector2(300, 40)
	top.add_child(top_right)
	steps_box = HBoxContainer.new()
	steps_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	steps_box.position = Vector2(-300, 22)
	steps_box.size = Vector2(600, 50)
	steps_box.alignment = BoxContainer.ALIGNMENT_CENTER
	steps_box.add_theme_constant_override("separation", 8)
	steps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(steps_box)

func set_top(left: String, coins: int) -> void:
	top_left.text = left
	top_right.text = "%d coins" % coins

func show_top(on: bool, menu := true) -> void:
	top.visible = on
	menu_btn.visible = menu

## Step chips across the top: done ones show their grade colour, the current one glows.
func set_steps(steps: Array, current: int, scores: Array) -> void:
	for c in steps_box.get_children():
		c.queue_free()
	for i in steps.size():
		var p = PanelContainer.new()
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		if i < scores.size():
			sb.bg_color = BK.step_grade(scores[i])["color"]
		elif i == current:
			sb.bg_color = Color(1.0, 0.95, 0.85)
			sb.border_color = EMBER
			sb.set_border_width_all(3)
		else:
			sb.bg_color = Color(0.3, 0.25, 0.22, 0.8)
		p.add_theme_stylebox_override("panel", sb)
		# Long recipes: only the current step shows its name, the rest show their number.
		var name = steps[i] if (i == current or steps.size() <= 7) else str(i + 1)
		var l = label(name, 16, INK if (i < scores.size() or i == current) else Color(0.85, 0.8, 0.75))
		p.add_child(l)
		steps_box.add_child(p)

func clear_steps() -> void:
	for c in steps_box.get_children():
		c.queue_free()

# --- Banner: step intro with Ready... GO! -----------------------------------------
func _banner() -> void:
	banner = PanelContainer.new()
	banner.theme = theme_res
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	banner.add_child(v)
	banner_title = label("", 52, EMBER.darkened(0.2))
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_title)
	banner_how = label("", 26)
	banner_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_how.custom_minimum_size = Vector2(640, 0)
	v.add_child(banner_how)
	banner_go = label("", 40, Color(0.25, 0.55, 0.25))
	banner_go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_go)
	banner.visible = false
	add_child(banner)

## Show a step's title and how-to, count in, then return.
func intro(title: String, how: String) -> void:
	banner_title.text = title
	banner_how.text = words(how)
	banner_go.text = "Ready..."
	banner.visible = true
	banner.reset_size()
	banner.position = (get_viewport().get_visible_rect().size - banner.size) * 0.5 + Vector2(0, -40)
	banner.scale = Vector2(0.7, 0.7)
	banner.pivot_offset = banner.size * 0.5
	var tw = create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(2.2).timeout
	banner_go.text = "GO!"
	await get_tree().create_timer(0.45).timeout
	banner.visible = false

# --- Floating text and the big grade --------------------------------------------
func float_text(s: String, pos: Vector2, color := Color.WHITE, size := 40) -> void:
	var l = label(s, size, color, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	l.reset_size()
	l.position = pos - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.6, 0.6)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 60, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)

func big(s: String, color: Color, time := 1.3, size := 110) -> void:
	var l = label(s, size, color, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	l.reset_size()
	var vs = get_viewport().get_visible_rect().size
	l.position = Vector2(vs.x * 0.5, vs.y * 0.42) - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.2, 0.2)
	l.rotation = -0.08
	var tw = create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "rotation", 0.04, 0.2)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(time - 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

# --- The mentor: a live portrait of Old Grizzle and what he says ----------------------
func _mentor() -> void:
	mentor_box = PanelContainer.new()
	mentor_box.theme = theme_res
	mentor_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mentor_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	mentor_box.add_child(h)
	var svc = SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(120, 120)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(svc)
	mentor_vp = SubViewport.new()
	mentor_vp.size = Vector2i(120, 120)
	mentor_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(mentor_vp)
	mentor_cam = Camera3D.new()
	mentor_cam.fov = 30
	mentor_vp.add_child(mentor_cam)
	var v = VBoxContainer.new()
	h.add_child(v)
	v.add_child(label(BK.MENTOR["name"], 22, EMBER.darkened(0.25)))
	mentor_text = label("", 24)
	mentor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mentor_text.custom_minimum_size = Vector2(320, 0)
	v.add_child(mentor_text)
	mentor_box.visible = false
	add_child(mentor_box)

func mentor_say(s: String, time := 2.5) -> void:
	mentor_text.text = s
	mentor_box.visible = true
	mentor_box.reset_size()
	var vs = get_viewport().get_visible_rect().size
	mentor_box.position = Vector2(16, vs.y - mentor_box.size.y - 16)
	mentor_box.set_meta("until", Time.get_ticks_msec() + int(time * 1000))

func _process(_delta: float) -> void:
	if mentor_box.visible:
		if Time.get_ticks_msec() > int(mentor_box.get_meta("until", 0)):
			mentor_box.visible = false
		elif ws and ws.mentor:
			var hp = ws.mentor.head_position() + Vector3(0, -0.15, 0)
			var fwd = ws.mentor.global_transform.basis.z.normalized()
			mentor_cam.global_transform = Transform3D(Basis(), hp + fwd * 1.6 + Vector3(0, 0.1, 0)).looking_at(hp, Vector3.UP)

# --- Customer speech bubble ---------------------------------------------------------
func _bubble() -> void:
	bubble = PanelContainer.new()
	bubble.theme = theme_res
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = VBoxContainer.new()
	bubble.add_child(v)
	bubble_name = label("", 22, EMBER.darkened(0.25))
	v.add_child(bubble_name)
	bubble_text = label("", 30)
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.custom_minimum_size = Vector2(520, 0)
	v.add_child(bubble_text)
	bubble.visible = false
	add_child(bubble)

func say(who: String, s: String) -> void:
	bubble_name.text = who
	bubble_text.text = s
	bubble.visible = true
	bubble.reset_size()
	var vs = get_viewport().get_visible_rect().size
	bubble.position = Vector2(vs.x * 0.5 - bubble.size.x * 0.5 + 120, 110)

func hush() -> void:
	bubble.visible = false

# --- Menus ---------------------------------------------------------------------------
func clear_menu() -> void:
	for c in menu_root.get_children():
		c.queue_free()

## A centered panel to fill with buttons. Returns its VBox.
func panel(title: String, width := 560.0) -> VBoxContainer:
	clear_menu()
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	if title != "":
		var l = label(title, 44, EMBER.darkened(0.2))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return v

func button(parent: Control, s: String, cb: Callable, enabled := true) -> Button:
	var b = Button.new()
	b.text = s
	b.disabled = not enabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
