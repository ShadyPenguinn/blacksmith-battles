extends CanvasLayer
## On-screen text: timer, door, buffs and debuffs, hints, toasts, the slot-machine roll.

var main: Node
const CONTROLS := "WASD move   Shift sprint   Space jump (again in air: belly flop)   E / right-click grab, place, drop   F / click use   Q throw   1-4 / wheel pick slot   Tab switch smith   L call lightning   N skip door"
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
var menu: PanelContainer
var hotbar: Array = []     # [panel, label] per slot
var slot_style: StyleBoxFlat
var slot_style_sel: StyleBoxFlat
var menu_box: VBoxContainer

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
	controls.text = CONTROLS
	toast_label = _label(Vector2(0, 0), 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast_label, 0.5, 0.0, -450, 230, 900, 44)
	action_label = _label(Vector2(0, 0), 26)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(action_label, 0.5, 1.0, -400, -160, 800, 40)

	slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0, 0, 0, 0.5)
	slot_style.set_border_width_all(2)
	slot_style.border_color = Color(1, 1, 1, 0.25)
	slot_style.set_corner_radius_all(6)
	slot_style_sel = slot_style.duplicate()
	slot_style_sel.bg_color = Color(0.25, 0.2, 0.1, 0.8)
	slot_style_sel.border_color = Color(1.0, 0.8, 0.3)
	slot_style_sel.set_border_width_all(4)
	for i in SF.SLOTS:
		var panel = PanelContainer.new()
		_place(panel, 0.5, 1.0, -330 + i * 166, -118, 158, 64)
		var l = Label.new()
		l.add_theme_font_size_override("font_size", 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		panel.add_child(l)
		add_child(panel)
		hotbar.append([panel, l])

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

# ---------------------------------------------------------------- menu and lobby

func _menu_panel() -> void:
	if menu:
		menu.queue_free()
	menu = PanelContainer.new()
	_place(menu, 0.5, 0.5, -260, -190, 520, 380)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 14)
	menu.add_child(menu_box)
	add_child(menu)

func _menu_label(text: String, size: int) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	menu_box.add_child(l)
	return l

func _menu_button(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	menu_box.add_child(b)
	return b

func show_menu() -> void:
	_menu_panel()
	_menu_label("Storm Forge", 44)
	_menu_button("Play offline (switch between 4 smiths)", _on_offline)
	if OS.has_feature("web"):
		_menu_label("Browser version: offline only for now.\nOnline play needs the downloaded game.", 18)
		return
	_menu_button("Host a game", func(): main.menu_host())
	var ip = LineEdit.new()
	ip.text = main.join_ip
	ip.placeholder_text = "Host IP address"
	ip.add_theme_font_size_override("font_size", 24)
	menu_box.add_child(ip)
	_menu_button("Join", func(): main.menu_join(ip.text.strip_edges()))
	_menu_label("Type the host's IP above. Same Wi-Fi works,\nor the host forwards port %d." % 7777, 18)

func show_lobby(title: String, sub: String, can_start: bool) -> void:
	_menu_panel()
	_menu_label(title, 40)
	_menu_label(sub, 24)
	if can_start:
		_menu_button("Start", _on_start)

func _on_offline() -> void:
	_close_menu()
	main.menu_offline()

func _on_start() -> void:
	_close_menu()
	main.net.host_start()

func _close_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null

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
	if main.players.is_empty():
		return
	var p = main.players[main.controlled]
	bottom.text = "You: %s   %s" % [p.role["name"], main.hint(p)]
	for i in hotbar.size():
		hotbar[i][0].visible = main.run_started
		var it = p.slots[i] if i < p.slots.size() else null
		var name = it.display_name() if it and is_instance_valid(it) else ("tool" if i == 0 else "-")
		hotbar[i][1].text = "%d  %s" % [i + 1, name]
		hotbar[i][1].modulate.a = 1.0 if it else 0.5
		hotbar[i][0].add_theme_stylebox_override("panel", slot_style_sel if i == p.sel else slot_style)
	if main.is_online():
		controls.text = CONTROLS.replace("   Tab switch smith", "")
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
	_close_menu()
	roll_t = -1.0
	big_title.text = title
	big_sub.text = sub
	big.visible = true

func hide_big() -> void:
	_close_menu()
	roll_t = -1.0
	big.visible = false
