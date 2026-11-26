extends Node3D
## A job in progress that the smith carries around the shop: the ore, the crushed ore, the
## crucible or bloom, the bar, the blade... Its look follows the job's stage. The label over
## it says where it goes next.

var job: Dictionary          # {id, ticket, weapon, tier, stages, si, scores}
var holder: Node3D = null
var model: Node3D
var label: Label3D
var kind := ""

func setup(p_job: Dictionary) -> void:
	job = p_job
	label = Build.label("", 28)
	label.position.y = 0.95
	add_child(label)
	refresh()

func stage() -> Dictionary:
	return job["stages"][job["si"]]

func refresh() -> void:
	var k = job["stages"][job["si"] - 1]["make"] if job["si"] > 0 else "ore"
	if k == kind and model:
		_label()
		return
	kind = k
	if model:
		model.queue_free()
	var mat_d = BK.MATERIALS[job["tier"]]
	var col: Color = mat_d["color"]
	var hot := 0.0
	match kind:
		"ore":
			model = BK.fitted(BK.M + "resources/" + mat_d["ore"] + ".gltf", 0.45)
			BK.tint(model, col.darkened(0.2), 0.45)
		"crushed":
			model = Node3D.new()
			for i in 4:
				var bit = BK.fitted(BK.M + "resources/" + mat_d["ore"] + ".gltf", 0.18)
				bit.position = Vector3(randf_range(-0.12, 0.12), randf_range(0.0, 0.08), randf_range(-0.12, 0.12))
				model.add_child(bit)
				BK.tint(bit, Color(0.4, 0.18, 0.1), 0.6, 0.3, Color(1.0, 0.4, 0.1))
		"crucible":
			model = Node3D.new()
			var pot = Build.cyl(0.18, 0.36, Color(0.45, 0.3, 0.22))
			model.add_child(pot)
			var melt = Build.cyl(0.15, 0.03, col.lerp(Color(1.0, 0.7, 0.3), 0.6), 2.5)
			melt.position.y = 0.17
			model.add_child(melt)
		"bloom":
			model = BK.fitted(BK.M + "resources/" + mat_d["ore"] + ".gltf", 0.42)
			hot = 0.85
		"bar":
			model = BK.fitted(BK.M + "resources/" + mat_d["bar"] + ".gltf", 0.55)
			hot = 0.7
		_:
			model = BK.fitted(BK.WEAPONS[job["weapon"]]["model"], 0.9)
			model.rotation_degrees = Vector3(90, 0, -90)
			hot = 0.75 if kind == "hot_blade" else (0.45 if kind == "blank" and BK.route(job["tier"]) == "cast" else 0.0)
			if hot == 0.0:
				BK.tint(model, col, 0.45, 0.25 if kind == "done" else 0.0, Color(1, 0.9, 0.6))
	if model == null:
		model = Build.box(Vector3(0.3, 0.2, 0.3), col)
	add_child(model)
	if hot > 0.0:
		var c = col.lerp(BK.heat_color(hot * 0.85), hot)
		BK.tint(model, c, 0.5 + 0.3 * hot, hot * 1.3, BK.heat_color(hot * 0.85))
	_label()

func _label() -> void:
	var st = stage()
	var name = BK.WEAPONS[job["weapon"]]["name"]
	label.text = "%s\n> %s" % [name, BK.STATION_NAMES[st["at"]]]
	label.modulate = Color(1.0, 0.95, 0.8)
	label.font_size = 26
