class_name Build
extends RefCounted
## Small helpers for placeholder shapes.

static func mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func box(size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, glow)
	return mi

static func cyl(radius: float, height: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat(color, glow)
	return mi

static func sphere(radius: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = mat(color, glow)
	return mi

static func box_shape(size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	return cs

static func label(text: String, size: int = 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.009
	return l

## A text meter like [----|##O##|----] for beat and heat bars.
static func meter(value: float, lo: float, hi: float, width: int = 21) -> String:
	var s := ""
	var pos := int(round(clampf(value, 0.0, 1.0) * (width - 1)))
	var a := int(round(lo * (width - 1)))
	var b := int(round(hi * (width - 1)))
	for i in width:
		if i == pos:
			s += "O"
		elif i >= a and i <= b:
			s += "="
		else:
			s += "-"
	return "[" + s + "]"
