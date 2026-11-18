extends CanvasLayer
## On-screen text: timer, door, buffs and debuffs, hints, toasts, the slot-machine roll.

var main: Node
var top_left: Label
var top_right: Label
var bottom: Label
var controls: Label
var toast_label: Label
var action_label: Label
var big: PanelContainer
var big_title: Label
var big_sub: Label
var door_bar: ProgressBar
var toast_t = 0.0
var action_t = 0.0
var roll_t = -1.0
var roll_buff: Dictionary
var roll_debuff: Dictionary

func setup(p_main: Node) -> void:
	main = p_main
	top_left = _label(Vector2(20, 16), 26)
	door_bar = ProgressBar.new()
	door_bar.position = Vector2(20, 168)
	door_bar.size = Vector2(360, 24)
	door_bar.show_percentage = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.35, 0.2)
	door_bar.add_theme_stylebox_override("background", bg)
	door_bar.add_theme_stylebox_override("fill", fill)
	add_child(door_bar)
	top_right = _label(Vector2(0, 16), 20)
	top_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(top_right, 1.0, 0.0, -620, 16, 600, 300)
	bottom = _label(Vector2(20, 0), 22)
	_place(bottom, 0.0, 1.0, 20, -96, 1500, 34)
	controls = _label(Vector2(20, 0), 16)
	_place(controls, 0.0, 1.0, 20, -40, 1560, 26)
	controls.modulate = Color(1, 1, 1, 0.75)
	controls.text = "WASD move   Shift sprint   Space dive   E / right-click grab, place, drop   F / click use   Q throw   1-4 switch smith   L call lightning   N skip door"
	toast_label = _label(Vector2(0, 0), 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast_label, 0.5, 0.0, -500, 90, 1000, 44)
	action_label = _label(Vector2(0, 0), 26)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(action_label, 0.5, 1.0, -400, -160, 800, 40)

	big = PanelContainer.new()
	_place(big, 0.5, 0.5, -380, -130, 760, 260)
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_child(vb)
	big_title = Label.new()
	big_title.add_theme_font_size_override("font_size", 44)
	big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(big_title)
	big_sub = Label.new()
	big_sub.add_theme_font_size_override("font_size", 26)
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(big_sub)
	add_child(big)
	big.visible = false

## Pin a control to an anchor point of the screen with an offset and size.
func _place(c: Control, ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_top = oy
	c.offset_right = ox + w
	c.offset_bottom = oy + h

func _label(pos: Vector2, size: int) -> Label:
	var l = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l

func refresh() -> void:
	var dt = get_process_delta_time()
	var cfg: Dictionary = SF.DOORS[main.door_index]
	var clock: String
	if main.time_left > 0.0:
		clock = "Storm peaks in %d:%02d" % [int(main.time_left) / 60, int(main.time_left) % 60]
	else:
		var left: float = maxf(0.0, SF.PEAK_GRACE - main.peak_time)
		clock = "STORM PEAK! Last stand %d:%02d" % [int(left) / 60, int(left) % 60]
	top_left.text = "Door %d/%d  %s\n%s\nNewest metal: %s\nDoor HP" % [main.door_index + 1, SF.DOORS.size(), cfg["area"], clock, SF.material_name(cfg["tier"]), ]
	door_bar.max_value = main.door.max_hp
	door_bar.value = main.door.hp
	var lines = []
	for b in SF.BUFFS:
		if main.mod(b["id"]) > 0:
			lines.append("+ %s x%d: %s" % [b["name"], main.mod(b["id"]), b["desc"]])
	for d in SF.DEBUFFS:
		if main.mod(d["id"]) > 0:
			lines.append("- %s x%d: %s" % [d["name"], main.mod(d["id"]), d["desc"]])
	top_right.text = "\n".join(lines)
	var p = main.players[main.controlled]
	bottom.text = "You: %s   %s" % [p.role["name"], main.hint(p)]
	toast_t = maxf(0.0, toast_t - dt)
	toast_label.modulate.a = clampf(toast_t, 0.0, 1.0)
	action_t = maxf(0.0, action_t - dt)
	action_label.modulate.a = clampf(action_t * 2.0, 0.0, 1.0)
	if roll_t >= 0.0:
		roll_t += dt
		if roll_t < 1.8:
			var b: Dictionary = SF.BUFFS.pick_random()
			var d: Dictionary = SF.DEBUFFS.pick_random()
			big_sub.text = "+ %s\n- %s" % [b["name"], d["name"]]
		else:
			big_sub.text = "+ %s: %s\n- %s: %s" % [roll_buff["name"], roll_buff["desc"], roll_debuff["name"], roll_debuff["desc"]]

func toast(msg: String) -> void:
	toast_label.text = msg
	toast_t = 2.5

func action(msg: String) -> void:
	action_label.text = msg
	action_t = 1.2

func show_roll(buff: Dictionary, debuff: Dictionary) -> void:
	roll_buff = buff
	roll_debuff = debuff
	roll_t = 0.0
	big_title.text = "Door broken!"
	big.visible = true

func show_big(title: String, sub: String) -> void:
	roll_t = -1.0
	big_title.text = title
	big_sub.text = sub
	big.visible = true

func hide_big() -> void:
	roll_t = -1.0
	big.visible = false
