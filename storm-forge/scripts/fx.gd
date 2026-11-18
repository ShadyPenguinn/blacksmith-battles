class_name Fx
extends RefCounted
## Little particle bursts: dust, rock chips, sparks, splashes. Meshes and materials are
## made once and shared, so a burst never makes the game hitch compiling a new shader.

static var _mesh: SphereMesh = null
static var _cube: BoxMesh = null
static var _curve: Curve = null

static func _shared() -> void:
	if _mesh:
		return
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_mesh = SphereMesh.new()
	_mesh.radius = 0.09
	_mesh.height = 0.18
	_mesh.radial_segments = 8
	_mesh.rings = 4
	_mesh.material = mat
	_cube = BoxMesh.new()
	_cube.size = Vector3(0.12, 0.12, 0.12)
	_cube.material = mat
	_curve = Curve.new()
	_curve.add_point(Vector2(0, 1))
	_curve.add_point(Vector2(1, 0))

## One burst at pos. dir is the main direction (the spread fans out around it).
static func burst(parent: Node, pos: Vector3, color: Color, count: int, size := 1.0,
		speed := 2.0, gravity := 0.6, life := 0.45, dir := Vector3.UP, spread := 80.0, chunky := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	_shared()
	var pa = CPUParticles3D.new()
	pa.mesh = _cube if chunky else _mesh
	pa.one_shot = true
	pa.amount = maxi(count, 1)
	pa.lifetime = life
	pa.explosiveness = 1.0
	pa.direction = dir
	pa.spread = spread
	pa.initial_velocity_min = speed * 0.5
	pa.initial_velocity_max = speed
	pa.gravity = Vector3(0, gravity, 0)
	pa.damping_min = 1.0
	pa.damping_max = 3.0
	pa.scale_amount_min = size * 0.7
	pa.scale_amount_max = size * 1.2
	pa.scale_amount_curve = _curve
	if chunky:
		pa.angular_velocity_min = -400.0
		pa.angular_velocity_max = 400.0
	pa.color = color
	parent.add_child(pa)
	pa.global_position = pos
	pa.emitting = true
	pa.finished.connect(pa.queue_free)

static func dust(parent: Node, pos: Vector3, count: int, size := 1.0) -> void:
	burst(parent, pos, Color(0.92, 0.9, 0.85, 0.8), count, size, 2.0 * size, 0.6, 0.45)

## Run once at startup, out of sight, so the first real burst is already compiled.
static func warm_up(parent: Node) -> void:
	burst(parent, Vector3(0, -50, 0), Color.WHITE, 1)
	burst(parent, Vector3(0, -50, 0), Color.WHITE, 1, 1.0, 1.0, 0.0, 0.2, Vector3.UP, 10.0, true)
