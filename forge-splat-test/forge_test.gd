## Phone test for live pixel-art splats: the forge diorama drawn by the splat addon, with an FPS readout.
extends Node

## Camera framing, matching the ink-studio scene's own camera.
@export var camera_target: Vector3 = Vector3(-0.1, 1.15, -0.3)
@export var camera_distance: float = 7.6
@export var camera_pitch: float = 0.4
@export var camera_yaw: float = 0.32

@onready var _camera: Camera3D = %Camera
@onready var _scene: SplatScene = %SplatScene
@onready var _picture: TextureRect = %Picture
@onready var _status: Label = %Status

var _next_status: float = 0.0
var _frames: int = 0
var _elapsed: float = 0.0
var _low: float = 999.0


func _ready() -> void:
	var cp: float = cos(camera_pitch)
	var eye: Vector3 = camera_target + camera_distance * Vector3(cp * sin(camera_yaw), sin(camera_pitch), cp * cos(camera_yaw))
	_camera.look_at_from_position(eye, camera_target, Vector3.UP)
	_picture.texture = _scene.get_picture()
	_scene.measure_render_time = true
	_scene.interior = SplatScene.Interior.VOTE


func _process(delta: float) -> void:
	_frames += 1
	_elapsed += delta
	_next_status -= delta
	if _next_status > 0.0:
		return
	var fps: float = _frames / max(_elapsed, 0.001)
	if _elapsed > 3.0:
		_low = min(_low, fps)
	_frames = 0
	_elapsed = 0.0
	var passes: Vector2 = _scene.get_render_msec()
	_status.text = "%d fps   (lowest %s)\nsplats: %s\nrender %.1f ms GPU\n%s" % [
		roundi(fps), "-" if _low > 998.0 else str(roundi(_low)), _scene.status(), passes.y, RenderingServer.get_video_adapter_name()]
	_next_status = 1.0
