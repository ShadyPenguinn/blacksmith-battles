extends Node3D
## Something a smith can carry in Rush Hour: ore, a hot or cold ingot, a blank, a quenched
## blade, a finished weapon, or the bucket.

var rush: Node
var kind := ""
var weapon := ""
var holder: Node3D = null
var hot := 0.0
var brittle := false
var water := false
var model: Node3D
var mat: StandardMaterial3D
var label: Label3D

func setup(p_rush: Node, p_kind: String, p_weapon := "") -> void:
	rush = p_rush
	kind = p_kind
	weapon = p_weapon
	if kind == "ingot":
		hot = BK.RUSH["ingot_cool"]
	label = Build.label("", 30)
	label.position.y = 0.9
	add_child(label)
	refresh()

func refresh() -> void:
	if model:
		model.queue_free()
	var copper = BK.MATERIALS[0]
	match kind:
		"ore":
			model = BK.fitted(BK.M + "resources/" + copper["ore"] + ".gltf", 0.5)
		"ingot", "cold":
			model = BK.fitted(BK.M + "resources/" + copper["bar"] + ".gltf", 0.55)
		"blank", "quenched", "weapon":
			model = BK.fitted(BK.WEAPONS[weapon]["model"], 0.9)
			model.rotation_degrees = Vector3(90, 0, -90)
		"bucket":
			model = BK.fitted(BK.M + "tools/bucket_metal.gltf", 0.8)
	add_child(model)
	label.text = ""
	match kind:
		"ingot":
			mat = BK.tint(model, BK.heat_color(0.8), 0.7, 1.4, BK.heat_color(0.8))
		"cold":
			BK.tint(model, Color(0.45, 0.45, 0.5), 0.6)
			label.text = "cold"
		"blank":
			BK.tint(model, BK.heat_color(0.7), 0.6, 1.0, BK.heat_color(0.7))
			label.text = BK.WEAPONS[weapon]["name"]
		"quenched":
			BK.tint(model, Color(0.55, 0.55, 0.6), 0.4)
			label.text = "grind me"
		"weapon":
			BK.tint(model, BK.MATERIALS[0]["color"], 0.35, 0.3, Color(1, 0.9, 0.6))
			label.text = BK.WEAPONS[weapon]["name"] + (" (brittle)" if brittle else "") + "!"
		"bucket":
			if water:
				var w = Build.cyl(0.2, 0.04, Color(0.35, 0.65, 1.0), 0.4)
				w.position.y = 0.05
				model.add_child(w)
			label.text = "bucket" + (" (full)" if water else "")
	label.modulate = Color(1, 1, 1, 0.9)

func _process(_delta: float) -> void:
	if kind == "ingot" and mat:
		var h = clampf(hot / BK.RUSH["ingot_cool"], 0.0, 1.0)
		mat.emission = BK.heat_color(0.3 + 0.6 * h)
		mat.albedo_color = Color(BK.heat_color(0.3 + 0.6 * h), 0.7)
		mat.emission_energy_multiplier = 0.4 + h
		if holder == null and randf() < 0.05:
			Fx.burst(rush.ws, global_position, Color(1.0, 0.6, 0.2), 1, 0.4, 1.0, -3.0, 0.4)
