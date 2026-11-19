## Interactive phone test for live pixel-art splats. The smith stands idle with his arm down.
## Tap: a hot piece (sword, axe or spear) lands on the anvil and he raises the hammer.
## Each tap after that is a slam, with sparks. Five slams finish the piece and the next one comes up.
## Leave it alone for a few seconds and he puts the hammer down.
extends Node

## Camera framing, matching the ink-studio scene's own camera.
@export var camera_target: Vector3 = Vector3(-0.1, 1.15, -0.3)
@export var camera_distance: float = 7.6
@export var camera_pitch: float = 0.4
@export var camera_yaw: float = 0.32

## Where the hammer lands, in the scene's metres (forge-live.js HIT).
const HIT: Vector3 = Vector3(0.65, 0.93, 0.45)
const FPS: float = 24.0
## The clip's segments, in seconds: [start, end].
const IDLE: Vector2 = Vector2(0.0, 1.0)
const RAISE: Vector2 = Vector2(1.0, 1.5)
const READY: Vector2 = Vector2(1.5, 2.0)
const SLAM: Vector2 = Vector2(2.0, 2.25)
const RECOVER: Vector2 = Vector2(2.25, 2.5)
const SLAMS_PER_PIECE: int = 5
const IDLE_AFTER: float = 4.0
const HIDDEN: Vector3 = Vector3(0.0, -60.0, 0.0)

enum State { IDLE, RAISE, READY, SLAM, RECOVER, LOWER }

@onready var _camera: Camera3D = %Camera
@onready var _scene: SplatScene = %SplatScene
@onready var _picture: TextureRect = %Picture
@onready var _status: Label = %Status
@onready var _hint: Label = %Hint
@onready var _smith = %Forge
@onready var _sparks: Control = %Sparks
@onready var _pieces: Array[Node3D] = [%Sword, %Axe, %Spear]

var _state: State = State.IDLE
var _t: float = 0.0
var _queued: bool = false
var _since_tap: float = 0.0
var _piece: int = -1
var _slams: int = 0
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
	for p: Node3D in _pieces:
		p.position = HIDDEN
	_hint.text = "Tap to forge"


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE)
	if tap:
		_tap()


func _tap() -> void:
	_since_tap = 0.0
	match _state:
		State.IDLE, State.LOWER:
			_next_piece()
			_go(State.RAISE)
		State.READY:
			_go(State.SLAM)
		_:
			_queued = true


func _next_piece() -> void:
	if _piece >= 0:
		_pieces[_piece].position = HIDDEN
	_piece = (_piece + 1) % _pieces.size()
	_pieces[_piece].position = Vector3.ZERO
	_slams = 0
	_hint.text = "%s: tap to slam" % ["Sword", "Axe", "Spear"][_piece]


func _go(s: State) -> void:
	_state = s
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	_since_tap += delta
	var clip_time: float = 0.0
	match _state:
		State.IDLE:
			clip_time = IDLE.x + fmod(_t, IDLE.y - IDLE.x)
		State.RAISE:
			clip_time = minf(RAISE.x + _t, RAISE.y - 0.001)
			if _t >= RAISE.y - RAISE.x:
				_go(State.READY)
		State.READY:
			clip_time = READY.x + fmod(_t, READY.y - READY.x)
			if _queued:
				_queued = false
				_go(State.SLAM)
			elif _since_tap > IDLE_AFTER:
				_go(State.LOWER)
		State.SLAM:
			clip_time = minf(SLAM.x + _t, SLAM.y - 0.001)
			if _t >= SLAM.y - SLAM.x:
				_hit()
				_go(State.RECOVER)
		State.RECOVER:
			clip_time = minf(RECOVER.x + _t, RECOVER.y - 0.001)
			if _t >= RECOVER.y - RECOVER.x:
				_go(State.READY)
		State.LOWER:
			# the raise played backwards
			clip_time = maxf(RAISE.y - _t, RAISE.x)
			if _t >= RAISE.y - RAISE.x:
				if _piece >= 0:
					_pieces[_piece].position = HIDDEN
				_hint.text = "Tap to forge"
				_go(State.IDLE)
	_smith.frame = clampi(floori(clip_time * FPS), 0, 59)
	_fps(delta)


func _hit() -> void:
	_slams += 1
	_sparks.pixel = _art_pixel()
	_sparks.burst(_to_screen(HIT), 14 if _slams < SLAMS_PER_PIECE else 40)
	if _slams >= SLAMS_PER_PIECE:
		_hint.text = "%s done! Tap for the next" % ["Sword", "Axe", "Spear"][_piece]
		_slams = 0
		_next_piece_later()
	else:
		_hint.text = "%s: %d / %d" % [["Sword", "Axe", "Spear"][_piece], _slams, SLAMS_PER_PIECE]


func _next_piece_later() -> void:
	await get_tree().create_timer(0.35).timeout
	_next_piece()


## Screen pixels per art pixel on the picture.
func _art_pixel() -> float:
	var art: Vector2 = Vector2(_scene.art_size)
	var r: Vector2 = _picture.size
	return minf(r.x / art.x, r.y / art.y)


## A point of the scene on screen, through the same projection the splat pass uses.
func _to_screen(p: Vector3) -> Vector2:
	var art: Vector2 = Vector2(_scene.art_size)
	var local: Vector3 = _camera.global_transform.affine_inverse() * p
	var lens: float = art.y * 0.5 / tan(deg_to_rad(_camera.fov) * 0.5)
	var a: Vector2 = Vector2(art.x * 0.5 + local.x / -local.z * lens, art.y * 0.5 - local.y / -local.z * lens)
	var s: float = _art_pixel()
	var offset: Vector2 = _picture.global_position + (_picture.size - art * s) * 0.5
	return offset + a * s - _sparks.global_position


func _fps(delta: float) -> void:
	_frames += 1
	_elapsed += delta
	_next_status -= delta
	if _next_status > 0.0:
		return
	var fps: float = _frames / max(_elapsed, 0.001)
	if _elapsed > 0.5:
		_low = min(_low, fps) if Engine.get_process_frames() > 180 else _low
	_frames = 0
	_elapsed = 0.0
	var passes: Vector2 = _scene.get_render_msec()
	_status.text = "%d fps   (lowest %s)\n%s\nrender %.1f ms GPU   %s" % [
		roundi(fps), "-" if _low > 998.0 else str(roundi(_low)), _scene.status(), passes.y, RenderingServer.get_video_adapter_name()]
	_next_status = 1.0
