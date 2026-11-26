extends SceneTree
## Runs the game and saves a screenshot every N seconds.
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/capture.gd -- OUTDIR EVERY COUNT [game args...]
var out := ""
var every := 2.0
var count := 10
var t := 0.0
var n := 0
var next := 0.0

func _initialize() -> void:
	var a = OS.get_cmdline_user_args()
	out = a[0]
	every = float(a[1])
	count = int(a[2])
	next = every
	DirAccess.make_dir_recursive_absolute(out)
	root.add_child(load("res://main.tscn").instantiate())

func _process(delta: float) -> bool:
	t += delta
	if t >= next:
		next += every
		var img = root.get_texture().get_image()
		img.save_png(out + "/shot_%02d.png" % n)
		n += 1
		if n >= count:
			return true
	return false
